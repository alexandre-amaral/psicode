extends TesteBase
## A FALHA DO REATOR e a SELECAO DE ATAQUE (BOSS 08 e 09).
##
## As duas juntas porque respondem a mesma pergunta por lados opostos: o que o
## chefe faz agora, e quanto ele avisa antes. Um seletor esperto com telegrafo
## curto e um chefe que le o jogador e nao deixa reagir -- e a combinacao que o
## GDD chama de mentir sobre a propria regra.
##
## O caso que mais vale esta no fim: **a fase 1 continua legivel.** E a licao do
## `PerfilJogador` aplicada a selecao. Ele so corrige a mira com CONFIANCA,
## depois de ver o jogador se mexer por alguns segundos; tirar esse freio faz o
## primeiro disparo da luta ja sair corrigido, punindo um habito que o jogador
## nao teve chance de formar. A fase 1 do Automato existe para ensinar, entao ele
## escolhe burro de proposito -- selecao esperta cedo demais vira selecao cruel.

const CENA := preload("res://src/enemies/boss_guardiao_01.tscn")

## Longe da origem, como as outras suites que instanciam inimigo.
const LONGE := Vector2(91000.0, 91000.0)
## Quantos sorteios cada distribuicao mede. Alto porque o que se cobra e a
## TENDENCIA: com poucas amostras, o ruido do sorteio passaria por vies.
const AMOSTRAS := 600

var _barra_original: float = 0.0


func nome() -> String:
	return "BossSelecao"


func executar() -> void:
	_barra_original = Deterioracao.valor
	Deterioracao.valor = 0.0
	_o_reator_e_exclusivo_da_fase_3()
	_o_telegrafo_do_reator_e_o_mais_longo_da_luta()
	_o_cerco_deixa_saida()
	await _o_reator_semeia_o_cerco_e_estoura_junto()
	_o_mesmo_ataque_nao_sai_duas_vezes_seguidas()
	_a_distancia_muda_a_distribuicao()
	_a_fase_1_continua_legivel()
	Deterioracao.valor = _barra_original


## O repertorio SO CRESCE. A Falha do Reator entra na fase 3 e nada sai --
## ataque que some faria o jogador desaprender.
func _o_reator_e_exclusivo_da_fase_3() -> void:
	var chefe := _nascer()
	igual(chefe.repertorio_da_fase(1).size(), 4, "fase 1: os quatro ataques conhecidos")
	igual(chefe.repertorio_da_fase(2).size(), 4, "fase 2: os mesmos quatro, so mais rapidos")
	igual(chefe.repertorio_da_fase(3).size(), 5, "fase 3: os quatro MAIS a Falha do Reator")

	for fase in [1, 2, 3]:
		for ataque in chefe.repertorio_da_fase(2):
			var achou := false
			for depois in chefe.repertorio_da_fase(3):
				achou = achou or depois == ataque
			ok(achou, "nada sai do repertorio ao passar para a fase 3 (%s)" % ataque)
		break

	# E ele nunca e sorteado antes da hora.
	chefe.fase_chefe = 2
	var apareceu := false
	for _i in AMOSTRAS:
		chefe._escolher_ataque()
		apareceu = apareceu or chefe._ataque == chefe.REATOR
	ok(not apareceu, "a Falha do Reator nao aparece na fase 2, em %d sorteios" % AMOSTRAS)
	chefe.free()


