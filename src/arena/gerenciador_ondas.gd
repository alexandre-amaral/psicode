class_name GerenciadorOndas
extends Node
## Orquestra a sequencia de ondas do vertical slice.
##
## Contrato: ele so SPAWNA e CONTA. Nao sabe desenhar nada, nao sabe de HUD.
## Tudo que a interface precisa sai pelo EventBus.

signal onda_completa(indice: int)
signal run_completa(venceu: bool)

const CENA_MARCADOR := preload("res://src/arena/marcador_spawn.tscn")
const CENA_RASTEJANTE := preload("res://src/enemies/rastejante.tscn")
const CENA_VIGIA := preload("res://src/enemies/vigia.tscn")
const CENA_DIRETORA := preload("res://src/enemies/diretora.tscn")
const CENA_PICKUP := preload("res://src/arena/pickup_arma.tscn")

@export var ondas: Array[DadosOnda] = []
## Caminhos em vez de referencias diretas: NodePath e resolvido na hora certa
## e sobrevive a quem mover o no no editor sem reconectar nada.
@export var caminho_container_inimigos: NodePath = ^"../ContainerInimigos"
@export var caminho_container_pickups: NodePath = ^"../ContainerPickups"
## Retangulo util onde inimigos podem nascer (em coordenadas locais da arena).
@export var area_spawn: Rect2 = Rect2(-700, -370, 1400, 740)
## Distancia minima entre um spawn e o jogador. Impede spawn na cara.
@export var distancia_minima_player: float = 300.0

var indice: int = -1
var rodando: bool = false

var _vivos: Array[Node] = []
var _pendentes: int = 0
var _chefe: Node = null

var container_inimigos: Node2D
var container_pickups: Node2D

## Trava de reentrancia. _proxima_onda espera um timer antes de avancar o
## indice; sem essa trava, duas chamadas sobrepostas pulariam uma onda inteira
## -- inclusive a do chefe.
var _avancando: bool = false


## Ondas usadas quando o array do Inspetor esta vazio. Deixar esse fallback
## aqui evita que um merge mal resolvido no .tscn quebre o jogo inteiro.
const ONDAS_PADRAO := [
	"res://src/arena/onda_1.tres",
	"res://src/arena/onda_2.tres",
	"res://src/arena/onda_3.tres",
	"res://src/arena/onda_4.tres",
	"res://src/arena/onda_5.tres",
]


func _ready() -> void:
	# A HUD encontra o gerenciador por grupo para ler o titulo da onda atual.
	add_to_group("gerenciador_ondas")
	container_inimigos = get_node_or_null(caminho_container_inimigos) as Node2D
	container_pickups = get_node_or_null(caminho_container_pickups) as Node2D
	if container_inimigos == null:
		push_error("GerenciadorOndas: container de inimigos nao encontrado em '%s'." % caminho_container_inimigos)
	if container_pickups == null:
		container_pickups = container_inimigos


func iniciar() -> void:
	if ondas.is_empty():
		for caminho in ONDAS_PADRAO:
			var d: DadosOnda = load(caminho)
			if d != null:
				ondas.append(d)
	if ondas.is_empty():
		push_error("GerenciadorOndas: nenhuma onda configurada.")
		return
	indice = -1
	rodando = true
	GameState.total_ondas = ondas.size()
	_proxima_onda(0.9)


func _proxima_onda(atraso: float) -> void:
	if not rodando or _avancando:
		return
	_avancando = true
	await get_tree().create_timer(atraso).timeout
	_avancando = false
	if not rodando or not is_inside_tree():
		return

	indice += 1
	if indice >= ondas.size():
		_finalizar(true)
		return

	var dados: DadosOnda = ondas[indice]
	GameState.onda_atual = indice + 1

	if dados.deterioracao_minima_inicial >= 0.0:
		if Deterioracao.valor < dados.deterioracao_minima_inicial:
			Deterioracao.valor = dados.deterioracao_minima_inicial

	EventBus.onda_iniciada.emit(indice, ondas.size())

	if dados.eh_chefe:
		_spawnar_chefe()
	else:
		_spawnar_onda(dados)


func _spawnar_onda(dados: DadosOnda) -> void:
	var lista: Array[PackedScene] = []
	for i in dados.rastejantes:
		lista.append(CENA_RASTEJANTE)
	for i in dados.vigias:
		lista.append(CENA_VIGIA)
	lista.shuffle()

	_pendentes = lista.size()
	for cena in lista:
		_agendar_spawn(cena)
		if dados.intervalo_spawn > 0.0:
			await get_tree().create_timer(dados.intervalo_spawn).timeout
			if not rodando or not is_inside_tree():
				return


