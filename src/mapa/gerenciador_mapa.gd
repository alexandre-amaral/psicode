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
##    muito diferentes (960x544, 1440x800, 768x960, 960x960). Multiplicar a
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
## 4. **Sala especial nao "cabe" numa celula: e a celula que nasce colada
##    nela.** O chefe so tem porta Sul, e torcer para o passeio aleatorio
##    produzir uma celula que use exatamente essa direcao nao funciona. Entao
##    toda sala marcada como PENDURADA em `DadosSala` ganha uma celula nova,
##    encostada numa ancora escolhida pela regra do proprio tipo (mais distante
##    da origem, beco sem saida, distancia minima). Quem chega primeiro escolhe
##    melhor, e por isso existe `prioridade`: o chefe vem antes dos premios.

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

## Todos os tipos de sala do andar, cada um com a propria regra de colocacao.
## Substituiu os tres exports separados (cenas_salas/cena_boss/cena_tesouro) e
## as duas funcoes `_pendurar_X` copiadas uma da outra: tipo novo agora e um
## .tres a mais nesta lista, sem uma linha de GDScript.
@export var tipos_de_sala: Array[DadosSala] = []
## Distancia livre entre duas bandas vizinhas: e o comprimento do corredor.
@export var vao_corredor: float = 256.0
## Quantas salas o andar tenta ter, contando as penduradas.
@export var total_salas: int = 10
@export var largura_corredor: float = 80.0

var sala_atual: Sala = null

## PackedScene -> { "direcoes": Array[Vector2], "caixa": Rect2 }
var _catalogo: Dictionary = {}
## Vector2i -> DadosSala. Guarda o TIPO de cada celula, nao so a cena: e daqui
## que saem cor e icone do minimapa e a regra de fim de run.
var _dados_por_celula: Dictionary = {}
## Vector2i -> StringName. So as celulas reservadas para tipo pendurado.
var _reservadas: Dictionary = {}
## Ligacoes ja resolvidas para quem desenha. Mesmo motivo do cache de contorno.
var _ligacoes_cache: Array[Dictionary] = []
## Vector2i -> PackedVector2Array. Contorno ja em coordenadas de mundo.
## Geometria de sala nao muda em runtime, entao vale cachear uma vez e poupar
## o minimapa de refazer to_global por sala a cada redesenho.
var _contornos: Dictionary = {}
## Vector2i -> Array[Vector2]. E o grafo: por celula, as direcoes que ela usa.
var _arestas: Dictionary = {}
var _cena_por_celula: Dictionary = {}
## Vector2i -> Array[PackedScene]. Decidido UMA VEZ, na montagem do andar, e
## entregue a cada sala antes de o jogador andar um passo. E a diferenca entre
## "a sala escolhe seus inimigos quando voce entra" e "o andar ja nasce com a
## dificuldade distribuida".
var _composicao_por_celula: Dictionary = {}
var _salas: Dictionary = {}
var _visitadas: Dictionary = {}
## Cada item: { "a": Vector2i, "b": Vector2i, "no": Corredor }
var _corredores: Array[Dictionary] = []


var _em_travessia: bool = false
var _sala_destino: Sala = null
var _direcao_travessia: Vector2 = Vector2.ZERO
## Trava de reentrancia: sair e chegar mexem em posicao do player, camera e
## estado de sala, e ambos rodam de dentro de um sinal de fisica.
var _ocupado: bool = false

## Zoom que o Camera2D do player traz da propria cena, lido no primeiro clamp.
## E o valor para o qual o enquadramento volta em toda sala que cabe na tela.
var _zoom_base: float = 0.0


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

	# ANTES do _chegar: a HUD e o primeiro filho de main.tscn, entao o _ready
	# dela roda antes deste e o minimapa nasce sem gerenciador. Este sinal e o
	# aviso de que o andar existe -- se ele fosse emitido depois do _chegar, a
	# primeira transicao_concluida chegaria num minimapa ainda sem layout.
	EventBus.andar_gerado.emit()

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


## Onde esta a sala que encerra a run. O teste de fumaca depende disto para
## deixar o chefe por ultimo no percurso.
func celula_do_chefe() -> Vector2i:
	return primeira_celula_do_tipo(DadosSala.ID_BOSS)


