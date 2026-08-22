extends Node
## Teste de fumaca automatizado. Roda o jogo inteiro sem janela e sem humano:
## mata os inimigos por script para avancar as ondas, arranha o chefe aos poucos
## para que as tres fases dele realmente executem, ANDA pelo andar de sala em
## sala ate o chefe, e falha se aparecer qualquer erro de script ou se a run nao
## terminar em vitoria dentro do tempo.
##
## Decisao de design deste arquivo: o teste nao simula input. Ele conversa com o
## GerenciadorMapa pela API de teste (`celulas`, `vizinhos_de`,
## `celula_do_chefe`, `ir_para_sala`), porque fazer o boneco caminhar corredor
## afora daria um teste lento e sensivel a colisao -- o que se quer verificar
## aqui e que o andar inteiro carrega, ativa e limpa, nao que o personagem sabe
## andar.
##
## Segunda decisao: a sala do chefe fica por ultimo de proposito. Chegar nela
## termina a run, entao ir direto para la passaria o teste sem ter tocado no
## resto do andar. Entre as demais, o criterio de escolha e aproximar do chefe.
##
## Use:  godot --headless --path . tools/teste_fumaca.tscn
## Saida 0 = passou. Qualquer outra coisa = quebrou.

const TEMPO_LIMITE := 240.0
const INTERVALO_TICK := 0.12
const DANO_POR_TICK_CHEFE := 9

## Quanto o teste espera o GerenciadorMapa aparecer no grupo antes de desistir.
## Falhar aqui e muito melhor que ficar parado ate o tempo limite: a mensagem
## diz o que quebrou, o tempo limite so diz que demorou.
const TEMPO_ESPERA_MAPA := 5.0

## Respiro entre uma sala e a seguinte, para a chegada assentar antes de o teste
## pedir a proxima.
const INTERVALO_AVANCO := 0.35

var _t: float = 0.0
var _t_tick: float = 0.0
var _t_avanco: float = 0.0
var _eventos: Array[String] = []
var _falhas: Array[String] = []
var _terminou := false

var _mapa: GerenciadorMapa = null
var _celula_atual: Vector2i = Vector2i.ZERO
var _visitadas: Dictionary = {}
var _salas_percorridas: int = 0


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
	EventBus.sala_limpa.connect(_ao_sala_limpa)
	EventBus.run_terminada.connect(_ao_terminar)

	add_child(preload("res://src/main/main.tscn").instantiate())


func _process(delta: float) -> void:
	if _terminou:
		return
	_t += delta
	if _t > TEMPO_LIMITE:
		_falhar("tempo limite de %.0fs estourado (parou em %s)" % [TEMPO_LIMITE, _descricao_da_sala()])
		_encerrar()
		return

	if not _achar_mapa():
		return

	# O jogador nunca morre no teste -- queremos exercitar o caminho da vitoria.
	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player) and "vida" in player:
		if player.vida < player.vida_maxima:
			player.vida = player.vida_maxima

	_t_avanco -= delta
	_avancar_se_der()

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


# --------------------------------------------------------------- travessia ---

## Busca por grupo e a excecao legitima ao EventBus, e aqui ela e ainda mais
## defensavel: isto e ferramenta de teste, nao codigo de jogo.
func _achar_mapa() -> bool:
	if _mapa != null and is_instance_valid(_mapa):
		return true

	_mapa = get_tree().get_first_node_in_group("gerenciador_mapa") as GerenciadorMapa
	if _mapa == null:
		if _t > TEMPO_ESPERA_MAPA:
			_falhar("nenhum GerenciadorMapa no grupo 'gerenciador_mapa' apos %.0fs -- o andar nao foi gerado" % TEMPO_ESPERA_MAPA)
			_encerrar()
		return false

	if _mapa.celulas().is_empty():
		_falhar("GerenciadorMapa apareceu sem nenhuma celula -- grafo vazio")
		_encerrar()
		return false

	_log("mapa pronto: %d celulas, chefe em %s" % [_mapa.celulas().size(), _mapa.celula_do_chefe()])
	_registrar_chegada()
	return true


## So sai da sala quando ela esta LIMPA. A sondagem do estado existe porque nem
## toda sala emite `sala_limpa`: a de tesouro nasce limpa e nunca emite, e sem
## isto o teste ficaria preso nela ate o tempo limite.
func _avancar_se_der() -> void:
	if _t_avanco > 0.0:
		return
	var sala := _mapa.sala_atual
	if sala == null or sala.estado != Sala.Estado.LIMPA:
		return

	var passo := _proximo_passo()
	if passo.is_empty():
		# Andar inteiro percorrido: so falta o chefe cair, e quem termina a run e
		# a morte dele.
		return

	_t_avanco = INTERVALO_AVANCO
	_mapa.ir_para_sala(passo[0])
	_registrar_chegada()


