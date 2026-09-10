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

## TODOS os tipos que DECLARAM regiao no atlas volumetrico, inclusive os que
## hoje nao pedem prop nenhum.
##
## Ela e mais larga que `TIPOS_COM_VOLUME` de proposito, e a diferenca importa
## para o portao de fundo chapado: regiao declarada e regiao que alguem pode
## desenhar amanha -- o `tipo_boss.tres` lista 13 celulas com a faixa em zero, e
## medir so quem pede HOJE deixaria essas 13 fora da conta em silencio. Mesmo
## desenho de `_nenhum_png_fica_fora_de_regime`: arte que ninguem mede nao
## reprova, ela SOME.
const TIPOS_COM_REGIAO_DECLARADA := [
	"res://src/mapa/tipo_combate.tres",
	"res://src/mapa/tipo_inicial.tres",
	"res://src/mapa/tipo_arma.tres",
	"res://src/mapa/tipo_item.tres",
	"res://src/mapa/tipo_loja.tres",
	"res://src/mapa/tipo_boss.tres",
]

## Acima disto o fundo tem MATIZ e nao e fundo de gerador -- e sombra de
## contato, que e desenho e tem de ficar. Medido nas celulas do andar 1: a
## sombra legitima que encosta na borda fica entre 0,14 e 0,52 de saturacao, e
## os dois fundos chapados que este portao achou mediam 0,000 e 0,009.
const SATURACAO_MAXIMA_DE_FUNDO := 0.08

## E abaixo deste valor o cinza e escuro demais para ser o fundo do gerador.
const VALOR_MINIMO_DE_FUNDO := 0.235

## Distancia L1 de RGB (em 0..1) ate a cor do fundo. Mesmo criterio de
## `preparar_icone.py`: o gerador devolve o fundo em DOIS tons quase iguais, e
## tolerancia apertada deixa o segundo para tras -- a peca sai com a moldura
## colada em volta.
const TOLERANCIA_DE_FUNDO := 0.095

## O piso de area para o caso MORDER. Cinco pixels de fundo encostando na borda
## sao ruido de recorte; um retangulo atras da peca comeca em 4%.
const FRACAO_MINIMA_DE_FUNDO := 0.01


func nome() -> String:
	return "Props"


func executar() -> void:
	_o_atlas_ancora_a_arte_no_fundo_da_celula()
	_o_prop_volumetrico_nasce_com_base_sombra_e_y_sort()
	_o_prop_chapado_continua_chapado()
	_a_arena_do_chefe_fica_limpa()
	_o_foreground_nunca_entra_na_area_util()
	_o_prop_raro_aparece_numa_sala_por_andar()
	_a_arena_reage_sem_cobrir_a_leitura()
	_o_decalque_industrial_e_POUCO_e_nao_espelha()
	_o_CORPO_fica_fora_da_area_util_e_a_MANCHA_entra_nela()
	_so_o_prop_volumetrico_tem_colisao_e_a_forma_dele_e_a_SOMBRA()
	_a_peca_de_PAREDE_so_existe_onde_ha_FACE()
	_nada_desenhado_passa_do_ALCANCE_da_parede()
	_o_solido_nunca_deixa_um_BOLSAO_intransponivel_contra_a_parede()
	_a_peca_mostra_a_VISTA_do_lado_em_que_ela_encosta()
	_a_LIGACAO_toca_as_duas_pecas_que_ela_liga()
	_nenhuma_celula_do_atlas_entra_com_FUNDO_CHAPADO()


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
	ok(dados.faixa_de_props_volume().y > 0, "a sala de combate pede prop volumetrico")

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
		dados.faixa_de_props_volume(), Vector2i.ZERO,
		"a arena do chefe nao recebe prop volumetrico (bullet hell le silhueta, nao decoracao)"
	)


## O que tem CORPO nunca entra na area util; o que e MANCHA entra.
##
## As duas metades sao o mesmo teste porque elas sao a mesma decisao, e medir so
## uma aprova o erro oposto.
##
## **A primeira e a regra que protege o gameplay.** Prop volumetrico nao tem
## colisao: um caixote dentro da area de combate e cobertura que nao cobre e
## obstaculo que nao obstrui, e o jogador so descobre isso levando um tiro
## atraves dele. A garantia e geometrica -- `posicoes()` recusa toda PEGADA que
## toque a `area_spawn` --, e ela virou cobravel agora porque a migracao das
## contagens triplicou a densidade e abriu a faixa de 44 px para os 96 do
## perfil: os corpos passaram a nascer muito mais perto da area util, e "nao
## toca" deixou de ser folgado por acidente.
##
## **A segunda e a `[FAB 06]`, e ela e uma excecao DECLARADA.** A referencia tem
## marcacao de galao no meio da area livre e mais de dez grades espalhadas; a
## primeira versao do decorador rejeitava tudo ali e o piso do miolo virava um
## vazio. Sem este caso, alguem "conserta" o decalque para obedecer a area util
## -- o codigo fica mais simples, nenhum portao reclama, e o centro da sala fica
## chapado de novo.
func _o_CORPO_fica_fora_da_area_util_e_a_MANCHA_entra_nela() -> void:
	var dados: DadosSala = load("res://src/mapa/tipo_combate.tres")
	if dados == null:
		return
	var corpos := 0
	var invasores := 0
	var manchas := 0
	var manchas_no_miolo := 0
	for x in 16:
		var sala := CENA_SALA.instantiate() as Sala
		sala.coordenadas_grid = Vector2i(x * 5, x)
		sala.definir_visual(dados)
		sala.position = LONGE
		Engine.get_main_loop().root.add_child(sala)

		for corpo in _props_volumetricos(sala):
			corpos += 1
			# A PEGADA NO CHAO, e nao um quadrado do tamanho da peca.
			#
			# A conta era `largura x largura`, e ela nunca descreveu objeto
			# nenhum: um armario e largo e RASO, um tanque apoia numa base
			# estreita. Pior, ela impedia peca grande de existir -- um hero de
			# 96 px reservava 96x96 de piso e nao cabia na faixa de 96, entao a
			# saida foi encolher a peca ate ela ficar menor que o jogador.
			#
			# O que nao pode entrar na area de combate e o chao que a peca
			# ocupa, porque e nele que o jogador tentaria andar. A ALTURA
			# desenhada cresce para cima da tela, atras de todo mundo, e nao
			# tira area jogavel nenhuma.
			#
			# A conta vem do decorador, e nao daqui: duas formas de medir a
			# mesma pegada divergem, e a divergencia seria o jogo colocando uma
			# peca que a suite chama de invasora.
			var largura := _largura_do_corpo(corpo)
			var pegada := DecoradorDeSala.pegada_no_chao(corpo.position, largura)
			if sala.area_spawn.intersects(pegada):
				invasores += 1

		var raiz := sala.get_node_or_null("Decalques") as Node2D
		if raiz != null:
			for filho in raiz.get_children():
				var sprite := filho as Sprite2D
				if sprite == null:
					continue
				manchas += 1
				if sala.area_spawn.has_point(sprite.position):
					manchas_no_miolo += 1
		sala.free()

	ok(corpos > 0, "houve prop volumetrico para conferir (%d)" % corpos)
	igual(invasores, 0,
		"nenhum corpo toca a area util -- prop sem colisao ali e cobertura que nao cobre (%d de %d)"
			% [invasores, corpos])
	ok(manchas > 0, "houve decalque para conferir (%d)" % manchas)
	# As DUAS pontas, e nao so uma. "Alcanca o miolo" sozinho passaria com o
	# piso do perimetro limpo, que foi o estado medido enquanto o decalque
	# sorteava a partir de uma aresta: 89% no miolo e 11% na beirada. E "fica na
	# beirada" sozinho e a `[FAB 06]` desfeita. O piso e folgado de proposito --
	# o que ele pega e a distribuicao COLAPSAR para um lado.
	var fracao := float(manchas_no_miolo) / maxf(float(manchas), 1.0)
	entre(fracao, 0.25, 0.85,
		"o decalque cai nos dois lugares -- miolo e perimetro (%d de %d no miolo)"
			% [manchas_no_miolo, manchas])


