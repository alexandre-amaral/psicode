class_name InventarioDeArmas
extends RefCounted
## O QUE O JOGADOR CARREGA: duas armas, uma ativa, o pente de cada uma.
##
## A separacao que ele existe para fazer, e que o pedido do epico chama de
## `WeaponInventory` contra `WeaponController`:
##
##     InventarioDeArmas  = o que carregamos   (slots, pente, quem esta na mao)
##     Arma               = o que estamos usando (cadencia, recarga, disparo)
##
## O componente `Arma` e o mesmo script no jogador e nos inimigos, e um inimigo
## nao tem slot nenhum -- entao slot NAO pode morar la. Antes deste arquivo ele
## morava em dois `var` soltos do `player.gd` (`_slots` e `_slot_ativo`), com a
## regra "o slot 0 e a pistola infinita e nunca sai" escrita em quatro lugares
## diferentes do mesmo script.
##
## **Ele nao conhece a arvore, nao emite no EventBus e nao abre UI.** Isso e
## deliberado, e e o que torna a regra cobravel: `teste_inventario_de_armas.gd`
## monta um inventario, pede tres armas e confere o resultado sem instanciar uma
## cena. Quem traduz o resultado em sinal global e em tela e o Player, que e o
## adaptador -- mesma divisao que faz a HUD nao conhecer o Player.
##
## **Os dois slots sao SIMETRICOS**, e isso e a mudanca de design do epico. Antes
## o slot 0 era a arma inicial e nao podia ser trocado; hoje a arma inicial e
## so a primeira coisa a ocupar o slot 0. O medo obvio de tornar os dois
## substituiveis -- "o jogador troca a arma infinita e fica sem nada" -- foi
## medido e nao tem caso: as 21 armas do jogo tem reserva infinita, entao
## nenhuma acaba.

## Quantas armas cabem. Dois nao e `@export` nem `const` ajustavel por acaso: e
## uma decisao de design ("o personagem carrega o que cabe nas maos"), e um
## numero ajustavel seria ajustado para tres na primeira vez que alguem achasse
## que faltava espaco.
const SLOTS := 2

## O que `pedir_aquisicao()` respondeu.
enum Resultado {
	## Havia vaga: a arma entrou e virou ativa. Quem pediu pode consumir o pickup.
	ACEITA,
	## Os dois slots estao cheios. **NADA foi alterado** -- quem pediu tem de
	## abrir a escolha, e o pickup continua no chao ate ela terminar.
	PRECISA_ESCOLHER,
	## O molde era nulo, ou ja esta carregado. Nada a fazer.
	RECUSADA,
}

## `InstanciaDeArma` ou `null` por vaga. Nunca redimensionado -- vaga vazia e
## `null` e nao "fora da lista", senao "o slot 2 esta vazio" e "o slot 2 nao
## existe" viram a mesma pergunta.
var _slots: Array = [null, null]

var _ativo: int = 0


# ------------------------------------------------------------- consultas ---

func slot(indice: int) -> InstanciaDeArma:
	if indice < 0 or indice >= SLOTS:
		return null
	return _slots[indice] as InstanciaDeArma


func indice_ativo() -> int:
	return _ativo


## A arma na mao. Pode ser `null` antes de a run comecar.
func ativa() -> InstanciaDeArma:
	return slot(_ativo)


## A outra. `null` enquanto o jogador so tem uma arma -- que e o estado em que
## ele comeca toda run, e por isso a HUD tem de saber desenhar essa ausencia.
func reserva() -> InstanciaDeArma:
	return slot(1 - _ativo)


func tem_vaga() -> bool:
	return _primeira_vaga() >= 0


## Ja carrego esta arma? Perguntado antes de aceitar: sem isso, pegar a mesma
## Rail-X duas vezes encheria os dois slots com ela e a troca deixaria de trocar
## qualquer coisa -- sem erro nenhum, e so uma tecla que parou de fazer efeito.
func carrega(molde: DadosArma) -> bool:
	for i in SLOTS:
		var inst := slot(i)
		if inst != null and inst.e_o_mesmo_molde(molde):
			return true
	return false


