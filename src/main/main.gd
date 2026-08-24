extends Node
## Ponto de entrada. Junta Arena, HUD e tela de fim, e cuida das teclas
## globais (reiniciar, pausar, atalho de debug).

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Juice.resetar()
	randomize()


func _unhandled_input(evento: InputEvent) -> void:
	# R so reinicia com a run JA terminada. Durante o jogo a mesma tecla
	# recarrega a arma -- e reiniciar por engano no meio de uma run boa e o
	# tipo de acidente que o jogador nunca perdoa.
	if evento.is_action_pressed("reiniciar") and _run_terminou():
		GameState.reiniciar()
		get_viewport().set_input_as_handled()
		return

	if evento.is_action_pressed("pausar"):
		if GameState.estado == GameState.Estado.GAME_OVER or GameState.estado == GameState.Estado.VITORIA:
			get_tree().quit()
		else:
			GameState.alternar_pausa()
		get_viewport().set_input_as_handled()
		return

	# Atalho de teste: F1 empurra a Deterioracao em +25 para ver as fases
	# sem precisar limpar todas as ondas. So existe em build de debug.
	if OS.is_debug_build() and evento.is_action_pressed("debug_deterioracao"):
		Deterioracao.adicionar(25.0)
		get_viewport().set_input_as_handled()


func _run_terminou() -> bool:
	var e := GameState.estado
	return e == GameState.Estado.GAME_OVER or e == GameState.Estado.VITORIA
