extends Node2D
## A PROVA DE LEITURA das salas: as quatro perguntas da Fase D, numa execucao.
##
## O briefing fecha o andar 1 com quatro conferencias que sao a mesma pergunta
## vista de quatro angulos -- **a sala diz o que ela e sem depender de cor?**:
##
##   `[FAB 40]`  as salas montadas e fotografadas, no enquadramento do jogo
##   `[FAB 39]`  as mesmas SEM o acento de tipo (secoes 83 e 110)
##   `[FAB 41]`  as mesmas em CINZA (secao 88)
##   `[FAB 42]`  as mesmas em MINIATURA (secao 89)
##
## Elas viram uma ferramenta so porque as tres ultimas sao a PRIMEIRA vista de
## outro jeito: a mesma sala, o mesmo enquadramento, a mesma semente. Rodar
## quatro ferramentas produziria quatro sorteios diferentes, e ai a comparacao
## deixaria de ser sobre o regime e passaria a ser sobre a sorte de cada uma.
##
## ## O que "sem tint" desliga, e o que ele NAO desliga
##
## Depois da `[FAB 09]`/`[FAB 10]` o acento de tipo mora em tres lugares: a
## textura de CHAO, a familia de FACE e a luminaria FRIA. Este modo troca os
## tres pelo neutro do andar -- `EstiloDeParede.face_neutra`, o chao
## `chao_andar1_*` e zero luz fria -- e **nao mexe em mais nada**.
##
## O que sobra e o que a `[FAB 12]` decidiu que deve carregar a identidade:
## PROP, DECALQUE e LAYOUT. Uma sala que fica irreconhecivel aqui esta dizendo
## que a funcao dela era tinta, e e esse o FAIL que a secao 110 descreve.
##
## ## Por que ele fotografa em vez de so medir
##
## O aceite da `[FAB 39]` e "as quatro identificadas sem cor por ALGUEM QUE NAO
## MONTOU AS SALAS", e isso nao e um numero -- e a mesma classe de conferencia
## que o playtest resolve e nenhuma regua resolve. O que a ferramenta entrega e
## o material para essa pessoa olhar, na forma em que ela vai olhar.
##
## **Mas ela mede o que da para medir**, e o que da e a pergunta irma: duas
## salas que produzem a MESMA assinatura sem cor nunca vao ser separadas por
## ninguem, por mais atento que esteja. A regua compara os pares e nomeia os que
## colidem -- e o numero dela e a distancia entre as assinaturas, nao um
## veredito sobre a funcao da sala.
##
## ## Uso
##
##   godot --path . tools/fabrica/prova_de_leitura.tscn --resolution 960x544
##
## Sai em `user://capturas/prova/`, uma pasta por regime. Sem janela ele nao
## roda: nao ha GPU, `get_image()` nao devolve o que a tela mostraria, e uma
## regua que mede um quadro preto e pior que regua nenhuma -- ele avisa e
## encerra com 1.

const SAIDA := "user://capturas/prova"

## A regua de familias de cor, emprestada inteira.
##
## `preload` do script e nao uma copia dos limites: `medir_ambiente.gd` e o dono
## das faixas de matiz, saturacao e valor que separam as sete familias, e duas
## copias delas divergiriam na primeira mexida -- com o sintoma sendo duas
## reguas discordando sobre a mesma imagem. Mesma razao pela qual `MATIZ_POR_TIPO`
## vive em dois arquivos e isso esta registrado como armadilha.
const MedirAmbiente := preload("res://tools/texturas/medir_ambiente.gd")

## A referencia MEDIDA, em `docs/REFERENCIA_FABRICA.md` secao 3.1.
##
## Sao as fracoes do QUADRO INTEIRO de `docs/fabrica_01.png`. Elas nao sao alvo
## de portao -- a referencia e um render 3D de UMA sala e o jogo e outra coisa --,
## e sim a regua do `[FAB 45]`: por os dois lado a lado e ver o que diverge.
const REFERENCIA := {
	"preto": 0.5075,
	"cinza_azulado": 0.3543,
	"outro": 0.0777,
	"ferrugem": 0.0330,
	"ciano": 0.0050,
	"ambar": 0.0041,
	"magenta": 0.0017,
	"verde": 0.0016,
}

## Os tipos fotografados, na ordem em que a folha os apresenta.
##
## A Loja entra, e ela nao esta na lista de quatro do briefing porque nao
## existia quando ele foi escrito. Deixa-la de fora seria repetir o defeito que
## `_nenhum_png_fica_fora_de_regime` conserta do lado das texturas: o que nao e
## medido nao reprova, ele SOME da conta.
const TIPOS: Array[String] = [
	"res://src/mapa/tipo_combate.tres",
	"res://src/mapa/tipo_item.tres",
	"res://src/mapa/tipo_arma.tres",
	"res://src/mapa/tipo_loja.tres",
	"res://src/mapa/tipo_boss.tres",
]

