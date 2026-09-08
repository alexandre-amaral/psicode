extends Node
## O LABORATORIO DE ICONES: os 16 implantes lado a lado, e a regua que os separa.
##
## A decisao de design que este arquivo carrega: **um icone nao se julga
## sozinho.** Ele e visto na bandeja da HUD ao lado dos outros que o jogador ja
## pegou, e ali a pergunta deixa de ser "este icone le?" e passa a ser "estes
## dois sao a mesma coisa?". Medir peca a peca aprova 16 icones que sao, dois a
## dois, indistinguiveis -- foi assim que dez dos 210 pares de arma passaram a
## menos de 15 graus de matiz, dois deles com RGB identico. Por isso a regua
## mede os **120 pares** dos 16, e nao os 16.
##
## E ela vem ANTES da arte de proposito. Os cinco modulos de face foram
## desenhados e so entao medidos, e a `tubulacao` nao tem ponto que passe --
## descoberto com o PNG pronto em disco. Com 16 pecas o preco de descobrir tarde
## e 16 vezes maior.
##
## TRES MEDIDAS, e as duas primeiras se cruzam:
##
##   SILHUETA  a mascara de alfa de cada peca, reduzida ao tamanho de leitura.
##             Dois recortes com IoU acima de `TETO_IOU` sao a mesma forma.
##   CINZA     a peca dessaturada e composta sobre o chao. Matiz e a primeira
##             coisa que se perde num jogo escuro -- a mesma licao que separa as
##             tres classes de Unidade Aprimorada por MOVIMENTO e nao por cor.
##   FAIXA     a mediana de VALOR do MIOLO tem de morar entre o teto do chao e o
##             piso do ator: abaixo ela some no piso, acima ela vira tiro.
##
## **Um par COLIDE quando colide nos DOIS primeiros eixos**, e nao em um. A
## licao registrada e literal -- *"duas armas com a mesma COR e a mesma FORMA
## sao a mesma arma"* --, e a conjuncao e o que ela diz: o anel claro e o anel
## escuro dividem silhueta e continuam sendo duas pecas. O que a regua NUNCA
## aceita como defesa e o matiz, e e por isso que o segundo eixo e medido em
## cinza. Par que colide num eixo so sai como ATENCAO: ele nao reprova a
## entrega, mas e onde a proxima peca vai encostar.
##
## DOIS MODOS, e o modo sai do DisplayServer e nao de uma bandeira, como no
## `laboratorio_projeteis.gd`:
##
##   godot --path . tools/itens/laboratorio_icones.tscn --resolution 960x544
##     Com janela: os 16 nos tres tamanhos de leitura, a folha inteira repetida
##     sobre N0 e sobre N1 -- o vazio e o chao base. Fotografa e encerra.
##
##   godot --headless --path . tools/itens/laboratorio_icones.tscn
##     Sem janela: o auto-teste, a tabela por peca, a matriz de IoU e a lista de
##     colisoes. Encerra com 1 se houver alguma.
##
## Argumentos, sempre depois de um `--` isolado:
##   --ficar       com janela, nao fecha depois da foto
##   --sinteticas  passa as pecas do auto-teste pelo RELATORIO inteiro, no lugar
##                 do disco. E a prova de que a esteira toda morde -- a matriz, a
##                 lista de colisoes e o CODIGO DE SAIDA --, e nao so o
##                 auto-teste: a familia tem um par identico de proposito, entao
##                 esta invocacao SEMPRE encerra com 1.
##
## **O AUTO-TESTE RODA SEMPRE**, com ou sem arte. Regua que nunca reprova e
## carimbo, e enquanto nao ha um unico icone em disco ele e a UNICA prova de que
## esta regua morde: as pecas sinteticas desenhadas em codigo cobram os tres
## eixos nos dois sentidos -- o que tem de reprovar reprova, o que tem de passar
## passa. Ele tambem imprime a CALIBRACAO de onde `TETO_IOU` saiu, entao o
## numero continua conferivel a cada execucao em vez de virar prosa.
##
## ENCERRA EM TODO CAMINHO DE SAIDA: cena headless que nao encerra vira runaway,
## e um `runner.tscn` esquecido ja acumulou 1574 s de CPU em tres horas girando
## num nucleo.

## As pastas de icone que a matriz varre, e o `.tres` de onde sai a cor de cada
## peca.
##
## **As duas familias entram na MESMA matriz, e isso e o ponto.** Elas moram em
## pastas separadas porque cada uma responde pelo proprio portao de orfao em
## `teste_icones_de_item.gd` -- mas separar o DONO do arquivo nao pode virar
## separar a PERGUNTA. Item e arma dividem a prateleira da Loja, tres bancadas
## lado a lado, e e exatamente ali que dois icones viram a mesma mancha. Medir as
## familias em matrizes separadas aprovaria um par que so se encontra em jogo.
const FONTES: Array[Dictionary] = [
	{&"icones": "res://assets/itens/", &"dados": "res://src/items/",
		&"prefixo": "implante_", &"cor": &"cor"},
	{&"icones": "res://assets/armas/", &"dados": "res://src/weapons/",
		&"prefixo": "", &"cor": &"cor_projetil"},
]
const PREFIXO_ICONE := "icone_"
const SAIDA := "user://capturas"

