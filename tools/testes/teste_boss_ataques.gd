extends TesteBase
## O MOVESET do Automato Enferrujado (BOSS 03 a 06).
##
## A regra que vale para os quatro e a mesma, e e ela que a suite protege: **o
## moveset nao e substituido entre fases.** O mesmo ataque fica reconhecivel e
## mais rapido, e ganha uma camada -- uma onda vira tres, um leque vira dois
## intercalados, uma investida vira ate tres. Trocar de ataque a cada terco seria
## tres chefes curtos em sequencia, e o jogador nao teria o que dominar.
##
## E a trava que vale para todo ataque de AREA, herdada das sete da Diretora:
## ele deixa saida. `teste_diretora.gd` mede quantas aberturas cada ataque abre e
## o vao angular entre dois projeteis, em graus -- nao e opiniao, e numero. Aqui
## o metodo e o mesmo, e o vao e comparado contra o corpo do jogador em vez de
## contra um limite escrito a mao.

const CENA := preload("res://src/enemies/boss_guardiao_01.tscn")

## Longe da origem, como as outras suites que instanciam inimigo.
const LONGE := Vector2(81000.0, 81000.0)

## Raio do corpo do jogador, em px. E contra ele que o vao angular e medido.
const RAIO_JOGADOR := 11.0

var _barra_original: float = 0.0


func nome() -> String:
	return "BossAtaques"


func executar() -> void:
	_barra_original = Deterioracao.valor
	Deterioracao.valor = 0.0
	_a_alternancia_vive_num_lugar_so()
	_o_repertorio_so_cresce()
	await _o_soco_avisa_no_chao_e_cada_golpe_tem_o_seu()
	await _a_rajada_sai_inteira_e_intercala()
	await _o_pisao_deixa_vao_passavel()
	await _a_investida_trava_a_direcao_e_a_parede_atordoa()
	_a_cadencia_da_arma_nao_engole_um_beat()
	Deterioracao.valor = _barra_original


## A ALTERNANCIA mora num lugar so: `Balistica`.
##
## Tres lugares pedem a mesma conta -- o anel do Drone Aranha, a rajada do chefe
## e o pisao dele. O mapa de angulo para quadro ja foi duplicado uma vez neste
## projeto e teve de virar `src/util/direcoes.gd` por isso, e o sintoma de duas
## copias divergindo aparece em TELA e nunca no console.
func _a_alternancia_vive_num_lugar_so() -> void:
	perto(Balistica.setor(8), 45.0, "o setor sai da contagem: oito bracos, 45 graus")
	perto(Balistica.setor(12), 30.0, "e doze bracos dao 30 -- passo fixo deixaria de cair no vao")

	perto(Balistica.alternancia(8, 0), 0.0, "a salva par sai sem giro")
	perto(Balistica.alternancia(8, 1), 22.5, "a impar sai no MEIO do vao (22,5 de 45)")
	perto(Balistica.alternancia(8, 2), 0.0, "e a seguinte volta: a alternancia nao vira deriva")
	perto(Balistica.alternancia(8, 99), 22.5, "e continua alternando indefinidamente")

	# LEQUE e ANEL tem passos diferentes, e confundi-los foi o defeito da
	# primeira versao da rajada: com o passo do anel, a segunda salva caia EM
	# CIMA da primeira em vez de nos vaos dela.
	perto(Balistica.passo_do_leque(5, 60.0), 15.0,
		"o passo do leque reparte a abertura por `contagem - 1`, e nao por `contagem`")
	perto(Balistica.alternancia_de_passo(15.0, 1), 7.5,
		"e a alternancia dele e meio passo do LEQUE, nao meio setor do anel")
	perto(Balistica.alternancia_de_passo(0.0, 1), 0.0,
		"passo zero nao gira nada -- leque de um projetil nao tem vao")

	# Nenhum giro passa do setor: se passasse, a "alternancia" seria uma rotacao
	# acumulada e as salvas cairiam em posicoes arbitrarias.
	var estourou := false
	for i in 200:
		estourou = estourou or Balistica.alternancia(8, i) >= Balistica.setor(8)
	ok(not estourou, "nenhum giro chega ao setor inteiro -- senao a alternancia vira deriva")

	# E o Drone consome o helper em vez de guardar uma copia.
	var fonte := FileAccess.get_file_as_string("res://src/enemies/drone_aranha.gd")
	ok(fonte.contains("Balistica.alternancia("),
		"o Drone Aranha usa o helper compartilhado, e nao uma copia da conta")


