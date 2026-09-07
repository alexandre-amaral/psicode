class_name BancadaDeOferta
extends Area2D
## Uma das tres bancadas da Loja: mostra o que esta a venda e fecha a compra.
##
## Ela e bancada e nao pedestal, e isso e a ficcao inteira do lugar: **a fabrica
## esta abandonada, a Loja nao.** Um pedestal elegante diria showroom; uma caixa
## industrial aberta com uma chapa soldada em cima diz que alguem ocupou um
## pedaco de uma fabrica morta e converteu sucata em comercio.
##
## ## A ORDEM da transacao e a issue inteira
##
## Validar a entrega ANTES de debitar. Um implante unico ja no bolso do jogador
## e recusado por `Modificadores.aplicar()`, e ele devolve `false` justamente
## para quem chama nao consumir o pickup -- se o credito saisse primeiro, o
## jogador pagaria por um implante que nao recebeu, e numa economia isso nao tem
## desfazer.
##
## `GameState.gastar_creditos()` tambem devolve `bool` e nao altera nada quando
## recusa. As duas garantias juntas sao o que torna a compra atomica sem
## precisar de transacao de verdade.
##
## ## E ela desenha ABAIXO do jogador
##
## `y_sort` resolve a ordem entre ela e quem anda na sala, mas o CONTEUDO a venda
## flutua acima da chapa -- e ele nao pode subir para a faixa do telegrafo. Uma
## Loja nao tem combate, mas o jogador atravessa a sala com projetil na tela
## quando entra fugindo de uma porta que acabou de abrir.

signal comprada(oferta: OfertaDeLoja)

## Quanto o jogador precisa chegar perto para o prompt aparecer.
const RAIO_DE_INTERACAO := 44.0

## A chapa da bancada, em px. 64 de largura da o vao de 64 a 96 entre centros que
## o plano pede sem os prompts se sobreporem.
const LARGURA := 56.0
const PROFUNDIDADE := 34.0

const COR_CAIXA := Color(0.20, 0.22, 0.28)
const COR_CHAPA := Color(0.30, 0.33, 0.40)
const COR_SOLDA := Color(0.42, 0.45, 0.52)
## O verde da economia, o mesmo da ficha e do contador da HUD: o jogador liga as
## tres coisas sem que nada explique.
const COR_PRECO := Color(0.62, 0.86, 0.72)
const COR_SEM_SALDO := Color(0.86, 0.42, 0.44)
const COR_VENDIDO := Color(0.38, 0.40, 0.46)

var oferta: OfertaDeLoja = null

var _jogador: Node2D = null
var _perto: bool = false
var _t: float = 0.0


func definir_oferta(nova: OfertaDeLoja) -> void:
	oferta = nova
	queue_redraw()


func _ready() -> void:
	monitoring = false
	monitorable = false
	y_sort_enabled = false
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _jogador == null or not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group("player") as Node2D
	var estava := _perto
	_perto = _jogador != null \
		and global_position.distance_to(_jogador.global_position) <= RAIO_DE_INTERACAO
	if _perto != estava:
		queue_redraw()
	if _perto and Input.is_action_just_pressed("interagir"):
		comprar()
	elif oferta != null and not oferta.vendida:
		# So redesenha quando ha o que animar: a bancada vendida e estatica, e
		# tres `queue_redraw` por frame numa sala parada e desperdicio.
		queue_redraw()


## Se a compra pode acontecer AGORA. Ela nao muda nada.
##
## Separada de `comprar()` de proposito: o prompt precisa da resposta sem
## executar, e um `comprar()` que "so testa" quando chamado de um lugar seria a
## mesma funcao afirmando duas coisas.
func pode_comprar() -> bool:
	return oferta != null and oferta.valida() and not oferta.vendida \
		and GameState.pode_pagar(oferta.preco)