## Os quatro contextos em que um icone de 64 px e lido, em pixels de TELA.
##
## Eles nao sao suposicao: cada um sai de uma const do consumidor.
##   64  o arquivo, e o cartao
##   32  o chao          -- `PickupItem.ESCALA_ICONE` (0,5 sobre 64)
##   32  a bancada       -- `BancadaDeOferta.ICONE_LADO`
##   16  a bandeja da HUD -- `BandejaImplantes`, um quarto exato
const TAMANHOS_DE_LEITURA: Array[int] = [64, 32, 16]

## A silhueta e o cinza sao medidos no PIOR contexto, e nao no arquivo.
##
## **O pior contexto e a BANDEJA, e ela desenha a 16.** Esta const dizia 32, e
## dizia isso porque foi escrita ANTES dos consumidores existirem -- a bandeja da
## HUD acabou em 16 px, um quarto exato do arquivo, que e a maior reducao que a
## grade aceita sem reamostrar. Uma regua que mede num tamanho e um jogo que
## desenha noutro e um portao verde sobre uma pergunta que ninguem fez.
##
## 16 domina 32 nos DOIS eixos, e por isso medir so nele basta: celula maior
## borra silhueta (mais interseccao) e faz media de cinza sobre mais pixels
## (menos diferenca). Medido nos 16 icones: a 32 px o pior par da IoU 0,85 com
## 0,121 de cinza; a 16 px da IoU 0,84 com **0,094** -- o mesmo empate de forma
## com a folga de cinza encolhendo, que e o eixo que decide colisao.
##
## E a bandeja e o contexto mais duro tambem por outra razao: e o unico em que os
## icones aparecem em CONJUNTO, lado a lado, onde a pergunta deixa de ser "este le?"
## e vira "estes dois sao a mesma coisa?".
const LADO_MEDIDO := 16

## Acima disto, duas mascaras de alfa sao a mesma forma.
##
## Sai da CALIBRACAO que o auto-teste imprime a cada execucao, e nao de gosto.
## Medido a 32 px nas cinco formas sinteticas: os dez pares que o projeto aceita
## como diferentes ficam entre **0,241** (triangulo x anel) e **0,630** (circulo
## x anel), e o par identico da 1,000. Sobra um vao, e a unica coisa dentro dele
## e quadrado x circulo, em **0,799** -- que a 32 px de leitura E a mesma mancha,
## e por isso fica do lado de fora junto com o par identico. 0,70 e o meio desse
## vao. Numero escrito a mao envelhece; por isso a calibracao roda a cada
## execucao em vez de morar numa planilha.
const TETO_IOU := 0.70

## Piso da faixa de valor: o teto de valor do CHAO.
##
## Gemeo de `teste_texturas.TETO_VALOR[&"chao"]`, que e decisao registrada -- o
## andar 1 foi para o azul, o matiz parou de separar mapa de ator e sobrou o
## valor. Um icone cuja mediana de miolo mora abaixo do teto do piso nao some
## por ser escuro: some por ser a MESMA coisa que o chao.
const PISO_VALOR_MIOLO := 0.30

## Teto da faixa de valor: o piso de valor do ATOR (portao G2 da `Paleta`).
##
## Acima dele, e saturado, e a definicao literal de "compete com ator" -- a
## linguagem de "isto e um tiro". Um pickup brilhante demais no chao de uma sala
## de combate e um projetil parado. Os 0,25 entre este numero e o de cima sao a
## mesma folga que o comentario do teto do chao ja declara.
const TETO_VALOR_MIOLO := Paleta.LIMITE_VALOR

## Fracao do miolo que pode competir com ator antes de a peca VIRAR ator.
##
## Gemeo de `teste_texturas.PISO_COMPETE`, e usado ao contrario: la ele e o PISO
## que a arte de projetil tem de alcancar para ler como tiro; aqui e o TETO que o
## icone nao pode alcancar, pelo mesmo motivo e com o mesmo numero. Duas reguas
## com o mesmo limiar em sentidos opostos e o mesmo desenho de `_regra_de_ator()`
## contra `_regra_de_gamut()`, que sao funcoes irmas pela mesma razao.
const TETO_COMPETE := 0.7

## Alfa a partir do qual um pixel conta como desenho. Gemeo do 0,5 de
## `teste_texturas._e_miolo()`: PNG e RGBA8, e meio alfa e o unico corte que nao
## depende de como a ferramenta escreveu a borda.
const ALFA_OPACO := 0.5

## A grade da folha com janela. Quatro colunas por metade, 960x544 no total.
const CELULA := Vector2(112.0, 130.0)
const COLUNAS := 4
const MARGEM := Vector2(8.0, 18.0)

## A tela das pecas sinteticas. 64 e o tamanho do icone que vai existir, e medir
## a regua contra outro tamanho mediria a reducao em vez da regua.
const LADO_SINTETICO := 64
const MARGEM_SINTETICA := 6


