import sys
import json
import boto3
from datetime import datetime, timezone
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql import functions as F
from pyspark.sql.window import Window

args = getResolvedOptions(sys.argv, ['JOB_NAME'])
glue = GlueContext(SparkContext.getOrCreate())
spark = glue.spark_session
job = Job(glue)
job.init(args['JOB_NAME'], args)
BUCKET = 'tech-challenge-fase3-grupo-18'
BASE = f's3://{BUCKET}/silver/dados-mercado-brasil/'
OUT = f's3://{BUCKET}/gold/dados-mercado-brasil/'

profile = spark.read.parquet(BASE + 'perfil_enriquecido/').cache()
multiple = spark.read.parquet(BASE + 'respostas_multiplas/').cache()

# Stop rather than silently hide duplicates or incomplete keys.
for df, keys, name in [
    (profile, ['edicao', 'id_resposta'], 'perfil_enriquecido'),
    (multiple, ['edicao', 'id_resposta', 'tema', 'codigo_pergunta'], 'respostas_multiplas')
]:
    if not df.limit(1).count():
        raise ValueError(f'Tabela vazia: {name}')
    for key in keys:
        if df.filter(F.col(key).isNull() | (F.trim(F.col(key)) == '')).limit(1).count():
            raise ValueError(f'Chave ausente: {name}.{key}')
    if df.groupBy(*keys).count().filter('count > 1').limit(1).count():
        raise ValueError(f'Duplicatas encontradas em {name}; corrigir a Silver primeiro')

def boolean_number(name):
    v = F.lower(F.trim(F.col(name).cast('string')))
    return F.when(v.isin('1', 'true'), 1).when(v.isin('0', 'false'), 0)

profile = (profile.withColumn('satisfeito', F.col('satisfeito_booleano').cast('int'))
    .withColumn('gestor_normalizado', F.col('gestor_booleano').cast('int')))

def segments(df):
    # The total is a separate analytical scope, not additive to the sectors.
    segmented = df.withColumn('segmento',
        F.when(F.col('setor').isNull() | (F.trim(F.col('setor')) == ''), 'setor_nao_informado')
         .when(F.col('setor') == 'Finanças ou Bancos', 'financas_bancos')
         .otherwise('demais_setores'))
    return segmented.unionByName(df.withColumn('segmento', F.lit('todos')))

p = segments(profile).cache()
m = segments(multiple).cache()
tables = {}

def distribution(df, grouping, category):
    # Only answered values enter the denominator. Other literal responses,
    # such as "Prefiro não informar", remain explicit categories.
    valid = df.filter(F.col(category).isNotNull() & (F.trim(F.col(category).cast('string')) != ''))
    counts = valid.groupBy(*(grouping + [category])).agg(F.count('*').alias('numerador'))
    return (counts.withColumn('denominador', F.sum('numerador').over(Window.partitionBy(*grouping)))
        .withColumn('percentual', F.round(F.lit(100.0) * F.col('numerador') / F.col('denominador'), 2)))

# Population by dimension. Each dimension has its own valid-response base.
demographic = []
for dimension in ['cargo', 'senioridade', 'genero', 'regiao', 'escolaridade', 'gestor_normalizado']:
    d = p.select('edicao', 'segmento', F.col(dimension).cast('string').alias('categoria'))
    demographic.append(distribution(d, ['edicao', 'segmento'], 'categoria')
                       .withColumn('dimensao', F.lit(dimension)))
tables['gold_perfil'] = demographic[0]
for d in demographic[1:]:
    tables['gold_perfil'] = tables['gold_perfil'].unionByName(d)

# Salary bands, not an estimated mean. Flagged malformed bands are excluded.
salary = p.filter(~F.coalesce(F.col('alerta_faixa_salarial'), F.lit(False)))
for field in ['cargo', 'senioridade', 'regiao', 'genero']:
    salary = salary.withColumn(field, F.coalesce(F.col(field), F.lit('Nao informado')))
tables['gold_remuneracao'] = distribution(
    salary, ['edicao', 'segmento', 'cargo', 'senioridade', 'regiao', 'genero'], 'faixa_salarial')

models = []
for field, kind in [('modelo_atual', 'atual'), ('modelo_ideal', 'ideal')]:
    d = p.select('edicao', 'segmento', F.col(field).alias('modelo'))
    models.append(distribution(d, ['edicao', 'segmento'], 'modelo')
                  .withColumn('tipo_modelo', F.lit(kind)))
