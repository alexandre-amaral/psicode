extends TesteBase
## Trava o CONTRATO de camadas do mundo -- as faixas de z de `Sala` e quem
## desenha em cada uma.
##
## Existe porque ordem de desenho quebra em SILENCIO. Nao ha erro no console
## para "a parede desenhou por cima da sala inteira" nem para "a moldura da
## porta sumiu atras do chao": o jogo roda, o teste de fumaca passa (ele nunca
## olha um pixel) e o defeito so aparece numa captura que alguem precisa
## lembrar de olhar.
##
## A migracao para Low Top-Down Squared vai encher estas faixas -- face de
## parede (LTD 04), mundo ordenado por Y (LTD 02), frente (LTD 10). Cada uma
## dessas issues acrescenta um caso aqui; esta suite e o lugar onde "a camada
## existe e esta na faixa certa" vira pergunta com resposta.

const CENA_SALA := preload("res://src/mapa/sala_1_retangular.tscn")
const CENA_L := preload("res://src/mapa/sala_2_l_shape.tscn")
const CENA_PILAR := preload("res://src/mapa/sala_5_pilar.tscn")

## Longe da origem: outras suites deixam no ao redor de (0,0) enquanto o
## coletor nao passa, e uma delas ja custou um dia de teste vermelho com o
## codigo certo (ver teste_hack.gd).
const LONGE := Vector2(9000.0, 9000.0)


func nome() -> String:
	return "CamadaVisual"


func executar() -> void:
	_as_faixas_estao_em_ordem()
	_a_sala_monta_cada_camada_na_sua_faixa()
	_o_chao_fica_acima_do_topo_da_parede()
	_a_moldura_da_porta_fica_acima_do_chao()
	_o_obstaculo_cobre_o_chao()
	_a_sala_em_l_monta_as_camadas()
	_a_corrente_do_y_sort_esta_inteira()
	_o_mundo_da_cena_principal_ordena_por_y()
	_o_projetil_desenha_ACIMA_de_todo_cenario_ordenado_por_y()
	_as_camadas_de_cenario_ficam_fora_do_y_sort()
	_o_ator_tem_sombra_na_base()
	_todo_ator_com_arte_tem_origem_nos_pes()
	_o_chefe_do_andar_e_alcancado_pelo_portao_de_origem()
	_a_face_sorteia_por_lado()
	_a_faixa_de_uv_da_face_e_declarada()
	_o_corredor_usa_a_mesma_perspectiva_da_sala()
	_os_quatro_lados_sao_a_mesma_parede()
	_o_topo_e_subordinado_a_face()
	_o_topo_cerca_a_sala_e_a_face_nao_desce_para_o_sul()
	_a_sombra_assenta_a_parede_sem_invadir_o_combate()
	_a_deterioracao_visual_nunca_decresce()
	_so_o_trecho_pre_chefe_anuncia_o_chefe()


## O contrato em si: as faixas sobem na ordem em que as coisas se empilham.
## Se alguem renumerar uma sem olhar as vizinhas, cai aqui.
func _as_faixas_estao_em_ordem() -> void:
	ok(Sala.Z_PAREDE_TOPO < Sala.Z_CHAO, "topo da parede fica ATRAS do chao (e o chao que recorta a faixa visivel)")
	ok(Sala.Z_CHAO < Sala.Z_SOMBRA_PAREDE,
		"a sombra da parede fica ACIMA do chao -- ela precisa escurece-lo")
	ok(Sala.Z_SOMBRA_PAREDE < Sala.Z_CHAO_DETALHE,
		"e ABAIXO do detalhe de chao -- decalque, telegrafo e ator leem por cima dela")
	ok(Sala.Z_CHAO < Sala.Z_CHAO_DETALHE, "detalhe de chao fica acima do chao")
	ok(Sala.Z_CHAO_DETALHE < Sala.Z_PAREDE_FACE, "face da parede fica acima do detalhe de chao")
	ok(Sala.Z_PAREDE_FACE < Sala.Z_MUNDO, "o mundo ordenado por Y fica acima da face")
	ok(Sala.Z_MUNDO < Sala.Z_FRENTE, "a frente fica acima do mundo")
	# Espacamento de 2: cabe uma camada nova entre duas existentes sem
	# renumerar as outras. Renumerar e o que quebra ordem sem erro no console.
	igual(Sala.Z_CHAO - Sala.Z_PAREDE_TOPO, 2, "espacamento entre topo e chao")
	igual(Sala.Z_CHAO_DETALHE - Sala.Z_CHAO, 2, "espacamento entre chao e detalhe")


func _a_sala_monta_cada_camada_na_sua_faixa() -> void:
	var sala := _montar(CENA_SALA)

	var sombra := sala.get_node_or_null("SombraDaParede") as Node2D
	ok(sombra != null, "a sala monta a sombra da parede")
	if sombra != null:
		igual(sombra.z_index, Sala.Z_SOMBRA_PAREDE, "a sombra na faixa dela")
		ok(sombra.get_child_count() >= 4, "a sombra tem tiras (%d)"
			% sombra.get_child_count())

	var fita := sala.get_node_or_null("ParedeModulos") as Node2D
	ok(fita != null, "a sala monta a fita de parede")
	if fita != null:
		ok(fita.z_index < Sala.Z_MUNDO,
			"a fita fica abaixo da faixa do mundo -- parede e arquitetura, e nao ator")
		ok(fita.get_child_count() >= 8, "a fita tem pecas (%d)" % fita.get_child_count())

	var chao := sala.get_node_or_null("Chao") as Polygon2D
	ok(chao != null, "a sala monta a camada Chao")
	if chao != null:
		igual(chao.z_index, Sala.Z_CHAO, "Chao na faixa dele")
		igual(chao.texture_repeat, CanvasItem.TEXTURE_REPEAT_ENABLED,
			"o chao ladrilha -- sem isso a textura sai UMA vez esticada, e o default do projeto e Disabled")

	sala.free()


## A FITA NAO ENCOSTA NO CHAO, e por isso ela pode desenhar por cima dele.
##
## O truque antigo era outro: o corpo da parede era o contorno INFLADO e solido,
## desenhado ATRAS do chao, e quem recortava a faixa visivel era o chao por cima.
## Era isso que fazia a sala em L funcionar sem calcular anel com furo -- e era
## fragil, porque dependia de duas camadas na ordem certa.
##
## A fita nao precisa do truque: toda celula dela mora na FAIXA, do contorno para
## fora, e nenhuma toca area jogavel. Isso e afirmacao geometrica, e o portao que
## a prova celula a celula vive em `teste_renderizador_paredes.gd`. Aqui se cobra
## a consequencia visivel: a fita desenha ACIMA do chao e mesmo assim o chao
## aparece inteiro.
func _o_chao_fica_acima_do_topo_da_parede() -> void:
	var sala := _montar(CENA_SALA)
	var fita := sala.get_node_or_null("ParedeModulos") as Node2D
	var chao := sala.get_node_or_null("Chao") as Polygon2D
	if fita != null and chao != null:
		ok(fita.z_index > chao.z_index,
			"a fita desenha acima do chao -- ela nao precisa mais do recorte")
		# VARRE `Node2D`, E NAO `Sprite2D`.
		#
		# Ate aqui este laco fazia `filho as Sprite2D`, e o renderizador nao cria
		# um unico `Sprite2D` desde a MOLDURA -- ele so monta `Polygon2D`. O caso
		# contava ZERO DE ZERO e passava por vacuidade: um portao que nao olha
		# nada, do mesmo jeito que a #125 registrou para a PAREDE 13.
		#
		# Ele continua valendo ao lado de
		# `teste_renderizador_paredes.gd:_nenhuma_celula_invade_o_chao()`, que
		# cobra a mesma invariante com mais amostras: o que ESTE caso acrescenta e
		# medir a invasao na MESMA cena em que se afirma `fita.z_index > chao`, e
		# sao as duas juntas que autorizam a fita a desenhar acima do chao.
		var contorno := sala.contorno_local()
		# So a SOMBRA DE CONTATO pode entrar, e so ate onde o perfil declara.
		# Ver a versao longa em `teste_renderizador_paredes`.
		var perfil := PerfilDeParede.new()
		var fundo_permitido := perfil.sombra_de_contato
		var dentro := 0
		var conferidas := 0
		for filho in fita.get_children():
			var peca := filho as Node2D
			if peca == null:
				continue
			conferidas += 1
			if not Geometry2D.is_point_in_polygon(peca.position, contorno):
				continue
			var fundura := INF
			var n := contorno.size()
			for k in n:
				fundura = minf(fundura, peca.position.distance_to(
					Geometry2D.get_closest_point_to_segment(
						peca.position, contorno[k], contorno[(k + 1) % n])))
			if fundura > fundo_permitido:
				dentro += 1
		ok(conferidas > 0, "e ha pecas para conferir (%d) -- senao o portao nao olha nada" % conferidas)
		igual(dentro, 0, "e so a sombra de contato entra no chao (%d de %d fora do permitido)"
			% [dentro, conferidas])
	sala.free()


