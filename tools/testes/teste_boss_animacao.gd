extends TesteBase
## O gesto do chefe termina no GOLPE, nas duas pontas da luta.
##
## Esta suite existe por uma medicao. O `PREPARAR` do Automato vale **1,0667 s**
## na fase 1 com a barra zerada e **0,3620 s** na fase 3 com ela cheia -- uma
## faixa de **2,95x**. A duracao de um clipe tocado por fps e CONSTANTE, e
## nenhuma constante cabe numa faixa dessas: ela erra numa ponta ou nas duas.
##
## E a ponta que quebra nao e a rapida, que era a suspeita obvia. Com 4 quadros
## a 9 fps (0,4444 s) contra 0,3620 s de estado, `int(0.362/0.444 * 4) = 3` -- o
## ultimo quadro ainda aparece, por 29 ms. **Quem quebra e a ponta LENTA:** na
## fase 1 o clipe acaba em 42% do estado e congela pelo resto; em laco, ele
## RE-ARMA o punho 2,4 vezes antes de socar, e ai a animacao mente sobre a
## CONTAGEM e nao so sobre o tempo.
##
## Por isso o preparo e dirigido pelo PROGRESSO do estado. E por isso esta suite
## mede a fase 1 com a barra em zero E a fase 3 com ela cheia: uma ponta so nao
## enxerga o problema.
##
## O piso de 0,35 s NAO morde no preparo -- sobram 12 ms. Quem ele corta e a
## execucao. Isso e medido aqui de proposito, porque e uma margem e nao uma
## garantia: `tempo_telegrafo` vale 0,80 e o regime vira em 0,7735.

const CENA := preload("res://src/enemies/boss_guardiao_01.tscn")

## Longe da origem: o grupo "player" e global e outras suites deixam bonecos
## nele. Mesma razao de `teste_hack` e `teste_boss_ataques`.
const LONGE := Vector2(9000, 9000)

## O passo de fisica do projeto. E tambem a TOLERANCIA das medicoes de tempo:
## um estado so pode ser medido com a resolucao com que ele e processado.
const PASSO := 1.0 / 60.0

## Quantos quadros um gesto de preparo tem, para efeito de medicao.
##
## Ele nasceu antes da arte, para o teto de permanencia ser cobrado ANTES de os
## quadros existirem. A arte chegou na ANIM 04 -- e agora o numero e cobrado
## contra ela em `_o_gesto_pedido_existe_e_tem_a_contagem_medida`, senao ele
## viraria uma constante que ninguem atualiza: um clipe redesenhado com 6 quadros
## continuaria sendo medido como 4, e o teto de permanencia mediria uma arte que
## nao esta em disco.
const QUADROS_DE_PREPARO := 4

## Os gestos que o chefe PEDE e a cena ainda nao tem.
##
## Mesmo desenho do `SEM_ARTE_AINDA` de `teste_sprite_direcional.gd`, e pela
## mesma razao: `encenar()` nao da `push_error` quando o gesto falta -- um erro
## por frame afogaria o console e tornaria a cena inutilizavel no editor --,
## entao o barulho tem de ficar no PORTAO. Sem esta lista o portao so poderia
## existir depois da ultima issue do epico, e a arte que ja chegou passaria sem
## prova ate la.
##
## Uma lista assim so vale se ela morder dos DOIS lados: nome fora dela tem de
## existir, e nome DENTRO dela tem de continuar faltando. Sem a segunda metade a
## ANIM 05 entregaria o Reator e a linha ficaria aqui para sempre, cobrindo em
## silencio o dia em que aquele clipe se perdesse.
##
## **Ela esta VAZIA, e foi assim que ela terminou de servir.** Entraram quatro
## nomes -- os dois do Reator, o cambalear e o despertar -- e o `morrer` entrou
## depois, quando o portao passou a varrer o estado MORTE. Os cinco sairam com a
## arte das ANIM 05, 06 e 07. A lista fica: ela e o interruptor de "este gesto
## ainda nao existe", e sem ela o proximo gesto pedido antes da arte poria o
## portao vermelho sem ter onde declarar isso.
const SEM_CLIPE_AINDA: Array[StringName] = [
]

