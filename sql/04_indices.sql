-- =============================================================
-- 04_indices.sql
-- Índices de performance na tabela fato
-- Executar conectado como dw_dcv
-- Dependência: FATO_OBITO criada e carregada (03_fato.sql)
-- =============================================================

-- Índices nos campos de join e no filtro mais frequente (fl_dcv)
CREATE INDEX idx_fato_municipio ON fato_obito(sk_municipio);
CREATE INDEX idx_fato_data      ON fato_obito(sk_data);
CREATE INDEX idx_fato_causa     ON fato_obito(sk_causa);
CREATE INDEX idx_fato_fl_dcv    ON fato_obito(fl_dcv);

-- NOTA: NÃO criar índice em dim_municipio(co_ibge)
-- Oracle cria índice único automaticamente para toda PRIMARY KEY e UNIQUE constraint
-- Tentar criar causaria ORA-01408 (coluna já indexada)

-- Verificar índices criados:
SELECT index_name, table_name, uniqueness
FROM user_indexes
WHERE table_name IN ('FATO_OBITO', 'DIM_MUNICIPIO', 'DIM_DATA', 'DIM_CAUSA_MORTE')
ORDER BY table_name, index_name;

-- Contagem geral de todas as tabelas do DW:
SELECT 'STG_MORTALIDADE'    AS tabela, COUNT(*) AS linhas FROM stg_mortalidade   UNION ALL
SELECT 'STG_CNES_JSON',                COUNT(*)           FROM stg_cnes_json      UNION ALL
SELECT 'STG_MACROREGIAO',              COUNT(*)           FROM stg_macroregiao    UNION ALL
SELECT 'DIM_DATA',                     COUNT(*)           FROM dim_data           UNION ALL
SELECT 'DIM_MUNICIPIO',                COUNT(*)           FROM dim_municipio      UNION ALL
SELECT 'DIM_CAUSA_MORTE',              COUNT(*)           FROM dim_causa_morte    UNION ALL
SELECT 'DIM_SEXO',                     COUNT(*)           FROM dim_sexo           UNION ALL
SELECT 'DIM_RACA_COR',                 COUNT(*)           FROM dim_raca_cor       UNION ALL
SELECT 'DIM_LOCAL_OBITO',              COUNT(*)           FROM dim_local_obito    UNION ALL
SELECT 'DIM_ESTABELECIMENTO',          COUNT(*)           FROM dim_estabelecimento UNION ALL
SELECT 'FATO_OBITO',                   COUNT(*)           FROM fato_obito
ORDER BY 1;