## Vector2i.ZERO quando o tipo nao entrou no andar -- e o mesmo valor que
## `celula_do_chefe` devolvia antes quando nao havia chefe.
func primeira_celula_do_tipo(id: StringName) -> Vector2i:
	for celula in _reservadas:
		if _reservadas[celula] == id:
			return celula
	return Vector2i.ZERO


# ------------------------------------------------- api para quem desenha ----
# O minimapa consome SO daqui. Nada de _visitadas, _salas ou _contornos vazando:
# ele acha este no por grupo (a excecao legitima ao EventBus) e pergunta.

## O tipo daquela celula, com cor e icone. null quando a celula nao existe.
## Quantos inimigos aquela celula recebeu na montagem. Existe para diagnostico
## e teste: e o unico jeito de medir a curva de dificuldade do andar sem jogar.
func composicao_da_celula(celula: Vector2i) -> Array[PackedScene]:
	var vazio: Array[PackedScene] = []
	return _composicao_por_celula.get(celula, vazio)


func dados_da_celula(celula: Vector2i) -> DadosSala:
	return _dados_por_celula.get(celula)


func celula_atual() -> Vector2i:
	if sala_atual == null:
		return Vector2i.ZERO
	return sala_atual.coordenadas_grid


## Fica true em `_sair()`, ou seja, quando o jogador entra no corredor -- o
## mesmo instante em que a sala acende no mundo. E de proposito: o minimapa
## acompanha o que a tela mostra, nao a chegada.
func foi_visitada(celula: Vector2i) -> bool:
	return _visitadas.has(celula)


func esta_limpa(celula: Vector2i) -> bool:
	var sala: Sala = _salas.get(celula)
	if sala == null:
		return false
	return sala.estado == Sala.Estado.LIMPA


## Visitada, ou vizinha de alguma visitada. E a regra de nevoa do minimapa, e
## espelha o que o mundo ja faz: `_revelar` so acende o corredor cujas duas
## pontas sao conhecidas, para nao existir caminho iluminado terminando no
## escuro.
func e_conhecida(celula: Vector2i) -> bool:
	if _visitadas.has(celula):
		return true
	for direcao in vizinhos_de(celula):
		if _visitadas.has(celula + _para_grid(direcao)):
			return true
	return false


## Contorno real da sala em coordenadas de mundo, sem o ponto repetido de
## fechamento. Vazio quando a celula nao existe.
func contorno_global_de(celula: Vector2i) -> PackedVector2Array:
	return _contornos.get(celula, PackedVector2Array())


## Bounding box de todas as salas e corredores. E a base da escala unica do
## minimapa: como o layout e em bandas, normalizar por celula distorceria as
## distancias.
func limites_do_andar() -> Rect2:
	var limites := Rect2()
	var primeiro := true
	for celula in _salas:
		var sala: Sala = _salas[celula]
		if not is_instance_valid(sala):
			continue
		var caixa := sala.obter_limites()
		if primeiro:
			limites = caixa
			primeiro = false
		else:
			limites = limites.merge(caixa)
	for ligacao in _corredores:
		var no: Corredor = ligacao["no"]
		if not is_instance_valid(no):
			continue
		var caixa := no.obter_limites()
		if primeiro:
			limites = caixa
			primeiro = false
		else:
			limites = limites.merge(caixa)
	return limites


## Cada item: { "a": Vector2i, "b": Vector2i, "caixa": Rect2 }. Retangulo real
## do corredor, nao uma linha entre centros -- o minimapa desenha forma, entao
## a ligacao tambem e forma.
## Devolve a lista cacheada, sem copiar: o minimapa redesenha a cada frame por
## causa do pulso da sala atual, e remontar isto 60 vezes por segundo seria
## desperdicio puro. Quem consome trata como somente-leitura.
func ligacoes() -> Array[Dictionary]:
	return _ligacoes_cache


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
	for dados in _tipos_validos():
		for cena in dados.cenas_validas():
			if not lista.has(cena):
				lista.append(cena)
	return lista


## Tipos utilizaveis: com cena e sem buraco deixado pelo Inspetor. Loop
## explicito porque filter() devolve Array sem tipo.
func _tipos_validos() -> Array[DadosSala]:
	var lista: Array[DadosSala] = []
	for dados in tipos_de_sala:
		if dados != null and not dados.cenas_validas().is_empty():
			lista.append(dados)
	return lista


