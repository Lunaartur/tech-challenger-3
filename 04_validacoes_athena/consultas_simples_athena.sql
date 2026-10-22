-- 01. Ver quais tabelas estao no banco.
SHOW TABLES IN tech_challenge_fase3;

-- 02. Contar os perfis por edicao na Silver.
SELECT edicao, COUNT(*) AS quantidade
FROM tech_challenge_fase3.perfil_enriquecido
GROUP BY edicao
ORDER BY edicao;

-- 03. Procurar IDs repetidos na mesma edicao.
SELECT edicao, id_resposta, COUNT(*) AS quantidade
FROM tech_challenge_fase3.perfil_enriquecido
GROUP BY edicao, id_resposta
HAVING COUNT(*) > 1;

-- 04. Procurar a mesma opcao repetida para o mesmo respondente.
SELECT edicao, id_resposta, tema, codigo_pergunta, COUNT(*) AS quantidade
FROM tech_challenge_fase3.respostas_multiplas
GROUP BY edicao, id_resposta, tema, codigo_pergunta
HAVING COUNT(*) > 1;

-- 05. Contar as linhas da Gold de multiplas escolhas.
SELECT COUNT(*) AS quantidade
FROM tech_challenge_fase3.gold_multiplas_escolhas;

-- 06. Conferir genero na ultima edicao.
SELECT categoria, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_perfil
WHERE edicao = '2025-2026'
  AND segmento = 'todos'
  AND dimensao = 'genero'
ORDER BY numerador DESC;

-- 07. Ver quantas pessoas estao em cada faixa salarial e senioridade.
SELECT senioridade, faixa_salarial, SUM(numerador) AS quantidade
FROM tech_challenge_fase3.gold_remuneracao
WHERE edicao = '2025-2026'
  AND segmento = 'todos'
GROUP BY senioridade, faixa_salarial
ORDER BY senioridade, faixa_salarial;

-- 08. Conferir modelos de trabalho atual e ideal.
SELECT tipo_modelo, modelo, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_modelo_trabalho
WHERE edicao = '2025-2026'
  AND segmento = 'todos'
ORDER BY tipo_modelo, percentual DESC;

-- 09. Conferir satisfacao por alinhamento ao modelo ideal.
SELECT modelo_diferente_ideal, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_satisfacao
WHERE edicao = '2025-2026'
  AND segmento = 'todos';

-- 10. Conferir os rotulos cloud de 2023-2024 apos o ajuste do grupo.
SELECT codigo_pergunta, opcao, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_multiplas_escolhas
WHERE edicao = '2023-2024'
  AND segmento = 'todos'
  AND tema = 'cloud_uso'
ORDER BY codigo_pergunta;

-- 11. Conferir o estagio dos projetos de IA em Financas/Bancos.
SELECT resposta, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_ia_empresas
WHERE edicao = '2025-2026'
  AND segmento = 'financas_bancos'
  AND indicador = 'resultado_ia_empresa'
ORDER BY numerador DESC;

-- 12. Conferir adocao de IA e as exclusoes nas tres edicoes.
SELECT edicao, total_respondentes, numerador, denominador,
       nao_usuarios, respostas_contraditorias,
       respostas_insuficientes_ou_ausentes, percentual
FROM tech_challenge_fase3.gold_adocao_ia
WHERE segmento = 'todos'
ORDER BY edicao;

-- 13. Slide 5: cargos, senioridade e regiao na ultima edicao.
SELECT dimensao, categoria, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_perfil
WHERE edicao = '2025-2026' AND segmento = 'todos'
  AND dimensao IN ('cargo','senioridade','regiao')
ORDER BY dimensao, numerador DESC;

-- 14. Slide 5: participacao conjunta dos tres principais cargos.
SELECT SUM(numerador) AS pessoas, MAX(denominador) AS base_cargo,
       ROUND(100.0 * SUM(numerador) / NULLIF(MAX(denominador),0),2) AS percentual
