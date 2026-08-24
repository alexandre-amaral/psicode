extends Node
## Diagnostico descartavel: gera muitos andares e mede a composicao de inimigos.
##
## Existe para responder a pergunta que nenhum teste responde -- "quantos
## inimigos o jogador encontra de fato numa sala?". O teste unitario confere a
## conta e o de fumaca confere que a run termina; nenhum dos dois diz se a
## sala-corredor virou uma parede de corpos.
##
## Nao entra no runner e nao roda no CI: e uma regua para a sessao de tuning.
##
## Use:  godot --headless --path . tools/medir_composicao.tscn

const ANDARES := 120


func _ready() -> void:
	await get_tree().process_frame
	_medir()
	get_tree().quit(0)


func _medir() -> void:
	print("\n=== COMPOSICAO POR SALA: %d andares ===\n" % ANDARES)

	var tipos: Array[DadosSala] = []
	for caminho in [
		"res://src/mapa/tipo_combate.tres",
		"res://src/mapa/tipo_boss.tres",
		"res://src/mapa/tipo_arma.tres",
		"res://src/mapa/tipo_item.tres",
		"res://src/mapa/tipo_inicial.tres",
	]:
		tipos.append(load(caminho))

	# Quantas salas cada TIPO de inimigo ocupou, e em quantos andares ele
	# apareceu ao menos uma vez. E o que diz se uma porta por Deterioracao ficou
	# alta demais e transformou o inimigo em conteudo morto.
	var por_inimigo: Dictionary = {}
	var andares_com: Dictionary = {}

	# cena -> {"salas": n, "inimigos": n, "min": n, "max": n, "rastejantes": n}
	var por_cena: Dictionary = {}
	var por_tipo: Dictionary = {}
	var presenca: Dictionary = {}
	var salas_no_andar := 0

	for _andar in ANDARES:
		var mapa := GerenciadorMapa.new()
		mapa.tipos_de_sala = tipos
		add_child(mapa)

		# A sala e achada pelos filhos do gerenciador, e nao por uma API nova:
		# um diagnostico descartavel nao deve fazer o codigo de jogo crescer.
		var salas: Dictionary = {}
		for filho in mapa.get_children():
			var sala := filho as Sala
			if sala != null:
				salas[sala.coordenadas_grid] = sala

		var vistos: Dictionary = {}
		var vistos_inimigo: Dictionary = {}
		salas_no_andar += mapa.celulas().size()
		for celula in mapa.celulas():
			var dados := mapa.dados_da_celula(celula)
			var sala: Sala = salas.get(celula)
			if dados == null or sala == null:
				continue
			var composicao := mapa.composicao_da_celula(celula)
			vistos[dados.id] = true

			var chave: String = sala.scene_file_path.get_file()
			_somar(por_cena, chave, composicao)
			_somar(por_tipo, String(dados.id), composicao)

			for cena in composicao:
				if cena == null:
					continue
				var apelido := cena.resource_path.get_file().get_basename()
				por_inimigo[apelido] = int(por_inimigo.get(apelido, 0)) + 1
				vistos_inimigo[apelido] = true

		for id in vistos:
			presenca[id] = int(presenca.get(id, 0)) + 1
		for apelido in vistos_inimigo:
			andares_com[apelido] = int(andares_com.get(apelido, 0)) + 1

		# free() e nao queue_free(): o laco e sincrono, e 120 andares adiados ate
		# o fim do frame seriam 1200 salas vivas ao mesmo tempo.
		remove_child(mapa)
		mapa.free()

	print("media de %.1f salas por andar\n" % (float(salas_no_andar) / ANDARES))

	print("por CENA:")
	_imprimir(por_cena)
	print("\npor TIPO de sala:")
	_imprimir(por_tipo)

	print("\ninimigos colocados (total em %d andares):" % ANDARES)
	var total_inimigos := 0
	for apelido in por_inimigo:
		total_inimigos += int(por_inimigo[apelido])
	var apelidos := por_inimigo.keys()
	apelidos.sort()
	for apelido: String in apelidos:
		var n := int(por_inimigo[apelido])
		var andares := int(andares_com.get(apelido, 0))
		var marca := ""
		# Inimigo que nao aparece em pelo menos um quinto dos andares esta, na
		# pratica, invisivel para quem joga -- porta por Deterioracao alta demais.
		if andares * 5 < ANDARES:
			marca = "   <== raro demais"
		print("  %-22s %5d colocados (%4.1f%%) | em %3d andares (%3.0f%%)%s" % [
			apelido, n, 100.0 * n / maxf(total_inimigos, 1),
			andares, 100.0 * andares / ANDARES, marca,
		])

	print("\npresenca no andar (de %d):" % ANDARES)
	for id in presenca:
		print("  %-10s %3d andares  (%.0f%%)" % [
			id, presenca[id], 100.0 * float(presenca[id]) / ANDARES,
		])
	print("")


func _somar(acc: Dictionary, chave: String, composicao: Array[PackedScene]) -> void:
	var linha: Dictionary = acc.get(chave, {
		"salas": 0, "inimigos": 0, "min": 999, "max": 0, "rastejantes": 0,
	})
	var n := composicao.size()
	linha["salas"] = int(linha["salas"]) + 1
	linha["inimigos"] = int(linha["inimigos"]) + n
	linha["min"] = mini(int(linha["min"]), n)
	linha["max"] = maxi(int(linha["max"]), n)
	for cena in composicao:
		if cena != null and cena.resource_path.contains("rastejante"):
			linha["rastejantes"] = int(linha["rastejantes"]) + 1
	acc[chave] = linha


func _imprimir(acc: Dictionary) -> void:
	var chaves := acc.keys()
	chaves.sort()
	for chave: String in chaves:
		var linha: Dictionary = acc[chave]
		var salas := int(linha["salas"])
		var inimigos := int(linha["inimigos"])
		var rast := int(linha["rastejantes"])
		var proporcao := "-"
		if inimigos > 0:
			proporcao = "%.0f%% rastejante" % (100.0 * float(rast) / inimigos)
		print("  %-26s %5d salas | media %5.2f | min %d | max %2d | %s" % [
			chave, salas, float(inimigos) / maxf(salas, 1.0),
			int(linha["min"]) if salas > 0 else 0, int(linha["max"]), proporcao,
		])
