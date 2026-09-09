class_name AbaDeArmamento
extends Control
## A aba ARMAMENTO: as duas armas que o jogador carrega FISICAMENTE.
##
## Ela e a metade do inventario que TEM limite, e a separacao das outras duas
## abas e o que torna esse limite legivel: os aprimoramentos sao acumulativos e
## sem teto, as armas sao exatamente duas. Misturadas numa tela so, o jogador
## teria de descobrir sozinho qual das duas regras vale para o que ele acabou de
## pegar.
##
## Ela LE o inventario injetado por quem monta a tela -- nao procura o Player por
## grupo, pela mesma razao que a HUD nao conhece o Player.

## O inventario a desenhar. `null` e estado valido: a aba pode ser aberta fora
## de uma run (a regua visual faz isso) e desenha as duas vagas livres.
var inventario: InventarioDeArmas = null

const LADO_ICONE := 48.0
const ALTURA_SLOT := 64.0
const ESPACO := 10.0

const COR_TITULO := Color(0.42, 0.90, 1.00, 0.85)
const COR_ROTULO := Color(0.55, 0.70, 0.80)
const COR_TINTA := Color(0.86, 0.93, 1.00)
const COR_TRILHO := Color(0.16, 0.19, 0.26)
const COR_ATIVA := Color(1.00, 0.72, 0.29)
const COR_VAZIO := Color(0.34, 0.40, 0.48)

## A coluna das quatro barras. Igual em todos os cartoes: as reguas so comparam
## se estiverem alinhadas, e larguras diferentes fariam a arma de cima parecer
## melhor que a de baixo pelo desenho.
const LARGURA_BARRAS := 190.0

const TAMANHO_TITULO := 10
const TAMANHO_NOME := 14
const TAMANHO_ROTULO := 9


## Teto da largura de um cartao de slot.
##
## Sem ele os dois cartoes esticam pela largura inteira da aba (904 px) e o vao
## entre o nome da arma e as barras vira um deserto: o olho tem de atravessar a
## tela para ligar as duas metades da mesma arma. Duas armas nao preenchem uma
## tela, e fingir que preenchem e o que faz a aba parecer vazia.
const LARGURA_MAXIMA := 620.0


func caixa_do_slot(indice: int) -> Rect2:
	return Rect2(0.0, 26.0 + float(indice) * (ALTURA_SLOT + ESPACO),
		minf(size.x, LARGURA_MAXIMA), ALTURA_SLOT)


func _draw() -> void:
	var fonte := ThemeDB.fallback_font

	draw_string(fonte, Vector2(0.0, 10.0), tr("ARMAMENTO"),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_TITULO, COR_TITULO)
	draw_line(Vector2(0.0, 16.0), Vector2(minf(size.x, LARGURA_MAXIMA), 16.0), COR_TRILHO, 1.0)

	for i in InventarioDeArmas.SLOTS:
		_desenhar_slot(fonte, i, caixa_do_slot(i))

	var fim := caixa_do_slot(InventarioDeArmas.SLOTS - 1).end.y + 16.0
	# A dica da tecla mora AQUI e nao so na HUD: quem abre o inventario esta
	# justamente perguntando "o que eu carrego", e e o momento em que descobrir
	# que da para alternar custa menos.
	draw_string(fonte, Vector2(0.0, fim), tr("[F] ALTERNAR"),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_ROTULO, COR_ROTULO)