## Uma peca medida: a imagem crua mais as reducoes que a regua compara.
class Peca:
	extends RefCounted

	var id: String = ""
	var imagem: Image = null
	var cor_declarada: Color = Color.WHITE
	## LADO_MEDIDO x LADO_MEDIDO, 1 onde a celula e desenho.
	var mascara: PackedByteArray = PackedByteArray()
	## LADO_MEDIDO x LADO_MEDIDO, a luma da celula composta sobre o chao.
	var cinza: PackedFloat32Array = PackedFloat32Array()
	var opacos: int = 0
	var miolo: int = 0
	var valor_mediano: float = 0.0
	var luma_mediana: float = 0.0
	var fracao_compete: float = 0.0


func _ready() -> void:
	# Um frame antes de qualquer coisa, pelo mesmo motivo que o `runner.gd`:
	# `quit()` chamado de dentro do `_ready` nao encerra confiavelmente, e cena
	# headless que nao encerra vira runaway.
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		_medir()
		return
	await _montar_folha()


# -- modo headless ----------------------------------------------------------


func _medir() -> void:
	var falhas := 0
	falhas += _auto_teste()

	var pecas := _familia_sintetica() if _tem("--sinteticas") else _pecas_do_disco()
	if pecas.is_empty():
		print("\n--- os icones em disco ---\n")
		var pastas: Array[String] = []
		for fonte in FONTES:
			pastas.append(fonte[&"icones"])
		print("  nenhum %s*.png em %s -- so o auto-teste rodou."
			% [PREFIXO_ICONE, ", ".join(pastas)])
		_encerrar(falhas)
		return

	falhas += _tabela_por_peca(pecas)
	_matriz_de_iou(pecas)
	falhas += _colisoes(pecas)
	_encerrar(falhas)


func _encerrar(falhas: int) -> void:
	print("\n--- resultado ---")
	if falhas > 0:
		print("  FALHOU: %d problema(s)" % falhas)
		get_tree().quit(1)
		return
	print("  PASSOU")
	get_tree().quit()


## A tabela peca a peca. So a FAIXA DE VALOR reprova aqui -- silhueta e cinza nao
## existem para uma peca sozinha, que e a razao de ser deste arquivo.
func _tabela_por_peca(pecas: Array[Peca]) -> int:
	print("\n--- as pecas, uma a uma (faixa de valor %.2f a %.2f no MIOLO) ---\n"
		% [PISO_VALOR_MIOLO, TETO_VALOR_MIOLO])
	print("%-22s %6s %6s %7s %7s %8s  %s" % [
		"icone", "px", "miolo", "valor", "luma", "compete", "veredito"
	])
	print("-".repeat(84))
	var falhas := 0
	for p in pecas:
		var motivos: Array[String] = []
		if p.miolo == 0:
			# Miolo vazio e peca so de contorno: ela nao passa por omissao,
			# reprova -- um icone que e so borda nao tem o que acender.
			motivos.append("so contorno")
		else:
			if p.valor_mediano < PISO_VALOR_MIOLO:
				motivos.append("deitado no chao")
			if p.valor_mediano > TETO_VALOR_MIOLO:
				motivos.append("acima do ator")
			if p.fracao_compete > TETO_COMPETE:
				motivos.append("vira tiro")
		if not motivos.is_empty():
			falhas += 1
		print("%-22s %6d %6d %7.3f %7.3f %7.0f%%  %s" % [
			p.id, p.opacos, p.miolo, p.valor_mediano, p.luma_mediana,
			p.fracao_compete * 100.0,
			"ok" if motivos.is_empty() else "FALHA: " + ", ".join(motivos),
		])
	return falhas


## A matriz de IoU. Ela e o entregavel para quem desenha: cada linha diz de quem
## aquela peca precisa fugir, e nao so se ela passou.
func _matriz_de_iou(pecas: Array[Peca]) -> void:
	print("\n--- silhueta: IoU par a par a %d px (teto %.2f) ---\n"
		% [LADO_MEDIDO, TETO_IOU])
	var cabecalho := "%-22s" % ""
	for p in pecas:
		cabecalho += "%5s" % p.id.substr(0, 4)
	print(cabecalho)
	for i in pecas.size():
		var linha := "%-22s" % pecas[i].id
		for j in pecas.size():
			if i == j:
				linha += "    ."
				continue
			linha += "%5.2f" % _iou(pecas[i], pecas[j])
		print(linha)


