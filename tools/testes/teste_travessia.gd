extends TesteBase
## A travessia de verdade: o jogador ATRAVESSA A PORTA.
##
## **Nada disto estava coberto, e a razao e que o teste de fumaca nao passa pela
## porta**: ele mata os inimigos por script e salta de sala em sala. Toda a
## maquina de `_ao_porta_atravessada` -> `_sair` -> `_chegar` roda em jogo e nunca
## rodava em suite.
##
## Com a parede compartilhada isso deixou de ser um detalhe. A travessia caiu de
## 316 px para 96, e tres coisas que sobravam de folga passaram a ser apertadas:
##
##   - **desistir no meio.** `_cancelar_travessia()` tem uma janela de 96 px para
##     acontecer; antes tinha 316.
##   - **o lockdown.** A fronteira de combate agora e uma parede que a sala
##     vizinha tambem usa, e trancar uma porta nao pode abrir a outra.
##   - **o backtracking.** Voltar para uma sala limpa nao pode recomecar o
##     combate -- `ativar()` e idempotente, e isso continua sendo cobrado.
##
## O jogador anda em PASSOS: `Porta` escuta `body_entered` de uma `Area2D`, e um
## teleporte de uma vez atravessaria o gatilho sem disparar. Oito px por passo e
## menos que o raio do corpo, entao nenhum passo pula a area.

## Longe da origem, como as outras suites que sobem nos.
const LONGE := Vector2(53000.0, 53000.0)

## Quanto o jogador anda por passo. Menor que o raio do corpo de proposito.
const PASSO := 8.0

## Teto de passos por travessia. O maior vao declarado e 384 px, mais a folga de
## centragem; 200 passos sao 1600 px, folgado o bastante para nao mascarar um
## defeito e curto o bastante para a suite terminar.
const PASSOS_MAXIMOS := 200


func nome() -> String:
	return "Travessia"


func executar() -> void:
	await _atravessar_e_voltar()
	await _desistir_no_meio_nao_troca_de_sala()
	await _a_porta_trancada_nao_deixa_passar()


## Sobe o andar e devolve `{main, mapa, jogador}`.
func _montar() -> Dictionary:
	var main := (load("res://src/main/main.tscn") as PackedScene).instantiate()
	var mundo := main.find_child("Mundo", true, false) as Node2D
	if mundo != null:
		mundo.position = LONGE
	Engine.get_main_loop().root.add_child(main)
	var mapa := main.find_child("GerenciadorMapa", true, false) as GerenciadorMapa
	var jogador := main.find_child("Player", true, false) as Node2D
	return {"main": main, "mapa": mapa, "jogador": jogador}


## Anda em passos ate a condicao ou o teto. Devolve quantos passos deu.
func _andar(jogador: Node2D, direcao: Vector2, ate: Callable) -> int:
	for i in PASSOS_MAXIMOS:
		if ate.call():
			return i
		jogador.global_position += direcao * PASSO
		await Engine.get_main_loop().physics_frame
	return PASSOS_MAXIMOS


## Uma aresta da sala inicial, com a direcao e a sala de destino.
func _primeira_saida(mapa: GerenciadorMapa) -> Dictionary:
	var origem := mapa.celula_atual()
	for direcao in mapa.vizinhos_de(origem):
		return {"direcao": direcao, "destino": origem + Vector2i(int(direcao.x), int(direcao.y))}
	return {}


