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

## Quantas vezes a grossura do feixe mede o ponto de impacto.
##
## O §15 do plano pede ORIGEM, CORPO e PONTO DE IMPACTO distintos, e o feixe
## tinha os dois primeiros: ele simplesmente TERMINAVA. Um raio que acaba no ar e
## um raio que nao diz onde esta queimando -- e onde ele queima e a unica
## informacao que o jogador precisa dele.
##
## 1,6 e a menor razao em que o ponto ainda se separa do traco a 6 px de
## grossura: abaixo disso ele vira um engrossamento da ponta, que le como o feixe
## estar fora de foco em vez de estar batendo em algo.
const RAIO_DO_IMPACTO := 1.6

## Quantos lados o ponto de impacto tem.
##
## Sete e nao oito: um poligono de lado par a 10 px de diametro le como um
## losango ou um quadrado -- uma FORMA --, e o ponto de impacto tem de ler como
## brilho. Impar quebra a simetria de eixo e o olho para de achar a figura.
const LADOS_DO_IMPACTO := 7

var _nucleo: Line2D
var _impacto: Polygon2D


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

	# O ponto de impacto, tambem em codigo e pela mesma razao do nucleo.
	_impacto = Polygon2D.new()
	_impacto.top_level = true
	_impacto.z_index = 37
	add_child(_impacto)


## Chamado a cada frame em que o feixe esta ligado.
func apontar(de: Vector2, para: Vector2, tinta: Color, grossura: float,
		bateu: bool = false) -> void:
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

	# O PONTO DE IMPACTO fica na ponta, e ele so existe quando ha ponta.
	#
	# `bateu` e falso quando o feixe morre no alcance sem encostar em nada: ali
	# nao ha impacto nenhum, e desenhar um diria que o raio esta queimando o ar.
	_impacto.visible = bateu
	if bateu:
		_impacto.position = para
		_impacto.polygon = _estrela(grossura * RAIO_DO_IMPACTO)
		_impacto.color = tinta.lerp(Color.WHITE, 0.55)


## O poligono do ponto de impacto, centrado na origem.
func _estrela(raio: float) -> PackedVector2Array:
	var pontos := PackedVector2Array()
	for i in LADOS_DO_IMPACTO:
		var a := TAU * float(i) / float(LADOS_DO_IMPACTO)
		pontos.append(Vector2(cos(a), sin(a)) * raio)
	return pontos
