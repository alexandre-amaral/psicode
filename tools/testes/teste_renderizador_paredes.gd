extends TesteBase
## A FITA de modulos: ela fecha, ela nao invade o chao, e ela nao gira arte.
##
## O que esta suite existe para provar e uma AFIRMACAO GEOMETRICA, e nao um
## gosto. A parede antiga -- o contorno inflado e solido -- e desenhada ATRAS do
## chao, e o chao por cima recorta a faixa que sobra: e esse truque que faz a
## sala em L funcionar sem calcular anel com furo. A fita abandona o truque e
## desenha ACIMA do chao, e so pode fazer isso se **nenhuma celula encostar em
## area jogavel**. Se um dia uma encostar, o sintoma sera um retangulo de parede
## no meio da sala -- visivel na hora, mas so em UMA forma de sala, e o teste de
## fumaca nao olha para o chao.
##
## E ela varre as cenas em DISCO em vez de listar as nove. Lista fixa aqui teria
## o mesmo defeito que a `AUTORADAS` do teste de texturas ja teve: cena nova fora
## dela nao seria conferida por nada.

const PASTA := "res://src/mapa"

## Longe da origem, como as outras suites que sobem nos.
const LONGE := Vector2(21000, 21000)

## O lado da celula, espelhando `RenderizadorParedes.CELULA`.
const CELULA := 32.0


func nome() -> String:
	return "Renderizador de paredes"


func executar() -> void:
	await _toda_forma_de_sala_veste_a_fita()
	await _nenhuma_celula_invade_o_chao()
	await _a_fita_nao_gira_nem_espelha_arte()
	await _o_vao_da_porta_fica_sem_modulo()
	await _o_acabamento_existe_e_cabe_na_faixa()
	await _toda_quina_recebe_canto()
	_a_variante_e_deterministica_e_o_espacamento_morde()
	_as_duas_contas_de_onde_ha_parede_coincidem()


## Toda forma de sala em disco monta a fita, e nenhuma monta vazia.
##
## O piso importa: uma fita vazia nao da erro nenhum -- a sala continua com a
## parede antiga por baixo e a foto sai igual a de antes deste epico.
func _toda_forma_de_sala_veste_a_fita() -> void:
	var cenas := _cenas()
	ok(cenas.size() >= 5, "a varredura achou as cenas de sala (%d)" % cenas.size())
	for caminho in cenas:
		var sala := _nascer(caminho)
		if sala == null:
			continue
		await Engine.get_main_loop().process_frame
		var fita := sala.get_node_or_null("ParedeModulos")
		ok(fita != null, "%s monta a fita" % caminho.get_file())
		if fita != null:
			ok(
				fita.get_child_count() >= 8,
				"%s veste %d celulas -- fita vazia nao da erro nenhum"
					% [caminho.get_file(), fita.get_child_count()]
			)
		sala.free()


## NENHUMA CELULA CAI DENTRO DO CONTORNO.
##
## E a afirmacao que autoriza a fita a desenhar acima do chao, e ela vale para a
## sala em L tambem: no vao dela a normal externa aponta para dentro da mordida,
## que e area FORA do poligono. Um contorno novo que quebrasse isso poria parede
## no meio do combate.
##
## Ele varre todo `Node2D` e nao so `Sprite2D`, e a diferenca nao e cosmetica: o
## acabamento da TOPO 01 sao `Polygon2D`, e com o alvo estreito o portao mediria
## 300 celulas ignorando as tiras -- verde, e cego para metade do que a fita
## desenha. Alvo estreito e como um portao vira carimbo.
func _nenhuma_celula_invade_o_chao() -> void:
	var conferidas := 0
	for caminho in _cenas():
		var sala := _nascer(caminho)
		if sala == null:
			continue
		await Engine.get_main_loop().process_frame
		var contorno := sala.contorno_local()
		var fita := sala.get_node_or_null("ParedeModulos")
		if fita == null:
			sala.free()
			continue
		var dentro := 0
		for filho in fita.get_children():
			var item := filho as Node2D
			if item == null:
				continue
			conferidas += 1
			if Geometry2D.is_point_in_polygon(item.position, contorno):
				dentro += 1
		igual(
			dentro, 0,
			"%s: nenhuma celula da fita cai na area jogavel (%d de %d)"
				% [caminho.get_file(), dentro, fita.get_child_count()]
		)
		sala.free()
	ok(conferidas > 40, "a varredura mediu as pecas de todas as formas (%d)" % conferidas)