## O repertorio so CRESCE. Ataque que some faria o jogador desaprender.
func _o_repertorio_so_cresce() -> void:
	var chefe := _nascer()
	igual(chefe.REPERTORIO.size(), 4, "os quatro ataques da BOSS 03 a 06 estao no repertorio")
	for esperado in ["SOCO", "RAJADA", "INVESTIDA", "PISAO"]:
		var achou := false
		for nome_ataque in chefe.REPERTORIO:
			achou = achou or String(nome_ataque) == esperado
		ok(achou, "%s esta no repertorio" % esperado)

	# O rodizio exercita TODOS. Um sorteio poderia repetir um e esconder que os
	# outros tres nunca rodaram -- e a arena e as suites dependem de que rodem.
	var vistos := {}
	for _i in 8:
		chefe._escolher_ataque()
		vistos[String(chefe._ataque)] = true
	igual(vistos.size(), 4, "oito escolhas exercitam os quatro ataques")
	chefe.free()


## BOSS 03: o soco avisa NO CHAO, e na fase 3 cada golpe tem o seu aviso.
##
## O aviso e uma `AreaDePerigo` reusada, e a economia nao e de linhas: ela ja
## carrega as tres armadilhas registradas deste ataque resolvidas -- nao estoura
## no `_ready`, varre com `intersect_shape` em vez de `get_overlapping_bodies()`,
## e desenha na faixa do mundo. Um circulo proprio aqui reencenaria os tres bugs.
func _o_soco_avisa_no_chao_e_cada_golpe_tem_o_seu() -> void:
	var cena := _montar()
	var chefe: Node = cena["chefe"]
	var container: Node = cena["container"]

	chefe.fase_chefe = 1
	chefe._ataque = chefe.SOCO
	chefe._golpes_restantes = chefe._golpes_do_soco()
	igual(chefe._golpes_do_soco(), 1, "na fase 1 e um golpe so")
	chefe._maquina.trocar(chefe.PREPARAR)
	igual(_areas(container), 1, "entrar em PREPARAR semeia o aviso no chao")

	var area: AreaDePerigo = _primeira_area(container)
	ok(area != null and not area.monitoring,
		"e o aviso NAO machuca enquanto e aviso -- senao o telegrafo estaria mentindo")
	if area != null:
		perto(area.tempo_aviso, chefe._aviso_atual,
			"o aviso dura exatamente o telegrafo daquela fase", 0.001)
		ok(area.global_position.distance_to(chefe.global_position) > 40.0,
			"e ele cai A FRENTE dele, e nao em cima dele")

	# A onda de choque: uma na fase 1, tres a partir da 2. Ele nao vira outro
	# ataque -- vira uma versao mais eficiente do mesmo.
	igual(chefe._ondas_do_soco(), 1, "fase 1: uma onda frontal")
	chefe.fase_chefe = 2
	igual(chefe._ondas_do_soco(), 3, "fase 2: o leque de tres, e nao um ataque novo")
	chefe.fase_chefe = 3
	igual(chefe._ondas_do_soco(), 3, "fase 3: o mesmo leque, agora com dois golpes")
	igual(chefe._golpes_do_soco(), 2, "e sao DOIS golpes na fase 3")

	# A onda sai inteira, e sai com o leque que a fase pede.
	chefe._direcao_travada = Vector2.RIGHT
	var caixa := _caixa_de(chefe._arma_onda)
	chefe._bater()
	igual(caixa.get_child_count(), 3,
		"a onda sai com os tres projeteis -- um `for` com atirar() sairia com 1")

	# Cada golpe da fase 3 tem TELEGRAFO PROPRIO: o segundo volta a PREPARAR em
	# vez de repetir dentro de EXECUTAR, que daria o segundo golpe de graca.
	_limpar_areas(container)
	chefe._golpes_restantes = 2
	chefe._maquina.trocar(chefe.PREPARAR)
	var primeiro: Vector2 = _primeira_area(container).global_position
	chefe._maquina.trocar(chefe.EXECUTAR)
	chefe._golpes_restantes -= 1
	chefe._maquina.trocar(chefe.PREPARAR)
	igual(_areas(container), 2, "o segundo golpe semeia o proprio aviso")
	var segundo: Vector2 = _ultima_area(container).global_position
	ok(primeiro.distance_to(segundo) > 40.0,
		"e ele cai do OUTRO lado (%.0f px de distancia): e esquerdo e direito, nao o mesmo golpe duas vezes"
			% primeiro.distance_to(segundo))

	_desmontar(cena)
	await Engine.get_main_loop().process_frame


