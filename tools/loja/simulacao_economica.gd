extends Node2D
## A renda do andar contra os precos da Loja, medida em muitos andares.
##
## **O plano e explicito: "nao balancear a economia apenas por sensacao
## manual".** E a primeira medicao ja contradisse o plano -- ele assume 35 a 55
## creditos no andar 1, e uma run completa rendeu **173**. Girar preco ou renda
## por gosto em cima disso seria calibrar contra um numero imaginario.
##
## Ela monta andares de verdade e soma o que eles pagariam:
##
##     renda = soma dos `creditos` da composicao   (o valor ESPERADO das fichas)
##           + premio de limpeza de cada sala      (chance x faixa)
##           x `fracao_do_valor` da tabela de drop
##
## E gera a Loja daquele andar com a semente daquele andar, para a comprabilidade
## sair do par renda-estoque de verdade -- e nao de uma renda media contra um
## preco medio, que e onde as duas pontas mentem juntas.
##
## ## O que ela NAO faz
##
## Ela nao simula o jogador: nao ha coleta perdida, nao ha morte antes do fim.
## E o TETO da renda, e nao a media. Isso e deliberado -- para decidir preco, o
## que importa e quanto o andar PODE pagar, porque e contra isso que o jogador
## bem-sucedido vai comprar.

const ANDARES := 40
const POOL := "res://src/items/pool_padrao.tres"
const LOJA := "res://src/loja/loja_andar1.tres"
const DROP := "res://src/items/drop_credito_andar1.tres"

## Onde a Loja cai na progressao, em fracao. O plano pede 35% a 70%: o jogador
## chega com algum dinheiro e ainda tem run pela frente para aproveitar.
const FRACAO_DA_LOJA := 0.5


func _ready() -> void:
	var pool := load(POOL) as PoolLoot
	var dados_loja := load(LOJA) as DadosLoja
	var drop := load(DROP) as DadosDropCredito
	if pool == null or dados_loja == null or drop == null:
		print("SIMULACAO: recursos nao carregaram")
		get_tree().quit()
		return

	print("\n=== SIMULACAO ECONOMICA: ANDAR 1 ===")
	print("  %d andares, renda de teto (sem coleta perdida)\n" % ANDARES)

	var cena: PackedScene = load("res://src/main/main.tscn")
	var antes_da_loja: Array[float] = []
	var totais: Array[float] = []
	var precos: Array[int] = []
	var compraveis := {0: 0, 1: 0, 2: 0, 3: 0}

	for i in ANDARES:
		seed(31000 + i * 71)
		var main := cena.instantiate()
		add_child(main)
		await get_tree().process_frame
		var mapa := main.find_child("GerenciadorMapa", true, false) as GerenciadorMapa
		if mapa == null:
			main.free()
			continue

		var por_sala := _renda_por_sala(mapa, drop)
		var total := 0.0
		for valor: float in por_sala:
			total += valor
		# O que o jogador tem NA Loja: a renda das salas ate a fracao declarada.
		var ate_a_loja := 0.0
		var corte := int(floorf(float(por_sala.size()) * FRACAO_DA_LOJA))
		for k in mini(corte, por_sala.size()):
			ate_a_loja += por_sala[k]

		antes_da_loja.append(ate_a_loja)
		totais.append(total)

		var ofertas := GeradorDeLoja.gerar(dados_loja, pool,
			GeradorDeLoja.semente_de(31000 + i * 71, mapa.celula_do_chefe()))
		var quantas := _quantas_cabem(ofertas, ate_a_loja)
		compraveis[quantas] = int(compraveis[quantas]) + 1
		for oferta in ofertas:
			precos.append(oferta.preco)

		main.free()
		await get_tree().process_frame

	_relatar("creditos ATE a Loja", antes_da_loja, 14.0, 24.0)
	_relatar("creditos no ANDAR", totais, 35.0, 55.0)

	precos.sort()
	if not precos.is_empty():
		var soma := 0
		for p: int in precos:
			soma += p
		print("  preco das ofertas: min %d  mediana %d  medio %.0f  max %d"
			% [precos[0], precos[precos.size() / 2],
				float(soma) / float(precos.size()), precos[precos.size() - 1]])

	# **A COMPRABILIDADE E O PORTAO, e nao o preco.** Preco e o botao; o que se
	# quer e a distribuicao de quantas ofertas cabem no bolso.
	print("\n  quantas ofertas o jogador consegue comprar:")
	var alvos := {0: "15-30%", 1: "70-85% (ao menos uma)", 2: "15-35%", 3: "menos de 10%"}
	var acumulado := 0
	for quantas in [3, 2, 1, 0]:
		var n: int = compraveis[quantas]
		var fracao := float(n) / float(maxi(ANDARES, 1)) * 100.0
		if quantas >= 1:
			acumulado += n
		print("    exatamente %d: %5.1f%%%s" % [quantas, fracao,
			"   (ao menos uma: %.1f%%)" % (float(acumulado) / float(ANDARES) * 100.0)
				if quantas == 1 else ""])
	print("    alvos do plano: %s" % alvos)
	get_tree().quit()


