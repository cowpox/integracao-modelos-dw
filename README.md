# T1 — Data Warehouse: Mortalidade por DCV vs. Estrutura de Saúde

**Disciplina:** Integração e Preparação de Dados — UEL 2026  
**Aluno:** Adriano Lúcio Uchôa Brandão  
**Aluno:** Herik Daurizio Ricardo  
**Professor:** Daniel dos Santos Kaster

---

## Pergunta central

> Municípios com maior densidade de estabelecimentos de saúde apresentam menores taxas de mortalidade por Doenças Cardiovasculares (DCV)?

---

## Visão geral

Data Warehouse relacional construído no Oracle Database, integrando três fontes heterogêneas via ETL majoritariamente em SQL. O modelo analisa a relação entre mortalidade por DCV e infraestrutura hospitalar nos municípios brasileiros, usando dados de 2025.

**Tecnologias:** Oracle Database (SQL Developer) · SQL/JSON (`JSON_TABLE`) · SQL/XML (`XMLTABLE`) · PL/SQL

---

## Fontes de dados

| Dataset | Formato | Tamanho | Papel | Download |
|---|---|---|---|---|
| Mortalidade_Geral_2025 | CSV | 501 MB | Fonte da tabela fato — ~1,5 M óbitos | [Download](https://s3.sa-east-1.amazonaws.com/ckan.saude.gov.br/SIM/csv/Mortalidade_Geral_2025_csv.zip) |
| cnes_estabelecimentos | JSON | 581 MB | Estrutura de saúde por município (CNES) | [Download](https://s3.sa-east-1.amazonaws.com/ckan.saude.gov.br/CNES/cnes_estabelecimentos_json.zip) |
| macroregiao_de_saude | XML | 2,6 MB | Hierarquia geográfica + população 2022 | [Download](https://s3.sa-east-1.amazonaws.com/ckan.saude.gov.br/dbgeral/macroregiao_de_saude_xml.zip) |

> **Dicionário de dados SIM:** [Dicionario_SIM_2025.pdf](https://s3.sa-east-1.amazonaws.com/ckan.saude.gov.br/SIM/Dicionario_SIM_2025.pdf)
>
> **Nota:** os arquivos de dados não estão neste repositório por conta do tamanho. Todas as fontes são públicas (DATASUS / DataSUS CNES).

---

## Modelo dimensional

Esquema estrela com 1 tabela fato, 6 dimensões e 1 outrigger.

**Esquema estrela (8 tabelas DW):**

![Esquema estrela](mer/mer_dw_star_8_tables.png)

**Modelo completo com staging (13 tabelas):**

![Modelo completo com staging](mer/mer_dw_13_tables.png)

**Fluxo de importação das fontes:**

![Fluxo de importação](mer/mer_table_imports.png)

---

## Estrutura do repositório

```
├── sql/
│   ├── 00_schema.sql       # Schema dw_dcv, permissões, DIRECTORY Oracle
│   ├── 01_staging.sql      # STG_MORTALIDADE, STG_CNES_RAW/JSON, STG_MACROREGIAO_RAW/XML
│   ├── 02_dimensoes.sql    # DIM_SEXO, DIM_RACA_COR, DIM_LOCAL_OBITO, DIM_DATA,
│   │                       # DIM_CAUSA_MORTE, DIM_MUNICIPIO, DIM_ESTABELECIMENTO
│   ├── 03_fato.sql         # FATO_OBITO + verificações de integridade referencial
│   ├── 04_indices.sql      # Índices de performance + contagem geral das tabelas
│   ├── 05_consultas.sql    # Consultas analíticas Q1–Q6
│   └── 06_mv.sql           # Materialized View (Q7) + REFRESH
│
├── mer/
│   ├── mer_dw_star_8_tables.png    # Diagrama do esquema estrela
│   ├── mer_dw_13_tables.png        # Diagrama completo com staging
│   └── mer_table_imports.png       # Fluxo de importação das fontes
│
├── entrega_final.md            # Documento de entrega (texto + SQL + imagens)
├── Proposta do trabalho.png    # Enunciado original do trabalho
└── README.md
```

---

## Como executar

### Pré-requisitos

- Oracle Database (testado com Oracle XE / Oracle 21c+)
- SQL Developer (ou qualquer cliente Oracle)
- Acesso administrativo para criar usuário/schema

### Ordem de execução

Execute os scripts na sequência numérica dentro do SQL Developer:

| Script | Conexão | Modo |
|---|---|---|
| `00_schema.sql` (parte 1: CREATE USER) | (admin) | F5 |
| `00_schema.sql` (parte 2: teste JSON/XML) | `dw_dcv` | F9 |
| `01_staging.sql` | `dw_dcv` | F5 |
| `02_dimensoes.sql` | `dw_dcv` | F5 |
| `03_fato.sql` | `dw_dcv` | F5 (pode demorar alguns minutos) |
| `04_indices.sql` | `dw_dcv` | F5 |
| `05_consultas.sql` | `dw_dcv` | F9 (uma query por vez) |
| `06_mv.sql` | `dw_dcv` | F5 |

> **Atenção:** antes de executar `01_staging.sql`, a carga do CSV da Mortalidade deve ser feita separadamente pelo Import Data Wizard do SQL Developer (delimitador `;`, encoding UTF-8) ou pelo SQL*Loader — consulte `roteiro_implementacao_v2.md` para instruções detalhadas.

### Ajuste do DIRECTORY

Em `00_schema.sql`, atualize o caminho do `DIRECTORY` para apontar para a pasta onde estão os arquivos de dados:

```sql
CREATE OR REPLACE DIRECTORY BRONZE_DIR AS 'C:\seu\caminho\para\os\dados';
```

---

## Consultas analíticas

| # | Consulta | Técnica |
|---|---|---|
| Q1 | Evolução temporal de óbitos DCV por região | `GROUP BY + ROLLUP` |
| Q2 | Comparação por região, macrorregião e sexo | `CUBE` |
| Q3 | Taxa DCV × densidade hospitalar por município | Consulta principal |
| Q4 | Ranking de municípios por taxa DCV | `RANK() OVER (PARTITION BY)` |
| Q5 | Perfil dos óbitos: sexo, raça/cor, faixa etária | `CASE + GROUP BY + LAG` |
| Q6 | Variação mensal de óbitos por macrorregião | `LAG()` |
| Q7 | Resumo anual por macrorregião (pré-calculado) | `MATERIALIZED VIEW` |

---

## Resultados principais

- **1.505.609** óbitos em 2025; **382.363 (25,4%)** por DCV
- Pico de mortalidade DCV em julho (26,27%); queda em dezembro (subnotificação SIM)
- Homens morrem de DCV **~5 anos mais cedo** do que mulheres (universal em todas as macrorregiões)
- **73%** dos 30 municípios com maior taxa DCV não têm nenhum hospital — consistente com a hipótese
- RS domina o top 50 de municípios com maior taxa (~50% dos municípios)
