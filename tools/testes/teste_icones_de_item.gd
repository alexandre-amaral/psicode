extends TesteBase
## Amarra os 16 implantes de `src/items/` a arte de `assets/itens/`.
##
## A decisao de design que esta suite carrega: **o icone e opcional, e por isso
## precisa de um portao.** `DadosItem.icone` pode ficar nulo -- e tem de poder,
## senao um implante novo nao nasce antes da arte dele --, so que uma ausencia
## opcional nao aparece em lugar nenhum. Um `.tres` sem icone desenha o losango
## de `cor` com a `sigla` dentro, exatamente como antes, e ninguem descobre que
## a peca nunca foi entregue. E o mesmo ponto cego que deixou o chefe do andar 1
## lutar seis issues encarando o sul.
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

const PASTA_ITENS := "res://src/items/"
const PASTA_ICONES := "res://assets/itens/"

## O prefixo que separa implante de todo outro `.tres` de `src/items/`
## (`pool_padrao`, `drop_credito_andar1`).
const PREFIXO := "implante_"

## Como o arquivo de arte se chama, dado o id do implante.
const MOLDE_DO_ICONE := "icone_%s.png"

## Os implantes que AINDA nao tem icone, declarados.
##
## Ela nasce com os 16 e ENCOLHE ate zero conforme a arte entra. Tirar um nome
## daqui e o interruptor de "a arte chegou" -- e enquanto o nome estiver aqui, o
## portao exige que ele continue SEM icone, para a lista nao guardar uma divida
## ja paga.
const SEM_ICONE_AINDA: Array[String] = [
	# VAZIA, e este e o estado saudavel: os 16 implantes do andar 1 tem icone.
	# Implante novo entra aqui na linha em que nasce, e sai na linha em que a arte
	# chega -- e enquanto o nome estiver aqui a suite EXIGE que ele continue sem
	# icone, entao a lista nunca vira permissao esquecida.
]


func nome() -> String:
	return "IconesDeItem"


func executar() -> void:
	var implantes := _implantes()

	# Guarda contra a suite virar decoracao: se a varredura parar de achar
	# ninguem -- pasta renomeada, prefixo mudado --, todas as asercoes abaixo
	# somem e o relatorio fica verde.
	ok(implantes.size() >= SEM_ICONE_AINDA.size(),
		"a varredura achou os implantes em disco (%d)" % implantes.size())

	var apontados: Array[String] = []
	for id: String in implantes:
		var dados: DadosItem = implantes[id]
		_o_caminho_do_icone_e_mecanico(id, dados)
		_a_ausencia_esta_declarada(id, dados)
		if dados != null and dados.icone != null:
			apontados.append(dados.icone.resource_path)

	_a_lista_de_divida_nao_guarda_fantasma(implantes)
	_nenhum_png_fica_orfao(apontados)


## Os `implante_*.tres` de `src/items/`, indexados pelo id derivado do nome.
##
## Varre o disco em vez de listar: implante novo entra na conta sozinho, sem
## ninguem lembrar de acrescentar. Uma lista fixa aqui teria o mesmo defeito que
## a `AUTORADAS` do teste de texturas ja pagou -- arquivo fora dela nao e
## conferido por nada, e cinco passaram assim em tres ondas de arte.
func _implantes() -> Dictionary:
	var achados := {}
	var pasta := DirAccess.open(PASTA_ITENS)
	if pasta == null:
		ok(false, "src/items/ pode ser aberta")
		return achados
	for arquivo in pasta.get_files():
		if not arquivo.begins_with(PREFIXO) or not arquivo.ends_with(".tres"):
			continue
		var id := arquivo.get_basename().trim_prefix(PREFIXO)
		achados[id] = load(PASTA_ITENS + arquivo) as DadosItem
	return achados


## O icone de `implante_<id>.tres` mora em `assets/itens/icone_<id>.png`.
##
## O caminho sai do id, e o id sai do nome do arquivo: nada aqui e escrito a
## mao. O defeito que este caso pega e o copiar-colar de `.tres` -- clonar um
## implante e esquecer de trocar a arte deixa dois pickups iguais em jogo, sem
## uma linha no console, e foi assim que a Loja passou a se apresentar como sala
## de arma.
func _o_caminho_do_icone_e_mecanico(id: String, dados: DadosItem) -> void:
	if dados == null:
		ok(false, "implante_%s.tres carrega como DadosItem" % id)
		return
	if dados.icone == null:
		return
	igual(
		dados.icone.resource_path, PASTA_ICONES + MOLDE_DO_ICONE % id,
		"implante_%s aponta para o icone do proprio id" % id
	)


## Todo implante ou tem icone, ou esta declarado em `SEM_ICONE_AINDA`.
##
## As duas metades. A primeira e a obvia: quem saiu da lista precisa ter a arte.
## A segunda e a que impede a lista de apodrecer -- quem esta nela precisa
## continuar SEM arte, senao a divida fica registrada depois de paga e cobre em
## silencio o dia em que aquele icone se perder do `.tres`.
func _a_ausencia_esta_declarada(id: String, dados: DadosItem) -> void:
	if dados == null:
		return
	var declarado := SEM_ICONE_AINDA.has(id)
	if declarado:
		ok(dados.icone == null,
			"implante_%s esta em SEM_ICONE_AINDA e continua sem icone -- se ganhou arte, TIRE o nome da lista" % id)
	else:
		ok(dados.icone != null,
			"implante_%s tem icone (nao esta em SEM_ICONE_AINDA)" % id)


## Nome em `SEM_ICONE_AINDA` que nao corresponde a implante nenhum.
##
## Sem isto, renomear um `.tres` deixaria a linha velha na lista para sempre --
## e uma linha que nao aponta para nada nao reprova nada, ela so parece uma
## divida em aberto que ninguem consegue fechar.
func _a_lista_de_divida_nao_guarda_fantasma(implantes: Dictionary) -> void:
	var fantasmas: Array[String] = []
	for id in SEM_ICONE_AINDA:
		if not implantes.has(id):
			fantasmas.append(id)
	igual(
		fantasmas.size(), 0,
		"todo nome de SEM_ICONE_AINDA tem um implante em disco (%s)" % [fantasmas]
	)


## Nenhum PNG em `assets/itens/` fica sem dono.
##
## PNG orfao e arte que ninguem desenha: ou o `.tres` esqueceu de aponta-la, ou
## o arquivo sobrou de um id renomeado. Nos dois casos ele passa em toda medicao
## de arquivo e some da tela, que e onde o defeito e mais caro de achar.
##
## A pasta pode NAO EXISTIR -- ela nasce com o primeiro icone --, e isso nao e
## falha: e o estado de hoje. `DirAccess.open` devolver null aqui significa
## "nenhuma arte ainda", nao "a varredura quebrou".
func _nenhum_png_fica_orfao(apontados: Array[String]) -> void:
	var pasta := DirAccess.open(PASTA_ICONES)
	if pasta == null:
		ok(true, "assets/itens/ ainda nao existe -- nenhum icone para ficar orfao")
		return
	var orfaos: Array[String] = []
	for arquivo in pasta.get_files():
		if not arquivo.ends_with(".png"):
			continue
		if not apontados.has(PASTA_ICONES + arquivo):
			orfaos.append(arquivo)
	igual(
		orfaos.size(), 0,
		"nenhum PNG de assets/itens/ fica sem um implante que o aponte (%s)" % [orfaos]
	)
