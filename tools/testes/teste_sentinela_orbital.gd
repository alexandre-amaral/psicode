extends TesteBase
## A Sentinela Orbital (INIM 04): a rajada quebra o ritmo da orbita.
##
## Por que isto e teste: a rajada tem um modo de falha silencioso e ja conhecido
## do projeto. `Arma.atirar()` num laco no mesmo frame dispara UMA vez -- o
## `_t_cadencia` e setado no primeiro tiro e `pode_atirar()` recusa o resto,
## porque o `_process` que decrementa nao roda no meio do laco. Uma rajada
## escrita assim sai com um projetil, exatamente como o tiro unico, e ninguem
## percebe: nao ha erro, e o ataque continua "funcionando".

const CENA := preload("res://src/enemies/sentinela_orbital.tscn")
## Longe da origem, como as outras suites que instanciam inimigo.
const LONGE := Vector2(25000.0, 25000.0)


func nome() -> String:
	return "SentinelaOrbital"


func executar() -> void:
	_a_rajada_sai_com_todos_os_projeteis()
	_o_aviso_distingue_os_dois_ataques()
	_o_ritmo_alterna()


## Tres projeteis, e nao um.
##
## Monta um container proprio e conta o que caiu nele. O container e liberado
## com `free()` e nao `queue_free()`: a suite roda inteira num frame, e um
## container ainda na arvore continua no grupo -- os casos seguintes pediriam
## `get_first_node_in_group` e receberiam ESTE, contando zero no proprio.
func _a_rajada_sai_com_todos_os_projeteis() -> void:
	var raiz := Node2D.new()
	var container := Node2D.new()
	container.add_to_group("container_projeteis")
	raiz.add_child(container)
	raiz.position = LONGE
	Engine.get_main_loop().root.add_child(raiz)

	var sentinela := CENA.instantiate()
	raiz.add_child(sentinela)
	var arma: Arma = sentinela.get_node("Torre/Arma") if sentinela.has_node("Torre/Arma") else sentinela._arma

	ok(sentinela.projeteis_rajada >= 3,
		"a rajada declara ao menos tres projeteis (%d)" % sentinela.projeteis_rajada)

	arma.atirar_varias(
		Balistica.leque(Vector2.RIGHT, sentinela.projeteis_rajada, sentinela.abertura_rajada)
	)
	igual(
		container.get_child_count(), sentinela.projeteis_rajada,
		"a rajada sai com todos os projeteis -- um laco com atirar() sairia com 1"
	)

	# E o leque e simetrico, com a abertura que o inimigo declara.
	var direcoes := Balistica.leque(Vector2.RIGHT, sentinela.projeteis_rajada, sentinela.abertura_rajada)
	var extremos := rad_to_deg(absf(direcoes[0].angle_to(direcoes[direcoes.size() - 1])))
	perto(
		extremos, sentinela.abertura_rajada,
		"a abertura entre os extremos e a declarada", 0.5
	)
	raiz.free()


## O aviso da rajada tem de ser DISTINGUIVEL do aviso do tiro unico.
##
## A regra do projeto e "quanto mais forte o ataque, maior o telegrafo". Se os
## dois avisassem igual, o jogador nao teria como saber qual esta vindo -- e um
## ataque que nao da para distinguir do outro nao da para preparar. E o ataque
## ficaria em cima da linha que separa "dificil" de "mente sobre a propria
## regra".
func _o_aviso_distingue_os_dois_ataques() -> void:
	var sentinela := _nascer()
	ok(sentinela.fator_aviso_rajada > 1.0,
		"o aviso da rajada dura mais que o do tiro unico (%.2fx)" % sentinela.fator_aviso_rajada)

	sentinela._ate_rajada = 5
	var aviso_unico: float = sentinela._duracao_do_aviso()
	ok(not sentinela._vai_rajar(), "com contador cheio a proxima salva e tiro unico")

	sentinela._ate_rajada = 0
	var aviso_rajada: float = sentinela._duracao_do_aviso()
	ok(sentinela._vai_rajar(), "com o contador zerado a proxima salva e rajada")
	ok(
		aviso_rajada > aviso_unico,
		"e o aviso dela e mais longo (%.2f contra %.2f)" % [aviso_rajada, aviso_unico]
	)
	sentinela.free()


## A rajada e OCASIONAL: ela quebra o ritmo, nao vira o ritmo.
##
## Com tiro unico a intervalo fixo o jogador encontra uma cadencia de orbita e
## fica nela. Se toda salva fosse rajada, ele encontraria outra cadencia e
## ficaria nela do mesmo jeito -- o que quebra o ritmo e a ALTERNANCIA.
func _o_ritmo_alterna() -> void:
	var sentinela := _nascer()
	ok(sentinela.tiros_ate_rajada > 0,
		"ela declara quantos tiros unicos vem antes da rajada (%d)" % sentinela.tiros_ate_rajada)

	# Duas sentinelas na mesma sala nao comecam sincronizadas: duas rajadas
	# simultaneas sao seis projeteis, que e outro ataque.
	var inicios := {}
	for i in 24:
		var outra := _nascer()
		inicios[outra._ate_rajada] = true
		outra.free()
	ok(
		inicios.size() >= 2,
		"o contador comeca em fases diferentes (%d valores) -- senao elas rajam juntas" % inicios.size()
	)
	sentinela.free()


func _nascer() -> Node:
	var sentinela := CENA.instantiate()
	sentinela.position = LONGE
	Engine.get_main_loop().root.add_child(sentinela)
	return sentinela
