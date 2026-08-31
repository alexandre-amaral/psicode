extends TesteBase
## O AUTOMATO ENFERRUJADO: tres fases e o multiplicador central (BOSS 01/02).
##
## A identidade dele cabe numa frase -- "quanto mais danificado ele fica, mais
## rapido funciona" --, e ela mora inteira num numero so. Por isso esta suite
## cobra o numero, e nao a sensacao: se `tempo_real()` deixar de alcancar um dos
## tempos, o jogador ve um robo andando rapido com ataques no mesmo ritmo, e a
## ideia inteira nao chega. Nao ha erro no console para isso.
##
## Os dois casos que mais valem estao no fim:
##
## - **O piso contra o PIOR CASO.** O multiplicador de fase 3 nao e o pior caso:
##   a Deterioracao multiplica dificuldade por cima dele. Um piso conferido so
##   contra 1,30 passaria aqui e furaria em jogo, com a barra cheia.
## - **A transicao de fase nao pode ser interrompida.** O HP cruza o limiar no
##   meio de uma sequencia, e o dano continua chegando durante a virada.

const CENA := preload("res://src/enemies/boss_guardiao_01.tscn")

## Longe da origem, como as outras suites que instanciam inimigo.
const LONGE := Vector2(71000.0, 71000.0)

var _barra_original: float = 0.0


func nome() -> String:
	return "BossGuardiao01"


func executar() -> void:
	_barra_original = Deterioracao.valor
	_as_tres_fases_saem_da_fracao_de_vida()
	_o_multiplicador_alcanca_tudo()
	_o_piso_vale_contra_o_pior_caso()
	_a_transicao_acontece_uma_vez_por_virada()
	_a_transicao_nao_e_interrompida_por_ataque()
	_ele_persegue_e_a_diretora_continua_intocada()
	_a_vitoria_da_run_nao_depende_de_quem_e_o_chefe()
	await _da_para_dizer_a_fase_sem_olhar_a_barra()
	_nenhum_efeito_de_fase_cobre_telegrafo_ou_projetil()
	Deterioracao.valor = _barra_original


## As fases saem da FRACAO e nao do valor absoluto: mexer na vida do chefe na
## sessao de tuning nao pode reescrever onde as viradas acontecem.
func _as_tres_fases_saem_da_fracao_de_vida() -> void:
	var chefe := _nascer()
	var maximo: int = chefe.vida_maxima
	ok(maximo >= 100, "o chefe tem vida de chefe (%d)" % maximo)

	for caso in [
		{"fracao": 1.00, "fase": 1}, {"fracao": 0.80, "fase": 1},
		{"fracao": 0.66, "fase": 2}, {"fracao": 0.50, "fase": 2},
		{"fracao": 0.33, "fase": 3}, {"fracao": 0.01, "fase": 3},
	]:
		chefe.vida = maxi(int(round(float(maximo) * caso["fracao"])), 1)
		igual(chefe.fase_por_vida(), caso["fase"],
			"com %.0f%% de vida ele esta na fase %d" % [caso["fracao"] * 100.0, caso["fase"]])

	# O tuning muda a vida e as viradas continuam nos mesmos TERCOS.
	chefe.vida_maxima = 900
	chefe.vida = 600
	igual(chefe.fase_por_vida(), 2, "com o dobro da vida, 600/900 continua sendo a fase 2")
	chefe.free()


