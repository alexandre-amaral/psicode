extends Node2D
## Aviso de que um inimigo vai nascer aqui. Existe por um motivo so:
## inimigo que aparece em cima do jogador e dano que o jogador nao podia evitar.

signal terminou(posicao: Vector2)

@export var duracao: float = 0.65
@export var cor: Color = Color(1, 0.35, 0.45, 1)

var _anel: Polygon2D


func _ready() -> void:
	_anel = $Anel
	_anel.color = cor
	_anel.scale = Vector2(0.15, 0.15)
	_anel.modulate.a = 0.0

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_anel, "scale", Vector2.ONE, duracao).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(_anel, "modulate:a", 0.85, duracao * 0.6)
	t.chain().tween_callback(_concluir)


func _process(delta: float) -> void:
	if _anel != null:
		_anel.rotation += delta * 3.0


func _concluir() -> void:
	terminou.emit(global_position)
	queue_free()
