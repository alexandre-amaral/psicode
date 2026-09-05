extends TesteBase
## A SALA E UMA CAVIDADE: a sequencia de valor que produz profundidade.
##
## Esta suite existe porque a sala parava de ler como sala. A geometria estava
## certa -- topo, face, sombra de contato, vazio exterior, faixa continua, tudo
## entregue pelos epicos PAREDE, TOPO e MOLDURA --, e mesmo assim a tela lia como
## **uma grande superficie de placas** com uma borda em volta.
##
## Medido, o motivo nao era a geometria: era a DISTANCIA DE VALOR.
##
##     topo    0,161      passo topo -> face    0,020
##     face    0,141      passo face -> piso    0,020
##     piso    0,122      passo piso -> sombra  0,027
##     sombra  0,095
##
## A ordem estava correta. O que nao existia era separacao: a arquitetura inteira
## cabia em **17 niveis de 255**. Quatro superficies com o mesmo valor sao uma
## superficie so, por mais que a geometria diga que sao quatro -- e nenhum portao
## do projeto olhava isso, porque `teste_texturas.gd` mede cada familia contra o
## proprio teto e nunca uma contra a outra.
##
## O que esta suite cobra e a RELACAO. `docs/LOW_TOPDOWN_SQUARED.md` cuida da
## perspectiva e `teste_texturas.gd` cuida do gamut; aqui a pergunta e a do §48
## do plano: **o piso parece estar dentro de uma caixa?**


const TEXTURAS := "res://assets/texturas/"

## As tres familias que formam a sequencia, e os arquivos que as representam.
##
## Sao os arquivos NEUTROS de cada uma: a variacao por tipo de sala muda o matiz
## e nao o valor, e e o valor que esta em jogo aqui.
const CHAO: Array[String] = ["chao_andar1_a", "chao_andar1_b", "chao_andar1_c"]
const TOPO: Array[String] = ["parede_topo_a", "parede_topo_b", "parede_topo_c"]
const FACE: Array[String] = ["parede_face", "parede_face_combate"]

## O passo minimo de valor entre duas superficies vizinhas.
##
## Ele nao e escolhido: sai da propria rampa de neutros da `Paleta`. Os degraus
## dela vao de 0,04 a 0,09 de distancia -- N1->N2 e 0,036, N4->N5 e 0,071 --, e
## um passo abaixo do MENOR degrau da rampa e uma diferenca que a propria paleta
## nao considera uma cor nova.
##
## Medido antes deste portao: os tres passos valiam 0,020, 0,020 e 0,027. Todos
## abaixo do menor degrau, e e por isso que a sala lia como uma superficie so.
const PASSO_MINIMO := 0.036

## A razao de detalhe entre piso e parede, do §60 do plano: "se a parede usa 100%
## de detalhe, o piso deve usar aproximadamente 25-40% dessa densidade".
##
## Medido antes deste portao: 21,8% de piso contra ~51,5% de parede = 42%, acima
## do teto. Hoje o piso do andar 1 fica em ~15% = 29%.
const TETO_DA_RAZAO := 0.40
const PISO_DA_RAZAO := 0.15

## Detalhe: dois pixels vizinhos contam como mudanca quando a soma das
## diferencas de canal passa disto. Gemeo de `teste_texturas.LIMIAR_DETALHE` e do
## `LIMIAR_DETALHE` de `preparar_textura.py`.
const LIMIAR_DETALHE := 24

## Quanto a sombra tem de escurecer o chao, em fracao do valor dele.
const FRACAO_MINIMA_DA_SOMBRA := 0.20

## Quanto a sombra escurece o que esta sob ela, no trecho mais perto da parede.
## Espelha `SombraDeParede.ALFA_PERTO`, e muda junto com ele.
const ALFA_SOMBRA := 0.34


func nome() -> String:
	return "Profundidade da sala"


