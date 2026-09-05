extends Node
## A CAIXA: a cena que prova a arquitetura antes de existir gerador de parede.
##
## Ela responde uma pergunta so, e e a pergunta de aceitacao do epico das
## paredes:
##
##   **A sala parece uma caixa arquitetonica aberta para a camera, ou um
##   tabuleiro com borda?**
##
## Se a resposta for "tabuleiro", o problema e PERSPECTIVA e PROPORCAO, e nenhuma
## quantidade de ferrugem, tubo ou painel conserta isso. O plano e explicito: se
## a silhueta falhar, revisar altura da face, espessura do topo, cantos, parede
## sul e posicao do chao ANTES de acrescentar um unico detalhe.
##
## **Ela nao e o `sala_prototipo.tscn`.** Aquele monta o andar 1 inteiro -- chao,
## props, atores, telegrafo, mostruario de face -- e responde "o conteudo da
## LTD 14 esta completo?", que e outra pergunta. Esta cena e POBRE de proposito:
## sem prop, sem decalque, sem prop animado, sem pickup. Se ela ficar boa, e a
## arquitetura que esta funcionando, e nao a decoracao.
##
## **A sala e menor que a tela, e isso e a peca inteira.** As salas do jogo tem
## 960x544 de contorno e a faixa de parede soma 64 de cada lado: 1088x672 contra
## uma tela de 960x544, entao com o jogador no centro nenhuma parede aparece
## (medido em `docs/PIVO_PAREDES.md` §5). O `sala_prototipo` contorna isso com
## zoom 0,72 -- e zoom fracionario BORRA pixel art, o que e aceitavel para
## conferir cor e nao para julgar silhueta. Aqui a sala e de 480x352, a moldura
## inteira cabe em 608x480, e a camera fica em **zoom 1.0, escala inteira**. O
## que se ve e o que o jogo desenha, pixel a pixel.
##
## Uso: godot --path . tools/teste_paredes.tscn --resolution 960x544
## Sai em user://capturas/paredes_*.png

const SAIDA := "user://capturas"

## O degrau minimo para dois patamares contarem como superficies diferentes.
##
## Mesmo numero do `PASSO_MINIMO` de `teste_profundidade.gd`, e pelo mesmo
## motivo: e o menor degrau da rampa de neutros da `Paleta`. Abaixo dele a
## propria paleta nao considera que houve mudanca de cor.
const DEGRAU_MINIMO := 0.036

## Quantos pixels um valor precisa SUSTENTAR para contar como superficie.
##
## Abaixo disto e detalhe: rebite, junta, contorno de placa. A face norte tem 24
## px no perfil C, entao 8 cabe nela com folga e nao cabe numa borda de placa.
const ALTURA_DE_PATAMAR := 8

## Quantas superficies distintas a coluna tem de atravessar.
##
## Tres e o minimo do plano: exterior, arquitetura e piso. Hoje a sala entrega
## QUATRO -- exterior, topo, face e piso --, e o quarto e o que separa "tem uma
## borda" de "tem uma parede com espessura".
const PATAMARES_MINIMOS := 3

## A distancia minima entre a superficie mais clara e a mais escura da coluna.
##
## Medido em A/B na MESMA cena, trocando so as texturas:
##
##     arte de antes do epico   amplitude 0,192   (e 4 patamares: passava)
##     arte de hoje             amplitude 0,388
##
## O corte fica entre as duas e longe de ambas. Ele separa "as superficies
## existem" de "as superficies se afastam", que e a pergunta do §48 -- e e o que
## a contagem sozinha nao respondia.
const AMPLITUDE_MINIMA := 0.25
const CENA_SALA := preload("res://src/mapa/sala_1_retangular.tscn")
const CENA_PLAYER := preload("res://src/player/player.tscn")
const CENA_DRONE := preload("res://src/enemies/drone_aranha.tscn")
const CENA_PROJETIL := preload("res://src/projectiles/projetil.tscn")
const DADOS_COMBATE := preload("res://src/mapa/tipo_combate.tres")
const PERSONAGEM := preload("res://src/player/personagem_raven.tres")
const ARMA_PLAYER := preload("res://src/weapons/pistola.tres")

