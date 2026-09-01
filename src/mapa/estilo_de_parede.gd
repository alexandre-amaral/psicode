class_name EstiloDeParede
extends Resource
## O KIT de parede de um andar: de que material ele e feito.
##
## Ele existe para separar duas coisas que estavam no mesmo lugar: **a geometria
## da sala** e **a identidade do andar**. A forma de uma sala e o `.tscn` dela
## mais o `DadosSala` que diz onde ela pode nascer; o MATERIAL com que a parede
## dela e vestida passa a ser isto. A mesma sala logica pode virar setor
## industrial, laboratorio ou nucleo sem tocar em uma linha da geracao
## procedural.
##
## **`DadosSala` ganha UM campo, e nao uma duzia.** Com a parede virando fita de
## modulos, cada tipo de sala precisaria de listas de topo, de face, de canto e
## de variante -- e o plano avisa contra a explosao de `@export`. Um recurso
## apontado por um campo resolve, e de quebra deixa o kit reusavel entre tipos:
## as cinco salas do andar 1 compartilham o MESMO estilo, porque elas sao o mesmo
## setor.
##
## **O que ele NAO carrega e a face por tipo de sala.** Desde a LTD 13 a face e
## quem diz de que sala se trata -- combate ciano, chefe rosa, arma ambar --, e
## isso continua morando em `DadosSala.texturas_face`. O estilo carrega o que e
## do ANDAR: o topo, que e neutro e compartilhado desde a PAR 04, os cantos, e a
## face de recurso para quem nao declarar a propria.
##
## A divisao entre os dois se le assim:
##
##   ESTILO      o andar    topo, cantos, face neutra
##   DadosSala   a sala     face do tipo, chao, props, regras de colocacao

## O nome do kit, para o Inspetor e para mensagem de erro.
@export var id: StringName = &""

## Os TOPOS, sorteados por celula. Neutros e compartilhados por todo tipo de
## sala: a identidade mora na face, e cinco copias da mesma lista divergiriam no
## dia em que alguem mudasse quatro.
@export var topos: Array[Texture2D] = []

## A face de recurso, usada por quem nao declara `texturas_face`.
@export var face_neutra: Texture2D = null

## Os CANTOS convexos, na ordem noroeste, nordeste.
##
## Eles sao lista e nao dois campos porque a PAREDE 06 acrescenta os concavos, e
## campo por quina e exatamente a explosao de `@export` que este recurso existe
## para evitar. Quem indexa e `RenderizadorParedes`, por um enum.
@export var cantos: Array[Texture2D] = []


## Este estilo esta montado o bastante para vestir uma parede?
##
## Irma de `ClipeDirecional.desenhavel()` e de `SpriteDirecional.tem_ciclo()`, e
## pelo mesmo motivo: quem pergunta nao precisa saber que "desmontado" quer dizer
## lista vazia.
func vestivel() -> bool:
	return not topos.is_empty()


## O canto de um indice, ou `null` se o kit ainda nao tem aquele.
##
## Devolver `null` em vez de estourar e deliberado: a PAREDE 06 acrescenta quatro
## quinas novas, e ate la o renderizador pede por elas e nao recebe. Kit
## incompleto desenha menos, e nao quebra.
func canto(indice: int) -> Texture2D:
	if indice < 0 or indice >= cantos.size():
		return null
	return cantos[indice]