## Quantas salas de cada tipo a linha de base tem.
##
## Os numeros sao os da `[FAB 40]` (secoes 84-87): dez de combate, tres de cada
## recompensa. Dez e tres porque a sala de combate e a que o jogador ve dez
## vezes por andar -- a variedade DELA e o que decide se o andar parece repetido,
## e tres amostras de uma sala que aparece uma vez ja mostram o que ela e.
##
## O chefe entra com duas: ele aparece uma vez por andar e a arena e autorada,
## entao a pergunta "ela varia?" quase nao existe -- mas "ela existe na folha?"
## existe, e deixa-lo de fora seria tira-lo da conta.
const QUANTAS_POR_TIPO := {
	&"combate": 10,
	&"item": 3,
	&"arma": 3,
	&"loja": 3,
	&"boss": 2,
}

## Quanto a DECORACAO precisa somar ao desvio da sala NUA, em cinza (`[FAB 41]`).
##
## **O piso da `[FAB 41]` nao pode ser o `PISO_DESVIO_CINZA` de
## `medir_ambiente.gd`, e isso foi medido.** Aquele 0,06 e sobre um ARQUIVO de
## textura, que e detalhe de ponta a ponta; um quadro de jogo tem o vazio alem
## da parede (12 a 16% dele, por decisao do `margem_exterior`) e um piso escuro
## debaixo do `AmbienteDaFabrica`. Medida, a sala montada da 0,044 a 0,055 --
## abaixo daquele numero, com a decoracao inteira em tela. Herdar a constante
## reprovaria as cinco salas e nao diria nada: e a mesma armadilha que o
## `FATOR_DE_RENDER` do `teste_luz.gd` registra, uma constante de transferencia
## trazida de outro regime.
##
## O que a secao 88 pergunta e se **forma e massa** carregam a identidade sem
## cor, e isso tem um controle obvio: a MESMA sala sem decoracao nenhuma. Se o
## desvio nao subir quando os props entram, eles nao estao somando massa -- eles
## estao somando cor.
##
## 1,15 pede 15% acima da sala nua. Nao e muito de proposito: a decoracao ocupa
## a faixa de perimetro, e a faixa e uma fracao do quadro.
const GANHO_MINIMO_DA_DECORACAO := 1.15

## Os tipos que sao LIMPOS por decisao, e nao por falta de arte.
##
## A arena do chefe declara as quatro contagens de volume em ZERO, e isso e
## escolha registrada: ela e a sala mais densa de projetil do jogo, e um corpo
## com face vertical ali e o que a LTD 10 manda dosar. `teste_props.gd` tem um
## caso inteiro (`_a_arena_do_chefe_fica_limpa`) para essa mudanca ser
## DELIBERADA.
##
## Sem esta lista a regua reprovaria o chefe e empurraria alguem a "consertar"
## a arena enchendo-a de caixotes -- o oposto exato do que aquele portao pede.
##
## **Ela morde dos DOIS lados**, como `SEM_ARTE_AINDA` e `SEM_CLIPE_AINDA`: nome
## de fora precisa ganhar massa, nome de DENTRO precisa continuar sem ganhar. Se
## a arena passar a somar massa, a decisao mudou e alguem tem de dizer isso em
## voz alta em vez de a lista cobrir a mudanca em silencio.
const TIPOS_LIMPOS_POR_DECISAO: Array[StringName] = [&"boss"]

## Piso de quanto do contraste sobrevive a reducao para 1/4 (`[FAB 42]`).
##
## Gemeo do `PISO_SOBREVIVENCIA_MINIATURA`, pela mesma razao. A ordem de
## correcao, se ele reprovar, e contrato da secao 88 e nao escolha: **primeiro
## baixar contraste, e so entao diminuir quantidade.** Deixar a sala vazia e a
## resposta errada.
const PISO_SOBREVIVENCIA_MINIATURA := 0.60

## O chao NEUTRO do andar: o mesmo que a sala de combate usa.
##
## "Neutro" aqui nao e um cinza inventado -- e o chao que o andar 1 tem quando
## ninguem acentua nada, e a sala de combate e justamente a que nao acentua.
const CHAO_NEUTRO: Array[String] = [
	"res://assets/texturas/chao_andar1_a.png",
	"res://assets/texturas/chao_andar1_b.png",
	"res://assets/texturas/chao_andar1_c.png",
]

