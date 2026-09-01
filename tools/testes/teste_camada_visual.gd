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
	_o_chefe_do_andar_e_alcancado_pelo_portao_de_origem()
	_a_face_sorteia_por_lado()
	_a_faixa_de_uv_da_face_e_declarada()
	_o_corredor_usa_a_mesma_perspectiva_da_sala()
	_a_razao_face_topo_fica_em_um_para_um()
	_o_topo_cerca_a_sala_e_a_face_so_aparece_ao_norte()
	_a_deterioracao_visual_nunca_decresce()
	_so_o_trecho_pre_chefe_anuncia_o_chefe()


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


## Quem AINDA nao tem arte direcional, e por isso o portao de origem nao alcanca.
##
## A lista existe para o silencio virar declaracao. `Visual/Corpo` que e
## `Polygon2D` e pulado pelo portao acima -- e o certo para os quatro inimigos
## desenhados em volta da propria origem, mas foi tambem como a Diretora passou
## anos fora da ancora sem ninguem ver. Um CHEFE nao pode entrar nessa categoria
## por acidente: ele e grande, e sprite grande fora da ancora e o caso em que o
## Y-sort erra mais.
##
## Tirar um nome daqui e o interruptor de "a arte chegou": no dia em que o
## `boss_guardiao_01` ganhar as oito rotacoes (BOSS 10), este teste passa a
## exigir dele a moldura e a ancora como de qualquer outro ator.
## Vazia desde que o Automato ganhou as oito rotacoes (BOSS 10). Ela continua
## existindo porque o proximo chefe vai nascer sem arte tambem, e o que nao pode
## voltar a existir e o SILENCIO.
const SEM_ARTE_AINDA: Array[String] = []


