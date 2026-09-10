class_name PerfilDeDecoracao
extends Resource
## QUANTA decoracao uma sala recebe, ONDE ela pode cair e COMO ela se agrupa.
##
## Ele e o botao de densidade do andar, e existe porque o briefing da fabrica
## pede muito mais materia em tela do que a sala espalha hoje -- mas pede isso
## CONCENTRADO no perimetro, com o miolo livre. Densidade sem essa segunda
## metade nao e ambientacao, e obstaculo mentiroso no meio do combate.
##
## ## As tres regras que este recurso existe para tornar ajustaveis
##
## 1. **A FAIXA.** Toda decoracao vive entre o contorno e
##    `largura_da_faixa_de_perimetro` para dentro. E a mesma ideia que ja
##    protege o Foreground em `DadosSala`: manter a decoracao fora da area util
##    transforma "nao atrapalha o combate" de revisao de olho em comparacao de
##    numeros que uma suite faz.
## 2. **A ZONA LIVRE.** Nada dentro de `raio_da_zona_livre` do centro. A faixa
##    sozinha ja daria isso numa sala grande; numa sala pequena, "perto da
##    parede" e "no meio da sala" sao o mesmo lugar, e e la que a zona livre
##    morde.
## 3. **OS PESOS POR LADO.** A sala e vista de cima com a face desenhada so no
##    norte, entao o norte e o unico lado onde a decoracao encosta em superficie
##    VERTICAL -- e onde ela rende mais. O sul e o lado por onde o jogador
##    entra e onde a camera corta primeiro: peca grande ali vira coisa que
##    aparece pela metade.
##
## ## Por que os contadores sao campos NOMEADOS e nao um dicionario por porte
##
## Um `Dictionary[Porte, Vector2i]` seria mais curto e nao apareceria no
## Inspetor de um jeito que alguem sem GDScript consiga girar -- e girar sem
## programar e o requisito. Alem disso, o enum `Porte` mora em
## `DecoradorDeSala`, que ja consome este recurso; le-lo aqui fecharia um ciclo
## entre dois `class_name` e o projeto abriria vermelho no import. Quem traduz
## porte -> campo e o decorador, num `match` unico, e `teste_decoracao.gd` cobra
## que os cinco portes cheguem aos cinco campos certos.

@export_group("Quantidade por porte")
## HERO: a peca de leitura da sala -- a prensa, o forno, o tanque grande. Uma,
## as vezes nenhuma. Duas heroinas na mesma sala e duas salas brigando.
@export var contagem_hero: Vector2i = Vector2i(1, 1)
## GRANDE: maquinario, armario alto, tanque medio. O corpo da decoracao.
@export var contagem_grande: Vector2i = Vector2i(2, 4)
## MEDIO: barril, caixote grande, painel, motor solto.
@export var contagem_medio: Vector2i = Vector2i(3, 6)
## PEQUENO: caixa, balde, ferramenta, entulho.
@export var contagem_pequeno: Vector2i = Vector2i(4, 8)
## MICRO (o porte `MICRO` do decorador): decalque, mancha, marca de arraste.
##
## O nome do campo e `decalque` porque e assim que o briefing chama, e o porte e
## `MICRO` porque e assim que o decorador ordena as pecas por tamanho. Os dois
## nomes falam da mesma coisa e a traducao esta no `match` do decorador -- se um
## dia surgir um MICRO que nao seja decalque, e este comentario que sai, nao o
## campo.
@export var contagem_decalque: Vector2i = Vector2i(2, 5)

## Quantos objetos MINUSCULOS (ferramenta, parafuso, sucata) a sala recebe.
##
## Separado de `contagem_decalque` porque eles deixaram de ser a mesma coisa:
## micro e VOLUME e mora na faixa de perimetro; decalque e chao pintado e mora
## em qualquer lugar. Enquanto os dois compartilhavam este campo, era preciso
## escolher entre nao ter sujeira no centro e ter parafusos flutuando no meio
## do combate.
@export var contagem_micro: Vector2i = Vector2i(3, 8)

## Quantas pecas ficam PRESAS NA FACE da parede (tubo, caixa de juncao, duto).
##
## Na referencia medida (`docs/fabrica_01.png`) quase nenhum trecho de parede
## aparece limpo. Sem este numero a parede continua sendo um plano, e a
## densidade so pode crescer no chao -- que e onde ela atrapalha.
@export var contagem_parede: Vector2i = Vector2i(2, 5)

