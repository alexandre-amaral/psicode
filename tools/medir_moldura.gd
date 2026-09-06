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

	var chao := 0
	var faixa_pintada := 0
	var faixa_crua := 0
	var fora := 0
	var passo := 2  # amostra de 2 em 2: o veredicto e uma fracao, nao um pixel
	var total := 0
	var y := 0
	while y < imagem.get_height():
		var x := 0
		while x < imagem.get_width():
			total += 1
			var mundo := canto + Vector2(float(x), float(y))
			var regiao := _regiao(mundo, sala, perfil, limites)
			match regiao:
				0:
					chao += 1
				1:
					if _mesma_cor(imagem.get_pixel(x, y), vazio):
						faixa_crua += 1
					else:
						faixa_pintada += 1
				_:
					fora += 1
			x += passo
		y += passo

	var n := float(maxi(total, 1))
	print("%-22s %-8s %6.1f%% %6.1f%% %6.1f%% %6.1f%%" % [
		nome_cena, rotulo,
		chao / n * 100.0, faixa_pintada / n * 100.0,
		faixa_crua / n * 100.0, fora / n * 100.0])


## 0 = chao, 1 = faixa de parede daquele lado, 2 = alem de tudo.
##
## Usa o RETANGULO dos limites e nao o contorno exato: a sala em L teria uma
## quina concava, e o objetivo aqui e a moldura e nao a forma. A margem de cada
## lado sai do perfil, entao a faixa medida e exatamente a que o renderizador
## desenha.
func _regiao(mundo: Vector2, _sala: Sala, perfil: PerfilDeParede, limites: Rect2) -> int:
	if limites.has_point(mundo):
		return 0
	var m := perfil.margens()
	var faixa := Rect2(
		limites.position - Vector2(m.x, m.y),
		limites.size + Vector2(m.x + m.z, m.y + m.w))
	return 1 if faixa.has_point(mundo) else 2


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
