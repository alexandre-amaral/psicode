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
##
## ## O ICONE, e por que so no ITEM
##
## Esta e a leitura mais cara do jogo: a bancada cobra ate 30 creditos de uma
## renda de andar medida em 35-55, e o jogador decide olhando o que flutua sobre
## a chapa. Um hexagono de cor nao sustenta essa decisao, e o icone de 64 px do
## implante sustenta.
##
## A oferta de ARMA nao muda. Arma esta fora do epico dos icones -- ela ja tem
## identidade propria (silhueta de projetil, cor, rastro) -- e um placeholder
## naquele lugar seria pior que o losango de hoje, que ao menos e consistente.

signal comprada(oferta: OfertaDeLoja)

## Quanto o jogador precisa chegar perto para o prompt aparecer.
const RAIO_DE_INTERACAO := 44.0

## Os dois sons da transacao. Eles sao o MESMO gesto -- a trava do balcao
## girando --, e o que muda e se ela completa: dois sons sem relacao fariam a
## recusa parecer erro do jogo em vez de resposta do lugar.
const SOM_OK := "res://assets/audio/compra_ok.wav"
const SOM_FALHA := "res://assets/audio/compra_falha.wav"

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

## Onde o conteudo a venda flutua, e o quanto ele sobe e desce.
const ALTURA_DO_CONTEUDO := -14.0
const AMPLITUDE_DO_BOB := 2.0
## As duas linhas do prompt, contadas do centro da bancada.
const ALTURA_DO_NOME := -34.0
const ALTURA_DO_PRECO := -22.0

## O lado do icone desenhado, em px de tela -- e ele e METADE do arquivo.
##
## **Escala de pixel art e inteira**, e 64 -> 32 e a unica reducao aqui que nao
## reamostra: cada pixel de tela cai sobre um pixel do arquivo. 48, o tamanho
## que `tools/itens/laboratorio_icones.gd` supos para a bancada antes de este
## layout existir, e 0,75 -- borra a peca e ainda cobriria o prompt inteiro.
## E 32 e o pior contexto que a regua ja mede, entao nenhum icone chega aqui sem
## ter provado que se distingue dos outros quinze neste tamanho.
const ICONE_LADO := 32.0

## Quanto o prompt sobe quando ha icone.
##
## O icone e mais alto que o losango, e o preco tem de continuar LEGIVEL: sem
## esta subida a linha do preco cairia dentro da peca, e a ficha desenhada --
## que existe porque o glifo da moeda nao existe na fonte -- sumiria no meio do
## desenho. Ele sobe o bastante para o conteudo passar por baixo, e nem um pixel
## alem: o prompt precisa continuar ancorado NESTA bancada e nao pairando entre
## as tres.
const SUBIDA_DO_PROMPT_COM_ICONE := 16.0

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
			Audio.tocar(load(SOM_FALHA) as AudioStream)
			EventBus.compra_recusada.emit(oferta)
		return false

	if not _entregar():
		# A entrega falhou e NADA saiu do bolso. E por isso que ela vem antes.
		Audio.tocar(load(SOM_FALHA) as AudioStream)
		EventBus.compra_recusada.emit(oferta)
		return false

	if not GameState.gastar_creditos(oferta.preco):
		# Nao deveria acontecer -- `pode_comprar()` acabou de conferir --, mas o
		# saldo e global e outra coisa pode te-lo mexido entre as duas linhas.
		# Sem esta guarda o jogador levaria o conteudo de graca.
		return false

	oferta.vendida = true
	Audio.tocar(load(SOM_OK) as AudioStream)
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


