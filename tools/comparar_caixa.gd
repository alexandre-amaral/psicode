extends Node2D
## A prova A/B do epico da CAIXA: o perfil de hoje contra o alvo, e SO OS DOIS.
##
## **Duas colunas, nao cinco presets.** A secao 77 do plano e explicita sobre
## isso, e a razao e a historia deste epico: cada rodada de presets produziu uma
## direcao NOVA em vez de decidir a que estava na mesa. Uma matriz convida a
## inventar um sexto perfil; um par obriga a responder "qual dos dois?".
##
##     ESQUERDA   o perfil assimetrico -- norte 60, lateral 40, sul 36
##     DIREITA    a caixa -- corpo 48, cap 12, sombra 4, chanfro 48, nos quatro
##
## **A esquerda e RECONSTRUIDA pelos `escala_*`, e isso e uma aproximacao
## declarada.** Os nove campos do modelo antigo sairam do recurso -- era esse o
## entregavel da CAIXA 01 --, entao a unica forma de remonta-lo hoje e escalar o
## corpo por lado. A lateral sai 40 onde media 36 e o sul 36 onde media 32,
## porque o cap de 12 nao escala junto. A DIFERENCA que a comparacao existe para
## mostrar e maior que esses 4 px, e a foto congelada em `baseline_assimetrico/`
## guarda o estado exato para quem quiser conferir.
##
## ## Sem textura primeiro, e isso nao e economia
##
## A secao 37 manda comparar em cores chapadas antes de vestir arte. Se a sala
## nao parecer uma caixa grossa com piso azul escuro, corpo cinza medio, cap
## cinza claro e sombra quase preta, a arte estaria COMPENSANDO a geometria -- e
## "compensar com textura" e o item mais repetido da lista do que nao fazer.
##
## Sem janela ela MEDE e imprime a tabela; com janela ela fotografa os pares e as
## reducoes de 25% e 10% que as secoes 38 e 47 pedem.

const CENA := "res://src/mapa/sala_1_retangular.tscn"

## As duas colunas, e o `null` da direita quer dizer "o perfil de producao".
##
## Escalar o corpo e o UNICO jeito de o recurso novo produzir assimetria, e e
## deliberado: a assimetria virou uma declaracao visivel em vez de nove campos
## que divergem por descuido.
const ESCALAS_DE_HOJE := {"norte": 1.0, "sul": 0.5, "leste": 0.5833, "oeste": 0.5833}

## A paleta da secao 37, e os valores sao os que ela pede.
##
## Piso azul escuro, corpo cinza medio, cap cinza claro, sombra quase preta,
## vazio preto. Em cores chapadas nao ha onde uma parede fina se esconder: a
## pergunta deixa de ser "que material e esse?" e passa a ser "ha massa nos
## quatro lados?".
const PALETA_DE_PROVA := {
	RenderizadorParedes.COR_FACE: Color(0.45, 0.46, 0.50),
	RenderizadorParedes.COR_TOPO: Color(0.72, 0.73, 0.77),
	RenderizadorParedes.COR_CONTATO: Color(0.03, 0.03, 0.05, 0.9),
}
const COR_DO_PISO := Color(0.10, 0.12, 0.20)


func _ready() -> void:
	var com_janela := DisplayServer.get_name() != "headless"
	if com_janela:
		DirAccess.make_dir_recursive_absolute("user://capturas")
	print("\n=== A CAIXA: ATUAL contra ALVO ===")
	print("%s\n" % ("fotos em user://capturas" if com_janela else "medicao"))

	_medir()
	if not com_janela:
		get_tree().quit()
		return

	for solido in [true, false]:
		for posicao in EnquadramentoDeSala.POSICOES:
			var esquerda := await _fotografar("atual", posicao, solido)
			var direita := await _fotografar("alvo", posicao, solido)
			_compor(esquerda, direita, "caixa_%s_%s.png"
				% ["solido" if solido else "arte", posicao])

	# As reducoes valem sobre a coluna que se propoe: se a moldura sumir em 10%,
	# ela esta sustentada por detalhe e nao por massa.
	_reduzir("caixa_solido_norte.png")
	print("\n  pronto.")
	get_tree().quit()


## A tabela que decide, e ela e a mesma que o portao cobra.
func _medir() -> void:
	var alvo := PerfilDeParede.new()
	var atual := _perfil_de_hoje()
	print("  lado     ATUAL (corpo+cap)      ALVO (corpo+cap)")
	var lados := {
		"norte": RenderizadorParedes.Lado.NORTE,
		"sul": RenderizadorParedes.Lado.SUL,
		"leste": RenderizadorParedes.Lado.LESTE,
		"oeste": RenderizadorParedes.Lado.OESTE,
	}
	var minimo_atual := INF
	var maximo_atual := 0.0
	for nome: String in lados:
		var lado: int = lados[nome]
		var a := atual.profundidade(lado)
		var b := alvo.profundidade(lado)
		minimo_atual = minf(minimo_atual, a)
		maximo_atual = maxf(maximo_atual, a)
		print("  %-8s %4.0f px  (%2.0f + %2.0f)      %4.0f px  (%2.0f + %2.0f)"
			% [nome, a, atual.fim_da_face(lado), atual.cap,
				b, alvo.fim_da_face(lado), alvo.cap])

	# **O NUMERO QUE DECIDE E A DISPERSAO, e nao a espessura.** A secao 4 pede
	# diferenca aparente abaixo de 10%: um lado que parece acabamento ao lado de
	# outro que parece parede reprova mesmo que os dois sejam grossos.
	var dispersao := (maximo_atual - minimo_atual) / maximo_atual * 100.0
	print("\n  dispersao entre lados:  ATUAL %.0f%%   ALVO 0%%  (teto do plano: 10%%)"
		% dispersao)
	print("  vao entre duas salas:   ATUAL %.0f px       ALVO %.0f px"
		% [atual.profundidade(RenderizadorParedes.Lado.SUL)
			+ atual.profundidade(RenderizadorParedes.Lado.NORTE),
			alvo.profundidade(RenderizadorParedes.Lado.SUL)
			+ alvo.profundidade(RenderizadorParedes.Lado.NORTE)])