func executar() -> void:
	_a_sequencia_de_valor_esta_na_ordem()
	_e_os_passos_sao_grandes_o_bastante_para_serem_vistos()
	_a_arquitetura_nao_cabe_num_punhado_de_niveis()
	_o_piso_e_a_superficie_mais_calma_da_sala()
	_a_face_le_como_superficie_VERTICAL()
	_o_chao_e_a_face_nao_falam_a_mesma_lingua()
	_o_vazio_alem_da_sala_e_declarado()


## O exterior e uma DECISAO da sala, e nao um ajuste de viewport.
##
## O §5 do plano pede a camada de vazio atras de toda a arquitetura -- sem ela a
## parede perde profundidade, porque some o contraste entre mundo jogavel,
## arquitetura e nada. Ela ja existia, e por acidente feliz: o
## `default_clear_color` e o N0 da paleta.
##
## O risco de deixar assim e que ninguem lendo `src/mapa/` descobre que ha um
## exterior, e nada impede a proxima pessoa de mudar aquela linha por um motivo
## que nada tem a ver com sala -- um menu, uma transicao -- e apagar a moldura
## inteira sem tocar num arquivo de mapa.
##
## O portao e barato e e o que transforma o acidente em decisao: as duas pontas
## tem de continuar dizendo a mesma cor, e ela tem de ser o N0.
func _o_vazio_alem_da_sala_e_declarado() -> void:
	var do_render: Color = ProjectSettings.get_setting(
		"rendering/environment/defaults/default_clear_color", Color.BLACK)
	ok(
		Paleta.mesma_cor(do_render, Sala.COR_DO_VAZIO),
		"o clear color e o vazio declarado pela Sala (%s contra %s)"
			% [do_render.to_html(false), Sala.COR_DO_VAZIO.to_html(false)]
	)
	ok(
		Paleta.mesma_cor(Sala.COR_DO_VAZIO, Paleta.neutro(&"N0")),
		"e o vazio e o N0 da paleta -- o mais escuro que o jogo tem"
	)
	# E ele e mais escuro que a sombra de contato, senao a sombra desenharia mais
	# clara que o nada e a parede pareceria flutuar sobre o exterior.
	ok(
		Sala.COR_DO_VAZIO.v <= _sombra_sobre(_valor(CHAO)) + 0.001,
		"e ele nao e mais claro que a sombra (%.3f contra %.3f)"
			% [Sala.COR_DO_VAZIO.v, _sombra_sobre(_valor(CHAO))]
	)


## O piso e a area visualmente MAIS CALMA da sala.
##
## E a segunda metade do defeito. A primeira era o valor -- quatro superficies na
## mesma tinta --, e esta e a densidade: o piso tinha placa com borda clara e
## rebite a cada ~64 px, e era a coisa mais barulhenta do quadro. Uma moldura
## calma em volta de um piso que grita nao le como moldura; le como mosaico com
## uma borda.
##
## O numero e do §60 do plano: se a parede usa 100% de detalhe, o piso usa 25-40%
## disso. Ele e uma RAZAO e nao um teto solto, e essa e a diferenca que importa:
## `teste_texturas.gd` ja mede cada familia contra a propria faixa e passaria com
## as duas no teto, que e um piso tao denso quanto a parede.
##
## O piso do CHEFE, da ARMA e do ITEM ficam fora da conta de propOsito: eles ja
## nasceram abaixo da faixa (5,2% e 5,7% medidos) -- sao calmos por natureza, e
## cobrar deles uma razao contra a parede so os empurraria para chapados.
func _o_piso_e_a_superficie_mais_calma_da_sala() -> void:
	var piso := _densidade_de(CHAO)
	var parede := _densidade_de(TOPO + FACE)
	if piso < 0.0 or parede < 0.0:
		ok(false, "as texturas carregam para medir densidade")
		return
	var razao := piso / maxf(parede, 0.0001)
	ok(
		razao <= TETO_DA_RAZAO,
		"o piso usa %.0f%% do detalhe da parede (teto %.0f%%) -- piso %.1f%%, parede %.1f%%"
			% [razao * 100.0, TETO_DA_RAZAO * 100.0, piso * 100.0, parede * 100.0]
	)
	# E o outro lado: piso chapado tambem reprova. Um chao sem nenhum detalhe
	# deixa de ler como material, e a cavidade vira um buraco de cor.
	ok(
		razao >= PISO_DA_RAZAO,
		"e ele nao fica CHAPADO (%.0f%%, minimo %.0f%%)"
			% [razao * 100.0, PISO_DA_RAZAO * 100.0]
	)


