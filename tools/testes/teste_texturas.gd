extends TesteBase
## Os portoes da identidade visual (docs/IDENTIDADE_VISUAL.md) aplicados aos
## PNGs de assets/texturas/.
##
## Por que isto e teste e nao revisao de olho: a regra "cenario nunca compete
## com projetil" e uma regra de saturacao e valor, e olho humano nao mede HSV.
## Uma textura bonita que passa de raspao num monitor claro some com o tiro no
## monitor escuro do testador. A suite mede, e a captura confirma.
##
## O que ela cobra:
##   G1  todo pixel opaco de textura de AMBIENTE pertence a Paleta.ambiente()
##   G2  nenhuma cor de ambiente e saturada E clara ao mesmo tempo
##   G3  ambiente e ator nao se cruzam, e o ator esta do lado claro de G2
##   +   dimensao multipla de 16, alpha so 0 ou 1, todo tipo aponta textura
##       que carrega, e o gerador e deterministico -- inclusive contra o PNG
##       em disco, para ninguem mudar o gerador e esquecer de gerar.

const PASTA := "res://assets/texturas"
const GRADE := 16

const TIPOS := [
	"res://src/mapa/tipo_combate.tres",
	"res://src/mapa/tipo_boss.tres",
	"res://src/mapa/tipo_arma.tres",
	"res://src/mapa/tipo_item.tres",
	"res://src/mapa/tipo_inicial.tres",
]

## Onde moram os atores. A lista de arquivos NAO e fixa de proposito: era, e um
## branch sem os cinco inimigos novos reprovava cinco vezes por arquivo ausente,
## sem que ninguem tivesse mudado uma cor. Pior que isso, o inverso tambem valia
## -- inimigo novo que ninguem lembrasse de listar aqui passava sem cobertura
## nenhuma. Varrer o disco resolve os dois lados; o piso abaixo impede a
## varredura vazia virar aprovacao.
const PASTA_INIMIGOS := "res://src/enemies/"
const PASTA_ARMAS := "res://src/weapons/"

## Piso de atores conferidos. Dois inimigos (Rastejante, Vigia) mais a Diretora
## e as duas armas do jogador existem desde a v0.1: abaixo disso a varredura
## achou pouco demais para estar certa.
const MINIMO_ATORES := 6


func nome() -> String:
	return "Texturas"


func executar() -> void:
	_paleta()
	_espelho_do_ator()
	_arquivos()
	_determinismo()
	_tipos_apontam_textura()


## G2 e G3 sobre a PALETA, antes de qualquer pixel: se a lista ja estiver
## errada, nao adianta olhar textura.
func _paleta() -> void:
	var ambiente := Paleta.ambiente()
	var ator := Paleta.ator()
	ok(ambiente.size() >= 8, "a paleta de ambiente tem ao menos os oito neutros (%d cores)" % ambiente.size())
	ok(ator.size() >= 8, "o espelho de ator tem ao menos os oito atores (%d cores)" % ator.size())

	for cor in ambiente:
		ok(
			not Paleta.compete_com_ator(cor),
			"G2: %s e dessaturada ou escura (S=%.2f V=%.2f)" % [cor.to_html(false), cor.s, cor.v]
		)
	for cor in ator:
		ok(
			Paleta.compete_com_ator(cor),
			"G3: ator %s e saturado e claro (S=%.2f V=%.2f)" % [cor.to_html(false), cor.s, cor.v]
		)
		ok(not Paleta.pertence(cor, ambiente), "G3: ator %s nao esta na paleta de ambiente" % cor.to_html(false))

	# N7 e o teto do brilho e tem de continuar sendo: se alguem clarear o
	# neutro mais claro, o teste acima ainda passaria um pouco, e este avisa.
	var n7 := Paleta.neutro(&"N7")
	ok(n7.v <= Paleta.LIMITE_VALOR, "N7 nao passa do teto de valor (V=%.2f)" % n7.v)


