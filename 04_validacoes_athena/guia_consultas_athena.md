# Guia de consultas SQL para validar o projeto no Athena

Grupo 18 | Referência dos outputs: 18/10/2026

## Como usar

1. Abra o editor do Athena na região us-east-1, catálogo AwsDataCatalog, banco tech_challenge_fase3 e workgroup primary. O local de resultados do workgroup deve estar configurado.
2. Execute os Jobs em sequência e aguarde Succeeded. Atualize o catálogo quando houver tabelas, colunas ou partições novas.
3. Copie e execute **uma consulta por vez**. O arquivo SQL contém os mesmos blocos numerados deste guia. Todos são SELECT: não alteram as tabelas, mas o Athena grava resultados no S3 e pode cobrar pela leitura.
4. Primeiro execute os controles 01 a 14. Depois confira os indicadores da apresentação. As consultas Silver exigem o esquema da última versão dos Jobs.
5. Zero linhas só é aprovação quando a seção indicar isso. Um erro de execução ou tabela ausente não é aprovação. Preserve evidências de data, consulta e resultado.

## Regras de leitura

- Todas as tabelas estão qualificadas com tech_challenge_fase3.
- Contagens de linhas Gold são agregados, não número de respondentes. A referência estática muda se a base for atualizada.
- Percentuais Gold estão em 0 a 100. Compare numerador e denominador; não some percentuais.
- Use todos OU setores exclusivos. Não some os dois recortes.
- Na remuneração, some contagens por faixa, nunca denominadores repetidos.
- IA: respostas insuficientes ou contraditórias ficam fora da base válida; base zero produz percentual nulo.
- Não tratar preferência de linguagem como uso, satisfação como retenção ou relatos de IA como impacto causal.
- O guia consulta tabelas agregadas e a Silver; não prova representatividade nem a correção dos rótulos da fonte.
- Consultas com diagnóstico por ID são para validação interna. Compartilhe preferencialmente os totais de controle, sem IDs individuais ou células pequenas.

## Limites da verificação feita na preparação

As consultas Gold foram executadas localmente contra os CSVs em um mecanismo SQL de apoio para conferir lógica e valores. Essa verificação não substitui execução no Athena. Consultas de catálogo e Silver foram revisadas com os scripts disponíveis, mas não executadas na AWS nesta entrega. Nenhuma credencial foi acessada.

