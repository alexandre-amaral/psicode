extends TesteBase
## O PORTAO DE IDENTIDADE DA IA DIRETORA.
##
## Esta suite nao pergunta "o chefe funciona?". Ela pergunta **"isto ainda e a
## Diretora?"** -- e recusa a mudanca que diz que nao.
##
## Ela existe porque tudo que define quem ela e morava em prosa, e prosa nao
## recusa um commit. O GDD promete telegrafo em todo ataque com piso de 0,35 s,
## janela de alivio de 0,9 s na virada de fase, e uma personagem que ORBITA
## porque "um sistema nao corre atras de voce". Nada disso era medido. O teste de
## fumaca a mata em ~4 s simulados so para as fases rodarem: ele nunca olhou a
## duracao de um aviso, nunca conferiu a orbita, nunca soube o que e um ataque
## sem saida.
##
## Cada trava abaixo tem a frase que a originou junto dela -- metade vem do GDD,
## metade vem do texto de historia da Diretora. Quem for mexer nela daqui a seis
## meses precisa poder ler POR QUE a trava existe, e nao so que ela existe.
##
## O que esta suite deliberadamente NAO cobra: duracao da luta. A faixa boa e
## 60-90 s, mas o projeto ja decidiu (commit ea5fe61) que o tempo e dominado pelo
## uptime e nao pela vida, e que a resposta vem da tela de fim e do playtest --
## "em vez de trocar um chute por outro". Travar duracao aqui seria justamente
## trocar um chute por outro, com a autoridade de um teste verde.

const CENA_DIRETORA := preload("res://src/enemies/diretora.tscn")

## As quatro fases. A quarta ja entra na conta porque `repertorio_da_fase` cai
## no ramo `_` para qualquer valor acima de 2 -- entao a trava vale para ela
## antes mesmo de ela existir.
const FASES := [1, 2, 3, 4]

## Longe da origem: o grupo "inimigo" e global e inimigos de outras suites que
## ainda nao foram coletados ficam quase todos perto de (0,0).
const LONGE := Vector2(9000, 9000)

const PASSO := 1.0 / 60.0


func nome() -> String:
	return "Diretora"


func executar() -> void:
	var chefe := _nascer()

	_todo_ataque_avisa(chefe)
	_o_aviso_encurta_mas_nunca_some(chefe)
	_o_repertorio_so_cresce(chefe)
	_a_virada_de_fase_perdoa(chefe)
	_nenhum_ataque_fecha_a_arena(chefe)
	_ela_nao_persegue(chefe)
	_a_mira_preditiva_nao_depende_da_barra(chefe)
	_o_hack_atravessa_o_chefe(chefe)

	chefe.get_parent().free()

	_o_perfil_le_o_jogador()


# ------------------------------------------------------------- as travas ---

## TRAVA 1 -- "Todo ataque tem telegrafo (laser, anel de aviso expandindo, ou
## clarao)" (GDD). Um ataque com aviso zero e dano vindo do nada: o jogador nao
## tem como aprender com a morte, e o GEMINI.md lista isso em "o que evitar".
func _todo_ataque_avisa(chefe: Node) -> void:
	for fase: int in FASES:
		for ataque: StringName in _repertorio_unico(chefe, fase):
			var d: float = chefe.duracao_telegrafo(ataque, fase)
			ok(d > 0.0, "fase %d: '%s' avisa antes de doer (%.2fs)" % [fase, ataque, d])


## TRAVA 2 e 3 -- "o telegrafo encurta com a fase mas nunca abaixo de 0,35 s"
## (GDD) e "Telegrafo encurta com a fase, nunca some" (GEMINI).
##
## Sao duas metades da mesma promessa e quebram por motivos opostos: alguem
## endurecendo o chefe derruba o piso, alguem "consertando" a dificuldade
## congela o encurtamento e as fases param de escalar. As duas passam sem erro
## no console.
func _o_aviso_encurta_mas_nunca_some(chefe: Node) -> void:
	var piso: float = chefe.TELEGRAFO_MINIMO
	for fase: int in FASES:
		for ataque: StringName in _repertorio_unico(chefe, fase):
			var d: float = chefe.duracao_telegrafo(ataque, fase)
			ok(
				d >= piso - 0.0001,
				"fase %d: o aviso de '%s' respeita o piso de %.2fs (%.2fs)" % [fase, ataque, piso, d]
			)

	# Encurtar: comparado ataque a ataque, e nunca para BAIXO do piso.
	for ataque: StringName in _repertorio_unico(chefe, 3):
		var f1: float = chefe.duracao_telegrafo(ataque, 1)
		var f3: float = chefe.duracao_telegrafo(ataque, 3)
		ok(
			f3 < f1 or is_equal_approx(f3, piso),
			"'%s' avisa mais rapido na fase 3 que na 1 (%.2fs -> %.2fs)" % [ataque, f1, f3]
		)


