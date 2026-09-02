extends TesteBase
## O LOBBY: ele monta, da para andar nele, e ele NAO e uma run.
##
## A suite instancia a cena de verdade em vez de conferir o `.tscn` como texto.
## O que interessa aqui e o que existe DEPOIS do `_ready` -- chao, parede,
## colisao, estacoes e camera nascem em codigo, entao ler o arquivo mediria a
## unica parte que nao tem nada.
##
## **Ela usa um `user://` de teste.** `Save._caminho` e sobrescrito pela mesma
## razao de sempre: uma suite que grava no save real apaga o progresso de quem
## esta desenvolvendo.

const CENA := preload("res://src/lobby/lobby.tscn")
const CAMINHO_DE_TESTE := "user://teste_lobby_suite.json"


func nome() -> String:
	return "Lobby"


func executar() -> void:
	await _o_lobby_monta_o_lugar_inteiro()
	await _o_jogador_nasce_no_spawn_com_a_camera_presa()
	await _as_tres_estacoes_existem_e_sao_acionaveis()
	await _o_detector_escolhe_o_MAIS_PROXIMO()
	await _selecionar_personagem_grava_e_acende_a_plataforma()
	await _o_prompt_aparece_EM_CIMA_do_objeto()
	await _o_lobby_nao_mostra_hud_de_run()


## Um lobby montado, e quem o libera no fim.
##
## O `free()` e imediato de proposito: a cena poe um Player no grupo global
## "player", e um `queue_free()` deixaria esse Player no grupo enquanto o
## coletor nao passa -- as suites seguintes que fazem
## `get_first_node_in_group("player")` receberiam o boneco desta. E a mesma
## loteria que o `container_projeteis` ja cobrou.
func _nascer() -> Lobby:
	var antes := Save._caminho
	Save._caminho = CAMINHO_DE_TESTE
	Save.apagar_save()
	Progressao.criar_novo()
	Save._caminho = antes

	var lobby := CENA.instantiate() as Lobby
	Engine.get_main_loop().root.add_child(lobby)
	# Longe da origem: outras suites deixam corpos por la enquanto o coletor nao
	# passa, e uma Area2D de interacao encostaria neles.
	lobby.global_position = Vector2(41000.0, 41000.0)
	return lobby


## Chao, sombra, fita e colisao -- os quatro nascem em codigo.
func _o_lobby_monta_o_lugar_inteiro() -> void:
	var lobby := _nascer()
	await Engine.get_main_loop().process_frame

	ok(lobby.get_node_or_null("Mundo/Chao") != null, "o lobby monta o chao")
	ok(lobby.get_node_or_null("Mundo/SombraDaParede") != null,
		"e a sombra da parede -- ela assenta a parede aqui como na sala")
	var fita := lobby.get_node_or_null("Mundo/ParedeModulos") as Node2D
	ok(fita != null, "e a fita de parede")
	if fita != null:
		ok(fita.get_child_count() > 40,
			"a fita veste o lobby inteiro (%d pecas)" % fita.get_child_count())

	var paredes := lobby.get_node_or_null("Paredes") as StaticBody2D
	ok(paredes != null, "e a colisao")
	if paredes != null:
		igual(paredes.collision_layer, Lobby.LAYER_PAREDE,
			"a parede do lobby usa a layer `parede`, como a da sala")
		igual(paredes.get_child_count(), 4, "um segmento por lado")

	# A GRADE vale aqui tambem: a dimensao tem de ser multipla de 32, senao a
	# meia dimensao do contorno nao cai na grade de 16 e a fita desalinha.
	igual(int(Lobby.LARGURA) % 32, 0, "a largura cai na grade (%d)" % int(Lobby.LARGURA))
	igual(int(Lobby.ALTURA) % 32, 0, "a altura cai na grade (%d)" % int(Lobby.ALTURA))
	ok(Lobby.LARGURA > 960.0, "e o lobby e maior que a tela -- a camera tem para onde andar")
	lobby.free()


