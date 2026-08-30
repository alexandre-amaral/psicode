extends TesteBase
## As duas familias de prop da LTD 09, e o contrato que as separa.
##
## Por que isto e teste e nao revisao de olho: props nao tem colisao e nao
## emitem nada. Quando um deles nasce no lugar errado, na faixa de z errada ou
## com a origem no meio do corpo, NAO ha erro no console -- o jogo roda igual e
## a sala so fica um pouco errada, de um jeito que so aparece quando dois
## corpos se cruzam em movimento. Foi exatamente esse o sintoma que a LTD 07
## corrigiu nos atores, e props ficaram de fora na epoca.
##
## O contrato tem tres metades que nao se provam sozinhas:
##
##   1. o ATLAS ancora a arte no fundo da celula;
##   2. a SALA desloca o sprite em -altura/2;
##   3. as duas juntas poem a base do prop na origem do no.
##
## Medir so a sala aprovaria um atlas mal composto, e medir so o atlas
## aprovaria uma sala que ignora a ancora. Esta suite mede as duas pontas.

const CENA_SALA := preload("res://src/mapa/sala_1_retangular.tscn")
const ATLAS_VOLUME := "res://assets/texturas/props_volume.png"

## Longe da origem pelo mesmo motivo de teste_hact/teste_camada_visual: outras
## suites deixam no perto de (0,0) enquanto o coletor nao passa.
const LONGE := Vector2(11000.0, 11000.0)

## Os tipos que declaram prop volumetrico. O boss fica FORA de proposito e a
## ausencia dele e cobrada, nao ignorada -- ver _a_arena_do_chefe_fica_limpa.
const TIPOS_COM_VOLUME := [
	"res://src/mapa/tipo_combate.tres",
	"res://src/mapa/tipo_inicial.tres",
	"res://src/mapa/tipo_arma.tres",
	"res://src/mapa/tipo_item.tres",
]


func nome() -> String:
	return "Props"


func executar() -> void:
	_o_atlas_ancora_a_arte_no_fundo_da_celula()
	_o_prop_volumetrico_nasce_com_base_sombra_e_y_sort()
	_o_prop_chapado_continua_chapado()
	_a_arena_do_chefe_fica_limpa()


## Metade 1 do contrato: a arte de cada celula encosta no FUNDO dela.
##
## E o que faz o deslocamento de -altura/2 ser uma regra unica em vez de uma
## tabela por prop. Se alguem recompor o atlas centralizando a arte na celula,
## todos os props do jogo passam a flutuar meio corpo acima do chao -- e nao ha
## erro no console para isso, porque a sala continua fazendo a conta certa
## sobre um dado errado.
##
## A folga de 1 px existe porque a arte tem contorno e nem todo prop encosta
## com a base perfeitamente reta (o barril tem quina arredondada).
func _o_atlas_ancora_a_arte_no_fundo_da_celula() -> void:
	var imagem := _abrir_atlas()
	if imagem == null:
		ok(false, "props_volume.png abre")
		return

	var conferidas := 0
	for caminho: String in TIPOS_COM_VOLUME:
		var dados: DadosSala = load(caminho)
		if dados == null:
			continue
		for regiao: Rect2i in dados.regioes_props_volume:
			var fundo := _ultima_linha_com_arte(imagem, regiao)
			if fundo < 0:
				ok(false, "regiao %s tem arte" % regiao)
				continue
			conferidas += 1
			var distancia := regiao.size.y - 1 - fundo
			ok(
				distancia <= 1,
				"regiao %s: a arte encosta no fundo da celula (sobra %d px)" % [regiao, distancia]
			)

	ok(conferidas >= 8, "o atlas volumetrico foi conferido em varias celulas (%d)" % conferidas)


## Metade 2 e 3: a sala monta o prop como CORPO, e a base cai na origem do no.
func _o_prop_volumetrico_nasce_com_base_sombra_e_y_sort() -> void:
	var dados: DadosSala = load("res://src/mapa/tipo_combate.tres")
	ok(dados != null, "tipo_combate carrega")
	if dados == null:
		return
	ok(dados.quantidade_props_volume > 0, "a sala de combate pede prop volumetrico")

	var sala := _montar(dados)
	var corpos := _props_volumetricos(sala)
	ok(not corpos.is_empty(), "a sala de combate colocou ao menos um prop volumetrico")

	var regioes := {}
	for r: Rect2i in dados.regioes_props_volume:
		regioes[r] = true

	for corpo in corpos:
		# Filho DIRETO da sala, sem raiz intermediaria: e o que o deixa no
		# Z_MUNDO e portanto dentro da ordenacao por Y.
		igual(corpo.get_parent(), sala, "o prop volumetrico e filho direto da sala")
		igual(corpo.z_index, Sala.Z_MUNDO, "o prop volumetrico esta na faixa do mundo")

		var sprite := corpo.get_node_or_null("Sprite2D") as Sprite2D
		if sprite == null:
			for filho in corpo.get_children():
				if filho is Sprite2D:
					sprite = filho as Sprite2D
					break
		ok(sprite != null, "o prop volumetrico tem sprite")
		if sprite != null:
			var regiao := Rect2i(sprite.region_rect)
			ok(regioes.has(regiao), "o prop usa uma regiao declarada no tipo (%s)" % regiao)
			# A conta inteira em uma linha: a base do desenho cai na origem.
			perto(
				sprite.position.y, -float(regiao.size.y) * 0.5,
				"o sprite sobe a partir da base (regiao %s)" % regiao
			)
			perto(sprite.position.x, 0.0, "o sprite nao desliza na horizontal")

		var sombra := corpo.get_node_or_null("Sombra") as Sombra
		ok(sombra != null, "o prop volumetrico tem sombra -- e ela que diz onde ele encosta")
		if sombra != null:
			perto(sombra.position.y, 0.0, "a sombra fica NA base, que ja e a origem do corpo")
			ok(sombra.z_index < 0, "a sombra desenha sob o proprio prop")

	sala.free()


