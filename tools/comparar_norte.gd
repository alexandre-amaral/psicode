extends Node2D
## Poe o LOBBY e uma SALA no mesmo enquadramento, com o jogador encostado na
## parede NORTE dos dois, e fotografa.
##
## O dono apontou a parede norte do Lobby como "precisamente como deve ser". A
## captura que existia (`capturar_lobby`) poe o jogador em y=-100, o que mostra
## so 52 dos 104 px de faixa -- ela fotografa a BAIA, e nao a parede. Sem ver a
## faixa inteira nao da para saber o que foi aprovado, e alinhar o plano a uma
## medicao errada custa as nove cenas de novo.

const SALA := "res://src/mapa/sala_1_retangular.tscn"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://capturas")
	await _fotografar_lobby()
	await _fotografar_sala()
	print("COMPARAR_NORTE: pronto")
	get_tree().quit()


func _fotografar_lobby() -> void:
	Save._caminho = "user://teste_comparar.json"
	Save.apagar_save()
	Progressao.criar_novo()
	var lobby: Node2D = (load("res://src/lobby/lobby.tscn") as PackedScene).instantiate()
	add_child(lobby)
	await get_tree().process_frame
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p != null:
		p.global_position = Vector2(0.0, -Lobby.ALTURA * 0.5 + 24.0)
	await _assentar()
	_salvar("norte_lobby.png")
	# O SUL e a QUINA, que e onde os defeitos apontados moram.
	if p != null:
		p.global_position = Vector2(0.0, Lobby.ALTURA * 0.5 - 24.0)
	await _assentar()
	_salvar("sul_lobby.png")
	if p != null:
		p.global_position = Vector2(-Lobby.LARGURA * 0.5 + 24.0, -Lobby.ALTURA * 0.5 + 24.0)
	await _assentar()
	_salvar("quina_lobby.png")
	lobby.queue_free()
	await get_tree().process_frame


## O POSICIONAMENTO e o de `EnquadramentoDeSala`, e nao uma copia dele.
##
## A #240 pediu que esta ferramenta e `comparar_topos` compartilhassem o
## enquadramento: duas copias divergem, e o sintoma e comparar coisas
## fotografadas de lugares diferentes sem nada acusar.
func _fotografar_sala() -> void:
	var sala := EnquadramentoDeSala.montar(self, SALA)
	await get_tree().process_frame
	sala.ativar()
	# O jogador da metade anterior morreu junto com o Lobby, entao esta metade
	# monta o seu. Sem camera o viewport cai na de fallback, na origem, e a sala
	# sai encostada no canto -- que se parece com um defeito de clamp e nao e.
	var p := EnquadramentoDeSala.acompanhar(self, sala)
	for onde in EnquadramentoDeSala.POSICOES:
		EnquadramentoDeSala.posicionar(p, sala, onde)
		await _assentar()
		_salvar("%s_sala.png" % onde)


func _assentar() -> void:
	for i in 5:
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout


func _salvar(nome: String) -> void:
	get_viewport().get_texture().get_image().save_png("user://capturas/" + nome)
	print("  %s" % nome)