## Penduradas em ordem de prioridade. A ordem e o que faz `evita_vizinhanca_de`
## funcionar: so da para fugir de quem ja foi colocado, entao o chefe precisa
## vir antes de quem foge dele.
func _tipos_pendurados() -> Array[DadosSala]:
	var lista: Array[DadosSala] = []
	for dados in _tipos_validos():
		if dados.eh_pendurada():
			lista.append(dados)
	lista.sort_custom(func(a: DadosSala, b: DadosSala) -> bool: return a.prioridade < b.prioridade)
	return lista


## Tipos que o passeio aleatorio pode usar para preencher o andar. A INICIAL
## fica de fora: ela tem celula propria e sortea-la no meio do andar poria o
## jogador diante de uma segunda sala de entrada, vazia e sem proposito.
func _tipos_de_preenchimento() -> Array[DadosSala]:
	var lista: Array[DadosSala] = []
	for dados in _tipos_validos():
		if not dados.eh_pendurada() and not dados.eh_inicial():
			lista.append(dados)
	return lista


## O tipo da celula de origem. Sem ele o andar ainda gera -- a origem so vira
## uma sala de combate como antes -- entao vale um aviso, nao um erro.
func _tipo_inicial() -> DadosSala:
	for dados in _tipos_validos():
		if dados.eh_inicial():
			return dados
	return null


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
	if _tipos_de_preenchimento().is_empty():
		push_error("GerenciadorMapa sem tipo de sala de preenchimento: nao ha andar para gerar.")
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
	_dados_por_celula.clear()
	_reservadas.clear()

	# O passeio so produz as celulas COMUM: cada pendurada traz a propria.
	var reservadas := 0
	for dados in _tipos_pendurados():
		reservadas += dados.celulas_reservadas()
	_passear(maxi(1, alvo - reservadas))
	_reservar_inicial()

	if not _pendurar_especiais():
		return false
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


## Fixa a sala de entrada na origem do andar, que e onde o passeio sempre
## comeca e onde o Player nasce em main.tscn.
##
## Ela entra pelo mesmo caminho de uma PENDURADA -- `_reservadas` -- e nao por
## um caso especial em _escolher_cenas. Isso reaproveita a conferencia de
## cobertura de portas que ja existe la e traz de graca a regra de
## `_celula_aceita`: nada pendurado encosta numa celula reservada, entao nenhum
## premio nem o chefe nascem colados na entrada.
##
## Precisa vir ANTES de _pendurar_especiais pelo mesmo motivo.
func _reservar_inicial() -> void:
	var dados := _tipo_inicial()
	if dados == null:
		push_warning("GerenciadorMapa: nenhum tipo de sala inicial; a origem vira sala comum.")
		return
	var cenas := dados.cenas_validas()
	if cenas.is_empty():
		return
	_reservadas[Vector2i.ZERO] = dados.id
	_dados_por_celula[Vector2i.ZERO] = dados
	_cena_por_celula[Vector2i.ZERO] = cenas.pick_random()


## Coloca todas as salas PENDURADA, em ordem de prioridade. Devolve false so
## quando um tipo obrigatorio nao coube -- ai o grafo inteiro e sorteado de
## novo, que e exatamente o que `_pendurar_chefe` fazia antes.
##
## Tipo opcional que nao cabe simplesmente nao aparece no andar: derrubar 24
## tentativas de grafo por causa de um premio sai caro, e o andar sem ele
## continua jogavel.
func _pendurar_especiais() -> bool:
	for dados in _tipos_pendurados():
		for _n in range(dados.celulas_reservadas()):
			var criada := _pendurar(dados)
			if not criada.is_empty():
				continue
			if not dados.opcional:
				return false
			break
	return true


