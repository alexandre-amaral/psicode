class_name MedidorEscape
extends RefCounted
## A REGUA de "isso e evitavel": quantas saidas o jogador tem, agora.
##
## O GDD proibe uma coisa em especifico, e nao "dificil": a SITUACAO INEVITAVEL
## -- um instante em que nenhuma entrada do jogador evita o dano. E o que separa
## "dificil de interpretar rapido" de "quantidade enorme de projeteis
## aleatorios", e opiniao nao resolve a diferenca.
##
## O metodo e o mesmo que `teste_diretora.gd` ja usa para o repertorio do chefe,
## generalizado de um ataque para o CAMPO INTEIRO: em vez de perguntar "quantas
## aberturas este ataque deixa", pergunta "para quantas das N direcoes da para
## correr sem encostar em nada nos proximos H segundos". Zero saidas = situacao
## inevitavel. Continua sendo numero, e nao impressao.
##
## Tres decisoes que a regua carrega:
##
## 1. **O modelo de ameaca e generico, sem um caso por inimigo.** Toda ameaca do
##    jogo vira o mesmo trio: posicao, velocidade e raio. Disco parado e area de
##    perigo; disco em movimento e projetil ou corpo de inimigo. Uma regua com
##    um `if` por inimigo mediria o que ela conhece, e o proximo inimigo nasceria
##    invisivel para ela -- que e o modo de falha caro aqui, porque uma regua
##    cega passa VERDE.
##
## 2. **FICAR PARADO conta como saida.** E uma entrada do jogador como outra
##    qualquer, e ha ataque que se evita nao andando -- a investida da Cyber-Besta
##    passa reta por quem nao entrou na linha. Ignorar isso inventaria
##    inevitabilidade onde nao ha.
##
## 3. **Ameaca parada e ameaca em movimento sao perguntas diferentes.** O circulo
##    do Hacker fere num instante -- quando o aviso acaba --, entao o que importa
##    e onde o jogador esta NO FIM do horizonte; sair de dentro dele antes de
##    estourar e a jogada que o telegrafo existe para permitir. O projetil fere no
##    CONTATO, entao o caminho inteiro conta. Tratar as duas igual foi o primeiro
##    defeito desta regua, e ele reprovava TODA combinacao -- inclusive as que nao
##    tem como ser inevitaveis. Regua que reprova tudo mede a si mesma.
##
## 4. **O horizonte e curto de proposito.** Ele mede a saida IMEDIATA, nao o
##    futuro da sala: o jogador tambem se mexe, os inimigos mudam de estado, e
##    extrapolar longe demais transformaria a regua num simulador ruim. O padrao
##    e o piso de telegrafo do projeto -- se ha aviso de 0,35 s, e nesse intervalo
##    que a saida tem de existir.

## Quantas direcoes a regua testa. 64 da um passo de 5,6 graus, mais fino que o
## corpo do jogador visto de qualquer distancia util.
const DIRECOES := 64

## Em quantos instantes o caminho e conferido dentro do horizonte. Conferir so o
## fim do horizonte deixaria passar a ameaca que cruza o caminho no MEIO dele.
const PASSOS := 6

## Horizonte padrao, em segundos: o piso de telegrafo do projeto.
const HORIZONTE := 0.35

## Abaixo disto uma ameaca conta como PARADA, e a pergunta muda de "ela cruza meu
## caminho?" para "eu estou fora dela quando ela estoura?". Ver `_rota_livre`.
const VELOCIDADE_PARADA := 4.0


## Varre a cena e devolve toda ameaca ao jogador, no formato da regua.
##
## Le do MUNDO e nao de uma lista declarada: uma lista declarada seria uma
## segunda fonte de verdade sobre o que machuca, e a primeira coisa a divergir.
static func ameacas(raiz: Node, ignorar: Node = null) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	_coletar(raiz, ignorar, saida)
	return saida


## Reconhece o projetil pelo que ele TEM, e nao pelo tipo.
##
## `src/projectiles/projetil.gd` e `extends Area2D` sem `class_name` -- ele nunca
## precisou de um, porque quem o cria e sempre a `Arma`. Dar um so para a regua
## poder cita-lo seria mexer no no mais quente do jogo por causa de uma
## ferramenta; perguntar pelos campos custa o mesmo e nao toca em nada.
static func _e_projetil_hostil(no: Node) -> bool:
	if not no is Area2D:
		return false
	if not ("hostil" in no and "velocidade" in no and "raio" in no):
		return false
	return no.hostil