## Teto de quanto tempo UM quadro pode ficar parado na tela.
##
## Nao e um numero escolhido: e `Telegrafo.DURACAO_MINIMA`. O projeto ja declara
## que 0,35 s e o intervalo mais curto em que um aviso de QUATRO fases inteiro
## tem de ser legivel. Um unico quadro parado mais tempo que um telegrafo minimo
## completo e, na regua do proprio projeto, imagem estatica -- e nao animacao.
const TETO_POR_QUADRO := Telegrafo.DURACAO_MINIMA

var _barra_original: float = 0.0


func nome() -> String:
	return "Animacao do chefe"


func executar() -> void:
	_barra_original = Deterioracao.valor
	_o_gesto_pedido_existe_e_tem_a_contagem_medida()
	_o_corpo_do_chefe_TROCA_para_a_fita_do_gesto()
	_o_preparo_termina_no_golpe()
	_o_gesto_de_beat_recomeca_a_cada_beat()
	_nenhum_quadro_fica_parado_alem_do_teto()
	_o_reator_nao_e_dirigido_por_progresso()
	_a_boca_da_arma_sai_do_lado_que_o_corpo_encara()
	Deterioracao.valor = _barra_original


## TODO NOME QUE O CHEFE PEDE EXISTE NA CENA (ANIM 04).
##
## `clipe_do_estado()` devolve um nome, `SpriteDirecional.encenar()` procura esse
## nome, e **nao acha nada e nao reclama**: o corpo cai na pose parada e a luta
## segue. Isso e certo em jogo -- um erro por frame tornaria a cena inutilizavel
## no editor -- e e exatamente por isso que o portao precisa existir: renomear
## `socar` para `soco` no `.tres` nao quebra nada, nao imprime nada, e devolve o
## chefe a pose congelada que esta epico existe para consertar.
##
## O caso tambem cobra a CONTAGEM, e nao so a existencia. `QUADROS_DE_PREPARO`
## alimenta o teto de permanencia por quadro; um clipe redesenhado com outra
## contagem faria aquele teto medir uma arte que nao esta em disco.
func _o_gesto_pedido_existe_e_tem_a_contagem_medida() -> void:
	var chefe := _nascer()
	var sprite := chefe.get_node_or_null("Visual/Corpo") as SpriteDirecional
	ok(sprite != null, "o chefe tem um SpriteDirecional em Visual/Corpo")
	if sprite == null:
		chefe.free()
		return

	var pedidos: Array[StringName] = []
	for ataque: StringName in [chefe.SOCO, chefe.RAJADA, chefe.INVESTIDA, chefe.PISAO,
			chefe.REATOR]:
		for estado: StringName in [chefe.PREPARAR, chefe.EXECUTAR]:
			var nome: StringName = chefe.clipe_do_estado(estado, ataque)
			ok(nome != &"", "%s/%s pede um gesto" % [ataque, estado])
			if nome != &"":
				pedidos.append(nome)
	# MORTE entra na lista, e a ausencia dela era um buraco.
	#
	# O portao varria os estados um por um, escritos a mao, e `MORTE` nao estava
	# entre eles: um gesto pedido por `clipe_do_estado()` e nao declarado em
	# lugar nenhum passava VERDE. E a mesma familia do defeito que abriu este
	# epico -- "clipe declarado nao prova que alguem o desenha" --, so que pelo
	# outro lado: alguem pedia e nada provava que existia.
	for estado: StringName in [chefe.ATORDOADO, chefe.DESPERTAR, chefe.MORTE]:
		var nome: StringName = chefe.clipe_do_estado(estado, chefe.SOCO)
		ok(nome != &"", "%s pede um gesto" % estado)
		if nome != &"":
			pedidos.append(nome)

	var conferidos := 0
	var pendentes: Array[StringName] = []
	for nome in pedidos:
		if SEM_CLIPE_AINDA.has(nome):
			ok(
				not sprite.tem_clipe(nome),
				"'%s' esta declarado como pendente e continua faltando -- a lista nao carrega nome morto"
					% nome
			)
			pendentes.append(nome)
			continue
		conferidos += 1
		ok(sprite.tem_clipe(nome), "o gesto '%s' que o chefe pede existe na cena" % nome)

	ok(conferidos >= 8, "os oito gestos dos quatro ataques foram conferidos (%d)" % conferidos)
	igual(
		pendentes.size(), SEM_CLIPE_AINDA.size(),
		"toda pendencia declarada foi de fato pedida pelo chefe (%d de %d)"
			% [pendentes.size(), SEM_CLIPE_AINDA.size()]
	)

	# A contagem que o teto de permanencia usa e a que esta em disco.
	for ataque: StringName in [chefe.SOCO, chefe.RAJADA, chefe.INVESTIDA, chefe.PISAO]:
		var nome: StringName = chefe.clipe_do_estado(chefe.PREPARAR, ataque)
		var clipe := _clipe_de(sprite, nome)
		if clipe == null:
			ok(false, "o preparo de %s tem clipe" % ataque)
			continue
		igual(
			clipe.quadros, QUADROS_DE_PREPARO,
			"o preparo de %s tem os %d quadros que o teto de permanencia mede"
				% [ataque, QUADROS_DE_PREPARO]
		)
	chefe.free()


