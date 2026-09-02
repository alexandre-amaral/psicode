class_name Lobby
extends Node2D
## O espaco PERSISTENTE entre runs, e o novo centro do jogo.
##
## Ele nao e uma sala e nao e uma run. Nao ha `GerenciadorMapa`, nao ha
## composicao de inimigos, nao ha Deterioracao subindo e nao ha porta que tranca.
## Quem garante isso nao e a boa vontade desta cena: e `GameState.entrar_lobby()`,
## que DESLIGA a passiva em vez de so nao ligar -- quem chega aqui pode estar
## vindo de uma run que acabou.
##
## **A geometria e construida em codigo, e nao desenhada no `.tscn`.** E a mesma
## escolha que a `Sala` faz: o contorno e a fonte unica de onde saem colisao,
## parede, sombra e clamp de camera, e um poligono desenhado a mao no editor
## desalinha desses quatro sem erro nenhum no console. Aqui a fonte e `CONTORNO`.
##
## Ele reusa `RenderizadorParedes` e `SombraDeParede` de proposito. O Lobby tem
## de parecer o MESMO mundo do Andar 1 -- so mais seguro --, e sistema de parede
## proprio seria a forma mais rapida de ele virar "um menu em forma de mapa".

## Quanto o Lobby mede.
##
## 1024x640, e os dois numeros sao multiplos de 32 como a grade do projeto exige
## -- as salas guardam a MEIA dimensao no contorno, entao a dimensao inteira tem
## de ser multipla de 32 para a meia cair na grade de 16.
##
## Maior que a tela (960x544) de proposito: a camera precisa ter para onde
## andar. Um lobby do tamanho exato do quadro seria lido como uma tela, e o
## plano e explicito -- ele tem de parecer um LUGAR.
const LARGURA := 1024.0
const ALTURA := 640.0

## A faixa de parede, a mesma da sala.
const ESPESSURA_PAREDE := 64.0

const LAYER_PAREDE := 4

const TEXTURA_CHAO := "res://assets/texturas/chao_andar1_a.png"

## Os operadores que a baia oferece, na ordem em que ficam lado a lado.
const PERSONAGENS: Array[String] = [
	"res://src/player/personagem_raven.tres",
	"res://src/player/personagem_nova.tres",
]

## A cor da plataforma ACESA, e ela e da categoria SINAL.
##
## O `IDENTIDADE_VISUAL.md` e explicito: sinal e brilhante, mas sempre numa
## FORMA grande demais para ser confundida com projetil. A plataforma tem 96x32
## -- nenhum projetil do jogo e um retangulo desse tamanho --, e por isso ela
## pode acender sem competir com a leitura de combate que o Lobby nem tem.
const COR_ACESA := Color("30d9c4")
const COR_APAGADA := Color("242a3a")

@onready var _mundo: Node2D = $Mundo
@onready var _interativos: Node2D = $Mundo/Interativos
@onready var _ui: CanvasLayer = $UI

var _prompt: Label = null
var _plataformas: Dictionary = {}


func _ready() -> void:
	GameState.entrar_lobby()
	_montar_visual()
	_montar_paredes()
	_montar_prompt()
	_montar_estacoes()
	_posicionar_jogador()
	_equipar_detector()
	_pintar_plataformas()


## O contorno, em coordenadas locais e centrado na origem.
##
## Aberto (sem repetir o primeiro ponto no fim), porque e assim que
## `Geometry2D.triangulate_polygon` e o renderizador o querem -- a versao fechada
## devolve poligono vazio na triangulacao, que e uma armadilha ja registrada.
func contorno_local() -> PackedVector2Array:
	var meia := Vector2(LARGURA, ALTURA) * 0.5
	return PackedVector2Array([
		Vector2(-meia.x, -meia.y),
		Vector2(meia.x, -meia.y),
		Vector2(meia.x, meia.y),
		Vector2(-meia.x, meia.y),
	])


## Onde o jogador nasce.
##
## Um pouco abaixo do centro, e nao no meio: as estacoes ficam na metade de cima
## e nascer entre elas faria o jogador comecar dentro de um prompt de interacao,
## sem ter andado. A primeira coisa que ele faz tem de ser andar.
func ponto_de_spawn() -> Vector2:
	return Vector2(0.0, ALTURA * 0.25)


