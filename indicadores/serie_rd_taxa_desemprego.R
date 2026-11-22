###############################################################################
#
#  PNAD CONTÍNUA - SÉRIES DE DESEMPREGO E RAZÃO DE DEPENDÊNCIA
#
#   Autor: Matheus Stivali
#   Versão inicial: 17/10/2024
#
#  Objetivo:
#   Calcular séries anuais e trimestrais da taxa de desocupação
#   geral, de jovens (14 a 23 anos), de idosos (65 anos ou mais)
#   e da razão de dependência demográfica.
#
#  Entradas:
#   - Microdados anuais e trimestrais em formato Parquet
#
#  Saídas:
#   - Séries de taxas de desocupação e razão de dependência
#     em formatos RDS e CSV
#   - Gráficos das taxas de desocupação geral, de jovens
#     e de idosos
#
#  Observações:
#   - Utiliza o desenho amostral definido pelo PNADcIBGE.
#   - Processa os arquivos sequencialmente, selecionando apenas
#     as variáveis necessárias antes de carregá-las na memória.
#   - Os diretórios devem ser definidos previamente no ambiente R.
#
#  Referência:
#   Stivali (2024). Criando séries de indicadores a partir dos
#   microdados da PNADC-IBGE. RPubs.
#   https://rpubs.com/mstivali/PNADCserie
#
###############################################################################

library("PNADcIBGE")
library("survey")
library("tidyverse")
library("arrow")


###############################################################################
## Configuração
###############################################################################

## Pré-requisitos:
## pnadc_anual_parquet - diretório dos arquivos anuais
## pnadc_trim_parquet  - diretório dos arquivos trimestrais
## pnadc_resultados    - diretório para salvar os resultados

pnadc_anual_parquet <- "D:/Data/PNADC/Anual/parquet"
pnadc_trim_parquet <- "D:/Data/PNADC/Trimestral/parquet"
pnadc_resultados <- "D:/Dropbox/Programas/github/pnad/outputs"

###############################################################################
## Variáveis necessárias para o desenho amostral
###############################################################################

## Microdados anuais
vars_plano_a <- c(
  "Ano", "Trimestre", "UF", "UPA", "Estrato",
  "V1008", "V1014", "V1030", "V1031",
  "V1032", "V1034", "posest", "posest_sxi",
  "V2003", "ID_DOMICILIO",
  sprintf("V1032%03d", 1:200)
)

## Microdados trimestrais
vars_plano_t <- c(
  "Ano", "Trimestre", "UF", "UPA", "Estrato",
  "V1008", "V1014", "V1027", "V1028",
  "V1029", "V1033", "posest", "posest_sxi",
  "V2003", "ID_DOMICILIO",
  sprintf("V1028%03d", 1:200)
)


###############################################################################
## Função para o cálculo dos indicadores
###############################################################################

calcula_indicadores <- function(arquivo, tipo = c("anual", "trimestral")) {
  
  tipo <- match.arg(tipo)
  
  vars_plano <- if (tipo == "anual") vars_plano_a else vars_plano_t
  
  ## Seleciona apenas as variáveis utilizadas
  dados <- arrow::open_dataset(arquivo, format = "parquet") %>%
    select(all_of(c("V2009", "VD4001", "VD4002",
                    vars_plano))) %>%
    collect() %>%
    mutate(
      dependentes = as.integer(V2009 < 14 | V2009 > 65),
      PIA = as.integer(V2009 >= 14 & V2009 <= 65)
    )
  
  ## Constrói o objeto do desenho amostral
  desenho <- PNADcIBGE::pnadc_design(dados)
  
  ## Função auxiliar para extrair uma razão estimada
  estima_razao <- function(design, numerador, denominador) {
    
    estimativa <- survey::svyratio(
      numerator = numerador,
      denominator = denominador,
      design = design,
      na.rm = TRUE
    )
    
    as.numeric(coef(estimativa)[1])
  }
  
  ## Taxa de desocupação geral
  geral <- estima_razao(
    desenho,
    ~ I(VD4002 == 2),
    ~ I(VD4001 == 1)
  )
  
  ## Taxa de desocupação de jovens (14 a 23 anos)
  jovens <- estima_razao(
    subset(desenho, V2009 >= 14 & V2009 <= 23),
    ~ I(VD4002 == 2),
    ~ I(VD4001 == 1)
  )
  
  ## Taxa de desocupação de idosos (65 anos ou mais)
  idosos <- estima_razao(
    subset(desenho, V2009 >= 65),
    ~ I(VD4002 == 2),
    ~ I(VD4001 == 1)
  )
  
  ## Razão de dependência demográfica
  rdt <- estima_razao(
    desenho,
    ~ I(dependentes == 1),
    ~ I(PIA == 1)
  )
  
  ## Retorna os resultados
  tibble(
    ano = as.integer(unique(dados$Ano)),
    trimestre = if (tipo == "trimestral") {
      as.integer(unique(dados$Trimestre))
    } else {
      NA_integer_
    },
    geral = geral,
    jovens = jovens,
    idosos = idosos,
    rdt = rdt
  )
}