func _colisoes(pecas: Array[Peca]) -> int:
	var piso_cinza := _piso_de_cinza()
	print("\n--- colisoes de leitura (IoU >= %.2f E cinza < %.3f) ---\n"
		% [TETO_IOU, piso_cinza])
	var colisoes := 0
	var atencao := 0
	var pares := 0
	for i in pecas.size():
		for j in range(i + 1, pecas.size()):
			pares += 1
			var iou := _iou(pecas[i], pecas[j])
			var cinza := _distancia_de_cinza(pecas[i], pecas[j])
			var mesma_forma := iou >= TETO_IOU
			var mesmo_tom := cinza < piso_cinza
			if mesma_forma and mesmo_tom:
				colisoes += 1
				print("  COLIDE   IoU %.2f  cinza %.3f  %s x %s"
					% [iou, cinza, pecas[i].id, pecas[j].id])
			elif mesma_forma or mesmo_tom:
				atencao += 1
				print("  atencao  IoU %.2f  cinza %.3f  %s x %s  (%s)"
					% [iou, cinza, pecas[i].id, pecas[j].id,
						"mesma forma" if mesma_forma else "mesmo tom"])
	print("\n  %d par(es) medidos, %d colisao(oes), %d atencao(oes)"
		% [pares, colisoes, atencao])
	# Zero par medido e suspeito pela mesma razao que no laboratorio de
	# projeteis: uma regua que nao mediu nada nao aprovou nada.
	if pares == 0:
		print("  nenhum par medido -- a regua nao olhou para nada")
	return colisoes


# -- o auto-teste: a prova de que a regua morde ------------------------------


## As pecas sinteticas, e a regua aplicada a elas.
##
## Enquanto nao houver um unico icone em disco, isto e a unica prova de que esta
## regua reprova alguma coisa. Ele morde nos DOIS sentidos em cada eixo: o caso
## que tem de reprovar reprova, e o que tem de passar passa. So o segundo deixa a
## regua honesta -- uma que reprovasse tudo estaria medindo a si mesma, que foi
## exatamente o que a primeira versao da `MedidorEscape` fez ao reprovar as cinco
## combinacoes de inimigo.
func _auto_teste() -> int:
	print("\n--- auto-teste: a regua reprova? ---\n")

	# Duas cores DENTRO da faixa de valor, para o auto-teste de PAR nao ser
	# contaminado pelo de FAIXA. A segunda e o matiz oposto da primeira rebaixado
	# ate a MESMA luma: e o caso que prova que matiz nao salva par nenhum, que e
	# a razao de o segundo eixo ser medido em cinza.
	var tinta := Color.from_hsv(0.52, 0.55, 0.45)
	var oposta := _com_luma(Color.from_hsv(0.02, 0.55, 0.45), _luma(tinta))

	var quadrado := _peca_sintetica("quadrado", _desenho_quadrado(tinta))
	var copia := _peca_sintetica("quadrado_copia", _desenho_quadrado(tinta))
	var trocado := _peca_sintetica("quadrado_oposto", _desenho_quadrado(oposta))
	var triangulo := _peca_sintetica("triangulo", _desenho_triangulo(tinta))
	var circulo := _peca_sintetica("circulo", _desenho_circulo(tinta))
	var anel := _peca_sintetica("anel", _desenho_anel(tinta))
	var cruz := _peca_sintetica("cruz", _desenho_cruz(tinta))

	print("  calibracao de TETO_IOU -- as formas que o projeto aceita como")
	print("  diferentes, medidas a %d px:" % LADO_MEDIDO)
	var calibracao: Array[Peca] = [quadrado, circulo, triangulo, anel, cruz]
	for i in calibracao.size():
		for j in range(i + 1, calibracao.size()):
			print("    %-10s x %-10s  IoU %.3f" % [
				calibracao[i].id, calibracao[j].id, _iou(calibracao[i], calibracao[j])
			])
	print("    par identico                IoU %.3f" % _iou(quadrado, copia))
	print("    (TETO_IOU = %.2f mora no vao entre os dois grupos)" % TETO_IOU)

	var piso_cinza := _piso_de_cinza()
	print("\n  piso de cinza, o degrau mediano da rampa neutra: %.4f\n" % piso_cinza)

	var falhas := 0
	falhas += _cobrar(
		_colidem(quadrado, copia),
		"dois quadrados identicos COLIDEM (IoU %.2f, cinza %.3f)"
			% [_iou(quadrado, copia), _distancia_de_cinza(quadrado, copia)]
	)
	falhas += _cobrar(
		not _colidem(quadrado, triangulo),
		"quadrado e triangulo NAO colidem (IoU %.2f, cinza %.3f)"
			% [_iou(quadrado, triangulo), _distancia_de_cinza(quadrado, triangulo)]
	)
	falhas += _cobrar(
		_colidem(quadrado, trocado),
		"matiz oposto nao salva: mesma forma, mesmo cinza (IoU %.2f, cinza %.3f)"
			% [_iou(quadrado, trocado), _distancia_de_cinza(quadrado, trocado)]
	)

	# A faixa de valor, tambem nos dois sentidos.
	var escura := _peca_sintetica(
		"escura", _desenho_quadrado(Color.from_hsv(0.52, 0.55, 0.12))
	)
	var acesa := _peca_sintetica(
		"acesa", _desenho_quadrado(Color.from_hsv(0.52, 0.90, 0.95))
	)
	falhas += _cobrar(
		escura.valor_mediano < PISO_VALOR_MIOLO,
		"peca escura demais REPROVA a faixa (valor %.3f, piso %.2f)"
			% [escura.valor_mediano, PISO_VALOR_MIOLO]
	)
	falhas += _cobrar(
		acesa.valor_mediano > TETO_VALOR_MIOLO and acesa.fracao_compete > TETO_COMPETE,
		"peca acesa demais REPROVA a faixa e vira tiro (valor %.3f, compete %.0f%%)"
			% [acesa.valor_mediano, acesa.fracao_compete * 100.0]
	)
	falhas += _cobrar(
		quadrado.valor_mediano >= PISO_VALOR_MIOLO
			and quadrado.valor_mediano <= TETO_VALOR_MIOLO
			and quadrado.fracao_compete <= TETO_COMPETE,
		"peca no meio da faixa PASSA (valor %.3f, compete %.0f%%)"
			% [quadrado.valor_mediano, quadrado.fracao_compete * 100.0]
	)
	falhas += _cobrar(
		anel.miolo > 0 and cruz.miolo > 0,
		"forma vazada e forma fina ainda tem miolo (anel %d px, cruz %d px)"
			% [anel.miolo, cruz.miolo]
	)
	return falhas