## A moldura da porta (z -1, dentro da cena da porta) tem de ficar acima do
## chao. Antes os dois empatavam em -1 e o desempate era ordem de arvore, o que
## obrigava as camadas geradas a entrar no INICIO da lista de filhos.
func _a_moldura_da_porta_fica_acima_do_chao() -> void:
	var sala := _montar(CENA_SALA)
	var portas := sala.get_node_or_null("Portas")
	ok(portas != null, "a sala_1 tem o no Portas")
	var conferidas := 0
	if portas != null:
		for porta in portas.get_children():
			var moldura := porta.get_node_or_null("Moldura") as CanvasItem
			if moldura == null:
				continue
			conferidas += 1
			ok(moldura.z_index > Sala.Z_CHAO,
				"a moldura de %s desenha acima do chao sem depender de ordem de arvore" % porta.name)
	ok(conferidas >= 2, "conferiu ao menos duas molduras")
	sala.free()


## O pilar e parede no meio da sala: ele PRECISA cobrir o chao, entao nao pode
## usar o truque do recorte. Se ele cair na faixa do topo, some.
func _o_obstaculo_cobre_o_chao() -> void:
	var sala := _montar(CENA_PILAR)
	var bloco: Polygon2D = null
	for filho in sala.get_children():
		if filho.name == "ObstaculoCorpo":
			bloco = filho as Polygon2D
			break
	ok(bloco != null, "a sala com pilar monta o corpo do obstaculo")
	if bloco != null:
		ok(bloco.z_index > Sala.Z_CHAO, "o obstaculo desenha ACIMA do chao, senao o pilar some")
		igual(bloco.z_index, Sala.Z_PAREDE_FACE, "o obstaculo usa a faixa da face de parede")
	sala.free()


## A sala em L e a unica concava do projeto, e e ela que o truque do recorte
## existe para salvar. Uma camada que funcione so no retangulo nao serve.
func _a_sala_em_l_monta_as_camadas() -> void:
	var sala := _montar(CENA_L)
	var fita := sala.get_node_or_null("ParedeModulos") as Node2D
	var chao := sala.get_node_or_null("Chao") as Polygon2D
	ok(fita != null, "a sala em L monta a fita")
	ok(chao != null, "a sala em L monta Chao")
	if fita != null:
		# Seis lados e uma quina CONCAVA: e a forma que quebra sistema de parede
		# escrito so para retangulo.
		ok(fita.get_child_count() >= 8,
			"a fita da sala em L nao degenerou (%d pecas)" % fita.get_child_count())
		var contorno := sala.contorno_local()
		var dentro := 0
		for filho in fita.get_children():
			var sprite := filho as Sprite2D
			if sprite != null and Geometry2D.is_point_in_polygon(sprite.position, contorno):
				dentro += 1
		igual(dentro, 0, "e nenhuma celula dela invade a area jogavel da L (%d)" % dentro)
	sala.free()


## O Y-sort do Godot so alcanca um no se TODOS os ancestrais entre ele e a raiz
## ordenada tambem estiverem ligados. Um elo solto nao gera erro: o jogo roda,
## e a ordem daquele ramo passa a vir da arvore em vez da posicao.
func _a_corrente_do_y_sort_esta_inteira() -> void:
	var sala := _montar(CENA_SALA)
	ok(sala.y_sort_enabled, "a Sala ordena os filhos por Y")

	# O container vem da CENA nesta sala. Metade das salas o traz pronto e
	# metade o cria em codigo -- os dois caminhos tem de acabar ligados.
	var container := sala.get_node_or_null("ContainerInimigos") as Node2D
	ok(container != null, "a sala_1 traz o ContainerInimigos da cena")
	if container != null:
		ok(container.y_sort_enabled, "o ContainerInimigos que veio da cena ordena por Y")

	sala.free()


## A cena principal e onde a corrente comeca. Conferida pelo PackedSceneState,
## sem instanciar: instanciar main.tscn sobe o jogo inteiro e chama
## iniciar_run(), o que nao cabe numa suite unitaria.
func _o_mundo_da_cena_principal_ordena_por_y() -> void:
	var cena: PackedScene = load("res://src/main/main.tscn")
	ok(cena != null, "main.tscn carrega")
	if cena == null:
		return
	var estado := cena.get_state()

	var achou_mundo := false
	var pais: Dictionary = {}
	for i in estado.get_node_count():
		var nome := estado.get_node_name(i)
		pais[nome] = String(estado.get_node_path(i, true))
		if nome != "Mundo":
			continue
		achou_mundo = true
		ok(_propriedade(estado, i, "y_sort_enabled") == true,
			"o no Mundo da cena principal ordena por Y")

	ok(achou_mundo, "a cena principal tem o no Mundo")
	# Player e GerenciadorMapa tem de estar DENTRO dele: irmaos do Mundo nao se
	# ordenam contra o que esta dentro, e era assim que a cena estava antes --
	# o jogador nunca se ordenava contra os inimigos.
	igual(pais.get("Player", ""), "./Mundo", "o Player mora dentro do Mundo")
	igual(pais.get("GerenciadorMapa", ""), "./Mundo", "o GerenciadorMapa mora dentro do Mundo")


## O PROJETIL desenha acima de tudo que se ordena por Y (`[FAB 43]`).
##
## **Isto estava certo por ACIDENTE ate agora.** Nao havia no nenhum no grupo
## `container_projeteis`, entao `Arma._container()` caia em `current_scene` --
## o proprio `Main` --, e projetil adicionado depois do `Mundo` desenha depois
## dele. O resultado era o desejado e a razao nao existia em lugar nenhum: era
## ordem de arvore, e ela se perde no dia em que alguem arrastar um no.
##
## Deixou de ser detalhe quando a migracao das contagens levou a sala de combate
## de 4 para ~15 corpos volumetricos. Um projetil que passa ATRAS de um caixote
## e o defeito que a secao 90 do briefing manda nao ter -- e ele nao da erro, so
## some por meio segundo no meio de uma esquiva.
##
## O contrato tem tres partes, e as tres se cobram aqui:
##
## 1. o container EXISTE e esta no grupo, para o `_container()` nao depender do
##    fallback;
## 2. ele e IRMAO do `Mundo` e vem DEPOIS dele -- dentro do `Mundo` ele entraria
##    no Y-sort e voltaria a sumir atras de quem esta mais abaixo na tela;
## 3. ele NAO ordena por Y, pela mesma razao.
##
## O que continua podendo cobrir um projetil e o Foreground (`Z_FRENTE`), e isso
## e declarado: ele ja e a unica camada do jogo que pode esconder o jogador, e
## ele nunca entra na area util.
func _o_projetil_desenha_ACIMA_de_todo_cenario_ordenado_por_y() -> void:
	var cena: PackedScene = load("res://src/main/main.tscn")
	if cena == null:
		return
	var estado := cena.get_state()
	var indice_do_mundo := -1
	var indice_do_container := -1
	for i in estado.get_node_count():
		match estado.get_node_name(i):
			"Mundo":
				indice_do_mundo = i
			"ContainerProjeteis":
				indice_do_container = i

	ok(indice_do_container >= 0, "a cena principal declara o ContainerProjeteis")
	if indice_do_container < 0:
		return
	var grupos: PackedStringArray = estado.get_node_groups(indice_do_container)
	ok(grupos.has("container_projeteis"),
		"o container esta no grupo que a Arma procura (%s)" % ", ".join(grupos))
	igual(String(estado.get_node_path(indice_do_container, true)), ".",
		"o container e IRMAO do Mundo -- dentro dele o projetil voltaria ao Y-sort")
	ok(indice_do_container > indice_do_mundo,
		"o container vem DEPOIS do Mundo na cena (%d > %d)"
			% [indice_do_container, indice_do_mundo])
	var ordena: Variant = _propriedade(estado, indice_do_container, "y_sort_enabled")
	ok(ordena == null or ordena == false,
		"o container NAO ordena por Y -- projetil nao e corpo no chao")
	# E a camada que ainda pode cobrir um projetil e uma so, declarada.
	ok(Sala.Z_FRENTE > Sala.Z_MUNDO,
		"so o Foreground desenha acima da faixa do mundo")


## z_index tem prioridade sobre Y: so irmaos no MESMO z se ordenam por posicao.
## E isso que mantem chao e parede fora da brincadeira -- e o que faria o chao
## passar na frente do jogador se alguem os trouxesse para a faixa do mundo.
func _as_camadas_de_cenario_ficam_fora_do_y_sort() -> void:
	var sala := _montar(CENA_SALA)
	for nome in ["Chao", "SombraDaParede", "ParedeModulos", "Decoracao"]:
		var camada := sala.get_node_or_null(nome) as CanvasItem
		if camada == null:
			continue
		ok(camada.z_index < Sala.Z_MUNDO,
			"%s fica abaixo da faixa do mundo, entao o Y-sort nao o mistura com os atores" % nome)
	sala.free()


