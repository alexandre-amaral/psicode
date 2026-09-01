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
## Visual em duas pecas, e nao num retangulo que troca de cor: a "Moldura" e o
## batente, sempre visivel onde ha vao, com a passagem para fora pintada de
## escuridao (corredor nao revelado e o desconhecido, nao parede); o "Campo" e o
## campo de forca, so TRANCADA, na paleta SINAL -- brilhante de proposito, mas
## com 80x32, um tamanho que nenhum projetil tem. Em coordenadas locais da
## porta, -y e sempre o lado de FORA da sala: os .tscn rotacionam cada porta
## para isso, e e o que deixa a mesma textura servir aos quatro lados.

enum Direcao { NORTE, SUL, LESTE, OESTE }
enum Estado { ABERTA, TRANCADA, SELADA }

## Vao que a parede da sala precisa abrir para caber esta porta.
const LARGURA := 80.0

## A ABERTURA, em segundos, e o TETO dela.
##
## A sequencia e "motor liga -> porta vibra -> trava solta -> placas movem", e
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

const CAMINHO_BARREIRA := ^"Barreira/Colisao"
const CAMINHO_MOLDURA := ^"Moldura"
const CAMINHO_CAMPO := ^"Campo"
const CAMINHO_VAO := ^"Vao"

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
var _campo: Sprite2D = null
var _vao: Sprite2D = null
var _moldura_em_casa: Vector2 = Vector2.ZERO
var _tween_abertura: Tween = null


func _ready() -> void:
	sala_dona = get_parent().get_parent() as Sala
	if sala_dona == null:
		push_error("Porta sem Sala dona: esperado Sala/Portas/Porta em %s" % get_path())

	_barreira = get_node_or_null(CAMINHO_BARREIRA) as CollisionShape2D
	if _barreira == null:
		push_error("Porta sem no Barreira/Colisao em %s" % get_path())

	_moldura = get_node_or_null(CAMINHO_MOLDURA) as Sprite2D
	if _moldura != null:
		_moldura_em_casa = _moldura.position
	_campo = get_node_or_null(CAMINHO_CAMPO) as Sprite2D
	_vao = get_node_or_null(CAMINHO_VAO) as Sprite2D

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


func abrir() -> void:
	# Selar e permanente: nao existe sala do outro lado para onde abrir.
	if estado == Estado.SELADA:
		return
	var estava_trancada := estado == Estado.TRANCADA
	estado = Estado.ABERTA
	_aplicar_estado()
	if estava_trancada:
		_encenar_abertura()


## A abertura industrial: motor, tremor, trava, placas.
##
## A BARREIRA JA CAIU quando isto comeca -- `_aplicar_estado()` roda antes. E a
## decisao inteira desta animacao: ela e leitura, e nao pedagio. Se a passagem so
## liberasse no fim, cada porta cobraria a duracao dela em toda travessia, e o
## jogador atravessa dez salas por andar num jogo cuja dificuldade sobe com o
## TEMPO. Assim quem quer correr atravessa no primeiro quadro e ve a porta
## terminar de abrir pelas costas; quem olha, ve a maquina velha pegando.
##
## O campo de forca RECOLHE em vez de sumir. Ele e o unico elemento da porta que
## o jogador precisa ler num quadro so -- ele diz "trancada" --, e apagar de uma
## vez perde a unica chance de mostrar que a tranca soltou.
func _encenar_abertura() -> void:
	if _tween_abertura != null and _tween_abertura.is_valid():
		_tween_abertura.kill()
	Audio.tocar(som_do_motor)

	var t := create_tween()
	_tween_abertura = t
	# 1. O motor pega e a porta TREME. Tremor em x local, que e o eixo
	#    atravessado pelo vao: -y e sempre o lado de fora, nos quatro lados.
	if _moldura != null:
		var passos := 4
		for i in passos:
			var lado := TREMOR if i % 2 == 0 else -TREMOR
			t.tween_property(_moldura, "position",
				_moldura_em_casa + Vector2(lado, 0.0), TEMPO_DE_ABERTURA * 0.10)
		t.tween_property(_moldura, "position", _moldura_em_casa, TEMPO_DE_ABERTURA * 0.08)
	# 2. A TRAVA solta: um estalo, e so entao as placas se mexem.
	t.tween_callback(func() -> void: Audio.tocar(som_da_trava))
	# 3. As placas movem -- o campo recolhe para a borda em vez de apagar.
	if _campo != null:
		_campo.visible = true
		_campo.scale = Vector2.ONE
		t.tween_property(_campo, "scale", Vector2(1.0, 0.02), TEMPO_DE_ABERTURA * 0.42)
		t.tween_callback(func() -> void:
			_campo.visible = false
			_campo.scale = Vector2.ONE
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

	# SELADA esconde as duas pecas: o vao nem e aberto na parede, entao a
	# parede e continua ali e qualquer coisa desenhada seria um erro visivel.
	if _moldura != null:
		_moldura.visible = estado != Estado.SELADA
	if _vao != null:
		# O recesso segue a MOLDURA e nao o estado: porta selada nao tem vao
		# nenhum -- `_vaos_no_trecho` a pula e a parede passa reta por cima --,
		# entao desenhar escuridao ali abriria um buraco onde ha parede.
		_vao.visible = estado != Estado.SELADA
	if _campo != null:
		_campo.visible = estado == Estado.TRANCADA