## O espelho Paleta.ATOR precisa bater com as cenas e os .tres reais. Nao e a
## fonte deles -- e o que prova que ambiente e ator nao se cruzam, e uma prova
## sobre uma lista desatualizada nao prova nada.
func _espelho_do_ator() -> void:
	var ator := Paleta.ator()
	var conferidos := 0

	for caminho: String in _caminhos_de(PASTA_INIMIGOS, ".tscn"):
		# Nem toda cena de src/enemies/ e um ator: area_de_perigo e afins nao
		# tem cor_base. Ausencia da propriedade e "nao se aplica", nao falha --
		# quem falha e a cor errada de quem TEM a propriedade.
		var cor: Variant = _propriedade_da_raiz(caminho, &"cor_base")
		if cor == null:
			continue
		conferidos += 1
		ok(
			Paleta.pertence(cor, ator),
			"%s: cor_base %s esta no espelho ATOR" % [caminho.get_file(), (cor as Color).to_html(false)]
		)

	for caminho: String in _caminhos_de(PASTA_ARMAS, ".tres"):
		var dados: Resource = load(caminho)
		if dados == null or not "cor_projetil" in dados:
			continue
		conferidos += 1
		var cor: Color = dados.cor_projetil
		ok(
			Paleta.pertence(cor, ator),
			"%s: cor_projetil %s esta no espelho ATOR" % [caminho.get_file(), cor.to_html(false)]
		)

	ok(
		conferidos >= MINIMO_ATORES,
		"a varredura achou os atores (%d encontrados, minimo %d)" % [conferidos, MINIMO_ATORES]
	)


## Caminhos de uma pasta com a extensao pedida, em ordem estavel. Ordenado
## porque relatorio de teste que muda de ordem entre maquinas e ruido no diff.
func _caminhos_de(pasta: String, extensao: String) -> Array[String]:
	var lista: Array[String] = []
	var dir := DirAccess.open(pasta)
	if dir == null:
		ok(false, "%s pode ser aberta" % pasta)
		return lista
	for arquivo in dir.get_files():
		if arquivo.ends_with(extensao):
			lista.append(pasta + arquivo)
	lista.sort()
	return lista


## Le uma propriedade do no raiz direto do PackedScene, sem instanciar: os
## inimigos tem @onready e sinais que nao valem a pena acordar aqui.
func _propriedade_da_raiz(caminho: String, propriedade: StringName) -> Variant:
	var cena: PackedScene = load(caminho)
	if cena == null:
		return null
	var estado := cena.get_state()
	if estado.get_node_count() == 0:
		return null
	for i in estado.get_node_property_count(0):
		if estado.get_node_property_name(0, i) == propriedade:
			return estado.get_node_property_value(0, i)
	return null


func _arquivos() -> void:
	var ambiente := Paleta.ambiente()
	var sinal := Paleta.sinal()
	var de_ambiente := GeradorTexturas.nomes_de_ambiente()
	var conferidos := 0

	for nome in GeradorTexturas.nomes():
		var caminho := "%s/%s" % [PASTA, nome]
		var imagem := _carregar_png(caminho)
		if imagem == null:
			ok(false, "%s existe em disco (rode tools/texturas/gerar_texturas.tscn)" % nome)
			continue
		conferidos += 1

		# Sem excecao: o filete era a unica textura fora da grade (8 px de altura,
		# a largura da linha de neon) e saiu com o neon. Toda textura que restou
		# ladrilha nos dois eixos.
		ok(
			imagem.get_width() % GRADE == 0 and imagem.get_height() % GRADE == 0,
			"%s tem dimensao multipla de %d (%dx%d)" % [nome, GRADE, imagem.get_width(), imagem.get_height()]
		)

		var paleta := ambiente if de_ambiente.has(nome) else sinal
		var portao := "G1" if de_ambiente.has(nome) else "SINAL"
		var fora := 0
		var alpha_parcial := 0
		var opacos := 0
		var exemplo := ""
		for y in imagem.get_height():
			for x in imagem.get_width():
				var cor := imagem.get_pixel(x, y)
				if cor.a > 0.001 and cor.a < 0.999:
					alpha_parcial += 1
					continue
				if cor.a < 0.5:
					continue
				opacos += 1
				if not Paleta.pertence(cor, paleta):
					fora += 1
					if exemplo.is_empty():
						exemplo = "%s em (%d, %d)" % [cor.to_html(false), x, y]
		igual(alpha_parcial, 0, "%s nao tem alpha parcial" % nome)
		ok(opacos > 0, "%s tem ao menos um pixel opaco" % nome)
		igual(fora, 0, "%s: %s -- todo pixel pertence a paleta (primeiro fora: %s)" % [nome, portao, exemplo])

	igual(conferidos, GeradorTexturas.nomes().size(), "todas as texturas do catalogo foram abertas")


