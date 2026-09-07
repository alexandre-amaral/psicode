extends TesteBase
## O backend da Loja: composicao, duplicata, preco e determinismo (#283).
##
## O que esta suite guarda e o que falha em SILENCIO. Uma Loja que sorteia tres
## implantes parecidos continua funcionando; uma que muda de estoque a cada
## entrada continua funcionando; uma que vende de graca continua funcionando. As
## tres arruinam a economia sem uma linha no console.


const POOL := "res://src/items/pool_padrao.tres"
const LOJA := "res://src/loja/loja_andar1.tres"
const AMOSTRAS := 400


func nome() -> String:
	return "Loja"


func executar() -> void:
	_a_loja_sempre_tem_uma_arma_e_um_item()
	_nenhuma_vaga_repete_conteudo()
	_a_mesma_semente_devolve_o_mesmo_estoque()
	_nada_vai_a_prateleira_de_graca()
	_a_loja_le_a_pool_REAL()
	_a_vaga_livre_nao_pende_para_um_lado()
	_a_loja_nasce_uma_vez_e_no_meio_do_andar()


## SEMPRE UMA ARMA E UM ITEM, e a terceira e surpresa.
##
## Com tres vagas livres, uma loja pode sair com tres implantes de dano quase
## iguais -- tres opcoes que sao a MESMA escolha, e a decisao que a Loja existe
## para criar ("compro agora ou economizo?") deixa de existir junto.
func _a_loja_sempre_tem_uma_arma_e_um_item() -> void:
	var dados := load(LOJA) as DadosLoja
	var pool := load(POOL) as PoolLoot
	ok(dados != null and pool != null, "a loja do andar 1 e a pool carregam")
	if dados == null or pool == null:
		return

	var sem_arma := 0
	var sem_item := 0
	var fora_de_tres := 0
	for i in AMOSTRAS:
		var ofertas := GeradorDeLoja.gerar(dados, pool, 7000 + i * 31)
		if ofertas.size() != dados.quantidade_de_vagas():
			fora_de_tres += 1
			continue
		var armas := 0
		var itens := 0
		for oferta in ofertas:
			if oferta.tipo == OfertaDeLoja.Tipo.ARMA:
				armas += 1
			else:
				itens += 1
		if armas < 1:
			sem_arma += 1
		if itens < 1:
			sem_item += 1

	igual(fora_de_tres, 0,
		"toda loja tem %d ofertas (%d fora)" % [dados.quantidade_de_vagas(), fora_de_tres])
	igual(sem_arma, 0, "toda loja tem ao menos uma ARMA (%d sem)" % sem_arma)
	igual(sem_item, 0, "toda loja tem ao menos um ITEM (%d sem)" % sem_item)


## NENHUMA VAGA REPETE CONTEUDO.
##
## Duas vagas com o mesmo conteudo sao uma vaga so com dois precos -- o jogador
## olha tres prateleiras e ve duas escolhas.
func _nenhuma_vaga_repete_conteudo() -> void:
	var dados := load(LOJA) as DadosLoja
	var pool := load(POOL) as PoolLoot
	if dados == null or pool == null:
		return
	ok(not dados.permite_duplicata, "a loja do andar 1 nao permite duplicata")

	var repetidas := 0
	for i in AMOSTRAS:
		var vistos: Array[String] = []
		for oferta in GeradorDeLoja.gerar(dados, pool, 12000 + i * 17):
			if vistos.has(oferta.id()):
				repetidas += 1
			vistos.append(oferta.id())
	igual(repetidas, 0, "nenhuma loja repete conteudo (%d repeticoes)" % repetidas)


