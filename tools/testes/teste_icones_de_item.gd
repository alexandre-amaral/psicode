extends TesteBase
## Amarra o loot a arte: os 16 implantes de `src/items/` e as 10 armas de
## prateleira de `src/weapons/`.
##
## A decisao de design que esta suite carrega: **o icone e opcional, e por isso
## precisa de um portao.** `DadosItem.icone` e `DadosArma.icone` podem ficar
## nulos -- e tem de poder, senao uma peca nova nao nasce antes da arte dela --,
## so que uma ausencia opcional nao aparece em lugar nenhum. Um `.tres` sem icone
## desenha o losango de cor exatamente como antes, e ninguem descobre que a peca
## nunca foi entregue. E o mesmo ponto cego que deixou o chefe do andar 1 lutar
## seis issues encarando o sul.
##
## Entao a divida vira LISTA: `SEM_ICONE_AINDA` declara quem ainda nao tem arte,
## e ela morde dos dois lados -- nome fora dela TEM de ter icone, nome dentro
## dela TEM de continuar sem. Mesmo desenho de `SEM_ARTE_AINDA` e
## `SEM_CLIPE_AINDA`: sem a segunda metade, a lista viraria permissao permanente
## e cobriria em silencio o dia em que um icone ja entregue se perdesse.
##
## O caminho e derivado, nunca listado. `implante_<id>.tres` aponta para
## `icone_<id>.png` por construcao, e a suite refaz a conta a partir do proprio
## `resource_path`. Uma tabela escrita a mao seria a terceira copia da mesma
## verdade, e o `MATIZ_POR_TIPO` ja registra o que acontece quando duas copias
## divergem: o funil escrevendo o que o portao recusa, com os dois "certos".
##
## ## Por que ARMA entrou aqui, e nao numa suite propria
##
## As armas ganharam icone DEPOIS dos implantes, e a primeira versao desta suite
## so conhecia implante. Copiar o arquivo trocando `DadosItem` por `DadosArma`
## daria duas suites de 170 linhas afirmando a mesma coisa -- e duas copias
## divergem, com o sintoma aparecendo meses depois na familia que ninguem
## atualizou. As duas familias passam pela MESMA varredura, e o que muda entre
## elas e uma linha de tabela.
##
## Elas leem o campo por `get(&"icone")` em vez de por tipo, pela mesma razao que
## `OfertaDeLoja.nome()` faz isso: `DadosArma` e `DadosItem` nao tem base comum,
## e fingir uma interface que nao existe seria pior que perguntar.

## Como o arquivo de arte se chama, dado o id da peca.
const MOLDE_DO_ICONE := "icone_%s.png"

## As duas familias de loot que precisam de icone, e onde cada uma mora.
##
## `prefixo` separa a peca do resto da pasta: em `src/items/` ele afasta
## `pool_padrao` e `drop_credito_andar1`. Em `src/weapons/` nao ha prefixo, e
## quem faz a separacao e `so_com_preco`.
##
## **`so_com_preco` nao e um atalho: e a regra.** `src/weapons/` guarda tambem a
## `pistola` (inicial, nunca vendida) e as armas do chefe (`onda_guardiao`,
## `sucata_guardiao`), que nao aparecem em prateleira nem no chao. Exigir icone
## delas cobraria arte que ninguem veria, e a lista de divida ficaria com tres
## nomes permanentes -- que e como uma lista de divida deixa de ser lida.
## `valor_de_loja > 0` e exatamente o mesmo teste que `GeradorDeLoja._sortear()`
## usa para decidir o que pode ir a prateleira.
const FAMILIAS: Array[Dictionary] = [
	{
		&"nome": "implante",
		&"pasta": "res://src/items/",
		&"prefixo": "implante_",
		&"icones": "res://assets/itens/",
		&"so_com_preco": false,
	},
	{
		&"nome": "arma",
		&"pasta": "res://src/weapons/",
		&"prefixo": "",
		&"icones": "res://assets/armas/",
		&"so_com_preco": true,
	},
]

