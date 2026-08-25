extends Control
## Tela de escolha de operador. E a PRIMEIRA tela do jogo, nao um painel sobre
## o menu.
##
## Ela absorveu o menu inicial. O fluxo era intro -> menu -> NOVO JOGO ->
## selecao, e "NOVO JOGO" era um clique que so existia para levar a tela onde a
## escolha de verdade acontece. Hoje escolher o operador E comecar a partida, e
## OPCOES/SAIR ficam na barra de baixo. "CARREGAR" saiu junto: era um botao que
## imprimia "nao implementado" no console.
##
## Toda a moldura e DESENHADA (`MolduraHud`) em vez de vir de textura: o chanfro
## de canto nao existe em StyleBox, e desenhar deixa a cor do operador tingir o
## cartao em runtime sem precisar de um arquivo por cor.
##
## A lista de personagens e @export: operador novo e um .tres arrastado para ela
## no editor, sem GDScript.

signal escolhido(dados: DadosPersonagem)
signal pediu_opcoes()
signal pediu_sair()

const LARGURA_CARD := 330
## Altura da caixa do retrato. O arquivo ja vem em 128 (o recorte de 64 dobrado
## pelo gerador), entao a caixa em 128 desenha 1:1 -- qualquer outro numero
## reescalaria e borraria a pixel art.
const LADO_MINIATURA := 128
const SEPARACAO := 28

const COR_MOLDURA := Color(0.35, 0.62, 0.95)
const COR_TITULO := Color(1.0, 0.6, 0.2)
const COR_TEXTO := Color(0.66, 0.72, 0.84)

## Alfa da borda do cartao fora de foco. Esmaecer em vez de trocar por cinza
## mantem a identidade do operador legivel mesmo no cartao que nao esta ativo.
const ESMAECIDO := 0.22

@export var personagens: Array[DadosPersonagem] = []

@onready var _quadro: MolduraHud = $Quadro
@onready var _linha: HBoxContainer = $Quadro/Conteudo/Linha
@onready var _titulo: Label = $Quadro/Conteudo/Titulo
@onready var _barra: MolduraHud = $BarraInferior
@onready var _btn_opcoes: Button = $BarraInferior/Botoes/BtnOpcoes
@onready var _btn_sair: Button = $BarraInferior/Botoes/BtnSair

var _botoes: Array[Button] = []
## botao -> { "cartao": MolduraHud, "cor": Color }. Dicionario em vez de subir
## pela arvore a partir do botao: caminho de no e o que o GEMINI.md manda
## evitar, e aqui ele quebraria a cada mexida no layout.
var _cartoes: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_quadro.cor_borda = COR_MOLDURA
	_barra.cor_borda = Color(COR_MOLDURA, 0.7)
	_titulo.add_theme_color_override("font_color", COR_TITULO)

	_montar_cards()
	_btn_opcoes.pressed.connect(func() -> void: pediu_opcoes.emit())
	_btn_sair.pressed.connect(func() -> void: pediu_sair.emit())
	focar_primeiro()


## Devolve o foco ao primeiro cartao. Quem fecha as opcoes chama isto: sem
## ancora, a navegacao por teclado fica sem cursor visivel.
func focar_primeiro() -> void:
	if not _botoes.is_empty():
		_botoes[0].grab_focus()


func _montar_cards() -> void:
	_linha.add_theme_constant_override("separation", SEPARACAO)
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


## Um cartao: moldura chanfrada, nome, retrato, arma, texto e o perfil da arma.
##
## A area de clique e um Button de rect cheio POR CIMA de tudo, e nao o nome.
## Antes so o texto do nome respondia: o jogador mirava na arte, clicava, e nada
## acontecia -- num cartao deste tamanho o alvo util era uma linha de texto.
func _criar_card(dados: DadosPersonagem) -> Control:
	var cartao := MolduraHud.new()
	cartao.custom_minimum_size = Vector2(LARGURA_CARD, 0)
	cartao.cor_borda = Color(dados.cor, ESMAECIDO)
	cartao.cor_fundo = Color(0.05, 0.06, 0.09, 0.92)
	cartao.chanfro = 16.0
	cartao.espessura = 1.0
	cartao.colchetes = true
	# Menor que o padrao: no cartao os colchetes moram dentro da margem, e no
	# tamanho cheio a perna deles alcancava a primeira linha do perfil da arma.
	cartao.tamanho_colchete = 13.0
	cartao.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	cartao.margem = 14

	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 5)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartao.add_child(coluna)

	coluna.add_child(_faixa_do_nome(dados))

	if dados.miniatura != null:
		var retrato := TextureRect.new()
		retrato.texture = dados.miniatura
		retrato.custom_minimum_size = Vector2(0, LADO_MINIATURA)
		retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		retrato.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
		coluna.add_child(retrato)

	coluna.add_child(_faixa_da_arma(dados))
	coluna.add_child(_rotulo(tr(dados.descricao), 11, COR_TEXTO))
	coluna.add_child(_separador(dados.cor))
	for barra in _perfil_da_arma(dados):
		coluna.add_child(barra)

	# MarginContainer estica TODO filho para o proprio retangulo, entao o botao
	# cobre o cartao sem precisar de ancora.
	var area := Button.new()
	area.focus_mode = Control.FOCUS_ALL
	# Invisivel: quem desenha o estado e a moldura. O botao so recebe clique e
	# foco -- e por ser o ULTIMO filho fica na frente na ordem de desenho, que e
	# a mesma ordem em que o input e oferecido.
	var vazio := StyleBoxEmpty.new()
	for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
		area.add_theme_stylebox_override(estado, vazio)
	area.pressed.connect(_ao_escolher.bind(dados))
	cartao.add_child(area)

	_botoes.append(area)
	_cartoes[area] = {"cartao": cartao, "cor": dados.cor}
	return cartao