###############################################################################
## Série anual
###############################################################################

arquivos_anuais <- list.files(
  pnadc_anual_parquet,
  pattern = "^PNADC_[0-9]{4}_A[15]\\.parquet$",
  recursive = TRUE,
  full.names = TRUE
)

## Mantém V5 para 2020 e 2021 e V1 para os demais anos
nomes_anuais <- basename(arquivos_anuais)
anos_anuais <- as.integer(substr(nomes_anuais, 7, 10))
visitas_anuais <- as.integer(substr(nomes_anuais, 13, 13))

arquivos_anuais <- arquivos_anuais[
  (anos_anuais %in% c(2020, 2021) & visitas_anuais == 5) |
    (!(anos_anuais %in% c(2020, 2021)) & visitas_anuais == 1)]


taxas_desemprego_anual <- purrr::map_dfr(
  sort(arquivos_anuais),
  function(arquivo) {
    message("Processando: ", basename(arquivo))
    resultado <- calcula_indicadores(arquivo, "anual")
    gc()
    resultado
  }
) %>%
  arrange(ano) %>%
  select(-trimestre)

saveRDS(
  taxas_desemprego_anual,
  file.path(pnadc_resultados, "taxas_desemprego_anual.rds")
)

write_csv(
  taxas_desemprego_anual,
  file.path(pnadc_resultados, "taxas_desemprego_anual.csv")
)


###############################################################################
## Série trimestral
###############################################################################

arquivos_trimestrais <- list.files(
  pnadc_trim_parquet,
  pattern = "^PNADC_[0-9]{4}_T[1-4]\\.parquet$",
  full.names = TRUE
)

if (length(arquivos_trimestrais) == 0) {
  stop("Nenhum arquivo trimestral encontrado.")
}

taxas_desemprego_trim <- purrr::map_dfr(
  sort(arquivos_trimestrais),
  function(arquivo) {
    message("Processando: ", basename(arquivo))
    resultado <- calcula_indicadores(arquivo, "trimestral")
    gc()
    resultado
  }
) %>%
  arrange(ano, trimestre)

saveRDS(
  taxas_desemprego_trim,
  file.path(pnadc_resultados, "taxas_desemprego_trimestral.rds")
)

write_csv(
  taxas_desemprego_trim,
  file.path(pnadc_resultados, "taxas_desemprego_trimestral.csv")
)


###############################################################################
## Gráficos das taxas de desocupação
###############################################################################

taxas_desemprego_anual <- readRDS(file.path(pnadc_resultados, 
                                            "taxas_desemprego_anual.rds"))

taxas_desemprego_trim <- readRDS(file.path(pnadc_resultados, 
                                           "taxas_desemprego_trimestral.rds"))

## Função para criar o gráfico
grafico_desemprego <- function(dados, periodicidade) {
  
  if (periodicidade == "anual") {
    dados <- dados %>% mutate(periodo = ano)
  } else {
    dados <- dados %>%
      mutate(periodo = ano + (trimestre - 1) / 4)
  }
  
  dados %>%
    select(periodo, geral, jovens, idosos) %>%
    pivot_longer(
      cols = c(geral, jovens, idosos),
      names_to = "grupo",
      values_to = "taxa"
    ) %>%
    mutate(
      grupo = factor(
        grupo,
        levels = c("geral", "jovens", "idosos"),
        labels = c("Geral", "Jovens (14–23)",
                   "Idosos (65+)")
      )
    ) %>%
    ggplot(aes(x = periodo, y = taxa * 100,
               color = grupo)) +
    geom_line(linewidth = 0.8) +
    labs(
      title = paste("Taxa de desocupação - PNAD Contínua",
                    periodicidade),
      x = "Ano",
      y = "Taxa de desocupação (%)",
      color = NULL
    ) +
    theme_minimal() +
    theme(legend.position = "bottom")
}

grafico_anual <- grafico_desemprego(taxas_desemprego_anual, 
                                    "anual")

grafico_trimestral <- grafico_desemprego(taxas_desemprego_trim, 
                                         "trimestral")

ggsave(
  file.path(pnadc_resultados, "desemprego_anual.png"),
  grafico_anual, width = 10, height = 5, dpi = 300
)

ggsave(
  file.path(pnadc_resultados, "desemprego_trimestral.png"),
  grafico_trimestral, width = 10, height = 5, dpi = 300
)

print(grafico_anual)
print(grafico_trimestral)