func _cobrar(condicao: bool, descricao: String) -> int:
	print("  %s %s" % ["[ok]   " if condicao else "[FALHA]", descricao])
	return 0 if condicao else 1


func _colidem(a: Peca, b: Peca) -> bool:
	return _iou(a, b) >= TETO_IOU and _distancia_de_cinza(a, b) < _piso_de_cinza()


# -- as tres medidas --------------------------------------------------------


## Sobreposicao das duas mascaras de alfa: intersecao sobre uniao.
##
## E o mesmo criterio que `_a_arte_de_projetil_nao_repete_silhueta` aplica as
## armas, com uma diferenca que importa: la a forma e DECLARADA (a familia de
## silhueta mora no `.tres`) e aqui ela precisa ser lida do pixel, porque um
## icone nao declara nada sobre a propria forma.
func _iou(a: Peca, b: Peca) -> float:
	var intersecao := 0
	var uniao := 0
	for i in a.mascara.size():
		var x := a.mascara[i] == 1
		var y := b.mascara[i] == 1
		if x and y:
			intersecao += 1
		if x or y:
			uniao += 1
	if uniao == 0:
		return 0.0
	return float(intersecao) / float(uniao)


## Diferenca media de luma, contada so onde ao menos uma das duas desenha.
##
## Fora da uniao das mascaras as duas pecas sao o mesmo chao por construcao, e
## incluir esse vazio dilui a conta: duas pecas pequenas e bem diferentes
## pareceriam parecidas so por sobrar margem em volta das duas.
func _distancia_de_cinza(a: Peca, b: Peca) -> float:
	var soma := 0.0
	var celulas := 0
	for i in a.mascara.size():
		if a.mascara[i] == 0 and b.mascara[i] == 0:
			continue
		soma += absf(a.cinza[i] - b.cinza[i])
		celulas += 1
	if celulas == 0:
		return 0.0
	return soma / float(celulas)


## O degrau MEDIANO da rampa neutra da `Paleta`, em luma.
##
## Calculado e nao escrito. A rampa N0..N7 e a quantizacao de luminancia que o
## proprio projeto usa para dizer "isto e outro tom": duas pecas que diferem, em
## media, menos que um degrau dela nao diferem em tom nenhum que esta paleta
## reconheca. Um literal aqui envelheceria em silencio no dia em que a rampa
## mudasse -- a mesma armadilha do `MATIZ_POR_TIPO` copiado em dois arquivos.
func _piso_de_cinza() -> float:
	var lumas: Array[float] = []
	for chave in Paleta.NEUTROS:
		lumas.append(_luma(Paleta.NEUTROS[chave] as Color))
	lumas.sort()
	var degraus: Array[float] = []
	for i in range(1, lumas.size()):
		degraus.append(lumas[i] - lumas[i - 1])
	degraus.sort()
	if degraus.is_empty():
		return 0.0
	return degraus[degraus.size() / 2]


# -- reducao de uma imagem a peca -------------------------------------------


func _peca_sintetica(id: String, imagem: Image) -> Peca:
	return _medir_peca(id, imagem, Color.WHITE)


