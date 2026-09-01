extends Node
## A CAIXA: a cena que prova a arquitetura antes de existir gerador de parede.
##
## Ela responde uma pergunta so, e e a pergunta de aceitacao do epico das
## paredes:
##
##   **A sala parece uma caixa arquitetonica aberta para a camera, ou um
##   tabuleiro com borda?**
##
## Se a resposta for "tabuleiro", o problema e PERSPECTIVA e PROPORCAO, e nenhuma
## quantidade de ferrugem, tubo ou painel conserta isso. O plano e explicito: se
## a silhueta falhar, revisar altura da face, espessura do topo, cantos, parede
## sul e posicao do chao ANTES de acrescentar um unico detalhe.
##
## **Ela nao e o `sala_prototipo.tscn`.** Aquele monta o andar 1 inteiro -- chao,
## props, atores, telegrafo, mostruario de face -- e responde "o conteudo da
## LTD 14 esta completo?", que e outra pergunta. Esta cena e POBRE de proposito:
## sem prop, sem decalque, sem prop animado, sem pickup. Se ela ficar boa, e a
## arquitetura que esta funcionando, e nao a decoracao.
##
## **A sala e menor que a tela, e isso e a peca inteira.** As salas do jogo tem
## 960x544 de contorno e a faixa de parede soma 64 de cada lado: 1088x672 contra
## uma tela de 960x544, entao com o jogador no centro nenhuma parede aparece
## (medido em `docs/PIVO_PAREDES.md` §5). O `sala_prototipo` contorna isso com
## zoom 0,72 -- e zoom fracionario BORRA pixel art, o que e aceitavel para
## conferir cor e nao para julgar silhueta. Aqui a sala e de 480x352, a moldura
## inteira cabe em 608x480, e a camera fica em **zoom 1.0, escala inteira**. O
## que se ve e o que o jogo desenha, pixel a pixel.
##
## Uso: godot --path . tools/teste_paredes.tscn --resolution 960x544
## Sai em user://capturas/paredes_*.png

const SAIDA := "user://capturas"
const CENA_SALA := preload("res://src/mapa/sala_1_retangular.tscn")
const CENA_PLAYER := preload("res://src/player/player.tscn")
const CENA_DRONE := preload("res://src/enemies/drone_aranha.tscn")
const CENA_PROJETIL := preload("res://src/projectiles/projetil.tscn")
const DADOS_COMBATE := preload("res://src/mapa/tipo_combate.tres")
const PERSONAGEM := preload("res://src/player/personagem_raven.tres")
const ARMA_PLAYER := preload("res://src/weapons/pistola.tres")

## Os seis modulos da PAREDE 03. Eles sao montados A MAO aqui, e nao por um
## renderizador: o plano manda provar a forma antes de escrever o sistema, e este
## laco e o rascunho que a PAREDE 04 promove a `RenderizadorParedes`.
const MODULO_N := preload("res://assets/texturas/modulo_n.png")
const MODULO_S := preload("res://assets/texturas/modulo_s.png")
const MODULO_L := preload("res://assets/texturas/modulo_l.png")
const MODULO_O := preload("res://assets/texturas/modulo_o.png")
const CANTO_NO := preload("res://assets/texturas/modulo_canto_no.png")
const CANTO_NE := preload("res://assets/texturas/modulo_canto_ne.png")

## Onde a fita de modulos desenha: acima da parede antiga, abaixo de `Z_MUNDO`.
##
## A parede antiga continua embaixo de proposito (o fallback vivo que o plano
## pede): onde a fita ainda nao cobre -- os dois cantos de baixo, que sao a
## PAREDE 06, e o vao da porta -- e ela que aparece.
const Z_MODULO := -13

## 15 x 11 tiles de 32. Multiplos de 32 nas duas dimensoes, entao a MEIA dimensao
## cai na grade de 16 -- que e o que `teste_grade.gd` cobra de toda sala, e a
## razao pela qual dimensao impar de tile nao serve.
const LARGURA := 480.0
const ALTURA := 352.0

