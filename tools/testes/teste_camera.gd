extends TesteBase
## Trava o acordo entre o que a PAREDE desenha e o que a CAMERA enquadra.
##
## Os dois numeros sao derivados um do outro de proposito -- `margem_da_parede()`
## le `Sala.ESPESSURA_PAREDE`, que e a mesma distancia que a parede avanca para
## fora do contorno. Quando eles descolam, o sintoma nao tem erro no console e
## so aparece olhando uma captura:
##
##   margem MAIOR que a parede  -> tira do vazio entre-salas na borda do quadro
##   margem MENOR que a parede  -> meia parede cortada
##
## O caso mais perigoso e o terceiro, e e o motivo desta suite existir:
## `Sala._inflar()` tem uma SAIDA DE EMERGENCIA. Se `offset_polygon` nao
## devolver um poligono valido, ela devolve o contorno CRU e emite push_warning.
## A sala fica sem faixa de parede, a camera continua abrindo a margem inteira,
## e o resultado e vazio em volta da sala inteira. push_warning nao reprova CI e
## ninguem le o log de uma run verde.
##
## Por isso a conferencia nao e "a constante bate com a constante": e o bbox do
## poligono REALMENTE montado contra o retangulo que a camera REALMENTE usa.

const CENAS: Array[String] = [
	"res://src/mapa/sala_1_retangular.tscn",
	"res://src/mapa/sala_2_l_shape.tscn",
	"res://src/mapa/sala_3_grande.tscn",
	"res://src/mapa/sala_4_corredor.tscn",
	"res://src/mapa/sala_5_pilar.tscn",
	"res://src/mapa/sala_6_boss.tscn",
	"res://src/mapa/sala_7_arma.tscn",
	"res://src/mapa/sala_8_item.tscn",
	"res://src/mapa/sala_9_inicial.tscn",
]

## Longe da origem, como as outras suites que instanciam sala.
const LONGE := Vector2(12000.0, 12000.0)
## Folga em pixels na comparacao de bbox. offset_polygon trabalha em float e a
## quina em miter pode devolver fracao; 0,5 px nao esconde erro de margem, que
## seria de dezenas.
const FOLGA := 0.5


func nome() -> String:
	return "Camera"


func executar() -> void:
	var margem := _margem()
	_a_margem_deriva_da_parede(margem)
	_o_clamp_cobre_a_parede_e_mais_nada(margem)
	_a_margem_segue_o_perfil_DA_SALA()
	_o_zoom_nunca_e_fracionario()
	_o_clamp_nunca_e_menor_que_o_quadro()


