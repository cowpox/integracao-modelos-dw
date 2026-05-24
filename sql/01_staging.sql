-- =============================================================
-- 01_staging.sql
-- Criação e carga das tabelas de staging (camada intermediária)
-- Executar conectado como dw_dcv
-- Ordem: STG_MORTALIDADE -> STG_CNES_RAW/JSON -> STG_MACROREGIAO_RAW/XML
-- =============================================================


-- -------------------------------------------------------------
-- STG_MORTALIDADE — CSV do SIM (todos os campos como VARCHAR2)
-- -------------------------------------------------------------
CREATE TABLE stg_mortalidade (
    contador     VARCHAR2(20),
    dtobito      VARCHAR2(8),    -- formato DDMMAAAA
    tipobito     VARCHAR2(2),    -- 1=fetal, 2=não-fetal
    codmunres    VARCHAR2(10),
    codmunocor   VARCHAR2(10),
    causabas     VARCHAR2(10),   -- CID-10 bruto (pode vir com asterisco: *I219)
    linhaa       VARCHAR2(200),
    linhab       VARCHAR2(200),
    linhac       VARCHAR2(200),
    linhad       VARCHAR2(200),
    sexo         VARCHAR2(2),
    idade        VARCHAR2(5),    -- codificado SIM: 1º dígito = unidade de tempo
    racacor      VARCHAR2(2),
    lococor      VARCHAR2(2),
    necropsia    VARCHAR2(2)
);

-- Carga via Import Data Wizard (SQL Developer) ou SQL*Loader
-- Delimitador: ; (ponto e vírgula)
-- Encoding: UTF8
-- Selecionar apenas as 15 colunas acima (CSV tem ~70 colunas)
-- Excluir coluna NATURAL (palavra reservada Oracle)

-- Verificação após carga:
SELECT COUNT(*) AS total FROM stg_mortalidade;
-- Esperado: ~1.507.424

SELECT
    COUNT(*)                                                         AS total,
    COUNT(CASE WHEN TRIM(causabas)  IS NULL THEN 1 END)             AS sem_causa,
    COUNT(CASE WHEN TRIM(codmunres) IS NULL
                 OR TRIM(codmunres) = '000000' THEN 1 END)          AS sem_municipio,
    COUNT(CASE WHEN NOT REGEXP_LIKE(dtobito, '^\d{8}$') THEN 1 END) AS data_invalida
FROM stg_mortalidade;
-- Esperado: sem_causa=0, sem_municipio=0, data_invalida=0


-- -------------------------------------------------------------
-- STG_CNES_RAW — receptora do JSON bruto como CLOB
-- -------------------------------------------------------------
CREATE TABLE stg_cnes_raw (
    id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    json_doc CLOB,
    CONSTRAINT chk_json CHECK (json_doc IS JSON)
);

-- Carga do arquivo JSON via PL/SQL (executar com F5)
DECLARE
    v_file          BFILE := BFILENAME('BRONZE_DIR', 'cnes_estabelecimentos.json');
    v_clob          CLOB;
    v_dest_offset   NUMBER := 1;
    v_src_offset    NUMBER := 1;
    v_lang_context  NUMBER := DBMS_LOB.DEFAULT_LANG_CTX;
    v_warning       NUMBER;
BEGIN
    DBMS_LOB.CREATETEMPORARY(v_clob, TRUE);
    DBMS_LOB.OPEN(v_file, DBMS_LOB.LOB_READONLY);
    DBMS_LOB.LOADCLOBFROMFILE(
        dest_lob     => v_clob,
        src_bfile    => v_file,
        amount       => DBMS_LOB.LOBMAXSIZE,
        dest_offset  => v_dest_offset,
        src_offset   => v_src_offset,
        bfile_csid   => NLS_CHARSET_ID('AL32UTF8'),
        lang_context => v_lang_context,
        warning      => v_warning
    );
    DBMS_LOB.CLOSE(v_file);
    INSERT INTO stg_cnes_raw (json_doc) VALUES (v_clob);
    COMMIT;
    DBMS_LOB.FREETEMPORARY(v_clob);
    DBMS_OUTPUT.PUT_LINE('JSON carregado. Warning: ' || v_warning);
END;
/


