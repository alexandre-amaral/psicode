extends TesteBase
## Confere os DadosPersonagem reais do projeto.
##
## Mesma pergunta que teste_dados_arma faz das armas: o dado que alimenta o jogo
## esta bem formado? Personagem e escolhido antes da run e nao tem como ser
## trocado depois -- um .tres torto aqui nao trava nada, so entrega uma run
## inteira com a arma errada ou um card em branco.
##
## A trava que mais importa e a da arma inicial nao estar no pool de loot. A
## arma de personagem ocupa o slot 0 e nunca sai; se ela tambem pudesse cair na
## sala de arma, o jogador ganharia de graca o que define outro personagem.

const PASTA := "res://src/player/"
const POOL := "res://src/items/pool_padrao.tres"

## Mesmo teto das outras descricoes que vao para a tela.
const MAXIMO_DESCRICAO := 300

## Lado da moldura de todo sprite de personagem, parado ou andando. Uma so para
## os dois conjuntos: e o alinhamento entre eles que impede a personagem de
## saltar de lugar ao comecar a andar, e duas molduras conviverem seria o convite
## para esse bug voltar. Quem gera e tools/sprites/gerar_sprites.py.
const LADO_SPRITE := 80.0


func nome() -> String:
	return "Personagem"


func executar() -> void:
	_os_personagens_do_projeto()


func _os_personagens_do_projeto() -> void:
	var pasta := DirAccess.open(PASTA)
	if pasta == null:
		ok(false, "src/player/ pode ser aberta")
		return

	var pool: PoolLoot = load(POOL)
	var achados := 0

	for arquivo in pasta.get_files():
		if not arquivo.begins_with("personagem_") or not arquivo.ends_with(".tres"):
			continue
		achados += 1
		var p: DadosPersonagem = load(PASTA + arquivo)
		if p == null:
			ok(false, "%s carrega" % arquivo)
			continue

		ok(not String(p.id).is_empty(), "%s tem id" % arquivo)
		ok(not p.nome.is_empty(), "%s tem nome" % arquivo)
		ok(not p.papel.is_empty(), "%s tem papel para o card" % arquivo)
		ok(not p.descricao.is_empty(), "%s tem descricao" % arquivo)
		ok(
			p.descricao.length() <= MAXIMO_DESCRICAO,
			"%s: descricao cabe no card (%d de %d)" % [arquivo, p.descricao.length(), MAXIMO_DESCRICAO]
		)
		ok(p.cor.a > 0.0, "%s tem cor visivel" % arquivo)

		_o_conjunto_de_sprites(p, arquivo)

		ok(p.arma_inicial != null, "%s tem arma inicial" % arquivo)
		if p.arma_inicial != null:
			# A arma do slot 0 nunca e descartada. Reserva finita deixaria o
			# personagem sem arma no meio da run, e o GDD promete o contrario.
			ok(
				p.arma_inicial.municao_infinita(),
				"%s: a arma inicial tem reserva infinita" % arquivo
			)
			if pool != null:
				var no_pool := false
				for a in pool.armas_validas():
					if a.resource_path == p.arma_inicial.resource_path:
						no_pool = true
				ok(not no_pool, "%s: a arma inicial nao cai como loot" % arquivo)

		# Coerencia do Hack: os numeros so precisam fazer sentido em quem tem.
		if p.tem_hack():
			entre(p.hack_chance, 0.0, 1.0, "%s: chance de Hack e uma probabilidade" % arquivo)
			ok(p.hack_duracao > 0.0, "%s: o Hack dura algum tempo" % arquivo)
			ok(p.hack_bonus_dano > 1.0, "%s: o Hack aumenta o dano recebido" % arquivo)
			entre(
				p.hack_chance_propagacao, 0.0, 1.0,
				"%s: chance de propagacao e uma probabilidade" % arquivo
			)
			ok(p.hack_raio_propagacao > 0.0, "%s: a propagacao tem raio" % arquivo)

	# Guarda contra a suite virar decoracao, como em teste_efeito_item.
	ok(achados >= 2, "a varredura achou os personagens (%d encontrados)" % achados)


