extends Control
## Painel de opcoes, compartilhado pelo menu inicial e pelo menu de pausa.
##
## E uma cena unica instanciada nos dois lugares, e nao dois paineis parecidos:
## opcao nova entra aqui e aparece nos dois sem ninguem lembrar de duplicar.
##
## Nao troca de cena. O padrao do projeto para painel e alternar `visible`
## (menu_pausa e tela_fim fazem assim); trocar de cena aqui obrigaria a recriar
## o fundo e o logo do menu, e a saber de onde o jogador veio para poder voltar.

signal fechado()

@onready var _tela_cheia: CheckButton = %TelaCheia
@onready var _shake: CheckButton = %Shake
@onready var _glitch: CheckButton = %Glitch
@onready var _btn_voltar: Button = %BtnVoltar


func _ready() -> void:
	# Obrigatorio para o painel responder com o jogo pausado -- mesmo motivo do
	# menu de pausa e do Juice.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_tela_cheia.toggled.connect(Configuracao.definir_tela_cheia)
	_shake.toggled.connect(Configuracao.definir_shake)
	_glitch.toggled.connect(Configuracao.definir_glitch)
	_btn_voltar.pressed.connect(fechar)


func abrir() -> void:
	_sincronizar()
	visible = true
	_btn_voltar.grab_focus()


func fechar() -> void:
	if not visible:
		return
	visible = false
	fechado.emit()


## Le o estado REAL antes de mostrar.
##
## A tela cheia em particular pode ter mudado sem passar por aqui: no navegador
## o jogador sai dela com ESC pelo proprio browser, e o itch.io ainda oferece um
## botao de fullscreen no proprio iframe. Confiar no booleano guardado deixaria o
## interruptor marcado com o jogo em janela.
##
## `set_pressed_no_signal` e nao `set_pressed`: marcar o interruptor aqui nao
## pode disparar o `toggled` e regravar a configuracao que acabamos de ler.
func _sincronizar() -> void:
	_tela_cheia.set_pressed_no_signal(Configuracao.esta_em_tela_cheia())
	_shake.set_pressed_no_signal(Configuracao.shake)
	_glitch.set_pressed_no_signal(Configuracao.glitch)


## ESC fecha o painel, e para por aqui.
##
## O `set_input_as_handled` nao e detalhe: `main.gd` trata a mesma tecla em
## `_unhandled_input`, que roda DEPOIS de `_input`. Sem marcar como tratado, um
## unico ESC fecharia o painel e despausaria o jogo por baixo dele.
func _input(evento: InputEvent) -> void:
	if not visible:
		return
	if evento.is_action_pressed("pausar"):
		fechar()
		get_viewport().set_input_as_handled()
