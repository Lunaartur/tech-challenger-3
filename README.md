# Scripts por camada e validações Athena

Grupo 18 | Organizado em 21/10/2026

## Conteúdo

- 01_bronze/: instruções da ingestão manual dos CSVs originais.
- 02_silver/01_bronze_para_silver.py: tratamento inicial, padronização, deduplicação e auditoria.
- 02_silver/02_silver_tecnologias_ia.py: enriquecimento, respostas múltiplas e classificação de IA; inclui ajuste cloud 2023-2024.
- 03_gold/03_silver_para_gold.py: agregação das sete tabelas Gold.
- 04_validacoes_athena/consultas_validacao_athena.sql: 28 consultas numeradas.
- 04_validacoes_athena/guia_consultas_athena.md: propósito, consulta e resultado esperado de cada teste.
- 04_validacoes_athena/validacao_cloud.sql: conferência específica do ajuste cloud.
- 04_validacoes_athena/verificacao_local.json: registro da conferência local de 20 consultas Gold; não é resultado de execução AWS.
- manifesto_scripts.json: hashes dos três scripts para conferência das versões.

## Configuração utilizada

Região: us-east-1. Bucket: tech-challenge-fase3-grupo-18.
Banco no Glue/Athena: tech_challenge_fase3. Catálogo: AwsDataCatalog.
Função IAM existente: LabRole. Workgroup Athena: primary.

Não há credenciais neste pacote. Os Jobs utilizam a função IAM configurada no Glue. Para outra conta, ajuste nomes e permissões nos caminhos utilizados pelos scripts.

## Ordem de execução completa

1. Conferir os três CSVs na Bronze.
2. Colar o arquivo 02_silver/01_bronze_para_silver.py no Job bronze_para_silver_mercado_dados, salvar e executar. Aguardar Succeeded.
3. Colar 02_silver/02_silver_tecnologias_ia.py no Job silver_tecnologias_ia, salvar e executar. Aguardar Succeeded.
4. Colar 03_gold/03_silver_para_gold.py no Job silver_para_gold_mercado_dados, salvar e executar. Aguardar Succeeded.
5. Atualizar os Crawlers correspondentes para tabelas, colunas ou partições novas. Os Jobs leem Parquet diretamente do S3; o catálogo é necessário para as consultas no Athena.
6. Executar as consultas SQL UMA POR VEZ, começando pelas consultas 01 a 14. O guia informa quais testes devem retornar zero linhas.
7. Conferir os indicadores e, se necessário, exportar novamente os CSVs.

Salve backup dos scripts atuais antes de substituí-los. Cada Job substitui as próprias saídas derivadas com overwrite. Não executar Jobs concorrentes nos mesmos caminhos. A Bronze permanece preservada.

## Versão e limites

Os scripts são cópias integrais da última versão local preparada com o ajuste cloud de 18/10/2026, sem nova alteração de lógica nesta organização. A mudança de rótulos em 2023-2024 é uma decisão documentada do grupo: 4.h.1 = AWS; 4.h.2 = GCP; 4.h.3 = Azure. Não representa confirmação de uma errata oficial da fonte.

As contagens esperadas no guia SQL correspondem à exportação auditada em 18/10/2026. Novos dados podem mudar legitimamente os totais. Percentuais usam escala 0 a 100; não somar todos aos setores, nem denominadores repetidos por categoria/faixa.

Os três scripts passaram na análise de sintaxe Python ao preparar este pacote. Nenhum Job ou consulta foi executado na AWS nesta entrega. O pacote não é um provisionador de infraestrutura: não cria automaticamente bucket, IAM, Jobs ou Crawlers.