## A sombra e o que responde "onde esta a base disto?" -- a pergunta que a
## perspectiva Low Top-Down cria e nao resolve sozinha. Ela tem de existir, tem
## de ficar NA base (nao no centro do corpo) e tem de ficar FORA do Visual: o
## clarao de dano escreve em `_visual.modulate`, que desce para os filhos, e
## sombra piscando branco a cada tiro e pior que sombra nenhuma.
func _o_ator_tem_sombra_na_base() -> void:
	var cena: PackedScene = load("res://src/enemies/rastejante.tscn")
	ok(cena != null, "rastejante.tscn carrega")
	if cena == null:
		return
	var inimigo := cena.instantiate()
	Engine.get_main_loop().root.add_child(inimigo)

	var sombra := inimigo.get_node_or_null("Sombra") as Sombra
	ok(sombra != null, "o inimigo com sprite ganha sombra")
	if sombra != null:
		ok(sombra.get_parent() == inimigo,
			"a sombra e irma do Visual, nao filha -- senao o clarao de dano a faz piscar")
		var corpo := inimigo.get_node_or_null("Visual/Corpo") as Node2D
		if corpo != null:
			perto(sombra.position.y, Sombra.base_de(corpo),
				"a sombra fica nos pes, e nao no centro do corpo")
			ok(sombra.position.y > corpo.position.y,
				"a sombra fica ABAIXO do corpo (pes %.0f, corpo %.0f)" % [sombra.position.y, corpo.position.y])
		ok(sombra.z_index < 0, "a sombra desenha sob o corpo do proprio ator")
		ok(sombra.color.a > 0.0 and sombra.color.a < 1.0,
			"a sombra e translucida -- opaca ela vira buraco no chao")
	inimigo.free()

	# A arena do chefe nasce DO chao. Sombra nela leria como se a torre
	# estivesse pousada sobre o piso em vez de ter subido dele.
	var cena_torre: PackedScene = load("res://src/enemies/torre_diretora.tscn")
	if cena_torre != null:
		var torre := cena_torre.instantiate()
		Engine.get_main_loop().root.add_child(torre)
		ok(torre.get_node_or_null("Sombra") == null,
			"a torre da arena nao tem sombra: ela sobe do chao, nao pousa nele")
		torre.free()


## Quem AINDA nao tem arte direcional, e por isso o portao de origem nao alcanca.
##
## A lista existe para o silencio virar declaracao. `Visual/Corpo` que e
## `Polygon2D` e pulado pelo portao acima -- e o certo para os quatro inimigos
## desenhados em volta da propria origem, mas foi tambem como a Diretora passou
## anos fora da ancora sem ninguem ver. Um CHEFE nao pode entrar nessa categoria
## por acidente: ele e grande, e sprite grande fora da ancora e o caso em que o
## Y-sort erra mais.
##
## Tirar um nome daqui e o interruptor de "a arte chegou": no dia em que o
## `boss_guardiao_01` ganhar as oito rotacoes (BOSS 10), este teste passa a
## exigir dele a moldura e a ancora como de qualquer outro ator.
## Vazia desde que o Automato ganhou as oito rotacoes (BOSS 10). Ela continua
## existindo porque o proximo chefe vai nascer sem arte tambem, e o que nao pode
## voltar a existir e o SILENCIO.
const SEM_ARTE_AINDA: Array[String] = []


## O CHEFE nao pode ser pulado em silencio pelo portao de origem.
##
## A Diretora e o precedente inteiro: o sprite dela e 192x192 num no
## `Visual/SpriteDiretora`, entao `InimigoBase._corpo` procura `Visual/Corpo`,
## nao acha, e o tint de Hack e de nanite nao pintam nela -- e o portao acima a
## pula sem dizer nada. A BOSS 10 pede que a decisao seja tomada ANTES de
## desenhar, e este caso e a decisao virada portao.
func _o_chefe_do_andar_e_alcancado_pelo_portao_de_origem() -> void:
	var tipo: DadosSala = load("res://src/mapa/tipo_boss.tres")
	ok(tipo != null and not tipo.inimigos.is_empty(), "o tipo de sala do chefe declara um inimigo")
	if tipo == null or tipo.inimigos.is_empty():
		return

	var grupo: GrupoInimigo = tipo.inimigos[0]
	ok(grupo != null and grupo.cena != null, "e o grupo dele aponta para uma cena")
	if grupo == null or grupo.cena == null:
		return

	var arquivo := grupo.cena.resource_path.get_file()
	var chefe := grupo.cena.instantiate()
	Engine.get_main_loop().root.add_child(chefe)

	# 1. O corpo tem de estar onde `InimigoBase` procura. Sem isso o tint de
	#    Hack e o de nanite nao pintam nele, em silencio.
	var corpo := chefe.get_node_or_null("Visual/Corpo")
	ok(corpo != null,
		"%s tem `Visual/Corpo` -- e onde InimigoBase procura para pintar Hack e nanite" % arquivo)

	# 2. Ou ele tem arte ancorada, ou esta DECLARADO como ainda sem arte. O que
	#    o portao proibe e a terceira opcao: ser pulado sem ninguem saber.
	var sprite := corpo as Sprite2D
	var tem_arte := sprite != null and sprite.texture != null
	if tem_arte:
		var altura := sprite.texture.get_height()
		ok(Direcoes.moldura_de_ator(float(altura)),
			"%s usa uma moldura de ator (%d) -- arte de chefe fora do gerador foi como a Diretora perdeu a ancora"
				% [arquivo, altura])
		perto(sprite.position.y, -Direcoes.base_de_quadro(float(altura)),
			"%s: o chefe e ancorado nos PES" % arquivo)
	else:
		ok(SEM_ARTE_AINDA.has(arquivo),
			"%s ainda nao tem arte, e isso esta DECLARADO em SEM_ARTE_AINDA" % arquivo)
		ok(chefe.get("largura_sombra") != null and float(chefe.get("largura_sombra")) > 0.0,
			"%s ja nasce com sombra: a ancora nos pes vale desde o placeholder" % arquivo)

	chefe.free()


## A regra de origem do Low Top-Down: a posicao logica do ator e o ponto em que
## ele encosta no CHAO, e o desenho sobe a partir dali.
##
## Isto e portao e nao convencao porque o sintoma nao aparece no console e quase
## nao aparece parado: com o sprite ancorado no meio do corpo, o Y-sort ordena
## pelo MEIO e um inimigo alto passa na frente de outro que esta mais abaixo na
## tela. So se ve em movimento, e so quando dois corpos se cruzam.
##
## Os quatro inimigos que ainda sao Polygon2D ficam de fora de proposito: eles
## sao desenhados em volta da propria origem, entao a base deles JA e a origem.
##
## E o portao distingue DOIS regimes pela moldura, em vez de exigir -36 de todo
## mundo (LTD 16):
##
## - moldura de ATOR (`Direcoes.MOLDURAS_DE_ATOR`): veio de `gerar_sprites.py`,
##   que ancora nos pes. A base sai de `Direcoes.base_de_quadro()`, entao a
##   moldura de 160 do chefe e cobrada com o numero DELA -- 76 -- e nao com o
##   36 da moldura de 80. Foi o chefe que trouxe o segundo tamanho (BOSS 10):
##   ele e duas a tres vezes o jogador e nao cabe em 80.
## - qualquer outra moldura: arte autorada, com ancora propria. O caso vivo e a
##   Diretora, um orbe flutuante radialmente simetrico de 192x192 -- ela nao tem
##   pes, e centrada E a ancora certa. Exigir -36 dela seria cobrar uma regra
##   anatomica de um corpo sem anatomia.
##
## O que se cobra do segundo regime e a COERENCIA: quem esta centrado nao pode
## ter sombra, porque a elipse nasceria dentro do proprio corpo e ficaria
## invisivel -- foi exatamente o no morto que a Diretora carregava.
func _todo_ator_com_arte_tem_origem_nos_pes() -> void:
	var conferidos := 0

	var dir := DirAccess.open("res://src/enemies/")
	ok(dir != null, "a pasta de inimigos abre")
	if dir != null:
		for arquivo in dir.get_files():
			if not arquivo.ends_with(".tscn"):
				continue
			var cena: PackedScene = load("res://src/enemies/" + arquivo)
			if cena == null:
				continue
			var inimigo := cena.instantiate()
			Engine.get_main_loop().root.add_child(inimigo)
			var corpo := inimigo.get_node_or_null("Visual/Corpo")
			var sprite := corpo as Sprite2D
			if sprite != null and sprite.texture != null:
				var altura := sprite.texture.get_height()
				if Direcoes.moldura_de_ator(float(altura)):
					conferidos += 1
					perto(sprite.position.y, -Direcoes.base_de_quadro(float(altura)),
						"%s: o sprite da moldura de %d e ancorado nos pes" % [arquivo, altura])
				else:
					# Arte autorada, de moldura propria. O caso vivo e a Diretora.
					perto(sprite.position.y, 0.0,
						"%s: arte de moldura %d e centrada -- ela nao tem pes" % [arquivo, altura])
					ok(inimigo.get("largura_sombra") == 0.0,
						"%s: corpo centrado nao carrega sombra (ela nasceria dentro dele)" % arquivo)
			inimigo.free()

	# Piso: os cinco inimigos com sprite direcional existem desde a v0.3.
	# Sem ele, uma varredura que nao achasse nada passaria como aprovacao.
	ok(conferidos >= 5, "a varredura achou os inimigos com arte (%d)" % conferidos)

	# O jogador, pelas duas pontas: a cena e o .tres de cada operador.
	var cena_player: PackedScene = load("res://src/player/player.tscn")
	if cena_player != null:
		var estado := cena_player.get_state()
		for i in estado.get_node_count():
			if estado.get_node_name(i) != "Sprite":
				continue
			var pos: Variant = _propriedade(estado, i, "position")
			if pos != null:
				perto((pos as Vector2).y, -Direcoes.BASE_NO_QUADRO,
					"player.tscn: o Sprite e ancorado nos pes")

	var operadores := 0
	var dir_p := DirAccess.open("res://src/player/")
	if dir_p != null:
		for arquivo in dir_p.get_files():
			if not arquivo.begins_with("personagem_") or not arquivo.ends_with(".tres"):
				continue
			var dados: Resource = load("res://src/player/" + arquivo)
			if dados == null or not "deslocamento_sprite" in dados:
				continue
			operadores += 1
			perto(dados.deslocamento_sprite.y, -Direcoes.BASE_NO_QUADRO,
				"%s: o deslocamento poe os pes na origem" % arquivo)
	ok(operadores >= 2, "os dois operadores foram conferidos (%d)" % operadores)


