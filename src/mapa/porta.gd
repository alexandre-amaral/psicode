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

const CAMINHO_BARREIRA := ^"Barreira/Colisao"
const CAMINHO_MOLDURA := ^"Moldura"
const CAMINHO_CAMPO := ^"Campo"

@export var direcao: Direcao = Direcao.NORTE

var estado: Estado = Estado.TRANCADA

## Resolvida no _ready porque referencia de no exportada nao sobrevive a
## instanciacao da cena dentro da sala.
var sala_dona: Sala = null

var _barreira: CollisionShape2D = null
var _moldura: Sprite2D = null
var _campo: Sprite2D = null


func _ready() -> void:
	sala_dona = get_parent().get_parent() as Sala
	if sala_dona == null:
		push_error("Porta sem Sala dona: esperado Sala/Portas/Porta em %s" % get_path())

	_barreira = get_node_or_null(CAMINHO_BARREIRA) as CollisionShape2D
	if _barreira == null:
		push_error("Porta sem no Barreira/Colisao em %s" % get_path())

	_moldura = get_node_or_null(CAMINHO_MOLDURA) as Sprite2D
	_campo = get_node_or_null(CAMINHO_CAMPO) as Sprite2D

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

	# SELADA esconde as duas pecas: o vao nem e aberto na parede, entao a
	# parede e continua ali e qualquer coisa desenhada seria um erro visivel.
	if _moldura != null:
		_moldura.visible = estado != Estado.SELADA
	if _campo != null:
		_campo.visible = estado == Estado.TRANCADA