## topo > face > piso > sombra.
##
## A ordem E a profundidade: o topo pega a luz porque olha para cima, a face
## recebe de esguelha, o piso esta no fundo da cavidade e a sombra e o contato.
## Trocar duas delas nao da erro nenhum -- so faz a parede afundar ou o chao
## flutuar.
func _a_sequencia_de_valor_esta_na_ordem() -> void:
	var topo := _valor(TOPO)
	var face := _valor(FACE)
	var piso := _valor(CHAO)
	var sombra := _sombra_sobre(piso)
	if topo < 0.0 or face < 0.0 or piso < 0.0:
		ok(false, "as texturas das tres familias carregam")
		return

	ok(topo > face, "o topo e mais claro que a face (%.3f > %.3f)" % [topo, face])
	ok(face > piso, "a face e mais clara que o piso (%.3f > %.3f)" % [face, piso])
	ok(piso > sombra, "o piso e mais claro que a sombra (%.3f > %.3f)" % [piso, sombra])


## E os passos sao grandes o bastante para serem VISTOS.
##
## A ordem sozinha nao prova nada: quatro superficies a 0,02 de distancia estao
## na ordem certa e leem como uma so. Este e o caso que reprovava o estado que
## abriu o epico, e ele reprovava nos TRES passos.
##
## O piso e o unico que ja estava certo -- o problema era o topo, escuro pela
## metade do que o §34 pede (N5/N6 = 0,30 a 0,39).
func _e_os_passos_sao_grandes_o_bastante_para_serem_vistos() -> void:
	var topo := _valor(TOPO)
	var face := _valor(FACE)
	var piso := _valor(CHAO)
	var sombra := _sombra_sobre(piso)

	_passo("topo -> face", topo, face)
	_passo("face -> piso", face, piso)

	# A SOMBRA E MEDIDA EM FRACAO, e nao no mesmo passo absoluto.
	#
	# Ela nao e material: e N0 com alfa por cima do que estiver embaixo, e o alfa
	# tem teto proprio (`SombraDeParede.ALFA_MAXIMO`, 0,40) que existe para ela
	# nao invadir a leitura de combate -- a area dela ja e cobrada abaixo de 6% do
	# chao. Cobrar dela o mesmo passo absoluto das superficies seria pedir que ela
	# estourasse esse teto, ou seja, que uma trava quebrasse a outra.
	#
	# O que se cobra e o que ela promete: escurecer o chao de forma perceptivel no
	# ponto de contato. Um quinto e o degrau relativo que a rampa de neutros usa
	# entre vizinhos na faixa escura.
	var queda := (piso - sombra) / maxf(piso, 0.001)
	ok(
		queda >= FRACAO_MINIMA_DA_SOMBRA,
		"piso -> sombra: a sombra escurece o chao em %.0f%% (minimo %.0f%%)"
			% [queda * 100.0, FRACAO_MINIMA_DA_SOMBRA * 100.0]
	)


## A arquitetura inteira nao pode caber num punhado de niveis.
##
## O caso acima cobra vizinho contra vizinho; este cobra a AMPLITUDE. Tres passos
## de exatamente `PASSO_MINIMO` passariam ali e ainda deixariam a sala num vao de
## 0,11 -- pouco mais do que os 0,066 que ela ocupava quando o epico abriu.
##
## O teto do chao e 0,30 e o da parede e 0,50 (`teste_texturas.TETO_VALOR`), o que
## deixa a rampa inteira disponivel. Nao usar essa folga e desenhar quatro
## superficies com a mesma tinta.
func _a_arquitetura_nao_cabe_num_punhado_de_niveis() -> void:
	var topo := _valor(TOPO)
	var piso := _valor(CHAO)
	var vao := topo - _sombra_sobre(piso)
	ok(
		vao >= PASSO_MINIMO * 3.0,
		"do topo a sombra ha amplitude de verdade (%.3f, piso %.3f)"
			% [vao, PASSO_MINIMO * 3.0]
	)


