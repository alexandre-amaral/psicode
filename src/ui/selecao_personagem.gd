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
const LARGURA_CARD := 280
const SEPARACAO := 32
## Lado da miniatura. 128 = 2x exato dos 80 do arquivo? Nao: e o TETO da caixa.
## O retrato usa KEEP_ASPECT_CENTERED, entao 160 = 2x exato dos 80 e o que
## mantem a grade de pixel intacta -- escala fracionaria borra pixel art mesmo
## com filtro Nearest.
const LADO_MINIATURA := 160

const COR_TITULO := Color(1.0, 0.6, 0.2)

## Espessura da borda do cartao.
const BORDA := 2
## Fundo do cartao. Um degrau acima do painel (0.05, 0.05, 0.08) para o cartao
## se separar dele sem precisar de sombra.
const COR_FUNDO_CARTAO := Color(0.09, 0.10, 0.14, 0.9)

@export var personagens: Array[DadosPersonagem] = []

@onready var _linha: HBoxContainer = $Painel/Linha

var _botoes: Array[Button] = []
## botao -> { "cartao": PanelContainer, "normal": StyleBox, "focada": StyleBox }.
## Um dicionario em vez de subir pela arvore a partir do botao: caminho de no e
## o que o GEMINI.md manda evitar, e aqui ele quebraria a cada mexida no layout.
var _cartoes: Dictionary = {}


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


## Miniatura, nome e arma. So isso, e o cartao INTEIRO clica.
##
## O papel e a lista de comportamentos sairam: o card e para RECONHECER quem se
## escolhe, nao para ensinar a jogar. Com quatro blocos de texto, a arte -- que
## e o que de fato distingue as duas -- ficava espremida entre paragrafos.
##
## A area de clique e um Button de rect cheio POR CIMA do conteudo, e nao o
## nome. Antes so o texto do nome respondia: o jogador mirava na arte, clicava,
## e nao acontecia nada -- num cartao de 280x260, o alvo util era uma linha de
## texto. Como PanelContainer estica todo filho para o proprio rect, o botao
## cobre o cartao sozinho; e por ser o ULTIMO filho, ele fica na frente na
## ordem de desenho, que e a mesma ordem em que o input e oferecido.
func _criar_card(dados: DadosPersonagem) -> Control:
	var cartao := PanelContainer.new()
	cartao.custom_minimum_size = Vector2(LARGURA_CARD, 0)
	cartao.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var normal := _borda(dados.cor, 0.35)
	var focada := _borda(dados.cor, 1.0)
	cartao.add_theme_stylebox_override("panel", normal)

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	# So decoracao: quem responde a mouse e o botao de cima.
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartao.add_child(coluna)

	if dados.miniatura != null:
		var retrato := TextureRect.new()
		retrato.texture = dados.miniatura
		retrato.custom_minimum_size = Vector2(LADO_MINIATURA, LADO_MINIATURA)
		retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		coluna.add_child(retrato)

	var nome := _rotulo(dados.nome, 24, dados.cor, LARGURA_CARD - 32)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(nome)

	var arma := dados.arma_inicial.nome if dados.arma_inicial != null else "-"
	var rotulo := _rotulo(arma, 12, COR_TITULO, LARGURA_CARD - 32)
	rotulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(rotulo)

	var area := Button.new()
	area.focus_mode = Control.FOCUS_ALL
	# Invisivel de proposito: quem desenha o estado e a borda do PanelContainer
	# e a cor do nome. O botao existe so para receber clique e foco.
	var vazio := StyleBoxEmpty.new()
	for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
		area.add_theme_stylebox_override(estado, vazio)
	area.pressed.connect(_ao_escolher.bind(dados))
	cartao.add_child(area)

	_botoes.append(area)
	_cartoes[area] = {
		"cartao": cartao, "normal": normal, "focada": focada,
		"nome": nome, "cor": dados.cor,
	}
	return cartao


## A borda do cartao, na cor do personagem. `intensidade` separa o estado de
## foco do de repouso -- e ela, e nao o marcador ">", que diz onde o cursor
## esta: com o nome centralizado, prefixar ">" empurraria o texto de lado a
## cada troca de foco.
func _borda(cor: Color, intensidade: float) -> StyleBoxFlat:
	var caixa := StyleBoxFlat.new()
	caixa.bg_color = COR_FUNDO_CARTAO
	caixa.border_width_left = BORDA
	caixa.border_width_top = BORDA
	caixa.border_width_right = BORDA
	caixa.border_width_bottom = BORDA
	caixa.border_color = Color(cor.r, cor.g, cor.b, intensidade)
	caixa.content_margin_left = 16
	caixa.content_margin_right = 16
	caixa.content_margin_top = 16
	caixa.content_margin_bottom = 16
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


func _ao_focar(focado: bool, btn: Button) -> void:
	if not _cartoes.has(btn):
		return
	var info: Dictionary = _cartoes[btn]
	var cartao: PanelContainer = info["cartao"]
	cartao.add_theme_stylebox_override("panel", info["focada"] if focado else info["normal"])
	# O nome clareia junto da borda, mas continua na cor do personagem: a cor E
	# a identidade dele, e virar branco apagaria justamente quem esta em foco.
	var cor: Color = info["cor"]
	var nome: Label = info["nome"]
	nome.add_theme_color_override("font_color", cor.lerp(Color.WHITE, 0.45) if focado else cor)


func _ao_escolher(dados: DadosPersonagem) -> void:
	escolhido.emit(dados)
