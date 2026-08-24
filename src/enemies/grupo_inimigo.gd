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


## Custo utilizavel. Protege de um zero digitado no Inspetor, que faria o
## sorteio de composicao nunca gastar o orcamento e girar para sempre.
func custo_real() -> int:
	return maxi(custo, 1)


func valido() -> bool:
	return cena != null and peso > 0.0