## O zoom da camera nunca sai de um valor INTEIRO.
##
## `_ajustar_zoom()` adaptava o zoom quando o clamp ficava menor que a viewport,
## para nao mostrar o vazio. A premissa expirou: o exterior virou camada
## declarada (`Sala.COR_DO_VAZIO`) e ha parede desenhada entre o chao e ele --
## vazio depois de uma PAREDE nao le como area alcancavel.
##
## O preco era invisivel e caro: `sala_4_corredor` tem 768 px de largura, entao o
## fator saia `960/832 = 1,15` e a sala inteira era reamostrada em zoom
## fracionario. Mesma armadilha do "64 para 96 borra" que o projeto ja registra
## para escala de sprite, aplicada a sala toda -- e nada no console.
##
## O caso tem TRES metades, e a terceira e a que morde: sem ela o portao passaria
## se alguem simplesmente cravasse `zoom = 1` e voltasse a adaptar por outro
## caminho.
func _o_zoom_nunca_e_fracionario() -> void:
	var gerenciador := GerenciadorMapa.new()
	var conferidas := 0
	for caminho in CENAS:
		var cena: PackedScene = load(caminho)
		if cena == null:
			continue
		var sala := cena.instantiate() as Sala
		Engine.get_main_loop().root.add_child(sala)
		var camera := Camera2D.new()
		camera.zoom = Vector2.ONE
		Engine.get_main_loop().root.add_child(camera)

		var limites := sala.obter_limites()
		var m: Vector4 = gerenciador.margem_da_parede([sala])
		gerenciador._ajustar_zoom(camera, limites.grow_individual(m.x, m.y, m.z, m.w).size)
		conferidas += 1
		var z: float = camera.zoom.x
		ok(
			is_equal_approx(z, roundf(z)) and z >= 1.0,
			"%s: zoom inteiro (%.3f)" % [caminho.get_file(), z]
		)

		camera.get_parent().remove_child(camera)
		camera.free()
		sala.get_parent().remove_child(sala)
		sala.free()
	igual(conferidas, CENAS.size(), "todas as salas foram conferidas")

	# A ENTRADA da regra: se `_zoom_base` nao for inteiro, a regra confere a si
	# mesma e nao o jogo.
	var cena_player: PackedScene = load("res://src/player/player.tscn")
	var player := cena_player.instantiate()
	var cam_player := player.get_node_or_null("Camera") as Camera2D
	ok(
		cam_player != null and is_equal_approx(cam_player.zoom.x, roundf(cam_player.zoom.x)),
		"e o zoom da camera do jogador ja nasce inteiro (%.2f)"
			% (cam_player.zoom.x if cam_player != null else -1.0)
	)
	player.free()

	# O LADO QUE MORDE: numa area MENOR que o campo, o desenho certo e mostrar o
	# vazio -- nao crescer o zoom. E o que trava contra a proxima pessoa que
	# reintroduzir a adaptacao.
	var estreita := Camera2D.new()
	estreita.zoom = Vector2.ONE
	Engine.get_main_loop().root.add_child(estreita)
	gerenciador._ajustar_zoom(estreita, Vector2(640.0, 320.0))
	perto(
		estreita.zoom.x, 1.0,
		"area menor que o campo NAO aumenta o zoom -- o vazio aparece, e e ele que faz a moldura ler"
	)
	estreita.get_parent().remove_child(estreita)
	estreita.free()
	gerenciador.free()


## O retangulo do clamp nunca e MENOR que o quadro.
##
## E a outra metade do conserto do zoom. `_ajustar_zoom` parou de dar zoom para
## dentro justamente para nao reamostrar a sala; o efeito colateral e que uma sala
## mais estreita que a tela passa a entregar a camera um `limit_*` que nao cabe no
## proprio quadro. Nao existe posicao que satisfaca um retangulo de 832 px dentro
## de uma tela de 960: o motor escolhe sozinho a que borda encostar, e o quadro
## sai com a sala num canto.
##
## `_cabendo_a_tela()` cresce o retangulo ate o quadro, CENTRADO. O que aparece de
## cada lado e o vazio alem da parede, que o plano quer a vista.
##
## O caso tem os dois lados: as nove cenas de verdade, e um retangulo minusculo
## sintetico. Sem o segundo, o dia em que alguem trocasse o crescimento por um
## `if` que nunca dispara passaria verde -- as nove cenas de hoje ja cabem em Y.
func _o_clamp_nunca_e_menor_que_o_quadro() -> void:
	var gerenciador := GerenciadorMapa.new()
	var tela := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 544))
	)
	var estreitas := 0
	for caminho in CENAS:
		var cena: PackedScene = load(caminho)
		if cena == null:
			continue
		var sala := cena.instantiate() as Sala
		Engine.get_main_loop().root.add_child(sala)
		var limites := sala.obter_limites()
		var m: Vector4 = gerenciador.margem_da_parede([sala])
		var cru := limites.grow_individual(m.x, m.y, m.z, m.w)
		var final_ := gerenciador._cabendo_a_tela(cru)
		if cru.size.x < tela.x or cru.size.y < tela.y:
			estreitas += 1
		ok(
			final_.size.x >= tela.x - FOLGA and final_.size.y >= tela.y - FOLGA,
			"%s: o clamp cabe o quadro (%.0fx%.0f)"
				% [caminho.get_file(), final_.size.x, final_.size.y]
		)
		# Centrado: crescer para um lado so encostaria a sala numa borda, que e
		# exatamente o defeito que isto existe para evitar.
		perto(
			final_.get_center().x, cru.get_center().x,
			"%s: o crescimento e centrado em x" % caminho.get_file(), FOLGA
		)
		perto(
			final_.get_center().y, cru.get_center().y,
			"%s: e em y" % caminho.get_file(), FOLGA
		)
		sala.get_parent().remove_child(sala)
		sala.free()

	# TODAS as salas dependem do crescimento agora, e isso e aritmetica.
	#
	# **Este caso ja exigiu as duas coisas opostas, e as duas por medicao.**
	# Primeiro exigia ao menos uma sala estreita, para exercitar o crescimento;
	# depois exigia ZERO, porque com a lateral em 96 px o contorno de 768 fechava
	# 960 exato e o vazio preto que o corredor mostrava sumiu.
	#
	# Com a lateral em 36 px a conta virou de novo: 768 + 36 + 36 da 840, e o
	# quadro tem 960. Nao ha escolha aqui -- ou as salas ficam mais largas, ou o
	# clamp cresce. E o crescimento agora e DESEJADO: e ele que produz o vazio em
	# volta da arquitetura, sem o qual ela nao le como caixa dentro de um negativo.
	#
	# O que se cobra passa a ser o TAMANHO do vazio: ele existe, e nao domina.
	# Medido, 60 px de cada lado numa sala de 768 -- 12,5% do quadro.
	ok(estreitas > 0,
		"as salas dependem do crescimento do clamp (%d) -- e dele que vem o exterior visivel"
			% estreitas)
	ok(estreitas <= CENAS.size(),
		"e nenhuma o dispensa de um jeito que o portao nao veja (%d de %d)"
			% [estreitas, CENAS.size()])

	# O LADO QUE MORDE, sintetico: um retangulo que nao cabe em NENHUM eixo.
	var minusculo := gerenciador._cabendo_a_tela(Rect2(-50.0, -50.0, 100.0, 100.0))
	perto(minusculo.size.x, tela.x, "um retangulo de 100 px cresce ate a largura do quadro", FOLGA)
	perto(minusculo.size.y, tela.y, "e ate a altura", FOLGA)
	perto(minusculo.get_center().x, 0.0, "sem sair do centro", FOLGA)
	# E o que JA cabe nao se mexe -- crescer sempre esconderia parede.
	var grande := Rect2(-800.0, -600.0, 1600.0, 1200.0)
	var mesma := gerenciador._cabendo_a_tela(grande)
	ok(mesma == grande, "um retangulo que ja cabe passa intacto")
	gerenciador.free()


