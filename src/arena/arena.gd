extends Node2D
## A arena de testes. Uma sala fechada, como o GDD pediu para o vertical slice.
## Ela desenha o proprio chao (nada de assets ainda), limita a camera e
## repassa o comeco da run para o GerenciadorOndas.

@export var tamanho: Vector2 = Vector2(1600, 900)
@export var espacamento_grade: float = 80.0
@export var cor_fundo: Color = Color("0b0d16")
@export var cor_grade: Color = Color(0.25, 0.55, 0.8, 0.13)
@export var cor_borda: Color = Color(0.3, 0.9, 1.0, 0.55)
## Para onde o chao puxa quando a Deterioracao esta no maximo.
@export var cor_fundo_critica: Color = Color("1a0a14")

var _ondas: GerenciadorOndas
var _borda: Line2D
var _player: Node2D


func _ready() -> void:
	_ondas = $Ondas
	_borda = $Borda
	_montar_borda()
	queue_redraw()

	EventBus.player_pronto.connect(_ao_player_pronto)
	EventBus.deterioracao_mudou.connect(_ao_mudar_deterioracao)

	GameState.iniciar_run()
	_ondas.iniciar()


func _draw() -> void:
	var meia := tamanho * 0.5
	draw_rect(Rect2(-meia, tamanho), cor_fundo, true)

	# Grade -- referencia espacial para o jogador medir distancia e esquiva.
	var x := -meia.x
	while x <= meia.x:
		draw_line(Vector2(x, -meia.y), Vector2(x, meia.y), cor_grade, 1.0)
		x += espacamento_grade
	var y := -meia.y
	while y <= meia.y:
		draw_line(Vector2(-meia.x, y), Vector2(meia.x, y), cor_grade, 1.0)
		y += espacamento_grade

	# Marca do centro: onde a Diretora vai nascer.
	draw_arc(Vector2.ZERO, 120.0, 0.0, TAU, 48, Color(0.5, 0.3, 0.8, 0.16), 2.0)
	draw_arc(Vector2.ZERO, 60.0, 0.0, TAU, 32, Color(0.5, 0.3, 0.8, 0.1), 2.0)


func _montar_borda() -> void:
	var meia := tamanho * 0.5
	_borda.clear_points()
	_borda.add_point(Vector2(-meia.x, -meia.y))
	_borda.add_point(Vector2(meia.x, -meia.y))
	_borda.add_point(Vector2(meia.x, meia.y))
	_borda.add_point(Vector2(-meia.x, meia.y))
	_borda.add_point(Vector2(-meia.x, -meia.y))
	_borda.default_color = cor_borda


func _ao_player_pronto(player: Node2D) -> void:
	_player = player
	var cam: Camera2D = player.get_node_or_null("Camera")
	if cam == null:
		return
	# Prende a camera na arena: sem isso ela mostraria o vazio fora das paredes.
	var meia := tamanho * 0.5
	cam.limit_left = int(-meia.x)
	cam.limit_right = int(meia.x)
	cam.limit_top = int(-meia.y)
	cam.limit_bottom = int(meia.y)


func _ao_mudar_deterioracao(_valor: float, _fase: int) -> void:
	var t := Deterioracao.normalizado()
	cor_fundo = Color("0b0d16").lerp(cor_fundo_critica, t)
	cor_borda = Color(0.3, 0.9, 1.0, 0.55).lerp(Color(1.0, 0.2, 0.4, 0.8), t)
	_borda.default_color = cor_borda
	queue_redraw()
