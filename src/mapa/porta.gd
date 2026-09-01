class_name Porta
extends Area2D
## Passagem entre duas salas: detecta o player e avisa quem cuida da transicao.
##
## Decisao de design: o lockdown do GDD precisa ser fisico, nao visual. Por isso
## a porta carrega um StaticBody2D ("Barreira") que fecha o vao enquanto o
## estado nao for ABERTA. Antes disso a porta trancada era so um Area2D com
## monitoring desligado — o jogador passava direto por ela e a sala nunca
## prendia ninguem.
##
## O estado SELADA existe para o lado do grid que nao tem vizinho: ali a parede
## e definitiva, entao a porta nunca reabre, nunca aparece e NAO POE BARREIRA --
## quem fecha aquele lado e a parede da sala, que passa reta por cima dela.
##
## ARTE POR LADO, E NUNCA ARTE GIRADA (PORTA 03). A porta era a MESMA imagem
## rotacionada nas quatro direcoes -- 180 graus no sul, 90 no leste, -90 no
## oeste. Numa perspectiva em que parede tem topo e face, girar uma face e
## exatamente destruir a perspectiva, e e a mesma razao pela qual o sprite
## direcional tem oito desenhos em vez de um girado.
##
## O numero de vistas nao foi escolhido: ele sai do que a PAREDE ja faz.
## `Sala._montar_faces()` so desenha face nos lados virados para a camera, entao
## o norte mostra FACE e o sul, o leste e o oeste mostram TOPO. A porta precisa
## concordar com a parede em que ela esta:
##
##   NORTE  `porta_moldura` + `porta_folha` -- a vista de frente, autorada.
##   SUL    `porta_topo`    + `porta_folha_topo`  -- a vista de cima.
##   LESTE  `porta_lado`    + `porta_folha_lado`  -- a vista de cima, outro eixo.
##   OESTE  as texturas do leste ESPELHADAS em x. Espelhar nao gira nada.
##
## Sao tres artes para quatro lados, e a quarta e um espelho. `direcao` continua
## sendo a fonte de verdade da orientacao logica (`vetor()`); o figurino so
## escolhe o que se desenha.
##
## Visual em quatro pecas: a "Moldura" e o batente e nunca some; o "Vao" e o
## recesso escuro atras dela, pintado de escuridao porque corredor nao revelado
## e o desconhecido e nao parede; as duas metades da "Folha" sao a chapa que
## fecha a passagem; e a "Trava" e a unica peca em paleta SINAL -- uma barra
## atravessando a abertura, brilhante de proposito, porque o jogador tem de
## saber de longe que aquela porta esta trancada.

enum Direcao { NORTE, SUL, LESTE, OESTE }
enum Estado { ABERTA, TRANCADA, SELADA }

## Vao que a parede da sala precisa abrir para caber esta porta.
const LARGURA := 80.0

## A ABERTURA, em segundos, e o TETO dela.
##
## A sequencia e "motor liga -> porta vibra -> trava solta -> folhas partem", e
## ela existe para reforcar a idade do setor: uma maquina velha custa a comecar,
## que e a mesma ideia que o chefe do andar carrega.
##
## O teto nao e decoracao. O jogador atravessa dez salas por andar, e meio
## segundo a mais por porta sao cinco segundos parados por run -- num jogo cujo
## sistema-assinatura e uma barra que sobe com o TEMPO. Por isso ele e const e
## nao `@export`: e um limite de design, e nao um botao de tuning.
const TEMPO_DE_ABERTURA := 0.42
const TEMPO_MAXIMO_DE_ABERTURA := 0.6

## Quanto a porta treme enquanto o motor pega, em px.
const TREMOR := 1.5

## Quanto cada metade da folha recolhe, em px.
##
## E meia abertura: as duas metades somadas liberam os 32 px de vao que a
## moldura autorada tem. E 16 cabe atras de um batente de 24 com folga -- e o
## batente que ESCONDE a folha recolhida, e nao um `visible = false`, que e o
## que separa "recolheu" de "sumiu".
const RECUO_DA_FOLHA := 16.0

