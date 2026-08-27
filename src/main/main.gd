extends Node
## Ponto de entrada. Junta Arena, HUD e tela de fim, e cuida das teclas
## globais (pausar, atalho de debug).
##
## O R saiu daqui. Ele reiniciava a run com a tela de fim aberta, e era a unica
## acao do jogo que so existia como tecla decorada num rotulo -- hoje a tela de
## fim tem botao para isso, como as outras tres telas sempre tiveram.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Juice.resetar()
	randomize()


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("pausar"):
		if GameState.estado == GameState.Estado.GAME_OVER or GameState.estado == GameState.Estado.VITORIA:
			# Nao chega aqui com a tela de fim aberta: ela trata o ESC no _input,
			# que roda antes, e marca o evento como tratado para voltar ao menu.
			# Este ramo cobre o caso de a run ter terminado sem a tela visivel.
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
