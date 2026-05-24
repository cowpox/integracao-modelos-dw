-- =============================================================
-- 05_consultas.sql
-- Consultas analíticas Q1–Q6
-- Executar conectado como dw_dcv (F9 para executar uma por vez)
-- Dependência: FATO_OBITO + todas as dimensões
-- =============================================================


-- -------------------------------------------------------------
-- Q1 — Evolução temporal por região (GROUP BY + ROLLUP)
-- -------------------------------------------------------------
-- Subtotais hierárquicos automáticos por ano, mês e região.
-- Linhas com NULL nas colunas de agrupamento são subtotais gerados pelo ROLLUP.
SELECT
    d.nr_ano,
    d.nr_mes,
    m.no_regiao_pais,
    COUNT(*)                                        AS total_obitos,
    SUM(f.fl_dcv)                                   AS obitos_dcv,
    ROUND(SUM(f.fl_dcv) * 100.0 / COUNT(*), 2)     AS pct_dcv
FROM fato_obito f
JOIN dim_data d      ON f.sk_data      = d.sk_data
JOIN dim_municipio m ON f.sk_municipio = m.sk_municipio
WHERE d.nr_ano >= 2024
GROUP BY ROLLUP(d.nr_ano, d.nr_mes, m.no_regiao_pais)
ORDER BY d.nr_ano, d.nr_mes, m.no_regiao_pais;


-- -------------------------------------------------------------
-- Q2 — Comparação multidimensional por região, macrorregião e sexo (CUBE)
-- -------------------------------------------------------------
-- CUBE com 3 dimensões gera 2^3 = 8 combinações de subtotais.
-- NVL substitui os NULLs dos subtotais por rótulos legíveis.
-- Filtro co_sexo IN ('1','2') exclui "Ignorado" para subtotais coerentes.
SELECT
    NVL(m.no_regiao_pais, 'TOTAL BRASIL')  AS regiao,
    NVL(m.no_macro,       'TOTAL MACRO')   AS macrorregiao,
    NVL(s.ds_sexo,        'AMBOS SEXOS')   AS sexo,
    COUNT(*)                               AS total_obitos_dcv,
    TRUNC(AVG(f.idade_anos))               AS idade_media_obito
FROM fato_obito f
JOIN dim_municipio m   ON f.sk_municipio = m.sk_municipio
JOIN dim_sexo s        ON f.sk_sexo      = s.sk_sexo
WHERE f.fl_dcv = 1
  AND s.co_sexo IN ('1', '2')
GROUP BY CUBE(m.no_regiao_pais, m.no_macro, s.ds_sexo);


-- -------------------------------------------------------------
-- Q3 — Taxa DCV × estrutura hospitalar por município
-- -------------------------------------------------------------
-- Consulta principal: responde à pergunta central do DW.
-- NULLIF evita ORA-01476 (divisão por zero) quando populacao_2022 = 0.
-- DIM_ESTABELECIMENTO é outrigger — join via co_ibge, não via FATO_OBITO.
SELECT
    m.no_municipio,
    m.no_uf,
    m.no_macro,
    e.qtd_hospitais,
    COUNT(*)                                                            AS obitos_dcv,
    ROUND(COUNT(*) * 100000.0 / NULLIF(m.populacao_2022, 0), 2)        AS taxa_dcv_por_100k,
    ROUND(e.qtd_hospitais * 100000.0 / NULLIF(m.populacao_2022, 0), 4) AS hospitais_por_100k
FROM fato_obito f
JOIN dim_municipio m       ON f.sk_municipio = m.sk_municipio
JOIN dim_estabelecimento e ON m.co_ibge      = e.co_ibge
WHERE f.fl_dcv = 1
  AND m.populacao_2022 > 0
GROUP BY m.no_municipio, m.no_uf, m.no_macro,
         e.qtd_hospitais, m.populacao_2022
ORDER BY taxa_dcv_por_100k DESC
FETCH FIRST 30 ROWS ONLY;


