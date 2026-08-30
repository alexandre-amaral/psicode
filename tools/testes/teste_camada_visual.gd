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
	_o_ator_tem_sombra_na_base()
	_todo_ator_com_arte_tem_origem_nos_pes()
	_a_face_sorteia_por_lado()


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


## A sombra e o que responde "onde esta a base disto?" -- a pergunta que a
## perspectiva Low Top-Down cria e nao resolve sozinha. Ela tem de existir, tem
## de ficar NA base (nao no centro do corpo) e tem de ficar FORA do Visual: o
## clarao de dano escreve em `_visual.modulate`, que desce para os filhos, e
## sombra piscando branco a cada tiro e pior que sombra nenhuma.
func _o_ator_tem_sombra_na_base() -> void:
	var cena: PackedScene = load("res://src/enemies/rastejante.tscn")
	ok(cena != null, "rastejante.tscn carrega")
	if cena == null:
		return
	var inimigo := cena.instantiate()
	Engine.get_main_loop().root.add_child(inimigo)

	var sombra := inimigo.get_node_or_null("Sombra") as Sombra
	ok(sombra != null, "o inimigo com sprite ganha sombra")
	if sombra != null:
		ok(sombra.get_parent() == inimigo,
			"a sombra e irma do Visual, nao filha -- senao o clarao de dano a faz piscar")
		var corpo := inimigo.get_node_or_null("Visual/Corpo") as Node2D
		if corpo != null:
			perto(sombra.position.y, Sombra.base_de(corpo),
				"a sombra fica nos pes, e nao no centro do corpo")
			ok(sombra.position.y > corpo.position.y,
				"a sombra fica ABAIXO do corpo (pes %.0f, corpo %.0f)" % [sombra.position.y, corpo.position.y])
		ok(sombra.z_index < 0, "a sombra desenha sob o corpo do proprio ator")
		ok(sombra.color.a > 0.0 and sombra.color.a < 1.0,
			"a sombra e translucida -- opaca ela vira buraco no chao")
	inimigo.free()

	# A arena do chefe nasce DO chao. Sombra nela leria como se a torre
	# estivesse pousada sobre o piso em vez de ter subido dele.
	var cena_torre: PackedScene = load("res://src/enemies/torre_diretora.tscn")
	if cena_torre != null:
		var torre := cena_torre.instantiate()
		Engine.get_main_loop().root.add_child(torre)
		ok(torre.get_node_or_null("Sombra") == null,
			"a torre da arena nao tem sombra: ela sobe do chao, nao pousa nele")
		torre.free()


## A regra de origem do Low Top-Down: a posicao logica do ator e o ponto em que
## ele encosta no CHAO, e o desenho sobe a partir dali.
##
## Isto e portao e nao convencao porque o sintoma nao aparece no console e quase
## nao aparece parado: com o sprite ancorado no meio do corpo, o Y-sort ordena
## pelo MEIO e um inimigo alto passa na frente de outro que esta mais abaixo na
## tela. So se ve em movimento, e so quando dois corpos se cruzam.
##
## Os quatro inimigos que ainda sao Polygon2D ficam de fora de proposito: eles
## sao desenhados em volta da propria origem, entao a base deles JA e a origem.
func _todo_ator_com_arte_tem_origem_nos_pes() -> void:
	var esperado := -Direcoes.BASE_NO_QUADRO
	var conferidos := 0

	var dir := DirAccess.open("res://src/enemies/")
	ok(dir != null, "a pasta de inimigos abre")
	if dir != null:
		for arquivo in dir.get_files():
			if not arquivo.ends_with(".tscn"):
				continue
			var cena: PackedScene = load("res://src/enemies/" + arquivo)
			if cena == null:
				continue
			var inimigo := cena.instantiate()
			Engine.get_main_loop().root.add_child(inimigo)
			var corpo := inimigo.get_node_or_null("Visual/Corpo")
			if corpo is Sprite2D:
				conferidos += 1
				perto((corpo as Sprite2D).position.y, esperado,
					"%s: o sprite e ancorado nos pes" % arquivo)
			inimigo.free()

	# Piso: os cinco inimigos com sprite direcional existem desde a v0.3.
	# Sem ele, uma varredura que nao achasse nada passaria como aprovacao.
	ok(conferidos >= 5, "a varredura achou os inimigos com arte (%d)" % conferidos)

	# O jogador, pelas duas pontas: a cena e o .tres de cada operador.
	var cena_player: PackedScene = load("res://src/player/player.tscn")
	if cena_player != null:
		var estado := cena_player.get_state()
		for i in estado.get_node_count():
			if estado.get_node_name(i) != "Sprite":
				continue
			var pos: Variant = _propriedade(estado, i, "position")
			if pos != null:
				perto((pos as Vector2).y, esperado, "player.tscn: o Sprite e ancorado nos pes")

	var operadores := 0
	var dir_p := DirAccess.open("res://src/player/")
	if dir_p != null:
		for arquivo in dir_p.get_files():
			if not arquivo.begins_with("personagem_") or not arquivo.ends_with(".tres"):
				continue
			var dados: Resource = load("res://src/player/" + arquivo)
			if dados == null or not "deslocamento_sprite" in dados:
				continue
			operadores += 1
			perto(dados.deslocamento_sprite.y, esperado,
				"%s: o deslocamento poe os pes na origem" % arquivo)
	ok(operadores >= 2, "os dois operadores foram conferidos (%d)" % operadores)


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