## Gerar duas vezes da bytes iguais, e o disco e igual ao gerador de hoje.
func _determinismo() -> void:
	for nome in GeradorTexturas.nomes():
		var a := GeradorTexturas.gerar(nome)
		var b := GeradorTexturas.gerar(nome)
		if a == null or b == null:
			ok(false, "%s: o gerador produz imagem" % nome)
			continue
		ok(_mesmos_bytes(a, b), "%s: gerar duas vezes da os mesmos bytes" % nome)

		var disco := _carregar_png("%s/%s" % [PASTA, nome])
		if disco == null:
			continue
		ok(
			_mesmos_bytes(a, disco),
			"%s: o PNG em disco e o que o gerador produz hoje (gerou e esqueceu de rodar?)" % nome
		)


## Cada tipo de sala declara as tres texturas, e elas carregam -- .import
## faltando volta nulo aqui em vez de virar sala lisa em silencio.
func _tipos_apontam_textura() -> void:
	var conferidos := 0
	for caminho: String in TIPOS:
		var dados: DadosSala = load(caminho)
		var etiqueta := caminho.get_file()
		if dados == null:
			ok(false, "%s carrega" % etiqueta)
			continue
		conferidos += 1
		ok(dados.textura_chao != null, "%s declara textura de chao que carrega" % etiqueta)
		ok(dados.textura_parede != null, "%s declara textura de parede que carrega" % etiqueta)
		if dados.quantidade_props > 0:
			ok(dados.atlas_props != null, "%s pede props e tem atlas" % etiqueta)
			ok(not dados.regioes_props.is_empty(), "%s pede props e lista regioes" % etiqueta)
		if dados.atlas_props != null:
			var caixa := Rect2i(Vector2i.ZERO, Vector2i(dados.atlas_props.get_width(), dados.atlas_props.get_height()))
			for regiao in dados.regioes_props:
				ok(caixa.encloses(regiao), "%s: regiao %s cabe no atlas" % [etiqueta, regiao])
				ok(
					regiao.position.x % GeradorTexturas.TILE == 0 and regiao.position.y % GeradorTexturas.TILE == 0,
					"%s: regiao %s esta na grade do atlas" % [etiqueta, regiao]
				)
	igual(conferidos, TIPOS.size(), "todos os tipos de sala foram conferidos")


func _carregar_png(caminho: String) -> Image:
	if not FileAccess.file_exists(caminho):
		return null
	# Caminho absoluto de proposito: load_from_file com res:// avisa que "nao
	# funciona no export", e aqui e exatamente o PNG fonte que se quer ler.
	var imagem := Image.load_from_file(ProjectSettings.globalize_path(caminho))
	if imagem == null or imagem.is_empty():
		return null
	imagem.convert(Image.FORMAT_RGBA8)
	return imagem


func _mesmos_bytes(a: Image, b: Image) -> bool:
	if a.get_width() != b.get_width() or a.get_height() != b.get_height():
		return false
	var da := a.duplicate() as Image
	var db := b.duplicate() as Image
	da.convert(Image.FORMAT_RGBA8)
	db.convert(Image.FORMAT_RGBA8)
	return da.get_data() == db.get_data()