## O multiplicador tem de alcancar MOVIMENTO e TEMPO ao mesmo tempo.
##
## Se ele valesse so para a movimentacao, o jogador veria um robo andando rapido
## com ataques no mesmo ritmo. E o inverso -- so nos tempos -- daria um robo
## lento com ataques nervosos. Sao os dois, e e por isso que os dois sao
## cobrados aqui lado a lado.
func _o_multiplicador_alcanca_tudo() -> void:
	var chefe := _nascer()
	Deterioracao.valor = 0.0

	ok(chefe.multiplicador_de(1) < chefe.multiplicador_de(2),
		"a fase 2 destrava a maquina (%.2f -> %.2f)"
			% [chefe.multiplicador_de(1), chefe.multiplicador_de(2)])
	ok(chefe.multiplicador_de(2) < chefe.multiplicador_de(3),
		"e a fase 3 a leva acima do limite (%.2f -> %.2f)"
			% [chefe.multiplicador_de(2), chefe.multiplicador_de(3)])
	ok(chefe.multiplicador_de(1) < 1.0,
		"a fase 1 e mais LENTA que o normal: ele nao e lento por design, esta travado")

	var velocidades: Array[float] = []
	var telegrafos: Array[float] = []
	for fase in [1, 2, 3]:
		chefe.fase_chefe = fase
		velocidades.append(chefe.velocidade_atual())
		telegrafos.append(chefe.tempo_real(chefe.tempo_preparo))

	ok(velocidades[0] < velocidades[1] and velocidades[1] < velocidades[2],
		"ele ANDA mais rapido a cada fase (%.0f, %.0f, %.0f px/s)"
			% [velocidades[0], velocidades[1], velocidades[2]])
	ok(telegrafos[0] > telegrafos[1] and telegrafos[1] > telegrafos[2],
		"e o mesmo ataque acontece mais rapido (%.2f, %.2f, %.2f s)"
			% [telegrafos[0], telegrafos[1], telegrafos[2]])

	# Nada guarda o produto: perder vida no meio de um passo ja acelera o passo.
	chefe.fase_chefe = 1
	var lento: float = chefe.velocidade_atual()
	Deterioracao.valor = 100.0
	ok(chefe.velocidade_atual() > lento,
		"a velocidade le a Deterioracao no frame (%.0f -> %.0f px/s)"
			% [lento, chefe.velocidade_atual()])
	Deterioracao.valor = 0.0
	chefe.free()


## O PISO, contra o pior caso de verdade.
##
## O pior caso nao e o multiplicador de fase 3 sozinho: a Deterioracao multiplica
## dificuldade POR CIMA dele e chega a 1,7x em cadencia. Um piso conferido so
## contra 1,30 passaria neste teste e furaria em jogo com a barra cheia -- e
## telegrafo abaixo do piso e a fronteira entre "dificil" e "mente sobre a
## propria regra".
func _o_piso_vale_contra_o_pior_caso() -> void:
	var chefe := _nascer()
	perto(chefe.TEMPO_MINIMO, Telegrafo.DURACAO_MINIMA,
		"o piso do chefe e o mesmo do Telegrafo")

	var tempos := [
		chefe.tempo_escolha, chefe.tempo_preparo, chefe.tempo_execucao,
		chefe.tempo_recuperacao, chefe.tempo_transicao, chefe.tempo_atordoado,
	]
	var furou := false
	var menor := 999.0
	for fase in [1, 2, 3]:
		chefe.fase_chefe = fase
		var barra := 0.0
		while barra <= 100.0:
			Deterioracao.valor = barra
			for base: float in tempos:
				var real: float = chefe.tempo_real(base)
				furou = furou or real < chefe.TEMPO_MINIMO - 0.0001
				menor = minf(menor, real)
			barra += 5.0
	ok(not furou,
		"nenhum tempo cai abaixo do piso, em nenhuma fase e em nenhum valor da barra")
	perto(menor, chefe.TEMPO_MINIMO,
		"e o piso de fato MORDE no pior caso -- senao ele nunca foi testado", 0.0001)

	# A prova de que o pior caso e o combinado, e nao a fase sozinha.
	chefe.fase_chefe = 3
	Deterioracao.valor = 0.0
	var so_a_fase: float = chefe.tempo_execucao / chefe.multiplicador_total()
	Deterioracao.valor = 100.0
	var com_a_barra: float = chefe.tempo_execucao / chefe.multiplicador_total()
	ok(com_a_barra < so_a_fase,
		"a barra cheia comprime alem da fase 3 (%.2f s contra %.2f) -- e por isso o piso e contra ela"
			% [com_a_barra, so_a_fase])

	Deterioracao.valor = 0.0
	chefe.free()