## O CORPO troca de fita ao entrar no gesto -- e nao so "o gesto existe".
##
## Este caso fecha a mesma armadilha que deu origem ao epico inteiro. Ali as
## oito poses e as oito fitas de caminhada estavam declaradas, casadas e
## medidas; o que faltava era o CHAMADOR, e chamador ausente nao aparece em
## teste de arquivo. O chefe passou seis issues no `south.png` quadro 0.
##
## O portao acima confere que o NOME existe. Este confere que o pixel muda: com
## `_pos_movimento` deixando de chamar `encenar()`, ou com `encenar()` caindo no
## `return false` por um clipe nao desenhavel, todos os outros casos desta suite
## continuariam verdes -- eles medem TEMPO, e o tempo do estado nao depende de
## quem desenha.
func _o_corpo_do_chefe_TROCA_para_a_fita_do_gesto() -> void:
	var chefe := _nascer()
	var sprite := chefe.get_node_or_null("Visual/Corpo") as SpriteDirecional
	if sprite == null:
		ok(false, "o chefe tem um SpriteDirecional em Visual/Corpo")
		chefe.free()
		return

	Deterioracao.valor = 0.0
	_forcar_fase(chefe, 1)
	var trocas := 0
	for ataque: StringName in [chefe.SOCO, chefe.RAJADA, chefe.INVESTIDA, chefe.PISAO]:
		_entrar_em_preparar(chefe, ataque)
		# Um passo de fisica: e nele que `_pos_movimento` roda e pede o gesto.
		chefe._physics_process(PASSO)
		var nome: StringName = chefe.clipe_do_estado(chefe.PREPARAR, ataque)
		var clipe := _clipe_de(sprite, nome)
		if clipe == null:
			ok(false, "%s tem clipe de preparo" % ataque)
			continue
		var na_fita := clipe.fitas.has(sprite.texture)
		if na_fita:
			trocas += 1
		ok(
			na_fita,
			"%s: o corpo esta desenhando a fita de '%s', e nao a pose parada"
				% [ataque, nome]
		)
	igual(trocas, 4, "os quatro preparos trocaram a fita do corpo (%d)" % trocas)
	chefe.free()


func _clipe_de(sprite: SpriteDirecional, nome: StringName) -> ClipeDirecional:
	for c in sprite.clipes:
		if c != null and c.nome == nome:
			return c
	return null


