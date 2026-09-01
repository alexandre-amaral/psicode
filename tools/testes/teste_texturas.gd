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
	_a_parede_tem_volume()
	_os_modulos_de_face_ficam_na_faixa_da_base()
	_nenhum_png_fica_fora_de_regime()


## Mesmo limiar do `preparar_textura.py`: dois pixels vizinhos contam como
## detalhe quando a soma das diferencas de canal passa disto.
const LIMIAR_DETALHE := 24


## OS MODULOS DE FACE ficam na mesma faixa de densidade da base (AND1 03).
##
## A face e a unica superficie do projeto que EXCEDE a faixa de densidade da
## parede de proposito: o chao fica quase liso (20%) porque e onde o combate e
## lido, e a informacao visual desce para as bordas da sala, onde a face mede
## 55%. Essa razao E a identidade do andar.
##
## Os dois limites nao sao chutados, e nenhum dos dois sai da amostra:
##
## - **Piso: acima do teto da faixa de parede (34%).** Um modulo menos denso que
##   isso e uma parede comum, e perde a identidade que a face carrega.
## - **Teto: 1,4x a base.** Passando disso a borda vira ruido -- e ruido na
##   borda compete com o que o jogador precisa ler no meio.
##
## Sem este portao a regra fica na prosa da issue, e prosa nao sobrevive ao
## proximo modulo desenhado por outra pessoa.
func _os_modulos_de_face_ficam_na_faixa_da_base() -> void:
	var base := _abrir("parede_face.png")
	ok(base != null, "a face base existe -- e a referencia de densidade")
	if base == null:
		return
	var densidade_base := _densidade(base)
	entre(densidade_base, 0.40, 0.70,
		"a base mede o que o style test cravou (%.0f%%)" % (densidade_base * 100.0))

	var teto_parede := 0.34
	var teto := densidade_base * 1.4
	var conferidos := 0
	for arquivo in ["parede_face_combate_tubulacao.png", "parede_face_combate_tecnica.png",
			"parede_face_combate_deteriorada.png", "parede_face_combate_ventilada.png"]:
		var imagem := _abrir(arquivo)
		if imagem == null:
			ok(false, "%s existe" % arquivo)
			continue
		conferidos += 1
		var d := _densidade(imagem)
		ok(d > teto_parede,
			"%s e mais denso que uma parede comum (%.0f%% contra %.0f%%)"
				% [arquivo, d * 100.0, teto_parede * 100.0])
		ok(d <= teto,
			"%s nao vira ruido de borda (%.0f%%, teto %.0f%%)"
				% [arquivo, d * 100.0, teto * 100.0])
	igual(conferidos, 4, "os quatro modulos novos foram conferidos")


## Quantos pixels tem um vizinho diferente. Mesma conta do
## `preparar_textura.py`: e a metrica em que o style test mediu 20% no chao e
## 55% na face, e usar outra aqui daria dois numeros para a mesma pergunta.
func _densidade(imagem: Image) -> float:
	var l := imagem.get_width()
	var a := imagem.get_height()
	var muda := 0
	for y in a:
		for x in l:
			var c := imagem.get_pixel(x, y)
			var d := imagem.get_pixel((x + 1) % l, y)
			var e := imagem.get_pixel(x, (y + 1) % a)
			if _diferenca(c, d) > LIMIAR_DETALHE or _diferenca(c, e) > LIMIAR_DETALHE:
				muda += 1
	return float(muda) / float(maxi(l * a, 1))


func _diferenca(a: Color, b: Color) -> int:
	return int(round((absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) * 255.0))