func _agendar_spawn(cena: PackedScene) -> void:
	var pos := _sortear_posicao()
	var marcador := CENA_MARCADOR.instantiate()
	marcador.global_position = pos
	container_inimigos.add_child(marcador)
	marcador.terminou.connect(func(p: Vector2) -> void:
		if not rodando or not is_inside_tree():
			return
		var inimigo := cena.instantiate()
		inimigo.global_position = p
		container_inimigos.add_child(inimigo)
		_registrar(inimigo)
	)


func _spawnar_chefe() -> void:
	var marcador := CENA_MARCADOR.instantiate()
	marcador.global_position = Vector2.ZERO
	marcador.duracao = 1.4
	marcador.cor = Color(0.85, 0.3, 1.0)
	marcador.scale = Vector2(3.0, 3.0)
	container_inimigos.add_child(marcador)
	marcador.terminou.connect(func(_p: Vector2) -> void:
		if not rodando or not is_inside_tree():
			return
		_chefe = CENA_DIRETORA.instantiate()
		_chefe.global_position = Vector2.ZERO
		container_inimigos.add_child(_chefe)
		_chefe.morreu.connect(func(_pos: Vector2) -> void: _finalizar(true))
	)


func _registrar(inimigo: Node) -> void:
	_vivos.append(inimigo)
	_pendentes = maxi(_pendentes - 1, 0)
	EventBus.contagem_inimigos_mudou.emit(_contar_vivos())
	if inimigo.has_signal("morreu"):
		inimigo.morreu.connect(_ao_morrer_inimigo)


func _ao_morrer_inimigo(_posicao: Vector2) -> void:
	# O no ainda nao saiu da arvore neste frame; espera um quadro para contar.
	await get_tree().process_frame
	if not rodando or not is_inside_tree():
		return
	var restantes := _contar_vivos()
	EventBus.contagem_inimigos_mudou.emit(restantes)

	# Guarda: a onda do chefe NUNCA termina por contagem de inimigos. Ela
	# termina quando a Diretora morre, e mais nada. Sem isso, um invocado
	# morrendo com a lista vazia declararia a onda limpa e pularia o chefe.
	if indice >= 0 and indice < ondas.size() and ondas[indice].eh_chefe:
		return

	if restantes == 0 and _pendentes == 0:
		_limpar_onda()


## Poda e conta numa passada so.
## Nota: Array.filter() devolve Array sem tipo, o que quebra a atribuicao de
## volta num Array[Node] tipado. Loop explicito e o caminho seguro em GDScript.
func _contar_vivos() -> int:
	var restantes: Array[Node] = []
	for n in _vivos:
		if is_instance_valid(n):
			restantes.append(n)
	_vivos = restantes
	return _vivos.size()


func _limpar_onda() -> void:
	var dados: DadosOnda = ondas[indice]
	EventBus.onda_limpa.emit(indice)
	onda_completa.emit(indice)

	if dados.deterioracao_ao_limpar > 0.0:
		Deterioracao.adicionar(dados.deterioracao_ao_limpar)

	if dados.solta_arma:
		_soltar_arma()

	_proxima_onda(dados.respiro)


func _soltar_arma() -> void:
	var pickup := CENA_PICKUP.instantiate()
	pickup.global_position = _sortear_posicao(180.0)
	container_pickups.add_child(pickup)


func _finalizar(venceu: bool) -> void:
	if not rodando:
		return
	rodando = false
	run_completa.emit(venceu)
	# GameState.terminar_run(venceu) # Removido para desacoplar de salas


func parar() -> void:
	rodando = false


## Sorteia um ponto util longe do jogador. Tenta algumas vezes e, se nao
## conseguir, aceita o melhor candidato -- nunca trava o spawn num loop.
func _sortear_posicao(distancia_min: float = -1.0) -> Vector2:
	var minimo := distancia_min if distancia_min >= 0.0 else distancia_minima_player
	var player := get_tree().get_first_node_in_group("player")
	var melhor := Vector2.ZERO
	var melhor_dist := -1.0

	for tentativa in 24:
		var p := Vector2(
			randf_range(area_spawn.position.x, area_spawn.end.x),
			randf_range(area_spawn.position.y, area_spawn.end.y)
		)
		if player == null or not is_instance_valid(player):
			return p
		var d := p.distance_to(player.global_position)
		if d >= minimo:
			return p
		if d > melhor_dist:
			melhor_dist = d
			melhor = p
	return melhor