## NENHUM pixel desenhado passa do alcance da parede -- o ENVELOPE.
##
## **Era o defeito mais visivel do andar, e nao havia portao nenhum sobre ele.**
## O decorador colocava a peca olhando so a POSICAO da base: `_no_lugar()` exigia
## `fundura <= faixa` e mais nada. Nada, em lugar nenhum, olhava `regiao.size.y`
## -- nem a pegada, que e `largura x 24` fixo, nem esta suite. A regra de encaixe
## era planar, e a altura desenhada nunca entrou na conta.
##
## Com peca de 64 px isso nao aparecia: ancorada a 8 px do contorno ela sobe 56,
## e a parede desenha 60. Com o vaso de pressao de 96x160 do commit da escala de
## fabrica, a mesma ancora poe o topo 152 px alem do contorno -- 92 px de arte no
## VAZIO PRETO, alem de tudo que a sala desenha. O dono viu antes de qualquer
## teste: *"o armario por exemplo esta vazando/maior que as paredes"*.
##
## ## Por que ele mede o PONTO e nao a desigualdade
##
## A tentacao e cobrar `altura <= fundura + alcance`. Ela esta errada nos dois
## sentidos, porque `fundura` e a distancia a aresta MAIS PROXIMA em QUALQUER
## direcao e o vazamento e VERTICAL: uma peca no meio da parede leste tem
## fundura 8 e 400 px de sala acima dela, e nao vaza nada. O que se afirma aqui e
## o que se ve: o topo do sprite, recuado do alcance, ainda cai dentro da sala.
##
## ## As duas pontas
##
## `ok(medidos > 0)` sozinho seria um carimbo. A segunda ponta e exigir que a
## peca MAIS ALTA medida de fato passe do contorno -- se nenhuma passar, o atlas
## virou raso e o portao esta aprovando sem ter tocado na regra que ele cobra.
func _nada_desenhado_passa_do_ALCANCE_da_parede() -> void:
	var medidos := 0
	var vazando := 0
	var maior_avanco := -1.0
	var pior := ""
	for caminho in TIPOS_COM_VOLUME:
		var dados: DadosSala = load(caminho)
		if dados == null:
			continue
		for semente in 6:
			var sala := _montar_com_semente(dados, semente + 1, false)
			var aberto := sala.contorno_local()
			# O alcance sai do MESMO perfil que desenhou a parede. Um numero
			# cravado aqui envelheceria junto com `corpo` e `cap`, e o portao
			# passaria a afirmar uma espessura que o jogo ja nao usa.
			var perfil := sala.perfil_de_parede()
			var alcance: float = perfil.alcance() if perfil != null 				else PerfilDeParede.new().alcance()
			for corpo in _props_volumetricos(sala):
				var sprite := _sprite_do_corpo(corpo)
				if sprite == null:
					continue
				medidos += 1
				var altura := float(sprite.region_rect.size.y)
				var topo := corpo.position.y - altura
				# Quanto a peca avanca ALEM do contorno, na vertical.
				var borda := _contorno_acima(aberto, corpo.position.x)
				var avanco := borda - topo
				if avanco > maior_avanco:
					maior_avanco = avanco
				if avanco > alcance + 1.0:
					vazando += 1
					if pior == "":
						pior = "%s celula %dx%d avanca %.0f px (alcance %.0f)" % [
							dados.id, sprite.region_rect.size.x,
							sprite.region_rect.size.y, avanco, alcance]
			sala.free()

	ok(medidos > 0, "houve prop volumetrico para medir (%d)" % medidos)
	igual(vazando, 0,
		"nenhuma peca desenha alem do que a parede desenha -- alem dela e vazio (%d de %d; %s)"
			% [vazando, medidos, pior])
	# A ponta que impede o carimbo: se NADA chega perto do contorno, a regra nao
	# foi exercitada e este caso esta verde por acidente.
	ok(maior_avanco > 0.0,
		"e alguma peca de fato sobe alem do contorno, senao a regra nao foi tocada (%.0f px)"
			% maior_avanco)


## O y do contorno logo ACIMA daquele x -- a linha que a peca nao pode ultrapassar
## sem entrar na faixa de parede.
##
## Ele varre as arestas em vez de usar a caixa envolvente porque numa sala em L
## a borda de cima depende de onde se esta: no braco do L ela e o degrau interno,
## e nao o topo da caixa. Medir pela caixa aprovaria uma peca que sobe pelo vao.
func _contorno_acima(aberto: PackedVector2Array, x: float) -> float:
	var melhor := INF
	for i in aberto.size():
		var a := aberto[i]
		var b := aberto[(i + 1) % aberto.size()]
		if is_equal_approx(a.x, b.x):
			continue
		var esquerda := minf(a.x, b.x)
		var direita := maxf(a.x, b.x)
		if x < esquerda or x > direita:
			continue
		var t := (x - esquerda) / (direita - esquerda)
		var y := lerpf(a.y, b.y, t) if a.x < b.x else lerpf(b.y, a.y, t)
		if y < melhor:
			melhor = y
	return melhor


func _sprite_do_corpo(corpo: Node2D) -> Sprite2D:
	for filho in corpo.get_children():
		var sprite := filho as Sprite2D
		if sprite != null:
			return sprite
	return null


## A largura desenhada de um prop volumetrico, lida do sprite dele.
##
## Ela nao e uma constante: o atlas tem celulas de 32 e de 64, e `Sala` escolhe
## a folga a partir da REGIAO sorteada. Cravar 64 aqui aprovaria o dobro do que
## a sala de fato reserva para uma peca estreita.
func _largura_do_corpo(corpo: Node2D) -> float:
	for filho in corpo.get_children():
		var sprite := filho as Sprite2D
		if sprite != null:
			return sprite.region_rect.size.x
	return Sala.PROP_LADO