## O portao da direcao de luz (IDENTIDADE_VISUAL, "Direcao da luz"): a luz vem
## de cima e da esquerda, entao o TOPO da parede e mais claro que a FACE.
##
## Isto e a forma medivel do que vende a altura na perspectiva Low Top-Down. Se
## topo e face tiverem o mesmo valor, a parede volta a ler como faixa chapada --
## exatamente o defeito que a migracao existe para corrigir -- e nada no console
## avisa, porque as duas texturas continuam validas pela paleta.
##
## Mede a MEDIANA e nao a media: a face tem uma faixa de sombra de 8 px na base
## que puxaria a media para baixo por um motivo diferente do que se quer medir.
## Ele varre AS TRES variantes de topo (PAR 04): enquanto o topo era um arquivo
## so, medir "o topo" bastava; com uma lista, uma variante clara e duas escuras
## passariam pela media de ninguem e a parede leria chapada em dois tercos do
## andar. E a lista vem de `Sala.TOPOS_NEUTROS`, que e quem o jogo consome --
## uma copia aqui deixaria de cobrar a variante que alguem acrescentasse la.
func _a_parede_tem_volume() -> void:
	var face := _abrir("parede_face.png")
	if face == null:
		ok(false, "parede_face.png existe em disco")
		return
	igual(face.get_width(), GeradorTexturas.TILE_PAREDE, "a face usa o tile da parede")
	igual(face.get_height(), GeradorTexturas.TILE_PAREDE, "a face e quadrada")

	var v_face := _mediana_de_valor(face)
	var conferidos := 0
	for caminho in Sala.TOPOS_NEUTROS:
		var nome: String = caminho.get_file()
		var topo := _abrir(nome)
		if topo == null:
			continue
		conferidos += 1
		igual(topo.get_width(), GeradorTexturas.TILE_PAREDE, "%s usa o tile da parede" % nome)
		igual(topo.get_height(), GeradorTexturas.TILE_PAREDE, "%s e quadrado" % nome)
		var v_topo := _mediana_de_valor(topo)
		ok(
			v_topo > v_face,
			"%s e mais claro que a face (%.3f contra %.3f) -- e o que vende a altura"
				% [nome, v_topo, v_face]
		)
	igual(conferidos, Sala.TOPOS_NEUTROS.size(), "as tres variantes de topo estao em disco")


func _abrir(nome: String) -> Image:
	var caminho := "%s/%s" % [PASTA, nome]
	if not ResourceLoader.exists(caminho):
		return null
	var textura: Texture2D = load(caminho)
	if textura == null:
		return null
	return textura.get_image()


func _mediana_de_valor(imagem: Image) -> float:
	var valores: Array[float] = []
	for y in imagem.get_height():
		for x in imagem.get_width():
			var cor := imagem.get_pixel(x, y)
			if cor.a < 0.5:
				continue
			valores.append(cor.v)
	if valores.is_empty():
		return 0.0
	valores.sort()
	return valores[valores.size() / 2]


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