func _desenhar_slot(fonte: Font, indice: int, caixa: Rect2) -> void:
	var inst: InstanciaDeArma = inventario.slot(indice) if inventario != null else null
	var ativa := inventario != null and inventario.indice_ativo() == indice and inst != null

	draw_rect(caixa, COR_TRILHO)
	draw_rect(caixa, COR_ATIVA if ativa else COR_TRILHO, false, 1.0)
	draw_string(fonte, caixa.position + Vector2(8.0, 20.0), "[%d]" % (indice + 1),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_ROTULO, COR_ATIVA if ativa else COR_ROTULO)

	if inst == null or inst.dados == null:
		# Vaga vazia e o estado NORMAL do inicio da run, e nao um defeito. Ela
		# diz "cabe mais uma", que e a informacao que faz o jogador procurar.
		draw_string(fonte, caixa.position + Vector2(40.0, 20.0), tr("VAGA LIVRE"),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_ROTULO, COR_VAZIO)
		return

	var dados := inst.dados
	var canto := caixa.position + Vector2(36.0, (ALTURA_SLOT - LADO_ICONE) * 0.5)
	if dados.icone != null:
		draw_texture_rect(dados.icone, Rect2(canto, Vector2(LADO_ICONE, LADO_ICONE)), false)
	else:
		var meio := canto + Vector2(LADO_ICONE, LADO_ICONE) * 0.5
		var raio := LADO_ICONE * 0.36
		draw_colored_polygon(PackedVector2Array([
			meio + Vector2(0.0, -raio), meio + Vector2(raio, 0.0),
			meio + Vector2(0.0, raio), meio + Vector2(-raio, 0.0),
		]), dados.cor_projetil)

	var x_texto := canto.x + LADO_ICONE + ESPACO
	var x_barras := caixa.end.x - LARGURA_BARRAS - ESPACO
	draw_string(fonte, Vector2(x_texto, caixa.position.y + 24.0), tr(dados.nome),
		HORIZONTAL_ALIGNMENT_LEFT, x_barras - x_texto - ESPACO, TAMANHO_NOME, dados.cor_projetil)

	# O pente vem da INSTANCIA e nao do `.tres`: e justamente o numero que a
	# troca de arma tinha de preservar, e mostra-lo aqui e o que torna a regra
	# visivel ao jogador.
	draw_string(fonte, Vector2(x_texto, caixa.position.y + 40.0),
		"%d / %d" % [inst.pente, dados.pente()],
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_ROTULO, COR_TINTA)

	var tags := PainelDeTroca.tags_de(dados)
	if not tags.is_empty():
		var traduzidas: Array[String] = []
		for t in tags:
			traduzidas.append(tr(t))
		draw_string(fonte, Vector2(x_texto, caixa.position.y + 54.0), " · ".join(traduzidas),
			HORIZONTAL_ALIGNMENT_LEFT, x_barras - x_texto - ESPACO, TAMANHO_ROTULO, COR_ROTULO)

	_desenhar_barras(fonte, dados, Vector2(x_barras, caixa.position.y + 12.0))

	if ativa:
		# `pos.x` e a borda ESQUERDA da faixa de alinhamento. Passar a borda
		# direita ali desenha o texto inteiro para FORA do cartao -- foi assim
		# que este rotulo sumiu na primeira captura, sem erro nenhum.
		var faixa := 80.0
		draw_string(fonte, Vector2(caixa.end.x - 6.0 - faixa, caixa.position.y + 20.0),
			tr("ATIVA"), HORIZONTAL_ALIGNMENT_RIGHT, faixa, TAMANHO_ROTULO, COR_ATIVA)


## As quatro barras. Elas vem de `DadosArma.perfil_*()`, que le o `.tres` -- uma
## copia dos numeros aqui descolaria da arma na primeira sessao de tuning.
func _desenhar_barras(fonte: Font, dados: DadosArma, canto: Vector2) -> void:
	var perfis := [
		["DANO", dados.perfil_dano()],
		["CADÊNCIA", dados.perfil_cadencia()],
		["PRECISÃO", dados.perfil_precisao()],
		["ALCANCE", dados.perfil_alcance()],
	]
	var altura := 5.0
	var passo := 12.0
	var x_barra := canto.x + 62.0
	var largura_barra := LARGURA_BARRAS - 62.0
	for i in perfis.size():
		var y := canto.y + float(i) * passo
		draw_string(fonte, Vector2(canto.x, y + altura + 2.0), tr(str(perfis[i][0])),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_ROTULO, COR_ROTULO)
		draw_rect(Rect2(x_barra, y, largura_barra, altura), COR_TRILHO)
		var fracao: float = clampf(float(perfis[i][1]), 0.0, 1.0)
		draw_rect(Rect2(x_barra, y, largura_barra * fracao, altura), dados.cor_projetil)