## SO o prop volumetrico tem colisao, e a forma dele e a SOMBRA (`[FAB 49]`).
##
## **Este caso afirmava o contrario, e a inversao foi pedida jogando.** A politica
## da `[FAB 46]` era "decorativo sem colisao, obstaculo com colisao explicita", e
## na pratica nada tinha colisao: as pecas grandes PARECIAM obstaculo e o jogador
## atravessava. O dono foi direto -- a maquina "vai possuir colisao" e "precisa
## parecer conectada a sala". O docstring antigo daqui ja previa este dia, dizendo
## que o obstaculo de verdade nasceria com colisao declarada e o caso passaria a
## listar a excecao pelo nome; o que ele nao previu e que a excecao seria a
## familia inteira.
##
## Ele morde dos DOIS lados, e e essa a diferenca entre inverter um portao e
## perder um:
##
##   1. as cinco familias PLANAS continuam sem colisao nenhuma. Decalque, prop
##      chapado, prop animado, foreground e luminaria sao desenho no chao ou na
##      parede -- solido em qualquer um deles e esbarrao em coisa pintada.
##   2. todo `prop_volume` PRECISA ter exatamente um solido, na layer da parede,
##      sem mask. Sem esta metade, apagar a colisao inteira deixaria o caso verde.
##
## E a FORMA e cobrada contra a sombra, nao contra a pegada. `pegada_no_chao()` e
## a RESERVA -- a largura cheia da celula, conservadora, que decide se a peca cabe
## --, e usa-la como solido pararia o corpo 28% mais largo que a sombra desenhada.
## O jogador le a sombra como o pe da maquina; treze pixels de esbarrao alem dela
## e fantasma, e fantasma nao da erro no console. A relacao que se afirma e
## colisao ⊆ reserva.
func _so_o_prop_volumetrico_tem_colisao_e_a_forma_dele_e_a_SOMBRA() -> void:
	var dados: DadosSala = load("res://src/mapa/tipo_combate.tres")
	if dados == null:
		return
	var sala := _montar(dados)
	var aberto := sala.contorno_local()

	# 1. as familias planas continuam limpas.
	var planas := 0
	var com_corpo: Array[String] = []
	for nome in ["Decoracao", "Decalques", "DecoracaoAnimada", "Frente", "Luminarias",
			"ParedePecas"]:
		var raiz := sala.get_node_or_null(nome)
		if raiz == null:
			continue
		for peca in _todos_os_nos(raiz):
			planas += 1
			if peca is CollisionObject2D or peca is CollisionShape2D 				or peca is CollisionPolygon2D:
				com_corpo.append("%s/%s" % [nome, peca.name])

	# 2. todo volumetrico tem UM solido, e a forma dele bate com a sombra.
	var volumes := 0
	var sem_solido := 0
	var layer_errada := 0
	var forma_errada := 0
	var fora_da_reserva := 0
	for corpo in _props_volumetricos(sala):
		volumes += 1
		var solidos: Array[StaticBody2D] = []
		for filho in corpo.get_children():
			var solido := filho as StaticBody2D
			if solido != null:
				solidos.append(solido)
		if solidos.size() != 1:
			sem_solido += 1
			continue
		if solidos[0].collision_layer != Sala.LAYER_PAREDE or solidos[0].collision_mask != 0:
			layer_errada += 1
		var largura := _largura_do_corpo(corpo)
		var perto := Sala.ponto_da_parede_mais_proxima(aberto, corpo.position)
		var esperada := Sala.forma_de_colisao_do_prop(
			largura, perto.distance_to(corpo.position))
		var forma: CollisionShape2D = null
		for filho in solidos[0].get_children():
			var candidata := filho as CollisionShape2D
			if candidata != null:
				forma = candidata
		var caixa: RectangleShape2D = null
		if forma != null:
			caixa = forma.shape as RectangleShape2D
		if caixa == null or not caixa.size.is_equal_approx(esperada):
			forma_errada += 1
			continue
		# O solido NUNCA toca a area de combate. Ele PODE ser mais fundo que a
		# reserva -- ele cresce para TRAS, para dentro do muro, que ja e solido --,
		# mas para a frente ele para onde a peca reservou.
		var centro := corpo.position + forma.position
		var solido_como_caixa := Rect2(centro - caixa.size * 0.5, caixa.size)
		if sala.area_spawn.intersects(solido_como_caixa):
			fora_da_reserva += 1

	ok(planas > 0, "houve peca plana para conferir (%d)" % planas)
	igual(com_corpo.size(), 0,
		"nenhuma familia plana tem colisao -- solido em coisa pintada e esbarrao fantasma (%s)"
			% ", ".join(com_corpo))
	ok(volumes > 0, "houve prop volumetrico para conferir (%d)" % volumes)
	igual(sem_solido, 0,
		"todo prop volumetrico tem exatamente UM solido (%d de %d sem)" % [sem_solido, volumes])
	igual(layer_errada, 0,
		"o solido esta na layer da PAREDE e nao procura ninguem (%d errados)" % layer_errada)
	igual(forma_errada, 0,
		"a caixa do solido e a SOMBRA da peca, e nao a pegada cheia (%d errados)" % forma_errada)
	igual(fora_da_reserva, 0,
		"e ela nunca toca a area de combate (%d tocando)" % fora_da_reserva)
	sala.free()


## O solido nunca deixa um vao INTRANSPONIVEL entre ele e a parede.
##
## **E o unico risco que a colisao introduz e que nao se ve chegando.** Solido na
## faixa de perimetro pode nascer a qualquer profundidade da janela de ancora, e
## uma peca ancorada a meio caminho deixa uma fresta entre a parede e ela. Fresta
## larga e um vao; fresta de dez pixels e um lugar em que o jogador enfia o
## personagem, fica preso e nao entende por que -- e o inimigo, que nao tem
## pathfinding, fica raspando ali.
##
## A regra e binaria e nao tem numero proprio: ou o solido ENCOSTA na parede (vao
## zero ou negativo, e ai a peca e uma saliencia continua do muro), ou ele deixa
## espaco para um corpo passar (`FOLGA_CORPO`, o mesmo raio que
## `posicao_livre()` ja usa para decidir se cabe alguem). O meio termo e o que
## nao pode existir.
##
## Ela e cobrada aqui e nao no decorador porque quem produz o vao e a soma de tres
## decisoes -- janela de ancora, largura da peca e profundidade do solido -- e
## nenhuma das tres sozinha sabe do resultado.
func _o_solido_nunca_deixa_um_BOLSAO_intransponivel_contra_a_parede() -> void:
	var medidos := 0
	var bolsoes := 0
	var pior := ""
	for caminho in TIPOS_COM_VOLUME:
		var dados: DadosSala = load(caminho)
		if dados == null:
			continue
		for semente in 6:
			var sala := _montar_com_semente(dados, semente + 1, false)
			var aberto := sala.contorno_local()
			for corpo in _props_volumetricos(sala):
				var largura := _largura_do_corpo(corpo)
				var ate_a_parede := Sala.ponto_da_parede_mais_proxima(
					aberto, corpo.position).distance_to(corpo.position)
				var caixa := Sala.forma_de_colisao_do_prop(largura, ate_a_parede)
				# A distancia da BEIRADA DE TRAS do solido a parede, ja contado o
				# recuo -- e ele que faz a peca encostar quando a fresta seria
				# estreita demais para o corpo passar.
				var recuo := Sala.recuo_do_solido(largura, ate_a_parede)
				var vao := ate_a_parede - recuo - caixa.y * 0.5
				medidos += 1
				if vao > 0.5 and vao < Sala.FOLGA_CORPO:
					bolsoes += 1
					if pior == "":
						pior = "%s: vao de %.0f px contra folga de %.0f" % [
							dados.id, vao, Sala.FOLGA_CORPO]
			sala.free()

	ok(medidos > 0, "houve solido para medir (%d)" % medidos)
	igual(bolsoes, 0,
		"nenhum solido deixa fresta em que o corpo nao passa -- ou encosta, ou da caminho (%d de %d; %s)"
			% [bolsoes, medidos, pior])