## 15 x 11 tiles de 32. Multiplos de 32 nas duas dimensoes, entao a MEIA dimensao
## cai na grade de 16 -- que e o que `teste_grade.gd` cobra de toda sala, e a
## razao pela qual dimensao impar de tile nao serve.
const LARGURA := 480.0
const ALTURA := 352.0

## Espera antes de cada foto. O jogador cai no chao e o inimigo acorda; fotografar
## no primeiro frame pega o `_ready` e nao o jogo.
const ESPERA := 0.8

## Onde o jogador para em cada foto.
##
## A do NORTE e a do SUL nao sao capricho: elas sao o teste da assimetria. A
## parede norte mostra topo E face, entao o jogador encostado nela some atras de
## 32 px de metal se a face for alta demais; a sul mostra so o topo justamente
## para isso nao acontecer. Duas fotos, e a pergunta se responde comparando.
const POSTOS := {
	"01_geral": Vector2(0.0, 0.0),
	"02_norte": Vector2(0.0, -ALTURA * 0.5 + 24.0),
	"03_sul": Vector2(0.0, ALTURA * 0.5 - 24.0),
}

var _sala: Sala = null
var _player: Node2D = null
var _camera: Camera2D = null
var _restantes: Array[String] = []
var _t: float = 0.0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAIDA)
	GameState.personagem = PERSONAGEM

	_sala = CENA_SALA.instantiate() as Sala
	# ANTES do add_child, e sao as duas coisas que o `_ready` da sala consome: o
	# contorno vira colisao, camera, minimapa e parede, e a posicao das portas
	# vira o vao que a parede abre. Depois do add_child nada disso reage.
	_encolher(_sala)
	_sala.definir_visual(DADOS_COMBATE)
	# Norte e sul conectados: as outras duas portas se selam sozinhas, e porta
	# selada nao desenha nada. Sobram exatamente as duas que o plano pede.
	_sala.configurar_conexoes([Vector2.UP, Vector2.DOWN])
	add_child(_sala)

	_montar_atores()
	_montar_camera()
	# Laco explicito: `Dictionary.keys()` devolve `Array` SEM tipo, e atribuir
	# isso a um `Array[String]` explode em runtime. Mesma armadilha que o
	# `Array[Node].filter()` ja registrou no GEMINI.md.
	for nome: String in POSTOS:
		_restantes.append(nome)


## O contorno de 480x352 e as portas nas bordas novas.
##
## A sala retangular do jogo tem 960x544. Encolher em vez de criar uma cena nova
## e deliberado: o que se quer medir e a PAREDE que o jogo desenha, e uma cena
## propria acabaria divergindo da de verdade no dia em que uma delas mudasse.
func _encolher(sala: Sala) -> void:
	var meia := Vector2(LARGURA, ALTURA) * 0.5
	var linha := sala.get_node_or_null("Parede") as Line2D
	if linha == null:
		push_error("teste_paredes: a sala nao tem o Line2D 'Parede'")
		return
	# Fechado, como o `.tscn` guarda: o primeiro ponto se repete no fim.
	linha.points = PackedVector2Array([
		Vector2(-meia.x, -meia.y), Vector2(meia.x, -meia.y),
		Vector2(meia.x, meia.y), Vector2(-meia.x, meia.y),
		Vector2(-meia.x, -meia.y),
	])

	var portas := sala.get_node_or_null("Portas")
	if portas == null:
		return
	var onde := {
		"Porta_Norte": Vector2(0.0, -meia.y), "Porta_Sul": Vector2(0.0, meia.y),
		"Porta_Leste": Vector2(meia.x, 0.0), "Porta_Oeste": Vector2(-meia.x, 0.0),
	}
	for nome: String in onde:
		var porta := portas.get_node_or_null(nome) as Node2D
		if porta != null:
			porta.position = onde[nome]