## Espera antes de cada foto. O jogador cai no chao e o inimigo acorda; fotografar
## no primeiro frame pega o `_ready` e nao o jogo.
const ESPERA := 0.8

## Onde o jogador para em cada foto.
##
## A do NORTE e a do SUL nao sao capricho: elas sao o teste da assimetria. A
## parede norte mostra topo E face, entao o jogador encostado nela some atras de
## 32 px de metal se a face for alta demais; a sul mostra so o topo justamente
## para isso nao acontecer. Duas fotos, e a pergunta se responde comparando.
const POSTOS := {
	"01_geral": Vector2(0.0, 0.0),
	"02_norte": Vector2(0.0, -ALTURA * 0.5 + 24.0),
	"03_sul": Vector2(0.0, ALTURA * 0.5 - 24.0),
}

var _sala: Sala = null
var _player: Node2D = null
var _camera: Camera2D = null
var _restantes: Array[String] = []
var _t: float = 0.0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAIDA)
	GameState.personagem = PERSONAGEM

	_sala = CENA_SALA.instantiate() as Sala
	# ANTES do add_child, e sao as duas coisas que o `_ready` da sala consome: o
	# contorno vira colisao, camera, minimapa e parede, e a posicao das portas
	# vira o vao que a parede abre. Depois do add_child nada disso reage.
	_encolher(_sala)
	_sala.definir_visual(DADOS_COMBATE)
	# Norte e sul conectados: as outras duas portas se selam sozinhas, e porta
	# selada nao desenha nada. Sobram exatamente as duas que o plano pede.
	_sala.configurar_conexoes([Vector2.UP, Vector2.DOWN])
	add_child(_sala)

	_montar_modulos()
	_montar_atores()
	_montar_camera()
	# Laco explicito: `Dictionary.keys()` devolve `Array` SEM tipo, e atribuir
	# isso a um `Array[String]` explode em runtime. Mesma armadilha que o
	# `Array[Node].filter()` ja registrou no GEMINI.md.
	for nome: String in POSTOS:
		_restantes.append(nome)


## O contorno de 480x352 e as portas nas bordas novas.
##
## A sala retangular do jogo tem 960x544. Encolher em vez de criar uma cena nova
## e deliberado: o que se quer medir e a PAREDE que o jogo desenha, e uma cena
## propria acabaria divergindo da de verdade no dia em que uma delas mudasse.
func _encolher(sala: Sala) -> void:
	var meia := Vector2(LARGURA, ALTURA) * 0.5
	var linha := sala.get_node_or_null("Parede") as Line2D
	if linha == null:
		push_error("teste_paredes: a sala nao tem o Line2D 'Parede'")
		return
	# Fechado, como o `.tscn` guarda: o primeiro ponto se repete no fim.
	linha.points = PackedVector2Array([
		Vector2(-meia.x, -meia.y), Vector2(meia.x, -meia.y),
		Vector2(meia.x, meia.y), Vector2(-meia.x, meia.y),
		Vector2(-meia.x, -meia.y),
	])

	var portas := sala.get_node_or_null("Portas")
	if portas == null:
		return
	var onde := {
		"Porta_Norte": Vector2(0.0, -meia.y), "Porta_Sul": Vector2(0.0, meia.y),
		"Porta_Leste": Vector2(meia.x, 0.0), "Porta_Oeste": Vector2(-meia.x, 0.0),
	}
	for nome: String in onde:
		var porta := portas.get_node_or_null(nome) as Node2D
		if porta != null:
			porta.position = onde[nome]