## O progresso do preparo chega a 1,0 no instante em que o golpe sai.
##
## Duas afirmacoes por ataque, e elas pegam defeitos diferentes:
##
## 1. **O estado dura o que `duracao_do_estado()` diz.** E o portao
##    anti-divergencia: se a funcao deixar de concordar com aquilo que
##    `_preparar` compara, o gesto passa a terminar antes ou depois do golpe, e
##    nada mais no projeto acusaria.
## 2. **O ultimo progresso visto ainda em PREPARAR mostra o ULTIMO quadro.** E o
##    que separa "o gesto acompanha o estado" de "o gesto acaba quando quer".
func _o_preparo_termina_no_golpe() -> void:
	for canto in [{"fase": 1, "barra": 0.0}, {"fase": 3, "barra": 100.0}]:
		var chefe := _nascer()
		Deterioracao.valor = canto["barra"]
		for ataque in chefe.repertorio_da_fase(canto["fase"]):
			_forcar_fase(chefe, canto["fase"])
			_entrar_em_preparar(chefe, ataque)

			var esperado: float = chefe.duracao_do_estado()
			var passos := 0
			var ultimo := 0.0
			while chefe._maquina.estado == chefe.PREPARAR and passos < 600:
				ultimo = chefe.progresso_do_gesto()
				chefe._physics_process(PASSO)
				passos += 1

			var medido := float(passos) * PASSO
			perto(
				medido, esperado, "f%d/b%.0f %s: o estado dura o que duracao_do_estado() diz"
					% [canto["fase"], canto["barra"], ataque], PASSO
			)
			var quadro := int(ultimo * float(QUADROS_DE_PREPARO))
			igual(
				mini(quadro, QUADROS_DE_PREPARO - 1), QUADROS_DE_PREPARO - 1,
				"f%d/b%.0f %s: o ultimo quadro do preparo esta em cena quando o golpe sai (progresso %.3f em %.3fs)"
					% [canto["fase"], canto["barra"], ataque, ultimo, esperado]
			)
		chefe.free()


## Num ataque de BEAT o gesto recomeca a cada beat, e nao uma vez por estado.
##
## O pisao da fase 3 sao DOIS pisoes dentro de um `EXECUTAR` so. Dirigido pelo
## progresso do ESTADO, um clipe mostraria meio pisao por pisao -- a perna
## subindo no primeiro e descendo no segundo, com o impacto de nenhum dos dois
## caindo no lugar.
func _o_gesto_de_beat_recomeca_a_cada_beat() -> void:
	var chefe := _nascer()
	Deterioracao.valor = 0.0
	_forcar_fase(chefe, 3)
	_entrar_em_preparar(chefe, chefe.PISAO)
	chefe._maquina.trocar(chefe.EXECUTAR)

	igual(chefe._beats_do_ataque(), 2, "o pisao da fase 3 tem dois beats (pre-condicao)")

	var subiu_e_voltou := 0
	var anterior: float = chefe.progresso_do_gesto()
	var passos := 0
	while passos < 600:
		chefe._physics_process(PASSO)
		passos += 1
		# Sair do estado ANTES de amostrar. `progresso_do_gesto()` responde pelo
		# estado ATUAL: lido ja em RECUPERAR ele devolve quase zero, e essa queda
		# contaria como um reinicio de beat que nao aconteceu.
		if chefe._maquina.estado != chefe.EXECUTAR:
			break
		var agora: float = chefe.progresso_do_gesto()
		# O progresso CAIR quer dizer que um gesto acabou e outro comecou.
		if agora < anterior - 0.3:
			subiu_e_voltou += 1
		anterior = agora

	igual(
		subiu_e_voltou, 1,
		"o gesto do pisao reinicia entre os dois beats, em vez de esticar sobre os dois"
	)
	chefe.free()


