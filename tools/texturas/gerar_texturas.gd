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
## 96 de largura = o vao de 80 mais 8 px de batente de cada lado.
## 128 de altura porque a faixa de parede passou de 24 para 64 na migracao Low
## Top-Down: a moldura tem de cobrir a faixa inteira, senao a porta aparece
## como um retangulo de 24 px no meio de uma parede de 64.
const PORTA_MOLDURA := Vector2i(96, 128)

## A porta em NUMEROS, e eles sao os mesmos nos quatro lados (PORTA 03).
##
## AO LONGO da parede sao 80 px -- e `Porta.LARGURA`, o vao que a parede abre --
## mais 8 px de folga de cada lado, o que da os 96 da moldura autorada.
## ATRAVESSANDO a parede sao 64 px de banda mais 64 dentro da sala: os 128.
##
## A ABERTURA de 32 nao foi escolhida, foi MEDIDA no alfa da
## `porta_moldura.png` (colunas 32..63). O que sobra de cada lado -- 24 px de
## batente -- e onde a folha recolhe, e e por isso que meia folha, 16 px, cabe
## atras dele com folga. As vistas de cima repetem esse desenho para que a mesma
## porta tenha a mesma medida nos quatro lados.
const PORTA_ABERTURA := 32
const PORTA_BATENTE := 24
## A banda de parede vista de cima. E o mesmo numero de `Sala.ESPESSURA_PAREDE`.
const PORTA_BANDA := 64

## A vista de CIMA da porta, para os lados que so mostram o topo da parede
## (sul, leste e oeste). Transposta em `porta_lado`, nunca rotacionada.
const PORTA_TOPO := Vector2i(96, 128)
const PORTA_LADO := Vector2i(128, 96)

## A FOLHA vista de cima: a chapa dentro da espessura da parede. O sprite cobre
## a banda inteira para a metade poder deslizar dentro dele.
const PORTA_FOLHA_TOPO := Vector2i(32, 64)
const PORTA_FOLHA_LADO := Vector2i(64, 32)

## O RECESSO das vistas de cima: o poco da passagem, visto de cima.
##
## Ele e uma peca SEPARADA da moldura pela mesma razao que no norte: a folha
## desliza ENTRE os dois. Desenhar o poco dentro da propria moldura -- que foi a
## primeira versao desta issue -- poe um retangulo opaco por cima da chapa, e a
## porta trancada volta a ser um buraco com um adesivo luminoso na frente. O
## defeito nao aparece em teste de arquivo nenhum: as duas texturas estavam
## certas, so estavam na ordem errada.
const PORTA_VAO_TOPO := Vector2i(32, 64)
const PORTA_VAO_LADO := Vector2i(64, 32)

## O indicador de TRANCADA, e a unica peca da porta que fica na paleta SINAL.
##
## Ele e uma BARRA que atravessa a abertura, e nao a folha inteira: a folha e
## chapa de ambiente, e o sinal e detalhe sobre ela. Barra e nao disco pela
## razao de sempre -- disco e a silhueta de um projetil.
const PORTA_TRAVA := Vector2i(32, 16)
const PORTA_TRAVA_LADO := Vector2i(16, 32)

## O RECESSO do vao: o que se ve DENTRO do batente.
##
## Ele existe porque a moldura autorada tem um buraco literal. A moldura gerada
## que ela substituiu na LTD 11 preenchia o vao com N0 opaco -- `gerar_porta_moldura`
## ainda tem a linha, comentada como "corredor nao revelado e escuridao" --, e
## esse codigo saiu de `nomes()` junto com a migracao. O fundo se perdeu ali, e
## sem ele a parede aparece por dentro da porta: no lado NORTE, que e o unico que
## ganha face, o que se ve e o modulo autorado de face dentro do batente.
##
## Tile PROPRIO em vez de repintar a moldura: os batentes, a verga e a soleira
## sao arte autorada e nao podem mudar um pixel, e um no separado deixa o recesso
## disponivel para a folha da porta deslizar POR CIMA dele quando a abertura
## virar abertura de verdade.
const PORTA_VAO := Vector2i(32, 48)

