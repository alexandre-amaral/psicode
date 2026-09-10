class_name PainelDeTroca
extends Control
## O desenho da escolha: a arma nova em cima, os dois slots embaixo.
##
## Ele **desenha e nao decide**. Quem le tecla, pausa a arvore e devolve a
## escolha e `tela_troca_de_arma.gd`; este no so responde "com estes tres
## `DadosArma`, como fica a tela". A divisao e a mesma de `hud.gd` com
## `bandeja_implantes.gd`, e existe para o portao poder conferir a decisao sem
## desenhar nada.
##
## **Ele mostra QUATRO atributos e nao vinte** (§35 do plano). O objetivo aqui e
## uma decisao rapida no meio de uma run, e nao uma ficha tecnica: a lista longa
## faz o jogador parar de ler e escolher pelo nome. Os quatro sao os mesmos que
## o cartao de selecao de personagem ja desenha, e pela mesma razao -- eles saem
## de `DadosArma.perfil_*()`, que le o `.tres`, entao a barra nunca descola do
## que a arma faz de fato.

## A arma que esta sendo oferecida.
var nova: DadosArma = null
## As duas carregadas, na ordem dos slots. `null` numa vaga nao acontece aqui --
## esta tela so existe com os dois slots cheios --, mas o desenho aguenta.
var atuais: Array = [null, null]
## Qual slot esta sob o cursor/foco. -1 = nenhum.
var destaque: int = -1

const LARGURA_PAINEL := 560.0
const ALTURA_CARTAO := 96.0
const ESPACO := 12.0
const MARGEM := 20.0

## O lado do icone desenhado. 64 e o tamanho do arquivo -- escala 1:1, a unica
## que nao reamostra. Aqui ha espaco para isso, ao contrario da bandeja da HUD,
## que reduz para 16 (1/4 exato) porque a coluna de status nao tem 64 px.
const LADO_ICONE := 64.0

## A coluna das quatro barras. Ela e a mesma na oferta e nos dois cartoes: as
## tres reguas so comparam se estiverem alinhadas, e barras de larguras
## diferentes fariam a arma de cima parecer melhor que a de baixo pelo desenho.
const LARGURA_BARRAS := 190.0

const COR_FUNDO := Color(0.05, 0.06, 0.10, 0.94)
const COR_BORDA := Color(0.42, 0.90, 1.00, 0.55)
const COR_TINTA := Color(0.86, 0.93, 1.00)
const COR_APAGADA := Color(0.55, 0.62, 0.72)
const COR_TRILHO := Color(0.16, 0.19, 0.26)
const COR_DESTAQUE := Color(1.00, 0.72, 0.29)

const TAMANHO_TITULO := 13
const TAMANHO_NOME := 15
const TAMANHO_ROTULO := 9


## Os cantos dos dois cartoes de slot, em coordenada local. Publico porque o
## clique do mouse precisa da MESMA geometria do desenho -- calcular a caixa
## duas vezes e como a tela ficaria clicavel num lugar e desenhada noutro.
func caixa_do_slot(indice: int) -> Rect2:
	var topo := MARGEM + 150.0 + float(indice) * (ALTURA_CARTAO + ESPACO)
	return Rect2(MARGEM, topo, LARGURA_PAINEL - MARGEM * 2.0, ALTURA_CARTAO)


func _draw() -> void:
	var fonte := ThemeDB.fallback_font
	var largura := LARGURA_PAINEL

	draw_rect(Rect2(0.0, 0.0, largura, size.y), COR_FUNDO)
	draw_rect(Rect2(0.0, 0.0, largura, size.y), COR_BORDA, false, 1.0)

	_desenhar_oferta(fonte, largura)

	# A regua que separa "o que chegou" de "o que sai". Sem ela os tres cartoes
	# leem como uma lista de tres armas iguais, e a pergunta da tela -- qual
	# destas duas eu deixo? -- some.
	var y_regua := MARGEM + 134.0
	draw_line(Vector2(MARGEM, y_regua), Vector2(largura - MARGEM, y_regua), COR_TRILHO, 1.0)
	draw_string(fonte, Vector2(MARGEM, y_regua - 6.0), tr("SUBSTITUIR:"),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_ROTULO, COR_APAGADA)

	for i in 2:
		_desenhar_slot(fonte, i)

	var y_rodape := caixa_do_slot(1).end.y + 22.0
	draw_string(fonte, Vector2(MARGEM, y_rodape), tr("[1] [2] ESCOLHER") + "     " + tr("[ESC] CANCELAR"),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_ROTULO, COR_APAGADA)


