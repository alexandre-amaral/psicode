class_name AbaDeStatus
extends Control
## A aba STATUS: o que os aprimoramentos fizeram, em numero.
##
## **Os numeros sao DERIVADOS, nunca calculados de novo.** Cada linha pergunta
## ao sistema que de fato manda naquilo -- `Modificadores` para os
## multiplicadores, o proprio Player para a vida --, e nao ha uma segunda conta
## aqui. Uma UI que recalculasse o efeito dos implantes viraria a segunda fonte
## de verdade sobre a build, e ela divergiria na primeira vez que alguem
## mexesse num `EfeitoItem`: o painel diria +12% e o tiro entregaria +10%, sem
## erro nenhum no console.
##
## E ela mostra o MULTIPLICADOR e nao o valor final. "x1,15" responde "o que os
## meus implantes fizeram", que e a pergunta que se faz olhando o inventario;
## "379 px/s" responde uma que ninguem faz.
##
## **A aba separada existe porque a pergunta e outra.** ITENS responde "o que eu
## instalei" e STATUS responde "e no que isso deu" -- e a segunda so faz sentido
## depois da primeira. Empilhadas na mesma tela elas competiam pela mesma
## coluna, e a mais importante (a lista) perdia espaco para a derivada.

## (vida atual, vida maxima). Injetada por quem monta a tela. `ZERO` = nao ha
## Player, e a linha de integridade some em vez de mostrar `0 / 0`.
var vida: Vector2i = Vector2i.ZERO

const COR_TITULO := Color(0.42, 0.90, 1.00, 0.85)
const COR_ROTULO := Color(0.55, 0.70, 0.80)
const COR_TRILHO := Color(0.16, 0.19, 0.26)
const COR_NEUTRO := Color(0.62, 0.70, 0.80)
const COR_BOA := Color(0.49, 0.97, 0.77)
const COR_RUIM := Color(0.96, 0.52, 0.52)

const TAMANHO_TITULO := 10
const TAMANHO_ROTULO := 10

## Largura da coluna de valores. A tabela e desenhada como duas colunas
## alinhadas -- rotulo a esquerda, numero a direita -- porque a pergunta que se
## faz aqui e comparativa: "o que subiu e o que desceu" se le varrendo a coluna
## de numeros, e nao lendo linha por linha.
const COLUNA_VALOR := 110.0
## Teto da largura da tabela. Esticada pela aba inteira (904 px), cada linha
## vira um rotulo numa ponta e um numero na outra, com meio quadro de vazio no
## meio -- e ler a tabela passa a exigir atravessar a tela oito vezes.
const LARGURA_MAXIMA := 420.0


func _draw() -> void:
	var fonte := ThemeDB.fallback_font

	draw_string(fonte, Vector2(0.0, 10.0), tr("DIAGNÓSTICO"),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_TITULO, COR_TITULO)
	var largura := minf(size.x, LARGURA_MAXIMA)
	draw_line(Vector2(0.0, 16.0), Vector2(largura, 16.0), COR_TRILHO, 1.0)

	var y := 36.0
	for linha in linhas_de_diagnostico(vida):
		draw_string(fonte, Vector2(0.0, y), tr(str(linha[0])),
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_ROTULO, COR_ROTULO)
		# **`pos.x` e a borda ESQUERDA da faixa de alinhamento, nunca a direita.**
		# `draw_string` com `HORIZONTAL_ALIGNMENT_RIGHT` alinha dentro de
		# [pos.x, pos.x + width]; passando a borda direita como pos.x, a coluna
		# inteira de valores era desenhada para FORA do painel e a aba aparecia
		# so com os rotulos. Nao ha erro: ha uma tabela pela metade que parece
		# proposital.
		draw_string(fonte, Vector2(largura - COLUNA_VALOR, y), str(linha[1]),
			HORIZONTAL_ALIGNMENT_RIGHT, COLUNA_VALOR, TAMANHO_ROTULO, linha[2] as Color)
		y += 18.0


## As linhas do diagnostico: [rotulo, valor formatado, cor].
##
## `static` para o portao poder afirmar "toda linha sai de `Modificadores`" sem
## desenhar nada -- e para a suite nao precisar fixar o idioma, ja que o rotulo
## devolvido e a CHAVE em portugues e a traducao acontece no `_draw`.
static func linhas_de_diagnostico(vida_atual: Vector2i) -> Array:
	var linhas: Array = []
	if vida_atual.y > 0:
		linhas.append(["INTEGRIDADE", "%d / %d" % [vida_atual.x, vida_atual.y], COR_NEUTRO])
	linhas.append(_linha_soma("DANO (SOMA)", Modificadores.bonus_dano()))
	linhas.append(_linha_fator("DANO (FATOR)", Modificadores.multiplicador_dano()))
	linhas.append(_linha_fator("CADÊNCIA", Modificadores.multiplicador_cadencia()))
	linhas.append(_linha_fator("MOVIMENTO", Modificadores.multiplicador_velocidade()))
	# Cooldown INVERTE: menor e melhor. Pintar de verde o que subiu daria a este
	# um sinal trocado -- e o painel diria "melhorou" no exato campo em que o
	# implante piorou.
	linhas.append(_linha_fator("ROLAMENTO", Modificadores.multiplicador_cooldown_rolamento(), true))
	linhas.append(_linha_fator("DETERIORAÇÃO", Modificadores.multiplicador_ganho_deterioracao(), true))
	var ricochete := Modificadores.chance_ricochete()
	if ricochete > 0.0:
		linhas.append(["RICOCHETE", "%d%%" % roundi(ricochete * 100.0), COR_BOA])
	var fragmentacao := Modificadores.chance_fragmentacao()
	if fragmentacao > 0.0:
		linhas.append(["FRAGMENTAÇÃO", "%d%%" % roundi(fragmentacao * 100.0), COR_BOA])
	return linhas


static func _linha_soma(rotulo: String, valor: int) -> Array:
	if valor == 0:
		return [rotulo, "--", COR_NEUTRO]
	return [rotulo, "%+d" % valor, COR_BOA if valor > 0 else COR_RUIM]


static func _linha_fator(rotulo: String, fator: float, menor_e_melhor: bool = false) -> Array:
	if is_equal_approx(fator, 1.0):
		return [rotulo, "--", COR_NEUTRO]
	var melhorou := fator < 1.0 if menor_e_melhor else fator > 1.0
	return [rotulo, "x%.2f" % fator, COR_BOA if melhorou else COR_RUIM]
