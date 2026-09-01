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
	_o_recesso_cobre_o_vao_da_moldura()
	_a_folha_cobre_o_vao_da_moldura()
	await _nenhuma_porta_desenha_arte_girada()
	await _a_face_abre_no_vao_da_porta()


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


## A face da parede ABRE no vao da porta, em vez de passar reta por cima.
##
## `_subtrechos()` corta o lado nas portas e, ate esta issue, tinha um consumidor
## so: a colisao. O visual usava o par de vertices cru, entao o quad de face
## atravessava a porta inteira. Como so o lado NORTE ganha face
## (`LIMIAR_LADO_NORTE`), era la que o modulo autorado aparecia dentro do batente.
##
## O caso conta QUADS: um lado sem porta da um, um lado com porta no meio da
## dois. E o numero que separa "abriu" de "nao abriu" sem depender de pixel.
func _a_face_abre_no_vao_da_porta() -> void:
	var sala := CENA_SALA.instantiate() as Sala
	Engine.get_main_loop().root.add_child(sala)
	sala.global_position = LONGE
	await Engine.get_main_loop().process_frame

	var raiz := sala.get_node_or_null("ParedeFace")
	ok(raiz != null, "a sala retangular desenha face")
	if raiz == null:
		sala.free()
		return

	# A sala retangular tem UMA face (o lado norte) e uma porta no meio dele.
	# Aberta, ela vira dois trechos.
	igual(
		raiz.get_child_count(), 2,
		"a face do lado norte abre no vao da porta, virando dois trechos (%d)"
			% raiz.get_child_count()
	)

	# E nenhum trecho pode cobrir o centro do vao.
	var porta := sala.get_node_or_null("Portas/Porta_Norte") as Porta
	if porta != null:
		var centro := porta.position
		var cobrindo := 0
		for filho in raiz.get_children():
			var quad := filho as Polygon2D
			if quad != null and Geometry2D.is_point_in_polygon(centro, quad.polygon):
				cobrindo += 1
		igual(cobrindo, 0, "nenhum trecho de face cobre o centro do vao")
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


## NENHUMA PORTA DESENHA ARTE GIRADA (PORTA 03).
##
## A porta era a MESMA imagem rotacionada nos quatro lados: 180 graus no sul, 90
## no leste, -90 no oeste. Numa perspectiva em que parede tem topo e face, girar
## uma face e destruir a perspectiva -- e a `porta_moldura.png` e face, com 96 de
## largura por 128 de altura. Girada para o leste, aqueles 128 px de ALTURA
## viravam 128 px de extensao horizontal, com a face deitada.
##
## O portao varre as cenas de sala em DISCO em vez de listar as sete: uma lista
## fixa aqui teria o mesmo defeito que a `AUTORADAS` do teste de texturas ja
## teve -- cena nova fora dela nao seria conferida por nada, e ninguem
## descobriria.
##
## Espelhar continua permitido, e a distincao e o assunto inteiro da issue:
## `flip_h` reflete e nao gira, entao a porta oeste pode ser a leste espelhada.
## `flip_v` nao entra na mesma sacada -- espelhar na vertical troca o que esta
## em cima pelo que esta embaixo, que numa arte com face e a mesma destruicao
## que girar 180 graus.
func _nenhuma_porta_desenha_arte_girada() -> void:
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
				for sprite in _sprites_de(porta):
					sprites += 1
					ok(
						is_zero_approx(sprite.global_rotation),
						"%s/%s desenha sem rotacao (%.2f rad)"
							% [porta.name, sprite.name, sprite.global_rotation]
					)
					ok(
						not sprite.flip_v,
						"%s/%s nao espelha na vertical -- isso vira arte de cabeca para baixo"
							% [porta.name, sprite.name]
					)
		sala.free()
	ok(portas >= 20, "a varredura conferiu as portas das salas (%d)" % portas)
	ok(sprites >= portas, "e conferiu ao menos um sprite por porta (%d)" % sprites)


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
