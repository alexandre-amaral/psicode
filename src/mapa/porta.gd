extends Area2D
## Uma porta que conecta duas salas.

enum Direcao { NORTE, SUL, LESTE, OESTE }

@export var direcao: Direcao = Direcao.NORTE
@export var aberta: bool = true

var sala_pai: Node2D

func _ready() -> void:
	sala_pai = get_parent().get_parent() 
	body_entered.connect(_ao_corpo_entrar)
	
	# Forçar Layer e Mask para 1 (Colisao de Parede/Player)
	set_collision_layer_value(1, true)
	set_collision_mask_value(1, true)
	# Limpar outras layers caso tenham vindo com 3
	for i in range(2, 32):
		set_collision_layer_value(i, false)
		set_collision_mask_value(i, false)
		
	_atualizar_visual()

func abrir() -> void:
	aberta = true
	_atualizar_visual()

func fechar() -> void:
	aberta = false
	_atualizar_visual()

func _ao_corpo_entrar(corpo: Node2D) -> void:
	if not aberta:
		return
	
	if corpo.is_in_group("player"):
		var dir_vetor := Vector2.ZERO
		match direcao:
			Direcao.NORTE: dir_vetor = Vector2.UP
			Direcao.SUL: dir_vetor = Vector2.DOWN
			Direcao.LESTE: dir_vetor = Vector2.RIGHT
			Direcao.OESTE: dir_vetor = Vector2.LEFT
		
		EventBus.transicao_iniciada.emit(dir_vetor, null)

func _atualizar_visual() -> void:
	set_monitoring(aberta)
	set_monitorable(aberta)
	
	if has_node("Collision"):
		$Collision.disabled = !aberta