## BOSS 04: a salva sai inteira, e duas rajadas seguidas ficam INTERCALADAS.
##
## `atirar_varias` e obrigatorio e nao preferencia: um `for` com `atirar()`
## sairia com UM projetil, porque `_t_cadencia` e setado no primeiro tiro e
## `pode_atirar()` recusa o resto -- foi este mesmo defeito que fez o anel da
## Diretora sair com um projetil.
func _a_rajada_sai_inteira_e_intercala() -> void:
	var cena := _montar()
	var chefe: Node = cena["chefe"]
	var projeteis: Node = cena["projeteis"]

	chefe._ataque = chefe.RAJADA
	chefe._direcao_travada = Vector2.RIGHT
	chefe._indice_salva = 0
	chefe._beats = 0
	var caixa := _caixa_de(chefe._arma_sucata)
	chefe._disparar_beat()
	igual(caixa.get_child_count(), chefe.projeteis_rajada,
		"a rajada sai com todos os projeteis")

	var primeira := _angulos(caixa)
	_limpar(caixa)
	_esperar_cadencia(chefe._arma_sucata)
	chefe._disparar_beat()
	var segunda := _angulos(caixa)

	# INTERCALADAS: nenhum projetil da segunda cai em cima de um da primeira, e o
	# mais proximo fica a meio vao. E o que faz o buraco de agora ser a parede de
	# daqui a pouco -- uma regra que da para dominar.
	var menor := 999.0
	for a in segunda:
		for b in primeira:
			menor = minf(menor, absf(rad_to_deg(a - b)))
	var meio_vao: float = chefe.abertura_rajada / float(chefe.projeteis_rajada - 1) * 0.5
	perto(menor, meio_vao,
		"a segunda rajada cai no MEIO do vao da primeira (%.1f graus)" % menor, 0.5)

	# E o numero de rajadas cresce com a fase, sem o ataque virar outro.
	for fase in [1, 2, 3]:
		chefe.fase_chefe = fase
		igual(chefe._beats_do_ataque(), fase, "fase %d: %d rajada(s) na salva" % [fase, fase])

	_desmontar(cena)
	await Engine.get_main_loop().process_frame


## BOSS 06: o pisao deixa vao PASSAVEL, e na fase 3 as duas ondas intercalam.
##
## Um radial com o jogador no centro exato precisa ter vao passavel, senao o
## ataque e "tome dano" e nao "esquive". O vao e medido contra o corpo do
## jogador na distancia em que o anel o alcanca -- e nao contra um limite escrito
## a mao, que envelheceria calado se a contagem mudasse.
func _o_pisao_deixa_vao_passavel() -> void:
	var cena := _montar()
	var chefe: Node = cena["chefe"]
	var projeteis: Node = cena["projeteis"]

	chefe._ataque = chefe.PISAO
	for fase in [1, 2, 3]:
		chefe.fase_chefe = fase
		var setor: float = Balistica.setor(chefe.projeteis_pisao)
		# O vao LINEAR entre dois bracos, a 120 px do centro: e a distancia em
		# que o jogador costuma estar quando o anel chega nele.
		var vao := deg_to_rad(setor) * 120.0
		ok(vao > RAIO_JOGADOR * 2.0 + 8.0,
			"fase %d: cabe o jogador entre dois bracos (%.0f px de vao, corpo de %.0f)"
				% [fase, vao, RAIO_JOGADOR * 2.0])

	# As DUAS ondas da fase 3 ficam intercaladas.
	chefe.fase_chefe = 3
	igual(chefe._beats_do_ataque(), 2, "a fase 3 pisa duas vezes")
	chefe._indice_salva = 0
	chefe._beats = 0
	var caixa := _caixa_de(chefe._arma_sucata)
	chefe._disparar_beat()
	var onda_1 := _angulos(caixa)
	_limpar(caixa)
	_esperar_cadencia(chefe._arma_sucata)
	chefe._disparar_beat()
	var onda_2 := _angulos(caixa)
	igual(onda_1.size(), chefe.projeteis_pisao, "o anel sai com os oito bracos")

	var menor := 999.0
	for a in onda_2:
		for b in onda_1:
			menor = minf(menor, absf(rad_to_deg(a - b)))
	perto(menor, Balistica.setor(chefe.projeteis_pisao) * 0.5,
		"a segunda onda cai no meio dos vaos da primeira -- e o padrao de tabuleiro",
		0.5)

	_desmontar(cena)
	await Engine.get_main_loop().process_frame