## A familia CHAPADA nao pode ter mudado: ela continua numa raiz com faixa
## propria, fora do Y-sort. Se ela entrasse na ordenacao, o jogador passaria a
## sumir atras de uma mancha de oleo.
func _o_prop_chapado_continua_chapado() -> void:
	var dados: DadosSala = load("res://src/mapa/tipo_combate.tres")
	if dados == null:
		return
	var sala := _montar(dados)

	var raiz := sala.get_node_or_null("Decoracao") as Node2D
	ok(raiz != null, "a sala monta a raiz Decoracao dos props chapados")
	if raiz != null:
		igual(raiz.z_index, Sala.Z_CHAO_DETALHE, "a Decoracao fica na faixa de detalhe de chao")
		ok(raiz.get_child_count() > 0, "a Decoracao recebeu props chapados")
		ok(
			Sala.Z_CHAO_DETALHE < Sala.Z_MUNDO,
			"o chapado desenha ABAIXO do mundo -- o jogador passa por cima dele"
		)
		# O chapado vem do atlas CHAPADO, cujas celulas sao quadradas de 32. Um
		# retangulo 32x64 aqui significa que uma regiao volumetrica vazou para a
		# lista errada -- ela desenharia deitada no chao, com a face vertical
		# achatada contra o piso.
		for filho in raiz.get_children():
			var s := filho as Sprite2D
			if s == null:
				continue
			var r := s.region_rect
			ok(
				r.size.x == r.size.y,
				"prop chapado usa celula quadrada (achado %.0fx%.0f)" % [r.size.x, r.size.y]
			)

	# E nenhum volumetrico caiu dentro da raiz chapada por engano.
	for filho in raiz.get_children() if raiz != null else []:
		ok(filho.name != "PropVolume", "nenhum prop volumetrico foi parar na Decoracao")

	sala.free()


## A arena do chefe fica SEM corpo volumetrico, e isso e escolha e nao esquecimento.
##
## Ela e a sala mais densa de projetil do jogo. Um corpo com face vertical ali
## e exatamente o que a LTD 10 manda dosar e o que o GDD proibe encostar num
## telegrafo. O tipo declara as regioes -- para quem quiser experimentar nao ter
## de procurar quais servem -- e mantem a quantidade em zero.
##
## O teste existe para a mudanca ser DELIBERADA: quem subir esse numero vai ver
## esta mensagem e o motivo, em vez de descobrir na captura do chefe.
func _a_arena_do_chefe_fica_limpa() -> void:
	var dados: DadosSala = load("res://src/mapa/tipo_boss.tres")
	ok(dados != null, "tipo_boss carrega")
	if dados == null:
		return
	igual(
		dados.quantidade_props_volume, 0,
		"a arena do chefe nao recebe prop volumetrico (bullet hell le silhueta, nao decoracao)"
	)


# ------------------------------------------------------------------ apoio ----

func _montar(dados: DadosSala) -> Sala:
	var sala := CENA_SALA.instantiate() as Sala
	# ANTES do add_child: e o _ready que monta a decoracao, e ele so ve os
	# dados se eles ja estiverem la. O GerenciadorMapa faz na mesma ordem.
	sala.definir_visual(dados)
	sala.position = LONGE
	Engine.get_main_loop().root.add_child(sala)
	return sala


func _props_volumetricos(sala: Sala) -> Array[Node2D]:
	# Loop explicito: Array[Node].filter() devolve Array sem tipo, e atribuir de
	# volta a uma variavel tipada explode em runtime (armadilha ja registrada).
	var achados: Array[Node2D] = []
	for filho in sala.get_children():
		if filho.name == "PropVolume" and filho is Node2D:
			achados.append(filho as Node2D)
	return achados


func _abrir_atlas() -> Image:
	if not ResourceLoader.exists(ATLAS_VOLUME):
		return null
	var textura: Texture2D = load(ATLAS_VOLUME)
	if textura == null:
		return null
	return textura.get_image()


## A ultima linha da celula que tem pixel opaco, medida a partir do TOPO da
## celula. -1 quando a celula esta vazia.
func _ultima_linha_com_arte(imagem: Image, regiao: Rect2i) -> int:
	for y in range(regiao.size.y - 1, -1, -1):
		for x in regiao.size.x:
			var px := Vector2i(regiao.position.x + x, regiao.position.y + y)
			if px.x >= imagem.get_width() or px.y >= imagem.get_height():
				continue
			if imagem.get_pixel(px.x, px.y).a > 0.5:
				return y
	return -1