## Texturas AUTORADAS: arte preparada por tools/texturas/preparar_textura.py.
##
## Elas nao tem gerador, entao nao ha determinismo a cobrar -- o PNG nao e
## consequencia de codigo nenhum. O que as tranca sao propriedades medidas sobre
## o proprio arquivo: gamut, teto de valor, faixa de matiz e costura.
const AUTORADAS: Dictionary = {
	"chao_andar1_a.png": {&"familia": &"chao", &"tipo": &"andar1"},
	"chao_andar1_b.png": {&"familia": &"chao", &"tipo": &"andar1"},
	"chao_andar1_c.png": {&"familia": &"chao", &"tipo": &"andar1"},
	"chao_boss.png": {&"familia": &"chao", &"tipo": &"boss"},
	"chao_arma.png": {&"familia": &"chao", &"tipo": &"arma"},
	"chao_item.png": {&"familia": &"chao", &"tipo": &"item"},
	# O atlas VOLUMETRICO (LTD 09). O chapado (`props_atlas.png`) continua
	# GERADO e trancado pelo determinismo -- sao dois arquivos justamente
	# para cada um ficar no regime que sabe provar o que ele e.
	"props_volume.png": {&"familia": &"prop", &"tipo": &"andar1"},
	# As FACES da parede, autoradas na identidade industrial do andar 1. Elas
	# sao a superficie que carrega a identidade do setor: o chao fica quase
	# liso porque e onde o combate e lido, e a informacao visual desce para as
	# bordas da sala. O TOPO (`parede_topo.png`) continua gerado.
	#
	# `parede_face.png` e a NEUTRA -- o modulo "simples", usado como fallback
	# pela sala sem DadosSala. As cinco seguintes sao a mesma estrutura
	# industrial tingida na rampa de cada tipo (LTD 13): mesma arquitetura,
	# acento diferente. As duas coisas sao ortogonais de proposito -- a
	# estrutura diz "e o mesmo setor", o acento diz "e outra sala".
	#
	# Combate e inicial declaram tipo `andar1` porque e a faixa que o portao
	# cobra deles; o que os separa e o matiz DENTRO da faixa (ciano contra
	# cinza-azulado), nao a faixa.
	# O TOPO neutro, em tres variantes sorteadas por celula como o chao (PAR 03).
	# Elas NAO tem tipo proprio: a identidade da sala mora na face desde a #43, e
	# o topo e a superficie que todo tipo compartilha. Autoradas de origem GRANDE
	# e reduzidas pelo funil -- gerar direto em 64 enche cada pixel de detalhe e
	# a densidade sai no dobro da faixa.
	"parede_topo_a.png": {&"familia": &"parede", &"tipo": &"andar1"},
	"parede_topo_b.png": {&"familia": &"parede", &"tipo": &"andar1"},
	"parede_topo_c.png": {&"familia": &"parede", &"tipo": &"andar1"},
	"parede_face.png": {&"familia": &"parede", &"tipo": &"andar1"},
	"parede_face_combate.png": {&"familia": &"parede", &"tipo": &"andar1"},
	"parede_face_inicial.png": {&"familia": &"parede", &"tipo": &"andar1"},
	"parede_face_boss.png": {&"familia": &"parede", &"tipo": &"boss"},
	"parede_face_arma.png": {&"familia": &"parede", &"tipo": &"arma"},
	"parede_face_item.png": {&"familia": &"parede", &"tipo": &"item"},
	# Os quatro MODULOS de combate (AND1 03). Eles ficaram FORA desta lista
	# desde que nasceram, e por isso passavam so pelo portao de densidade --
	# nao por gamut, teto de valor, faixa de matiz, grade, alfa nem costura.
	# Metade da superficie de parede do andar estava sem medicao enquanto a
	# outra metade era cobrada. A contagem de `AUTORADAS` nao acusa ausencia:
	# ela confere o que esta na lista contra o que foi conferido, entao um
	# arquivo que nunca entrou simplesmente some.
	"parede_face_combate_tubulacao.png": {&"familia": &"parede", &"tipo": &"andar1"},
	"parede_face_combate_tecnica.png": {&"familia": &"parede", &"tipo": &"andar1"},
	"parede_face_combate_deteriorada.png": {&"familia": &"parede", &"tipo": &"andar1"},
	"parede_face_combate_ventilada.png": {&"familia": &"parede", &"tipo": &"andar1"},
	# A MOLDURA da porta (LTD 11). Familia `prop` e nao `parede`: ela serve
	# todos os tipos de sala, entao nao pode ter faixa de matiz -- amarra-la a
	# uma pintaria a mesma porta de vermelho no chefe e de ambar na sala de arma.
	# O CAMPO continua gerado: ele e SINAL e tem lista de cor propria.
	"porta_moldura.png": {&"familia": &"prop", &"tipo": &"andar1"},
	"props_frente.png": {&"familia": &"prop", &"tipo": &"andar1"},
	# A BAIA do chefe (AND1 07): a marca de chao sob o ponto de partida dele.
	# Familia `decalque` -- ela e chapada e o jogador anda por cima --, tipo
	# `boss` porque a faixa dela e a da sala do chefe. Ela tambem estava fora
	# de regime nenhum, e foi a varredura de orfaos que a achou.
	"baia_chefe.png": {&"familia": &"decalque", &"tipo": &"boss"},
}

