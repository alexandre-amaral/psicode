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


func _fotografar_sala() -> void:
	var sala: Sala = (load(SALA) as PackedScene).instantiate()
	sala.definir_visual(_dados_do_tipo("sala_1_retangular"))
	add_child(sala)
	await get_tree().process_frame
	sala.ativar()
	var limites := sala.obter_limites()
	var margens := RenderizadorParedes.margens(sala.perfil_de_parede())
	# O jogador da metade anterior morreu junto com o Lobby, entao esta metade
	# monta o seu. Sem camera o viewport cai na de fallback, na origem, e a sala
	# sai encostada no canto -- que se parece com um defeito de clamp e nao e.
	var p: Node2D = (load("res://src/player/player.tscn") as PackedScene).instantiate()
	add_child(p)
	p.global_position = Vector2(0.0, limites.position.y + 24.0)
	var camera := p.get_node_or_null("Camera") as Camera2D
	if camera != null:
		camera.make_current()
	if camera != null:
		# O mesmo retangulo do jogo: cresce pela parede desenhada e depois ate o
		# quadro, senao a sala mais estreita que a tela sai encostada numa borda.
		var visivel := limites.grow_individual(margens.x, margens.y, margens.z, margens.w)
		var gerenciador := GerenciadorMapa.new()
		visivel = gerenciador._cabendo_a_tela(visivel)
		gerenciador.free()
		camera.limit_left = int(visivel.position.x)
		camera.limit_top = int(visivel.position.y)
		camera.limit_right = int(visivel.end.x)
		camera.limit_bottom = int(visivel.end.y)
	await _assentar()
	_salvar("norte_sala.png")
	p.global_position = Vector2(0.0, limites.end.y - 24.0)
	await _assentar()
	_salvar("sul_sala.png")
	p.global_position = Vector2(limites.position.x + 24.0, limites.position.y + 24.0)
	await _assentar()
	_salvar("quina_sala.png")


func _assentar() -> void:
	for i in 5:
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout


func _salvar(nome: String) -> void:
	get_viewport().get_texture().get_image().save_png("user://capturas/" + nome)
	print("  %s" % nome)


## O `DadosSala` do tipo daquela cena, para a sala vestir o ESTILO de verdade.
##
## Sem isto a sala nasce com `_dados_visual` nulo, `_perfil()` devolve `null` e
## quem mede cai no `PerfilDeParede` default -- que e justamente o perfil que o
## jogo NAO usava. Uma ferramenta de medicao que se engana assim mede a regra e
## afirma que mediu o jogo, e foi o que aconteceu: a moldura foi medida em 18%
## enquanto a sala real desenhava o perfil C.
##
## `definir_visual()` roda ANTES do `add_child`, como `configurar_conexoes`: e o
## `_ready` que monta as camadas.
func _dados_do_tipo(nome_cena: String) -> DadosSala:
	var tipo := "combate"
	if nome_cena.ends_with("_boss"):
		tipo = "boss"
	elif nome_cena.ends_with("_arma"):
		tipo = "arma"
	elif nome_cena.ends_with("_item"):
		tipo = "item"
	elif nome_cena.ends_with("_inicial"):
		tipo = "inicial"
	return load("res://src/mapa/tipo_%s.tres" % tipo) as DadosSala
