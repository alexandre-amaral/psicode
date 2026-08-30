extends Node
## A SALA PROTOTIPO do andar 1 industrial -- o teste visual obrigatorio.
##
## Decisao que esta ferramenta carrega: **nenhum pacote de assets e produzido
## antes desta sala responder sim as dez perguntas.** O plano de identidade
## visual do andar 1 crava isso com todas as letras ("nao produzir dezenas de
## assets antes dessa sala estar correta"), e a razao e economica: material
## errado descoberto no asset numero quarenta custa quarenta refacoes.
##
## Ela NAO e o `capturar.tscn`. Aquele roda a run inteira e fotografa o que
## calhar de estar em tela; este monta uma composicao FIXA, com um exemplar de
## cada coisa que precisa conviver, e sempre o mesmo enquadramento. E o que
## permite comparar duas versoes da arte lado a lado sem o ruido de uma run
## diferente.
##
## O conteudo obrigatorio (LTD 14 mais o plano do andar 1). A lista existe para
## ser conferida, e o `_conferir_conteudo()` no fim deste arquivo a cobra em vez
## de confiar em quem edita a cena:
##
##   chao, as QUATRO paredes, porta, caixa, mesa, terminal, tubulacao, maquina,
##   pickup, telegrafo, a personagem, um inimigo, um projetil do jogador e um
##   projetil inimigo.
##
## A camera e PROPRIA e afastada, e nao a do jogador. Nao e trapaca: o que esta
## cena valida e se todos os elementos compartilham a mesma CAMERA IMAGINARIA --
## se a caixa parece vista a 25 graus e a mesa a 60, uma das duas e refeita. Isso
## e uma pergunta sobre a arte, e responde-la exige ver tudo junto. Com a camera
## do jogo nao da: o clamp folga so `Sala.ESPESSURA_PAREDE` alem do contorno,
## entao numa sala do tamanho da tela nunca ha mais de uma parede em quadro.
##
## Uso: godot --path . tools/sala_prototipo.tscn --resolution 960x544
## Sai em user://capturas/prototipo_andar1.png

const SAIDA := "user://capturas"
const CENA_SALA := preload("res://src/mapa/sala_1_retangular.tscn")
const CENA_PLAYER := preload("res://src/player/player.tscn")
const CENA_DRONE := preload("res://src/enemies/drone_aranha.tscn")
const CENA_PROJETIL := preload("res://src/projectiles/projetil.tscn")
const DADOS_COMBATE := preload("res://src/mapa/tipo_combate.tres")
const PERSONAGEM := preload("res://src/player/personagem_raven.tres")
const ARMA_PLAYER := preload("res://src/weapons/pistola.tres")
const CENA_PICKUP := preload("res://src/items/pickup_item.tscn")
const CENA_TELEGRAFO := preload("res://src/enemies/area_de_perigo.tscn")
const ITEM_AMOSTRA := preload("res://src/items/implante_firewall.tres")

## Zoom da camera propria. 0.72 poe os 1088x672 de sala mais parede dentro dos
## 960x544 da tela com folga -- e a folga importa, porque e nela que se ve se a
## parede termina onde deveria.
const ZOOM_DA_CENA := 0.72

## O telegrafo tem de estar no AUGE do aviso na hora da foto, e nao no comeco
## dele. `AreaDePerigo` sobe a opacidade ao longo de `tempo_aviso`: congelado em
## t=0 ele sai quase invisivel, e a foto diria que o aviso e fraco quando na
## verdade ela pegou o primeiro frame.
##
## Entao o aviso dura pouco mais que a espera da captura, e a foto sai perto do
## fim da rampa -- que e o instante em que o jogador de fato le o perigo.
const AVISO_DO_TELEGRAFO := 3.0
## Espera antes de fotografar. Fica dentro de `AVISO_DO_TELEGRAFO` de proposito:
## passar dele faria a area estourar e a foto perder o telegrafo inteiro.
const ESPERA_DA_FOTO := 2.4

## As celulas do atlas volumetrico que o plano exige em quadro, por nome.
## Fixas e nao sorteadas: o teste tem de mostrar SEMPRE as mesmas pecas, senao
## duas rodadas nao sao comparaveis.
const PROPS_EM_QUADRO := [
	{"nome": "caixa", "regiao": Rect2i(0, 0, 32, 64), "em": Vector2(-300, -196)},
	{"nome": "terminal", "regiao": Rect2i(32, 0, 32, 64), "em": Vector2(-190, -200)},
	{"nome": "mesa", "regiao": Rect2i(64, 0, 32, 64), "em": Vector2(-80, -200)},
	{"nome": "tubulacao", "regiao": Rect2i(160, 0, 32, 64), "em": Vector2(230, -200)},
	{"nome": "maquina", "regiao": Rect2i(0, 64, 64, 64), "em": Vector2(340, -190)},
]

