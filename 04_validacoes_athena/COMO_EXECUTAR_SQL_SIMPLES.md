# Como executar as consultas simples no Athena

O arquivo [consultas_simples_athena.sql](consultas_simples_athena.sql) contém 12 consultas independentes. Cada bloco tem apenas um título indicando seu propósito, sem respostas ou valores esperados.

## Preparação

1. Inicie o AWS Academy Lab e entre no console da AWS.
2. Confira a região **us-east-1**.
3. Abra **Amazon Athena > Query editor**.
4. Selecione o catálogo **AwsDataCatalog**, banco **tech_challenge_fase3** e workgroup **primary**.
5. Confira se o local dos resultados está configurado no workgroup. Utilize o prefixo de resultados Athena do projeto no S3.
6. Confirme que os Jobs necessários concluíram com **Succeeded**. Atualize o catálogo por Crawler se houver tabelas, colunas ou partições novas.

## Execução

1. Abra o arquivo SQL no GitHub e copie o primeiro bloco, do comando até o ponto e vírgula.
2. Cole no editor do Athena e clique em **Executar**.
3. Confira o status e os resultados antes de continuar.
4. Repita o procedimento com as demais consultas, uma por vez.
5. Registre a consulta, a data e o resultado utilizado na validação. Use **Baixar CSV dos resultados** quando precisar compartilhar a saída.

Não cole as 12 consultas de uma vez como uma única execução. Cada consulta é independente; não é preciso criar tabelas temporárias.

## O que as consultas verificam

- Catálogo de tabelas do projeto.
- Quantidades de perfis por edição e duplicatas na Silver.
- Repetição de opções de respostas múltiplas.
- Quantidade de agregados na Gold.
- Perfil de gênero e distribuição de faixas salariais.
- Modelos de trabalho atual e ideal e alinhamento com satisfação.
- Rótulos de cloud e estágios declarados de projetos de IA.
- Adoção individual de IA, base válida e exclusões.

## Cuidados de interpretação

- Não some o segmento **todos** com os segmentos específicos.
- Na remuneração, não some denominadores repetidos por faixa.
- Os percentuais da Gold estão na escala de 0 a 100.
- Ausência de resposta não significa resposta negativa.
- Diferencie preferência de uso tecnológico e associação de causalidade.
- Contagens de linhas Gold são agregados, não quantidades de pessoas.

## Se ocorrer um erro

- **TABLE_NOT_FOUND:** confira catálogo, banco e registro da tabela no Glue.
- **COLUMN_NOT_FOUND:** confira a versão do esquema e a atualização do catálogo.
- **AccessDenied:** confira as permissões do laboratório e o acesso aos caminhos S3.
- Problema com a saída da consulta: confira a configuração do local de resultados do workgroup.

As consultas não alteram as tabelas. O Athena lê os dados e grava as saídas no local de resultados configurado, sujeito ao consumo do serviço. Não inclua credenciais nos scripts ou nos arquivos compartilhados.