-- -------------------------------------------------------------
-- Q4 — Ranking de municípios por taxa DCV (RANK — função de janela)
-- -------------------------------------------------------------
-- Dois rankings simultâneos: dentro da macrorregião e nacional.
-- RANK() atribui a mesma posição em empates e pula a posição seguinte.
-- co_ibge no GROUP BY distingue municípios homônimos em estados diferentes.
SELECT
    m.no_municipio,
    m.sg_uf,
    m.no_macro,
    COUNT(*)                                                       AS obitos_dcv,
    ROUND(COUNT(*) * 100000.0 / NULLIF(m.populacao_2022, 0), 2)   AS taxa_dcv_por_100k,
    RANK() OVER (
        PARTITION BY m.no_macro
        ORDER BY COUNT(*) * 100000.0 / NULLIF(m.populacao_2022, 0) DESC
    ) AS rank_na_macro,
    RANK() OVER (
        ORDER BY COUNT(*) * 100000.0 / NULLIF(m.populacao_2022, 0) DESC
    ) AS rank_nacional
FROM fato_obito f
JOIN dim_municipio m ON f.sk_municipio = m.sk_municipio
WHERE f.fl_dcv = 1
GROUP BY m.no_municipio, m.sg_uf, m.no_macro, m.co_ibge, m.populacao_2022
ORDER BY rank_nacional
FETCH FIRST 50 ROWS ONLY;


-- -------------------------------------------------------------
-- Q5 — Perfil dos óbitos por DCV: sexo, raça/cor, faixa etária (CASE + GROUP BY)
-- -------------------------------------------------------------
-- CASE transforma idade em faixa etária categórica.
-- Prefixos A–E forçam ordenação cronológica via ORDER BY faixa_etaria (lexicográfico).
-- CASE deve ser repetido no GROUP BY — Oracle não permite alias do SELECT no GROUP BY.
-- SUM(COUNT(*)) OVER () é função de janela sobre o resultado do GROUP BY.
SELECT
    s.ds_sexo,
    rc.ds_raca_cor,
    CASE
        WHEN f.idade_anos < 40 THEN 'A. Menos de 40 anos'
        WHEN f.idade_anos < 60 THEN 'B. 40-59 anos'
        WHEN f.idade_anos < 70 THEN 'C. 60-69 anos'
        WHEN f.idade_anos < 80 THEN 'D. 70-79 anos'
        ELSE                        'E. 80 anos ou mais'
    END AS faixa_etaria,
    COUNT(*) AS total_obitos,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_total
FROM fato_obito f
JOIN dim_sexo s      ON f.sk_sexo     = s.sk_sexo
JOIN dim_raca_cor rc ON f.sk_raca_cor = rc.sk_raca_cor
WHERE f.fl_dcv = 1
  AND s.co_sexo != '9'
GROUP BY
    s.ds_sexo,
    rc.ds_raca_cor,
    CASE
        WHEN f.idade_anos < 40 THEN 'A. Menos de 40 anos'
        WHEN f.idade_anos < 60 THEN 'B. 40-59 anos'
        WHEN f.idade_anos < 70 THEN 'C. 60-69 anos'
        WHEN f.idade_anos < 80 THEN 'D. 70-79 anos'
        ELSE                        'E. 80 anos ou mais'
    END
ORDER BY s.ds_sexo, faixa_etaria;


-- -------------------------------------------------------------
-- Q6 — Variação mensal de óbitos por DCV por macrorregião (LAG)
-- -------------------------------------------------------------
-- LAG retorna o valor da linha anterior dentro da partição.
-- PARTITION BY garante séries temporais independentes por macrorregião.
-- Primeira linha de cada macro: obitos_mes_anterior = NULL (comportamento correto).
SELECT
    m.no_macro,
    d.nr_ano,
    d.nr_mes,
    COUNT(*)                         AS obitos_dcv,
    LAG(COUNT(*)) OVER (
        PARTITION BY m.no_macro
        ORDER BY d.nr_ano, d.nr_mes
    )                                AS obitos_mes_anterior,
    COUNT(*) - LAG(COUNT(*)) OVER (
        PARTITION BY m.no_macro
        ORDER BY d.nr_ano, d.nr_mes
    )                                AS variacao_absoluta
FROM fato_obito f
JOIN dim_municipio m ON f.sk_municipio = m.sk_municipio
JOIN dim_data d      ON f.sk_data      = d.sk_data
WHERE f.fl_dcv = 1
GROUP BY m.no_macro, d.nr_ano, d.nr_mes
ORDER BY m.no_macro, d.nr_ano, d.nr_mes;
