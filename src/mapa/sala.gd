class_name Sala
extends Node2D
## Uma sala do andar: contorno, portas, colisao de parede e o ciclo de combate.
##
## Decisao de design que este script carrega: a **forma da sala e desenhada uma
## vez so**, no Line2D "Parede". Colisao, limites de camera e os vaos das portas
## saem todos desses mesmos pontos, gerados em codigo no _ready. Nao existe
## tamanho de celula declarado em lugar nenhum -- se alguem arrastar um ponto do
## contorno no editor, a parede fisica acompanha sozinha. Sala em L, corredor e
## arena grande usam este mesmo script sem caso especial.
##
## Segunda decisao: porta sem vizinho do outro lado e SELADA, e parede passa
## reta por cima dela. Buraco para o vazio e pior que sala fechada.
##
## Terceira decisao: quem precisa de um ponto DENTRO da sala pergunta a ela, e
## nunca deduz do bounding box. O centro da caixa do L e o canto concavo (fora
## da sala) e o centro da sala de pilar e o pilar -- os dois casos ja nasceram o
## jogador dentro de geometria solida. ponto_seguro() e posicao_livre() existem
## para isso, e olham o contorno real mais os obstaculos.
##
## Quarta decisao: **a sala nao escolhe os proprios inimigos, so os coloca.**
## Quem decide quantos e quais e o GerenciadorMapa, uma vez, na montagem do
## andar -- e entrega a lista pronta em definir_composicao(). Antes isso morava
## num no "Ondas" dentro de cada .tscn, o que amarrava a dificuldade a qual cena
## caiu na celula: a sala inicial podia calhar de ser a arena grande com nove
## inimigos. Com a composicao vindo de fora, o gerador tem palavra sobre o ritmo
## do andar, e a sala continua sem saber que existe um andar.

enum Estado { INATIVA, OCUPADA, LIMPA }

## Layer 3 do project.godot. Parede colide com tudo e nao procura ninguem.
const LAYER_PAREDE := 4
## Sub-segmento menor que isso e ruido de arredondamento: vao encostando na
## quina do contorno. Criar a forma so daria uma colisao degenerada.
const COMPRIMENTO_MINIMO := 8.0
## Folga para aceitar que uma porta "esta sobre" um segmento do contorno.
const TOLERANCIA_ENCAIXE := 24.0
## Quanto o jogador entra na sala alem da boca da porta. Menos que isso e o
## lockdown fecha a parede em cima dele no mesmo frame da chegada.
const RECUO_ENTRADA := 48.0
## Folga exigida entre o corpo do jogador e qualquer parede ou obstaculo. O
## CollisionShape2D do player tem raio 11; o resto e margem para ele nao nascer
## raspando numa quina e ser empurrado para dentro do solido pela resolucao.
const FOLGA_CORPO := 24.0
## Quantas posicoes o spawn testa antes de aceitar a melhor que achou. Vinte e
## quatro cobre com folga a sala mais recortada, e o custo e uma vez por
## inimigo, uma vez por sala.
const TENTATIVAS_DE_SPAWN := 24
## Folga exigida em volta de um inimigo recem-colocado. Menor que a do jogador
## porque o corpo deles e menor, e porque exigir a mesma coisa faria o braco
## estreito da sala em L rejeitar quase todo ponto.
const FOLGA_SPAWN := 20.0
## Passo da varredura que procura ponto livre. Cada candidato e validado exato,
## entao o passo so decide o quao estreita pode ser uma passagem para ainda ser
## encontrada: 64 acha qualquer vao maior que isso e custa poucas centenas de
## testes na maior sala, uma vez so por sala.
const PASSO_VARREDURA := 32.0

## StringName e nao String porque este campo virou chave: o gerenciador e o
## minimapa comparam com os ids de DadosSala, e comparacao de StringName e por
## ponteiro. Os ids conhecidos moram em DadosSala (ID_BOSS, ID_ARMA...), entao
## ninguem precisa repetir string magica.
@export var tipo: StringName = DadosSala.ID_COMBATE

