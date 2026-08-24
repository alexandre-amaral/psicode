class_name DadosItem
extends Resource
## Um implante: o upgrade passivo que vale ate o fim da run.
##
## A decisao de design daqui: o efeito e DADO, nao codigo. Um item e um par
## (alvo, valor) mais o modo de combinar, e quem sofre o efeito consulta o
## autoload Modificadores no frame em que precisa. Por isso criar um implante
## novo e criar um .tres -- nao existe um `match` de nomes de item em lugar
## nenhum, e nada no jogo guarda um numero ja multiplicado.
##
## Para criar um implante: clique direito em src/items > Novo Recurso >
## DadosItem, salve como implante_<nome>.tres, e adicione ao pool de loot
## (src/items/pool_padrao.tres).

## O que o implante mexe. Um alvo novo exige um getter novo em Modificadores --
## e o unico lugar do sistema que ainda pede codigo, porque cada alvo e lido
## por um sistema diferente do jogo.
enum Alvo {
	VIDA_MAXIMA,
	VELOCIDADE,
	COOLDOWN_ROLAMENTO,
	CADENCIA,
	DANO,
	VELOCIDADE_PROJETIL,
	GANHO_DETERIORACAO,
}

## MULTIPLICA acumula por produto (1.1 e 1.1 viram 1.21), SOMA por adicao.
## Percentual pede MULTIPLICA; contagem inteira, como vida, pede SOMA.
enum Modo { MULTIPLICA, SOMA }

@export var nome: String = "Implante"
@export_multiline var descricao: String = ""

@export_group("Efeito")
@export var alvo: Alvo = Alvo.VELOCIDADE
@export var modo: Modo = Modo.MULTIPLICA
## Com MULTIPLICA, 1.0 e neutro e menor que 1.0 reduz -- e assim que um
## implante de reducao de cooldown se escreve (0.85 = 15% mais rapido).
@export var valor: float = 1.1
## Quantas vezes o mesmo implante pode acumular numa run. 0 = sem limite.
@export var maximo_por_run: int = 0

@export_group("Apresentacao")
@export var cor: Color = Color("7cf7c4")
## Marca curta desenhada no pickup e na lista da HUD.
@export var sigla: String = "+"


## Neutro do modo: o valor que nao muda nada quando acumulado. Existe para o
## Modificadores poder inicializar um alvo sem saber qual modo ele usa.
func neutro() -> float:
	return 1.0 if modo == Modo.MULTIPLICA else 0.0


## Texto curto para a HUD, montado do proprio dado. Sem isto cada implante
## precisaria de uma descricao escrita a mao so para dizer o obvio.
func resumo() -> String:
	if modo == Modo.SOMA:
		return "%s %+.0f" % [nome, valor]
	return "%s %+.0f%%" % [nome, (valor - 1.0) * 100.0]
