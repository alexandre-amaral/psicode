extends InimigoBase
## HACKER PARASITA -- nao encosta e nao atira. Semeia perigo no chao e foge.
##
## Ele e o unico inimigo do jogo que ataca o ESPACO em vez do jogador. Nada que
## ele faz persegue voce; o que ele faz e apagar, aos poucos, os lugares onde
## voce estava confortavel. Contra ele o certo nunca e esquivar -- e andar antes
## de precisar.
##
## Isso muda a prioridade de alvo, que e a razao de ele existir: enquanto o
## Rastejante e a Cyber-Besta pedem atencao imediata, o Parasita cobra por ser
## ignorado. Ele e o inimigo que ensina a olhar o campo inteiro.
##
## Ele foge do jogador de proposito. Um semeador que fica ao alcance morre no
## primeiro segundo e nunca chega a semear nada.
##
## A ZONA RESIDUAL e o que faz a promessa acima ser verdade. Sem ela, o estouro
## e um instante: quem estava dentro toma, e um segundo depois o chao esta livre
## outra vez -- o Parasita punia um momento e nao reduzia espaco nenhum. A brasa
## nao mata; ela impede o jogador de VOLTAR para onde estava, que e a coisa
## inteira que este inimigo existe para fazer.

const CENA_AREA := preload("res://src/enemies/area_de_perigo.tscn")

@export_group("Semeadura")
## Teto de areas vivas ao mesmo tempo. Sem ele, tres Parasitas na mesma sala
## cobrem o chao inteiro e nao sobra lugar para o jogador estar.
@export var max_areas: int = 3
@export var intervalo: float = 2.4
## Quanto tempo ele fica exposto ao semear -- a janela para puni-lo.
@export var tempo_semear: float = 0.55
## Raio em volta do jogador onde as areas nascem. Zero cairia sempre em cima
## dele, o que seria um ataque sem escolha.
@export var espalhamento: float = 96.0
@export var raio_area: float = 60.0
## Quanto tempo a brasa fica no chao depois do estouro.
##
## E o botao de controle territorial dele: mais tempo, menos chao util. Ligado
## AQUI e nao no default da `AreaDePerigo` porque a mesma cena serve os ataques
## de area da Diretora, e o repertorio dela foi medido sem brasa nenhuma.
@export var tempo_residual: float = 1.5

@export_group("Fuga")
## Abaixo disto ele recua. Acima, ele so se reposiciona devagar.
@export var distancia_minima: float = 240.0

const REPOSICIONAR := &"REPOSICIONAR"
const SEMEAR := &"SEMEAR"
const ESPERAR := &"ESPERAR"

var _maquina: MaquinaEstados
var _aura: Polygon2D
var _t_intervalo: float = 0.0
## Areas que ESTE parasita semeou e que ainda vivem. Ver `morrer()`.
var _areas: Array[Node] = []


func _ready() -> void:
	super._ready()
	_aura = $Visual/Aura
	_aura.visible = false
	_t_intervalo = randf_range(0.5, intervalo)

	_maquina = MaquinaEstados.new(name)
	_maquina.adicionar(REPOSICIONAR, _reposicionar)
	_maquina.adicionar(SEMEAR, _semear, _semear_entrar, _semear_sair)
	_maquina.adicionar(ESPERAR, _esperar)
	_maquina.iniciar(REPOSICIONAR)


func _comportamento(delta: float) -> void:
	_maquina.processar(delta)


# ------------------------------------------------------------- estados ------

func _reposicionar(delta: float) -> void:
	_t_intervalo -= delta * Deterioracao.multiplicador_cadencia()
	_fugir(delta, 1.0)
	if _t_intervalo <= 0.0 and _vivas() < max_areas:
		_maquina.trocar(SEMEAR)