## Cria uma celula nova encostada em alguma das ancoras, usando uma porta que a
## cena realmente tem. Devolve lista com a celula criada, ou vazia se nao coube.
func _pendurar(dados: DadosSala) -> Array[Vector2i]:
	var vazio: Array[Vector2i] = []
	var cenas := dados.cenas_validas()
	if cenas.is_empty():
		return vazio
	# TODOS os estilos do tipo sao tentados, nao um sorteado. Estilos diferentes
	# tem portas em lados diferentes, entao um que nao cabe nao diz nada sobre o
	# proximo -- desistir no primeiro faria o tipo sumir do andar por azar.
	cenas.shuffle()

	var distancias := _distancias()
	var ancoras := _ancoras_para(dados, distancias)

	for cena in cenas:
		# _direcoes_da_cena ja devolve uma copia nova, entao embaralhar aqui nao
		# mexe no catalogo.
		var direcoes := _direcoes_da_cena(cena)
		direcoes.shuffle()

		for ancora in ancoras:
			for direcao in direcoes:
				# A celula nova olha para a ancora por `direcao`, logo ela fica
				# do lado oposto.
				var celula: Vector2i = ancora - _para_grid(direcao)
				if _arestas.has(celula):
					continue
				if not _celula_aceita(celula, dados, distancias):
					continue
				_criar_celula(celula)
				_ligar(celula, ancora, direcao)
				_reservadas[celula] = dados.id
				_dados_por_celula[celula] = dados
				_cena_por_celula[celula] = cena
				var resultado: Array[Vector2i] = [celula]
				return resultado

	return vazio


## Ancoras candidatas, na ordem em que devem ser tentadas: mais longe da origem
## primeiro, e becos antes das demais quando o tipo pede beco.
##
## Celula ja reservada nunca e ancora. Toda pendurada pode ter uma porta so, e
## dar a ela uma segunda aresta quebraria a escolha de cena mais adiante.
func _ancoras_para(dados: DadosSala, distancias: Dictionary) -> Array[Vector2i]:
	var por_distancia := _mais_longe_primeiro(distancias)

	var preferidas: Array[Vector2i] = []
	var demais: Array[Vector2i] = []
	for celula in _arestas:
		if _reservadas.has(celula):
			continue
		if dados.exige_beco and _grau(celula) > 1:
			demais.append(celula)
		else:
			preferidas.append(celula)

	preferidas.sort_custom(por_distancia)
	demais.sort_custom(por_distancia)
	# `demais` e ultimo recurso: um andar sem nenhum beco livre ainda deve
	# receber o premio, so que num lugar menos escondido.
	preferidas.append_array(demais)
	return preferidas


## A celula CRIADA respeita as regras de vizinhanca?
##
## Repare que quem e testado e a celula nova, nao a ancora. A versao antiga
## filtrava a ancora, e por isso deixava passar o caso de a celula nova encostar
## por OUTRO lado numa sala que ela deveria evitar.
func _celula_aceita(celula: Vector2i, dados: DadosSala, distancias: Dictionary) -> bool:
	for direcao in DIRECOES:
		var vizinha: Vector2i = celula + _para_grid(direcao)
		if _reservadas.has(vizinha):
			# Regra estrutural, sem opt-out: pendurada nunca encosta em
			# pendurada. Ambas podem ter porta unica e o par se estrangula.
			return false

	if dados.distancia_minima_da_origem <= 0:
		return true

	# A celula nova ainda nao esta no grafo, entao a distancia dela e a da
	# ancora mais um passo. Basta uma vizinha ja conhecida para saber.
	var menor := -1
	for direcao in DIRECOES:
		var vizinha: Vector2i = celula + _para_grid(direcao)
		if not distancias.has(vizinha):
			continue
		var d := int(distancias[vizinha]) + 1
		if menor < 0 or d < menor:
			menor = d
	return menor < 0 or menor >= dados.distancia_minima_da_origem