## Cada virada acontece UMA vez.
##
## Sem a bandeira, o HP oscilando em volta do limiar -- e ele oscila, porque a
## vida cai a cada tiro -- reentraria em TRANSICAO_FASE a cada frame, e o chefe
## nunca mais atacaria. O sintoma seria "o chefe travou", que e a categoria de
## bug mais cara de perseguir depois.
func _a_transicao_acontece_uma_vez_por_virada() -> void:
	var chefe := _nascer()
	chefe._maquina.trocar(chefe.ESCOLHER_ATAQUE)

	chefe.vida = int(float(chefe.vida_maxima) * 0.6)
	chefe._checar_fase()
	ok(chefe.em_transicao(), "cruzar o primeiro limiar entra em TRANSICAO_FASE")
	igual(chefe.fase_chefe, 2, "e a fase sobe na ENTRADA da transicao")

	# Sai da transicao e volta a atacar.
	chefe._maquina.trocar(chefe.ESCOLHER_ATAQUE)
	chefe._checar_fase()
	ok(not chefe.em_transicao(),
		"continuar apanhando dentro da mesma fase NAO reentra na transicao")

	# Curar de volta para a fase 1 e cair de novo nao repete a virada: ela ja
	# aconteceu, e reencena-la seria o chefe "virando" duas vezes.
	chefe.vida = chefe.vida_maxima
	chefe._checar_fase()
	ok(not chefe.em_transicao(), "curar nao desfaz uma virada ja acontecida")
	chefe.vida = int(float(chefe.vida_maxima) * 0.6)
	chefe._checar_fase()
	ok(not chefe.em_transicao(), "e cair de novo no mesmo limiar nao a repete")

	# A SEGUNDA virada, essa sim, acontece.
	chefe.vida = int(float(chefe.vida_maxima) * 0.2)
	chefe._checar_fase()
	ok(chefe.em_transicao(), "cruzar o segundo limiar entra em transicao de novo")
	igual(chefe.fase_chefe, 3, "e ele chega na fase 3")
	chefe.free()


## Durante TRANSICAO_FASE, nenhum ataque novo comeca.
##
## E o que evita o problema de o HP cruzar o limiar no MEIO de uma sequencia: sem
## isso, o jogador leria o telegrafo de uma fase e levaria o golpe de outra.
func _a_transicao_nao_e_interrompida_por_ataque() -> void:
	var chefe := _nascer()
	chefe.vida = int(float(chefe.vida_maxima) * 0.6)
	chefe._checar_fase()
	ok(chefe.em_transicao(), "ele esta virando de fase (pre-condicao)")

	# O dano CONTINUA chegando durante a virada -- e o caso real, nao o
	# hipotetico: o jogador nao para de atirar porque o chefe mudou de fase.
	for _i in 20:
		chefe.vida = maxi(chefe.vida - 5, 1)
		chefe._comportamento(0.016)
		if not chefe.em_transicao():
			break
	ok(chefe.em_transicao(),
		"e continua virando mesmo levando dano: nenhum ataque novo comeca no meio")

	# Passado o tempo, ela termina -- e termina escolhendo, nao atacando.
	var saiu := false
	for _i in 400:
		chefe._comportamento(0.016)
		if not chefe.em_transicao():
			saiu = true
			break
	ok(saiu, "e a transicao TERMINA -- ela nao pode virar um estado permanente")
	igual(String(chefe._maquina.estado), "ESCOLHER_ATAQUE",
		"e ele sai dela escolhendo o proximo ataque")
	chefe.free()


## Ele PERSEGUE -- e e por isso que ele e um inimigo novo e nao uma reforma.
##
## A trava 7 de `teste_diretora.gd` diz que a Diretora NUNCA persegue, porque
## "um sistema nao corre atras de voce". As duas identidades sao opostas, e
## reformar a Diretora para caber nesta exigiria afrouxar aquele portao -- a
## personagem deixaria de existir sem uma linha no console. Aqui se cobra os dois
## lados: que o Automato persegue, e que o portao dela continua no runner.
func _ele_persegue_e_a_diretora_continua_intocada() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)
	var jogador := CharacterBody2D.new()
	jogador.add_to_group("player")
	raiz.add_child(jogador)
	jogador.global_position = LONGE + Vector2(400.0, 0.0)

	var chefe := CENA.instantiate()
	raiz.add_child(chefe)
	chefe.global_position = LONGE
	chefe._maquina.trocar(chefe.ESCOLHER_ATAQUE)
	chefe._comportamento(0.05)
	ok(chefe.velocity.x > 0.0,
		"o Automato anda PARA o jogador (vx %.0f) -- ele investe, soca e pisa" % chefe.velocity.x)
	raiz.free()

	var runner := FileAccess.get_file_as_string("res://tools/testes/runner.gd")
	ok(runner.contains("teste_diretora.gd"),
		"e o portao da Diretora continua no runner: as travas dela nao foram afrouxadas")