## O CHEFE nao pode ser pulado em silencio pelo portao de origem.
##
## A Diretora e o precedente inteiro: o sprite dela e 192x192 num no
## `Visual/SpriteDiretora`, entao `InimigoBase._corpo` procura `Visual/Corpo`,
## nao acha, e o tint de Hack e de nanite nao pintam nela -- e o portao acima a
## pula sem dizer nada. A BOSS 10 pede que a decisao seja tomada ANTES de
## desenhar, e este caso e a decisao virada portao.
func _o_chefe_do_andar_e_alcancado_pelo_portao_de_origem() -> void:
	var tipo: DadosSala = load("res://src/mapa/tipo_boss.tres")
	ok(tipo != null and not tipo.inimigos.is_empty(), "o tipo de sala do chefe declara um inimigo")
	if tipo == null or tipo.inimigos.is_empty():
		return

	var grupo: GrupoInimigo = tipo.inimigos[0]
	ok(grupo != null and grupo.cena != null, "e o grupo dele aponta para uma cena")
	if grupo == null or grupo.cena == null:
		return

	var arquivo := grupo.cena.resource_path.get_file()
	var chefe := grupo.cena.instantiate()
	Engine.get_main_loop().root.add_child(chefe)

	# 1. O corpo tem de estar onde `InimigoBase` procura. Sem isso o tint de
	#    Hack e o de nanite nao pintam nele, em silencio.
	var corpo := chefe.get_node_or_null("Visual/Corpo")
	ok(corpo != null,
		"%s tem `Visual/Corpo` -- e onde InimigoBase procura para pintar Hack e nanite" % arquivo)

	# 2. Ou ele tem arte ancorada, ou esta DECLARADO como ainda sem arte. O que
	#    o portao proibe e a terceira opcao: ser pulado sem ninguem saber.
	var sprite := corpo as Sprite2D
	var tem_arte := sprite != null and sprite.texture != null
	if tem_arte:
		var altura := sprite.texture.get_height()
		ok(Direcoes.moldura_de_ator(float(altura)),
			"%s usa uma moldura de ator (%d) -- arte de chefe fora do gerador foi como a Diretora perdeu a ancora"
				% [arquivo, altura])
		perto(sprite.position.y, -Direcoes.base_de_quadro(float(altura)),
			"%s: o chefe e ancorado nos PES" % arquivo)
	else:
		ok(SEM_ARTE_AINDA.has(arquivo),
			"%s ainda nao tem arte, e isso esta DECLARADO em SEM_ARTE_AINDA" % arquivo)
		ok(chefe.get("largura_sombra") != null and float(chefe.get("largura_sombra")) > 0.0,
			"%s ja nasce com sombra: a ancora nos pes vale desde o placeholder" % arquivo)

	chefe.free()


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
##
## E o portao distingue DOIS regimes pela moldura, em vez de exigir -36 de todo
## mundo (LTD 16):
##
## - moldura de ATOR (`Direcoes.MOLDURAS_DE_ATOR`): veio de `gerar_sprites.py`,
##   que ancora nos pes. A base sai de `Direcoes.base_de_quadro()`, entao a
##   moldura de 160 do chefe e cobrada com o numero DELA -- 76 -- e nao com o
##   36 da moldura de 80. Foi o chefe que trouxe o segundo tamanho (BOSS 10):
##   ele e duas a tres vezes o jogador e nao cabe em 80.
## - qualquer outra moldura: arte autorada, com ancora propria. O caso vivo e a
##   Diretora, um orbe flutuante radialmente simetrico de 192x192 -- ela nao tem
##   pes, e centrada E a ancora certa. Exigir -36 dela seria cobrar uma regra
##   anatomica de um corpo sem anatomia.
##
## O que se cobra do segundo regime e a COERENCIA: quem esta centrado nao pode
## ter sombra, porque a elipse nasceria dentro do proprio corpo e ficaria
## invisivel -- foi exatamente o no morto que a Diretora carregava.
func _todo_ator_com_arte_tem_origem_nos_pes() -> void:
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
			var sprite := corpo as Sprite2D
			if sprite != null and sprite.texture != null:
				var altura := sprite.texture.get_height()
				if Direcoes.moldura_de_ator(float(altura)):
					conferidos += 1
					perto(sprite.position.y, -Direcoes.base_de_quadro(float(altura)),
						"%s: o sprite da moldura de %d e ancorado nos pes" % [arquivo, altura])
				else:
					# Arte autorada, de moldura propria. O caso vivo e a Diretora.
					perto(sprite.position.y, 0.0,
						"%s: arte de moldura %d e centrada -- ela nao tem pes" % [arquivo, altura])
					ok(inimigo.get("largura_sombra") == 0.0,
						"%s: corpo centrado nao carrega sombra (ela nasceria dentro dele)" % arquivo)
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
				perto((pos as Vector2).y, -Direcoes.BASE_NO_QUADRO,
					"player.tscn: o Sprite e ancorado nos pes")

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
			perto(dados.deslocamento_sprite.y, -Direcoes.BASE_NO_QUADRO,
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

	# 2. Ao longo do ANDAR os modulos variam. E aqui que a biblioteca aparece --
	#    e a variacao vem da FRACAO, nao so da celula: desde a AND1 01 a escolha
	#    passa pelo terco do andar em que a sala esta. Varrer celulas com fracao
	#    fixa mediria so o hash, e o hash sozinho nao e mais quem decide.
	var vistas := {}
	for i in 16:
		var sala_i := _montar_com(CENA_SALA, dados, Vector2i(i, 0))
		sala_i.fracao_do_andar = float(i) / 15.0
		# A fracao e lida na montagem, entao a sala precisa remontar o visual.
		# Monta uma nova em vez de remontar: a suite mede o caminho real.
		sala_i.free()
		var outra := CENA_SALA.instantiate() as Sala
		outra.coordenadas_grid = Vector2i(i, 0)
		outra.fracao_do_andar = float(i) / 15.0
		outra.definir_visual(dados)
		outra.position = LONGE
		Engine.get_main_loop().root.add_child(outra)
		for t in _texturas_de_face(outra):
			vistas[t] = true
	ok(
		vistas.size() >= 2,
		"o andar veste modulos diferentes conforme avanca (%d de 2)" % vistas.size()
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
## As texturas DISTINTAS de face que a sala veste.
##
## Distintas, e nao um item por poligono: desde que a face abre no vao da porta
## (PAR 01), um lado com porta no meio vira DOIS quads da mesma textura. A
## pergunta que estes casos fazem sempre foi "quantos MODULOS a sala veste", e a
## contagem de filhos era so um atalho que deixou de valer -- contar poligonos
## faria a resposta mudar quando uma sala ganhasse uma porta a mais, sem nada
## sobre a arte ter mudado.
## QUE PARTE do modulo de face chega a tela.
##
## A UV e escrita em PIXELS e ancorada no canto do contorno (`Sala._texturizar`),
## e o quad de face tem `Sala.ALTURA_FACE` de altura. Se a textura for mais alta
## que a faixa, parte dela simplesmente nao e amostrada -- e nada avisa: o
## arquivo continua valido, o portao de densidade continua medindo o arquivo
## INTEIRO, e quem desenhar o proximo modulo desenha as cegas na metade que nao
## aparece.
##
## Este caso mede a faixa de `uv.y` de fato usada e a compara com a altura da
## textura. Ele nao exige que sejam iguais -- exige que a relacao esteja
## DECLARADA aqui, para deixar de ser acidente.
func _a_faixa_de_uv_da_face_e_declarada() -> void:
	var sala := CENA_SALA.instantiate() as Sala
	Engine.get_main_loop().root.add_child(sala)
	var raiz := sala.get_node_or_null("ParedeFace") as Node2D
	if raiz == null or raiz.get_child_count() == 0:
		ok(false, "a sala desenha face")
		sala.free()
		return
	var quad := raiz.get_child(0) as Polygon2D
	if quad == null or quad.texture == null:
		ok(false, "o primeiro trecho de face tem textura")
		sala.free()
		return

	var menor := INF
	var maior := -INF
	for p in quad.uv:
		menor = minf(menor, p.y)
		maior = maxf(maior, p.y)
	var altura := float(quad.texture.get_height())
	var usado := maior - menor
	ok(
		true,
		"MEDIDO -- uv.y de %.1f a %.1f (%.0f px) numa textura de %.0f px; ALTURA_FACE = %.0f"
			% [menor, maior, usado, altura, Sala.ALTURA_FACE]
	)
	perto(usado, Sala.ALTURA_FACE, "a faixa de uv da face tem a altura do quad", 0.5)
	sala.free()


func _texturas_de_face(sala: Sala) -> Array[String]:
	var achados: Array[String] = []
	var raiz := sala.get_node_or_null("ParedeFace") as Node2D
	if raiz != null:
		for filho in raiz.get_children():
			var poly := filho as Polygon2D
			if poly != null and poly.texture != null \
					and not achados.has(poly.texture.resource_path):
				achados.append(poly.texture.resource_path)
	sala.free()
	return achados


## O corredor usa EXATAMENTE a perspectiva da sala (LTD 12).
##
## Ele era a unica parte do jogo que continuava chapada depois da LTD 04:
## a sala ganhou topo e face, e atravessar de uma para outra trocava de
## perspectiva no meio do caminho. Nao ha erro no console para isso -- o jogo
## roda igual e o mundo so deixa de ser coerente.
##
## O que este caso cobra e a igualdade das faixas, e nao a existencia dos nos:
## o corredor desenha nas MESMAS faixas absolutas da `Sala`. Ele ja valeu -1 no
## no raiz, e ai o mesmo numero significava coisas diferentes nos dois -- o
## empate entre os dois chaos era desempatado por ordem de arvore, funcionando
## por acidente.
## SO o ultimo trecho anuncia o chefe (AND1 06).
##
## O corredor comum fica na noite base de PROPOSITO: "pintar cada metade com a
## cor da sala vizinha anunciaria o que ha do outro lado antes de o jogador
## chegar". O trecho pre-chefe e a excecao deliberada -- ali anunciar E o
## objetivo --, e por isso ele precisa de portao dos DOIS lados:
##
## - o trecho pre-chefe muda mesmo (senao a excecao e so uma bandeira);
## - o trecho comum NAO muda (senao o andar inteiro anuncia o chefe desde a
##   terceira porta, e a virada deixa de acontecer em um lugar so).
func _so_o_trecho_pre_chefe_anuncia_o_chefe() -> void:
	var comum := _corredor(false)
	var pre := _corredor(true)

	var chao_comum := comum.get_node_or_null("Chao") as Polygon2D
	var chao_pre := pre.get_node_or_null("Chao") as Polygon2D
	ok(chao_comum != null and chao_pre != null, "os dois corredores montam chao")
	if chao_comum != null and chao_pre != null:
		ok(chao_comum.texture != chao_pre.texture,
			"o trecho pre-chefe veste OUTRO chao -- ali anunciar e o objetivo")
		igual(chao_comum.modulate, Color.WHITE,
			"e o trecho comum fica na noite base, sem escurecer")
		ok(chao_pre.modulate.v < 1.0,
			"enquanto o pre-chefe escurece (%.2f) -- a iluminacao irregular do plano"
				% chao_pre.modulate.v)
		# O escurecimento vai no CHAO e nao no corredor inteiro: projetil e
		# telegrafo tem de manter o contraste deles, e o que muda e so o fundo
		# contra o qual eles sao lidos.
		igual(pre.modulate, Color.WHITE,
			"e o corredor inteiro NAO escurece -- so o chao dele")

	var face_comum := comum.get_node_or_null("ParedeFace") as Polygon2D
	var face_pre := pre.get_node_or_null("ParedeFace") as Polygon2D
	if face_comum != null and face_pre != null:
		ok(face_comum.texture != face_pre.texture,
			"e a face tambem muda: a parede do trecho final e a do chefe")

	comum.free()
	pre.free()


## Um corredor solto, pre-chefe ou nao.
func _corredor(pre_chefe: bool) -> Corredor:
	var c := Corredor.new()
	c.pre_chefe = pre_chefe
	Engine.get_main_loop().root.add_child(c)
	c.global_position = LONGE
	# ANTES do configurar, como o GerenciadorMapa faz: e ele que veste.
	c.configurar(Vector2.ZERO, Vector2(320.0, 0.0), 80.0)
	return c


func _o_corredor_usa_a_mesma_perspectiva_da_sala() -> void:
	# HORIZONTAL: a lateral norte fica virada para o sul e mostra face.
	var deitado := Corredor.new()
	Engine.get_main_loop().root.add_child(deitado)
	deitado.configurar(LONGE, LONGE + Vector2(480.0, 0.0), 80.0)
	igual(deitado.z_index, 0, "o no raiz do corredor nao desloca as faixas dos filhos")

	var face := deitado.get_node_or_null("ParedeFace") as Polygon2D
	ok(face != null, "o corredor horizontal desenha a face da parede")
	if face != null:
		igual(face.z_index, Sala.Z_PAREDE_FACE, "a face do corredor usa a faixa da sala")
		# A altura da face tem de ser a mesma da sala, senao a parede muda de
		# altura no meio da travessia.
		var caixa := _caixa_do_poligono(face.polygon)
		perto(
			caixa.size.y, Sala.ALTURA_FACE,
			"a face do corredor tem a altura da face da sala"
		)
	var topo := deitado.get_node_or_null("ParedeTopo") as Polygon2D
	ok(topo != null, "o corredor desenha o topo da parede")
	if topo != null:
		igual(topo.z_index, Sala.Z_PAREDE_TOPO, "o topo do corredor usa a faixa da sala")
	var chao := deitado.get_node_or_null("Chao") as Polygon2D
	if chao != null:
		igual(chao.z_index, Sala.Z_CHAO, "o chao do corredor usa a faixa da sala")
	deitado.free()

	# VERTICAL: as laterais apontam para leste e oeste, nenhuma se qualifica.
	# Nao desenhar face aqui e o resultado CERTO, e nao um caso faltando -- e a
	# mesma geometria que faz a parede de baixo de uma sala mostrar so o topo.
	var em_pe := Corredor.new()
	Engine.get_main_loop().root.add_child(em_pe)
	em_pe.configurar(LONGE, LONGE + Vector2(0.0, 480.0), 80.0)
	ok(
		em_pe.get_node_or_null("ParedeFace") == null,
		"o corredor vertical NAO desenha face: nenhum lado dele esta virado para a camera"
	)
	em_pe.free()


func _caixa_do_poligono(pontos: PackedVector2Array) -> Rect2:
	if pontos.is_empty():
		return Rect2()
	var caixa := Rect2(pontos[0], Vector2.ZERO)
	for ponto in pontos:
		caixa = caixa.expand(ponto)
	return caixa


## A regra operacional da direcao de arte: face e topo em 1:1 (LTD 15).
##
## `LOW_TOPDOWN_SQUARED` secao 24 chama isso de "a forma conferivel de todos os
## elementos compartilharem a mesma camera imaginaria". E a unica parte daquele
## documento que vira numero, e por isso ela vira teste.
##
## A razao importa porque ela E a perspectiva. Face muito maior que o topo le
## como parede vista quase de lado -- camera baixa; topo muito maior le como
## vista quase de cima -- camera alta. Os props sao desenhados supondo uma
## camera so, e se a parede escorregar para outra, eles deixam de pertencer a
## mesma cena sem que nada quebre.
##
## A folga de 25% e do plano, e nao inventada aqui: ela permite ajuste fino sem
## permitir mudanca de perspectiva.
func _a_razao_face_topo_fica_em_um_para_um() -> void:
	var topo := Sala.ESPESSURA_PAREDE - Sala.ALTURA_FACE
	ok(topo > 0.0, "sobra faixa de topo depois da face (%.0f de %.0f)" % [topo, Sala.ESPESSURA_PAREDE])
	if topo <= 0.0:
		return
	var razao := Sala.ALTURA_FACE / topo
	ok(
		razao >= 0.75 and razao <= 1.25,
		"a razao face:topo fica em 1:1 +/-25%% (achado %.2f) -- e o que fixa a camera imaginaria" % razao
	)


## `ParedeTopo` cerca a sala inteira; `ParedeFace` so aparece onde a camera ve a
## superficie vertical (LTD 15).
##
## Os dois lados desta asercao importam, e o segundo mais que o primeiro:
##
## - o TOPO e um poligono unico, o contorno inflado, entao ele cobre os quatro
##   lados por construcao. Medir a area dele contra a do contorno prova isso sem
##   depender de quantos lados a sala tem.
## - a FACE so pode aparecer nos lados virados para a camera. Face no lado de
##   BAIXO cobriria jogador, inimigo, projetil e telegrafo -- e a Solucao 1 do
##   documento (parede cortada) existe exatamente para impedir isso.
##
## O teste seria facil de enganar contando nos; ele compara GEOMETRIA: nenhum
## quad de face pode estar na metade de baixo do contorno.
func _o_topo_cerca_a_sala_e_a_face_so_aparece_ao_norte() -> void:
	for cena: PackedScene in [CENA_SALA, CENA_L, CENA_PILAR]:
		var sala := _montar(cena)
		var contorno := sala.contorno_local()
		var caixa := _caixa_do_poligono(contorno)

		var topo := sala.get_node_or_null("ParedeTopo") as Polygon2D
		ok(topo != null, "%s monta ParedeTopo" % cena.resource_path.get_file())
		if topo != null:
			var caixa_topo := _caixa_do_poligono(topo.polygon)
			ok(
				caixa_topo.size.x > caixa.size.x and caixa_topo.size.y > caixa.size.y,
				"%s: o topo cerca a sala pelos quatro lados" % cena.resource_path.get_file()
			)

		var raiz := sala.get_node_or_null("ParedeFace") as Node2D
		if raiz != null:
			for filho in raiz.get_children():
				var quad := filho as Polygon2D
				if quad == null:
					continue
				var c := _caixa_do_poligono(quad.polygon)
				# A face fica na METADE DE CIMA do contorno. Uma no lado de baixo
				# desenharia por cima da area de combate.
				ok(
					c.position.y < caixa.get_center().y,
					"%s: a face fica ao norte, longe de cobrir o combate (y %.0f)"
						% [cena.resource_path.get_file(), c.position.y]
				)
		sala.free()


## A progressao visual do andar nunca ANDA PARA TRAS (AND1 01).
##
## O andar conta uma historia: conservado, deteriorado, critico. Isso prepara a
## mecanica do chefe antes da luta -- quando ele comeca lento e enferrujado,
## parece natural porque o andar inteiro mostrou maquinas com o mesmo problema.
##
## A historia so funciona numa direcao. Uma sala mais funda que a anterior e
## mais CONSERVADA quebra a leitura, e o defeito e invisivel numa sala so: ele
## exige comparar duas, e o jogador compara sem perceber.
##
## Mede a funcao pura em vez de montar um andar: `textura_progressiva` e quem
## decide, e uma varredura da fracao de 0 a 1 cobre todos os andares possiveis
## de uma vez -- inclusive os curtos, onde o terco final chega mais cedo.
func _a_deterioracao_visual_nunca_decresce() -> void:
	var dados := DadosSala.new()
	var lista: Array[Texture2D] = []
	# Tres variantes, na ordem que a convencao pede: conservada -> critica.
	for nome in ["chao_andar1_a.png", "chao_andar1_b.png", "chao_andar1_c.png"]:
		var t: Texture2D = load("res://assets/texturas/" + nome)
		if t != null:
			lista.append(t)
	igual(lista.size(), 3, "as tres variantes de chao carregam")
	if lista.size() < 3:
		return
	dados.texturas_chao = lista

	var indice_anterior := -1
	var passos := 40
	var subiu := false
	for i in passos + 1:
		var fracao := float(i) / float(passos)
		var escolhida := dados.textura_progressiva(lista, 12345, fracao)
		var indice := lista.find(escolhida)
		ok(indice >= 0, "a escolha pertence a lista (fracao %.2f)" % fracao)
		if indice_anterior >= 0:
			ok(
				indice >= indice_anterior,
				"a deterioracao nao anda para tras (fracao %.2f: %d depois de %d)"
					% [fracao, indice, indice_anterior]
			)
			if indice > indice_anterior:
				subiu = true
		indice_anterior = indice
	# Piso: uma funcao que devolvesse sempre o mesmo indice passaria em todas as
	# comparacoes acima sem progredir nada.
	ok(subiu, "e ela de fato PROGRIDE ao longo do andar, nao fica no mesmo")