## Escolhe a cena de cada celula em ordem BFS. A ordem importa: quando nenhuma
## cena cobre todas as portas que a celula usa, a aresta aparada e sempre a que
## leva a um ramo ainda nao processado -- assim nada fica inalcancavel.
func _escolher_cenas() -> bool:
	# As reservadas ja entraram em _cena_por_celula quando foram penduradas:
	# a cena delas foi sorteada antes, e a celula nasceu do tamanho dela.
	var padrao := _tipo_de_preenchimento_padrao()

	var pais: Dictionary = {}
	for celula in _ordem_bfs(pais):
		if not _arestas.has(celula):
			continue
		var usadas := vizinhos_de(celula)

		if _reservadas.has(celula):
			var fixa: DadosSala = _dados_por_celula[celula]
			if _cobre(_direcoes_da_cena(_cena_por_celula[celula]), usadas):
				continue
			# Obrigatoria que nao cabe derruba o grafo inteiro, como antes.
			# Opcional que nao cabe vira sala comum em vez de custar 24
			# tentativas de sorteio por causa de um premio.
			if not fixa.opcional:
				return false
			_reservadas.erase(celula)
			_dados_por_celula.erase(celula)
			_cena_por_celula.erase(celula)

		var candidatas := _cenas_que_servem(usadas)
		if not candidatas.is_empty():
			_cena_por_celula[celula] = candidatas.pick_random()
			_dados_por_celula[celula] = padrao
			continue

		var melhor := _melhor_cobertura(usadas, pais.get(celula, Vector2.ZERO))
		if melhor == null:
			return false
		_cena_por_celula[celula] = melhor
		_dados_por_celula[celula] = padrao
		var servidas := _direcoes_da_cena(melhor)
		for direcao in usadas:
			if not servidas.has(direcao):
				_podar(celula, direcao)

	# Pendurada obrigatoria que sumiu numa poda derruba o grafo; opcional so
	# deixa de existir.
	for celula in _reservadas.keys():
		if _arestas.has(celula):
			continue
		var perdida: DadosSala = _dados_por_celula.get(celula)
		if perdida != null and not perdida.opcional:
			return false
		_reservadas.erase(celula)
		_dados_por_celula.erase(celula)

	for celula in _arestas:
		if not _cena_por_celula.has(celula):
			return false
	return true


## O tipo que descreve as celulas comuns. Serve para o minimapa saber a cor de
## uma sala de combate sem precisar de um caso especial para "nao e pendurada".
func _tipo_de_preenchimento_padrao() -> DadosSala:
	var comuns := _tipos_de_preenchimento()
	if comuns.is_empty():
		return null
	return comuns[0]


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
	for cena in _cenas_de_preenchimento():
		if _cobre(_direcoes_da_cena(cena), usadas):
			lista.append(cena)
	return lista


## As cenas que podem preencher uma celula comum. Sai dos tipos COMUM, entao
## acrescentar um estilo de sala de combate e arrastar a cena para o .tres.
func _cenas_de_preenchimento() -> Array[PackedScene]:
	var lista: Array[PackedScene] = []
	for dados in _tipos_de_preenchimento():
		for cena in dados.cenas_validas():
			if _catalogo.has(cena) and not lista.has(cena):
				lista.append(cena)
	return lista


## Melhor cena quando nenhuma serve inteira. `obrigatoria` e a direcao do pai na
## BFS: perder essa porta desligaria a propria celula do andar.
func _melhor_cobertura(usadas: Array[Vector2], obrigatoria: Vector2) -> PackedScene:
	var melhor: PackedScene = null
	var melhor_nota := -1
	for cena in _cenas_de_preenchimento():
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
	# Uma vez so, fora do laco: `_distancias()` roda um BFS no andar inteiro.
	var distancias_visuais := _distancias()

	for celula in _arestas:
		var cena: PackedScene = _cena_por_celula[celula]
		var sala := cena.instantiate() as Sala
		if sala == null:
			continue
		sala.coordenadas_grid = celula
		sala.fracao_do_andar = _fracao_do_andar(celula, distancias_visuais)
		# Antes do add_child de proposito: e o _ready da sala que sela as portas
		# sem vizinho, monta a parede em cima delas e veste a sala com as
		# texturas do tipo -- inclusive escolhendo a variante pela fracao acima.
		sala.definir_visual(_dados_por_celula.get(celula))
		sala.configurar_conexoes(vizinhos_de(celula))
		add_child(sala)
		sala.position = centros[celula] - _caixa_da_cena(cena).get_center()
		_salas[celula] = sala
		_ocultar(sala)

	_montar_corredores()
	_cachear_geometria()
	_sortear_composicoes()


## Decide, de uma vez para o andar inteiro, o que nasce em cada sala.
##
## Roda na montagem e nao na chegada -- e literalmente o pedido: quando o
## jogador entra, os inimigos ja estao distribuidos. Ele tambem e o unico lugar
## do projeto onde a dificuldade de uma sala e escolhida, o que torna a curva do
## andar ajustavel por .tres em vez de por seis cenas.
func _sortear_composicoes() -> void:
	_composicao_por_celula.clear()
	# Uma vez para o andar todo: a distancia de cada celula ate a entrada e o
	# que estima a Deterioracao que o jogador tera ao chegar la.
	var distancias := _distancias()
	for celula in _salas:
		var sala: Sala = _salas[celula]
		if not is_instance_valid(sala):
			continue
		var composicao := _sortear_composicao(celula, sala, distancias)
		_composicao_por_celula[celula] = composicao
		sala.definir_composicao(composicao)


