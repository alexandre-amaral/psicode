extends TesteBase
## A economia de run: a API, o drop e a trava anti-farm (#279).
##
## Ate a #280 o credito era uma linha na morte do inimigo -- uma atribuicao
## direta, invisivel, sem forma de gastar. Com uma Loja para consumi-lo, cada
## uma dessas tres coisas vira um lugar onde o jogo pode perder ou inventar
## dinheiro, e nenhuma delas da erro no console quando erra.


const DROP := "res://src/items/drop_credito_andar1.tres"
const ABATES := 10000


func nome() -> String:
	return "Creditos"


func executar() -> void:
	var saldo := GameState.creditos
	_gastar_recusa_SEM_alterar_nada()
	_o_saldo_so_muda_pela_API()
	_o_drop_converge_para_o_valor_declarado()
	_o_drop_nao_enche_a_tela_de_fichas()
	_a_ficha_nao_desenha_na_faixa_do_combate()
	GameState.creditos = saldo


## GASTAR RECUSA SEM ALTERAR NADA, e isto e o portao mais importante daqui.
##
## Uma funcao que debita e deixa o chamador conferir depois e a forma de o
## jogador pagar por uma arma que nao recebeu -- e numa economia isso nao tem
## desfazer. A transacao da Loja (#288) valida a entrega ANTES de pagar, e essa
## ordem so vale se a recusa aqui for limpa.
func _gastar_recusa_SEM_alterar_nada() -> void:
	GameState.creditos = 0
	GameState.adicionar_creditos(10)
	igual(GameState.creditos_atuais(), 10, "creditar soma")

	ok(not GameState.pode_pagar(11), "nao pode pagar mais do que tem")
	ok(GameState.pode_pagar(10), "pode pagar exatamente o que tem")

	var antes := GameState.creditos_atuais()
	ok(not GameState.gastar_creditos(11), "gastar demais RECUSA")
	igual(GameState.creditos_atuais(), antes,
		"e o saldo nao se move na recusa (%d)" % GameState.creditos_atuais())

	ok(GameState.gastar_creditos(4), "gastar o que cabe passa")
	igual(GameState.creditos_atuais(), 6, "e debita exatamente")

	# O outro lado: quantidade nao positiva nao e erro, e um drop que sorteie
	# zero e caso normal -- mas ela tambem nao pode CREDITAR nada.
	GameState.adicionar_creditos(0)
	GameState.adicionar_creditos(-5)
	igual(GameState.creditos_atuais(), 6, "creditar zero ou negativo nao faz nada")


## O SALDO SO MUDA PELA API, e o portao le o codigo para provar.
##
## Nao ha teste de comportamento que pegue isto: uma atribuicao direta em
## qualquer arquivo funciona, some do sinal, e a HUD para de atualizar naquele
## caso especifico -- sem erro, e so naquele caminho.
##
## `game_state.gd` e a excecao obvia (e onde o campo mora) e este arquivo
## tambem, porque ele monta cenarios.
func _o_saldo_so_muda_pela_API() -> void:
	var permitidos := [
		"res://src/autoload/game_state.gd",
		"res://tools/testes/teste_creditos.gd",
	]
	var infratores: Array[String] = []
	for caminho in _varrer("res://src/"):
		if permitidos.has(caminho):
			continue
		var texto := FileAccess.get_file_as_string(caminho)
		if texto.is_empty():
			continue
		for linha in texto.split("\n"):
			var limpa := linha.strip_edges()
			if limpa.begins_with("#"):
				continue
			if limpa.contains("GameState.creditos +=") \
					or limpa.contains("GameState.creditos -=") \
					or limpa.contains("GameState.creditos ="):
				infratores.append("%s: %s" % [caminho.get_file(), limpa])
	igual(infratores.size(), 0,
		"ninguem escreve em GameState.creditos fora da API (%s)"
			% ", ".join(infratores))


## O DROP CONVERGE PARA O VALOR DECLARADO.
##
## `InimigoBase.creditos` e o valor ESPERADO, e nao o pago: dois Drones iguais
## nao derrubam a mesma coisa, e o resto que nao fecha uma ficha vira chance de
## mais uma. Sem isso a economia vira uma regua -- o mesmo abate, o mesmo troco,
## toda vez.
##
## **A tolerancia e de 3%, e ela e apertada de proposito.** Um vies de 10% na
## renda do andar move a comprabilidade da Loja inteira, e comprabilidade e o
## portao do epico. Dez mil abates deixam o erro de amostragem bem abaixo disso.
func _o_drop_converge_para_o_valor_declarado() -> void:
	var dados := load(DROP) as DadosDropCredito
	ok(dados != null, "a tabela de drop do andar 1 carrega")
	if dados == null:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for esperado in [6, 7, 10, 12, 60]:
		var total := 0
		for _i in ABATES:
			for valor in dados.sortear(esperado, rng):
				total += valor
		var media := float(total) / float(ABATES)
		perto(media, float(esperado) * dados.fracao_do_valor,
			"um inimigo de %d creditos paga %.2f em media" % [esperado, media],
			float(esperado) * 0.03)


