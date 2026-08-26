extends TesteBase
## Confere o sprite direcional do Drone Aranha -- os arquivos, o mapa de
## angulos e o canal de cor.
##
## Esta suite existe porque **nada disto avisa quando quebra**. Trocar duas
## rotacoes de lugar faz o inimigo encarar o lado errado; declarar 8 quadros
## numa fita de 9 mostra fatias cortadas de dois quadros ao mesmo tempo; e o
## tint de Hack num sprite vira no-op silencioso se o canal de cor escolhido for
## o errado. Nenhum dos tres imprime uma linha no console, e o teste de fumaca
## nao alcanca nenhum deles: ele mata todo inimigo a cada 0,12 s e nunca chega a
## ver um ciclo de caminhada terminar.
##
## O caso do tint e o que separa "esta pintando" de "virou no-op": ele e a unica
## prova de que `InimigoBase._pintar_corpo` encontrou o sprite, ja que um
## `Visual/Corpo` ausente e um `Visual/Corpo` que nao aceita cor se comportam
## exatamente igual em tela -- sem nada.

const CENA_DRONE := preload("res://src/enemies/drone_aranha.tscn")

## Lado da moldura de todo sprite do projeto, parado ou andando. Uma so para os
## dois conjuntos: e o alinhamento entre eles que impede o bicho de saltar de
## lugar ao comecar a andar. Quem gera e tools/sprites/gerar_sprites.py.
const LADO_SPRITE := 80.0

## Longe da origem, pela mesma razao de teste_hack: o grupo "inimigo" e global e
## inimigos de outras suites ainda nao coletados ficam quase todos perto de
## (0,0).
const LONGE := Vector2(6000, 6000)

## Passo do relogio manual, em segundos.
const PASSO := 0.1


func nome() -> String:
	return "SpriteDirecional"


func executar() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)

	var drone := CENA_DRONE.instantiate() as InimigoBase
	raiz.add_child(drone)
	drone.global_position = LONGE

	var sprite := drone.get_node_or_null("Visual/Corpo") as SpriteDirecional
	ok(sprite != null, "o Drone Aranha tem um Visual/Corpo direcional")
	if sprite != null:
		_o_conjunto_de_arquivos(sprite)
		var esperado := _o_mapa_de_angulos()
		_textura_e_hframes_andam_juntos(sprite, esperado)
	_o_tint_alcanca_o_sprite(drone, sprite)

	# free() e nao queue_free(): a suite roda inteira num frame, entao um
	# queue_free deixaria o drone no grupo "inimigo" para os casos das outras
	# suites acharem.
	raiz.free()


## As oito paradas e as oito fitas, medidas em disco.
##
## A largura da fita e o que mais importa: ela e lida por `hframes`, e se a
## contagem declarada nao bater com o arquivo o Sprite mostra fatias cortadas --
## sem erro no console, sem nada que aponte para a cena. Multiplicar
## `quadros_andando` pelo lado e o que amarra os dois.
func _o_conjunto_de_arquivos(s: SpriteDirecional) -> void:
	igual(s.sprites_parado.size(), Direcoes.TOTAL, "tem as %d rotacoes paradas" % Direcoes.TOTAL)
	igual(s.sprites_andando.size(), Direcoes.TOTAL, "tem as %d fitas de caminhada" % Direcoes.TOTAL)
	ok(s.quadros_andando >= 2, "um ciclo precisa de ao menos 2 quadros")
	ok(s.fps_andando > 0.0, "o ciclo tem cadencia positiva")
	ok(s.tem_ciclo(), "o conjunto declara ter ciclo de caminhada")

	_medir(s.sprites_parado, Vector2(LADO_SPRITE, LADO_SPRITE), "rotacao")
	_medir(
		s.sprites_andando,
		Vector2(LADO_SPRITE * float(s.quadros_andando), LADO_SPRITE),
		"fita"
	)


## Cada textura tem o tamanho certo, nao e nula, e nao repete outro arquivo.
## Repetir e o erro de copiar-colar que deixa duas direcoes identicas, e nada
## mais no jogo acusa.
func _medir(texturas: Array[Texture2D], tamanho: Vector2, rotulo: String) -> void:
	var vistas: Array[String] = []
	for i in texturas.size():
		var t: Texture2D = texturas[i]
		if t == null:
			ok(false, "%s %d nao e nula" % [rotulo, i])
			continue
		igual(t.get_size(), tamanho, "%s %d mede %s" % [rotulo, i, tamanho])
		ok(
			not vistas.has(t.resource_path),
			"%s %d nao repete outro arquivo (%s)" % [rotulo, i, t.resource_path.get_file()]
		)
		vistas.append(t.resource_path)