## Gasta o orcamento da sala comprando inimigos sorteados por peso.
##
## O orcamento sai da AREA REAL da sala vezes a densidade do tipo, entao sala
## maior recebe mais -- sem tabela por cena. E como cada grupo tem um custo, um
## Vigia de custo 2 ocupa o lugar de dois Rastejantes: a mesma sala pode sair com
## menos corpos e mais perigo, que e o outro jeito de ficar mais dificil.
##
## A Deterioracao NAO entra nesta conta, de proposito. Ela mexe em velocidade,
## cadencia e mira preditiva pelos multiplicadores que os inimigos leem no frame
## -- agressividade, nunca quantidade.
func _sortear_composicao(
	celula: Vector2i, sala: Sala, distancias: Dictionary
) -> Array[PackedScene]:
	var lista: Array[PackedScene] = []
	var dados: DadosSala = _dados_por_celula.get(celula)
	if dados == null:
		return lista

	var grupos := dados.grupos_validos()
	if grupos.is_empty():
		return lista

	var estimada := _deterioracao_estimada(celula, dados, distancias)
	var restante := dados.orcamento_para(sala.area_do_contorno())
	# Trava de seguranca: com custo_real() >= 1 o restante sempre cai, mas um
	# laco que gasta orcamento nao pode depender disso para terminar.
	var seguranca := restante + 8
	while restante > 0 and seguranca > 0:
		seguranca -= 1
		var escolhido := _sortear_grupo(grupos, restante, estimada)
		if escolhido == null:
			break
		lista.append(escolhido.cena)
		restante -= escolhido.custo_real()
	return lista


## Quao fundo no andar esta a celula, de 0.0 a 1.0 (AND1 01).
##
## Sai do MESMO BFS que decide quais inimigos podem nascer onde -- reusar em vez
## de inventar um segundo numero para "quao longe da entrada", que acabaria
## divergindo do primeiro sem ninguem notar.
##
## Normaliza pela celula mais funda do andar, e nao por uma contagem fixa: o
## andar tem entre oito e doze salas dependendo do sorteio, e dividir por um
## numero fixo faria o terco final nunca chegar nos andares curtos.
##
## As celulas soltas que `_distancias()` marca com 9999 sao ignoradas na hora de
## achar o fundo -- uma delas puxaria o divisor para 9999 e achataria o andar
## inteiro no primeiro terco.
func _fracao_do_andar(celula: Vector2i, distancias: Dictionary) -> float:
	var fundo := 0
	for valor: int in distancias.values():
		if valor < 9999 and valor > fundo:
			fundo = valor
	if fundo <= 0:
		return 0.0
	var passos := int(distancias.get(celula, 0))
	if passos >= 9999:
		return 1.0
	return clampf(float(passos) / float(fundo), 0.0, 1.0)


## Quanto a barra deve marcar quando o jogador chegar nesta celula.
##
## Salas limpas ate aqui vezes o ganho por sala. Ignora o ganho passivo, entao
## subestima -- a porta de um inimigo abre um pouco mais tarde do que na
## partida real, que e o lado seguro de errar. A explicacao longa esta no
## `deterioracao_minima` do GrupoInimigo.
func _deterioracao_estimada(
	celula: Vector2i, dados: DadosSala, distancias: Dictionary
) -> float:
	var passos := float(distancias.get(celula, 0))
	return passos * dados.deterioracao_ao_limpar


