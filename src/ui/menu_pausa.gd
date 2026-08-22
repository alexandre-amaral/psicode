extends CanvasLayer

@onready var btn_continuar: Button = $Painel/VBoxContainer/BtnContinuar
@onready var btn_menu: Button = $Painel/VBoxContainer/BtnMenu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	btn_continuar.pressed.connect(_on_btn_continuar_pressed)
	btn_menu.pressed.connect(_on_btn_menu_pressed)

func _process(_delta: float) -> void:
	var pausado = (GameState.estado == GameState.Estado.PAUSADO)
	if visible != pausado:
		visible = pausado
		if visible:
			btn_continuar.grab_focus()

func _on_btn_continuar_pressed() -> void:
	GameState.alternar_pausa()

func _on_btn_menu_pressed() -> void:
	GameState.estado = GameState.Estado.MENU
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/ui/menu_inicial.tscn")
