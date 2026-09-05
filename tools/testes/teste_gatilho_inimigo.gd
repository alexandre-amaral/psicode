extends TesteBase
## INIMIGO NAO TEM DEDO, e por isso arma semiautomatica o silencia.
##
## `pode_atirar()` recusa quando `not dados.automatica and not _gatilho_solto`, e
## `atirar()` poe `_gatilho_solto = false`. Quem devolve o gatilho e
## `atualizar_gatilho(false)` -- e essa chamada existe no `Player`, que aperta e
## solta um botao de verdade.
##
## Um inimigo nao aperta nada. Ele decide atirar dentro de uma maquina de
## estados, e cada decisao ja E um tiro novo: nao ha "segurar" para impedir. Sem
## alguem soltando o gatilho por ele, **o primeiro tiro sai e todos os seguintes
## sao recusados em silencio** -- sem erro no console, sem nada em tela, so um
## inimigo que carrega o aviso e nao dispara.
##
## Tres inimigos usam arma semiautomatica: Sentinela Orbital, Atirador Neon e
## Vigia. A Diretora tambem, e ela e a UNICA que funcionava -- ela chama
## `atualizar_gatilho(false)` a mao, no `diretora.gd:535`. Uma chamada que
## precisa ser lembrada em cada inimigo novo e uma chamada que sera esquecida, e
## foi.

const CENAS := {
	&"sentinela_orbital": "res://src/enemies/sentinela_orbital.tscn",
	&"atirador_neon": "res://src/enemies/atirador_neon.tscn",
	&"vigia": "res://src/enemies/vigia.tscn",
	&"diretora": "res://src/enemies/diretora.tscn",
}

## Longe da origem: outras suites deixam corpos por la enquanto o coletor nao
## passa, e um deles no grupo "player" faria a mira medir outra coisa.
const LONGE := Vector2(52000.0, 52000.0)


func nome() -> String:
	return "Gatilho de inimigo"


func executar() -> void:
	await _a_arma_de_inimigo_atira_MAIS_DE_UMA_VEZ()
	_a_regra_do_semiautomatico_e_do_jogador()
	await _o_projetil_hostil_MACHUCA_o_jogador()


## O portao: cada inimigo armado dispara DUAS vezes seguidas.
##
## Duas e nao uma, e a diferenca e o bug inteiro: com uma so, a suite passaria
## exatamente como o jogo passava -- o primeiro tiro sempre saiu.
func _a_arma_de_inimigo_atira_MAIS_DE_UMA_VEZ() -> void:
	for chave in CENAS:
		var cena: PackedScene = load(CENAS[chave])
		if cena == null:
			ok(false, "%s carrega" % chave)
			continue
		var raiz := Node2D.new()
		var container := Node2D.new()
		container.add_to_group("container_projeteis")
		raiz.add_child(container)
		Engine.get_main_loop().root.add_child(raiz)
		raiz.global_position = LONGE

		var inimigo := cena.instantiate() as Node2D
		raiz.add_child(inimigo)
		await Engine.get_main_loop().process_frame

		var arma := _arma_de(inimigo)
		if arma == null:
			ok(false, "%s tem uma Arma" % chave)
			raiz.free()
			continue

		var semi := arma.dados != null and not arma.dados.automatica
		var saiu := 0
		for i in 3:
			# Zera a cadencia entre os tiros: o que se mede aqui e o GATILHO, e
			# nao o intervalo. Deixar a cadencia correr misturaria as duas
			# recusas e o portao nao diria qual delas mordeu.
			arma._t_cadencia = 0.0
			if arma.atirar(Vector2.RIGHT):
				saiu += 1
		ok(
			saiu == 3,
			"%s: a arma dispara as tres vezes (saiu %d) -- semiautomatica: %s"
				% [chave, saiu, "sim" if semi else "nao"]
		)
		raiz.free()


