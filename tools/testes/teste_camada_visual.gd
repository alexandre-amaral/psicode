extends TesteBase
## Trava o CONTRATO de camadas do mundo -- as faixas de z de `Sala` e quem
## desenha em cada uma.
##
## Existe porque ordem de desenho quebra em SILENCIO. Nao ha erro no console
## para "a parede desenhou por cima da sala inteira" nem para "a moldura da
## porta sumiu atras do chao": o jogo roda, o teste de fumaca passa (ele nunca
## olha um pixel) e o defeito so aparece numa captura que alguem precisa
## lembrar de olhar.
##
## A migracao para Low Top-Down Squared vai encher estas faixas -- face de
## parede (LTD 04), mundo ordenado por Y (LTD 02), frente (LTD 10). Cada uma
## dessas issues acrescenta um caso aqui; esta suite e o lugar onde "a camada
## existe e esta na faixa certa" vira pergunta com resposta.

const CENA_SALA := preload("res://src/mapa/sala_1_retangular.tscn")
const CENA_L := preload("res://src/mapa/sala_2_l_shape.tscn")
const CENA_PILAR := preload("res://src/mapa/sala_5_pilar.tscn")

## Longe da origem: outras suites deixam no ao redor de (0,0) enquanto o
## coletor nao passa, e uma delas ja custou um dia de teste vermelho com o
## codigo certo (ver teste_hack.gd).
const LONGE := Vector2(9000.0, 9000.0)


func nome() -> String:
	return "CamadaVisual"


func executar() -> void:
	_as_faixas_estao_em_ordem()
	_a_sala_monta_cada_camada_na_sua_faixa()
	_o_chao_fica_acima_do_topo_da_parede()
	_a_moldura_da_porta_fica_acima_do_chao()
	_o_obstaculo_cobre_o_chao()
	_a_sala_em_l_monta_as_camadas()
	_a_corrente_do_y_sort_esta_inteira()
	_o_mundo_da_cena_principal_ordena_por_y()
	_as_camadas_de_cenario_ficam_fora_do_y_sort()


## O contrato em si: as faixas sobem na ordem em que as coisas se empilham.
## Se alguem renumerar uma sem olhar as vizinhas, cai aqui.
func _as_faixas_estao_em_ordem() -> void:
	ok(Sala.Z_PAREDE_TOPO < Sala.Z_CHAO, "topo da parede fica ATRAS do chao (e o chao que recorta a faixa visivel)")
	ok(Sala.Z_CHAO < Sala.Z_CHAO_DETALHE, "detalhe de chao fica acima do chao")
	ok(Sala.Z_CHAO_DETALHE < Sala.Z_PAREDE_FACE, "face da parede fica acima do detalhe de chao")
	ok(Sala.Z_PAREDE_FACE < Sala.Z_MUNDO, "o mundo ordenado por Y fica acima da face")
	ok(Sala.Z_MUNDO < Sala.Z_FRENTE, "a frente fica acima do mundo")
	# Espacamento de 2: cabe uma camada nova entre duas existentes sem
	# renumerar as outras. Renumerar e o que quebra ordem sem erro no console.
	igual(Sala.Z_CHAO - Sala.Z_PAREDE_TOPO, 2, "espacamento entre topo e chao")
	igual(Sala.Z_CHAO_DETALHE - Sala.Z_CHAO, 2, "espacamento entre chao e detalhe")


func _a_sala_monta_cada_camada_na_sua_faixa() -> void:
	var sala := _montar(CENA_SALA)

	var topo := sala.get_node_or_null("ParedeTopo") as Polygon2D
	ok(topo != null, "a sala monta a camada ParedeTopo")
	if topo != null:
		igual(topo.z_index, Sala.Z_PAREDE_TOPO, "ParedeTopo na faixa dela")
		ok(topo.polygon.size() >= 3, "ParedeTopo tem poligono")

	var chao := sala.get_node_or_null("Chao") as Polygon2D
	ok(chao != null, "a sala monta a camada Chao")
	if chao != null:
		igual(chao.z_index, Sala.Z_CHAO, "Chao na faixa dele")
		igual(chao.texture_repeat, CanvasItem.TEXTURE_REPEAT_ENABLED,
			"o chao ladrilha -- sem isso a textura sai UMA vez esticada, e o default do projeto e Disabled")

	sala.free()


