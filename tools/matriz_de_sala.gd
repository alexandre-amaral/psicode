extends Node2D
## A MATRIZ DE SALA: quanto da TELA vira parede, no enquadramento real do jogo.
##
## Ela existe porque a decisao tem de ser tomada OLHANDO, e antes de nove cenas
## serem mexidas. O pedido do dono foi literal: *"apenas diminuir ou aumentar
## fara com que, caso a parede fique pequena ainda depois da implementacao, tenha
## que descartar toda a mudanca."*
##
## ELA NAO SUBSTITUI `matriz_paredes.tscn`, e a diferenca nao e de detalhe.
## Aquela da ZOOM PARA FORA ate a sala inteira caber e pergunta *"quanto da
## composicao sala+moldura e moldura?"* -- e assim mediu 19,5% no perfil C. Esta
## pergunta *"quanto da TELA e parede enquanto se joga?"*, com a camera no regime
## real: zoom 1,0 e o clamp de verdade.
##
## As duas discordam hoje de forma extrema -- 19,5% contra praticamente ZERO --,
## e nenhuma esta errada. A parede simplesmente esta fora do quadro: seis das
## nove salas tem EXATAMENTE o tamanho da viewport, a camera desliza 64x68 px, e
## o jogador ve parede de 7% do espaco.
##
## A ARITMETICA QUE ELA MEDE, e que nao tem saida: para a parede estar sempre
## visivel, `sala + profundidade da parede <= viewport`. Se a parede engorda para
## ocupar mais tela, a sala encolhe mais. Nao ha terceira opcao -- e por isso a
## escolha e uma matriz, e nao um palpite.
##
## Uso: godot --path . tools/matriz_de_sala.tscn --resolution 960x544
## Sai em user://capturas/matriz_sala_*.png

const CENA_SALA := "res://src/mapa/sala_1_retangular.tscn"
const SAIDA := "user://capturas"

## As margens que a sala de HOJE deixa entre o contorno e a `area_spawn`:
## (960-704)/2 = 128 na horizontal, (544-352)/2 = 96 na vertical.
##
## Elas sao mantidas em ABSOLUTO e nao em proporcao, e isso e deliberado: os
## props vivem nessa margem, precisam de 40 px livres ate o contorno e 96 px de
## distancia de porta, e `_sortear_ponto_de_prop()` desiste apos 12 tentativas
## **sem nenhum aviso**. Encolher a margem junto com a sala os faria sumir em
## silencio -- e `teste_props.gd` so cobra `get_child_count() > 0`.
const MARGEM_DE_PROP := Vector2(256.0, 192.0)

## Um degrau por linha da tabela de decisao. Nao e a explosao combinatoria: cada
## linha e o MAIOR tamanho de sala que ainda cabe com aquela parede.
##
## `perfil` nulo = o perfil C que roda hoje.
const CASOS := [
	{"nome": "0_hoje_960x544_C", "w": 960, "h": 544, "perfil": "C",
		"diz": "o estado de hoje, para referencia"},
	{"nome": "1_896x448_C", "w": 896, "h": 448, "perfil": "C",
		"diz": "o menor encolhimento possivel, sem tocar na parede"},
	{"nome": "2_864x448_B", "w": 864, "h": 448, "perfil": "B",
		"diz": "parede um pouco mais grossa"},
	{"nome": "3_832x416_A", "w": 832, "h": 416, "perfil": "A",
		"diz": "o perfil que a MOLDURA considerou pesado demais"},
	{"nome": "4_864x416_N80", "w": 864, "h": 416, "perfil": "N80",
		"diz": "norte de 80 px: a parede ocupa quase o dobro de hoje"},
	{"nome": "5_832x384_N96", "w": 832, "h": 384, "perfil": "N96",
		"diz": "norte de 96 px, o mais grosso que ainda deixa sala jogavel"},
	{"nome": "6_896x448_E", "w": 896, "h": 448, "perfil": "E",
		"diz": "os px extras na FACE e nao no topo: mesma moldura do C, mais altura"},
	{"nome": "7_864x416_F", "w": 864, "h": 416, "perfil": "F",
		"diz": "o mesmo raciocinio, um degrau acima"},
]