## O jogador, um inimigo e dois projeteis parados.
##
## Os projeteis sao o item mais facil de esquecer e o mais importante: um deles
## fica SOBRE a face e o outro sobre o chao, porque a pergunta que a parede nova
## nao pode responder errado e "um tiro continua legivel na frente dela?".
func _montar_atores() -> void:
	_player = CENA_PLAYER.instantiate() as Node2D
	_sala.add_child(_player)

	var drone := CENA_DRONE.instantiate() as Node2D
	drone.position = Vector2(120.0, 40.0)
	_sala.add_child(drone)

	# Sobre a FACE do norte: ela ocupa `ALTURA_FACE` acima da linha do contorno.
	_projetil(Vector2(-140.0, -ALTURA * 0.5 - Sala.ALTURA_FACE * 0.5), false)
	# E sobre o chao, para a comparacao ter os dois fundos.
	_projetil(Vector2(-60.0, 40.0), true)


func _projetil(onde: Vector2, hostil: bool) -> void:
	var p := CENA_PROJETIL.instantiate()
	p.name = "Projetil_%s" % ("hostil" if hostil else "player")
	_sala.add_child(p)
	# add_child ANTES de configurar, como a Arma faz.
	if p.has_method("configurar"):
		p.configurar(onde, Vector2.RIGHT, ARMA_PLAYER, hostil)
	p.position = onde
	p.set_physics_process(false)
	p.set_process(false)
	# Parar o processamento nao basta: o projetil continua no espaco de fisica e
	# some ao encostar em alguem. Armadilha ja registrada no `sala_prototipo`.
	if p is Area2D:
		(p as Area2D).monitoring = false
		(p as Area2D).monitorable = false
	for filho in p.get_children():
		var forma := filho as CollisionShape2D
		if forma != null:
			forma.set_deferred("disabled", true)


## A camera da cena, em ZOOM 1.0.
##
## Ela e propria e nao a do jogador pelo mesmo motivo do `sala_prototipo`: a do
## jogo e clampada e nunca mostra mais de uma parede. Mas aqui ela nao precisa de
## zoom nenhum -- a sala inteira mais a faixa cabem em 608x480 dentro de 960x544
## --, e isso e o ponto: julgar silhueta com zoom fracionario e julgar uma imagem
## borrada.
func _montar_camera() -> void:
	if _player != null:
		var dele := _player.get_node_or_null("Camera") as Camera2D
		if dele != null:
			dele.enabled = false
	_camera = Camera2D.new()
	_camera.name = "CameraDaCena"
	_camera.zoom = Vector2.ONE
	_camera.position = _sala.global_position
	add_child(_camera)
	_camera.make_current()


func _process(delta: float) -> void:
	if _restantes.is_empty():
		return
	_t += delta
	if _t < ESPERA:
		return
	_t = 0.0
	var nome: String = _restantes.pop_front()
	if _player != null:
		_player.position = POSTOS[nome]
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var caminho := "%s/paredes_%s.png" % [SAIDA, nome]
	get_viewport().get_texture().get_image().save_png(caminho)
	print("capturado: %s" % ProjectSettings.globalize_path(caminho))
	if _restantes.is_empty():
		_conferir()
		get_tree().quit()


## O que a foto TEM de conter. Conferido em vez de confiado a quem edita a cena.
##
## A lista e curta de proposito: esta cena e sobre arquitetura. Canto ainda nao
## esta aqui porque canto ainda nao existe -- ele e a PAREDE 06, e quando chegar
## esta conferencia cresce com ele.
func _conferir() -> void:
	var faltando: Array[String] = []
	if _sala.get_node_or_null("Chao") == null:
		faltando.append("chao")
	var fita := _sala.get_node_or_null("ParedeModulos")
	if fita == null or fita.get_child_count() == 0:
		faltando.append("fita de parede")
	var abertas := 0
	for filho in _sala.get_node("Portas").get_children():
		var porta := filho as Porta
		if porta != null and not porta.esta_selada():
			abertas += 1
	if abertas != 2:
		faltando.append("duas portas (achei %d)" % abertas)
	if _sala.get_node_or_null("Projetil_player") == null:
		faltando.append("projetil do jogador")
	if _sala.get_node_or_null("Projetil_hostil") == null:
		faltando.append("projetil hostil")

	if faltando.is_empty():
		print("a caixa esta montada: chao, fita de parede, duas portas e dois projeteis")
	else:
		print("teste_paredes: FALTANDO %s" % ", ".join(faltando))

	_medir_profundidade()


