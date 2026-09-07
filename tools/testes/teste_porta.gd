extends TesteBase
## A porta como SOLIDO: quem bloqueia, quando, e onde.
##
## Esta suite nasceu de um defeito que ninguem via e todo mundo sentia: a porta
## SELADA -- a do lado da sala que nao tem vizinho -- continuava ligando a
## propria barreira. E a barreira nao fica no mesmo lugar que a parede.
##
## A parede gerada por `Sala._montar_paredes()` e um `SegmentShape2D` sobre a
## linha do contorno, sem espessura. A barreira da porta e um retangulo de 80x32
## CENTRADO nessa linha. Metade dele -- 16 px -- caia DENTRO da area jogavel.
## Resultado: uma laje invisivel de 80x16 encostada na parede, em todo lado de
## sala sem vizinho, e o jogador esbarrando em nada.
##
## Nao ha erro no console para colisao a mais, e o teste de fumaca nao pega:
## ele nunca tenta encostar na parede. Por isso a trava e aqui.
##
## A pergunta que a suite faz de cada estado e sempre a mesma: **este estado
## precisa de um solido proprio, ou ja existe um solido ali?**

const CENA_PORTA := preload("res://src/mapa/porta.tscn")
const CENA_SALA := preload("res://src/mapa/sala_1_retangular.tscn")

const CAMINHO_BARREIRA := "Barreira/Colisao"

## Longe da origem, como as outras suites que sobem nos: sobras de outras
## suites ficam quase todas perto de (0,0).
const LONGE := Vector2(15000, 15000)


func nome() -> String:
	return "Porta"


func executar() -> void:
	await _cada_estado_e_seu_solido()
	await _sala_sem_vizinho_nao_deixa_solido_sobrando()
	await _a_abertura_nao_cobra_pedagio()
	await _a_folha_parte_em_vez_de_achatar()
	await _a_travessia_e_decidida_na_saida()
	_o_recesso_cobre_o_vao_da_moldura()
	_a_folha_cobre_o_vao_da_moldura()
	await _o_giro_da_porta_concorda_com_a_direcao()
	await _a_moldura_de_cada_lado_abre_no_vao()
	_toda_moldura_CERCA_o_vao()
	_a_moldura_e_mais_escura_que_a_parede()
	await _a_face_abre_no_vao_da_porta()
	_a_FACE_nao_e_mais_funda_que_a_moldura()


## A ANIMACAO DE ABERTURA e leitura, e nao pedagio (AND1 05).
##
## Duas coisas se cobram, e as duas sao sobre o mesmo risco: o jogador atravessa
## dez salas por andar, num jogo cujo sistema-assinatura e uma barra que sobe com
## o TEMPO.
##
## 1. **A BARREIRA CAI NO PRIMEIRO QUADRO**, e nao no fim da animacao. Se a
##    passagem so liberasse ao terminar, cada porta cobraria a propria duracao em
##    toda travessia -- meio segundo por porta sao cinco segundos parados por
##    run. Quem quer correr atravessa ja; quem olha, ve a maquina velha pegando.
## 2. **A duracao tem TETO, e ele e const e nao `@export`.** E limite de design e
##    nao botao de tuning: um numero ajustavel aqui seria ajustado para cima na
##    primeira vez que alguem achasse a animacao bonita.
func _a_abertura_nao_cobra_pedagio() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)
	var porta := _porta_solta(raiz)
	ok(porta.TEMPO_DE_ABERTURA <= porta.TEMPO_MAXIMO_DE_ABERTURA,
		"a abertura cabe no teto (%.2f s de %.2f)"
			% [porta.TEMPO_DE_ABERTURA, porta.TEMPO_MAXIMO_DE_ABERTURA])
	ok(porta.TEMPO_MAXIMO_DE_ABERTURA <= 0.6,
		"e o teto e curto: dez portas por andar transformam meio segundo em cinco")

	# A barreira cai ANTES de a animacao terminar -- de fato, no mesmo frame.
	porta.trancar()
	var colisao := porta.get_node_or_null("Barreira/Colisao") as CollisionShape2D
	ok(colisao != null, "a porta tem barreira")
	await Engine.get_main_loop().physics_frame
	ok(not colisao.disabled, "trancada, ela bloqueia (pre-condicao)")

	porta.abrir()
	await Engine.get_main_loop().physics_frame
	ok(colisao.disabled,
		"aberta, a passagem libera no MESMO frame -- a animacao nao e pedagio")
	igual(porta.estado, porta.Estado.ABERTA, "e o estado ja e ABERTA desde o inicio dela")

	# A FOLHA -- a chapa que o jogador le num quadro so -- some ao fim da
	# encenacao, e nao antes: e a unica chance de mostrar a porta abrindo.
	var folha := porta.get_node_or_null("FolhaA") as Sprite2D
	ok(folha != null, "a porta tem folha")
	if folha != null:
		ok(folha.visible, "e ela ainda esta em tela enquanto a porta abre")

	raiz.free()