## A FITA DE MODULOS, montada a mao.
##
## Um sprite por celula de 32 px ao longo de cada lado, mais os dois cantos de
## cima. E o rascunho do `RenderizadorParedes`: o que se prova aqui e que a fita
## FECHA -- que 32 px encostam em 32 px sem fresta e sem sobreposicao --, e isso
## nao se prova em textura esticada.
##
## Os cantos de BAIXO ficam de fora porque ainda nao existem: eles resolvem a
## transicao entre lateral alta e parede sul baixa, que e problema proprio. A
## foto mostra os dois regimes lado a lado, e e util que mostre.
func _montar_modulos() -> void:
	var raiz := Node2D.new()
	raiz.name = "ModulosDeParede"
	raiz.z_index = Z_MODULO
	_sala.add_child(raiz)

	var meia := Vector2(LARGURA, ALTURA) * 0.5
	var banda := Sala.ESPESSURA_PAREDE
	var passo := 32.0

	# Norte e sul: a fita corre em x.
	var x := -meia.x
	while x < meia.x - 0.5:
		if not _vao_de_porta(Vector2.UP, x, x + passo):
			_modulo(raiz, MODULO_N, Vector2(x + passo * 0.5, -meia.y - banda * 0.5))
		if not _vao_de_porta(Vector2.DOWN, x, x + passo):
			_modulo(raiz, MODULO_S, Vector2(x + passo * 0.5, meia.y + banda * 0.5))
		x += passo

	# Leste e oeste: a fita corre em y.
	var y := -meia.y
	while y < meia.y - 0.5:
		if not _vao_de_porta(Vector2.RIGHT, y, y + passo):
			_modulo(raiz, MODULO_L, Vector2(meia.x + banda * 0.5, y + passo * 0.5))
		if not _vao_de_porta(Vector2.LEFT, y, y + passo):
			_modulo(raiz, MODULO_O, Vector2(-meia.x - banda * 0.5, y + passo * 0.5))
		y += passo

	_modulo(raiz, CANTO_NO, Vector2(-meia.x - banda * 0.5, -meia.y - banda * 0.5))
	_modulo(raiz, CANTO_NE, Vector2(meia.x + banda * 0.5, -meia.y - banda * 0.5))


## Esta celula cai no vao de uma porta?
##
## E aqui que aparece um numero que o plano nao previu: **`Porta.LARGURA` e 80, e
## 80 nao e multiplo de 32.** O plano desenha `[wall][wall][DOOR][DOOR][wall]`,
## com a porta ocupando celulas inteiras, e com 80 ela ocupa 2,5. As celulas das
## pontas ficam meio dentro e meio fora, e nao ha modulo que sirva.
##
## Aqui isso e resolvido do jeito honesto e provisorio: a celula que ENCOSTA no
## vao nao recebe modulo, e a parede antiga aparece por baixo. A foto mostra o
## desalinhamento em vez de escondе-lo, que e o que faz dele um achado da
## PAREDE 07 e nao uma surpresa dela.
func _vao_de_porta(lado: Vector2, de: float, ate: float) -> bool:
	var portas := _sala.get_node_or_null("Portas")
	if portas == null:
		return false
	for filho in portas.get_children():
		var porta := filho as Porta
		if porta == null or porta.esta_selada() or porta.vetor() != lado:
			continue
		var centro := porta.position.x if absf(lado.y) > 0.5 else porta.position.y
		var meia := Porta.LARGURA * 0.5
		if ate > centro - meia and de < centro + meia:
			return true
	return false