## TRAVA 4 -- o repertorio so CRESCE. A tabela de fases do GDD acrescenta em
## cada linha; nenhuma fase tira um padrao de circulacao.
##
## Comparado como CONJUNTO e nao como lista: a fase 1 repete "preditivo" duas
## vezes de proposito, para ele sair mais vezes no sorteio, e isso nao e
## repertorio maior -- e peso.
func _o_repertorio_so_cresce(chefe: Node) -> void:
	var anterior: Array[StringName] = []
	for fase: int in FASES:
		var atual := _repertorio_unico(chefe, fase)
		ok(not atual.is_empty(), "fase %d tem repertorio" % fase)
		for ataque: StringName in anterior:
			ok(
				atual.has(ataque),
				"fase %d nao perdeu '%s', que a fase anterior tinha" % [fase, ataque]
			)
		ok(
			atual.size() >= anterior.size(),
			"fase %d nao encolheu o repertorio (%d -> %d)" % [fase, anterior.size(), atual.size()]
		)
		anterior = atual


## TRAVA 5 -- "Na virada de fase ha uma janela de alivio de 0,9 s -- sem ela, a
## transicao vira dano gratuito em cima de quem estava no meio de uma esquiva"
## (GDD). E a mesma filosofia do `roll_graca`: o perdao que separa "dificil" de
## "injusto".
func _a_virada_de_fase_perdoa(chefe: Node) -> void:
	ok(
		chefe.ALIVIO_DE_FASE >= 0.9 - 0.0001,
		"a virada de fase da ao menos 0,9s de alivio (%.2fs)" % chefe.ALIVIO_DE_FASE
	)


## TRAVA 6 -- ela nunca fecha a arena inteira.
##
## Vem do texto de historia dela: mesmo a Sobrecarga do Nucleo, o ataque mais
## brutal do repertorio, "deixa apenas uma pequena area segura", e o Firewall
## "deixa pequenas aberturas para passagem". Dano inevitavel COM telegrafo e
## pior que dano inevitavel sem: ler a intencao e nao poder agir sobre ela e a
## definicao de mentir sobre a propria regra.
##
## `aberturas_de` devolve -1 para ataque que nao e de area -- disparo nao fecha
## espaco, e cobrar abertura dele seria cobrar o numero errado.
func _nenhum_ataque_fecha_a_arena(chefe: Node) -> void:
	for fase: int in FASES:
		for ataque: StringName in _repertorio_unico(chefe, fase):
			var aberturas: int = chefe.aberturas_de(ataque, fase)
			if aberturas < 0:
				continue
			ok(
				aberturas >= 1,
				"fase %d: '%s' deixa por onde escapar (%d aberturas)" % [fase, ataque, aberturas]
			)

	# O anel adensa por fase. Se adensar demais, as aberturas viram costura e o
	# "deixa passar" existe so na planilha.
	for fase: int in FASES:
		var passo := 360.0 / float(chefe.projeteis_do_anel(fase))
		ok(
			passo >= 6.0,
			"fase %d: o vao entre dois projeteis do anel ainda e passavel (%.1f graus)" % [fase, passo]
		)


