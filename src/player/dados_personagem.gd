class_name DadosPersonagem
extends Resource
## Quem o jogador escolhe antes da run: a arma com que comeca e o que so ele
## sabe fazer.
##
## A decisao de design daqui: personagem e DADO, nao subclasse de Player. Nao ha
## player_raven.gd nem player_nova.gd -- ha um Player que le este recurso no
## _ready. Personagem novo custa um .tres e uma linha na lista da tela de
## selecao; nao custa cena nova, nem heranca, nem um `match` que cresce a cada
## adicao.
##
## O Hack mora aqui e nao em DadosArma porque ele acompanha a PESSOA: NOVA
## continua hackeando depois de trocar a Cipher por uma shotgun na sala de arma.
## Se fosse da arma, escolher personagem deixaria de importar no minuto em que o
## jogador pegasse o primeiro loot -- e a escolha e o ponto.
##
## Os cinco numeros do Hack ficam soltos aqui em vez de virarem um
## DadosItem/Comportamento porque aquele carrega UM `parametro` float, e forcar
## cinco numeros por um buraco de um so significaria esconder quatro deles como
## const em GDScript. Numero que alguem vai querer girar sem programar fica no
## Inspetor.

## Chave curta e estavel. StringName porque vira chave de comparacao (a tela de
## selecao e os testes comparam por id, nao por nome exibido).
@export var id: StringName = &"personagem"

@export_group("Apresentacao")
@export var nome: String = "Personagem"
## A linha abaixo do nome na tela de selecao. Ex.: "Operadora de Combate".
@export var papel: String = ""
## O texto do card. Uma linha por comportamento, comecando com "- ": a tela
## imprime literal, entao a formatacao mora no dado e nao na cena.
@export_multiline var descricao: String = ""
## Cor do card e do marcador na tela de selecao.
@export var cor: Color = Color("6ee7ff")
## O retrato do card. Costuma ser o frame `south` (a personagem de frente), mas
## e um campo proprio e nao `sprites_direcao[2]` para um dia caber um retrato
## desenhado sem mexer no conjunto de rotacoes.
@export var miniatura: Texture2D

@export_group("Sprite")
## As oito rotacoes, NESTA ORDEM:
##
##   0 leste  1 sudeste  2 sul  3 sudoeste  4 oeste  5 noroeste  6 norte  7 nordeste
##
## A ordem nao e arbitraria: e a que sai de `round(angulo / (PI/4))` com o
## angulo de `Vector2.angle()`, em que +y aponta para BAIXO. Trocar dois indices
## de lugar faz a personagem encarar o lado errado -- muito visivel em tela e
## nada diagnosticavel no console, entao `teste_personagem.gd` confere os oito.
@export var sprites_direcao: Array[Texture2D] = []
## Multiplicador do sprite. INTEIRO, sempre: pixel art em escala fracionaria
## borra mesmo com filtro Nearest, porque um pixel da arte deixa de cair num
## numero redondo de pixels de tela.
@export var escala_sprite: float = 1.0
## Sobe o sprite em relacao ao centro de colisao. A arte e de corpo inteiro em
## vista 3/4 e a colisao e um circulo de raio 11 na origem; sem deslocar, a
## personagem parece flutuar com os pes muito abaixo de onde ela de fato esbarra.
@export var deslocamento_sprite: Vector2 = Vector2(0, -20)

@export_group("Combate")
## A arma do slot 0. Nunca sai do jogador, entao precisa de reserva infinita
## (municao_maxima = -1), como manda o GDD sobre a arma inicial.
@export var arma_inicial: DadosArma

@export_group("Hack")
## Chance (0..1) de um TIRO hackear quem ele acertar. Zero desliga o Hack
## inteiro, e e assim que um personagem sem Hack se declara.
@export var hack_chance: float = 0.0
## Por quantos segundos o alvo fica marcado.
@export var hack_duracao: float = 4.0
## Multiplicador de dano recebido enquanto marcado. 1.25 = +25%.
@export var hack_bonus_dano: float = 1.25
## Chance (0..1) de o Hack pular para um vizinho quando o marcado morre.
@export var hack_chance_propagacao: float = 0.5
## Ate que distancia o Hack procura esse vizinho, em pixels.
@export var hack_raio_propagacao: float = 220.0


## Quantas direcoes o conjunto de sprites tem.
const DIRECOES := 8


## O frame que encara `direcao`.
##
## Funcao pura de proposito: e a unica peca desta feature que da para conferir
## sem subir cena, e e justamente a que erra calado.
func textura_para(direcao: Vector2) -> Texture2D:
	if sprites_direcao.size() < DIRECOES:
		return null
	if direcao.length_squared() < 0.0001:
		return sprites_direcao[2]
	var passo := TAU / float(DIRECOES)
	var indice := int(roundi(direcao.angle() / passo)) % DIRECOES
	# GDScript herda o modulo de C: -1 % 8 da -1, nao 7. Angulos negativos sao
	# metade do circulo (todo o hemisferio norte), entao sem esta linha a
	# personagem so olharia para baixo.
	if indice < 0:
		indice += DIRECOES
	return sprites_direcao[indice]


## Se este personagem hackeia. Existe para quem le nao precisar saber que o
## desligamento e "chance zero" -- se um dia o criterio mudar, muda so aqui.
func tem_hack() -> bool:
	return hack_chance > 0.0