## Onde a composicao inteira se planta: colada na parede NORTE.
##
## Nao e enquadramento bonito, e o unico que responde a pergunta 8 ("as paredes
## parecem ter altura?"). O clamp da camera folga so `Sala.ESPESSURA_PAREDE`
## alem do contorno, entao numa sala do tamanho da tela ela desliza 64 px por
## eixo -- com o jogador no centro NENHUMA parede entra no quadro, e o teste
## fotografaria so o chao. A divida esta anotada em
## `GerenciadorMapa.margem_da_parede()`; aqui ela e contornada de proposito,
## plantando os atores onde a parede aparece.
const LINHA_DOS_ATORES := -150.0

var _t: float = 0.0
var _feito := false
var _sala: Sala = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAIDA)
	# A escolha de personagem normalmente vem da tela de selecao. Aqui e fixa,
	# porque o teste compara ARTE e nao pode mudar de protagonista entre rodadas.
	GameState.personagem = PERSONAGEM

	_sala = CENA_SALA.instantiate() as Sala
	# ANTES do add_child: e o _ready da sala que veste o visual e monta a
	# decoracao, e ele so ve os dados se ja estiverem la.
	_sala.definir_visual(DADOS_COMBATE)
	add_child(_sala)

	_montar_props_fixos()
	_montar_atores()
	_montar_pickup()
	_montar_telegrafo()
	_montar_camera()


## Os props do plano, em posicao fixa, montados com a MESMA regra da sala:
## origem na base, sprite deslocado -altura/2, sombra no pe. Se a regra mudar em
## `Sala`, esta composicao passa a mentir -- por isso ela replica a conta em vez
## de inventar outra.
func _montar_props_fixos() -> void:
	var atlas: Texture2D = DADOS_COMBATE.atlas_props_volume
	if atlas == null:
		push_warning("prototipo: tipo_combate nao tem atlas volumetrico.")
		return
	for item: Dictionary in PROPS_EM_QUADRO:
		var regiao: Rect2i = item["regiao"]
		var corpo := Node2D.new()
		corpo.name = "Prop_%s" % item["nome"]
		corpo.position = item["em"]
		_sala.add_child(corpo)

		corpo.add_child(Sombra.criar(float(regiao.size.x) * 0.72, 0.0))

		var sprite := Sprite2D.new()
		sprite.texture = atlas
		sprite.region_enabled = true
		sprite.region_rect = Rect2(regiao)
		sprite.position = Vector2(0.0, -float(regiao.size.y) * 0.5)
		corpo.add_child(sprite)


## Personagem, inimigo e os DOIS projeteis.
##
## Os projeteis sao o item mais importante do quadro e o mais facil de esquecer:
## a pergunta 6 do plano e "os projeteis continuam faceis de identificar?", e ela
## nao tem resposta sem um projetil de cada lado em cima da arte nova.
func _montar_atores() -> void:
	var player := CENA_PLAYER.instantiate()
	player.position = Vector2(-40, LINHA_DOS_ATORES)
	_sala.add_child(player)

	var drone := CENA_DRONE.instantiate()
	drone.position = Vector2(150, LINHA_DOS_ATORES - 20.0)
	_sala.add_child(drone)

	# Um de cada lado, parados no ar: o teste e de LEITURA, entao eles nao
	# precisam voar -- precisam estar sobre o chao novo para se comparar com ele.
	_projetil(Vector2(20, LINHA_DOS_ATORES - 6.0), false)
	_projetil(Vector2(96, LINHA_DOS_ATORES + 58.0), true)


## O pickup. Ele entra na lista da LTD 14 por um motivo especifico: e o unico
## elemento do quadro que o jogador PRECISA distinguir do cenario a distancia --
## um implante no chao que pareca prop e um upgrade perdido.
func _montar_pickup() -> void:
	var pickup := CENA_PICKUP.instantiate()
	pickup.position = Vector2(-180, 60)
	if "dados" in pickup:
		pickup.dados = ITEM_AMOSTRA
	_sala.add_child(pickup)


## O telegrafo, e ele e o item mais importante desta cena.
##
## Ele e a coisa que o cenario NUNCA pode cobrir -- a trava do GDD e a regra que
## a camada Foreground existe para respeitar. Poe-lo aqui e o que transforma
## "nenhum telegrafo fica coberto" de promessa em foto.
##
## Nasce no container da SALA e nao como filho de quem o criou: filha do
## invocador, a area anda junto com ele, e aviso no chao que se move e aviso que
## mente. Armadilha ja registrada no GEMINI.md.
func _montar_telegrafo() -> void:
	var area := CENA_TELEGRAFO.instantiate()
	if "tempo_aviso" in area:
		area.tempo_aviso = AVISO_DO_TELEGRAFO
	_sala.add_child(area)
	if area.has_method("configurar"):
		area.configurar(_sala.global_position + Vector2(60, 90), 64.0, 1)
	else:
		area.position = Vector2(60, 90)


