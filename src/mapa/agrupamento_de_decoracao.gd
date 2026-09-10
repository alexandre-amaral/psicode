class_name AgrupamentoDeDecoracao
extends Resource
## Um CLUSTER de decoracao: o tanque COM o tubo, a valvula, os dois barris e a
## mancha de oleo debaixo deles.
##
## ## A decisao de design: a unidade de decoracao deixa de ser o prop
##
## Ate aqui a sala espalhava props soltos por regioes declaradas no
## `tipo_*.tres`, um sorteio independente por peca. Isso produz densidade, mas
## nao produz LEITURA: doze objetos sorteados um a um contam doze historias de
## uma peca cada, e o olho le isso como ruido uniforme -- exatamente o que uma
## fabrica abandonada nao parece.
##
## Uma fabrica de verdade tem CONJUNTOS. O tanque nao esta sozinho: dele sai um
## tubo, o tubo tem valvula, embaixo ha barris e o oleo que vazou. O briefing
## chama isso de agrupamento, e a mudanca e de unidade -- o decorador coloca
## CLUSTERS, e nao props. Um cluster tem forma propria e entra na sala como uma
## peca so: ou cabe inteiro, ou nao entra.
##
## ## Por que as pecas sao DUAS listas paralelas, e nao uma lista de recursos
##
## O modelo obvio seria um `PecaDeDecoracao` proprio -- um Resource por peca,
## com `porte` e `deslocamento`. Ele custa um quinto arquivo e um `.tres`
## aninhado por barril, e o Inspetor passa a exigir tres cliques para mover um
## barril 8 px. Para um par de campos sem comportamento nenhum, isso e cerimonia.
##
## O preco das listas paralelas e conhecido e esta pago aqui: **duas listas
## podem divergir**, e o Inspetor cria buraco toda vez que alguem cresce um
## array. Por isso a divergencia nao e tolerada nem truncada em silencio --
## `valido()` recusa o agrupamento INTEIRO, e `DecoradorDeSala` simplesmente nao
## o coloca. Truncar pelo menor produziria um cluster com o tanque e sem o tubo,
## que le como bug de arte e nao tem uma linha no console para explicar.
##
## ## A moldura dos deslocamentos e a do lado NORTE
##
## `deslocamentos` sao relativos a ANCORA do cluster, na moldura do lado norte:
## **+x corre ao longo da parede, +y entra na sala**. Quem gira isso para o lado
## sorteado e o decorador. Declarar em coordenada de mundo faria um cluster
## desenhado para o norte entrar sala adentro quando caisse no leste -- e a sala
## e vista de cima, entao o mesmo conjunto tem de servir aos quatro lados.

## Nome do conjunto, e a chave da MEMORIA RECENTE: e ele que o decorador compara
## com a lista `recentes` das ultimas salas para reduzir o peso deste cluster.
## Dois agrupamentos com o mesmo nome se anulam nessa conta, entao ele e
## identidade e nao rotulo.
@export var nome: StringName = &""

## O PORTE de cada peca, como ordinal de `DecoradorDeSala.Porte`
## (0 HERO, 1 GRANDE, 2 MEDIO, 3 PEQUENO, 4 MICRO).
##
## E `int` e nao o enum porque o enum mora em `DecoradorDeSala`, que ja depende
## deste recurso: importar o enum de volta fecharia um ciclo entre dois
## `class_name`, e ciclo em GDScript nao da erro de logica, da erro de PARSE no
## import -- o projeto inteiro abre vermelho. A ponta solta e cobrada em
## `teste_decoracao.gd`, que enxerga os dois lados e cruza um com o outro.
@export var portes: PackedInt32Array = PackedInt32Array()

## Onde cada peca fica em relacao a ancora, na moldura do lado norte descrita
## acima. Pareado com `portes` por INDICE.
##
## Deslocamento pequeno de proposito: um cluster e um conjunto, nao uma parede
## decorada. Se as pecas se espalham por 300 px, o jogador nao le um conjunto,
## le props soltos -- que e o estado anterior a esta issue.
@export var deslocamentos: PackedVector2Array = PackedVector2Array()


## As duas listas tem de andar juntas, e um agrupamento vazio nao e agrupamento.
##
## Quem chama nao trunca: recusa. Ver o bloco de decisao no topo.
func valido() -> bool:
	if portes.is_empty():
		return false
	return portes.size() == deslocamentos.size()


func contagem_de_pecas() -> int:
	if not valido():
		return 0
	return portes.size()


func porte_da_peca(indice: int) -> int:
	return portes[indice]


func deslocamento_da_peca(indice: int) -> Vector2:
	return deslocamentos[indice]