## Todo PNG de `assets/texturas/` esta num REGIME -- gerado ou autorado.
##
## Este caso existe porque o cabecalho desta suite ja avisava do defeito e nao o
## cobrava: "uma lista fixa aqui teria o mesmo defeito que a `AUTORADAS` do teste
## de texturas ja tem -- arquivo fora dela nao e conferido por nada, e ninguem
## descobre". Era exatamente o que estava acontecendo.
##
## O que a contagem existente NAO pega: `igual(autoradas, AUTORADAS.size())`
## confere o que esta na lista contra o que foi conferido. Um arquivo que nunca
## entrou na lista nao aparece nos dois lados -- ele SOME, e a suite fica verde.
##
## Achados por esta varredura quando ela foi escrita: os quatro modulos de face
## de combate (AND1 03) e a `baia_chefe.png` (AND1 07). Cinco arquivos, tres
## ondas de arte, nenhum erro no console -- e os cinco passaram assim que foram
## conferidos, que e o pior caso: o portao nao estava barrando arte ruim, estava
## deixando arte boa passar sem prova, e a proxima podia nao ser boa.
func _nenhum_png_fica_fora_de_regime() -> void:
	var pasta := DirAccess.open(PASTA)
	if pasta == null:
		ok(false, "assets/texturas/ pode ser aberta")
		return
	var gerados := GeradorTexturas.nomes()
	var orfaos: Array[String] = []
	var vistos := 0
	for arquivo in pasta.get_files():
		if not arquivo.ends_with(".png"):
			continue
		vistos += 1
		if AUTORADAS.has(arquivo) or gerados.has(arquivo):
			continue
		orfaos.append(arquivo)

	ok(vistos >= AUTORADAS.size(), "a varredura achou os PNGs em disco (%d)" % vistos)
	igual(
		orfaos.size(), 0,
		"nenhum PNG fica fora de regime -- gerado ou autorado (%s)" % [orfaos]
	)


## A faixa de matiz e do TIPO DE SALA, e e ela que faz a sala do chefe se
## anunciar de longe sem o andar deixar de ser um lugar so. Sai das rampas
## ACENTOS de paleta.gd, rebaixadas.
##
## O corredor nao tem faixa propria de proposito: ele fica na noite base, porque
## pintar cada metade com a cor da sala vizinha anunciaria o que ha do outro lado
## antes de o jogador chegar.
##
## A faixa do ANDAR 1 e larga -- 135 graus contra os 25 a 30 das outras -- e e
## deliberado. Ela separa TIPO DE SALA, e nao mapa de ator: quem faz a segunda
## separacao e o teto de valor (chao em 0,30 contra o piso de 0,55 do portao
## G2), porque o andar 1 ja abriu mao do matiz ao ir para o azul, que e a
## familia de seis projeteis do jogo. Alargar veio da arte do piso, que traz
## acento ciano (~180) e magenta (~320); como o teto de valor nao mudou, isso
## nao aproxima o chao de projetil nenhum. 185 fica 5 graus acima do teto do
## item e 320 fica 10 abaixo do piso do chefe -- as tres faixas seguem disjuntas.
##
## Este dicionario e GEMEO do MATIZ_POR_TIPO de preparar_textura.py, e os dois
## tem de mudar juntos: mexer num so deixa o funil escrevendo o que o portao
## recusa.
## Familias que NAO tem faixa de matiz por tipo de sala.
##
## Existe UM atlas de props volumetricos para o jogo inteiro, oferecido a todos
## os tipos. Amarra-lo a faixa de um tipo pintaria a mesma caixa de vermelho na
## sala do chefe e de ambar na sala de arma, no mesmo andar. Quem carrega a
## identidade do tipo e o atlas CHAPADO, que tem uma celula por tipo para isso.
##
## Gemeo de SEM_FAIXA_DE_MATIZ em preparar_textura.py, e muda junto.
const SEM_FAIXA_DE_MATIZ: Array[StringName] = [&"prop"]

const MATIZ_POR_TIPO: Dictionary = {
	&"andar1": Vector2(185.0, 320.0),
	&"boss": Vector2(330.0, 355.0),
	&"arma": Vector2(25.0, 50.0),
	&"item": Vector2(150.0, 180.0),
}

