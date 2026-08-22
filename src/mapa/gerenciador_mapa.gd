class_name GerenciadorMapa
extends Node2D
## Monta o andar inteiro: sorteia o grafo de salas, escolhe uma cena para cada
## celula, posiciona tudo no mundo, liga as vizinhas por corredor e conduz a
## travessia do jogador de uma sala para a outra.
##
## Quatro decisoes de design moram aqui:
##
## 1. **O jogador atravessa ANDANDO.** Nao existe teleporte nem fade entre
##    salas: elas ficam separadas por um vao real, ligadas por um Corredor, e a
##    camera acompanha sozinha porque o Camera2D do player ja tem
##    position_smoothing. O unico trabalho do gerenciador na travessia e abrir o
##    clamp da camera para a uniao origem+corredor+destino e fecha-lo de novo na
##    chegada.
##
## 2. **Layout em bandas, nao em grade de passo fixo.** As salas tem tamanhos
##    muito diferentes (1600x900, 2400x1350, 600x1600, 1600x1600). Multiplicar a
##    celula do grid por uma constante sobrepoe as grandes e deixa buraco entre
##    as pequenas. Aqui a largura de uma coluna e a da sala mais larga daquela
##    coluna, a altura de uma linha e a da sala mais alta daquela linha, e cada
##    sala fica centrada na propria banda. Isso da sobreposicao zero para
##    qualquer grafo e para qualquer conjunto de cenas, sem ninguem precisar
##    redimensionar um .tscn.
##
## 3. **O catalogo de formas sai das proprias cenas.** Nenhuma tabela dizendo
##    "a sala 2 tem porta Norte e Leste" vive neste script: cada cena e
##    instanciada uma unica vez no _ready so para responder
##    direcoes_disponiveis() e obter_limites(), e e liberada em seguida. Quem
##    move uma porta no editor nao precisa vir atualizar nada aqui.
##
## 4. **Sala com uma porta so nao "cabe" numa celula: e a celula que nasce
##    colada nela.** O chefe so tem porta Sul. Em vez de torcer para o passeio
##    aleatorio produzir uma celula que use exatamente essa direcao, o chefe e
##    pendurado numa celula nova, vizinha da celula mais distante da origem.
##    Mesma coisa para o tesouro, num beco sem saida que nao seja o do chefe.

## As quatro direcoes do grid. Vector2, nao Vector2i, porque e assim que Porta,
## Sala e EventBus falam de direcao.
const DIRECOES: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]

## Andar menor que isso vira um corredorzinho de duas salas e perde a sensacao
## de descoberta. Se o grafo sorteado nao chegar aqui, ele e sorteado de novo.
const MINIMO_SALAS := 8

## Chance de o passeio retomar de uma celula ja visitada em vez de seguir em
## frente. E o que cria ramo: sem isso o andar seria sempre uma cobra reta.
const CHANCE_BIFURCACAO := 0.35

const MAX_TENTATIVAS := 24

@export var cenas_salas: Array[PackedScene] = []
@export var cena_boss: PackedScene
@export var cena_tesouro: PackedScene
## Distancia livre entre duas bandas vizinhas: e o comprimento do corredor.
@export var vao_corredor: float = 420.0
## Quantas salas o andar tenta ter, contando chefe e tesouro.
@export var total_salas: int = 10
@export var largura_corredor: float = 120.0

var sala_atual: Sala = null

## PackedScene -> { "direcoes": Array[Vector2], "caixa": Rect2 }
var _catalogo: Dictionary = {}
## Vector2i -> Array[Vector2]. E o grafo: por celula, as direcoes que ela usa.
var _arestas: Dictionary = {}
var _cena_por_celula: Dictionary = {}
var _salas: Dictionary = {}
var _visitadas: Dictionary = {}
## Cada item: { "a": Vector2i, "b": Vector2i, "no": Corredor }
var _corredores: Array[Dictionary] = []

var _celula_chefe: Vector2i = Vector2i.ZERO
var _celula_tesouro: Vector2i = Vector2i.ZERO
var _tem_chefe: bool = false
var _tem_tesouro: bool = false