## Retangulo util onde os inimigos podem nascer, em coordenadas LOCAIS da sala.
## Quem monta uma sala no editor pensa nas coordenadas dela, nao nas do andar --
## e e isso que permite a mesma cena servir a varias celulas sem saber onde foi
## parar. O default cobre a sala padrao de 960x544 com margem de parede.
@export var area_spawn: Rect2 = Rect2(-352, -176, 704, 352)
## Distancia minima entre um inimigo recem-colocado e o jogador.
@export var distancia_minima_player: float = 180.0

var estado: Estado = Estado.INATIVA
var coordenadas_grid: Vector2i = Vector2i.ZERO

## Direcoes que o gerenciador confirmou ter vizinho. Vazio nao significa "sem
## vizinho": significa que ninguem configurou (sala aberta solta para teste).
## Por isso a flag separada -- sem ela, rodar a cena isolada selaria tudo.
var _conexoes: Array[Vector2] = []
var _conexoes_definidas: bool = false

var _portas_por_direcao: Dictionary = {}
var _raiz_portas: Node2D = null

## Cenas que esta sala vai colocar quando o jogador entrar. Vazia = sala sem
## combate, e e so isso que separa a de recompensa da de briga.
var _composicao: Array[PackedScene] = []
var _vivos: Array[Node] = []
var _container: Node2D = null
## Sala de recompensa nasce LIMPA no _ready, antes de o jogador existir por
## perto. Sem esta trava ela nunca anunciaria, e a tela de fim mostrava
## "9 / 10" numa run completa; anunciar no _ready contaria as dez salas do
## andar de uma vez, inclusive as que ninguem visitou.
var _anunciou_limpa: bool = false

## Area do contorno em pixels quadrados. Nao muda em runtime, e quem pergunta e
## o sorteio de composicao -- vale a pena pagar a conta uma vez so.
var _area_contorno: float = -1.0

## A geometria da sala nao muda em runtime, e a varredura e determinista: vale a
## pena pagar uma vez e devolver sempre o mesmo ponto. Nascer em lugar diferente
## a cada reentrada na mesma sala seria ruido, nao variedade.
var _ponto_seguro_local: Vector2 = Vector2.ZERO
var _ponto_seguro_pronto: bool = false


func _ready() -> void:
	add_to_group("salas")
	_mapear_portas()
	_selar_portas_sem_vizinho()
	_montar_paredes()


## Le as portas direto dos filhos de $Portas. Vale antes de add_child: o
## gerenciador instancia cada cena uma vez so para montar o catalogo de formas,
## e nesse momento a sala ainda nao esta na arvore.
func direcoes_disponiveis() -> Array[Vector2]:
	var lista: Array[Vector2] = []
	var raiz := get_node_or_null("Portas")
	if raiz == null:
		return lista
	for filho in raiz.get_children():
		var porta := filho as Porta
		if porta != null:
			lista.append(porta.vetor())
	return lista


## Chamado ANTES de add_child. So guarda -- quem age e o _ready, que ja tem as
## portas mapeadas e ainda nao montou parede nenhuma.
func configurar_conexoes(direcoes: Array[Vector2]) -> void:
	_conexoes = direcoes.duplicate()
	_conexoes_definidas = true


## O que vai nascer aqui quando o jogador entrar.
##
## Chamado pelo GerenciadorMapa depois do add_child e antes de ativar(). Lista
## vazia deixa a sala sem combate -- e o que a sala inicial, a de arma e a de
## item recebem.
func definir_composicao(cenas: Array[PackedScene]) -> void:
	_composicao = cenas.duplicate()


## Area do contorno em pixels quadrados, pela formula do shoelace.
##
## E a medida que o gerador usa para dar mais inimigos a uma sala maior. A area
## do bounding box nao serve: a sala em L teria a do retangulo inteiro e
## receberia inimigos para um pedaco que nao existe.
func area_do_contorno() -> float:
	if _area_contorno >= 0.0:
		return _area_contorno
	var pontos := contorno_local()
	var soma := 0.0
	for i in pontos.size():
		var a := pontos[i]
		var b := pontos[(i + 1) % pontos.size()]
		soma += a.x * b.y - b.x * a.y
	_area_contorno = absf(soma) * 0.5
	return _area_contorno


