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
## e definitiva, entao a porta nunca reabre e nunca aparece.

enum Direcao { NORTE, SUL, LESTE, OESTE }
enum Estado { ABERTA, TRANCADA, SELADA }

## Vao que a parede da sala precisa abrir para caber esta porta.
const LARGURA := 80.0

const COR_ABERTA := Color(0.0, 0.8, 1.0, 0.4)
const COR_TRANCADA := Color(1.0, 0.25, 0.4, 0.75)

const CAMINHO_BARREIRA := ^"Barreira/Colisao"
const CAMINHO_VISUAL := ^"Visual"

@export var direcao: Direcao = Direcao.NORTE

var estado: Estado = Estado.TRANCADA

## Resolvida no _ready porque referencia de no exportada nao sobrevive a
## instanciacao da cena dentro da sala.
var sala_dona: Sala = null

var _barreira: CollisionShape2D = null
var _visual: ColorRect = null


func _ready() -> void:
	sala_dona = get_parent().get_parent() as Sala
	if sala_dona == null:
		push_error("Porta sem Sala dona: esperado Sala/Portas/Porta em %s" % get_path())

	_barreira = get_node_or_null(CAMINHO_BARREIRA) as CollisionShape2D
	if _barreira == null:
		push_error("Porta sem no Barreira/Colisao em %s" % get_path())

	_visual = get_node_or_null(CAMINHO_VISUAL) as ColorRect

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
	estado = Estado.ABERTA
	_aplicar_estado()


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
	var bloqueia := estado != Estado.ABERTA

	if _barreira != null:
		# Deferido porque trancar costuma ser chamado de dentro de um sinal de
		# fisica, e mexer em colisao no meio do passo derruba o servidor.
		_barreira.set_deferred(&"disabled", not bloqueia)

	if _visual != null:
		_visual.visible = estado != Estado.SELADA
		_visual.color = COR_ABERTA if estado == Estado.ABERTA else COR_TRANCADA