var _em_travessia: bool = false
var _sala_destino: Sala = null
var _direcao_travessia: Vector2 = Vector2.ZERO
## Trava de reentrancia: sair e chegar mexem em posicao do player, camera e
## estado de sala, e ambos rodam de dentro de um sinal de fisica.
var _ocupado: bool = false


func _ready() -> void:
	add_to_group("gerenciador_mapa")
	EventBus.porta_atravessada.connect(_ao_porta_atravessada)
	EventBus.sala_limpa.connect(_ao_sala_limpa)

	_montar_catalogo()
	if not _gerar_andar():
		return

	# A run comeca depois que o andar existe: iniciar_run zera total_salas, liga
	# a Deterioracao passiva e destrava o pause. Enquanto a arena morava em
	# main.tscn era ela quem chamava isto; hoje o dono do ciclo e o mapa.
	GameState.iniciar_run()
	GameState.total_salas = _salas.size()

	_chegar(Vector2i.ZERO, Vector2.ZERO)


# ------------------------------------------------------------ api publica ---

func celulas() -> Array[Vector2i]:
	var lista: Array[Vector2i] = []
	for celula in _arestas:
		lista.append(celula)
	return lista


## Direcoes em que aquela celula tem vizinho de verdade.
func vizinhos_de(pos_grid: Vector2i) -> Array[Vector2]:
	var lista: Array[Vector2] = []
	if not _arestas.has(pos_grid):
		return lista
	# Loop explicito: Array.duplicate() de dentro de Dictionary volta sem tipo.
	for direcao in _arestas[pos_grid]:
		lista.append(direcao)
	return lista


func celula_do_chefe() -> Vector2i:
	return _celula_chefe


## API de teste: o teste de fumaca nao tem como andar pelo corredor, entao ele
## pula direto para a sala e executa a chegada inteira (revelar, ativar, camera,
## sinais). Uma travessia em curso e desfeita antes, para nao sobrar destino
## pendurado.
func ir_para_sala(pos_grid: Vector2i) -> void:
	if not _salas.has(pos_grid):
		return
	if _em_travessia:
		_cancelar_travessia()
	_chegar(pos_grid, Vector2.ZERO)


# ------------------------------------------------------------- catalogo -----

func _montar_catalogo() -> void:
	_catalogo.clear()
	for cena in _todas_as_cenas():
		if cena == null or _catalogo.has(cena):
			continue
		var amostra := cena.instantiate() as Sala
		if amostra == null:
			push_error("GerenciadorMapa: %s nao tem o script Sala na raiz." % cena.resource_path)
			continue
		# A amostra entra na arvore por um instante: obter_limites() usa
		# transform global, e pedir transform global de no solto e erro de debug
		# no Godot. Ela nasce invisivel e sem processar, entao nada dela roda.
		amostra.visible = false
		amostra.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(amostra)
		var caixa := amostra.obter_limites()
		# Guardada relativa a origem da propria sala: quando o layout e
		# calculado, a posicao dela no mundo ainda nao existe.
		caixa.position -= amostra.global_position
		_catalogo[cena] = {
			"direcoes": amostra.direcoes_disponiveis(),
			"caixa": caixa,
		}
		remove_child(amostra)
		amostra.free()


func _todas_as_cenas() -> Array[PackedScene]:
	var lista: Array[PackedScene] = []
	for cena in cenas_salas:
		if cena != null:
			lista.append(cena)
	if cena_boss != null:
		lista.append(cena_boss)
	if cena_tesouro != null:
		lista.append(cena_tesouro)
	return lista


func _direcoes_da_cena(cena: PackedScene) -> Array[Vector2]:
	var lista: Array[Vector2] = []
	if cena == null or not _catalogo.has(cena):
		return lista
	for direcao in _catalogo[cena]["direcoes"]:
		lista.append(direcao)
	return lista


func _caixa_da_cena(cena: PackedScene) -> Rect2:
	if cena == null or not _catalogo.has(cena):
		return Rect2()
	return _catalogo[cena]["caixa"]


# --------------------------------------------------------------- grafo ------