# -- helpers ----------------------------------------------------------------


func _passo(rotulo: String, de: float, para: float) -> void:
	var passo := de - para
	ok(
		passo >= PASSO_MINIMO,
		"%s: passo de %.3f, e o minimo e %.3f (o menor degrau da rampa de neutros)"
			% [rotulo, passo, PASSO_MINIMO]
	)


## O valor MEDIANO das texturas de uma familia.
##
## Mediana e nao media: um rebite claro isolado ou uma junta escura nao podem
## mover a superficie inteira, e e justamente disso que estas texturas sao feitas.
func _valor(familia: Array[String]) -> float:
	var todos: Array[float] = []
	for nome_arquivo in familia:
		var imagem := _abrir(TEXTURAS + nome_arquivo + ".png")
		if imagem == null:
			continue
		for y in imagem.get_height():
			for x in imagem.get_width():
				var cor := imagem.get_pixel(x, y)
				if cor.a < 0.5:
					continue
				todos.append(cor.v)
	if todos.is_empty():
		return -1.0
	todos.sort()
	return todos[todos.size() / 2]


## O valor do piso depois de a sombra passar por cima dele.
##
## A sombra nao tem textura propria: ela e N0 com alfa sobre o que estiver
## embaixo. Medi-la isolada mediria a cor do recurso, e nao o que o jogador ve.
func _sombra_sobre(piso: float) -> float:
	var n0 := Color("05060b").v
	return piso * (1.0 - ALFA_SOMBRA) + n0 * ALFA_SOMBRA


## A densidade MEDIANA de uma familia: fracao de pixels que diferem de um vizinho.
func _densidade_de(familia: Array[String]) -> float:
	var todas: Array[float] = []
	for nome_arquivo in familia:
		var imagem := _abrir(TEXTURAS + nome_arquivo + ".png")
		if imagem == null:
			continue
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
		todas.append(float(muda) / float(maxi(l * a, 1)))
	if todas.is_empty():
		return -1.0
	todas.sort()
	return todas[todas.size() / 2]


func _diferenca(a: Color, b: Color) -> int:
	return (
		absi(int(round(a.r * 255.0)) - int(round(b.r * 255.0)))
		+ absi(int(round(a.g * 255.0)) - int(round(b.g * 255.0)))
		+ absi(int(round(a.b * 255.0)) - int(round(b.b * 255.0)))
	)


func _abrir(caminho: String) -> Image:
	if not FileAccess.file_exists(caminho):
		return null
	var imagem := Image.load_from_file(ProjectSettings.globalize_path(caminho))
	if imagem == null or imagem.is_empty():
		return null
	imagem.convert(Image.FORMAT_RGBA8)
	return imagem


## Quanto o gradiente de uma superficie tem de puxar para o eixo VERTICAL.
##
## A conta e a energia de gradiente em cada eixo, normalizada:
##
##     orientacao = (energia_x - energia_y) / (energia_x + energia_y)
##
## `energia_x` e a media de |I(x+1,y) - I(x,y)|, produzida por arestas VERTICAIS
## -- andar em x atravessa uma coluna, um duto, uma nervura. `energia_y` e a irma,
## produzida por arestas horizontais. Positivo = a superficie le como vertical;
## negativo = horizontal. E metrica sobre a imagem, invariante a exposicao, da
## mesma familia da faixa dinamica.
##
## **O numero nao e palpite: a propria biblioteca o ancora nos dois lados.** O
## modulo `ventilada` mede -0,70 -- ele E comprometido com um eixo, so que com o
## errado --, entao o estilo alcanca 0,7 de compromisso sem esforco. E os modulos
## que nao se comprometem com nada formam um aglomerado em |0,03|, que e o ruido.
## Um quarto do que a arte ja provou possivel fica muito acima do ruido e muito
## abaixo do teto.
const LIMIAR_VERTICAL := 0.20