## Quanto a miniatura reduz. Gemeo do `FATOR_MINIATURA` de
## `tools/texturas/medir_ambiente.gd`, e os dois mudam juntos: a pergunta da
## secao 89 e uma so, e duas respostas dela divergiriam em silencio.
const FATOR_MINIATURA := 4

## As DUAS celulas em que cada tipo e fotografado sem tint.
##
## Elas existem para produzir o CONTROLE, e sem ele esta regua nao vale nada.
## `Sala` semeia a decoracao com `hash(coordenadas_grid)`, entao a mesma sala em
## duas celulas e o mesmo tipo com outro sorteio -- e a distancia entre essas
## duas e o RUIDO do sorteio.
##
## A primeira versao desta ferramenta comparava as distancias entre tipos contra
## um piso escrito a mao (0,12) e reprovou os DEZ pares. Regua que reprova tudo
## mede a si mesma: um histograma de luminancia sobre um quadro
## majoritariamente escuro varia pouco por construcao, e 0,12 era um numero
## sobre nada. E a mesma licao que a `MedidorEscape` ja pagou, e o mesmo conserto
## que o disco chapado faz no laboratorio de luz.
const CELULAS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(7, 3)]

## Quanto a diferenca ENTRE TIPOS precisa ser maior que o RUIDO do sorteio.
##
## 1,0 seria "qualquer coisa acima do ruido serve", que aceita diferenca dentro
## da margem de erro. 1,5 pede que a diferenca entre duas salas seja meia vez
## maior que a diferenca entre duas versoes da MESMA sala -- o minimo para
## alguem poder atribuir o que ve ao tipo em vez de ao sorteio.
const VEZES_ACIMA_DO_RUIDO := 1.5

## Quantas faixas o histograma tem.
##
## 32 e grosso de proposito: com 256 faixas duas salas se separariam por ruido
## de um pixel, que nao e o que ninguem enxerga.
const FAIXAS := 32

var _quadros: Dictionary = {}
## A linha de base inteira: um registro por sala fotografada com tint.
var _amostras: Array[Dictionary] = []
## O retangulo, em pixels de TELA, que a ultima sala fotografada ocupa.
##
## Ele existe para a `[FAB 45]` poder medir a SALA e nao o quadro. O quadro tem
## o vazio alem da parede -- 12 a 16% dele, por decisao do `margem_exterior` --,
## e aquele vazio e preto puro por construcao (`Sala.COR_DO_VAZIO`). Comparar o
## quadro inteiro com a referencia, que e um render de uma sala FECHADA, conta a
## moldura como se fosse sombra da fabrica.
var _ultimo_recorte := Rect2i()


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("\n[prova_de_leitura] sem janela nao ha o que fotografar.")
		print("  Ela le PIXEL RENDERIZADO: em --headless nao ha GPU e o quadro")
		print("  volta preto. Rode com:")
		print("    godot --path . tools/fabrica/prova_de_leitura.tscn --resolution 960x544")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(SAIDA)
	# A ESCURIDAO DA RUN, e ela e obrigatoria aqui.
	#
	# `AmbienteDaFabrica` mora em `main.tscn` e NAO nas cenas de sala, de
	# proposito: as reguas de `tools/` que medem geometria (`medir_moldura`,
	# `comparar_caixa`, `formas_paredes`) montam sala sozinha, e escurece-las
	# mudaria o significado dos numeros historicos delas de uma vez.
	#
	# **Esta regua e a excecao, e por isso ela declara.** As quatro perguntas da
	# Fase D sao sobre PERCEPCAO -- o que o jogador ve --, e sem o
	# `CanvasModulate` a sala sai com o brilho cru: medido, 17,4% de preto contra
	# os 88% que uma captura do jogo da. A primeira versao desta ferramenta media
	# uma sala que o jogador nunca ve, e a `[FAB 45]` foi quem denunciou, porque
	# so ela compara com um numero ABSOLUTO.
	add_child(AmbienteDaFabrica.new())
	await _fotografar_tudo()
	_medir()
	get_tree().quit()


