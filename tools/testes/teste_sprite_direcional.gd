extends TesteBase
## Confere TODO inimigo com sprite direcional -- os arquivos, o mapa de angulos
## e o canal de cor.
##
## A suite VARRE `src/enemies/*.tscn` em vez de listar cenas: inimigo novo com
## arte entra na conta sozinho, sem ninguem lembrar de acrescentar. Uma lista
## fixa aqui teria o mesmo defeito que a `AUTORADAS` do teste de texturas ja tem
## -- arquivo fora dela nao e conferido por nada, e ninguem descobre.
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

const PASTA_INIMIGOS := "res://src/enemies/"

## Lado da moldura de todo sprite do projeto, parado ou andando.
##
## Uma so POR CONJUNTO, e nao uma para o projeto inteiro: e o alinhamento entre
## o parado e a fita do MESMO bicho que impede ele de saltar de lugar ao comecar
## a andar, e o chefe trouxe uma moldura de 160 (BOSS 10) por nao caber em 80.
##
## Por isso a moldura e LIDA do primeiro quadro e cobrada dos outros, em vez de
## cravada aqui: cravada, ela reprovaria o chefe certo; e sem cobrar dos outros,
## um conjunto com um arquivo de tamanho trocado passaria. Quem gera as duas
## molduras e `tools/sprites/gerar_sprites.py`, e `Direcoes.MOLDURAS_DE_ATOR`
## diz quais existem.
const LADO_SPRITE := 80.0

## Longe da origem, pela mesma razao de teste_hack: o grupo "inimigo" e global e
## inimigos de outras suites ainda nao coletados ficam quase todos perto de
## (0,0).
const LONGE := Vector2(6000, 6000)

## Passo do relogio manual, em segundos.
const PASSO := 0.1

## De quem sao as verificacoes que estao rodando agora. Sem isto, "rotacao 3
## mede 80x80" nao diz de qual inimigo, e um relatorio com tres bichos vira
## adivinhacao.
var _nome_atual: String = "?"


func nome() -> String:
	return "SpriteDirecional"


func executar() -> void:
	# O mapa de angulos nao depende de cena nenhuma: confere uma vez so.
	var esperado := _o_mapa_de_angulos()

	var achados := 0
	for arquivo in _cenas_de_inimigo():
		var cena: PackedScene = load(PASTA_INIMIGOS + arquivo)
		if cena == null:
			continue
		var raiz := Node2D.new()
		Engine.get_main_loop().root.add_child(raiz)

		# add_child ANTES do cast: nem todo .tscn de src/enemies/ e um inimigo
		# (area_de_perigo tem Area2D na raiz). Testando o cast primeiro, o no
		# instanciado ficava orfao -- fora da arvore, sem ninguem para libera-lo,
		# e o Godot reclamava de RID vazado no fim da suite. Dentro da arvore,
		# o `raiz.free()` leva tudo junto.
		var no := cena.instantiate()
		raiz.add_child(no)
		var inimigo := no as InimigoBase
		if inimigo == null:
			raiz.free()
			continue
		inimigo.global_position = LONGE

		var sprite := inimigo.get_node_or_null("Visual/Corpo") as SpriteDirecional
		if sprite == null:
			# Inimigo de poligono. Nao se aplica -- e ausencia de sprite nao e
			# falha, do mesmo jeito que ausencia de `cor_base` nao e no teste de
			# texturas.
			raiz.free()
			continue

		achados += 1
		_nome_atual = arquivo.get_basename()
		_o_conjunto_de_arquivos(sprite)
		_textura_e_hframes_andam_juntos(sprite, esperado)
		_a_arte_declarada_e_exercitada(inimigo, sprite, raiz)
		_o_tint_alcanca_o_sprite(inimigo, sprite)

		# free() e nao queue_free(): a suite roda inteira num frame, entao um
		# queue_free deixaria o inimigo no grupo "inimigo" para os casos das
		# outras suites acharem.
		raiz.free()

	_o_ciclo_segue_o_chao()
	_andar_em_qualquer_estado_anima()

	# Guarda contra a suite virar decoracao: se a varredura parar de achar
	# ninguem, todas as verificacoes acima somem e o relatorio fica verde.
	ok(achados >= 1, "a varredura achou inimigo com sprite direcional (%d)" % achados)