func _gerar_andar() -> bool:
	if cenas_salas.is_empty():
		push_error("GerenciadorMapa sem cenas_salas: nao ha andar para gerar.")
		return false

	var alvo := maxi(3, total_salas)
	var minimo := mini(MINIMO_SALAS, alvo)

	for _tentativa in range(MAX_TENTATIVAS):
		if _tentar_grafo(alvo, minimo):
			_montar_andar()
			return true

	# Ultima chance com o piso baixo: um andar curto ainda e jogavel, nenhum nao.
	if _tentar_grafo(alvo, 2):
		push_warning("GerenciadorMapa: andar gerado com menos de %d salas." % minimo)
		_montar_andar()
		return true

	push_error("GerenciadorMapa: nenhuma combinacao de cenas serve ao grafo sorteado.")
	return false


func _tentar_grafo(alvo: int, minimo: int) -> bool:
	_arestas.clear()
	_cena_por_celula.clear()
	_tem_chefe = false
	_tem_tesouro = false

	var base := alvo
	if cena_boss != null:
		base -= 1
	if cena_tesouro != null:
		base -= 1
	_passear(maxi(1, base))

	if not _pendurar_chefe():
		return false
	_pendurar_tesouro()
	if not _escolher_cenas():
		return false
	return _arestas.size() >= minimo


## Passeio aleatorio sem ciclo: so liga celula nova, nunca duas ja existentes.
## A bifurcacao vem de retomar o passeio de uma celula qualquer ja visitada.
func _passear(alvo: int) -> void:
	_criar_celula(Vector2i.ZERO)
	var cursor := Vector2i.ZERO
	# O passeio pode se enfiar num canto sem saida; o contador evita que isso
	# vire loop infinito quando o alvo nao cabe mais em lugar nenhum.
	var seguranca := alvo * 40

	while _arestas.size() < alvo and seguranca > 0:
		seguranca -= 1

		if _arestas.size() > 1 and randf() < CHANCE_BIFURCACAO:
			cursor = _celula_aleatoria()

		var ordem := _direcoes_sorteadas()

		var avancou := false
		for direcao in ordem:
			var proxima := cursor + _para_grid(direcao)
			if _arestas.has(proxima):
				continue
			_criar_celula(proxima)
			_ligar(cursor, proxima, direcao)
			cursor = proxima
			avancou = true
			break

		if not avancou:
			cursor = _celula_aleatoria()


## Pendura a sala do chefe na celula mais distante da origem que aceite ela.
func _pendurar_chefe() -> bool:
	if cena_boss == null:
		return true
	var distancias := _distancias()
	var candidatos := celulas()
	candidatos.sort_custom(_mais_longe_primeiro(distancias))

	var criada := _pendurar(cena_boss, candidatos)
	if criada.is_empty():
		return false
	_celula_chefe = criada[0]
	_tem_chefe = true
	return true


## Tesouro em beco sem saida, longe da origem e nunca colado no chefe: premio de
## desvio so vale se custar um desvio.
func _pendurar_tesouro() -> void:
	if cena_tesouro == null:
		return
	var distancias := _distancias()
	var becos: Array[Vector2i] = []
	var demais: Array[Vector2i] = []
	for celula in _arestas:
		if _tem_chefe and (celula == _celula_chefe or _sao_vizinhas(celula, _celula_chefe)):
			continue
		if _grau(celula) <= 1:
			becos.append(celula)
		else:
			demais.append(celula)

	var por_distancia := _mais_longe_primeiro(distancias)
	becos.sort_custom(por_distancia)
	demais.sort_custom(por_distancia)
	becos.append_array(demais)

	var criada := _pendurar(cena_tesouro, becos)
	if criada.is_empty():
		return
	_celula_tesouro = criada[0]
	_tem_tesouro = true


## Cria uma celula nova encostada em alguma das ancoras, usando uma porta que a
## cena realmente tem. Devolve lista com a celula criada, ou vazia se nao coube.
func _pendurar(cena: PackedScene, ancoras: Array[Vector2i]) -> Array[Vector2i]:
	# _direcoes_da_cena ja devolve uma copia nova, entao embaralhar aqui nao
	# mexe no catalogo.
	var direcoes := _direcoes_da_cena(cena)
	direcoes.shuffle()
	for ancora in ancoras:
		for direcao in direcoes:
			# A celula nova olha para a ancora por `direcao`, logo ela fica do
			# lado oposto.
			var celula: Vector2i = ancora - _para_grid(direcao)
			if _arestas.has(celula):
				continue
			_criar_celula(celula)
			_ligar(celula, ancora, direcao)
			var resultado: Array[Vector2i] = [celula]
			return resultado
	var vazio: Array[Vector2i] = []
	return vazio


