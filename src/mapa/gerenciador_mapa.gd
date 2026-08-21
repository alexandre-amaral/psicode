extends Node2D
## Gerencia a geracao do andar e transicoes entre salas.

@export var cena_sala_1: PackedScene
@export var cena_sala_2: PackedScene
@export var cena_sala_3: PackedScene
@export var cena_sala_4: PackedScene
@export var cena_sala_boss: PackedScene

var _pool_salas: Array[PackedScene] = []

func _ready() -> void:
	_pool_salas = [cena_sala_1, cena_sala_2, cena_sala_3, cena_sala_4]
	EventBus.transicao_iniciada.connect(_ao_transicao_iniciada)
	gerar_mapa() # Agora ativado automaticamente

func gerar_mapa() -> void:
	# Mapa fixo para teste: 0(Start) -> 1 -> 2 -> 3(Treasure) -> 4(Boss)
	mapa[Vector2.ZERO] = _instanciar_sala(Vector2.ZERO, _pool_salas.pick_random())
	
	var pos := Vector2.ZERO
	for i in range(4):
		pos += Vector2.RIGHT # Caminho simples para a direita
		if i == 3:
			mapa[pos] = _instanciar_sala(pos, cena_sala_boss)
		else:
			mapa[pos] = _instanciar_sala(pos, _pool_salas.pick_random())
	
	_entrar_na_sala(Vector2.ZERO)

func _instanciar_sala(pos_grid: Vector2, cena: PackedScene) -> Node2D:
	var s := cena.instantiate()
	s.coordenadas_grid = pos_grid
	s.position = pos_grid * 2000.0 # Espacamento fixo grande para evitar sobreposicao
	add_child(s)
	return s

func _entrar_na_sala(pos_grid: Vector2) -> void:
	if not mapa.has(pos_grid):
		return
	
	sala_atual = mapa[pos_grid]
	sala_atual.ativar()
	_ajustar_camera(sala_atual)

func _ao_transicao_iniciada(direcao: Vector2, _sala_nova: Node2D) -> void:
	if _transicionando:
		return
	
	var nova_pos_grid := sala_atual.coordenadas_grid + direcao
	if not mapa.has(nova_pos_grid):
		push_warning("GerenciadorMapa: Tentativa de ir para sala inexistente em %s" % nova_pos_grid)
		return
	
	_executar_transicao(mapa[nova_pos_grid], direcao)

func _executar_transicao(nova_sala: Node2D, direcao: Vector2) -> void:
	_transicionando = true
	var player := get_tree().get_first_node_in_group("player")
	
	# 1. Trava o player ou inicia animacao
	# 2. Inicia Tween da camera
	var camera := player.get_node("Camera")
	var limites := nova_sala.obter_limites()
	
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Desliza a camera (se ela nao for fixa)
	# Para simplificar, movemos o player um pouco para "atravessar" a porta
	var offset_player := direcao * 200.0 # Teleporta o player para dentro da nova sala
	tween.tween_property(player, "global_position", player.global_position + offset_player, 0.5)
	
	# Atualiza os limites da camera suavemente (se possivel) ou no final
	# Nota: Camera2D.limit_* nao sao interpolaveis nativamente de forma simples
	# Vamos fazer a troca de limites e entao o slide da posicao da camera
	
	await tween.finished
	
	sala_atual = nova_sala
	_ajustar_camera(sala_atual)
	sala_atual.ativar()
	_transicionando = false
	EventBus.transicao_concluida.emit(sala_atual)

func _ajustar_camera(sala: Node2D) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var cam: Camera2D = player.get_node("Camera")
	var limites := sala.obter_limites()
	
	cam.limit_left = int(limites.position.x)
	cam.limit_right = int(limites.end.x)
	cam.limit_top = int(limites.position.y)
	cam.limit_bottom = int(limites.end.y)