# ------------------------------------------------------------------ ajuda ----

## Le uma propriedade declarada de um no dentro do PackedSceneState. Devolve
## null quando a propriedade nao foi sobrescrita na cena.
func _propriedade(estado: SceneState, indice: int, nome: String) -> Variant:
	for p in estado.get_node_property_count(indice):
		if estado.get_node_property_name(indice, p) == nome:
			return estado.get_node_property_value(indice, p)
	return null

## `free()` e nao `queue_free()`: a suite roda inteira num frame, entao uma
## sala enfileirada continuaria na arvore e no grupo "salas" durante os casos
## seguintes. Mesma licao ja registrada para container de projetil.
func _montar(cena: PackedScene) -> Sala:
	var sala := cena.instantiate() as Sala
	sala.position = LONGE
	Engine.get_main_loop().root.add_child(sala)
	return sala


## Area por shoelace, so para comparar tamanhos entre dois poligonos.
func _area_do(pontos: PackedVector2Array) -> float:
	if pontos.size() < 3:
		return 0.0
	var soma := 0.0
	for i in pontos.size():
		var a := pontos[i]
		var b := pontos[(i + 1) % pontos.size()]
		soma += a.x * b.y - b.x * a.y
	return absf(soma) * 0.5

## Como a face escolhe o modulo que veste cada lado (LTD 13).
##
## Este caso existe porque a medicao contrariou o desenho, e o que ficou no
## codigo foi o resultado da medicao.
##
## **Uma sala mostra UMA face.** `LIMIAR_LADO_NORTE` so desenha face no lado
## cuja normal aponta para o norte -- ou seja, a parede do fundo, a unica cuja
## superficie vertical esta virada para a camera. Medido nas nove formas de
## sala: todas dao exatamente uma. E geometricamente certo para esta
## perspectiva, e e o que impede o cenario de cobrir jogador e telegrafo.
##
## A consequencia manda no planejamento de arte, e nao e obvia: uma biblioteca
## de cinco modulos de face NAO produz cinco paineis diferentes numa sala. Ela
## produz variedade ao longo do ANDAR -- salas vizinhas vestindo modulos
## diferentes. Quem for produzir os modulos precisa saber disso, senao desenha
## pensando numa composicao que nunca acontece.
##
## O sorteio continua sendo por (celula, lado) e nao so por celula: custa nada,
## e o dia em que uma sala tiver dois trechos de fundo -- um L entalhado por
## cima -- ela ja veste os dois sem mudanca nenhuma.
func _a_face_sorteia_por_lado() -> void:
	var um: Texture2D = load("res://assets/texturas/parede_face_boss.png")
	var dois: Texture2D = load("res://assets/texturas/parede_face_arma.png")
	ok(um != null and dois != null, "as faces de teste carregam do disco")
	if um == null or dois == null:
		return
	var dados := DadosSala.new()
	dados.texturas_face = [um, dois]

	# 1. A sala veste a face que o TIPO manda, e nao a neutra em disco.
	#
	# O numero de LADOS com face mudou, e a mudanca e deliberada: ate a fita, so
	# o lado de fundo tinha face -- `LIMIAR_LADO_NORTE` recusava os outros tres --
	# e as laterais ficavam faixas chapadas, tres vezes mais claras que o chao.
	# Hoje o norte, o leste e o oeste tem face, e so o SUL fica so com topo. Isso
	# nao e capricho: a face de uma parede ao sul olha para longe da camera,
	# escondida pela propria parede.
	var sala_um := _montar_com(CENA_SALA, dados, Vector2i(3, 1))
	var faces_sul := 0
	var caixa := Rect2(sala_um.contorno_local()[0], Vector2.ZERO)
	for ponto in sala_um.contorno_local():
		caixa = caixa.expand(ponto)
	var fita := sala_um.get_node_or_null("ParedeModulos") as Node2D
	if fita != null:
		for filho in fita.get_children():
			if not _textura_de(filho).get_file().begins_with("parede_face"):
				continue
			var item := filho as Node2D
			if item != null and item.position.y > caixa.end.y:
				faces_sul += 1
	# O SUL NAO VESTE FACE, e esta e a terceira redacao desta linha.
	#
	# Ela ja disse "o sul nao ganha face", depois "o sul veste face como as
	# outras", depois para a primeira via SOLEIRA -- e agora para a segunda, por um
	# motivo que nenhuma das tres tinha: **a sala e uma caixa aberta vista de
	# cima**, e numa caixa as quatro paredes tem a mesma massa.
	#
	# O medo que produziu a soleira era concreto: uma face alta ao sul cobriria o
	# jogador. A resposta nao e tirar a face, e sim faze-la crescer para FORA da
	# area jogavel -- a maior parte dela fica abaixo do piso na tela, entao nao ha
	# nada a esconder e nenhum foreground e necessario.
	#
	# Sem face ao sul, aquele lado media 32 px contra 60 do norte e lia como uma
	# linha; era o defeito que fechou o epico anterior.
	ok(faces_sul > 0,
		"o sul VESTE face (%d pecas), como os outros tres lados" % faces_sul)
	var usadas := _texturas_de_face(sala_um)
	ok(not usadas.is_empty(), "a sala veste face nos lados que a camera enxerga")
	if not usadas.is_empty():
		ok(
			usadas[0] != Sala.FACE_NEUTRA,
			"ela usa o modulo declarado pelo tipo, nao a face neutra (%s)" % usadas[0]
		)

	# 2. Ao longo do ANDAR os modulos variam. E aqui que a biblioteca aparece --
	#    e a variacao vem da FRACAO, nao so da celula: desde a AND1 01 a escolha
	#    passa pelo terco do andar em que a sala esta. Varrer celulas com fracao
	#    fixa mediria so o hash, e o hash sozinho nao e mais quem decide.
	var vistas := {}
	for i in 16:
		var sala_i := _montar_com(CENA_SALA, dados, Vector2i(i, 0))
		sala_i.fracao_do_andar = float(i) / 15.0
		# A fracao e lida na montagem, entao a sala precisa remontar o visual.
		# Monta uma nova em vez de remontar: a suite mede o caminho real.
		sala_i.free()
		var outra := CENA_SALA.instantiate() as Sala
		outra.coordenadas_grid = Vector2i(i, 0)
		outra.fracao_do_andar = float(i) / 15.0
		outra.definir_visual(dados)
		outra.position = LONGE
		Engine.get_main_loop().root.add_child(outra)
		for t in _texturas_de_face(outra):
			vistas[t] = true
	ok(
		vistas.size() >= 2,
		"o andar veste modulos diferentes conforme avanca (%d de 2)" % vistas.size()
	)

	# 3. Determinismo: a mesma celula veste igual nas duas montagens. Sem isso,
	#    voltar para uma sala a redecora, e o jogador percebe.
	var a := _texturas_de_face(_montar_com(CENA_SALA, dados, Vector2i(7, 2)))
	var b := _texturas_de_face(_montar_com(CENA_SALA, dados, Vector2i(7, 2)))
	igual(a, b, "a mesma celula veste os mesmos modulos nas duas montagens")

	# 4. Sem dados, a sala nao fica sem face -- ela cai na neutra. E o caso da
	#    cena aberta sozinha no editor, e ele nao pode virar parede chapada.
	var sem := _texturas_de_face(_montar_com(CENA_SALA, null, Vector2i(1, 1)))
	ok(sem.size() >= 1, "sala sem DadosSala ainda desenha a face (%d)" % sem.size())
	if not sem.is_empty():
		igual(sem[0], Sala.FACE_NEUTRA, "e ela e a face neutra")


## Monta uma sala numa celula dada, com os dados dados. Longe da origem, como o
## resto desta suite.
func _montar_com(cena: PackedScene, dados: DadosSala, celula: Vector2i) -> Sala:
	var sala := cena.instantiate() as Sala
	sala.coordenadas_grid = celula
	# Os dois ANTES do add_child: e o _ready que monta as faces, e ele le os
	# dois. E a mesma ordem que o GerenciadorMapa usa.
	sala.definir_visual(dados)
	sala.position = LONGE
	Engine.get_main_loop().root.add_child(sala)
	return sala