## Quanto cada sala pagaria, em ordem de distancia da entrada.
##
## A ORDEM importa: a Loja fica no meio do andar, entao o que o jogador tem no
## bolso ao chegar nela e a renda das salas ANTES dela -- somar o andar inteiro
## responderia sobre o fim da run, que e outra pergunta.
func _renda_por_sala(mapa: GerenciadorMapa, drop: DadosDropCredito) -> Array[float]:
	var saida: Array[float] = []
	var celulas: Array = mapa._composicao_por_celula.keys()
	# Ordena pela distancia ate a entrada, com o mesmo BFS que ja decide quais
	# inimigos podem nascer onde -- reusar em vez de inventar um segundo numero.
	celulas.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.length_squared() < b.length_squared())

	for celula: Vector2i in celulas:
		var composicao: Array = mapa._composicao_por_celula[celula]
		var da_sala := 0.0
		for cena: PackedScene in composicao:
			if cena == null:
				continue
			da_sala += float(_creditos_da_cena(cena))
		# O premio de limpeza entra pelo VALOR ESPERADO (chance x meio da faixa):
		# simular o sorteio por andar so acrescentaria ruido a uma media.
		var dados: DadosSala = mapa._dados_por_celula.get(celula)
		if dados != null and da_sala > 0.0:
			da_sala += dados.chance_de_premio \
				* float(dados.premio_minimo + dados.premio_maximo) * 0.5
		saida.append(da_sala * drop.fracao_do_valor)
	return saida


var _cache_de_creditos: Dictionary = {}


## Quanto vale o inimigo daquela cena.
##
## Instanciar cada inimigo para ler um `int` seria caro em 40 andares; o valor
## mora no `DadosInimigo`, e a cena aponta para ele. O cache existe porque a
## mesma cena aparece dezenas de vezes por andar.
func _creditos_da_cena(cena: PackedScene) -> int:
	var chave := cena.resource_path
	if _cache_de_creditos.has(chave):
		return int(_cache_de_creditos[chave])
	var no := cena.instantiate()
	var valor := 0
	if no != null:
		var declarado: Variant = no.get("creditos")
		if declarado != null:
			valor = int(declarado)
		var dados: Variant = no.get("dados")
		if dados != null and dados is DadosInimigo:
			valor = (dados as DadosInimigo).creditos
		no.free()
	_cache_de_creditos[chave] = valor
	return valor


## Quantas das tres ofertas cabem num saldo, comprando da mais barata para a
## mais cara -- que e o que um jogador maximizando compras faz.
func _quantas_cabem(ofertas: Array[OfertaDeLoja], saldo: float) -> int:
	var precos: Array[int] = []
	for oferta in ofertas:
		precos.append(oferta.preco)
	precos.sort()
	var restante := saldo
	var quantas := 0
	for preco: int in precos:
		if restante >= float(preco):
			restante -= float(preco)
			quantas += 1
	return quantas


func _relatar(rotulo: String, valores: Array[float], alvo_min: float, alvo_max: float) -> void:
	if valores.is_empty():
		return
	valores.sort()
	var soma := 0.0
	for v: float in valores:
		soma += v
	var media := soma / float(valores.size())
	var dentro := 0
	for v: float in valores:
		if v >= alvo_min and v <= alvo_max:
			dentro += 1
	print("  %-22s min %4.0f  mediana %4.0f  media %4.0f  max %4.0f   "
		% [rotulo, valores[0], valores[valores.size() / 2], media,
			valores[valores.size() - 1]]
		+ "alvo %.0f-%.0f: %.0f%% dentro"
			% [alvo_min, alvo_max, float(dentro) / float(valores.size()) * 100.0])
