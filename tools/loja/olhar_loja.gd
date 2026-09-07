extends Node2D
## A Loja no enquadramento real do jogo, para a pergunta que nao se automatiza.
##
## O portao do epico e: *"sem UI, alguem que nunca viu o jogo diz que um
## comerciante ocupou um pedaco desta fabrica -- e nao que isto e uma loja
## generica?"*. Nenhum numero responde isso, entao ele fica como captura.

func _ready() -> void:
	var pool := load("res://src/items/pool_padrao.tres") as PoolLoot
	var dados := load("res://src/loja/loja_andar1.tres") as DadosLoja
	var sala := EnquadramentoDeSala.montar(self, "res://src/mapa/sala_10_loja.tscn")
	if sala is SalaLoja:
		(sala as SalaLoja).definir_ofertas(
			GeradorDeLoja.gerar(dados, pool, 20260907))
	sala.ativar()
	var jogador := EnquadramentoDeSala.acompanhar(self, sala)
	# Ao SUL: e por onde o jogador entra, e a composicao que ele ve na chegada e
	# o que o portao pergunta.
	EnquadramentoDeSala.posicionar(jogador, sala, "sul")
	# E depois JUNTO da bancada do meio: o portao visual pergunta pela chegada, e
	# o prompt so existe perto -- as duas coisas precisam da mesma foto.
	jogador.global_position = sala.global_position + Vector2(0.0, 6.0)
	for i in 6:
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute("user://capturas")
		get_viewport().get_texture().get_image().save_png("user://capturas/loja.png")
		print("  loja.png")
	get_tree().quit()