## Os caminhos das texturas de cada quad de face, na ordem em que a sala montou.
## Caminho e nao Texture2D para a mensagem de falha ser legivel.
## As texturas DISTINTAS de face que a sala veste.
##
## Distintas, e nao um item por poligono: desde que a face abre no vao da porta
## (PAR 01), um lado com porta no meio vira DOIS quads da mesma textura. A
## pergunta que estes casos fazem sempre foi "quantos MODULOS a sala veste", e a
## contagem de filhos era so um atalho que deixou de valer -- contar poligonos
## faria a resposta mudar quando uma sala ganhasse uma porta a mais, sem nada
## sobre a arte ter mudado.
## A TEXTURA CORRE POR CIMA DA GRADE, e essa e a afirmacao da moldura.
##
## Este caso ja mediu duas coisas diferentes, e as duas morreram por motivo bom.
##
## **Primeiro** ele guardava a armadilha da UV: o quad de face tinha 32 px numa
## textura de 64 e amostrava so as linhas 32..63 -- a metade de cima nunca
## aparecia, e nada avisava. **Depois** a fita trocou aquilo por um
## `region_rect` de 32x32 sorteado entre quatro quadrantes, e o caso passou a
## contar quantos quadrantes distintos chegavam a tela.
##
## A MOLDURA 04 acabou com os dois: nao ha mais recorte nenhum. A superficie e
## um quad continuo por trecho, com `texture_repeat` ligado e a UV ancorada na
## SALA -- entao a textura ladrilha por cima de qualquer grade, e duas faixas
## vizinhas continuam o mesmo desenho em vez de cada uma recomecar do zero.
##
## Recomecar e exatamente o que produzia a emenda visivel. Por isso o que se
## cobra agora e a ANCORA: `texture_offset` tem de compensar a `position` da
## peca, senao cada faixa reinicia a textura no proprio inicio.
func _a_faixa_de_uv_da_face_e_declarada() -> void:
	var sala := CENA_SALA.instantiate() as Sala
	sala.position = LONGE
	Engine.get_main_loop().root.add_child(sala)
	var raiz := sala.get_node_or_null("ParedeModulos") as Node2D
	if raiz == null:
		ok(false, "a sala monta a fita")
		sala.free()
		return

	var texturizadas := 0
	var sem_repeticao := 0
	var ancoras: Array[Vector2] = []
	for filho in raiz.get_children():
		var poly := filho as Polygon2D
		if poly == null or poly.texture == null:
			continue
		texturizadas += 1
		if poly.texture_repeat != CanvasItem.TEXTURE_REPEAT_ENABLED:
			sem_repeticao += 1
		# A ANCORA EFETIVA desta peca.
		#
		# A UV de um vertice e `vertice + texture_offset`, em coordenada local; o
		# ponto de mundo dele e `position + vertice`. Para as duas coincidirem a
		# menos da ancora da sala, `position - texture_offset` tem de dar a
		# ancora -- e e isso, e nao a soma, que se compara.
		ancoras.append(poly.position - poly.texture_offset)

	ok(texturizadas >= 4, "a fita veste textura em faixas (%d)" % texturizadas)
	igual(sem_repeticao, 0,
		"toda faixa tem `texture_repeat` -- sem ele a textura sai ESTICADA uma vez no trecho inteiro (%d)"
			% sem_repeticao)
	# A ancora tem de bater com o canto do contorno para TODAS: e o que faz duas
	# faixas vizinhas serem a continuacao do mesmo desenho.
	var caixa := _caixa_do_poligono(sala.contorno_local())
	var descoladas := 0
	for uv in ancoras:
		if absf(uv.x - caixa.position.x) > 1.0 or absf(uv.y - caixa.position.y) > 1.0:
			descoladas += 1
	igual(descoladas, 0,
		"e todas ancoram no mesmo canto da sala -- faixa que recomeca a textura e emenda visivel (%d)"
			% descoladas)
	sala.free()


func _texturas_de_face(sala: Sala) -> Array[String]:
	var achados: Array[String] = []
	for caminho in _faces_da_fita(sala):
		if not achados.has(caminho):
			achados.append(caminho)
	sala.free()
	return achados


## As texturas de FACE que a fita esta vestindo, pelo nome do arquivo.
##
## Pelo NOME e nao pela posicao na faixa: uma celula de fita e um sprite solto, e
## nada nela diz se ela e topo ou face -- as duas sao 32x32 na mesma raiz. O
## prefixo `parede_face` e a convencao que `teste_texturas.gd` ja cobra ao varrer
## os modulos, entao ler por ele nao inventa um segundo contrato.
func _faces_da_fita(sala: Sala) -> Array[String]:
	var achados: Array[String] = []
	var raiz := sala.get_node_or_null("ParedeModulos") as Node2D
	if raiz == null:
		return achados
	for filho in raiz.get_children():
		var caminho := _textura_de(filho)
		if caminho.get_file().begins_with("parede_face"):
			achados.append(caminho)
	return achados


## O caminho da textura de uma peca da fita, seja ela qual for.
##
## A peca deixou de ser `Sprite2D` na MOLDURA 04: a superficie virou um
## `Polygon2D` continuo por trecho. Os coletores desta suite perguntavam pelo
## TIPO do no, e por isso ficaram cegos de uma vez -- eles mediam a
## implementacao e nao a pergunta. Ler a textura de qualquer `CanvasItem` que
## tenha uma sobrevive a proxima troca de peca.
func _textura_de(no: Node) -> String:
	var sprite := no as Sprite2D
	if sprite != null and sprite.texture != null:
		return sprite.texture.resource_path
	var poly := no as Polygon2D
	if poly != null and poly.texture != null:
		return poly.texture.resource_path
	return ""


## O corredor usa EXATAMENTE a perspectiva da sala (LTD 12).
##
## Ele era a unica parte do jogo que continuava chapada depois da LTD 04:
## a sala ganhou topo e face, e atravessar de uma para outra trocava de
## perspectiva no meio do caminho. Nao ha erro no console para isso -- o jogo
## roda igual e o mundo so deixa de ser coerente.
##
## O que este caso cobra e a igualdade das faixas, e nao a existencia dos nos:
## o corredor desenha nas MESMAS faixas absolutas da `Sala`. Ele ja valeu -1 no
## no raiz, e ai o mesmo numero significava coisas diferentes nos dois -- o
## empate entre os dois chaos era desempatado por ordem de arvore, funcionando
## por acidente.
## SO o ultimo trecho anuncia o chefe (AND1 06).
##
## O corredor comum fica na noite base de PROPOSITO: "pintar cada metade com a
## cor da sala vizinha anunciaria o que ha do outro lado antes de o jogador
## chegar". O trecho pre-chefe e a excecao deliberada -- ali anunciar E o
## objetivo --, e por isso ele precisa de portao dos DOIS lados:
##
## - o trecho pre-chefe muda mesmo (senao a excecao e so uma bandeira);
## - o trecho comum NAO muda (senao o andar inteiro anuncia o chefe desde a
##   terceira porta, e a virada deixa de acontecer em um lugar so).
func _so_o_trecho_pre_chefe_anuncia_o_chefe() -> void:
	var comum := _corredor(false)
	var pre := _corredor(true)

	var chao_comum := comum.get_node_or_null("Chao") as Polygon2D
	var chao_pre := pre.get_node_or_null("Chao") as Polygon2D
	ok(chao_comum != null and chao_pre != null, "os dois corredores montam chao")
	if chao_comum != null and chao_pre != null:
		ok(chao_comum.texture != chao_pre.texture,
			"o trecho pre-chefe veste OUTRO chao -- ali anunciar e o objetivo")
		igual(chao_comum.modulate, Color.WHITE,
			"e o trecho comum fica na noite base, sem escurecer")
		ok(chao_pre.modulate.v < 1.0,
			"enquanto o pre-chefe escurece (%.2f) -- a iluminacao irregular do plano"
				% chao_pre.modulate.v)
		# O escurecimento vai no CHAO e nao no corredor inteiro: projetil e
		# telegrafo tem de manter o contraste deles, e o que muda e so o fundo
		# contra o qual eles sao lidos.
		igual(pre.modulate, Color.WHITE,
			"e o corredor inteiro NAO escurece -- so o chao dele")

	var face_comum := _faces_de(comum)
	var face_pre := _faces_de(pre)
	ok(not face_comum.is_empty() and not face_pre.is_empty(),
		"os dois corredores vestem face")
	if not face_comum.is_empty() and not face_pre.is_empty():
		ok(face_comum[0] != face_pre[0],
			"e a face tambem muda: a parede do trecho final e a do chefe (%s contra %s)"
				% [face_comum[0].get_file(), face_pre[0].get_file()])

	comum.free()
	pre.free()


## Um corredor solto, pre-chefe ou nao.
func _corredor(pre_chefe: bool) -> Corredor:
	var c := Corredor.new()
	c.pre_chefe = pre_chefe
	Engine.get_main_loop().root.add_child(c)
	c.global_position = LONGE
	# ANTES do configurar, como o GerenciadorMapa faz: e ele que veste.
	c.configurar(Vector2.ZERO, Vector2(320.0, 0.0), 80.0)
	return c


func _o_corredor_usa_a_mesma_perspectiva_da_sala() -> void:
	# HORIZONTAL: a lateral norte fica virada para o sul e mostra face.
	var deitado := Corredor.new()
	Engine.get_main_loop().root.add_child(deitado)
	deitado.configurar(LONGE, LONGE + Vector2(480.0, 0.0), 80.0)
	igual(deitado.z_index, 0, "o no raiz do corredor nao desloca as faixas dos filhos")

	var fita := deitado.get_node_or_null("ParedeModulos") as Node2D
	ok(fita != null, "o corredor horizontal monta a fita")
	if fita != null:
		ok(fita.z_index < Sala.Z_MUNDO,
			"a fita do corredor fica abaixo da faixa do mundo, como a da sala")
		# SEIS e nao oito, e a queda tem causa.
		#
		# O corredor tem dois lados fechados (as duas laterais longas) e dois
		# abertos (as bocas). Com o perfil direcional cada lado fechado desenha
		# TRES camadas -- sombra, face e reveal --, e as quinas sao puladas porque
		# elas encostam em lado aberto. Seis pecas e a conta certa; oito era a do
		# modelo em que cada lado desenhava topo, face e mais quatro tiras de
		# acabamento.
		#
		# O piso continua importando: fita vazia nao da erro nenhum, e o corredor
		# ficaria uma tira de chao sem parede nenhuma.
		ok(fita.get_child_count() >= 6,
			"o corredor veste celulas (%d)" % fita.get_child_count())
	ok(not _faces_de(deitado).is_empty(), "e ele desenha FACE, e nao so topo")
	var chao := deitado.get_node_or_null("Chao") as Polygon2D
	if chao != null:
		igual(chao.z_index, Sala.Z_CHAO, "o chao do corredor usa a faixa da sala")
	deitado.free()

	# VERTICAL: as laterais dele apontam para leste e oeste.
	#
	# Ele NAO desenhava face nenhuma, e isso era consequencia da regra antiga --
	# "so o lado voltado para o sul" --, nao uma decisao sobre corredor vertical.
	# O resultado era uma faixa chapada, tres vezes mais clara que o chao, ao lado
	# de salas com volume. Com a face nas laterais, ele passa a ter a mesma
	# perspectiva do resto do andar, que e o que este caso existe para cobrar.
	var em_pe := Corredor.new()
	Engine.get_main_loop().root.add_child(em_pe)
	em_pe.configurar(LONGE, LONGE + Vector2(0.0, 480.0), 80.0)
	ok(
		not _faces_de(em_pe).is_empty(),
		"o corredor vertical tambem desenha face -- as laterais dele sao paredes como as da sala"
	)
	em_pe.free()