## Os `.tscn` de `src/enemies/`, em ordem estavel.
func _cenas_de_inimigo() -> Array[String]:
	var nomes: Array[String] = []
	var pasta := DirAccess.open(PASTA_INIMIGOS)
	if pasta == null:
		ok(false, "src/enemies/ pode ser aberta")
		return nomes
	for arquivo in pasta.get_files():
		if arquivo.ends_with(".tscn"):
			nomes.append(arquivo)
	nomes.sort()
	return nomes


## As oito paradas e as oito fitas, medidas em disco.
##
## A largura da fita e o que mais importa: ela e lida por `hframes`, e se a
## contagem declarada nao bater com o arquivo o Sprite mostra fatias cortadas --
## sem erro no console, sem nada que aponte para a cena. Multiplicar
## `quadros_andando` pelo lado e o que amarra os dois.
## A moldura DESTE conjunto, lida do primeiro quadro parado.
func _lado_do_conjunto(s: SpriteDirecional) -> float:
	if s.sprites_parado.is_empty() or s.sprites_parado[0] == null:
		return LADO_SPRITE
	return s.sprites_parado[0].get_size().y


func _o_conjunto_de_arquivos(s: SpriteDirecional) -> void:
	igual(s.sprites_parado.size(), Direcoes.TOTAL, "%s: tem as %d rotacoes paradas" % [_nome_atual, Direcoes.TOTAL])
	igual(s.sprites_andando.size(), Direcoes.TOTAL, "%s: tem as %d fitas de caminhada" % [_nome_atual, Direcoes.TOTAL])
	ok(s.quadros_andando >= 2, "%s: um ciclo precisa de ao menos 2 quadros" % _nome_atual)
	ok(s.fps_andando > 0.0, "%s: o ciclo tem cadencia positiva" % _nome_atual)
	ok(s.tem_ciclo(), "%s: o conjunto declara ter ciclo de caminhada" % _nome_atual)

	# A moldura sai do proprio conjunto, e tem de ser uma que o gerador produz:
	# arte de ator fora do gerador foi como a Diretora perdeu a ancora de base.
	var lado := _lado_do_conjunto(s)
	ok(Direcoes.moldura_de_ator(lado),
		"%s: a moldura (%d) e uma das que o gerador produz" % [_nome_atual, int(lado)])
	_medir(s.sprites_parado, Vector2(lado, lado), "rotacao")
	_medir(
		s.sprites_andando,
		Vector2(lado * float(s.quadros_andando), lado),
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
			ok(false, "%s: %s %d nao e nula" % [_nome_atual, rotulo, i])
			continue
		igual(t.get_size(), tamanho, "%s: %s %d mede %s" % [_nome_atual, rotulo, i, tamanho])
		ok(
			not vistas.has(t.resource_path),
			"%s: %s %d nao repete outro arquivo (%s)" % [_nome_atual, rotulo, i, t.resource_path.get_file()]
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
			"%s: parado para %s usa a rotacao %d" % [_nome_atual, caso[2], indice]
		)
		igual(s.hframes, 1, "%s: parado para %s le a textura como um quadro so" % [_nome_atual, caso[2]])

		s.apontar(direcao, true, 0.0, direcao)
		ok(
			s.texture == s.sprites_andando[indice],
			"%s: andando para %s usa a fita %d" % [_nome_atual, caso[2], indice]
		)
		igual(
			s.hframes, s.quadros_andando,
			"%s: andando para %s le a fita em %d quadros" % [_nome_atual, caso[2], s.quadros_andando]
		)

	_o_ciclo_nao_sai_da_fita(s)


## O ciclo avanca, volta para o inicio, e nunca indexa fora da fita -- nem
## andando de re, que e o que o knockback faz enquanto o drone encara o alvo.
## Sem o `fposmod`, o sentido negativo devolve quadro negativo.
func _o_ciclo_nao_sai_da_fita(s: SpriteDirecional) -> void:
	# A velocidade do movimento IMPORTA desde que o ciclo passou a seguir o
	# chao: um `Vector2.DOWN` cru tem comprimento 1, e contra uma
	# `velocidade_referencia` de 88 isso e praticamente parado -- o ciclo mal
	# saia do lugar e o caso "de fato avanca de quadro" reprovava sem haver
	# defeito nenhum. Anda-se a uma velocidade de verdade.
	var rapidez := maxf(s.velocidade_referencia, 100.0)
	var quadros: Array[int] = []
	for i in 40:
		s.apontar(Vector2.DOWN, true, 1.0 / 30.0, Vector2.DOWN * rapidez)
		quadros.append(s.frame)
	for i in 40:
		s.apontar(Vector2.DOWN, true, 1.0 / 30.0, Vector2.UP * rapidez)
		quadros.append(s.frame)

	var dentro := true
	var maior := 0
	for q in quadros:
		if q < 0 or q >= s.quadros_andando:
			dentro = false
		maior = maxi(maior, q)
	ok(dentro, "%s: o ciclo nunca indexa fora da fita, nos dois sentidos" % _nome_atual)
	ok(maior > 0, "%s: o ciclo de fato avanca de quadro" % _nome_atual)


## O tint de Hack tem de CHEGAR num corpo que e sprite.
##
## Num Polygon2D ele vai em `color`; num Sprite2D nao existe `color`, e o
## equivalente e `self_modulate`. Se `InimigoBase` escolher o canal errado -- ou
## se o cast de `_corpo` falhar -- o Hack continua "funcionando" em toda a
## logica e some so da tela, que e o pior lugar para um bug se esconder.
func _o_tint_alcanca_o_sprite(drone: InimigoBase, sprite: SpriteDirecional) -> void:
	if sprite == null:
		return
	igual(sprite.self_modulate, Color.WHITE, "%s: sem nada acontecendo o sprite fica neutro" % _nome_atual)

	drone.aplicar_hack(4.0)
	ok(drone.esta_hackeado(), "%s: aceita ser hackeado" % _nome_atual)
	ok(sprite.self_modulate != Color.WHITE, "%s: o tint de Hack chega ao sprite" % _nome_atual)
	ok(sprite.self_modulate.g > sprite.self_modulate.r, "%s: o tint de Hack puxa para o verde" % _nome_atual)

	# O clarao de dano mora no modulate do PAI. Sao dois canais que nao podem se
	# cruzar: se o clarao escrevesse aqui, o primeiro tiro apagaria a marca.
	drone.receber_dano(1)
	ok(sprite.self_modulate != Color.WHITE, "%s: o clarao de dano nao apaga o tint de Hack" % _nome_atual)

	# Expira pelo caminho de verdade -- o `_t_hack` do `_physics_process` --, e
	# nao chamando `_pintar_hack(false)` na mao: aquele so devolve o canal se o
	# Hack ja tiver acabado, entao chamar direto testaria uma ordem que nao
	# acontece no jogo e passaria verde com a marca ainda pintada.
	_avancar(drone, 4.2)
	ok(not drone.esta_hackeado(), "%s: a marca expira sozinha" % _nome_atual)
	igual(sprite.self_modulate, Color.WHITE, "%s: sair do Hack devolve o sprite ao neutro" % _nome_atual)


## Quanto tempo simulado o inimigo ganha para provar que desenha.
##
## Quatro segundos, e o numero sai do CHEFE: ele nasce DORMENTE e leva
## `tempo_despertar` = 2,0 s so para acordar, antes de andar pela primeira vez.
## Um segundo de folga reprovaria o chefe certo, que e o mesmo erro que a moldura
## cravada teria cometido.
const SEGUNDOS_DE_PROVA := 4.0


## A arte declarada na cena tem de ser EXERCITADA em runtime.
##
## Este caso generaliza `_andar_em_qualquer_estado_anima`, que nasceu de uma
## regressao da Cyber-Besta e ficou cravado nela. O docstring de la ja dizia a
## coisa certa -- "a trava e sobre o inimigo montado, e nao sobre o sprite solto:
## o defeito morava em quem CHAMA `apontar()`, nao nele" --, so que apontada para
## um bicho so ela nao cobria os outros seis.
##
## E havia o que cobrir. O `boss_guardiao_01` declarava as 8 poses e as 8 fitas
## desde a BOSS 10 e **nunca chamava `apontar()`**: nao existia sequer um campo
## `_sprite` nas 1060 linhas dele. O corpo ficava no quadro que o `_ready()` do
## `SpriteDirecional` escreve -- `south.png`, quadro 0 -- a luta inteira, e ele
## deslizava para o norte encarando o sul. Nada avisava: os arquivos estavam
## certos, casados e medidos, e a suite conferia tudo isso. Ninguem conferia se
## alguem os usava.
##
## A afirmacao e a MINIMA que separa "tem arte" de "toca arte": em algum momento
## dos `SEGUNDOS_DE_PROVA` o par (textura, quadro) mudou. Nao afirma qual quadro
## nem em que ordem -- isso e desenho de cada inimigo, e cravar aqui engessaria
## quem legitimamente congela o corpo para telegrafar, como o Drone Aranha faz.
func _a_arte_declarada_e_exercitada(inimigo: InimigoBase, sprite: SpriteDirecional, raiz: Node2D) -> void:
	if sprite == null:
		return

	# Alvo explicito, e nao o grupo "player": o grupo e global, e um jogador de
	# outra suite ainda nao coletado seria achado a milhares de px daqui. Foi
	# assim que o vies de distancia do chefe "sumiu" uma vez.
	var alvo := Node2D.new()
	raiz.add_child(alvo)
	# A OESTE, e a escolha sustenta o portao: `SpriteDirecional._ready()` ja
	# escreve o quadro SUL (indice 2), entao um alvo ao sul tornaria "virou"
	# indistinguivel de "nunca se mexeu". Oeste e o indice 4, o oposto.
	alvo.global_position = inimigo.global_position + Vector2(-400.0, 0.0)
	inimigo.alvo = alvo

	var vistos: Array[String] = []
	var saiu_do_sul := false
	for i in int(ceil(SEGUNDOS_DE_PROVA / PASSO)):
		inimigo._physics_process(PASSO)
		var caminho := "?" if sprite.texture == null else sprite.texture.resource_path
		var chave := "%s#%d" % [caminho, sprite.frame]
		if not chave in vistos:
			vistos.append(chave)
		if not _e_do_sul(sprite):
			saiu_do_sul = true

	# Duas afirmacoes, e elas pegam defeitos diferentes. Sem a primeira, um
	# inimigo que encara certo mas nunca anima passaria; sem a segunda, um que
	# anima mas nunca vira.
	ok(
		vistos.size() >= 2,
		"%s: a arte declarada na cena e desenhada em runtime (%d quadros distintos em %.0fs)"
			% [_nome_atual, vistos.size(), SEGUNDOS_DE_PROVA]
	)
	ok(
		saiu_do_sul,
		"%s: o corpo VIRA -- ele deixou o sul que o _ready escreveu, com o alvo a oeste"
			% _nome_atual
	)


## O sprite esta desenhando alguma das duas texturas do SUL?
##
## O sul e o indice 2, e e o que `SpriteDirecional._ready()` escreve antes de
## qualquer um chamar `apontar()`. Comparar por `resource_path` e nao por
## referencia porque a fita e a pose sao recursos distintos do mesmo lado.
func _e_do_sul(s: SpriteDirecional) -> bool:
	if s.texture == null:
		return true
	var sul := Direcoes.indice(Vector2.DOWN)
	for lista in [s.sprites_parado, s.sprites_andando]:
		if lista.size() > sul and lista[sul] != null:
			if lista[sul].resource_path == s.texture.resource_path:
				return true
	return false


## Avanca o relogio do inimigo na mao. O _physics_process nao roda numa suite
## sincrona, e esperar frames de verdade tornaria a suite lenta e instavel.
func _avancar(inimigo: InimigoBase, segundos: float) -> void:
	for i in int(ceil(segundos / PASSO)):
		inimigo._physics_process(PASSO)

## O ciclo de patas segue o CHAO, e nao o relogio.
##
## Cadencia fixa desliza em qualquer bicho com mais de uma velocidade -- e "uma
## velocidade so" nao existe aqui, porque a Deterioracao multiplica a velocidade
## de todo inimigo ate 1,55x. O caso que tornou isso obvio foi a Cyber-Besta:
## 88 px/s andando contra 720 investindo, com as patas sempre no mesmo passo.
func _o_ciclo_segue_o_chao() -> void:
	var s := SpriteDirecional.new()
	s.fps_andando = 12.0
	s.quadros_andando = 9
	s.velocidade_referencia = 100.0
	s.aceleracao_maxima_do_ciclo = 3.0

	var normal := _avanco(s, 100.0)
	var dobro := _avanco(s, 200.0)
	var quase_parado := _avanco(s, 5.0)

	ok(dobro > normal * 1.9, "andar ao dobro roda o ciclo ao dobro (%.2f -> %.2f)" % [normal, dobro])
	ok(quase_parado < normal, "quase parado, o ciclo desacelera junto (%.2f < %.2f)" % [quase_parado, normal])

	# O teto. Sem ele a investida real -- 8x a referencia -- rodaria o ciclo de
	# 9 quadros quase cinco vezes em 0,42 s: ruido, e nao galope.
	perto(_avanco(s, 800.0), normal * 3.0, "a 8x a referencia o ciclo para no teto de 3x", 0.05)

	# E quem nao optou continua exatamente como estava.
	var fixo := SpriteDirecional.new()
	fixo.fps_andando = 12.0
	fixo.quadros_andando = 9
	perto(
		_avanco(fixo, 800.0), _avanco(fixo, 50.0),
		"sem velocidade_referencia a cadencia e fixa, como antes", 0.001
	)

	s.free()
	fixo.free()


## Andar anima, em QUALQUER estado.
##
## Este caso existe por uma regressao concreta: `_pos_movimento` da Cyber-Besta
## excluia o estado OBSERVAR de `andando`, achando que observar era ficar
## parado. Nao e -- `_observar()` faz ela CIRCULAR o jogador a ~53 px/s, e e o
## estado em que ela passa mais tempo. As patas ficavam congeladas exatamente
## onde ela mais se desloca.
##
## A trava e sobre o inimigo montado, e nao sobre o sprite solto: o defeito
## morava em quem CHAMA `apontar()`, nao nele.
func _andar_em_qualquer_estado_anima() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)
	var besta := preload("res://src/enemies/cyber_besta.tscn").instantiate() as InimigoBase
	raiz.add_child(besta)
	besta.global_position = LONGE
	besta.set_physics_process(false)

	var sprite := besta.get_node_or_null("Visual/Corpo") as SpriteDirecional
	if sprite == null:
		ok(false, "a Cyber-Besta tem sprite direcional")
		raiz.free()
		return

	# Deslocando-se de lado, como ela faz o tempo todo enquanto observa.
	besta.velocity = Vector2(0.0, 60.0)
	var quadros: Array[int] = []
	for i in 20:
		besta._pos_movimento(PASSO)
		quadros.append(sprite.frame)

	var mudou := false
	for q in quadros:
		if q != quadros[0]:
			mudou = true
	ok(mudou, "deslocar-se enquanto observa move as patas (%s)" % [quadros.slice(0, 6)])

	raiz.free()


## Quantos quadros o ciclo avanca em 1 s a esta velocidade.
func _avanco(s: SpriteDirecional, velocidade: float) -> float:
	s._t_ciclo = 0.0
	var movimento := Vector2.RIGHT * velocidade
	for i in 60:
		s._avancar_ciclo(1.0 / 60.0, Vector2.RIGHT, movimento)
	# fposmod dobra o valor dentro da fita; o que interessa aqui e o AVANCO, e
	# ele so cabe cru enquanto for menor que um ciclo. Acima disso conta-se
	# quantas voltas deram, e por isso o harness usa 1 s e nao mais.
	return s._t_ciclo