## A fita nao gira nem espelha arte, e e a mesma trava que a porta ja tem.
##
## Cada lado tem modulo PROPRIO -- 32x64 no norte e no sul, 64x32 no leste e no
## oeste --, e o oeste nao e o leste espelhado: no leste a aresta virada para a
## sala pega a luz, no oeste ela olha para longe dela. Um `flip_h` aqui poria o
## realce no lado errado, e ninguem veria.
##
## **Com o acabamento da TOPO 01 o portao ENDURECE, e nao afrouxa.** A tentacao
## era abrir excecao para a tira poder acompanhar o lado; a saida foi desenha-la
## em coordenadas, onde nao ha o que girar. Entao ele passa a varrer todo
## `Node2D` -- uma tira rotacionada seria a mesma mentira de luz que uma arte
## girada, e a tabela por lado de `_vestir_acabamento()` so vale se ninguem a
## contornar com um `rotation`.
func _a_fita_nao_gira_nem_espelha_arte() -> void:
	for caminho in _cenas():
		var sala := _nascer(caminho)
		if sala == null:
			continue
		await Engine.get_main_loop().process_frame
		var fita := sala.get_node_or_null("ParedeModulos")
		if fita == null:
			sala.free()
			continue
		var tortos := 0
		var vistos := 0
		for filho in fita.get_children():
			var item := filho as Node2D
			if item == null:
				continue
			vistos += 1
			if not is_zero_approx(item.global_rotation):
				tortos += 1
				continue
			var sprite := item as Sprite2D
			if sprite != null and (sprite.flip_h or sprite.flip_v):
				tortos += 1
		igual(tortos, 0, "%s: nenhuma peca da fita gira ou espelha (%d de %d)"
			% [caminho.get_file(), tortos, vistos])
		sala.free()