## Teto de valor mais baixo no chao do chefe, e nao e capricho: e a sala mais
## densa de projetil do jogo, e o matiz dela e vizinho do `tiro_diretora` (336
## graus). Como o andar 1 abriu mao da separacao por matiz, sobrou o valor -- e
## no lugar onde ele mais importa vale compra-lo mais folgado.
const TETO_ESPECIAL: Dictionary = {
	&"boss": {&"chao": 0.24},
}

## Teto de valor por familia. O do chao e o mais apertado e e o que sustenta a
## leitura de combate: como o andar 1 foi para o azul -- a familia de seis
## projeteis do jogo -- o matiz parou de separar mapa de ator, e sobrou o valor.
## Ator tem piso de V 0,55 no portao G2; 0,30 no chao garante 0,25 de folga.
const TETO_VALOR: Dictionary = {
	&"chao": 0.30,
	&"parede": 0.50,
	## O prop volumetrico fica ENTRE os dois, e nao e meio-termo preguicoso: ele
	## precisa ler como corpo -- senao a face vertical que a LTD 09 pede nao
	## aparece -- mas vive no miolo por onde o combate passa, entao nao chega aos
	## 0,50 da parede, que e moldura e fica na beira do quadro.
	&"prop": 0.42,
	## O DECALQUE e o mais escuro dos quatro, e o numero vem do funil
	## (`FAMILIAS` de preparar_textura.py). Ele fica embaixo do prop de
	## proposito: prop vive na margem calma e pode ter volume, decalque e
	## chapado e vive ONDE O COMBATE ACONTECE -- o jogador anda por cima dele.
	## Faltava aqui, entao a `baia_chefe.png` era medida contra o default de
	## 0,55: quase tres vezes o teto que o funil aplicou ao escreve-la.
	&"decalque": 0.19,
}

## Abaixo deste valor o matiz de um pixel de 8 bits e ruido de arredondamento --
## os canais estao na casa de 0..15 e um passo de 1/255 gira o matiz dezenas de
## graus. Medir ali e medir o 8 bits, nao a cor.
const PISO_MATIZ_LEGIVEL := 0.06

## Teto da razao de costura. Calibrado em tres regimes e validado contra
## gabarito: textura gerada com `posmod` -- seamless por construcao -- mede
## 0,14 a 0,42, arte costurada mede ate 0,95, e arte crua que nao ladrilha
## passa de 1,4.
const TETO_COSTURA := 1.10


func _arquivos() -> void:
	var ambiente := Paleta.ambiente()
	var sinal := Paleta.sinal()
	var de_ambiente := GeradorTexturas.nomes_de_ambiente()
	var conferidos := 0

	# Regime GERADO: o pixel nasce da paleta porque o gerador so sabe escrever a
	# paleta, entao a pertinencia continua sendo cobrada como lista.
	for nome in GeradorTexturas.nomes():
		var caminho := "%s/%s" % [PASTA, nome]
		var imagem := _carregar_png(caminho)
		if imagem == null:
			ok(false, "%s existe em disco (rode tools/texturas/gerar_texturas.tscn)" % nome)
			continue
		conferidos += 1
		_grade(imagem, nome)
		var paleta := ambiente if de_ambiente.has(nome) else sinal
		var portao := "G1" if de_ambiente.has(nome) else "SINAL"
		_pertence_a_lista(imagem, nome, paleta, portao)

	igual(conferidos, GeradorTexturas.nomes().size(), "todas as texturas geradas foram abertas")

	# Regime AUTORADO: nao ha lista a que pertencer, ha regra a obedecer.
	var autoradas := 0
	for nome in AUTORADAS:
		var imagem := _carregar_png("%s/%s" % [PASTA, nome])
		if imagem == null:
			ok(false, "%s existe em disco (rode preparar_textura.py)" % nome)
			continue
		autoradas += 1
		_grade(imagem, nome)
		var d: Dictionary = AUTORADAS[nome]
		_regra_de_gamut(imagem, nome, d[&"familia"], d[&"tipo"])
		# Atlas nao ladrilha: ele e uma grade de CELULAS, e a borda direita dele
		# nao encosta na esquerda em lugar nenhum. Medir costura ali cobraria
		# continuidade entre dois props que nunca se tocam.
		if d[&"familia"] != &"prop":
			_costura(imagem, nome)

	igual(autoradas, AUTORADAS.size(), "todas as texturas autoradas foram abertas")