## As oito rotacoes e o mapa de angulo -> quadro.
##
## O mapa e o que mais precisa de teste e o que menos avisa quando quebra:
## trocar dois indices de lugar faz a personagem encarar o lado errado, e isso
## nao gera erro, nao gera aviso, e passa despercebido em qualquer teste que so
## pergunte "carregou?".
func _o_conjunto_de_sprites(p: DadosPersonagem, arquivo: String) -> void:
	ok(p.miniatura != null, "%s tem miniatura para o card" % arquivo)

	igual(
		p.sprites_direcao.size(), DadosPersonagem.DIRECOES,
		"%s tem as %d rotacoes" % [arquivo, DadosPersonagem.DIRECOES]
	)
	if p.sprites_direcao.size() < DadosPersonagem.DIRECOES:
		return

	var vistas: Array[String] = []
	for i in DadosPersonagem.DIRECOES:
		var t: Texture2D = p.sprites_direcao[i]
		if t == null:
			ok(false, "%s: rotacao %d nao e nula" % [arquivo, i])
			continue
		igual(
			t.get_size(), Vector2(LADO_SPRITE, LADO_SPRITE),
			"%s: rotacao %d e %dx%d" % [arquivo, i, LADO_SPRITE, LADO_SPRITE]
		)
		# Oito arquivos distintos. Repetir um e o erro de copiar-colar que faz
		# duas direcoes ficarem identicas, e nada mais no jogo acusa.
		ok(
			not vistas.has(t.resource_path),
			"%s: rotacao %d nao repete outro arquivo (%s)" % [arquivo, i, t.resource_path.get_file()]
		)
		vistas.append(t.resource_path)

	# Os oito angulos que importam, no sentido horario a partir do leste. `+y`
	# aponta para BAIXO, entao sul e POSITIVO e norte e NEGATIVO -- e o sinal
	# trocado aqui e exatamente o bug que este caso existe para pegar.
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
		var direcao: Vector2 = caso[0]
		var indice: int = caso[1]
		ok(
			p.textura_para(direcao) == p.sprites_direcao[indice],
			"%s: mirar para %s escolhe a rotacao %d" % [arquivo, caso[2], indice]
		)

	# Um angulo entre dois passos cai no mais proximo, e nao num terceiro.
	var quase_leste := Vector2.RIGHT.rotated(deg_to_rad(20.0))
	ok(
		p.textura_para(quase_leste) == p.sprites_direcao[0],
		"%s: 20 graus ainda e leste (o passo e de 45)" % arquivo
	)
	ok(
		p.textura_para(Vector2.ZERO) == p.sprites_direcao[2],
		"%s: direcao nula cai no frontal" % arquivo
	)

	_o_ciclo_de_caminhada(p, arquivo, esperado)


## As oito fitas de caminhada.
##
## O que mais importa aqui e a LARGURA. Uma fita e lida por hframes; se a
## contagem declarada nao bater com o arquivo, o Sprite mostra fatias cortadas
## de dois quadros ao mesmo tempo -- sem erro no console, sem nada que aponte
## para o `.tres`. Multiplicar quadros_andando pelo lado e o que amarra os dois.
func _o_ciclo_de_caminhada(p: DadosPersonagem, arquivo: String, esperado: Array) -> void:
	igual(
		p.sprites_andando.size(), DadosPersonagem.DIRECOES,
		"%s tem as %d fitas de caminhada" % [arquivo, DadosPersonagem.DIRECOES]
	)
	if p.sprites_andando.size() < DadosPersonagem.DIRECOES:
		return

	ok(p.quadros_andando >= 2, "%s: um ciclo precisa de ao menos 2 quadros" % arquivo)
	ok(p.fps_andando > 0.0, "%s: o ciclo tem cadencia positiva" % arquivo)

	var largura := LADO_SPRITE * float(p.quadros_andando)
	var vistas: Array[String] = []
	for i in DadosPersonagem.DIRECOES:
		var t: Texture2D = p.sprites_andando[i]
		if t == null:
			ok(false, "%s: fita %d nao e nula" % [arquivo, i])
			continue
		igual(
			t.get_size(), Vector2(largura, LADO_SPRITE),
			"%s: fita %d cabe %d quadros" % [arquivo, i, p.quadros_andando]
		)
		ok(
			not vistas.has(t.resource_path),
			"%s: fita %d nao repete outro arquivo (%s)" % [arquivo, i, t.resource_path.get_file()]
		)
		vistas.append(t.resource_path)

	# O MESMO mapa de angulos do parado. Se os dois conjuntos divergirem, a
	# personagem troca de direcao no instante em que comeca a andar.
	for caso in esperado:
		var direcao: Vector2 = caso[0]
		var indice: int = caso[1]
		ok(
			p.textura_andando_para(direcao) == p.sprites_andando[indice],
			"%s: andando para %s escolhe a fita %d" % [arquivo, caso[2], indice]
		)
