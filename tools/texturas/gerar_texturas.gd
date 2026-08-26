class_name GeradorTexturas
extends Node
## Gera os PNGs de assets/texturas/ a partir da Paleta, em codigo.
##
## Use:  godot --headless --path . tools/texturas/gerar_texturas.tscn
##
## A decisao de design que este arquivo carrega: **a textura e consequencia da
## paleta, nao o contrario.** Nenhum pixel nasce num editor de imagem; nasce de
## uma funcao que so enxerga Paleta.NEUTROS e Paleta.ACENTOS. E isso que faz o
## portao G1 (todo pixel pertence a paleta) ser verdade por construcao e nao por
## disciplina -- e que faz "mudar a cor do chao" custar um hex em paleta.gd, e
## nao abrir dez arquivos.
##
## Duas garantias que os testes cobram e que moram aqui:
##
## 1. **Determinismo.** Toda aleatoriedade vem de um RandomNumberGenerator
##    local com a semente fixa de SEEDS, ou de _ruido(), que e um hash puro de
##    (x, y, semente). Nunca randi() global. Gerar duas vezes da os mesmos bytes,
##    e o teste compara o PNG em disco com o que o gerador produz hoje.
## 2. **Seamless por construcao.** O grao e amostrado em coordenada MODULAR
##    (x % largura, y % altura), e todo desenho passa por _pintar(), que faz o
##    wrap. A borda direita continua na esquerda sem retoque.
##
## O tile visual e 32 px (o unico que divide todas as dimensoes de sala). As
## texturas de chao e parede tem 128 = 4 tiles, o que da variacao de placa sem
## repeticao obvia.
##
## Este script mora em tools/ e fica fora do export. O jogo le o PNG pronto.

const PASTA := "res://assets/texturas"
const TILE := 32
const TAMANHO_CHAO := 128
const TAMANHO_PAREDE := 128
const PORTA_MOLDURA := Vector2i(96, 48)
const PORTA_CAMPO := Vector2i(80, 32)
const PROPS_ATLAS := Vector2i(256, 128)

## Os tipos de sala na ordem em que ganham semente. Novo tipo entra no fim: mudar a
## ordem muda a semente de todos e re-gera o mundo inteiro por nada.
const TIPOS: Array[StringName] = [&"combate", &"boss", &"arma", &"item", &"inicial"]

## Seed fixa por familia. Trocar uma delas e trocar a textura de proposito.
const SEEDS: Dictionary = {
	&"chao": 1001,
	&"parede": 2002,
	&"porta_moldura": 4004,
	&"porta_campo": 5005,
	&"props_atlas": 6006,
}


func _ready() -> void:
	await get_tree().process_frame
	var escritos := escrever_todas()
	print("gerar_texturas: %d arquivo(s) em %s" % [escritos, ProjectSettings.globalize_path(PASTA)])
	get_tree().quit(0)


## Nomes de arquivo (sem pasta) que o gerador sabe produzir. E a lista que o
## teste de determinismo percorre.
##
## CHAO E PAREDE SAIRAM DAQUI. Eles viraram arte autorada em
## `assets/texturas/chao_andar1_*.png` e `parede_andar1_*.png`, preparada por
## `tools/texturas/preparar_textura.py`. O que sobrou aqui e o que continua
## nascendo de codigo: as duas metades da porta e o atlas de props.
##
## `TIPOS` continua existindo e continua nesta ordem, porque ele ainda alimenta
## as linhas 2 e 3 do atlas -- o painel de acento e a marcacao de chao, uma
## coluna por tipo. Encolher `TIPOS` para acompanhar a saida do chao mataria em
## silencio justamente os props que carregam a identidade de cada sala.
static func nomes() -> Array[String]:
	var lista: Array[String] = []
	lista.append("porta_moldura.png")
	lista.append("porta_campo.png")
	lista.append("props_atlas.png")
	return lista


## Texturas que pertencem a paleta AMBIENTE (G1 e G2 valem para elas). O campo
## da porta e SINAL e fica de fora de proposito.
static func nomes_de_ambiente() -> Array[String]:
	var lista: Array[String] = []
	for nome in nomes():
		if nome != "porta_campo.png":
			lista.append(nome)
	return lista


static func gerar(nome: String) -> Image:
	match nome:
		"porta_moldura.png":
			return gerar_porta_moldura()
		"porta_campo.png":
			return gerar_porta_campo()
		"props_atlas.png":
			return gerar_props_atlas(SEEDS[&"props_atlas"])
	push_error("GeradorTexturas: textura desconhecida '%s'" % nome)
	return null


