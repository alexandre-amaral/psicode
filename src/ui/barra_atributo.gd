class_name BarraAtributo
extends Control
## Uma linha do perfil da arma: icone, rotulo e a barra em segmentos.
##
## Segmentos e nao barra continua pelo mesmo motivo que a vida do jogador e em
## pips (`barra_vida.gd`): o numero exato nao interessa, "quantos degraus a mais
## que a outra" interessa. Oito degraus dao contraste suficiente para comparar
## duas armas de relance e poucos o bastante para contar sem esforco.
##
## O valor vem de DadosArma.perfil_*(), que le o .tres. Nao ha numero digitado
## aqui: barra que nao mede nada e enfeite que o jogador le como informacao.

enum Icone { DANO, CADENCIA, PRECISAO, ALCANCE }

const SEGMENTOS := 8
const LARGURA_SEG := 15.0
const ALTURA_SEG := 8.0
const ESPACO_SEG := 3.0
const LARGURA_ROTULO := 92.0
const LADO_ICONE := 12.0

var rotulo: String = ""
var icone: Icone = Icone.DANO
var valor: float = 0.0
var cor: Color = Color(0.3, 0.9, 1.0)


func configurar(qual: Icone, texto: String, fracao: float, tinta: Color) -> void:
	icone = qual
	rotulo = texto
	valor = clampf(fracao, 0.0, 1.0)
	cor = tinta
	custom_minimum_size = Vector2(
		LARGURA_ROTULO + LADO_ICONE + 8.0 + SEGMENTOS * (LARGURA_SEG + ESPACO_SEG),
		ALTURA_SEG + 4.0
	)
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var meio := size.y * 0.5
	_desenhar_icone(Vector2(0.0, meio - LADO_ICONE * 0.5))

	var fonte := ThemeDB.fallback_font
	draw_string(
		fonte, Vector2(LADO_ICONE + 8.0, meio + 4.0), rotulo,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.72, 0.78, 0.88)
	)

	# Arredonda para cima com piso 1: uma arma com dano baixissimo ainda tem
	# dano, e uma barra vazia leria como "esta arma nao faz isso".
	var cheios := 0 if valor <= 0.0 else maxi(int(ceil(valor * float(SEGMENTOS))), 1)
	var x := LARGURA_ROTULO + LADO_ICONE + 8.0
	for i in SEGMENTOS:
		var r := Rect2(Vector2(x + i * (LARGURA_SEG + ESPACO_SEG), meio - ALTURA_SEG * 0.5),
			Vector2(LARGURA_SEG, ALTURA_SEG))
		if i < cheios:
			draw_rect(r, cor, true)
		else:
			draw_rect(r, Color(0.10, 0.12, 0.17, 0.9), true)
			draw_rect(r, Color(cor, 0.22), false, 1.0)


## Icones desenhados, e nao PNG: sao quatro formas de doze pixels que a paleta
## do personagem tem de tingir em runtime. Como textura seriam quatro arquivos
## por cor, ou um shader -- desenhados, sao doze linhas.
func _desenhar_icone(canto: Vector2) -> void:
	var l := LADO_ICONE
	var c := canto + Vector2(l, l) * 0.5
	match icone:
		Icone.DANO:
			# Ponta de projetil: losango alongado apontando para a direita.
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(l * 0.5, 0), c + Vector2(-l * 0.1, -l * 0.32),
				c + Vector2(-l * 0.5, -l * 0.32), c + Vector2(-l * 0.5, l * 0.32),
				c + Vector2(-l * 0.1, l * 0.32),
			]), cor)
		Icone.CADENCIA:
			# Raio.
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(l * 0.12, -l * 0.5), c + Vector2(-l * 0.34, l * 0.08),
				c + Vector2(-l * 0.04, l * 0.08), c + Vector2(-l * 0.12, l * 0.5),
				c + Vector2(l * 0.34, -l * 0.08), c + Vector2(l * 0.04, -l * 0.08),
			]), cor)
		Icone.PRECISAO:
			# Mira: circulo com quatro tracos.
			draw_arc(c, l * 0.34, 0.0, TAU, 16, cor, 1.5)
			for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				draw_line(c + d * l * 0.34, c + d * l * 0.5, cor, 1.5)
		Icone.ALCANCE:
			# Seta longa: distancia percorrida.
			draw_line(c + Vector2(-l * 0.5, 0), c + Vector2(l * 0.32, 0), cor, 1.5)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(l * 0.5, 0), c + Vector2(l * 0.2, -l * 0.26),
				c + Vector2(l * 0.2, l * 0.26),
			]), cor)