## Como a face escolhe o modulo que veste cada lado (LTD 13).
##
## Este caso existe porque a medicao contrariou o desenho, e o que ficou no
## codigo foi o resultado da medicao.
##
## **Uma sala mostra UMA face.** `LIMIAR_LADO_NORTE` so desenha face no lado
## cuja normal aponta para o norte -- ou seja, a parede do fundo, a unica cuja
## superficie vertical esta virada para a camera. Medido nas nove formas de
## sala: todas dao exatamente uma. E geometricamente certo para esta
## perspectiva, e e o que impede o cenario de cobrir jogador e telegrafo.
##
## A consequencia manda no planejamento de arte, e nao e obvia: uma biblioteca
## de cinco modulos de face NAO produz cinco paineis diferentes numa sala. Ela
## produz variedade ao longo do ANDAR -- salas vizinhas vestindo modulos
## diferentes. Quem for produzir os modulos precisa saber disso, senao desenha
## pensando numa composicao que nunca acontece.
##
## O sorteio continua sendo por (celula, lado) e nao so por celula: custa nada,
## e o dia em que uma sala tiver dois trechos de fundo -- um L entalhado por
## cima -- ela ja veste os dois sem mudanca nenhuma.
func _a_face_sorteia_por_lado() -> void:
	var um: Texture2D = load("res://assets/texturas/parede_face_boss.png")
	var dois: Texture2D = load("res://assets/texturas/parede_face_arma.png")
	ok(um != null and dois != null, "as faces de teste carregam do disco")
	if um == null or dois == null:
		return
	var dados := DadosSala.new()
	dados.texturas_face = [um, dois]

	# 1. A sala veste a face que o TIPO manda, e nao a neutra em disco.
	var usadas := _texturas_de_face(_montar_com(CENA_SALA, dados, Vector2i(3, 1)))
	igual(usadas.size(), 1, "a sala retangular desenha uma face -- so o lado de fundo aparece")
	if not usadas.is_empty():
		ok(
			usadas[0] != Sala.FACE_NEUTRA,
			"ela usa o modulo declarado pelo tipo, nao a face neutra (%s)" % usadas[0]
		)

	# 2. Ao longo do ANDAR os modulos variam. E aqui que a biblioteca aparece.
	var vistas := {}
	for x in 16:
		for t in _texturas_de_face(_montar_com(CENA_SALA, dados, Vector2i(x, 0))):
			vistas[t] = true
	ok(
		vistas.size() >= 2,
		"salas diferentes do andar vestem modulos diferentes (%d de 2)" % vistas.size()
	)

	# 3. Determinismo: a mesma celula veste igual nas duas montagens. Sem isso,
	#    voltar para uma sala a redecora, e o jogador percebe.
	var a := _texturas_de_face(_montar_com(CENA_SALA, dados, Vector2i(7, 2)))
	var b := _texturas_de_face(_montar_com(CENA_SALA, dados, Vector2i(7, 2)))
	igual(a, b, "a mesma celula veste os mesmos modulos nas duas montagens")

	# 4. Sem dados, a sala nao fica sem face -- ela cai na neutra. E o caso da
	#    cena aberta sozinha no editor, e ele nao pode virar parede chapada.
	var sem := _texturas_de_face(_montar_com(CENA_SALA, null, Vector2i(1, 1)))
	igual(sem.size(), 1, "sala sem DadosSala ainda desenha a face")
	if not sem.is_empty():
		igual(sem[0], Sala.FACE_NEUTRA, "e ela e a face neutra")


## Monta uma sala numa celula dada, com os dados dados. Longe da origem, como o
## resto desta suite.
func _montar_com(cena: PackedScene, dados: DadosSala, celula: Vector2i) -> Sala:
	var sala := cena.instantiate() as Sala
	sala.coordenadas_grid = celula
	# Os dois ANTES do add_child: e o _ready que monta as faces, e ele le os
	# dois. E a mesma ordem que o GerenciadorMapa usa.
	sala.definir_visual(dados)
	sala.position = LONGE
	Engine.get_main_loop().root.add_child(sala)
	return sala


## Os caminhos das texturas de cada quad de face, na ordem em que a sala montou.
## Caminho e nao Texture2D para a mensagem de falha ser legivel.
func _texturas_de_face(sala: Sala) -> Array[String]:
	var achados: Array[String] = []
	var raiz := sala.get_node_or_null("ParedeFace") as Node2D
	if raiz != null:
		for filho in raiz.get_children():
			var poly := filho as Polygon2D
			if poly != null and poly.texture != null:
				achados.append(poly.texture.resource_path)
	sala.free()
	return achados