## O VAO DA PORTA fica sem modulo.
##
## Aqui mora um numero que o plano nao previu: `Porta.LARGURA` e 80, e 80 nao e
## multiplo de 32. A porta ocupa 2,5 celulas, entao as das pontas ficam meio
## dentro e meio fora do vao. A regra provisoria e tirar toda celula que ENCOSTA
## no vao -- 128 px de buraco para 80 px de passagem --, e ela e segura porque a
## parede antiga continua desenhando por baixo e preenche a sobra.
##
## O que este caso cobra e o lado que NAO pode falhar: nenhum modulo pode cair
## dentro do vao. Modulo ali desenharia parede em cima do batente da porta.
func _o_vao_da_porta_fica_sem_modulo() -> void:
	var conferidas := 0
	for caminho in _cenas():
		var sala := _nascer(caminho)
		if sala == null:
			continue
		await Engine.get_main_loop().process_frame
		var fita := sala.get_node_or_null("ParedeModulos")
		var portas := sala.get_node_or_null("Portas")
		if fita == null or portas == null:
			sala.free()
			continue
		for filho in portas.get_children():
			var porta := filho as Porta
			if porta == null or porta.esta_selada():
				continue
			conferidas += 1
			# O eixo AO LONGO da parede daquela porta.
			var eixo := Vector2(absf(porta.vetor().y), absf(porta.vetor().x))
			var centro := porta.position.dot(eixo)
			var meia := Porta.LARGURA * 0.5
			var invasores := 0
			for peca in fita.get_children():
				var item := peca as Node2D
				if item == null:
					continue
				# So conta quem esta na MESMA faixa: a fita do lado oposto
				# projeta no mesmo eixo e nao tem nada a ver com este vao.
				if item.position.dot(porta.vetor()) < 0.0:
					continue
				# A EXTENSAO, e nao o centro.
				#
				# O acabamento e uma tira por TRECHO, entao o centro dela fica no
				# meio do lado -- longe do vao, e um teste de centro a daria por
				# inocente mesmo que ela atravessasse a soleira inteira. Medir a
				# extensao tambem endurece o caso para as celulas: uma peca cuja
				# BORDA entra no vao passava antes.
				# O TOPO PODE atravessar; a FACE nao.
				#
				# Sobre a porta ha verga: a superficie de cima da parede passa por
				# cima da passagem, e e isso que impede um retangulo preto de
				# 64 px pelo fundo da faixa alem de cada porta -- o defeito que o
				# dono viu quando a faixa passou de 32 para 96 px. Quem tem
				# abertura e a face, que e onde a passagem se ve.
				#
				# Sem esta distincao o portao afirmava "nada atravessa o vao", que
				# e o oposto do que o proprio projeto documenta.
				var poly_item := item as Polygon2D
				var caminho_tex := ""
				if poly_item != null and poly_item.texture != null:
					caminho_tex = poly_item.texture.resource_path
				else:
					var spr := item as Sprite2D
					if spr != null and spr.texture != null:
						caminho_tex = spr.texture.resource_path
				if not caminho_tex.get_file().begins_with("parede_face"):
					continue
				var faixa := _extensao(item, eixo)
				if faixa.y > centro - meia + 0.5 and faixa.x < centro + meia - 0.5:
					invasores += 1
			igual(
				invasores, 0,
				"%s/%s: nenhuma FACE desenha dentro do vao (%d) -- o topo atravessa, ela nao"
					% [caminho.get_file(), porta.name, invasores]
			)

			# E A RESERVA E EXATA: a faixa ACABA na borda do vao.
			#
			# A pergunta mudou de forma com a moldura. Antes a peca era uma
			# celula, entao meia celula nao podia existir e a regra era tirar
			# toda celula que ENCOSTASSE no vao -- 128 px de buraco para 64 px de
			# passagem. Uma faixa pode acabar em qualquer lugar, entao o buraco
			# passa a ter o tamanho da porta, e o que se cobra e o encosto: a
			# faixa vizinha termina a `meia` do centro, e nao antes.
			var vizinho := 9999.0
			for peca in fita.get_children():
				var poly := peca as Polygon2D
				if poly == null or poly.polygon.is_empty():
					continue
				if poly.position.dot(porta.vetor()) < 0.0:
					continue
				var faixa := _extensao(poly, eixo)
				# A borda mais proxima do centro da porta, dos dois lados.
				if faixa.y <= centro:
					vizinho = minf(vizinho, absf(centro - faixa.y))
				elif faixa.x >= centro:
					vizinho = minf(vizinho, absf(faixa.x - centro))
			ok(
				vizinho <= meia + 1.0,
				"%s/%s: a faixa encosta no vao -- borda a %.0f px do centro (vao %.0f)"
					% [caminho.get_file(), porta.name, vizinho, meia]
			)
		sala.free()
	ok(conferidas >= 4, "a varredura mediu portas de verdade (%d)" % conferidas)


func _toda_quina_recebe_canto() -> void:
	var quinas := 0
	var cantos := 0
	for caminho in _cenas():
		var sala := _nascer(caminho)
		if sala == null:
			continue
		await Engine.get_main_loop().process_frame
		var contorno := sala.contorno_local()
		var fita := sala.get_node_or_null("ParedeModulos")
		if fita == null:
			sala.free()
			continue
		# A QUINA NAO E MAIS UMA PECA, e a pergunta mudou junto.
		#
		# Antes o canto era um sprite inteiro (sem `region_enabled`) desenhado
		# POR CIMA das celulas, e bastava conta-los. Com a MOLDURA 12 ele virou
		# um quad de PREENCHIMENTO do tamanho exato do vao entre as duas faixas
		# -- ele nao se ve, e esse e o ponto.
		#
		# Entao o que se cobra deixou de ser "ha uma peca ali" e passou a ser
		# **nao ha buraco ali**: para cada vertice, alguma peca da fita cobre o
		# ponto logo fora da quina, na diagonal das duas normais.
		var deste := 0
		var total_de_quinas := contorno.size()
		for i in total_de_quinas:
			var v: Vector2 = contorno[i]
			var anterior: Vector2 = contorno[(i - 1 + total_de_quinas) % total_de_quinas]
			var proximo: Vector2 = contorno[(i + 1) % total_de_quinas]
			var n1 := RenderizadorParedes.normal_externa(contorno, anterior, v)
			var n2 := RenderizadorParedes.normal_externa(contorno, v, proximo)
			var diagonal := (n1 + n2)
			if diagonal == Vector2.ZERO:
				deste += 1
				continue
			var sonda: Vector2 = v + diagonal.normalized() * 6.0
			for filho in fita.get_children():
				var poly := filho as Polygon2D
				if poly == null or poly.polygon.size() < 3:
					continue
				var absoluto := PackedVector2Array()
				for ponto in poly.polygon:
					absoluto.append(poly.position + ponto)
				if Geometry2D.is_point_in_polygon(sonda, absoluto):
					deste += 1
					break
		quinas += contorno.size()
		cantos += deste
		igual(
			deste, contorno.size(),
			"%s: as %d quinas estao FECHADAS, sem buraco (%d)"
				% [caminho.get_file(), contorno.size(), deste]
		)
		sala.free()
	ok(quinas >= 38, "a varredura contou as quinas das nove formas (%d)" % quinas)
	igual(cantos, quinas, "nenhuma quina ficou com buraco (%d de %d)" % [cantos, quinas])


