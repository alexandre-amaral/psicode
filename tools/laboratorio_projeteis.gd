extends Node
## O LABORATORIO DE PROJETEIS: as silhuetas lado a lado, e a regua que as mede.
##
## Nao existia lugar onde se olhasse dois projeteis juntos. Para comparar a
## Mantis com o Swarm era preciso jogar ate achar as duas armas -- e foi por isso
## que as 21 armas passaram anos desenhando A MESMA FORMA sem ninguem notar.
##
## DOIS MODOS, e o modo sai do DisplayServer e nao de uma bandeira, como no
## `arena_chefe.gd`:
##
##   godot --path . tools/laboratorio_projeteis.tscn --resolution 960x544
##     Com janela: a folha de silhuetas sobre o chao de verdade, com o circulo da
##     HITBOX desenhado por cima de cada uma. Silhueta que mente aparece como o
##     desenho saindo do circulo pelo LADO.
##
##   godot --headless --path . tools/laboratorio_projeteis.tscn
##     Sem janela: mede e imprime a tabela por arma, depois a lista de COLISOES
##     de leitura -- pares a menos de `LARGURA_MATIZ` que dividem silhueta.
##     Encerra com 1 se houver alguma.
##
## Argumentos, sempre depois de um `--` isolado:
##   --arma=rail_x     so ela, grande e VIVA (folha congelada nao mostra rastro)
##   --familia=AGULHA  todas as familias num raio fixo: julga a BIBLIOTECA
##   --raio=12         uma familia varrida por raio
##   --vivo            deixa tudo voar, em vez de congelar
##
## Ela NAO substitui `teste_linguagem_projetil.gd`. A suite cobra a conta; isto
## cobra que a conta virou tela -- a mesma relacao que `arena_chefe` tem com
## `teste_boss_guardiao`.
##
## ENCERRA EM TODO CAMINHO DE SAIDA, inclusive erro de argumento: cena headless
## que nao encerra vira runaway, e um `runner.tscn` esquecido ja acumulou 1574 s
## de CPU em tres horas girando num nucleo.

const CENA_SALA := preload("res://src/mapa/sala_1_retangular.tscn")
const CENA_PROJETIL := preload("res://src/projectiles/projetil.tscn")
const ARMAS := "res://src/weapons/"
const SAIDA := "user://capturas"

## Gemea de `teste_linguagem_projetil.LARGURA_MATIZ`. As duas respondem a mesma
## pergunta -- "estas duas cores leem como a mesma?" -- e divergir faria a regua
## aprovar o que o portao recusa.
const LARGURA_MATIZ := 15.0

## A grade da folha. Duas colunas cabem 21 armas em 960x544 com folga.
const PASSO_Y := 44.0
const PASSO_X := 430.0
const POR_COLUNA := 11

var _sala: Node2D = null
var _container: Node2D = null


func _ready() -> void:
	# A barra parada: o glitch de projetil hostil sacode o desenho conforme a
	# Deterioracao, e o que se julga aqui e a silhueta e nao o tremor.
	Deterioracao.passiva_ativa = false
	# Um frame antes de qualquer coisa, pelo mesmo motivo que o `runner.gd`:
	# `quit()` chamado de dentro do `_ready` nao encerra confiavelmente, e cena
	# headless que nao encerra vira runaway.
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		_medir()
		return
	await _montar_folha()


# -- modo headless ----------------------------------------------------------