FROM tech_challenge_fase3.gold_perfil
WHERE edicao = '2025-2026' AND segmento = 'todos' AND dimensao = 'cargo'
  AND categoria IN ('Analista de Dados/Data Analyst',
                    'Cientista de Dados/Data Scientist',
                    'Engenheiro de Dados/Data Engineer/Data Architect');

-- 15. Slide 5: participacao conjunta de seniores e especialistas.
SELECT SUM(numerador) AS pessoas, MAX(denominador) AS base_senioridade,
       ROUND(100.0 * SUM(numerador) / NULLIF(MAX(denominador),0),2) AS percentual
FROM tech_challenge_fase3.gold_perfil
WHERE edicao = '2025-2026' AND segmento = 'todos' AND dimensao = 'senioridade'
  AND categoria IN ('Sênior','Especialista/Staff+');

-- 16. Slide 5: participacao das regioes fora do Sul e Sudeste.
SELECT SUM(numerador) AS pessoas, MAX(denominador) AS base_regiao,
       ROUND(100.0 * SUM(numerador) / NULLIF(MAX(denominador),0),2) AS percentual
FROM tech_challenge_fase3.gold_perfil
WHERE edicao = '2025-2026' AND segmento = 'todos' AND dimensao = 'regiao'
  AND categoria IN ('Norte','Nordeste','Centro-oeste');

-- 17. Slide 6: proporcao acima de R$ 12 mil por cargo.
SELECT cargo, SUM(numerador) AS base_salarial,
       SUM(CASE WHEN faixa_salarial IN (
          'de R$ 12.001/mês a R$ 16.000/mês',
          'de R$ 16.001/mês a R$ 20.000/mês',
          'de R$ 20.001/mês a R$ 25.000/mês',
          'de R$ 25.001/mês a R$ 30.000/mês',
          'de R$ 30.001/mês a R$ 40.000/mês',
          'Acima de R$ 40.001/mês')
           THEN numerador ELSE 0 END) AS pessoas_acima_12mil,
       ROUND(100.0 * SUM(CASE WHEN faixa_salarial IN (
          'de R$ 12.001/mês a R$ 16.000/mês',
          'de R$ 16.001/mês a R$ 20.000/mês',
          'de R$ 20.001/mês a R$ 25.000/mês',
          'de R$ 25.001/mês a R$ 30.000/mês',
          'de R$ 30.001/mês a R$ 40.000/mês',
          'Acima de R$ 40.001/mês')
           THEN numerador ELSE 0 END) / NULLIF(SUM(numerador),0),2) AS percentual_acima_12mil
FROM tech_challenge_fase3.gold_remuneracao
WHERE edicao = '2025-2026' AND segmento = 'todos'
  AND cargo NOT IN ('Nao informado','Outra Opção')
GROUP BY cargo
HAVING SUM(numerador) >= 50
ORDER BY percentual_acima_12mil DESC;

-- 18. Slides 3 e 6: proporcao acima de R$ 12 mil por nivel e setor.
SELECT segmento, senioridade, SUM(numerador) AS base_salarial,
       SUM(CASE WHEN faixa_salarial IN (
          'de R$ 12.001/mês a R$ 16.000/mês',
          'de R$ 16.001/mês a R$ 20.000/mês',
          'de R$ 20.001/mês a R$ 25.000/mês',
          'de R$ 25.001/mês a R$ 30.000/mês',
          'de R$ 30.001/mês a R$ 40.000/mês',
          'Acima de R$ 40.001/mês')
           THEN numerador ELSE 0 END) AS pessoas_acima_12mil,
       ROUND(100.0 * SUM(CASE WHEN faixa_salarial IN (
          'de R$ 12.001/mês a R$ 16.000/mês',
          'de R$ 16.001/mês a R$ 20.000/mês',
          'de R$ 20.001/mês a R$ 25.000/mês',
          'de R$ 25.001/mês a R$ 30.000/mês',
          'de R$ 30.001/mês a R$ 40.000/mês',
          'Acima de R$ 40.001/mês')
           THEN numerador ELSE 0 END) / NULLIF(SUM(numerador),0),2) AS percentual_acima_12mil