## Onde a abertura da moldura cai dentro deste tile, em linhas.
##
## Medido na propria `porta_moldura.png`: a regiao transparente dela vai da linha
## 29 a 62, e o recesso e centrado em (0, -18) na cena. Sao numeros de UM lugar
## so, e `teste_porta.gd` confere que eles ainda casam com o alfa da moldura --
## um recesso deslocado deixaria uma fresta, e fresta e por onde a parede volta a
## vazar.
const VAO_LINHA_INICIAL := 7
const VAO_LINHA_FINAL := 40
const PROPS_ATLAS := Vector2i(256, 128)
## O MODULO de parede: 32 px ao longo do muro, 64 atravessando a faixa.
##
## 32 e o tile visual do projeto e o unico numero que divide toda dimensao de
## sala; 64 e `Sala.ESPESSURA_PAREDE`, a faixa inteira. A metade interna dela --
## os 32 colados no contorno -- e a FACE, e a externa e o TOPO. A razao 1:1 entre
## as duas e o que o `LOW_TOPDOWN_SQUARED.md` secao 24 exige, e ela ja estava
## satisfeita antes deste epico: o que muda aqui e a parede deixar de ser uma
## textura esticada e virar uma fita de pecas.
const MODULO := 32
const MODULO_VERTICAL := Vector2i(32, 64)
const MODULO_HORIZONTAL := Vector2i(64, 32)
const MODULO_CANTO := Vector2i(64, 64)

## Lado do tile da parede Low Top-Down (docs/LOW_TOPDOWN_SQUARED.md secao 14).
## Multiplo de 16 e de 32, entao nao mexe na grade estrutural do projeto.
const TILE_PAREDE := 64
## Sub-grade dentro do tile: e nela que caem as juntas entre placas. O olho le
## a placa de 32 mesmo com o tile de 64, e 32 divide toda dimensao de sala.
const PLACA := 32

## Os tipos de sala na ordem em que ganham semente. Novo tipo entra no fim: mudar a
## ordem muda a semente de todos e re-gera o mundo inteiro por nada.
const TIPOS: Array[StringName] = [&"combate", &"boss", &"arma", &"item", &"inicial"]

