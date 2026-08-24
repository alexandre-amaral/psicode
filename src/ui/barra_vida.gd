extends Control
## Vida em segmentos. Numero exato importa menos que "quantos erros ainda cabem".

const LARGURA_PIP := 16.0
const ALTURA_PIP := 10.0
const ESPACO := 4.0

var vida: int = 6
var vida_maxima: int = 6
var _piscando: float = 0.0


func _ready() -> void:
	EventBus.player_dano_recebido.connect(_atualizar)
	EventBus.player_curado.connect(_atualizar)


func _atualizar(atual: int, maximo: int) -> void:
	if atual < vida:
		_piscando = 0.35
	vida = atual
	vida_maxima = maximo
	queue_redraw()


func _process(delta: float) -> void:
	if _piscando > 0.0:
		_piscando = maxf(_piscando - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	for i in vida_maxima:
		var x := i * (LARGURA_PIP + ESPACO)
		var r := Rect2(Vector2(x, 0.0), Vector2(LARGURA_PIP, ALTURA_PIP))
		if i < vida:
			var cor := Color(0.35, 0.95, 1.0)
			if vida <= 2:
				# Vida critica pulsa: o jogador precisa saber sem olhar a HUD.
				var p := absf(sin(Time.get_ticks_msec() * 0.008))
				cor = Color(1.0, 0.3, 0.42).lerp(Color(1, 0.85, 0.9), p)
			if _piscando > 0.0:
				cor = cor.lerp(Color.WHITE, _piscando * 2.0)
			draw_rect(r, cor, true)
		else:
			draw_rect(r, Color(0.16, 0.18, 0.26, 0.9), true)
			draw_rect(r, Color(0.3, 0.34, 0.45, 0.6), false, 1.0)