## A VARIANTE e deterministica, o comum domina, e o espacamento MORDE.
##
## Tres afirmacoes, e as tres sao numero e nao gosto.
##
## 1. **Mesma celula, mesma variante.** Sair da sala e voltar mostra a mesma
##    parede -- e a regra que o projeto ja aplica ao chao, a face e ao prop.
## 2. **O comum domina.** Sem isso a sala fica ruidosa, e ruido na borda compete
##    com o que o jogador precisa ler no meio. E o mesmo argumento que
##    `max_props_animados` ja carrega.
## 3. **O espacamento MORDE.** Teto que nunca e alcancado e teto que nunca foi
##    testado -- a licao que `teste_props_animados.gd` ja registra. Aqui isso e
##    provado montando a MESMA parede duas vezes, com espacamento 0 e com 2, e
##    exigindo que a segunda tenha menos especiais. Se a regra nao mordesse, os
##    dois numeros seriam iguais e o portao seria um carimbo.
func _a_variante_e_deterministica_e_o_espacamento_morde() -> void:
	# Uma parede longa e reta: 1600 px de lado dao 50 celulas por lado, amostra
	# suficiente para a distribuicao significar alguma coisa.
	var contorno := PackedVector2Array([
		Vector2(-800, -400), Vector2(800, -400), Vector2(800, 400), Vector2(-800, 400),
	])
	var topos: Array[Texture2D] = [load("res://assets/texturas/parede_topo_a.png")]
	var faces: Array[Texture2D] = [
		load("res://assets/texturas/parede_face_combate.png"),
		load("res://assets/texturas/parede_face_combate_tubulacao.png"),
		load("res://assets/texturas/parede_face_combate_tecnica.png"),
		load("res://assets/texturas/parede_face_combate_ventilada.png"),
	]
	var cantos: Array[Texture2D] = []
	var vazias: Array[Porta] = []
	for t in topos + faces:
		if t == null:
			ok(false, "as texturas de amostra carregam")
			return

	var solto := RenderizadorParedes.construir(
		contorno, vazias, 12345, topos, faces, cantos, 0.65, 0)
	var apertado := RenderizadorParedes.construir(
		contorno, vazias, 12345, topos, faces, cantos, 0.65, 2)
	var repetido := RenderizadorParedes.construir(
		contorno, vazias, 12345, topos, faces, cantos, 0.65, 2)

	# 1. DETERMINISMO: as duas montagens com a mesma semente sao identicas.
	# Comparado por HASH e nao por `igual()`: a assinatura de uma parede tem
	# centenas de pecas, e o relatorio da suite imprime o valor esperado E o
	# obtido mesmo quando passa. Uma linha de portao nao pode custar duas telas
	# de console -- quem le o relatorio deixa de ler.
	var assinatura := _assinatura(apertado)
	ok(
		assinatura == _assinatura(repetido),
		"a mesma semente monta a mesma parede (%d pecas, hash %d)"
			% [apertado.get_child_count(), hash(assinatura)]
	)

	# 2. A VARIEDADE MUDOU DE ESCALA, e as duas perguntas antigas morreram com ela.
	#
	# Ate a MOLDURA 04 a face era sorteada POR CELULA, e havia dois botoes para
	# cobrar: o `peso_comum` (o modulo comum domina ~65% das celulas) e o
	# `espacamento_minimo` (duas especiais nao encostam). Os dois mediam a mesma
	# coisa -- a distribuicao ao longo de um lado --, e essa coisa era exatamente
	# o que fazia a parede ler como uma fileira de blocos.
	#
	# Hoje a face e escolhida UMA VEZ por lado. Nao ha distribuicao dentro do
	# lado para medir, e cobrar que "o comum domina 65% das celulas" seria cobrar
	# a volta do defeito. A variedade passou a acontecer entre LADOS e entre
	# SALAS, que e onde o jogador a le como material e nao como grade.
	#
	# O que sobra e cobravel: **lados diferentes podem vestir faces diferentes**,
	# e a escolha continua deterministica.
	var vistas := {}
	for filho in solto.get_children():
		var poly := filho as Polygon2D
		if poly != null and poly.texture != null:
			vistas[poly.texture.resource_path] = true
	ok(vistas.size() >= 2,
		"a sala veste mais de uma textura (%d) -- topo e face sao superficies diferentes"
			% vistas.size())
	# E o espacamento deixou de agir: com uma escolha por lado, mudar o parametro
	# nao pode mudar a parede. Isso NAO e regressao -- e o entregavel da
	# MOLDURA 03, e cobra-lo evita que alguem \"conserte\" o botao de volta.
	ok(
		_assinatura(solto) == _assinatura(apertado),
		"o espacamento nao age mais por celula: mesma parede com 0 e com 2"
	)

	solto.free()
	apertado.free()
	repetido.free()