## Todo no daquela sub-arvore, a raiz incluida.
func _todos_os_nos(raiz: Node) -> Array[Node]:
	var saida: Array[Node] = [raiz]
	for filho in raiz.get_children():
		saida.append_array(_todos_os_nos(filho))
	return saida


## A peca de PAREDE so existe onde ha FACE, e ela nao espelha (`[FAB 22]`).
##
## Esta e a quinta familia de decoracao e a que faltava: o porte `PAREDE` existe
## no `DecoradorDeSala` desde a `[FAB 07]` e ate aqui so a luminaria o consumia.
## O plano registrava a divida com todas as letras -- "peca presa na FACE nao e
## nem prop de chao nem foreground".
##
## As tres coisas que ela cobra falham em silencio, e nenhuma da erro:
##
## 1. **So o lado NORTE recebe.** `_montar_visual` so veste de face o lado
##    virado para a camera; os outros tres mostram TOPO, que e a espessura vista
##    de cima. Um tubo colado ali seria um tubo deitado sobre a espessura da
##    parede -- e a perspectiva que o `LOW_TOPDOWN_SQUARED.md` defende cairia
##    junto, sem uma linha no console.
## 2. **Ela desenha ABAIXO de `Z_MUNDO` e ACIMA da fita.** Acima do mundo ela
##    cobriria telegrafo e projetil; abaixo da fita ela sumiria dentro da propria
##    parede, e o sintoma seria arte em disco que nao aparece -- o mesmo defeito
##    que a `AreaDePerigo` pagou desenhando em z -4.
## 3. **Ela NAO espelha.** Toda arte do jogo e iluminada do canto superior
##    esquerdo, e `flip_h` poe a luz vindo da direita numa peca colada ao lado de
##    uma face que continua iluminada da esquerda. As outras familias espelham
##    para multiplicar variedade; esta nao pode.
func _a_peca_de_PAREDE_so_existe_onde_ha_FACE() -> void:
	var dados: DadosSala = load("res://src/mapa/tipo_combate.tres")
	if dados == null:
		return
	ok(dados.faixa_de_props_parede().y > 0,
		"a sala de combate pede peca de parede (%d)" % dados.faixa_de_props_parede().y)

	var pecas := 0
	var fora_do_norte := 0
	var espelhadas := 0
	for x in 12:
		var sala := CENA_SALA.instantiate() as Sala
		sala.coordenadas_grid = Vector2i(x * 3, x)
		sala.definir_visual(dados)
		sala.position = LONGE
		Engine.get_main_loop().root.add_child(sala)

		var raiz := sala.get_node_or_null("ParedePecas") as Node2D
		if raiz != null:
			igual(raiz.z_index, RenderizadorParedes.Z_FITA + 1,
				"a camada de parede desenha logo acima da fita")
			ok(raiz.z_index < Sala.Z_MUNDO,
				"e abaixo do mundo -- ela nunca cobre telegrafo nem projetil")
			var caixa := _caixa_do_contorno(sala.contorno_local())
			for filho in raiz.get_children():
				var sprite := filho as Sprite2D
				if sprite == null:
					continue
				pecas += 1
				if sprite.flip_h or sprite.flip_v:
					espelhadas += 1
				# O lado NORTE e o topo da caixa envolvente. Uma peca na metade
				# de baixo esta num lado que mostra TOPO, e nao face.
				if sprite.position.y > caixa.position.y + caixa.size.y * 0.25:
					fora_do_norte += 1
		sala.free()

	ok(pecas > 0, "houve peca de parede para conferir (%d)" % pecas)
	igual(fora_do_norte, 0,
		"toda peca de parede fica no lado que TEM face (%d de %d fora)"
			% [fora_do_norte, pecas])
	igual(espelhadas, 0,
		"nenhuma peca de parede espelha -- a luz do jogo vem do canto superior esquerdo (%d)"
			% espelhadas)


## A caixa envolvente de um contorno, em coordenadas locais.
func _caixa_do_contorno(pontos: PackedVector2Array) -> Rect2:
	if pontos.is_empty():
		return Rect2()
	var caixa := Rect2(pontos[0], Vector2.ZERO)
	for i in range(1, pontos.size()):
		caixa = caixa.expand(pontos[i])
	return caixa


# ------------------------------------------------------------------ apoio ----