## Sorteio por peso entre os grupos que cabem no orcamento restante E que ja
## foram liberados pela Deterioracao estimada da celula.
## Devolve null quando nenhum serve -- e o que encerra a compra.
func _sortear_grupo(
	grupos: Array[GrupoInimigo], restante: int, estimada: float
) -> GrupoInimigo:
	var elegiveis: Array[GrupoInimigo] = []
	var soma := 0.0
	for grupo in grupos:
		if grupo.custo_real() <= restante and grupo.liberado_em(estimada):
			elegiveis.append(grupo)
			soma += grupo.peso
	if elegiveis.is_empty() or soma <= 0.0:
		return null

	var sorteio := randf() * soma
	for grupo in elegiveis:
		sorteio -= grupo.peso
		if sorteio <= 0.0:
			return grupo

	# Só chega aqui por erro de arredondamento no ultimo item.
	return elegiveis[elegiveis.size() - 1]


## Contorno de cada sala em coordenadas de mundo, calculado uma vez.
##
## Roda depois de _montar_corredores porque so ali as posicoes finais existem.
## Todas as salas ja estao na arvore neste ponto (o _ocultar mexe em `visible` e
## `process_mode`, nao tira da arvore), entao ate as celulas nunca visitadas tem
## global_position valida -- e por isso o minimapa consegue desenhar o andar
## inteiro sem instanciar nada.
func _cachear_geometria() -> void:
	_contornos.clear()
	_ligacoes_cache.clear()
	for celula in _salas:
		var sala: Sala = _salas[celula]
		if not is_instance_valid(sala):
			continue
		var local := sala.contorno_local()
		var mundo := PackedVector2Array()
		for ponto in local:
			mundo.append(sala.to_global(ponto))
		_contornos[celula] = mundo

	for ligacao in _corredores:
		var no: Corredor = ligacao["no"]
		if not is_instance_valid(no):
			continue
		_ligacoes_cache.append({
			"a": ligacao["a"],
			"b": ligacao["b"],
			"caixa": no.obter_limites(),
		})


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

	# So aparece o corredor cujas DUAS pontas ja foram reveladas. Revelar todo
	# corredor encostado na celula desenhava chao e parede entrando numa sala
	# ainda oculta: o jogador via um caminho iluminado terminando no escuro, em
	# lugar onde ele ainda nao pode entrar. O corredor da saida acende no mesmo
	# frame em que _sair revela o destino, entao a travessia nao perde nada.
	for ligacao in _corredores:
		if ligacao["a"] != celula and ligacao["b"] != celula:
			continue
		var no: Corredor = ligacao["no"]
		no.visible = _visitadas.has(ligacao["a"]) and _visitadas.has(ligacao["b"])


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
	_forcar_deterioracao_de(celula)
	# ativar() e idempotente: reentrar numa sala ja limpa nao recomeca o combate.
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
##
## Sem direcao (primeira sala do andar, ou o salto que o teste de fumaca usa)
## nao existe porta para se guiar. Aqui ficava o centro do bounding box, e era
## por isso que o jogador nascia dentro do pilar da sala 5 e no canto concavo da
## sala em L: bounding box nao sabe onde a sala termina. Quem sabe e a sala.
func _posicao_de_chegada(destino: Sala, direcao: Vector2) -> Vector2:
	if direcao == Vector2.ZERO:
		return destino.ponto_seguro()
	var entrada := destino.ponto_de_entrada(direcao)
	# A boca da porta so leva a lugar bom se nao houver obstaculo logo atras
	# dela. Nenhuma sala de hoje cai nisso; a guarda evita que a proxima que
	# tiver um obstaculo colado na porta reponha o mesmo defeito.
	if destino.posicao_livre(entrada):
		return entrada
	return destino.ponto_seguro()


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


## Encosta a camera nos limites da area, JA folgados para mostrar a parede.
##
## A folga e aplicada aqui e nao em `Sala.obter_limites()` de proposito: aquele
## retangulo tambem posiciona as salas no andar (`_montar_andar` mede as celulas
## com ele), entao inflar na origem afastaria as salas umas das outras e
## desalinharia os corredores. O clamp e o unico lugar onde "quanto a camera
## mostra" e a pergunta.
func _clampar(limites: Rect2) -> void:
	if limites.size == Vector2.ZERO:
		return
	var player := _player()
	if player == null:
		return
	var camera := player.get_node_or_null("Camera") as Camera2D
	if camera == null:
		return
	var visivel := limites.grow(margem_da_parede())
	_ajustar_zoom(camera, visivel.size)
	camera.limit_left = roundi(visivel.position.x)
	camera.limit_top = roundi(visivel.position.y)
	camera.limit_right = roundi(visivel.end.x)
	camera.limit_bottom = roundi(visivel.end.y)