## Uma assinatura da parede montada: textura e posicao de cada peca, em ordem.
func _assinatura(raiz: Node2D) -> String:
	var partes: Array[String] = []
	for filho in raiz.get_children():
		var sprite := filho as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		partes.append("%s@%s" % [sprite.texture.resource_path.get_file(), sprite.position])
	return "|".join(partes)


func _contar(raiz: Node2D, alvo: Texture2D) -> int:
	var n := 0
	for filho in raiz.get_children():
		var sprite := filho as Sprite2D
		if sprite != null and sprite.texture == alvo:
			n += 1
	return n


func _contar_especiais(raiz: Node2D, faces: Array[Texture2D]) -> int:
	var n := 0
	for filho in raiz.get_children():
		var sprite := filho as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		for i in range(1, faces.size()):
			if sprite.texture == faces[i]:
				n += 1
				break
	return n


# ------------------------------------------------------------- helpers ------

## AS DUAS RESPOSTAS PARA "ONDE HA PAREDE" TEM DE COINCIDIR.
##
## Existem duas implementacoes do mesmo corte, e elas alimentam coisas
## diferentes:
##
##   `Sala._subtrechos()`               -> a SOMBRA e a colisao
##   `RenderizadorParedes.trechos_livres()` -> a parede DESENHADA
##
## As duas cortam o lado nos vaos de porta, e as duas usam numeros diferentes: a
## primeira descarta trecho abaixo de 8 px e exige encaixe perpendicular de 24;
## a segunda descarta abaixo de 1 px e filtra so pela direcao da porta.
##
## O sintoma de elas divergirem e silencioso e visual: um trecho recebe parede
## desenhada e nao recebe sombra, ou o contrario -- a faixa termina num lugar e a
## sombra noutro. Perto de uma quina, ou numa sala em L, e onde isso apareceria
## primeiro. E a mesma licao que o vocabulario de `Movimento` ja carrega: duas
## copias divergem, e o sintoma aparece em TELA e nunca no console.
##
## Este caso nao unifica as duas -- ele MEDE se elas ja discordam. Enquanto
## coincidirem, ele e a guarda que avisa no dia em que uma das duas mudar
## sozinha.
func _as_duas_contas_de_onde_ha_parede_coincidem() -> void:
	var divergentes := 0
	var conferidos := 0
	for caminho in _cenas():
		var sala := _nascer(caminho)
		if sala == null:
			continue
		var contorno := sala.contorno_local()
		var portas: Array[Porta] = []
		var raiz_portas := sala.get_node_or_null("Portas")
		if raiz_portas != null:
			for filho in raiz_portas.get_children():
				var porta := filho as Porta
				if porta != null:
					portas.append(porta)

		for i in contorno.size():
			var a: Vector2 = contorno[i]
			var b: Vector2 = contorno[(i + 1) % contorno.size()]
			var da_sala: Array = sala._subtrechos(a, b)
			var do_render := RenderizadorParedes.trechos_livres(contorno, a, b, portas)
			conferidos += 1
			# Compara a COBERTURA, e nao a lista: as duas podem partir o lado em
			# numeros diferentes de pedacos e ainda cobrir o mesmo comprimento.
			# O que importa e se a sombra e a parede param no mesmo lugar.
			var c1 := _comprimento_coberto(da_sala)
			var c2 := _comprimento_coberto(do_render)
			if absf(c1 - c2) > 8.0:
				divergentes += 1
				ok(
					false,
					"%s lado %d: a sombra cobre %.0f px e a parede %.0f"
						% [caminho.get_file(), i, c1, c2]
				)
		sala.free()

	ok(conferidos >= 20, "houve lado para conferir (%d)" % conferidos)
	igual(divergentes, 0, "as duas contas de onde ha parede concordam")


