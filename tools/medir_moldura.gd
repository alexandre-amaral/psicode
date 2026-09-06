extends Node2D
## Quanto de cada quadro e CHAO, PAREDE PINTADA e VAZIO PRETO.
##
## O dono apontou que a textura da parede mudou mas o ASPECTO nao, e que a
## mudanca de enquadramento deixou "uma area fora da sala completamente preta
## onde, se texturizada corretamente, a parede funcionaria como no norte". Isso e
## uma afirmacao sobre PIXELS, e portanto e medivel -- e medir vem antes de
## reescrever a regra, senao a regra nova persegue uma impressao.
##
## A classificacao e por GEOMETRIA e nao por cor, porque cor nao separa "vazio"
## de "parede muito escura":
##
##   CHAO    dentro do contorno da sala
##   FAIXA   fora do contorno, dentro de `perfil.profundidade(lado)` daquele lado
##   VAZIO   alem disso -- e onde nao ha nada desenhado
##
## E dentro da FAIXA ele ainda separa PINTADA de CRUA: pixel igual ao
## `default_clear_color` e faixa que ninguem vestiu. Uma faixa larga que ninguem
## pinta le exatamente como vazio, e e essa a diferenca que o dono esta vendo.

const CENAS := "res://src/mapa/"

## Onde o jogador e posto, em fracao do meio-tamanho da sala. As cinco posicoes
## sao os extremos do clamp mais o centro: e nos extremos que a parede entra em
## quadro, e e por isso que medir so o centro esconderia o problema.
const POSTOS := {
	"centro": Vector2(0.0, 0.0),
	"norte": Vector2(0.0, -0.92),
	"sul": Vector2(0.0, 0.92),
	"leste": Vector2(0.92, 0.0),
	"oeste": Vector2(-0.92, 0.0),
}


func _ready() -> void:
	# ELA PRECISA DE JANELA, e sem uma o sintoma nao diz isso.
	#
	# A regua LE O QUADRO (`get_viewport().get_texture()`), e com `--headless` o
	# rasterizador e o dummy: a textura volta nula e o console enche de
	# `Parameter "t" is null` uma vez por cena, sem nenhuma linha dizendo o que
	# fazer. Uma rodada em background terminou com codigo ZERO e 45 erros,
	# parecendo um defeito do medidor.
	if DisplayServer.get_name() == "headless":
		print("MEDIR_MOLDURA precisa de JANELA -- ela le o quadro renderizado.")
		print("  godot --path . tools/medir_moldura.tscn --resolution 960x544")
		get_tree().quit()
		return
	var tela := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 544))
	)
	var vazio: Color = ProjectSettings.get_setting(
		"rendering/environment/defaults/default_clear_color", Color("0b0d16"))

	print("\nquanto de cada quadro e CHAO, FAIXA e VAZIO (tela %.0fx%.0f)" % [tela.x, tela.y])
	print("%-22s %-8s %7s %7s %7s %7s" % [
		"cena", "posto", "chao", "faixa", "  crua", "vazio"])

	for nome_cena in _cenas():
		var cena: PackedScene = load(CENAS + nome_cena + ".tscn")
		if cena == null:
			continue
		var sala := cena.instantiate() as Sala
		sala.definir_visual(_dados_do_tipo(nome_cena))
		add_child(sala)
		await get_tree().process_frame
		sala.ativar()

		var player: Node2D = (load("res://src/player/player.tscn") as PackedScene).instantiate()
		add_child(player)
		var camera := player.get_node_or_null("Camera") as Camera2D
		if camera != null:
			camera.make_current()

		var limites := sala.obter_limites()
		var perfil := sala.perfil_de_parede()
		if perfil == null:
			perfil = PerfilDeParede.new()
		var m := perfil.margens()
		var gerenciador := GerenciadorMapa.new()
		var visivel: Rect2 = gerenciador._cabendo_a_tela(
			limites.grow_individual(m.x, m.y, m.z, m.w))
		gerenciador.free()
		if camera != null:
			camera.limit_left = int(visivel.position.x)
			camera.limit_top = int(visivel.position.y)
			camera.limit_right = int(visivel.end.x)
			camera.limit_bottom = int(visivel.end.y)

		for rotulo in POSTOS:
			var f: Vector2 = POSTOS[rotulo]
			player.global_position = limites.get_center() + f * limites.size * 0.5
			for i in 4:
				await get_tree().process_frame
			await get_tree().create_timer(0.15).timeout
			_medir(nome_cena, rotulo, sala, perfil, limites, tela, vazio)

		player.queue_free()
		sala.queue_free()
		await get_tree().process_frame

	print("")
	get_tree().quit()