## A FOLHA PARTE, E NAO ACHATA (PORTA 02).
##
## O que existia aqui antes nao era uma abertura: `_encenar_abertura()` levava a
## `scale` do campo de forca a `(1.0, 0.02)`. Numa grade de listras aquilo
## passava como "o campo recolheu"; numa CHAPA metalica -- que e o que a porta e
## desde a PORTA 01 -- e a porta sendo esmagada, e nao aberta.
##
## Tres coisas se cobram, e as tres sao geometria e nao gosto:
##
## 1. **A escala nunca sai de 1.** Deformar o desenho e o defeito, entao o teste
##    e sobre `scale` e nao sobre "parece bom".
## 2. **Cada metade recolhe o proprio tamanho.** Meia folha some por inteiro,
##    sem sobrar um fio dela no meio do vao.
## 3. **O recuo cabe atras do BATENTE**, medido no alfa da moldura autorada e
##    nao escrito a mao. Quem esconde a folha e a moldura, como numa porta de
##    verdade -- um `visible = false` no meio do vao seria a folha evaporando.
func _a_folha_parte_em_vez_de_achatar() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)
	var porta := _porta_solta(raiz)
	var a := porta.get_node_or_null("FolhaA") as Sprite2D
	var b := porta.get_node_or_null("FolhaB") as Sprite2D
	ok(a != null and b != null, "a folha tem duas metades")
	if a == null or b == null:
		raiz.free()
		return

	var meia := a.region_rect.size.x
	igual(
		meia, Porta.RECUO_DA_FOLHA,
		"cada metade recolhe o proprio tamanho (%.0f px de %.0f)" % [Porta.RECUO_DA_FOLHA, meia]
	)

	var batente := _batente_da_moldura(porta)
	ok(batente > 0.0, "a moldura tem batente opaco ao lado do vao (%.0f px)" % batente)
	ok(
		Porta.RECUO_DA_FOLHA <= batente,
		"a metade recolhida cabe atras do batente (%.0f px de %.0f) -- quem esconde a folha e a moldura"
			% [Porta.RECUO_DA_FOLHA, batente]
	)

	var casa_a := a.position
	var casa_b := b.position
	porta.trancar()
	await Engine.get_main_loop().process_frame
	ok(a.visible and b.visible, "trancada, as duas metades estao em tela (pre-condicao)")

	porta.abrir()
	# O laco anda ate a animacao TERMINAR, e nao um numero fixo de quadros.
	#
	# Sem janela o Godot nao tem vsync e roda centenas de quadros por segundo:
	# um teto de 30 quadros cobria 0,05 s de uma abertura de 0,42 s, e parava
	# dentro do TREMOR -- antes de a chapa ter comecado a se mexer. O caso
	# reprovava com o codigo certo, dizendo que a folha nao partia.
	var andou := false
	for i in 5000:
		await Engine.get_main_loop().process_frame
		if not a.scale.is_equal_approx(Vector2.ONE) or not b.scale.is_equal_approx(Vector2.ONE):
			ok(false, "a folha foi deformada em vez de deslocada (escala %s)" % a.scale)
			break
		if not a.position.is_equal_approx(casa_a):
			andou = true
		if not a.visible and not b.visible:
			break
	ok(andou, "as metades PARTEM: a posicao delas muda durante a abertura")
	ok(a.scale.is_equal_approx(Vector2.ONE), "e a escala nunca sai de 1 -- nada e achatado")

	# ABERTA nao deixa residuo, e o residuo nao e so o pixel: uma metade parada
	# fora de casa reapareceria deslocada na proxima vez que esta porta trancasse.
	ok(not a.visible and not b.visible, "ABERTA nao deixa a folha em cena")
	ok(
		a.position.is_equal_approx(casa_a) and b.position.is_equal_approx(casa_b),
		"e as metades voltam para casa, para a proxima tranca comecar do lugar certo"
	)

	raiz.free()