func _medir_peca(id: String, imagem: Image, cor_declarada: Color) -> Peca:
	var p := Peca.new()
	p.id = id
	p.imagem = imagem
	p.cor_declarada = cor_declarada
	p.mascara.resize(LADO_MEDIDO * LADO_MEDIDO)
	p.cinza.resize(LADO_MEDIDO * LADO_MEDIDO)

	var fundo: Color = Paleta.neutro(&"N1")
	var l := imagem.get_width()
	var a := imagem.get_height()
	for cy in LADO_MEDIDO:
		for cx in LADO_MEDIDO:
			var x0 := cx * l / LADO_MEDIDO
			var x1 := maxi(x0 + 1, (cx + 1) * l / LADO_MEDIDO)
			var y0 := cy * a / LADO_MEDIDO
			var y1 := maxi(y0 + 1, (cy + 1) * a / LADO_MEDIDO)
			var cobertos := 0
			var total := 0
			var soma_luma := 0.0
			for y in range(y0, mini(y1, a)):
				for x in range(x0, mini(x1, l)):
					var cor := imagem.get_pixel(x, y)
					total += 1
					if cor.a >= ALFA_OPACO:
						cobertos += 1
					# Composta sobre o chao, porque e assim que o jogador ve: um
					# icone vazado deixa o piso aparecer no meio dele, e esse
					# buraco e parte do cinza que ele mostra.
					soma_luma += _luma(cor.lerp(fundo, 1.0 - cor.a))
			var i := cy * LADO_MEDIDO + cx
			# A celula e desenho quando METADE dos pixels de origem sao opacos.
			# Reduzir por vizinho mais proximo jogaria fora tres de cada quatro
			# pixels de um icone de 64 px, e a silhueta mudaria de forma no
			# caminho -- a regua estaria medindo a reducao, e nao a arte.
			p.mascara[i] = 1 if total > 0 and cobertos * 2 >= total else 0
			p.cinza[i] = soma_luma / float(maxi(total, 1))

	_medir_miolo(p)
	return p


## O MIOLO, e nao o sprite inteiro.
##
## Gemeo de `teste_texturas._e_miolo()`: pixel opaco cujos quatro vizinhos tambem
## sao opacos. Pixel art tem contorno escuro, e o contorno e justamente o que
## separa a peca do fundo -- cobrar valor dele seria proibir contorno, ou seja,
## proibir pixel art. Medido la: 47% dos pixels de um sprite de 32 px eram
## contorno, e um piso sobre o total reprovava arte legitima pelo motivo errado.
func _medir_miolo(p: Peca) -> void:
	var valores: Array[float] = []
	var lumas: Array[float] = []
	var compete := 0
	var l := p.imagem.get_width()
	var a := p.imagem.get_height()
	for y in a:
		for x in l:
			var cor := p.imagem.get_pixel(x, y)
			if cor.a < ALFA_OPACO:
				continue
			p.opacos += 1
			if not _e_miolo(p.imagem, x, y):
				continue
			p.miolo += 1
			valores.append(cor.v)
			lumas.append(_luma(cor))
			if Paleta.compete_com_ator(cor):
				compete += 1
	valores.sort()
	lumas.sort()
	# MEDIANA e nao media: um icone com um ponto de luz aceso e outro lavado de
	# claro teriam a mesma media, e so um dos dois vira tiro.
	p.valor_mediano = 0.0 if valores.is_empty() else valores[valores.size() / 2]
	p.luma_mediana = 0.0 if lumas.is_empty() else lumas[lumas.size() / 2]
	p.fracao_compete = 0.0 if p.miolo == 0 else float(compete) / float(p.miolo)


func _e_miolo(imagem: Image, x: int, y: int) -> bool:
	if x <= 0 or y <= 0 or x >= imagem.get_width() - 1 or y >= imagem.get_height() - 1:
		return false
	return (
		imagem.get_pixel(x - 1, y).a >= ALFA_OPACO
		and imagem.get_pixel(x + 1, y).a >= ALFA_OPACO
		and imagem.get_pixel(x, y - 1).a >= ALFA_OPACO
		and imagem.get_pixel(x, y + 1).a >= ALFA_OPACO
	)