static func escrever_todas() -> int:
	DirAccess.make_dir_recursive_absolute(PASTA)
	var escritos := 0
	for nome in nomes():
		var imagem := gerar(nome)
		if imagem == null:
			continue
		var caminho := "%s/%s" % [PASTA, nome]
		var erro := imagem.save_png(caminho)
		if erro != OK:
			push_error("GeradorTexturas: falha ao salvar %s (erro %d)" % [caminho, erro])
			continue
		print("  %s  %dx%d" % [nome, imagem.get_width(), imagem.get_height()])
		escritos += 1
	return escritos


# ------------------------------------------------------------------ chao -----

## Placas de 32 em N1/N2 com junta N0 e grao raro. O chao e onde o projetil
## voa, entao o acento entra em doses homeopaticas: um respiro A0 numa placa em
## dezesseis, e UM LED A1 de 2 px em outra placa em dezesseis.
static func gerar_chao(tipo: StringName, semente: int) -> Image:
	var img := _nova(TAMANHO_CHAO, TAMANHO_CHAO)
	var rng := _rng(semente)
	var n0 := Paleta.neutro(&"N0")
	var n1 := Paleta.neutro(&"N1")
	var n2 := Paleta.neutro(&"N2")
	var n3 := Paleta.neutro(&"N3")
	var a0 := Paleta.acento(tipo, &"A0")
	var a1 := Paleta.acento(tipo, &"A1")

	var placas := TAMANHO_CHAO / TILE
	for py in placas:
		for px in placas:
			var clara := rng.randf() < 0.25
			var respiro := rng.randf() < 0.0625
			var led := rng.randf() < 0.0625
			var base := n2 if clara else n1
			var ox := px * TILE
			var oy := py * TILE

			for y in TILE:
				for x in TILE:
					var cor := base
					var grao := _ruido(ox + x, oy + y, semente)
					if grao < 0.05:
						cor = n0 if not clara else n1
					elif grao > 0.965:
						cor = n2 if not clara else n3
					# Junta de 1 px em N0 e uma aresta clara ao lado: a placa
					# le como placa, nao como quadriculado desenhado.
					if x == 0 or y == 0:
						cor = n0
					elif x == 1 or y == 1:
						cor = n2 if not clara else n3
					_pintar(img, ox + x, oy + y, cor)

			if respiro:
				# Duas linhas de A0 com vao no meio: uma grelha apagada.
				for x in range(8, 24):
					if (x / 4) % 2 == 0:
						_pintar(img, ox + x, oy + 14, a0)
						_pintar(img, ox + x, oy + 15, a0)
			if led:
				_pintar(img, ox + 24, oy + 6, a1)
				_pintar(img, ox + 25, oy + 6, a1)
	return img


# ---------------------------------------------------------------- parede -----

## Paineis de metal de 32 com moldura embutida, rebite e uma luz apagada em
## painel alternado. So uma faixa de 24 px aparece no jogo, e a fatia muda de
## lado para lado da sala -- por isso o desenho e simetrico em x e y: qualquer
## fatia de 24 px, em qualquer direcao, tem de ler como "parede".
static func gerar_parede(tipo: StringName, semente: int) -> Image:
	var img := _nova(TAMANHO_PAREDE, TAMANHO_PAREDE)
	var n4 := Paleta.neutro(&"N4")
	var n5 := Paleta.neutro(&"N5")
	var n6 := Paleta.neutro(&"N6")
	var n7 := Paleta.neutro(&"N7")
	var a0 := Paleta.acento(tipo, &"A0")
	var a1 := Paleta.acento(tipo, &"A1")
	var a2 := Paleta.acento(tipo, &"A2")

	var paineis := TAMANHO_PAREDE / TILE
	for py in paineis:
		for px in paineis:
			var ox := px * TILE
			var oy := py * TILE
			for y in TILE:
				for x in TILE:
					var cor := n5
					var grao := _ruido(ox + x, oy + y, semente)
					if grao < 0.07:
						cor = n4
					elif grao > 0.95:
						cor = n6
					# Borda externa: lit em cima/esquerda, sombra embaixo/direita.
					if x == 0 or y == 0:
						cor = n6
					elif x == TILE - 1 or y == TILE - 1:
						cor = n4
					# Moldura embutida a 3 px, mesma regra de luz.
					elif (x == 3 or y == 3) and x >= 3 and y >= 3 and x <= TILE - 4 and y <= TILE - 4:
						cor = n6
					elif (x == TILE - 4 or y == TILE - 4) and x >= 3 and y >= 3:
						cor = n4
					_pintar(img, ox + x, oy + y, cor)

			# Rebites de 1 px: N7 e o teto do brilho e nunca vira disco.
			for canto: Vector2i in [Vector2i(5, 5), Vector2i(26, 5), Vector2i(5, 26), Vector2i(26, 26)]:
				_pintar(img, ox + canto.x, oy + canto.y, n7)

			# Luz apagada no centro dos paineis alternados: carcaca A0, vidro
			# A1, um traco A2. Retangulo, nunca circulo -- circulo e projetil.
			if (px + py) % 2 == 0:
				_ret(img, ox + 11, oy + 13, 10, 6, a0)
				_ret(img, ox + 12, oy + 14, 8, 4, a1)
				_ret(img, ox + 13, oy + 15, 6, 1, a2)
	return img