## A ARENA REAGE AS FASES sem cobrir a leitura (AND1 07).
##
## Esta e a sala mais densa de projetil do jogo, e a fase 3 e exatamente quando
## os dois riscos se somam: mais efeito na tela e mais projetil na tela, no mesmo
## instante. O plano crava a regra -- "faiscas ficam principalmente perto das
## PAREDES; nunca particulas brilhantes atravessando a arena" -- e aqui ela vira
## geometria em vez de bom senso.
##
## Tres coisas se cobram, e nenhuma delas e sobre gosto:
##
## 1. Toda luz nasce junto da parede. O miolo -- onde o jogador esquiva e onde o
##    telegrafo desenha -- fica limpo.
## 2. Toda luz desenha ABAIXO de `Sala.Z_MUNDO`, a faixa do telegrafo e do
##    projetil.
## 3. O brilho tem teto, e ele NAO explode na fase 3.
func _a_arena_reage_sem_cobrir_a_leitura() -> void:
	var arena: Sala = preload("res://src/mapa/sala_6_boss.tscn").instantiate()
	arena.position = LONGE
	Engine.get_main_loop().root.add_child(arena)

	var baia := arena.get_node_or_null("Baia") as Sprite2D
	ok(baia != null and baia.texture != null,
		"a arena tem a BAIA: o lugar de onde o chefe saiu, legivel antes de ele se mexer")
	if baia != null:
		ok(baia.z_index < Sala.Z_MUNDO,
			"e ela e marca de CHAO -- desenha abaixo do mundo, sob o proprio chefe")

	var reacao := arena.get_node_or_null("ReacaoDeArena") as ReacaoDeArena
	ok(reacao != null, "e a arena reage as fases do chefe")
	if reacao == null:
		arena.free()
		return

	ok(reacao.z_index < Sala.Z_MUNDO,
		"as luzes desenham abaixo da faixa do telegrafo e do projetil (z %d)" % reacao.z_index)
	var longe_da_parede := reacao.distancia_maxima_do_contorno()
	ok(longe_da_parede <= ReacaoDeArena.FAIXA_DA_PAREDE,
		"nenhuma luz entra na arena (%.0f px da parede, teto %.0f)"
			% [longe_da_parede, ReacaoDeArena.FAIXA_DA_PAREDE])

	# O brilho SOBE com a fase, mas nao explode: a fase 3 e onde os dois riscos
	# se somam, e e la que o teto tem de morder.
	var brilhos: Array[float] = []
	for fase in [1, 2, 3]:
		EventBus.boss_fase_mudou.emit(fase)
		var pico := 0.0
		for _i in 60:
			reacao._process(0.05)
			for luz in reacao.get_children():
				pico = maxf(pico, (luz as CanvasItem).modulate.a)
		brilhos.append(pico)
	ok(brilhos[0] < brilhos[2],
		"a arena acende com a fase (%.2f na 1, %.2f na 3)" % [brilhos[0], brilhos[2]])
	ok(brilhos[2] <= ReacaoDeArena.ALPHA_MAXIMO + 0.001,
		"e a fase 3 nao passa do teto de brilho (%.2f de %.2f)"
			% [brilhos[2], ReacaoDeArena.ALPHA_MAXIMO])

	arena.free()


## O PROP RARO aparece em UMA sala do andar, e so.
##
## O caso vivo e o Robo Desativado: ele e o que faz o jogador perceber que o
## setor usava robos muito antes de encontrar o chefe, e isso funciona uma vez.
## Repetido em cinco salas ele vira mobilia, e a descoberta que ele existe para
## plantar deixa de acontecer -- o plano do andar pede "com extrema moderacao"
## com todas as letras.
##
## O que se cobra e o PORTAO da sala, e nao o sorteio: uma sala nao autorizada
## nunca pode desenhar a regiao rara, por mais vezes que ela sorteie. Sem isso, a
## regra ficaria dependendo de o gerenciador nunca errar -- e regra que depende
## de ninguem errar nao e regra.
func _o_prop_raro_aparece_numa_sala_por_andar() -> void:
	var combate: DadosSala = load("res://src/mapa/tipo_combate.tres")
	ok(combate != null and not combate.regioes_props_raras.is_empty(),
		"a sala de combate declara ao menos um prop raro")
	if combate == null or combate.regioes_props_raras.is_empty():
		return

	var raras := {}
	for r: Rect2i in combate.regioes_props_raras:
		raras[str(r)] = true
	# E ele NAO esta no pool comum: estando nos dois, a sala nao autorizada o
	# desenharia mesmo assim, e o portao seria decorativo.
	for r: Rect2i in combate.regioes_props_volume:
		ok(not raras.has(str(r)),
			"a regiao rara %s nao esta tambem no pool comum" % r)

	# Uma sala NAO autorizada nunca desenha a regiao rara, em varias sementes.
	var vazou := false
	var autorizada_desenhou := false
	for semente in 12:
		var comum := _montar_com_semente(combate, semente, false)
		vazou = vazou or _tem_regiao(comum, raras)
		comum.free()
		var sorteada := _montar_com_semente(combate, semente, true)
		autorizada_desenhou = autorizada_desenhou or _tem_regiao(sorteada, raras)
		sorteada.free()
	ok(not vazou, "sala nao autorizada NUNCA desenha o prop raro, em 12 sementes")
	ok(autorizada_desenhou, "e a autorizada chega a desenhar -- senao o portao seria um mute")


func _montar_com_semente(dados: DadosSala, semente: int, autorizada: bool) -> Sala:
	var sala: Sala = CENA_SALA.instantiate()
	sala.definir_visual(dados)
	if autorizada:
		sala.permitir_props_raros()
	sala.coordenadas_grid = Vector2i(semente, semente * 3)
	sala.position = LONGE
	Engine.get_main_loop().root.add_child(sala)
	return sala


func _tem_regiao(sala: Sala, raras: Dictionary) -> bool:
	for filho in sala.get_children():
		for neto in filho.get_children():
			var sprite := neto as Sprite2D
			if sprite != null and sprite.region_enabled:
				var r := Rect2i(sprite.region_rect)
				if raras.has(str(r)):
					return true
	return false


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
		# Pelo GRUPO e nao pelo nome: `add_child` renomeia o segundo em diante
		# para `@PropVolume@<id>`, entao o filtro por nome achava exatamente UM
		# por sala -- este helper media o primeiro prop e nada mais, verde, desde
		# que nasceu.
		if filho is Node2D and (filho as Node2D).is_in_group(Sala.GRUPO_PROP_VOLUME):
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