func _desenhar_oferta(fonte: Font, largura: float) -> void:
	if nova == null:
		return
	draw_string(fonte, Vector2(MARGEM, MARGEM + 10.0), tr("NOVA ARMA"),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_ROTULO, COR_APAGADA)

	var y := MARGEM + 24.0
	_desenhar_icone(nova, Vector2(MARGEM, y))
	var x_texto := MARGEM + LADO_ICONE + ESPACO

	# **O nome tem largura MAXIMA, e ela e o vao ate a coluna de barras.** Sem o
	# limite, `Lanca-Granadas "Boomer"` -- o nome mais comprido da pool -- entrava
	# por cima do rotulo DANO. Nome que atravessa outro campo nao da erro: da uma
	# tela que parece quebrada exatamente na arma que o jogador esta avaliando.
	var x_barras := largura - LARGURA_BARRAS - MARGEM
	draw_string(fonte, Vector2(x_texto, y + 20.0), tr(nova.nome),
		HORIZONTAL_ALIGNMENT_LEFT, x_barras - x_texto - ESPACO, TAMANHO_NOME, nova.cor_projetil)
	_desenhar_tags(fonte, nova, Vector2(x_texto, y + 38.0))
	_desenhar_barras(fonte, nova, Vector2(x_barras, y + 6.0), LARGURA_BARRAS)


func _desenhar_slot(fonte: Font, indice: int) -> void:
	var caixa := caixa_do_slot(indice)
	var dados: DadosArma = atuais[indice] as DadosArma
	var escolhido := indice == destaque

	draw_rect(caixa, COR_TRILHO if not escolhido else Color(0.14, 0.17, 0.22, 1.0))
	draw_rect(caixa, COR_DESTAQUE if escolhido else COR_BORDA, false, 1.0)

	# A tecla e desenhada DENTRO do cartao, e nao numa legenda de rodape: a
	# escolha e por numero, e um numero que mora longe do que ele escolhe faz o
	# jogador contar de cima para baixo antes de apertar.
	draw_string(fonte, caixa.position + Vector2(8.0, 18.0), "[%d]" % (indice + 1),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_TITULO,
		COR_DESTAQUE if escolhido else COR_APAGADA)

	if dados == null:
		draw_string(fonte, caixa.position + Vector2(40.0, 18.0), tr("VAZIO"),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_ROTULO, COR_APAGADA)
		return

	_desenhar_icone(dados, caixa.position + Vector2(38.0, (ALTURA_CARTAO - LADO_ICONE) * 0.5))
	var x_texto := caixa.position.x + 38.0 + LADO_ICONE + ESPACO
	var x_barras := caixa.end.x - LARGURA_BARRAS - ESPACO
	draw_string(fonte, Vector2(x_texto, caixa.position.y + 26.0), tr(dados.nome),
		HORIZONTAL_ALIGNMENT_LEFT, x_barras - x_texto - ESPACO, TAMANHO_NOME, dados.cor_projetil)
	_desenhar_tags(fonte, dados, Vector2(x_texto, caixa.position.y + 44.0))
	_desenhar_barras(fonte, dados, Vector2(x_barras, caixa.position.y + 10.0), LARGURA_BARRAS)