func _modulo(raiz: Node2D, textura: Texture2D, onde: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = textura
	sprite.position = onde
	raiz.add_child(sprite)


## O jogador, um inimigo e dois projeteis parados.
##
## Os projeteis sao o item mais facil de esquecer e o mais importante: um deles
## fica SOBRE a face e o outro sobre o chao, porque a pergunta que a parede nova
## nao pode responder errado e "um tiro continua legivel na frente dela?".
func _montar_atores() -> void:
	_player = CENA_PLAYER.instantiate() as Node2D
	_sala.add_child(_player)

	var drone := CENA_DRONE.instantiate() as Node2D
	drone.position = Vector2(120.0, 40.0)
	_sala.add_child(drone)

	# Sobre a FACE do norte: ela ocupa `ALTURA_FACE` acima da linha do contorno.
	_projetil(Vector2(-140.0, -ALTURA * 0.5 - Sala.ALTURA_FACE * 0.5), false)
	# E sobre o chao, para a comparacao ter os dois fundos.
	_projetil(Vector2(-60.0, 40.0), true)


func _projetil(onde: Vector2, hostil: bool) -> void:
	var p := CENA_PROJETIL.instantiate()
	p.name = "Projetil_%s" % ("hostil" if hostil else "player")
	_sala.add_child(p)
	# add_child ANTES de configurar, como a Arma faz.
	if p.has_method("configurar"):
		p.configurar(onde, Vector2.RIGHT, ARMA_PLAYER, hostil)
	p.position = onde
	p.set_physics_process(false)
	p.set_process(false)
	# Parar o processamento nao basta: o projetil continua no espaco de fisica e
	# some ao encostar em alguem. Armadilha ja registrada no `sala_prototipo`.
	if p is Area2D:
		(p as Area2D).monitoring = false
		(p as Area2D).monitorable = false
	for filho in p.get_children():
		var forma := filho as CollisionShape2D
		if forma != null:
			forma.set_deferred("disabled", true)


## A camera da cena, em ZOOM 1.0.
##
## Ela e propria e nao a do jogador pelo mesmo motivo do `sala_prototipo`: a do
## jogo e clampada e nunca mostra mais de uma parede. Mas aqui ela nao precisa de
## zoom nenhum -- a sala inteira mais a faixa cabem em 608x480 dentro de 960x544
## --, e isso e o ponto: julgar silhueta com zoom fracionario e julgar uma imagem
## borrada.
func _montar_camera() -> void:
	if _player != null:
		var dele := _player.get_node_or_null("Camera") as Camera2D
		if dele != null:
			dele.enabled = false
	_camera = Camera2D.new()
	_camera.name = "CameraDaCena"
	_camera.zoom = Vector2.ONE
	_camera.position = _sala.global_position
	add_child(_camera)
	_camera.make_current()


func _process(delta: float) -> void:
	if _restantes.is_empty():
		return
	_t += delta
	if _t < ESPERA:
		return
	_t = 0.0
	var nome: String = _restantes.pop_front()
	if _player != null:
		_player.position = POSTOS[nome]
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var caminho := "%s/paredes_%s.png" % [SAIDA, nome]
	get_viewport().get_texture().get_image().save_png(caminho)
	print("capturado: %s" % ProjectSettings.globalize_path(caminho))
	if _restantes.is_empty():
		_conferir()
		get_tree().quit()


## O que a foto TEM de conter. Conferido em vez de confiado a quem edita a cena.
##
## A lista e curta de proposito: esta cena e sobre arquitetura. Canto ainda nao
## esta aqui porque canto ainda nao existe -- ele e a PAREDE 06, e quando chegar
## esta conferencia cresce com ele.
func _conferir() -> void:
	var faltando: Array[String] = []
	if _sala.get_node_or_null("Chao") == null:
		faltando.append("chao")
	if _sala.get_node_or_null("ParedeTopo") == null:
		faltando.append("topo")
	var face := _sala.get_node_or_null("ParedeFace")
	if face == null or face.get_child_count() == 0:
		faltando.append("face")
	var abertas := 0
	for filho in _sala.get_node("Portas").get_children():
		var porta := filho as Porta
		if porta != null and not porta.esta_selada():
			abertas += 1
	if abertas != 2:
		faltando.append("duas portas (achei %d)" % abertas)
	if _sala.get_node_or_null("Projetil_player") == null:
		faltando.append("projetil do jogador")
	if _sala.get_node_or_null("Projetil_hostil") == null:
		faltando.append("projetil hostil")

	if faltando.is_empty():
		print("a caixa esta montada: chao, topo, face, duas portas e dois projeteis")
	else:
		print("teste_paredes: FALTANDO %s" % ", ".join(faltando))
