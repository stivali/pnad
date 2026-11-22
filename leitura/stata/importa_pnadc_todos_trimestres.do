/*******************************************************************/
/*                                                                 */
/* PNAD CONTÍNUA - LEITURA AUTOMATIZADA DOS MICRODADOS TRIMESTRAIS */
/*                                                                 */
/* Autor: Matheus Stivali										   */
/*                                                                 */
/* Objetivo:													   */
/*   Importar os microdados trimestrais da PNAD Contínua (IBGE)    */
/*   disponíveis no diretório de origem, aplicar rótulos às        */
/*   variáveis selecionadas e construir identificadores de         */
/*   domicílio e pessoa.                                           */
/*                                                                 */
/* Entradas:													   */	
/*   - Microdados trimestrais em formato TXT					   */
/*   - Dicionário de leitura do Stata (pnadc.dct)				   */
/*                                                                 */
/* Saída:														   */
/*   - Arquivo Stata (.dta) correspondente ao trimestre			   */
/*                                                                 */
/* Identificadores: 											   */
/*   DOM = UPA + V1008 + V1014									   */
/*   PES = sexo + dia + mês + ano de nascimento					   */
/*                                                                 */
/* Observações:													   */	
/*  - Os arquivos são identificados automaticamente no diretório.  */
/*   - O programa não exige uma sequência completa de trimestres.  */
/*   - PES é uma chave auxiliar para pareamento longitudinal e     */
/*     não garante identificação única em todos os domicílios.     */
/*   - Os identificadores são preservados como strings.            */
/*   - Os diretórios são definidos em arquivo local não versionado.*/
/*                                                                 */
/*******************************************************************/

clear all
set more off, permanently

* Lista os arquivos disponíveis para leitura
local arquivos : dir "$pnadc_txt" files "PNADC_0*.txt", respectcase

* Verifica a quantidade de arquivos encontrados
local n_arquivos : word count `arquivos'
display "Arquivos encontrados: `n_arquivos'"
display `"`arquivos'"'


foreach arquivo of local arquivos {
	* Extrai ano e trimestre do nome do arquivo
	local trimestre = substr("`arquivo'", 8, 1)
	local ano       = substr("`arquivo'", 9, 4)

	display "Processando: `arquivo'"
	
	clear
	infile using "$pnadc_dic/pnadc.dct", using("$pnadc_txt/`arquivo'")
	
	/*******************************************************************/
	/***                  Define Rótulos e Labels                    ***/
	/*******************************************************************/
	label define estados ///
				11	"Rondônia" ///
				12	"Acre" ///
				13	"Amazonas" ///
				14	"Roraima" ///
				15	"Pará" ///
				16	"Amapá" ///
				17	"Tocantins" ///
				21	"Maranhão" ///
				22	"Piauí" ///
				23	"Ceará" ///
				24	"Rio Grande do Norte" ///
				25	"Paraíba" ///
				26	"Pernambuco" ///
				27	"Alagoas" ///
				28	"Sergipe" ///
				29	"Bahia" ///
				31	"Minas Gerais" ///
				32	"Espírito Santo" ///
				33	"Rio de Janeiro" ///
				35	"São Paulo" ///
				41	"Paraná" ///
				42	"Santa Catarina" ///
				43	"Rio Grande do Sul" ///
				50	"Mato Grosso do Sul" ///
				51	"Mato Grosso" ///
				52	"Goiás" ///
				53	"Distrito Federal"
	label define condomi ///
				01 "Pessoa responsável pelo domicílio " ///
				02 "Cônjuge ou companheiro(a) de sexo diferente" ///
				03 "Cônjuge ou companheiro(a) do mesmo sexo" ///
				04 "Filho(a) do responsável e do cônjuge " ///
				05 "Filho(a) somente do responsável" ///
				06 "Enteado(a)" ///
				07 "Genro ou nora" ///
				08 "Pai, mãe, padrasto ou madrasta" ///
				09 "Sogro(a)" ///
				10 "Neto(a)" ///
				11 "Bisneto(a) " ///
				12 "Irmão ou irmã" ///
				13 "Avô ou avó" ///
				14 "Outro parente" ///
				15 "Agregado(a) - Não parente que não compartilha despesas" ///
				16 "Convivente - Não parente que compartilha despesas" ///
				17 "Pensionista" ///
				18 "Empregado(a) doméstico(a)" ///
				19 "Parente do(a) empregado(a) doméstico(a)"
	label define sex 1 "Homem" 2 "Mulher"
	label define corraca 1 "Branca" 2 "Preta" 3 "Amarela" 4 "Parda" 5 "Indígena" 9 "Ignorado"
	label values UF estados
	label values V2005 condomi
	label values V2007 sex
	label values V2010 corraca
	format UPA %9.0f
	
	/***********************************************************/
	/***       Identificadores de domicílio e pessoa         ***/
	/***********************************************************/

	generate UPAs   = string(UPA, "%09.0f")
	generate V1008s = string(V1008, "%02.0f")
	generate V1014s = string(V1014, "%02.0f")
	egen DOM = concat(UPAs V1008s V1014s)

	generate sexos   = string(V2007, "%1.0f")
	generate V2008s  = string(V2008, "%02.0f")
	generate V20081s = string(V20081, "%02.0f")
	generate V20082s = string(V20082, "%04.0f")
	egen PES = concat(sexos V2008s V20081s V20082s)

	drop UPAs V1008s V1014s sexos V2008s V20081s V20082s
	
	
	/***********************************************************/
	/***          Salva o arquivo processado                 ***/
	/***********************************************************/
	
	save "$pnadc_dta/PNADC_`ano'_`trimestre'.dta", replace
	
	display "Concluído: PNADC_`ano'_`trimestre'.dta"
}


