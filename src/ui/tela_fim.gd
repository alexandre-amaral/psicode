extends CanvasLayer
## Tela de fim de run. Cobre tanto derrota quanto vitoria -- e a mesma
## informacao, muda so o tom.

@onready var _fundo: ColorRect = $Fundo
@onready var _titulo: Label = $Painel/Titulo
@onready var _sub: Label = $Painel/Subtitulo
@onready var _stats: Label = $Painel/Stats
@onready var _dica: Label = $Painel/Dica


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	EventBus.run_terminada.connect(_ao_terminar)


func _ao_terminar(venceu: bool, dados: Dictionary) -> void:
	# Deixa a explosao acontecer antes de cortar para a tela.
	await get_tree().create_timer(1.1, true, false, true).timeout

	visible = true
	_fundo.modulate.a = 0.0
	$Painel.modulate.a = 0.0

	if venceu:
		_titulo.text = "DIRETORA OFFLINE"
		_titulo.modulate = Color(0.4, 1.0, 0.85)
		_sub.text = "Voce sobreviveu a propria cabeca. Por enquanto."
	else:
		_titulo.text = "CONSCIENCIA PERDIDA"
		_titulo.modulate = Color(1.0, 0.3, 0.45)
		_sub.text = "Restaurando do ultimo backup..."

	_stats.text = "\n".join([
		"ONDAS SOBREVIVIDAS      %d / %d" % [dados.get("ondas", 0), dados.get("total_ondas", 0)],
		"HOSTIS NEUTRALIZADOS    %d" % dados.get("inimigos_mortos", 0),
		"CREDITOS                %d" % dados.get("creditos", 0),
		"TEMPO                   %s" % GameState.formatar_tempo(dados.get("tempo", 0.0)),
		"DETERIORACAO FINAL      %d%%" % int(dados.get("deterioracao_final", 0.0)),
	])
	_dica.text = "R  reiniciar          ESC  sair"

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_fundo, "modulate:a", 1.0, 0.5)
	t.tween_property($Painel, "modulate:a", 1.0, 0.6)

	get_tree().paused = true

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("reiniciar"):
		get_tree().paused = false
		get_tree().change_scene_to_file("res://src/ui/menu_inicial.tscn")
	elif event.is_action_pressed("pausar"): # Usa pausar(ESC) para sair do jogo a partir da tela de game over
		get_tree().quit()
