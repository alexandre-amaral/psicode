class_name Sombra
extends Polygon2D
## Elipse escura sob um ator, no ponto em que ele encosta no chao.
##
## Decisao de design que este no carrega: **a sombra e informacao, nao enfeite.**
## Ela responde a unica pergunta que a perspectiva Low Top-Down cria e nao
## resolve sozinha -- "onde esta a base disto?". Sem ela, um corpo desenhado em
## 3/4 sobre um chao com volume fica ambiguo entre "de pe aqui" e "flutuando
## sobre ali", e o jogador so descobre quando toma dano de contato.
##
## Ela tambem herda um papel que ficou vago. O `docs/IDENTIDADE_VISUAL.md`
## descrevia uma `Visual/Aura` ciano sob os pes do jogador e a chamava de
## "ancora de leitura" -- o que impedia a personagem, que e pixel art escura e
## dessaturada, de competir em valor com o chao texturizado. Esse no NAO existe
## mais em `player.tscn`: saiu junto com o cano quando a mira virou reticulo, e
## nada assumiu o lugar. A sombra assume, e com uma vantagem: ela nao usa cor de
## ATOR. A aura era ciano brilhante -- a mesma familia de seis projeteis do
## jogo -- colada justamente em quem o jogador precisa distinguir de um tiro.
##
## Por isso a cor e N0, o vazio da paleta AMBIENTE, com alpha. Escurecer o chao
## nao pode ser confundido com nada: nenhum projetil, telegrafo ou pickup e uma
## mancha escura.

## O neutro mais escuro da paleta (docs/IDENTIDADE_VISUAL.md). Nao ha risco de
## competir com ator: G2 barra o que e saturado E claro, e isto nao e nenhum.
const COR := Color("05060b")
## Opacidade. Alta o bastante para achar o ator num chao de luminancia 26-29,
## baixa o bastante para o chao continuar legivel por baixo -- a sombra nao
## pode virar um buraco.
const ALPHA := 0.38
## Quantos lados a elipse tem. Doze le como redondo no pixel e custa doze
## vertices; circulo de verdade seria um poligono de 32 para o mesmo resultado.
const LADOS := 12
## Achatamento vertical. A sombra e um circulo no CHAO visto pela camera
## inclinada, entao ela chega ao olho como elipse -- e o mesmo encurtamento que
## faz o topo da parede parecer mais fino que a espessura dela.
const ACHATAMENTO := 0.42
## Um degrau abaixo do corpo, dentro do proprio ator. Relativo e nao absoluto:
## o ator vive na faixa Z_MUNDO e se ordena por Y, e a sombra tem de viajar
## junto com ele nessa ordenacao em vez de disputar faixa propria.
const Z := -1


## Onde um ator com sprite direcional encosta no chao, em coordenadas locais.
## Perguntar ao sprite em vez de tabelar por ator: cada um tem um deslocamento
## proprio, ajustado a mao, e tabelar seria uma segunda fonte para o mesmo dado.
static func base_de(corpo: Node2D) -> float:
	if corpo == null:
		return 0.0
	# So sprite tem a moldura de 80. O corpo geometrico (quatro inimigos ainda
	# sao Polygon2D) e desenhado em volta da propria origem, entao a base dele
	# JA e a origem -- somar 36 poria a sombra 36 px abaixo dos pes dele.
	if not (corpo is Sprite2D):
		return corpo.position.y
	return corpo.position.y + Direcoes.BASE_NO_QUADRO


## Cria a sombra de um ator de `largura` px, ja posicionada na base dele.
##
## `base_y` e a distancia, em pixels locais, entre a origem do ator e o ponto
## em que ele encosta no chao. Nao e adivinhada: quem chama sabe onde o sprite
## foi ancorado, e passar o numero e mais honesto que deduzir do bbox -- o bbox
## de um inimigo que flutua nao diz onde ele projeta sombra.
static func criar(largura: float, base_y: float) -> Sombra:
	var sombra := Sombra.new()
	sombra.name = "Sombra"
	sombra.color = Color(COR.r, COR.g, COR.b, ALPHA)
	sombra.z_index = Z
	sombra.position = Vector2(0.0, base_y)
	sombra.polygon = _elipse(largura * 0.5, largura * 0.5 * ACHATAMENTO)
	return sombra


static func _elipse(raio_x: float, raio_y: float) -> PackedVector2Array:
	var pontos := PackedVector2Array()
	for i in LADOS:
		var angulo := TAU * float(i) / float(LADOS)
		pontos.append(Vector2(cos(angulo) * raio_x, sin(angulo) * raio_y))
	return pontos
