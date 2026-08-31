class_name Direcoes
extends RefCounted
## O mapa de "para onde ele olha" -> "qual dos oito quadros desenhar".
##
## Isolada aqui pelo mesmo motivo da Balistica: e a peca mais facil de errar e a
## que menos avisa quando quebra. Trocar dois indices de lugar faz o sprite
## encarar o lado errado -- gritante em tela, invisivel no console -- e e a
## unica parte de um sprite direcional que da para conferir sem subir cena.
##
## Ela nasceu dentro de `DadosPersonagem`, e saiu de la quando o Drone Aranha
## ganhou arte: duas copias do mesmo mapa acabariam divergindo, e o sintoma
## seria o inimigo e a personagem lendo o mesmo angulo de jeitos diferentes.


## Quantos quadros tem uma volta completa.
const TOTAL := 8

## Lado da moldura em que todo sprite de ator e normalizado, e onde os PES
## caem dentro dela. Espelham `tools/sprites/gerar_sprites.py` (LADO 80,
## FOLGA_PE 4): os pes ficam na linha 76, e num Sprite2D centrado isso e
## 76 - 40 = 36 px abaixo da origem do no.
##
## Moram aqui pelo mesmo motivo que o mapa de angulo mora: personagem e inimigo
## passam pelo MESMO gerador, e duas copias deste numero divergiriam com o
## sintoma aparecendo em tela e nao no console.
const LADO_QUADRO := 80.0
## Folga entre o pe e o fundo da moldura, espelhando `FOLGA_PE` do gerador.
const FOLGA_PE := 4.0
const BASE_NO_QUADRO := 36.0

## As molduras que o gerador produz, e portanto as unicas em que os pes caem no
## lugar previsto.
##
## 80 cobre personagem e inimigo comum. 160 existe para o CHEFE: o Automato e
## duas a tres vezes o tamanho do jogador e nao cabe em 80, e enfiar arte de
## chefe numa moldura pequena demais foi como a Diretora acabou fora da ancora.
##
## Sao multiplos um do outro de proposito: 160 e exatamente 2x 80, entao a
## proporcao entre o chefe e o jogador e a mesma em pixels e em moldura, e a
## escala continua INTEIRA -- 64 para 96 borra mesmo com filtro Nearest.
const MOLDURAS_DE_ATOR: Array[float] = [80.0, 160.0]


## Onde os pes caem numa moldura de lado `lado`, contado da ORIGEM do Sprite2D.
##
## Um `Sprite2D` e centrado, entao a linha do pe (`lado - FOLGA_PE`) vira
## `lado/2 - FOLGA_PE` abaixo do centro. Com 80 isso da os 36 de sempre.
##
## Existe como funcao e nao como segunda constante porque o chefe trouxe uma
## moldura nova: com duas constantes soltas, a proxima moldura entraria com o
## numero calculado a mao -- e um erro de 4 px na ancora e exatamente o tipo de
## coisa que so aparece quando dois corpos se cruzam em movimento.
static func base_de_quadro(lado: float) -> float:
	return lado * 0.5 - FOLGA_PE


## A moldura e uma das que o gerador produz?
##
## Quem responde `false` e arte AUTORADA, de ancora propria -- o caso vivo e a
## Diretora, um orbe de 192x192 sem pes. O portao de origem trata os dois
## regimes de forma diferente, e precisa saber qual e qual.
static func moldura_de_ator(lado: float) -> bool:
	for m in MOLDURAS_DE_ATOR:
		if is_equal_approx(lado, m):
			return true
	return false

## Onde o sprite tem de ficar para os PES coincidirem com a origem do ator.
##
## E a regra de origem do Low Top-Down (LOW_TOPDOWN_SQUARED secao 6): a posicao
## logica do ator e o ponto em que ele encosta no chao, e o desenho sobe a
## partir dali. Antes cada ator tinha um deslocamento proprio, ajustado a olho,
## e o efeito colateral era o Y-sort ordenar pelo MEIO do corpo -- um inimigo
## alto passava na frente de outro mais abaixo na tela.
const DESLOCAMENTO_PARA_BASE := Vector2(0.0, -BASE_NO_QUADRO)


## O indice do quadro que encara `direcao`, na ordem canonica:
##
##   0 leste  1 sudeste  2 sul  3 sudoeste  4 oeste  5 noroeste  6 norte  7 nordeste
##
## A ordem nao e arbitraria: e a que sai de `round(angulo / (PI/4))` com o
## angulo de `Vector2.angle()`, em que +y aponta para BAIXO. Quem gera os
## arquivos (tools/sprites/gerar_sprites.py) usa esta mesma ordem em `DIRECOES`,
## e as duas precisam continuar iguais.
static func indice(direcao: Vector2) -> int:
	# Sul: e para onde se olha quando nao ha para onde olhar.
	if direcao.length_squared() < 0.0001:
		return 2
	var passo := TAU / float(TOTAL)
	var i := int(roundi(direcao.angle() / passo)) % TOTAL
	# GDScript herda o modulo de C: -1 % 8 da -1, nao 7. Angulos negativos sao
	# metade do circulo (todo o hemisferio norte), entao sem esta linha o sprite
	# so olharia para baixo.
	if i < 0:
		i += TOTAL
	return i
