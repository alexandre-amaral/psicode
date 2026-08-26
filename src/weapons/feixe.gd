class_name Feixe
extends Line2D
## O risco continuo do Laser Cutter, redesenhado todo frame enquanto o gatilho
## estiver apertado.
##
## Ele e SO leitura: quem fere e o raycast da Arma. A separacao existe porque o
## feixe precisa acompanhar a mira a 60 fps, e um no que tambem calculasse dano
## teria de decidir a cada frame se ja cobrou -- exatamente o tipo de estado
## duplicado que fez o projetil nascer ciano antes do `_aplicar_aparencia`.
##
## `top_level` ligado pelo mesmo motivo do rastro do projetil: sem ele os pontos
## herdariam a rotacao da arma e o feixe descreveria um arco ao girar a mira,
## em vez de ficar preso onde a mira aponta.

## Quanto o nucleo branco e mais fino que a borda colorida.
const FRACAO_NUCLEO := 0.4

var _nucleo: Line2D


func _ready() -> void:
	top_level = true
	z_index = 35
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND

	# O nucleo nasce em codigo e nao na cena: sub-resource de .tscn e
	# COMPARTILHADO entre instancias, e duas armas de feixe na mesma run
	# escreveriam uma por cima da outra. Mesma armadilha da forma de colisao.
	_nucleo = Line2D.new()
	_nucleo.top_level = true
	_nucleo.z_index = 36
	_nucleo.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_nucleo.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_nucleo)


## Chamado a cada frame em que o feixe esta ligado.
func apontar(de: Vector2, para: Vector2, tinta: Color, grossura: float) -> void:
	var pontos := PackedVector2Array([de, para])
	points = pontos
	width = grossura
	default_color = Color(tinta.r, tinta.g, tinta.b, 0.55)

	_nucleo.points = pontos
	_nucleo.width = grossura * FRACAO_NUCLEO
	# Nucleo puxado para o branco: e o que da a leitura de "isto queima" sem
	# precisar de shader, e o export web nao aceita SCREEN_TEXTURE de qualquer
	# jeito.
	_nucleo.default_color = tinta.lerp(Color.WHITE, 0.7)
