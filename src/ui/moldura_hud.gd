class_name MolduraHud
extends MarginContainer
## Moldura de canto chanfrado, no estilo de painel de HUD cyberpunk.
##
## Existe como no desenhado e nao como StyleBoxFlat porque StyleBox so sabe
## canto reto ou arredondado -- o chanfro (o canto "cortado" na diagonal) e
## justamente o que da a leitura de interface tecnica, e nao ha propriedade que
## o produza. Desenhar tambem sai mais barato que um NinePatch: nao entra
## textura nova no projeto, e a cor vem do personagem em runtime.
##
## E generico de proposito: a mesma moldura serve o quadro externo, cada cartao
## e a barra de baixo, mudando so cor e espessura. Um formato, tres usos.
##
## MarginContainer e nao Control, e isso importa: como Control puro ela nao tem
## altura minima vinda do conteudo, entao um cartao com `size_flags_vertical =
## SHRINK_CENTER` nascia com altura ZERO e todo o texto vazava para fora da
## moldura. Sendo container, ela cresce com o que esta dentro -- e o `_draw` do
## pai roda antes dos filhos, entao a borda fica atras do conteudo de graca.

## Quanto de cada canto e cortado na diagonal.
@export var chanfro: float = 14.0:
	set(v):
		chanfro = v
		queue_redraw()

@export var cor_borda: Color = Color(0.3, 0.9, 1.0):
	set(v):
		cor_borda = v
		queue_redraw()

@export var cor_fundo: Color = Color(0.04, 0.05, 0.08, 0.92):
	set(v):
		cor_fundo = v
		queue_redraw()

@export var espessura: float = 2.0:
	set(v):
		espessura = v
		queue_redraw()

## A linha fina paralela por dentro. E ela que faz a moldura parecer usinada em
## vez de apenas contornada; sem ela a borda fica com cara de retangulo comum.
@export var linha_interna: bool = true:
	set(v):
		linha_interna = v
		queue_redraw()

@export var recuo_linha_interna: float = 5.0

## Colchetes nos cantos, como marca de canto de visor.
@export var colchetes: bool = false:
	set(v):
		colchetes = v
		queue_redraw()

@export var tamanho_colchete: float = 18.0

## Respiro entre a borda e o conteudo, nos quatro lados. Existe como um numero
## so porque nenhum uso do projeto precisou de margens diferentes por lado.
@export var margem: int = 16:
	set(v):
		margem = v
		_aplicar_margem()


func _ready() -> void:
	# A moldura e fundo: clique e foco pertencem a quem esta dentro dela.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	_aplicar_margem()


func _aplicar_margem() -> void:
	if not is_inside_tree():
		return
	for lado in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		add_theme_constant_override(lado, margem)


## Os oito pontos do octogono, no sentido horario a partir do topo-esquerdo.
static func contorno(tamanho: Vector2, corte: float) -> PackedVector2Array:
	var c: float = minf(corte, minf(tamanho.x, tamanho.y) * 0.5)
	var l: float = tamanho.x
	var a: float = tamanho.y
	return PackedVector2Array([
		Vector2(c, 0.0), Vector2(l - c, 0.0),
		Vector2(l, c), Vector2(l, a - c),
		Vector2(l - c, a), Vector2(c, a),
		Vector2(0.0, a - c), Vector2(0.0, c),
	])


func _draw() -> void:
	var pontos := contorno(size, chanfro)

	if cor_fundo.a > 0.0:
		draw_colored_polygon(pontos, cor_fundo)

	# Fechado: draw_polyline nao une o ultimo ponto ao primeiro sozinho, e sem
	# repetir a origem sobra uma fresta numa das quinas.
	var fechado := pontos.duplicate()
	fechado.append(pontos[0])
	draw_polyline(fechado, cor_borda, espessura)

	if linha_interna:
		var dentro := contorno(
			size - Vector2.ONE * (recuo_linha_interna * 2.0),
			maxf(chanfro - recuo_linha_interna, 2.0)
		)
		var deslocado := PackedVector2Array()
		for p in dentro:
			deslocado.append(p + Vector2.ONE * recuo_linha_interna)
		deslocado.append(deslocado[0])
		draw_polyline(deslocado, Color(cor_borda, cor_borda.a * 0.28), 1.0)

	if colchetes:
		_desenhar_colchetes()


## Traços curtos nas quatro quinas, por dentro do chanfro.
func _desenhar_colchetes() -> void:
	var t: float = tamanho_colchete
	var m: float = chanfro + 3.0
	var cantos := [
		[Vector2(m, m), Vector2(1, 0), Vector2(0, 1)],
		[Vector2(size.x - m, m), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(size.x - m, size.y - m), Vector2(-1, 0), Vector2(0, -1)],
		[Vector2(m, size.y - m), Vector2(1, 0), Vector2(0, -1)],
	]
	for canto in cantos:
		var o: Vector2 = canto[0]
		draw_line(o, o + (canto[1] as Vector2) * t, cor_borda, 2.0)
		draw_line(o, o + (canto[2] as Vector2) * t, cor_borda, 2.0)
