# Tech Challenge Fase 3 — Dados e IA

Projeto do Grupo 18 da pós-graduação em Data Analytics da FIAP. A solução organiza e processa três edições da pesquisa **State of Data Brasil**, da comunidade Data Hackers em parceria com a Bain, para apoiar uma instituição financeira em decisões de contratação, capacitação e investimentos em Dados e Inteligência Artificial.

O repositório reúne os scripts utilizados nos Jobs do AWS Glue, consultas de validação e análise no Athena e a apresentação executiva.

## Objetivos da análise

- Descrever o perfil dos participantes por cargo, senioridade, gênero e região.
- Comparar faixas salariais e modelos de trabalho.
- Identificar tecnologias utilizadas e linguagens preferidas, respeitando as diferenças entre perguntas.
- Examinar adoção de IA, resultados declarados e barreiras à implementação.
- Formular recomendações para o contexto de uma instituição financeira.

As pesquisas são retratos de amostras de respondentes, não um acompanhamento das mesmas pessoas ao longo do tempo. Os resultados não devem ser automaticamente generalizados para toda a população brasileira.

## Bases utilizadas

Origem: [datasets do Data Hackers no Kaggle](https://www.kaggle.com/datahackers/datasets).

| Edição | Registros originais | Registros após remoção de cópias exatas |
|---|---:|---:|
| 2023-2024 | 5.293 | 5.293 |
| 2024-2025 | 5.217 | 5.215 |
| 2025-2026 | 3.495 | 3.494 |
| **Total** | **14.005** | **14.002** |

Essas contagens são referências da versão utilizada no projeto. O denominador de cada indicador pode ser menor, conforme a disponibilidade de respostas válidas. Não representam pessoas únicas entre edições.

## Arquitetura

```text
CSVs da pesquisa
    ↓ upload manual
Amazon S3 — Bronze (originais CSV)
    ↓ Glue Job 01 — tratamento e deduplicação com PySpark
Amazon S3 — Silver / perfil_profissionais (Parquet)
    ↓ Glue Job 02 — enriquecimento e respostas múltiplas
Amazon S3 — Silver / perfil_enriquecido e respostas_multiplas (Parquet)
    ↓ Glue Job 03 — indicadores e agregações
Amazon S3 — Gold (sete tabelas Parquet)
    ↓ Glue Data Catalog + consultas no Athena
Exportação de resultados e apresentação executiva
```

Os Crawlers inspecionam os arquivos da Silver e da Gold e atualizam seus metadados no Glue Data Catalog. Os Jobs executam as transformações e gravam os dados; o catálogo registra esquemas, localizações e partições. Os resultados das consultas Athena são gravados separadamente no S3.

## Organização do repositório

```text
01_bronze/
  LEIA-ME_BRONZE.md
02_silver/
  01_bronze_para_silver.py
  02_silver_tecnologias_ia.py
03_gold/
  03_silver_para_gold.py
04_validacoes_athena/
  consultas_simples_athena.sql
  COMO_EXECUTAR_SQL_SIMPLES.md
  consultas_validacao_athena.sql
  guia_consultas_athena.md
  validacao_cloud.sql
ppt/
  Apresentação V4 e orientações
manifesto_scripts.json
README.md
```

Os CSVs e Parquet não fazem parte deste repositório. A ingestão da Bronze foi manual; não há um Job separado para baixar ou carregar as fontes. O manifesto registra hashes dos três scripts organizados por camada.

## Scripts e responsabilidades

| Arquivo | Job no Glue | Responsabilidade |
|---|---|---|
| [01_bronze_para_silver.py](02_silver/01_bronze_para_silver.py) | `bronze_para_silver_mercado_dados` | Ler os CSVs, validar esquemas, remover cópias exatas, padronizar campos e preservar respostas originais em JSON |
| [02_silver_tecnologias_ia.py](02_silver/02_silver_tecnologias_ia.py) | `silver_tecnologias_ia` | Enriquecer o perfil, normalizar campos booleanos, estruturar múltiplas escolhas e classificar respostas de IA |
| [03_silver_para_gold.py](03_gold/03_silver_para_gold.py) | `silver_para_gold_mercado_dados` | Calcular distribuições e indicadores, validar agregações e gravar as sete tabelas Gold |

Os Jobs utilizam Spark/PySpark e as bibliotecas do ambiente AWS Glue. O parâmetro `JOB_NAME` é lido pelo código na inicialização do Job.

## Ambiente utilizado

| Item | Configuração do projeto |
|---|---|
| Ambiente | AWS Academy Learner Lab |
| Região | `us-east-1` |
| Bucket | `tech-challenge-fase3-grupo-18` |
| Catálogo | `AwsDataCatalog` |
| Banco | `tech_challenge_fase3` |
| Função IAM existente | `LabRole` |
| Workgroup Athena | `primary` |

Os nomes e caminhos estão definidos nos scripts. Para reproduzir em outra conta, ajuste o bucket, as permissões e os recursos necessários. O repositório não provisiona automaticamente S3, IAM, Jobs ou Crawlers.

### Caminhos S3

```text
bronze/dados-mercado-brasil/
silver/dados-mercado-brasil/perfil_profissionais/
silver/dados-mercado-brasil/perfil_enriquecido/
silver/dados-mercado-brasil/respostas_multiplas/
gold/dados-mercado-brasil/
auditoria/
athena-resultados/
```

Silver e Gold são gravadas em Parquet, com partições por `edicao`. Os relatórios de qualidade são gravados em prefixos de auditoria pelos Jobs.

## Como executar o pipeline

1. Inicie o AWS Academy Lab e confira a região e as permissões.
2. Disponibilize os três CSVs originais no prefixo da Bronze, mantendo os nomes que permitem identificar cada edição.
3. Configure os três Jobs Spark no Glue com a função IAM existente e os scripts correspondentes. Se substituir uma versão em uso, salve um backup antes.
4. Execute `bronze_para_silver_mercado_dados` e aguarde **Succeeded**.
5. Execute `silver_tecnologias_ia` e aguarde **Succeeded**.
6. Execute `silver_para_gold_mercado_dados` e aguarde **Succeeded**.
7. Atualize o catálogo quando houver tabelas, colunas ou partições novas.
8. Execute os SELECTs no Athena e confira os resultados antes de utilizá-los em gráficos.

Os Jobs leem os dados diretamente do S3. Cada um grava suas próprias saídas derivadas com `overwrite`, preservando os arquivos da Bronze. Não execute Jobs concorrentes que leiam ou substituam os mesmos caminhos durante a gravação.

Os Crawlers utilizados no projeto são `crawler_silver_mercado_dados`, `crawler_silver_tecnologias_ia` e `crawler_gold_mercado_dados`. A existência de uma pasta no S3 não garante que sua tabela esteja registrada no catálogo.

## Tabelas Gold

| Tabela | Conteúdo |
|---|---|
| `gold_perfil` | Distribuições por dimensão de perfil |
| `gold_remuneracao` | Faixas salariais por cargo, senioridade, região, gênero e segmento |
| `gold_modelo_trabalho` | Distribuições de modelo atual e ideal |
| `gold_satisfacao` | Contagens do indicador de satisfação por alinhamento ao modelo ideal |
| `gold_ia_empresas` | Prioridade e resultados empresariais de IA declarados pelos respondentes |
| `gold_multiplas_escolhas` | Seleções por tema, código da pergunta e opção |
| `gold_adocao_ia` | Uso de IA entre respostas classificáveis, com bases e exclusões |

## Consultas e validação no Athena

Para começar, utilize as [30 consultas simples](04_validacoes_athena/consultas_simples_athena.sql) e o [guia de execução](04_validacoes_athena/COMO_EXECUTAR_SQL_SIMPLES.md). O guia relaciona as consultas aos slides da V4. Os comentários dos SQLs simples identificam seus propósitos, sem informar respostas esperadas.

**Execute um bloco por vez.** No editor, selecione o catálogo e o banco do projeto e confira a configuração do local de resultados do workgroup.

A pasta também contém as [consultas de validação detalhada](04_validacoes_athena/consultas_validacao_athena.sql), seu [guia de conferência](04_validacoes_athena/guia_consultas_athena.md) e a [validação específica de cloud](04_validacoes_athena/validacao_cloud.sql).

As verificações incluem unicidade de chaves, contagens, numeradores e denominadores, percentuais, reconciliação de populações e indicadores da apresentação. Parte das consultas Gold foi conferida localmente contra os CSVs exportados. Essa conferência não substitui a execução no Athena nem comprova o estado atual da infraestrutura AWS.

## Regras de tratamento e interpretação

- **Deduplicação:** o primeiro Job remove cópias exatas dentro de cada edição. IDs repetidos com respostas diferentes interrompem o fluxo para investigação.
- **Faixas salariais suspeitas:** o texto original é preservado e sinalizado; as faixas apontadas pelas regras são excluídas conservadoramente dos indicadores salariais até revisão.
- **Adoção de IA:** respostas contraditórias ou insuficientes não são convertidas em não usuários. A taxa é calculada entre respostas classificáveis; total da amostra, base válida e exclusões devem acompanhar sua interpretação.
- **Múltiplas escolhas:** uma pessoa pode selecionar mais de uma opção. Não some seleções para obter pessoas únicas.
- **Linguagens:** uso nas edições anteriores e preferência na última edição são perguntas distintas.
- **Cloud 2023-2024:** a versão atual incorpora o ajuste de rótulos adotado pelo grupo: `4.h.1 = AWS`, `4.h.2 = GCP` e `4.h.3 = Azure`. Essa decisão se baseou no cruzamento cloud × BI e não representa confirmação de uma errata oficial da fonte.
- **Segmentos:** `todos` é uma visão alternativa aos setores exclusivos; não deve ser somado a eles. `financas_bancos` representa o segmento financeiro disponível na pesquisa.
- **Percentuais:** estão na escala de 0 a 100. Ao reagrupar, recalcule a razão com as contagens corretas. Na remuneração, não some denominadores repetidos por faixa.
- **Limites:** salário em faixas não é salário médio exato; uso tecnológico não mede demanda por vagas; satisfação não mede retenção; resultados de IA são relatos e não comprovam impacto causal ou retorno financeiro.

## Apresentação executiva

A [pasta `ppt`](ppt/) contém a **V4 original**, enviada sem alterações nos slides. Os pontos de interpretação identificados na revisão seguem para validação da equipe. A publicação do arquivo não equivale à aprovação final de sua redação.

## Credenciais e dados

Os Jobs utilizam a função IAM configurada no Glue. Credenciais temporárias, tokens, arquivos de autenticação e dados detalhados não devem ser incluídos nos scripts ou commits. O `.gitignore` exclui formatos de dados e arquivos locais de credenciais do fluxo usual do Git.

Não há execução automática dos Jobs ou implantação de infraestrutura a partir deste repositório. Ele consolida o código e as instruções de reprodução do projeto.