## Quanto a camera enxerga ALEM do contorno.
##
## Sai de `Sala.ESPESSURA_PAREDE` em vez de ser um numero proprio: a faixa de
## parede e desenhada exatamente essa distancia para fora, entao derivar dela
## garante que a camera mostre a parede INTEIRA e nem um pixel do vazio que vem
## depois. Um numero solto aqui descolaria no dia em que alguem engrossasse a
## parede, e o sintoma seria uma tira preta na borda -- ou meia parede cortada.
##
## O custo, e ele e real e CRESCEU com a migracao Low Top-Down: a faixa passou
## de 24 para 64 px, entao numa sala do tamanho exato da tela (960x544) o quadro
## util vira 1088x672 e a camera desliza ate 64 px por eixo. Com o jogador no
## centro, nenhuma parede aparece -- ela entra quando ele anda ate a borda.
##
## Nao ha conserto por margem: o retangulo tem de casar com a parede desenhada,
## e e isso que `tools/testes/teste_camera.gd` trava. O conserto e geometrico --
## sala de 832x416 fecharia 960x544 exato -- e mexe em tamanho de sala, que a
## Fase 25 do plano de migracao proibe alterar enquanto ela acontece.
func margem_da_parede() -> float:
	return Sala.ESPESSURA_PAREDE


## O clamp sozinho nao basta: Camera2D nao respeita limite menor que o proprio
## campo de visao, entao numa sala mais estreita que a tela ela desenha o vazio
## de fora da sala nas bordas e o jogador le aquilo como area que deveria
## alcancar. Aproximar o zoom ate o campo caber e o unico remedio que nao passa
## por desenhar coisa nova.
##
## Nas salas de hoje, em janela 16:9, isto nao muda nada. Ele existe porque o
## stretch "expand" do project.godot alarga o campo em janela ultrawide -- e ai
## a sala mais estreita do andar volta a nao caber, sem ninguem ter mexido em
## .tscn nenhum.
func _ajustar_zoom(camera: Camera2D, area: Vector2) -> void:
	if _zoom_base <= 0.0:
		_zoom_base = maxf(camera.zoom.x, camera.zoom.y)

	var vista := camera.get_viewport_rect().size
	var fator := _zoom_base
	if area.x > 0.0:
		fator = maxf(fator, vista.x / area.x)
	if area.y > 0.0:
		fator = maxf(fator, vista.y / area.y)

	if not is_equal_approx(camera.zoom.x, fator) or not is_equal_approx(camera.zoom.y, fator):
		camera.zoom = Vector2(fator, fator)


# ----------------------------------------------------------- ciclo da run ---

## Piso de Deterioracao ao ENTRAR, quando o tipo da sala pede um.
##
## Existe por causa do chefe: o GDD quer a luta final em nivel critico, e sem
## isto ela aconteceria no nivel em que a run por acaso chegou. Herda o papel do
## `deterioracao_minima_inicial` que morava no DadosOnda.
##
## Nunca abaixa a barra -- so empurra para cima.
func _forcar_deterioracao_de(celula: Vector2i) -> void:
	var dados: DadosSala = _dados_por_celula.get(celula)
	if dados == null or dados.deterioracao_minima_ao_entrar < 0.0:
		return
	if Deterioracao.valor < dados.deterioracao_minima_ao_entrar:
		Deterioracao.valor = dados.deterioracao_minima_ao_entrar


func _ao_sala_limpa(sala: Node2D) -> void:
	GameState.salas_limpas += 1
	var limpa := sala as Sala
	if limpa == null:
		return
	# Le do DADO da celula, nao do @export da cena: assim uma cena reaproveitada
	# por dois tipos nao encerra a run no tipo errado.
	var dados: DadosSala = _dados_por_celula.get(limpa.coordenadas_grid)
	var id: StringName = dados.id if dados != null else limpa.tipo

	# A escalada da run mora aqui desde que as ondas sairam. So sobe quem tinha
	# combate: limpar a sala de item nao e conquista nenhuma.
	if dados != null and dados.deterioracao_ao_limpar > 0.0:
		Deterioracao.adicionar(dados.deterioracao_ao_limpar)

	if id == DadosSala.ID_BOSS:
		GameState.terminar_run(true)