## A vitoria da run NAO sai da morte do chefe, e trocar o chefe nao mexe nisso.
##
## Quem chama `terminar_run(true)` e o `GerenciadorMapa`, quando a sala do tipo
## `boss` fica LIMPA. A issue pede para VERIFICAR que essa chamada sobreviveu, e
## a razao e historica: ela ja se perdeu uma vez neste projeto ao trocar quem
## hospeda a run, e o sintoma foi silencioso -- a Deterioracao passiva
## simplesmente parou de subir.
func _a_vitoria_da_run_nao_depende_de_quem_e_o_chefe() -> void:
	var mapa := FileAccess.get_file_as_string("res://src/mapa/gerenciador_mapa.gd")
	ok(mapa.contains("GameState.terminar_run(true)"),
		"o GerenciadorMapa continua encerrando a run em vitoria")
	ok(mapa.contains("DadosSala.ID_BOSS"),
		"e o gatilho continua sendo a sala do tipo boss ficar limpa")

	# So o CODIGO, sem os comentarios: o cabecalho do Automato explica justamente
	# que a vitoria nao sai dele, e citar a funcao para explicar isso nao pode
	# contar como chama-la.
	ok(not _codigo_de("res://src/enemies/boss_guardiao_01.gd").contains("terminar_run"),
		"o Automato NAO chama terminar_run: duas fontes de vitoria divergiriam na primeira mudanca")