## O TELEGRAFO MAIS LONGO DA LUTA, e ele tem de continuar sendo na fase 3.
##
## Regra do projeto: quanto mais forte o ataque, maior o telegrafo. Este e o mais
## perigoso da luta, entao ele avisa mais que qualquer outro -- inclusive com o
## multiplicador em 1,30 E a barra cheia, que e onde tudo o mais esta comprimido
## ate o piso.
func _o_telegrafo_do_reator_e_o_mais_longo_da_luta() -> void:
	var chefe := _nascer()
	var furou := false
	var pior := ""
	for fase in [1, 2, 3]:
		chefe.fase_chefe = fase
		var barra := 0.0
		while barra <= 100.0:
			Deterioracao.valor = barra
			var reator: float = chefe.tempo_real(chefe.preparo_de(chefe.REATOR))
			for outro in chefe.REPERTORIO:
				var dele: float = chefe.tempo_real(chefe.preparo_de(outro))
				if reator <= dele:
					furou = true
					pior = "fase %d, barra %.0f%%: reator %.2f s contra %s %.2f s" % [
						fase, barra, reator, outro, dele,
					]
			barra += 5.0
	ok(furou == false,
		"o aviso do reator e o mais longo em toda fase e toda barra%s"
			% ("" if pior.is_empty() else " -- " + pior))

	# E ele continua sendo um aviso LONGO, e nao so o maior de um conjunto
	# comprimido: no pior caso ele ainda dura mais que o dobro do piso.
	chefe.fase_chefe = 3
	Deterioracao.valor = 100.0
	var no_pior_caso: float = chefe.tempo_real(chefe.preparo_de(chefe.REATOR))
	ok(no_pior_caso > chefe.TEMPO_MINIMO * 2.0,
		"e no pior caso ele ainda dura %.2f s, mais que o dobro do piso" % no_pior_caso)

	# A recuperacao e parte do ataque: e o preco de usar a arma mais forte, e uma
	# das melhores janelas de dano da luta.
	ok(
		chefe.tempo_real(chefe.recuperacao_de(chefe.REATOR))
			> chefe.tempo_real(chefe.recuperacao_de(chefe.SOCO)) * 1.5,
		"e a recuperacao dele e MUITO maior que a dos outros -- ela representa a ficcao"
	)
	Deterioracao.valor = 0.0
	chefe.free()


## O cerco deixa saida, e a saida cabe o jogador.
##
## Medido em px e nao em opiniao: o raio do cerco, a contagem e o raio de cada
## area sao tres botoes do Inspetor, e alguem pode fechar o cerco girando um
## deles sem perceber. O sintoma seria um ataque que nao da para esquivar, e ele
## nao da erro no console.
func _o_cerco_deixa_saida() -> void:
	var chefe := _nascer()
	ok(chefe.aberturas_de(chefe.REATOR) >= 1,
		"a Falha do Reator deixa por onde escapar (%d vaos)" % chefe.aberturas_de(chefe.REATOR))
	igual(chefe.aberturas_de(chefe.INVESTIDA), -1,
		"e ataque que nao e de area nao e cobrado por abertura: -1 diz 'nao se aplica'")

	# O corpo do jogador tem raio 11: o vao precisa caber ele com folga.
	var vao: float = chefe.vao_do_cerco()
	ok(vao > 11.0 * 2.0 + 8.0,
		"e cada vao cabe o jogador (%.0f px de vao, corpo de 22)" % vao)

	# Fechar o cerco DEVE reprovar: uma regua que nunca reprova e um carimbo.
	chefe.areas_do_reator = 40
	ok(chefe.vao_do_cerco() < 0.0,
		"e o numero acusa quando o cerco fecha (com 40 areas, vao de %.0f px)" % chefe.vao_do_cerco())
	chefe.free()


## O cerco nasce no TELEGRAFO e estoura junto, e o miolo nao e abrigo.
func _o_reator_semeia_o_cerco_e_estoura_junto() -> void:
	var cena := _montar()
	var chefe: Node = cena["chefe"]
	var container: Node = cena["container"]

	chefe.fase_chefe = 3
	chefe._ataque = chefe.REATOR
	chefe._maquina.trocar(chefe.PREPARAR)

	var areas := _areas(container)
	igual(areas, chefe.areas_do_reator + 1,
		"o cerco semeia uma area por vao MAIS o estouro central")

	var no_miolo := false
	var no_cerco := 0
	for filho in container.get_children():
		if not filho is AreaDePerigo:
			continue
		var d: float = (filho as Node2D).global_position.distance_to(chefe.global_position)
		if d < 1.0:
			no_miolo = true
		elif absf(d - chefe.raio_do_cerco) < 1.0:
			no_cerco += 1
		ok(not (filho as AreaDePerigo).monitoring,
			"nenhuma area do cerco machuca enquanto e aviso")
	ok(no_miolo, "o estouro central existe: colar nele nao pode ser o lugar mais seguro da sala")
	igual(no_cerco, chefe.areas_do_reator, "e as outras ficam todas no raio do cerco")

	# Todas avisam pelo MESMO tempo: um cerco que estoura em ordens diferentes
	# seria varios ataques, e o jogador leria um aviso e levaria outro golpe.
	var duracoes := {}
	for filho in container.get_children():
		if filho is AreaDePerigo:
			duracoes["%.3f" % (filho as AreaDePerigo).tempo_aviso] = true
	igual(duracoes.size(), 1, "e todas avisam pelo mesmo tempo, entao o cerco estoura junto")

	_desmontar(cena)
	await Engine.get_main_loop().process_frame


