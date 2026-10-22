import sys
import re
import json
import boto3
from datetime import datetime, timezone
import uuid
from functools import reduce
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.context import SparkContext
from pyspark.sql import functions as F

RUN = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '_' + uuid.uuid4().hex[:8]
quality = []
EXPECTED_COLUMNS = {'2023-2024': 399, '2024-2025': 403, '2025-2026': 388}

args = getResolvedOptions(sys.argv, ['JOB_NAME'])
glue = GlueContext(SparkContext.getOrCreate())
spark = glue.spark_session
job = Job(glue)
job.init(args['JOB_NAME'], args)

BUCKET = 'tech-challenge-fase3-grupo-18'
PREFIX = 'bronze/dados-mercado-brasil/'
OUTPUT = f's3://{BUCKET}/silver/dados-mercado-brasil/perfil_profissionais/'

# Locate the original CSVs, including files uploaded into subfolders.
keys = []
for page in boto3.client('s3').get_paginator('list_objects_v2').paginate(
    Bucket=BUCKET, Prefix=PREFIX
):
    keys.extend(x['Key'] for x in page.get('Contents', [])
                if x['Key'].lower().endswith('.csv'))

files = {}
for edition, year in [('2023-2024', '2023'), ('2024-2025', '2024'),
                      ('2025-2026', '2025')]:
    matches = [k for k in keys if year in k.rsplit('/', 1)[-1]]
    if len(matches) != 1:
        raise ValueError(f'Expected one CSV for {edition}; found: {matches}')
    files[edition] = matches[0]

common = {
    'idade': '1.a', 'faixa_idade': '1.a.1', 'genero': '1.b',
    'cor_raca_etnia': '1.c', 'pcd': '1.d', 'vive_no_brasil': '1.g',
    'uf': '1.i.1', 'regiao': '1.i.2', 'escolaridade': '1.l',
    'situacao_trabalho': '2.a', 'setor': '2.b', 'gestor': '2.d',
    'cargo_gestao': '2.e', 'cargo': '2.f', 'senioridade': '2.g',
    'faixa_salarial': '2.h', 'experiencia_dados': '2.i',
    'satisfacao': '2.k', 'prioridade_ia': '3.e'
}

def question_code(header):
    if header.startswith("('P"):
        return header.split("'")[1].strip()[1:].replace('_', '.')
    match = re.match(r'^(\d+(?:\.[a-z0-9]+)*)(?:_|\s|$)', header)
    return match.group(1) if match else None