## O caminho inteiro: sair, chegar, e voltar sem recomecar o combate.
##
## **Voltar e a metade que quase ninguem testa.** `ativar()` e idempotente de
## proposito -- "reentrar numa sala ja limpa nao recomeca o combate" --, e com a
## travessia curta o jogador cruza a fronteira de ida e volta em menos de um
## segundo.
func _atravessar_e_voltar() -> void:
	var cenario := _montar()
	var mapa: GerenciadorMapa = cenario["mapa"]
	var jogador: Node2D = cenario["jogador"]
	if mapa == null or jogador == null:
		ok(false, "o andar monta gerenciador e jogador")
		return
	await Engine.get_main_loop().physics_frame
	await Engine.get_main_loop().physics_frame

	var saida := _primeira_saida(mapa)
	ok(not saida.is_empty(), "a sala inicial tem uma saida")
	if saida.is_empty():
		cenario["main"].free()
		return

	var origem := mapa.celula_atual()
	var destino: Vector2i = saida["destino"]
	var direcao: Vector2 = saida["direcao"]
	# Desliga o `_physics_process` do jogador: ele le o mouse e a entrada, e num
	# harness isso empurra o corpo contra o passo que a suite esta dando.
	jogador.set_physics_process(false)
	jogador.global_position = mapa.contorno_global_de(origem)[0].lerp(
		_centro(mapa.contorno_global_de(origem)), 0.5)
	jogador.global_position = _centro(mapa.contorno_global_de(origem))

	var passos := await _andar(jogador, direcao, func(): return mapa.celula_atual() == destino)
	igual(mapa.celula_atual(), destino,
		"o jogador atravessou a porta e chegou na sala vizinha (%d passos)" % passos)

	if mapa.celula_atual() != destino:
		cenario["main"].free()
		return

	# O LOCKDOWN ACONTECE AQUI, e a primeira versao deste caso nao previa.
	#
	# A sala de destino ativa ao ser alcancada, poe a composicao dela em campo e
	# TRANCA as portas -- entao o jogador nao volta, e a suite media 200 passos
	# sem sair do lugar. Isso nao era um defeito da travessia: era a fronteira de
	# combate funcionando, no meio do teste que deveria prova-la.
	#
	# Entao ela vira a asercao: com inimigos vivos, a porta nao deixa passar.
	var vivos := _inimigos_de(mapa, destino)
	if vivos > 0:
		var tentou := await _andar(jogador, -direcao,
			func(): return mapa.celula_atual() == origem)
		igual(mapa.celula_atual(), destino,
			"com %d inimigos vivos, a porta trancada nao deixa voltar (%d passos)"
				% [vivos, tentou])
		_limpar_sala(mapa, destino)
		for i in 10:
			await Engine.get_main_loop().physics_frame

	# E DE VOLTA. A sala de origem ja foi visitada; reentrar nela nao pode
	# recomecar nada.
	jogador.global_position = _centro(mapa.contorno_global_de(destino))
	await Engine.get_main_loop().physics_frame
	var voltou := await _andar(jogador, -direcao, func(): return mapa.celula_atual() == origem)
	igual(mapa.celula_atual(), origem,
		"limpa a sala, ele volta por onde veio (%d passos)" % voltou)
	ok(mapa.foi_visitada(destino), "a sala visitada continua marcada como visitada")
	cenario["main"].free()
	await Engine.get_main_loop().physics_frame


## Sair pela porta e voltar antes de chegar NAO troca de sala.
##
## E o gesto de quem desistiu, e ele ja quebrou uma vez: antes da correcao,
## sair de uma porta para dentro da propria sala iniciava a travessia. Com 96 px
## de vao a janela para desistir e um terco do que era.
func _desistir_no_meio_nao_troca_de_sala() -> void:
	var cenario := _montar()
	var mapa: GerenciadorMapa = cenario["mapa"]
	var jogador: Node2D = cenario["jogador"]
	if mapa == null or jogador == null:
		return
	await Engine.get_main_loop().physics_frame
	await Engine.get_main_loop().physics_frame

	var saida := _primeira_saida(mapa)
	if saida.is_empty():
		cenario["main"].free()
		return
	var origem := mapa.celula_atual()
	var direcao: Vector2 = saida["direcao"]
	jogador.set_physics_process(false)
	jogador.global_position = _centro(mapa.contorno_global_de(origem))

	# Meio caminho para fora, e volta.
	var contorno := mapa.contorno_global_de(origem)
	var fora := func():
		return not Geometry2D.is_point_in_polygon(jogador.global_position, contorno)
	await _andar(jogador, direcao, fora)
	for i in 4:
		jogador.global_position += direcao * PASSO
		await Engine.get_main_loop().physics_frame
	var dentro := func(): return Geometry2D.is_point_in_polygon(
		jogador.global_position, contorno)
	await _andar(jogador, -direcao, dentro)
	for i in 6:
		await Engine.get_main_loop().physics_frame

	igual(mapa.celula_atual(), origem,
		"sair e voltar antes de chegar mantem a sala atual")
	cenario["main"].free()
	await Engine.get_main_loop().physics_frame


