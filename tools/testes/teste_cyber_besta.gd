extends TesteBase
## A Cyber-Besta (INIM 03): a parede virou recurso do jogador.
##
## Por que isto e teste e nao revisao de olho: o defeito era uma AUSENCIA. A
## investida terminava por TEMPO, acertasse ela o que acertasse -- errar a
## esquiva custava dano, e ACERTAR nao rendia nada. Um inimigo assim e pressao
## pura sem resposta, e nada no console diz isso.
##
## O teste monta uma parede DE VERDADE, na layer 3, e faz a besta correr contra
## ela. Forjar `is_on_wall()` provaria que a maquina de estados troca quando
## alguem manda -- que nao e a pergunta. A pergunta e se ela bate.

const CENA := preload("res://src/enemies/cyber_besta.tscn")
## Layer 3 do project.godot ("parede"), como bit.
const CAMADA_PAREDE := 4
## Longe da origem: outras suites deixam no perto de (0,0) enquanto o coletor
## nao passa, e a besta procura alvo por grupo.
const LONGE := Vector2(21000.0, 21000.0)


func nome() -> String:
	return "CyberBesta"


func executar() -> void:
	await _ela_se_atordoa_ao_bater_na_parede()
	_o_repertorio_ganhou_o_momento_de_encarar()


## A janela de contra-ataque.
##
## Precisa de passo de FISICA: um corpo recem-adicionado so entra no espaco no
## passo seguinte, e `is_on_wall()` so significa alguma coisa depois de o motor
## ter tentado mover alguem. O `runner.gd` faz `await suite.executar()` por isso.
func _ela_se_atordoa_ao_bater_na_parede() -> void:
	var raiz := Node2D.new()
	raiz.position = LONGE
	Engine.get_main_loop().root.add_child(raiz)

	# A parede: um solido na layer 3, largo o bastante para ela nao contornar.
	var parede := StaticBody2D.new()
	parede.collision_layer = CAMADA_PAREDE
	parede.collision_mask = 0
	var forma := CollisionShape2D.new()
	var caixa := RectangleShape2D.new()
	caixa.size = Vector2(40.0, 800.0)
	forma.shape = caixa
	parede.add_child(forma)
	parede.position = Vector2(220.0, 0.0)
	raiz.add_child(parede)

	var besta := CENA.instantiate()
	besta.position = Vector2.ZERO
	raiz.add_child(besta)

	ok(besta.tempo_atordoado > 0.0,
		"ela declara um tempo de atordoamento (%.2f s)" % besta.tempo_atordoado)

	# Investe para a direita, contra a parede.
	besta._direcao_travada = Vector2.RIGHT
	besta._maquina.trocar(besta.INVESTIR)
	igual(String(besta._maquina.estado), "INVESTIR", "ela entra na investida")

	# Deixa a fisica rodar ate ela alcancar a parede. A investida dura 0,42 s a
	# 720 px/s, e a parede esta a 220 px -- ela chega com folga.
	var passos := 0
	while passos < 40 and String(besta._maquina.estado) == "INVESTIR":
		await Engine.get_main_loop().physics_frame
		passos += 1

	igual(
		String(besta._maquina.estado), "ATORDOADO",
		"bater na parede a atordoa -- e a janela de contra-ataque do inimigo"
	)
	ok(passos < 40, "ela alcancou a parede dentro da investida (%d passos)" % passos)

	raiz.free()


## O momento de encarar existe e vem ANTES do agachamento.
##
## Ele nao existe para dar tempo de reagir -- o agachamento ja faz isso -- e sim
## para SEPARAR os dois instantes. Sem ele a besta sai de contornar e agacha no
## mesmo frame, e o jogador nao ve o momento em que ela escolheu ele.
func _o_repertorio_ganhou_o_momento_de_encarar() -> void:
	var besta := CENA.instantiate()
	besta.position = LONGE
	Engine.get_main_loop().root.add_child(besta)

	ok(besta.tempo_encarando > 0.0,
		"ela declara um tempo encarando (%.2f s)" % besta.tempo_encarando)
	ok(
		besta.tempo_encarando < besta.tempo_preparo,
		"encarar e mais curto que preparar (%.2f < %.2f) -- quem da o tempo de reacao e o agachamento"
			% [besta.tempo_encarando, besta.tempo_preparo]
	)

	besta._maquina.trocar(besta.ENCARAR)
	igual(String(besta._maquina.estado), "ENCARAR", "o estado existe na maquina")

	# Atordoada, ela encara PARA ONDE CORREU, e nao para o jogador: virar-se
	# leria como alerta, o oposto da janela que o estado anuncia.
	besta._direcao_travada = Vector2.UP
	besta._maquina.trocar(besta.ATORDOADO)
	var encarada: Vector2 = besta._direcao_encarada()
	perto(
		encarada.angle_to(Vector2.UP), 0.0,
		"atordoada, ela continua encarando a parede que acertou"
	)
	besta.free()