# ----------------------------------------------------------------- porta -----

## Moldura de 96x48 centrada no vao de 80x32. Em coordenadas LOCAIS da porta,
## -y e sempre o lado de FORA da sala (as portas sao rotacionadas no .tscn
## para isso), entao a metade de cima da textura e a passagem e a de baixo e
## chao da sala. O que cada faixa faz:
##
##   linhas  0..19  passagem para fora, em N0 -- corredor nao revelado e escuridao
##   linhas 20..27  soleira: cobre o filete da parede, que atravessa o vao
##   linhas 28..47  transparente: o chao da sala aparece
##
## Simetrica na horizontal e quase na vertical de proposito: a porta Sul e a
## mesma textura de cabeca para baixo.
static func gerar_porta_moldura() -> Image:
	var img := _nova(PORTA_MOLDURA.x, PORTA_MOLDURA.y)
	var n0 := Paleta.neutro(&"N0")
	var n4 := Paleta.neutro(&"N4")
	var n5 := Paleta.neutro(&"N5")
	var n6 := Paleta.neutro(&"N6")
	var n7 := Paleta.neutro(&"N7")
	var largura := PORTA_MOLDURA.x
	var altura := PORTA_MOLDURA.y
	var batente := 8

	for lado: int in [0, largura - batente]:
		for y in altura:
			for i in batente:
				var x := lado + i
				var interno := i == batente - 1 if lado == 0 else i == 0
				var externo := i == 0 if lado == 0 else i == batente - 1
				var cor := n6
				if externo or y == 0 or y == altura - 1:
					cor = n4
				elif interno:
					cor = n7
				elif (i == batente - 2 if lado == 0 else i == 1):
					cor = n5
				_pintar(img, x, y, cor)
		# Parafusos do batente.
		var px: int = lado + 3 if lado == 0 else lado + 4
		_pintar(img, px, 4, n4)
		_pintar(img, px, altura - 5, n4)

	_ret(img, batente, 0, largura - 2 * batente, 20, n0)
	_ret(img, batente, 20, largura - 2 * batente, 8, n5)
	_ret(img, batente, 20, largura - 2 * batente, 1, n6)
	_ret(img, batente, 27, largura - 2 * batente, 1, n4)
	# Ranhuras da soleira a cada 16 px.
	for x in range(batente + 8, largura - batente, 16):
		_ret(img, x, 21, 1, 6, n4)
	return img


## Campo de forca de 80x32: scanlines nos dois tons de SINAL. E a unica textura
## fora da paleta AMBIENTE, e por isso e a unica que so aparece TRANCADA -- e
## sempre com 80x32, tamanho que nenhum projetil tem.
static func gerar_porta_campo() -> Image:
	var img := _nova(PORTA_CAMPO.x, PORTA_CAMPO.y)
	var claro: Color = Paleta.SINAL[&"porta_trancada"]
	var escuro: Color = Paleta.SINAL[&"porta_trancada_sombra"]
	for y in PORTA_CAMPO.y:
		for x in PORTA_CAMPO.x:
			var cor := claro if (y / 2) % 2 == 0 else escuro
			if x == 0 or x == PORTA_CAMPO.x - 1 or y == 0 or y == PORTA_CAMPO.y - 1:
				cor = claro
			_pintar(img, x, y, cor)
	return img


# ----------------------------------------------------------------- props -----

