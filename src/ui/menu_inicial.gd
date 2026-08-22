extends Control

@onready var btn_jogar: Button = $MenuPanel/VBoxContainer/BtnJogar
@onready var btn_carregar: Button = $MenuPanel/VBoxContainer/BtnCarregar
@onready var btn_opcoes: Button = $MenuPanel/VBoxContainer/BtnOpcoes
@onready var btn_sair: Button = $MenuPanel/VBoxContainer/BtnSair

var _botoes: Array[Button] = []

func _ready() -> void:
	_botoes = [btn_jogar, btn_carregar, btn_opcoes, btn_sair]
	
	btn_jogar.pressed.connect(_on_btn_jogar_pressed)
	btn_sair.pressed.connect(_on_btn_sair_pressed)
	btn_carregar.pressed.connect(func(): print("Carregar não implementado"))
	btn_opcoes.pressed.connect(func(): print("Opções não implementado"))
	
	for btn in _botoes:
		btn.focus_entered.connect(_on_btn_focus.bind(btn, true))
		btn.focus_exited.connect(_on_btn_focus.bind(btn, false))
		btn.mouse_entered.connect(btn.grab_focus)
		_on_btn_focus(false, btn)

	btn_jogar.grab_focus()

func _on_btn_focus(focado: bool, btn: Button) -> void:
	var base_text = btn.text.strip_edges(true, false).trim_prefix(">").strip_edges(true, false)
	if focado:
		btn.text = "> " + base_text
	else:
		btn.text = "  " + base_text

func _on_btn_jogar_pressed() -> void:
	get_tree().change_scene_to_file("res://src/main/main.tscn")

func _on_btn_sair_pressed() -> void:
	get_tree().quit()
