extends CPUParticles2D
## Particula "dispare e esqueca": emite uma vez e se remove sozinha.
## Sem isso, cada tiro deixaria um no morto na arvore para sempre.

func _ready() -> void:
	emitting = true
	await get_tree().create_timer(lifetime + 0.2).timeout
	queue_free()