## Atlas de 8x4 celulas de 32. Linhas 0 e 1 sao neutras e servem a qualquer
## sala; a linha 2 e um painel de parede e a 3 uma marcacao de chao, uma
## celula por tipo na ordem de TIPOS. Qual celula cada tipo usa esta em
## `regioes_props` do tipo_*.tres -- o atlas so oferece.
static func gerar_props_atlas(semente: int) -> Image:
	var img := _nova(PROPS_ATLAS.x, PROPS_ATLAS.y)

	# Linha 0
	_prop_caixa(img, _cel(0, 0) + Vector2i(4, 6), 24, 20)
	_prop_caixa(img, _cel(1, 0) + Vector2i(8, 10), 16, 14)
	_prop_barril(img, _cel(2, 0) + Vector2i(16, 16), 10)
	_prop_cano_h(img, _cel(3, 0))
	_prop_grade(img, _cel(4, 0) + Vector2i(4, 8), 24, 16)
	_prop_entulho(img, _cel(5, 0), semente + 1)
	_prop_mancha(img, _cel(6, 0), semente + 2)
	_prop_terminal(img, _cel(7, 0))
	# Linha 1
	_prop_caixa(img, _cel(0, 1) + Vector2i(2, 14), 14, 12)
	_prop_caixa(img, _cel(0, 1) + Vector2i(16, 10), 14, 16)
	_prop_cabo(img, _cel(1, 1) + Vector2i(16, 16), 9)
	_prop_placa(img, _cel(2, 1) + Vector2i(4, 4), 24)
	_prop_cano_v(img, _cel(3, 1))
	_prop_cano_canto(img, _cel(4, 1))
	_prop_tambor(img, _cel(5, 1) + Vector2i(16, 16), 9)
	_prop_fita(img, _cel(6, 1))
	_prop_entulho(img, _cel(7, 1), semente + 3)
	# Linhas 2 e 3: uma por tipo.
	for i in TIPOS.size():
		_prop_painel_acento(img, _cel(i, 2), TIPOS[i])
		_prop_marcacao_acento(img, _cel(i, 3), TIPOS[i])
	return img


static func _cel(coluna: int, linha: int) -> Vector2i:
	return Vector2i(coluna * TILE, linha * TILE)


static func _prop_caixa(img: Image, o: Vector2i, w: int, h: int) -> void:
	var n4 := Paleta.neutro(&"N4")
	var n5 := Paleta.neutro(&"N5")
	var n6 := Paleta.neutro(&"N6")
	_ret(img, o.x, o.y, w, h, n5)
	_ret(img, o.x, o.y, w, 1, n6)
	_ret(img, o.x, o.y, 1, h, n6)
	_ret(img, o.x, o.y + h - 1, w, 1, n4)
	_ret(img, o.x + w - 1, o.y, 1, h, n4)
	# Cinta central e rebites nos cantos.
	_ret(img, o.x + w / 2 - 1, o.y + 1, 2, h - 2, n4)
	for c: Vector2i in [Vector2i(2, 2), Vector2i(w - 3, 2), Vector2i(2, h - 3), Vector2i(w - 3, h - 3)]:
		_pintar(img, o.x + c.x, o.y + c.y, n6)


static func _prop_barril(img: Image, c: Vector2i, r: int) -> void:
	_disco(img, c, r, Paleta.neutro(&"N6"))
	_disco(img, c, r - 1, Paleta.neutro(&"N5"))
	_anel(img, c, r - 4, Paleta.neutro(&"N4"))
	_pintar(img, c.x, c.y, Paleta.neutro(&"N4"))


static func _prop_tambor(img: Image, c: Vector2i, r: int) -> void:
	_disco(img, c, r, Paleta.neutro(&"N5"))
	_disco(img, c, r - 1, Paleta.neutro(&"N4"))
	_disco(img, c, r - 3, Paleta.neutro(&"N0"))


static func _prop_cabo(img: Image, c: Vector2i, r: int) -> void:
	_anel(img, c, r, Paleta.neutro(&"N4"))
	_anel(img, c, r - 1, Paleta.neutro(&"N5"))
	_anel(img, c, r - 2, Paleta.neutro(&"N4"))
	_anel(img, c, r - 3, Paleta.neutro(&"N3"))


static func _prop_cano_h(img: Image, o: Vector2i) -> void:
	var n4 := Paleta.neutro(&"N4")
	var n5 := Paleta.neutro(&"N5")
	var n6 := Paleta.neutro(&"N6")
	_ret(img, o.x, o.y + 12, TILE, 8, n5)
	_ret(img, o.x, o.y + 12, TILE, 2, n6)
	_ret(img, o.x, o.y + 19, TILE, 1, n4)
	for fx: int in [6, 22]:
		_ret(img, o.x + fx, o.y + 10, 4, 12, n6)
		_ret(img, o.x + fx + 3, o.y + 10, 1, 12, n4)