func _grade(imagem: Image, nome: String) -> void:
	ok(
		imagem.get_width() % GRADE == 0 and imagem.get_height() % GRADE == 0,
		"%s tem dimensao multipla de %d (%dx%d)" % [nome, GRADE, imagem.get_width(), imagem.get_height()]
	)


func _pertence_a_lista(imagem: Image, nome: String, paleta: Array[Color], portao: String) -> void:
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


## G1 como REGRA, e nao como lista.
##
## Com arte autorada a lista de 22 cores deixou de servir: ela proibia gradiente,
## dithering e sombra, que e exatamente o que tira a textura do chapado. O que
## importava na lista nunca foi a lista -- era garantir que nada do cenario
## compete com um ator. Isso e mensuravel direto, e de quebra pega coisa que a
## lista deixava passar: um cinza dessaturado em V 0,90 pertencia ao gamut
## AMBIENTE e destruia a noite.
func _regra_de_gamut(imagem: Image, nome: String, familia: StringName, tipo: StringName) -> void:
	var teto: float = TETO_ESPECIAL.get(tipo, {}).get(familia, TETO_VALOR.get(familia, 0.55))
	var faixa: Vector2 = MATIZ_POR_TIPO.get(tipo, Vector2(0.0, 360.0))
	var compete := 0
	var acima := 0
	var alpha_parcial := 0
	var opacos := 0
	var matiz_min := 999.0
	var matiz_max := -1.0
	var pior := ""
	for y in imagem.get_height():
		for x in imagem.get_width():
			var cor := imagem.get_pixel(x, y)
			if cor.a > 0.001 and cor.a < 0.999:
				alpha_parcial += 1
				continue
			if cor.a < 0.5:
				continue
			opacos += 1
			if Paleta.compete_com_ator(cor):
				compete += 1
			if cor.v > teto + 0.004:
				acima += 1
				if pior.is_empty():
					pior = "%s (V %.3f) em (%d, %d)" % [cor.to_html(false), cor.v, x, y]
			if cor.s > 0.05 and cor.v > PISO_MATIZ_LEGIVEL:
				matiz_min = minf(matiz_min, cor.h * 360.0)
				matiz_max = maxf(matiz_max, cor.h * 360.0)

	igual(alpha_parcial, 0, "%s nao tem alpha parcial" % nome)
	ok(opacos > 0, "%s tem ao menos um pixel opaco" % nome)
	igual(compete, 0, "%s: G1 -- nenhum pixel compete com ator" % nome)
	igual(acima, 0, "%s: nenhum pixel acima do teto de valor %.2f (%s)" % [nome, teto, pior])
	if matiz_max >= 0.0 and not SEM_FAIXA_DE_MATIZ.has(familia):
		ok(
			matiz_min >= faixa.x - 1.0 and matiz_max <= faixa.y + 1.0,
			"%s: matiz na faixa %.0f-%.0f do tipo '%s' (achado %.0f-%.0f)"
				% [nome, faixa.x, faixa.y, tipo, matiz_min, matiz_max]
		)


## A junta do ladrilho nao pode criar uma borda mais forte do que qualquer borda
## que a textura ja tenha.
##
## Substitui, para arte autorada, o que o determinismo provava de graca: o
## gerador fazia `posmod` em toda escrita, entao ladrilhar era consequencia do
## codigo. Sem gerador, ladrilhar vira propriedade a medir.
func _costura(imagem: Image, nome: String) -> void:
	var w := imagem.get_width()
	var h := imagem.get_height()
	if w < 4 or h < 4:
		return

	var junta_x := _energia_colunas(imagem, w - 1, 0)
	var junta_y := _energia_linhas(imagem, h - 1, 0)
	var maior_x := 0.0
	var maior_y := 0.0
	for i in w - 1:
		maior_x = maxf(maior_x, _energia_colunas(imagem, i, i + 1))
	for i in h - 1:
		maior_y = maxf(maior_y, _energia_linhas(imagem, i, i + 1))

	var rx := junta_x / maxf(maior_x, 1.0 / 255.0)
	var ry := junta_y / maxf(maior_y, 1.0 / 255.0)
	ok(
		rx <= TETO_COSTURA and ry <= TETO_COSTURA,
		"%s ladrilha sem costura (x %.2f, y %.2f, teto %.2f)" % [nome, rx, ry, TETO_COSTURA]
	)


