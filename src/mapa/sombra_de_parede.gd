class_name SombraDeParede
extends RefCounted
## A sombra que a parede projeta NO CHAO, para dentro da sala.
##
## E a quinta banda da referencia (`docs/objetivo/isaac.png`), e a ultima que
## faltava depois da TOPO 01. Medido la, no perfil de 1 px: a face encontra o
## chao com uma linha de contato de 3 px a 0,85x o valor do chao, e do lado
## oposto o chao desce numa rampa de 8 px ate 0,56x antes de virar parede.
##
## No psicode nao havia nenhuma das duas. A face encostava no chao seco -- V 0,33
## na ultima linha dela, V 0,10 na primeira do chao --, e uma parede com 64 px de
## presenca visual nao projetava nada. **E a sombra projetada e o que vende
## altura, mais que o valor do topo**: e ela que diz que aquela superficie esta
## ACIMA do chao, e nao pintada nele.
##
## **Ela NAO e filha da fita, e isso nao e organizacao.** Ela cai DENTRO do
## contorno de proposito, e e justamente essa a invariante que autoriza a fita a
## desenhar acima do chao -- `teste_renderizador_paredes.gd` exige que nenhuma
## peca da fita caia na area jogavel. Pendurar a sombra la obrigaria aquele
## portao a ganhar uma excecao, e invariante com excecao nao e invariante, e
## comentario. A faixa de `z` tambem e outra, e filho herda faixa por
## `z_as_relative` -- a armadilha que o `Telegrafo` ja registra.
##
## **A profundidade nao e simetrica, e a assimetria e a luz.** O
## `LOW_TOPDOWN_SQUARED.md` §18 crava luz de cima e da esquerda, com sombra para
## baixo e para a direita. Entao a parede NORTE projeta para dentro da sala e a
## OESTE tambem; a LESTE e a SUL projetam para FORA, e do lado de dentro sobra so
## a linha de contato. Uma sombra igual nos quatro lados leria como vinheta, que
## e efeito de camera, e nao como sombra, que e afirmacao sobre altura.
##
## **O que ela nao pode fazer e disputar a leitura de combate**, e isso virou
## numero e nao intencao: `teste_camada_visual.gd` cobra que ela nao passe de
## `PROFUNDIDADE_MAXIMA`, que o alfa nao passe de `ALFA_MAXIMO`, e que a area
## dela fique abaixo de 6% do chao. Ela so ESCURECE, entao G2 -- nada de ambiente
## com S > 0,35 e V > 0,55 -- nao e tocado por construcao.

## A cor da sombra, ESPELHADA de `Paleta.neutro("N0")`.
##
## Espelhada e nao lida pela mesma razao do `RenderizadorParedes`: `tools/` esta
## em `exclude_filter` do export e a `Paleta` nao existe na build. Mesmo hex de
## `Sombra.COR`, e pelo mesmo argumento que aquele arquivo ja escreve -- nenhum
## projetil, telegrafo ou pickup e uma mancha escura, entao escurecer nunca
## compete com o que o jogador precisa ler.
const COR := Color("05060b")

## Ate onde a sombra entra na sala, por lado.
##
## Os numeros saem da referencia medida: 3 px de contato e 8 px de rampa. Aqui
## eles sao 4 e 12 porque a faixa do psicode tem 64 px de profundidade contra os
## ~50 do Isaac, e porque 4 e submultiplo da celula de 32 -- um numero que nao
## cai na grade reaparece como meia coluna de sombra na ponta de um lado.
const PROFUNDIDADE_NORTE := 12.0
const PROFUNDIDADE_OESTE := 8.0
const PROFUNDIDADE_CONTATO := 4.0

## O teto, e ele existe para o portao ter o que cobrar.
const PROFUNDIDADE_MAXIMA := 16.0
const ALFA_MAXIMO := 0.40

## O degrau perto da parede e o longe dela.
##
## Dois degraus e nao um gradiente: gradiente em `Polygon2D` exigiria textura ou
## `vertex_colors`, e a referencia tambem nao tem gradiente -- ela tem uma linha
## de contato e um segundo tom mais fraco. Dois retangulos dizem a mesma coisa
## com duas pecas.
const ALFA_PERTO := 0.34
const ALFA_LONGE := 0.17

## A fracao da profundidade que o degrau de perto ocupa.
const FRACAO_PERTO := 0.66


## A sombra inteira: um no pronto para a sala ou o corredor pendurar.
##
## `trechos` chega ja CORTADO nos vaos de porta, e chega de fora de proposito:
## quem sabe onde ha porta e a `Sala`, e ela ja calcula isso para a colisao em
## `_subtrechos()`. Recalcular aqui seria uma segunda resposta para "onde ha
## parede" -- exatamente a divergencia que a PAR 01 pagou quando o visual e a
## colisao discordaram sobre o vao.
static func construir(trechos: Array[PackedVector2Array],
		contorno: PackedVector2Array) -> Node2D:
	var raiz := Node2D.new()
	raiz.name = "SombraDaParede"
	raiz.z_index = Sala.Z_SOMBRA_PAREDE
	if contorno.size() < 3:
		return raiz
	for trecho in trechos:
		if trecho.size() < 2:
			continue
		var a := trecho[0]
		var b := trecho[1]
		var fora := RenderizadorParedes.normal_externa(contorno, a, b)
		if fora == Vector2.ZERO:
			continue
		# O CHANFRO DE QUINA nao projeta sombra propria.
		#
		# Ele e a transicao entre dois lados, e as sombras dos dois ja se
		# encontram ali -- uma terceira banda na diagonal soma por cima das duas.
		# Medido na sala em L, que tem seis quinas: a sombra saltou de 8% do chao
		# para 12,8%, e o teto existe porque sombra e o que come area de combate.
		if RenderizadorParedes._e_chanfro(fora):
			continue
		var dentro := -fora
		var fundo := _profundidade(RenderizadorParedes.classificar(fora))
		var perto := fundo * FRACAO_PERTO
		_banda(raiz, a, b, dentro, 0.0, perto, ALFA_PERTO)
		_banda(raiz, a, b, dentro, perto, fundo, ALFA_LONGE)
	return raiz


## Quanto este lado projeta para dentro.
static func _profundidade(lado: RenderizadorParedes.Lado) -> float:
	match lado:
		RenderizadorParedes.Lado.NORTE:
			return PROFUNDIDADE_NORTE
		RenderizadorParedes.Lado.OESTE:
			return PROFUNDIDADE_OESTE
		_:
			# LESTE e SUL projetam para FORA da sala: do lado de dentro sobra a
			# linha de contato, que e o que a referencia mostra no norte dela.
			return PROFUNDIDADE_CONTATO


## Uma tira retangular ao longo de um trecho, entrando na sala.
##
## `position` no meio e o poligono RELATIVO a ela, pelo mesmo motivo do
## `RenderizadorParedes._banda()`: os portoes leem `position` mais a caixa local.
static func _banda(raiz: Node2D, de: Vector2, ate: Vector2, dentro: Vector2,
		inicio: float, fim: float, alfa: float) -> void:
	if fim - inicio < 0.5 or de.distance_to(ate) < 0.5:
		return
	var centro := (de + ate) * 0.5 + dentro * ((inicio + fim) * 0.5)
	var poly := Polygon2D.new()
	poly.color = Color(COR.r, COR.g, COR.b, alfa)
	poly.position = centro
	poly.polygon = PackedVector2Array([
		de + dentro * inicio - centro,
		ate + dentro * inicio - centro,
		ate + dentro * fim - centro,
		de + dentro * fim - centro,
	])
	raiz.add_child(poly)