func _medir() -> void:
	var nomes := _armas()
	if nomes.is_empty():
		print("nenhuma arma encontrada em %s" % ARMAS)
		get_tree().quit(1)
		return

	print("\n--- as silhuetas, arma por arma ---\n")
	print("%-18s %-9s %6s %-8s %5s %8s %7s %8s" % [
		"arma", "cor", "matiz", "familia", "raio", "lateral", "rastro", "vao"
	])
	print("-".repeat(78))
	for nome in nomes:
		var d := _arma(nome)
		var vao := d.velocidade_projetil / maxf(d.cadencia, 0.001)
		print("%-18s #%-8s %6.1f %-8s %5.1f %8d %7.0f %8.0f" % [
			nome,
			d.cor_projetil.to_html(false),
			d.cor_projetil.h * 360.0,
			FormasProjetil.nome(d.familia_silhueta),
			d.raio_projetil,
			FormasProjetil.lateral_de(d.raio_projetil),
			d.rastro_comprimento * d.raio_projetil,
			vao,
		])

	print("\n--- colisoes de leitura (menos de %.0f graus de matiz) ---\n" % LARGURA_MATIZ)
	var falhas := 0
	var proximos := 0
	for i in nomes.size():
		for j in range(i + 1, nomes.size()):
			var a := _arma(nomes[i])
			var b := _arma(nomes[j])
			var g := _distancia_de_matiz(a.cor_projetil, b.cor_projetil)
			if g >= LARGURA_MATIZ:
				continue
			proximos += 1
			var iguais := a.familia_silhueta == b.familia_silhueta
			if iguais:
				falhas += 1
			print("  %5.1f graus  %-18s %-18s  %s" % [
				g, nomes[i], nomes[j],
				"AMBAS %s" % FormasProjetil.nome(a.familia_silhueta) if iguais
					else "%s contra %s" % [
						FormasProjetil.nome(a.familia_silhueta),
						FormasProjetil.nome(b.familia_silhueta),
					],
			])
	if proximos == 0:
		print("  nenhum par proximo -- a regua nao mediu nada, e isso e suspeito")

	print("\n--- resultado ---")
	if falhas > 0:
		print("  FALHOU: %d par(es) de cor proxima dividem silhueta" % falhas)
		get_tree().quit(1)
		return
	print("  PASSOU: %d arma(s), %d par(es) proximos, todos com silhueta propria"
		% [nomes.size(), proximos])
	get_tree().quit()


# -- modo janela ------------------------------------------------------------


func _montar_folha() -> void:
	DirAccess.make_dir_recursive_absolute(SAIDA)

	_sala = CENA_SALA.instantiate()
	add_child(_sala)

	# Obrigatorio: NENHUMA cena de src/ entra neste grupo, entao em jogo
	# `Arma._container()` cai no `current_scene`. Sem cria-lo aqui, um projetil
	# vivo iria para a raiz -- ou pior, para um container vazado de outra cena.
	_container = Node2D.new()
	_container.name = "ContainerProjeteis"
	_container.add_to_group("container_projeteis")
	_sala.add_child(_container)

	var arma_pedida := _texto("--arma=")
	var familia_pedida := _texto("--familia=")
	if arma_pedida != "":
		_uma_arma(arma_pedida)
	elif familia_pedida != "":
		_uma_familia(familia_pedida)
	else:
		_todas_as_armas()

	_montar_camera()
	await _fotografar()


func _todas_as_armas() -> void:
	var nomes := _armas()
	for i in nomes.size():
		var d := _arma(nomes[i])
		var onde := Vector2(
			-380.0 + float(i / POR_COLUNA) * PASSO_X,
			-220.0 + float(i % POR_COLUNA) * PASSO_Y
		)
		_plantar(d, onde, nomes[i])


func _uma_arma(nome: String) -> void:
	var d := _arma(nome)
	if d == null:
		print("arma desconhecida: %s" % nome)
		get_tree().quit(1)
		return
	_plantar(d, Vector2.ZERO, nome)


## A folha que julga a BIBLIOTECA, e nao o elenco: uma familia por raio.
func _uma_familia(nome: String) -> void:
	var alvo := -1
	for f in FormasProjetil.Familia.values():
		if String(FormasProjetil.nome(f)).to_lower() == nome.to_lower():
			alvo = f
	if alvo < 0:
		print("familia desconhecida: %s" % nome)
		get_tree().quit(1)
		return
	var base := _arma("pistola")
	var raios: Array[float] = [3.0, 5.0, 9.0, 16.0]
	for i in raios.size():
		var d: DadosArma = base.duplicate()
		d.familia_silhueta = alvo
		d.raio_projetil = raios[i]
		_plantar(d, Vector2(-260.0 + float(i) * 170.0, 0.0),
			"%s r%.0f" % [FormasProjetil.nome(alvo), raios[i]])


