extends Control

@onready var video: VideoStreamPlayer = $Video

func _ready() -> void:
	video.finished.connect(_on_video_finished)
	
	# Tentativa de carregar o vídeo
	var res = ResourceLoader.load("res://assets/INTRO.mp4")
	if res is VideoStream:
		video.stream = res
		video.play()
	else:
		# Fallback se o Godot falhar ao carregar o MP4 nativamente
		push_error("Aviso: O Godot não conseguiu carregar o MP4 nativamente. Geralmente, ele suporta '.ogv' (Ogg Theora) por padrão.")
		_on_video_finished()

func _input(event: InputEvent) -> void:
	# Permitir que o jogador pule a intro apertando qualquer tecla ou clicando
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
		_on_video_finished()

func _on_video_finished() -> void:
	get_tree().change_scene_to_file("res://src/ui/menu_inicial.tscn")