## Bounding box GLOBAL do contorno. E daqui que a camera tira os limites.
func obter_limites() -> Rect2:
	var pontos := _pontos_do_contorno()
	if pontos.is_empty():
		push_warning("Sala '%s': sem Line2D 'Parede', limites indefinidos." % name)
		return Rect2(global_position, Vector2.ZERO)
	var limites := Rect2(to_global(pontos[0]), Vector2.ZERO)
	for i in range(1, pontos.size()):
		limites = limites.expand(to_global(pontos[i]))
	return limites


## Posicao GLOBAL da porta daquele lado. Sem porta no lado pedido, cai no centro
## da sala -- ruim de ver, mas nunca teleporta o jogador para fora do mapa.
func boca_da_porta(direcao: Vector2) -> Vector2:
	var porta := _portas_por_direcao.get(direcao) as Porta
	if porta == null:
		return global_position
	return porta.global_position


## Onde largar o jogador que chegou andando em `direcao_vinda`: ele entra pela
## porta do lado oposto e ja aparece dentro da sala, nao em cima do vao.
func ponto_de_entrada(direcao_vinda: Vector2) -> Vector2:
	return boca_da_porta(-direcao_vinda) + direcao_vinda * RECUO_ENTRADA


## Ponto GLOBAL onde cabe um corpo do tamanho do jogador: dentro do contorno
## real, longe da parede e fora de qualquer obstaculo. Use isto sempre que
## precisar de "um lugar dentro da sala" sem uma porta para se guiar -- o centro
## do bounding box NAO serve, ele cai no entalhe do L e em cima do pilar.
func ponto_seguro() -> Vector2:
	if not _ponto_seguro_pronto:
		_ponto_seguro_local = _procurar_ponto_seguro()
		_ponto_seguro_pronto = true
	return to_global(_ponto_seguro_local)


## Aquele ponto GLOBAL comporta um corpo de raio `folga` sem entrar em parede
## nem em obstaculo? E o teste que falta a quem sorteia posicao (spawn de
## inimigo, pickup) para nao largar nada atras da parede.
func posicao_livre(ponto_global: Vector2, folga: float = FOLGA_CORPO) -> bool:
	var contorno := _pontos_do_contorno()
	if contorno.size() < 3:
		return true
	return _local_livre(to_local(ponto_global), contorno, folga)


## Idempotente de proposito: reentrar numa sala ja limpa nao pode recomecar o
## combate dela. Isso ja custou uma sessao inteira de playtest aqui.
##
## E aqui, e nao no _ready, que se decide se a sala tem combate: a composicao
## chega depois do add_child, entao no _ready a sala ainda nao sabe. Composicao
## vazia vira LIMPA na chegada, que e o mesmo comportamento que a sala de
## recompensa sempre teve.
func ativar() -> void:
	if estado == Estado.LIMPA:
		EventBus.sala_entrada.emit(self)
		_anunciar_limpa()
		return

	EventBus.sala_entrada.emit(self)

	if _composicao.is_empty():
		_limpar()
		return

	estado = Estado.OCUPADA
	_trancar_portas()
	_povoar()


func _mapear_portas() -> void:
	_portas_por_direcao.clear()
	_raiz_portas = get_node_or_null("Portas") as Node2D
	if _raiz_portas == null:
		return
	for filho in _raiz_portas.get_children():
		var porta := filho as Porta
		if porta != null:
			_portas_por_direcao[porta.vetor()] = porta


func _selar_portas_sem_vizinho() -> void:
	if not _conexoes_definidas:
		return
	for direcao in _portas_por_direcao:
		var porta := _portas_por_direcao[direcao] as Porta
		if not _conexoes.has(direcao):
			porta.selar()


