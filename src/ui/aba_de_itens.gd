class_name AbaDeItens
extends Control
## A aba ITENS: os aprimoramentos instalados nesta run.
##
## **Ela e uma GRADE e nao um corpo, e isso foi uma reversao consciente.** A
## primeira versao desta aba desenhava uma silhueta tecnica com os implantes
## pendurados por regiao (neural, nucleo, bracos...), ligados por linhas. O dono
## do projeto olhou e reprovou: a ideia pode voltar no futuro, mas por enquanto
## o inventario responde "o que eu tenho" e nao "no que eu me transformei".
##
## O campo `DadosItem.categoria_corporal` continua existindo e continua cobrado
## por `teste_inventario.gd` -- ele e a semente daquela ideia, e apagar os 16
## `.tres` para reescreve-los no dia em que ela voltar e trabalho jogado fora
## duas vezes. **Esta aba simplesmente nao o le.**
##
## **Repetido CONTA em vez de repetir**, pela mesma razao da bandeja da HUD: a
## lista crua cresceria com o numero de COLETAS, que nao tem teto, em vez de com
## o numero de implantes distintos, que tem teto de 16.

## O implante sob o cursor, para quem desenha o tooltip. `null` = nenhum.
signal apontou(dados: DadosItem)

## O lado de um icone. 48 e 3/4 dos 64 do arquivo, e isso NAO e escala inteira
## -- mas `draw_texture_rect` nao e `Sprite2D` com filtro Nearest herdado da
## cena, e a reducao aqui e feita pelo importador com mipmap. O degrau limpo
## seria 32 (1/2 exato); 48 foi medido como o que faz a peca ler numa grade de
## seis colunas sem a lista passar de duas linhas com os 16.
const LADO_ICONE := 48.0
## A largura de uma CELULA, que e maior que a do icone.
##
## Medido: com a celula do tamanho do icone (48), "Nanobots de Reparacao" e
## "Celula de Eco" saiam cortados no meio da palavra -- e nome cortado assim le
## como texto quebrado, e nao como texto abreviado. 88 e o que faz a maioria dos
## dezesseis caber inteiro; os que ainda nao cabem terminam em ".." explicito.
const LARGURA_CELULA := 88.0
## Vao entre celulas. Ele existe para as silhuetas nao se lerem como uma barra
## so -- o mesmo motivo do `ESPACO` da bandeja.
const ESPACO := 10.0
## Altura de uma celula: o icone mais a linha do nome embaixo dele.
const ALTURA_CELULA := LADO_ICONE + 16.0

const COR_TITULO := Color(0.42, 0.90, 1.00, 0.85)
const COR_TINTA := Color(0.86, 0.93, 1.00)
const COR_ROTULO := Color(0.55, 0.70, 0.80)
const COR_TRILHO := Color(0.16, 0.19, 0.26)
const COR_VAZIO := Color(0.34, 0.40, 0.48)
const COR_FUNDO_VAGA := Color(0.06, 0.07, 0.11, 0.60)
const COR_ESCOLHIDO := Color(0.42, 0.90, 1.00, 0.85)
const COR_ESCURA := Color(0.04, 0.05, 0.08)

const TAMANHO_TITULO := 10
const TAMANHO_NOME := 8
const TAMANHO_SIGLA := 18
const TAMANHO_CONTAGEM := 9

## Uma entrada por implante DISTINTO: {"dados": DadosItem, "contagem": int}.
var _vagas: Array[Dictionary] = []

## Onde cada celula foi DESENHADA, para o tooltip acertar o que o olho ve.
## Recalcular a caixa no hover deixaria a aba clicavel num lugar e desenhada
## noutro -- a mesma armadilha que a tela de troca ja evita perguntando ao painel.
var _caixas: Array[Dictionary] = []

var _apontado: DadosItem = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


## Le `Modificadores` e reagrupa.
##
## **Nao guarda uma segunda lista de implantes** -- o autoload continua sendo o
## dono, e esta e uma vista dele. Chamada a cada abertura, e nao por sinal: a
## aba so precisa estar em dia enquanto esta na tela.
func recolher() -> void:
	_vagas.clear()
	_apontado = null
	for item in Modificadores.itens_ativos():
		var achou := false
		for vaga in _vagas:
			if vaga["dados"] == item:
				vaga["contagem"] += 1
				achou = true
				break
		if not achou:
			_vagas.append({"dados": item, "contagem": 1})
	queue_redraw()


## Quantas celulas cabem por linha, no espaco que a aba de fato tem.
##
## Calculado e nao cravado: a aba muda de largura com a resolucao, e uma
## constante faria a ultima coluna sair pela borda na primeira janela diferente.
func colunas() -> int:
	return maxi(1, int((size.x + ESPACO) / (LARGURA_CELULA + ESPACO)))


## A caixa de uma celula, em coordenada local. Publica pela mesma razao que a
## `caixa_do_slot` da tela de troca: o hover pergunta onde foi desenhado.
func caixa_da_celula(indice: int) -> Rect2:
	var por_linha := colunas()
	var coluna := indice % por_linha
	var linha := indice / por_linha
	return Rect2(
		float(coluna) * (LARGURA_CELULA + ESPACO),
		24.0 + float(linha) * (ALTURA_CELULA + ESPACO),
		LARGURA_CELULA, ALTURA_CELULA)


