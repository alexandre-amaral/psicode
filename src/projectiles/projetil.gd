extends Area2D
## Projetil generico. O mesmo no serve para o jogador e para os inimigos --
## quem cria decide as camadas de colisao chamando configurar().
##
## Layers do projeto (Projeto > Configuracoes > Camadas):
##   1 player | 2 inimigo | 3 parede | 4 projetil_player | 5 projetil_inimigo

const LAYER_PLAYER := 1
const LAYER_INIMIGO := 2
const LAYER_PAREDE := 4
const LAYER_PROJ_PLAYER := 8
const LAYER_PROJ_INIMIGO := 16

var velocidade: Vector2 = Vector2.ZERO
var dano: int = 1
var knockback: float = 0.0
var perfuracao_restante: int = 0
var hostil: bool = false
var cor: Color = Color("6ee7ff")
var raio: float = 4.0

var _vida_restante: float = 2.0
var _atingidos: Array[int] = []
var _rastro: Line2D
var _forma: CollisionShape2D
var _visual: Polygon2D


func _ready() -> void:
	_forma = $Forma
	_visual = $Visual
	_rastro = $Rastro
	# Cada projetil precisa da propria forma: se compartilhassemos o recurso
	# da cena, mudar o raio de um mudaria o de todos.
	var forma_circulo := CircleShape2D.new()
	forma_circulo.radius = raio
	_forma.shape = forma_circulo

	_visual.color = cor
	_visual.polygon = _montar_polygon(raio)

	_rastro.top_level = true          # ignora a rotacao do pai
	_rastro.default_color = Color(cor.r, cor.g, cor.b, 0.35)
	_rastro.width = maxf(raio * 1.5, 4.0)
	_rastro.clear_points()
	_rastro.add_point(global_position)
	_rastro.add_point(global_position)

	body_entered.connect(_ao_encostar)


func configurar(
	posicao: Vector2,
	direcao: Vector2,
	dados: DadosArma,
	eh_hostil: bool,
	multiplicador_velocidade: float = 1.0,
	bonus_dano: int = 0
) -> void:
	global_position = posicao
	hostil = eh_hostil
	# Congelado no disparo de proposito: o projetil que ja esta no ar nao muda
	# de dano quando o implante e pego. Quem filtra por hostil e a Arma -- aqui
	# o bonus ja chega zerado para inimigo.
	dano = maxi(dados.dano + bonus_dano, 1)
	knockback = dados.knockback
	perfuracao_restante = dados.perfuracao
	cor = dados.cor_projetil
	raio = dados.raio_projetil

	var vel := dados.velocidade_projetil * multiplicador_velocidade
	velocidade = direcao.normalized() * vel
	rotation = velocidade.angle()
	_vida_restante = dados.alcance / maxf(vel, 1.0)

	if hostil:
		collision_layer = LAYER_PROJ_INIMIGO
		collision_mask = LAYER_PLAYER | LAYER_PAREDE
	else:
		collision_layer = LAYER_PROJ_PLAYER
		collision_mask = LAYER_INIMIGO | LAYER_PAREDE


func _physics_process(delta: float) -> void:
	global_position += velocidade * delta
	_vida_restante -= delta
	if _vida_restante <= 0.0:
		queue_free()
		return
	_atualizar_rastro()
	_aplicar_glitch()


func _atualizar_rastro() -> void:
	if _rastro == null:
		return
	_rastro.set_point_position(0, global_position)
	# O ponto de tras fica sempre alguns frames atras, na direcao oposta.
	_rastro.set_point_position(1, global_position - velocidade.normalized() * maxf(raio * 6.0, 22.0))


## Identidade visual da Deterioracao alta: os projeteis inimigos passam a
## tremer, como se a percepcao do protagonista nao conseguisse fixa-los.
func _aplicar_glitch() -> void:
	if not hostil or _visual == null:
		return
	var g := Deterioracao.intensidade_glitch()
	if g <= 0.0:
		if _visual.position != Vector2.ZERO:
			_visual.position = Vector2.ZERO
		return
	_visual.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * g * 3.0


func _ao_encostar(corpo: Node) -> void:
	# Parede: sempre absorve.
	if corpo.is_in_group("parede"):
		_impacto()
		queue_free()
		return

	var id := corpo.get_instance_id()
	if id in _atingidos:
		return
	_atingidos.append(id)

	var acertou := false
	if corpo.has_method("receber_dano"):
		acertou = corpo.receber_dano(dano, velocidade.normalized() * knockback)

	if not acertou:
		return

	_impacto()
	if perfuracao_restante > 0:
		perfuracao_restante -= 1
	else:
		queue_free()


func _impacto() -> void:
	var fx := preload("res://src/fx/impacto.tscn").instantiate()
	fx.global_position = global_position
	fx.modulate = cor
	get_tree().current_scene.add_child(fx)


func _montar_polygon(r: float) -> PackedVector2Array:
	# Losango alongado no eixo X -- parece um dardo de energia e le bem
	# a direcao do tiro sem precisar de sprite.
	return PackedVector2Array([
		Vector2(r * 2.4, 0.0),
		Vector2(0.0, -r),
		Vector2(-r * 1.6, 0.0),
		Vector2(0.0, r),
	])
