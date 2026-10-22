-- Execute uma consulta por vez.
SELECT edicao, segmento, codigo_pergunta, opcao, numerador, denominador, percentual
FROM tech_challenge_fase3.gold_multiplas_escolhas
WHERE tema = 'cloud_uso'
  AND segmento IN ('todos', 'financas_bancos')
  AND opcao IN ('Amazon Web Services (AWS)', 'Google Cloud (GCP)', 'Azure (Microsoft)')
ORDER BY segmento, codigo_pergunta, edicao;

-- Esperado: 702 linhas, se a base permanecer a mesma.
SELECT COUNT(*) AS linhas FROM tech_challenge_fase3.gold_multiplas_escolhas;

-- Esperado: nenhuma linha.
SELECT edicao, segmento, tema, codigo_pergunta, COUNT(*) AS quantidade
FROM tech_challenge_fase3.gold_multiplas_escolhas
GROUP BY edicao, segmento, tema, codigo_pergunta
HAVING COUNT(*) > 1;