## AS DUAS REGUAS DO PLANO, medidas na propria captura.
##
## O §49 e o §50 pedem a mesma prova por dois caminhos: reduzida a 25% a imagem
## ainda tem de ler como moldura + cavidade, e sem cor a profundidade tem de
## continuar existindo. As duas respondem "a profundidade vem de VALOR e forma, e
## nao da paleta nem do tamanho".
##
## Elas sao medidas e nao olhadas porque o olho se acostuma: quem passou a tarde
## ajustando a parede ja nao ve o mosaico. E o mesmo argumento que fez a densidade
## e o gamut virarem numero em vez de conferencia.
##
## O metodo: uma COLUNA de pixels pelo meio da sala, de cima para baixo, atravessa
## exterior -> topo -> face -> piso. Se as quatro leem como valores separaveis, a
## cavidade existe. A reducao a 25% e feita por media de area, que e exatamente o
## que o olho faz de longe.
func _medir_profundidade() -> void:
	var imagem := get_viewport().get_texture().get_image()
	if imagem == null or imagem.is_empty():
		print("teste_paredes: sem imagem para medir")
		return
	var cheia := _patamares_medianos(imagem, 1)
	var reduzida := _patamares_medianos(_reduzir(imagem, 4), 4)
	var amplitude := _amplitude(imagem)
	print("profundidade: %d superficies na coluna; a 25%%, %d; amplitude %.3f"
		% [cheia, reduzida, amplitude])
	if cheia < PATAMARES_MINIMOS:
		print("teste_paredes: REPROVA -- a coluna nao separa exterior, parede e piso")
	elif reduzida < PATAMARES_MINIMOS:
		print("teste_paredes: REPROVA na MINIATURA -- a 25%% a sala volta a ser uma massa so")
	elif amplitude < AMPLITUDE_MINIMA:
		print("teste_paredes: REPROVA na AMPLITUDE -- %.3f contra o minimo de %.3f: as"
			% [amplitude, AMPLITUDE_MINIMA]
			+ " superficies existem mas estao todas na mesma tinta")
	else:
		print("teste_paredes: a cavidade sobrevive a miniatura e ao grayscale (amplitude %.3f)"
			% amplitude)


## Quantos PATAMARES de valor a coluna central atravessa.
##
## Patamar e nao TRANSICAO, e a diferenca e o que separa a regua de um carimbo. A
## primeira versao contava toda mudanca de valor acima do degrau e devolvia 81 --
## ela estava contando a borda de cada placa do piso, e teria aprovado tambem a
## parede lisa que abriu o epico.
##
## Um patamar so conta quando ele SUSTENTA o valor por `ALTURA_DE_PATAMAR` pixels.
## Rebite, junta e contorno de placa duram dois ou tres, e por isso somem da
## conta; exterior, topo, face e piso duram dezenas.
##
## Conta em grayscale (o `v` do HSV): e a metade do §50 que nao precisa de uma
## segunda captura.
## A MEDIANA de quatro colunas DENTRO da sala.
##
## As fracoes sao da SALA e nao da imagem: a sala nao preenche o quadro (ha
## exterior em volta, que e o ponto), e uma coluna em 18% da imagem cai no vazio
## e mede um patamar so. E elas fogem do meio, porque as portas nascem centradas
## nos lados -- a coluna central atravessa o VAO e nao a parede.
func _patamares_medianos(imagem: Image, escala: int) -> int:
	var contagens: Array[int] = []
	for fracao in [0.30, 0.38, 0.62, 0.70]:
		contagens.append(_patamares_na_coluna(imagem, int(imagem.get_width() * fracao), escala))
	contagens.sort()
	return contagens[contagens.size() / 2]