## TRAVA 7 -- "Orbita o centro da arena -- nao persegue, porque um sistema nao
## corre atras de voce" (GDD).
##
## E a trava que mais protege a ficcao e a mais facil de perder: basta alguem
## "melhorar" a movimentacao dela para `direcao_para_alvo()` e a Diretora vira
## um Rastejante de 300 HP. O jogo continuaria funcionando, o teste de fumaca
## continuaria verde, e a personagem teria deixado de existir.
##
## A prova e diferencial: mesma Diretora, mesmo tempo, jogador em dois lugares
## opostos. Se a trajetoria depender de onde o jogador esta, ela persegue.
func _ela_nao_persegue(chefe: Node) -> void:
	var origem: Vector2 = chefe.global_position
	var caminho_a := _rodar_orbita(chefe, origem + Vector2(400, 0))
	var caminho_b := _rodar_orbita(chefe, origem + Vector2(-400, 0))

	var maior := 0.0
	for i in mini(caminho_a.size(), caminho_b.size()):
		maior = maxf(maior, caminho_a[i].distance_to(caminho_b[i]))
	ok(
		maior < 1.0,
		"a trajetoria dela nao muda com a posicao do jogador (desvio %.2f px)" % maior
	)
	ok(
		origem.distance_to(caminho_a[caminho_a.size() - 1]) <= chefe.raio_orbita + 2.0,
		"ela fica presa a propria orbita, nao se solta atras do alvo"
	)


## TRAVA 8 -- a mira preditiva dela NAO depende da barra.
##
## O comentario dela no codigo diz por que: "A Diretora sempre preve,
## independente da barra: ela E a Deterioracao". Para todo o resto do jogo a
## previsao liga em 50%; para ela, nao ligar seria dizer que o chefe final e
## menos do que o sistema que ele encarna.
func _a_mira_preditiva_nao_depende_da_barra(chefe: Node) -> void:
	var fonte := chefe.get_node_or_null("Visual/ArmaPreditiva")
	ok(fonte != null, "ela tem a arma preditiva")
	if fonte == null:
		return

	var guardado: float = Deterioracao.valor
	Deterioracao.valor = 0.0
	var boca: Vector2 = fonte.global_position
	var velocidade_bala: float = fonte.dados.velocidade_projetil
	var alvo_pos: Vector2 = boca + Vector2(300, 0)
	var previsto_frio := Balistica.ponto_de_intercepto(boca, alvo_pos, Vector2(0, 240), velocidade_bala)
	Deterioracao.valor = guardado

	ok(
		previsto_frio.distance_to(alvo_pos) > 1.0,
		"com a barra em zero ela ainda mira a frente do alvo (%.1f px)" % previsto_frio.distance_to(alvo_pos)
	)


## TRAVA 10 -- ela nao pode ser a unica imune ao Hack.
##
## `receber_dano` dela e reimplementado sem `super`, e o GEMINI ja registra a
## armadilha: o bonus de dano do Hack entra em `projetil._dano_no_alvo()`,
## nunca aqui. Se alguem "consertar" isso movendo o bonus para `receber_dano`,
## o chefe fica imune em silencio e a NOVA perde a personagem inteira contra
## ele.
func _o_hack_atravessa_o_chefe(chefe: Node) -> void:
	var antes: int = chefe.vida
	chefe.aplicar_hack(4.0)
	ok(chefe.esta_hackeado(), "a Diretora aceita ser hackeada")
	chefe.receber_dano(7, Vector2.ZERO)
	igual(chefe.vida, antes - 7, "o dano chega inteiro nela")
	ok(chefe.esta_hackeado(), "levar dano nao limpa a marca")


# -------------------------------------------------- o perfil, isolado ------

## TRAVA 9 -- o aprendizado existe de fato.
##
## Sem esta trava `PerfilJogador` poderia virar codigo morto: a Diretora
## continuaria atacando, o jogo continuaria rodando, e a unica coisa perdida
## seria justamente o que a historia dela promete -- "ela analisa os padroes do
## jogador e modifica seus ataques progressivamente".
func _o_perfil_le_o_jogador() -> void:
	var p := PerfilJogador.new()

	# Sem amostra nenhuma ela nao corrige nada. E o freio de justica: punir um
	# habito que o jogador ainda nao teve chance de formar nao e leitura, e
	# adivinhacao com cara de leitura.
	perto(p.confianca(), 0.0, "perfil recem-nascido nao tem confianca")
	perto(p.lado_previsto(), 0.0, "perfil recem-nascido nao tem vies")

	# Um jogador que so circula para um lado: a normal da linha chefe->jogador
	# aponta para +y quando ele esta a +x, entao circular para baixo e vies
	# POSITIVO.
	var chefe := Vector2.ZERO
	var jogador := Vector2(300, 0)
	for i in 240:
		p.observar(jogador, Vector2(0, 260), chefe, PASSO)
	ok(p.lado_previsto() > 0.5, "ele sempre desvia para o mesmo lado (%.2f)" % p.lado_previsto())
	perto(p.confianca(), 1.0, "quatro segundos de movimento dao confianca cheia")

	# E o jogador pode QUEBRAR a leitura -- o texto promete um duelo, e duelo
	# em que a leitura nao se desfaz e so punicao com nome bonito.
	for i in 240:
		p.observar(jogador, Vector2(0, -260), chefe, PASSO)
	ok(p.lado_previsto() < -0.5, "trocar de lado desfaz a leitura (%.2f)" % p.lado_previsto())

	_o_perfil_le_postura_e_imobilidade()