## A TRAVESSIA E DECIDIDA NA SAIDA DA AREA, E POR QUAL LADO.
##
## Este caso nasceu de um bug que se sentia jogando e que nenhum teste via. O
## aviso de travessia saia no `body_entered`, e a area da porta tem 32 px de
## profundidade: quem encostava nela e recuava sem cruzar disparava a saida da
## sala e **nada a desfazia**. A camera ficava no enquadramento largo da
## travessia -- meio numa sala, meio na outra --, e a proxima tentativa de sair de
## verdade era lida como "desistiu" e consumida. Rocar o batente desviando de um
## tiro bastava, e o estado so voltava ao normal depois de duas travessias
## inteiras.
##
## Entrar numa porta nao e atravessa-la. O caso cobra as duas metades:
##
## 1. Sair pelo lado do CORREDOR avisa `para_fora = true`.
## 2. Sair pelo lado da SALA avisa `para_fora = false`, e e esse aviso que nao
##    existia -- sem ele o gerenciador nunca sabia que o jogador tinha voltado.
func _a_travessia_e_decidida_na_saida() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)
	var porta := _porta_solta(raiz)
	porta.abrir()

	var avisos: Array[bool] = []
	var ouvinte := func(_sala: Node2D, _direcao: Vector2, para_fora: bool) -> void:
		avisos.append(para_fora)
	EventBus.porta_atravessada.connect(ouvinte)

	var corpo := _corpo_de_teste()
	raiz.add_child(corpo)
	var fora := porta.vetor()

	# 1. Entra na area e SAI pelo lado do corredor: atravessou.
	corpo.global_position = porta.global_position
	await Engine.get_main_loop().physics_frame
	await Engine.get_main_loop().physics_frame
	igual(avisos.size(), 0, "entrar na area nao avisa nada -- entrar nao e atravessar")
	corpo.global_position = porta.global_position + fora * 80.0
	await Engine.get_main_loop().physics_frame
	await Engine.get_main_loop().physics_frame
	igual(avisos.size(), 1, "sair da area avisa (%d)" % avisos.size())
	if avisos.size() == 1:
		ok(avisos[0], "quem sai pelo lado do corredor atravessou (para_fora)")

	# 2. Entra de novo e RECUA para dentro da sala: desistiu.
	avisos.clear()
	corpo.global_position = porta.global_position
	await Engine.get_main_loop().physics_frame
	await Engine.get_main_loop().physics_frame
	corpo.global_position = porta.global_position - fora * 80.0
	await Engine.get_main_loop().physics_frame
	await Engine.get_main_loop().physics_frame
	igual(avisos.size(), 1, "recuar tambem avisa (%d)" % avisos.size())
	if avisos.size() == 1:
		ok(
			not avisos[0],
			"e quem recua para dentro NAO atravessou -- era este aviso que faltava"
		)

	EventBus.porta_atravessada.disconnect(ouvinte)
	raiz.free()


## Um corpo na layer e no grupo do jogador.
##
## A porta so reage a quem esta no grupo "player" e na layer 1, entao o boneco
## precisa das duas coisas: sem o grupo ela ignora, sem a layer o `collision_mask`
## dela nunca o enxerga e o teste passaria medindo silencio.
func _corpo_de_teste() -> CharacterBody2D:
	var corpo := CharacterBody2D.new()
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	corpo.add_to_group("player")
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 8.0
	forma.shape = circulo
	corpo.add_child(forma)
	return corpo


## ABERTA deixa passar, TRANCADA bloqueia, SELADA nao poe nada.
##
## O caso do meio e o unico que o jogo ja exercitava; os outros dois sao os que
## erram calados. ABERTA com barreira prenderia o jogador na sala limpa --
## visivel na hora. SELADA com barreira e invisivel para sempre.
func _cada_estado_e_seu_solido() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)
	var porta := _porta_solta(raiz)

	porta.trancar()
	await Engine.get_main_loop().process_frame
	ok(not _barreira_de(porta).disabled, "TRANCADA poe barreira: e o lockdown do GDD")

	porta.abrir()
	await Engine.get_main_loop().process_frame
	ok(_barreira_de(porta).disabled, "ABERTA tira a barreira: da para atravessar")

	porta.trancar()
	await Engine.get_main_loop().process_frame
	porta.selar()
	await Engine.get_main_loop().process_frame
	ok(
		_barreira_de(porta).disabled,
		"SELADA NAO poe barreira -- quem fecha aquele lado e a parede da sala"
	)
	ok(porta.esta_selada(), "e selar e permanente")

	# Selar depois de trancar e o caminho real: a sala tranca tudo no _ready e
	# so depois descobre quem nao tem vizinho. Se `selar()` nao desfizesse a
	# barreira do `trancar()`, o defeito voltaria por esse lado.
	porta.abrir()
	await Engine.get_main_loop().process_frame
	ok(porta.esta_selada(), "porta selada nao reabre")
	ok(_barreira_de(porta).disabled, "e continua sem barreira depois de tentar abrir")

	raiz.free()


## O caso de verdade: uma sala montada com UMA conexao so.
##
## Aqui nao se testa a porta, e a SALA -- que sela sozinha os lados sem vizinho
## no `_ready`, antes de gerar a parede. O que se cobra e o resultado combinado:
## o lado conectado tem barreira (esta trancado), e os outros tres nao tem
## solido nenhum alem da parede.
func _sala_sem_vizinho_nao_deixa_solido_sobrando() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)

	var sala := CENA_SALA.instantiate() as Sala
	# ANTES do add_child: e o `_ready` que sela e monta a parede, e ele precisa
	# ja saber quem sao os vizinhos.
	sala.configurar_conexoes([Vector2.DOWN])
	raiz.add_child(sala)
	sala.global_position = LONGE
	await Engine.get_main_loop().process_frame

	var portas := sala.get_node_or_null("Portas")
	ok(portas != null, "a sala tem o no Portas")
	if portas == null:
		raiz.free()
		return

	var conferidas := 0
	var seladas := 0
	for filho in portas.get_children():
		var porta := filho as Porta
		if porta == null:
			continue
		conferidas += 1
		var barreira := _barreira_de(porta)
		if barreira == null:
			continue
		if porta.vetor() == Vector2.DOWN:
			ok(not barreira.disabled, "o lado COM vizinho fica trancado ate a sala limpar")
		else:
			seladas += 1
			ok(
				barreira.disabled,
				"o lado sem vizinho (%s) nao deixa solido dentro da sala" % porta.vetor()
			)

	ok(conferidas >= 2, "a varredura achou as portas da sala (%d)" % conferidas)
	ok(seladas >= 1, "e ao menos um lado ficou sem vizinho neste cenario (%d)" % seladas)

	raiz.free()