## O truque que faz a sala em L funcionar sem calcular anel com furo: o corpo
## da parede e o contorno INFLADO e solido, e quem recorta a faixa de 24 px e o
## chao desenhado por cima. Inverter isso cobre a sala inteira de parede.
func _o_chao_fica_acima_do_topo_da_parede() -> void:
	var sala := _montar(CENA_SALA)
	var topo := sala.get_node_or_null("ParedeTopo") as Polygon2D
	var chao := sala.get_node_or_null("Chao") as Polygon2D
	if topo != null and chao != null:
		ok(topo.z_index < chao.z_index, "o chao recorta o topo da parede, e nao o contrario")
		ok(_area_do(topo.polygon) > _area_do(chao.polygon),
			"o topo e o contorno inflado, entao cobre mais area que o chao")
	sala.free()


## A moldura da porta (z -1, dentro da cena da porta) tem de ficar acima do
## chao. Antes os dois empatavam em -1 e o desempate era ordem de arvore, o que
## obrigava as camadas geradas a entrar no INICIO da lista de filhos.
func _a_moldura_da_porta_fica_acima_do_chao() -> void:
	var sala := _montar(CENA_SALA)
	var portas := sala.get_node_or_null("Portas")
	ok(portas != null, "a sala_1 tem o no Portas")
	var conferidas := 0
	if portas != null:
		for porta in portas.get_children():
			var moldura := porta.get_node_or_null("Moldura") as CanvasItem
			if moldura == null:
				continue
			conferidas += 1
			ok(moldura.z_index > Sala.Z_CHAO,
				"a moldura de %s desenha acima do chao sem depender de ordem de arvore" % porta.name)
	ok(conferidas >= 2, "conferiu ao menos duas molduras")
	sala.free()


## O pilar e parede no meio da sala: ele PRECISA cobrir o chao, entao nao pode
## usar o truque do recorte. Se ele cair na faixa do topo, some.
func _o_obstaculo_cobre_o_chao() -> void:
	var sala := _montar(CENA_PILAR)
	var bloco: Polygon2D = null
	for filho in sala.get_children():
		if filho.name == "ObstaculoCorpo":
			bloco = filho as Polygon2D
			break
	ok(bloco != null, "a sala com pilar monta o corpo do obstaculo")
	if bloco != null:
		ok(bloco.z_index > Sala.Z_CHAO, "o obstaculo desenha ACIMA do chao, senao o pilar some")
		igual(bloco.z_index, Sala.Z_PAREDE_FACE, "o obstaculo usa a faixa da face de parede")
	sala.free()


## A sala em L e a unica concava do projeto, e e ela que o truque do recorte
## existe para salvar. Uma camada que funcione so no retangulo nao serve.
func _a_sala_em_l_monta_as_camadas() -> void:
	var sala := _montar(CENA_L)
	var topo := sala.get_node_or_null("ParedeTopo") as Polygon2D
	var chao := sala.get_node_or_null("Chao") as Polygon2D
	ok(topo != null, "a sala em L monta ParedeTopo")
	ok(chao != null, "a sala em L monta Chao")
	if topo != null and chao != null:
		ok(topo.polygon.size() >= 3, "o contorno inflado da sala em L nao degenerou")
		ok(_area_do(topo.polygon) > _area_do(chao.polygon),
			"na sala em L o inflado tambem cobre mais que o chao")
	sala.free()


