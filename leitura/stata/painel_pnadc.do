
/*******************************************************************/
/*                                                                 */
/* PNAD CONTÍNUA - CONSTRUÇÃO DO PAINEL DE PESSOAS                 */
/*                                                                 */
/* Autor: Matheus Stivali                                          */
/* Versão inicial 15/07/2020									   */
/*                                                                 */
/* Objetivo:                                                       */
/*   Construir um painel longitudinal de pessoas a partir dos      */
/*   microdados trimestrais da PNAD Contínua (IBGE), utilizando    */
/*   identificadores de domicílio e características individuais.   */
/*                                                                 */
/* Entradas:                                                       */
/*   - Arquivos trimestrais em formato Stata (.dta)                */
/*   - Identificadores DOM e PES criados na etapa de leitura       */
/*                                                                 */
/* Saída:                                                          */
/*   - Arquivo Stata (.dta) com o painel de pessoas                */
/*                                                                 */
/* Procedimentos:                                                  */
/*   - Empilhamento dos arquivos trimestrais                       */
/*   - Criação da variável de tempo (trimestre)                    */
/*   - Construção do identificador longitudinal ID                 */
/*   - Identificação e exclusão de observações duplicadas          */
/*   - Declaração da estrutura de painel com xtset                 */
/*                                                                 */
/* Observações:                                                    */
/*   - ID é construído a partir de DOM e PES após o empilhamento.  */
/*   - Observações sem identificação única em um trimestre são     */
/*     excluídas do painel.                                        */
/*   - O procedimento não corrige erros nas informações usadas    */
/*     para identificar pessoas entre diferentes entrevistas.     */
/*   - Os diretórios são definidos previamente em config.do.      */
/*                                                                 */
/* Referência:                                                     */
/*   Stivali (2020). Explicações gerais da PNAD-C e detalhamento  */
/*   da montagem do painel. Nota metodológica, Ipea.               */
/*                                                                 */
/*******************************************************************/

clear all
set more off, permanently

* Pré-requisito: executar config.do anteriormente

* Definir aqui o começo e o fim do painel
* Para começar e acabar em trimestres específicos é necessário 
* Ajustar o código
local ano_inicio = 2012
local ano_fim    = 2022

* Lista os arquivos trimestrais processados
local arquivos : dir "$pnadc_dta" files "PNADC_*.dta", respectcase
local n_arquivos : word count `arquivos'
display "Arquivos encontrados: `n_arquivos'"


local primeiro = 1
foreach arquivo of local arquivos {

    * Extrai ano e trimestre do nome PNADC_AAAA_T.dta
    local ano = real(substr("`arquivo'", 7, 4))

    if inrange(`ano', `ano_inicio', `ano_fim') {

        display "Incluindo: `arquivo'"

        if `primeiro' == 1 {
            use "$pnadc_dta/`arquivo'", clear
            local primeiro = 0
        }
        else {
            append using "$pnadc_dta/`arquivo'"
        }
    }
}

/****************************************/
/*     Criar variável de trimestre      */
/****************************************/
generate sAno = string(Ano)
generate sTrimestre = string(Trimestre)
generate sQuarter = sAno + "q" + sTrimestre
generate trime = quarterly(sQuarter, "YQ")
format trime %tq
drop sAno sTrimestre sQuarter

/****************************************/
/* Cria o identificador único de pessoa */
/****************************************/
sort DOM PES trime
egen ID = group(DOM PES)

/*******************************************************************/
/* Investigando casos sem identificação única                      */
/*                                                                 */
/* Nota metodológica:                                              */
/* Os microdados da PNAD Contínua foram atualizados pelo IBGE      */
/* desde a elaboração de Stivali (2020). Assim, os resultados      */
/* de identificação e perda amostral podem diferir dos valores     */
/* apresentados naquela nota.                                      */
/*                                                                 */
/* Diferenças também podem decorrer de alterações nos dicionários  */
/* e nos procedimentos de leitura e construção das chaves.         */
/*******************************************************************/

*isid ID trime
duplicates report ID trime
duplicates report DOM PES trime

duplicates tag ID trime, gen(repetido)
tabulate trime repetido


/* Quantifica a perda amostral por identificação não única        */
generate byte sem_id_unico = repetido > 0

preserve

collapse (count) total = ID ///
         (sum) excluidas = sem_id_unico, by(trime)

generate perda_pct = 100 * excluidas / total
format perda_pct %6.2f

* Exibe a tabela resumida
list trime total excluidas perda_pct, noobs

* Cria string legível do trimestre para eventual exportação
generate trimestre = string(trime, "%tq")
order trimestre total excluidas perda_pct

* Gera o gráfico das perdas
twoway ///
    (line perda_pct trime, sort), ///
    title("PNAD Contínua: perda amostral por identificação não única") ///
    subtitle("Painel de pessoas, `ano_inicio'T1-`ano_fim'T4") ///
    xtitle("Trimestre") ///
    ytitle("Perda amostral (%)") ///
    xlabel(#12, angle(45) format(%tq)) ///
    ylabel(0(1)8, format(%3.1f)) ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    legend(off) ///
    name(graf_perdas_pnadc, replace)

* Salva o gráfico
graph export "$outputs/graf_perdas_pnadc.png", replace width(2000)

restore



/****************************************************/
/* Excluindo observações sem identificação única    */
/****************************************************/

keep if repetido == 0
drop repetido sem_id_unico

/* Verifica a unicidade após a exclusão */
isid ID trime

/* Declara a estrutura longitudinal */
xtset ID trime, quarterly

/* Salva o painel de pessoas */
save "$pnadc_dta/Painel_PNADC.dta", replace
