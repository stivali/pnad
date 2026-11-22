###############################################################################
##
## PNAD CONTÍNUA - CONVERSÃO DOS MICRODADOS ANUAIS PARA PARQUET
##
## Autor: Matheus Stivali
## Versão inicial: 17/10/2024
##
## Objetivo:
##   Importar os microdados anuais da PNAD Contínua (IBGE) utilizando
##   os leiautes oficiais e armazená-los em formato Parquet.
##
##   A conversão permite reutilizar os microdados em análises
##   posteriores, evitando a leitura repetida dos arquivos TXT,
##   especialmente na construção de séries históricas.
##
## Entradas:
##   - Microdados anuais da PNAD Contínua em formato TXT
##   - Arquivos de leiaute (input) disponibilizados pelo IBGE
##
## Saídas:
##   - Um arquivo Parquet para cada ano processado
##
## Observações:
##   - Utiliza os dados anuais acumulados na primeira visita (V1).
##   - Para 2020 e 2021, utiliza os arquivos da quinta visita (V5),
##     conforme a disponibilidade dos microdados utilizados.
##   - Os leiautes variam entre os anos e devem ser compatíveis
##     com as versões dos microdados.
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
## pnadc_anual_txt     - diretório dos arquivos TXT
## pnadc_anual_input   - diretório dos arquivos de leiaute
## pnadc_anual_parquet - diretório de saída dos Parquets

pnadc_anual_txt <- "D:/Data/PNADC/Anual/txt/"
pnadc_anual_input <- "D:/Data/PNADC/Anual/Documentação/"
pnadc_anual_parquet <- "D:/Data/PNADC/Anual/parquet/"

anos <- 2012:2025

## Visita utilizada em cada ano
visitas <- ifelse(anos %in% c(2020, 2021), 5, 1)
names(visitas) <- as.character(anos)

###############################################################################
## Associação dos anos aos respectivos leiautes
###############################################################################

inputs_anuais <- c(
  "2012" = "input_PNADC_2012_a_2014_visita1_20220224.txt",
  "2013" = "input_PNADC_2012_a_2014_visita1_20220224.txt",
  "2014" = "input_PNADC_2012_a_2014_visita1_20220224.txt",
  "2015" = "input_PNADC_2015_visita1_20220224.txt",
  "2016" = "input_PNADC_2016_visita1_20220224.txt",
  "2017" = "input_PNADC_2017_visita1_20220224.txt",
  "2018" = "input_PNADC_2018_visita1_20220224.txt",
  "2019" = "input_PNADC_2019_visita1_20230811.txt",
  "2020" = "input_PNADC_2020_visita5_20220224.txt",
  "2021" = "input_PNADC_2021_visita5.txt",
  "2022" = "input_PNADC_2022_visita1_20231129.txt",
  "2023" = "input_PNADC_2023_visita1_20241220.txt",
  "2024" = "input_PNADC_2024_visita1_20251119.txt",
  "2025" = "input_PNADC_2025_visita1_20260923.txt"
)

###############################################################################
## Leitura dos microdados e gravação em Parquet
###############################################################################

for (ano in anos) {
  
  visita <- visitas[as.character(ano)]
  
  arquivo_txt <- file.path(pnadc_anual_txt,
                           paste0("PNADC_", ano, "_visita", visita, ".txt")
                           )
  
  arquivo_input <- file.path(pnadc_anual_input,
                             inputs_anuais[as.character(ano)])
  
  arquivo_parquet <- file.path(pnadc_anual_parquet,
                               paste0("V", visita),
                               paste0("PNADC_", ano, "_A", visita, ".parquet"))
  
  message("Processando PNADC ", ano, " - visita ", visita)
  
  ## Importa os microdados utilizando o leiaute correspondente
  PNAD <- PNADcIBGE::read_pnadc(microdata = arquivo_txt,
                                input_txt = arquivo_input) %>%
    ## A ordenação melhora a compactação e a velociade de consulta
    arrange(Ano, Trimestre, UF, Capital, RM_RIDE, UPA, Estrato,
            V1008, V1014, V1022, V1023)
  
  ## Grava os microdados em formato Parquet
  arrow::write_parquet(PNAD,
                       sink = arquivo_parquet,
                       compression = "gzip",
                       compression_level = 9)
  
  ## Libera a memória antes de processar o próximo ano
  rm(PNAD)
  gc()
  
  message("Arquivo gerado: ", arquivo_parquet)
}