## E a REGRA continua valendo para o jogador.
##
## O conserto podia ter sido "todo inimigo chama `atualizar_gatilho`", e ele
## seria pior: uma chamada que precisa ser lembrada em cada inimigo novo e uma
## chamada que sera esquecida -- exatamente como foi. O conserto e a `Arma` saber
## que gatilho e coisa de quem tem dedo.
##
## Mas o semiautomatico existe por um motivo no jogador: sem ele, segurar o botao
## dispara em cadencia cheia e a arma deixa de ser semiautomatica. Este caso e o
## outro lado da moeda -- o afrouxamento nao pode vazar para o Player.
func _a_regra_do_semiautomatico_e_do_jogador() -> void:
	var raiz := Node2D.new()
	var container := Node2D.new()
	container.add_to_group("container_projeteis")
	raiz.add_child(container)
	Engine.get_main_loop().root.add_child(raiz)
	raiz.global_position = LONGE

	var dados := DadosArma.new()
	dados.automatica = false
	dados.cadencia = 100.0
	dados.tamanho_pente = 99
	dados.municao_maxima = -1

	var do_jogador := Arma.new()
	do_jogador.hostil = false
	raiz.add_child(do_jogador)
	do_jogador.equipar(dados)

	var saiu := 0
	for i in 3:
		do_jogador._t_cadencia = 0.0
		if do_jogador.atirar(Vector2.RIGHT):
			saiu += 1
	igual(saiu, 1,
		"a arma do JOGADOR continua semiautomatica: um tiro por aperto (%d)" % saiu)

	do_jogador.atualizar_gatilho(false)
	do_jogador._t_cadencia = 0.0
	ok(do_jogador.atirar(Vector2.RIGHT), "e soltar o gatilho libera o proximo")

	var do_inimigo := Arma.new()
	do_inimigo.hostil = true
	raiz.add_child(do_inimigo)
	do_inimigo.equipar(dados)
	var saiu_inimigo := 0
	for i in 3:
		do_inimigo._t_cadencia = 0.0
		if do_inimigo.atirar(Vector2.RIGHT):
			saiu_inimigo += 1
	igual(saiu_inimigo, 3,
		"a MESMA arma na mao de um inimigo dispara as tres (%d)" % saiu_inimigo)

	raiz.free()


func _arma_de(no: Node) -> Arma:
	var arma := no as Arma
	if arma != null and arma.dados != null:
		return arma
	for filho in no.get_children():
		var achado := _arma_de(filho)
		if achado != null:
			return achado
	return null


## E O TIRO QUE SAI MACHUCA, medido no jogador de verdade.
##
## O reporte trazia dois sintomas -- "o disparo nao sai, ou se sai nao da dano"
## --, e a causa achada explica o primeiro. O segundo precisava ser MEDIDO e nao
## deduzido: se houvesse um segundo defeito no caminho do dano, consertar so o
## gatilho entregaria um inimigo que atira e continua inofensivo.
##
## O caminho tem tres pontos onde ele poderia se perder em silencio: a layer do
## projetil hostil (5 contra a mask do player), o `_dano_no_alvo()` que devolve
## `dano` cru quando `hostil` -- sem passar por `Modificadores`, que e do jogador
## --, e os i-frames, que recusam o segundo acerto de proposito.
func _o_projetil_hostil_MACHUCA_o_jogador() -> void:
	var cena: PackedScene = load("res://src/player/player.tscn")
	if cena == null:
		ok(false, "a cena do player carrega")
		return
	var raiz := Node2D.new()
	var container := Node2D.new()
	container.add_to_group("container_projeteis")
	raiz.add_child(container)
	Engine.get_main_loop().root.add_child(raiz)
	raiz.global_position = LONGE

	var jogador := cena.instantiate() as Node2D
	raiz.add_child(jogador)
	jogador.global_position = LONGE + Vector2(120.0, 0.0)
	# O `_physics_process` dele mira pelo mouse e anda; num arnes isso so
	# atrapalha, e a armadilha ja esta registrada para o sprite.
	jogador.set_physics_process(false)
	await Engine.get_main_loop().process_frame

	var vida_antes: int = jogador.vida
	ok(vida_antes > 0, "o jogador nasce com vida (%d)" % vida_antes)

	var arma := Arma.new()
	arma.hostil = true
	raiz.add_child(arma)
	arma.global_position = LONGE
	arma.equipar(load("res://src/weapons/tiro_sentinela.tres") as DadosArma)
	ok(arma.atirar(Vector2.RIGHT), "a arma da Sentinela dispara")

	# Deixa o projetil viajar os 120 px. A 470 px/s isso e ~0,26 s; o laco anda
	# ate o dano chegar, com teto grande so como rede -- contar QUADROS nao
	# serve, porque sem janela o headless roda centenas por segundo.
	var voltas := 0
	while jogador.vida == vida_antes and voltas < 3000:
		await Engine.get_main_loop().physics_frame
		voltas += 1

	ok(
		jogador.vida < vida_antes,
		"e o tiro MACHUCA: vida de %d para %d em %d passos"
			% [vida_antes, jogador.vida, voltas]
	)
	raiz.free()
