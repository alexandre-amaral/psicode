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


## Se este personagem hackeia. Existe para quem le nao precisar saber que o
## desligamento e "chance zero" -- se um dia o criterio mudar, muda so aqui.
func tem_hack() -> bool:
	return hack_chance > 0.0