var _linhas: Array[String] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAIDA)
	for caso in CASOS:
		await _medir(caso)
	Sala.perfil_de_teste = null

	print("\n--- quanto da TELA e o que, no enquadramento real ---\n")
	print("%-18s %-11s %8s %8s %8s %8s  %s" % [
		"caso", "sala", "norte%", "moldura%", "vazio%", "piso%", "ve parede de"])
	print("-".repeat(96))
	for linha in _linhas:
		print(linha)
	print("\nAs seis capturas estao em %s" % ProjectSettings.globalize_path(SAIDA))
	print("A escolha e por IMAGEM. O numero so diz o que a imagem ja mostra.")
	get_tree().quit()


func _medir(caso: Dictionary) -> void:
	var perfil := _perfil_de(caso["perfil"] as String)
	# A VALVULA TEM DE SER ARMADA ANTES DO `add_child`.
	#
	# `Sala._ready()` monta chao, fita, sombra e colisao a partir do `Line2D`, e
	# nao ha janela depois disso -- e a mesma razao pela qual `perfil_de_teste` e
	# variavel de classe e nao parametro.
	Sala.perfil_de_teste = perfil

	var cena: PackedScene = load(CENA_SALA)
	var sala := cena.instantiate() as Sala
	var largura := float(caso["w"])
	var altura := float(caso["h"])
	_reescrever_contorno(sala, largura, altura)
	sala.configurar_conexoes([])
	add_child(sala)
	await get_tree().process_frame
	await get_tree().process_frame

	var camera := _camera_do_jogo(sala, perfil, largura, altura)
	await get_tree().create_timer(0.2).timeout

	var imagem := get_viewport().get_texture().get_image()
	imagem.save_png("%s/matriz_sala_%s.png" % [SAIDA, caso["nome"]])
	_anotar(caso, perfil, largura, altura, imagem)

	camera.queue_free()
	sala.queue_free()
	await get_tree().process_frame


## Reescreve o retangulo do contorno, ANTES de a sala entrar na arvore.
##
## Tambem move as quatro portas para o meio dos lados novos e encolhe a
## `area_spawn` mantendo a MARGEM DE PROP em absoluto -- senao a sala montada
## aqui nao seria a sala que o jogo montaria com esses numeros.
func _reescrever_contorno(sala: Sala, largura: float, altura: float) -> void:
	var mx := largura * 0.5
	var my := altura * 0.5
	var parede := sala.get_node_or_null("Parede") as Line2D
	if parede != null:
		parede.points = PackedVector2Array([
			Vector2(-mx, -my), Vector2(mx, -my), Vector2(mx, my),
			Vector2(-mx, my), Vector2(-mx, -my),
		])
	sala.area_spawn = Rect2(
		-(largura - MARGEM_DE_PROP.x) * 0.5, -(altura - MARGEM_DE_PROP.y) * 0.5,
		largura - MARGEM_DE_PROP.x, altura - MARGEM_DE_PROP.y)

	var portas := sala.get_node_or_null("Portas")
	if portas == null:
		return
	for filho in portas.get_children():
		var porta := filho as Porta
		if porta == null:
			continue
		var v := porta.vetor()
		porta.position = Vector2(v.x * mx, v.y * my)


## A camera do JOGO: zoom 1,0 e o mesmo clamp que `GerenciadorMapa._clampar()`
## aplica, com o jogador no centro da sala.
##
## O centro e o pior caso de proposito -- e de la que o jogador passa o combate,
## e e de la que a parede some. Medir com o jogador encostado na parede mediria
## o unico lugar onde ela ja aparece hoje.
func _camera_do_jogo(sala: Sala, perfil: PerfilDeParede, largura: float, altura: float) -> Camera2D:
	var m := perfil.margens()
	var camera := Camera2D.new()
	camera.zoom = Vector2.ONE
	camera.position = sala.global_position
	camera.limit_left = roundi(sala.global_position.x - largura * 0.5 - m.x)
	camera.limit_top = roundi(sala.global_position.y - altura * 0.5 - m.y)
	camera.limit_right = roundi(sala.global_position.x + largura * 0.5 + m.z)
	camera.limit_bottom = roundi(sala.global_position.y + altura * 0.5 + m.w)
	add_child(camera)
	camera.make_current()
	return camera