const CAMINHO_BARREIRA := ^"Barreira/Colisao"
const CAMINHO_COLISAO := ^"Collision"
const CAMINHO_MOLDURA := ^"Moldura"
const CAMINHO_FOLHA_A := ^"FolhaA"
const CAMINHO_FOLHA_B := ^"FolhaB"
const CAMINHO_TRAVA := ^"Trava"
const CAMINHO_VAO := ^"Vao"

const TEXTURA_MOLDURA := preload("res://assets/texturas/porta_moldura.png")
const TEXTURA_TOPO := preload("res://assets/texturas/porta_topo.png")
const TEXTURA_LADO := preload("res://assets/texturas/porta_lado.png")
const TEXTURA_FOLHA := preload("res://assets/texturas/porta_folha.png")
const TEXTURA_FOLHA_TOPO := preload("res://assets/texturas/porta_folha_topo.png")
const TEXTURA_FOLHA_LADO := preload("res://assets/texturas/porta_folha_lado.png")
const TEXTURA_TRAVA := preload("res://assets/texturas/porta_trava.png")
const TEXTURA_TRAVA_LADO := preload("res://assets/texturas/porta_trava_lado.png")
const TEXTURA_VAO := preload("res://assets/texturas/porta_vao.png")
const TEXTURA_VAO_TOPO := preload("res://assets/texturas/porta_vao_topo.png")
const TEXTURA_VAO_LADO := preload("res://assets/texturas/porta_vao_lado.png")

## Quanto o recesso e a folha frontal se afastam da linha do contorno, para
## dentro da faixa de parede. Sai de onde a abertura da moldura autorada cai:
## linhas 29..62 de 128, cujo centro fica 18 px acima do meio do sprite.
const RECUO_FRONTAL := 18.0
## O mesmo para as vistas de cima: a chapa mora no meio da espessura da parede.
const RECUO_DE_CIMA := 32.0

@export var direcao: Direcao = Direcao.NORTE

@export_group("Som")
## O motor pegando, e o estalo da trava soltando.
##
## Opcionais: a porta abre em silencio se ninguem declarar. Uma porta que
## depende de audio para funcionar seria uma porta que trava quando o som falta.
@export var som_do_motor: AudioStream
@export var som_da_trava: AudioStream

var estado: Estado = Estado.TRANCADA

## Resolvida no _ready porque referencia de no exportada nao sobrevive a
## instanciacao da cena dentro da sala.
var sala_dona: Sala = null

var _barreira: CollisionShape2D = null
var _moldura: Sprite2D = null
var _folha_a: Sprite2D = null
var _folha_b: Sprite2D = null
var _trava: Sprite2D = null
var _vao: Sprite2D = null
var _moldura_em_casa: Vector2 = Vector2.ZERO
var _folha_a_em_casa: Vector2 = Vector2.ZERO
var _folha_b_em_casa: Vector2 = Vector2.ZERO
var _tween_abertura: Tween = null


func _ready() -> void:
	sala_dona = get_parent().get_parent() as Sala
	if sala_dona == null:
		push_error("Porta sem Sala dona: esperado Sala/Portas/Porta em %s" % get_path())

	_barreira = get_node_or_null(CAMINHO_BARREIRA) as CollisionShape2D
	if _barreira == null:
		push_error("Porta sem no Barreira/Colisao em %s" % get_path())

	_moldura = get_node_or_null(CAMINHO_MOLDURA) as Sprite2D
	_folha_a = get_node_or_null(CAMINHO_FOLHA_A) as Sprite2D
	_folha_b = get_node_or_null(CAMINHO_FOLHA_B) as Sprite2D
	_trava = get_node_or_null(CAMINHO_TRAVA) as Sprite2D
	_vao = get_node_or_null(CAMINHO_VAO) as Sprite2D

	_vestir()
	_talhar_colisoes()

	if _moldura != null:
		_moldura_em_casa = _moldura.position
	if _folha_a != null:
		_folha_a_em_casa = _folha_a.position
	if _folha_b != null:
		_folha_b_em_casa = _folha_b.position

	body_entered.connect(_ao_corpo_entrar)
	_aplicar_estado()