func _o_jogador_nasce_no_spawn_com_a_camera_presa() -> void:
	var lobby := _nascer()
	await Engine.get_main_loop().process_frame

	var player := lobby.get_node_or_null("Mundo/Player") as Node2D
	ok(player != null, "o lobby traz o Player")
	if player != null:
		perto(
			player.global_position.distance_to(lobby.global_position + lobby.ponto_de_spawn()),
			0.0, "e ele nasce no spawn", 1.0
		)
		# O spawn fica FORA das estacoes: nascer dentro de um prompt faria a
		# primeira coisa do jogo ser um texto, e nao andar.
		var detector := DetectorDeInteracao.new()
		detector.dono = player
		ok(lobby.ponto_de_spawn().y > 0.0,
			"o spawn fica na metade de baixo, longe da baia")
		detector.free()

		var camera := player.get_node_or_null("Camera") as Camera2D
		ok(camera != null, "o Player traz a propria camera, como no jogo")
		if camera != null:
			var margem := RenderizadorParedes.alcance()
			perto(
				float(camera.limit_right - camera.limit_left),
				Lobby.LARGURA + margem * 2.0,
				"o clamp cobre o lobby MAIS a faixa de parede -- senao o quadro para na linha do chao",
				2.0
			)
	lobby.free()


## As tres estacoes do plano existem, e todas as tres sao `Interativo`.
func _as_tres_estacoes_existem_e_sao_acionaveis() -> void:
	var lobby := _nascer()
	await Engine.get_main_loop().process_frame

	var achados: Array[StringName] = []
	for interativo in _interativos_de(lobby):
		achados.append(interativo.id)
	ok(achados.has(&"raven"), "a baia oferece a RAVEN")
	ok(achados.has(&"nova"), "a baia oferece a NOVA")
	ok(achados.has(&"historico"),
		"o terminal de historico existe -- e ele e a PROVA de que o save funciona")
	ok(achados.has(&"andar_01"), "e a entrada do Andar 1")
	igual(achados.size(), 4, "e nada alem disso (%d)" % achados.size())

	# NAO E POSSIVEL INICIAR RUN SEM PASSAR PELA ENTRADA. O portao mede o unico
	# lado que da para medir sem simular clique: o elevador e um `Interativo`
	# habilitado, e nada no `_ready` do lobby troca de cena.
	igual(GameState.modo, GameState.Modo.LOBBY,
		"montar o lobby deixa o jogo em modo LOBBY, e nao em RUN")
	lobby.free()


## O MAIS PROXIMO ganha, e a distancia e recalculada.
##
## Pegar o ultimo que entrou seria mais simples e erraria: com duas capsulas lado
## a lado, andar de uma para a outra sem sair do raio da primeira deixaria o
## prompt preso na errada. O jogador leria "Selecionar Raven" parado na frente da
## Nova, e apertaria a tecla acreditando na tela.
func _o_detector_escolhe_o_MAIS_PROXIMO() -> void:
	var lobby := _nascer()
	await Engine.get_main_loop().process_frame

	var capsulas: Array[Interativo] = []
	for interativo in _interativos_de(lobby):
		if interativo.id == &"raven" or interativo.id == &"nova":
			capsulas.append(interativo)
	if capsulas.size() < 2:
		ok(false, "ha duas capsulas para comparar")
		lobby.free()
		return

	var player := lobby.get_node_or_null("Mundo/Player") as Node2D
	var detector := player.get_node_or_null("DetectorDeInteracao") as DetectorDeInteracao
	ok(detector != null, "o Player ganha o detector ao entrar no lobby")
	if detector == null:
		lobby.free()
		return

	for alvo in capsulas:
		detector._ao_entrar(alvo)
	# Colado na PRIMEIRA.
	detector.global_position = capsulas[0].global_position
	detector._reavaliar()
	ok(detector.alvo() == capsulas[0], "colado na primeira, o alvo e a primeira")
	# Colado na SEGUNDA, sem ter saido da primeira.
	detector.global_position = capsulas[1].global_position
	detector._reavaliar()
	ok(detector.alvo() == capsulas[1],
		"andar ate a segunda troca o alvo mesmo sem sair do raio da primeira")

	# Desligado sai da disputa: area fechada e upgrade nao comprado leem como
	# "esta la mas nao serve ainda", que e melhor que o objeto nao existir.
	capsulas[1].habilitado = false
	detector._reavaliar()
	ok(detector.alvo() != capsulas[1], "um interativo DESLIGADO nao vira alvo")
	lobby.free()