# ------------------------------------------------------------- helpers ------

## O recesso tapa a abertura da moldura, pixel a pixel.
##
## O defeito que este caso fecha: `porta_moldura.png` e arte autorada com um
## BURACO -- 32x34 px de alfa zero no meio dela. A moldura GERADA que ela
## substituiu na LTD 11 preenchia esse vao com N0 opaco ("corredor nao revelado e
## escuridao"); a migracao para arte autorada perdeu o preenchimento e nada o
## substituiu. O que aparecia por dentro do batente era a parede da sala.
##
## O caso mede as DUAS imagens e cruza as coordenadas locais delas, em vez de
## comparar numeros escritos a mao. Assim o recesso continua cobrindo o vao no
## dia em que a moldura for redesenhada -- e se nao cobrir, o teste diz quantos
## pixels ficaram de fora, que e por onde a parede volta a vazar.
func _o_recesso_cobre_o_vao_da_moldura() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)
	var porta := _porta_solta(raiz)
	var no_vao := porta.get_node_or_null("Vao") as Sprite2D
	ok(no_vao != null, "a porta tem um no Vao -- o recesso do batente")
	if no_vao != null:
		_o_no_cobre_o_vao(porta, no_vao.texture, no_vao.position, "o recesso")
	raiz.free()


## Um sprite da porta tapa, pixel a pixel, o furo da moldura.
##
## Duas pecas fazem essa pergunta: o RECESSO (o que ha atras do furo) e a FOLHA
## (o que fecha o furo). A conta e a mesma -- cruzar as coordenadas locais das
## duas imagens -- e por isso ela mora num lugar so: duas copias divergiriam no
## dia em que a moldura fosse redesenhada, e uma delas continuaria verde.
##
## Sprite2D e centrado: o pixel (c, r) cai em (c - largura/2, r - altura/2) mais
## a posicao do no.
func _o_no_cobre_o_vao(porta: Porta, cobertura: Texture2D, centro: Vector2, rotulo: String) -> void:
	var no_moldura := porta.get_node_or_null("Moldura") as Sprite2D
	if no_moldura == null or no_moldura.texture == null or cobertura == null:
		ok(false, "%s e a moldura tem textura" % rotulo)
		return
	var moldura := no_moldura.texture.get_image()
	var cobre := cobertura.get_image()

	var canto_moldura := no_moldura.position - Vector2(moldura.get_width(), moldura.get_height()) * 0.5
	var canto_cobre := centro - Vector2(cobre.get_width(), cobre.get_height()) * 0.5

	var buracos := 0
	var descobertos := 0
	for r in moldura.get_height():
		for c in moldura.get_width():
			if not _e_furo_interno(moldura, c, r):
				continue
			buracos += 1
			var local := canto_moldura + Vector2(c, r)
			var cc := int(local.x - canto_cobre.x)
			var cr := int(local.y - canto_cobre.y)
			if cc < 0 or cc >= cobre.get_width() \
					or cr < 0 or cr >= cobre.get_height() \
					or cobre.get_pixel(cc, cr).a < 0.999:
				descobertos += 1

	ok(buracos > 0, "a moldura tem uma abertura (%d px) -- e por ela que se ve o vao" % buracos)
	igual(descobertos, 0, "%s cobre a abertura inteira da moldura (%d de %d descobertos)"
		% [rotulo, descobertos, buracos])


## Este pixel e transparente E esta cercado por moldura nos QUATRO lados?
##
## Quatro e nao dois, e a diferenca foi medida. Cercar so na horizontal acha
## 1240 px de "abertura" numa moldura cuja porta tem 1088, e os 152 restantes NAO
## sao defeito:
##
##   linha 6, colunas 20-75  -- o vao ENTRE os dois blocos de canto, no alto. Ali
##                              se ve a parede de proposito: e o recorte da
##                              moldura, e nao um buraco nela.
##   linhas 65-67            -- abaixo da SOLEIRA, ja dentro da sala. Ali se ve o
##                              CHAO, que e o que tem de aparecer: a passagem
##                              continua no piso.
##
## So a porta e fechada em cima (verga), embaixo (soleira) e dos dois lados
## (batentes). Cercar nos quatro isola exatamente ela, sem numero escrito a mao,
## e continua isolando se a moldura for redesenhada.
func _e_furo_interno(img: Image, c: int, r: int) -> bool:
	if img.get_pixel(c, r).a >= 0.999:
		return false
	return _ha_opaco(img, c, r, -1, 0) and _ha_opaco(img, c, r, 1, 0) \
		and _ha_opaco(img, c, r, 0, -1) and _ha_opaco(img, c, r, 0, 1)