## Gemea de `AssinaturaDeSuperficie._luma()` e do `luma()` de
## `preparar_textura.py`. Copiada em vez de chamada porque aquela e privada da
## outra classe; a formula ja e declarada gemea em tres lugares, como o
## `LIMIAR_DETALHE` ao lado dela, e muda nos quatro no dia em que mudar.
func _luma(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


## A mesma cor rebaixada ate uma luma alvo. Luma e linear em RGB, entao escalar
## os tres canais juntos preserva matiz e saturacao exatamente -- que e o que o
## caso "matiz oposto nao salva o par" precisa para nao provar outra coisa.
func _com_luma(cor: Color, alvo: float) -> Color:
	var atual := _luma(cor)
	if atual <= 0.0:
		return cor
	var k := alvo / atual
	return Color(minf(cor.r * k, 1.0), minf(cor.g * k, 1.0), minf(cor.b * k, 1.0), cor.a)


# -- as pecas do disco ------------------------------------------------------


## Os icones em disco, lidos da PASTA -- nunca de lista fixa, pelo mesmo motivo
## que `_dono_de_cada_arte()` le os `.tres` de arma em vez de uma tabela.
##
## A cor declarada vem do `.tres` do implante de mesmo id, quando existe. Ela nao
## entra em medida nenhuma -- matiz nunca defende um par -- mas aparece na folha
## com janela e no relatorio.
func _pecas_do_disco() -> Array[Peca]:
	var fora: Array[Peca] = []
	for fonte in FONTES:
		var caminho: String = fonte[&"icones"]
		var pasta := DirAccess.open(caminho)
		if pasta == null:
			continue
		var arquivos := pasta.get_files()
		arquivos.sort()
		var cores := _cor_de_cada_peca(fonte)
		for arquivo in arquivos:
			if not arquivo.begins_with(PREFIXO_ICONE) or not arquivo.ends_with(".png"):
				continue
			var id := arquivo.get_basename().substr(PREFIXO_ICONE.length())
			var imagem := _carregar_png(caminho + arquivo)
			if imagem == null:
				print("  %s nao carrega" % arquivo)
				continue
			fora.append(_medir_peca(id, imagem, cores.get(id, Color.WHITE) as Color))
	return fora


## A cor declarada de cada peca de uma fonte.
##
## Ela nao entra em medida nenhuma -- matiz nunca defende um par -- mas aparece
## na folha com janela e no relatorio. O campo e perguntado por nome porque
## `DadosItem` guarda `cor` e `DadosArma` guarda `cor_projetil`, e os dois nao tem
## base comum.
func _cor_de_cada_peca(fonte: Dictionary) -> Dictionary:
	var fora := {}
	var caminho: String = fonte[&"dados"]
	var prefixo: String = fonte[&"prefixo"]
	var campo: StringName = fonte[&"cor"]
	var pasta := DirAccess.open(caminho)
	if pasta == null:
		return fora
	for arquivo in pasta.get_files():
		if not arquivo.begins_with(prefixo) or not arquivo.ends_with(".tres"):
			continue
		var dados := load(caminho + arquivo) as Resource
		if dados == null:
			continue
		var cor: Variant = dados.get(campo)
		if cor is Color:
			fora[arquivo.get_basename().trim_prefix(prefixo)] = cor
	return fora


func _carregar_png(caminho: String) -> Image:
	if not FileAccess.file_exists(caminho):
		return null
	# Caminho absoluto de proposito, como em `teste_texturas._carregar_png()`:
	# `load_from_file` com `res://` avisa que "nao funciona no export", e aqui e
	# exatamente o PNG fonte que se quer ler.
	var imagem := Image.load_from_file(ProjectSettings.globalize_path(caminho))
	if imagem == null or imagem.is_empty():
		return null
	imagem.convert(Image.FORMAT_RGBA8)
	return imagem


# -- as pecas sinteticas ----------------------------------------------------


## A familia que substitui o disco enquanto nao ha arte.
##
## Ela tem um par IDENTICO de proposito: e o que faz `--sinteticas` reprovar
## sempre, provando a esteira inteira -- matriz, colisoes e codigo de saida --
## sem depender de arte que ainda nao existe e sem escrever um PNG de mentira
## dentro de `assets/`, que e onde a arte de verdade vai morar.
func _familia_sintetica() -> Array[Peca]:
	var tinta := Color.from_hsv(0.52, 0.55, 0.45)
	var oposta := _com_luma(Color.from_hsv(0.02, 0.55, 0.45), _luma(tinta))
	return [
		_peca_sintetica("quadrado", _desenho_quadrado(tinta)),
		_peca_sintetica("quadrado_copia", _desenho_quadrado(tinta)),
		_peca_sintetica("quadrado_oposto", _desenho_quadrado(oposta)),
		_peca_sintetica("circulo", _desenho_circulo(tinta)),
		_peca_sintetica("triangulo", _desenho_triangulo(tinta)),
		_peca_sintetica("anel", _desenho_anel(tinta)),
		_peca_sintetica("cruz", _desenho_cruz(tinta)),
	]


func _tela_vazia() -> Image:
	var img := Image.create_empty(LADO_SINTETICO, LADO_SINTETICO, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	return img


func _desenho_quadrado(cor: Color) -> Image:
	var img := _tela_vazia()
	for y in range(MARGEM_SINTETICA, LADO_SINTETICO - MARGEM_SINTETICA):
		for x in range(MARGEM_SINTETICA, LADO_SINTETICO - MARGEM_SINTETICA):
			img.set_pixel(x, y, cor)
	return img


func _desenho_triangulo(cor: Color) -> Image:
	var img := _tela_vazia()
	var lado := LADO_SINTETICO - 2 * MARGEM_SINTETICA
	for j in lado:
		var largura := int(round(float(j + 1) / float(lado) * float(lado)))
		var x0 := MARGEM_SINTETICA + (lado - largura) / 2
		for x in range(x0, x0 + largura):
			img.set_pixel(x, MARGEM_SINTETICA + j, cor)
	return img


func _desenho_circulo(cor: Color) -> Image:
	var img := _tela_vazia()
	var centro := float(LADO_SINTETICO) * 0.5 - 0.5
	var raio := float(LADO_SINTETICO) * 0.5 - float(MARGEM_SINTETICA)
	for y in LADO_SINTETICO:
		for x in LADO_SINTETICO:
			if Vector2(float(x) - centro, float(y) - centro).length() <= raio:
				img.set_pixel(x, y, cor)
	return img


func _desenho_anel(cor: Color) -> Image:
	var img := _desenho_circulo(cor)
	var centro := float(LADO_SINTETICO) * 0.5 - 0.5
	var interno := float(LADO_SINTETICO) * 0.5 - float(MARGEM_SINTETICA) - 10.0
	for y in LADO_SINTETICO:
		for x in LADO_SINTETICO:
			if Vector2(float(x) - centro, float(y) - centro).length() <= interno:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	return img


func _desenho_cruz(cor: Color) -> Image:
	var img := _tela_vazia()
	var meio := LADO_SINTETICO / 2
	var braco := 6
	for y in range(MARGEM_SINTETICA, LADO_SINTETICO - MARGEM_SINTETICA):
		for x in range(meio - braco, meio + braco):
			img.set_pixel(x, y, cor)
	for x in range(MARGEM_SINTETICA, LADO_SINTETICO - MARGEM_SINTETICA):
		for y in range(meio - braco, meio + braco):
			img.set_pixel(x, y, cor)
	return img


# -- modo janela ------------------------------------------------------------


## A folha inteira duas vezes: metade esquerda sobre N0 (o vazio, a sombra
## profunda), metade direita sobre N1 (o chao base). Sao os dois fundos em que um
## icone cai de fato, e uma peca so passa quando le nos DOIS -- arte calibrada
## contra um fundo so e arte que some no outro.
func _montar_folha() -> void:
	DirAccess.make_dir_recursive_absolute(SAIDA)

	var pecas := _pecas_do_disco() if not _tem("--sinteticas") else _familia_sintetica()
	var sinteticas := pecas.is_empty()
	if sinteticas:
		# Folha vazia nao mostra nada e nao ensina nada: sem arte, a janela
		# exibe as pecas do auto-teste, que sao as mesmas que a regua mediu.
		pecas = _familia_sintetica()

	var quadro := get_viewport().get_visible_rect().size
	_pintar(Rect2(Vector2.ZERO, Vector2(quadro.x * 0.5, quadro.y)), Paleta.neutro(&"N0"))
	_pintar(
		Rect2(Vector2(quadro.x * 0.5, 0.0), Vector2(quadro.x * 0.5, quadro.y)),
		Paleta.neutro(&"N1")
	)
	_rotulo(Vector2(8.0, 2.0), "N0 -- o vazio")
	_rotulo(Vector2(quadro.x * 0.5 + 8.0, 2.0), "N1 -- o chao base")

	for metade in 2:
		var origem := Vector2(quadro.x * 0.5 * float(metade), 0.0) + MARGEM
		for i in pecas.size():
			var celula := origem + Vector2(
				float(i % COLUNAS) * CELULA.x, float(i / COLUNAS) * CELULA.y
			)
			_desenhar_peca(pecas[i], celula)

	if sinteticas:
		_rotulo(
			Vector2(8.0, quadro.y - 16.0),
			"sem arte em disco: as pecas do auto-teste, nos tres tamanhos de leitura"
		)
	await _fotografar()


## Uma peca nos tres tamanhos: 64 no cartao, 48 na bancada da Loja, 32 no chao e
## na bandeja da HUD. Os dois menores ficam lado a lado embaixo do maior, porque
## a comparacao que interessa e entre CELULAS e nao dentro de uma.
func _desenhar_peca(p: Peca, canto: Vector2) -> void:
	_rotulo(canto, p.id.substr(0, 14))
	var textura := ImageTexture.create_from_image(p.imagem)
	var x := canto.x
	var y := canto.y + 14.0
	for k in TAMANHOS_DE_LEITURA.size():
		var tamanho: int = TAMANHOS_DE_LEITURA[k]
		var s := Sprite2D.new()
		s.texture = textura
		s.centered = false
		# Nearest: reescalar pixel art com filtro borra, e o que se julga aqui e
		# a silhueta e nao o borrao.
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2.ONE * (float(tamanho) / float(maxi(p.imagem.get_width(), 1)))
		s.position = Vector2(x, y)
		add_child(s)
		if k == 0:
			y += float(tamanho) + 2.0
		else:
			x += float(tamanho) + 4.0
	return


func _pintar(onde: Rect2, cor: Color) -> void:
	var r := ColorRect.new()
	r.color = cor
	r.position = onde.position
	r.size = onde.size
	add_child(r)


## `Label` e nao `Label2D`: este build do Godot nao tem o segundo, e uma cena de
## ferramenta que nao PARSEIA fica pendurada para sempre -- o parse error
## acontece antes de qualquer `quit()` que este arquivo escreva.
func _rotulo(onde: Vector2, texto: String) -> void:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.position = onde
	etiqueta.add_theme_font_size_override("font_size", 10)
	etiqueta.modulate = Color(1.0, 1.0, 1.0, 0.75)
	add_child(etiqueta)


func _fotografar() -> void:
	if _tem("--ficar"):
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var caminho := "%s/icones.png" % SAIDA
	get_viewport().get_texture().get_image().save_png(caminho)
	print("capturado: %s" % ProjectSettings.globalize_path(caminho))
	get_tree().quit()


# -- helpers ----------------------------------------------------------------


## Le de `get_cmdline_user_args()` -- o que vem DEPOIS do `--` --, que e o unico
## lugar onde um argumento nosso nao briga com uma opcao do proprio Godot.
func _tem(bandeira: String) -> bool:
	return OS.get_cmdline_user_args().has(bandeira)