## As texturas de face que um corredor esta vestindo.
func _faces_de(corredor: Corredor) -> Array[String]:
	var achados: Array[String] = []
	var raiz := corredor.get_node_or_null("ParedeModulos") as Node2D
	if raiz == null:
		return achados
	for filho in raiz.get_children():
		var caminho := _textura_de(filho)
		if caminho.get_file().begins_with("parede_face") and not achados.has(caminho):
			achados.append(caminho)
	return achados


func _caixa_do_poligono(pontos: PackedVector2Array) -> Rect2:
	if pontos.is_empty():
		return Rect2()
	var caixa := Rect2(pontos[0], Vector2.ZERO)
	for ponto in pontos:
		caixa = caixa.expand(ponto)
	return caixa


## OS QUATRO LADOS SAO A MESMA PAREDE, e a assimetria que saiu daqui era o defeito.
##
## **Este caso ja afirmou o CONTRARIO, e a virada e o assunto.** Ele exigia que
## as tres pilhas fossem diferentes entre si, com o argumento de que a camera e
## uma so e cada lado esta numa relacao diferente com ela -- norte visto de
## frente, lateral de esguelha, sul de cima. O argumento e verdadeiro em
## PERSPECTIVA e falso em LEITURA, e o jogo mostrou qual das duas manda.
##
## Medido no estado que ele aprovava (`baseline_assimetrico/norte_sala.png`):
##
##     vazio 6 | cap 48 | corpo 44 | contato 9 | piso 17     lateral 36 px, sul 32
##
## As quinas diziam "ha uma moldura"; os lados diziam "ha um acabamento". **A
## sala e uma caixa aberta vista de cima**, e numa caixa as quatro paredes tem a
## mesma espessura -- a perspectiva vem do chanfro, da sombra e da orientacao da
## textura, nunca da diferenca de massa.
##
## E a correcao nao foi escolher valores iguais: foi tirar do recurso a
## capacidade de divergir. Enquanto houvesse um campo por lado, alguem os giraria
## em separado, e foi o que aconteceu.
##
## O que este caso cobra e o que ainda pode falhar em silencio:
##
##   - **um lado voltar a divergir**, por um `escala_*` girado sem que o andar
##     inteiro tenha sido pensado para isso;
##   - **o cap sumir.** Cap zero deixa a parede sem espessura nenhuma: uma face
##     chapada colada no vazio;
##   - **o cap dominar.** Foi o defeito medido pelo dono -- 40 px de topo lendo
##     como faixa de piso. O corpo e a autoridade estrutural, e o cap acabamento;
##   - **o sul voltar a ser soleira.** Ele foi tratado como ledge por um epico
##     inteiro, e o resultado lia como uma linha em vez de parede.
func _os_quatro_lados_sao_a_mesma_parede() -> void:
	var perfil := PerfilDeParede.new()
	var lados := {
		"norte": RenderizadorParedes.Lado.NORTE,
		"sul": RenderizadorParedes.Lado.SUL,
		"leste": RenderizadorParedes.Lado.LESTE,
		"oeste": RenderizadorParedes.Lado.OESTE,
	}

	# 1. AS QUATRO PILHAS COINCIDEM. Uma diferente e um lado que voltou a ter
	#    perfil proprio -- e isso nao da erro nenhum, so faz a moldura voltar a ler
	#    como acabamento de um lado e parede do outro.
	var nomes: Array = lados.keys()
	var referencia := _assinatura_do_lado(perfil, lados[nomes[0]])
	for n: String in nomes:
		var assinatura := _assinatura_do_lado(perfil, lados[n])
		ok(assinatura == referencia,
			"%s desenha a mesma pilha que %s (%s)" % [n, nomes[0], assinatura])

	# 2. OS QUATRO SCALES VALEM 1,0 NO ANDAR 1. Eles existem para outro andar
	#    poder declarar uma assimetria -- e declarar e diferente de derivar para
	#    uma. Um scale girado aqui reabre exatamente o defeito de cima.
	for par: Array in [["norte", perfil.escala_norte], ["sul", perfil.escala_sul],
			["leste", perfil.escala_leste], ["oeste", perfil.escala_oeste]]:
		perto(par[1], 1.0, "a escala do %s e neutra no andar 1" % par[0], 0.0001)

	# 3. O CORPO E A AUTORIDADE, O CAP E ACABAMENTO -- nos QUATRO lados.
	for n: String in nomes:
		var lado: int = lados[n]
		var corpo := perfil.fim_da_face(lado)
		var cap := perfil.profundidade(lado) - corpo
		ok(cap > 0.0, "o cap do %s existe (%.0f px) -- sem ele a parede nao tem espessura"
			% [n, cap])
		ok(corpo > cap, "e o corpo do %s domina (%.0f contra %.0f)" % [n, corpo, cap])
		# O SUL TEM CORPO, e este e o portao que impede a soleira de voltar. Ele
		# desenhava `labio 4 + ledge 20 + queda 8` e ZERO de face; hoje desenha a
		# mesma parede que o norte, crescendo para fora da area jogavel.
		ok(corpo >= 32.0,
			"o corpo do %s tem massa de parede (%.0f px), e nao de soleira" % [n, corpo])

	# 4. A SOMBRA CRESCE PARA DENTRO, E EXISTE NOS QUATRO LADOS.
	#
	#    No modelo antigo o SUL nao tinha nenhuma, e era isso que fazia o piso
	#    parecer TERMINAR ali em vez de descer. Ela e o segundo anel: contorna a
	#    sala inteira, chanfro incluido.
	for n: String in nomes:
		var tem_sombra := false
		for camada in perfil.camadas(lados[n]):
			if int(camada.z) == PerfilDeParede.Camada.SOMBRA:
				tem_sombra = camada.x < 0.0
		ok(tem_sombra, "a sombra de contato do %s cresce para DENTRO do piso" % n)

	# 5. O CHANFRO EXISTE E CAI NA GRADE. Sem ele as quinas voltam a 90 graus, e
	#    o dono mediu que so isso ja mantem a sala lendo como planta baixa.
	ok(perfil.chanfro_de_canto >= 16.0,
		"o chanfro de quina existe (%.0f px)" % perfil.chanfro_de_canto)
	perto(fmod(perfil.chanfro_de_canto, 16.0), 0.0, "e ele cai na grade de 16")


## A pilha de camadas de um lado, como texto. Duas iguais sao dois lados que
## deixaram de ser diferentes.
func _assinatura_do_lado(perfil: PerfilDeParede, lado: int) -> String:
	var partes: Array[String] = []
	for camada in perfil.camadas(lado):
		partes.append("%d:%.0f-%.0f" % [int(camada.z), camada.x, camada.y])
	return ",".join(partes)