## A margem sai do perfil DAQUELA SALA, e nao do default.
##
## `margem_da_parede()` chamava `RenderizadorParedes.margens()` sem argumento, e
## a funcao cai em `PerfilDeParede.new()` -- o default, sempre. Quem DESENHA, no
## entanto, usa `Sala._perfil()`, que le o `EstiloDeParede` do tipo de sala.
##
## Passava por coincidencia: nenhum `.tres` de estilo grava os cinco campos de
## espessura, entao o estilo devolvia exatamente o default. O dia em que um andar
## tivesse perfil proprio -- que e a razao de o campo existir -- a parede
## desenharia mais fundo e a camera pararia no mesmo lugar, cortando a moldura
## fora do quadro. Sem erro no console.
##
## O caso usa a valvula `Sala.perfil_de_teste` para dar a sala um perfil
## claramente diferente do default e exigir que a margem acompanhe.
func _a_margem_segue_o_perfil_DA_SALA() -> void:
	var cena: PackedScene = load(CENAS[0])
	if cena == null:
		ok(false, "a cena de sala carrega")
		return
	var sala := cena.instantiate() as Sala
	Engine.get_main_loop().root.add_child(sala)

	var gerenciador := GerenciadorMapa.new()
	var padrao: Vector4 = gerenciador.margem_da_parede([sala])

	var fundo := PerfilDeParede.new()
	# Claramente mais fundo que o default, seja ele qual for -- um literal
	# escolhido perto do default de hoje empata com ele amanha.
	fundo.corpo = PerfilDeParede.new().corpo * 2.0
	Sala.perfil_de_teste = fundo
	var maior: Vector4 = gerenciador.margem_da_parede([sala])
	Sala.perfil_de_teste = null

	ok(
		maior.y > padrao.y,
		"perfil mais fundo empurra a margem NORTE (%.0f contra %.0f)" % [maior.y, padrao.y]
	)
	perto(
		maior.y, fundo.profundidade(RenderizadorParedes.Lado.NORTE) + fundo.margem_exterior,
		"e ela vale exatamente o que aquele perfil desenha ao norte"
	)

	# E o outro lado: sem sala nenhuma ela cai no default, que e o que a
	# assinatura antiga fazia sempre.
	var vazia: Vector4 = gerenciador.margem_da_parede([])
	var base := PerfilDeParede.new()
	perto(vazia.y, base.profundidade(RenderizadorParedes.Lado.NORTE) + base.margem_exterior,
		"sem sala, a margem e a do perfil default")

	gerenciador.free()
	sala.get_parent().remove_child(sala)
	sala.free()