## A porta TRANCADA nao deixa passar, e a barreira e um solido de verdade.
##
## O lockdown e o que faz o combate ter fronteira, e com a parede compartilhada
## essa fronteira passou a ser a mesma parede que a sala vizinha usa. Trancar uma
## porta nao pode abrir a outra.
func _a_porta_trancada_nao_deixa_passar() -> void:
	var cena := load("res://src/mapa/sala_1_retangular.tscn") as PackedScene
	var sala := cena.instantiate() as Sala
	sala.position = LONGE
	Engine.get_main_loop().root.add_child(sala)
	await Engine.get_main_loop().physics_frame

	var raiz := sala.get_node_or_null("Portas")
	ok(raiz != null, "a sala monta as portas")
	if raiz == null:
		sala.free()
		return
	# `_aplicar_estado()` mexe na colisao por `set_deferred` -- trancar costuma ser
	# chamado de dentro de um sinal de fisica, e mexer em colisao no meio do passo
	# derruba o servidor. Entao a leitura vem DEPOIS de um frame; sem isso o
	# portao le o estado anterior e a primeira versao deste caso mediu 0 de 4 com
	# o codigo certo.
	var trancadas := 0
	for filho in raiz.get_children():
		var porta := filho as Porta
		if porta == null or porta.esta_selada():
			continue
		porta.trancar()
		trancadas += 1
	await Engine.get_main_loop().physics_frame
	var com_solido := 0
	for filho in raiz.get_children():
		var porta := filho as Porta
		if porta == null or porta.esta_selada():
			continue
		var barreira := porta.get_node_or_null("Barreira/Colisao") as CollisionShape2D
		if barreira != null and not barreira.disabled:
			com_solido += 1
	ok(trancadas > 0, "houve porta para trancar (%d)" % trancadas)
	igual(com_solido, trancadas,
		"toda porta trancada liga a barreira (%d de %d)" % [com_solido, trancadas])

	# E o outro lado: destrancada, a barreira sai. Sem esta metade o portao
	# passaria com uma barreira presa para sempre, e a sala limpa ficaria fechada.
	for filho in raiz.get_children():
		var porta := filho as Porta
		if porta != null and not porta.esta_selada():
			porta.abrir()
	await Engine.get_main_loop().physics_frame
	var soltas := 0
	for filho in raiz.get_children():
		var porta := filho as Porta
		if porta == null or porta.esta_selada():
			continue
		var barreira := porta.get_node_or_null("Barreira/Colisao") as CollisionShape2D
		if barreira != null and barreira.disabled:
			soltas += 1
	igual(soltas, trancadas,
		"e destrancada ela sai (%d de %d)" % [soltas, trancadas])
	sala.free()


func _centro(pontos: PackedVector2Array) -> Vector2:
	return _caixa(pontos).get_center()


func _caixa(pontos: PackedVector2Array) -> Rect2:
	if pontos.is_empty():
		return Rect2()
	var caixa := Rect2(pontos[0], Vector2.ZERO)
	for p in pontos:
		caixa = caixa.expand(p)
	return caixa


## Quantos inimigos vivos ha nesta celula.
func _inimigos_de(mapa: GerenciadorMapa, celula: Vector2i) -> int:
	for filho in mapa.get_children():
		var sala := filho as Sala
		if sala == null or sala.coordenadas_grid != celula:
			continue
		var container := sala.get_node_or_null("ContainerInimigos")
		return container.get_child_count() if container != null else 0
	return 0


## Tira os inimigos da sala para a porta destrancar.
##
## `free()` e nao `queue_free()`: a sala escuta a morte deles para decidir que
## ficou LIMPA, e um no diferido continua contando por mais um frame -- tempo
## suficiente para a suite andar oito px contra uma porta ainda trancada.
func _limpar_sala(mapa: GerenciadorMapa, celula: Vector2i) -> void:
	for filho in mapa.get_children():
		var sala := filho as Sala
		if sala == null or sala.coordenadas_grid != celula:
			continue
		var container := sala.get_node_or_null("ContainerInimigos")
		if container == null:
			return
		for inimigo in container.get_children():
			if inimigo.has_method("morrer"):
				inimigo.morrer()
			else:
				inimigo.free()
		return
