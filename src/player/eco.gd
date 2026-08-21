extends Polygon2D
## Rastro fantasma deixado pelo rolamento. Comunica os i-frames sem HUD:
## enquanto voce ve os ecos, voce esta invulneravel.

func iniciar(pontos: PackedVector2Array, cor: Color, duracao: float = 0.28) -> void:
	polygon = pontos
	color = cor
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, duracao)
	t.tween_callback(queue_free)
