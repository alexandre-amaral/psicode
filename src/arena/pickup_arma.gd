extends Area2D
## Loot no chao. Encoste para pegar. Se ja tiver a mesma arma, recarrega.

@export var dados: DadosArma
@export var gira: bool = true

var _t: float = 0.0
var _visual: Node2D
var _rotulo: Label


func _ready() -> void:
	_visual = $Visual
	_rotulo = $Rotulo
	if dados != null:
		$Visual/Corpo.color = dados.cor_projetil
		_rotulo.text = dados.nome
		_rotulo.modulate = dados.cor_projetil
	body_entered.connect(_ao_encostar)


func _process(delta: float) -> void:
	_t += delta
	if _visual != null:
		_visual.position.y = sin(_t * 3.0) * 5.0
		if gira:
			_visual.rotation += delta * 1.6


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