func _energia_colunas(imagem: Image, a: int, b: int) -> float:
	var soma := 0.0
	for y in imagem.get_height():
		var u := imagem.get_pixel(a, y)
		var v := imagem.get_pixel(b, y)
		soma += absf(u.r - v.r) + absf(u.g - v.g) + absf(u.b - v.b)
	return soma / float(imagem.get_height())


func _energia_linhas(imagem: Image, a: int, b: int) -> float:
	var soma := 0.0
	for x in imagem.get_width():
		var u := imagem.get_pixel(x, a)
		var v := imagem.get_pixel(x, b)
		soma += absf(u.r - v.r) + absf(u.g - v.g) + absf(u.b - v.b)
	return soma / float(imagem.get_width())


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
		ok(not dados.texturas_chao.is_empty(), "%s declara ao menos uma textura de chao" % etiqueta)
		# O TOPO nao e mais declarado por tipo (PAR 04): ele e neutro e vem de
		# `Sala.TOPOS_NEUTROS`. Cobrar `texturas_parede` aqui manteria de pe um
		# campo que ja nao existe.
		# A FACE e a superficie que carrega a identidade do tipo (LTD 13). Lista
		# vazia nao quebra nada -- a sala cai na face neutra -- e e exatamente
		# por isso que precisa de portao: o sintoma de esquecer de declarar e o
		# andar inteiro ficar com a mesma parede, sem uma linha no console.
		ok(not dados.texturas_face.is_empty(), "%s declara ao menos uma face de parede" % etiqueta)
		for t in dados.texturas_face:
			ok(t != null, "%s: nenhuma entrada nula na lista de face" % etiqueta)
		for t in dados.texturas_chao:
			ok(t != null, "%s: nenhuma entrada nula na lista de chao" % etiqueta)
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

		# O atlas VOLUMETRICO (LTD 09) tem as mesmas duas travas, e uma terceira
		# que so vale para ele: a ALTURA da celula entra na conta da origem.
		# `Sala._montar_props_volumetricos` desloca o sprite em `-altura/2` para
		# por a base do prop na origem do no, e essa conta so fecha se a arte
		# estiver ancorada no fundo da celula. Regiao de altura errada nao da
		# erro nenhum -- o prop so flutua, ou afunda no chao.
		if dados.quantidade_props_volume > 0:
			ok(dados.atlas_props_volume != null,
				"%s pede prop volumetrico e tem atlas" % etiqueta)
			ok(not dados.regioes_props_volume.is_empty(),
				"%s pede prop volumetrico e lista regioes" % etiqueta)
		if dados.atlas_props_volume != null:
			var caixa_v := Rect2i(Vector2i.ZERO, Vector2i(
				dados.atlas_props_volume.get_width(), dados.atlas_props_volume.get_height()))
			for regiao in dados.regioes_props_volume:
				ok(caixa_v.encloses(regiao),
					"%s: regiao volumetrica %s cabe no atlas" % [etiqueta, regiao])
				ok(
					regiao.position.x % GeradorTexturas.TILE == 0 and regiao.position.y % GeradorTexturas.TILE == 0,
					"%s: regiao volumetrica %s esta na grade" % [etiqueta, regiao]
				)
				ok(
					regiao.size.y > regiao.size.x or regiao.size.y == regiao.size.x,
					"%s: regiao volumetrica %s nao e mais larga que alta -- prop com volume sobe, nao deita" % [etiqueta, regiao]
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
