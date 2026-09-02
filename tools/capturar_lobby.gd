extends Node2D
func _ready() -> void:
	var cena: PackedScene = load("res://src/lobby/lobby.tscn")
	if cena == null:
		print("LOBBY: nao carregou"); get_tree().quit(1); return
	# Perfil de teste, para as plataformas terem o que acender.
	Save._caminho = "user://teste_lobby.json"
	Save.apagar_save()
	Progressao.criar_novo()
	var lobby: Node2D = cena.instantiate()
	add_child(lobby)
	# A camera olha o meio da baia, e nao o spawn: e la que estao as estacoes.
	await get_tree().process_frame
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p != null:
		# Colado na capsula da RAVEN, para o prompt aparecer.
		p.global_position = Vector2(-88, -100)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://capturas")
	img.save_png("user://capturas/lobby_01.png")
	print("LOBBY: capturado")
	get_tree().quit()