## Escolhe a cena de cada celula em ordem BFS. A ordem importa: quando nenhuma
## cena cobre todas as portas que a celula usa, a aresta aparada e sempre a que
## leva a um ramo ainda nao processado -- assim nada fica inalcancavel.
func _escolher_cenas() -> bool:
	_cena_por_celula.clear()
	if _tem_chefe:
		_cena_por_celula[_celula_chefe] = cena_boss
	if _tem_tesouro:
		_cena_por_celula[_celula_tesouro] = cena_tesouro

	var pais: Dictionary = {}
	for celula in _ordem_bfs(pais):
		if not _arestas.has(celula):
			continue
		var usadas := vizinhos_de(celula)

		if _cena_por_celula.has(celula):
			# Chefe e tesouro sao fixos: se a celula deles ganhou porta demais,
			# o grafo inteiro e sorteado de novo.
			if not _cobre(_direcoes_da_cena(_cena_por_celula[celula]), usadas):
				return false
			continue

		var candidatas := _cenas_que_servem(usadas)
		if not candidatas.is_empty():
			_cena_por_celula[celula] = candidatas.pick_random()
			continue

		var melhor := _melhor_cobertura(usadas, pais.get(celula, Vector2.ZERO))
		if melhor == null:
			return false
		_cena_por_celula[celula] = melhor
		var servidas := _direcoes_da_cena(melhor)
		for direcao in usadas:
			if not servidas.has(direcao):
				_podar(celula, direcao)

	if _tem_chefe and not _arestas.has(_celula_chefe):
		return false
	if _tem_tesouro and not _arestas.has(_celula_tesouro):
		_tem_tesouro = false
	for celula in _arestas:
		if not _cena_por_celula.has(celula):
			return false
	return true


## Corta a aresta e leva junto o ramo que dependia dela. Como o grafo e arvore,
## o outro lado nunca tem caminho alternativo -- deixar as celulas la seria
## deixa-las inalcancaveis.
func _podar(celula: Vector2i, direcao: Vector2) -> void:
	var vizinha := celula + _para_grid(direcao)
	_desligar(celula, vizinha, direcao)
	for perdida in _ramo_a_partir_de(vizinha):
		_arestas.erase(perdida)
		_cena_por_celula.erase(perdida)


func _ramo_a_partir_de(inicio: Vector2i) -> Array[Vector2i]:
	var achadas: Array[Vector2i] = []
	if not _arestas.has(inicio):
		return achadas
	var vistas: Dictionary = {inicio: true}
	var fila: Array[Vector2i] = [inicio]
	while not fila.is_empty():
		var atual: Vector2i = fila.pop_front()
		achadas.append(atual)
		for direcao in vizinhos_de(atual):
			var proxima := atual + _para_grid(direcao)
			if vistas.has(proxima):
				continue
			vistas[proxima] = true
			fila.append(proxima)
	return achadas


func _cenas_que_servem(usadas: Array[Vector2]) -> Array[PackedScene]:
	var lista: Array[PackedScene] = []
	for cena in cenas_salas:
		if cena == null or not _catalogo.has(cena):
			continue
		if _cobre(_direcoes_da_cena(cena), usadas):
			lista.append(cena)
	return lista


## Melhor cena quando nenhuma serve inteira. `obrigatoria` e a direcao do pai na
## BFS: perder essa porta desligaria a propria celula do andar.
func _melhor_cobertura(usadas: Array[Vector2], obrigatoria: Vector2) -> PackedScene:
	var melhor: PackedScene = null
	var melhor_nota := -1
	for cena in cenas_salas:
		if cena == null or not _catalogo.has(cena):
			continue
		var servidas := _direcoes_da_cena(cena)
		if obrigatoria != Vector2.ZERO and not servidas.has(obrigatoria):
			continue
		var nota := 0
		for direcao in usadas:
			if servidas.has(direcao):
				nota += 1
		if nota > melhor_nota:
			melhor_nota = nota
			melhor = cena
	return melhor