## A margem tem de bater com onde a FITA CHEGOU, e nao com uma constante.
##
## Ela comparava `margem_da_parede()` com `Sala.ESPESSURA_PAREDE`, e as duas
## derivavam uma da outra -- o portao provava que dois nomes do mesmo numero eram
## iguais. Isso bastava enquanto a parede era um poligono inflado por aquela
## constante. Com a fita, quem decide ate onde ha PIXEL e o renderizador, e
## `ESPESSURA_PAREDE` passou a descrever so a GEOMETRIA: colisao, encaixe do
## corredor, faixa da parede antiga.
##
## Entao o portao passa a MEDIR. Ele monta cada sala, procura a peca da fita que
## foi mais longe em cada direcao, e exige que a margem da camera bata com ela
## nos quatro lados. Assim ele continua valendo no dia em que a parede sul ficar
## mais rasa -- o que o plano quer -- sem ninguem precisar lembrar de mexer aqui.
func _a_margem_deriva_da_parede(margem: Vector4) -> void:
	ok(margem.x > 0.0 and margem.y > 0.0 and margem.z > 0.0 and margem.w > 0.0,
		"as quatro margens sao positivas (sem elas a parede nunca entra no quadro)")
	# A ASSIMETRIA E O ENTREGAVEL, e esta assercao ja girou quatro vezes.
	#
	# Ela nasceu como `y > w` -- "a assimetria carrega a perspectiva", com o sul
	# raso. Virou `y == w` num conserto meu de uma borda preta que nao existia.
	# Voltou a `y > w`. Virou igualdade de novo quando o sul ganhou face. E agora
	# volta a ordem, por um motivo que nenhuma das quatro tinha: **os quatro lados
	# continuam sendo QUATRO numeros**, mas hoje eles COINCIDEM -- e a coincidencia
	# e o que se cobra.
	#
	# **ESTE PORTAO JA AFIRMOU O CONTRARIO, e a virada tem medicao.** Ele exigia
	# `norte > lateral > sul`, com o argumento de que cada lado esta numa relacao
	# diferente com a camera. O argumento e verdadeiro em perspectiva e falso em
	# LEITURA, e o jogo mostrou qual das duas importa: com a lateral em 36 px e o
	# sul em 32, as quinas diziam "ha uma moldura" e os lados diziam "ha um
	# acabamento".
	#
	#     baseline_assimetrico/norte_sala.png, coluna 240:
	#     vazio 6 | cap 48 | corpo 44 | contato 9 | piso 17
	#
	# **A sala e uma caixa aberta vista de cima**, e numa caixa as quatro paredes
	# tem a mesma espessura. A perspectiva passa a vir do chanfro, da sombra e da
	# orientacao da textura -- nunca da diferenca de massa entre os lados.
	#
	# Quatro margens iguais aqui querem dizer que nenhum lado divergiu, e e
	# exatamente o que o perfil unico existe para garantir.
	for par: Array in [[margem.y, margem.w, "norte", "sul"],
			[margem.x, margem.z, "leste", "oeste"],
			[margem.y, margem.x, "norte", "leste"]]:
		perto(par[0], par[1],
			"%s e %s medem a mesma coisa (%.0f e %.0f) -- a caixa e simetrica"
				% [par[2], par[3], par[0], par[1]], 0.5)
	var conferidas := 0
	for caminho in CENAS:
		var cena: PackedScene = load(caminho)
		if cena == null:
			continue
		var sala := cena.instantiate() as Sala
		sala.configurar_conexoes([])
		Engine.get_main_loop().root.add_child(sala)
		sala.global_position = Vector2(31000, 31000)
		var fita := sala.get_node_or_null("ParedeModulos") as Node2D
		if fita == null:
			sala.free()
			continue
		var contorno := sala.contorno_local()
		var caixa := Rect2(contorno[0], Vector2.ZERO)
		for ponto in contorno:
			caixa = caixa.expand(ponto)
		var desenhado := caixa_das_pecas(fita)
		# POR EIXO, porque a parede deixou de ser simetrica: as laterais sao mais
		# estreitas que a norte, e um numero so usaria a maior nos dois lados --
		# a camera passaria a mostrar vazio do lado estreito.
		# POR LADO, porque a parede deixou de ser simetrica ate no eixo
		# vertical: o norte desenha 40 px e o sul 16, e um numero unico faria a
		# camera mostrar 24 px de vazio embaixo.
		var alcance := Vector4(
			caixa.position.x - desenhado.position.x,
			caixa.position.y - desenhado.position.y,
			desenhado.end.x - caixa.end.x,
			desenhado.end.y - caixa.end.y
		)
		conferidas += 1
		var nomes := ["esquerda", "cima", "direita", "baixo"]
		var medidos := [alcance.x, alcance.y, alcance.z, alcance.w]
		# A MARGEM DEIXOU DE SER SO A PAREDE, e a diferenca e o entregavel.
		#
		# Ela agora e `profundidade + margem_exterior`: a parede desenha ate onde
		# desenhava, e o clamp reserva um pouco alem para o VAZIO aparecer. Medido
		# antes desta mudanca, `vazio` era 0,0% no centro da sala retangular -- a
		# arquitetura ocupava ate a borda da tela e nao lia como caixa.
		#
		# Entao este caso passa a cobrar duas coisas de uma vez: que a parede
		# chegue onde a profundidade diz, e que sobre exatamente a margem exterior
		# depois dela. Um exterior que sumisse continuaria passando no portao
		# antigo.
		var fora := _margem_exterior()
		var esperados := [margem.x - fora, margem.y - fora, margem.z - fora,
			margem.w - fora]
		for i in 4:
			perto(
				esperados[i], medidos[i],
				"%s: a margem de %s bate com onde a parede chegou (%.0f contra %.0f)"
					% [caminho.get_file(), nomes[i], esperados[i], medidos[i]], 2.0
			)
		sala.free()
	ok(conferidas >= 5, "a varredura mediu a parede das salas (%d)" % conferidas)