func _ha_opaco(img: Image, c: int, r: int, dc: int, dr: int) -> bool:
	var x := c + dc
	var y := r + dr
	while x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		if img.get_pixel(x, y).a >= 0.999:
			return true
		x += dc
		y += dr
	return false


## A PAREDE ABRE no vao da porta, em vez de passar reta por cima.
##
## `_subtrechos()` corta o lado nas portas e, ate a PAR 01, tinha um consumidor
## so: a colisao. O visual usava o par de vertices cru, entao o quad de face
## atravessava a porta inteira, e o modulo autorado aparecia DENTRO do batente --
## onde o jogador mais olha.
##
## Com a fita o mecanismo mudou e a pergunta nao: quem decide agora e o
## renderizador, reservando as celulas do vao antes de escolher modulo. O caso
## mede o resultado, que e o que interessa -- **nenhuma peca de parede cai dentro
## do vao** --, e por isso ele sobrevive a troca do desenho por baixo.
func _a_face_abre_no_vao_da_porta() -> void:
	var sala := CENA_SALA.instantiate() as Sala
	Engine.get_main_loop().root.add_child(sala)
	sala.global_position = LONGE
	await Engine.get_main_loop().process_frame

	var fita := sala.get_node_or_null("ParedeModulos")
	ok(fita != null, "a sala retangular monta a fita")
	if fita == null:
		sala.free()
		return

	var porta := sala.get_node_or_null("Portas/Porta_Norte") as Porta
	if porta != null:
		var eixo := Vector2(absf(porta.vetor().y), absf(porta.vetor().x))
		var centro := porta.position.dot(eixo)
		var meia := Porta.LARGURA * 0.5
		var dentro := 0
		for filho in fita.get_children():
			var sprite := filho as Sprite2D
			if sprite == null:
				continue
			# So a faixa DESTE lado: a fita do lado oposto projeta no mesmo eixo
			# e nao tem nada a ver com este vao.
			if sprite.position.dot(porta.vetor()) < 0.0:
				continue
			var onde := sprite.position.dot(eixo)
			if onde > centro - meia and onde < centro + meia:
				dentro += 1
		igual(dentro, 0, "nenhuma peca de parede cai dentro do vao da porta (%d)" % dentro)
	sala.free()


## A FOLHA cobre o vao da moldura (PORTA 01).
##
## Mesma pergunta que o recesso responde -- "o que ha atras deste furo?" -- so
## que um passo a frente: atras dele tem de haver uma CHAPA, e nao escuridao. A
## porta trancada era `porta_campo.png`, 80x32 em duas cores de sinal, no meio de
## uma moldura de 96x128: uma tira vermelha de 32 px de altura num vao de 34, com
## o buraco continuando visivelmente um buraco.
##
## O caso cruza as coordenadas locais das DUAS imagens, como o do recesso, e nao
## compara numero escrito a mao: a medida sai do alfa da moldura autorada.
func _a_folha_cobre_o_vao_da_moldura() -> void:
	var porta := CENA_PORTA.instantiate() as Porta
	Engine.get_main_loop().root.add_child(porta)
	var a := porta.get_node_or_null("FolhaA") as Sprite2D
	var b := porta.get_node_or_null("FolhaB") as Sprite2D
	ok(a != null and b != null, "a porta tem as duas metades da folha")
	if a == null or b == null:
		porta.free()
		return
	# As duas metades sao regioes da MESMA textura e, juntas, reconstroem a chapa
	# inteira centrada no meio delas. Medir a uniao e medir a folha fechada.
	var centro := (a.position + b.position) * 0.5
	_o_no_cobre_o_vao(porta, a.texture, centro, "a folha")
	porta.free()