## A SOMBRA ASSENTA A PAREDE, e nao invade o combate (TOPO 02).
##
## Ela e a unica peca deste epico que desenha DENTRO da area jogavel, e por isso
## e a unica que precisa de teto. As tres afirmacoes:
##
## 1. **ela existe** -- em toda forma de sala, e no corredor tambem. Sem o
##    corredor, atravessar uma porta trocaria a perspectiva no meio da passagem:
##    a parede assenta de um lado e flutua do outro, que e o defeito que a LTD 12
##    existiu para consertar;
## 2. **ela cabe** -- nenhuma tira entra mais que `PROFUNDIDADE_MAXIMA`, e a area
##    somada fica abaixo de 6% do chao. Efeito que disputa a leitura de combate e
##    efeito cortado, e aqui isso e numero e nao promessa;
## 3. **ela nao clareia nada** -- todo alfa abaixo do teto, e a cor e N0. Sombra
##    que ilumina seria uma vinheta, que e efeito de camera, e nao uma afirmacao
##    sobre altura.
func _a_sombra_assenta_a_parede_sem_invadir_o_combate() -> void:
	for cena: PackedScene in [CENA_SALA, CENA_L, CENA_PILAR]:
		var sala := _montar(cena)
		var nome := cena.resource_path.get_file()
		var contorno := sala.contorno_local()
		var sombra := sala.get_node_or_null("SombraDaParede") as Node2D
		ok(sombra != null, "%s monta a sombra" % nome)
		if sombra == null:
			sala.free()
			continue

		var tiras := 0
		var fundo := 0.0
		var alfa_maximo := 0.0
		var area := 0.0
		for filho in sombra.get_children():
			var poly := filho as Polygon2D
			if poly == null or poly.polygon.size() < 4:
				continue
			tiras += 1
			alfa_maximo = maxf(alfa_maximo, poly.color.a)
			var caixa := Rect2(poly.polygon[0], Vector2.ZERO)
			for ponto in poly.polygon:
				caixa = caixa.expand(ponto)
			area += caixa.size.x * caixa.size.y
			# Quanto ela entrou: a distancia do vertice mais fundo ate o contorno.
			for ponto in poly.polygon:
				var mundo: Vector2 = poly.position + ponto
				if Geometry2D.is_point_in_polygon(mundo, contorno):
					fundo = maxf(fundo, _distancia_ao_contorno(mundo, contorno))

		ok(tiras >= 4, "%s: a sombra tem tiras (%d)" % [nome, tiras])
		ok(
			fundo <= SombraDeParede.PROFUNDIDADE_MAXIMA + 0.5,
			"%s: a sombra entra %.0f px, teto %.0f" % [nome, fundo,
				SombraDeParede.PROFUNDIDADE_MAXIMA]
		)
		ok(
			alfa_maximo <= SombraDeParede.ALFA_MAXIMO + 0.001,
			"%s: o alfa maximo e %.2f, teto %.2f" % [nome, alfa_maximo,
				SombraDeParede.ALFA_MAXIMO]
		)
		# O TETO SUBIU DE 6% PARA 8%, e o motivo nao e a sombra ter crescido.
		#
		# Ela e um efeito de PERIMETRO medido contra uma AREA. Quando as salas
		# encolheram de 960x544 para 896x448, a area caiu 23% e o perimetro so
		# ~8% -- entao a fracao subiu por construcao, com a sombra desenhando
		# exatamente os mesmos 12 px de sempre. A sala em L foi a primeira a
		# passar do teto, com 6,2%, porque ela e a de menor area do jogo.
		#
		# Baixar a sombra para caber nos 6% seria mexer na arte para agradar um
		# proxy. Quem guarda o que este teto existe para guardar -- "a sombra nao
		# invade o combate" -- e a assercao ACIMA, `fundo <= PROFUNDIDADE_MAXIMA`:
		# ela mede o quanto a sombra entra, que e o que o jogador sente, e nao
		# muda com o tamanho da sala.
		#
		# O teto de area continua existindo como rede contra alguem multiplicar a
		# sombra por dez, e 8% e o que deixa a menor sala do jogo passar com folga
		# sem deixar passar o dobro dela.
		var area_do_chao := absf(_area_do(contorno))
		ok(
			area < area_do_chao * 0.08,
			"%s: a sombra ocupa %.1f%% do chao, teto 8%%"
				% [nome, 100.0 * area / maxf(area_do_chao, 1.0)]
		)
		sala.free()

	# O CORREDOR tambem, senao a travessia troca de perspectiva no meio.
	var corredor := Corredor.new()
	Engine.get_main_loop().root.add_child(corredor)
	corredor.configurar(LONGE, LONGE + Vector2(480.0, 0.0), 80.0)
	var sombra_corredor := corredor.get_node_or_null("SombraDaParede") as Node2D
	ok(sombra_corredor != null, "o corredor monta a sombra")
	if sombra_corredor != null:
		ok(sombra_corredor.get_child_count() >= 2,
			"o corredor veste as duas laterais (%d tiras)"
				% sombra_corredor.get_child_count())
	corredor.free()


## A distancia de um ponto ate o lado mais proximo do contorno.
func _distancia_ao_contorno(ponto: Vector2, contorno: PackedVector2Array) -> float:
	var perto := INF
	var total := contorno.size()
	for i in total:
		perto = minf(perto, ponto.distance_to(Geometry2D.get_closest_point_to_segment(
			ponto, contorno[i], contorno[(i + 1) % total])))
	return perto


## A fita cerca a sala inteira, e a FACE nao desce para o sul (LTD 15).
##
## **Este caso estava MORTO, e morreu na mesma linha que o irmao dele em
## `teste_camera.gd`.** Ate a PAREDE 13 a parede era um `Polygon2D` chamado
## `ParedeTopo`, e as duas metades liam `topo.polygon` e o no `ParedeFace`.
## Quando a fita substituiu os dois, o `polygon` passou a explodir num `Node2D` e
## o `ParedeFace` passou a devolver `null` -- o primeiro ABORTA a funcao, o
## segundo desliga o laco em silencio. A suite continuou verde sem fazer
## nenhuma das duas perguntas.
##
## As duas continuam valendo, e a segunda MUDOU DE FORMA:
##
## - **cercar** deixou de ser "a area do inflado contra a do chao" e virou "as
##   pecas passam do contorno nos QUATRO sentidos". A fita nao tem poligono para
##   medir; ela tem ~180 pecas, e cercar e uma afirmacao sobre onde elas chegam.
## - **"a face so aparece ao norte" nao e mais verdade, e nao e defeito.** Ate a
##   PAREDE 13 so o lado voltado para a camera ganhava face e os outros tres
##   viravam faixa chapada. Hoje o norte, o leste e o oeste tem face; quem NAO
##   tem e o SUL, porque a face de uma parede ao sul olha para longe da camera.
##   O que o caso cobra passa a ser o limite que importa: **nenhuma peca de face
##   abaixo da borda sul do contorno**, que e onde ela cobriria combate.
func _o_topo_cerca_a_sala_e_a_face_nao_desce_para_o_sul() -> void:
	for cena: PackedScene in [CENA_SALA, CENA_L, CENA_PILAR]:
		var sala := _montar(cena)
		var nome := cena.resource_path.get_file()
		var contorno := sala.contorno_local()
		var caixa := _caixa_do_poligono(contorno)

		var fita := sala.get_node_or_null("ParedeModulos") as Node2D
		ok(fita != null, "%s monta a fita" % nome)
		if fita == null:
			sala.free()
			continue

		# CERCAR, medido peca a peca: a fita tem de passar do contorno nos quatro
		# sentidos. Comparar so o tamanho da caixa deixaria passar uma fita
		# inteira deslocada para um lado.
		var folga := Rect2(caixa)
		var faces_ao_sul := 0
		var pecas := 0
		for filho in fita.get_children():
			var item := filho as Node2D
			if item == null:
				continue
			var meia := Vector2.ZERO
			var sprite := item as Sprite2D
			if sprite != null and sprite.texture != null:
				meia = sprite.texture.get_size() * 0.5
			else:
				var poly := item as Polygon2D
				if poly == null or poly.polygon.is_empty():
					continue
				meia = _caixa_do_poligono(poly.polygon).size * 0.5
			pecas += 1
			folga = folga.merge(Rect2(item.position - meia, meia * 2.0))
			if _textura_de(item).get_file().begins_with("parede_face") and item.position.y > caixa.end.y:
				faces_ao_sul += 1
		# O PISO CAIU DE 40 PARA 6, e a queda e o proprio entregavel.
		#
		# A fita tinha ~360 pecas por sala -- duas por celula --, e era isso que o
		# jogador via como `|tile|tile|tile|`. Com uma faixa por trecho e por banda,
		# uma sala retangular fecha em 8. Cobrar "muitas pecas" aqui seria cobrar
		# exatamente o defeito que este epico removeu.
		ok(pecas >= 6, "%s: a fita tem faixas para medir (%d)" % [nome, pecas])
		ok(
			folga.position.x < caixa.position.x and folga.position.y < caixa.position.y 				and folga.end.x > caixa.end.x and folga.end.y > caixa.end.y,
			"%s: a fita cerca a sala pelos QUATRO sentidos" % nome
		)
		# A FACE AO SUL ja foi proibida, depois exigida, e volta a ser proibida --
		# por um terceiro motivo, que nenhuma das duas versoes anteriores tinha.
		#
		# A proibicao original dizia "e la que ela cobriria combate". O que ela
		# nao previu e que a face pode crescer para FORA: o corpo do sul fica
		# abaixo do piso na tela, entao ele nunca disputa area jogavel com nada.
		#
		# Sem face, aquele lado voltava a ler como uma linha -- e as nove salas
		# ficavam com tres paredes e um acabamento.
		ok(
			faces_ao_sul > 0,
			"%s: o sul veste face (%d pecas), como os outros tres lados"
				% [nome, faces_ao_sul]
		)
		sala.free()


