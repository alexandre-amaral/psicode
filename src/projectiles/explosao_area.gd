class_name ExplosaoArea
extends Area2D
## Explosao em area do jogador, com dano que cai da borda para o centro.
##
## E irma da `AreaDePerigo` do Hacker Parasita e nasceu do mesmo molde, mas as
## duas nao se fundiram de proposito: a do Parasita e um TELEGRAFO -- ela cresce
## avisando e so entao machuca, porque um circulo que aparece ja explodindo seria
## dano vindo do chao. Esta aqui e o contrario: quando ela existe o aviso ja
## aconteceu (foi o voo da granada, ou o baque na parede), e transformar isso em
## mais um segundo de espera tiraria o impacto do tiro.
##
## Duas decisoes que valem a leitura:
##
## 1. **O dano cai com a distancia.** Explosao de dano chapado transforma raio em
##    "acertou ou nao", e a arma deixa de recompensar quem mira no meio do grupo.
##    Com falloff, encostar a granada no alvo VALE mais que pega-lo de raspao.
##
## 2. **Ela varre em vez de esperar `body_entered`.** Quem ja esta dentro do raio
##    no instante da explosao nunca ENTRA nele -- e a maioria dos alvos de uma
##    explosao esta exatamente nessa situacao. A mesma armadilha esta documentada
##    em `AreaDePerigo._explodir()`.

## Layers nomeadas no project.godot: 2 inimigo, 4 projetil_player.
const LAYER_PROJ_PLAYER := 8
const LAYER_INIMIGO := 2

const LADOS := 24
## Quanto do dano sobra na BORDA do raio. No centro vale sempre 1.0.
const DANO_NA_BORDA := 0.35
## Quanto o clarao dura antes de sumir. Curto: e um estouro, nao uma poca.
const DURACAO := 0.28

@export var raio: float = 90.0
@export var dano: int = 4
@export var knockback: float = 260.0
@export var cor: Color = Color(1.0, 0.55, 0.2)

var _visual: Polygon2D
var _borda: Line2D


## O _ready SO prepara. Quem estoura e `configurar()`.
##
## Estourar aqui era uma corrida: a convencao do projeto e `add_child` ANTES de
## `configurar`, entao no _ready a area ainda esta em (0,0) com o raio padrao --
## ela varria o lugar errado. O que salvava era uma segunda varredura diferida,
## e "as vezes acerta" e pior que "nunca acerta", porque passa no teste.
func _ready() -> void:
	collision_layer = LAYER_PROJ_PLAYER
	collision_mask = LAYER_INIMIGO
	_visual = $Visual
	_borda = $Borda


## Chamado DEPOIS do add_child: `global_position` so tem significado dentro da
## arvore. Mesmo contrato de AreaDePerigo.configurar().
func configurar(posicao: Vector2, dados: DadosArma, tinta: Color) -> void:
	global_position = posicao
	if dados != null:
		raio = dados.raio_explosao
		dano = dados.dano_explosao
		knockback = dados.knockback_explosao
	cor = tinta
	_desenhar()
	_estourar()


func _desenhar() -> void:
	if _visual == null:
		return
	var circulo := CircleShape2D.new()
	circulo.radius = raio
	($Forma as CollisionShape2D).shape = circulo

	var pontos := _poligono(raio)
	_visual.polygon = pontos
	_visual.color = Color(cor.r, cor.g, cor.b, 0.45)
	# O Line2D precisa repetir o primeiro ponto para fechar; o Polygon2D nao
	# pode repetir. Mesma armadilha que Sala.contorno_local() documenta.
	var fechado := PackedVector2Array(pontos)
	fechado.append(pontos[0])
	_borda.points = fechado
	_borda.default_color = Color(cor.r, cor.g, cor.b, 0.9)


func _estourar() -> void:
	# NAO se usa get_overlapping_bodies() aqui: ele responde com o estado do
	# ultimo passo de fisica, e a area nasceu neste frame -- no instante do
	# estouro ela literalmente ainda nao existia para o servidor de fisica.
	# A consulta direta ao espaco enxerga o agora, e e o que torna a explosao
	# deterministica em vez de "as vezes pega".
	_varrer_agora()

	EventBus.pedido_shake.emit(4.5, 0.16)

	var fx := preload("res://src/fx/explosao.tscn").instantiate()
	fx.global_position = global_position
	fx.modulate = cor
	get_tree().current_scene.add_child(fx)

	_visual.scale = Vector2(0.3, 0.3)
	_borda.scale = Vector2(0.3, 0.3)
	var t := create_tween()
	t.tween_property(_visual, "scale", Vector2.ONE, DURACAO * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_borda, "scale", Vector2.ONE, DURACAO * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.chain().set_parallel(true)
	t.tween_property(_visual, "modulate:a", 0.0, DURACAO * 0.6)
	t.tween_property(_borda, "modulate:a", 0.0, DURACAO * 0.6)
	t.chain().tween_callback(queue_free)


## Pergunta ao servidor de fisica quem esta dentro do circulo AGORA.
func _varrer_agora() -> void:
	var consulta := PhysicsShapeQueryParameters2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = raio
	consulta.shape = circulo
	consulta.transform = Transform2D(0.0, global_position)
	consulta.collision_mask = LAYER_INIMIGO
	consulta.collide_with_areas = false
	consulta.collide_with_bodies = true
	for achado in get_world_2d().direct_space_state.intersect_shape(consulta, 32):
		_ferir(achado["collider"])


## Quem ja tomou nao toma de novo: as duas varreduras cobrem o mesmo alvo, e sem
## a lista a explosao cobraria em dobro de quem estava parado no raio.
var _atingidos: Array[int] = []


func _ferir(corpo: Node) -> void:
	if not corpo.has_method("receber_dano"):
		return
	var no := corpo as Node2D
	if no == null:
		return
	var id := no.get_instance_id()
	if id in _atingidos:
		return
	_atingidos.append(id)

	var afastamento := no.global_position - global_position
	var fracao := clampf(afastamento.length() / maxf(raio, 1.0), 0.0, 1.0)
	var fator := lerpf(1.0, DANO_NA_BORDA, fracao)
	# Piso 1: alvo na borda exata ainda sente o estouro. Dano zero num inimigo
	# que visivelmente foi pego pela explosao le como bug, nao como falloff.
	var final := maxi(roundi(float(dano) * fator), 1)
	var direcao := afastamento.normalized() if afastamento.length_squared() > 0.01 else Vector2.RIGHT
	corpo.receber_dano(final, direcao * knockback * fator)


func _poligono(r: float) -> PackedVector2Array:
	var pontos := PackedVector2Array()
	for i in LADOS:
		pontos.append(Vector2.RIGHT.rotated(TAU * float(i) / float(LADOS)) * r)
	return pontos