## A camera da cena. Substitui a do jogador, que existe para jogar e nao para
## conferir arte.
func _montar_camera() -> void:
	var player := _sala.get_node_or_null("Player")
	if player == null:
		for filho in _sala.get_children():
			if filho.name.begins_with("Player") or filho.is_in_group("player"):
				player = filho
				break
	if player != null:
		var dele := player.get_node_or_null("Camera") as Camera2D
		if dele != null:
			dele.enabled = false

	var camera := Camera2D.new()
	camera.name = "CameraDaCena"
	camera.zoom = Vector2(ZOOM_DA_CENA, ZOOM_DA_CENA)
	camera.position = Vector2.ZERO
	_sala.add_child(camera)
	camera.make_current()


## Cobra a lista da LTD 14 em vez de confiar em quem editar esta cena depois.
##
## Uma cena de validacao que perde um elemento em silencio e pior que nenhuma:
## ela continua produzindo captura, alguem olha, aprova, e o elemento que
## faltava era justamente o que quebraria. Imprime e nao trava -- ela e
## ferramenta, nao portao.
func _conferir_conteudo() -> void:
	var faltando: Array[String] = []
	var props := 0
	var projeteis := 0
	for filho in _sala.get_children():
		if filho.name.begins_with("Prop_"):
			props += 1
		if filho.name.begins_with("Projetil_"):
			projeteis += 1
	if props < 5:
		faltando.append("props (%d de 5)" % props)
	if projeteis < 2:
		faltando.append("projeteis (%d de 2)" % projeteis)
	if _sala.get_node_or_null("CameraDaCena") == null:
		faltando.append("camera da cena")
	if _sala.get_node_or_null("ParedeFace") == null:
		faltando.append("face da parede")
	if _sala.get_node_or_null("ParedeTopo") == null:
		faltando.append("topo da parede")
	var tem_telegrafo := false
	var tem_pickup := false
	for filho in _sala.get_children():
		if filho.has_method("configurar") and "tempo_aviso" in filho:
			tem_telegrafo = true
		if "dados" in filho and "gira" in filho:
			tem_pickup = true
	if not tem_telegrafo:
		faltando.append("telegrafo")
	if not tem_pickup:
		faltando.append("pickup")

	if faltando.is_empty():
		print("conteudo da LTD 14: completo")
	else:
		push_warning("prototipo: faltando %s" % ", ".join(faltando))
		print("conteudo da LTD 14: FALTANDO %s" % ", ".join(faltando))


func _projetil(onde: Vector2, hostil: bool) -> void:
	var p := CENA_PROJETIL.instantiate()
	p.name = "Projetil_%s" % ("hostil" if hostil else "player")
	_sala.add_child(p)
	# add_child ANTES de configurar, como a Arma faz -- o `_ready` do projetil
	# roda primeiro e quem pinta e dimensiona e chamado nas duas pontas.
	if p.has_method("configurar"):
		p.configurar(onde, Vector2.RIGHT, ARMA_PLAYER, hostil)
	p.position = onde
	# Parar o projetil: o quadro e uma foto, e um tiro que anda sai de cena
	# antes da captura.
	p.set_physics_process(false)
	p.set_process(false)
	# E DESARMAR a colisao. Parar o processamento nao basta: o projetil continua
	# no espaco de fisica e some ao encostar em alguem -- foi o que aconteceu
	# quando a espera da foto subiu para 2,4 s, e quem pegou foi o
	# `_conferir_conteudo`, nao o olho. Uma foto com um projetil a menos passaria
	# despercebida justamente na pergunta que ela existe para responder.
	if p is Area2D:
		(p as Area2D).monitoring = false
		(p as Area2D).monitorable = false
	for filho in p.get_children():
		var forma := filho as CollisionShape2D
		if forma != null:
			forma.set_deferred("disabled", true)


func _process(delta: float) -> void:
	_t += delta
	if _feito or _t < ESPERA_DA_FOTO:
		return
	_feito = true
	_conferir_conteudo()
	_capturar()
	get_tree().quit()


func _capturar() -> void:
	await RenderingServer.frame_post_draw
	var caminho := "%s/prototipo_andar1.png" % SAIDA
	get_viewport().get_texture().get_image().save_png(caminho)
	print("capturado: %s" % ProjectSettings.globalize_path(caminho))