tables['gold_modelo_trabalho'] = models[0].unionByName(models[1])

# Satisfaction by alignment with ideal work model; descriptive association.
sat = p.filter(F.col('modelo_diferente_ideal').isNotNull() & F.col('satisfeito').isNotNull())
tables['gold_satisfacao'] = (sat.groupBy('edicao', 'segmento', 'modelo_diferente_ideal')
    .agg(F.sum('satisfeito').alias('numerador'), F.count('*').alias('denominador'))
    .withColumn('percentual', F.round(F.lit(100.0) * F.col('numerador') / F.col('denominador'), 2)))

# Keep priority and declared business results as separate questions/populations.
ia = []
for field in ['prioridade_ia', 'resultado_ia_empresa']:
    d = p.select('edicao', 'segmento', F.col(field).alias('resposta'))
    ia.append(distribution(d, ['edicao', 'segmento'], 'resposta')
              .withColumn('indicador', F.lit(field)))
tables['gold_ia_empresas'] = ia[0].unionByName(ia[1])

# Each option has its own denominator. Multiple-choice percentages need not
# sum to 100. "linguagem_preferencia" stays separate from "linguagem_uso".
if multiple.filter(~F.col('selecionado').isin(0, 1) | F.col('selecionado').isNull()).limit(1).count():
    raise ValueError('Resposta multipla diferente de 0/1')
tables['gold_multiplas_escolhas'] = (m.groupBy('edicao', 'segmento', 'tema', 'codigo_pergunta', 'opcao')
    .agg(F.sum('selecionado').alias('numerador'), F.count('*').alias('denominador'))
    .withColumn('percentual', F.round(F.lit(100.0) * F.col('numerador') / F.col('denominador'), 2)))

# Adoption denominator excludes contradictory and insufficient responses.
adoption = (p.groupBy('edicao', 'segmento').agg(
    F.count('*').alias('total_respondentes'),
    F.sum(F.when(F.col('usa_ia_generativa') == F.lit(True), 1).otherwise(0)).alias('numerador'),
    F.count('usa_ia_generativa').alias('denominador'),
    F.sum(F.col('ia_resposta_contraditoria').cast('long')).alias('respostas_contraditorias'),
    F.sum(F.when(F.col('status_resposta_ia') == 'insuficiente_ou_ausente', 1).otherwise(0)).alias('respostas_insuficientes_ou_ausentes'))
    .withColumn('nao_usuarios', F.col('denominador') - F.col('numerador'))
    .withColumn('percentual', F.when(F.col('denominador') > 0,
        F.round(F.lit(100.0) * F.col('numerador') / F.col('denominador'), 2))))
tables['gold_adocao_ia'] = adoption
if adoption.filter(F.col('total_respondentes') !=
    F.col('denominador') + F.col('respostas_contraditorias') +
    F.col('respostas_insuficientes_ou_ausentes')).limit(1).count():
    raise ValueError('Populacao de IA nao reconciliada')

# Validate all tables before starting any write.
for name, df in tables.items():
    tables[name] = df.cache()
    invalid = df.filter((F.col('denominador') < (0 if name == 'gold_adocao_ia' else 1)) | (F.col('numerador') < 0)
                        | (F.col('numerador') > F.col('denominador')))
    if invalid.limit(1).count():
        raise ValueError(f'Numerador/denominador invalido: {name}')
    if df.count() == 0:
        raise ValueError(f'Saida vazia: {name}')

report = {}
for name, df in tables.items():
    expected = df.count()
    path = OUT + name + '/'
    (df.repartition(3, 'edicao').write.mode('overwrite')
        .partitionBy('edicao').parquet(path))
    observed = spark.read.parquet(path).count()
    if observed != expected:
        raise ValueError(f'Contagem de saida incorreta: {name}')
    report[name] = {'linhas': observed, 's3': path}
    print('GOLD_OK ' + json.dumps({name: report[name]}))

stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
boto3.client('s3').put_object(Bucket=BUCKET,
    Key=f'auditoria/gold/{stamp}_resumo.json',
    Body=json.dumps(report, ensure_ascii=False, indent=2).encode('utf-8'),
    ContentType='application/json; charset=utf-8')
print('SUCCESS: Gold concluida. Percentuais na escala 0 a 100.')
job.commit()
