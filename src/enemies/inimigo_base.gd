class_name InimigoBase
extends CharacterBody2D
## Base de todo inimigo. Cuida de vida, dano, knockback, flash e morte.
## As subclasses so implementam _comportamento().
##
## Regra importante: NENHUM inimigo guarda os proprios numeros de dificuldade
## multiplicados. Eles leem Deterioracao a cada frame. Assim a barra subir tem
## efeito imediato, inclusive nos inimigos que ja estao na tela.

signal morreu(posicao: Vector2)

const GRUPO := "inimigo"

## Para onde a cor do corpo puxa enquanto o inimigo esta hackeado. Verde do
## Cipher: quem hackeou tem de ser reconhecivel no alvo, nao so no cano.
const COR_HACK := Color(0.45, 1.0, 0.3)

@export_group("Atributos")
@export var vida_maxima: int = 5
@export var velocidade_base: float = 120.0
@export var dano_contato: int = 1
@export var creditos: int = 3
## Quanto este inimigo soma na barra de Deterioracao ao morrer. Zero por
## padrao -- quem move a barra e o fim de onda, nao a matanca.
@export var deterioracao_ao_morrer: float = 0.0

@export_group("Feedback")
@export var cor_base: Color = Color("ff4d6d")
@export var raio_contato: float = 26.0
@export var intervalo_dano_contato: float = 0.7

var vida: int = 5
var alvo: Node2D = null
var morto: bool = false

var _knockback: Vector2 = Vector2.ZERO
var _t_contato: float = 0.0
## Segundos restantes de Hack. O estado mora AQUI e nao num Dictionary do
## autoload por dois motivos: um dicionario chaveado por instance_id acumularia
## ids de inimigos mortos a run inteira sem ninguem podar, e o tint precisa do
## estado localmente de qualquer jeito. Nascer e morrer com o no e o
## comportamento certo.
var _t_hack: float = 0.0
var _visual: Node2D
var _corpo: Polygon2D
var _tween_flash: Tween


func _ready() -> void:
	add_to_group(GRUPO)
	vida = vida_maxima
	_visual = get_node_or_null("Visual")
	_corpo = get_node_or_null("Visual/Corpo")
	if _corpo != null:
		_corpo.color = cor_base
	_procurar_alvo()
	EventBus.inimigo_spawnou.emit(self)
	_ao_nascer()


func _physics_process(delta: float) -> void:
	if morto:
		return
	if alvo == null or not is_instance_valid(alvo):
		_procurar_alvo()

	_t_contato = maxf(_t_contato - delta, 0.0)

	if _t_hack > 0.0:
		_t_hack = maxf(_t_hack - delta, 0.0)
		if _t_hack <= 0.0:
			_pintar_hack(false)

	_comportamento(delta)

	# Knockback e somado por fora do comportamento para que empurrar um inimigo
	# nunca "cancele" a IA dele -- so desloca.
	if _knockback.length_squared() > 1.0:
		velocity += _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 1400.0 * delta)

	move_and_slide()
	_pos_movimento(delta)


## Ponto de extensao principal: cada inimigo escreve so isto.
func _comportamento(_delta: float) -> void:
	pass


func _pos_movimento(_delta: float) -> void:
	pass


## Ponto de extensao do MOVIMENTO: recebe para onde o inimigo QUER ir e devolve
## para onde ele de fato vai.
##
## Hoje devolve a direcao crua, e e de proposito -- o comportamento nao muda em
## nada. O que ele cria e o lugar: quando entrar pathfinding ou desvio de
## obstaculo, esta e a unica funcao que muda, em vez de sete arquivos de
## inimigo. A divida esta declarada no ROADMAP ("sem pathfinding -- o melee anda
## em linha reta") e as salas com pilar e as em L a tornaram real.
##
## Quem escreve inimigo novo passa o movimento por aqui. O Rastejante e o Vigia
## ainda nao passam: eles sao o que a v0.2.0-alpha esta testando com os amigos, e
## mexer neles agora invalidaria esse retorno.
func direcao_de_locomocao(desejada: Vector2) -> Vector2:
	return desejada


