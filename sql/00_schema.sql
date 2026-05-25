-- =============================================================
-- 00_schema.sql
-- Criar schema dw_dcv e configurar DIRECTORY de arquivos
-- Executar conectado como (admin)
-- =============================================================

-- 1. Criar usuário/schema dedicado ao projeto
CREATE USER dw_dcv IDENTIFIED BY senha123
    DEFAULT TABLESPACE users
    TEMPORARY TABLESPACE temp;

GRANT CONNECT, RESOURCE TO dw_dcv;
GRANT CREATE VIEW TO dw_dcv;
GRANT CREATE MATERIALIZED VIEW TO dw_dcv;
GRANT UNLIMITED TABLESPACE TO dw_dcv;

-- 2. DIRECTORY apontando para a pasta com os arquivos de dados
--    (ajustar o caminho se necessário)
CREATE OR REPLACE DIRECTORY BRONZE_DIR AS
    'E:\Dropbox\UEL\3 Ano\Integração e Preparação de Dados\Atividades\T1-Integracao_modelos_DW\mort_dcv_bronze';

GRANT READ ON DIRECTORY BRONZE_DIR TO dw_dcv;

-- 3. Verificar suporte a JSON e XML (executar conectado como dw_dcv)
SELECT JSON_VALUE('{"teste":1}', '$.teste') AS resultado FROM DUAL;

SELECT v FROM XMLTABLE(
    '/r' PASSING XMLTYPE('<r><v>42</v></r>')
    COLUMNS v NUMBER PATH 'v'
);