## Ele para e acende a aura. E o unico momento em que da para alcanca-lo sem
## correr atras -- o preco do ataque dele.
func _semear_entrar() -> void:
	_aura.visible = true
	_aura.scale = Vector2(0.3, 0.3)
	_aura.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_aura, "scale", Vector2(1.4, 1.4), tempo_semear)
	t.parallel().tween_property(_aura, "modulate:a", 0.7, tempo_semear * 0.6)


func _semear(delta: float) -> void:
	Movimento.frear(self, delta, 1400.0)
	if _maquina.passou(tempo_semear):
		_plantar()
		_t_intervalo = intervalo
		_maquina.trocar(ESPERAR)


func _semear_sair() -> void:
	_aura.visible = false


func _esperar(delta: float) -> void:
	_fugir(delta, 1.0)
	if _maquina.passou(0.4):
		_maquina.trocar(REPOSICIONAR)


# ------------------------------------------------------------ semeadura -----

## A area nasce no CONTAINER da sala, e nao como filha deste no.
##
## Filha dele, ela andaria junto -- e um aviso no chao que se move e um aviso
## que mente: o jogador sai de cima e o perigo vai atras. O container e o mesmo
## pai que a Sala usa para os inimigos, entao a area vive e morre com a sala.
func _plantar() -> void:
	var container := get_parent()
	if container == null:
		return

	var alvo_pos := alvo.global_position if alvo != null and is_instance_valid(alvo) else global_position
	var destino := alvo_pos + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.0, espalhamento)

	# Nao semeia dentro de parede nem em cima de obstaculo. A Sala ja sabe
	# responder isso, e usar a resposta dela e o que impede um circulo de
	# aviso do outro lado da parede -- perigo que o jogador nao pode evitar
	# porque nao pode nem chegar la.
	var sala := _sala_dona()
	if sala != null and not sala.posicao_livre(destino, raio_area * 0.5):
		destino = sala.ponto_seguro()

	var area := CENA_AREA.instantiate()
	# Antes do `configurar()`, que e quem acende o telegrafo e passa a contar.
	area.tempo_residual = tempo_residual
	container.add_child(area)
	area.configurar(destino, raio_area, dano_contato)
	_areas.append(area)
	EventBus.pedido_shake.emit(1.2, 0.1)


## Poda e conta numa passada so -- mesmo padrao de `Sala._contar_vivos()`.
## Loop explicito porque `Array.filter()` devolve `Array` sem tipo e a
## atribuicao de volta num `Array[Node]` tipado estoura em runtime.
func _vivas() -> int:
	var restantes: Array[Node] = []
	for a in _areas:
		if is_instance_valid(a):
			restantes.append(a)
	_areas = restantes
	return _areas.size()


func _sala_dona() -> Sala:
	var atual: Node = get_parent()
	while atual != null:
		var sala := atual as Sala
		if sala != null:
			return sala
		atual = atual.get_parent()
	return null


# ------------------------------------------------------------- movimento ----

## Para tras quando o jogador encosta, de lado quando ha espaco.
##
## A conta saiu daqui para `src/util/movimento.gd` (INIM 07). Uma coisa mudou de
## lugar mas nao de comportamento: a deriva lateral era multiplicada por 0,5 e
## normalizada na linha seguinte, o que apagava o 0,5 -- ele nunca andou mais
## devagar de lado. Quem quiser de fato desacelerar a deriva mexe no `fator`,
## que atua depois da normalizacao.
func _fugir(delta: float, fator: float) -> void:
	Movimento.fugir(self, delta, distancia_minima, fator, 1000.0)


## As areas dele morrem com ele.
##
## Sem isto, matar o Parasita nao para o ataque: os circulos que ele ja tinha
## semeado continuam explodindo, e o jogador leva dano de um inimigo que nao
## existe mais. E o tipo de dano que ninguem consegue atribuir a nada -- so
## parece bug.
func morrer() -> void:
	for a in _areas:
		if is_instance_valid(a):
			a.queue_free()
	_areas.clear()
	super.morrer()