func _ao_nascer() -> void:
	# Pop de entrada -- comunica "algo novo apareceu" sem precisar de animacao.
	if _visual == null:
		return
	_visual.scale = Vector2(0.1, 0.1)
	var t := create_tween()
	t.tween_property(_visual, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func velocidade_atual() -> float:
	return velocidade_base * Deterioracao.multiplicador_velocidade()


func direcao_para_alvo() -> Vector2:
	if alvo == null or not is_instance_valid(alvo):
		return Vector2.ZERO
	return (alvo.global_position - global_position).normalized()


func distancia_do_alvo() -> float:
	if alvo == null or not is_instance_valid(alvo):
		return INF
	return global_position.distance_to(alvo.global_position)


## Velocidade do alvo, usada pela mira preditiva. Isolado aqui para que o
## chefe e o Vigia leiam exatamente a mesma coisa.
func velocidade_do_alvo() -> Vector2:
	if alvo == null or not is_instance_valid(alvo):
		return Vector2.ZERO
	if "velocity" in alvo:
		return alvo.velocity
	return Vector2.ZERO


func tentar_dano_contato() -> void:
	if _t_contato > 0.0 or alvo == null or not is_instance_valid(alvo):
		return
	if distancia_do_alvo() > raio_contato:
		return
	if alvo.has_method("receber_dano"):
		var acertou: bool = alvo.receber_dano(dano_contato, direcao_para_alvo() * 260.0)
		if acertou:
			_t_contato = intervalo_dano_contato
			_knockback = -direcao_para_alvo() * 220.0


func receber_dano(quantidade: int, impulso: Vector2 = Vector2.ZERO) -> bool:
	if morto:
		return false
	vida -= quantidade
	_knockback += impulso
	_flash()
	EventBus.pedido_hitstop.emit(0.025, 0.25)
	if vida <= 0:
		morrer()
	return true


## Clarao branco ao levar dano.
##
## Nao reinicia um clarao que ja esta em andamento. Parece detalhe, mas com
## dano continuo (shotgun encostada, chefe sendo metralhado) reiniciar a cada
## acerto deixa o inimigo branco permanente e some com a silhueta dele.
func _flash() -> void:
	if _visual == null:
		return
	if _tween_flash != null and _tween_flash.is_valid():
		return
	_visual.modulate = Color(5.0, 5.0, 5.0, 1.0)
	_tween_flash = create_tween()
	_tween_flash.tween_property(_visual, "modulate", Color.WHITE, 0.16)


func morrer() -> void:
	if morto:
		return
	morto = true
	set_physics_process(false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	var fx := preload("res://src/fx/explosao.tscn").instantiate()
	fx.global_position = global_position
	fx.modulate = cor_base
	get_parent().add_child(fx)

	GameState.inimigos_mortos += 1
	GameState.creditos += creditos
	if deterioracao_ao_morrer > 0.0:
		Deterioracao.adicionar(deterioracao_ao_morrer)

	# Antes do queue_free, e aqui e o unico lugar possivel: este e o unico ponto
	# do jogo com a identidade do morto, a posicao dele e o no ainda na arvore.
	# EventBus.inimigo_morreu so carrega (posicao, creditos) -- quem escuta la
	# nao tem como saber que foi um hackeado que caiu.
	if _t_hack > 0.0:
		_propagar_hack()

	morreu.emit(global_position)
	EventBus.inimigo_morreu.emit(global_position, creditos)
	queue_free()


## Marca este inimigo por `duracao` segundos. Chamado pelo projetil.
func aplicar_hack(duracao: float) -> void:
	if morto or duracao <= 0.0:
		return
	# Renova em vez de somar: dois tiros seguidos nao empilham oito segundos.
	_t_hack = maxf(_t_hack, duracao)
	_pintar_hack(true)


func esta_hackeado() -> bool:
	return _t_hack > 0.0


## O Hack pula para o vizinho vivo mais proximo dentro do raio.
##
## A busca e por grupo, a excecao que o GEMINI.md sanciona: Sala._vivos nao
## serve porque ela guarda so quem a SALA colocou, e os invocados da Diretora
## ficam de fora de proposito -- pelo grupo eles entram.
func _propagar_hack() -> void:
	if randf() >= Modificadores.chance_propagacao_hack():
		return
	var raio := Modificadores.raio_propagacao_hack()
	if raio <= 0.0:
		return

	var melhor: Node2D = null
	var menor := raio
	for outro in get_tree().get_nodes_in_group(GRUPO):
		if outro == self or not is_instance_valid(outro):
			continue
		var inimigo := outro as InimigoBase
		# Ja hackeado nao conta como destino: propagar para ele desperdicaria o
		# pulo e o Hack morreria com o proximo abate em vez de se espalhar.
		if inimigo == null or inimigo.morto or inimigo.esta_hackeado():
			continue
		var d := global_position.distance_to(inimigo.global_position)
		if d < menor:
			menor = d
			melhor = inimigo

	if melhor != null:
		melhor.aplicar_hack(Modificadores.duracao_hack())


## Tint de hackeado.
##
## Vai em `_corpo.color` e NUNCA em `_visual.modulate`: aquele e do clarao de
## dano, que termina sempre em Color.WHITE e apagaria o tint no primeiro tiro
## que acertasse. Como o modulate do pai multiplica por cima da cor do
## poligono, os dois efeitos convivem sem se conhecer.
func _pintar_hack(ligado: bool) -> void:
	if _corpo == null:
		return
	_corpo.color = cor_base.lerp(COR_HACK, 0.55) if ligado else cor_base


func _procurar_alvo() -> void:
	alvo = get_tree().get_first_node_in_group("player")
