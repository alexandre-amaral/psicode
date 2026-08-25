extends Control
## Menu inicial.
##
## O rotulo de versao le o config/version do project.godot em vez de trazer o
## numero escrito na cena. Estava fixo em "v1.0.3" enquanto o jogo era
## 0.1.0-alpha -- um testador leria a build como 1.0 e reportaria bug achando
## que e versao final. Lendo daqui, uma tag nova ja aparece certa no menu sem
## ninguem lembrar de editar a cena.

@onready var btn_jogar: Button = $MenuPanel/VBoxContainer/BtnJogar
@onready var btn_carregar: Button = $MenuPanel/VBoxContainer/BtnCarregar
@onready var btn_opcoes: Button = $MenuPanel/VBoxContainer/BtnOpcoes
@onready var btn_sair: Button = $MenuPanel/VBoxContainer/BtnSair
@onready var _rotulo_versao: Label = $RodapeEsq
@onready var _opcoes: Control = $MenuOpcoes
@onready var _selecao: Control = $SelecaoPersonagem
@onready var _painel: Panel = $MenuPanel

var _botoes: Array[Button] = []
## botao -> o texto em portugues, que e a CHAVE de traducao.
##
## Guardado aqui porque o marcador "> " e escrito DENTRO de `text`, e um
## "> NOVO JOGO" nao existe na tabela. Com a traducao automatica ligada o botao
## ficaria em portugues no jogo em ingles, calado. Entao ela e desligada nestes
## botoes e a traducao passa a ser explicita, aqui.
var _chaves: Dictionary = {}

func _ready() -> void:
	_mostrar_versao()

	_botoes = [btn_jogar, btn_carregar, btn_opcoes, btn_sair]

	btn_jogar.pressed.connect(_on_btn_jogar_pressed)
	btn_sair.pressed.connect(_on_btn_sair_pressed)
	btn_carregar.pressed.connect(func(): print("Carregar não implementado"))
	btn_opcoes.pressed.connect(_abrir_opcoes)
	_opcoes.fechado.connect(_ao_fechar_opcoes)
	_selecao.escolhido.connect(_ao_escolher_personagem)
	_selecao.fechado.connect(_ao_fechar_selecao)
	
	for btn in _botoes:
		_chaves[btn] = btn.text.strip_edges()
		btn.auto_translate_mode = Control.AUTO_TRANSLATE_MODE_DISABLED
		# A ORDEM do bind importa: focus_entered/focus_exited nao passam
		# argumento nenhum, entao o que o bind anexa e tudo que chega -- e chega
		# na ordem em que foi ligado. Com .bind(btn, true) a chamada virava
		# _on_btn_focus(btn, true), um Button no parametro `focado: bool`, e cada
		# foco de botao cuspia um erro de conversao no console.
		btn.focus_entered.connect(_on_btn_focus.bind(true, btn))
		btn.focus_exited.connect(_on_btn_focus.bind(false, btn))
		btn.mouse_entered.connect(btn.grab_focus)
		_on_btn_focus(false, btn)

	btn_jogar.grab_focus()

func _mostrar_versao() -> void:
	if _rotulo_versao == null:
		return
	var versao: String = str(ProjectSettings.get_setting("application/config/version", ""))
	# Sem versao configurada e melhor nao mostrar nada do que mostrar "v".
	_rotulo_versao.text = "v" + versao if not versao.is_empty() else ""


func _on_btn_focus(focado: bool, btn: Button) -> void:
	# Le a chave guardada em vez de raspar o proprio texto: raspar so funciona
	# enquanto o texto na tela E a chave, e em ingles ele deixa de ser.
	var base: String = _chaves.get(btn, btn.text.strip_edges())
	btn.text = ("> " if focado else "  ") + tr(base)


## O jogador acabou de trocar de idioma nas opcoes. Como estes botoes tem a
## traducao automatica desligada, ninguem os reescreve por conta propria.
func _notification(que: int) -> void:
	if que != NOTIFICATION_TRANSLATION_CHANGED:
		return
	for btn in _botoes:
		_on_btn_focus(btn.has_focus(), btn)

## NEW GAME abre a selecao; quem entra no jogo e a confirmacao dela.
func _on_btn_jogar_pressed() -> void:
	_painel.visible = false
	_selecao.abrir()


func _ao_escolher_personagem(dados: DadosPersonagem) -> void:
	# Escrever ANTES da troca de cena: quem le e o Player, no _ready da cena que
	# esta linha carrega.
	GameState.personagem = dados
	get_tree().change_scene_to_file("res://src/main/main.tscn")


func _ao_fechar_selecao() -> void:
	_painel.visible = true
	btn_jogar.grab_focus()

func _on_btn_sair_pressed() -> void:
	get_tree().quit()


func _abrir_opcoes() -> void:
	# Esconde o menu de tras: dois paineis empilhados confundem, e o
	# escurecimento sozinho nao segura o laranja dos botoes.
	_painel.visible = false
	_opcoes.abrir()


## Devolve o foco ao botao que abriu o painel. Sem isto a navegacao por teclado
## fica sem ancora depois de fechar, e o marcador ">" some da tela.
func _ao_fechar_opcoes() -> void:
	_painel.visible = true
	btn_opcoes.grab_focus()