## O FOREGROUND (LTD 10) nunca entra na area util da sala.
##
## Este e o criterio de aceite da issue -- "nenhum telegrafo de inimigo ou do
## chefe fica coberto pelo Foreground" -- na unica forma que da para cobrar sem
## alguem olhar cada captura.
##
## A cadeia e esta: telegrafo nasce onde o inimigo esta; inimigo nasce dentro da
## `area_spawn`; logo, elemento que nunca toca a `area_spawn` nunca cobre
## telegrafo. Sai uma pergunta de revisao visual e entra uma comparacao de
## retangulos.
##
## Ele tambem cobra a DOSAGEM. A issue diz "usar com moderacao: o objetivo e
## aumentar profundidade, nao esconder constantemente o combate", e sem numero
## isso e opiniao. O numero e o TETO de `PerfilDeDecoracao.contagem_frente`, e o
## teste prova que a sala respeita o teto em vez de encher a margem.
func _o_foreground_nunca_entra_na_area_util() -> void:
	var dados: DadosSala = load("res://src/mapa/tipo_combate.tres")
	ok(dados != null, "tipo_combate carrega")
	if dados == null:
		return
	var teto_de_frente := dados.faixa_de_props_frente().y
	ok(teto_de_frente > 0, "a sala de combate pede Foreground")

	# Varre varias celulas: o sorteio e por celula, e uma celula so poderia
	# passar por sorte. Se algum lugar do andar puser uma viga sobre a area
	# util, alguem vai jogar naquele lugar.
	var conferidas := 0
	var vistos := 0
	for x in 10:
		var sala := CENA_SALA.instantiate() as Sala
		sala.coordenadas_grid = Vector2i(x, 0)
		sala.definir_visual(dados)
		sala.position = LONGE
		Engine.get_main_loop().root.add_child(sala)

		var raiz := sala.get_node_or_null("Frente") as Node2D
		if raiz != null:
			igual(raiz.z_index, Sala.Z_FRENTE, "a camada Frente esta na faixa dela")
			ok(
				raiz.get_child_count() <= teto_de_frente,
				"a sala respeita o teto de Foreground (%d de %d)"
					% [raiz.get_child_count(), teto_de_frente]
			)
			for filho in raiz.get_children():
				var sprite := filho as Sprite2D
				if sprite == null:
					continue
				vistos += 1
				var r := sprite.region_rect
				var caixa := Rect2(
					sprite.position - r.size * 0.5, r.size
				)
				ok(
					not sala.area_spawn.intersects(caixa),
					"o Foreground fica FORA da area util -- telegrafo nasce la dentro (%s)" % caixa
				)
			conferidas += 1
		sala.free()

	ok(conferidas > 0, "alguma celula montou a camada Frente (%d)" % conferidas)
	# Piso: uma varredura que nao achasse nenhum elemento passaria como aprovacao
	# sem ter olhado nada -- a mesma armadilha que o piso de atores do
	# teste_texturas evita.
	ok(vistos > 0, "a varredura viu ao menos um elemento de Foreground (%d)" % vistos)

	# E ele NAO tem sombra: sombra responde "onde isto encosta no chao", e uma
	# viga suspensa nao encosta. Sombra ali diria que ha obstaculo no piso.
	var amostra := CENA_SALA.instantiate() as Sala
	amostra.coordenadas_grid = Vector2i(2, 2)
	amostra.definir_visual(dados)
	amostra.position = LONGE
	Engine.get_main_loop().root.add_child(amostra)
	var frente := amostra.get_node_or_null("Frente") as Node2D
	if frente != null:
		for filho in frente.get_children():
			ok(
				filho.get_node_or_null("Sombra") == null,
				"elemento de Foreground nao tem sombra: ele nao encosta no chao"
			)
	amostra.free()


## Quantas salas a varredura de contagem visita.
##
## Doze: com `PROP_TENTATIVAS` em 12 e a margem apertada, uma sala isolada pode
## perder uma peca sem que nada esteja errado. O que o portao tem de pegar e a
## decoracao sumir de VEZ -- e isso e uma media, nao um caso.
const SALAS_MEDIDAS := 12


## O decalque industrial e POUCO, ele nao espelha, e ele fica chapado.
##
## As tres coisas falham em silencio, e nenhuma aparece no console.
##
## **Pouco.** `_sortear_ponto_de_prop()` desiste depois de 12 tentativas sem
## dizer nada, e `_cabe_prop()` recusa quem encosta em porta ou parede. Uma sala
## com ZERO decalques passa por qualquer teste que pergunte `> 0` -- e essa era a
## divida anotada no plano de enquadramento: "o portao de props precisa passar a
## cobrar a CONTAGEM pedida, e nao `> 0`". Este caso cobra os dois lados: que
## chegue perto do pedido, e que nao passe dele.
##
## **Nao espelha.** `_montar_props_chapados` sorteia `flip_h` para multiplicar a
## variedade de graca. Num decalque com texto isso escreve `30-A` em metade das
## salas -- e nao ha erro para uma placa lida ao contrario. Espelhar REFLETE, e e
## a mesma razao pela qual `flip_v` e proibido na porta.
##
## **Chapado.** Zero e onde ficam telegrafo, projetil e atores. Um decalque ali
## poderia cair na frente do aviso que torna um ataque justo.
func _o_decalque_industrial_e_POUCO_e_nao_espelha() -> void:
	var dados: DadosSala = load("res://src/mapa/tipo_combate.tres")
	if dados == null:
		ok(false, "o tipo de combate carrega")
		return
	ok(dados.atlas_decalques != null and not dados.regioes_decalques.is_empty(),
		"o tipo de combate declara o atlas de decalques")
	# POUCO deixou de ser o literal "1 a 3" e passou a ser uma REGRA contra o
	# atlas: o teto pedido nao passa do numero de pecas declaradas, entao uma
	# sala nunca estampa a mesma peca duas vezes em media. O numero cravado
	# envelheceria com a arte -- e a mesma licao que o teto de fichas de credito
	# ja pagou, afirmando "o chefe paga 60" em vez da regra. Quando a `[FAB 28]`
	# entregar as 10 pecas novas, o teto sobe sozinho.
	var faixa_decalque := dados.faixa_de_decalques()
	var pecas := dados.regioes_decalques.size()
	ok(faixa_decalque.x >= 1, "a sala pede ao menos um decalque (%d)" % faixa_decalque.x)
	entre(float(faixa_decalque.y), 1.0, float(pecas),
		"o teto de decalques cabe no atlas -- sem peca repetida em media (%d de %d)"
			% [faixa_decalque.y, pecas])
	if dados.atlas_decalques == null:
		return

	var total := 0
	var espelhados := 0
	var fora_da_faixa := 0
	var regioes := {}
	for r in dados.regioes_decalques:
		regioes["%d,%d,%d,%d" % [r.position.x, r.position.y, r.size.x, r.size.y]] = true

	for i in SALAS_MEDIDAS:
		var sala := CENA_SALA.instantiate() as Sala
		sala.coordenadas_grid = Vector2i(i * 7, i)
		sala.definir_visual(dados)
		sala.position = LONGE
		Engine.get_main_loop().root.add_child(sala)
		var raiz := sala.get_node_or_null("Decalques") as Node2D
		if raiz != null:
			if raiz.z_index != Sala.Z_CHAO_DETALHE:
				fora_da_faixa += 1
			for filho in raiz.get_children():
				var s := filho as Sprite2D
				if s == null:
					continue
				total += 1
				if s.flip_h or s.flip_v:
					espelhados += 1
				var r := s.region_rect
				var chave := "%d,%d,%d,%d" % [r.position.x, r.position.y, r.size.x, r.size.y]
				if not regioes.has(chave):
					fora_da_faixa += 1
		sala.free()

	igual(espelhados, 0,
		"nenhum decalque espelha -- texto espelhado nao da erro nenhum (%d de %d)"
			% [espelhados, total])
	igual(fora_da_faixa, 0,
		"todo decalque fica na faixa de detalhe de chao e numa regiao declarada (%d)"
			% fora_da_faixa)

	# A faixa e um INTERVALO desde a migracao das contagens: cada sala sorteia
	# dentro dela, entao o esperado do lote e o intervalo multiplicado pelas
	# salas -- e nao um numero.
	var piso := faixa_decalque.x * SALAS_MEDIDAS
	var teto := faixa_decalque.y * SALAS_MEDIDAS
	# O piso e 60% do minimo pedido, e nao o minimo inteiro: a margem entre a
	# parede e a area de spawn e apertada e uma peca de 64 nem sempre cabe longe
	# da porta. O que este numero pega e a decoracao sumir de vez -- que e o modo
	# de falha real, porque `_ponto_de_prop()` desiste em silencio.
	entre(float(total), float(piso) * 0.6, float(teto),
		"as salas receberam os decalques pedidos (%d, faixa %d a %d em %d salas)"
			% [total, piso, teto, SALAS_MEDIDAS])


