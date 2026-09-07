class_name PickupCredito
extends Area2D
## Uma ficha de credito no chao: o abate deixa de virar saldo em silencio.
##
## Ate a #280 o credito era uma linha na morte do inimigo -- `GameState.creditos
## += creditos` --, invisivel e instantanea. Com uma Loja para gastar, o credito
## precisa ser uma COISA: algo que cai, que se ve, e que o jogador decide se vale
## atravessar a sala para pegar.
##
## ## A leitura em combate e a trava dura, e nao um acabamento
##
## Ela divide a tela com projetil e telegrafo, e perder um dos dois por causa de
## dinheiro seria o pior defeito possivel -- a regra que corta todas as outras
## aqui e que efeito atrapalhando a leitura de combate e efeito cortado. Por
## isso:
##
##   - **silhueta LOSANGO e nao circulo.** Circulo pequeno e brilhante e
##     exatamente o que um projetil e neste jogo, e a forma e o primeiro canal
##     que o olho usa;
##   - **sem brilho grande e sem amarelo saturado**, que e a faixa de perigo do
##     andar 1 (a sala de arma usa 25-50 graus);
##   - **abaixo da faixa do mundo.** `Z_CHAO_DETALHE` e onde o prop chapado e a
##     aura de aprimoramento ja vivem; zero e onde telegrafo, projetil e atores
##     desenham. E garantia GEOMETRICA, e nao intencao.
##
## ## E ela nao colide com nada
##
## `Area2D` e nao corpo: nao bloqueia inimigo, nao empurra o jogador, nao entra
## na fisica de projetil. Uma ficha que empurrasse o jogador durante uma esquiva
## seria dinheiro matando gente.

## A faixa chapada, a mesma do prop e da aura.
const Z_FICHA := -18

## Quanto ela atrai, e quao forte.
##
## **O jogador nao pode ter de PARAR para coletar** -- parar num bullet hell e o
## oposto do que o jogo pede o tempo todo. O raio e generoso e a aceleracao e
## suave: a ficha vai ate ele enquanto ele resolve o combate.
const RAIO_DE_ATRACAO := 96.0
const ACELERACAO := 900.0
const VELOCIDADE_MAXIMA := 620.0

## Raio de coleta. Menor que o de atracao de proposito: a ficha tem de CHEGAR,
## e nao ser absorvida de longe -- o pequeno voo dela e o feedback de que ela
## existiu.
const RAIO_DE_COLETA := 14.0

## Quanto ela salta ao nascer, para nao empilhar no ponto exato da morte.
## Quanto tempo a ficha voa depois de a sala limpar antes de se creditar sozinha.
##
## **O voo e feedback, e nao uma corrida que o jogador possa perder.** Medido: so
## com a atracao, uma run de 38 abates rendeu **12 creditos** dos ~266 esperados
## -- o jogador saia da sala e as fichas ficavam perseguindo do outro lado do
## andar, algumas nunca chegando. Renda que depende de o jogador esperar no lugar
## certo nao e economia.
##
## Dois segundos: tempo de a ficha atravessar a sala e ser vista chegando, e
## curto o bastante para nao virar espera.
const TEMPO_DE_VOO := 2.0

const IMPULSO_INICIAL := 90.0
const ATRITO := 4.5

## As cores, por tamanho. Elas sao a MESMA familia com valores diferentes -- e
## nao tres cores --, porque o que o jogador precisa ler primeiro e "isso e
## dinheiro", e so depois "quanto".
const COR_PEQUENA := Color(0.55, 0.78, 0.72)
const COR_MEDIA := Color(0.62, 0.86, 0.72)
const COR_GRANDE := Color(0.72, 0.94, 0.70)

var valor: int = 2

var _velocidade: Vector2 = Vector2.ZERO
var _jogador: Node2D = null
var _coletada: bool = false
## Depois de a sala limpar, ela vai ate o jogador de qualquer distancia.
##
## **Sem isto o jogador PERDE dinheiro por geometria.** Medido no teste de
## fumaca: uma run inteira com 33 abates terminou com **zero** creditos -- as
## fichas caiam onde o inimigo morreu, o jogador saia da sala e elas ficavam
## para tras. Renda que depende de o jogador ter passado por cima do lugar certo
## nao e economia, e sorte.
##
## E o conserto respeita a regra que abriu a issue: *"o jogador nao pode ter de
## PARAR para coletar"*. Durante o combate ele pega o que passa perto; quando a
## luta acaba, o resto vem ate ele. Ninguem varre a sala catando ficha.
var _atraido_sempre: bool = false
var _t_voo: float = 0.0
var _t: float = 0.0