## Nenhum quadro de um gesto por PROGRESSO fica parado alem do teto.
##
## Este e o portao que PRODUZ decisao em vez de carimbar uma. Ele divide a
## duracao do estado pelos quadros do gesto e cobra o resultado contra
## `Telegrafo.DURACAO_MINIMA`. Um preparo que estoure o teto nao e um preparo
## ruim -- e um preparo que precisa de mais quadros, ou de outro modo. A Falha do
## Reator e exatamente esse caso, e e por isso que ela esta fora daqui: ver
## `_o_reator_nao_e_dirigido_por_progresso`.
func _nenhum_quadro_fica_parado_alem_do_teto() -> void:
	var chefe := _nascer()
	# A ponta LENTA e a que morde: fase 1 com a barra zerada e o preparo mais
	# longo que existe fora do Reator.
	Deterioracao.valor = 0.0
	_forcar_fase(chefe, 1)
	for ataque in [chefe.SOCO, chefe.RAJADA, chefe.INVESTIDA, chefe.PISAO]:
		_entrar_em_preparar(chefe, ataque)
		var por_quadro: float = chefe.duracao_do_estado() / float(QUADROS_DE_PREPARO)
		ok(
			por_quadro <= TETO_POR_QUADRO,
			"%s: cada quadro do preparo fica %.3fs na tela, dentro do teto de %.2fs"
				% [ataque, por_quadro, TETO_POR_QUADRO]
		)
		ok(
			por_quadro >= PASSO,
			"%s: e nenhum quadro passa despercebido (%.3fs contra o passo de %.4fs)"
				% [ataque, por_quadro, PASSO]
		)
	chefe.free()


## A Falha do Reator NAO pode ser um gesto por progresso, e o numero diz por que.
##
## O preparo dela vale 2,9333 s na fase 1 -- o telegrafo mais longo da luta, e
## por regra do projeto ele tem de continuar sendo, porque ataque capaz de tirar
## grande parte da vida precisa ser facilmente reconhecivel. Quatro quadros
## esticados nisso dao 0,733 s por quadro, o DOBRO do teto: slideshow, e nao
## animacao.
##
## A saida nao e encurtar o aviso, que a issue proibe. E que o Reator ja tem
## contagem regressiva PROPRIA no chao -- o cerco de `AreaDePerigo` com as
## quatro fases do `Telegrafo`. O corpo dele nao precisa responder "quando": a
## pose sobrecarregada e a mensagem, e o anel faz o relogio.
func _o_reator_nao_e_dirigido_por_progresso() -> void:
	var chefe := _nascer()
	Deterioracao.valor = 0.0
	_forcar_fase(chefe, 3)
	_entrar_em_preparar(chefe, chefe.REATOR)

	var por_quadro: float = chefe.duracao_do_estado() / float(QUADROS_DE_PREPARO)
	ok(
		por_quadro > TETO_POR_QUADRO,
		"o preparo do Reator NAO cabe em %d quadros por progresso (%.3fs por quadro, teto %.2fs) -- e por isso que ele e UMA_VEZ"
			% [QUADROS_DE_PREPARO, por_quadro, TETO_POR_QUADRO]
	)

	# E a margem que separa o preparo do piso, medida em vez de assumida. Se
	# `tempo_telegrafo` cair abaixo de 0,7735 o regime vira: o preparo passa a
	# ser cortado pelo piso e o gesto termina antes do golpe.
	Deterioracao.valor = 100.0
	var mais_rapido: float = chefe.tempo_real(chefe.tempo_preparo)
	ok(
		mais_rapido > chefe.TEMPO_MINIMO,
		"o preparo comum NAO e cortado pelo piso: para em %.4fs, %.0f ms acima de %.2f -- quem morde o piso e a execucao"
			% [mais_rapido, (mais_rapido - chefe.TEMPO_MINIMO) * 1000.0, chefe.TEMPO_MINIMO]
	)
	chefe.free()