## A peca mostra a VISTA do lado em que ela encosta (`[FAB 50]`).
##
## **E a terceira correcao do dono, e a que so aparece em tela.** O pedido foi
## *"usar a orientacao reta, norte-sul ou leste-oeste, para que caiba encostado na
## parede na maioria das vezes"*. Uma peca desenhada de frente tem o eixo longo
## correndo leste-oeste; colada na parede LESTE, esse eixo aponta para dentro da
## sala -- ela fica com uma quina no muro e um vao atras, e nenhuma regua de cor
## ou de posicao pega isso.
##
## Por isso cada gabarito tem DUAS artes, e o atlas as declara em pares:
## `[frente_0, ponta_0, frente_1, ponta_1, ...]`. Norte e sul mostram a frente;
## leste e oeste mostram a ponta, que e a mesma peca com o eixo longo virado.
## Nao e a mesma arte girada -- girar arte de FACE destroi a perspectiva, e o
## projeto ja fechou essa decisao na porta.
##
## O caso morde onde a divergencia moraria: ele deriva o LADO da geometria (a
## aresta mais proxima da peca) e cobra que a regiao desenhada esteja na metade
## certa do par. Uma tabela paralela de "que lado usa que vista" divergiria da do
## `DadosSala`, e o sintoma seria a peca reservando o chao de uma silhueta e
## desenhando outra.
func _a_peca_mostra_a_VISTA_do_lado_em_que_ela_encosta() -> void:
	var medidas := 0
	var erradas := 0
	var em_lateral := 0
	var pior := ""
	for caminho in TIPOS_COM_VOLUME:
		var dados: DadosSala = load(caminho)
		if dados == null or dados.regioes_props_volume.size() < 2:
			continue
		# As pontas sao os indices IMPARES, por construcao do par.
		var pontas := {}
		for i in range(1, dados.regioes_props_volume.size(), 2):
			pontas[str(dados.regioes_props_volume[i])] = true
		var frentes := {}
		for i in range(0, dados.regioes_props_volume.size(), 2):
			frentes[str(dados.regioes_props_volume[i])] = true

		for semente in 6:
			var sala := _montar_com_semente(dados, semente + 1, false)
			var aberto := sala.contorno_local()
			for corpo in _props_volumetricos(sala):
				var sprite := _sprite_do_corpo(corpo)
				if sprite == null:
					continue
				medidas += 1
				var chave := str(Rect2i(sprite.region_rect))
				var lado := DecoradorDeSala.lado_da_posicao(aberto, corpo.position)
				var lateral := lado == DecoradorDeSala.Lado.LESTE 					or lado == DecoradorDeSala.Lado.OESTE
				if lateral:
					em_lateral += 1
				# Peca simetrica de ponta a ponta declara a MESMA regiao nas duas
				# metades do par -- ela e frente e ponta ao mesmo tempo, e passa
				# em qualquer lado. E o caso do engradado e do duto.
				var vale: bool = pontas.has(chave) if lateral else frentes.has(chave)
				if not vale:
					erradas += 1
					if pior == "":
						pior = "%s: %s numa parede %s" % [
							dados.id, chave, "lateral" if lateral else "norte/sul"]
			sala.free()

	ok(medidas > 0, "houve peca para conferir (%d)" % medidas)
	igual(erradas, 0,
		"toda peca mostra a vista do lado em que ela encosta (%d de %d; %s)"
			% [erradas, medidas, pior])
	# A ponta que impede o carimbo: se NENHUMA peca cair numa lateral, o caso
	# esta verde por nunca ter exercitado a metade que ele existe para cobrar.
	ok(em_lateral > 0,
		"e alguma peca de fato encostou numa parede lateral (%d)" % em_lateral)


## A LIGACAO toca as DUAS pecas que ela liga (`[FAB 22]`).
##
## **E o unico dos cinco pedidos do dono que nao e sobre posicao:** *"as conexoes
## com canos, com cantos e entre si dos moveis com a sala deve ser evidente"*. A
## bancada e uma fileira de maquinas encostadas, e uma fileira sem nada
## atravessando le como moveis lado a lado.
##
## O cano desenha em `Z_FITA + 1`, ATRAS dos volumes, e so aparece nos vaos --
## ele entra em cada maquina por oclusao. Isso e barato e tem um modo de falha
## proprio: um cano curto demais termina ANTES da vizinha e le como cano cortado,
## e um cano no lugar errado nao aparece de jeito nenhum, porque tudo que nao cai
## num vao fica escondido. **Nenhum dos dois da erro no console** -- os dois sao
## um sprite existindo em disco sem nada em tela.
##
## Por isso o caso mede SOBREPOSICAO e nao presenca: a caixa do cano tem de
## invadir a caixa das duas vizinhas mais proximas dele. Cobrar so "existe um
## sprite em Ligacoes" passaria com o cano desenhado no meio do nada.
func _a_LIGACAO_toca_as_duas_pecas_que_ela_liga() -> void:
	var canos := 0
	var soltos := 0
	var salas_com_ligacao := 0
	for caminho in TIPOS_COM_VOLUME:
		var dados: DadosSala = load(caminho)
		if dados == null or dados.atlas_canos == null:
			continue
		for semente in 8:
			var sala := _montar_com_semente(dados, semente + 1, false)
			var raiz := sala.get_node_or_null("Ligacoes") as Node2D
			if raiz != null and raiz.get_child_count() > 0:
				salas_com_ligacao += 1
			if raiz != null:
				var corpos := _props_volumetricos(sala)
				for filho in raiz.get_children():
					var cano := filho as Sprite2D
					if cano == null:
						continue
					canos += 1
					var caixa := Rect2(
						cano.position - cano.region_rect.size * 0.5,
						cano.region_rect.size)
					# Quantas pecas de volume esta ligacao ATRAVESSA.
					var tocadas := 0
					for corpo in corpos:
						var sprite := _sprite_do_corpo(corpo)
						if sprite == null:
							continue
						var largura := float(sprite.region_rect.size.x)
						var altura := float(sprite.region_rect.size.y)
						var peca := Rect2(
							corpo.position - Vector2(largura * 0.5, altura),
							Vector2(largura, altura))
						if peca.intersects(caixa):
							tocadas += 1
					if tocadas < 2:
						soltos += 1
			sala.free()

	ok(canos > 0, "houve ligacao para conferir (%d)" % canos)
	igual(soltos, 0,
		"toda ligacao atravessa as DUAS vizinhas -- cano que nao entra le como cano cortado (%d de %d)"
			% [soltos, canos])
	ok(salas_com_ligacao > 0,
		"e as salas de fato montam bancada com vao para ligar (%d)" % salas_com_ligacao)


