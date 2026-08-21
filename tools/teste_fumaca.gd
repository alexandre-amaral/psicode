extends Node
## Teste de fumaca automatizado. Roda o jogo inteiro sem janela e sem humano:
## mata os inimigos por script para avancar as ondas, arranha o chefe aos poucos
## para que as tres fases dele realmente executem, e falha se aparecer qualquer
## erro de script ou se a run nao terminar em vitoria dentro do tempo.
##
## Use:  godot --headless --path . tools/teste_fumaca.tscn
## Saida 0 = passou. Qualquer outra coisa = quebrou.

const TEMPO_LIMITE := 90.0
const INTERVALO_TICK := 0.12
const DANO_POR_TICK_CHEFE := 9

var _t: float = 0.0
var _t_tick: float = 0.0
var _eventos: Array[String] = []
var _falhas: Array[String] = []
var _terminou := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("\n=== TESTE DE FUMACA: psicode ===\n")

	_testar_balistica()

	EventBus.onda_iniciada.connect(func(i: int, t: int) -> void: _log("onda_iniciada %d/%d" % [i + 1, t]))
	EventBus.onda_limpa.connect(func(i: int) -> void: _log("onda_limpa %d (deterioracao %.0f%%)" % [i + 1, Deterioracao.valor]))
	EventBus.fase_deterioracao_mudou.connect(func(n: int, _a: int) -> void: _log("fase_deterioracao -> %s" % Deterioracao.nome_fase()))
	EventBus.boss_revelado.connect(func(nome: String, hp: int) -> void: _log("boss_revelado %s (%d hp)" % [nome, hp]))
	EventBus.boss_fase_mudou.connect(func(f: int) -> void: _log("boss_fase -> %d" % f))
	EventBus.boss_morreu.connect(func() -> void: _log("boss_morreu"))
	EventBus.run_terminada.connect(_ao_terminar)

	add_child(preload("res://src/main/main.tscn").instantiate())


func _process(delta: float) -> void:
	if _terminou:
		return
	_t += delta
	if _t > TEMPO_LIMITE:
		_falhar("tempo limite de %.0fs estourado" % TEMPO_LIMITE)
		_encerrar()
		return

	# O jogador nunca morre no teste -- queremos exercitar o caminho da vitoria.
	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player) and "vida" in player:
		if player.vida < player.vida_maxima:
			player.vida = player.vida_maxima

	_t_tick -= delta
	if _t_tick > 0.0:
		return
	_t_tick = INTERVALO_TICK
	_bater_nos_inimigos()


func _bater_nos_inimigos() -> void:
	for no in get_tree().get_nodes_in_group("inimigo"):
		if not is_instance_valid(no) or not no.has_method("receber_dano"):
			continue
		# O chefe apanha devagar de proposito: se morresse de uma vez, as
		# transicoes de fase e os padroes de ataque nunca rodariam.
		var dano := DANO_POR_TICK_CHEFE if no.get("nome_exibicao") != null else 999
		no.receber_dano(dano, Vector2.ZERO)


func _ao_terminar(venceu: bool, dados: Dictionary) -> void:
	if _terminou:
		return
	_log("run_terminada venceu=%s %s" % [venceu, dados])
	if not venceu:
		_falhar("a run terminou em derrota")
	_encerrar()


# ------------------------------------------------------------- asserts ---

func _testar_balistica() -> void:
	# Alvo parado: o intercepto tem de ser a propria posicao do alvo.
	var p := Balistica.ponto_de_intercepto(Vector2.ZERO, Vector2(100, 0), Vector2.ZERO, 500.0)
	_checar(p.is_equal_approx(Vector2(100, 0)), "intercepto de alvo parado")

	# Alvo cruzando: a previsao tem de cair a frente dele, nunca atras.
	var q := Balistica.ponto_de_intercepto(Vector2.ZERO, Vector2(300, 0), Vector2(0, 200), 600.0)
	_checar(q.y > 0.0, "intercepto antecipa alvo em movimento (y=%.1f)" % q.y)

	# Alvo mais rapido que o projetil e fugindo: sem solucao, cai na posicao atual.
	var r := Balistica.ponto_de_intercepto(Vector2.ZERO, Vector2(100, 0), Vector2(900, 0), 200.0)
	_checar(r.is_equal_approx(Vector2(100, 0)), "sem solucao volta para a posicao atual")

	# Peso 0 tem de ignorar completamente a previsao.
	var s := Balistica.mira_ponderada(Vector2.ZERO, Vector2(300, 0), Vector2(0, 400), 600.0, 0.0)
	_checar(s.is_equal_approx(Vector2(300, 0)), "peso 0 = mira burra")

	# Leque simetrico com a quantidade pedida.
	var leque := Balistica.leque(Vector2.RIGHT, 5, 40.0)
	_checar(leque.size() == 5, "leque devolve 5 direcoes")
	_checar(absf(leque[0].angle() + leque[4].angle()) < 0.001, "leque e simetrico")

	# Anel fechado.
	var anel := Balistica.anel(12)
	_checar(anel.size() == 12, "anel devolve 12 direcoes")
	var soma := Vector2.ZERO
	for d in anel:
		soma += d
	_checar(soma.length() < 0.001, "anel e equilibrado")

	# Limiares da Deterioracao.
	Deterioracao.valor = 49.0
	_checar(not Deterioracao.usa_mira_preditiva(), "49% ainda nao preve")
	Deterioracao.valor = 50.0
	_checar(Deterioracao.usa_mira_preditiva(), "50% comeca a prever")
	_checar(Deterioracao.precisao_preditiva() > 0.0, "precisao preditiva > 0 no limiar")
	Deterioracao.valor = 100.0
	_checar(Deterioracao.precisao_preditiva() >= 0.99, "precisao preditiva satura em 100%")
	Deterioracao.resetar()


func _checar(condicao: bool, descricao: String) -> void:
	if condicao:
		print("  [ok]    %s" % descricao)
	else:
		_falhar(descricao)


func _falhar(descricao: String) -> void:
	print("  [FALHA] %s" % descricao)
	_falhas.append(descricao)


func _log(texto: String) -> void:
	_eventos.append("%6.2fs  %s" % [_t, texto])


func _encerrar() -> void:
	_terminou = true
	print("\n--- linha do tempo ---")
	for e in _eventos:
		print("  " + e)
	print("\n--- resultado ---")
	if _falhas.is_empty():
		print("  PASSOU: %d eventos, %.1fs simulados\n" % [_eventos.size(), _t])
		get_tree().quit(0)
	else:
		print("  FALHOU com %d problema(s):" % _falhas.size())
		for f in _falhas:
			print("    - " + f)
		print("")
		get_tree().quit(1)