## O fonte sem as linhas de comentario.
func _codigo_de(caminho: String) -> String:
	var linhas := PackedStringArray()
	for linha in FileAccess.get_file_as_string(caminho).split("
"):
		if linha.strip_edges().begins_with("#"):
			continue
		linhas.append(linha)
	return "
".join(linhas)


## BOSS 07: da para dizer em que fase ele esta SEM olhar a barra de vida.
##
## Se o jogador nao VE a maquina destravar, a mecanica inteira da luta -- dano
## que acelera -- nao chega, e ele so sente que o chefe ficou injusto de repente.
## Por isso a leitura e cobrada em numero: o pulso do nucleo e o desgaste da
## carcaca tem de MUDAR entre as fases, e nao so existir.
func _da_para_dizer_a_fase_sem_olhar_a_barra() -> void:
	var chefe := _nascer()

	var pulsos: Array[float] = []
	for fase in [1, 2, 3]:
		chefe.fase_chefe = fase
		pulsos.append(chefe.pulso_da_fase())
	ok(pulsos[0] < pulsos[1] and pulsos[1] < pulsos[2],
		"o nucleo pulsa mais rapido a cada fase (%.1f, %.1f, %.1f Hz)"
			% [pulsos[0], pulsos[1], pulsos[2]])
	ok(pulsos[0] > 0.0, "e nunca para: nucleo apagado tiraria o sinal de que ele funciona")

	# OS TRES ESTADOS DE DETERIORACAO que a BOSS 10 pede -- 100%, 66%, 33% --,
	# distinguiveis por nos diferentes e nao por um numero interno.
	#
	# Sobre ARTE o sinal e o que se ACRESCENTA, e nao o que se esconde: a
	# carcaca desenhada ja tem as placas, entao apagar um poligono por cima dela
	# nao tira nada. O que le e a fumaca aparecendo e o remendo de motor exposto.
	var remendo := chefe.get_node_or_null("Visual/Placa") as CanvasItem
	var fumaca := chefe.get_node_or_null("Visual/Fumaca") as CanvasItem
	ok(remendo != null and fumaca != null, "o corpo tem os nos de desgaste")

	var vistos := {}
	for caso in [
		{"fracao": 1.00, "estado": 0, "diz": "carcaca inteira"},
		{"fracao": 0.50, "estado": 1, "diz": "danificado"},
		{"fracao": 0.20, "estado": 2, "diz": "motor exposto"},
	]:
		chefe.vida = maxi(int(float(chefe.vida_maxima) * caso["fracao"]), 1)
		chefe._atualizar_leitura_visual(0.016)
		igual(chefe.estado_de_desgaste(), caso["estado"],
			"com %.0f%% de vida ele esta %s" % [caso["fracao"] * 100.0, caso["diz"]])
		vistos["%s|%s" % [str(fumaca.visible), str(remendo.visible)]] = true

	igual(vistos.size(), 3,
		"e os tres estados sao DISTINGUIVEIS em tela, e nao so no numero interno")
	ok(fumaca.visible and remendo.visible, "no ultimo terco ele fuma E mostra o motor")

	perto(chefe.desgaste(), 0.8, "e o desgaste acompanha a vida (%.2f)" % chefe.desgaste(), 0.01)

	# E nao volta. Placa que se remonta leria como o chefe se recuperando, que e
	# o oposto da ficcao: aqui o dano e o que o destrava.
	var antes: float = chefe.desgaste()
	chefe.vida = chefe.vida_maxima
	chefe._atualizar_leitura_visual(0.016)
	ok(chefe.desgaste() >= antes,
		"e o desgaste NUNCA decresce (%.2f depois de curar, era %.2f)" % [chefe.desgaste(), antes])

	# A virada emite o gancho de som, mesmo sem camada de audio existir ainda.
	var avisou := [0]
	chefe.fase_mudou.connect(func(f: int) -> void: avisou[0] = f)
	chefe.vida = int(float(chefe.vida_maxima) * 0.2)
	chefe._checar_fase()
	igual(avisou[0], 3, "a virada emite `fase_mudou` -- e o gancho que a camada de audio vai usar")

	chefe.free()
	await Engine.get_main_loop().process_frame


## BOSS 07: nenhum efeito de fase cobre telegrafo ou projetil.
##
## Efeito que atrapalha a leitura do combate e efeito cortado, por mais bonito
## que seja -- e fumaca na fase 3 e o risco obvio. A garantia e geometrica e nao
## de bom senso: os efeitos desenham ABAIXO da faixa do mundo, que e onde ficam
## o telegrafo, os projeteis e os atores, e tem teto de opacidade.
func _nenhum_efeito_de_fase_cobre_telegrafo_ou_projetil() -> void:
	var chefe := _nascer()
	ok(chefe.Z_EFEITO < 0, "os efeitos de fase desenham atras do corpo (z %d)" % chefe.Z_EFEITO)
	ok(chefe.Z_EFEITO < Sala.Z_MUNDO,
		"e abaixo da faixa do mundo, onde estao telegrafo e projetil")
	ok(chefe.ALPHA_MAXIMO_EFEITO < 0.5,
		"e o teto de opacidade deles e baixo (%.2f) -- mesma regra do alpha_maximo do glitch"
			% chefe.ALPHA_MAXIMO_EFEITO)

	var fumaca := chefe.get_node_or_null("Visual/Fumaca") as CanvasItem
	ok(fumaca != null, "a fumaca existe")
	if fumaca != null:
		igual(fumaca.z_index, chefe.Z_EFEITO, "e ela esta na faixa dos efeitos")
		chefe.vida = 1
		chefe._atualizar_leitura_visual(0.016)
		ok(fumaca.modulate.a <= chefe.ALPHA_MAXIMO_EFEITO + 0.0001,
			"e no pior caso ela nao passa do teto (%.2f)" % fumaca.modulate.a)

	# E o efeito e PROCEDURAL: `SCREEN_TEXTURE` quebra no export web e MSAA 2D
	# nao existe no Compatibility -- efeito que dependesse deles sairia no PC e
	# sumiria no navegador, que e para onde vai a build do testador.
	# So o CODIGO: o cabecalho do metodo visual explica justamente que nada ali
	# depende de SCREEN_TEXTURE, e citar o nome para explicar isso nao pode
	# contar como usa-lo. Mesma leitura do caso de `terminar_run`.
	ok(not _codigo_de("res://src/enemies/boss_guardiao_01.gd").contains("SCREEN_TEXTURE"),
		"nada no chefe depende de SCREEN_TEXTURE")
	chefe.free()


func _nascer() -> Node:
	var chefe := CENA.instantiate()
	chefe.position = LONGE
	Engine.get_main_loop().root.add_child(chefe)
	return chefe