func _fotografar_tudo() -> void:
	print("\n--- a linha de base, sem HUD ---\n")
	for caminho in TIPOS:
		var dados := load(caminho) as DadosSala
		if dados == null:
			print("  %s nao carrega" % caminho)
			continue
		var id := String(dados.id)

		# A LINHA DE BASE da `[FAB 40]`: N salas do tipo, sementes diferentes.
		# Cada uma vira uma foto; a PRIMEIRA vira tambem a amostra dos outros
		# tres regimes, para as quatro folhas mostrarem a mesma sala.
		var quantas: int = QUANTAS_POR_TIPO.get(StringName(id), 1)
		for n in quantas:
			var celula := Vector2i(n * 11 + 1, n * 5)
			var quadro := await _fotografar(dados, false, celula)
			if quadro == null:
				continue
			_gravar(quadro, "com_tint", "%s_%02d" % [id, n])
			if n == 0:
				_quadros[id] = quadro
				_gravar(_em_cinza(quadro), "cinza", id)
				_gravar(_em_miniatura(quadro), "miniatura", id)
			_amostras.append({"id": id, "quadro": quadro, "recorte": _ultimo_recorte})

		# SEM TINT nas duas celulas: a segunda e o CONTROLE, e nao uma foto a
		# mais. Ela e gravada tambem -- quem olhar a folha precisa ver que "a
		# mesma sala noutro sorteio" continua sendo a mesma sala.
		# A sala NUA, com tint: o controle da `[FAB 41]`. Ela nao vai para a
		# folha -- ninguem precisa olhar uma sala vazia --, so para a regua.
		var nua := await _fotografar(dados, false, CELULAS[0], true)
		if nua != null:
			_quadros["%s_nua" % id] = nua

		for i in CELULAS.size():
			var sem := await _fotografar(dados, true, CELULAS[i])
			if sem == null:
				continue
			_quadros["%s_sem_tint_%d" % [id, i]] = sem
			_gravar(sem, "sem_tint" if i == 0 else "sem_tint_controle", id)


## Uma sala montada, enquadrada e fotografada.
##
## Ela e montada NUA: sem inimigo, sem jogador e sem HUD. Os tres respondem
## outras perguntas, e um inimigo na foto e a primeira coisa que o olho procura
## -- ele responderia "sala de combate" antes de a arquitetura ter chance.
func _fotografar(
	dados: DadosSala, sem_tint: bool, celula: Vector2i, nua: bool = false
) -> Image:
	var cenas := dados.cenas_validas()
	if cenas.is_empty():
		return null
	var sala := cenas[0].instantiate() as Sala
	if sala == null:
		return null
	sala.coordenadas_grid = celula
	sala.definir_visual(_dados_para(dados, sem_tint, nua))
	add_child(sala)

	var camera := Camera2D.new()
	camera.position = sala.obter_limites().get_center()
	camera.zoom = Vector2.ONE
	add_child(camera)
	camera.make_current()

	# Dois quadros: o primeiro monta, o segundo desenha o que foi montado.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var imagem := get_viewport().get_texture().get_image()

	# Onde a SALA cai na tela. Com a camera no centro dela e zoom 1, o contorno
	# vai do meio do quadro para os dois lados; o resto e o vazio alem da
	# parede, que e preto puro e nao pertence a nenhuma medicao de ambiente.
	var tela := Vector2(imagem.get_width(), imagem.get_height())
	var limites := sala.obter_limites()
	var canto := tela * 0.5 - limites.size * 0.5
	_ultimo_recorte = Rect2i(canto.round(), Vector2i(limites.size.round())).intersection(
		Rect2i(Vector2i.ZERO, Vector2i(tela)))

	camera.queue_free()
	sala.queue_free()
	await get_tree().process_frame
	return imagem


## O `DadosSala` do regime pedido.
##
## Sempre uma COPIA, mesmo no modo normal: `load()` devolve o recurso
## COMPARTILHADO, e escrever nele vazaria o "sem tint" para o jogo inteiro --
## inclusive para quem carregasse aquele `.tres` depois, ja que o Godot o serve
## de memoria. E a mesma armadilha do sub-resource compartilhado num `.tscn`.
func _dados_para(dados: DadosSala, sem_tint: bool, nua: bool) -> DadosSala:
	var copia := dados.duplicate() as DadosSala
	if nua:
		# Sem perfil, `DadosSala.faixa_de_*()` devolve ZERO nas quatro familias:
		# a sala nasce com chao, parede, porta e luz, e mais nada. E o CONTROLE
		# da `[FAB 41]` -- o quadro que a decoracao tem de melhorar.
		copia.perfil_de_decoracao = null
	if not sem_tint:
		return copia
	copia.texturas_chao = _texturas(CHAO_NEUTRO)
	var neutra: Texture2D = null
	if copia.estilo_de_parede != null:
		neutra = copia.estilo_de_parede.face_neutra
	var faces: Array[Texture2D] = []
	if neutra != null:
		faces.append(neutra)
	copia.texturas_face = faces
	# A luz FRIA e o terceiro lugar onde o tipo mora (`[FAB 12]`): ela e o
	# indicador tecnico do item, da arma e da loja. As AMBAR ficam -- elas sao
	# do andar, e nao do tipo.
	copia.quantidade_luminarias_frias = 0
	return copia


