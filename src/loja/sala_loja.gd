class_name SalaLoja
extends Sala
## A sala de Loja: um posto de troca improvisado dentro da fabrica morta.
##
## **A fabrica esta abandonada. A Loja nao.** E esse contraste que ela existe
## para produzir, e ele nao vem de material novo: a sala usa a MESMA arquitetura
## do andar 1 -- o mesmo `Line2D "Parede"` gerando colisao, o mesmo
## `RenderizadorParedes` vestindo, o mesmo corpo de 48 com cap de 12 e quinas
## chanfradas. Geometria propria aqui reabriria o epico da caixa numa sala so.
##
## O que a torna Loja e o que se ACRESCENTA -- balcao, tres bancadas, luz de
## trabalho. Mesmo principio que o desgaste do chefe ja segue: com a carcaca
## desenhada, esconder um poligono nao tira nada; o que le e o que aparece.
##
## ## As ofertas chegam de fora, e nao sao sorteadas aqui
##
## Mesma divisao que a composicao de inimigos ja tem: quem DECIDE e o
## `GerenciadorMapa`, que conhece a semente do andar; quem APLICA e a sala. Uma
## Loja que sorteasse o proprio estoque no `_ready` mudaria de conteudo toda vez
## que o jogador entrasse, e "vendido continua vendido" viraria impossivel.
##
## E as ofertas sao os MESMOS objetos que o gerenciador guarda, por referencia --
## e isso que faz a venda persistir sem estado duplicado. Copiar aqui exigiria
## devolver o resultado, e um caminho de volta e onde as duas copias divergem.

## Onde as tres bancadas ficam, em relacao ao centro da sala.
##
## **64 a 96 px entre centros**, que e o que o plano pede: mais perto os prompts
## se sobrepoem e o jogador nao sabe qual bancada esta selecionando; mais longe
## elas deixam de ler como uma prateleira e viram tres moveis soltos.
const VAO_ENTRE_BANCADAS := 96.0
## Elas ficam acima do centro, entre o balcao e a entrada -- o jogador entra pelo
## sul, ve as tres, e o NPC fica atras delas.
const ALTURA_DAS_BANCADAS := -24.0
## **A 128 o balcao ficava na borda do quadro e o Sucateiro FORA dele.** A sala
## tem 640 de altura e o jogador entra pelo sul: com o clamp, o que ele ve na
## chegada e o terco de baixo. Um comerciante que so aparece depois de o jogador
## atravessar a sala nao diz "alguem ocupou este lugar" -- ele e uma surpresa
## depois da leitura, e nao a leitura.
const ALTURA_DO_BALCAO := -74.0

const COR_BALCAO := Color(0.18, 0.20, 0.26)
const COR_TAMPO := Color(0.28, 0.31, 0.38)
## A luz de trabalho: uma mancha quente e PEQUENA sobre as bancadas.
##
## Ela e o unico sinal de que ha energia funcionando neste pedaco do andar, e o
## contraste com o resto e a ficcao inteira. Pequena de proposito: iluminacao de
## shopping e o primeiro item da lista do que nao fazer.
## **A primeira versao era um borrao laranja, e ela lia como DECALQUE.** Tres
## aneis concentricos de alfa 0,10 somam 0,30 no centro sobre um chao que mede
## luma 20 -- o resultado e uma mancha desenhada no piso, e nao luz. E o circulo
## perfeito piorava: luminaria pendurada sobre bancada faz uma poca LARGA e
## baixa, e um circulo le como holofote de vitrine.
##
## Hoje ela e elipse, mais rasa, e cai depressa. A luz nao pode ser a coisa mais
## visivel da sala -- o que o jogador precisa achar sao as tres bancadas.
const COR_LUZ := Color(0.95, 0.84, 0.62, 0.045)
const RAIO_DA_LUZ := 150.0
## Quanto a poca e achatada. Menor que 1 = mais larga que alta.
const ACHATAMENTO_DA_LUZ := 0.45

var _ofertas: Array[OfertaDeLoja] = []
var _bancadas: Array[BancadaDeOferta] = []


## As ofertas desta Loja. Escrito ANTES do `ativar()`, como a composicao.
func definir_ofertas(ofertas: Array[OfertaDeLoja]) -> void:
	_ofertas = ofertas


## `ativar()` da Loja e idempotente pela mesma razao que o da sala de combate.
##
## Voltar a uma Loja ja visitada nao pode remontar as bancadas: as ofertas seriam
## as mesmas (elas vem do gerenciador), mas os nos novos perderiam o `vendida` do
## desenho e o jogador veria estoque que ja comprou.
func ativar() -> void:
	super.ativar()
	if _bancadas.is_empty():
		_montar_loja()