FROM tech_challenge_fase3.gold_remuneracao
WHERE edicao = '2025-2026'
  AND senioridade <> 'Nao informado'
GROUP BY segmento, senioridade

ORDER BY segmento, senioridade;

-- 19. Slide 6: proporcao acima de R$ 12 mil por regiao no geral.
SELECT regiao, SUM(numerador) AS base_salarial,
       SUM(CASE WHEN faixa_salarial IN (
          'de R$ 12.001/mês a R$ 16.000/mês',
          'de R$ 16.001/mês a R$ 20.000/mês',
          'de R$ 20.001/mês a R$ 25.000/mês',
          'de R$ 25.001/mês a R$ 30.000/mês',
          'de R$ 30.001/mês a R$ 40.000/mês',
          'Acima de R$ 40.001/mês')
           THEN numerador ELSE 0 END) AS pessoas_acima_12mil,
       ROUND(100.0 * SUM(CASE WHEN faixa_salarial IN (
          'de R$ 12.001/mês a R$ 16.000/mês',
          'de R$ 16.001/mês a R$ 20.000/mês',
          'de R$ 20.001/mês a R$ 25.000/mês',
          'de R$ 25.001/mês a R$ 30.000/mês',
          'de R$ 30.001/mês a R$ 40.000/mês',
          'Acima de R$ 40.001/mês')
           THEN numerador ELSE 0 END) / NULLIF(SUM(numerador),0),2) AS percentual_acima_12mil
FROM tech_challenge_fase3.gold_remuneracao
WHERE edicao = '2025-2026' AND segmento = 'todos'
  AND regiao IN ('Sudeste','Nordeste')
GROUP BY regiao

ORDER BY regiao;

-- 20. Slide 6: proporcao acima de R$ 12 mil por regiao entre seniores.
SELECT regiao, SUM(numerador) AS base_salarial,
       SUM(CASE WHEN faixa_salarial IN (
          'de R$ 12.001/mês a R$ 16.000/mês',
          'de R$ 16.001/mês a R$ 20.000/mês',
          'de R$ 20.001/mês a R$ 25.000/mês',
          'de R$ 25.001/mês a R$ 30.000/mês',
          'de R$ 30.001/mês a R$ 40.000/mês',
          'Acima de R$ 40.001/mês')
           THEN numerador ELSE 0 END) AS pessoas_acima_12mil,
       ROUND(100.0 * SUM(CASE WHEN faixa_salarial IN (
          'de R$ 12.001/mês a R$ 16.000/mês',
          'de R$ 16.001/mês a R$ 20.000/mês',
          'de R$ 20.001/mês a R$ 25.000/mês',
          'de R$ 25.001/mês a R$ 30.000/mês',
          'de R$ 30.001/mês a R$ 40.000/mês',
          'Acima de R$ 40.001/mês')
           THEN numerador ELSE 0 END) / NULLIF(SUM(numerador),0),2) AS percentual_acima_12mil
FROM tech_challenge_fase3.gold_remuneracao
WHERE edicao = '2025-2026' AND segmento = 'todos'
  AND senioridade = 'Sênior' AND regiao IN ('Sudeste','Nordeste')
GROUP BY regiao

ORDER BY regiao;

-- 21. Slide 7: participacao feminina por setor e edicao.
SELECT edicao, segmento, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_perfil
WHERE dimensao = 'genero' AND categoria = 'Feminino'
ORDER BY segmento, edicao;

