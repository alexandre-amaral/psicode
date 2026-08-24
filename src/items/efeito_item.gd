class_name EfeitoItem
extends Resource
## Um efeito isolado de implante: o que ele mexe, como combina e QUANDO vale.
##
## Existe separado de DadosItem porque um implante deixou de ser um numero so.
## O Overclock Neural sobe a cadencia E a Deterioracao; o Firewall Cognitivo
## reduz a Deterioracao E o dano. Com um par (alvo, valor) por item nao havia
## como escrever nenhum dos dois.
##
## A condicao e o que permite implante que liga e desliga em jogo -- o bonus de
## vida baixa do Modulo de Sobrecarga, as cargas do Daemon de Combate. Quem
## decide se a condicao vale agora e o autoload Modificadores, que acompanha o
## estado da run; aqui so mora a declaracao.

## O que este efeito mexe.
##
## DANO e DANO_PERCENTUAL sao alvos SEPARADOS de proposito: dano e int no jogo,
## entao "+10%" numa pistola de dano 2 arredondaria de volta para 2 e o
## implante nao faria nada. Mantendo os dois, DANO soma inteiros e
## DANO_PERCENTUAL multiplica, e o arredondamento acontece uma vez so, no fim.
enum Alvo {
	VIDA_MAXIMA,
	VELOCIDADE,
	COOLDOWN_ROLAMENTO,
	CADENCIA,
	DANO,
	DANO_PERCENTUAL,
	VELOCIDADE_PROJETIL,
	GANHO_DETERIORACAO,
}

## MULTIPLICA acumula por produto (1.1 e 1.1 viram 1.21), SOMA por adicao.
## Percentual pede MULTIPLICA; contagem inteira, como vida, pede SOMA.
enum Modo { MULTIPLICA, SOMA }

## Quando este efeito conta.
##
## SEMPRE e o passivo puro. Os outros dependem de estado que o Modificadores
## acompanha, e por isso NAO entram no acumulo estatico: eles sao calculados no
## frame em que alguem pergunta, como manda a regra 2 do projeto.
enum Condicao {
	SEMPRE,
	## Vale so abaixo do limiar de vida do implante (Modulo de Sobrecarga).
	VIDA_BAIXA,
	## Aplicado uma vez por carga acumulada (Daemon de Combate).
	POR_CARGA,
	## Vale so nos primeiros tiros depois de recarregar (Celula de Eco).
	TIROS_DE_ECO,
}

@export var alvo: Alvo = Alvo.VELOCIDADE
@export var modo: Modo = Modo.MULTIPLICA
## Com MULTIPLICA, 1.0 e neutro e menor que 1.0 reduz -- e assim que um efeito
## de reducao de cooldown se escreve (0.85 = 15% mais rapido).
@export var valor: float = 1.1
@export var condicao: Condicao = Condicao.SEMPRE


## O valor que nao muda nada quando acumulado. Existe para o Modificadores
## inicializar um alvo sem precisar saber qual modo ele usa.
func neutro() -> float:
	return 1.0 if modo == Modo.MULTIPLICA else 0.0


func eh_multiplicativo() -> bool:
	return modo == Modo.MULTIPLICA


## Este alvo guarda um valor inteiro no jogo? Percentual em cima de int some no
## arredondamento, entao a suite de teste recusa essa combinacao.
static func alvo_e_inteiro(a: int) -> bool:
	return a == Alvo.VIDA_MAXIMA or a == Alvo.DANO


## Texto curto para a HUD e para as descricoes, montado do proprio dado.
func resumo() -> String:
	if modo == Modo.SOMA:
		return "%+.0f" % valor
	return "%+.0f%%" % ((valor - 1.0) * 100.0)