## O icone da arma, ou o losango de `cor_projetil` quando ela ainda nao tem
## arte. **A ausencia cai no fallback e nunca deixa um buraco**: `DadosArma.icone`
## e opcional de proposito, e e ele que permite uma arma nova nascer com os
## numeros prontos e o desenho vindo depois.
func _desenhar_icone(dados: DadosArma, canto: Vector2) -> void:
	if dados.icone != null:
		draw_texture_rect(dados.icone, Rect2(canto, Vector2(LADO_ICONE, LADO_ICONE)), false)
		return
	var meio := canto + Vector2(LADO_ICONE, LADO_ICONE) * 0.5
	var raio := LADO_ICONE * 0.32
	draw_colored_polygon(PackedVector2Array([
		meio + Vector2(0.0, -raio), meio + Vector2(raio, 0.0),
		meio + Vector2(0.0, raio), meio + Vector2(-raio, 0.0),
	]), dados.cor_projetil)


## As quatro barras. Elas vem de `DadosArma.perfil_*()`, que le o `.tres` -- uma
## copia dos numeros aqui descolaria da arma na primeira sessao de tuning.
func _desenhar_barras(fonte: Font, dados: DadosArma, canto: Vector2, largura: float) -> void:
	var perfis := [
		[tr("DANO"), dados.perfil_dano()],
		[tr("CADÊNCIA"), dados.perfil_cadencia()],
		[tr("PRECISÃO"), dados.perfil_precisao()],
		[tr("ALCANCE"), dados.perfil_alcance()],
	]
	var altura := 5.0
	var passo := 16.0
	var x_barra := canto.x + 62.0
	var largura_barra := largura - 62.0
	for i in perfis.size():
		var y := canto.y + float(i) * passo
		draw_string(fonte, Vector2(canto.x, y + altura + 2.0), str(perfis[i][0]),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_ROTULO, COR_APAGADA)
		draw_rect(Rect2(x_barra, y, largura_barra, altura), COR_TRILHO)
		var fracao: float = clampf(float(perfis[i][1]), 0.0, 1.0)
		draw_rect(Rect2(x_barra, y, largura_barra * fracao, altura), dados.cor_projetil)


## As tags de comportamento. Elas dizem o que barra nenhuma diz -- uma arma
## explosiva e uma teleguiada podem ter perfis identicos e jogar diferente.
func _desenhar_tags(fonte: Font, dados: DadosArma, canto: Vector2) -> void:
	var tags := tags_de(dados)
	if tags.is_empty():
		return
	# A traducao acontece AQUI e nao em `tags_de()`: aquela e `static` para o
	# portao poder perguntar sem montar a tela, e `tr()` e metodo de `Node`. De
	# quebra o portao passa a afirmar sobre a CHAVE em portugues, que e o que o
	# `.tres` guarda -- uma suite que lesse texto ja traduzido passaria na
	# maquina de quem tem o SO em portugues e quebraria no CI, que roda em ingles.
	var traduzidas: Array[String] = []
	for t in tags:
		traduzidas.append(tr(t))
	draw_string(fonte, canto, " · ".join(traduzidas),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_ROTULO, COR_TINTA)


## As tags de uma arma, como texto.
##
## `static` porque o portao pergunta isto sem montar a tela: "toda arma da pool
## produz alguma tag legivel" e uma afirmacao sobre os `.tres`, e nao sobre o
## desenho. Por isso ela devolve a CHAVE em portugues e nao o texto traduzido --
## quem traduz e quem desenha.
static func tags_de(dados: DadosArma) -> Array[String]:
	var tags: Array[String] = []
	if dados == null:
		return tags
	match dados.comportamento:
		DadosArma.Comportamento.FANTASMA: tags.append("FANTASMA")
		DadosArma.Comportamento.GRAVIDADE: tags.append("GRAVIDADE")
		DadosArma.Comportamento.EXPLOSIVO: tags.append("EXPLOSIVO")
		DadosArma.Comportamento.PLASMA: tags.append("PLASMA")
		DadosArma.Comportamento.TELEGUIADO: tags.append("TELEGUIADO")
		DadosArma.Comportamento.CORRENTE: tags.append("CORRENTE")
		DadosArma.Comportamento.NANITE: tags.append("NANITE")
		DadosArma.Comportamento.FEIXE: tags.append("FEIXE")
	if dados.perfuracao > 0:
		tags.append("PERFURA")
	if dados.projeteis_por_tiro > 1:
		tags.append("RAJADA")
	return tags