func _texturas(caminhos: Array[String]) -> Array[Texture2D]:
	var lista: Array[Texture2D] = []
	for caminho in caminhos:
		var t := load(caminho) as Texture2D
		if t != null:
			lista.append(t)
	return lista


# ------------------------------------------------------------ os regimes ----


## CINZA: a luminancia, pelos mesmos pesos que o resto do projeto usa.
func _em_cinza(fonte: Image) -> Image:
	var saida := Image.create(fonte.get_width(), fonte.get_height(), false, fonte.get_format())
	for y in fonte.get_height():
		for x in fonte.get_width():
			var v := _luma(fonte.get_pixel(x, y))
			saida.set_pixel(x, y, Color(v, v, v, 1.0))
	return saida


## MINIATURA: o quadro reduzido, com a interpolacao que o jogo usa.
##
## `INTERPOLATE_NEAREST` e nao bilinear: a pergunta da secao 89 e se a silhueta
## sobrevive ao tamanho, e um filtro que MEDIA pixels responderia sobre o
## filtro. O projeto inteiro desenha em Nearest.
func _em_miniatura(fonte: Image) -> Image:
	var saida := fonte.duplicate() as Image
	saida.resize(
		maxi(1, fonte.get_width() / FATOR_MINIATURA),
		maxi(1, fonte.get_height() / FATOR_MINIATURA),
		Image.INTERPOLATE_NEAREST)
	return saida


func _gravar(imagem: Image, regime: String, id: String) -> void:
	var pasta := "%s/%s" % [SAIDA, regime]
	DirAccess.make_dir_recursive_absolute(pasta)
	var caminho := "%s/%s.png" % [pasta, id]
	imagem.save_png(caminho)
	print("  %-10s %s" % [regime, ProjectSettings.globalize_path(caminho)])


# -------------------------------------------------------------- a regua -----


## As salas COLIDEM sem cor?
##
## Ela nao responde "da para identificar a funcao" -- isso e a pessoa. Ela
## responde a pergunta irma, que e objetiva: **duas salas com a mesma assinatura
## sem cor nao tem como ser separadas por ninguem.** Um par abaixo do piso e um
## par que nao adianta mostrar.
func _medir() -> void:
	print("\n=== a prova de leitura ===\n")
	var ids: Array[String] = []
	for caminho in TIPOS:
		var dados := load(caminho) as DadosSala
		if dados != null and _quadros.has("%s_sem_tint_0" % String(dados.id)):
			ids.append(String(dados.id))

	print("  %d sala(s) fotografada(s)." % ids.size())
	print("  A pergunta que SO uma pessoa responde esta em capturas/prova/sem_tint:")
	print("  mostre as %d a alguem que nao montou nenhuma e peca a funcao de cada uma.\n"
		% ids.size())

	# O CONTROLE primeiro: a mesma sala, outro sorteio. Ele e a unidade em que
	# todo o resto e lido -- sem ele os numeros abaixo nao teriam escala.
	print("  --- o CONTROLE: a mesma sala noutra celula ---\n")
	var ruido := 0.0
	for id in ids:
		var d := _distancia(_quadros["%s_sem_tint_0" % id], _quadros["%s_sem_tint_1" % id])
		ruido += d
		print("    %-10s x ela mesma   %.3f" % [id, d])
	ruido /= maxf(float(ids.size()), 1.0)
	var piso := ruido * VEZES_ACIMA_DO_RUIDO
	print("\n    ruido medio do sorteio: %.3f" % ruido)
	print("    piso para uma diferenca contar: %.3f (%.1fx o ruido)"
		% [piso, VEZES_ACIMA_DO_RUIDO])

	print("\n  --- distancia entre pares, SEM TINT ---\n")
	var colisoes: Array[String] = []
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var a: Image = _quadros["%s_sem_tint_0" % ids[i]]
			var b: Image = _quadros["%s_sem_tint_0" % ids[j]]
			var d := _distancia(a, b)
			var leitura := "%.1fx o ruido" % (d / maxf(ruido, 0.0001))
			if d < piso:
				leitura = "DENTRO DO RUIDO"
				colisoes.append("%s x %s (%.3f)" % [ids[i], ids[j], d])
			print("    %-10s x %-10s   %.3f   %s" % [ids[i], ids[j], d, leitura])

	if colisoes.is_empty():
		print("\n  nenhum par cai dentro do ruido -- sem cor, as salas continuam")
		print("  diferentes entre si por mais do que o sorteio explica.")
	else:
		print("\n  %d par(es) que o sorteio explica sozinho: %s"
			% [colisoes.size(), ", ".join(colisoes)])
		print("  Nao adianta perguntar a uma pessoa sobre esses: a diferenca entre")
		print("  eles e menor que a diferenca entre duas versoes da MESMA sala.")

	_o_teste_em_cinza()
	_o_teste_em_miniatura()
	_o_teste_da_referencia()

	print("\n  --- quanto o tint estava carregando ---\n")
	print("  Distancia entre a MESMA sala com e sem o acento de tipo, na mesma")
	print("  celula. Alta demais quer dizer que a cor era boa parte do que se")
	print("  via -- que e o que a secao 110 manda nao ser.\n")
	for id in ids:
		var d := _distancia(_quadros[id], _quadros["%s_sem_tint_0" % id])
		print("    %-10s   %.3f   (%.1fx o ruido)" % [id, d, d / maxf(ruido, 0.0001)])


