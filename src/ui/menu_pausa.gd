extends CanvasLayer

@onready var btn_continuar: Button = $Painel/VBoxContainer/BtnContinuar
@onready var btn_menu: Button = $Painel/VBoxContainer/BtnMenu
@onready var btn_opcoes: Button = $Painel/VBoxContainer/BtnOpcoes
@onready var _opcoes: Control = $MenuOpcoes
@onready var _painel: Control = $Painel
@onready var _fundo: ColorRect = $ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	btn_continuar.pressed.connect(_on_btn_continuar_pressed)
	btn_opcoes.pressed.connect(_abrir_opcoes)
	btn_menu.pressed.connect(_on_btn_menu_pressed)
	_opcoes.fechado.connect(_ao_fechar_opcoes)

func _process(_delta: float) -> void:
	var pausado = (GameState.estado == GameState.Estado.PAUSADO)
	if visible != pausado:
		visible = pausado
		if visible:
			btn_continuar.grab_focus()
		else:
			# Despausar com as opcoes abertas deixaria o painel "aberto" por
			# baixo, e ele reapareceria sozinho na proxima pausa.
			_opcoes.fechar()

func _on_btn_continuar_pressed() -> void:
	GameState.alternar_pausa()

func _on_btn_menu_pressed() -> void:
	GameState.estado = GameState.Estado.MENU
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/ui/menu_inicial.tscn")


func _abrir_opcoes() -> void:
	# Some com o painel de pausa enquanto as opcoes estao na frente. O
	# escurecimento continua, entao o jogo segue legivel ao fundo.
	_painel.visible = false
	_opcoes.abrir()


func _ao_fechar_opcoes() -> void:
	_painel.visible = true
	btn_opcoes.grab_focus()