func _montar_visual() -> void:
	var contorno := contorno_local()

	var chao := Polygon2D.new()
	chao.name = "Chao"
	chao.polygon = contorno
	chao.z_index = Sala.Z_CHAO
	var textura: Texture2D = load(TEXTURA_CHAO) as Texture2D
	if textura != null:
		chao.texture = textura
		# A UV e em PIXELS e ancorada no CANTO, e a repeticao tem de ser ligada
		# na mao: o projeto nao define `default_texture_repeat`, entao o padrao e
		# Disabled e a textura sairia esticada UMA vez no lobby inteiro.
		chao.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		chao.texture_offset = -contorno[0]
	_mundo.add_child(chao)
	_mundo.move_child(chao, 0)

	var trechos: Array[PackedVector2Array] = []
	var total := contorno.size()
	for i in total:
		trechos.append(PackedVector2Array([contorno[i], contorno[(i + 1) % total]]))
	_mundo.add_child(SombraDeParede.construir(trechos, contorno))

	var topos: Array[Texture2D] = []
	for caminho in Sala.TOPOS_NEUTROS:
		var t := load(caminho) as Texture2D
		if t != null:
			topos.append(t)
	var faces: Array[Texture2D] = []
	# A face NEUTRA, e nao um modulo de tipo: o Lobby e mais organizado e menos
	# deteriorado que o Andar 1, e o modulo comum e justamente o que nao tem
	# tubulacao exposta nem ferrugem. O contraste com o setor e o ponto, e ele
	# sai de graca escolhendo a peca mais calma da mesma biblioteca.
	var face := load(Sala.FACE_NEUTRA) as Texture2D
	if face != null:
		faces.append(face)
	var cantos: Array[Texture2D] = []
	for caminho in Sala.CANTOS_NEUTROS:
		var c := load(caminho) as Texture2D
		if c != null:
			cantos.append(c)

	var sem_portas: Array[Porta] = []
	_mundo.add_child(RenderizadorParedes.construir(
		contorno, sem_portas, hash("lobby"), topos, faces, cantos))


func _montar_paredes() -> void:
	var contorno := contorno_local()
	var corpo := StaticBody2D.new()
	corpo.name = "Paredes"
	corpo.collision_layer = LAYER_PAREDE
	corpo.collision_mask = 0
	add_child(corpo)
	var total := contorno.size()
	for i in total:
		var segmento := SegmentShape2D.new()
		segmento.a = contorno[i]
		segmento.b = contorno[(i + 1) % total]
		var forma := CollisionShape2D.new()
		forma.shape = segmento
		corpo.add_child(forma)


## Poe o jogador no spawn e prende a camera ao Lobby.
##
## O clamp cresce `RenderizadorParedes.alcance()` alem do contorno pela mesma
## razao que o da sala: e essa folga que faz a faixa de parede aparecer no quadro
## em vez de o quadro parar na linha do chao.
func _posicionar_jogador() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	player.global_position = global_position + ponto_de_spawn()
	var camera := player.get_node_or_null("Camera") as Camera2D
	if camera == null:
		return
	var margem := RenderizadorParedes.alcance()
	var meia := Vector2(LARGURA, ALTURA) * 0.5
	camera.limit_left = int(global_position.x - meia.x - margem)
	camera.limit_top = int(global_position.y - meia.y - margem)
	camera.limit_right = int(global_position.x + meia.x + margem)
	camera.limit_bottom = int(global_position.y + meia.y + margem)


# ------------------------------------------------------------- estacoes ------

## As tres estacoes, e o espaco vazio que sobra é reservado.
##
## O plano manda o Lobby aceitar expansao SEM criar dez espacos enormes vazios.
## A metade de baixo fica livre: cabe sala de upgrades, NPC e codex, e ela nao
## precisa de porta fechada nenhuma para isso -- chao vazio ja e convite.
func _montar_estacoes() -> void:
	var meia := Vector2(LARGURA, ALTURA) * 0.5

	# A BAIA: as capsulas lado a lado, na metade de cima.
	var passo := 176.0
	var base := Vector2(-passo * 0.5 * (PERSONAGENS.size() - 1), -meia.y + 176.0)
	for i in PERSONAGENS.size():
		var dados: DadosPersonagem = load(PERSONAGENS[i]) as DadosPersonagem
		if dados == null:
			continue
		_montar_capsula(dados, base + Vector2(passo * i, 0.0))

	_montar_terminal(Vector2(-meia.x + 208.0, 0.0))
	_montar_elevador(Vector2(meia.x - 208.0, 0.0))