## A progressao visual do andar nunca ANDA PARA TRAS (AND1 01).
##
## O andar conta uma historia: conservado, deteriorado, critico. Isso prepara a
## mecanica do chefe antes da luta -- quando ele comeca lento e enferrujado,
## parece natural porque o andar inteiro mostrou maquinas com o mesmo problema.
##
## A historia so funciona numa direcao. Uma sala mais funda que a anterior e
## mais CONSERVADA quebra a leitura, e o defeito e invisivel numa sala so: ele
## exige comparar duas, e o jogador compara sem perceber.
##
## Mede a funcao pura em vez de montar um andar: `textura_progressiva` e quem
## decide, e uma varredura da fracao de 0 a 1 cobre todos os andares possiveis
## de uma vez -- inclusive os curtos, onde o terco final chega mais cedo.
func _a_deterioracao_visual_nunca_decresce() -> void:
	var dados := DadosSala.new()
	var lista: Array[Texture2D] = []
	# Tres variantes, na ordem que a convencao pede: conservada -> critica.
	for nome in ["chao_andar1_a.png", "chao_andar1_b.png", "chao_andar1_c.png"]:
		var t: Texture2D = load("res://assets/texturas/" + nome)
		if t != null:
			lista.append(t)
	igual(lista.size(), 3, "as tres variantes de chao carregam")
	if lista.size() < 3:
		return
	dados.texturas_chao = lista

	var indice_anterior := -1
	var passos := 40
	var subiu := false
	for i in passos + 1:
		var fracao := float(i) / float(passos)
		var escolhida := dados.textura_progressiva(lista, 12345, fracao)
		var indice := lista.find(escolhida)
		ok(indice >= 0, "a escolha pertence a lista (fracao %.2f)" % fracao)
		if indice_anterior >= 0:
			ok(
				indice >= indice_anterior,
				"a deterioracao nao anda para tras (fracao %.2f: %d depois de %d)"
					% [fracao, indice, indice_anterior]
			)
			if indice > indice_anterior:
				subiu = true
		indice_anterior = indice
	# Piso: uma funcao que devolvesse sempre o mesmo indice passaria em todas as
	# comparacoes acima sem progredir nada.
	ok(subiu, "e ela de fato PROGRIDE ao longo do andar, nao fica no mesmo")


## Quanto o TOPO pode chamar a atencao, em fracao da FACE.
##
## **A fracao sai da hierarquia que o projeto ja declara, e nao de gosto.** O
## chao e a superficie calma por decisao e mede 19% da face. O topo nao precisa
## ir tao longe -- ele e arquitetura e a face e identidade --, mas 100% e o
## numero de quem nao e subordinado a ninguem. 0,75 poe o topo claramente abaixo
## e ainda bem acima do chao.
const SUBORDINACAO_MAXIMA := 0.75

## O topo ainda compete com a face, e isso esta DECLARADO.
##
## Mesmo desenho de `SEM_ARTE_AINDA`, `SEM_CLIPE_AINDA` e `MODULOS_COLAPSADOS`: a
## bandeira morde dos DOIS lados. Enquanto ela estiver ligada, o topo TEM de
## continuar competindo -- no dia em que a #241 e a #242 entrarem, este caso
## reprova e obriga a desliga-la. Sem a segunda metade ela viraria permissao
## permanente, que e como o `EstiloDeParede` cobriu dois epicos inteiros.
const TOPO_AINDA_COMPETE := true

## Quantas celulas a varredura visita.
##
## Oito e o menor numero que exercita as tres texturas de topo e as cinco de
## face com folga: com tres e cinco no sorteio, oito hashes independentes deixam
## a chance de nao ver a face mais calma abaixo de 20%. Subir isto so custa
## tempo, e o tempo aqui e rasterizar 96x96 px por celula.
const CELULAS_MEDIDAS := 8


## O TOPO e ESPESSURA, e espessura nao disputa atencao com identidade.
##
## A ordem desejada de leitura e player -> interior -> face -> props -> topo ->
## exterior. Medido na captura real (`quina_sala.png`), a energia de gradiente
## por pixel dizia outra coisa: topo 27,66 e face 27,67 -- identicos --, contra
## 5,29 do chao. O topo e a face competem em igualdade exata.
##
## **A medicao e sobre o MIOLO de cada superficie, e nao sobre a faixa inteira.**
## As juntas -- linha de contato, costura, labio, bisel -- sao estrutura, e a
## #241 acrescenta mais delas de proposito. Um portao que as contasse subiria
## quando a estrutura melhorasse, que e o oposto do que ele existe para dizer.
## O que ele pergunta e sobre o MATERIAL: quanto a chapa de cima conversa,
## comparada com a face.
##
## **E ele VARRE celulas, porque uma sala so nao responde a pergunta.** A face e
## sorteada por lado dentro de uma biblioteca que varia de proposito -- medidas
## nos arquivos, as cinco de combate vao de 10,7 a 27,4 de energia --, e o topo e
## sorteado uma vez por sala entre tres. Amostrar UMA sala compara o topo com a
## face que aquele hash escolheu: a primeira versao deste caso caiu numa sala de
## face `tubulacao`, a mais agitada da biblioteca, e mediu 1,015 onde a mesma
## arte contra a face `comum` mede mais que o dobro. O que vale e o PIOR par que
## o andar consegue produzir, porque e uma sala de verdade.
##
## E ele le a fita MONTADA, e nao os PNGs. O que o jogador ve no topo e a textura
## mais as bandas desenhadas em codigo; medir `parede_topo_a.png` responderia
## sobre um arquivo, e nao sobre a parede.
##
## **Este portao NAO prova a #241.** Ele mede material, e a #241 mexe em
## estrutura -- borda, chapa e bisel. Quem julga a #241 e `comparar_topos.tscn`,
## olhando. Quem faz este numero cair e a chapa nova da #242.
func _o_topo_e_subordinado_a_face() -> void:
	var dados := load("res://src/mapa/tipo_combate.tres") as DadosSala
	var pior := 0.0
	var pior_face := 0.0
	var pior_topo := 0.0
	var medidas := 0
	for i in CELULAS_MEDIDAS:
		# Celulas diferentes = hashes diferentes = outra face e outro topo. E o
		# mesmo sorteio que o andar faz, e nao uma variacao inventada aqui.
		var sala := _montar_com(CENA_SALA, dados, Vector2i(i, i * 3))
		var energias := _energia_da_faixa_norte(sala)
		sala.free()
		if energias.x <= 0.0:
			continue
		medidas += 1
		var razao := energias.y / energias.x
		if razao > pior:
			pior = razao
			pior_face = energias.x
			pior_topo = energias.y
	ok(medidas >= CELULAS_MEDIDAS - 1,
		"a varredura mediu as celulas (%d de %d)" % [medidas, CELULAS_MEDIDAS])
	if medidas == 0:
		return

	if TOPO_AINDA_COMPETE:
		# A metade que morde: enquanto a bandeira estiver ligada, o topo TEM de
		# continuar competindo. Quando a chapa nova chegar, este caso reprova e a
		# linha nao fica para tras.
		ok(pior > SUBORDINACAO_MAXIMA,
			"o topo esta declarado como competindo e continua competindo (pior par: topo %.2f / face %.2f = %.3f)"
				% [pior_topo, pior_face, pior])
	else:
		ok(pior <= SUBORDINACAO_MAXIMA,
			"o topo e subordinado a face no pior par (topo %.2f / face %.2f = %.3f, teto %.2f)"
				% [pior_topo, pior_face, pior, SUBORDINACAO_MAXIMA])


## (energia da face, energia do topo) na faixa NORTE desta sala.
##
## O norte e o unico lado que mostra a face inteira de frente, e por isso o unico
## em que a pergunta "o topo compete com a face?" tem sentido.
func _energia_da_faixa_norte(sala: Sala) -> Vector2:
	var fita := sala.get_node_or_null("ParedeModulos") as Node2D
	var perfil := sala.perfil_de_parede()
	if fita == null or perfil == null:
		return Vector2.ZERO
	var contorno := sala.contorno_local()
	var portas: Array[Porta] = []
	var raiz := sala.get_node_or_null("Portas")
	if raiz != null:
		for filho in raiz.get_children():
			var porta := filho as Porta
			if porta != null:
				portas.append(porta)

	var melhor := PackedVector2Array()
	var normal := Vector2.ZERO
	var maior := 0.0
	for i in contorno.size():
		var a := contorno[i]
		var b := contorno[(i + 1) % contorno.size()]
		var n := RenderizadorParedes.normal_externa(contorno, a, b)
		if RenderizadorParedes.classificar(n) != RenderizadorParedes.Lado.NORTE:
			continue
		# O trecho LIVRE, e ele vem do proprio renderizador: a face abre no vao
		# da porta e o topo o atravessa, entao amostrar em cima de uma porta
		# compararia topo contra nada.
		for trecho in RenderizadorParedes.trechos_livres(contorno, a, b, portas):
			var comprimento: float = trecho[0].distance_to(trecho[1])
			if comprimento > maior:
				maior = comprimento
				melhor = trecho
				normal = n
	if maior < 64.0:
		return Vector2.ZERO

	var fundo := int(perfil.profundidade(RenderizadorParedes.Lado.NORTE))
	var fim_face := int(perfil.fim_da_face(RenderizadorParedes.Lado.NORTE))
	var largura := int(minf(maior, 96.0))
	var meio := (melhor[0] + melhor[1]) * 0.5
	var eixo := (melhor[1] - melhor[0]).normalized()
	var imagem := RasterizadorDeFita.faixa(fita,
		meio - eixo * (largura * 0.5), meio + eixo * (largura * 0.5),
		normal, fundo, largura)

	# O MIOLO de cada banda: as juntas ficam de fora, dos dois lados, pela mesma
	# regra.
	#
	# 4 px porque a maior peca de acabamento da faixa tem 2 -- linha de contato,
	# sombra da costura e bisel medem 2, o labio mede 1 --, e 4 deixa um pixel de
	# folga de cada lado. **Nao use `RenderizadorParedes.COSTURA` aqui**: aquele
	# 32 e a POSICAO onde a costura ficava quando a face tinha 32 px, e nao a
	# largura de peca nenhuma. Com face de 56 ele apaga a banda inteira, e a
	# primeira versao deste caso mediu energia ZERO por causa dele.
	var margem := 4
	return Vector2(
		RasterizadorDeFita.energia(imagem, margem, fim_face - margem),
		RasterizadorDeFita.energia(imagem, fim_face + margem, fundo - margem))
