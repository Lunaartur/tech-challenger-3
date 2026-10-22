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