## Uma capsula de operador: plataforma, retrato e o gatilho.
##
## O retrato usa a `miniatura`, e nao o sprite de 80: aquela moldura existe para
## o quadro mais largo do conjunto de rotacoes e deixa vazio dos dois lados --
## num painel o personagem sairia pequeno demais. A miniatura ja vem recortada no
## alfa e em escala INTEIRA, a unica que nao borra pixel art.
func _montar_capsula(dados: DadosPersonagem, onde: Vector2) -> void:
	var raiz := Node2D.new()
	raiz.name = "Capsula_%s" % dados.id
	raiz.position = onde
	_interativos.add_child(raiz)

	var plataforma := Polygon2D.new()
	plataforma.name = "Plataforma"
	plataforma.polygon = PackedVector2Array([
		Vector2(-48.0, -16.0), Vector2(48.0, -16.0),
		Vector2(48.0, 16.0), Vector2(-48.0, 16.0),
	])
	plataforma.color = COR_APAGADA
	# Abaixo do mundo ordenado por Y: a plataforma e chao, e o personagem em
	# cima dela tem de desenhar por cima.
	plataforma.z_index = Sala.Z_CHAO_DETALHE
	plataforma.z_as_relative = false
	raiz.add_child(plataforma)
	_plataformas[String(dados.id)] = plataforma

	if dados.miniatura != null:
		var retrato := Sprite2D.new()
		retrato.name = "Retrato"
		retrato.texture = dados.miniatura
		# Ancorado pela BASE, como todo ator do projeto: centrado, o personagem
		# flutuaria meio corpo acima da plataforma.
		retrato.position = Vector2(0.0, -dados.miniatura.get_height() * 0.5)
		raiz.add_child(retrato)

	var gatilho := Interativo.new()
	gatilho.name = "Gatilho"
	gatilho.id = dados.id
	gatilho.texto = tr("Selecionar") + " " + dados.nome
	gatilho.alcance = 64.0
	gatilho.interagido.connect(func(_quem: Node2D) -> void:
		_selecionar_personagem(String(dados.id))
	)
	raiz.add_child(gatilho)


func _montar_terminal(onde: Vector2) -> void:
	var raiz := Node2D.new()
	raiz.name = "TerminalDeHistorico"
	raiz.position = onde
	_interativos.add_child(raiz)
	_montar_movel(raiz, Vector2(56.0, 40.0), Color("31384c"), Color("1e5a6b"))

	var gatilho := Interativo.new()
	gatilho.id = &"historico"
	gatilho.texto = tr("Histórico de Runs")
	gatilho.alcance = 64.0
	gatilho.interagido.connect(func(_quem: Node2D) -> void: _abrir_historico())
	raiz.add_child(gatilho)


## O ELEVADOR: a entrada fisica do Andar 1.
##
## Elevador e nao porta generica, e a escolha e do plano: e ele que conecta
## visualmente o Lobby ao setor deteriorado do outro lado. A run comeca descendo
## para algum lugar, e nao atravessando um vao qualquer.
func _montar_elevador(onde: Vector2) -> void:
	var raiz := Node2D.new()
	raiz.name = "EntradaAndar01"
	raiz.position = onde
	_interativos.add_child(raiz)
	_montar_movel(raiz, Vector2(64.0, 56.0), Color("242a3a"), Color("6b4d1e"))

	var gatilho := Interativo.new()
	gatilho.id = &"andar_01"
	gatilho.texto = tr("Iniciar Andar 1")
	gatilho.alcance = 72.0
	gatilho.interagido.connect(func(_quem: Node2D) -> void: _confirmar_run())
	raiz.add_child(gatilho)