## Quantas pecas passam POR CIMA do ator (viga, tubulacao suspensa, cabo).
##
## Ela nao e um porte do `DecoradorDeSala` e nao pode ser: os seis portes falam
## de ONDE a peca encosta -- chao, parede, chao pintado --, e o Foreground nao
## encosta em lugar nenhum. O que o separa e a CAMADA (`Sala.Z_FRENTE`), e nao a
## geometria: um cabo passa por cima de uma caixa sem disputar espaco com ela.
##
## Ela mora aqui mesmo assim porque o dono de QUANTOS e este recurso, e deixar
## uma das quatro familias em `DadosSala` reabriria a divida que a migracao veio
## fechar -- um numero de densidade fora do botao de densidade.
##
## **O default e ZERO**, como era em `DadosSala`: a issue do Foreground pede
## moderacao com todas as letras, e sala que quer viga pede explicitamente.
@export var contagem_frente: Vector2i = Vector2i.ZERO

@export_group("Geometria")
## Quao fundo a decoracao entra a partir do contorno. O briefing pede 64 a 128;
## 96 e o meio dele.
##
## Faixa estreita demais gruda tudo na parede e a sala fica com uma moldura
## desenhada; larga demais e a faixa engole a area de combate e a zona livre
## passa a ser a unica coisa que segura o miolo.
@export var largura_da_faixa_de_perimetro: float = 96.0
## Raio, a partir do centro da sala, onde NADA pode nascer. O briefing pede 140
## a 180.
##
## **E a regra que protege o gameplay, e a mais importante do recurso.** O
## centro e onde o jogador esquiva e onde o telegrafo desenha; um barril ali nao
## e cenario, e uma morte que o jogador nao consegue explicar. O centro medido e
## o do retangulo que envolve o contorno -- o mesmo ponto em que as cenas de
## sala centram a `area_spawn`.
@export var raio_da_zona_livre: float = 160.0

@export_group("Pesos por lado")
## Para onde a decoracao comum tende. Sao pesos relativos: o decorador
## normaliza, entao nao e preciso somar 1 na mao.
@export var peso_norte: float = 0.35
@export var peso_leste: float = 0.25
@export var peso_oeste: float = 0.25
## O sul e o menor de proposito: e por onde o jogador entra na maioria das salas
## e e o lado que a camera corta primeiro quando ele desce.
@export var peso_sul: float = 0.15

@export_group("Pesos de hero por lado")
## O HERO tem pesos proprios e mais concentrados que os comuns.
##
## Ele e a peca que da nome a sala, e a face desenhada do norte e a unica
## superficie vertical contra a qual uma silhueta grande le como volume. No sul
## a mesma peca aparece cortada pela beira do quadro; no leste e no oeste ela
## compete com a saida lateral.
@export var peso_hero_norte: float = 0.50
@export var peso_hero_leste: float = 0.20
@export var peso_hero_oeste: float = 0.20
@export var peso_hero_sul: float = 0.10

@export_group("Agrupamentos")
## Os CLUSTERS que esta sala pode usar. Ver `AgrupamentoDeDecoracao`: a unidade
## de decoracao e o conjunto, e nao o prop.
@export var agrupamentos: Array[AgrupamentoDeDecoracao] = []
## Quantos clusters a sala tenta colocar. O briefing calibra por tamanho de
## sala: pequena 1 a 2, media 2 a 4, grande 3 a 6 -- entao o numero mora aqui e
## nao no decorador, porque quem sabe o porte da sala e o `.tres` do tipo.
##
## Cada nome de agrupamento entra NO MAXIMO uma vez por sala: o mesmo conjunto
## repetido duas vezes na mesma parede vira mobilia, que e o defeito que os
## props raros de `DadosSala` ja registram com todas as letras.
@export var quantos_agrupamentos: Vector2i = Vector2i(2, 4)


## Copia limpa dos agrupamentos, sem os nulos que o Inspetor deixa ao crescer o
## array e sem os que declaram listas desalinhadas.
##
## Loop explicito: `Array.filter()` devolve `Array` sem tipo, e a atribuicao de
## volta a um `Array[AgrupamentoDeDecoracao]` estoura em runtime.
func agrupamentos_validos() -> Array[AgrupamentoDeDecoracao]:
	var lista: Array[AgrupamentoDeDecoracao] = []
	for agrupamento in agrupamentos:
		if agrupamento != null and agrupamento.valido():
			lista.append(agrupamento)
	return lista