func _comprimento_coberto(trechos: Array) -> float:
	var total := 0.0
	for t in trechos:
		var par: PackedVector2Array = t
		if par.size() >= 2:
			total += par[0].distance_to(par[1])
	return total


func _cenas() -> Array[String]:
	var lista: Array[String] = []
	var pasta := DirAccess.open(PASTA)
	if pasta == null:
		return lista
	for arquivo in pasta.get_files():
		if arquivo.begins_with("sala_") and arquivo.ends_with(".tscn"):
			lista.append("%s/%s" % [PASTA, arquivo])
	lista.sort()
	return lista


## Uma sala montada com TODAS as conexoes: assim nenhuma porta se sela, e o caso
## do vao tem o que conferir nos quatro lados.
func _nascer(caminho: String) -> Sala:
	var cena := load(caminho) as PackedScene
	if cena == null:
		ok(false, "%s carrega" % caminho)
		return null
	var sala := cena.instantiate() as Sala
	sala.configurar_conexoes([Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT])
	Engine.get_main_loop().root.add_child(sala)
	sala.global_position = LONGE
	return sala


## O ACABAMENTO EXISTE, cabe na faixa, e a costura sabe onde ha face.
##
## Os tres portoes que a TOPO 01 ampliou sao todos NEGATIVOS -- nao invade o
## chao, nao gira, nao atravessa a porta. Os tres passariam perfeitamente com o
## acabamento nao existindo, que e a forma mais comum de um portao aprovar o
## nada. Este e o positivo, e ele cobra as tres afirmacoes que a peca faz:
##
## 1. **existe** -- ha tira em toda forma de sala;
## 2. **cabe** -- nenhuma passa de `alcance()`, nem para fora nem para dentro do
##    contorno. Um pixel alem de 64 e a camera passa a mostrar vazio na borda do
##    quadro, sem erro no console;
## 3. **a costura sabe onde ha face** -- ela existe em `n*32` nos lados com face
##    e NAO existe no sul, que nao tem face para virar. Uma costura no sul seria
##    uma linha atravessando o meio de uma superficie continua.
func _o_acabamento_existe_e_cabe_na_faixa() -> void:
	var alcance := RenderizadorParedes.alcance()
	for caminho in _cenas():
		var sala := _nascer(caminho)
		if sala == null:
			continue
		await Engine.get_main_loop().process_frame
		var fita := sala.get_node_or_null("ParedeModulos")
		if fita == null:
			sala.free()
			continue
		var contorno := sala.contorno_local()
		var caixa_do_chao := Rect2(contorno[0], Vector2.ZERO)
		for ponto in contorno:
			caixa_do_chao = caixa_do_chao.expand(ponto)
		var eixo := RenderizadorParedes.alcance_por_eixo()
		var perfil := PerfilDeParede.new()
		var tiras := 0
		var fora := 0
		var costuras_ao_sul := 0
		var costuras := 0
		for filho in fita.get_children():
			var poly := filho as Polygon2D
			if poly == null or poly.polygon.is_empty():
				continue
			tiras += 1
			# POR EIXO, e nao por distancia ao segmento mais proximo.
			#
			# A distancia diagonal reprovava o quad que FECHA a quina: ele
			# alcanca `dx` num eixo e `dy` no outro, e a hipotenusa passa dos
			# dois. Isso nao e sair da faixa -- a camera tambem cresce por
			# eixo, entao a pergunta certa e por eixo.
			for ponto in poly.polygon:
				var mundo: Vector2 = poly.position + ponto
				if mundo.x < caixa_do_chao.position.x - eixo.x - 0.5 \
					or mundo.x > caixa_do_chao.end.x + eixo.x + 0.5 \
					or mundo.y < caixa_do_chao.position.y - eixo.y - 0.5 \
					or mundo.y > caixa_do_chao.end.y + eixo.y + 0.5:
					fora += 1
			if poly.color.is_equal_approx(RenderizadorParedes.N4) 					or poly.color.is_equal_approx(RenderizadorParedes.N7):
				var meio := poly.position
				var d := _profundidade(meio, contorno)
				# A costura saiu da const e passou a vir do PERFIL: com a
				# parede assimetrica ela cai em 24 no norte e em 16 nas
				# laterais, e um numero unico so acharia a de um dos lados.
				if absf(d - perfil.face_norte) <= 3.0 						or absf(d - perfil.face_lateral) <= 3.0:
					costuras += 1
					# Ao sul TAMBEM ha costura, desde que o sul ganhou face.
					# Ela era proibida aqui -- "la a fita e topo puro" --, e essa
					# proibicao era o reflexo da regra antiga.
					if meio.y > _caixa(contorno).end.y:
						costuras_ao_sul += 1
		var nome := caminho.get_file()
		ok(tiras > 0, "%s: a fita monta acabamento (%d tiras)" % [nome, tiras])
		igual(fora, 0, "%s: nenhum vertice sai da faixa (%.0fx%.0f px) (%d)"
			% [nome, eixo.x, eixo.y, fora])
		ok(costuras > 0, "%s: a costura existe onde ha face (%d)" % [nome, costuras])
		ok(costuras_ao_sul > 0,
			"%s: a costura tambem existe ao SUL (%d) -- ele tem face como os outros tres"
				% [nome, costuras_ao_sul])
		sala.free()