## O MESMO ataque nao sai duas vezes seguidas.
##
## Sem memoria, dois socos seguidos por azar leem como bug e tres leem como
## injustica -- o jogador nao tem como saber que foi sorteio.
func _o_mesmo_ataque_nao_sai_duas_vezes_seguidas() -> void:
	var chefe := _nascer()
	perto(chefe.peso_da_repeticao, 0.0, "o peso do ataque que acabou de sair e zero")

	for fase in [1, 2, 3]:
		chefe.fase_chefe = fase
		chefe._ultimo_ataque = &""
		var repetiu := false
		var anterior := &""
		for _i in AMOSTRAS:
			chefe._escolher_ataque()
			repetiu = repetiu or chefe._ataque == anterior
			anterior = chefe._ataque
		ok(not repetiu, "fase %d: nenhuma repeticao em %d sorteios" % [fase, AMOSTRAS])
	chefe.free()


## A DISTANCIA muda a distribuicao, com posicoes fixas.
##
## E o que faz o chefe parecer reativo sem trapacear: ele nao le a intencao do
## jogador, so onde ele esta. De perto sobem o soco e o pisao; de longe sobem a
## investida e a rajada.
func _a_distancia_muda_a_distribuicao() -> void:
	var cena := _montar()
	var chefe: Node = cena["chefe"]
	var jogador: Node2D = cena["jogador"]
	chefe.fase_chefe = 2

	jogador.global_position = chefe.global_position + Vector2(80.0, 0.0)
	var perto_de := _distribuicao(chefe)
	jogador.global_position = chefe.global_position + Vector2(520.0, 0.0)
	var longe_de := _distribuicao(chefe)

	ok(perto_de.get("SOCO", 0) > longe_de.get("SOCO", 0),
		"de PERTO o soco sai mais (%d contra %d)" % [perto_de.get("SOCO", 0), longe_de.get("SOCO", 0)])
	ok(perto_de.get("PISAO", 0) > longe_de.get("PISAO", 0),
		"de perto o pisao sai mais (%d contra %d)" % [perto_de.get("PISAO", 0), longe_de.get("PISAO", 0)])
	ok(longe_de.get("INVESTIDA", 0) > perto_de.get("INVESTIDA", 0),
		"de LONGE a investida sai mais (%d contra %d)"
			% [longe_de.get("INVESTIDA", 0), perto_de.get("INVESTIDA", 0)])
	ok(longe_de.get("RAJADA", 0) > perto_de.get("RAJADA", 0),
		"de longe a rajada sai mais (%d contra %d)"
			% [longe_de.get("RAJADA", 0), perto_de.get("RAJADA", 0)])

	# E NENHUM ataque some: um vies que zera uma opcao vira um chefe com dois
	# ataques por distancia, e o jogador para de ter o que aprender.
	for ataque in ["SOCO", "RAJADA", "INVESTIDA", "PISAO"]:
		ok(perto_de.get(ataque, 0) > 0 and longe_de.get(ataque, 0) > 0,
			"%s continua saindo nas duas distancias (%d perto, %d longe)"
				% [ataque, perto_de.get(ataque, 0), longe_de.get(ataque, 0)])

	_desmontar(cena)


