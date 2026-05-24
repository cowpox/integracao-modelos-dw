-- =============================================================
-- 02_dimensoes.sql
-- Criação e carga das dimensões do esquema estrela
-- Executar conectado como dw_dcv
-- Ordem obrigatória: dims estáticas -> DIM_DATA -> DIM_CAUSA_MORTE
--                    -> DIM_MUNICIPIO -> DIM_ESTABELECIMENTO
-- Dependências: STG_MORTALIDADE, STG_MACROREGIAO, STG_CNES_JSON
-- =============================================================


-- -------------------------------------------------------------
-- DIM_SEXO — domínio fixo (dicionário SIM)
-- -------------------------------------------------------------
CREATE TABLE dim_sexo (
    sk_sexo  NUMBER(3)    PRIMARY KEY,
    co_sexo  CHAR(1)      NOT NULL,
    ds_sexo  VARCHAR2(20) NOT NULL
);

INSERT INTO dim_sexo VALUES (1, '1', 'Masculino');
INSERT INTO dim_sexo VALUES (2, '2', 'Feminino');
INSERT INTO dim_sexo VALUES (9, '9', 'Ignorado');
COMMIT;

SELECT COUNT(*) FROM dim_sexo;
-- Esperado: 3


-- -------------------------------------------------------------
-- DIM_RACA_COR — domínio fixo (dicionário SIM)
-- -------------------------------------------------------------
CREATE TABLE dim_raca_cor (
    sk_raca_cor  NUMBER(3)    PRIMARY KEY,
    co_raca_cor  CHAR(1)      NOT NULL,
    ds_raca_cor  VARCHAR2(30) NOT NULL
);

INSERT INTO dim_raca_cor VALUES (1, '1', 'Branca');
INSERT INTO dim_raca_cor VALUES (2, '2', 'Preta');
INSERT INTO dim_raca_cor VALUES (3, '3', 'Amarela');
INSERT INTO dim_raca_cor VALUES (4, '4', 'Parda');
INSERT INTO dim_raca_cor VALUES (5, '5', 'Indígena');
INSERT INTO dim_raca_cor VALUES (9, '9', 'Ignorada');
COMMIT;

SELECT COUNT(*) FROM dim_raca_cor;
-- Esperado: 6


-- -------------------------------------------------------------
-- DIM_LOCAL_OBITO — domínio fixo (dicionário SIM)
-- -------------------------------------------------------------
CREATE TABLE dim_local_obito (
    sk_local      NUMBER(3)    PRIMARY KEY,
    co_local      CHAR(1)      NOT NULL,
    ds_local      VARCHAR2(50) NOT NULL,
    fl_hospitalar NUMBER(1)    DEFAULT 0
);

INSERT INTO dim_local_obito VALUES (1, '1', 'Hospital',                      1);
INSERT INTO dim_local_obito VALUES (2, '2', 'Domicílio',                     0);
INSERT INTO dim_local_obito VALUES (3, '3', 'Via pública',                   0);
INSERT INTO dim_local_obito VALUES (4, '4', 'Outros',                        0);
INSERT INTO dim_local_obito VALUES (5, '5', 'Aldeia indígena',               0);
INSERT INTO dim_local_obito VALUES (6, '6', 'Estabelecimento social/penal',  0);
INSERT INTO dim_local_obito VALUES (9, '9', 'Ignorado',                      0);
COMMIT;

SELECT COUNT(*) FROM dim_local_obito;
-- Esperado: 7


-- -------------------------------------------------------------
-- DIM_DATA — calendário 2020-2025 gerado por script
-- -------------------------------------------------------------
CREATE TABLE dim_data (
    sk_data         NUMBER(8)    PRIMARY KEY,  -- formato YYYYMMDD
    dt_completa     DATE         NOT NULL,
    nr_ano          NUMBER(4),
    nr_mes          NUMBER(2),
    nr_dia          NUMBER(2),
    nr_trimestre    NUMBER(1),
    nr_semestre     NUMBER(1),
    ds_mes          VARCHAR2(15),
    fl_ano_bissexto NUMBER(1)
);