func _draw() -> void:
	_caixas.clear()
	var fonte := ThemeDB.fallback_font

	draw_string(fonte, Vector2(0.0, 10.0), tr("SISTEMAS INSTALADOS"),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_TITULO, COR_TITULO)
	draw_line(Vector2(0.0, 16.0), Vector2(size.x, 16.0), COR_TRILHO, 1.0)

	if _vagas.is_empty():
		# **A run comeca assim, e isso nao e um defeito.** A frase existe para o
		# vazio dizer "ainda nao" em vez de parecer uma aba que nao carregou --
		# e ela e uma frase e nao uma fileira de vagas cinzentas, porque vaga
		# desenhada promete um limite que nao existe: os implantes sao
		# acumulativos e nao ha teto nenhum.
		draw_string(fonte, Vector2(0.0, 44.0), tr("NENHUM SISTEMA INSTALADO"),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_NOME, COR_VAZIO)
		return

	for i in _vagas.size():
		_desenhar_celula(fonte, i)


func _desenhar_celula(fonte: Font, indice: int) -> void:
	var vaga := _vagas[indice]
	var dados: DadosItem = vaga["dados"]
	var caixa := caixa_da_celula(indice)
	# O icone e CENTRADO na celula, que e mais larga que ele. Ancorado a esquerda,
	# a coluna de icones ficaria desalinhada da coluna de nomes.
	var quadro := Rect2(
		caixa.position + Vector2((LARGURA_CELULA - LADO_ICONE) * 0.5, 0.0),
		Vector2(LADO_ICONE, LADO_ICONE))
	_caixas.append({"caixa": caixa, "dados": dados})

	draw_rect(quadro, COR_FUNDO_VAGA)
	if dados == _apontado:
		draw_rect(quadro, COR_ESCOLHIDO, false, 1.0)

	if dados.icone != null:
		draw_texture_rect(dados.icone, quadro, false)
	else:
		# O fallback DECLARADO: losango de `cor` com a sigla dentro. Ele existe
		# para um implante poder nascer antes da arte dele, e some sozinho no dia
		# em que o icone chegar.
		var meio := quadro.get_center()
		var raio := LADO_ICONE * 0.40
		draw_colored_polygon(PackedVector2Array([
			meio + Vector2(0.0, -raio), meio + Vector2(raio, 0.0),
			meio + Vector2(0.0, raio), meio + Vector2(-raio, 0.0),
		]), dados.cor)
		draw_string(fonte, meio + Vector2(-5.0, 6.0), dados.sigla,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_SIGLA, COR_ESCURA)

	var contagem: int = vaga["contagem"]
	if contagem > 1:
		draw_string(fonte, quadro.end + Vector2(-9.0, -3.0), "%d" % contagem,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_CONTAGEM, COR_ESCOLHIDO)

	# O nome embaixo, cortado na largura da celula. **Ele nao substitui o
	# tooltip**: aqui cabem duas palavras, e o que o jogador precisa saber para
	# decidir esta na descricao. Ele existe para a aba ser legivel sem mouse --
	# num gamepad, futuramente, nao ha hover.
	draw_string(fonte, Vector2(caixa.position.x, quadro.end.y + 11.0),
		_encurtar(fonte, tr(dados.nome), LARGURA_CELULA),
		HORIZONTAL_ALIGNMENT_CENTER, LARGURA_CELULA, TAMANHO_NOME, COR_ROTULO)


## Corta o nome com ".." quando ele nao cabe.
##
## `draw_string` com largura maxima apenas CLIPA -- o texto some no meio da
## palavra e le como defeito de renderizacao. O corte explicito le como
## abreviacao, que e o que ele e.
##
## E as reticencias sao **duas ASCII e nao o glifo `…`**: glifo que a fonte nao
## tem some sem erro nenhum, e ai o nome cortado volta a parecer quebrado. E a
## mesma armadilha do losango da moeda no preco da bancada.
func _encurtar(fonte: Font, texto: String, largura: float) -> String:
	if fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_NOME).x <= largura:
		return texto
	var curto := texto
	while curto.length() > 1:
		curto = curto.substr(0, curto.length() - 1)
		var medida := fonte.get_string_size(
			curto + "..", HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_NOME).x
		if medida <= largura:
			break
	return curto.strip_edges() + ".."


func _gui_input(evento: InputEvent) -> void:
	if not evento is InputEventMouseMotion:
		return
	var local: Vector2 = (evento as InputEventMouseMotion).position
	var achado: DadosItem = null
	for entrada in _caixas:
		if (entrada["caixa"] as Rect2).has_point(local):
			achado = entrada["dados"]
			break
	if achado == _apontado:
		return
	_apontado = achado
	apontou.emit(achado)
	queue_redraw()


## Quantos implantes DISTINTOS a aba mostraria agora. Publico porque o portao
## pergunta isto sem desenhar: "repetido conta em vez de repetir" e uma
## afirmacao sobre o agrupamento, e nao sobre pixel.
func distintos() -> int:
	return _vagas.size()