## Um movel do lobby: corpo escuro, painel aceso e sombra de contato.
##
## Solido de verdade e nao decoracao: um terminal que se atravessa denuncia que
## o Lobby e um menu com chao. A colisao entra na layer 3 (`parede`), a mesma dos
## obstaculos da sala, para o Player nao precisar de mask nova.
func _montar_movel(raiz: Node2D, meia: Vector2, corpo: Color, painel: Color) -> void:
	var sombra := Polygon2D.new()
	sombra.polygon = PackedVector2Array([
		Vector2(-meia.x, meia.y - 6.0), Vector2(meia.x, meia.y - 6.0),
		Vector2(meia.x, meia.y + 10.0), Vector2(-meia.x, meia.y + 10.0),
	])
	sombra.color = Color(0.02, 0.024, 0.043, 0.34)
	sombra.z_index = Sala.Z_SOMBRA_PAREDE
	sombra.z_as_relative = false
	raiz.add_child(sombra)

	var bloco := Polygon2D.new()
	bloco.polygon = PackedVector2Array([
		Vector2(-meia.x, -meia.y), Vector2(meia.x, -meia.y),
		Vector2(meia.x, meia.y), Vector2(-meia.x, meia.y),
	])
	bloco.color = corpo
	raiz.add_child(bloco)

	var luz := Polygon2D.new()
	luz.polygon = PackedVector2Array([
		Vector2(-meia.x + 10.0, -meia.y + 10.0), Vector2(meia.x - 10.0, -meia.y + 10.0),
		Vector2(meia.x - 10.0, -meia.y + 24.0), Vector2(-meia.x + 10.0, -meia.y + 24.0),
	])
	luz.color = painel
	raiz.add_child(luz)

	var solido := StaticBody2D.new()
	solido.collision_layer = LAYER_PAREDE
	solido.collision_mask = 0
	var forma := CollisionShape2D.new()
	var caixa := RectangleShape2D.new()
	caixa.size = meia * 2.0
	forma.shape = caixa
	solido.add_child(forma)
	raiz.add_child(solido)


# ------------------------------------------------------------------ ui -------

## O prompt, e ele e o UNICO HUD do Lobby.
##
## Nada de barra de vida, barra de Deterioracao, contador de sala ou minimapa --
## e isso nao e economia de tela, e leitura. Uma barra de Deterioracao parada em
## zero MENTE: ela diz que existe um relogio correndo. O HUD e onde o jogador le
## se esta em perigo, e o Lobby precisa dizer que nao esta.
func _montar_prompt() -> void:
	_prompt = Label.new()
	_prompt.name = "Prompt"
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -240.0
	_prompt.offset_right = 240.0
	_prompt.offset_top = -72.0
	_prompt.offset_bottom = -40.0
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	_prompt.add_theme_color_override("font_color", COR_ACESA)
	_ui.add_child(_prompt)


func _equipar_detector() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var detector := DetectorDeInteracao.new()
	detector.name = "DetectorDeInteracao"
	detector.dono = player
	# Layer 6 e `pickup`: o detector nao e um pickup, mas e uma Area2D que so
	# precisa VER outras areas, e a mask dele e quem manda. Ele monitora tudo e
	# filtra por tipo em `_ao_entrar`, que e mais barato de manter do que uma
	# layer nova so para tres objetos.
	detector.collision_layer = 0
	detector.collision_mask = 0xFFFFFFFF
	detector.alvo_mudou.connect(_ao_alvo_mudar)
	player.add_child(detector)


func _ao_alvo_mudar(texto: String) -> void:
	if _prompt == null:
		return
	_prompt.visible = not texto.is_empty()
	if not texto.is_empty():
		_prompt.text = "[E] %s" % texto


## Acende a plataforma de quem esta selecionado e apaga as outras.
##
## A escolha tem de ser OBVIA sem texto: quem chega perto ve qual capsula esta
## ligada antes de ler qualquer coisa.
func _pintar_plataformas() -> void:
	var atual := Progressao.personagem_selecionado()
	for id: String in _plataformas:
		var plataforma: Polygon2D = _plataformas[id]
		if is_instance_valid(plataforma):
			plataforma.color = COR_ACESA if id == atual else COR_APAGADA


# ------------------------------------------------------------- acoes ---------

## Escolhe um operador e GRAVA na hora.
##
## Sem botao "Aplicar", como em `Configuracao`: e um passo a mais para o jogador
## errar e um estado intermediario a mais para o codigo carregar. Trocar de
## personagem e fechar o jogo tem de manter a troca.
func _selecionar_personagem(id: String) -> void:
	if not Progressao.carregado():
		return
	if not Progressao.selecionar_personagem(id):
		return
	for caminho in PERSONAGENS:
		var dados: DadosPersonagem = load(caminho) as DadosPersonagem
		if dados != null and String(dados.id) == id:
			GameState.personagem = dados
			break
	_pintar_plataformas()