## BOSS 05: a direcao e travada em PREPARAR e NAO muda durante a investida.
##
## Investida que persegue durante a execucao e um ataque que nao da para
## esquivar -- so para sobreviver. E a mesma regra que a Cyber-Besta ja segue.
func _a_investida_trava_a_direcao_e_a_parede_atordoa() -> void:
	var cena := _montar()
	var chefe: Node = cena["chefe"]
	var jogador: Node2D = cena["jogador"]

	chefe._ataque = chefe.INVESTIDA
	jogador.global_position = chefe.global_position + Vector2(300.0, 0.0)
	chefe._maquina.trocar(chefe.PREPARAR)
	var travada: Vector2 = chefe._direcao_travada
	perto(travada.angle_to(Vector2.RIGHT), 0.0, "a direcao trava apontando para o jogador", 0.01)

	# O jogador se joga para o outro lado DEPOIS da trava.
	chefe._maquina.trocar(chefe.EXECUTAR)
	jogador.global_position = chefe.global_position + Vector2(0.0, -300.0)
	for _i in 5:
		chefe._executar(0.016)
	perto(chefe._direcao_travada.angle_to(travada), 0.0,
		"e NAO e corrigida no meio da investida", 0.0001)
	ok(chefe.velocity.x > 0.0 and absf(chefe.velocity.y) < 1.0,
		"ele continua indo para onde travou, e nao atras do jogador")
	ok(chefe.velocity.length() > chefe.velocidade_atual(),
		"e a investida e mais rapida que o andar dele (%.0f contra %.0f px/s)"
			% [chefe.velocity.length(), chefe.velocidade_atual()])

	# Quantas investidas por fase, e a recuperacao grande no fim.
	for fase in [1, 2, 3]:
		chefe.fase_chefe = fase
		igual(chefe._investidas_da_fase(), fase, "fase %d: ate %d investida(s)" % [fase, fase])

	# Bater na parede atordoa, e a janela e MAIOR que o atordoamento comum:
	# errar a investida tem de render ao jogador.
	ok(chefe.tempo_atordoado_parede > chefe.tempo_atordoado,
		"bater na parede abre mais janela que o atordoamento comum (%.1f s contra %.1f)"
			% [chefe.tempo_atordoado_parede, chefe.tempo_atordoado])

	# E a deteccao e por LAYER e nao por grupo: as paredes geradas por sala.gd e
	# corredor.gd nao entram em grupo nenhum, e o teste por grupo foi o que
	# deixava projetil atravessar parede.
	var fonte := FileAccess.get_file_as_string("res://src/enemies/boss_guardiao_01.gd")
	ok(fonte.contains("is_on_wall()"),
		'a parede e detectada pela fisica, e nao por `is_in_group("parede")`')

	_desmontar(cena)
	await Engine.get_main_loop().process_frame


## A ARMA nao pode ser o que limita a salva -- quem espaca os beats e o CHEFE.
##
## Este caso nasceu de um defeito de verdade, achado escrevendo a suite: a sucata
## tinha `cadencia = 3.0`, ou seja 0,33 s entre tiros, e o chefe pede beats a
## cada 0,28 s. A segunda e a terceira rajada eram recusadas por `pode_atirar()`
## e sumiam em silencio -- sem erro no console, sem nada na tela, so um ataque
## que "as vezes sai menor". Na fase 3 seria pior: `tempo_real()` comprime o
## intervalo para 0,19 s.
##
## O pior caso e o intervalo mais curto que o chefe consegue produzir: fase 3
## com a barra cheia, ja com o piso aplicado.
func _a_cadencia_da_arma_nao_engole_um_beat() -> void:
	var chefe := _nascer()
	chefe.fase_chefe = 3
	Deterioracao.valor = 100.0
	var mais_curto := minf(
		chefe.tempo_real(chefe.intervalo_rajada), chefe.tempo_real(chefe.intervalo_pisao)
	)
	for par in [
		{"arma": chefe._arma_sucata, "nome": "sucata"},
		{"arma": chefe._arma_onda, "nome": "onda"},
	]:
		var arma: Arma = par["arma"]
		ok(
			arma.dados.intervalo() < mais_curto,
			"a cadencia da %s (%.3f s) cabe no beat mais curto do chefe (%.3f s)"
				% [par["nome"], arma.dados.intervalo(), mais_curto]
		)
	Deterioracao.valor = 0.0
	chefe.free()


# ------------------------------------------------------------- montagem -----