## Quantos PATAMARES de valor a coluna atravessa.
##
## Patamar e nao TRANSICAO, e a diferenca separa a regua de um carimbo. A
## primeira versao contava toda mudanca de valor acima do degrau e devolvia 81 --
## ela contava a borda de cada placa do piso, e aprovaria tambem a parede lisa que
## abriu o epico.
##
## E a coluna e SUAVIZADA antes, com mediana movel. Sem isso a parede texturizada
## nunca sustenta um patamar: ela tem 57% de densidade, entao o valor oscila mais
## que o degrau a cada poucos pixels e a superficie inteira se dissolve em ruido.
## O olho integra a distancia; a regua tem de integrar tambem, senao ela reprova
## justamente a superficie que TEM material.
##
## Conta em grayscale (o `v` do HSV): e a metade do §50 que dispensa uma segunda
## captura.
func _patamares_na_coluna(imagem: Image, x: int, escala: int) -> int:
	var altura := imagem.get_height()
	var suave := _suavizar(imagem, x, maxi(9 / escala, 3))
	var minimo := maxi(ALTURA_DE_PATAMAR / escala, 2)

	var patamares: Array[float] = []
	var inicio := 0
	var soma := 0.0
	var referencia := suave[0]
	for y in altura + 1:
		var v := suave[mini(y, altura - 1)]
		if y < altura and absf(v - referencia) < DEGRAU_MINIMO:
			soma += v
			continue
		var comprimento := y - inicio
		if comprimento >= minimo:
			patamares.append(soma / maxf(float(comprimento), 1.0))
		inicio = y
		soma = v
		referencia = v

	# Dois patamares do mesmo valor sao a MESMA superficie vista duas vezes -- o
	# exterior aparece em cima e embaixo. O que interessa e quantos valores
	# DISTINTOS a coluna atravessa.
	var distintos: Array[float] = []
	for p in patamares:
		var novo := true
		for d in distintos:
			if absf(p - d) < DEGRAU_MINIMO:
				novo = false
				break
		if novo:
			distintos.append(p)
	return distintos.size()


## Mediana movel na coluna. Mediana e nao media: ela ignora o rebite isolado sem
## arrastar a borda da superficie, que e o que uma media faria.
func _suavizar(imagem: Image, x: int, janela: int) -> Array[float]:
	var altura := imagem.get_height()
	var cru: Array[float] = []
	for y in altura:
		cru.append(imagem.get_pixel(x, y).v)
	var suave: Array[float] = []
	for i in altura:
		var a := maxi(0, i - janela / 2)
		var b := mini(altura, i + janela / 2 + 1)
		var fatia := cru.slice(a, b)
		fatia.sort()
		suave.append(fatia[fatia.size() / 2])
	return suave


## A DISTANCIA entre a superficie mais clara e a mais escura da coluna.
##
## A CONTAGEM SOZINHA E UM CARIMBO, e isso foi medido: com a arte de ANTES do
## epico -- topo em 0,161 contra piso em 0,122 -- a coluna ainda devolvia quatro
## patamares, porque 0,039 passa de raspao do degrau minimo de 0,036. A regua
## dizia "a cavidade sobrevive" sobre exatamente a imagem que abriu o epico.
##
## O que separa uma sala rasa de uma funda nao e quantas superficies existem: e o
## quanto elas se afastam. Medido em A/B na mesma cena: 0,192 antes, 0,388 depois.
func _amplitude(imagem: Image) -> float:
	var maior := 0.0
	for fracao in [0.30, 0.38, 0.62, 0.70]:
		var suave := _suavizar(imagem, int(imagem.get_width() * fracao), 9)
		var alto := 0.0
		var baixo := 1.0
		for v in suave:
			alto = maxf(alto, v)
			baixo = minf(baixo, v)
		maior = maxf(maior, alto - baixo)
	return maior


## Media de area, que e o que o olho faz de longe -- e o que uma miniatura faz.
func _reduzir(imagem: Image, fator: int) -> Image:
	var menor := imagem.duplicate() as Image
	menor.resize(maxi(imagem.get_width() / fator, 1), maxi(imagem.get_height() / fator, 1),
		Image.INTERPOLATE_LANCZOS)
	return menor
