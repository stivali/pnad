###############################################################################
##
## PNAD CONTÍNUA - CONVERSÃO DOS MICRODADOS TRIMESTRAIS PARA PARQUET
##
## Autor: Matheus Stivali
## Versão inicial: 17/10/2024
##
## Objetivo:
##   Importar os microdados trimestrais da PNAD Contínua (IBGE)
##   utilizando o leiaute oficial e armazená-los em formato Parquet.
##
##   A conversão permite reutilizar os microdados em análises
##   posteriores, evitando a leitura repetida dos arquivos TXT,
##   especialmente na construção de séries históricas.
##
## Entradas:
##   - Microdados trimestrais da PNAD Contínua em formato TXT
##   - Arquivo de leiaute (input) disponibilizado pelo IBGE
##
## Saídas:
##   - Um arquivo Parquet para cada trimestre processado
##
## Observações:
##   - Os arquivos disponíveis são identificados automaticamente.
##   - Os registros são ordenados antes da gravação para favorecer
##     a compactação e a eficiência das consultas.
##   - O leiaute deve ser compatível com os microdados utilizados.
##   - Os diretórios são definidos previamente em arquivo local
##     de configuração.
##
###############################################################################

library("PNADcIBGE")
library("tidyverse")
library("arrow")


###############################################################################
## Configuração do processamento
###############################################################################

## Pré-requisito: definir os diretórios no ambiente R
## antes de executar este programa:
##
## pnadc_trim_txt     - diretório dos arquivos TXT
## pnadc_trim_input   - diretório do arquivo de leiaute
## pnadc_trim_parquet - diretório de saída dos Parquets

pnadc_trim_txt <- "D:/Data/PNADC/Trimestral/txt/"
pnadc_trim_input <- "D:/Data/PNADC/Trimestral/Documentacao/"
pnadc_trim_parquet <- "D:/Data/PNADC/Trimestral/parquet/"

## Leiaute dos microdados trimestrais
input_trimestral <- file.path(pnadc_trim_input,
                              "input_PNADC_trimestral.txt")


###############################################################################
## Identificação dos arquivos disponíveis
###############################################################################

arquivos_trim_txt <- list.files(
  path = pnadc_trim_txt,
  pattern = "^PNADC_0[1-4][0-9]{4}\\.txt$",
  full.names = TRUE,
  ignore.case = TRUE)

message("Arquivos encontrados: ", length(arquivos_trim_txt))


###############################################################################
## Leitura dos microdados e gravação em Parquet
###############################################################################

for (arquivo_txt in arquivos_trim_txt) {
  
  ## Extrai o trimestre e o ano do nome PNADC_0TAAAA.txt
  nome_arquivo <- basename(arquivo_txt)
  trimestre <- substr(nome_arquivo, 8, 8)
  ano <- substr(nome_arquivo, 9, 12)
  
  ## Define o arquivo de saída
  arquivo_parquet <- file.path(pnadc_trim_parquet,
                               paste0("PNADC_", ano, "_T", trimestre, ".parquet"))
  
  message("Processando PNADC ", ano, " - trimestre ", trimestre)
  
  PNAD <- PNADcIBGE::read_pnadc(
    microdata = arquivo_txt,
    input_txt = input_trimestral) %>%
    ## A ordenação melhora a compactação
    arrange(Ano, Trimestre, UF, Capital, RM_RIDE,
            UPA, Estrato, V1008, V1014, V1022, V1023)
  
  ## Grava os microdados em formato Parquet
  arrow::write_parquet(
    PNAD,
    sink = arquivo_parquet,
    compression = "gzip",
    compression_level = 9)
  
  ## Libera a memória antes de processar o próximo trimestre
  rm(PNAD)
  gc()
  
  message("Arquivo gerado: ", arquivo_parquet)
}