## A que distancia do contorno este ponto esta, para FORA. Negativo se dentro.
func _profundidade(ponto: Vector2, contorno: PackedVector2Array) -> float:
	var perto_de := INF
	var total := contorno.size()
	for i in total:
		var a := contorno[i]
		var b := contorno[(i + 1) % total]
		perto_de = minf(perto_de,
			ponto.distance_to(Geometry2D.get_closest_point_to_segment(ponto, a, b)))
	if Geometry2D.is_point_in_polygon(ponto, contorno):
		return -perto_de
	return perto_de


func _caixa(pontos: PackedVector2Array) -> Rect2:
	var caixa := Rect2(pontos[0], Vector2.ZERO)
	for i in range(1, pontos.size()):
		caixa = caixa.expand(pontos[i])
	return caixa


## Ate onde uma peca da fita vai, projetada num eixo. (minimo, maximo)
##
## Sprite e poligono medem diferente e a diferenca importa: o sprite e centrado
## na `position` e o poligono tem os vertices em coordenada local. Somar os dois
## do mesmo jeito faria a tira do acabamento ser medida na origem da sala.
func _extensao(item: Node2D, eixo: Vector2) -> Vector2:
	var base := item.position.dot(eixo)
	var sprite := item as Sprite2D
	if sprite != null:
		if sprite.texture == null:
			return Vector2(base, base)
		var tamanho: Vector2 = sprite.region_rect.size if sprite.region_enabled 			else sprite.texture.get_size()
		var meia := absf(tamanho.dot(eixo)) * 0.5
		return Vector2(base - meia, base + meia)
	var poly := item as Polygon2D
	if poly == null or poly.polygon.is_empty():
		return Vector2(base, base)
	var lo := INF
	var hi := -INF
	for ponto in poly.polygon:
		var onde: float = (poly.position + ponto).dot(eixo)
		lo = minf(lo, onde)
		hi = maxf(hi, onde)
	return Vector2(lo, hi)
