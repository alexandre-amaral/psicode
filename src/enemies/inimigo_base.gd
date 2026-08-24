class_name InimigoBase
extends CharacterBody2D
## Base de todo inimigo. Cuida de vida, dano, knockback, flash e morte.
## As subclasses so implementam _comportamento().
##
## Regra importante: NENHUM inimigo guarda os proprios numeros de dificuldade
## multiplicados. Eles leem Deterioracao a cada frame. Assim a barra subir tem
## efeito imediato, inclusive nos inimigos que ja estao na tela.

signal morreu(posicao: Vector2)

const GRUPO := "inimigo"

@export_group("Atributos")
@export var vida_maxima: int = 5
@export var velocidade_base: float = 120.0
@export var dano_contato: int = 1
@export var creditos: int = 3
## Quanto este inimigo soma na barra de Deterioracao ao morrer. Zero por
## padrao -- quem move a barra e o fim de onda, nao a matanca.
@export var deterioracao_ao_morrer: float = 0.0

@export_group("Feedback")
@export var cor_base: Color = Color("ff4d6d")
@export var raio_contato: float = 26.0
@export var intervalo_dano_contato: float = 0.7

var vida: int = 5
var alvo: Node2D = null
var morto: bool = false

var _knockback: Vector2 = Vector2.ZERO
var _t_contato: float = 0.0
var _visual: Node2D
var _corpo: Polygon2D
var _tween_flash: Tween


func _ready() -> void:
	add_to_group(GRUPO)
	vida = vida_maxima
	_visual = get_node_or_null("Visual")
	_corpo = get_node_or_null("Visual/Corpo")
	if _corpo != null:
		_corpo.color = cor_base
	_procurar_alvo()
	EventBus.inimigo_spawnou.emit(self)
	_ao_nascer()


func _physics_process(delta: float) -> void:
	if morto:
		return
	if alvo == null or not is_instance_valid(alvo):
		_procurar_alvo()

	_t_contato = maxf(_t_contato - delta, 0.0)

	_comportamento(delta)

	# Knockback e somado por fora do comportamento para que empurrar um inimigo
	# nunca "cancele" a IA dele -- so desloca.
	if _knockback.length_squared() > 1.0:
		velocity += _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 1400.0 * delta)

	move_and_slide()
	_pos_movimento(delta)


## Ponto de extensao principal: cada inimigo escreve so isto.
func _comportamento(_delta: float) -> void:
	pass


func _pos_movimento(_delta: float) -> void:
	pass


## Ponto de extensao do MOVIMENTO: recebe para onde o inimigo QUER ir e devolve
## para onde ele de fato vai.
##
## Hoje devolve a direcao crua, e e de proposito -- o comportamento nao muda em
## nada. O que ele cria e o lugar: quando entrar pathfinding ou desvio de
## obstaculo, esta e a unica funcao que muda, em vez de sete arquivos de
## inimigo. A divida esta declarada no ROADMAP ("sem pathfinding -- o melee anda
## em linha reta") e as salas com pilar e as em L a tornaram real.
##
## Quem escreve inimigo novo passa o movimento por aqui. O Rastejante e o Vigia
## ainda nao passam: eles sao o que a v0.2.0-alpha esta testando com os amigos, e
## mexer neles agora invalidaria esse retorno.
func direcao_de_locomocao(desejada: Vector2) -> Vector2:
	return desejada


func _ao_nascer() -> void:
	# Pop de entrada -- comunica "algo novo apareceu" sem precisar de animacao.
	if _visual == null:
		return
	_visual.scale = Vector2(0.1, 0.1)
	var t := create_tween()
	t.tween_property(_visual, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func velocidade_atual() -> float:
	return velocidade_base * Deterioracao.multiplicador_velocidade()


func direcao_para_alvo() -> Vector2:
	if alvo == null or not is_instance_valid(alvo):
		return Vector2.ZERO
	return (alvo.global_position - global_position).normalized()


func distancia_do_alvo() -> float:
	if alvo == null or not is_instance_valid(alvo):
		return INF
	return global_position.distance_to(alvo.global_position)


## Velocidade do alvo, usada pela mira preditiva. Isolado aqui para que o
## chefe e o Vigia leiam exatamente a mesma coisa.
func velocidade_do_alvo() -> Vector2:
	if alvo == null or not is_instance_valid(alvo):
		return Vector2.ZERO
	if "velocity" in alvo:
		return alvo.velocity
	return Vector2.ZERO


func tentar_dano_contato() -> void:
	if _t_contato > 0.0 or alvo == null or not is_instance_valid(alvo):
		return
	if distancia_do_alvo() > raio_contato:
		return
	if alvo.has_method("receber_dano"):
		var acertou: bool = alvo.receber_dano(dano_contato, direcao_para_alvo() * 260.0)
		if acertou:
			_t_contato = intervalo_dano_contato
			_knockback = -direcao_para_alvo() * 220.0


func receber_dano(quantidade: int, impulso: Vector2 = Vector2.ZERO) -> bool:
	if morto:
		return false
	vida -= quantidade
	_knockback += impulso
	_flash()
	EventBus.pedido_hitstop.emit(0.025, 0.25)
	if vida <= 0:
		morrer()
	return true


## Clarao branco ao levar dano.
##
## Nao reinicia um clarao que ja esta em andamento. Parece detalhe, mas com
## dano continuo (shotgun encostada, chefe sendo metralhado) reiniciar a cada
## acerto deixa o inimigo branco permanente e some com a silhueta dele.
func _flash() -> void:
	if _visual == null:
		return
	if _tween_flash != null and _tween_flash.is_valid():
		return
	_visual.modulate = Color(5.0, 5.0, 5.0, 1.0)
	_tween_flash = create_tween()
	_tween_flash.tween_property(_visual, "modulate", Color.WHITE, 0.16)


func morrer() -> void:
	if morto:
		return
	morto = true
	set_physics_process(false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	var fx := preload("res://src/fx/explosao.tscn").instantiate()
	fx.global_position = global_position
	fx.modulate = cor_base
	get_parent().add_child(fx)

	GameState.inimigos_mortos += 1
	GameState.creditos += creditos
	if deterioracao_ao_morrer > 0.0:
		Deterioracao.adicionar(deterioracao_ao_morrer)

	morreu.emit(global_position)
	EventBus.inimigo_morreu.emit(global_position, creditos)
	queue_free()


func _procurar_alvo() -> void:
	alvo = get_tree().get_first_node_in_group("player")