func vetor() -> Vector2:
	match direcao:
		Direcao.SUL:
			return Vector2.DOWN
		Direcao.LESTE:
			return Vector2.RIGHT
		Direcao.OESTE:
			return Vector2.LEFT
		_:
			return Vector2.UP


## O eixo AO LONGO da parede: e nele que as duas metades da folha partem.
##
## Ele e sempre POSITIVO em tela -- (1,0) no norte e no sul, (0,1) no leste e no
## oeste -- e isso nao e detalhe. A metade "A" e a de coordenada MENOR na
## textura, e ela tem de cair do lado menor da TELA: com um eixo que trocasse de
## sinal com a direcao, a metade esquerda da chapa iria para a direita em duas
## das quatro portas, e a junta central do desenho apareceria nas bordas.
func eixo_da_folha() -> Vector2:
	return Vector2(absf(vetor().y), absf(vetor().x))


## VESTIR e escolher a arte do lado, e nunca girar a de outro.
##
## Este e o coracao da PORTA 03. A cena traz UMA porta; o que muda por lado sao
## as texturas e onde elas caem. Nada aqui mexe em `rotation` -- nem no da porta,
## nem no dos sprites --, e o unico espelhamento e `flip_h` no oeste, que reflete
## sem girar.
func _vestir() -> void:
	var de_frente := direcao == Direcao.NORTE
	var no_eixo_x := direcao == Direcao.LESTE or direcao == Direcao.OESTE
	var espelha := direcao == Direcao.OESTE
	var fora := vetor()

	if _moldura != null:
		if de_frente:
			_moldura.texture = TEXTURA_MOLDURA
		elif no_eixo_x:
			_moldura.texture = TEXTURA_LADO
		else:
			_moldura.texture = TEXTURA_TOPO
		_moldura.flip_h = espelha
		_moldura.position = Vector2.ZERO

	var recuo := RECUO_FRONTAL if de_frente else RECUO_DE_CIMA
	var centro := fora * recuo

	# O RECESSO fica ATRAS da folha nos quatro lados, e nao dentro da moldura.
	#
	# A primeira versao das vistas de cima pintava o poco na propria textura de
	# moldura, e a moldura desenha ACIMA da folha: a chapa existia, era carregada
	# e era posicionada certo -- e um retangulo opaco caia em cima dela. A porta
	# trancada voltava a ser um buraco com a barra de sinal na frente, que e o
	# defeito inteiro da PORTA 01. Nenhum portao de arquivo pega isso: as duas
	# texturas estavam certas, era a ORDEM que nao estava.
	if _vao != null:
		if de_frente:
			_vao.texture = TEXTURA_VAO
		else:
			_vao.texture = TEXTURA_VAO_LADO if no_eixo_x else TEXTURA_VAO_TOPO
		_vao.flip_h = espelha
		_vao.position = centro
	var lado := eixo_da_folha() * (RECUO_DA_FOLHA * 0.5)
	var textura_folha := TEXTURA_FOLHA
	if not de_frente:
		textura_folha = TEXTURA_FOLHA_LADO if no_eixo_x else TEXTURA_FOLHA_TOPO

	# As duas metades sao REGIOES da mesma textura, cortadas no eixo em que elas
	# partem. Duas texturas separadas convidariam a esquecer de cortar uma delas
	# no dia em que a arte mudasse.
	var tamanho := textura_folha.get_size()
	var meia := tamanho * (Vector2(0.5, 1.0) if not no_eixo_x else Vector2(1.0, 0.5))
	var passo := Vector2(meia.x, 0.0) if not no_eixo_x else Vector2(0.0, meia.y)
	for i in 2:
		var folha := _folha_a if i == 0 else _folha_b
		if folha == null:
			continue
		folha.texture = textura_folha
		folha.region_enabled = true
		folha.region_rect = Rect2(passo * i, meia)
		folha.flip_h = espelha
		folha.position = centro + lado * (1.0 if i == 1 else -1.0)

	if _trava != null:
		_trava.texture = TEXTURA_TRAVA_LADO if no_eixo_x else TEXTURA_TRAVA
		_trava.position = centro