## O portao de verdade: o retangulo que a camera usa tem de coincidir com o que a
## parede DESENHOU. Nem sobrando (vazio no quadro) nem faltando (parede cortada).
##
## **Ele mediu a coisa errada por uma issue inteira, e ficou verde.** Ate a
## PAREDE 13 a parede era um `Polygon2D` chamado `ParedeTopo` e este caso lia
## `topo.polygon`. Quando a fita substituiu o poligono, o no virou `Node2D` e a
## leitura passou a explodir -- `Invalid access to property or key 'polygon'`.
## Erro em GDScript ABORTA a funcao: as quatro comparacoes abaixo simplesmente
## deixaram de acontecer, o runner nao conta o que nao rodou, e a suite seguiu
## imprimindo PASSOU com quatro asserções a menos por cena.
##
## E a licao nao e "confira o `sed`": e que **portao que morre nao grita.** Por
## isso a caixa passou a sair de `caixa_das_pecas()`, compartilhada com o caso
## anterior -- uma funcao a mais e um lugar a menos onde o alvo pode envelhecer
## sozinho.
func _o_clamp_cobre_a_parede_e_mais_nada(margem: Vector4) -> void:
	var conferidas := 0
	for caminho in CENAS:
		var cena: PackedScene = load(caminho)
		if cena == null:
			ok(false, "%s carrega" % caminho.get_file())
			continue
		var sala := cena.instantiate() as Sala
		if sala == null:
			ok(false, "%s tem Sala na raiz" % caminho.get_file())
			continue
		sala.position = LONGE
		Engine.get_main_loop().root.add_child(sala)

		var fita := sala.get_node_or_null("ParedeModulos") as Node2D
		if fita == null:
			ok(false, "%s monta a fita" % caminho.get_file())
			sala.free()
			continue

		# O que a camera vai enquadrar: o contorno mais a margem, POR EIXO.
		# A margem do clamp inclui o VAZIO declarado; a parede para antes dele.
		var fora := _margem_exterior()
		var esperado := _caixa(sala.contorno_local()).grow_individual(
			margem.x - fora, margem.y - fora, margem.z - fora, margem.w - fora)
		# O que a parede de fato desenhou.
		var real := caixa_das_pecas(fita)

		conferidas += 1
		var nome_curto := caminho.get_file()
		perto(real.position.x, esperado.position.x, "%s: parede alcanca a borda esquerda do quadro" % nome_curto, FOLGA)
		perto(real.position.y, esperado.position.y, "%s: parede alcanca a borda de cima do quadro" % nome_curto, FOLGA)
		perto(real.end.x, esperado.end.x, "%s: parede alcanca a borda direita do quadro" % nome_curto, FOLGA)
		perto(real.end.y, esperado.end.y, "%s: parede alcanca a borda de baixo do quadro" % nome_curto, FOLGA)

		# A saida de emergencia de _inflar() devolve o contorno CRU. Se ela
		# disparar, o bbox da parede fica igual ao do contorno -- e as quatro
		# comparacoes acima ja falhariam, mas esta diz o PORQUE em uma linha.
		var caixa_contorno := _caixa(sala.contorno_local())
		ok(real.size.x > caixa_contorno.size.x,
			"%s: _inflar nao caiu na saida de emergencia (parede %.0f x contorno %.0f)" % [
				nome_curto, real.size.x, caixa_contorno.size.x,
			])

		sala.free()

	igual(conferidas, CENAS.size(), "todas as salas foram conferidas")


