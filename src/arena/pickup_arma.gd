extends Area2D
## Loot no chao. Encoste para pegar: a arma vai para o slot 1 do Player e
## substitui o que estivesse la.

## Preenchido = esta arma. Vazio = sorteia do pool ao nascer. Ficava fixo em
## shotgun.tres dentro do .tscn, e por isso TODA arma dropada no jogo era a
## mesma shotgun -- inclusive a da sala de recompensa.
@export var dados: DadosArma
@export var pool: PoolLoot
@export var gira: bool = true

## O icone de 64 px reduzido ao tamanho em que ele foi MEDIDO.
##
## Gemeo de `PickupItem.ESCALA_ICONE`, e pelo mesmo motivo: 32 px e o contexto do
## chao, e metade e a unica reducao que a pixel art aceita sem reamostrar.
const ESCALA_ICONE := 0.5

var _t: float = 0.0
var _visual: Node2D
var _rotulo: Label
var _icone: Sprite2D


func _ready() -> void:
	_visual = $Visual
	_rotulo = $Rotulo
	_icone = $Icone
	_icone.scale = Vector2.ONE * ESCALA_ICONE

	# Antes de pintar: o visual e o rotulo leem `dados`.
	if dados == null and pool != null:
		dados = pool.sortear_arma()

	if dados != null:
		# Mesma divisao do `PickupItem`: havendo icone, o losango SOLIDO sai e a
		# cor da arma passa para o HALO. Os dois desenhados juntos empilhavam duas
		# respostas para a mesma pergunta, e o solido, sendo opaco, emoldurava o
		# desenho em vez de ficar atras dele.
		$Visual/Halo.color = Color(dados.cor_projetil, $Visual/Halo.color.a)
		$Visual/Corpo.color = dados.cor_projetil
		$Visual/Corpo.visible = dados.icone == null
		_icone.texture = dados.icone
		_icone.visible = dados.icone != null
		_rotulo.text = dados.nome
		_rotulo.modulate = dados.cor_projetil
	body_entered.connect(_ao_encostar)


func _process(delta: float) -> void:
	_t += delta
	if _visual != null:
		_visual.position.y = sin(_t * 3.0) * 5.0
		if gira:
			_visual.rotation += delta * 1.6
		# O icone flutua junto, mas de FORA do `Visual`, que tambem gira: arte de
		# 64 px girando em angulo quebrado reamostra fora da grade.
		_icone.position.y = _visual.position.y


func _ao_encostar(corpo: Node) -> void:
	if not corpo.is_in_group("player") or dados == null:
		return
	if corpo.has_method("equipar_arma_loot"):
		corpo.equipar_arma_loot(dados)
	var fx := preload("res://src/fx/impacto.tscn").instantiate()
	fx.global_position = global_position
	fx.modulate = dados.cor_projetil
	get_parent().add_child(fx)
	queue_free()
