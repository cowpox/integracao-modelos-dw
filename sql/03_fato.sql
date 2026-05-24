-- =============================================================
-- 03_fato.sql
-- Criação e carga da tabela fato FATO_OBITO
-- Executar conectado como dw_dcv
-- Dependências: todas as dimensões de 02_dimensoes.sql
-- Pode demorar vários minutos (1,5 milhão de registros)
-- =============================================================

CREATE TABLE fato_obito (
    sk_obito      NUMBER(12) PRIMARY KEY,
    sk_municipio  NUMBER(8)  REFERENCES dim_municipio(sk_municipio),
    sk_data       NUMBER(8)  REFERENCES dim_data(sk_data),
    sk_causa      NUMBER(8)  REFERENCES dim_causa_morte(sk_causa),
    sk_sexo       NUMBER(3)  REFERENCES dim_sexo(sk_sexo),
    sk_raca_cor   NUMBER(3)  REFERENCES dim_raca_cor(sk_raca_cor),
    sk_local      NUMBER(3)  REFERENCES dim_local_obito(sk_local),
    idade_anos    NUMBER(5,1),
    fl_dcv        NUMBER(1)  DEFAULT 0,
    fl_hospitalar NUMBER(1)  DEFAULT 0,
    fl_necropsia  NUMBER(1)  DEFAULT 0,
    nk_contador   NUMBER(12)
);

INSERT INTO fato_obito (
    sk_obito, sk_municipio, sk_data, sk_causa,
    sk_sexo, sk_raca_cor, sk_local,
    idade_anos, fl_dcv, fl_hospitalar, fl_necropsia, nk_contador
)
SELECT
    ROWNUM AS sk_obito,

    m.sk_municipio,

    -- Converter DDMMAAAA -> inteiro YYYYMMDD (SK da DIM_DATA)
    TO_NUMBER(TO_CHAR(TO_DATE(s.dtobito, 'DDMMYYYY'), 'YYYYMMDD')) AS sk_data,

    NVL(c.sk_causa, 0)   AS sk_causa,    -- 0 = Causa ignorada se CID não encontrado
    NVL(sx.sk_sexo, 9)   AS sk_sexo,
    NVL(rc.sk_raca_cor, 9) AS sk_raca_cor,
    NVL(lo.sk_local, 9)  AS sk_local,

    -- Decodificar idade codificada pelo SIM
    -- 1º dígito indica unidade: 4=anos, 3=meses, 2=dias, 1=horas, 5=centenário
    CASE
        WHEN SUBSTR(s.idade, 1, 1) = '4' THEN TO_NUMBER(SUBSTR(s.idade, 2))
        WHEN SUBSTR(s.idade, 1, 1) = '3' THEN ROUND(TO_NUMBER(SUBSTR(s.idade, 2)) / 12.0, 1)
        WHEN SUBSTR(s.idade, 1, 1) IN ('1','2') THEN 0
        WHEN SUBSTR(s.idade, 1, 1) = '5' THEN TO_NUMBER(SUBSTR(s.idade, 2)) + 100
        ELSE NULL
    END AS idade_anos,

    CASE WHEN REGEXP_LIKE(TRIM(REPLACE(UPPER(s.causabas),'*','')), '^I[0-9]')
         THEN 1 ELSE 0 END AS fl_dcv,

    CASE WHEN TRIM(s.lococor) = '1' THEN 1 ELSE 0 END AS fl_hospitalar,

    CASE WHEN UPPER(TRIM(s.necropsia)) = 'S' THEN 1 ELSE 0 END AS fl_necropsia,

    TO_NUMBER(s.contador) AS nk_contador

FROM stg_mortalidade s

-- INNER JOIN no município: descarta registros sem município válido
JOIN dim_municipio m
    ON LPAD(TO_NUMBER(TRIM(s.codmunres)), 6, '0') = m.co_ibge

-- LEFT JOINs: mantém o registro mesmo sem correspondência na dimensão
LEFT JOIN dim_causa_morte c
    ON TRIM(REPLACE(UPPER(s.causabas),'*','')) = c.co_cid10

LEFT JOIN dim_sexo sx
    ON TRIM(s.sexo) = sx.co_sexo

LEFT JOIN dim_raca_cor rc
    ON TRIM(s.racacor) = rc.co_raca_cor

LEFT JOIN dim_local_obito lo
    ON TRIM(s.lococor) = lo.co_local

WHERE
    TRIM(s.codmunres) IS NOT NULL
    AND TRIM(s.codmunres) != '000000'
    AND REGEXP_LIKE(TRIM(s.codmunres), '^[0-9]+$')
    AND REGEXP_LIKE(s.dtobito, '^\d{8}$')   -- guard contra datas inválidas (ex: 00000000)
    AND TRIM(s.tipobito) = '2';             -- apenas óbitos não-fetais

COMMIT;

-- Verificações obrigatórias após a carga:
SELECT COUNT(*) FROM fato_obito;
-- Esperado: ~1.463.000

SELECT
    COUNT(*)                                        AS total_obitos,
    SUM(fl_dcv)                                     AS obitos_dcv,
    ROUND(SUM(fl_dcv) * 100.0 / COUNT(*), 2)        AS pct_dcv
FROM fato_obito;
-- Esperado: pct_dcv ~25-26%

-- Integridade referencial — nenhuma das queries abaixo deve retornar qtd > 0
SELECT 'sk_municipio orfao' AS problema, COUNT(*) AS qtd FROM fato_obito f
WHERE NOT EXISTS (SELECT 1 FROM dim_municipio m WHERE m.sk_municipio = f.sk_municipio)
UNION ALL
SELECT 'sk_data orfao', COUNT(*) FROM fato_obito f
WHERE NOT EXISTS (SELECT 1 FROM dim_data d WHERE d.sk_data = f.sk_data)
UNION ALL
SELECT 'sk_causa orfao', COUNT(*) FROM fato_obito f
WHERE NOT EXISTS (SELECT 1 FROM dim_causa_morte c WHERE c.sk_causa = f.sk_causa);