## `[FAB 41]` -- O TESTE EM CINZA, sobre a sala montada.
##
## A secao 88 pede que forma, massa e iluminacao carreguem a identidade quando o
## matiz sai. O que `medir_ambiente.gd` responde e a metade de dentro do
## ARQUIVO: uma textura pode ter contraste otimo no PNG e sumir na tela debaixo
## do `AmbienteDaFabrica`, porque massa e iluminacao so existem depois da
## montagem. Aqui a medicao e sobre o quadro.
##
## O numero e o desvio padrao da luminancia, lido contra o CONTROLE da sala sem
## decoracao. Sala que nao ganha massa quando os props entram e sala que so
## funcionava colorida.
func _o_teste_em_cinza() -> void:
	print("\n  --- `[FAB 41]` o teste em CINZA, na sala montada ---\n")
	print("    O numero e o desvio padrao da luminancia do QUADRO, e o CONTROLE")
	print("    e a mesma sala sem decoracao nenhuma. A secao 88 nao pergunta se")
	print("    ha contraste -- ela pergunta se a MASSA carrega a identidade sem")
	print("    cor, e massa que nao sobe quando os props entram e cor disfarcada.\n")
	print("    %-10s %9s %9s %8s   %s" % ["tipo", "nua", "decorada", "ganho", "leitura"])
	print("    " + "-".repeat(60))
	var por_tipo := {}
	for amostra in _amostras:
		var id: String = amostra["id"]
		if not por_tipo.has(id):
			por_tipo[id] = []
		(por_tipo[id] as Array).append(_desvio_de_luma(amostra["quadro"]))
	var abaixo: Array[String] = []
	var medidos := 0
	for id: String in por_tipo:
		if not _quadros.has("%s_nua" % id):
			continue
		medidos += 1
		var valores: Array = por_tipo[id]
		var media := 0.0
		for v: float in valores:
			media += v
		media /= maxf(float(valores.size()), 1.0)
		var vazia := _desvio_de_luma(_quadros["%s_nua" % id])
		var ganho := media / maxf(vazia, 0.0001)
		var limpo_de_proposito := TIPOS_LIMPOS_POR_DECISAO.has(StringName(id))
		var leitura := "a massa carrega"
		if limpo_de_proposito:
			# Os dois lados da lista: aqui esta o que ela ESPERA encontrar, e o
			# contrario tambem e reportado.
			leitura = "limpo por decisao"
			if ganho >= GANHO_MINIMO_DA_DECORACAO:
				leitura = "LIMPO POR DECISAO, mas ganhou massa"
				abaixo.append("%s (a decisao mudou?)" % id)
		elif ganho < GANHO_MINIMO_DA_DECORACAO:
			leitura = "SO A COR CARREGAVA"
			abaixo.append(id)
		print("    %-10s %9.4f %9.4f %7.2fx   %s" % [id, vazia, media, ganho, leitura])
	# TABELA VAZIA NAO E APROVACAO. A primeira versao deste caso imprimiu
	# "a decoracao soma massa em todos os tipos" com ZERO linhas medidas -- o
	# controle nao tinha sido tirado, `_quadros` nao tinha nenhuma sala nua, e o
	# laco inteiro caiu no `continue`. E o mesmo defeito que o `_verificacoes`
	# do laboratorio de decoracao existe para pegar: regua silenciosa que diz
	# PASSOU e pior que regua que reprova.
	if medidos <= 0:
		print("\n    NADA FOI MEDIDO -- nenhuma sala nua foi fotografada.")
		return
	print("\n    ganho minimo pedido: %.2fx" % GANHO_MINIMO_DA_DECORACAO)
	if abaixo.is_empty():
		print("    a decoracao soma massa nos %d tipos -- sem cor, ha o que ver."
			% medidos)
	else:
		print("    %d de %d tipo(s) em que a decoracao nao soma massa: %s"
			% [abaixo.size(), medidos, ", ".join(abaixo)])