func _o_perfil_le_postura_e_imobilidade() -> void:
	var colado := PerfilJogador.new()
	for i in 120:
		colado.observar(Vector2(80, 0), Vector2(0, 200), Vector2.ZERO, PASSO)
	igual(colado.postura(), PerfilJogador.Postura.COLADO, "quem gruda le como COLADO")

	var longe := PerfilJogador.new()
	for i in 120:
		longe.observar(Vector2(600, 0), Vector2(0, 200), Vector2.ZERO, PASSO)
	igual(longe.postura(), PerfilJogador.Postura.LONGE, "quem mantem distancia le como LONGE")

	# Parado atirando: e a leitura que justifica o Enxame, cujo proposito
	# declarado e "impedir que o jogador permaneca parado atacando o boss".
	var quieto := PerfilJogador.new()
	for i in 240:
		quieto.observar(Vector2(300, 0), Vector2.ZERO, Vector2.ZERO, PASSO)
	ok(quieto.fracao_parado() > 0.9, "quem nao anda le como parado (%.2f)" % quieto.fracao_parado())
	perto(quieto.confianca(), 0.0, "ficar parado nao ensina lado nenhum")


# ------------------------------------------------------------ helpers ------

func _nascer() -> Node:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)
	var chefe := CENA_DIRETORA.instantiate()
	raiz.add_child(chefe)
	chefe.global_position = LONGE
	# Sem fisica: a suite roda num frame so e `move_and_slide` fora de um passo
	# de fisica nao acrescenta nada ao que estas travas medem.
	chefe.set_physics_process(false)
	return chefe


## As posicoes por onde ela passa em 1 s de orbita, com o jogador em `pos_alvo`.
##
## A orbita e REBOBINADA antes de cada corrida. Sem isso a segunda comparacao
## comeca meia volta adiante da primeira e as duas trajetorias divergem por
## fase, nao por causa do jogador -- o teste acusaria perseguicao onde ha so um
## angulo acumulado. Foi exatamente o que aconteceu na primeira rodada desta
## suite, e o numero (12,68 px) era bonito o bastante para parecer um bug real.
func _rodar_orbita(chefe: Node, pos_alvo: Vector2) -> Array[Vector2]:
	var falso := Node2D.new()
	chefe.get_parent().add_child(falso)
	falso.global_position = pos_alvo
	chefe.alvo = falso

	chefe._angulo_orbita = 0.0
	chefe.global_position = LONGE
	chefe.velocity = Vector2.ZERO
	chefe._centro = LONGE
	chefe._centro_definido = true

	var caminho: Array[Vector2] = []
	for i in 60:
		chefe._orbitar(PASSO)
		# `_orbitar` escreve em `velocity`; sem passo de fisica, integramos na
		# mao. E o suficiente para a pergunta: a trajetoria depende do alvo?
		chefe.global_position += chefe.velocity * PASSO
		caminho.append(chefe.global_position)

	chefe.alvo = null
	falso.free()
	return caminho


## O repertorio de uma fase, sem repeticoes. Repeticao e peso no sorteio, nao
## padrao a mais.
func _repertorio_unico(chefe: Node, fase: int) -> Array[StringName]:
	var vistos: Array[StringName] = []
	for ataque: StringName in chefe.repertorio_da_fase(fase):
		if not vistos.has(ataque):
			vistos.append(ataque)
	return vistos