static func _prop_cano_v(img: Image, o: Vector2i) -> void:
	var n4 := Paleta.neutro(&"N4")
	var n5 := Paleta.neutro(&"N5")
	var n6 := Paleta.neutro(&"N6")
	_ret(img, o.x + 12, o.y, 8, TILE, n5)
	_ret(img, o.x + 12, o.y, 2, TILE, n6)
	_ret(img, o.x + 19, o.y, 1, TILE, n4)
	for fy: int in [6, 22]:
		_ret(img, o.x + 10, o.y + fy, 12, 4, n6)
		_ret(img, o.x + 10, o.y + fy + 3, 12, 1, n4)


static func _prop_cano_canto(img: Image, o: Vector2i) -> void:
	var n4 := Paleta.neutro(&"N4")
	var n5 := Paleta.neutro(&"N5")
	var n6 := Paleta.neutro(&"N6")
	_ret(img, o.x + 12, o.y + 12, 20, 8, n5)
	_ret(img, o.x + 12, o.y + 12, 8, 20, n5)
	_ret(img, o.x + 12, o.y + 12, 20, 2, n6)
	_ret(img, o.x + 12, o.y + 12, 2, 20, n6)
	_ret(img, o.x + 14, o.y + 19, 18, 1, n4)
	_ret(img, o.x + 19, o.y + 14, 1, 18, n4)
	_ret(img, o.x + 10, o.y + 10, 12, 12, n6)
	_ret(img, o.x + 11, o.y + 11, 10, 10, n5)


static func _prop_grade(img: Image, o: Vector2i, w: int, h: int) -> void:
	var n0 := Paleta.neutro(&"N0")
	var n3 := Paleta.neutro(&"N3")
	var n4 := Paleta.neutro(&"N4")
	_ret(img, o.x, o.y, w, h, n4)
	for y in range(2, h - 2):
		var cor := n0 if (y / 2) % 2 == 0 else n3
		_ret(img, o.x + 2, o.y + y, w - 4, 1, cor)


static func _prop_placa(img: Image, o: Vector2i, lado: int) -> void:
	var n2 := Paleta.neutro(&"N2")
	var n3 := Paleta.neutro(&"N3")
	var n4 := Paleta.neutro(&"N4")
	_ret(img, o.x, o.y, lado, lado, n4)
	_ret(img, o.x + 1, o.y + 1, lado - 2, lado - 2, n2)
	for c: Vector2i in [Vector2i(3, 3), Vector2i(lado - 4, 3), Vector2i(3, lado - 4), Vector2i(lado - 4, lado - 4)]:
		_pintar(img, o.x + c.x, o.y + c.y, n3)
	_ret(img, o.x + 6, o.y + lado / 2, lado - 12, 1, n3)


static func _prop_terminal(img: Image, o: Vector2i) -> void:
	var n0 := Paleta.neutro(&"N0")
	var n4 := Paleta.neutro(&"N4")
	var n5 := Paleta.neutro(&"N5")
	var n6 := Paleta.neutro(&"N6")
	var n7 := Paleta.neutro(&"N7")
	_ret(img, o.x + 8, o.y + 4, 16, 24, n5)
	_ret(img, o.x + 8, o.y + 4, 16, 1, n6)
	_ret(img, o.x + 8, o.y + 4, 1, 24, n6)
	_ret(img, o.x + 23, o.y + 4, 1, 24, n4)
	_ret(img, o.x + 8, o.y + 27, 16, 1, n4)
	_ret(img, o.x + 10, o.y + 7, 12, 9, n4)
	_ret(img, o.x + 11, o.y + 8, 10, 7, n0)
	_ret(img, o.x + 10, o.y + 19, 12, 2, n4)
	_ret(img, o.x + 10, o.y + 23, 12, 1, n4)
	_pintar(img, o.x + 21, o.y + 25, n7)


static func _prop_entulho(img: Image, o: Vector2i, semente: int) -> void:
	var rng := _rng(semente)
	var tons: Array[Color] = [Paleta.neutro(&"N3"), Paleta.neutro(&"N4"), Paleta.neutro(&"N2")]
	for _i in 9:
		var w := rng.randi_range(2, 6)
		var h := rng.randi_range(2, 4)
		var x := rng.randi_range(4, TILE - 4 - w)
		var y := rng.randi_range(6, TILE - 6 - h)
		_ret(img, o.x + x, o.y + y, w, h, tons[rng.randi_range(0, tons.size() - 1)])