## Coloca a composicao inteira de uma vez, no frame da entrada.
##
## Nao ha sequencia nem marcador de telegrafo. Telegrafo existe para o que
## aparece com o jogador ja dentro; aqui nada aparece depois -- ele entra e ja
## ve a sala como ela e.
##
## A composicao e consumida ao ser usada: se a sala for reativada por algum
## caminho, ela nao repovoa.
func _povoar() -> void:
	var cenas := _composicao
	_composicao = []

	var container := _container_de_inimigos()
	for cena in cenas:
		if cena == null:
			continue
		var inimigo := cena.instantiate() as Node2D
		if inimigo == null:
			continue
		# add_child ANTES de global_position: fora da arvore o setter cai no
		# position local e o pai reaplica a propria transform por cima, o que
		# desloca o spawn pelo offset da sala dentro do andar.
		container.add_child(inimigo)
		inimigo.global_position = _sortear_posicao()
		_vivos.append(inimigo)
		if inimigo.has_signal("morreu"):
			inimigo.morreu.connect(_ao_morrer_inimigo)

	EventBus.contagem_inimigos_mudou.emit(_contar_vivos())

	# Composicao que nao produziu ninguem (cena quebrada, array de nulos) nao
	# pode deixar a sala trancada para sempre.
	if _vivos.is_empty():
		_limpar()


## O container e criado quando a cena nao traz um. Assim uma sala nova serve
## para combate sem que quem a desenhou precise lembrar de um no de
## infraestrutura -- e a Diretora continua achando o container por get_parent(),
## como sempre fez.
func _container_de_inimigos() -> Node2D:
	if _container != null and is_instance_valid(_container):
		return _container
	_container = get_node_or_null("ContainerInimigos") as Node2D
	if _container == null:
		_container = Node2D.new()
		_container.name = "ContainerInimigos"
		add_child(_container)
	return _container


func _ao_morrer_inimigo(_posicao: Vector2) -> void:
	# O no ainda nao saiu da arvore neste frame; espera um quadro para contar.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var restantes := _contar_vivos()
	EventBus.contagem_inimigos_mudou.emit(restantes)
	if restantes == 0:
		_limpar()


## Poda e conta numa passada so.
##
## So conta quem a SALA colocou. Os invocados da Diretora nascem no mesmo
## container mas nao entram nesta lista, e e isso que preserva o contrato
## antigo: a sala do chefe fecha pela morte dele e por mais nada. Fosse
## contagem do container, um invocado sobrevivente seguraria a vitoria.
##
## Nota: Array.filter() devolve Array sem tipo, o que quebra a atribuicao de
## volta num Array[Node] tipado. Loop explicito e o caminho seguro em GDScript.
func _contar_vivos() -> int:
	var restantes: Array[Node] = []
	for n in _vivos:
		if is_instance_valid(n):
			restantes.append(n)
	_vivos = restantes
	return _vivos.size()


func _limpar() -> void:
	if estado == Estado.LIMPA:
		return
	estado = Estado.LIMPA
	_abrir_portas()
	_anunciar_limpa()


## Sorteia um ponto util longe do jogador e livre de parede e obstaculo, ja em
## coordenadas GLOBAIS.
##
## Duas armadilhas moram aqui, e as duas ja custaram tempo:
##
## 1. A conversao para global vem ANTES de medir a distancia. Comparar um ponto
##    local com a global_position do jogador mede espacos diferentes, e a
##    garantia de "nao nasce na cara dele" so valia por acidente na sala que
##    estivesse na origem do mundo.
## 2. Distancia do jogador nao basta. O sorteio antigo nao olhava geometria, e
##    nada impedia um inimigo de nascer dentro do pilar da sala 5 ou fora do
##    braco do L. posicao_livre() ja existia aqui e nao era usado.
##
## Nunca trava num loop: tenta um numero fixo de vezes e, se nada perfeito
## aparecer, aceita o melhor candidato livre; em ultimo caso, o ponto seguro da
## propria sala, que e o mesmo lugar onde o jogador nasceria.
func _sortear_posicao() -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var melhor := Vector2.ZERO
	var melhor_dist := -1.0

	for _tentativa in TENTATIVAS_DE_SPAWN:
		var ponto := to_global(Vector2(
			randf_range(area_spawn.position.x, area_spawn.end.x),
			randf_range(area_spawn.position.y, area_spawn.end.y)
		))
		if not posicao_livre(ponto, FOLGA_SPAWN):
			continue
		if player == null or not is_instance_valid(player):
			return ponto
		var d := ponto.distance_to(player.global_position)
		if d >= distancia_minima_player:
			return ponto
		if d > melhor_dist:
			melhor_dist = d
			melhor = ponto

	if melhor_dist >= 0.0:
		return melhor
	return ponto_seguro()


