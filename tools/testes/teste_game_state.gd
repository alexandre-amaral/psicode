extends TesteBase
## GameState guarda o estado da run e as ondas .tres descrevem a curva de
## dificuldade. Ambos sao dados que qualquer um edita sem programar, entao o
## que se verifica aqui e consistencia -- nao gameplay.


func nome() -> String:
	return "GameState e ondas"


func executar() -> void:
	_formatar_tempo()
	_estatisticas()
	_curva_das_ondas()


## Usado na tela de fim. Erro aqui aparece para o jogador na ultima tela que ele
## ve na run.
func _formatar_tempo() -> void:
	igual(GameState.formatar_tempo(0.0), "00:00", "zero segundos")
	igual(GameState.formatar_tempo(9.0), "00:09", "segundos tem zero a esquerda")
	igual(GameState.formatar_tempo(59.0), "00:59", "ultimo segundo antes do minuto")
	igual(GameState.formatar_tempo(60.0), "01:00", "vira o minuto certo")
	igual(GameState.formatar_tempo(125.0), "02:05", "minutos e segundos juntos")
	igual(GameState.formatar_tempo(599.0), "09:59", "quase dez minutos")
	igual(GameState.formatar_tempo(3600.0), "60:00", "uma hora conta como 60 minutos")
	# Fracao de segundo trunca, nao arredonda para cima -- senao o cronometro
	# mostraria 00:01 antes de um segundo ter passado.
	igual(GameState.formatar_tempo(1.9), "00:01", "fracao de segundo e truncada")


func _estatisticas() -> void:
	var e := GameState.estatisticas()
	for chave in ["ondas", "total_ondas", "inimigos_mortos", "creditos", "tempo", "deterioracao_final"]:
		ok(e.has(chave), "estatisticas tem a chave '%s'" % chave)
	perto(e["deterioracao_final"], Deterioracao.valor, "deterioracao_final reflete o valor atual")


## As ondas sao o ritmo do vertical slice. As invariantes: existir, escalar a
## barra, e terminar no chefe.
func _curva_das_ondas() -> void:
	var caminhos := [
		"res://src/arena/onda_1.tres",
		"res://src/arena/onda_2.tres",
		"res://src/arena/onda_3.tres",
		"res://src/arena/onda_4.tres",
		"res://src/arena/onda_5.tres",
	]
	var ondas: Array[DadosOnda] = []
	for c: String in caminhos:
		var d: DadosOnda = load(c)
		ok(d != null, "%s carrega" % c.get_file())
		if d != null:
			ondas.append(d)

	if ondas.size() != caminhos.size():
		return

	var chefes := 0
	for i in ondas.size():
		var o := ondas[i]
		var etiqueta := "onda %d" % (i + 1)
		ok(not o.titulo.is_empty(), "%s: tem titulo para o aviso da HUD" % etiqueta)
		ok(o.respiro >= 0.0, "%s: respiro nao e negativo" % etiqueta)
		ok(o.intervalo_spawn >= 0.0, "%s: intervalo de spawn nao e negativo" % etiqueta)
		ok(o.deterioracao_ao_limpar >= 0.0, "%s: deterioracao ao limpar nao e negativa" % etiqueta)
		ok(o.rastejantes >= 0 and o.vigias >= 0, "%s: contagens de inimigos nao sao negativas" % etiqueta)

		if o.eh_chefe:
			chefes += 1
		else:
			# Uma onda comum sem nenhum inimigo nunca seria limpa por contagem:
			# a run travaria ali para sempre.
			ok(o.rastejantes + o.vigias > 0, "%s: tem ao menos um inimigo" % etiqueta)

	igual(chefes, 1, "existe exatamente uma onda de chefe")
	ok(ondas[ondas.size() - 1].eh_chefe, "a ultima onda e a do chefe")

	# A barra tem de chegar perto do topo ao longo da run, senao a fase CRITICA
	# nunca acontece numa partida limpa.
	var soma := 0.0
	for o in ondas:
		soma += o.deterioracao_ao_limpar
	ok(soma > 0.0, "as ondas somam deterioracao ao longo da run")

	# Onda de chefe comecando em nivel critico e o clima que o GDD pede.
	var chefe := ondas[ondas.size() - 1]
	ok(chefe.deterioracao_minima_inicial >= Deterioracao.LIMIAR_MEDIO,
		"a onda do chefe comeca ao menos na fase MEDIA (valor=%.0f)" % chefe.deterioracao_minima_inicial)