static func _coletar(no: Node, ignorar: Node, saida: Array[Dictionary]) -> void:
	if no == ignorar:
		return

	var area := no as AreaDePerigo
	if area != null:
		# A area conta desde o AVISO: a regua pergunta se ha para onde ir, e o
		# aviso e justamente o momento em que essa pergunta importa.
		saida.append({
			"posicao": area.global_position,
			"velocidade": Vector2.ZERO,
			"raio": area.raio,
			"tipo": "area",
		})
	elif _e_projetil_hostil(no):
		saida.append({
			"posicao": (no as Node2D).global_position,
			"velocidade": no.velocidade,
			"raio": maxf(no.raio, 2.0),
			"tipo": "projetil",
		})
	elif no is InimigoBase and not (no as InimigoBase).morto:
		var inimigo := no as InimigoBase
		saida.append({
			"posicao": inimigo.global_position,
			"velocidade": inimigo.velocity,
			"raio": inimigo.raio_contato,
			"tipo": "corpo",
		})

	for filho in no.get_children():
		_coletar(filho, ignorar, saida)


## Quantas das `DIRECOES` saidas estao livres, mais a de ficar parado.
##
## Devolve de 0 a `DIRECOES + 1`. Zero e a situacao inevitavel.
static func saidas_livres(
	origem: Vector2,
	raio_corpo: float,
	velocidade: float,
	ameacas_: Array[Dictionary],
	horizonte: float = HORIZONTE
) -> int:
	var livres := 0
	if _rota_livre(origem, Vector2.ZERO, 0.0, raio_corpo, ameacas_, horizonte):
		livres += 1
	for i in DIRECOES:
		var d := Vector2.RIGHT.rotated(TAU * float(i) / float(DIRECOES))
		if _rota_livre(origem, d, velocidade, raio_corpo, ameacas_, horizonte):
			livres += 1
	return livres


## Nenhuma saida = nenhuma entrada do jogador evita o dano.
static func inevitavel(
	origem: Vector2,
	raio_corpo: float,
	velocidade: float,
	ameacas_: Array[Dictionary],
	horizonte: float = HORIZONTE
) -> bool:
	return saidas_livres(origem, raio_corpo, velocidade, ameacas_, horizonte) == 0


## Correr nesta direcao poe o corpo em seguranca dentro do horizonte?
##
## AMEACA PARADA e AMEACA EM MOVIMENTO sao perguntas diferentes, e trata-las
## igual foi o primeiro defeito desta regua -- ela reprovava TODA combinacao,
## inclusive as que nao tem como ser inevitaveis.
##
## - **Parada** (o circulo do Hacker) fere num INSTANTE: quando o aviso acaba.
##   O que importa e onde o jogador esta NO FIM do horizonte. Cobrar o caminho
##   inteiro dizia "voce nao escapa" para quem esta dentro do circulo -- e sair
##   de dentro dele antes de estourar e literalmente a jogada que o telegrafo
##   existe para permitir. Com essa regra, estar dentro de um aviso era sempre
##   uma sentenca, e a regua media a si mesma.
##
## - **Em movimento** (projetil, corpo) fere no CONTATO, a qualquer instante. Aqui
##   o caminho inteiro conta: o projetil que cruza a rota no meio do horizonte e
##   sai antes do fim seria invisivel para uma conferencia so do fim, e ele e
##   justamente o que passa raspando.
static func _rota_livre(
	origem: Vector2,
	direcao: Vector2,
	velocidade: float,
	raio_corpo: float,
	ameacas_: Array[Dictionary],
	horizonte: float
) -> bool:
	var fim := origem + direcao * velocidade * horizonte
	for a in ameacas_:
		var limite: float = raio_corpo + a["raio"]
		var vel: Vector2 = a["velocidade"]
		if vel.length_squared() < VELOCIDADE_PARADA * VELOCIDADE_PARADA:
			# Fere num instante: so o fim do horizonte importa.
			if fim.distance_squared_to(a["posicao"]) < limite * limite:
				return false
			continue
		# Fere no contato: o caminho inteiro importa.
		for passo in range(1, PASSOS + 1):
			var t := horizonte * float(passo) / float(PASSOS)
			var eu := origem + direcao * velocidade * t
			var ela: Vector2 = a["posicao"] + vel * t
			if eu.distance_squared_to(ela) < limite * limite:
				return false
	return true
