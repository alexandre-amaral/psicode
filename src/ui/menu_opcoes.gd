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

## Cor de repouso do rotulo de uma linha. Vem do Theme do painel, e esta
## repetida aqui porque o foco precisa saber para onde VOLTAR.
const COR_ROTULO := Color(0.85, 0.85, 0.9)
const COR_FOCO := Color(1.0, 0.8, 0.4)

@onready var _tela_cheia: CheckButton = %TelaCheia
@onready var _shake: CheckButton = %Shake
@onready var _glitch: CheckButton = %Glitch
@onready var _vol_master: HSlider = %VolMaster
@onready var _vol_sfx: HSlider = %VolSfx
@onready var _vol_ambiente: HSlider = %VolAmbiente
@onready var _idioma: OptionButton = %Idioma
@onready var _btn_voltar: Button = %BtnVoltar

## controle -> o Label da linha dele.
##
## Cada linha e um HBox com o texto num Label e o controle a direita, e nao um
## CheckButton com texto proprio. Foi o que alinhou a coluna: CheckButton
## desenha o texto depois do recuo interno do StyleBox dele, e o Label do idioma
## nao tinha recuo nenhum -- os quatro rotulos comecavam em x diferentes. Com
## todos sendo Label, o alinhamento e estrutural em vez de calibrado no olho.
##
## O preco e que o CheckButton deixou de ter texto para recolorir no foco. Este
## dicionario devolve isso: quem ganha foco pinta o proprio rotulo.
var _rotulos: Dictionary = {}


func _ready() -> void:
	# Obrigatorio para o painel responder com o jogo pausado -- mesmo motivo do
	# menu de pausa e do Juice.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_tela_cheia.toggled.connect(Configuracao.definir_tela_cheia)
	_shake.toggled.connect(Configuracao.definir_shake)
	_glitch.toggled.connect(Configuracao.definir_glitch)
	_ligar_volumes()
	_montar_idiomas()
	_ligar_rotulos()
	_btn_voltar.pressed.connect(fechar)


## Cada slider grava no bus dele.
##
## `value_changed` e nao `drag_ended`: o jogador tem de OUVIR enquanto arrasta,
## senao ele ajusta no escuro e so descobre o resultado quando solta. Gravar a
## cada passo custa uma escrita em `user://` por 0,05 de slider, que e barato --
## e `definir_volume` ja emite `configuracao_mudou`, que e por onde o autoload de
## audio reaplica.
func _ligar_volumes() -> void:
	for par in [
		[_vol_master, &"master"], [_vol_sfx, &"sfx"], [_vol_ambiente, &"ambiente"],
	]:
		var slider: HSlider = par[0]
		var qual: StringName = par[1]
		slider.value_changed.connect(
			func(v: float) -> void: Configuracao.definir_volume(qual, v)
		)


## O foco de cada controle acende o rotulo da linha dele.
func _ligar_rotulos() -> void:
	for controle: Control in [
		_tela_cheia, _shake, _glitch, _vol_master, _vol_sfx, _vol_ambiente, _idioma,
	]:
		var rotulo := controle.get_parent().get_node_or_null("Rotulo") as Label
		if rotulo == null:
			continue
		_rotulos[controle] = rotulo
		# A ORDEM do bind importa: focus_entered nao passa argumento nenhum,
		# entao o que o bind anexa e tudo que chega. Invertido, o Control cai no
		# parametro `focado: bool` e cada foco cospe erro de conversao.
		controle.focus_entered.connect(_ao_focar_linha.bind(true, controle))
		controle.focus_exited.connect(_ao_focar_linha.bind(false, controle))


func _ao_focar_linha(focado: bool, controle: Control) -> void:
	var rotulo: Label = _rotulos.get(controle)
	if rotulo == null:
		return
	rotulo.add_theme_color_override("font_color", COR_FOCO if focado else COR_ROTULO)


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
## Enche o seletor a partir de Configuracao.IDIOMAS.
##
## A lista vem do autoload e nao da cena: idioma novo e uma entrada la, sem
## abrir o editor. Os rotulos NAO passam por tr() de proposito -- cada lingua
## se anuncia na propria escrita, senao quem abriu as opcoes numa lingua que
## nao le fica sem reconhecer a dele.
func _montar_idiomas() -> void:
	_idioma.clear()
	for entrada in Configuracao.IDIOMAS:
		_idioma.add_item(String(entrada["rotulo"]))
	_idioma.item_selected.connect(_ao_escolher_idioma)


func _ao_escolher_idioma(indice: int) -> void:
	if indice < 0 or indice >= Configuracao.IDIOMAS.size():
		return
	Configuracao.definir_idioma(String(Configuracao.IDIOMAS[indice]["codigo"]))


func _sincronizar() -> void:
	_tela_cheia.set_pressed_no_signal(Configuracao.esta_em_tela_cheia())
	_shake.set_pressed_no_signal(Configuracao.shake)
	_glitch.set_pressed_no_signal(Configuracao.glitch)
	# `set_value_no_signal`: sincronizar nao pode disparar o `value_changed` e
	# regravar o que acabou de ser lido do disco.
	_vol_master.set_value_no_signal(Configuracao.volume_master)
	_vol_sfx.set_value_no_signal(Configuracao.volume_sfx)
	_vol_ambiente.set_value_no_signal(Configuracao.volume_ambiente)

	var atual := Configuracao.idioma_atual()
	for i in Configuracao.IDIOMAS.size():
		if String(Configuracao.IDIOMAS[i]["codigo"]) == atual:
			_idioma.selected = i


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
