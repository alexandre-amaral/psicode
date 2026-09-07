extends Node2D
## O MESMO andar com e sem planta, fotografado no mesmo lugar.
##
## Nada do epico dos setores tem portao possivel para a pergunta que importa --
## *"o jogador esta atravessando salas artificiais ou avancando por departamentos
## de uma mesma instalacao?"*. A unica resposta honesta e olhar o mesmo grafo nas
## duas versoes, e por isso esta ferramenta fixa a semente antes de montar.
##
## Ela fotografa o jogador **dentro da conexao**, e nao a sala: e ali que a
## diferenca acontece. Uma parede compartilhada e 96 px de travessia entre duas
## faixas que se encontram; um corredor tecnico e 384 px de um lugar proprio.
##
## Sem janela ela MEDE, como o resto das reguas: quantas conexoes de cada tipo, e
## quanto o jogador anda em cada uma.

const SEMENTE := 20260907

## Onde a camera para, em fracao do vao. 0,5 e o meio da travessia -- o ponto em
## que as duas salas aparecem juntas se elas forem vizinhas de verdade.
const FRACAO_DA_TRAVESSIA := 0.5


func _ready() -> void:
	var com_janela := DisplayServer.get_name() != "headless"
	if com_janela:
		DirAccess.make_dir_recursive_absolute("user://capturas")
	print("COMPARAR_PLANTA  (%s)" % ("fotos" if com_janela else "medicao"))

	for com_planta in [false, true]:
		var rotulo := "nova" if com_planta else "antiga"
		seed(SEMENTE)
		var main := (load("res://src/main/main.tscn") as PackedScene).instantiate()
		var mapa := main.find_child("GerenciadorMapa", true, false) as GerenciadorMapa
		if mapa != null and not com_planta:
			mapa.planta = null
		add_child(main)
		await get_tree().process_frame
		await get_tree().process_frame
		if mapa == null:
			main.free()
			continue

		_medir(rotulo, mapa)
		if com_janela:
			await _fotografar(rotulo, mapa, main)
		main.queue_free()
		await get_tree().process_frame

	get_tree().quit()


func _medir(rotulo: String, mapa: GerenciadorMapa) -> void:
	var conta := {}
	var vaos := {}
	for ligacao in mapa.ligacoes():
		var tipo: int = ligacao["tipo"]
		conta[tipo] = int(conta.get(tipo, 0)) + 1
		var caixa: Rect2 = ligacao["caixa"]
		# O comprimento da conexao e o maior lado da caixa dela: a largura e
		# sempre `Porta.LARGURA`.
		var comprimento := maxf(caixa.size.x, caixa.size.y)
		vaos[tipo] = float(vaos.get(tipo, 0.0)) + comprimento
	print("  --- planta %s ---" % rotulo)
	for tipo: int in conta:
		var n: int = conta[tipo]
		print("    %-22s %2d conexoes   travessia media %.0f px (%.2f s a 220 px/s)"
			% [PlantaDoAndar.nome_de(tipo as PlantaDoAndar.Conexao), n,
				float(vaos[tipo]) / float(n), float(vaos[tipo]) / float(n) / 220.0])


## Uma foto por TIPO de conexao, com o jogador no meio da travessia.
##
## Ela revela as duas salas antes de fotografar: sem isso a vizinha esta oculta
## (`_ocultar` desliga `visible`) e a foto mostraria uma sala e um vazio, que e
## exatamente a leitura que o epico existe para desfazer -- so que por outro
## motivo.
func _fotografar(rotulo: String, mapa: GerenciadorMapa, main: Node) -> void:
	var jogador := main.find_child("Player", true, false) as Node2D
	if jogador == null:
		return
	var camera := jogador.get_node_or_null("Camera") as Camera2D
	if camera == null:
		return
	camera.make_current()

	var vistos := {}
	for ligacao in mapa.ligacoes():
		var tipo: int = ligacao["tipo"]
		if vistos.has(tipo):
			continue
		vistos[tipo] = true
		mapa.ir_para_sala(ligacao["a"])
		await get_tree().process_frame
		mapa.ir_para_sala(ligacao["b"])
		await get_tree().process_frame
		var caixa: Rect2 = ligacao["caixa"]
		jogador.global_position = caixa.get_center()
		# A camera passa a enxergar as duas salas mais a conexao, que e o
		# enquadramento da travessia de verdade.
		var uniao := mapa.contorno_global_de(ligacao["a"])
		var alvo := _caixa(uniao).merge(_caixa(mapa.contorno_global_de(ligacao["b"])))
		camera.limit_left = int(alvo.position.x)
		camera.limit_top = int(alvo.position.y)
		camera.limit_right = int(alvo.end.x)
		camera.limit_bottom = int(alvo.end.y)
		for i in 5:
			await get_tree().process_frame
		await get_tree().create_timer(0.25).timeout
		var nome := "planta_%s_%s.png" % [rotulo,
			PlantaDoAndar.nome_de(tipo as PlantaDoAndar.Conexao)]
		get_viewport().get_texture().get_image().save_png("user://capturas/" + nome)
		print("    %s" % nome)


func _caixa(pontos: PackedVector2Array) -> Rect2:
	if pontos.is_empty():
		return Rect2()
	var caixa := Rect2(pontos[0], Vector2.ZERO)
	for p in pontos:
		caixa = caixa.expand(p)
	return caixa
