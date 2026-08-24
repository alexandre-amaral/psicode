class_name PoolLoot
extends Resource
## O que o jogo pode dar de recompensa: armas e implantes.
##
## Duas decisoes de design moram aqui.
##
## 1. **Lista explicita, nao varredura de diretorio.** Seria tentador varrer
##    src/weapons/ com DirAccess e pegar todo .tres. Mas .tres que ninguem
##    referencia e podado do export, entao a build web sairia com o pool vazio
##    e sem um erro sequer no console. Listar aqui garante a referencia.
##
## 2. **As armas de inimigo ficam de fora por construcao.** tiro_vigia,
##    tiro_diretora e salva_diretora sao DadosArma como qualquer outra; o que
##    impede o jogador de ganhar a arma da Diretora e nao estarem nesta lista.
##
## Conteudo novo entra arrastando o .tres para o array certo no Inspetor.

@export var armas: Array[DadosArma] = []
@export var itens: Array[DadosItem] = []


## Loop explicito em vez de filter(): Array.filter() devolve Array sem tipo e a
## atribuicao de volta a um Array tipado estoura em runtime.
func armas_validas() -> Array[DadosArma]:
	var lista: Array[DadosArma] = []
	for arma in armas:
		if arma != null:
			lista.append(arma)
	return lista


func itens_validos() -> Array[DadosItem]:
	var lista: Array[DadosItem] = []
	for item in itens:
		if item != null:
			lista.append(item)
	return lista


## Devolve null com o pool vazio. Quem chama tem de aguentar isso: e melhor um
## pickup que nao nasce do que um pickup sem dado, que quebra no _ready.
func sortear_arma() -> DadosArma:
	var validas := armas_validas()
	if validas.is_empty():
		return null
	return validas.pick_random()


func sortear_item() -> DadosItem:
	var validos := itens_validos()
	if validos.is_empty():
		return null
	return validos.pick_random()
