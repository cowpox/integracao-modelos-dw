-- =============================================================
-- 06_mv.sql
-- Q7 — Materialized View: resumo anual por macrorregião
-- Executar conectado como dw_dcv (F5)
-- Dependência: FATO_OBITO + DIM_MUNICIPIO + DIM_DATA
-- =============================================================

-- Criar a Materialized View
-- BUILD IMMEDIATE: popula na criação
-- REFRESH COMPLETE ON DEMAND: reconstrói completamente ao ser chamada manualmente
CREATE MATERIALIZED VIEW mv_resumo_macro_anual
BUILD IMMEDIATE
REFRESH COMPLETE ON DEMAND
AS
SELECT
    m.co_macro,
    m.no_macro,
    m.no_regiao_pais,
    d.nr_ano,
    COUNT(*)                                            AS total_obitos,
    SUM(f.fl_dcv)                                       AS obitos_dcv,
    ROUND(SUM(f.fl_dcv) * 100.0 / COUNT(*), 2)         AS pct_dcv,
    AVG(f.idade_anos)                                   AS idade_media
FROM fato_obito f
JOIN dim_municipio m ON f.sk_municipio = m.sk_municipio
JOIN dim_data d      ON f.sk_data      = d.sk_data
GROUP BY m.co_macro, m.no_macro, m.no_regiao_pais, d.nr_ano;


-- Consultar a MV (muito mais rápido que a query original sobre FATO_OBITO)
SELECT * FROM mv_resumo_macro_anual ORDER BY no_regiao_pais, nr_ano;


-- Verificar consistência: total de DCV deve ser igual ao da Q1 (~382.363)
SELECT SUM(obitos_dcv) AS total_dcv_mv FROM mv_resumo_macro_anual;


-- Atualizar manualmente após nova carga ETL
EXEC DBMS_MVIEW.REFRESH('MV_RESUMO_MACRO_ANUAL', 'C');