func quantas() -> int:
	var n := 0
	for i in SLOTS:
		if slot(i) != null:
			n += 1
	return n


# ----------------------------------------------------------------- posse ---

## A arma com que a run comeca. Ela ocupa o slot 0 e vira ativa -- e nao tem
## nada de especial alem disso: e substituivel como qualquer outra.
func definir_inicial(molde: DadosArma) -> void:
	_slots = [null, null]
	_ativo = 0
	if molde == null:
		return
	_slots[0] = InstanciaDeArma.new(molde)


## O UNICO caminho de aquisicao do jogo -- chao, sala de recompensa, Loja e o
## que vier depois.
##
## Uma segunda logica de aquisicao divergiria da primeira, e o sintoma seria uma
## arma COMPRADA se comportando diferente da mesma arma achada no chao: sem erro
## nenhum, e so quando alguem comparasse as duas.
##
## **Com os dois slots cheios ele nao mexe em nada e devolve
## `PRECISA_ESCOLHER`.** Ele nao abre tela e nao escolhe pelo jogador -- essa e
## a decisao que o epico existe para criar, e o §22 do pedido e explicito:
## mesmo que a arma nova seja melhor, nunca decidir por ele.
func pedir_aquisicao(molde: DadosArma) -> Resultado:
	if molde == null or carrega(molde):
		return Resultado.RECUSADA

	var vaga := _primeira_vaga()
	if vaga < 0:
		return Resultado.PRECISA_ESCOLHER

	_slots[vaga] = InstanciaDeArma.new(molde)
	# **A arma nova vira ATIVA** (§14 do pedido). Ela e a resposta imediata ao
	# ato de pegar: sem isso o jogador atravessa a sala com a arma nova guardada
	# e nada na tela muda, o que le como pickup que nao funcionou.
	_ativo = vaga
	return Resultado.ACEITA


## Troca o conteudo de um slot e devolve o que saiu, para quem chamou pode
## deixa-lo no chao.
##
## Devolver a instancia e nao o `DadosArma` e de proposito: e o que permitiria
## um dia a arma no chao lembrar o proprio pente. Hoje o pickup so le o molde --
## divida declarada, e nao esquecimento.
func substituir(indice: int, molde: DadosArma) -> InstanciaDeArma:
	if molde == null or indice < 0 or indice >= SLOTS:
		return null
	var saindo := slot(indice)
	_slots[indice] = InstanciaDeArma.new(molde)
	# Quem substituiu quer usar o que acabou de escolher.
	_ativo = indice
	return saindo


## Alterna a arma ativa. Devolve `false` quando nao ha o que alternar -- e e o
## chamador que decide se isso vira som, animacao ou nada.
func alternar() -> bool:
	var outro := 1 - _ativo
	if slot(outro) == null:
		return false
	_ativo = outro
	return true


## Esvazia o slot indicado. **Substitui a regra antiga "arma vazia volta para a
## pistola do slot 0"**, que deixou de ser verdade quando os dois slots viraram
## simetricos: nao existe mais um slot privilegiado para onde voltar.
##
## Se o slot esvaziado era o ativo e o outro tem arma, o outro assume -- ficar
## com a mao vazia tendo arma no coldre nao e decisao de ninguem, e um estado em
## que o botao de tiro nao faz nada.
func esvaziar(indice: int) -> void:
	if indice < 0 or indice >= SLOTS:
		return
	_slots[indice] = null
	if indice == _ativo and slot(1 - _ativo) != null:
		_ativo = 1 - _ativo


## Fim de run. O inventario de armas nao atravessa para a run seguinte, pela
## mesma razao que `Modificadores.resetar()` existe: a build e da run.
func limpar() -> void:
	_slots = [null, null]
	_ativo = 0


# ------------------------------------------------------------- internos ---

func _primeira_vaga() -> int:
	for i in SLOTS:
		if _slots[i] == null:
			return i
	return -1