## A MESMA SEMENTE DEVOLVE O MESMO ESTOQUE, e sementes diferentes nao.
##
## O determinismo torna um bug de loja reproduzivel -- e sem ele um relato de
## *"a loja veio com tres coisas caras"* nao teria como ser seguido.
##
## **E o portao cobra os DOIS lados.** So a primeira metade, um gerador que
## devolvesse sempre a mesma loja passaria: toda run teria o mesmo estoque, e
## isso e pior que aleatorio.
func _a_mesma_semente_devolve_o_mesmo_estoque() -> void:
	var dados := load(LOJA) as DadosLoja
	var pool := load(POOL) as PoolLoot
	if dados == null or pool == null:
		return

	var a := GeradorDeLoja.gerar(dados, pool, 4242)
	var b := GeradorDeLoja.gerar(dados, pool, 4242)
	igual(a.size(), b.size(), "a mesma semente devolve o mesmo numero de ofertas")
	var iguais := true
	for i in mini(a.size(), b.size()):
		if a[i].id() != b[i].id() or a[i].preco != b[i].preco:
			iguais = false
	ok(iguais, "e exatamente o mesmo estoque, na mesma ordem")

	# O OUTRO LADO: sementes diferentes tem de produzir lojas diferentes na
	# maioria das vezes. Nem sempre -- com poucos candidatos a colisao acontece
	# --, e por isso o portao mede a FRACAO em vez de exigir sempre.
	var diferentes := 0
	for i in AMOSTRAS:
		var x := GeradorDeLoja.gerar(dados, pool, 500 + i)
		var y := GeradorDeLoja.gerar(dados, pool, 900000 + i)
		var mudou := false
		for j in mini(x.size(), y.size()):
			if x[j].id() != y[j].id():
				mudou = true
		if mudou:
			diferentes += 1
	var fracao := float(diferentes) / float(AMOSTRAS)
	ok(fracao > 0.9,
		"sementes diferentes dao lojas diferentes em %.0f%% dos casos" % (fracao * 100.0))


## NADA VAI A PRATELEIRA DE GRACA.
##
## Conteudo sem `valor_de_loja` sairia por zero credito, e uma oferta gratuita
## quebra a economia inteira sem erro nenhum -- o jogador leva tudo e a decisao
## que a Loja existe para criar desaparece. A pistola inicial e o caso vivo: ela
## esta na pool e declara zero de proposito.
func _nada_vai_a_prateleira_de_graca() -> void:
	var dados := load(LOJA) as DadosLoja
	var pool := load(POOL) as PoolLoot
	if dados == null or pool == null:
		return
	var gratis := 0
	var invalidas := 0
	for i in AMOSTRAS:
		for oferta in GeradorDeLoja.gerar(dados, pool, 31000 + i * 13):
			if oferta.preco <= 0:
				gratis += 1
			if not oferta.valida():
				invalidas += 1
	igual(gratis, 0, "nenhuma oferta sai de graca (%d)" % gratis)
	igual(invalidas, 0, "e nenhuma sai sem conteudo (%d)" % invalidas)


## A LOJA LE A POOL REAL, e nao uma copia.
##
## Uma `ListaDeArmasDaLoja` duplicando o `pool_padrao` divergiria: uma arma nova
## apareceria no loot e nunca na Loja, sem erro, e so meses depois alguem
## repararia. O portao prova que todo conteudo ofertado veio da pool -- e que a
## Loja alcanca a maior parte dela em vez de girar em torno de tres itens.
func _a_loja_le_a_pool_REAL() -> void:
	var dados := load(LOJA) as DadosLoja
	var pool := load(POOL) as PoolLoot
	if dados == null or pool == null:
		return

	var da_pool: Array[String] = []
	for arma in pool.armas_validas():
		da_pool.append(arma.resource_path)
	for item in pool.itens_validos():
		da_pool.append(item.resource_path)

	var forasteiras := 0
	var alcancados: Array[String] = []
	for i in AMOSTRAS:
		for oferta in GeradorDeLoja.gerar(dados, pool, 60000 + i * 7):
			if not da_pool.has(oferta.id()):
				forasteiras += 1
			elif not alcancados.has(oferta.id()):
				alcancados.append(oferta.id())
	igual(forasteiras, 0,
		"todo conteudo ofertado veio da pool (%d de fora)" % forasteiras)

	# **A COBERTURA, e nao so a origem.** Um gerador que so oferecesse a primeira
	# arma da lista passaria no portao acima -- ela vem da pool. Em 400 lojas, a
	# variedade tem de aparecer.
	var vendaveis := 0
	for caminho in da_pool:
		var recurso := load(caminho) as Resource
		if recurso != null and GeradorDeLoja.preco_de(recurso) > 0:
			vendaveis += 1
	var cobertura := float(alcancados.size()) / float(maxi(vendaveis, 1))
	ok(cobertura > 0.8,
		"e a Loja alcanca %.0f%% do que e vendavel (%d de %d)"
			% [cobertura * 100.0, alcancados.size(), vendaveis])