## A boca da arma acompanha o corpo, nas oito direcoes.
##
## O no `Torre` era um `Marker2D` cravado em (0, -84) que nunca girava, e
## `Arma._emitir()` usa o `global_position` da arma: todo projetil de RAJADA,
## PISAO e REATOR nascia 84 px acima do centro do chefe, sem relacao com o lado
## para onde ele encarava.
##
## Duas afirmacoes, e a segunda e a que teria pego o defeito: a primeira mede que
## a boca esta no lado certo, a segunda que ela SAI DO LUGAR. Uma torre cravada
## passaria na primeira em uma das oito direcoes por coincidencia.
func _a_boca_da_arma_sai_do_lado_que_o_corpo_encara() -> void:
	var chefe := _nascer()
	Deterioracao.valor = 0.0
	_forcar_fase(chefe, 1)
	_entrar_em_preparar(chefe, chefe.RAJADA)

	var torre := chefe.get_node("Torre") as Node2D
	var arma := chefe.get_node("Torre/ArmaSucata") as Node2D
	var lugares := {}
	for i in Direcoes.TOTAL:
		var d := Vector2.RIGHT.rotated(TAU * float(i) / float(Direcoes.TOTAL))
		chefe._direcao_travada = d
		chefe._pos_movimento(PASSO)

		# Medido a partir da TORRE e nao do centro do chefe: a torre carrega o
		# desvio VERTICAL da altura do peito (-84), que e da carcaca e nao da
		# mira. Do centro, esse desvio dominaria a conta em todas as direcoes.
		var desvio := arma.global_position - torre.global_position
		perto(
			desvio.normalized().dot(d), 1.0,
			"a boca sai na direcao %d (%.0f graus)" % [i, rad_to_deg(d.angle())], 0.001
		)
		perto(
			desvio.length(), chefe.RAIO_DA_TORRE,
			"e a %.0f px do eixo do corpo, na direcao %d" % [chefe.RAIO_DA_TORRE, i], 0.5
		)
		lugares[Vector2i(desvio.round())] = true

	igual(
		lugares.size(), Direcoes.TOTAL,
		"a boca ocupa um lugar DIFERENTE em cada uma das oito direcoes -- cravada, ela teria um so"
	)
	chefe.free()


## Entra em PREPARAR pelo caminho de verdade.
##
## Passa por EXECUTAR antes porque `MaquinaEstados.trocar()` para o estado ATUAL
## e no-op deliberado -- pedir PREPARAR estando em PREPARAR nao roda o
## `_preparar_entrar`, e ai `_aviso_atual` fica com o valor do ataque anterior.
func _entrar_em_preparar(chefe: Node, ataque: StringName) -> void:
	chefe._ataque = ataque
	chefe._maquina.trocar(chefe.EXECUTAR)
	chefe._maquina.trocar(chefe.PREPARAR)


## Poe o chefe na fase pedida pela VIDA, que e de onde a fase sai.
##
## Sao DOIS campos, e escrever so um custou tres falhas ao escrever esta suite.
## `fase_chefe` e o que os multiplicadores leem, mas quem GUARDA a transicao e
## `_fase_anunciada`: `_checar_fase()` compara `fase_por_vida()` contra ele e,
## se a vida ja pede uma fase acima, joga o chefe em TRANSICAO_FASE no primeiro
## `_physics_process`. O sintoma era um PREPARAR de 0,0167 s -- um passo -- e so
## no PRIMEIRO ataque de cada canto, porque a partir do segundo a virada ja
## tinha acontecido.
func _forcar_fase(chefe: Node, fase: int) -> void:
	var fracao: float = [1.0, 0.9, 0.6, 0.2][clampi(fase, 1, 3)]
	chefe.vida = int(float(chefe.vida_maxima) * fracao)
	chefe._fase_anunciada = chefe.fase_por_vida()
	chefe.fase_chefe = chefe.fase_por_vida()


func _nascer() -> Node:
	var chefe := CENA.instantiate()
	Engine.get_main_loop().root.add_child(chefe)
	chefe.global_position = LONGE
	var alvo := Node2D.new()
	chefe.add_child(alvo)
	alvo.global_position = LONGE + Vector2(300.0, 0.0)
	chefe.alvo = alvo
	return chefe