## Um chefe numa arvore minima, com container de projeteis e um alvo falso.
func _montar() -> Dictionary:
	var raiz := Node2D.new()
	raiz.position = LONGE
	Engine.get_main_loop().root.add_child(raiz)

	var projeteis := Node2D.new()
	projeteis.add_to_group("container_projeteis")
	raiz.add_child(projeteis)

	var jogador := CharacterBody2D.new()
	jogador.add_to_group("player")
	raiz.add_child(jogador)
	jogador.global_position = LONGE + Vector2(300.0, 0.0)

	var container := Node2D.new()
	raiz.add_child(container)

	var chefe := CENA.instantiate()
	container.add_child(chefe)
	chefe.global_position = LONGE

	return {
		"raiz": raiz, "chefe": chefe, "container": container,
		"projeteis": projeteis, "jogador": jogador,
	}


## Desmonta o cenario AGORA, e o container de projeteis primeiro.
##
## E a armadilha registrada do projeto, e ela mordeu escrevendo esta suite: um
## `container_projeteis` que sobrevive continua no GRUPO, e a `Arma` do caso
## seguinte pede `get_first_node_in_group` e recebe AQUELE -- os projeteis caem
## no container errado e o caso conta ZERO no proprio. O sintoma e "a rajada nao
## dispara", que manda procurar o defeito no lugar errado.
##
## `queue_free()` nao serve: a suite roda inteira num frame, entao o no ficaria
## no grupo ate o fim dela. E a area de perigo sai da arvore ANTES de ser
## liberada -- liberar um `Area2D` com `monitoring` ligado no meio de uma
## varredura de fisica faz o motor reclamar.
func _desmontar(cena: Dictionary) -> void:
	var raiz: Node = cena["raiz"]
	var projeteis: Node = cena["projeteis"]
	_limpar(projeteis)
	projeteis.remove_from_group("container_projeteis")
	raiz.remove_child(projeteis)
	projeteis.free()
	_limpar_areas(cena["container"])
	raiz.free()


## Onde os projeteis DESTA arma vao cair, perguntado a ela.
##
## E deliberado nao assumir o container montado aqui. `Arma._container()` resolve
## por `get_first_node_in_group("container_projeteis")` no instante do disparo, e
## a ORDEM de um grupo no Godot nao e a de insercao -- um container vazado de
## outra suite pode vir na frente. Escrevendo esta suite, foi exatamente isso: a
## rajada "nao disparava", e os projeteis estavam caindo na caixa da suite
## anterior. Perguntar a arma tira o teste dessa loteria sem afrouxar o que ele
## afirma: a salva continua tendo de sair inteira.
## Deixa a arma pronta para o proximo tiro.
##
## `_t_cadencia` so decrementa no `_process` da `Arma`, e a suite roda inteira
## num frame -- sem isto, o segundo beat e recusado e o teste "prova" que a
## salva nao intercala. E a mesma armadilha que o `atualizar_gatilho(false)` das
## armas semiautomaticas ja documenta.
func _esperar_cadencia(arma: Arma) -> void:
	arma._process(1.0)


func _caixa_de(arma: Arma) -> Node:
	var caixa := arma._container()
	_limpar(caixa)
	return caixa


func _nascer() -> Node:
	var chefe := CENA.instantiate()
	chefe.position = LONGE
	Engine.get_main_loop().root.add_child(chefe)
	return chefe


func _areas(container: Node) -> int:
	var n := 0
	for filho in container.get_children():
		if filho is AreaDePerigo and not filho.is_queued_for_deletion():
			n += 1
	return n


func _primeira_area(container: Node) -> AreaDePerigo:
	for filho in container.get_children():
		if filho is AreaDePerigo:
			return filho
	return null


func _ultima_area(container: Node) -> AreaDePerigo:
	var achada: AreaDePerigo = null
	for filho in container.get_children():
		if filho is AreaDePerigo:
			achada = filho
	return achada


func _limpar_areas(container: Node) -> void:
	for filho in container.get_children():
		if filho is AreaDePerigo:
			container.remove_child(filho)
			filho.queue_free()


func _angulos(container: Node) -> Array[float]:
	var saida: Array[float] = []
	for filho in container.get_children():
		if "velocidade" in filho:
			saida.append((filho.velocidade as Vector2).angle())
	return saida


## `free()` e nao `queue_free()`: a suite roda inteira num frame, e um projetil
## ainda na arvore contaria na medicao seguinte.
func _limpar(container: Node) -> void:
	for filho in container.get_children():
		container.remove_child(filho)
		filho.free()