## O GIRO DA PORTA E UM DOS QUATRO ANGULOS RETOS, e nunca um espelho vertical.
##
## Este portao ja proibiu giro por completo, e a proibicao caiu -- por decisao do
## dono do projeto, olhando as quatro portas no jogo. O argumento original
## continua correto no papel: `porta_moldura.png` e arte de FACE, e girar uma face
## e destruir a perspectiva Low Top-Down. O que ele nao previu e que o substituto
## teria de ser tao bom quanto a arte desenhada, e em tres rodadas as vistas de
## cima geradas nao chegaram perto.
##
## O que sobra a cobrar nao e "nao gire": e **gire certo**. Duas coisas, e as duas
## erram calado:
##
## 1. **O angulo e um dos quatro retos.** Um giro de 0,3 rad em alguma cena poria
##    a moldura torta sobre um vao reto, e a fresta apareceria so naquele lado.
## 2. **`flip_v` continua proibido.** Espelhar na vertical troca o que esta em
##    cima pelo que esta embaixo -- poria a SOLEIRA acima da VERGA, e isso nenhum
##    giro faz. Girar 180 mantem a peca inteira coerente consigo mesma; espelhar
##    a desmonta.
##
## E o angulo tem de CONCORDAR com `direcao`, que continua sendo a fonte de
## verdade: uma porta leste com o visual girado como sul desenharia o batente
## atravessado no vao, e nada mais no projeto acusaria.
func _o_giro_da_porta_concorda_com_a_direcao() -> void:
	var cenas := _cenas_de_sala()
	ok(cenas.size() >= 5, "a varredura achou as cenas de sala (%d)" % cenas.size())
	var portas := 0
	var sprites := 0
	for caminho in cenas:
		var cena := load(caminho) as PackedScene
		if cena == null:
			ok(false, "%s carrega" % caminho)
			continue
		var sala := cena.instantiate() as Sala
		Engine.get_main_loop().root.add_child(sala)
		sala.global_position = LONGE
		await Engine.get_main_loop().process_frame
		var raiz := sala.get_node_or_null("Portas")
		if raiz != null:
			for filho in raiz.get_children():
				var porta := filho as Porta
				if porta == null:
					continue
				portas += 1
				var esperado := porta.vetor().angle() + PI * 0.5
				for sprite in _sprites_de(porta):
					sprites += 1
					var giro := wrapf(sprite.global_rotation - esperado, -PI, PI)
					ok(
						absf(giro) < 0.01,
						"%s/%s gira o que a direcao pede (%.2f rad, esperado %.2f)"
							% [porta.name, sprite.name, sprite.global_rotation, esperado]
					)
					ok(
						not sprite.flip_v,
						"%s/%s nao espelha na vertical -- isso poria a soleira acima da verga"
							% [porta.name, sprite.name]
					)
		sala.free()
	ok(portas >= 20, "a varredura conferiu as portas das salas (%d)" % portas)
	ok(sprites >= portas, "e conferiu ao menos um sprite por porta (%d)" % sprites)


## A MOLDURA DE CADA LADO tem de estar VAZADA onde a folha desenha.
##
## O defeito que este caso fecha nao existia no norte, e sim nas vistas de cima:
## a carcaca era pintada sobre os 80 px inteiros, passagem incluida. E a moldura
## desenha ACIMA da folha e do recesso, entao a porta trancada virava uma chapa
## lisa com uma barra de sinal em cima -- exatamente o buraco-com-adesivo que a
## PORTA 01 existiu para acabar.
##
## Nenhum portao de arquivo pega isso. As tres texturas continuam validas, cada
## uma no seu regime, e a de cima e que nao podia estar la: e um defeito de
## ORDEM, e ordem so se ve montando as tres.
##
## O caso pergunta o minimo que separa "abre" de "nao abre": no centro da folha,
## a moldura daquele lado tem de ser transparente. E ele varre os QUATRO lados,
## porque o norte -- o unico com arte autorada -- e justamente o que ja estava
## certo, e um caso cravado nele nao teria achado nada.
func _a_moldura_de_cada_lado_abre_no_vao() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)
	var sala := CENA_SALA.instantiate() as Sala
	sala.configurar_conexoes([])
	raiz.add_child(sala)
	sala.global_position = LONGE
	var portas := sala.get_node("Portas")

	var conferidos := 0
	for direcao: int in [Porta.Direcao.NORTE, Porta.Direcao.SUL,
			Porta.Direcao.LESTE, Porta.Direcao.OESTE]:
		var porta := CENA_PORTA.instantiate() as Porta
		porta.direcao = direcao
		portas.add_child(porta)
		await Engine.get_main_loop().process_frame

		var moldura := porta.get_node_or_null("Moldura") as Sprite2D
		var folha := porta.get_node_or_null("FolhaA") as Sprite2D
		var outra := porta.get_node_or_null("FolhaB") as Sprite2D
		if moldura == null or moldura.texture == null or folha == null or outra == null:
			ok(false, "a porta %d tem moldura e folha" % direcao)
			porta.queue_free()
			continue

		var img := moldura.texture.get_image()
		var centro := (folha.position + outra.position) * 0.5
		# Pelo TRANSFORM do sprite, e nao subtraindo posicoes: a moldura gira com a
		# direcao desde que a arte autorada voltou a servir os quatro lados, e uma
		# conta em coordenada de mundo acertaria o norte e erraria o leste --
		# apontando para um pixel que nao e o que esta sob a folha.
		var local := moldura.to_local(porta.to_global(centro))
		var c := int(local.x + img.get_width() * 0.5)
		var r := int(local.y + img.get_height() * 0.5)
		var dentro := c >= 0 and c < img.get_width() and r >= 0 and r < img.get_height()
		ok(dentro, "o centro da folha da porta %d cai dentro da moldura (%d, %d)"
			% [direcao, c, r])
		if dentro:
			conferidos += 1
			ok(
				img.get_pixel(c, r).a < 0.999,
				"a moldura da porta %d e vazada onde a folha desenha -- senao ela tapa a chapa"
					% direcao
			)
		porta.queue_free()

	igual(conferidos, 4, "os quatro lados foram conferidos (%d)" % conferidos)
	raiz.free()


