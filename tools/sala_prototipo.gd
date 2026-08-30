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
## O conteudo obrigatorio, do plano:
##   chao, quatro paredes, porta, caixa, terminal, tubulacao, maquina,
##   a personagem, um Drone Aranha, um projetil do jogador, um projetil inimigo.
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

## As celulas do atlas volumetrico que o plano exige em quadro, por nome.
## Fixas e nao sorteadas: o teste tem de mostrar SEMPRE as mesmas pecas, senao
## duas rodadas nao sao comparaveis.
const PROPS_EM_QUADRO := [
	{"nome": "caixa", "regiao": Rect2i(0, 0, 32, 64), "em": Vector2(-300, -196)},
	{"nome": "terminal", "regiao": Rect2i(32, 0, 32, 64), "em": Vector2(-190, -200)},
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
	_projetil(Vector2(90, LINHA_DOS_ATORES + 34.0), true)


func _projetil(onde: Vector2, hostil: bool) -> void:
	var p := CENA_PROJETIL.instantiate()
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


func _process(delta: float) -> void:
	_t += delta
	if _feito or _t < 0.8:
		return
	_feito = true
	_capturar()
	get_tree().quit()


func _capturar() -> void:
	await RenderingServer.frame_post_draw
	var caminho := "%s/prototipo_andar1.png" % SAIDA
	get_viewport().get_texture().get_image().save_png(caminho)
	print("capturado: %s" % ProjectSettings.globalize_path(caminho))
