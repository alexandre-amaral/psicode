extends Node2D
## Gerencia a geracao do andar e transicoes entre salas.

@export var cena_sala_1: PackedScene
@export var cena_sala_2: PackedScene
@export var cena_sala_3: PackedScene
@export var cena_sala_4: PackedScene
@export var cena_sala_boss: PackedScene

# Metadados de quais direções cada sala suporta conexão
var ROOM_METADATA: Dictionary = {}

var mapa: Dictionary = {} # Vector2 -> Node2D
var sala_atual: Node2D = null
var _transicionando: bool = false
var _pool_salas: Array[PackedScene] = []

func _ready() -> void:
	_pool_salas = [cena_sala_1, cena_sala_2, cena_sala_3, cena_sala_4]
	
	# Mapear cenas aos seus caminhos para buscar metadados
	ROOM_METADATA = {
		cena_sala_1.resource_path: [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT],
		cena_sala_2.resource_path: [Vector2.UP, Vector2.RIGHT],
		cena_sala_3.resource_path: [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT],
		cena_sala_4.resource_path: [Vector2.UP, Vector2.DOWN],
		cena_sala_boss.resource_path: [Vector2.DOWN]
	}
	
	EventBus.transicao_iniciada.connect(_ao_transicao_iniciada)
	gerar_mapa()

func gerar_mapa() -> void:
	for s in mapa.values():
		if is_instance_valid(s):
			s.queue_free()
	mapa.clear()
	
	var grid: Dictionary = {Vector2.ZERO: cena_sala_1} # Começa com uma sala padrão
	var pos: Vector2 = Vector2.ZERO
	
	for i in range(4):
		var possiveis: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
		possiveis.shuffle()
		
		for dir in possiveis:
			var nova_pos: Vector2 = pos + dir
			if not grid.has(nova_pos):
				# Filtra salas que possuem porta na direção inversa da conexão
				var cena_candidata: PackedScene = cena_sala_boss if i == 3 else _pool_salas.pick_random()
				if _is_compativel(cena_candidata, dir):
					grid[nova_pos] = cena_candidata
					pos = nova_pos
					break
	
	for p in grid.keys():
		mapa[p] = _instanciar_sala(p, grid[p])
		
	_entrar_na_sala(Vector2.ZERO)

func _is_compativel(cena: PackedScene, dir: Vector2) -> bool:
	# Verifica se a sala suporta a direção da conexão
	var portas: Array = ROOM_METADATA.get(cena.resource_path, [])
	return portas.has(dir)

func _instanciar_sala(pos_grid: Vector2, cena: PackedScene) -> Node2D:
	var s: Node2D = cena.instantiate()
	s.set("coordenadas_grid", pos_grid)
	s.position = pos_grid * 2000.0
	add_child(s)
	return s

# ... (funções _entrar_na_sala, _ao_transicao_iniciada, _executar_transicao, _ajustar_camera permanecem iguais)
func _entrar_na_sala(pos_grid: Vector2) -> void:
	if not mapa.has(pos_grid): return
	sala_atual = mapa[pos_grid]
	if sala_atual and sala_atual.has_method("ativar"):
		sala_atual.call("ativar")
		_ajustar_camera(sala_atual)

func _ao_transicao_iniciada(direcao: Vector2, _sala_nova: Node2D) -> void:
	if _transicionando or sala_atual == null: return
	var nova_pos_grid: Vector2 = sala_atual.get("coordenadas_grid") + direcao
	if not mapa.has(nova_pos_grid): return
	_executar_transicao(mapa[nova_pos_grid], direcao)

func _executar_transicao(nova_sala: Node2D, direcao: Vector2) -> void:
	_transicionando = true
	var player: CharacterBody2D = get_tree().get_first_node_in_group("player")
	if player == null:
		_transicionando = false
		return
	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player, "global_position", player.global_position + direcao * 400.0, 0.5)
	await tween.finished
	sala_atual = nova_sala
	_ajustar_camera(sala_atual)
	if sala_atual.has_method("ativar"):
		sala_atual.call("ativar")
	_transicionando = false
	EventBus.transicao_concluida.emit(sala_atual)

func _ajustar_camera(sala: Node2D) -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if not player or not player.has_node("Camera"): return
	var cam: Camera2D = player.get_node("Camera")
	var limites: Rect2 = sala.call("obter_limites")
	cam.limit_left = int(limites.position.x)
	cam.limit_right = int(limites.end.x)
	cam.limit_top = int(limites.position.y)
	cam.limit_bottom = int(limites.end.y)