## As pecas que AINDA nao tem icone, declaradas por familia.
##
## Elas ENCOLHEM ate zero conforme a arte entra. Tirar um nome daqui e o
## interruptor de "a arte chegou" -- e enquanto o nome estiver aqui, o portao
## exige que ele continue SEM icone, para a lista nao guardar uma divida ja paga.
const SEM_ICONE_AINDA: Dictionary = {
	# VAZIAS, e este e o estado saudavel: os 16 implantes e as 10 armas de
	# prateleira do andar 1 tem icone. Peca nova entra aqui na linha em que nasce
	# e sai na linha em que a arte chega.
	"implante": [],
	"arma": [],
}


func nome() -> String:
	return "IconesDeLoot"


func executar() -> void:
	for familia in FAMILIAS:
		_conferir_familia(familia)


func _conferir_familia(familia: Dictionary) -> void:
	var rotulo: String = familia[&"nome"]
	var pasta_icones: String = familia[&"icones"]
	var divida: Array = SEM_ICONE_AINDA.get(rotulo, [])
	var pecas := _pecas(familia)

	# Guarda contra a suite virar decoracao: se a varredura parar de achar
	# ninguem -- pasta renomeada, prefixo mudado --, todas as asercoes abaixo
	# somem e o relatorio fica verde.
	ok(pecas.size() > 0,
		"a varredura achou %s(s) em disco (%d)" % [rotulo, pecas.size()])

	var apontados: Array[String] = []
	for id: String in pecas:
		var dados: Resource = pecas[id]
		var arte := _icone_de(dados)
		_o_caminho_do_icone_e_mecanico(rotulo, id, dados, arte, pasta_icones)
		_a_ausencia_esta_declarada(rotulo, id, dados, arte, divida)
		if arte != null:
			apontados.append(arte.resource_path)

	_a_lista_de_divida_nao_guarda_fantasma(rotulo, divida, pecas)
	_nenhum_png_fica_orfao(rotulo, pasta_icones, apontados)


## O campo, perguntado e nunca tipado.
##
## As duas familias nao tem base comum, entao `dados.icone` so compilaria dentro
## de um `if dados is ...` por familia -- que e a interface fingida que este
## arquivo evita.
func _icone_de(dados: Resource) -> Texture2D:
	if dados == null:
		return null
	return dados.get(&"icone") as Texture2D


## Os `.tres` de uma familia, indexados pelo id derivado do nome do arquivo.
##
## Varre o disco em vez de listar: peca nova entra na conta sozinha, sem ninguem
## lembrar de acrescentar. Uma lista fixa aqui teria o mesmo defeito que a
## `AUTORADAS` do teste de texturas ja pagou -- arquivo fora dela nao e conferido
## por nada, e cinco passaram assim em tres ondas de arte.
func _pecas(familia: Dictionary) -> Dictionary:
	var achados := {}
	var caminho: String = familia[&"pasta"]
	var prefixo: String = familia[&"prefixo"]
	var so_com_preco: bool = familia[&"so_com_preco"]
	var pasta := DirAccess.open(caminho)
	if pasta == null:
		ok(false, "%s pode ser aberta" % caminho)
		return achados
	for arquivo in pasta.get_files():
		if not arquivo.begins_with(prefixo) or not arquivo.ends_with(".tres"):
			continue
		var dados := load(caminho + arquivo) as Resource
		if dados == null:
			continue
		if so_com_preco and int(dados.get(&"valor_de_loja")) <= 0:
			continue
		achados[arquivo.get_basename().trim_prefix(prefixo)] = dados
	return achados