func _registrar_chegada() -> void:
	var sala := _mapa.sala_atual
	if sala == null:
		return
	_celula_atual = sala.coordenadas_grid
	var revisita := _visitadas.has(_celula_atual)
	_visitadas[_celula_atual] = true
	if not revisita:
		_salas_percorridas += 1
	_log("sala %d/%d %s tipo=%s%s" % [
		_salas_percorridas,
		_mapa.celulas().size(),
		_celula_atual,
		sala.tipo,
		"  (voltando)" if revisita else "",
	])


## Primeiro passo do caminho mais curto ate a celula nao visitada mais proxima.
## Sai de graca dai o retorno por beco sem saida: se a celula atual nao tem
## vizinho novo, o caminho mais curto simplesmente comeca voltando.
## Devolve lista vazia quando nao ha mais para onde ir.
func _proximo_passo() -> Array[Vector2i]:
	var vazio: Array[Vector2i] = []
	var alvos := _alvos()
	if alvos.is_empty():
		return vazio

	var anterior: Dictionary = {_celula_atual: _celula_atual}
	var fila: Array[Vector2i] = [_celula_atual]
	while not fila.is_empty():
		var atual: Vector2i = fila.pop_front()
		if atual != _celula_atual and alvos.has(atual):
			var passo := atual
			while anterior[passo] != _celula_atual:
				passo = anterior[passo]
			var rota: Array[Vector2i] = [passo]
			return rota
		for direcao in _rumo_ao_chefe(_mapa.vizinhos_de(atual), atual):
			var proxima := atual + _para_grid(direcao)
			if anterior.has(proxima):
				continue
			anterior[proxima] = atual
			fila.append(proxima)

	_falhar("celula %s nao alcanca nenhuma das %d salas que faltam -- grafo desconexo" % [_celula_atual, alvos.size()])
	_encerrar()
	return vazio


## Celulas que ainda faltam. A do chefe fica de fora ate ser a ultima: entrar
## nela termina a run, entao ela e o fim do percurso, nunca um atalho.
func _alvos() -> Array[Vector2i]:
	var pendentes: Array[Vector2i] = []
	var chefe := _mapa.celula_do_chefe()
	var chefe_pendente := false
	for celula in _mapa.celulas():
		if _visitadas.has(celula):
			continue
		if celula == chefe:
			chefe_pendente = true
			continue
		pendentes.append(celula)
	if pendentes.is_empty() and chefe_pendente:
		pendentes.append(chefe)
	return pendentes


## Empate entre vizinhos vai para quem encosta mais no chefe: o percurso desce o
## andar em direcao a ele em vez de zigue-zaguear. As distancias sao calculadas
## antes e o comparador so le o dicionario -- lambda que chama metodo do proprio
## script dentro de sort_custom e terreno onde ja se perdeu tempo aqui.
func _rumo_ao_chefe(direcoes: Array[Vector2], origem: Vector2i) -> Array[Vector2]:
	var chefe := _mapa.celula_do_chefe()
	var distancias: Dictionary = {}
	var lista: Array[Vector2] = []
	for direcao in direcoes:
		lista.append(direcao)
		distancias[direcao] = _distancia_grid(origem + _para_grid(direcao), chefe)
	lista.sort_custom(func(a: Vector2, b: Vector2) -> bool: return int(distancias[a]) < int(distancias[b]))
	return lista


func _distancia_grid(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _para_grid(direcao: Vector2) -> Vector2i:
	return Vector2i(roundi(direcao.x), roundi(direcao.y))


func _descricao_da_sala() -> String:
	if _mapa == null or not is_instance_valid(_mapa) or _mapa.sala_atual == null:
		return "nenhuma sala ativa"
	return "%s tipo=%s estado=%d (%d/%d salas)" % [
		_celula_atual,
		_mapa.sala_atual.tipo,
		_mapa.sala_atual.estado,
		_salas_percorridas,
		_mapa.celulas().size(),
	]


# ------------------------------------------------------------------ fim ------

func _ao_sala_limpa(sala: Node2D) -> void:
	var limpa := sala as Sala
	if limpa != null:
		_log("sala_limpa %s tipo=%s" % [limpa.coordenadas_grid, limpa.tipo])
	else:
		_log("sala_limpa de um no que nao e Sala: %s" % sala)
	# Limpou: pode seguir ja no proximo frame, sem esperar o respiro acabar.
	_t_avanco = 0.0


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
		print("  PASSOU: %d eventos, %d salas, %.1fs simulados\n" % [_eventos.size(), _salas_percorridas, _t])
		get_tree().quit(0)
	else:
		print("  FALHOU com %d problema(s):" % _falhas.size())
		for f in _falhas:
			print("    - " + f)
		print("")
		get_tree().quit(1)
