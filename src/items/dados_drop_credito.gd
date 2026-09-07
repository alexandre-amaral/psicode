class_name DadosDropCredito
extends Resource
## Como um valor esperado de creditos vira FICHAS no chao.
##
## **O valor esperado ja existe, e nao se inventa.** O plano propunha derivar de
## `ameaca x creditos_por_ameaca`, e o levantamento mediu que os nove
## `GrupoInimigo.custo` valem **1** -- derivar dali daria economia plana. Mas
## `InimigoBase.creditos` ja e por inimigo e ja foi escalado:
##
##     Drone 6   Atirador 6   Sentinela 7   Hacker 10   Cyber-Besta 12   chefe 60
##
## Entao este recurso nao decide QUANTO o inimigo vale: ele decide como partir
## esse numero em fichas. Um segundo campo de ameaca duplicaria o primeiro, e
## duas copias divergem -- a mesma razao que tirou o mapa de angulos de dentro de
## `DadosPersonagem`.
##
## ## Por que ele parte em poucas fichas grandes
##
## Um Hacker de 10 creditos derrubando dez fichas de 1 seria poluicao visual num
## jogo cuja regra que corta todas as outras e a leitura de combate. O sorteio
## comeca pela maior ficha que cabe e desce, entao 10 vira UMA grande em vez de
## cinco pequenas.
##
## ## E por que ele e probabilistico
##
## Dois Drones iguais nao derrubam sempre a mesma coisa -- e o resto que nao
## fecha uma ficha vira CHANCE de mais uma. Assim a media converge para o valor
## declarado sem que todo abate pague o mesmo, e a economia deixa de ser uma
## regua. `teste_creditos.gd` cobra a convergencia com dez mil abates.

## Os valores das tres fichas, do maior para o menor.
##
## A ordem importa: o sorteio consome de cima para baixo, e uma lista fora de
## ordem produziria mais fichas do que o necessario sem nenhum erro.
@export var valores: Array[int] = [10, 5, 2]

## Quanto do valor esperado vira ficha, de fato.
##
## Abaixo de 1,0 a economia paga menos que o `creditos` declarado, o que e o
## botao para baixar a renda do andar sem mexer em inimigo nenhum -- e ele existe
## porque a renda ainda nao foi medida contra os precos da Loja (#284).
@export var fracao_do_valor: float = 1.0

## Teto de fichas por abate, para o chefe nao virar um chuveiro de 60 creditos.
##
## Ele MORDE no chefe e em mais ninguem: 60 pagaria seis fichas grandes, e o teto
## as junta -- a ultima carrega o resto. Teto que nunca e alcancado e teto que
## nunca foi testado.
@export var max_fichas: int = 4


## Os valores das fichas que este abate derruba.
##
## `rng` entra de fora para o resultado ser reproduzivel numa suite e numa
## simulacao -- o mesmo desenho de `PlantaDoAndar.sortear()`.
func sortear(valor_esperado: int, rng: RandomNumberGenerator) -> Array[int]:
	var saida: Array[int] = []
	if valores.is_empty() or valor_esperado <= 0 or fracao_do_valor <= 0.0:
		return saida

	var restante := float(valor_esperado) * fracao_do_valor
	for valor in valores:
		if valor <= 0:
			continue
		while restante >= float(valor) and saida.size() < max_fichas:
			saida.append(valor)
			restante -= float(valor)

	# **O RESTO VIRA CHANCE, e nao arredondamento.** Arredondado, um Drone de 6
	# pagaria sempre exatamente o mesmo, e a economia viraria uma regua: o mesmo
	# abate, o mesmo troco, toda vez. Como chance, a media continua batendo o
	# declarado e nenhum abate isolado e previsivel.
	var menor: int = valores[valores.size() - 1]
	if restante > 0.0 and saida.size() < max_fichas:
		if rng.randf() < restante / float(menor):
			saida.append(menor)

	# O TETO junta o que sobrou na ultima ficha, em vez de jogar fora. Descartar
	# faria o chefe pagar menos do que declara -- e o portao de convergencia
	# acusaria isso como se fosse defeito do sorteio.
	if saida.size() >= max_fichas and restante >= float(menor):
		saida[saida.size() - 1] += int(roundf(restante))
	return saida