INSERT INTO dim_data
SELECT
    TO_NUMBER(TO_CHAR(dt, 'YYYYMMDD'))                                AS sk_data,
    dt                                                                AS dt_completa,
    TO_NUMBER(TO_CHAR(dt, 'YYYY'))                                    AS nr_ano,
    TO_NUMBER(TO_CHAR(dt, 'MM'))                                      AS nr_mes,
    TO_NUMBER(TO_CHAR(dt, 'DD'))                                      AS nr_dia,
    CEIL(TO_NUMBER(TO_CHAR(dt, 'MM')) / 3.0)                          AS nr_trimestre,
    CASE WHEN TO_NUMBER(TO_CHAR(dt, 'MM')) <= 6 THEN 1 ELSE 2 END    AS nr_semestre,
    TO_CHAR(dt, 'Month', 'NLS_DATE_LANGUAGE=PORTUGUESE')              AS ds_mes,
    CASE WHEN MOD(TO_NUMBER(TO_CHAR(dt,'YYYY')),4) = 0
          AND (MOD(TO_NUMBER(TO_CHAR(dt,'YYYY')),100) != 0
            OR MOD(TO_NUMBER(TO_CHAR(dt,'YYYY')),400) = 0)
         THEN 1 ELSE 0 END                                            AS fl_ano_bissexto
FROM (
    SELECT DATE '2020-01-01' + LEVEL - 1 AS dt
    FROM DUAL
    CONNECT BY LEVEL <= DATE '2025-12-31' - DATE '2020-01-01' + 1
);
COMMIT;

SELECT COUNT(*) FROM dim_data;
-- Esperado: 2192 (6 anos * 365/366 dias)


-- -------------------------------------------------------------
-- DIM_CAUSA_MORTE — derivada do DISTINCT de CAUSABAS na staging
-- -------------------------------------------------------------
CREATE TABLE dim_causa_morte (
    sk_causa        NUMBER(8)     PRIMARY KEY,
    co_cid10        VARCHAR2(5)   NOT NULL UNIQUE,
    ds_cid10        VARCHAR2(200),
    co_capitulo_cid CHAR(1),
    ds_capitulo_cid VARCHAR2(100),
    fl_dcv          NUMBER(1) DEFAULT 0,
    fl_respiratoria NUMBER(1) DEFAULT 0,
    fl_neoplasia    NUMBER(1) DEFAULT 0,
    fl_externa      NUMBER(1) DEFAULT 0
);

INSERT INTO dim_causa_morte (
    sk_causa, co_cid10, co_capitulo_cid, ds_capitulo_cid,
    fl_dcv, fl_respiratoria, fl_neoplasia, fl_externa
)
SELECT
    ROWNUM,
    co_cid10,
    SUBSTR(co_cid10, 1, 1) AS co_capitulo_cid,
    CASE SUBSTR(co_cid10, 1, 1)
        WHEN 'A' THEN 'Doenças infecciosas e parasitárias'
        WHEN 'B' THEN 'Doenças infecciosas e parasitárias'
        WHEN 'C' THEN 'Neoplasias'
        WHEN 'D' THEN 'Neoplasias / Sangue'
        WHEN 'E' THEN 'Doenças endócrinas e metabólicas'
        WHEN 'F' THEN 'Transtornos mentais'
        WHEN 'G' THEN 'Doenças do sistema nervoso'
        WHEN 'H' THEN 'Doenças do olho / ouvido'
        WHEN 'I' THEN 'Doenças do aparelho circulatório'
        WHEN 'J' THEN 'Doenças do aparelho respiratório'
        WHEN 'K' THEN 'Doenças do aparelho digestivo'
        WHEN 'L' THEN 'Doenças da pele'
        WHEN 'M' THEN 'Doenças do sistema osteomuscular'
        WHEN 'N' THEN 'Doenças do aparelho geniturinário'
        WHEN 'O' THEN 'Gravidez, parto e puerpério'
        WHEN 'P' THEN 'Afecções perinatais'
        WHEN 'Q' THEN 'Malformações congênitas'
        WHEN 'R' THEN 'Sintomas e sinais mal definidos'
        WHEN 'S' THEN 'Lesões e envenenamentos'
        WHEN 'T' THEN 'Causas externas (complementar)'
        WHEN 'V' THEN 'Causas externas'
        WHEN 'W' THEN 'Causas externas'
        WHEN 'X' THEN 'Causas externas'
        WHEN 'Y' THEN 'Causas externas'
        WHEN 'Z' THEN 'Fatores influenciando saúde'
        ELSE 'Ignorado / Não classificado'
    END AS ds_capitulo_cid,
    CASE WHEN REGEXP_LIKE(co_cid10, '^I[0-9]') THEN 1 ELSE 0 END AS fl_dcv,
    CASE WHEN REGEXP_LIKE(co_cid10, '^J[0-9]') THEN 1 ELSE 0 END AS fl_respiratoria,
    CASE WHEN REGEXP_LIKE(co_cid10, '^[CD][0-9]') THEN 1 ELSE 0 END AS fl_neoplasia,
    CASE WHEN REGEXP_LIKE(co_cid10, '^[VWXY][0-9]') THEN 1 ELSE 0 END AS fl_externa