## `[FAB 42]` -- O TESTE EM MINIATURA, sobre a sala montada.
##
## Quanto do contraste sobrevive a um quarto do lado. A razao e o numero que
## interessa, e nao o desvio absoluto: uma sala escura pode ter pouco contraste
## e mesmo assim manter TODO ele ao encolher, e e a manutencao que diz se a
## silhueta aguenta a distancia.
##
## **A ordem de correcao e contrato, e nao escolha** (secao 88, repetida na
## 129): se reprovar, primeiro BAIXAR CONTRASTE, e so entao diminuir a
## quantidade de props. Esvaziar a sala e a resposta errada para esta pergunta.
func _o_teste_em_miniatura() -> void:
	print("\n  --- `[FAB 42]` o teste em MINIATURA (1/%d), na sala montada ---\n"
		% FATOR_MINIATURA)
	print("    piso da sobrevivencia: %.0f%%\n" % (PISO_SOBREVIVENCIA_MINIATURA * 100.0))
	var por_tipo := {}
	for amostra in _amostras:
		var id: String = amostra["id"]
		if not por_tipo.has(id):
			por_tipo[id] = []
		var cheio := _desvio_de_luma(amostra["quadro"])
		var pequeno := _desvio_de_luma(_em_miniatura(amostra["quadro"]))
		(por_tipo[id] as Array).append(pequeno / maxf(cheio, 0.0001))
	var abaixo: Array[String] = []
	for id: String in por_tipo:
		var valores: Array = por_tipo[id]
		var media := 0.0
		for v: float in valores:
			media += v
		media /= maxf(float(valores.size()), 1.0)
		var leitura := "aguenta a distancia"
		if media < PISO_SOBREVIVENCIA_MINIATURA:
			leitura = "VIRA RUIDO"
			abaixo.append(id)
		print("    %-10s   %.0f%%   (%d sala(s))   %s"
			% [id, media * 100.0, valores.size(), leitura])
	if abaixo.is_empty():
		print("\n    nenhum tipo vira ruido ao encolher.")
	else:
		print("\n    %d tipo(s) abaixo do piso: %s" % [abaixo.size(), ", ".join(abaixo)])
		print("    A ordem de correcao e da secao 88: baixar CONTRASTE primeiro,")
		print("    diminuir a quantidade de props so depois.")


## `[FAB 45]` -- O JOGO AO LADO DA REFERENCIA, medido.
##
## A secao 92 pede para por `docs/fabrica_01.png` ao lado das capturas e julgar.
## O julgamento e de olho e continua sendo -- o que esta aqui e a metade que
## tem numero, e ela existe para a conversa comecar do lugar certo.
##
## ## Ela mede a SALA, e nao o quadro -- e essa distincao vale 20 pontos
##
## O quadro de jogo tem o vazio alem da parede, que sao 12 a 16% dele por
## decisao do `margem_exterior`, e aquele vazio e `Sala.COR_DO_VAZIO` -- preto
## puro por construcao. A referencia e um render de uma sala FECHADA: ela nao
## tem moldura nenhuma. Medir o quadro inteiro conta a moldura como se fosse
## sombra da fabrica, e foi assim que a primeira comparacao desta sessao
## respondeu "37,7 pontos mais escuro" sem separar as duas coisas.
##
## As duas colunas ficam lado a lado justamente por isso: a diferenca entre elas
## E a moldura, e ve-la impede de atribuir a falta de luz o que e enquadramento.
func _o_teste_da_referencia() -> void:
	print("\n  --- `[FAB 45]` o jogo ao lado da referencia ---\n")
	print("    A referencia (`docs/fabrica_01.png`) e um render de UMA sala")
	print("    fechada. O quadro de jogo tem o vazio alem da parede, que e preto")
	print("    puro -- por isso as duas colunas: a diferenca entre elas e a")
	print("    moldura, e nao falta de luz.\n")
	if _amostras.is_empty():
		print("    NADA FOI MEDIDO -- nenhuma sala na linha de base.")
		return

	var no_quadro := _familias_medias(false)
	var na_sala := _familias_medias(true)
	print("    %-14s %10s %10s %12s   %s"
		% ["familia", "quadro", "so a sala", "referencia", "leitura"])
	print("    " + "-".repeat(66))
	for familia: String in REFERENCIA:
		var alvo: float = REFERENCIA[familia]
		var medido: float = na_sala.get(familia, 0.0)
		print("    %-14s %9.2f%% %9.2f%% %11.2f%%   %s" % [
			familia, no_quadro.get(familia, 0.0) * 100.0, medido * 100.0,
			alvo * 100.0, _leitura_da_familia(medido, alvo)])

	var preto_sala: float = na_sala.get("preto", 0.0)
	var preto_quadro: float = no_quadro.get("preto", 0.0)
	print("\n    a moldura sozinha responde por %.1f pontos de preto"
		% ((preto_quadro - preto_sala) * 100.0))
	print("    e a sala fica %.1f pontos %s que a referencia" % [
		absf(preto_sala - REFERENCIA["preto"]) * 100.0,
		"mais escura" if preto_sala > REFERENCIA["preto"] else "mais clara"])