func _perfil_de_hoje() -> PerfilDeParede:
	var p := PerfilDeParede.new()
	p.escala_norte = ESCALAS_DE_HOJE["norte"]
	p.escala_sul = ESCALAS_DE_HOJE["sul"]
	p.escala_leste = ESCALAS_DE_HOJE["leste"]
	p.escala_oeste = ESCALAS_DE_HOJE["oeste"]
	return p


## Uma foto, no enquadramento real do jogo.
##
## `perfil_de_teste` e `silhueta_de_teste` sao escritos ANTES do `montar()`: e o
## `_ready` da sala que constroi a fita, e nao ha segunda chance depois disso --
## a mesma razao pela qual eles sao variaveis de classe e nao parametros.
func _fotografar(variante: String, posicao: String, solido: bool) -> Image:
	Sala.perfil_de_teste = null if variante == "alvo" else _perfil_de_hoje()
	Sala.silhueta_de_teste = solido
	RenderizadorParedes.paleta_de_prova = PALETA_DE_PROVA if solido else {}
	var sala := EnquadramentoDeSala.montar(self, CENA)
	if solido:
		_chapar_o_chao(sala)
	var jogador := EnquadramentoDeSala.acompanhar(self, sala)
	EnquadramentoDeSala.posicionar(jogador, sala, posicao)
	for i in 4:
		await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	var imagem := get_viewport().get_texture().get_image()
	jogador.queue_free()
	sala.queue_free()
	await get_tree().process_frame
	Sala.perfil_de_teste = null
	Sala.silhueta_de_teste = false
	RenderizadorParedes.paleta_de_prova = {}
	return imagem


## O chao tambem entra chapado, senao a prova nao e uma prova.
##
## `silhueta_de_teste` alcanca a FITA e mais nada -- e correto, porque ela existe
## para medir a parede. Mas um chao texturizado dentro de uma parede chapada
## produz a leitura oposta a que se quer: o olho vai para o unico lugar com
## detalhe, que e justamente o que nao esta em julgamento aqui.
func _chapar_o_chao(sala: Sala) -> void:
	for filho in sala.get_children():
		var poly := filho as Polygon2D
		if poly == null or poly.texture == null:
			continue
		poly.texture = null
		poly.color = COR_DO_PISO


## As duas colunas lado a lado, com um fio claro entre elas.
##
## Compor aqui e nao no viewport e proposital: duas salas na mesma janela sairiam
## em ZOOM diferente do jogo, e a comparacao passaria a ser sobre outra coisa.
func _compor(esquerda: Image, direita: Image, nome: String) -> void:
	var l := esquerda.get_width()
	var a := esquerda.get_height()
	var par := Image.create(l * 2 + 4, a, false, esquerda.get_format())
	par.fill(Color(0.6, 0.62, 0.7))
	par.blit_rect(esquerda, Rect2i(0, 0, l, a), Vector2i.ZERO)
	par.blit_rect(direita, Rect2i(0, 0, l, a), Vector2i(l + 4, 0))
	par.save_png("user://capturas/" + nome)
	print("  %s   (esquerda ATUAL, direita ALVO)" % nome)


## 25%, 10% e cinza. A moldura tem de continuar grossa nas tres.
func _reduzir(nome: String) -> void:
	var caminho := "user://capturas/" + nome
	var base := Image.load_from_file(caminho)
	if base == null:
		return
	for fracao: float in [0.25, 0.10]:
		var pequena := base.duplicate() as Image
		pequena.resize(maxi(1, int(base.get_width() * fracao)),
			maxi(1, int(base.get_height() * fracao)), Image.INTERPOLATE_BILINEAR)
		var saida := "%s_%d.png" % [nome.get_basename(), int(fracao * 100.0)]
		pequena.save_png("user://capturas/" + saida)
		print("  %s" % saida)
	var cinza := base.duplicate() as Image
	for y in cinza.get_height():
		for x in cinza.get_width():
			var c := cinza.get_pixel(x, y)
			var v := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			cinza.set_pixel(x, y, Color(v, v, v, c.a))
	cinza.save_png("user://capturas/%s_cinza.png" % nome.get_basename())
	print("  %s_cinza.png" % nome.get_basename())
