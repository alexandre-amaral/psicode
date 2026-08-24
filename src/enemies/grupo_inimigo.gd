class_name GrupoInimigo
extends Resource
## Um tipo de inimigo que pode aparecer numa sala, com o quanto ele "pesa".
##
## Existe para que acrescentar um inimigo ao jogo NAO custe codigo. Antes a
## composicao de uma sala eram dois inteiros fixos no DadosOnda (`rastejantes` e
## `vigias`) e dois `preload` no gerenciador de ondas -- um terceiro tipo exigia
## mexer nos dois lugares. Aqui e um .tres arrastado para a lista do tipo de
## sala.
##
## Para criar: clique direito em src/enemies > Novo Recurso > GrupoInimigo,
## salve como grupo_<nome>.tres, aponte a cena, e ajuste peso e custo.

@export var cena: PackedScene

## Chance relativa no sorteio. Dois grupos de peso 1 aparecem meio a meio; um de
## peso 3 contra um de peso 1 aparece tres vezes mais.
@export var peso: float = 1.0

## Quanto este inimigo consome do orcamento da sala.
##
## E aqui que "sala mais dificil" se escreve sem mexer em quantidade: um Vigia
## de custo 2 ocupa o dobro de um Rastejante, entao a mesma sala cabe menos
## deles -- menos corpos, mais perigo por corpo.
@export var custo: int = 1


## A partir de que Deterioracao ESTIMADA este inimigo entra no sorteio.
##
## Serve para o andar apresentar os tipos aos poucos, em vez de a primeira sala
## poder sortear quatro Cyber-Bestas. Zero = disponivel desde o inicio.
##
## **A estimativa, e por que ela e uma estimativa.** A composicao de todas as
## salas e sorteada de uma vez, na montagem do andar, quando a barra ainda
## marca zero -- comparar com `Deterioracao.valor` naquele instante barraria
## TODO grupo com porta acima de zero, para sempre e em silencio. Entao o
## gerador compara com a Deterioracao que aquela celula deve ter quando o
## jogador chegar nela:
##
##     distancia da origem em salas x deterioracao_ao_limpar do tipo
##
## A conta ignora o ganho passivo, entao ela subestima -- a porta abre um pouco
## mais tarde do que na partida real. Erra para o lado seguro de proposito.
@export var deterioracao_minima: float = 0.0


## Este inimigo pode nascer numa celula com esta Deterioracao estimada?
func liberado_em(deterioracao_estimada: float) -> bool:
	return deterioracao_estimada >= deterioracao_minima


## Custo utilizavel. Protege de um zero digitado no Inspetor, que faria o
## sorteio de composicao nunca gastar o orcamento e girar para sempre.
func custo_real() -> int:
	return maxi(custo, 1)


func valido() -> bool:
	return cena != null and peso > 0.0
