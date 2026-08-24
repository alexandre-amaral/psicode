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

var estado: Estado = Estado.INATIVA
var coordenadas_grid: Vector2i = Vector2i.ZERO

## Direcoes que o gerenciador confirmou ter vizinho. Vazio nao significa "sem
## vizinho": significa que ninguem configurou (sala aberta solta para teste).
## Por isso a flag separada -- sem ela, rodar a cena isolada selaria tudo.
var _conexoes: Array[Vector2] = []
var _conexoes_definidas: bool = false

var _portas_por_direcao: Dictionary = {}
var _raiz_portas: Node2D = null
var _ondas: GerenciadorOndas = null
## Sala de recompensa nasce LIMPA no _ready, antes de o jogador existir por
## perto. Sem esta trava ela nunca anunciaria, e a tela de fim mostrava
## "9 / 10" numa run completa; anunciar no _ready contaria as dez salas do
## andar de uma vez, inclusive as que ninguem visitou.
var _anunciou_limpa: bool = false

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
	_conectar_ondas()


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


## Idempotente de proposito: reentrar numa sala ja limpa nao pode recomecar as
## ondas dela. Isso ja custou uma sessao inteira de playtest aqui.
func ativar() -> void:
	if estado == Estado.LIMPA:
		EventBus.sala_entrada.emit(self)
		_anunciar_limpa()
		return

	estado = Estado.OCUPADA
	_trancar_portas()
	EventBus.sala_entrada.emit(self)

	if _ondas != null and not _ondas.rodando:
		_ondas.iniciar()


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


## Ondas sao OPCIONAIS: sala de recompensa nao tem no "Ondas". Sem combate a
## sala ja nasce aberta, senao o jogador entra e fica preso.
func _conectar_ondas() -> void:
	_ondas = get_node_or_null("Ondas") as GerenciadorOndas
	if _ondas == null:
		estado = Estado.LIMPA
		_abrir_portas()
		return
	# run_completa, nao onda_completa: a onda do chefe termina pela morte da
	# Diretora, nunca por contagem de indice. run_completa cobre os dois fins e
	# e o unico sinal que faz a sala do chefe abrir.
	_ondas.run_completa.connect(_ao_run_completa)


func _ao_run_completa(_venceu: bool) -> void:
	if estado == Estado.LIMPA:
		return
	estado = Estado.LIMPA
	_abrir_portas()
	_anunciar_limpa()


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
