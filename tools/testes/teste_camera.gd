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
	ok(margem.y > margem.w,
		"e a de CIMA e maior que a de BAIXO -- e a assimetria que carrega a perspectiva (%.0f contra %.0f)"
			% [margem.y, margem.w])
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
		var esperados := [margem.x, margem.y, margem.z, margem.w]
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
		var esperado := _caixa(sala.contorno_local()).grow_individual(
			margem.x, margem.y, margem.z, margem.w)
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