## Os oito angulos que importam, no sentido horario a partir do leste.
##
## `+y` aponta para BAIXO, entao sul e POSITIVO e norte e NEGATIVO -- e o sinal
## trocado aqui e exatamente o bug que este caso existe para pegar. Como
## `Direcoes` e a mesma fonte que `DadosPersonagem` usa, este caso tambem guarda
## o Player contra uma regressao na extracao.
func _o_mapa_de_angulos() -> Array:
	var esperado := [
		[Vector2.RIGHT, 0, "leste"],
		[Vector2(1, 1), 1, "sudeste"],
		[Vector2.DOWN, 2, "sul"],
		[Vector2(-1, 1), 3, "sudoeste"],
		[Vector2.LEFT, 4, "oeste"],
		[Vector2(-1, -1), 5, "noroeste"],
		[Vector2.UP, 6, "norte"],
		[Vector2(1, -1), 7, "nordeste"],
	]
	for caso in esperado:
		igual(
			Direcoes.indice(caso[0]), caso[1],
			"olhar para %s escolhe o quadro %d" % [caso[2], caso[1]]
		)

	# Um angulo entre dois passos cai no mais proximo, e nao num terceiro.
	igual(
		Direcoes.indice(Vector2.RIGHT.rotated(deg_to_rad(20.0))), 0,
		"20 graus ainda e leste (o passo e de 45)"
	)
	igual(Direcoes.indice(Vector2.ZERO), 2, "direcao nula cai no frontal")
	return esperado


## `texture`, `hframes` e `frame` trocam sempre juntos.
##
## E a armadilha que o GEMINI.md ja registra e a unica que a medicao de arquivo
## nao alcanca: uma fita com hframes 1 desenha os nove quadros espremidos no
## lugar do inimigo, e uma pose parada com hframes 9 mostra um nono dele.
func _textura_e_hframes_andam_juntos(s: SpriteDirecional, esperado: Array) -> void:
	for caso in esperado:
		var direcao: Vector2 = caso[0]
		var indice: int = caso[1]

		s.apontar(direcao, false, 0.0)
		ok(
			s.texture == s.sprites_parado[indice],
			"parado para %s usa a rotacao %d" % [caso[2], indice]
		)
		igual(s.hframes, 1, "parado para %s le a textura como um quadro so" % caso[2])

		s.apontar(direcao, true, 0.0, direcao)
		ok(
			s.texture == s.sprites_andando[indice],
			"andando para %s usa a fita %d" % [caso[2], indice]
		)
		igual(
			s.hframes, s.quadros_andando,
			"andando para %s le a fita em %d quadros" % [caso[2], s.quadros_andando]
		)

	_o_ciclo_nao_sai_da_fita(s)


## O ciclo avanca, volta para o inicio, e nunca indexa fora da fita -- nem
## andando de re, que e o que o knockback faz enquanto o drone encara o alvo.
## Sem o `fposmod`, o sentido negativo devolve quadro negativo.
func _o_ciclo_nao_sai_da_fita(s: SpriteDirecional) -> void:
	var quadros: Array[int] = []
	for i in 40:
		s.apontar(Vector2.DOWN, true, 1.0 / 30.0, Vector2.DOWN)
		quadros.append(s.frame)
	for i in 40:
		s.apontar(Vector2.DOWN, true, 1.0 / 30.0, Vector2.UP)
		quadros.append(s.frame)

	var dentro := true
	var maior := 0
	for q in quadros:
		if q < 0 or q >= s.quadros_andando:
			dentro = false
		maior = maxi(maior, q)
	ok(dentro, "o ciclo nunca indexa fora da fita, nos dois sentidos")
	ok(maior > 0, "o ciclo de fato avanca de quadro")


## O tint de Hack tem de CHEGAR num corpo que e sprite.
##
## Num Polygon2D ele vai em `color`; num Sprite2D nao existe `color`, e o
## equivalente e `self_modulate`. Se `InimigoBase` escolher o canal errado -- ou
## se o cast de `_corpo` falhar -- o Hack continua "funcionando" em toda a
## logica e some so da tela, que e o pior lugar para um bug se esconder.
func _o_tint_alcanca_o_sprite(drone: InimigoBase, sprite: SpriteDirecional) -> void:
	if sprite == null:
		return
	igual(sprite.self_modulate, Color.WHITE, "sem nada acontecendo o sprite fica neutro")

	drone.aplicar_hack(4.0)
	ok(drone.esta_hackeado(), "o drone aceita ser hackeado")
	ok(sprite.self_modulate != Color.WHITE, "o tint de Hack chega ao sprite")
	ok(sprite.self_modulate.g > sprite.self_modulate.r, "o tint de Hack puxa para o verde")

	# O clarao de dano mora no modulate do PAI. Sao dois canais que nao podem se
	# cruzar: se o clarao escrevesse aqui, o primeiro tiro apagaria a marca.
	drone.receber_dano(1)
	ok(sprite.self_modulate != Color.WHITE, "o clarao de dano nao apaga o tint de Hack")

	# Expira pelo caminho de verdade -- o `_t_hack` do `_physics_process` --, e
	# nao chamando `_pintar_hack(false)` na mao: aquele so devolve o canal se o
	# Hack ja tiver acabado, entao chamar direto testaria uma ordem que nao
	# acontece no jogo e passaria verde com a marca ainda pintada.
	_avancar(drone, 4.2)
	ok(not drone.esta_hackeado(), "a marca expira sozinha")
	igual(sprite.self_modulate, Color.WHITE, "sair do Hack devolve o sprite ao neutro")


## Avanca o relogio do inimigo na mao. O _physics_process nao roda numa suite
## sincrona, e esperar frames de verdade tornaria a suite lenta e instavel.
func _avancar(inimigo: InimigoBase, segundos: float) -> void:
	for i in int(ceil(segundos / PASSO)):
		inimigo._physics_process(PASSO)