FROM (
    SELECT DISTINCT TRIM(REPLACE(UPPER(causabas), '*', '')) AS co_cid10
    FROM stg_mortalidade
    WHERE TRIM(causabas) IS NOT NULL
      AND TRIM(causabas) NOT IN ('000', '999')
      -- ATENÇÃO: NÃO incluir '' no NOT IN — em Oracle '' = NULL,
      -- o que faria o filtro eliminar todas as linhas silenciosamente
);

-- Registro reservado para causa ignorada/não informada
INSERT INTO dim_causa_morte (sk_causa, co_cid10, co_capitulo_cid, ds_capitulo_cid)
VALUES (0, '999', '9', 'Causa ignorada ou não informada');
COMMIT;

SELECT COUNT(*) AS total_cids, SUM(fl_dcv) AS cids_dcv FROM dim_causa_morte;
-- Esperado: ~5.666 total, ~307 com fl_dcv=1


-- -------------------------------------------------------------
-- DIM_MUNICIPIO — hierarquia geográfica + população (fonte: XML)
-- -------------------------------------------------------------
CREATE TABLE dim_municipio (
    sk_municipio    NUMBER(8)     PRIMARY KEY,
    co_ibge         CHAR(6)       NOT NULL UNIQUE,
    no_municipio    VARCHAR2(100),
    sg_uf           CHAR(2),
    no_uf           VARCHAR2(50),
    co_regiao_saude NUMBER(6),
    no_regiao_saude VARCHAR2(100),
    co_macro        NUMBER(6),
    no_macro        VARCHAR2(100),
    co_regiao_pais  NUMBER(2),
    no_regiao_pais  VARCHAR2(20),
    populacao_2022  NUMBER(10)
);

INSERT INTO dim_municipio (
    sk_municipio, co_ibge, no_municipio, sg_uf, no_uf,
    co_regiao_saude, no_regiao_saude,
    co_macro, no_macro,
    co_regiao_pais, no_regiao_pais,
    populacao_2022
)
SELECT
    ROWNUM,
    LPAD(TO_NUMBER(TRIM(co_ibge)), 6, '0'),
    TRIM(SUBSTR(no_municipio, 6)),   -- remove prefixo "UF - " que vem do XML
    sg_uf,
    no_uf,
    co_regiao_saude,
    no_regiao_saude,
    co_macro,
    no_macro,
    co_regiao_pais,
    no_regiao_pais,
    populacao_2022
FROM stg_macroregiao
WHERE TRIM(co_ibge) IS NOT NULL;
COMMIT;

SELECT COUNT(*) FROM dim_municipio;
-- Esperado: ~5.570


-- -------------------------------------------------------------
-- DIM_ESTABELECIMENTO — estrutura de saúde agregada por município
-- Outrigger: conecta via DIM_MUNICIPIO.co_ibge, não via FATO_OBITO
-- -------------------------------------------------------------
CREATE TABLE dim_estabelecimento (
    co_ibge         CHAR(6)   PRIMARY KEY,
    qtd_total       NUMBER(8) DEFAULT 0,
    qtd_hospitais   NUMBER(8) DEFAULT 0,
    qtd_amb_sus     NUMBER(8) DEFAULT 0,
    qtd_cirurgico   NUMBER(8) DEFAULT 0,
    fl_tem_hospital NUMBER(1) DEFAULT 0
);

INSERT INTO dim_estabelecimento
SELECT
    LPAD(TO_NUMBER(TRIM(co_ibge)), 6, '0')                                   AS co_ibge,
    COUNT(*)                                                                  AS qtd_total,
    SUM(CASE WHEN TRIM(st_atend_hospitalar) IN ('1','1.0') THEN 1 ELSE 0 END) AS qtd_hospitais,
    SUM(CASE WHEN UPPER(TRIM(co_ambulatorial_sus)) = 'SIM'  THEN 1 ELSE 0 END) AS qtd_amb_sus,
    SUM(CASE WHEN TRIM(st_centro_cirurgico) IN ('1','1.0')  THEN 1 ELSE 0 END) AS qtd_cirurgico,
    MAX(CASE WHEN TRIM(st_atend_hospitalar) IN ('1','1.0')  THEN 1 ELSE 0 END) AS fl_tem_hospital
FROM stg_cnes_json
WHERE TRIM(co_ibge) IS NOT NULL
  AND REGEXP_LIKE(TRIM(co_ibge), '^[0-9]+$')
GROUP BY LPAD(TO_NUMBER(TRIM(co_ibge)), 6, '0');
COMMIT;

SELECT COUNT(*) FROM dim_estabelecimento;
SELECT SUM(qtd_hospitais) AS total_hospitais FROM dim_estabelecimento;
-- Esperado: ~9.642 hospitais
