extends TesteBase
## A TERCEIRA ARMA: a tela de escolha, o descarte no chao e a trava de recoleta.
##
## O que esta suite guarda e um laco fechado que nao da erro nenhum: **a arma
## substituida cai exatamente onde o jogador esta.** Ele acabou de encostar no
## pickup para disparar a troca, entao a arma nova no chao dispara o
## `body_entered` dela no frame seguinte -- os dois slots continuam cheios, a
## tela reabre, e ela reabre sobre uma arvore que ja esta pausada. O jogo trava
## num painel que volta sozinho, e o console fica limpo.
##
## Por isso `PickupArma.soltar_no_chao()` ja nasce travada, e por isso a trava
## entra tambem no CANCELAMENTO: quem cancelou tambem nao saiu de cima do
## pickup.

const MANTIS := "res://src/weapons/smg_mantis.tres"
const RAIL_X := "res://src/weapons/rail_x.tres"
const BOOMER := "res://src/weapons/boomer.tres"


func nome() -> String:
	return "Troca de Arma"


func executar() -> void:
	_a_tela_mostra_as_tres_armas()
	_a_geometria_do_clique_e_a_do_desenho()
	await _decidir_devolve_a_escolha_e_despausa()
	await _a_arma_largada_nasce_TRAVADA()
	_toda_arma_da_pool_produz_tag_legivel()


func _arma(caminho: String) -> DadosArma:
	return load(caminho) as DadosArma


func _inventario_cheio() -> InventarioDeArmas:
	var inv := InventarioDeArmas.new()
	inv.definir_inicial(_arma(MANTIS))
	inv.pedir_aquisicao(_arma(RAIL_X))
	return inv


func _abrir() -> TelaTrocaDeArma:
	var raiz := Node.new()
	Engine.get_main_loop().root.add_child(raiz)
	return TelaTrocaDeArma.abrir(raiz, _arma(BOOMER), _inventario_cheio())


func _fechar(tela: TelaTrocaDeArma) -> void:
	var raiz := tela.get_parent()
	if is_instance_valid(tela):
		tela.queue_free()
	if raiz != null:
		raiz.queue_free()
	# A tela pausa a arvore ao montar. Uma suite que a deixasse pausada
	# congelaria TODAS as suites seguintes que esperam passo de fisica -- e o
	# runner ficaria vivo ate o timeout do CI, sem imprimir nada.
	Engine.get_main_loop().paused = false


func _a_tela_mostra_as_tres_armas() -> void:
	var tela := _abrir()
	var painel: PainelDeTroca = tela.get_node("Painel")

	ok(painel.nova == _arma(BOOMER), "a arma nova chega ao painel")
	ok(painel.atuais[0] == _arma(MANTIS), "o slot 0 chega ao painel")
	ok(painel.atuais[1] == _arma(RAIL_X), "e o slot 1 tambem")
	ok(Engine.get_main_loop().paused, "e a arvore pausa enquanto o jogador decide")
	_fechar(tela)


func _a_geometria_do_clique_e_a_do_desenho() -> void:
	var painel := PainelDeTroca.new()
	var caixa0 := painel.caixa_do_slot(0)
	var caixa1 := painel.caixa_do_slot(1)

	ok(caixa0.size.y > 0.0, "o cartao do slot 0 tem area")
	ok(caixa1.position.y > caixa0.position.y, "o slot 1 fica abaixo do slot 0")
	# **Os dois nao podem se tocar.** Sobrepostos, o clique no vao entre eles
	# escolheria o de cima enquanto o olho ve o de baixo -- e a tela ficaria
	# clicavel num lugar e desenhada noutro.
	ok(caixa1.position.y >= caixa0.end.y, "e eles nao se sobrepoem")
	ok(not caixa0.has_point(caixa1.get_center()), "o centro de um nao cai no outro")
	painel.free()


func _decidir_devolve_a_escolha_e_despausa() -> void:
	var tela := _abrir()
	var recebido := [-99]
	tela.decidida.connect(func(indice: int) -> void: recebido[0] = indice)

	tela._decidir(1)
	await Engine.get_main_loop().process_frame

	igual(recebido[0], 1, "a escolha chega a quem pediu")
	ok(not Engine.get_main_loop().paused, "e a arvore volta a correr")
	Engine.get_main_loop().paused = false


func _a_arma_largada_nasce_TRAVADA() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)

	var largado := PickupArma.soltar_no_chao(_arma(MANTIS), raiz, Vector2(4000.0, 4000.0))
	ok(largado != null, "a arma substituida vira pickup no chao")
	await Engine.get_main_loop().process_frame

	ok(largado.dados == _arma(MANTIS), "e ela e a arma que saiu")
	ok(largado.pool == null,
		"o pool sai junto: com `dados` e `pool` apontados ha duas respostas para que arma e esta")
	# A trava e o que fecha o laco. Ela vale por `TRAVA_APOS_LARGAR` segundos, e
	# o `process_frame` acima ja consumiu uma fracao dela -- entao o portao
	# pergunta se ainda ha trava, e nao se ela vale o numero cheio.
	ok(largado._t_trava > 0.0, "e ela nasce travada contra recoleta imediata")

	raiz.queue_free()


func _toda_arma_da_pool_produz_tag_legivel() -> void:
	var pool: PoolLoot = load("res://src/items/pool_padrao.tres")
	if pool == null:
		ok(false, "a pool de loot nao carregou")
		return
	for arma in pool.armas_validas():
		var tags := PainelDeTroca.tags_de(arma)
		for t in tags:
			# Tag vazia desenharia um separador solto (" · ") no cartao, e o
			# jogador leria um campo quebrado onde nao ha nada de errado.
			ok(not t.is_empty(), "'%s' nao produz tag vazia" % arma.nome)
		# A tag e a CHAVE em portugues e nao o texto traduzido: uma suite que
		# lesse texto ja traduzido passaria na maquina de quem tem o SO em
		# portugues e quebraria no CI, que roda em ingles.
		ok(tags.size() <= 3, "'%s' nao produz mais tags do que cabem no cartao" % arma.nome)