## O Y-sort do Godot so alcanca um no se TODOS os ancestrais entre ele e a raiz
## ordenada tambem estiverem ligados. Um elo solto nao gera erro: o jogo roda,
## e a ordem daquele ramo passa a vir da arvore em vez da posicao.
func _a_corrente_do_y_sort_esta_inteira() -> void:
	var sala := _montar(CENA_SALA)
	ok(sala.y_sort_enabled, "a Sala ordena os filhos por Y")

	# O container vem da CENA nesta sala. Metade das salas o traz pronto e
	# metade o cria em codigo -- os dois caminhos tem de acabar ligados.
	var container := sala.get_node_or_null("ContainerInimigos") as Node2D
	ok(container != null, "a sala_1 traz o ContainerInimigos da cena")
	if container != null:
		ok(container.y_sort_enabled, "o ContainerInimigos que veio da cena ordena por Y")

	sala.free()


## A cena principal e onde a corrente comeca. Conferida pelo PackedSceneState,
## sem instanciar: instanciar main.tscn sobe o jogo inteiro e chama
## iniciar_run(), o que nao cabe numa suite unitaria.
func _o_mundo_da_cena_principal_ordena_por_y() -> void:
	var cena: PackedScene = load("res://src/main/main.tscn")
	ok(cena != null, "main.tscn carrega")
	if cena == null:
		return
	var estado := cena.get_state()

	var achou_mundo := false
	var pais: Dictionary = {}
	for i in estado.get_node_count():
		var nome := estado.get_node_name(i)
		pais[nome] = String(estado.get_node_path(i, true))
		if nome != "Mundo":
			continue
		achou_mundo = true
		ok(_propriedade(estado, i, "y_sort_enabled") == true,
			"o no Mundo da cena principal ordena por Y")

	ok(achou_mundo, "a cena principal tem o no Mundo")
	# Player e GerenciadorMapa tem de estar DENTRO dele: irmaos do Mundo nao se
	# ordenam contra o que esta dentro, e era assim que a cena estava antes --
	# o jogador nunca se ordenava contra os inimigos.
	igual(pais.get("Player", ""), "./Mundo", "o Player mora dentro do Mundo")
	igual(pais.get("GerenciadorMapa", ""), "./Mundo", "o GerenciadorMapa mora dentro do Mundo")


## z_index tem prioridade sobre Y: so irmaos no MESMO z se ordenam por posicao.
## E isso que mantem chao e parede fora da brincadeira -- e o que faria o chao
## passar na frente do jogador se alguem os trouxesse para a faixa do mundo.
func _as_camadas_de_cenario_ficam_fora_do_y_sort() -> void:
	var sala := _montar(CENA_SALA)
	for nome in ["Chao", "ParedeTopo", "Decoracao"]:
		var camada := sala.get_node_or_null(nome) as CanvasItem
		if camada == null:
			continue
		ok(camada.z_index < Sala.Z_MUNDO,
			"%s fica abaixo da faixa do mundo, entao o Y-sort nao o mistura com os atores" % nome)
	sala.free()


# ------------------------------------------------------------------ ajuda ----

## Le uma propriedade declarada de um no dentro do PackedSceneState. Devolve
## null quando a propriedade nao foi sobrescrita na cena.
func _propriedade(estado: SceneState, indice: int, nome: String) -> Variant:
	for p in estado.get_node_property_count(indice):
		if estado.get_node_property_name(indice, p) == nome:
			return estado.get_node_property_value(indice, p)
	return null

## `free()` e nao `queue_free()`: a suite roda inteira num frame, entao uma
## sala enfileirada continuaria na arvore e no grupo "salas" durante os casos
## seguintes. Mesma licao ja registrada para container de projetil.
func _montar(cena: PackedScene) -> Sala:
	var sala := cena.instantiate() as Sala
	sala.position = LONGE
	Engine.get_main_loop().root.add_child(sala)
	return sala


## Area por shoelace, so para comparar tamanhos entre dois poligonos.
func _area_do(pontos: PackedVector2Array) -> float:
	if pontos.size() < 3:
		return 0.0
	var soma := 0.0
	for i in pontos.size():
		var a := pontos[i]
		var b := pontos[(i + 1) % pontos.size()]
		soma += a.x * b.y - b.x * a.y
	return absf(soma) * 0.5