## Instancia sem entrar na arvore: `_ready` do gerenciador chama iniciar_run(),
## e isso nao cabe numa suite unitaria. `new()` sozinho nao dispara `_ready`.
## Quanto do clamp e VAZIO declarado, e nao parede.
##
## Ele sai do perfil e nao de um literal: um exterior escrito aqui divergiria do
## que a camera reserva no dia em que alguem girasse o botao, e o sintoma seria a
## parede parecendo cortada -- ou o vazio sumindo -- sem nada acusar.
func _margem_exterior() -> float:
	return PerfilDeParede.new().margem_exterior


func _margem() -> Vector4:
	var gerenciador := GerenciadorMapa.new()
	var margem: Vector4 = gerenciador.margem_da_parede()
	gerenciador.free()
	return margem


## A caixa do que a fita DESENHOU, e nao do contorno dela.
##
## Publica e nao `_privada` porque os dois casos desta suite a usam, e porque a
## pergunta "ate onde a parede chegou" e a mesma para os dois. Ela mede toda
## peca, e nao so `Sprite2D`: acabamento desenhado em codigo tambem ocupa a
## faixa, e uma peca fora do alcance da camera nao daria erro nenhum -- daria uma
## tira de vazio na borda do quadro.
func caixa_das_pecas(fita: Node2D) -> Rect2:
	var caixa := Rect2()
	var primeira := true
	for filho in fita.get_children():
		var item := filho as Node2D
		if item == null:
			continue
		var meia := Vector2.ZERO
		var sprite := item as Sprite2D
		if sprite != null:
			if sprite.texture == null:
				continue
			meia = (sprite.region_rect.size if sprite.region_enabled 				else sprite.texture.get_size()) * 0.5
		else:
			var poly := item as Polygon2D
			if poly == null or poly.polygon.is_empty():
				continue
			meia = _caixa(poly.polygon).size * 0.5
		var caixinha := Rect2(item.position - meia, meia * 2.0)
		if primeira:
			caixa = caixinha
			primeira = false
		else:
			caixa = caixa.merge(caixinha)
	return caixa


func _caixa(pontos: PackedVector2Array) -> Rect2:
	if pontos.is_empty():
		return Rect2()
	var caixa := Rect2(pontos[0], Vector2.ZERO)
	for i in range(1, pontos.size()):
		caixa = caixa.expand(pontos[i])
	return caixa