Sintaxe de referência: [SELECT no Amazon Athena](https://docs.aws.amazon.com/athena/latest/ug/select.html). Os blocos foram escritos para Athena Engine 3; o mecanismo local não certifica compatibilidade de tipos no catálogo remoto.

## 01. Catálogo: verificar as dez tabelas

**Propósito:** Encontrar tabelas Silver ou Gold ainda não registradas; uma pasta no S3 não garante uma tabela no Athena.

**Esperado e interpretação:** Zero linhas. Se houver nome listado, revisar o Crawler ou o registro da tabela antes das próximas consultas.

```sql
WITH esperadas(nome) AS (VALUES ('perfil_profissionais'), ('perfil_enriquecido'), ('respostas_multiplas'), ('gold_perfil'), ('gold_remuneracao'), ('gold_modelo_trabalho'), ('gold_satisfacao'), ('gold_ia_empresas'), ('gold_multiplas_escolhas'), ('gold_adocao_ia'))
SELECT e.nome AS tabela_ausente
FROM esperadas e
LEFT JOIN information_schema.tables t
 ON t.table_schema = 'tech_challenge_fase3' AND t.table_name = e.nome
WHERE t.table_name IS NULL
ORDER BY e.nome;
```

## 02. Contagens Gold versus exportação

**Propósito:** Comparar as quantidades no Athena com o snapshot CSV auditado; não são quantidades de pessoas.

**Esperado e interpretação:** Sete linhas, todas com status OK. Referência estática de 18/10/2026; novas fontes ou mudanças legítimas exigem atualizar a referência.

```sql
WITH observado AS (SELECT 'gold_perfil' AS tabela, COUNT(*) AS observado FROM tech_challenge_fase3.gold_perfil
UNION ALL
SELECT 'gold_remuneracao' AS tabela, COUNT(*) AS observado FROM tech_challenge_fase3.gold_remuneracao
UNION ALL
SELECT 'gold_modelo_trabalho' AS tabela, COUNT(*) AS observado FROM tech_challenge_fase3.gold_modelo_trabalho
UNION ALL
SELECT 'gold_satisfacao' AS tabela, COUNT(*) AS observado FROM tech_challenge_fase3.gold_satisfacao
UNION ALL
SELECT 'gold_ia_empresas' AS tabela, COUNT(*) AS observado FROM tech_challenge_fase3.gold_ia_empresas
UNION ALL
SELECT 'gold_multiplas_escolhas' AS tabela, COUNT(*) AS observado FROM tech_challenge_fase3.gold_multiplas_escolhas
UNION ALL
SELECT 'gold_adocao_ia' AS tabela, COUNT(*) AS observado FROM tech_challenge_fase3.gold_adocao_ia), esperado(tabela, linhas) AS (VALUES ('gold_perfil',373),('gold_remuneracao',7693),('gold_modelo_trabalho',72),('gold_satisfacao',18),('gold_ia_empresas',60),('gold_multiplas_escolhas',702),('gold_adocao_ia',12))
SELECT o.tabela, o.observado, e.linhas AS esperado,
 CASE WHEN o.observado = e.linhas THEN 'OK' ELSE 'DIVERGENTE' END AS status
FROM observado o JOIN esperado e ON o.tabela = e.tabela
ORDER BY o.tabela;
```

## 03. População e IDs nas duas tabelas de perfil

**Propósito:** Verificar que o enriquecimento preservou a população e a unicidade por edição.

**Esperado e interpretação:** Seis linhas. Para cada tabela: 5293, 5215, 3494 nas respectivas edições; total = IDs distintos; chaves ausentes = 0.

```sql
SELECT 'perfil_profissionais' AS tabela, edicao, COUNT(*) AS total, COUNT(DISTINCT id_resposta) AS ids_distintos, SUM(CASE WHEN id_resposta IS NULL OR TRIM(id_resposta) = '' THEN 1 ELSE 0 END) AS chaves_ausentes FROM tech_challenge_fase3.perfil_profissionais GROUP BY edicao
UNION ALL
SELECT 'perfil_enriquecido' AS tabela, edicao, COUNT(*) AS total, COUNT(DISTINCT id_resposta) AS ids_distintos, SUM(CASE WHEN id_resposta IS NULL OR TRIM(id_resposta) = '' THEN 1 ELSE 0 END) AS chaves_ausentes FROM tech_challenge_fase3.perfil_enriquecido GROUP BY edicao
ORDER BY edicao, tabela;
```

## 04. IDs de perfil repetidos ou vazios

**Propósito:** Localizar registros responsáveis por falhas de unicidade; considerar edição como parte da chave.

**Esperado e interpretação:** Zero linhas. Isso valida a Silver atual; não reconstitui a deduplicação dos CSVs originais.

```sql
SELECT 'perfil_profissionais' AS tabela, edicao, id_resposta, COUNT(*) AS quantidade FROM tech_challenge_fase3.perfil_profissionais GROUP BY edicao, id_resposta HAVING COUNT(*) > 1 OR edicao IS NULL OR TRIM(edicao) = '' OR id_resposta IS NULL OR TRIM(id_resposta) = ''
UNION ALL
SELECT 'perfil_enriquecido' AS tabela, edicao, id_resposta, COUNT(*) AS quantidade FROM tech_challenge_fase3.perfil_enriquecido GROUP BY edicao, id_resposta HAVING COUNT(*) > 1 OR edicao IS NULL OR TRIM(edicao) = '' OR id_resposta IS NULL OR TRIM(id_resposta) = '';
```

## 05. Chave de múltiplas escolhas na Silver

**Propósito:** Não confundir opções diferentes do mesmo respondente com duplicatas.

**Esperado e interpretação:** Zero linhas.

```sql
SELECT edicao, id_resposta, tema, codigo_pergunta, COUNT(*) AS quantidade
FROM tech_challenge_fase3.respostas_multiplas
GROUP BY edicao, id_resposta, tema, codigo_pergunta
HAVING COUNT(*) > 1
 OR edicao IS NULL OR TRIM(edicao) = ''
 OR id_resposta IS NULL OR TRIM(id_resposta) = ''
 OR tema IS NULL OR TRIM(tema) = ''
 OR codigo_pergunta IS NULL OR TRIM(codigo_pergunta) = '';
```

## 06. Valores binários na Silver

**Propósito:** Detectar opções fora de 0/1; aceitar tipos booleanos ou numéricos catalogados.

**Esperado e interpretação:** Zero linhas.

```sql
SELECT edicao, CAST(selecionado AS VARCHAR) AS valor, COUNT(*) AS quantidade
FROM tech_challenge_fase3.respostas_multiplas
WHERE selecionado IS NULL
 OR LOWER(TRIM(CAST(selecionado AS VARCHAR))) NOT IN ('0','1','false','true')
GROUP BY edicao, CAST(selecionado AS VARCHAR);
```

## 07. Chaves Gold: duplicatas e campos ausentes

**Propósito:** Verificar as dimensões reais de cada agregado.

**Esperado e interpretação:** Sete linhas com grupos_invalidos = 0. Se positivo, inspecionar a tabela indicada.

```sql
SELECT 'gold_perfil' AS tabela, COUNT(*) AS grupos_invalidos FROM (SELECT edicao, segmento, dimensao, categoria FROM tech_challenge_fase3.gold_perfil GROUP BY edicao, segmento, dimensao, categoria HAVING COUNT(*) > 1 OR edicao IS NULL OR TRIM(CAST(edicao AS VARCHAR)) = '' OR segmento IS NULL OR TRIM(CAST(segmento AS VARCHAR)) = '' OR dimensao IS NULL OR TRIM(CAST(dimensao AS VARCHAR)) = '' OR categoria IS NULL OR TRIM(CAST(categoria AS VARCHAR)) = '') q
UNION ALL
SELECT 'gold_remuneracao' AS tabela, COUNT(*) AS grupos_invalidos FROM (SELECT edicao, segmento, cargo, senioridade, regiao, genero, faixa_salarial FROM tech_challenge_fase3.gold_remuneracao GROUP BY edicao, segmento, cargo, senioridade, regiao, genero, faixa_salarial HAVING COUNT(*) > 1 OR edicao IS NULL OR TRIM(CAST(edicao AS VARCHAR)) = '' OR segmento IS NULL OR TRIM(CAST(segmento AS VARCHAR)) = '' OR cargo IS NULL OR TRIM(CAST(cargo AS VARCHAR)) = '' OR senioridade IS NULL OR TRIM(CAST(senioridade AS VARCHAR)) = '' OR regiao IS NULL OR TRIM(CAST(regiao AS VARCHAR)) = '' OR genero IS NULL OR TRIM(CAST(genero AS VARCHAR)) = '' OR faixa_salarial IS NULL OR TRIM(CAST(faixa_salarial AS VARCHAR)) = '') q
UNION ALL
SELECT 'gold_modelo_trabalho' AS tabela, COUNT(*) AS grupos_invalidos FROM (SELECT edicao, segmento, tipo_modelo, modelo FROM tech_challenge_fase3.gold_modelo_trabalho GROUP BY edicao, segmento, tipo_modelo, modelo HAVING COUNT(*) > 1 OR edicao IS NULL OR TRIM(CAST(edicao AS VARCHAR)) = '' OR segmento IS NULL OR TRIM(CAST(segmento AS VARCHAR)) = '' OR tipo_modelo IS NULL OR TRIM(CAST(tipo_modelo AS VARCHAR)) = '' OR modelo IS NULL OR TRIM(CAST(modelo AS VARCHAR)) = '') q
UNION ALL
SELECT 'gold_satisfacao' AS tabela, COUNT(*) AS grupos_invalidos FROM (SELECT edicao, segmento, modelo_diferente_ideal FROM tech_challenge_fase3.gold_satisfacao GROUP BY edicao, segmento, modelo_diferente_ideal HAVING COUNT(*) > 1 OR edicao IS NULL OR TRIM(CAST(edicao AS VARCHAR)) = '' OR segmento IS NULL OR TRIM(CAST(segmento AS VARCHAR)) = '' OR modelo_diferente_ideal IS NULL OR TRIM(CAST(modelo_diferente_ideal AS VARCHAR)) = '') q
UNION ALL
SELECT 'gold_ia_empresas' AS tabela, COUNT(*) AS grupos_invalidos FROM (SELECT edicao, segmento, indicador, resposta FROM tech_challenge_fase3.gold_ia_empresas GROUP BY edicao, segmento, indicador, resposta HAVING COUNT(*) > 1 OR edicao IS NULL OR TRIM(CAST(edicao AS VARCHAR)) = '' OR segmento IS NULL OR TRIM(CAST(segmento AS VARCHAR)) = '' OR indicador IS NULL OR TRIM(CAST(indicador AS VARCHAR)) = '' OR resposta IS NULL OR TRIM(CAST(resposta AS VARCHAR)) = '') q
UNION ALL
SELECT 'gold_multiplas_escolhas' AS tabela, COUNT(*) AS grupos_invalidos FROM (SELECT edicao, segmento, tema, codigo_pergunta, opcao FROM tech_challenge_fase3.gold_multiplas_escolhas GROUP BY edicao, segmento, tema, codigo_pergunta, opcao HAVING COUNT(*) > 1 OR edicao IS NULL OR TRIM(CAST(edicao AS VARCHAR)) = '' OR segmento IS NULL OR TRIM(CAST(segmento AS VARCHAR)) = '' OR tema IS NULL OR TRIM(CAST(tema AS VARCHAR)) = '' OR codigo_pergunta IS NULL OR TRIM(CAST(codigo_pergunta AS VARCHAR)) = '' OR opcao IS NULL OR TRIM(CAST(opcao AS VARCHAR)) = '') q
UNION ALL
SELECT 'gold_adocao_ia' AS tabela, COUNT(*) AS grupos_invalidos FROM (SELECT edicao, segmento FROM tech_challenge_fase3.gold_adocao_ia GROUP BY edicao, segmento HAVING COUNT(*) > 1 OR edicao IS NULL OR TRIM(CAST(edicao AS VARCHAR)) = '' OR segmento IS NULL OR TRIM(CAST(segmento AS VARCHAR)) = '') q;
```

## 08. Qualidade e recálculo de todos os percentuais

**Propósito:** Examinar as sete tabelas conjuntamente, incluindo o tratamento de base zero de IA.

**Esperado e interpretação:** Zero linhas. Tolerância de 0,00501 ponto percentual para arredondamento a duas casas; base zero só é permitida na adoção IA e deve ter percentual nulo.

```sql
WITH metricas AS (SELECT 'gold_perfil' AS tabela, edicao, segmento, numerador, denominador, percentual FROM tech_challenge_fase3.gold_perfil
UNION ALL
SELECT 'gold_remuneracao' AS tabela, edicao, segmento, numerador, denominador, percentual FROM tech_challenge_fase3.gold_remuneracao
UNION ALL
SELECT 'gold_modelo_trabalho' AS tabela, edicao, segmento, numerador, denominador, percentual FROM tech_challenge_fase3.gold_modelo_trabalho
UNION ALL
SELECT 'gold_satisfacao' AS tabela, edicao, segmento, numerador, denominador, percentual FROM tech_challenge_fase3.gold_satisfacao
UNION ALL
SELECT 'gold_ia_empresas' AS tabela, edicao, segmento, numerador, denominador, percentual FROM tech_challenge_fase3.gold_ia_empresas
UNION ALL
SELECT 'gold_multiplas_escolhas' AS tabela, edicao, segmento, numerador, denominador, percentual FROM tech_challenge_fase3.gold_multiplas_escolhas
UNION ALL
SELECT 'gold_adocao_ia' AS tabela, edicao, segmento, numerador, denominador, percentual FROM tech_challenge_fase3.gold_adocao_ia)
SELECT tabela, edicao, segmento, numerador, denominador, percentual,
 ROUND(100.0 * numerador / NULLIF(denominador,0), 2) AS recalculado
FROM metricas
WHERE numerador IS NULL OR denominador IS NULL
 OR numerador < 0 OR denominador < 0 OR numerador > denominador
 OR (denominador = 0 AND (tabela <> 'gold_adocao_ia' OR percentual IS NOT NULL))
 OR (denominador > 0 AND (percentual IS NULL OR percentual < 0 OR percentual > 100
     OR ABS(percentual - 100.0 * numerador / NULLIF(denominador,0)) > 0.00501));
```

## 09. Fechamento das distribuições

**Propósito:** Conferir soma das categorias/faixas e constância das bases no grão correto.

**Esperado e interpretação:** Quatro linhas, grupos_com_erro = 0. Não aplicar esse teste a múltiplas escolhas, satisfeitos ou usuários de IA: seus numeradores não precisam fechar 100%.

```sql
SELECT 'gold_perfil' AS tabela, COUNT(*) AS grupos_com_erro FROM (SELECT edicao, segmento, dimensao FROM tech_challenge_fase3.gold_perfil GROUP BY edicao, segmento, dimensao HAVING SUM(numerador) <> MIN(denominador) OR MIN(denominador) <> MAX(denominador)) q
UNION ALL
SELECT 'gold_modelo_trabalho' AS tabela, COUNT(*) AS grupos_com_erro FROM (SELECT edicao, segmento, tipo_modelo FROM tech_challenge_fase3.gold_modelo_trabalho GROUP BY edicao, segmento, tipo_modelo HAVING SUM(numerador) <> MIN(denominador) OR MIN(denominador) <> MAX(denominador)) q
UNION ALL
SELECT 'gold_ia_empresas' AS tabela, COUNT(*) AS grupos_com_erro FROM (SELECT edicao, segmento, indicador FROM tech_challenge_fase3.gold_ia_empresas GROUP BY edicao, segmento, indicador HAVING SUM(numerador) <> MIN(denominador) OR MIN(denominador) <> MAX(denominador)) q
UNION ALL
SELECT 'gold_remuneracao' AS tabela, COUNT(*) AS grupos_com_erro FROM (SELECT edicao, segmento, cargo, senioridade, regiao, genero FROM tech_challenge_fase3.gold_remuneracao GROUP BY edicao, segmento, cargo, senioridade, regiao, genero HAVING SUM(numerador) <> MIN(denominador) OR MIN(denominador) <> MAX(denominador)) q;
```

## 10. Reconciliação de todos com os setores

**Propósito:** Detectar contagens que não reconciliam entre recorte geral e segmentos exclusivos.

**Esperado e interpretação:** Sete linhas com grupos_com_erro = 0. Não somar todos aos demais segmentos. Este controle compara numeradores, não soma bases repetidas.

```sql
SELECT 'gold_perfil' AS tabela, COUNT(*) AS grupos_com_erro FROM (SELECT edicao, dimensao, categoria FROM tech_challenge_fase3.gold_perfil GROUP BY edicao, dimensao, categoria HAVING SUM(CASE WHEN segmento = 'todos' THEN numerador ELSE 0 END) <> SUM(CASE WHEN segmento <> 'todos' THEN numerador ELSE 0 END) OR SUM(CASE WHEN segmento = 'todos' THEN 1 ELSE 0 END) <> 1) q
UNION ALL
SELECT 'gold_remuneracao' AS tabela, COUNT(*) AS grupos_com_erro FROM (SELECT edicao, cargo, senioridade, regiao, genero, faixa_salarial FROM tech_challenge_fase3.gold_remuneracao GROUP BY edicao, cargo, senioridade, regiao, genero, faixa_salarial HAVING SUM(CASE WHEN segmento = 'todos' THEN numerador ELSE 0 END) <> SUM(CASE WHEN segmento <> 'todos' THEN numerador ELSE 0 END) OR SUM(CASE WHEN segmento = 'todos' THEN 1 ELSE 0 END) <> 1) q
UNION ALL
SELECT 'gold_modelo_trabalho' AS tabela, COUNT(*) AS grupos_com_erro FROM (SELECT edicao, tipo_modelo, modelo FROM tech_challenge_fase3.gold_modelo_trabalho GROUP BY edicao, tipo_modelo, modelo HAVING SUM(CASE WHEN segmento = 'todos' THEN numerador ELSE 0 END) <> SUM(CASE WHEN segmento <> 'todos' THEN numerador ELSE 0 END) OR SUM(CASE WHEN segmento = 'todos' THEN 1 ELSE 0 END) <> 1) q
UNION ALL
SELECT 'gold_satisfacao' AS tabela, COUNT(*) AS grupos_com_erro FROM (SELECT edicao, modelo_diferente_ideal FROM tech_challenge_fase3.gold_satisfacao GROUP BY edicao, modelo_diferente_ideal HAVING SUM(CASE WHEN segmento = 'todos' THEN numerador ELSE 0 END) <> SUM(CASE WHEN segmento <> 'todos' THEN numerador ELSE 0 END) OR SUM(CASE WHEN segmento = 'todos' THEN 1 ELSE 0 END) <> 1) q
UNION ALL
SELECT 'gold_ia_empresas' AS tabela, COUNT(*) AS grupos_com_erro FROM (SELECT edicao, indicador, resposta FROM tech_challenge_fase3.gold_ia_empresas GROUP BY edicao, indicador, resposta HAVING SUM(CASE WHEN segmento = 'todos' THEN numerador ELSE 0 END) <> SUM(CASE WHEN segmento <> 'todos' THEN numerador ELSE 0 END) OR SUM(CASE WHEN segmento = 'todos' THEN 1 ELSE 0 END) <> 1) q
UNION ALL
SELECT 'gold_multiplas_escolhas' AS tabela, COUNT(*) AS grupos_com_erro FROM (SELECT edicao, tema, codigo_pergunta, opcao FROM tech_challenge_fase3.gold_multiplas_escolhas GROUP BY edicao, tema, codigo_pergunta, opcao HAVING SUM(CASE WHEN segmento = 'todos' THEN numerador ELSE 0 END) <> SUM(CASE WHEN segmento <> 'todos' THEN numerador ELSE 0 END) OR SUM(CASE WHEN segmento = 'todos' THEN 1 ELSE 0 END) <> 1) q
UNION ALL
SELECT 'gold_adocao_ia' AS tabela, COUNT(*) AS grupos_com_erro FROM (SELECT edicao FROM tech_challenge_fase3.gold_adocao_ia GROUP BY edicao HAVING SUM(CASE WHEN segmento = 'todos' THEN numerador ELSE 0 END) <> SUM(CASE WHEN segmento <> 'todos' THEN numerador ELSE 0 END) OR SUM(CASE WHEN segmento = 'todos' THEN 1 ELSE 0 END) <> 1) q;
```

## 11. Reconciliação da população de IA

**Propósito:** Verificar campos auxiliares, exclusões e não usuários.

**Esperado e interpretação:** Zero linhas.

```sql
SELECT * FROM tech_challenge_fase3.gold_adocao_ia
WHERE total_respondentes IS NULL OR nao_usuarios IS NULL
 OR respostas_contraditorias IS NULL OR respostas_insuficientes_ou_ausentes IS NULL
 OR total_respondentes < 0 OR nao_usuarios < 0
 OR respostas_contraditorias < 0 OR respostas_insuficientes_ou_ausentes < 0
 OR denominador <> numerador + nao_usuarios
 OR total_respondentes <> denominador + respostas_contraditorias
                           + respostas_insuficientes_ou_ausentes;
```

## 12. Adoção IA: taxa válida e cobertura

**Propósito:** Distinguir adoção entre respostas classificáveis da participação de usuários identificados no total.

**Esperado e interpretação:** 2025-2026: usuários 2061; válidos 2100; total 3494; taxa válida 98,14%; cobertura 60,10%; usuários identificados/total 58,99%. Não classificar ausentes como não usuários.

```sql
SELECT edicao, total_respondentes, numerador AS usuarios_identificados,
 denominador AS respostas_validas, nao_usuarios,
 respostas_contraditorias, respostas_insuficientes_ou_ausentes,
 percentual AS adocao_entre_validos,
 ROUND(100.0 * denominador / NULLIF(total_respondentes,0),2) AS cobertura_valida_pct,
 ROUND(100.0 * numerador / NULLIF(total_respondentes,0),2) AS usuarios_identificados_total_pct
FROM tech_challenge_fase3.gold_adocao_ia
WHERE segmento = 'todos' ORDER BY edicao;
```

## 13. Contraprova de adoção IA a partir da Silver

**Propósito:** Recalcular usuários e base válida para todos, sem depender das contagens da Gold.

**Esperado e interpretação:** Zero linhas. A consulta pressupõe usa_ia_generativa como BOOLEAN, conforme a última versão do Job; tipo diferente no catálogo precisa ser revisto.

```sql
WITH s AS (
 SELECT edicao, COUNT(*) AS total,
  SUM(CASE WHEN usa_ia_generativa = TRUE THEN 1 ELSE 0 END) AS usuarios,
  COUNT(usa_ia_generativa) AS validos
 FROM tech_challenge_fase3.perfil_enriquecido GROUP BY edicao
), g AS (SELECT * FROM tech_challenge_fase3.gold_adocao_ia WHERE segmento = 'todos')
SELECT COALESCE(s.edicao,g.edicao) AS edicao, s.total, g.total_respondentes,
 s.usuarios, g.numerador, s.validos, g.denominador
FROM s FULL OUTER JOIN g ON s.edicao = g.edicao
WHERE s.edicao IS NULL OR g.edicao IS NULL
 OR s.total <> g.total_respondentes OR s.usuarios <> g.numerador
 OR s.validos <> g.denominador;
```

## 14. Contraprova da Gold de múltiplas escolhas

**Propósito:** Reconstruir todas as opções no recorte todos com valores 0/1 da Silver e comparar as duas direções.

**Esperado e interpretação:** Zero linhas. Ausência de coluna/tabela indica catálogo desatualizado; não equivale a teste aprovado.

```sql
WITH s AS (
 SELECT edicao, tema, codigo_pergunta, opcao,
  SUM(CASE WHEN LOWER(CAST(selecionado AS VARCHAR)) IN ('1','true') THEN 1 ELSE 0 END) AS numerador,
  COUNT(*) AS denominador
 FROM tech_challenge_fase3.respostas_multiplas
 WHERE LOWER(CAST(selecionado AS VARCHAR)) IN ('0','1','false','true')
 GROUP BY edicao, tema, codigo_pergunta, opcao
), g AS (
 SELECT edicao, tema, codigo_pergunta, opcao, numerador, denominador
 FROM tech_challenge_fase3.gold_multiplas_escolhas WHERE segmento = 'todos'
), faltas_gold AS (SELECT * FROM s EXCEPT SELECT * FROM g),
 faltas_silver AS (SELECT * FROM g EXCEPT SELECT * FROM s)
SELECT 'silver_difere_da_gold' AS divergencia, * FROM faltas_gold
UNION ALL
SELECT 'gold_difere_da_silver' AS divergencia, * FROM faltas_silver;
```

## 15. Perfil: cargos, senioridade, região e gênero

**Propósito:** Reproduzir indicadores do slide 5 sem misturar bases de dimensões distintas.

**Esperado e interpretação:** Em 2025-2026: cargo Analista 23,96%; Cientista 16,92%; Engenheiro 16,08%; base cargo 2500. Sudeste 64,41%, base 3369. Gênero usa 3494.

```sql
SELECT dimensao, categoria, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_perfil
WHERE segmento = 'todos' AND edicao = '2025-2026'
 AND dimensao IN ('cargo','senioridade','regiao','genero')
ORDER BY dimensao, numerador DESC, categoria;
```

## 16. Diversidade de gênero nas três edições

**Propósito:** Conferir a série de participação feminina e preservar demais categorias.

**Esperado e interpretação:** Feminino em todos: 24,43%; 23,49%; 21,95%, em ordem cronológica. Variações descrevem amostras, não prova de evolução populacional.

```sql
SELECT edicao, segmento, categoria AS genero, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_perfil WHERE dimensao = 'genero'
ORDER BY edicao, segmento, categoria;
```

## 17. Remuneração por nível e segmento

**Propósito:** Reproduzir a proporção em faixas de R$ 12.001+; usar contagens, nunca média simples de percentuais.

**Esperado e interpretação:** Sênior: todos 52,10%; Finanças/Bancos 61,14%; demais 49,47%. Pleno em todos 11,10%. R$ 12.001+ é o limiar das faixas, não salário exato.

```sql
SELECT segmento, senioridade, SUM(numerador) AS base_salarial,
 SUM(CASE WHEN faixa_salarial IN ('de R$ 12.001/mês a R$ 16.000/mês', 'de R$ 16.001/mês a R$ 20.000/mês', 'de R$ 20.001/mês a R$ 25.000/mês', 'de R$ 25.001/mês a R$ 30.000/mês', 'de R$ 30.001/mês a R$ 40.000/mês', 'Acima de R$ 40.001/mês') THEN numerador ELSE 0 END) AS pessoas_acima_12mil,
 ROUND(100.0 * SUM(CASE WHEN faixa_salarial IN ('de R$ 12.001/mês a R$ 16.000/mês', 'de R$ 16.001/mês a R$ 20.000/mês', 'de R$ 20.001/mês a R$ 25.000/mês', 'de R$ 25.001/mês a R$ 30.000/mês', 'de R$ 30.001/mês a R$ 40.000/mês', 'Acima de R$ 40.001/mês') THEN numerador ELSE 0 END)
       / NULLIF(SUM(numerador),0),2) AS percentual_acima_12mil
FROM tech_challenge_fase3.gold_remuneracao WHERE edicao = '2025-2026' AND senioridade <> 'Nao informado'
GROUP BY segmento, senioridade ORDER BY segmento, senioridade;
```

## 18. Remuneração por cargo

**Propósito:** Conferir ranking com uma base mínima explícita e exclusão da categoria genérica.

**Esperado e interpretação:** ML/IA 64,15% (106); Analytics Engineer 51,85% (135); Engenheiro Dados 49,75% (402). Isso mede remuneração, não demanda por vagas.

```sql
SELECT cargo, SUM(numerador) AS base_salarial,
 SUM(CASE WHEN faixa_salarial IN ('de R$ 12.001/mês a R$ 16.000/mês', 'de R$ 16.001/mês a R$ 20.000/mês', 'de R$ 20.001/mês a R$ 25.000/mês', 'de R$ 25.001/mês a R$ 30.000/mês', 'de R$ 30.001/mês a R$ 40.000/mês', 'Acima de R$ 40.001/mês') THEN numerador ELSE 0 END) AS pessoas_acima_12mil,
 ROUND(100.0 * SUM(CASE WHEN faixa_salarial IN ('de R$ 12.001/mês a R$ 16.000/mês', 'de R$ 16.001/mês a R$ 20.000/mês', 'de R$ 20.001/mês a R$ 25.000/mês', 'de R$ 25.001/mês a R$ 30.000/mês', 'de R$ 30.001/mês a R$ 40.000/mês', 'Acima de R$ 40.001/mês') THEN numerador ELSE 0 END)
       / NULLIF(SUM(numerador),0),2) AS percentual_acima_12mil
FROM tech_challenge_fase3.gold_remuneracao WHERE edicao = '2025-2026' AND segmento = 'todos' AND cargo NOT IN ('Nao informado','Outra Opção')
GROUP BY cargo HAVING SUM(numerador) >= 50
ORDER BY percentual_acima_12mil DESC;
```

## 19. Regiões: geral versus Sênior

**Propósito:** Evitar dizer que a diferença regional desaparece: comparar o sinal e a composição.

**Esperado e interpretação:** Sudeste geral 44,64% e Sênior 49,05% (526); Nordeste geral 31,61% e Sênior 55,81% (86). Descritivo, sem teste de equivalência.

```sql
SELECT 'geral' AS recorte, regiao, SUM(numerador) AS base_salarial,
 SUM(CASE WHEN faixa_salarial IN ('de R$ 12.001/mês a R$ 16.000/mês', 'de R$ 16.001/mês a R$ 20.000/mês', 'de R$ 20.001/mês a R$ 25.000/mês', 'de R$ 25.001/mês a R$ 30.000/mês', 'de R$ 30.001/mês a R$ 40.000/mês', 'Acima de R$ 40.001/mês') THEN numerador ELSE 0 END) AS pessoas_acima_12mil,
 ROUND(100.0 * SUM(CASE WHEN faixa_salarial IN ('de R$ 12.001/mês a R$ 16.000/mês', 'de R$ 16.001/mês a R$ 20.000/mês', 'de R$ 20.001/mês a R$ 25.000/mês', 'de R$ 25.001/mês a R$ 30.000/mês', 'de R$ 30.001/mês a R$ 40.000/mês', 'Acima de R$ 40.001/mês') THEN numerador ELSE 0 END)
       / NULLIF(SUM(numerador),0),2) AS percentual_acima_12mil
FROM tech_challenge_fase3.gold_remuneracao WHERE edicao = '2025-2026' AND segmento = 'todos' AND regiao IN ('Sudeste','Nordeste')
GROUP BY regiao
UNION ALL
SELECT 'senior' AS recorte, regiao, SUM(numerador) AS base_salarial,
 SUM(CASE WHEN faixa_salarial IN ('de R$ 12.001/mês a R$ 16.000/mês', 'de R$ 16.001/mês a R$ 20.000/mês', 'de R$ 20.001/mês a R$ 25.000/mês', 'de R$ 25.001/mês a R$ 30.000/mês', 'de R$ 30.001/mês a R$ 40.000/mês', 'Acima de R$ 40.001/mês') THEN numerador ELSE 0 END) AS pessoas_acima_12mil,
 ROUND(100.0 * SUM(CASE WHEN faixa_salarial IN ('de R$ 12.001/mês a R$ 16.000/mês', 'de R$ 16.001/mês a R$ 20.000/mês', 'de R$ 20.001/mês a R$ 25.000/mês', 'de R$ 25.001/mês a R$ 30.000/mês', 'de R$ 30.001/mês a R$ 40.000/mês', 'Acima de R$ 40.001/mês') THEN numerador ELSE 0 END)
       / NULLIF(SUM(numerador),0),2) AS percentual_acima_12mil
FROM tech_challenge_fase3.gold_remuneracao WHERE edicao = '2025-2026' AND segmento = 'todos' AND senioridade = 'Sênior' AND regiao IN ('Sudeste','Nordeste')
GROUP BY regiao
ORDER BY recorte, regiao;
```

## 20. Gênero entre seniores: distribuição salarial

**Propósito:** Reproduzir a diferença bruta por gênero nos três anos, com bases visíveis.

**Esperado e interpretação:** 2025-2026: mulheres 42,13% (178), homens 54,96% (675). Não isola cargo, região ou setor.

```sql
SELECT edicao, genero, SUM(numerador) AS base_salarial,
 SUM(CASE WHEN faixa_salarial IN ('de R$ 12.001/mês a R$ 16.000/mês', 'de R$ 16.001/mês a R$ 20.000/mês', 'de R$ 20.001/mês a R$ 25.000/mês', 'de R$ 25.001/mês a R$ 30.000/mês', 'de R$ 30.001/mês a R$ 40.000/mês', 'Acima de R$ 40.001/mês') THEN numerador ELSE 0 END) AS pessoas_acima_12mil,
 ROUND(100.0 * SUM(CASE WHEN faixa_salarial IN ('de R$ 12.001/mês a R$ 16.000/mês', 'de R$ 16.001/mês a R$ 20.000/mês', 'de R$ 20.001/mês a R$ 25.000/mês', 'de R$ 25.001/mês a R$ 30.000/mês', 'de R$ 30.001/mês a R$ 40.000/mês', 'Acima de R$ 40.001/mês') THEN numerador ELSE 0 END)
       / NULLIF(SUM(numerador),0),2) AS percentual_acima_12mil
FROM tech_challenge_fase3.gold_remuneracao WHERE segmento = 'todos' AND senioridade = 'Sênior' AND genero IN ('Feminino','Masculino')
GROUP BY edicao, genero ORDER BY edicao, genero;
```

## 21. Modelos atual e ideal

**Propósito:** Conferir as duas distribuições sem atribuí-las especificamente aos seniores.

**Esperado e interpretação:** 2025-2026: híbrido flexível atual 19,55%, ideal 42,98%; base 3227. São distribuições marginais, não transições individuais.

```sql
SELECT tipo_modelo, modelo, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_modelo_trabalho
WHERE edicao = '2025-2026' AND segmento = 'todos'
ORDER BY modelo, tipo_modelo;
```

## 22. Satisfação e alinhamento ao modelo ideal

**Propósito:** Conferir os dois quocientes e suas bases antes de usá-los no slide.

**Esperado e interpretação:** 2025-2026: alinhado 1198/1581 = 75,77%; diferente 1028/1646 = 62,45%. O significado do numerador precisa estar documentado no script/questionário; associação não prova retenção ou causalidade.

```sql
SELECT edicao, modelo_diferente_ideal, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_satisfacao WHERE segmento = 'todos'
ORDER BY edicao, modelo_diferente_ideal;
```

## 23. Tecnologias: separar uso e preferência

**Propósito:** Reproduzir Python, SQL, cloud e BI com seus temas e bases, sem misturar perguntas.

**Esperado e interpretação:** Em 2025-2026: Python preferência 92,03%; SQL preferência 84,15%; AWS uso 48,26%; Power BI uso 59,00%. Linguagem_uso nas edições anteriores não equivale a linguagem_preferencia.

```sql
SELECT edicao, tema, codigo_pergunta, opcao, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_multiplas_escolhas
WHERE segmento = 'todos'
 AND tema IN ('linguagem_uso','linguagem_preferencia','cloud_uso','bi_uso')
ORDER BY tema, edicao, numerador DESC;
```

## 24. Rótulos cloud após o ajuste de 2023-2024

**Propósito:** Conferir código, rótulo, contagem e percentual após reprocessamento.

**Esperado e interpretação:** 2023-2024, todos: 4.h.1 AWS 42,32%; 4.h.2 GCP 30,61%; 4.h.3 Azure 31,58%; base 3613. Verifica o mapeamento adotado pelo grupo, não comprova uma errata oficial.

```sql
SELECT edicao, segmento, codigo_pergunta, opcao, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_multiplas_escolhas
WHERE tema = 'cloud_uso' AND segmento IN ('todos','financas_bancos')
 AND opcao IN ('Amazon Web Services (AWS)','Google Cloud (GCP)','Azure (Microsoft)')
ORDER BY segmento, edicao, codigo_pergunta;
```

## 25. Atratividade, barreiras e ferramentas de IA

**Propósito:** Consultar as opções com seus rótulos originais e evitar reduzir expertise ou recursos apenas a falta de pessoas.

**Esperado e interpretação:** Critérios: remuneração 83,20%, flexibilidade 56,59%, carreira 32,35%. Barreiras: expertise/recursos 38,84%, dados 36,80%, casos de uso 32,03%. IA paga pela empresa: Finanças/Bancos 56,44% (427); demais 38,74% (1678). Opções podem se sobrepor.

```sql
SELECT edicao, segmento, tema, codigo_pergunta, opcao, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_multiplas_escolhas
WHERE edicao = '2025-2026'
 AND tema IN ('criterios_emprego','barreiras_ia','ia_produtividade')
ORDER BY tema, segmento, numerador DESC;
```

## 26. Resultados e prioridade empresarial de IA

**Propósito:** Conferir os estágios e separar respostas de profissionais de empresas únicas.

**Esperado e interpretação:** Produção com resultado: 36,08% em Finanças/Bancos (97) e 24,77% nos demais (549). Pilotos: 43,30% e 37,52%; é a categoria mais citada, não maioria absoluta. Prioridade e resultado têm bases diferentes.

```sql
SELECT edicao, segmento, indicador, resposta, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_ia_empresas
WHERE edicao = '2025-2026'
ORDER BY indicador, segmento, numerador DESC;
```

## 27. Células salariais pequenas

**Propósito:** Identificar recortes que não devem fundamentar rankings detalhados ou exposição desnecessária.

**Esperado e interpretação:** 2025-2026, todos: 380 células; 238 com base menor que 5. Base por célula vem de um único denominador, sem repeti-lo por faixa.

```sql
WITH celulas AS (
 SELECT edicao, cargo, senioridade, regiao, genero, MAX(denominador) AS base
 FROM tech_challenge_fase3.gold_remuneracao WHERE segmento = 'todos'
 GROUP BY edicao, cargo, senioridade, regiao, genero
)
SELECT edicao, COUNT(*) AS celulas,
 SUM(CASE WHEN base < 5 THEN 1 ELSE 0 END) AS celulas_menos_5,
 SUM(CASE WHEN base < 10 THEN 1 ELSE 0 END) AS celulas_menos_10
FROM celulas GROUP BY edicao ORDER BY edicao;
```

## 28. Faixas salariais sinalizadas na Silver

**Propósito:** Rastrear exclusões conservadoras sem inventar correção do valor da fonte.

**Esperado e interpretação:** Conferir os textos preservados e suas contagens; há dois tipos de faixa suspeita nas regras do projeto. A quantidade de regras não equivale à quantidade de pessoas.

```sql
SELECT edicao, faixa_salarial, COUNT(*) AS quantidade
FROM tech_challenge_fase3.perfil_profissionais WHERE alerta_faixa_salarial = TRUE
GROUP BY edicao, faixa_salarial ORDER BY edicao, faixa_salarial;
```