## As formas de colisao nascem AQUI, e nao no .tscn.
##
## Duas razoes, e as duas ja custaram tempo neste projeto. A primeira e a
## armadilha registrada: sub-resource de `.tscn` e COMPARTILHADO entre
## instancias, e as quatro portas de uma sala sao quatro instancias da mesma
## cena -- mexer no tamanho de uma mexeria nas quatro. A segunda e a PORTA 03:
## sem a rotacao do no, o retangulo de 80x32 precisa virar 32x80 nas portas
## leste e oeste, senao a barreira do lockdown fica deitada e o jogador
## atravessa a parede pelo lado.
func _talhar_colisoes() -> void:
	var no_eixo_x := direcao == Direcao.LESTE or direcao == Direcao.OESTE
	var medida := Vector2(32.0, LARGURA) if no_eixo_x else Vector2(LARGURA, 32.0)
	for caminho: NodePath in [CAMINHO_COLISAO, CAMINHO_BARREIRA]:
		var forma := get_node_or_null(caminho) as CollisionShape2D
		if forma == null:
			continue
		var retangulo := RectangleShape2D.new()
		retangulo.size = medida
		forma.shape = retangulo


func abrir() -> void:
	# Selar e permanente: nao existe sala do outro lado para onde abrir.
	if estado == Estado.SELADA:
		return
	var estava_trancada := estado == Estado.TRANCADA
	estado = Estado.ABERTA
	_aplicar_estado()
	if estava_trancada:
		_encenar_abertura()


## A abertura industrial: motor, tremor, trava, folhas.
##
## A BARREIRA JA CAIU quando isto comeca -- `_aplicar_estado()` roda antes. E a
## decisao inteira desta animacao: ela e leitura, e nao pedagio. Se a passagem so
## liberasse no fim, cada porta cobraria a duracao dela em toda travessia, e o
## jogador atravessa dez salas por andar num jogo cuja dificuldade sobe com o
## TEMPO. Assim quem quer correr atravessa no primeiro quadro e ve a porta
## terminar de abrir pelas costas; quem olha, ve a maquina velha pegando.
##
## AS FOLHAS PARTEM, E NAO ACHATAM (PORTA 02). Antes daqui o unico movimento era
## `scale` do campo de forca indo a 2% em y: numa grade de listras aquilo passava
## como "o campo recolheu", mas numa CHAPA metalica -- que e o que a porta e
## desde a PORTA 01 -- achatar le como a porta sendo esmagada. Agora cada metade
## desliza `RECUO_DA_FOLHA` para o proprio lado e some ATRAS do batente, que e
## opaco. Nenhum pixel e deformado; quem esconde a folha e a moldura, como numa
## porta de verdade.
func _encenar_abertura() -> void:
	if _tween_abertura != null and _tween_abertura.is_valid():
		_tween_abertura.kill()
	Audio.tocar(som_do_motor)

	# `_aplicar_estado()` ja rodou e ja escondeu a folha, porque ABERTA nao tem
	# folha. Ela volta para a tela AQUI, para a animacao ter o que mover: sem
	# esta linha a porta abriria instantaneamente e a encenacao aconteceria sobre
	# nada, sem erro nenhum no console. E o mesmo cuidado que o campo de forca ja
	# pedia antes da PORTA 02.
	for peca: Sprite2D in [_folha_a, _folha_b, _trava]:
		if peca != null:
			peca.visible = true
	if _folha_a != null:
		_folha_a.position = _folha_a_em_casa
	if _folha_b != null:
		_folha_b.position = _folha_b_em_casa

	var t := create_tween()
	_tween_abertura = t
	# 1. O motor pega e a porta TREME, no eixo ao longo da parede -- que e o
	#    mesmo em que as folhas vao partir.
	var tremor := eixo_da_folha() * TREMOR
	if _moldura != null:
		var passos := 4
		for i in passos:
			var sinal := 1.0 if i % 2 == 0 else -1.0
			t.tween_property(_moldura, "position",
				_moldura_em_casa + tremor * sinal, TEMPO_DE_ABERTURA * 0.10)
		t.tween_property(_moldura, "position", _moldura_em_casa, TEMPO_DE_ABERTURA * 0.08)
	# 2. A TRAVA solta: um estalo, a barra de sinal apaga, e so entao a chapa
	#    se mexe. A ordem e a frase inteira -- destrancar vem antes de abrir.
	t.tween_callback(func() -> void:
		Audio.tocar(som_da_trava)
		if _trava != null:
			_trava.visible = false
	)
	# 3. As duas metades partem para os lados, cada uma para dentro do batente.
	if _folha_a != null and _folha_b != null:
		var recuo := eixo_da_folha() * RECUO_DA_FOLHA
		t.tween_property(_folha_a, "position",
			_folha_a_em_casa - recuo, TEMPO_DE_ABERTURA * 0.42)
		t.parallel().tween_property(_folha_b, "position",
			_folha_b_em_casa + recuo, TEMPO_DE_ABERTURA * 0.42)
		# ABERTA nao deixa residuo: a folha volta para casa invisivel, para a
		# proxima vez que esta porta trancar comecar do lugar certo.
		t.tween_callback(func() -> void:
			_folha_a.visible = false
			_folha_b.visible = false
			_folha_a.position = _folha_a_em_casa
			_folha_b.position = _folha_b_em_casa
		)


