class_name PromptDeInteracao
extends Node2D
## O aviso de "da para interagir", flutuando ACIMA do objeto.
##
## A primeira versao era um `Label` no rodape da tela, e ela falhava na unica
## coisa que um prompt precisa fazer: dizer **em que** se vai interagir. Com duas
## capsulas lado a lado, um texto no rodape obriga o jogador a ligar uma frase na
## base da tela a um corpo no meio dela -- e enquanto ele faz essa ligacao, andar
## um passo troca a frase sem nada indicar qual das duas mudou.
##
## Aqui o aviso nasce em cima do objeto. Nao ha o que ligar: a tecla esta onde a
## coisa esta.
##
## **A tecla e LIDA do `InputMap`, e nunca escrita a mao.** "[E]" cravado no
## texto vira mentira no dia em que alguem remapear a acao -- e o jogo tem tela
## de opcoes, entao esse dia e uma questao de quando. Ler do mapa custa uma
## funcao e nunca desatualiza.

## A tecla desenhada como TECLA, e nao como letra solta.
##
## O jogador procura um botao; uma letra sozinha no meio do cenario le como
## decoracao. A moldura e o que faz "E" virar "aperte E".
const COR_TECLA := Color("30d9c4")
const COR_FUNDO := Color("0b0d16")
const COR_TEXTO := Color("c8d4e8")

const MARGEM := Vector2(6.0, 3.0)

var _fundo: Polygon2D = null
var _moldura: Line2D = null
var _tecla: Label = null
var _texto: Label = null


func _ready() -> void:
	# Acima de tudo: o prompt e informacao de interface que por acaso mora no
	# mundo, e ficar atras de um prop o tornaria inutil justamente quando o
	# jogador esta perto o bastante para ele aparecer.
	z_index = Sala.Z_FRENTE
	z_as_relative = false
	visible = false

	_fundo = Polygon2D.new()
	_fundo.color = COR_FUNDO
	add_child(_fundo)

	_moldura = Line2D.new()
	_moldura.width = 1.0
	_moldura.default_color = COR_TECLA
	_moldura.closed = true
	add_child(_moldura)

	_tecla = Label.new()
	_tecla.add_theme_color_override("font_color", COR_TECLA)
	add_child(_tecla)

	_texto = Label.new()
	_texto.add_theme_color_override("font_color", COR_TEXTO)
	add_child(_texto)


## Mostra o aviso deste objeto. `null` esconde.
func apontar(alvo: Interativo) -> void:
	if alvo == null:
		visible = false
		return
	visible = true
	global_position = alvo.global_position + Vector2(0.0, -alvo.altura_do_prompt)
	_tecla.text = tecla_de(&"interagir")
	_texto.text = alvo.texto
	_arranjar()


## O rotulo da tecla ligada a uma acao, lido do `InputMap`.
##
## Devolve o primeiro evento de TECLADO; um botao de gamepad no meio da lista nao
## pode roubar o rotulo, porque quem esta lendo isto esta olhando um teclado. Se
## a acao nao existir ou nao tiver tecla, devolve "?" em vez de vazio -- uma
## moldura vazia parece defeito, e "?" pelo menos diz que ha algo a apertar.
static func tecla_de(acao: StringName) -> String:
	if not InputMap.has_action(acao):
		return "?"
	for evento in InputMap.action_get_events(acao):
		var tecla := evento as InputEventKey
		if tecla == null:
			continue
		var codigo := tecla.physical_keycode
		if codigo == 0:
			codigo = tecla.keycode
		if codigo == 0:
			continue
		# `keycode_get_string` e nao o `key_label`: o label vem vazio quando a
		# tecla foi gravada so por posicao fisica, que e como este projeto grava.
		return OS.get_keycode_string(
			DisplayServer.keyboard_get_keycode_from_physical(codigo))
	return "?"


## Poe a moldura em volta da tecla e o texto ao lado, centrados no objeto.
func _arranjar() -> void:
	var t := _tecla.get_minimum_size()
	var d := _texto.get_minimum_size()
	var caixa := t + MARGEM * 2.0
	var largura := caixa.x + 8.0 + d.x
	var esquerda := -largura * 0.5

	_tecla.position = Vector2(esquerda + MARGEM.x, -caixa.y * 0.5 + MARGEM.y)
	_texto.position = Vector2(esquerda + caixa.x + 8.0, -d.y * 0.5)

	var canto := Vector2(esquerda, -caixa.y * 0.5)
	_fundo.polygon = PackedVector2Array([
		canto + Vector2(-3.0, -2.0),
		canto + Vector2(largura + 3.0, -2.0),
		canto + Vector2(largura + 3.0, caixa.y + 2.0),
		canto + Vector2(-3.0, caixa.y + 2.0),
	])
	_moldura.points = PackedVector2Array([
		canto,
		canto + Vector2(caixa.x, 0.0),
		canto + Vector2(caixa.x, caixa.y),
		canto + Vector2(0.0, caixa.y),
	])