## Como ler a distancia de uma familia ate a referencia.
##
## Em PONTOS e nao em razao: uma familia que a referencia poe em 0,41% pode
## medir o dobro disso no jogo sem que ninguem veja diferenca, e a razao gritaria
## "200%". O que o olho percebe e quanto do quadro aquilo ocupa.
func _leitura_da_familia(medido: float, alvo: float) -> String:
	var pontos := (medido - alvo) * 100.0
	if absf(pontos) < 2.0:
		return "na referencia"
	return "%+.1f ponto(s)" % pontos


## A composicao media da linha de base, por familia.
##
## `so_a_sala` recorta o quadro no retangulo que a sala ocupa. Amostra de 2 em 2
## pixels, como o resto das reguas deste arquivo.
func _familias_medias(so_a_sala: bool) -> Dictionary:
	var soma: Dictionary = {}
	var quadros := 0
	for amostra in _amostras:
		var imagem: Image = amostra["quadro"]
		var recorte: Rect2i = amostra["recorte"] if so_a_sala else Rect2i(
			Vector2i.ZERO, Vector2i(imagem.get_width(), imagem.get_height()))
		if recorte.size.x <= 0 or recorte.size.y <= 0:
			continue
		var contagem: Dictionary = {}
		var total := 0
		for y in range(recorte.position.y, recorte.end.y, 2):
			for x in range(recorte.position.x, recorte.end.x, 2):
				var nome: String = MedirAmbiente.NOMES_DE_FAMILIA[
					MedirAmbiente.familia_do_pixel(imagem.get_pixel(x, y))]
				contagem[nome] = int(contagem.get(nome, 0)) + 1
				total += 1
		if total <= 0:
			continue
		quadros += 1
		for nome: String in contagem:
			soma[nome] = float(soma.get(nome, 0.0)) + float(contagem[nome]) / float(total)
	if quadros <= 0:
		return {}
	for nome: String in soma:
		soma[nome] = float(soma[nome]) / float(quadros)
	return soma


## Desvio padrao da luminancia do quadro.
##
## Amostrado de 2 em 2 pixels, como o histograma: a resposta e uma dispersao, e
## amostrar todos custa quatro vezes mais para mover a terceira casa.
func _desvio_de_luma(imagem: Image) -> float:
	var soma := 0.0
	var soma_q := 0.0
	var total := 0
	for y in range(0, imagem.get_height(), 2):
		for x in range(0, imagem.get_width(), 2):
			var v := _luma(imagem.get_pixel(x, y))
			soma += v
			soma_q += v * v
			total += 1
	if total <= 0:
		return 0.0
	var media := soma / float(total)
	return sqrt(maxf(soma_q / float(total) - media * media, 0.0))


## Distancia entre dois quadros pela LUMINANCIA, e nao pelo pixel.
##
## Comparar pixel a pixel responderia "as duas imagens sao iguais?", que nao e a
## pergunta -- duas salas do MESMO tipo com sementes diferentes tambem sao
## diferentes pixel a pixel. O histograma responde "elas tem a mesma cara?", que
## e o que o olho faz a distancia.
func _distancia(a: Image, b: Image) -> float:
	var ha := _histograma(a)
	var hb := _histograma(b)
	var soma := 0.0
	for i in FAIXAS:
		soma += absf(ha[i] - hb[i])
	return soma


func _histograma(imagem: Image) -> PackedFloat32Array:
	var faixas := PackedFloat32Array()
	faixas.resize(FAIXAS)
	faixas.fill(0.0)
	var total := 0
	# De 2 em 2 pixels: o quadro tem meio milhao deles e a resposta e uma
	# distribuicao. Amostrar todos custa quatro vezes mais para mexer na
	# terceira casa decimal.
	for y in range(0, imagem.get_height(), 2):
		for x in range(0, imagem.get_width(), 2):
			var v := _luma(imagem.get_pixel(x, y))
			var faixa := clampi(int(v * FAIXAS), 0, FAIXAS - 1)
			faixas[faixa] += 1.0
			total += 1
	if total > 0:
		for i in FAIXAS:
			faixas[i] /= float(total)
	return faixas


func _luma(c: Color) -> float:
	return c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
