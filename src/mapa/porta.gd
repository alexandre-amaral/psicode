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
## UMA ARTE, GIRADA POR DIRECAO -- e esta e uma decisao REVERTIDA, de propósito.
##
## A PORTA 03 tinha trocado isto por tres vistas: a face autorada no norte e duas
## vistas de cima geradas para os outros lados, com o argumento de que girar uma
## FACE destroi a perspectiva Low Top-Down. O argumento continua correto no papel.
## O que ele nao previu e que o substituto teria de ser tao bom quanto a arte
## autorada, e ele nao foi: em tres rodadas de correcao as vistas de cima
## passaram por chapadas demais, claras demais e sem cercar o vao, e em nenhuma
## delas chegaram perto do que a moldura desenhada entrega.
##
## O dono do projeto olhou as quatro portas no jogo e decidiu: **a moldura
## autorada, girada, vale mais que tres vistas medianas.** Fica registrado o que
## se paga por isso -- ao leste e ao oeste a face fica deitada, ao sul de cabeca
## para baixo -- e fica registrado tambem por que o preco e menor do que parecia:
## a moldura e quase simetrica nos dois eixos, e o que ela mostra e batente,
## verga e soleira, que sao as pecas menos direcionais do desenho.
##
## Quem gira e o VISUAL, e nao o no. A colisao continua nascendo em codigo com a
## medida certa por eixo, e `direcao` continua sendo a fonte de verdade da
## orientacao logica (`vetor()`). O que o portao ainda recusa e giro que nao seja
## um dos quatro angulos retos, e espelhamento VERTICAL -- que poria a soleira em
## cima da verga.
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
const TEXTURA_FOLHA := preload("res://assets/texturas/porta_folha.png")
const TEXTURA_TRAVA := preload("res://assets/texturas/porta_trava.png")
const TEXTURA_VAO := preload("res://assets/texturas/porta_vao.png")

## Quanto o recesso e a folha se afastam da linha do contorno, para dentro da
## faixa de parede. Sai de onde a abertura da moldura autorada cai: linhas 29..62
## de 128, cujo centro fica 18 px acima do meio do sprite.
const RECUO_FRONTAL := 18.0

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

	body_exited.connect(_ao_corpo_sair)
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


## VESTIR e girar a MESMA arte para o lado certo.
##
## A cena traz UMA porta e UMA moldura; o que muda por lado e o angulo do visual
## e onde as pecas caem. Quem gira e o sprite e nao o no: a colisao continua
## nascendo em codigo com a medida certa por eixo, e `direcao` continua sendo a
## fonte de verdade da orientacao logica.
func _vestir() -> void:
	var fora := vetor()
	# O angulo que leva o -y da textura para o lado de FORA da sala. E o mesmo
	# que os `.tscn` carregavam antes da PORTA 03, so que aplicado ao VISUAL e
	# nao ao no -- assim a colisao continua nascendo com a medida certa por eixo.
	var giro := fora.angle() + PI * 0.5

	if _moldura != null:
		_moldura.texture = TEXTURA_MOLDURA
		_moldura.position = Vector2.ZERO
		_moldura.rotation = giro

	if _vao != null:
		_vao.texture = TEXTURA_VAO
		_vao.position = fora * RECUO_FRONTAL
		_vao.rotation = giro

	var centro := fora * RECUO_FRONTAL
	var eixo := eixo_da_folha()
	# As duas metades sao REGIOES da mesma textura, cortadas no eixo em que elas
	# partem. Duas texturas separadas convidariam a esquecer de cortar uma delas
	# no dia em que a arte mudasse.
	var tamanho := TEXTURA_FOLHA.get_size()
	var meia := Vector2(tamanho.x * 0.5, tamanho.y)
	for i in 2:
		var folha := _folha_a if i == 0 else _folha_b
		if folha == null:
			continue
		folha.texture = TEXTURA_FOLHA
		folha.region_enabled = true
		folha.region_rect = Rect2(Vector2(meia.x * i, 0.0), meia)
		folha.rotation = giro
		folha.position = centro + eixo * (RECUO_DA_FOLHA * 0.5) * (1.0 if i == 1 else -1.0)

	if _trava != null:
		_trava.texture = TEXTURA_TRAVA
		_trava.position = centro
		_trava.rotation = giro


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


## A travessia e decidida na SAIDA da area, e por qual lado.
##
## Antes ela era decidida na ENTRADA, e isso tinha um buraco que se sentia
## jogando: a area tem 32 px de profundidade, entao quem encostava nela e recuava
## sem cruzar disparava a saida da sala e nunca a desfazia. A camera ficava no
## enquadramento largo da travessia -- meio numa sala, meio na outra --, e a
## proxima tentativa de sair de verdade era lida como "desistiu" e consumida.
## Rocar o batente desviando de um tiro era suficiente, e o estado so voltava ao
## normal depois de duas travessias inteiras.
##
## Entrar numa porta nao e atravessa-la. Sair PELO LADO DE FORA e -- e sair pelo
## lado de dentro e ter desistido. Os dois casos passam por aqui, e quem os
## distingue e a geometria e nao uma bandeira.
func _ao_corpo_sair(corpo: Node2D) -> void:
	if estado != Estado.ABERTA:
		return
	if not corpo.is_in_group("player"):
		return
	# `vetor()` aponta para fora da sala. Positivo = o corpo saiu da area pelo
	# lado do corredor.
	var para_fora := (corpo.global_position - global_position).dot(vetor()) > 0.0
	EventBus.porta_atravessada.emit(sala_dona, vetor(), para_fora)


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