## Um projetil parado, com o circulo da hitbox por cima e o nome ao lado.
func _plantar(dados: DadosArma, onde: Vector2, rotulo: String) -> void:
	var p := CENA_PROJETIL.instantiate()
	p.name = "Projetil_%s" % rotulo.replace(" ", "_")
	_container.add_child(p)
	# add_child ANTES de configurar, como a Arma faz -- e e por isso que o
	# `_aplicar_aparencia()` do projetil roda duas vezes.
	p.configurar(onde, Vector2.RIGHT, dados, false)
	p.position = onde

	if not _tem("--vivo"):
		p.set_physics_process(false)
		p.set_process(false)
		# Parar o processamento nao basta: o projetil continua no espaco de
		# fisica e some ao encostar em alguem.
		(p as Area2D).monitoring = false
		(p as Area2D).monitorable = false
		for filho in p.get_children():
			var forma := filho as CollisionShape2D
			if forma != null:
				forma.set_deferred("disabled", true)

	# O CIRCULO DA HITBOX. E o que torna visivel o portao de coerencia: a
	# silhueta pode avancar o quanto quiser na horizontal, mas encostar no
	# circulo por CIMA ou por BAIXO -- nunca sair dele.
	var anel := Line2D.new()
	anel.width = 1.0
	anel.default_color = Color(1.0, 1.0, 1.0, 0.85)
	anel.z_index = 5
	anel.position = onde
	var passos := 28
	# Fecha o anel repetindo o primeiro ponto: `Line2D` nao fecha sozinho, ao
	# contrario do `Polygon2D` -- a mesma distincao que a `AreaDePerigo` paga.
	for k in passos + 1:
		var a := TAU * float(k) / float(passos)
		anel.add_point(Vector2(cos(a), sin(a)) * dados.raio_projetil)
	_sala.add_child(anel)

	# `Label` e nao `Label2D`: este build do Godot nao tem o segundo, e uma cena
	# de ferramenta que nao PARSEIA fica pendurada para sempre -- o parse error
	# acontece antes de qualquer `quit()` que este arquivo escreva.
	var etiqueta := Label.new()
	etiqueta.text = "%s  %s  r%.1f" % [
		rotulo, FormasProjetil.nome(dados.familia_silhueta), dados.raio_projetil
	]
	etiqueta.position = onde + Vector2(46.0, -12.0)
	etiqueta.modulate = Color(1.0, 1.0, 1.0, 0.75)
	etiqueta.z_index = 5
	_sala.add_child(etiqueta)


## Camera propria em zoom 1.0: a do jogo e clampada, e julgar silhueta com zoom
## fracionario e julgar uma imagem borrada.
func _montar_camera() -> void:
	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE
	_sala.add_child(cam)
	cam.make_current()


func _fotografar() -> void:
	if _tem("--vivo"):
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var caminho := "%s/projeteis.png" % SAIDA
	get_viewport().get_texture().get_image().save_png(caminho)
	print("capturado: %s" % ProjectSettings.globalize_path(caminho))
	get_tree().quit()


# -- helpers ----------------------------------------------------------------


## Os `.tres` de arma do disco, sem o FEIXE -- ele nao instancia projetil.
func _armas() -> Array[String]:
	var fora: Array[String] = []
	var pasta := DirAccess.open(ARMAS)
	if pasta == null:
		return fora
	var arquivos := pasta.get_files()
	arquivos.sort()
	for arquivo in arquivos:
		if not arquivo.ends_with(".tres"):
			continue
		var d := load(ARMAS + arquivo) as DadosArma
		if d == null or d.e_feixe():
			continue
		fora.append(arquivo.get_basename())
	return fora


func _arma(nome: String) -> DadosArma:
	return load(ARMAS + nome + ".tres") as DadosArma


func _distancia_de_matiz(a: Color, b: Color) -> float:
	var d: float = fmod(absf(a.h - b.h), 1.0)
	return minf(d, 1.0 - d) * 360.0


## Le de `get_cmdline_user_args()` -- o que vem DEPOIS do `--` --, que e o unico
## lugar onde um argumento nosso nao briga com uma opcao do proprio Godot.
func _texto(prefixo: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefixo):
			return arg.substr(prefixo.length())
	return ""


func _tem(bandeira: String) -> bool:
	return OS.get_cmdline_user_args().has(bandeira)
