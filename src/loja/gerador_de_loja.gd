class_name GeradorDeLoja
## Monta as tres ofertas de uma Loja, e a cena da Loja nao escolhe nada.
##
## Mesma divisao que a `Sala` ja tem com a composicao: quem DECIDE e quem
## conhece o andar inteiro, quem APLICA e a cena. Uma Loja que sorteasse o
## proprio estoque no `_ready` mudaria de conteudo toda vez que o jogador
## entrasse, e "vendido continua vendido" viraria impossivel.
##
## ## Deterministico, e isso nao e conveniencia
##
## A semente sai de `(semente da run, celula)`. Mesma run e mesma celula devolvem
## o MESMO estoque -- e isso e o que torna um bug de loja reproduzivel. O projeto
## ja paga esse preco em toda geracao de andar, e uma Loja aleatoria por fora
## seria o unico lugar onde um relato de bug nao teria como ser seguido.
##
## ## Ela le a pool REAL
##
## `PoolLoot` e o mesmo recurso que decide o que cai de loot. A Loja passa por
## ele com um FILTRO, e nao com uma lista propria -- entao uma arma nova entra
## nas duas na mesma linha, e nao ha como uma esquecer da outra.


## As ofertas desta Loja, prontas.
##
## Devolve lista vazia quando nao ha o que vender: a cena tem de aguentar isso,
## como `sortear_arma()` ja obriga a aguentar `null`. Uma vaga com conteudo nulo
## seria pior -- ela desenharia um pedestal comprando nada.
static func gerar(dados: DadosLoja, pool: PoolLoot, semente: int) -> Array[OfertaDeLoja]:
	var ofertas: Array[OfertaDeLoja] = []
	if dados == null or pool == null:
		return ofertas

	var rng := RandomNumberGenerator.new()
	rng.seed = semente

	var armas := pool.armas_validas()
	var itens := pool.itens_validos()
	var usados: Array[String] = []

	for i in dados.quantidade_de_vagas():
		var vaga: DadosLoja.Vaga = dados.vagas[i]
		var quer_arma := vaga == DadosLoja.Vaga.ARMA
		if vaga == DadosLoja.Vaga.QUALQUER:
			# A vaga livre e 50/50 e nao "o que sobrou": enviesar para o que tem
			# mais candidatos faria a terceira vaga ser quase sempre item, porque
			# ha mais implantes que armas.
			quer_arma = rng.randf() < 0.5
			# Mas se um dos dois acabou, ela nao pode insistir -- e melhor uma
			# terceira arma que uma vaga vazia.
			if quer_arma and _todos_usados(armas, usados):
				quer_arma = false
			elif not quer_arma and _todos_usados(itens, usados):
				quer_arma = true

		var candidatos: Array[Resource] = []
		for recurso in (armas if quer_arma else itens):
			candidatos.append(recurso)
		var escolhido := _sortear(candidatos, usados, dados.permite_duplicata, rng)
		if escolhido == null:
			continue

		var oferta := OfertaDeLoja.new()
		oferta.slot = i
		oferta.tipo = OfertaDeLoja.Tipo.ARMA if quer_arma else OfertaDeLoja.Tipo.ITEM
		oferta.conteudo = escolhido
		oferta.preco = preco_de(escolhido)
		ofertas.append(oferta)
		if not dados.permite_duplicata:
			usados.append(escolhido.resource_path)
	return ofertas


## O preco de um conteudo.
##
## **Uma funcao so, e ela existe antes de haver o que multiplicar.** Hoje ela
## devolve `valor_de_loja` e mais nada; amanha entram o andar, o NPC e o
## desconto. O dia em que os modificadores existirem nao pode ser o dia em que
## quatro lugares aprendem a multiplicar -- e o `preco_final` da `OfertaDeLoja`
## existe por isso.
static func preco_de(conteudo: Resource) -> int:
	if conteudo == null:
		return 0
	var declarado: Variant = conteudo.get("valor_de_loja")
	if declarado == null:
		return 0
	return maxi(int(declarado), 0)


## A semente desta Loja. `celula` entra para duas Lojas do mesmo andar (quando
## houver) nao venderem a mesma coisa.
static func semente_de(semente_da_run: int, celula: Vector2i) -> int:
	return hash([semente_da_run, celula, "LOJA"])


static func _todos_usados(lista: Array, usados: Array[String]) -> bool:
	for recurso: Resource in lista:
		if not usados.has(recurso.resource_path):
			return false
	return true


## Sorteia um candidato ainda nao usado.
##
## Ele filtra ANTES de sortear, e nao sorteia ate achar um livre: com poucos
## candidatos, tentar ate acertar pode girar muito -- a mesma razao pela qual o
## sorteio de grupo de inimigo consome `custo_real()` com piso 1 em vez de
## confiar em um laco terminar.
static func _sortear(candidatos: Array[Resource], usados: Array[String],
		permite_duplicata: bool, rng: RandomNumberGenerator) -> Resource:
	var livres: Array[Resource] = []
	for recurso in candidatos:
		if recurso == null:
			continue
		if not permite_duplicata and usados.has(recurso.resource_path):
			continue
		# Conteudo sem preco nao pode ir para a prateleira: ele sairia de graca,
		# e uma oferta gratuita quebra a economia inteira em silencio.
		if preco_de(recurso) <= 0:
			continue
		livres.append(recurso)
	if livres.is_empty():
		return null
	return livres[rng.randi_range(0, livres.size() - 1)]