## A transacao, e a ORDEM dela e o que esta issue existe para garantir.
##
## 1. o slot nao esta vendido
## 2. o saldo cobre
## 3. **o conteudo E ENTREGUE**
## 4. so entao o credito sai
##
## Trocar 3 e 4 de lugar e a forma de o jogador pagar por uma arma que nao
## recebeu. `Modificadores.aplicar()` RECUSA um implante unico que ele ja tenha,
## e devolve `false` exatamente para quem chama nao consumir o pickup -- este e
## o caso vivo, e nao um cenario hipotetico.
func comprar() -> bool:
	if not pode_comprar():
		if oferta != null and not oferta.vendida:
			EventBus.compra_recusada.emit(oferta)
		return false

	if not _entregar():
		# A entrega falhou e NADA saiu do bolso. E por isso que ela vem antes.
		EventBus.compra_recusada.emit(oferta)
		return false

	if not GameState.gastar_creditos(oferta.preco):
		# Nao deveria acontecer -- `pode_comprar()` acabou de conferir --, mas o
		# saldo e global e outra coisa pode te-lo mexido entre as duas linhas.
		# Sem esta guarda o jogador levaria o conteudo de graca.
		return false

	oferta.vendida = true
	comprada.emit(oferta)
	EventBus.compra_concluida.emit(oferta)
	queue_redraw()
	return true


## A Loja NAO implementa arma nem item.
##
## Ela chama o mesmo caminho dos pickups. Uma segunda logica de aquisicao
## divergiria da primeira, e o sintoma seria uma arma comprada se comportando
## diferente da mesma arma achada no chao -- sem erro nenhum, e so quando alguem
## comparasse as duas.
func _entregar() -> bool:
	if oferta.tipo == OfertaDeLoja.Tipo.ARMA:
		var jogador := get_tree().get_first_node_in_group("player")
		if jogador == null or not jogador.has_method("equipar_arma_loot"):
			return false
		jogador.equipar_arma_loot(oferta.conteudo as DadosArma)
		return true
	return Modificadores.aplicar(oferta.conteudo as DadosItem)


func _draw() -> void:
	var meia := LARGURA * 0.5
	var fundo := PROFUNDIDADE * 0.5

	# A CAIXA: um crate industrial aberto, visto de cima em Low Top-Down.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-meia, -fundo), Vector2(meia, -fundo),
		Vector2(meia, fundo), Vector2(-meia, fundo),
	]), COR_CAIXA)
	# A CHAPA soldada em cima, menor que a caixa: a borda que sobra e o que le
	# como "duas pecas diferentes juntadas", que e a ficcao do lugar.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-meia + 5.0, -fundo + 4.0), Vector2(meia - 5.0, -fundo + 4.0),
		Vector2(meia - 5.0, fundo - 6.0), Vector2(-meia + 5.0, fundo - 6.0),
	]), COR_CHAPA)
	# Os pontos de solda nos cantos. Sao quatro e sao pequenos: eles dizem
	# improviso sem virar detalhe que compete com o conteudo a venda.
	for canto in [Vector2(-meia + 8.0, -fundo + 7.0), Vector2(meia - 8.0, -fundo + 7.0),
			Vector2(-meia + 8.0, fundo - 9.0), Vector2(meia - 8.0, fundo - 9.0)]:
		draw_circle(canto, 1.6, COR_SOLDA)

	if oferta == null or not oferta.valida():
		return

	if oferta.vendida:
		# VENDIDO nao e ausencia: a bancada continua ali, vazia, e o vazio e a
		# informacao. Um pedestal que sumisse faria o jogador duvidar de ter
		# comprado.
		draw_line(Vector2(-meia + 10.0, 0.0), Vector2(meia - 10.0, 0.0),
			COR_VENDIDO, 2.0)
		return

	# O CONTEUDO flutua acima da chapa, com um bob curto. Ele nao sobe para a
	# faixa do telegrafo -- este no desenha na propria faixa e o `z_index` da
	# sala manda.
	var altura := -14.0 + sin(_t * 2.2) * 2.0
	var cor_do_conteudo := COR_PRECO if oferta.tipo == OfertaDeLoja.Tipo.ARMA \
		else Color(0.72, 0.78, 0.95)
	# ARMA e um losango deitado, ITEM e um hexagono: a forma diz o tipo antes de
	# o jogador chegar perto o bastante para ler o nome.
	if oferta.tipo == OfertaDeLoja.Tipo.ARMA:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-9.0, altura), Vector2(0.0, altura - 5.0),
			Vector2(9.0, altura), Vector2(0.0, altura + 5.0),
		]), cor_do_conteudo)
	else:
		var pontos := PackedVector2Array()
		for i in 6:
			pontos.append(Vector2(0.0, altura)
				+ Vector2.RIGHT.rotated(TAU * float(i) / 6.0) * 7.0)
		draw_colored_polygon(pontos, cor_do_conteudo)
