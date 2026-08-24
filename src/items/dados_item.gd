class_name DadosItem
extends Resource
## Um implante: o upgrade passivo que vale ate o fim da run.
##
## A decisao de design daqui: o efeito e DADO, nao codigo. Quem sofre o efeito
## consulta o autoload Modificadores no frame em que precisa, e nada no jogo
## guarda um numero ja multiplicado.
##
## Um implante tem DUAS partes, e vale entender a diferenca antes de criar um:
##
## 1. **efeitos** -- uma lista de EfeitoItem. E aqui que moram os numeros, e e
##    puramente declarativo. Implante numerico novo (mesmo com varios efeitos,
##    mesmo condicional) custa so um .tres.
##
## 2. **comportamento** -- um enum. Cobre o que numero nenhum expressa:
##    ricochetear, dividir o projetil, curar por abate. Cada comportamento e
##    lido por um sistema diferente do jogo (projetil, arma, autoload), entao
##    um comportamento novo custa codigo. Esse e o limite honesto desta
##    abordagem, e nao adianta fingir que nao existe.
##
## Para criar um implante: clique direito em src/items > Novo Recurso >
## DadosItem, salve como implante_<nome>.tres, monte a lista de efeitos, e
## adicione ao pool de loot (src/items/pool_padrao.tres).

## O que o implante faz alem de mexer em numero.
##
## O `parametro` significa uma coisa diferente em cada um -- a doc de cada
## valor diz qual.
enum Comportamento {
	## So os efeitos numericos valem.
	NENHUM,
	## parametro = chance (0..1) de o projetil quicar na parede.
	RICOCHETE,
	## parametro = chance (0..1) de o projetil se dividir ao acertar.
	FRAGMENTAR,
	## parametro = chance (0..1) de curar 1 ao matar.
	VAMPIRISMO,
	## parametro = quantos abates ate curar 1.
	NANOBOTS,
	## parametro = fracao de vida abaixo da qual os efeitos VIDA_BAIXA ligam.
	SOBRECARGA,
	## parametro = quantos tiros depois da recarga contam como "de eco".
	ECO,
	## parametro = multiplicador de dano no alvo marcado.
	MARCADOR,
	## parametro = teto de cargas.
	CARGAS_SEM_DANO,
}

@export var nome: String = "Implante"
@export_multiline var descricao: String = ""

@export_group("Efeito")
@export var efeitos: Array[EfeitoItem] = []
@export var comportamento: Comportamento = Comportamento.NENHUM
@export var parametro: float = 0.0
## Quantas vezes o mesmo implante pode acumular numa run. 0 = sem limite.
@export var maximo_por_run: int = 0

@export_group("Apresentacao")
@export var cor: Color = Color("7cf7c4")
## Marca curta desenhada no pickup e na lista da HUD.
@export var sigla: String = "+"


## Loop explicito em vez de filter(): Array.filter() devolve Array sem tipo e a
## atribuicao de volta a um Array tipado estoura em runtime.
func efeitos_validos() -> Array[EfeitoItem]:
	var lista: Array[EfeitoItem] = []
	for efeito in efeitos:
		if efeito != null:
			lista.append(efeito)
	return lista


## Implante que nao mexe em numero nenhum nem tem comportamento e um .tres
## esquecido pela metade -- o defeito mais provavel deste sistema, e invisivel
## em runtime. A suite de teste usa isto para recusar.
func faz_alguma_coisa() -> bool:
	return comportamento != Comportamento.NENHUM or not efeitos_validos().is_empty()


func tem_comportamento() -> bool:
	return comportamento != Comportamento.NENHUM