-- 22. Slide 7: proporcao acima de R$ 12 mil por genero entre seniores.
SELECT edicao, genero, SUM(numerador) AS base_salarial,
       SUM(CASE WHEN faixa_salarial IN (
          'de R$ 12.001/mês a R$ 16.000/mês',
          'de R$ 16.001/mês a R$ 20.000/mês',
          'de R$ 20.001/mês a R$ 25.000/mês',
          'de R$ 25.001/mês a R$ 30.000/mês',
          'de R$ 30.001/mês a R$ 40.000/mês',
          'Acima de R$ 40.001/mês')
           THEN numerador ELSE 0 END) AS pessoas_acima_12mil,
       ROUND(100.0 * SUM(CASE WHEN faixa_salarial IN (
          'de R$ 12.001/mês a R$ 16.000/mês',
          'de R$ 16.001/mês a R$ 20.000/mês',
          'de R$ 20.001/mês a R$ 25.000/mês',
          'de R$ 25.001/mês a R$ 30.000/mês',
          'de R$ 30.001/mês a R$ 40.000/mês',
          'Acima de R$ 40.001/mês')
           THEN numerador ELSE 0 END) / NULLIF(SUM(numerador),0),2) AS percentual_acima_12mil
FROM tech_challenge_fase3.gold_remuneracao
WHERE segmento = 'todos' AND senioridade = 'Sênior'
  AND genero IN ('Feminino','Masculino')
GROUP BY edicao, genero

ORDER BY edicao, genero;

-- 23. Slide 8: criterios de escolha de emprego.
SELECT opcao, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_multiplas_escolhas
WHERE edicao = '2025-2026' AND segmento = 'todos'
  AND tema = 'criterios_emprego'
ORDER BY numerador DESC;

-- 24. Slide 9: linguagens preferidas na ultima edicao.
SELECT opcao, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_multiplas_escolhas
WHERE edicao = '2025-2026' AND segmento = 'todos'
  AND tema = 'linguagem_preferencia'
ORDER BY numerador DESC;

-- 25. Slide 9: cloud por setor nas tres edicoes.
SELECT edicao, segmento, opcao, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_multiplas_escolhas
WHERE tema = 'cloud_uso'
  AND segmento IN ('financas_bancos','demais_setores')
ORDER BY segmento, opcao, edicao;

-- 26. Slide 9: Power BI, QuickSight e outras ferramentas de BI.
SELECT segmento, opcao, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_multiplas_escolhas
WHERE edicao = '2025-2026' AND tema = 'bi_uso'
ORDER BY segmento, numerador DESC;

-- 27. Slides 3 e 10: modalidades de IA, incluindo pagamento pela empresa.
SELECT segmento, opcao, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_multiplas_escolhas
WHERE edicao = '2025-2026' AND tema = 'ia_produtividade'
ORDER BY segmento, numerador DESC;

-- 28. Slides 3 e 10: barreiras de IA e historico de retorno nao comprovado.
SELECT edicao, opcao, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_multiplas_escolhas
WHERE segmento = 'todos' AND tema = 'barreiras_ia'
ORDER BY opcao, edicao;

-- 29. Slides 3 e 10: estagios de IA em todos os setores.
SELECT segmento, resposta, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_ia_empresas
WHERE edicao = '2025-2026' AND indicador = 'resultado_ia_empresa'
ORDER BY segmento, numerador DESC;

-- 30. Slides 3 e 10: cobertura valida do indicador de adocao de IA.
SELECT edicao, total_respondentes, denominador AS respostas_validas,
       numerador AS usuarios_identificados,
       percentual AS adocao_entre_validos,
       ROUND(100.0 * denominador / NULLIF(total_respondentes,0),2) AS cobertura_valida_pct,
       ROUND(100.0 * numerador / NULLIF(total_respondentes,0),2) AS usuarios_total_pct
FROM tech_challenge_fase3.gold_adocao_ia
WHERE segmento = 'todos'
ORDER BY edicao;
