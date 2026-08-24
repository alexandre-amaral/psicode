class_name DadosSala
extends Resource
## Descreve um TIPO de sala: que cena usar, onde ela pode nascer no andar e
## como ela se apresenta no minimapa.
##
## A decisao de design que este arquivo carrega: antes, cada sala especial
## tinha codigo proprio no GerenciadorMapa -- um @export para a cena, um par de
## variaveis de estado e uma funcao `_pendurar_X` copiada da anterior. Um tipo
## novo custava um terceiro bloco igual. Aqui a regra de colocacao virou dado,
## entao adicionar sala de loja, de desafio ou de descanso e criar um .tres e
## arrasta-lo para a lista do GerenciadorMapa, sem abrir GDScript.
##
## Para criar um tipo: clique direito em src/mapa > Novo Recurso > DadosSala,
## salve como tipo_<nome>.tres, e adicione em `tipos_de_sala` no no
## GerenciadorMapa de src/main/main.tscn.

## Ids que o resto do codigo precisa reconhecer pelo nome. O que nao esta aqui
## e conteudo puro: o gerador trata igual, so o .tres muda.
const ID_COMBATE: StringName = &"combate"
const ID_BOSS: StringName = &"boss"
const ID_ARMA: StringName = &"arma"
const ID_ITEM: StringName = &"item"

## COMUM entra no sorteio normal do passeio aleatorio e preenche o andar.
## PENDURADA ganha uma celula propria encostada numa ancora ja existente. E o
## que o chefe precisa (ele so tem porta Sul, e quase nunca cairia numa celula
## com o grau certo por sorteio) e o que as recompensas usam para poder exigir
## beco sem saida -- coisa que o passeio nao garante sozinho.
enum Colocacao { COMUM, PENDURADA }

@export var id: StringName = ID_COMBATE
## Estilos possiveis deste tipo. E assim que "mais um estilo de sala de
## combate" custa arrastar uma cena aqui em vez de mexer em codigo. A sala de
## combate tem cinco; o chefe tem uma so.
##
## Numa sala PENDURADA o gerador tenta TODOS os estilos ate um caber, nao um
## sorteado: estilos diferentes tem portas em lados diferentes, entao o primeiro
## nao caber nao diz nada sobre o proximo.
@export var cenas: Array[PackedScene] = []

@export_group("Colocacao")
@export var colocacao: Colocacao = Colocacao.COMUM
## Quantas vezes este tipo aparece no andar. So vale para PENDURADA: as COMUM
## dividem entre si o que sobrou do passeio.
@export var quantidade: int = 1
## Ordem de colocacao, menor primeiro. Importa porque quem chega primeiro
## escolhe a melhor ancora: o chefe tem de tomar a celula mais distante antes
## que um premio a ocupe, senao ele cai no meio do andar.
@export var prioridade: int = 100
## Exige beco sem saida (celula de grau 1) como ancora. Recompensa que nao
## custa um desvio nao e recompensa.
@export var exige_beco: bool = false
## Quantas salas, no minimo, entre a origem e esta. Premio encostado na sala
## inicial nao e descoberta, e chefe perto da entrada encurta o andar.
##
## Nao existe um `evita_vizinhanca_de` aqui de proposito: duas salas penduradas
## NUNCA nascem coladas, por regra estrutural do gerador -- ambas podem ter uma
## porta so, e o par se estrangularia. Um campo para reconfigurar isso seria
## decorativo.
@export var distancia_minima_da_origem: int = 0
## Se falso e o tipo nao couber, o andar inteiro e sorteado de novo. O chefe e
## o unico obrigatorio: sem ele a run nao tem como terminar em vitoria.
@export var opcional: bool = true

@export_group("Minimapa")
@export var cor_mapa: Color = Color("3ce0ff")
## Marca curta desenhada no centro da sala no minimapa. Vazio = sem marca.
@export var icone: String = ""


func eh_pendurada() -> bool:
	return colocacao == Colocacao.PENDURADA


## Copia limpa dos estilos, sem os nulos que o Inspetor deixa ao crescer o
## array. Loop explicito: Array.filter() devolve Array sem tipo e a atribuicao
## de volta a um Array[PackedScene] estoura em runtime.
func cenas_validas() -> Array[PackedScene]:
	var lista: Array[PackedScene] = []
	for cena in cenas:
		if cena != null:
			lista.append(cena)
	return lista


## Quantas celulas este tipo ocupa de fato. Uma COMUM nao reserva celula: ela
## concorre pelo que o passeio produziu.
func celulas_reservadas() -> int:
	if not eh_pendurada():
		return 0
	return maxi(quantidade, 0)
