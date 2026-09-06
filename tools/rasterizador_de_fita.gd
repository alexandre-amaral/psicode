class_name RasterizadorDeFita
extends RefCounted
## Le a fita de parede COMO ELA CHEGA A TELA -- sem tela.
##
## Ele existe porque a pergunta do epico do topo (#238) e sobre PIXEL e nao sobre
## arquivo: "o topo compete com a face?" nao se responde medindo
## `parede_topo_a.png`, porque o que o jogador ve ali e a textura MAIS a linha de
## contato, a costura, o labio e o bisel -- e essas quatro sao desenhadas em
## codigo, nao existem em disco nenhum, e sao justamente as pecas que a #241
## mexe.
##
## **E ele nao remonta as bandas: ele LE as que o renderizador montou.** Uma
## copia da tabela de faixas aqui divergiria de `_vestir_acabamento()` no dia em
## que uma delas mudasse, e o sintoma seria um portao verde medindo uma parede
## que nao existe -- exatamente o que `_a_razao_face_topo_fica_em_um_para_um`
## registra ter acontecido com `ESPESSURA_PAREDE`.
##
## **Por que nao fotografar.** O runner roda `--headless`, e ali o rasterizador
## e o dummy: `get_viewport().get_texture()` volta em branco. Fotografar exigiria
## janela, e portao que precisa de janela nao roda no CI -- ele vira uma
## ferramenta que alguem tem de lembrar de rodar, que e a categoria de portao que
## este projeto ja perdeu tres vezes.
##
## A conta de UV nao e adivinhada: `Polygon2D` sem `uv` proprio deriva a
## coordenada do proprio vertice, com `texture_offset` somado. E por isso que
## `_superficie()` grava `texture_offset = centro - ancora` -- e por isso que a
## amostra aqui e `(mundo - position) + texture_offset`, que da `mundo - ancora`
## sem este arquivo precisar saber onde fica a ancora.


## Uma fatia da faixa, do contorno para FORA.
##
## Devolve uma imagem de `largura` x `fundo`: a LINHA 0 e o contorno (onde a
## parede encosta no chao) e a linha `fundo - 1` e a aresta externa. Assim o
## indice de linha e a PROFUNDIDADE em px, e um caso pode dizer "a face vai de 0
## a 56" sem converter nada.
##
## As coordenadas sao as da propria fita (que a `Sala` pendura sem deslocamento),
## entao o chamador passa contorno local e pronto.
static func faixa(fita: Node2D, de: Vector2, ate: Vector2, normal: Vector2,
		fundo: int, largura: int) -> Image:
	var imagem := Image.create(maxi(largura, 1), maxi(fundo, 1), false,
		Image.FORMAT_RGBA8)
	if fita == null or fundo <= 0 or largura <= 0:
		return imagem
	var comprimento := de.distance_to(ate)
	if comprimento < 1.0:
		return imagem
	var direcao := (ate - de) / comprimento
	var passo := comprimento / float(largura)

	# As pecas em ordem INVERSA de insercao: sem z_index proprio, quem foi
	# adicionado por ultimo desenha por cima. E o mesmo criterio do motor, e ele
	# importa aqui -- a linha de contato e o bisel sao adicionados DEPOIS da
	# superficie e e por isso que aparecem.
	var pecas: Array[Polygon2D] = []
	for i in range(fita.get_child_count() - 1, -1, -1):
		var poly := fita.get_child(i) as Polygon2D
		if poly != null:
			pecas.append(poly)

	for coluna in largura:
		var base := de + direcao * ((float(coluna) + 0.5) * passo)
		for linha in fundo:
			var mundo := base + normal * (float(linha) + 0.5)
			imagem.set_pixel(coluna, linha, _cor_em(pecas, mundo))
	return imagem


## A cor da peca mais acima que cobre este ponto. Transparente se nenhuma cobre.
static func _cor_em(pecas: Array[Polygon2D], mundo: Vector2) -> Color:
	for poly in pecas:
		var local := mundo - poly.position
		if not Geometry2D.is_point_in_polygon(local, poly.polygon):
			continue
		if poly.texture == null:
			return poly.color
		var imagem := poly.texture.get_image()
		if imagem == null:
			return poly.color
		var uv := local + poly.texture_offset
		var l := imagem.get_width()
		var a := imagem.get_height()
		var x := int(floorf(uv.x)) % l
		var y := int(floorf(uv.y)) % a
		if x < 0:
			x += l
		if y < 0:
			y += a
		return imagem.get_pixel(x, y) * poly.color
	return Color(0.0, 0.0, 0.0, 0.0)


## A ENERGIA de um trecho de linhas: quanto a superficie muda, por pixel.
##
## Media de `|luma - luma(direita)| + |luma - luma(abaixo)|` em 0..255. E a mesma
## pergunta que `AssinaturaDeSuperficie` faz para separar materiais, sem o eixo
## de orientacao: aqui o que importa nao e PARA ONDE a superficie corre, e sim
## QUANTO ela chama a atencao.
##
## Sem wrap, ao contrario da assinatura: esta faixa nao ladrilha -- ela e um
## pedaco de parede com comeco e fim, e emendar a ultima linha na primeira
## somaria uma diferenca entre a aresta externa e o chao que ninguem ve.
static func energia(imagem: Image, de_linha: int, ate_linha: int) -> float:
	if imagem == null or imagem.is_empty():
		return 0.0
	var l := imagem.get_width()
	var fim := mini(ate_linha, imagem.get_height())
	var inicio := maxi(de_linha, 0)
	if fim - inicio < 2 or l < 2:
		return 0.0
	var soma := 0.0
	var conta := 0
	for y in range(inicio, fim - 1):
		for x in l - 1:
			var v := _luma(imagem.get_pixel(x, y))
			soma += absf(_luma(imagem.get_pixel(x + 1, y)) - v)
			soma += absf(_luma(imagem.get_pixel(x, y + 1)) - v)
			conta += 1
	return 0.0 if conta == 0 else soma * 255.0 / float(conta)


static func _luma(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
