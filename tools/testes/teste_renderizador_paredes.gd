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
	ok(conferidas > 300, "a varredura mediu as celulas de todas as formas (%d)" % conferidas)


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
				var faixa := _extensao(item, eixo)
				if faixa.y > centro - meia + 0.5 and faixa.x < centro + meia - 0.5:
					invasores += 1
			igual(
				invasores, 0,
				"%s/%s: nenhum modulo desenha dentro do vao (%d)"
					% [caminho.get_file(), porta.name, invasores]
			)

			# E A RESERVA E EXATA: o primeiro modulo ao lado do vao encosta nele.
			#
			# Antes da grade ancorada na sala, cada lado tinha a propria grade e a
			# mesma porta caia em lugares diferentes dela conforme a paridade da
			# meia dimensao daquela sala -- 2 celulas reservadas num lado e 3 no
			# outro para o mesmo vao. Os 32 px de sobra apareciam como parede
			# antiga ao lado do batente, e nada acusava.
			#
			# Com o vao em 64 e a borda de celula caindo no centro da porta, o
			# modulo vizinho tem de estar a meia celula da borda do vao -- 48 px do
			# centro. Mais que isso e sobra.
			var vizinho := 9999.0
			for peca in fita.get_children():
				var sprite := peca as Sprite2D
				if sprite == null or not sprite.region_enabled:
					continue
				if sprite.position.dot(porta.vetor()) < 0.0:
					continue
				var onde := sprite.position.dot(eixo)
				vizinho = minf(vizinho, absf(onde - centro))
			ok(
				vizinho <= meia + CELULA * 0.5 + 0.5,
				"%s/%s: a reserva e exata -- o modulo vizinho esta a %.0f px do centro (teto %.0f)"
					% [caminho.get_file(), porta.name, vizinho, meia + CELULA * 0.5]
			)
		sala.free()
	ok(conferidas >= 15, "a varredura achou as portas abertas das salas (%d)" % conferidas)


## TODA QUINA RECEBE CANTO, e a sala em L e o caso que prova.
##
## O contorno de uma sala e um poligono qualquer, e o renderizador classifica
## cada quina pelo par de lados que se encontram nela. Quina que nao cai no mapa
## sai SEM peca -- e o sintoma e um pedaco de faixa sem articulacao, visivel so
## naquela forma de sala e em nenhuma outra. Nao ha erro no console para canto
## faltando.
##
## A sala em L e o caso duro por dois motivos: ela tem SEIS quinas em vez de
## quatro, e uma delas e CONCAVA -- a do fundo da mordida, onde as duas faixas se
## sobrepoem em vez de contornar. As duas familias usam a mesma peca de
## proposito, e este caso e o que prova que a concava nao ficou de fora.
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
		# A celula de fita e um RECORTE da textura autorada, entao ela tem
		# `region_enabled`. O canto e a peca inteira, e nao tem. E a unica
		# diferenca estrutural entre as duas, e ela nao depende de tamanho -- o
		# dia em que um canto tiver outro lado, esta conta continua valendo.
		var deste := 0
		for filho in fita.get_children():
			var sprite := filho as Sprite2D
			if sprite != null and not sprite.region_enabled:
				deste += 1
		quinas += contorno.size()
		cantos += deste
		igual(
			deste, contorno.size(),
			"%s: as %d quinas receberam canto (%d)"
				% [caminho.get_file(), contorno.size(), deste]
		)
		sala.free()
	ok(quinas >= 38, "a varredura contou as quinas das nove formas (%d)" % quinas)
	igual(cantos, quinas, "nenhuma quina ficou sem peca (%d de %d)" % [cantos, quinas])


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

	# 2. O COMUM DOMINA. Medido sem espacamento, que e onde o peso age sozinho.
	var comuns := _contar(solto, faces[0])
	var especiais := _contar_especiais(solto, faces)
	var total := comuns + especiais
	ok(total > 80, "a amostra tem celulas de face suficientes (%d)" % total)
	if total > 0:
		var fracao := float(comuns) / float(total)
		entre(
			fracao, 0.55, 0.75,
			"o modulo comum domina (%.0f%% de %d celulas, alvo 65%%)"
				% [fracao * 100.0, total]
		)

	# 3. O ESPACAMENTO MORDE.
	var especiais_apertado := _contar_especiais(apertado, faces)
	ok(
		especiais_apertado < especiais,
		"o espacamento MORDE: %d especiais com ele contra %d sem -- teto que nao morde nao foi testado"
			% [especiais_apertado, especiais]
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
		var tiras := 0
		var fora := 0
		var costuras_ao_sul := 0
		var costuras := 0
		for filho in fita.get_children():
			var poly := filho as Polygon2D
			if poly == null or poly.polygon.is_empty():
				continue
			tiras += 1
			# A profundidade de cada vertice, medida a partir do lado mais
			# proximo do contorno. Fora de [0, 64] a peca saiu da faixa.
			for ponto in poly.polygon:
				var mundo: Vector2 = poly.position + ponto
				var d := _profundidade(mundo, contorno)
				if d < -0.5 or d > alcance + 0.5:
					fora += 1
			if poly.color.is_equal_approx(RenderizadorParedes.N4) 					or poly.color.is_equal_approx(RenderizadorParedes.N7):
				var meio := poly.position
				var d := _profundidade(meio, contorno)
				if absf(d - RenderizadorParedes.COSTURA) <= 2.0:
					costuras += 1
					# Ao sul a fita e topo puro: costura ali e linha no meio de
					# uma superficie continua.
					if meio.y > _caixa(contorno).end.y:
						costuras_ao_sul += 1
		var nome := caminho.get_file()
		ok(tiras > 0, "%s: a fita monta acabamento (%d tiras)" % [nome, tiras])
		igual(fora, 0, "%s: nenhum vertice do acabamento sai da faixa de %.0f px (%d)"
			% [nome, alcance, fora])
		ok(costuras > 0, "%s: a costura existe onde ha face (%d)" % [nome, costuras])
		igual(costuras_ao_sul, 0,
			"%s: nenhuma costura na parede SUL -- la nao ha face para virar (%d)"
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