## TODA MOLDURA CERCA O VAO NOS QUATRO LADOS.
##
## Este e o portao que faltava, e ele mede exatamente a diferenca entre as duas
## coisas que se confundiram tres vezes seguidas:
##
##   dois blocos com um vao entre eles   -> o olho le "a parede tem um buraco"
##   uma moldura                          -> o olho le "aqui ha uma porta"
##
## O que separa as duas e topologia, e nao capricho: numa moldura o vao e FECHADO
## nos quatro lados. Na porta norte, que e arte autorada, quem fecha em cima e a
## verga e embaixo e a soleira. As vistas de cima nao tinham nada atravessando a
## abertura -- so os dois batentes laterais --, e por isso nao liam como porta por
## mais que ganhassem grao, rebite, laje e sombra de contato. Nenhuma medicao de
## COR pegaria isso; a de forma pega.
##
## A conta reusa `_e_furo_interno`, que ja existe nesta suite: um pixel so conta
## como vao quando ha opaco a esquerda, a direita, acima e abaixo dele. Antes das
## travessas, `porta_topo` e `porta_lado` tinham ZERO pixels assim.
func _toda_moldura_CERCA_o_vao() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)
	var sala := CENA_SALA.instantiate() as Sala
	sala.configurar_conexoes([])
	raiz.add_child(sala)
	sala.global_position = LONGE
	var portas := sala.get_node("Portas")

	var conferidas := 0
	for direcao: int in [Porta.Direcao.NORTE, Porta.Direcao.SUL,
			Porta.Direcao.LESTE, Porta.Direcao.OESTE]:
		var porta := CENA_PORTA.instantiate() as Porta
		porta.direcao = direcao
		portas.add_child(porta)
		var moldura := porta.get_node_or_null("Moldura") as Sprite2D
		if moldura == null or moldura.texture == null:
			ok(false, "a porta %d tem moldura" % direcao)
			porta.free()
			continue
		var img := moldura.texture.get_image()
		var cercados := 0
		for r in img.get_height():
			for c in img.get_width():
				if _e_furo_interno(img, c, r):
					cercados += 1
		conferidas += 1
		ok(
			cercados > 0,
			"a moldura da porta %d CERCA o vao (%d px cercados) -- dois blocos com um buraco entre eles nao sao moldura"
				% [direcao, cercados]
		)
		porta.free()
	igual(conferidas, 4, "as quatro molduras foram medidas (%d)" % conferidas)
	raiz.free()


## A MOLDURA E MAIS ESCURA QUE A PAREDE, e nao mais clara.
##
## Este portao ja existiu ao contrario, e o erro foi meu: a primeira versao dele
## exigia que a carcaca da porta NAO fosse mais escura que a parede, porque
## naquele momento a parede era uma fita cinza-clara e a porta sumia nela. Com a
## fita vestindo a arte autorada, a parede ficou escura -- e o portao passou a
## defender exatamente o defeito, um bloco palido colado num muro escuro.
##
## O numero vem da referencia de `docs/objetivo/`, medida: a moldura autorada da
## porta norte fica em V 0,094 a 0,251, contra 0,294 da face e 0,380 do topo. **A
## moldura e a coisa mais escura da parede, tirando o vao.** Ela nao se destaca
## por brilhar: ela se destaca por ser um poco.
##
## O teto e a FACE e nao o topo, porque a face e o que fica ao lado da porta nos
## tres lados que tem face -- e e contra o vizinho que o contraste se le.
func _a_moldura_e_mais_escura_que_a_parede() -> void:
	var face := _mediana_de_valor("res://assets/texturas/parede_face.png")
	ok(face > 0.0, "a face da parede carrega (%.3f)" % face)
	if face <= 0.0:
		return
	for nome in ["porta_moldura.png"]:
		var v := _mediana_de_valor("res://assets/texturas/%s" % nome)
		if v <= 0.0:
			ok(false, "%s carrega" % nome)
			continue
		ok(
			v < face,
			"%s e mais escura que a face da parede (V %.3f contra %.3f) -- moldura e poco, nao bloco"
				% [nome, v, face]
		)
		# E nao pode desabar no vao: escuridao total apagaria a propria moldura.
		ok(
			v > 0.05,
			"%s ainda e desenho e nao escuridao (V %.3f)" % [nome, v]
		)


## A mediana do VALOR entre os pixels opacos. Mesma conta de
## `teste_texturas.gd`, e nao outra: dois numeros para a mesma pergunta seria o
## comeco de duas respostas.
func _mediana_de_valor(caminho: String) -> float:
	var tex := load(caminho) as Texture2D
	if tex == null:
		return 0.0
	var img := tex.get_image()
	var valores: Array[float] = []
	for y in img.get_height():
		for x in img.get_width():
			var cor := img.get_pixel(x, y)
			if cor.a >= 0.5:
				valores.append(cor.v)
	if valores.is_empty():
		return 0.0
	valores.sort()
	return valores[valores.size() / 2]


func _cenas_de_sala() -> Array[String]:
	var lista: Array[String] = []
	var pasta := DirAccess.open("res://src/mapa")
	if pasta == null:
		return lista
	for arquivo in pasta.get_files():
		if arquivo.begins_with("sala_") and arquivo.ends_with(".tscn"):
			lista.append("res://src/mapa/%s" % arquivo)
	lista.sort()
	return lista