frames = []
counts = {}
deduplication = {}
for edition, key in files.items():
    raw = (spark.read.option('header', 'true').option('encoding', 'UTF-8')
           .option('multiLine', 'true').option('quote', '"')
           .option('escape', '"').option('mode', 'FAILFAST')
           .csv(f's3://{BUCKET}/{key}'))
    headers = raw.columns
    if len(headers) != EXPECTED_COLUMNS[edition]:
        raise ValueError(f"Numero de colunas inesperado: {edition}: {len(headers)}")
    # Safe internal names avoid dots and quotes in the original CSV headers.
    df = raw.toDF(*[f'c{i}' for i in range(len(headers))])
    # Remove only exact copies within this edition, before trimming values
    # or adding technical fields. Repeated IDs with different answers survive.
    bronze_count = df.count()
    df = df.dropDuplicates()
    codes = {}
    for i, header in enumerate(headers):
        code = question_code(header)
        if code is None:
            raise ValueError(f"Cabecalho nao reconhecido: {edition}: {header}")
        if code in codes:
            raise ValueError(f'Duplicate question code: {edition} {code}')
        codes[code] = f'c{i}'
    fields = dict(common)
    fields['id_resposta'] = '0' if edition == '2023-2024' else '0.a'
    fields['modelo_atual'] = '2.q' if edition == '2025-2026' else '2.r'
    fields['modelo_ideal'] = '2.r' if edition == '2025-2026' else '2.s'
    missing = [code for code in fields.values() if code not in codes]
    if missing:
        raise ValueError(f'Missing required question codes: {edition}: {missing}')
    columns = []
    for name, code in fields.items():
        value = F.trim(F.col(codes[code]))
        columns.append(F.when(value == '', F.lit(None))
                       .otherwise(value).alias(name))
    # Keep every original question and answer, including fields outside this
    # initial analytical selection. JSON is a backup, not the final BI model.
    original = F.to_json(F.struct(*[
        F.col(f'c{i}').alias(header) for i, header in enumerate(headers)
    ]), options={'ignoreNullFields': 'false'})
    result = (df.select(*columns, original.alias('respostas_originais_json'))
              .withColumn('edicao', F.lit(edition))
              .withColumn('arquivo_origem', F.lit(f's3://{BUCKET}/{key}'))
              .withColumn('processado_em', F.current_timestamp())
              .withColumn('idade_numerica',
                  F.when(F.col('idade').rlike(r'^\d+$'),
                         F.col('idade').cast('int')))
              .withColumn('alerta_faixa_salarial',
                  F.coalesce(F.col('faixa_salarial').isin(
                      'de R$ 101/mês a R$ 2.000/mês',
                      'de R$ 25.001/mês a R$ 3000/mês'), F.lit(False)))
              .withColumn('motivo_alerta_salarial',
                  F.when(F.col('alerta_faixa_salarial'),
                      F.lit('Faixa suspeita; valor original preservado; excluir de indicadores salariais ate revisao'))))
    result = result.cache()
    counts[edition] = result.count()
    deduplication[edition] = {
        'bronze': bronze_count,
        'silver': counts[edition],
        'copias_exatas_removidas': bronze_count - counts[edition]
    }
    if result.filter(F.col('id_resposta').isNull() | (F.trim(F.col('id_resposta')) == '')).limit(1).count():
        raise ValueError(f'Identificador ausente em {edition}')
    if result.groupBy('id_resposta').count().filter('count > 1').limit(1).count():
        raise ValueError(f'ID repetido com respostas diferentes em {edition}; investigar antes de excluir')
    nulls = result.agg(*[F.sum(F.col(c).isNull().cast('long')).alias(c) for c in fields]).first().asDict()
    quality.append({'edicao': edition, **deduplication[edition],
        'colunas_originais': len(headers), 'nulos_por_campo': nulls,
        'alertas_salariais': result.filter('alerta_faixa_salarial').count(),
        'mapeamento_campos': {name: headers[int(codes[code][1:])] for name, code in fields.items()}})
    print('DEDUPLICATION ' + json.dumps({edition: deduplication[edition]}))
    print(f'VALIDATION {edition}: {counts[edition]} rows, {len(headers)} original columns')
    frames.append(result)

silver = reduce(lambda a, b: a.unionByName(b), frames)
total = silver.count()
if total != sum(counts.values()) or any(n == 0 for n in counts.values()):
    raise ValueError('Record count validation failed')

# Re-running replaces only this specific derived dataset, never Bronze.
(silver.repartition(3, 'edicao').write.mode('overwrite')
 .partitionBy('edicao').parquet(OUTPUT))

check = spark.read.parquet(OUTPUT).groupBy('edicao').count().collect()
written = {row['edicao']: row['count'] for row in check}
if written != counts:
    raise ValueError(f'Output validation failed: {written} != {counts}')
print('SUCCESS: ' + json.dumps({'counts': counts, 'total': total,
      'deduplication': deduplication, 'output': OUTPUT}))
boto3.client('s3').put_object(Bucket=BUCKET,
    Key=f'auditoria/bronze_silver/{RUN}/qualidade.json',
    Body=json.dumps({'execucao': RUN, 'qualidade': quality}, ensure_ascii=False, indent=2).encode('utf-8'),
    ContentType='application/json; charset=utf-8')
job.commit()