func _selecionar_personagem_grava_e_acende_a_plataforma() -> void:
	var antes := Save._caminho
	Save._caminho = CAMINHO_DE_TESTE
	var lobby := _nascer()
	Save._caminho = CAMINHO_DE_TESTE
	await Engine.get_main_loop().process_frame

	igual(Progressao.personagem_selecionado(), "raven", "o perfil novo comeca na Raven")
	lobby._selecionar_personagem("nova")
	igual(Progressao.personagem_selecionado(), "nova", "selecionar troca em memoria")

	# E GRAVA NA HORA. Sem botao "Aplicar", como em `Configuracao`: e um passo a
	# mais para o jogador errar e um estado intermediario a mais para carregar.
	var lido := Save.carregar()
	ok(lido != null and lido.personagem_selecionado == "nova",
		"e grava no DISCO na mesma hora")

	var acesa := lobby._plataformas.get("nova") as Polygon2D
	var apagada := lobby._plataformas.get("raven") as Polygon2D
	ok(acesa != null and acesa.color.is_equal_approx(Lobby.COR_ACESA),
		"a plataforma da escolhida acende")
	ok(apagada != null and apagada.color.is_equal_approx(Lobby.COR_APAGADA),
		"e a da outra apaga -- a escolha tem de ser obvia sem texto")

	# O sinal e GRANDE, e isso e a regra do `IDENTIDADE_VISUAL.md`: sinal e
	# brilhante mas sempre numa forma grande demais para ser confundida com
	# projetil. Nenhum projetil do jogo e um retangulo de 96x32.
	if acesa != null:
		var caixa := Rect2(acesa.polygon[0], Vector2.ZERO)
		for ponto in acesa.polygon:
			caixa = caixa.expand(ponto)
		ok(caixa.size.x >= 64.0 and caixa.size.y >= 24.0,
			"a plataforma acesa e grande demais para ler como projetil (%.0fx%.0f)"
				% [caixa.size.x, caixa.size.y])

	Save.apagar_save()
	Save._caminho = antes
	lobby.free()


## O Lobby nao mostra HUD de run, e o disparo fica desligado.
##
## Uma barra de Deterioracao parada em zero MENTE: ela diz que existe um relogio
## correndo. O HUD e onde o jogador le se esta em perigo, e o Lobby precisa dizer
## que nao esta -- pela mesma razao que o botao de tiro nao responde la.
func _o_lobby_nao_mostra_hud_de_run() -> void:
	var lobby := _nascer()
	await Engine.get_main_loop().process_frame

	var ui := lobby.get_node_or_null("UI") as CanvasLayer
	ok(ui != null, "o lobby tem UI propria")
	if ui != null:
		var proibidos := 0
		for filho in ui.get_children():
			var nome_do_no := String(filho.name)
			if nome_do_no.contains("Barra") or nome_do_no.contains("HUD") \
					or nome_do_no.contains("Minimapa"):
				proibidos += 1
		igual(proibidos, 0, "e nela nao ha barra, HUD nem minimapa (%d)" % proibidos)
	# O PROMPT MORA NO MUNDO, e nao na UI: ele precisa aparecer EM CIMA do
	# objeto. Um rotulo no rodape obriga o jogador a ligar uma frase na base da
	# tela a um corpo no meio dela, e com duas capsulas lado a lado andar um
	# passo troca a frase sem nada indicar qual das duas mudou.
	var prompt := lobby.get_node_or_null("Prompt") as PromptDeInteracao
	ok(prompt != null, "o prompt existe, e no MUNDO e nao na CanvasLayer")
	if prompt != null:
		ok(not prompt.visible, "e nasce escondido -- nao ha nada por perto ainda")

	igual(GameState.modo, GameState.Modo.LOBBY, "o modo e LOBBY")
	ok(not Deterioracao.passiva_ativa, "e a Deterioracao passiva esta desligada")
	lobby.free()