-- -------------------------------------------------------------
-- STG_CNES_JSON — JSON normalizado via JSON_TABLE
-- -------------------------------------------------------------
CREATE TABLE stg_cnes_json AS
SELECT jt.*
FROM stg_cnes_raw,
     JSON_TABLE(
         json_doc, '$[*]'
         COLUMNS (
             co_cnes             VARCHAR2(20)  PATH '$.CO_CNES',
             co_ibge             VARCHAR2(10)  PATH '$.CO_IBGE',
             no_fantasia         VARCHAR2(200) PATH '$.NO_FANTASIA',
             ds_esfera           VARCHAR2(50)  PATH '$.DS_ESFERA_ADMINISTRATIVA',
             tp_unidade          VARCHAR2(5)   PATH '$.TP_UNIDADE',
             st_atend_hospitalar VARCHAR2(5)   PATH '$.ST_ATEND_HOSPITALAR',
             st_ambulatorial     VARCHAR2(5)   PATH '$.ST_ATEND_AMBULATORIAL',
             st_centro_cirurgico VARCHAR2(5)   PATH '$.ST_CENTRO_CIRURGICO',
             co_ambulatorial_sus VARCHAR2(5)   PATH '$.CO_AMBULATORIAL_SUS',
             nu_latitude         VARCHAR2(30)  PATH '$.NU_LATITUDE',
             nu_longitude        VARCHAR2(30)  PATH '$.NU_LONGITUDE'
         )
     ) jt;

-- Verificação:
SELECT COUNT(*) FROM stg_cnes_json;
-- Esperado: ~612.561

SELECT DISTINCT LENGTH(TRIM(co_ibge)) AS comprimento_ibge
FROM stg_cnes_json ORDER BY 1;

SELECT tp_unidade, COUNT(*) AS qtd
FROM stg_cnes_json
GROUP BY tp_unidade
ORDER BY qtd DESC
FETCH FIRST 10 ROWS ONLY;


-- -------------------------------------------------------------
-- STG_MACROREGIAO_RAW — receptora do XML bruto como XMLTYPE
-- -------------------------------------------------------------
CREATE TABLE stg_macroregiao_raw (
    id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    xml_doc XMLTYPE
);

-- Carga do arquivo XML via PL/SQL (executar com F5)
DECLARE
    v_xml XMLTYPE;
BEGIN
    v_xml := XMLTYPE(
        BFILENAME('BRONZE_DIR', 'macroregiao_de_saude.xml'),
        NLS_CHARSET_ID('AL32UTF8')
    );
    INSERT INTO stg_macroregiao_raw (xml_doc) VALUES (v_xml);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('XML carregado com sucesso.');
END;
/


-- -------------------------------------------------------------
-- STG_MACROREGIAO — XML normalizado via XMLTABLE
-- -------------------------------------------------------------
CREATE TABLE stg_macroregiao AS
SELECT x.*
FROM stg_macroregiao_raw,
     XMLTABLE(
         '/Rows/Row'
         PASSING xml_doc
         COLUMNS
             co_regiao_pais   NUMBER        PATH 'co_regiao_pais',
             no_regiao_pais   VARCHAR2(20)  PATH 'regiao_pais',
             sg_uf            VARCHAR2(2)   PATH 'sg_uf',
             no_uf            VARCHAR2(50)  PATH 'uf',
             co_macro         NUMBER        PATH 'cod_macrorregiao_de_saude',
             no_macro         VARCHAR2(100) PATH 'macrorregiao_de_saude',
             co_regiao_saude  NUMBER        PATH 'cod_regiao_de_saude',
             no_regiao_saude  VARCHAR2(100) PATH 'regiao_de_saude',
             co_ibge          VARCHAR2(7)   PATH 'cod_municipio',
             no_municipio     VARCHAR2(100) PATH 'no_municipio',
             populacao_2022   NUMBER        PATH 'populacao_ibge_2022'
     ) x;

-- Verificação:
SELECT COUNT(*) FROM stg_macroregiao;
-- Esperado: ~5.570

SELECT COUNT(*) FROM stg_macroregiao WHERE populacao_2022 IS NULL;
-- Esperado: 0

SELECT DISTINCT no_regiao_pais FROM stg_macroregiao ORDER BY 1;
-- Esperado: Centro-Oeste, Nordeste, Norte, Sudeste, Sul