func _cobre(disponiveis: Array[Vector2], usadas: Array[Vector2]) -> bool:
	for direcao in usadas:
		if not disponiveis.has(direcao):
			return false
	return true


func _criar_celula(celula: Vector2i) -> void:
	if _arestas.has(celula):
		return
	var vazio: Array[Vector2] = []
	_arestas[celula] = vazio


func _ligar(de: Vector2i, para: Vector2i, direcao: Vector2) -> void:
	_criar_celula(de)
	_criar_celula(para)
	if not _arestas[de].has(direcao):
		_arestas[de].append(direcao)
	if not _arestas[para].has(-direcao):
		_arestas[para].append(-direcao)


func _desligar(de: Vector2i, para: Vector2i, direcao: Vector2) -> void:
	if _arestas.has(de):
		_arestas[de].erase(direcao)
	if _arestas.has(para):
		_arestas[para].erase(-direcao)


func _distancias() -> Dictionary:
	var distancias: Dictionary = {Vector2i.ZERO: 0}
	var fila: Array[Vector2i] = [Vector2i.ZERO]
	while not fila.is_empty():
		var atual: Vector2i = fila.pop_front()
		for direcao in vizinhos_de(atual):
			var proxima := atual + _para_grid(direcao)
			if distancias.has(proxima):
				continue
			distancias[proxima] = int(distancias[atual]) + 1
			fila.append(proxima)
	# Celula que o passeio criou solta nao existe, mas se existisse ficaria sem
	# distancia e derrubaria a ordenacao.
	for celula in _arestas:
		if not distancias.has(celula):
			distancias[celula] = 9999
	return distancias


## Ordem BFS a partir da origem; preenche `pais` com a direcao que leva de volta
## ao pai de cada celula.
func _ordem_bfs(pais: Dictionary) -> Array[Vector2i]:
	var ordem: Array[Vector2i] = []
	if not _arestas.has(Vector2i.ZERO):
		return ordem
	var vistas: Dictionary = {Vector2i.ZERO: true}
	var fila: Array[Vector2i] = [Vector2i.ZERO]
	while not fila.is_empty():
		var atual: Vector2i = fila.pop_front()
		ordem.append(atual)
		for direcao in vizinhos_de(atual):
			var proxima := atual + _para_grid(direcao)
			if vistas.has(proxima):
				continue
			vistas[proxima] = true
			pais[proxima] = -direcao
			fila.append(proxima)
	return ordem


## Comparador para ordenar celulas da mais distante da origem para a mais perto.
func _mais_longe_primeiro(distancias: Dictionary) -> Callable:
	return func(a: Vector2i, b: Vector2i) -> bool: return int(distancias[a]) > int(distancias[b])


## Copia embaralhada das quatro direcoes. Loop explicito porque copia de Array
## tipado que passa por metodo destipado volta sem tipo -- armadilha ja paga.
func _direcoes_sorteadas() -> Array[Vector2]:
	var lista: Array[Vector2] = []
	for direcao in DIRECOES:
		lista.append(direcao)
	lista.shuffle()
	return lista


func _celula_aleatoria() -> Vector2i:
	var lista := celulas()
	if lista.is_empty():
		return Vector2i.ZERO
	return lista[randi() % lista.size()]


func _grau(celula: Vector2i) -> int:
	return vizinhos_de(celula).size()


func _sao_vizinhas(a: Vector2i, b: Vector2i) -> bool:
	var delta := a - b
	return absi(delta.x) + absi(delta.y) == 1


func _para_grid(direcao: Vector2) -> Vector2i:
	return Vector2i(roundi(direcao.x), roundi(direcao.y))


# -------------------------------------------------------------- montagem ----

