extends Control
## A barra-assinatura. Desenhada na mao para poder mostrar as marcas dos
## limiares (50% e 85%) -- e la que o comportamento dos inimigos muda, entao
## o jogador precisa ver a barra chegando.

@export var altura_barra: float = 13.0

var _valor_exibido: float = 0.0


func _ready() -> void:
	EventBus.deterioracao_mudou.connect(func(_v: float, _f: int) -> void: queue_redraw())


func _process(delta: float) -> void:
	# Persegue o valor real em vez de saltar: a barra "escorrendo" para cima
	# comunica escalada muito melhor que um degrau.
	var alvo := Deterioracao.normalizado()
	if absf(_valor_exibido - alvo) > 0.0005:
		_valor_exibido = move_toward(_valor_exibido, alvo, delta * 0.55)
		queue_redraw()


func _draw() -> void:
	var largura := size.x
	var r := Rect2(Vector2.ZERO, Vector2(largura, altura_barra))

	draw_rect(r, Color(0.06, 0.07, 0.11, 0.85), true)

	var cor := Deterioracao.cor_fase()
	var comprimento_preenchido = largura * (1.0 - _valor_exibido)
	var preenchida := Rect2(Vector2.ZERO, Vector2(comprimento_preenchido, altura_barra))
	draw_rect(preenchida, cor, true)

	# Brilho na ponta -- dá a sensacao de energia acumulando.
	if (1.0 - _valor_exibido) > 0.01:
		var ponta := Rect2(Vector2(comprimento_preenchido - 3.0, 0.0), Vector2(3.0, altura_barra))
		draw_rect(ponta, Color(1, 1, 1, 0.85), true)

	# Marcas dos limiares.
	_marca(largura, 1.0 - (Deterioracao.LIMIAR_MEDIO / Deterioracao.MAXIMO), Color(1, 1, 1, 0.55))
	_marca(largura, 1.0 - (Deterioracao.LIMIAR_CRITICO / Deterioracao.MAXIMO), Color(1, 0.3, 0.4, 0.8))

	draw_rect(r, Color(cor.r, cor.g, cor.b, 0.7), false, 1.5)


func _marca(largura: float, fracao: float, cor: Color) -> void:
	var x := largura * fracao
	draw_line(Vector2(x, -3.0), Vector2(x, altura_barra + 3.0), cor, 2.0)