func _anotar(caso: Dictionary, perfil: PerfilDeParede, largura: float,
		altura: float, imagem: Image) -> void:
	var tela := Vector2(get_viewport().size)
	var area_tela := tela.x * tela.y
	var m := perfil.margens()
	var norte := m.y
	var quadro := Vector2(largura + m.x + m.z, altura + m.y + m.w)

	# Quanto de cada coisa cabe na TELA. Sala maior que a tela e recortada: o que
	# nao cabe nao conta, porque o jogador nao ve.
	var piso := minf(largura, tela.x) * minf(altura, tela.y)
	var com_moldura := minf(quadro.x, tela.x) * minf(quadro.y, tela.y)
	var moldura := maxf(com_moldura - piso, 0.0)
	var vazio := maxf(area_tela - com_moldura, 0.0)

	# De que fracao do eixo se ve parede: a camera so encosta no limite nos
	# extremos, e fora deles o jogador ve so chao naquele eixo.
	var pan := Vector2(maxf(0.0, quadro.x - tela.x), maxf(0.0, quadro.y - tela.y))
	var ve_x := 100.0 if pan.x <= 0.0 else minf(100.0, pan.x / largura * 100.0)
	var ve_y := 100.0 if pan.y <= 0.0 else minf(100.0, pan.y / altura * 100.0)

	var regua := ReguaDeProfundidade.medir(imagem)
	_linhas.append("%-18s %4dx%-6d %7.1f%% %7.1f%% %7.1f%% %7.1f%%  x %3.0f%% y %3.0f%%  amp %.2f %s" % [
		caso["nome"], int(largura), int(altura),
		norte / tela.y * 100.0, moldura / area_tela * 100.0,
		vazio / area_tela * 100.0, piso / area_tela * 100.0,
		ve_x, ve_y, regua["amplitude"],
		"" if regua["passou"] else "[cavidade REPROVA]",
	])


## Os perfis da matriz. Os quatro nomeados vem de `PerfilDeParede.de_nome()`; os
## dois de norte grosso sao construidos aqui porque so existem para esta decisao
## -- se um deles for escolhido, ele vira um preset de verdade.
func _perfil_de(nome: String) -> PerfilDeParede:
	# E e F gastam os pixels extras na FACE, e nao no topo.
	#
	# A face e a UNICA superficie vista de frente -- e dela que vem a altura da
	# sala. Engordar o topo sobe a fracao de moldura sem subir a leitura, e foi
	# isso que fez o perfil A parecer pesado: 64 px de topo SUL, superficie
	# chapada vista de cima, que nao carrega volume nenhum.
	#
	# O E tem a mesma fracao de moldura que o C e 40% mais altura de face. E as
	# margens verticais dele somam 96, entao 448 + 96 = 544 EXATO: zero px de
	# folga na vertical, que e o encaixe mais limpo possivel.
	if nome == "E":
		var e := PerfilDeParede.new()
		e.topo_norte = 16.0
		e.face_norte = 40.0
		e.topo_lateral = 16.0
		e.face_lateral = 16.0
		e.topo_sul = 16.0
		e.borda_externa_sul = 24.0
		return e
	if nome == "F":
		var f := PerfilDeParede.new()
		f.topo_norte = 24.0
		f.face_norte = 48.0
		f.topo_lateral = 24.0
		f.face_lateral = 24.0
		f.topo_sul = 24.0
		f.borda_externa_sul = 16.0
		return f
	if nome == "N80":
		var p := PerfilDeParede.new()
		p.topo_norte = 32.0
		p.face_norte = 48.0
		p.topo_lateral = 24.0
		p.face_lateral = 24.0
		p.topo_sul = 24.0
		p.borda_externa_sul = 12.0
		return p
	if nome == "N96":
		var q := PerfilDeParede.new()
		q.topo_norte = 32.0
		q.face_norte = 64.0
		q.topo_lateral = 32.0
		q.face_lateral = 32.0
		q.topo_sul = 28.0
		q.borda_externa_sul = 12.0
		return q
	return PerfilDeParede.de_nome(nome)
