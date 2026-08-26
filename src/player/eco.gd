extends Sprite2D
## Um quadro congelado do jogador, que apaga sozinho. E o unico aviso de que os
## i-frames do rolamento estao valendo: enquanto ha eco na tela, voce e
## intocavel -- sem icone, sem barra, sem numero.
##
## Era um Polygon2D com a silhueta do corpo copiada a mao. Virou Sprite2D quando
## o jogador ganhou arte: o rastro passa a ser a personagem de verdade, no
## quadro em que ela estava, em vez de um octogono que nao se parecia mais com
## nada em tela.

func iniciar(textura: Texture2D, cor: Color, duracao: float = 0.28) -> void:
	texture = textura
	modulate = cor
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, duracao)
	t.tween_callback(queue_free)