## A FASE 1 CONTINUA LEGIVEL: seleccao esperta nao pode virar selecao cruel.
##
## E a licao do `PerfilJogador`, que so corrige com confianca. A fase 1 existe
## para ENSINAR, e um chefe que ja escolhe bem no primeiro terco pune um habito
## que o jogador nao teve chance de formar. A memoria continua valendo -- ela
## evita repeticao, que e legibilidade e nao esperteza --, mas o vies de
## distancia nao.
func _a_fase_1_continua_legivel() -> void:
	var chefe := _nascer()

	chefe.fase_chefe = 1
	var perto_1: float = chefe.peso_de(chefe.SOCO, 80.0, &"")
	var longe_1: float = chefe.peso_de(chefe.SOCO, 520.0, &"")
	perto(perto_1, longe_1,
		"na fase 1 a distancia NAO mexe no peso: ele parece burro porque precisa parecer")

	chefe.fase_chefe = 2
	var perto_2: float = chefe.peso_de(chefe.SOCO, 80.0, &"")
	var longe_2: float = chefe.peso_de(chefe.SOCO, 520.0, &"")
	ok(perto_2 > longe_2, "na fase 2 ela passa a mexer (%.1f perto contra %.1f longe)" % [perto_2, longe_2])

	# A memoria vale desde a fase 1: nao repetir e legibilidade, nao esperteza.
	chefe.fase_chefe = 1
	perto(chefe.peso_de(chefe.SOCO, 200.0, chefe.SOCO), 0.0,
		"mas a memoria vale desde a fase 1 -- repetir le como bug, nao como dificuldade")
	chefe.free()


# ------------------------------------------------------------- montagem -----

func _distribuicao(chefe: Node) -> Dictionary:
	var conta := {}
	chefe._ultimo_ataque = &""
	for _i in AMOSTRAS:
		chefe._escolher_ataque()
		var nome_ataque := String(chefe._ataque)
		conta[nome_ataque] = int(conta.get(nome_ataque, 0)) + 1
	return conta


func _montar() -> Dictionary:
	var raiz := Node2D.new()
	raiz.position = LONGE
	Engine.get_main_loop().root.add_child(raiz)

	var jogador := CharacterBody2D.new()
	jogador.add_to_group("player")
	raiz.add_child(jogador)
	jogador.global_position = LONGE + Vector2(300.0, 0.0)

	var container := Node2D.new()
	raiz.add_child(container)

	var chefe := CENA.instantiate()
	container.add_child(chefe)
	chefe.global_position = LONGE
	# O alvo e apontado A MAO, e nao deixado para `_procurar_alvo()`.
	#
	# O grupo "player" e GLOBAL, e outras suites deixam bonecos nele enquanto o
	# coletor nao passa -- `get_first_node_in_group` devolve qualquer um deles.
	# Escrevendo esta suite foi isso: o chefe media a distancia ate o jogador de
	# OUTRO teste, a 91 mil px, entao tudo era "longe" e o vies de distancia
	# parecia nao existir. Mesma loteria que o `container_projeteis` ja cobrou.
	chefe.alvo = jogador

	return {"raiz": raiz, "chefe": chefe, "container": container, "jogador": jogador}


## Tira as areas da arvore ANTES de liberar: um `Area2D` com `monitoring` ligado
## liberado no meio de uma varredura de fisica faz o motor reclamar.
func _desmontar(cena: Dictionary) -> void:
	var container: Node = cena["container"]
	for filho in container.get_children():
		if filho is AreaDePerigo:
			container.remove_child(filho)
			filho.queue_free()
	(cena["raiz"] as Node).free()


func _areas(container: Node) -> int:
	var n := 0
	for filho in container.get_children():
		if filho is AreaDePerigo and not filho.is_queued_for_deletion():
			n += 1
	return n


func _nascer() -> Node:
	var chefe := CENA.instantiate()
	chefe.position = LONGE
	Engine.get_main_loop().root.add_child(chefe)
	return chefe
