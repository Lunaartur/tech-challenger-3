# Como executar as consultas simples no Athena

O arquivo [consultas_simples_athena.sql](consultas_simples_athena.sql) contém 30 consultas independentes. Cada bloco tem apenas um título indicando seu propósito, sem respostas ou valores esperados.

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

Não cole as 30 consultas de uma vez como uma única execução. Cada consulta é independente; não é preciso criar tabelas temporárias.

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

## Relação com a apresentação V4

As consultas 01 a 12 foram preservadas. As consultas 13 a 30 complementam os recortes numéricos dos slides. Os comentários contêm apenas títulos e propósitos, sem respostas esperadas.

| Slide | Consultas |
|---|---|
| 2: totais de respostas | 02; somar as linhas por edição para obter o total |
| 3: resumo executivo | 08, 12, 18, 27, 28, 29, 30 |
| 4: catálogo e arquitetura | 01 para listar tabelas; execução e desenho exigem evidências além de SELECTs |
| 5: cargos, senioridade e região | 13, 14, 15, 16 |
| 6: remuneração por cargo, nível, setor e região | 07, 17, 18, 19, 20 |
| 7: gênero por edição e faixas salariais entre seniores | 06, 21, 22 |
| 8: trabalho, satisfação e critérios de emprego | 08, 09, 23 |
| 9: linguagens, cloud e BI | 10, 24, 25, 26 |
| 10: adoção, ferramentas, resultados e barreiras de IA | 12, 27, 28, 29, 30 |
| 11: recomendações | Usar os indicadores anteriores como evidência; as recomendações não são resultados diretos de uma consulta |

Nas consultas salariais, CASE seleciona as faixas a partir de R$ 12.001. SUM(numerador) agrega as contagens e NULLIF evita divisão por zero. Não há WITH, JOIN ou UNION. A consulta 17 exclui categorias genéricas e usa uma base mínima por cargo.

As consultas permitem conferir os valores; não validam automaticamente a interpretação dos textos da apresentação. A V4 é disponibilizada em sua versão original, com os pontos de redação em revisão pela equipe.

Os blocos Gold foram conferidos localmente contra os CSVs do projeto. Essa conferência não substitui a execução no Athena nem comprova o estado atual dos dados na AWS.