## O icone de `<id>.tres` mora em `<pasta de icones>/icone_<id>.png`.
##
## O caminho sai do id, e o id sai do nome do arquivo: nada aqui e escrito a
## mao. O defeito que este caso pega e o copiar-colar de `.tres` -- clonar uma
## peca e esquecer de trocar a arte deixa dois pickups iguais em jogo, sem uma
## linha no console, e foi assim que a Loja passou a se apresentar como sala de
## arma.
func _o_caminho_do_icone_e_mecanico(rotulo: String, id: String, dados: Resource,
		arte: Texture2D, pasta_icones: String) -> void:
	if dados == null:
		ok(false, "%s %s carrega" % [rotulo, id])
		return
	if arte == null:
		return
	igual(
		arte.resource_path, pasta_icones + MOLDE_DO_ICONE % id,
		"%s %s aponta para o icone do proprio id" % [rotulo, id]
	)


## Toda peca ou tem icone, ou esta declarada em `SEM_ICONE_AINDA`.
##
## As duas metades. A primeira e a obvia: quem saiu da lista precisa ter a arte.
## A segunda e a que impede a lista de apodrecer -- quem esta nela precisa
## continuar SEM arte, senao a divida fica registrada depois de paga e cobre em
## silencio o dia em que aquele icone se perder do `.tres`.
func _a_ausencia_esta_declarada(rotulo: String, id: String, dados: Resource,
		arte: Texture2D, divida: Array) -> void:
	if dados == null:
		return
	if divida.has(id):
		ok(arte == null,
			"%s %s esta em SEM_ICONE_AINDA e continua sem icone -- se ganhou arte, TIRE o nome da lista"
				% [rotulo, id])
	else:
		ok(arte != null,
			"%s %s tem icone (nao esta em SEM_ICONE_AINDA)" % [rotulo, id])


## Nome em `SEM_ICONE_AINDA` que nao corresponde a peca nenhuma.
##
## Sem isto, renomear um `.tres` deixaria a linha velha na lista para sempre --
## e uma linha que nao aponta para nada nao reprova nada, ela so parece uma
## divida em aberto que ninguem consegue fechar.
func _a_lista_de_divida_nao_guarda_fantasma(rotulo: String, divida: Array,
		pecas: Dictionary) -> void:
	var fantasmas: Array[String] = []
	for id: String in divida:
		if not pecas.has(id):
			fantasmas.append(id)
	igual(
		fantasmas.size(), 0,
		"todo nome de SEM_ICONE_AINDA[%s] tem uma peca em disco (%s)" % [rotulo, fantasmas]
	)


## Nenhum PNG na pasta de icones da familia fica sem dono.
##
## PNG orfao e arte que ninguem desenha: ou o `.tres` esqueceu de aponta-la, ou
## o arquivo sobrou de um id renomeado. Nos dois casos ele passa em toda medicao
## de arquivo e some da tela, que e onde o defeito e mais caro de achar.
##
## **E e este caso que obriga as duas familias a terem pastas SEPARADAS.** Um
## icone de arma dentro de `assets/itens/` nao tem implante que o aponte, entao
## ele seria orfao -- e reprovaria com razao. Separar a pasta e o que deixa cada
## familia responder pela propria arte; o que NAO se separa e a medicao de
## distinguibilidade, porque as duas dividem a prateleira da Loja e e la que dois
## icones viram a mesma mancha.
##
## A pasta pode NAO EXISTIR -- ela nasce com o primeiro icone --, e isso nao e
## falha: `DirAccess.open` devolver null aqui significa "nenhuma arte ainda", nao
## "a varredura quebrou".
func _nenhum_png_fica_orfao(rotulo: String, pasta_icones: String,
		apontados: Array[String]) -> void:
	var pasta := DirAccess.open(pasta_icones)
	if pasta == null:
		ok(true, "%s ainda nao existe -- nenhum icone de %s para ficar orfao"
			% [pasta_icones, rotulo])
		return
	var orfaos: Array[String] = []
	for arquivo in pasta.get_files():
		if not arquivo.ends_with(".png"):
			continue
		if not apontados.has(pasta_icones + arquivo):
			orfaos.append(arquivo)
	igual(
		orfaos.size(), 0,
		"nenhum PNG de %s fica sem uma peca que o aponte (%s)" % [pasta_icones, orfaos]
	)