## Seed fixa por familia. Trocar uma delas e trocar a textura de proposito.
const SEEDS: Dictionary = {
	&"chao": 1001,
	&"parede": 2002,
	&"porta_moldura": 4004,
	&"porta_vao": 5105,
	&"porta_topo": 5205,
	&"porta_lado": 5305,
	&"modulo": 6106,
	&"props_atlas": 6006,
	&"parede_topo": 7007,
	&"parede_face": 8008,
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
## nascendo de codigo: o CAMPO da porta, o atlas de props chapados e o TOPO da
## parede.
##
## A MOLDURA da porta saiu na LTD 11, pelo mesmo motivo da face: ela virou arte
## autorada -- batentes rebitados, verga aparafusada, ferragem lateral -- e G1
## cobra pertinencia a uma lista de 22 cores, o que proibe gradiente e sombra.
## O CAMPO fica: ele e SINAL, nao ambiente, e a funcao dele e dizer "trancada"
## em um quadro. Cor de sinal nao e lugar para arte autorada.
##
## A FACE saiu daqui na identidade industrial do andar 1. O motivo e o mesmo do
## chao: ela virou arte autorada, e arte autorada nao passa por G1 -- aquele
## portao cobra pertinencia a uma LISTA de 22 cores, o que proibe gradiente,
## dithering e sombra, que e exatamente o que tira a superficie do chapado. Ela
## passou para o regime AUTORADO de `teste_texturas.gd`, onde o que se cobra e
## regra medida: gamut, teto de valor, faixa de matiz e costura.
##
## `gerar_parede_face()` continua abaixo e continua sem ser chamada por
## `nomes()`. Ela fica como registro de onde a face veio e como referencia de
## valor -- foi ela que estabeleceu que a face e mais ESCURA que o topo, que e
## o que vende a altura e o que `_a_parede_tem_volume()` mede.
##
## `TIPOS` continua existindo e continua nesta ordem, porque ele ainda alimenta
## as linhas 2 e 3 do atlas -- o painel de acento e a marcacao de chao, uma
## coluna por tipo. Encolher `TIPOS` para acompanhar a saida do chao mataria em
## silencio justamente os props que carregam a identidade de cada sala.
static func nomes() -> Array[String]:
	var lista: Array[String] = []
	lista.append("porta_trava.png")
	lista.append("porta_vao.png")
	lista.append("modulo_n.png")
	lista.append("modulo_s.png")
	lista.append("modulo_l.png")
	lista.append("modulo_o.png")
	lista.append("props_atlas.png")
	return lista


## As texturas que ficam na paleta SINAL, e nao na AMBIENTE.
##
## Sao as duas barras de trancada -- o que sobrou do campo de forca depois que a
## porta ganhou folha (PORTA 01). Sinal e para DETALHE: uma lista pequena aqui e
## a prova de que ele continua sendo detalhe.
const SINALIZADORAS: Array[String] = ["porta_trava.png"]


## Texturas que pertencem a paleta AMBIENTE (G1 e G2 valem para elas). As barras
## de trancada sao SINAL e ficam de fora de proposito.
static func nomes_de_ambiente() -> Array[String]:
	var lista: Array[String] = []
	for nome in nomes():
		if not SINALIZADORAS.has(nome):
			lista.append(nome)
	return lista


static func gerar(nome: String) -> Image:
	match nome:
		"porta_moldura.png":
			return gerar_porta_moldura()
		"porta_trava.png":
			return gerar_porta_trava()
		"porta_vao.png":
			return gerar_porta_vao()
		"modulo_n.png":
			return gerar_modulo_n()
		"modulo_s.png":
			return gerar_modulo_s()
		"modulo_l.png":
			return gerar_modulo_l()
		"modulo_o.png":
			return gerar_modulo_o()
		"props_atlas.png":
			return gerar_props_atlas(SEEDS[&"props_atlas"])
		"parede_topo.png":
			return gerar_parede_topo(SEEDS[&"parede_topo"])
		"parede_face.png":
			return gerar_parede_face(SEEDS[&"parede_face"])
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
## O TOPO da parede: a espessura dela, vista de cima.
##
## Base N6 porque a paleta ja dizia isso antes desta migracao existir --
## "N6 metal medio: o topo da parede". A direcao de luz global (de cima e da
## esquerda, IDENTIDADE_VISUAL) cai daqui: o topo pega a luz e por isso e mais
## CLARO que a face; a face fica no tom intermediario e a base, na sombra.
##
## Esse par claro/escuro nao e enfeite -- e o que vende a altura. Se o topo e a
## face tiverem o mesmo valor, a parede volta a ler como faixa chapada, que e
## exatamente o que a migracao existe para sair. `teste_texturas.gd` mede.
##
## Placas de 32 dentro do tile de 64: o olho le a sub-grade que o projeto ja
## usa, e 32 divide toda dimensao de sala (64 nao divide 544).
##
## ATENCAO: o PNG que sai daqui AINDA NAO E DESENHADO em jogo. `Sala` texturiza
## o no `ParedeTopo` com a parede DO TIPO (`parede_boss.png` e companhia),
## porque a identidade de cada tipo de sala mora no topo desde antes desta
## migracao existir. Quem consome `parede_topo.png` hoje e so o portao de
## volume de `teste_texturas.gd`, que mede o valor dela contra o da face.
##
## Isso vira na LTD 13 (issue #43), quando a identidade do tipo desce para a
## FACE e o topo passa a ser a superficie neutra comum. Ate la a funcao fica --
## remover o gerador derrubaria o portao de volume, que e o unico lugar do
## projeto onde "a parede tem altura" e uma afirmacao medida.
static func gerar_parede_topo(semente: int) -> Image:
	var img := _nova(TILE_PAREDE, TILE_PAREDE)
	var n4 := Paleta.neutro(&"N4")
	var n5 := Paleta.neutro(&"N5")
	var n6 := Paleta.neutro(&"N6")
	var n7 := Paleta.neutro(&"N7")

	for y in TILE_PAREDE:
		for x in TILE_PAREDE:
			var cor := n6
			var grao := _ruido(x, y, semente)
			if grao < 0.10:
				cor = n5
			var px := x % PLACA
			var py := y % PLACA
			# Junta entre placas: sempre linha, nunca ponto. Ponto isolado de
			# 3 a 6 px e a silhueta de um projetil, e o cenario nao pode ter.
			if px == 0 or py == 0:
				cor = n5
			elif px == PLACA - 1 or py == PLACA - 1:
				cor = n4
			_pintar(img, x, y, cor)

	# Aresta iluminada da placa: N7 e o teto do brilho do ambiente, entao entra
	# em pixel solto no canto lit, nunca em linha inteira.
	for py in range(0, TILE_PAREDE, PLACA):
		for px in range(0, TILE_PAREDE, PLACA):
			_pintar(img, px + 1, py + 1, n7)
			_pintar(img, px + 2, py + 1, n7)
	return img


## A FACE da parede: a superficie vertical que a camera Low Top-Down enxerga.
##
## Base N5 -- "metal escuro: o corpo da parede", de novo direto da paleta. Ela
## e mais escura que o topo de proposito (ver gerar_parede_topo).
##
## Tres faixas horizontais, e as tres saem da direcao de luz:
##   - o LABIO de cima, onde a face encontra o topo, pega luz -> N6
##   - o CORPO fica no tom intermediario -> N5
##   - a BASE, onde a parede encontra o chao, fica na sombra -> N4
##
## Costura so importa na horizontal: a face ladrilha ao longo da parede, e na
## vertical ela e uma peca so.
static func gerar_parede_face(semente: int) -> Image:
	var img := _nova(TILE_PAREDE, TILE_PAREDE)
	var n4 := Paleta.neutro(&"N4")
	var n5 := Paleta.neutro(&"N5")
	var n6 := Paleta.neutro(&"N6")

	const LABIO := 4
	const BASE := 8

	for y in TILE_PAREDE:
		for x in TILE_PAREDE:
			var cor := n5
			if y < LABIO:
				cor = n6
			elif y >= TILE_PAREDE - BASE:
				cor = n4
			else:
				var grao := _ruido(x, y, semente)
				if grao < 0.08:
					cor = n4
				elif grao > 0.94:
					cor = n6
				# Montante vertical a cada placa: da ritmo a face sem nenhum
				# elemento aceso. O acento da sala entra depois (LTD 13).
				if x % PLACA == 0:
					cor = n4
				elif x % PLACA == 1:
					cor = n6
			_pintar(img, x, y, cor)
	return img


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
	# A soleira fica sobre a linha do contorno, que e o meio do sprite.
	var soleira := altura / 2 - 4
	# O batente para na soleira em vez de descer o sprite inteiro. Ele desenha
	# a lateral do VAO, e o vao acaba onde a parede acaba: continuar para
	# dentro poe duas barras de metal de pe no meio do chao da sala. Com a
	# moldura de 48 isso eram 24 px e passava; com 128 sao 64, e aparece.
	var fundo := soleira + 8

	for lado: int in [0, largura - batente]:
		for y in fundo:
			for i in batente:
				var x := lado + i
				var interno := i == batente - 1 if lado == 0 else i == 0
				var externo := i == 0 if lado == 0 else i == batente - 1
				var cor := n6
				if externo or y == 0 or y == fundo - 1:
					cor = n4
				elif interno:
					cor = n7
				elif (i == batente - 2 if lado == 0 else i == 1):
					cor = n5
				_pintar(img, x, y, cor)
		# Parafusos do batente.
		var px: int = lado + 3 if lado == 0 else lado + 4
		_pintar(img, px, 4, n4)
		_pintar(img, px, fundo - 5, n4)

	var vao := largura - 2 * batente
	_ret(img, batente, 0, vao, soleira, n0)
	_ret(img, batente, soleira, vao, 8, n5)
	_ret(img, batente, soleira, vao, 1, n6)
	_ret(img, batente, soleira + 7, vao, 1, n4)
	# Ranhuras da soleira a cada 16 px.
	for x in range(batente + 8, largura - batente, 16):
		_ret(img, x, soleira + 1, 1, 6, n4)
	return img


static func gerar_porta_trava() -> Image:
	return _barra_de_trava(PORTA_TRAVA, true)


static func _barra_de_trava(tamanho: Vector2i, horizontal: bool) -> Image:
	var img := _nova(tamanho.x, tamanho.y)
	var claro: Color = Paleta.SINAL[&"porta_trancada"]
	var escuro: Color = Paleta.SINAL[&"porta_trancada_sombra"]
	if horizontal:
		var y := tamanho.y / 2 - 3
		_ret(img, 0, y, tamanho.x, 6, escuro)
		_ret(img, 0, y + 1, tamanho.x, 3, claro)
	else:
		var x := tamanho.x / 2 - 3
		_ret(img, x, 0, 6, tamanho.y, escuro)
		_ret(img, x + 1, 0, 3, tamanho.y, claro)
	return img


## O recesso do vao: escuridao com um piso e uma soleira.
##
## Tudo em AMBIENTE, e o mais escuro que a paleta tem. O vao NAO pode virar
## sinal: `porta_trava` ja e o sinal de "trancada", e dois sinais na mesma
## silhueta cancelam um ao outro.
##
## A luz vem de cima e da esquerda (LOW_TOPDOWN secao 18), entao a sombra e mais
## funda embaixo da verga e o piso da passagem pega o pouco que sobra. A soleira
## e uma LINHA de 1 px e nao um bloco: detalhe pequeno neste projeto e sempre
## linha, junta ou canto -- nunca um disco, que e a silhueta de um tiro.
static func gerar_porta_vao() -> Image:
	var img := _nova(PORTA_VAO.x, PORTA_VAO.y)
	var n0: Color = Paleta.NEUTROS[&"N0"]
	var n1: Color = Paleta.NEUTROS[&"N1"]
	var n2: Color = Paleta.NEUTROS[&"N2"]
	# O piso da passagem ocupa o quinto de baixo da abertura.
	var piso := VAO_LINHA_FINAL - 5
	for y in range(VAO_LINHA_INICIAL, VAO_LINHA_FINAL + 1):
		for x in PORTA_VAO.x:
			var cor := n0
			if y >= piso:
				cor = n1
			if y == VAO_LINHA_FINAL:
				cor = n2
			elif x == 0 and y < piso:
				# A ombreira esquerda pega a luz: uma coluna de 1 px que da
				# profundidade sem acender nada.
				cor = n1
			img.set_pixel(x, y, cor)
	return img


# --------------------------------------------------------------- modulos -----

## OS SEIS MODULOS BASE (PAREDE 03), e nenhum deles tem ferrugem.
##
## A regra que esta secao carrega vem do plano com todas as letras: **se a sala
## nao parecer boa com seis modulos lisos, o problema e proporcao e nao falta de
## decoracao.** Painel, tubo, ventilacao e chapa amassada sao outra issue, e
## acrescenta-los aqui esconderia a pergunta em vez de responde-la.
##
## Eles nascem GERADOS, e nao autorados, e isso e deliberado. O que se prova aqui
## e FORMA: como o topo encontra a face, onde a junta cai, e se a fita de 32 px
## fecha sem fresta. Codigo da controle exato do pixel da emenda, que e o unico
## lugar onde um erro aqui aparece. A familia autorada `parede_modulo` que a
## PAREDE 01 decidiu chega com o kit industrial do andar 1.
##
## A LUZ vem de cima e da esquerda (LOW_TOPDOWN secao 18), e e ela que faz cada
## lado ser um desenho proprio em vez de uma rotacao:
##
##   NORTE  a face olha para a camera. Topo em cima, TRIM, face embaixo.
##   SUL    so topo. A aresta virada para a sala e a de cima, e ela acende.
##   LESTE  so topo. A aresta virada para a sala fica a OESTE e acende.
##   OESTE  so topo. A aresta virada para a sala fica a LESTE -- e ela NAO acende,
##          porque olha para longe da luz. E por isso que oeste e arte propria e
##          nao o leste espelhado: o espelho inverteria a luz junto.

## Quanto do modulo e face. Metade -- a razao 1:1 da secao 24.
const MODULO_FACE := 32

## O TRIM: o acabamento entre topo e face que a secao 4 do plano pede.
##
## Nao e neon, e nao pode ser: uma linha clara continua na borda da sala e
## exatamente o filete que o projeto ja removeu uma vez, quando ele virou a coisa
## mais brilhante encostando na beira do quadro. Aqui sao dois pixels -- um claro
## no lado do topo, um escuro no lado da face --, que e mudanca de VALOR e nao de
## brilho.
static func _trim(img: Image, x: int, y: int, w: int, horizontal: bool) -> void:
	var n4 := Paleta.neutro(&"N4")
	var n7 := Paleta.neutro(&"N7")
	if horizontal:
		_ret(img, x, y, w, 1, n7)
		_ret(img, x, y + 1, w, 1, n4)
	else:
		_ret(img, x, y, 1, w, n7)
		_ret(img, x + 1, y, 1, w, n4)


## A chapa de um modulo: base com grao, para nao ler como retangulo chapado.
## A rampa neutra em ordem. O grao de uma chapa e sempre UM degrau abaixo da
## base: dois degraus ja leem como duas superficies, e nao como uma superficie
## com textura.
const RAMPA: Array[StringName] = [&"N0", &"N1", &"N2", &"N3", &"N4", &"N5", &"N6", &"N7"]


static func _um_degrau_abaixo(base: StringName) -> StringName:
	var i := RAMPA.find(base)
	return RAMPA[maxi(i - 1, 0)] if i > 0 else base


static func _chapa(img: Image, x: int, y: int, w: int, h: int, base: StringName,
		semente: int) -> void:
	var cor := Paleta.neutro(base)
	var escura := Paleta.neutro(_um_degrau_abaixo(base))
	for dy in h:
		for dx in w:
			var c := cor
			if _ruido(x + dx, y + dy, semente) < 0.12:
				c = escura
			_pintar(img, x + dx, y + dy, c)


## Rebites de 2x2 com realce. Um pixel solto some na escala do jogo.
static func _rebite(img: Image, x: int, y: int) -> void:
	_ret(img, x, y, 2, 2, Paleta.neutro(&"N4"))
	_pintar(img, x, y, Paleta.neutro(&"N7"))


## NORTE: o unico lado que mostra FACE, e o que carrega a sala.
##
## De cima para baixo: 32 px de topo, o trim, e 32 px de face. A face e mais
## ESCURA que o topo de proposito -- superficie vertical pega menos luz que
## horizontal, e e essa diferenca que vende a altura. O ultimo pixel e a linha de
## contato com o chao: sem ela a parede FLUTUA sobre o piso em vez de assentar.
static func gerar_modulo_n() -> Image:
	var img := _nova(MODULO_VERTICAL.x, MODULO_VERTICAL.y)
	var semente: int = SEEDS[&"modulo"]
	var n4 := Paleta.neutro(&"N4")
	var meio := MODULO_VERTICAL.y - MODULO_FACE
	# TOPO em N6, FACE em N4: DOIS degraus da rampa, e nao um.
	#
	# A primeira versao usou N5 na face, que e o valor exato da face autorada
	# (0,298 contra 0,380 do topo). Medido em tela, aquilo nao leu: 0,09 de
	# diferenca some no grao, e quem separava as duas superficies era so a linha
	# de trim. A face autorada sobrevivia com esse degrau porque tinha MATIZ
	# proprio -- ela e teal contra o cinza-azulado do topo --, e um modulo liso
	# nao tem esse recurso. Sem matiz, o degrau tem de ser de valor.
	_chapa(img, 0, 0, MODULO_VERTICAL.x, meio, &"N6", semente)
	_chapa(img, 0, meio, MODULO_VERTICAL.x, MODULO_FACE, &"N4", semente + 1)
	_trim(img, 0, meio - 1, MODULO_VERTICAL.x, true)
	# A junta entre modulos vizinhos. Ela e o que faz a fita ler como uma
	# sequencia de placas e nao como uma textura repetida.
	_ret(img, 0, 0, 1, MODULO_VERTICAL.y, n4)
	# O CONTATO COM O CHAO, e sao dois pixels de N2 e nao um de N4.
	#
	# N4 e junta, e junta le como "aqui ha uma emenda"; o que se quer aqui e
	# SOMBRA -- o escuro que prova que a parede assenta no piso em vez de flutuar
	# sobre ele. N2 e cor de chao medio, e usada como linha de 2 px ela nao vira
	# superficie: vira o vao embaixo da chapa.
	_ret(img, 0, MODULO_VERTICAL.y - 2, MODULO_VERTICAL.x, 2, Paleta.neutro(&"N2"))
	_rebite(img, 4, meio + 5)
	_rebite(img, MODULO_VERTICAL.x - 6, meio + 5)
	return img


## SUL: so topo, e e a assimetria da secao 8 virando desenho.
##
## A parede de baixo nao ergue face na frente do jogador -- ela o esconderia. O
## que ela mostra e a superficie de cima, e a aresta virada para a SALA (a de
## cima, no sul) e a que acende.
static func gerar_modulo_s() -> Image:
	var img := _nova(MODULO_VERTICAL.x, MODULO_VERTICAL.y)
	var semente: int = SEEDS[&"modulo"] + 2
	var n4 := Paleta.neutro(&"N4")
	_chapa(img, 0, 0, MODULO_VERTICAL.x, MODULO_VERTICAL.y, &"N6", semente)
	# A borda que toca o chao da sala, e o chanfro aceso logo depois.
	_ret(img, 0, 0, MODULO_VERTICAL.x, 1, n4)
	_ret(img, 0, 1, MODULO_VERTICAL.x, 1, Paleta.neutro(&"N7"))
	# A metade externa cai de valor: o topo se afastando da luz.
	_chapa(img, 0, MODULO_VERTICAL.y - 16, MODULO_VERTICAL.x, 16, &"N5", semente + 1)
	_ret(img, 0, 0, 1, MODULO_VERTICAL.y, n4)
	_rebite(img, 4, 6)
	_rebite(img, MODULO_VERTICAL.x - 6, 6)
	return img


## LESTE: so topo. A aresta virada para a sala fica a oeste, e ela acende.
static func gerar_modulo_l() -> Image:
	return _modulo_lateral(SEEDS[&"modulo"] + 3, true)


## OESTE: so topo, e NAO e o leste espelhado.
##
## No oeste a aresta virada para a sala olha para LESTE -- para longe da luz --,
## entao ela nao acende: quem acende e a borda externa, que olha para o oeste. Um
## espelho em x inverteria o eixo e poria o realce no lado errado, e ninguem
## veria. E a mesma licao que a `porta_lado` ja carrega.
static func gerar_modulo_o() -> Image:
	return _modulo_lateral(SEEDS[&"modulo"] + 4, false)


static func _modulo_lateral(semente: int, leste: bool) -> Image:
	var img := _nova(MODULO_HORIZONTAL.x, MODULO_HORIZONTAL.y)
	var n4 := Paleta.neutro(&"N4")
	var n7 := Paleta.neutro(&"N7")
	var w := MODULO_HORIZONTAL.x
	var h := MODULO_HORIZONTAL.y
	_chapa(img, 0, 0, w, h, &"N6", semente)
	# A coluna que toca o chao da sala: leste a tem na esquerda, oeste na direita.
	var contato := 0 if leste else w - 1
	_ret(img, contato, 0, 1, h, n4)
	if leste:
		# A aresta virada para a sala olha para oeste: ela pega a luz.
		_ret(img, 1, 0, 1, h, n7)
		_chapa(img, w - 16, 0, 16, h, &"N5", semente + 1)
	else:
		# No oeste quem pega a luz e a borda EXTERNA, que olha para a esquerda.
		_ret(img, 0, 0, 1, h, n7)
		_chapa(img, 1, 0, 14, h, &"N5", semente + 1)
	# A junta entre modulos vizinhos corre na horizontal aqui.
	_ret(img, 0, 0, w, 1, n4)
	_rebite(img, w / 2 - 1, 4)
	_rebite(img, w / 2 - 1, h - 6)
	return img


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
	_pintar(img, o.x + 10, o.y + 25, n7)
	# O visor grande fica APAGADO (o N0 la em cima) e a luz do andar cabe em
	# dois pixels: o unico LED aceso de todo o atlas, com a carcaca escura em
	# volta para ele nao ler como pixel solto. E a secao 77 do briefing --
	# "a maioria dos visores INATIVA" -- desenhada em vez de escrita.
	_ret(img, o.x + 19, o.y + 24, 4, 3, Paleta.luz(&"led_ambar_base"))
	_ret(img, o.x + 20, o.y + 25, 2, 1, Paleta.luz(&"led_ambar"))


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


## A marcacao de piso do tipo, e o unico lugar do atlas onde o tipo de sala
## ainda pode aparecer em COR. Ela le por `Paleta.marca()`: `arma` recebe a
## faixa de galao envelhecida e `item` a marca tecnica fria, e todo o resto cai
## na rampa gunmetal -- que e a FAB 12 desenhada em vez de escrita.
static func _prop_marcacao_acento(img: Image, o: Vector2i, tipo: StringName) -> void:
	var faixa := Paleta.marca(tipo, &"faixa")
	var tique := Paleta.marca(tipo, &"tique")
	_ret(img, o.x + 2, o.y + 13, 28, 6, faixa)
	for x in range(4, 28, 8):
		_ret(img, o.x + x, o.y + 15, 4, 2, tique)


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