## O terminal: a prova de que o save funciona.
##
## Ele nao e conteudo. E o unico lugar onde o jogador ve que a run foi
## registrada -- sem ele, a persistencia inteira e uma afirmacao que ninguem
## consegue conferir sem abrir o JSON.
func _abrir_historico() -> void:
	var linhas: Array[String] = []
	var stats := Progressao.estatisticas()
	linhas.append("%s: %d    %s: %d    %s: %d" % [
		tr("TOTAL"), int(stats.get("total_runs", 0)),
		tr("VITÓRIAS"), int(stats.get("total_vitorias", 0)),
		tr("DERROTAS"), int(stats.get("total_derrotas", 0)),
	])
	linhas.append("")
	var historico := Progressao.historico()
	if historico.is_empty():
		linhas.append(tr("Nenhuma run registrada ainda."))
	else:
		for r in historico:
			linhas.append("#%-4d %-8s %-9s %s %d   %s   %d %s" % [
				r.id, r.personagem.to_upper(),
				tr("Vitória") if r.venceu else tr("Derrota"),
				tr("Andar"), r.andar_alcancado,
				GameState.formatar_tempo(r.duracao), r.kills, tr("abates"),
			])
	_abrir_painel(tr("HISTÓRICO DE RUNS"), "\n".join(linhas), [tr("FECHAR")], func(_i: int) -> void: pass)


## A confirmacao antes da run.
##
## Uma run e um compromisso de dez minutos; entrar nela por esbarrao e o tipo de
## coisa que so aparece no playtest, tarde.
func _confirmar_run() -> void:
	var nome := Progressao.personagem_selecionado().to_upper()
	_abrir_painel(
		tr("INICIAR ANDAR 1"),
		"%s %s?" % [tr("Iniciar run com"), nome],
		[tr("INICIAR"), tr("CANCELAR")],
		func(indice: int) -> void:
			if indice == 0:
				_iniciar_run()
	)


## Vai para o Andar 1.
##
## Quem liga a Deterioracao passiva continua sendo `GameState.iniciar_run()`,
## chamado pelo `_ready` do `GerenciadorMapa` -- e nao aqui. Essa chamada JA se
## perdeu uma vez ao trocar quem hospeda a run, e o sintoma foi silencioso: a
## barra simplesmente parou de subir. Este caminho e uma camada a mais entre ela
## e o jogador, entao ele nao pode duplicar a responsabilidade.
func _iniciar_run() -> void:
	var id := Progressao.personagem_selecionado()
	for caminho in PERSONAGENS:
		var dados: DadosPersonagem = load(caminho) as DadosPersonagem
		if dados != null and String(dados.id) == id:
			GameState.personagem = dados
			break
	get_tree().change_scene_to_file(GameState.CENA_MAIN)


## Um painel modal, com a arvore PAUSADA.
##
## O gameplay do Lobby para enquanto o painel esta aberto -- e o plano pede isso
## para o terminal. O painel roda em `PROCESS_MODE_ALWAYS` pela mesma razao que
## o menu de pausa: com a arvore parada, quem tem de continuar respondendo e
## justamente quem vai despausar.
func _abrir_painel(titulo: String, corpo: String, botoes: Array,
		ao_escolher: Callable) -> void:
	get_tree().paused = true
	var fundo := ColorRect.new()
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.color = Color(0.02, 0.024, 0.043, 0.85)
	fundo.process_mode = Node.PROCESS_MODE_ALWAYS
	_ui.add_child(fundo)

	var caixa := VBoxContainer.new()
	caixa.set_anchors_preset(Control.PRESET_CENTER)
	caixa.offset_left = -340.0
	caixa.offset_right = 340.0
	caixa.offset_top = -180.0
	caixa.offset_bottom = 180.0
	caixa.add_theme_constant_override("separation", 12)
	fundo.add_child(caixa)

	var rotulo := Label.new()
	rotulo.text = titulo
	rotulo.add_theme_color_override("font_color", COR_ACESA)
	caixa.add_child(rotulo)

	var texto := Label.new()
	texto.text = corpo
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caixa.add_child(texto)

	for i in botoes.size():
		var botao := Button.new()
		botao.text = str(botoes[i])
		botao.process_mode = Node.PROCESS_MODE_ALWAYS
		var indice := i
		botao.pressed.connect(func() -> void:
			fundo.queue_free()
			get_tree().paused = false
			ao_escolher.call(indice)
		)
		caixa.add_child(botao)
		if i == 0:
			botao.grab_focus()