func _medir(nome_cena: String, rotulo: String, sala: Sala, perfil: PerfilDeParede,
		limites: Rect2, tela: Vector2, vazio: Color) -> void:
	var imagem := get_viewport().get_texture().get_image()
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	# O canto superior esquerdo do quadro, em coordenadas de mundo.
	var canto := camera.get_screen_center_position() - tela * 0.5

	var contorno := sala.contorno_local()
	var m_perfil := perfil.margens()
	var fundo: float = maxf(maxf(m_perfil.x, m_perfil.y), maxf(m_perfil.z, m_perfil.w))
	var inflados := Geometry2D.offset_polygon(contorno, fundo)

	var chao := 0
	var faixa_pintada := 0
	var faixa_crua := 0
	var fora := 0
	var cruas_por_lugar := {}
	var passo := 2  # amostra de 2 em 2: o veredicto e uma fracao, nao um pixel
	var total := 0
	var y := 0
	while y < imagem.get_height():
		var x := 0
		while x < imagem.get_width():
			total += 1
			var mundo := canto + Vector2(float(x), float(y))
			var regiao := _regiao(mundo - sala.global_position, contorno, inflados)
			match regiao:
				0:
					chao += 1
				1:
					if _mesma_cor(imagem.get_pixel(x, y), vazio):
						faixa_crua += 1
						var onde := _onde_na_faixa(mundo, limites)
						cruas_por_lugar[onde] = int(cruas_por_lugar.get(onde, 0)) + 1
					else:
						faixa_pintada += 1
				_:
					fora += 1
			x += passo
		y += passo

	var n := float(maxi(total, 1))
	var detalhe := ""
	if not cruas_por_lugar.is_empty():
		var partes: Array[String] = []
		var chaves := cruas_por_lugar.keys()
		chaves.sort()
		for k: String in chaves:
			partes.append("%s %.1f%%" % [k, int(cruas_por_lugar[k]) / n * 100.0])
		detalhe = "   cru em: " + ", ".join(partes)
	print("%-22s %-8s %6.1f%% %6.1f%% %6.1f%% %6.1f%%%s" % [
		nome_cena, rotulo,
		chao / n * 100.0, faixa_pintada / n * 100.0,
		faixa_crua / n * 100.0, fora / n * 100.0, detalhe])


## 0 = chao, 1 = faixa de parede, 2 = alem de tudo.
##
## Usa o CONTORNO REAL e nao o retangulo dos limites. Com o retangulo, a sala em
## L contava o proprio recorte como faixa nao pintada: 12,5% de "cru" que nao era
## buraco nenhum, era a forma da sala. Uma regua que inventa defeito na forma
## mais incomum do jogo e uma regua que sera ignorada justamente onde importa.
## `inflados` vem PRONTO de fora, e isso nao e microotimizacao.
##
## `Geometry2D.offset_polygon` chamado por pixel sao ~130 mil chamadas por
## captura e 45 capturas por rodada: a ferramenta parou de terminar. O contorno
## nao muda dentro de uma cena, entao ele e calculado uma vez.
func _regiao(local: Vector2, contorno: PackedVector2Array,
		inflados: Array[PackedVector2Array]) -> int:
	if Geometry2D.is_point_in_polygon(local, contorno):
		return 0
	for inflado in inflados:
		if Geometry2D.is_point_in_polygon(local, inflado):
			return 1
	return 2


## ONDE na faixa este pixel cru caiu: um dos quatro lados, ou uma quina.
##
## "Cru" e faixa que ninguem pintou -- pixel da cor do vazio DENTRO da regiao que
## deveria ser parede. Sem saber onde, o numero e so um incomodo; com o lugar,
## ele aponta o desenho que faltou. Foi assim que o buraco alem das portas
## apareceu: "lateral 1,9%" em toda posicao de uma sala de quatro portas.
func _onde_na_faixa(mundo: Vector2, limites: Rect2) -> String:
	var acima := mundo.y < limites.position.y
	var abaixo := mundo.y > limites.end.y
	var esquerda := mundo.x < limites.position.x
	var direita := mundo.x > limites.end.x
	if (acima or abaixo) and (esquerda or direita):
		return "quina"
	if acima:
		return "norte"
	if abaixo:
		return "sul"
	if esquerda or direita:
		return "lateral"
	# Dentro do retangulo em x e y, mas fora do chao: e o recorte da forma (o vao
	# do L), e nao um buraco de parede.
	return "recorte"


func _mesma_cor(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02


func _cenas() -> Array[String]:
	var fora: Array[String] = []
	var pasta := DirAccess.open(CENAS)
	if pasta == null:
		return fora
	var arquivos := pasta.get_files()
	arquivos.sort()
	for arquivo in arquivos:
		if arquivo.begins_with("sala_") and arquivo.ends_with(".tscn"):
			fora.append(arquivo.get_basename())
	return fora


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