func _montar_andar() -> void:
	for sala in _salas.values():
		if is_instance_valid(sala):
			sala.queue_free()
	_salas.clear()
	_visitadas.clear()
	_corredores.clear()

	var centros := _centros_das_bandas()

	for celula in _arestas:
		var cena: PackedScene = _cena_por_celula[celula]
		var sala := cena.instantiate() as Sala
		if sala == null:
			continue
		sala.coordenadas_grid = celula
		# Antes do add_child de proposito: e o _ready da sala que sela as portas
		# sem vizinho e monta a parede em cima delas.
		sala.configurar_conexoes(vizinhos_de(celula))
		add_child(sala)
		sala.position = centros[celula] - _caixa_da_cena(cena).get_center()
		_salas[celula] = sala
		_ocultar(sala)

	_montar_corredores()


## Largura de cada coluna = a da sala mais larga daquela coluna; altura de cada
## linha = a da mais alta daquela linha. Prefixo-soma com o vao entre bandas da
## o centro de cada celula. O andar todo e deslocado para a celula de origem
## cair no (0,0) do mundo, que e onde o Player nasce em main.tscn.
func _centros_das_bandas() -> Dictionary:
	var larguras: Dictionary = {}
	var alturas: Dictionary = {}
	for celula in _arestas:
		var caixa := _caixa_da_cena(_cena_por_celula[celula])
		larguras[celula.x] = maxf(larguras.get(celula.x, 0.0), caixa.size.x)
		alturas[celula.y] = maxf(alturas.get(celula.y, 0.0), caixa.size.y)

	var centros_x := _prefixo(larguras)
	var centros_y := _prefixo(alturas)

	var origem := Vector2(centros_x.get(0, 0.0), centros_y.get(0, 0.0))
	var centros: Dictionary = {}
	for celula in _arestas:
		centros[celula] = Vector2(centros_x[celula.x], centros_y[celula.y]) - origem
	return centros


func _prefixo(tamanhos: Dictionary) -> Dictionary:
	var indices: Array = tamanhos.keys()
	indices.sort()
	var centros: Dictionary = {}
	var acumulado := 0.0
	for indice in indices:
		var tamanho: float = tamanhos[indice]
		centros[indice] = acumulado + tamanho * 0.5
		acumulado += tamanho + vao_corredor
	return centros


func _montar_corredores() -> void:
	for celula in _arestas:
		for direcao in vizinhos_de(celula):
			# Cada aresta aparece nas duas pontas; so a metade canonica monta.
			if direcao != Vector2.RIGHT and direcao != Vector2.DOWN:
				continue
			var vizinha: Vector2i = celula + _para_grid(direcao)
			var de: Sala = _salas.get(celula)
			var para: Sala = _salas.get(vizinha)
			if de == null or para == null:
				continue
			var corredor := Corredor.new()
			add_child(corredor)
			corredor.configurar(de.boca_da_porta(direcao), para.boca_da_porta(-direcao), largura_corredor)
			corredor.visible = false
			_corredores.append({"a": celula, "b": vizinha, "no": corredor})


# ------------------------------------------------------------ revelacao -----

func _ocultar(sala: Sala) -> void:
	sala.visible = false
	sala.process_mode = Node.PROCESS_MODE_DISABLED


## Sala revelada volta a existir para o jogo antes de o jogador chegar nela: e
## ela quem tem a parede e a porta que o corredor desemboca.
func _revelar(celula: Vector2i) -> void:
	var sala: Sala = _salas.get(celula)
	if sala == null:
		return
	_visitadas[celula] = true
	sala.visible = true
	sala.process_mode = Node.PROCESS_MODE_INHERIT

	# A sala so abre as portas dela quando esta limpa, e nasce trancada. Sem
	# isto o jogador anda o corredor inteiro e bate numa barreira pelo lado de
	# fora. Quem chega e que dispara ativar(), e ai ela tranca de novo.
	if sala.estado == Sala.Estado.INATIVA:
		_destrancar(sala)

	for ligacao in _corredores:
		if ligacao["a"] == celula or ligacao["b"] == celula:
			var no: Corredor = ligacao["no"]
			no.visible = true


## Sala nao expoe controle de porta individual, mas as portas sao filhas dela.
## Buscar por nome de filho direto e diferente de sair andando pela arvore com
## get_node("../.."): nao ha acoplamento com quem esta acima.
func _destrancar(sala: Sala) -> void:
	var raiz := sala.get_node_or_null("Portas")
	if raiz == null:
		return
	for filho in raiz.get_children():
		var porta := filho as Porta
		if porta != null and not porta.esta_selada():
			porta.abrir()


