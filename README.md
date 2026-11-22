# PNAD Contínua — Data Processing and Indicators

A collection of **R** and **Stata** programs used to prepare and analyze microdata from the **Continuous National Household Sample Survey (PNAD Contínua)**, conducted by the Brazilian Institute of Geography and Statistics (IBGE).

The repository brings together two independent applications: **(1)** importing microdata and constructing a longitudinal person-level panel in Stata, and **(2)** converting microdata to Parquet and computing time series of indicators in R. The programs in the two languages do not form a single execution pipeline.

## Repository Structure

```text
.
├── docs/
│   └── Stivali (2020) - Painel PNADC.pdf
├── indicadores/
│   ├── indicadores.Rproj
│   └── serie_rd_taxa_desemprego.R
├── leitura/
│   ├── R/
│   │   ├── importa_PNADC_anual_parquet.R
│   │   └── importa_PNADC_trimestral_parquet.R
│   └── stata/
│       ├── importa_pnadc_trimestre.do
│       ├── importa_pnadc_todos_trimestres.do
│       ├── painel_pnadc.do
│       └── pnadc.dct
└── outputs/
    ├── desemprego_anual.png
    ├── desemprego_trimestral.png
    ├── graf_perdas_pnadc.png
    ├── taxas_desemprego_anual.csv
    └── taxas_desemprego_trimestral.csv
```

The tree shows files intended for version control. Local configuration files, R history files, and binary results (`.rds`) are excluded from Git.

## Stata Programs: Importing Microdata and Building a Panel

The programs in `leitura/stata/` import quarterly microdata and construct identifiers to investigate the longitudinal tracking of individuals in the survey.

| Program | Purpose |
| --- | --- |
| `importa_pnadc_trimestre.do` | Imports one quarter of fixed-width TXT microdata using a Stata dictionary. |
| `importa_pnadc_todos_trimestres.do` | Automates the import of available quarterly files. |
| `painel_pnadc.do` | Appends quarterly datasets, constructs identifiers, and prepares the person-level panel. |
| `pnadc.dct` | Dictionary for reading the fixed-width files. |

Household identifiers are constructed from sampling and dwelling variables; person identifiers combine sex and date-of-birth information. The procedure identifies and removes observations with non-unique person identifiers within the same quarter. **Longitudinal matching is approximate:** changes or errors in reported information may lead to incorrect matches or lost observations.

The methodology is discussed in [`docs/Stivali (2020) - Painel PNADC.pdf`](docs/Stivali%20%282020%29%20-%20Painel%20PNADC.pdf) (*PNAD Contínua Panel*). The chart [`graf_perdas_pnadc.png`](outputs/graf_perdas_pnadc.png) shows observation losses associated with non-unique identifiers.

**Dictionary compatibility:** microdata layouts may change across releases. The `pnadc.dct` dictionary must be checked against the TXT files being processed. An import can complete without errors while still interpreting fields incorrectly.

## R Programs: Parquet Conversion and Indicator Series

### Microdata Conversion

| Program | Purpose |
| --- | --- |
| `leitura/R/importa_PNADC_anual_parquet.R` | Reads annual microdata with `PNADcIBGE` and saves them in Parquet format. |
| `leitura/R/importa_PNADC_trimestral_parquet.R` | Reads quarterly microdata with `PNADcIBGE` and saves them in Parquet format. |

The programs use `arrow` to write the files and sort records before writing to improve compression. Their purpose is to **avoid repeatedly parsing fixed-width TXT files** when analyses span many periods.

The annual series uses **first-interview (V1)** files, except for **2020 and 2021**, when **fifth-interview (V5)** files are used. Import specifications must match the versions of the TXT files available locally.

### Indicator Estimation

The program [`indicadores/serie_rd_taxa_desemprego.R`](indicadores/serie_rd_taxa_desemprego.R) uses the previously generated Parquet files, selects the necessary columns with `arrow`, loads those columns into memory, and constructs the survey design using `PNADcIBGE::pnadc_design()`. Ratios are estimated using `survey::svyratio()`.

It produces **annual and quarterly** series for:

- **Overall unemployment rate:** unemployed persons divided by persons in the labor force.
- **Youth unemployment rate:** the same ratio for people aged **14–23**.
- **Older persons' unemployment rate:** the same ratio for people aged **65 or older**.
- **Demographic dependency ratio used in this exercise:** population younger than 14 or older than 65 divided by the population aged 14–65, inclusive. This particular definition is retained to match the original code and should not be confused with other conventions for dependency ratios.

Rates are stored as proportions in the CSV files and displayed as percentages in the charts.

The original example and discussion are available in **[Stivali (2024), *Criando séries de indicadores a partir dos microdados da PNADC-IBGE* [Constructing Indicator Time Series from PNAD Contínua Microdata] (RPubs)](https://rpubs.com/mstivali/PNADCserie)**. Estimates produced from locally updated files may differ slightly from the results published in 2024.

### Available Outputs

- [Annual series (CSV)](outputs/taxas_desemprego_anual.csv) and [annual chart](outputs/desemprego_anual.png).
- [Quarterly series (CSV)](outputs/taxas_desemprego_trimestral.csv) and [quarterly chart](outputs/desemprego_trimestral.png).
- [Chart of observation losses during panel construction](outputs/graf_perdas_pnadc.png).

CSV files and charts are included so that results can be inspected without downloading the microdata. RDS files used locally are not versioned.

## Requirements and Execution

**Data:** obtain PNAD Contínua microdata and the corresponding input specifications or dictionaries from the official [IBGE](https://www.ibge.gov.br/) sources. Raw microdata and generated Parquet files are not distributed in this repository.

**R:** requires `PNADcIBGE`, `survey`, `tidyverse`, and `arrow`. Run the relevant scripts in `leitura/R/` to generate the Parquet files, then run `indicadores/serie_rd_taxa_desemprego.R`.

The R scripts use the following paths, which must be adapted to the local directory structure:

```r
# Annual conversion
pnadc_anual_txt     <- "path/to/annual/txt"
pnadc_anual_input   <- "path/to/annual/input"
pnadc_anual_parquet <- "path/to/annual/parquet"

# Quarterly conversion
pnadc_trim_txt      <- "path/to/quarterly/txt"
pnadc_trim_input    <- "path/to/quarterly/input"
pnadc_trim_parquet  <- "path/to/quarterly/parquet"

# Indicators
pnadc_resultados    <- "path/to/outputs"
```

**Stata:** the programs require access to the quarterly TXT files and the `pnadc.dct` dictionary. Before running them, define the directories required by the `.do` files in a local configuration file (`config.do`) and execute that file in the Stata session. To build the panel, first import the quarterly files and then run `painel_pnadc.do`.

> **Configuration note:** some R scripts currently contain absolute paths assigned directly in the source code. Adjust these paths when running the code on another computer. Before publishing the scripts, replace machine-specific assignments with local configuration settings.

## Scope and Limitations

This repository provides **research code and empirical applications**, not an R package or a ready-to-use harmonized dataset. Annual and quarterly microdata differ in structure and sampling weights. Exact numerical reproduction depends on the IBGE data releases, input specifications, and software environment. Panel construction in Stata and indicator estimation in R are separate procedures.