func trancar() -> void:
	if estado == Estado.SELADA:
		return
	estado = Estado.TRANCADA
	_aplicar_estado()


func selar() -> void:
	estado = Estado.SELADA
	_aplicar_estado()


func esta_selada() -> bool:
	return estado == Estado.SELADA


func _ao_corpo_entrar(corpo: Node2D) -> void:
	if estado != Estado.ABERTA:
		return
	if not corpo.is_in_group("player"):
		return
	EventBus.porta_atravessada.emit(sala_dona, vetor())


func _aplicar_estado() -> void:
	# So a porta TRANCADA precisa de barreira. A SELADA nao: `Sala._vaos_no_trecho`
	# pula porta selada, entao a parede gerada passa RETA por cima dela e o solido
	# ja existe ali.
	#
	# Enquanto isto era `estado != Estado.ABERTA`, a porta selada somava um
	# segundo solido em cima da parede -- e nao no mesmo lugar. A parede e um
	# SegmentShape2D sobre a linha do contorno, sem espessura; a barreira e um
	# retangulo de 80x32 CENTRADO nessa linha. Metade dele, 16 px, ficava DENTRO
	# da area jogavel: uma laje invisivel de 80x16 encostada na parede, em todo
	# lado de sala que nao tinha vizinho. O jogador esbarrava em nada, e nao ha
	# erro no console para colisao a mais.
	var bloqueia := estado == Estado.TRANCADA

	if _barreira != null:
		# Deferido porque trancar costuma ser chamado de dentro de um sinal de
		# fisica, e mexer em colisao no meio do passo derruba o servidor.
		_barreira.set_deferred(&"disabled", not bloqueia)

	# SELADA esconde tudo: o vao nem e aberto na parede, entao a parede e
	# continua ali e qualquer coisa desenhada seria um erro visivel.
	var ha_vao := estado != Estado.SELADA
	if _moldura != null:
		_moldura.visible = ha_vao
	if _vao != null:
		# O recesso segue a MOLDURA e nao o estado: porta selada nao tem vao
		# nenhum -- `_vaos_no_trecho` a pula e a parede passa reta por cima --,
		# entao desenhar escuridao ali abriria um buraco onde ha parede.
		_vao.visible = ha_vao
	for folha: Sprite2D in [_folha_a, _folha_b]:
		if folha != null:
			folha.visible = bloqueia
			if bloqueia:
				folha.position = _folha_a_em_casa if folha == _folha_a else _folha_b_em_casa
	if _trava != null:
		_trava.visible = bloqueia
