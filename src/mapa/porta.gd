extends Area2D
## Uma porta que conecta duas salas.

enum Direcao { NORTE, SUL, LESTE, OESTE }

@export var direcao: Direcao = Direcao.NORTE
@export var aberta: bool = true

var sala_pai: Node2D

func _ready() -> void:
	sala_pai = get_parent().get_parent() # Estrutura: Sala -> Portas -> Porta
	body_entered.connect(_ao_corpo_entrar)
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
		
		# Emitimos o desejo de transicao. O GerenciadorMapa escuta.
		EventBus.transicao_iniciada.emit(dir_vetor, null) # null porque o manager decide a sala nova

func _atualizar_visual() -> void:
	# Placeholder para feedback visual/colisao
	# No futuro, troca de sprite ou animação
	set_deferred("monitoring", aberta)
	if has_node("Collision"):
		$Collision.disabled = !aberta