static func _prop_mancha(img: Image, o: Vector2i, semente: int) -> void:
	var n0 := Paleta.neutro(&"N0")
	var n2 := Paleta.neutro(&"N2")
	var c := o + Vector2i(16, 16)
	for y in TILE:
		for x in TILE:
			var d := Vector2(x - 16, y - 16).length()
			var borda := 6.0 + 5.0 * _ruido(x / 3, y / 3, semente)
			if d < borda:
				_pintar(img, o.x + x, o.y + y, n0)
			elif d < borda + 1.5 and _ruido(x, y, semente) > 0.4:
				_pintar(img, o.x + x, o.y + y, n2)
	_pintar(img, c.x, c.y, n0)


static func _prop_fita(img: Image, o: Vector2i) -> void:
	var n3 := Paleta.neutro(&"N3")
	var n4 := Paleta.neutro(&"N4")
	for i in TILE:
		for k in 3:
			var x := i
			var y := (i + k + 6) % TILE
			var cor := n4 if ((i + k) / 4) % 2 == 0 else n3
			if y >= 4 and y < TILE - 4:
				_pintar(img, o.x + x, o.y + y, cor)


static func _prop_painel_acento(img: Image, o: Vector2i, tipo: StringName) -> void:
	var n4 := Paleta.neutro(&"N4")
	var n5 := Paleta.neutro(&"N5")
	var n6 := Paleta.neutro(&"N6")
	var a0 := Paleta.acento(tipo, &"A0")
	var a1 := Paleta.acento(tipo, &"A1")
	var a2 := Paleta.acento(tipo, &"A2")
	_ret(img, o.x + 4, o.y + 4, 24, 24, n5)
	_ret(img, o.x + 4, o.y + 4, 24, 1, n6)
	_ret(img, o.x + 4, o.y + 4, 1, 24, n6)
	_ret(img, o.x + 4, o.y + 27, 24, 1, n4)
	_ret(img, o.x + 27, o.y + 4, 1, 24, n4)
	_ret(img, o.x + 7, o.y + 7, 18, 12, a0)
	_ret(img, o.x + 9, o.y + 10, 14, 1, a1)
	_ret(img, o.x + 9, o.y + 13, 10, 1, a1)
	_ret(img, o.x + 9, o.y + 16, 12, 1, a1)
	_ret(img, o.x + 9, o.y + 16, 4, 1, a2)
	_ret(img, o.x + 8, o.y + 22, 16, 2, n4)


static func _prop_marcacao_acento(img: Image, o: Vector2i, tipo: StringName) -> void:
	var a0 := Paleta.acento(tipo, &"A0")
	var a1 := Paleta.acento(tipo, &"A1")
	_ret(img, o.x + 2, o.y + 13, 28, 6, a0)
	for x in range(4, 28, 8):
		_ret(img, o.x + x, o.y + 15, 4, 2, a1)


# --------------------------------------------------------------- helpers -----

static func _nova(largura: int, altura: int) -> Image:
	var img := Image.create_empty(largura, altura, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	return img


static func _rng(semente: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	return rng


## Toda escrita passa por aqui e faz wrap: e o que torna a textura seamless
## sem ninguem pensar na borda.
static func _pintar(img: Image, x: int, y: int, cor: Color) -> void:
	img.set_pixel(posmod(x, img.get_width()), posmod(y, img.get_height()), cor)


static func _ret(img: Image, x: int, y: int, w: int, h: int, cor: Color) -> void:
	for dy in h:
		for dx in w:
			_pintar(img, x + dx, y + dy, cor)


static func _disco(img: Image, c: Vector2i, r: int, cor: Color) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				_pintar(img, c.x + dx, c.y + dy, cor)


static func _anel(img: Image, c: Vector2i, r: int, cor: Color) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d := dx * dx + dy * dy
			if d <= r * r and d > (r - 1) * (r - 1):
				_pintar(img, c.x + dx, c.y + dy, cor)


## Hash puro de (x, y, semente) em [0, 1). Nao depende da ordem de chamada, o que
## e o que garante determinismo e seamless ao mesmo tempo: o pixel (x, y) tem
## sempre o mesmo grao, esteja ele na borda ou no meio.
static func _ruido(x: int, y: int, semente: int) -> float:
	var h: int = x * 374761393 + y * 668265263 + semente * 1274126177
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / float(0x1000000)
