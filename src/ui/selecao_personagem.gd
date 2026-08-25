extends Control
## Tela de escolha de personagem, entre o menu e a run.
##
## Nao troca de cena, alterna `visible` -- o mesmo padrao de menu_opcoes, e pelo
## mesmo motivo dito la: trocar de cena obrigaria a recriar o fundo e o logo do
## menu, e a saber de onde o jogador veio para poder voltar.
##
## A lista de personagens e @export e nao um preload fixo: personagem novo e um
## .tres arrastado para esta lista no editor, sem GDScript. Os cards sao
## construidos em codigo a partir dela, entao a cena nao sabe quantos sao.

signal escolhido(dados: DadosPersonagem)
signal fechado()

## Largura de cada card. Dois cabem lado a lado na tela de 960 com folga.
const LARGURA_CARD := 330
const SEPARACAO := 32
## Lado da miniatura. 128 = 2x exato dos 64 do arquivo. Escala fracionaria
## borra pixel art mesmo com filtro Nearest, porque um pixel da arte deixa de
## cair num numero redondo de pixels de tela.
const LADO_MINIATURA := 128

const COR_TITULO := Color(1.0, 0.6, 0.2)
const COR_PAPEL := Color(0.75, 0.82, 0.95)
const COR_TEXTO := Color(0.68, 0.74, 0.85)

@export var personagens: Array[DadosPersonagem] = []

@onready var _linha: HBoxContainer = $Painel/Linha

var _botoes: Array[Button] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_montar_cards()


func abrir() -> void:
	visible = true
	if not _botoes.is_empty():
		_botoes[0].grab_focus()


func fechar() -> void:
	if not visible:
		return
	visible = false
	fechado.emit()


## ESC fecha. Marcar como tratado e obrigatorio: main.gd escuta `pausar` em
## _unhandled_input, e sem isto o mesmo ESC fecharia a tela E pediria pausa.
func _input(evento: InputEvent) -> void:
	if not visible:
		return
	if evento.is_action_pressed("pausar"):
		fechar()
		get_viewport().set_input_as_handled()


func _montar_cards() -> void:
	for dados in personagens:
		if dados == null:
			continue
		_linha.add_child(_criar_card(dados))

	for btn in _botoes:
		# A ORDEM do bind importa -- focus_entered nao passa argumento nenhum,
		# entao o que o bind anexa e tudo que chega. Invertido, o Button cai no
		# parametro `focado: bool` e cada foco cospe erro de conversao. O mesmo
		# comentario existe em menu_inicial.gd, onde o bug aconteceu.
		btn.focus_entered.connect(_ao_focar.bind(true, btn))
		btn.focus_exited.connect(_ao_focar.bind(false, btn))
		btn.mouse_entered.connect(btn.grab_focus)
		_ao_focar(false, btn)


func _criar_card(dados: DadosPersonagem) -> Control:
	var caixa := VBoxContainer.new()
	caixa.custom_minimum_size = Vector2(LARGURA_CARD, 0)
	caixa.add_theme_constant_override("separation", 6)

	# Miniatura a esquerda, nome e papel a direita. O resto do card continua
	# embaixo, em coluna, porque sao linhas longas.
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 12)
	if dados.miniatura != null:
		var retrato := TextureRect.new()
		retrato.texture = dados.miniatura
		retrato.custom_minimum_size = Vector2(LADO_MINIATURA, LADO_MINIATURA)
		retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		topo.add_child(retrato)

	var coluna := VBoxContainer.new()
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_theme_constant_override("separation", 4)
	topo.add_child(coluna)
	caixa.add_child(topo)

	var botao := Button.new()
	botao.text = dados.nome
	botao.alignment = HORIZONTAL_ALIGNMENT_LEFT
	botao.add_theme_font_size_override("font_size", 24)
	# O foco clareia a propria cor em vez de virar branco: a cor E a identidade
	# do personagem, e trocar por branco apagava justamente quem esta em foco. O
	# marcador ">" ja diz onde o cursor esta.
	botao.add_theme_color_override("font_color", dados.cor)
	var focada := dados.cor.lerp(Color.WHITE, 0.45)
	botao.add_theme_color_override("font_focus_color", focada)
	botao.add_theme_color_override("font_hover_color", focada)
	var vazio := StyleBoxEmpty.new()
	for estado in ["normal", "hover", "pressed", "focus"]:
		botao.add_theme_stylebox_override(estado, vazio)
	botao.pressed.connect(_ao_escolher.bind(dados))
	coluna.add_child(botao)
	_botoes.append(botao)

	coluna.add_child(_rotulo(dados.papel, 12, COR_PAPEL, LADO_MINIATURA))

	var arma := dados.arma_inicial.nome if dados.arma_inicial != null else "-"
	caixa.add_child(_rotulo("ARMA  %s" % arma, 11, COR_TITULO))

	caixa.add_child(_rotulo(dados.descricao, 11, COR_TEXTO))
	return caixa


func _rotulo(texto: String, tamanho: int, cor: Color, largura: int = LARGURA_CARD) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Minimo e nao fixo: dentro do HBox a coluna cresce com o que sobra da
	# miniatura, e travar a largura do card inteiro empurraria a miniatura para
	# fora do painel.
	l.custom_minimum_size = Vector2(largura, 0)
	return l


## O mesmo marcador ">" do menu inicial, para a navegacao por teclado ter
## ancora visivel. Reescreve o texto a partir do nome limpo, senao o ">" se
## acumula a cada foco.
func _ao_focar(focado: bool, btn: Button) -> void:
	var base := btn.text.strip_edges(true, false).trim_prefix(">").strip_edges(true, false)
	btn.text = "> " + base if focado else "  " + base


func _ao_escolher(dados: DadosPersonagem) -> void:
	escolhido.emit(dados)