## O icone do que esta a venda, ou `null` quando nao ha.
##
## Ela PERGUNTA a propriedade em vez de fingir interface, pelo mesmo caminho de
## `OfertaDeLoja.nome()`: `DadosArma` e `DadosItem` nao tem base comum, e uma
## oferta que ganhasse um campo `icone` passaria a carregar duas verdades sobre
## o mesmo recurso -- a do `.tres` e a copiada.
##
## E o `null` nao e defensividade inutil. `DadosItem.icone` e OPCIONAL e tem de
## continuar sendo: e ele que permite um implante novo nascer antes da arte
## dele, e aqui a ausencia cai na forma de hoje em vez de deixar a bancada
## vazia.
func _icone_da_oferta() -> Texture2D:
	if oferta == null or oferta.conteudo == null:
		return null
	# Arma fica de fora ate por engano: se um dia `DadosArma` ganhar um campo de
	# mesmo nome, ela continua com o losango ate alguem decidir o contrario.
	if oferta.tipo != OfertaDeLoja.Tipo.ITEM:
		return null
	return oferta.conteudo.get(&"icone") as Texture2D


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

	var icone := _icone_da_oferta()
	# **O prompt sobe junto com o conteudo, e nunca o contrario.** O icone e mais
	# alto que o losango, e cravar a linha do preco a deixaria DENTRO da peca --
	# com a ficha desenhada, que existe porque o glifo da moeda nao existe na
	# fonte, sumindo no meio do desenho.
	var subida := SUBIDA_DO_PROMPT_COM_ICONE if icone != null else 0.0

	# O PROMPT so aparece perto, e ele e a UI inteira da compra.
	#
	# **Nada de menu de tela cheia.** Abrir um painel para comprar tiraria o
	# jogador da sala -- e a sala e o que a Loja tem de dizer. O nome, o preco e a
	# tecla cabem em duas linhas acima da bancada.
	if _perto and oferta != null and oferta.valida() and not oferta.vendida:
		var fonte := ThemeDB.fallback_font
		var tamanho := 10
		var titulo := oferta.nome()
		# **O LOSANGO E DESENHADO, e nao escrito.** `ThemeDB.fallback_font` nao
		# tem o glifo, e um caractere que nao existe some sem erro -- o preco
		# aparecia como "12   [E]", com um buraco onde deveria estar a moeda.
		var custo := "%d      [E]" % oferta.preco
		# Vermelho quando nao da: a recusa tem de ser legivel ANTES de o jogador
		# apertar, senao ele aprende a apertar e ser recusado.
		var cor_do_custo := COR_PRECO if GameState.pode_pagar(oferta.preco) 			else COR_SEM_SALDO
		var largura := fonte.get_string_size(titulo, HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, tamanho).x
		draw_string(fonte, Vector2(-largura * 0.5, ALTURA_DO_NOME - subida), titulo,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, tamanho, Color(0.86, 0.88, 0.94))
		var largura_custo := fonte.get_string_size(custo, HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, tamanho).x
		var linha := ALTURA_DO_PRECO - subida
		draw_string(fonte, Vector2(-largura_custo * 0.5, linha), custo,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, tamanho, cor_do_custo)
		# A ficha, do mesmo tamanho do texto e na mesma cor: e ela que liga o
		# preco ao que o jogador cata no chao.
		var x := -largura_custo * 0.5 + fonte.get_string_size(
			"%d " % oferta.preco, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tamanho).x + 4.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, linha - 8.0), Vector2(x + 3.0, linha - 4.0),
			Vector2(x, linha), Vector2(x - 3.0, linha - 4.0),
		]), cor_do_custo)

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
	var altura := ALTURA_DO_CONTEUDO + sin(_t * 2.2) * AMPLITUDE_DO_BOB
	# O ICONE TOMA O LUGAR DA FORMA, e nao se soma a ela: dois desenhos do mesmo
	# implante, um por cima do outro, sao ruido -- e a peca ja passou pela regua
	# de distinguibilidade justamente para nao precisar de apoio.
	if icone != null:
		draw_texture_rect(icone, Rect2(
			Vector2(-ICONE_LADO * 0.5, altura - ICONE_LADO * 0.5),
			Vector2(ICONE_LADO, ICONE_LADO)), false)
		return

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