## Quanto a face tem de estar ACIMA do chao em orientacao.
##
## Esta e a assercao que carrega a tese, e por isso ela e RELATIVA e nao um teto
## absoluto sobre o chao. Exigir que o piso puxe para horizontal o obrigaria a
## ganhar juntas -- e `_o_piso_e_a_superficie_mais_calma_da_sala` acabou de faze-lo
## perder detalhe, justamente porque piso calmo e onde o combate se le. Placa
## quadrada e isotropica por desenho, e isso esta certo.
##
## O que nao pode e as duas falarem a MESMA lingua. Medido antes deste portao:
## face -0,142 contra chao +0,024, ou seja, **separacao NEGATIVA de 0,166** -- em
## media o chao era mais vertical que a parede.
const SEPARACAO_MINIMA := 0.15

## As faces que ainda nao se comprometeram com o eixo, declaradas.
##
## Mesmo desenho do `SEM_ARTE_AINDA` do portao de origem e do `PENDENTES` do
## enquadramento: a lista SO ENCOLHE, todo nome nela tem de existir em disco e
## continuar reprovando, e toda face FORA dela tem de passar. Sem ela o portao
## entraria vermelho com 28 arquivos e seria desligado antes de servir para
## alguma coisa.
##
## Tirar um nome daqui e o interruptor de "esta face foi redesenhada".
const SEM_ORIENTACAO_AINDA: Array[String] = [
	"parede_face",
	"parede_face_arma",
	"parede_face_arma_deteriorada",
	"parede_face_arma_tecnica",
	"parede_face_arma_tubulacao",
	"parede_face_arma_ventilada",
	"parede_face_boss",
	"parede_face_boss_deteriorada",
	"parede_face_boss_energia",
	"parede_face_boss_motor",
	"parede_face_boss_tecnica",
	"parede_face_boss_tubulacao",
	"parede_face_boss_ventilada",
	"parede_face_combate",
	"parede_face_combate_deteriorada",
	"parede_face_combate_tecnica",
	"parede_face_combate_tubulacao",
	"parede_face_combate_ventilada",
	"parede_face_inicial",
	"parede_face_inicial_deteriorada",
	"parede_face_inicial_tecnica",
	"parede_face_inicial_tubulacao",
	"parede_face_inicial_ventilada",
	"parede_face_item",
	"parede_face_item_deteriorada",
	"parede_face_item_tecnica",
	"parede_face_item_tubulacao",
	"parede_face_item_ventilada",
]


## A FACE le como superficie vertical, e o CHAO nao fala a mesma lingua.
##
## Calmar o piso resolveu METADE do problema: as duas superficies deixaram de ter
## a mesma densidade. A outra metade e a GRAMATICA -- mesma escala de placa, mesmo
## material, mesma orientacao aparente. Duas superficies com a mesma gramatica nao
## produzem hierarquia espacial por mais que uma seja mais escura, e era isso que
## fazia a faixa de parede ler como "mais uma fileira de placas".
##
## A face e onde a identidade arquitetonica aparece; o TOPO e so espessura e por
## isso fica FORA desta conta -- cobrar verticalidade dele seria pedir decoracao
## na superficie que existe justamente para nao ter nenhuma.
func _a_face_le_como_superficie_VERTICAL() -> void:
	var no_disco := _faces_em_disco()
	var conferidas := 0
	var pendentes := 0
	for nome_arquivo in no_disco:
		var o := _orientacao(nome_arquivo)
		if o == INF:
			ok(false, "%s abre" % nome_arquivo)
			continue
		if SEM_ORIENTACAO_AINDA.has(nome_arquivo):
			# A lista morde dos DOIS lados: nome nela que JA passa e uma linha
			# que ficou para tras, e a lista deixa de dizer o que falta.
			ok(
				o < LIMIAR_VERTICAL,
				"%s esta declarada como pendente e continua horizontal (%.3f)"
					% [nome_arquivo, o]
			)
			pendentes += 1
			continue
		conferidas += 1
		ok(
			o >= LIMIAR_VERTICAL,
			"%s le como vertical (%.3f, minimo %.2f)"
				% [nome_arquivo, o, LIMIAR_VERTICAL]
		)
	ok(conferidas + pendentes > 0, "houve face para medir (%d)" % (conferidas + pendentes))

	# O outro lado da lista: nome declarado que sumiu do disco e isencao herdada
	# por engano -- uma face renomeada levaria a isencao da antiga junto.
	for pendente in SEM_ORIENTACAO_AINDA:
		ok(no_disco.has(pendente), "%s, declarada pendente, existe em disco" % pendente)