## E ELE NAO ENCHE A TELA DE FICHAS.
##
## Um Hacker de 10 creditos derrubando dez fichas de 1 seria poluicao visual num
## jogo cuja regra que corta todas as outras e a leitura de combate. O sorteio
## comeca pela maior ficha que cabe, entao 10 vira UMA grande.
##
## E o teto MORDE no chefe: 60 creditos pagariam seis fichas grandes, e ele as
## junta. Teto que nunca e alcancado e teto que nunca foi testado.
func _o_drop_nao_enche_a_tela_de_fichas() -> void:
	var dados := load(DROP) as DadosDropCredito
	if dados == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242

	for esperado in [6, 7, 10, 12]:
		var maior := 0
		var soma := 0
		for _i in 500:
			var fichas := dados.sortear(esperado, rng)
			maior = maxi(maior, fichas.size())
			soma += fichas.size()
		var media := float(soma) / 500.0
		entre(media, 0.5, 3.0,
			"um inimigo de %d creditos derruba %.1f fichas em media" % [esperado, media])
		ok(maior <= dados.max_fichas,
			"e nunca mais que o teto de %d (pico %d)" % [dados.max_fichas, maior])

	# O CHEFE e onde o teto morde.
	var do_chefe := dados.sortear(60, rng)
	ok(do_chefe.size() <= dados.max_fichas,
		"o chefe cabe no teto (%d fichas)" % do_chefe.size())
	var pago := 0
	for valor in do_chefe:
		pago += valor
	# **O ESPERADO SAI DA FRACAO DECLARADA, e nao do valor cru.** A primeira
	# versao cravava 60 e passava so porque a fracao era 1,0 -- calibrar a renda
	# para 0,20 reprovou o codigo CERTO, e o portao estava afirmando um numero em
	# vez de afirmar a regra. A regra e que o teto JUNTE o resto em vez de
	# descartar, e ela nao muda com o botao de renda.
	var esperado_do_chefe := int(roundf(60.0 * dados.fracao_do_valor))
	perto(float(pago), float(esperado_do_chefe),
		"o teto JUNTA o resto em vez de descartar (pagou %d de %d)"
			% [pago, esperado_do_chefe], 1.0)


## A FICHA NAO DESENHA NA FAIXA DO COMBATE.
##
## Ela divide a tela com projetil e telegrafo, e perder um dos dois por causa de
## dinheiro seria o pior defeito possivel. A faixa zero e onde o aviso que torna
## um ataque justo desenha; a ficha vive na faixa chapada, com o prop e a aura.
##
## E isto e garantia GEOMETRICA e nao intencao -- por isso o portao le a
## constante em vez de olhar uma captura.
func _a_ficha_nao_desenha_na_faixa_do_combate() -> void:
	ok(PickupCredito.Z_FICHA < 0,
		"a ficha desenha abaixo da faixa do mundo (z %d)" % PickupCredito.Z_FICHA)
	igual(PickupCredito.Z_FICHA, Sala.Z_CHAO_DETALHE,
		"na mesma faixa chapada do prop e da aura")
	# E ela CHEGA ate o jogador em vez de ser absorvida de longe: o pequeno voo e
	# o feedback de que ela existiu.
	ok(PickupCredito.RAIO_DE_COLETA < PickupCredito.RAIO_DE_ATRACAO,
		"o raio de coleta (%.0f) e menor que o de atracao (%.0f)"
			% [PickupCredito.RAIO_DE_COLETA, PickupCredito.RAIO_DE_ATRACAO])


func _varrer(raiz: String) -> Array[String]:
	var saida: Array[String] = []
	var pasta := DirAccess.open(raiz)
	if pasta == null:
		return saida
	for nome_do_arquivo in pasta.get_files():
		if nome_do_arquivo.ends_with(".gd"):
			saida.append(raiz + nome_do_arquivo)
	for sub in pasta.get_directories():
		saida.append_array(_varrer(raiz + sub + "/"))
	return saida