func _interativos_de(raiz: Node) -> Array[Interativo]:
	var achados: Array[Interativo] = []
	for filho in raiz.get_children():
		var interativo := filho as Interativo
		if interativo != null:
			achados.append(interativo)
		achados.append_array(_interativos_de(filho))
	return achados


## O PROMPT APARECE EM CIMA DO OBJETO, e diz a tecla de verdade.
##
## Duas coisas que a primeira versao errava:
##
## 1. **Onde.** Um rotulo no rodape da tela nao diz em QUE se vai interagir. Com
##    as duas capsulas lado a lado o jogador tem de ligar uma frase na base da
##    tela a um corpo no meio dela, e andar um passo troca a frase sem nada
##    indicar qual das duas mudou.
## 2. **Qual tecla.** "[E]" estava cravado no texto. O jogo tem tela de opcoes,
##    entao remapear a acao e questao de quando -- e um prompt que ensina a tecla
##    errada e pior que nenhum prompt.
func _o_prompt_aparece_EM_CIMA_do_objeto() -> void:
	var lobby := _nascer()
	await Engine.get_main_loop().process_frame

	var prompt := lobby.get_node_or_null("Prompt") as PromptDeInteracao
	ok(prompt != null, "o lobby monta o prompt")
	if prompt == null:
		lobby.free()
		return
	ok(not prompt.visible, "e ele nasce escondido")

	var capsula: Interativo = null
	for interativo in _interativos_de(lobby):
		if interativo.id == &"raven":
			capsula = interativo
			break
	ok(capsula != null, "achou a capsula da Raven")
	if capsula == null:
		lobby.free()
		return

	# ANDAR ATE A CAPSULA, e nao chamar `apontar()` na mao.
	#
	# A primeira versao deste caso chamava `apontar()` direto, e por isso passou
	# verde com o detector sem FORMA DE COLISAO -- uma `Area2D` sem forma nunca
	# encontra ninguem, e nao ha erro no console para isso. O portao media a
	# APRESENTACAO e nunca a deteccao, que e a metade que estava quebrada.
	var player := lobby.get_node_or_null("Mundo/Player") as Node2D
	player.global_position = capsula.global_position + Vector2(0.0, 40.0)
	for i in 4:
		await Engine.get_main_loop().physics_frame
	var detector := player.get_node_or_null("DetectorDeInteracao") as DetectorDeInteracao
	ok(detector != null and detector.alvo() == capsula,
		"andar ate a capsula faz o detector encontra-la")
	ok(prompt.visible, "e o prompt aparece sozinho")
	# ACIMA, e o quanto vem do proprio objeto: a capsula tem um retrato de 128 px
	# ancorado na base, e um prompt na altura do terminal cairia dentro dele.
	ok(
		prompt.global_position.y < capsula.global_position.y,
		"e ele fica ACIMA do objeto (%.0f contra %.0f)"
			% [prompt.global_position.y, capsula.global_position.y]
	)
	perto(
		capsula.global_position.y - prompt.global_position.y,
		capsula.altura_do_prompt,
		"na altura que a peca declara", 1.0
	)
	ok(capsula.altura_do_prompt > 128.0,
		"e a capsula pede mais alto que o retrato dela (%.0f)" % capsula.altura_do_prompt)

	prompt.apontar(null)
	ok(not prompt.visible, "e apontar para null esconde")

	# A TECLA VEM DO `InputMap`. Cravada no texto, ela vira mentira no primeiro
	# remapeamento -- e o jogo tem tela de opcoes.
	igual(PromptDeInteracao.tecla_de(&"interagir"), "E",
		"a tecla lida do InputMap e a que esta mapeada")
	igual(PromptDeInteracao.tecla_de(&"acao_que_nao_existe"), "?",
		"acao inexistente devolve `?` -- moldura vazia pareceria defeito")
	lobby.free()