## E as duas superficies ficam SEPARADAS em orientacao.
##
## Mede a mediana das faces JA migradas contra a mediana do chao. Enquanto
## nenhuma face migrou nao ha par para comparar, e o caso diz isso em vez de
## fingir que mediu -- mas assim que a lista comeca a encolher ele passa a
## carregar a tese sozinho.
func _o_chao_e_a_face_nao_falam_a_mesma_lingua() -> void:
	var faces: Array[float] = []
	for nome_arquivo in _faces_em_disco():
		if SEM_ORIENTACAO_AINDA.has(nome_arquivo):
			continue
		var o := _orientacao(nome_arquivo)
		if o != INF:
			faces.append(o)
	var chaos: Array[float] = []
	for nome_arquivo in CHAO:
		var o := _orientacao(nome_arquivo)
		if o != INF:
			chaos.append(o)

	igual(chaos.size(), CHAO.size(), "os chaos foram medidos")
	if faces.is_empty():
		ok(
			not SEM_ORIENTACAO_AINDA.is_empty(),
			"nenhuma face migrou ainda, e as %d pendentes explicam por que"
				% SEM_ORIENTACAO_AINDA.size()
		)
		return

	var mediana_face := _mediana(faces)
	var mediana_chao := _mediana(chaos)
	ok(
		mediana_face - mediana_chao >= SEPARACAO_MINIMA,
		"face e chao falam linguas diferentes (face %.3f, chao %.3f, separacao %.3f, minimo %.2f)"
			% [mediana_face, mediana_chao, mediana_face - mediana_chao, SEPARACAO_MINIMA]
	)


## A orientacao de uma textura, em [-1, 1]. `INF` quando o arquivo nao abre.
##
## Le com WRAP nos dois eixos, e nao parando na borda: estas texturas ladrilham,
## entao a coluna 63 e vizinha da 0 no jogo. Medir sem o wrap ignoraria justamente
## a juncao, que e onde uma nervura vertical mal fechada apareceria.
func _orientacao(nome_arquivo: String) -> float:
	var imagem := _abrir(TEXTURAS + nome_arquivo + ".png")
	if imagem == null:
		return INF
	var l := imagem.get_width()
	var a := imagem.get_height()
	var energia_x := 0.0
	var energia_y := 0.0
	for y in a:
		for x in l:
			var v := _luma(imagem.get_pixel(x, y))
			energia_x += absf(_luma(imagem.get_pixel((x + 1) % l, y)) - v)
			energia_y += absf(_luma(imagem.get_pixel(x, (y + 1) % a)) - v)
	var soma := energia_x + energia_y
	if soma <= 0.0:
		return 0.0
	return (energia_x - energia_y) / soma


func _luma(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


func _mediana(valores: Array[float]) -> float:
	if valores.is_empty():
		return 0.0
	valores.sort()
	return valores[valores.size() / 2]


## As faces em DISCO, e nao uma lista fixa.
##
## Lista fixa nao acusa arquivo que nunca entrou nela: ele SOME da conta em vez de
## reprovar, e a suite fica verde. E a armadilha que deixou cinco PNGs passarem sem
## prova em `_nenhum_png_fica_fora_de_regime`.
func _faces_em_disco() -> Array[String]:
	var fora: Array[String] = []
	var pasta := DirAccess.open(TEXTURAS)
	if pasta == null:
		return fora
	var arquivos := pasta.get_files()
	arquivos.sort()
	for arquivo in arquivos:
		if arquivo.begins_with("parede_face") and arquivo.ends_with(".png"):
			fora.append(arquivo.get_basename())
	return fora