## Nenhuma celula do atlas entra no jogo com o FUNDO DO GERADOR ainda colado.
##
## ## O defeito que este portao existe para pegar
##
## `transparent background` no prompt do PixelLab **nao garante alfa**, e este
## repositorio ja pagou a licao duas vezes -- nos icones as 16 pecas voltaram
## 100% opacas, e nos props "o armario voltou com alfa e o vaso de pressao 100%
## opaco" na mesma leva. Quando passa, a peca entra no atlas com um RETANGULO
## CINZA atras dela: numa sala escura o jogador ve uma moldura clara em volta do
## movel, que le como bug de renderizacao e nao como decoracao.
##
## Duas celulas estavam assim quando este caso foi escrito -- a cadeira da
## estacao de modificacao corporal (16,8% da celula) e um resto de fundo na base
## da bancada de ferramentas. **Nenhum portao acusava**, e nao por descuido: o
## de paleta mede valor e saturacao do ARQUIVO INTEIRO, e um cinza de luma 0,42
## cabe folgado no teto da familia `prop`; o de ancora mede a ultima linha com
## arte, e fundo chapado tambem e arte para ele. O defeito so aparecia em tela.
##
## ## Por que CONEXAO, e nunca cor
##
## Apagar "todo pixel parecido com o fundo" abriria buraco DENTRO da peca, e
## aqui isso seria fatal: metal escovado tem highlight quase branco, e **36 das
## 61 celulas** do atlas tem pixel de saturacao zero -- em 34 delas ele e o
## brilho da chapa. So conta o que ALCANCA a borda da celula.
##
## E o que separa fundo de sombra nao e um limiar escolhido a dedo: e a PALETA.
## O funil do andar 1 grampeia o matiz, entao arte aprovada e azulada por
## construcao e nunca cinza puro.
##
## Quem conserta e `tools/texturas/chavear_celula.py`, com esta mesma definicao
## de fundo -- portao e conserto discordarem seria pior que nao ter nenhum dos
## dois.
func _nenhuma_celula_do_atlas_entra_com_FUNDO_CHAPADO() -> void:
	var imagem := _abrir_atlas()
	if imagem == null:
		ok(false, "props_volume.png abre")
		return

	var vistas := {}
	var sujas := 0
	for caminho: String in TIPOS_COM_REGIAO_DECLARADA:
		var dados: DadosSala = load(caminho)
		if dados == null:
			continue
		var regioes: Array[Rect2i] = []
		regioes.append_array(dados.regioes_props_volume)
		regioes.append_array(dados.regioes_props_raras)
		for regiao: Rect2i in regioes:
			if vistas.has(regiao):
				continue
			vistas[regiao] = true
			var area := float(maxi(regiao.size.x * regiao.size.y, 1))
			var fundo := _fundo_chapado_da_celula(imagem, regiao)
			var fracao := float(fundo) / area
			if fracao >= FRACAO_MINIMA_DE_FUNDO:
				sujas += 1
				ok(
					false,
					"a celula %s entra com o fundo do gerador colado (%d px, %.1f%% dela)"
						% [regiao, fundo, fracao * 100.0]
				)

	# A segunda ponta: um portao que nunca olhou celula nenhuma tambem diria
	# "nenhuma suja". Tabela vazia nao e aprovacao.
	ok(vistas.size() >= 40,
		"o portao varreu o atlas inteiro (%d celulas declaradas)" % vistas.size())
	igual(sujas, 0, "nenhuma celula do atlas volumetrico tem fundo chapado")


## Os pixels de fundo chapado de uma celula: opacos, de cor NEUTRA, e ligados a
## borda dela. Zero quando a celula esta limpa. Ver o bloco do caso acima.
func _fundo_chapado_da_celula(imagem: Image, regiao: Rect2i) -> int:
	var larg := regiao.size.x
	var alt := regiao.size.y
	if larg <= 0 or alt <= 0:
		return 0

	# A cor do fundo e a mais comum NA BORDA, e nao na celula: a peca ocupa o
	# miolo, entao a moda da celula inteira seria a cor do movel.
	var contagem := {}
	var borda: Array[Vector2i] = []
	for i in larg:
		borda.append(Vector2i(i, 0))
		borda.append(Vector2i(i, alt - 1))
	for j in alt:
		borda.append(Vector2i(0, j))
		borda.append(Vector2i(larg - 1, j))

	var opacas: Array[Vector2i] = []
	for p: Vector2i in borda:
		var cor := imagem.get_pixelv(regiao.position + p)
		if cor.a <= 0.78:
			continue
		opacas.append(p)
		var chave := Vector3i(
			roundi(cor.r * 255.0), roundi(cor.g * 255.0), roundi(cor.b * 255.0))
		contagem[chave] = int(contagem.get(chave, 0)) + 1
	if opacas.is_empty():
		return 0

	var moda := Vector3i.ZERO
	var melhor := 0
	for chave: Vector3i in contagem:
		var n: int = contagem[chave]
		if n > melhor:
			melhor = n
			moda = chave
	var fundo := Color8(moda.x, moda.y, moda.z)
	var maior := maxf(fundo.r, maxf(fundo.g, fundo.b))
	var menor := minf(fundo.r, minf(fundo.g, fundo.b))
	var saturacao := 0.0 if maior <= 0.0 else (maior - menor) / maior
	if saturacao > SATURACAO_MAXIMA_DE_FUNDO or maior < VALOR_MINIMO_DE_FUNDO:
		return 0

	# Preenchimento a partir da borda. `visto` e um PackedByteArray e nao um
	# Dictionary porque a varredura roda em 61 celulas de ate 96x128.
	var visto := PackedByteArray()
	visto.resize(larg * alt)
	var fila: Array[Vector2i] = []
	for p: Vector2i in opacas:
		if visto[p.y * larg + p.x] == 0 and _e_fundo(imagem, regiao, p, fundo):
			visto[p.y * larg + p.x] = 1
			fila.append(p)

	var total := 0
	while not fila.is_empty():
		var atual: Vector2i = fila.pop_back()
		total += 1
		for passo: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var vizinho := atual + passo
			if vizinho.x < 0 or vizinho.y < 0 or vizinho.x >= larg or vizinho.y >= alt:
				continue
			var indice := vizinho.y * larg + vizinho.x
			if visto[indice] != 0:
				continue
			if _e_fundo(imagem, regiao, vizinho, fundo):
				visto[indice] = 1
				fila.append(vizinho)
	return total


func _e_fundo(imagem: Image, regiao: Rect2i, ponto: Vector2i, fundo: Color) -> bool:
	var cor := imagem.get_pixelv(regiao.position + ponto)
	if cor.a <= 0.78:
		return false
	var distancia := (
		absf(cor.r - fundo.r) + absf(cor.g - fundo.g) + absf(cor.b - fundo.b))
	return distancia <= TOLERANCIA_DE_FUNDO