## Uma sala so conta como limpa uma vez. Quem escuta sala_limpa incrementa
## contador, entao reemitir ao reentrar inflaria a estatistica da run.
func _anunciar_limpa() -> void:
	if _anunciou_limpa:
		return
	_anunciou_limpa = true
	EventBus.sala_limpa.emit(self)


func _trancar_portas() -> void:
	for direcao in _portas_por_direcao:
		var porta := _portas_por_direcao[direcao] as Porta
		if not porta.esta_selada():
			porta.trancar()


func _abrir_portas() -> void:
	for direcao in _portas_por_direcao:
		var porta := _portas_por_direcao[direcao] as Porta
		if not porta.esta_selada():
			porta.abrir()


## Contorno da sala em coordenadas LOCAIS, para quem precisa da silhueta e nao
## so do bounding box -- o minimapa desenha a forma real, entao um Rect2 nao
## serve: a sala em L viraria um quadrado.
##
## O ultimo ponto do Line2D repete o primeiro para fechar o desenho. Aqui ele e
## removido, porque quem consome poligono (Geometry2D, draw_colored_polygon)
## trata o fechamento sozinho e engasga com o ponto duplicado.
func contorno_local() -> PackedVector2Array:
	var pontos := _pontos_do_contorno()
	if pontos.size() >= 2 and pontos[0].is_equal_approx(pontos[pontos.size() - 1]):
		pontos.remove_at(pontos.size() - 1)
	return pontos


## Pontos do contorno em coordenadas locais da sala. O Line2D pode ter offset
## proprio, entao a transform dele entra na conta.
func _pontos_do_contorno() -> PackedVector2Array:
	var parede := get_node_or_null("Parede") as Line2D
	if parede == null:
		return PackedVector2Array()
	var pontos := PackedVector2Array()
	for ponto in parede.points:
		pontos.append(parede.transform * ponto)
	return pontos


## Varredura determinista em coordenadas locais. O centro do bounding box e
## testado primeiro porque, quando ele serve, e o enquadramento que quem montou
## a sala espera; so quando ele cai em solido a grade entra, e entre os pontos
## validos vence o mais proximo desse centro -- assim a sala em L larga o
## jogador no braco, nao numa quina distante.
func _procurar_ponto_seguro() -> Vector2:
	var contorno := _pontos_do_contorno()
	if contorno.size() < 3:
		return Vector2.ZERO

	var caixa := Rect2(contorno[0], Vector2.ZERO)
	for i in range(1, contorno.size()):
		caixa = caixa.expand(contorno[i])

	var centro := caixa.get_center()
	if _local_livre(centro, contorno, FOLGA_CORPO):
		return centro

	var melhor := centro
	var melhor_distancia := INF
	var x := caixa.position.x
	while x <= caixa.end.x:
		var y := caixa.position.y
		while y <= caixa.end.y:
			var candidato := Vector2(x, y)
			var distancia := candidato.distance_squared_to(centro)
			if distancia < melhor_distancia and _local_livre(candidato, contorno, FOLGA_CORPO):
				melhor_distancia = distancia
				melhor = candidato
			y += PASSO_VARREDURA
		x += PASSO_VARREDURA

	if melhor_distancia == INF:
		push_warning("Sala '%s': nenhum ponto livre para o jogador; caindo no centro." % name)
	return melhor


func _local_livre(ponto: Vector2, contorno: PackedVector2Array, folga: float) -> bool:
	if not Geometry2D.is_point_in_polygon(ponto, contorno):
		return false
	# Dentro do contorno ainda pode ser em cima da parede: o teste de poligono
	# aceita o ponto colado na linha, e ali o corpo do jogador ja atravessa.
	for i in range(contorno.size() - 1):
		var perto := Geometry2D.get_closest_point_to_segment(ponto, contorno[i], contorno[i + 1])
		if perto.distance_to(ponto) < folga:
			return false
	return not _dentro_de_obstaculo(ponto, folga)