func _montar_loja() -> void:
	var raiz := Node2D.new()
	raiz.name = "Loja"
	raiz.y_sort_enabled = true
	add_child(raiz)

	# A LUZ vem primeiro, e ela desenha na faixa chapada do chao: uma mancha de
	# luz acima dos atores os pintaria de amarelo, e acima do telegrafo esconderia
	# o unico aviso que torna um ataque justo -- a Loja nao tem combate, mas o
	# jogador atravessa a porta com projetil na tela.
	var luz := _Luz.new()
	luz.z_index = Z_CHAO_DETALHE
	luz.z_as_relative = false
	luz.position = Vector2(0.0, ALTURA_DAS_BANCADAS)
	add_child(luz)

	var balcao := _Balcao.new()
	balcao.position = Vector2(0.0, ALTURA_DO_BALCAO)
	raiz.add_child(balcao)

	# O SUCATEIRO fica ATRAS do balcao, e nao ao lado das bancadas.
	#
	# Duas razoes: o balcao entre ele e o jogador e o que diz "este e o dono do
	# lugar" sem uma linha de texto, e a distancia mantem o prompt dele longe do
	# das bancadas -- os dois alcances se tocando fariam o jogador conversar
	# quando queria comprar.
	var npc := Sucateiro.new()
	npc.name = "Sucateiro"
	npc.position = Vector2(0.0, ALTURA_DO_BALCAO - 18.0)
	raiz.add_child(npc)

	var cena := load("res://src/loja/bancada_de_oferta.tscn") as PackedScene
	if cena == null:
		return
	# Centradas: com tres bancadas, a do meio fica no eixo da porta sul e as
	# outras duas a distancia igual. O jogador entra olhando para as tres.
	var inicio := -VAO_ENTRE_BANCADAS * float(_ofertas.size() - 1) * 0.5
	for i in _ofertas.size():
		var bancada := cena.instantiate() as BancadaDeOferta
		if bancada == null:
			continue
		raiz.add_child(bancada)
		bancada.position = Vector2(inicio + VAO_ENTRE_BANCADAS * float(i),
			ALTURA_DAS_BANCADAS)
		bancada.definir_oferta(_ofertas[i])
		_bancadas.append(bancada)


## O BALCAO: chapa industrial reaproveitada, com o tampo menor que a base.
##
## Ele nao vende nada -- a compra acontece nas bancadas, e a issue e explicita
## que ela nao pode depender de falar com ninguem. O balcao esta ali porque um
## comerciante sem balcao e um comerciante no meio do nada, e o lugar precisa
## parecer construido.
class _Balcao:
	extends Node2D

	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-96.0, -18.0), Vector2(96.0, -18.0),
			Vector2(96.0, 18.0), Vector2(-96.0, 18.0),
		]), SalaLoja.COR_BALCAO)

		# **DUAS CHAPAS DE TAMANHOS DIFERENTES, e nao um tampo so.** A laje
		# unica lia como movel comprado; o balcao tem de parecer duas pecas de
		# sucata soldadas -- e a EMENDA entre elas e o que diz isso.
		draw_colored_polygon(PackedVector2Array([
			Vector2(-90.0, -13.0), Vector2(6.0, -13.0),
			Vector2(6.0, 10.0), Vector2(-90.0, 10.0),
		]), SalaLoja.COR_TAMPO)
		draw_colored_polygon(PackedVector2Array([
			Vector2(10.0, -11.0), Vector2(90.0, -11.0),
			Vector2(90.0, 12.0), Vector2(10.0, 12.0),
		]), SalaLoja.COR_TAMPO.darkened(0.12))

		# Os rebites da chapa maior, e a solda da emenda.
		for x in [-78.0, -54.0, -30.0, -6.0]:
			draw_circle(Vector2(x, -9.0), 1.4, SalaLoja.COR_BALCAO.lightened(0.25))
		draw_line(Vector2(8.0, -13.0), Vector2(8.0, 12.0),
			SalaLoja.COR_TAMPO.lightened(0.30), 2.0)

		# E a bagunca de quem trabalha ali: caixas e uma peca sobre o tampo. Elas
		# ficam nas PONTAS, longe do meio -- o centro do balcao e por onde o
		# jogador olha para as bancadas.
		draw_colored_polygon(PackedVector2Array([
			Vector2(-86.0, -24.0), Vector2(-62.0, -24.0),
			Vector2(-62.0, -12.0), Vector2(-86.0, -12.0),
		]), SalaLoja.COR_BALCAO.lightened(0.10))
		draw_colored_polygon(PackedVector2Array([
			Vector2(62.0, -21.0), Vector2(84.0, -21.0),
			Vector2(84.0, -11.0), Vector2(62.0, -11.0),
		]), SalaLoja.COR_BALCAO.lightened(0.16))


class _Luz:
	extends Node2D

	func _draw() -> void:
		# Elipse por poligono: `draw_circle` nao aceita achatamento, e escalar o
		# no inteiro escalaria tambem o que viesse a ser desenhado depois.
		#
		# Quatro degraus em vez de tres, cada um mais fraco: a queda fica mais
		# suave e nenhum anel isolado aparece como borda.
		for i in 4:
			var fracao := 1.0 - float(i) * 0.22
			var pontos := PackedVector2Array()
			for k in 24:
				var a := TAU * float(k) / 24.0
				pontos.append(Vector2(
					cos(a) * SalaLoja.RAIO_DA_LUZ * fracao,
					sin(a) * SalaLoja.RAIO_DA_LUZ * fracao
						* SalaLoja.ACHATAMENTO_DA_LUZ))
			draw_colored_polygon(pontos, SalaLoja.COR_LUZ)