## "··· RAVEN ···": o nome ladeado pelas marcas de terminal do mockup.
func _faixa_do_nome(dados: DadosPersonagem) -> Control:
	var caixa := HBoxContainer.new()
	caixa.alignment = BoxContainer.ALIGNMENT_CENTER
	caixa.add_theme_constant_override("separation", 10)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE

	caixa.add_child(_marca(dados.cor))
	var nome := Label.new()
	nome.text = dados.nome
	nome.add_theme_font_size_override("font_size", 24)
	nome.add_theme_color_override("font_color", dados.cor)
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(nome)
	caixa.add_child(_marca(dados.cor))
	return caixa


func _marca(cor: Color) -> Label:
	var l := Label.new()
	l.text = "···"
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(cor, 0.55))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## O tipo da arma numa etiqueta com borda e o apelido ao lado: [SMG] "Mantis".
##
## O tipo sai do proprio nome do .tres, e nao de um campo novo: 'SMG "Mantis"'
## ja carrega os dois pedacos, e inventar `categoria` seria pedir que alguem
## mantivesse em dia um dado que o nome ja tem.
func _faixa_da_arma(dados: DadosPersonagem) -> Control:
	var caixa := HBoxContainer.new()
	caixa.alignment = BoxContainer.ALIGNMENT_CENTER
	caixa.add_theme_constant_override("separation", 10)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dados.arma_inicial == null:
		return caixa

	var partes := partir_nome_da_arma(dados.arma_inicial.nome)

	var etiqueta := MolduraHud.new()
	etiqueta.chanfro = 5.0
	etiqueta.espessura = 1.0
	etiqueta.linha_interna = false
	etiqueta.cor_borda = dados.cor
	etiqueta.cor_fundo = Color(dados.cor, 0.10)
	etiqueta.margem = 4
	etiqueta.custom_minimum_size = Vector2(74, 0)
	etiqueta.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var tipo := Label.new()
	tipo.text = String(partes[0]).to_upper()
	tipo.add_theme_font_size_override("font_size", 11)
	tipo.add_theme_color_override("font_color", dados.cor)
	tipo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tipo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tipo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	etiqueta.add_child(tipo)
	caixa.add_child(etiqueta)

	var apelido := Label.new()
	apelido.text = String(partes[1])
	apelido.add_theme_font_size_override("font_size", 15)
	apelido.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
	apelido.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	apelido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_child(apelido)
	return caixa


## 'SMG "Mantis"' -> ["SMG", "\"Mantis\""]. Arma sem aspas devolve o nome
## inteiro como tipo e apelido vazio, que e o certo para uma arma sem apelido.
static func partir_nome_da_arma(nome: String) -> Array:
	var i := nome.find("\"")
	if i < 0:
		return [nome.strip_edges(), ""]
	return [nome.substr(0, i).strip_edges(), nome.substr(i).strip_edges()]


func _perfil_da_arma(dados: DadosPersonagem) -> Array[BarraAtributo]:
	var lista: Array[BarraAtributo] = []
	var a := dados.arma_inicial
	if a == null:
		return lista
	var linhas := [
		[BarraAtributo.Icone.DANO, "DANO", a.perfil_dano()],
		[BarraAtributo.Icone.CADENCIA, "CADÊNCIA", a.perfil_cadencia()],
		[BarraAtributo.Icone.PRECISAO, "PRECISÃO", a.perfil_precisao()],
		[BarraAtributo.Icone.ALCANCE, "ALCANCE", a.perfil_alcance()],
	]
	for l in linhas:
		var barra := BarraAtributo.new()
		barra.configurar(l[0], tr(String(l[1])), float(l[2]), dados.cor)
		lista.append(barra)
	return lista


func _separador(cor: Color) -> Control:
	var linha := ColorRect.new()
	linha.color = Color(cor, 0.22)
	linha.custom_minimum_size = Vector2(0, 1)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return linha


func _rotulo(texto: String, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## O foco acende a moldura do cartao. E ela, e nao um marcador ">", que diz onde
## o cursor esta: com o nome centralizado, prefixar ">" empurraria o texto de
## lado a cada troca de foco.
func _ao_focar(focado: bool, btn: Button) -> void:
	if not _cartoes.has(btn):
		return
	var info: Dictionary = _cartoes[btn]
	var cor: Color = info["cor"]
	var cartao: MolduraHud = info["cartao"]
	cartao.cor_borda = cor if focado else Color(cor, ESMAECIDO)
	cartao.espessura = 2.0 if focado else 1.0


func _ao_escolher(dados: DadosPersonagem) -> void:
	escolhido.emit(dados)