## Chamado por quem derruba, DEPOIS do `add_child`.
##
## Antes do `add_child` nao adianta: fora da arvore o setter de `global_position`
## cai no local e o pai reaplica a propria transform por cima -- a mesma
## armadilha que `Sala._povoar()` ja documenta.
func configurar(onde: Vector2, quanto: int) -> void:
	global_position = onde
	valor = maxi(quanto, 1)
	var angulo := randf() * TAU
	_velocidade = Vector2.RIGHT.rotated(angulo) * IMPULSO_INICIAL
	queue_redraw()


func _ready() -> void:
	EventBus.sala_limpa.connect(_ao_sala_limpa)
	z_index = Z_FICHA
	# `z_as_relative` desligado pela mesma razao do telegrafo e da aura: herdando
	# a camada de quem a pendurou, a garantia de "abaixo do mundo" deixa de ser
	# geometrica.
	z_as_relative = false
	monitoring = false
	monitorable = false
	queue_redraw()


func _process(delta: float) -> void:
	if _coletada:
		return
	_t += delta

	if _atraido_sempre:
		_t_voo += delta
		# O voo TERMINA em credito, sempre. Sem este piso a ficha que nao alcanca
		# o jogador -- porque ele trocou de sala, ou porque a sala foi liberada --
		# some com o dinheiro dentro.
		if _t_voo >= TEMPO_DE_VOO:
			_coletar()
			return

	if _jogador == null or not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group("player") as Node2D

	if _jogador != null:
		var para_o_jogador := _jogador.global_position - global_position
		var distancia := para_o_jogador.length()
		if distancia <= RAIO_DE_COLETA:
			_coletar()
			return
		if _atraido_sempre or distancia <= RAIO_DE_ATRACAO:
			_velocidade += para_o_jogador.normalized() * ACELERACAO * delta
			_velocidade = _velocidade.limit_length(VELOCIDADE_MAXIMA)

	# O atrito so vale FORA do raio: dentro dele a ficha esta sendo puxada, e
	# frear o que se acelera de proposito e o jeito de a atracao parecer lenta.
	if not _atraido_sempre and (_jogador == null
			or global_position.distance_to(_jogador.global_position) > RAIO_DE_ATRACAO):
		_velocidade = _velocidade.lerp(Vector2.ZERO, minf(ATRITO * delta, 1.0))

	global_position += _velocidade * delta
	queue_redraw()


func _coletar() -> void:
	_coletada = true
	GameState.adicionar_creditos(valor)
	EventBus.credito_coletado.emit(global_position, valor)
	queue_free()


## Um LOSANGO, e nao um circulo.
##
## A forma e o primeiro canal, e circulo pequeno e brilhante e o que um projetil
## e. O losango tem quatro cantos e uma orientacao, entao ele le como PECA -- que
## e o que a ficha e na ficcao: sucata industrial que virou moeda.
func _draw() -> void:
	var cor := COR_PEQUENA
	var raio := 4.0
	if valor >= 10:
		cor = COR_GRANDE
		raio = 6.5
	elif valor >= 5:
		cor = COR_MEDIA
		raio = 5.2

	# A pulsacao e pequena de proposito: ela diz "isto e coletavel" sem virar um
	# ponto piscando, que competiria com o telegrafo.
	var pulso := 1.0 + sin(_t * 4.0) * 0.08
	var r := raio * pulso
	var corpo := PackedVector2Array([
		Vector2(0.0, -r), Vector2(r * 0.7, 0.0),
		Vector2(0.0, r), Vector2(-r * 0.7, 0.0),
	])
	# O contorno escuro primeiro: sem ele a ficha some sobre o chao claro de uma
	# sala e brilha demais sobre o escuro. Mesma razao do contorno na pixel art.
	var fundo := PackedVector2Array()
	for p in corpo:
		fundo.append(p * 1.35)
	draw_colored_polygon(fundo, Color(0.04, 0.05, 0.08, 0.85))
	draw_colored_polygon(corpo, cor)


## A sala limpou: o que sobrou no chao vem para o jogador.
##
## Ela nao confere QUAL sala: uma ficha so existe dentro da sala em que caiu, e
## comparar o dono custaria uma referencia que o pickup nao tem motivo para
## guardar. Uma ficha de outra sala ja esta liberada junto com ela.
func _ao_sala_limpa(_sala: Node2D) -> void:
	_atraido_sempre = true