## A VAGA LIVRE NAO PENDE PARA UM LADO.
##
## Ha mais implantes que armas na pool. Sorteando entre "todos os candidatos", a
## terceira vaga seria quase sempre item -- e a promessa de que ela e surpresa
## viraria uma segunda vaga de item com outro nome. Por isso ela e 50/50 pelo
## TIPO, e nao pelo numero de candidatos.
func _a_vaga_livre_nao_pende_para_um_lado() -> void:
	var dados := load(LOJA) as DadosLoja
	var pool := load(POOL) as PoolLoot
	if dados == null or pool == null:
		return
	var armas_na_terceira := 0
	var contadas := 0
	for i in AMOSTRAS:
		var ofertas := GeradorDeLoja.gerar(dados, pool, 77000 + i * 19)
		if ofertas.size() < 3:
			continue
		contadas += 1
		if ofertas[2].tipo == OfertaDeLoja.Tipo.ARMA:
			armas_na_terceira += 1
	ok(contadas > 0, "houve terceira vaga para medir (%d)" % contadas)
	if contadas == 0:
		return
	var fracao := float(armas_na_terceira) / float(contadas)
	entre(fracao, 0.35, 0.65,
		"a terceira vaga e arma em %.0f%% das lojas" % (fracao * 100.0))


## A LOJA NASCE UMA VEZ POR ANDAR, E NO MEIO DELE (#285).
##
## Duas regras que so falham em SILENCIO: uma Loja a mais dobra a economia do
## andar sem nada acusar, e uma Loja no lugar errado a torna inutil -- colada na
## entrada o jogador chega sem dinheiro, no fim nao sobra run para aproveitar a
## compra.
##
## **E ela e obrigatoria, como a de arma e a de item.** Se nao couber no grafo
## sorteado, o andar inteiro e sorteado de novo: sem isso a run pode acontecer
## inteira sem Loja, e a economia deixa de ter para onde ir. E o mesmo argumento
## que ja torna a sala de arma obrigatoria, porque ela e a unica fonte de arma.
func _a_loja_nasce_uma_vez_e_no_meio_do_andar() -> void:
	var tipo := load("res://src/mapa/tipo_loja.tres") as DadosSala
	ok(tipo != null, "o tipo loja carrega")
	if tipo == null:
		return
	ok(not tipo.opcional, "a Loja e obrigatoria, como a de arma e a de item")
	ok(tipo.inimigos.is_empty(), "e ela nao tem combate")
	perto(tipo.chance_de_aprimorada, 0.0,
		"nem Unidade Aprimorada", 0.0001)
	ok(tipo.distancia_minima_da_origem > 0,
		"ela nao nasce colada na entrada (minimo %d)" % tipo.distancia_minima_da_origem)
	ok(tipo.distancia_maxima_da_origem > tipo.distancia_minima_da_origem,
		"e nao nasce no fim do andar (maximo %d)" % tipo.distancia_maxima_da_origem)

	# O ICONE e a COR sao proprios: reusar os da arma ou do item faria o jogador
	# ler o minimapa errado, que e o unico lugar onde ele decide o desvio.
	var arma := load("res://src/mapa/tipo_arma.tres") as DadosSala
	var item := load("res://src/mapa/tipo_item.tres") as DadosSala
	if arma != null:
		ok(tipo.icone != arma.icone, "o icone dela nao e o da arma")
		ok(not tipo.cor_mapa.is_equal_approx(arma.cor_mapa), "nem a cor")
	if item != null:
		ok(tipo.icone != item.icone, "nem o do item")

	# E O ANDAR: uma por andar, sempre, medido montando de verdade.
	var fora := 0
	var sem_loja := 0
	for i in 12:
		seed(5500 + i * 43)
		var mapa := _montar_andar()
		if mapa == null:
			continue
		var quantas := 0
		for celula: Vector2i in mapa._reservadas:
			if mapa._reservadas[celula] == &"loja":
				quantas += 1
		if quantas == 0:
			sem_loja += 1
		elif quantas != 1:
			fora += 1
		mapa.get_parent().remove_child(mapa)
		mapa.free()
	igual(sem_loja, 0, "todo andar tem Loja (%d sem)" % sem_loja)
	igual(fora, 0, "e nunca mais de uma (%d andares com outra contagem)" % fora)


func _montar_andar() -> GerenciadorMapa:
	var cena: PackedScene = load("res://src/main/main.tscn")
	var main := cena.instantiate()
	Engine.get_main_loop().root.add_child(main)
	var jogador := main.find_child("Player", true, false)
	if jogador != null:
		jogador.get_parent().remove_child(jogador)
		jogador.free()
	return main.find_child("GerenciadorMapa", true, false) as GerenciadorMapa