# ------------------------------------------------------------- travessia ----

## Uma unica porta de entrada para saida e chegada. Quem distingue os dois casos
## e de qual sala veio o sinal: da sala atual e saida, da sala destino e
## chegada. Nenhum estado extra precisa ser inventado.
func _ao_porta_atravessada(sala: Node2D, direcao: Vector2) -> void:
	var origem := sala as Sala
	if origem == null or _ocupado:
		return

	if _em_travessia:
		if origem == _sala_destino:
			_chegar(_sala_destino.coordenadas_grid, _direcao_travessia)
		elif origem == sala_atual:
			# Desistiu no meio do corredor e voltou pela mesma porta.
			_cancelar_travessia()
		return

	if origem != sala_atual:
		return
	var destino_grid := origem.coordenadas_grid + _para_grid(direcao)
	if not _salas.has(destino_grid):
		return
	_sair(direcao, _salas[destino_grid])


func _sair(direcao: Vector2, destino: Sala) -> void:
	_ocupado = true
	_em_travessia = true
	_sala_destino = destino
	_direcao_travessia = direcao

	_revelar(destino.coordenadas_grid)
	# Enquanto atravessa, a camera enxerga origem + corredor + destino; e o que
	# faz o deslize parecer intencional em vez de um corte.
	_clampar(_uniao_da_travessia(sala_atual, destino))
	EventBus.transicao_iniciada.emit(direcao, destino)
	_ocupado = false


func _chegar(celula: Vector2i, direcao: Vector2) -> void:
	var destino: Sala = _salas.get(celula)
	if destino == null:
		return
	_ocupado = true

	_revelar(celula)
	var player := _player()
	if player != null:
		player.global_position = _posicao_de_chegada(destino, direcao)

	sala_atual = destino
	_em_travessia = false
	_sala_destino = null
	_direcao_travessia = Vector2.ZERO

	_clampar(destino.obter_limites())
	# ativar() e idempotente: reentrar numa sala ja limpa nao recomeca as ondas.
	destino.ativar()
	EventBus.transicao_concluida.emit(destino)
	_ocupado = false


func _cancelar_travessia() -> void:
	_em_travessia = false
	_sala_destino = null
	_direcao_travessia = Vector2.ZERO
	if sala_atual != null:
		_clampar(sala_atual.obter_limites())


## `direcao` e o sentido da caminhada, nao o lado da porta que avisou: quem
## chega andando para o leste entra pela porta oeste da sala nova.
func _posicao_de_chegada(destino: Sala, direcao: Vector2) -> Vector2:
	if direcao == Vector2.ZERO:
		return destino.obter_limites().get_center()
	return destino.ponto_de_entrada(direcao)


func _uniao_da_travessia(origem: Sala, destino: Sala) -> Rect2:
	var uniao := destino.obter_limites()
	if origem != null:
		uniao = uniao.merge(origem.obter_limites())
		var corredor := _corredor_entre(origem.coordenadas_grid, destino.coordenadas_grid)
		if corredor != null:
			uniao = uniao.merge(corredor.obter_limites())
	return uniao


func _corredor_entre(a: Vector2i, b: Vector2i) -> Corredor:
	for ligacao in _corredores:
		var de: Vector2i = ligacao["a"]
		var para: Vector2i = ligacao["b"]
		if (de == a and para == b) or (de == b and para == a):
			return ligacao["no"]
	return null


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _clampar(limites: Rect2) -> void:
	if limites.size == Vector2.ZERO:
		return
	var player := _player()
	if player == null:
		return
	var camera := player.get_node_or_null("Camera") as Camera2D
	if camera == null:
		return
	camera.limit_left = roundi(limites.position.x)
	camera.limit_top = roundi(limites.position.y)
	camera.limit_right = roundi(limites.end.x)
	camera.limit_bottom = roundi(limites.end.y)


# ----------------------------------------------------------- ciclo da run ---

func _ao_sala_limpa(sala: Node2D) -> void:
	GameState.salas_limpas += 1
	var limpa := sala as Sala
	if limpa != null and limpa.tipo == "boss":
		GameState.terminar_run(true)