## Usa a propria forma de colisao do obstaculo contra um disco do tamanho do
## corpo: assim vale para retangulo, circulo ou poligono sem um caso por tipo.
func _dentro_de_obstaculo(ponto: Vector2, folga: float) -> bool:
	var raiz := get_node_or_null("Obstaculos")
	if raiz == null:
		return false
	var corpo := CircleShape2D.new()
	corpo.radius = folga
	var onde_o_corpo_esta := Transform2D(0.0, ponto)
	for forma in _formas_de(raiz):
		if forma.shape == null or forma.disabled:
			continue
		if forma.shape.collide(_transform_relativa(forma), corpo, onde_o_corpo_esta):
			return true
	return false


## Transform do no medida a partir DESTA sala, subindo a cadeia. Nao usa
## global_transform de proposito: assim a conta tambem vale para a instancia que
## o gerenciador cria fora da arvore so para ler o catalogo de formas.
func _transform_relativa(no: Node2D) -> Transform2D:
	var acumulada := Transform2D.IDENTITY
	var atual: Node2D = no
	while atual != null and atual != self:
		acumulada = atual.transform * acumulada
		atual = atual.get_parent() as Node2D
	return acumulada


func _formas_de(raiz: Node) -> Array[CollisionShape2D]:
	var lista: Array[CollisionShape2D] = []
	for filho in raiz.get_children():
		var forma := filho as CollisionShape2D
		if forma != null:
			lista.append(forma)
		lista.append_array(_formas_de(filho))
	return lista


func _montar_paredes() -> void:
	var pontos := _pontos_do_contorno()
	if pontos.size() < 2:
		return

	var corpo := StaticBody2D.new()
	corpo.name = "Paredes"
	corpo.collision_layer = LAYER_PAREDE
	corpo.collision_mask = 0
	add_child(corpo)

	for i in range(pontos.size() - 1):
		_criar_trecho(corpo, pontos[i], pontos[i + 1])


## Um lado do contorno vira uma ou mais colisoes, dependendo de quantas portas
## abrem vao nele. As formas nascem em codigo porque sub-resource declarado no
## .tscn e compartilhado entre todas as instancias da cena.
func _criar_trecho(corpo: StaticBody2D, inicio: Vector2, fim: Vector2) -> void:
	var comprimento := inicio.distance_to(fim)
	if comprimento <= COMPRIMENTO_MINIMO:
		return
	var direcao := (fim - inicio) / comprimento

	var vaos := _vaos_no_trecho(inicio, direcao, comprimento)
	vaos.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

	var cursor := 0.0
	for vao in vaos:
		var borda := clampf(vao.x, 0.0, comprimento)
		if borda - cursor > COMPRIMENTO_MINIMO:
			_adicionar_forma(corpo, inicio + direcao * cursor, inicio + direcao * borda)
		cursor = maxf(cursor, clampf(vao.y, 0.0, comprimento))

	if comprimento - cursor > COMPRIMENTO_MINIMO:
		_adicionar_forma(corpo, inicio + direcao * cursor, fim)


## Intervalos (inicio, fim) medidos ao longo do trecho onde a parede nao existe.
## Porta selada nao entra na lista: a parede passa reta por cima dela.
func _vaos_no_trecho(inicio: Vector2, direcao: Vector2, comprimento: float) -> Array[Vector2]:
	var vaos: Array[Vector2] = []
	for chave in _portas_por_direcao:
		var porta := _portas_por_direcao[chave] as Porta
		if porta.esta_selada():
			continue
		var ponto: Vector2 = _raiz_portas.transform * porta.position
		var avanco := (ponto - inicio).dot(direcao)
		if avanco < -TOLERANCIA_ENCAIXE or avanco > comprimento + TOLERANCIA_ENCAIXE:
			continue
		var mais_proximo := inicio + direcao * clampf(avanco, 0.0, comprimento)
		if ponto.distance_to(mais_proximo) > TOLERANCIA_ENCAIXE:
			continue
		var meia := Porta.LARGURA * 0.5
		vaos.append(Vector2(avanco - meia, avanco + meia))
	return vaos


func _adicionar_forma(corpo: StaticBody2D, de: Vector2, para: Vector2) -> void:
	var segmento := SegmentShape2D.new()
	segmento.a = de
	segmento.b = para
	var forma := CollisionShape2D.new()
	forma.shape = segmento
	corpo.add_child(forma)