func _sprites_de(raiz: Node) -> Array[Sprite2D]:
	var lista: Array[Sprite2D] = []
	for filho in raiz.get_children():
		var sprite := filho as Sprite2D
		if sprite != null and sprite.texture != null:
			lista.append(sprite)
		lista.append_array(_sprites_de(filho))
	return lista


## Quantos px OPACOS a moldura tem entre o vao e a borda do desenho.
##
## E o esconderijo da folha recolhida, e sai do alfa em vez de uma constante:
## redesenhar a moldura com batente mais estreito passa a reprovar o recuo, que e
## exatamente o dia em que a folha comecaria a aparecer no meio do vao.
func _batente_da_moldura(porta: Porta) -> float:
	var no := porta.get_node_or_null("Moldura") as Sprite2D
	if no == null or no.texture == null:
		return 0.0
	var img := no.texture.get_image()
	# O furo primeiro, e nao o meio do SPRITE. A abertura da moldura vai da linha
	# 29 a 62 de 128: medir na linha 64 cai na SOLEIRA, que e opaca de ponta a
	# ponta -- a primeira versao deste portao respondia 48 px de batente onde ha
	# 24, e um portao que mede a coisa errada aprova o dobro do que devia.
	var esquerda := img.get_width()
	var topo := img.get_height()
	var base := -1
	for r in img.get_height():
		for c in img.get_width():
			if not _e_furo_interno(img, c, r):
				continue
			esquerda = mini(esquerda, c)
			topo = mini(topo, r)
			base = maxi(base, r)
	if base < 0:
		return 0.0

	var linha := (topo + base) / 2
	var x := esquerda - 1
	var largura := 0
	while x >= 0 and img.get_pixel(x, linha).a >= 0.999:
		largura += 1
		x -= 1
	return float(largura)


func _porta_solta(raiz: Node) -> Porta:
	# A porta espera morar em Sala/Portas/Porta -- ela sobe dois niveis para
	# achar a dona. Sem os dois nos, o _ready dela solta push_error e a suite
	# passaria com o console sujo.
	var sala := CENA_SALA.instantiate() as Sala
	sala.configurar_conexoes([])
	raiz.add_child(sala)
	sala.global_position = LONGE
	var portas := sala.get_node("Portas")
	var porta := CENA_PORTA.instantiate() as Porta
	portas.add_child(porta)
	return porta


func _barreira_de(porta: Porta) -> CollisionShape2D:
	return porta.get_node_or_null(CAMINHO_BARREIRA) as CollisionShape2D


## A FACE da parede nao pode ser mais funda que a moldura da porta.
##
## A face ABRE no vao -- e a regra que faz a porta ler como passagem e nao como
## janela --, entao no vao quem cobre aquela faixa e a moldura. Uma face mais
## funda que a moldura deixa uma tira de NADA entre o alto dela e o comeco do
## topo: o dono viu como "um espaco vazio acima da porta, com uma cor parecida
## mas nao igual a da moldura".
##
## O teto e MEDIDO no alfa do arquivo e nao escrito aqui. `porta_moldura.png` tem
## hoje 58 px de conteudo acima do contorno; no dia em que a arte crescer, o teto
## sobe junto e a face pode acompanhar sem ninguem lembrar de mexer neste numero.
## E o mesmo desenho de `_o_recesso_cobre_o_vao_da_moldura`, que ja cruza as
## coordenadas locais de duas imagens em vez de comparar literais.
func _a_FACE_nao_e_mais_funda_que_a_moldura() -> void:
	var imagem := Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/texturas/porta_moldura.png"))
	if imagem == null or imagem.is_empty():
		ok(false, "porta_moldura.png abre")
		return
	imagem.convert(Image.FORMAT_RGBA8)
	# A linha mais alta com pixel opaco, em coordenadas de MUNDO: o sprite e
	# centrado sobre o contorno, entao a metade de cima do arquivo fica acima
	# dele.
	var primeira := -1
	for y in imagem.get_height():
		for x in imagem.get_width():
			if imagem.get_pixel(x, y).a >= 0.5:
				primeira = y
				break
		if primeira >= 0:
			break
	ok(primeira >= 0, "a moldura tem pixel opaco")
	if primeira < 0:
		return
	var acima_do_contorno := float(imagem.get_height()) * 0.5 - float(primeira)
	var perfil := PerfilDeParede.new()
	ok(
		perfil.fim_da_face(RenderizadorParedes.Lado.NORTE) <= acima_do_contorno,
		"a face (%.0f) cabe na moldura (%.0f px acima do contorno)"
			% [perfil.fim_da_face(RenderizadorParedes.Lado.NORTE), acima_do_contorno]
	)
	# O outro lado: uma face MUITO menor que a moldura tambem e defeito -- ai a
	# moldura invade o topo e a verga deixa de ler como verga.
	ok(
		perfil.fim_da_face(RenderizadorParedes.Lado.NORTE) >= acima_do_contorno - 16.0,
		"e nao sobra moldura demais sobre o topo (%.0f contra %.0f)"
			% [perfil.fim_da_face(RenderizadorParedes.Lado.NORTE), acima_do_contorno]
	)
