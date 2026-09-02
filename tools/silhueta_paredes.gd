extends Node2D
## O TESTE DA SILHUETA: parede numa cor, chao em outra, textura nenhuma.
##
## E a primeira verificacao do plano, e ela e a mais dura de fraudar. A pergunta
## e uma so: **a forma parece uma sala, ou parece uma grade de construcao?**
##
## Se parecer grade, nao adianta avancar -- o problema esta na GEOMETRIA, e
## textura nova so deixaria os blocos mais bonitos. E a ordem que o plano manda
## evitar: mais detalhe, mais ferrugem, mais sombra, esperar que melhore.
##
## Ele desenha as tres superficies em cor chapada e ainda escreve um mapa de
## DEBUG com uma cor por camada, que responde a pergunta seguinte: se a silhueta
## estiver errada, **qual parte esta fazendo a parede parecer um bloco?**

const CENA := "res://src/mapa/sala_1_retangular.tscn"

## Uma cor por camada, como o plano pede.
const COR_CHAO := Color("3a3a3a")
const COR_TOPO := Color("2b6cb0")
const COR_FACE := Color("c53030")
const COR_COLISAO := Color("2f855a")


func _ready() -> void:
	await _fotografar(false, "silhueta")
	await _fotografar(true, "debug")
	print("silhueta: 2 fotos em user://capturas")
	get_tree().quit()


func _fotografar(por_camada: bool, nome: String) -> void:
	var cena: PackedScene = load(CENA)
	var sala := cena.instantiate() as Sala
	sala.configurar_conexoes([])
	add_child(sala)
	await get_tree().process_frame
	await get_tree().process_frame

	# O chao numa cor so: sem textura nao ha nada para o olho confundir com
	# estrutura, e a fronteira parede/chao fica sendo a unica coisa na tela.
	var chao := sala.get_node_or_null("Chao") as Polygon2D
	if chao != null:
		chao.texture = null
		chao.color = COR_CHAO

	var fita := sala.get_node_or_null("ParedeModulos") as Node2D
	if fita != null:
		var contorno := sala.contorno_local()
		var caixa := Rect2(contorno[0], Vector2.ZERO)
		for ponto in contorno:
			caixa = caixa.expand(ponto)
		for filho in fita.get_children():
			var poly := filho as Polygon2D
			if poly == null:
				continue
			poly.texture = null
			if not por_camada:
				# SILHUETA: parede inteira numa cor so. Topo e face juntos, para
				# a pergunta ser sobre a FORMA e nada mais.
				poly.color = COR_TOPO
				continue
			# DEBUG: a distancia ao contorno diz se aquela peca e face ou topo.
			var d := _profundidade(poly.position, contorno)
			poly.color = COR_FACE if d < RenderizadorParedes.margens().y * 0.5 else COR_TOPO

	if por_camada:
		var paredes := sala.get_node_or_null("Paredes") as StaticBody2D
		if paredes != null:
			for filho in paredes.get_children():
				var forma := filho as CollisionShape2D
				if forma == null:
					continue
				var linha := Line2D.new()
				linha.width = 3.0
				linha.default_color = COR_COLISAO
				linha.z_index = Sala.Z_FRENTE
				linha.z_as_relative = false
				var segmento := forma.shape as SegmentShape2D
				if segmento != null:
					linha.points = PackedVector2Array([segmento.a, segmento.b])
				sala.add_child(linha)

	var contorno_zoom := sala.contorno_local()
	var caixa_zoom := Rect2(contorno_zoom[0], Vector2.ZERO)
	for ponto in contorno_zoom:
		caixa_zoom = caixa_zoom.expand(ponto)
	var margem := RenderizadorParedes.margens()
	var precisa := caixa_zoom.size + Vector2(margem.x + margem.z, margem.y + margem.w) * 1.8
	var tela := Vector2(get_viewport().size)
	var fator := minf(tela.x / precisa.x, tela.y / precisa.y)

	var camera := Camera2D.new()
	camera.position = sala.global_position + caixa_zoom.get_center()
	camera.zoom = Vector2(fator, fator)
	add_child(camera)
	camera.make_current()
	await get_tree().create_timer(0.25).timeout

	DirAccess.make_dir_recursive_absolute("user://capturas")
	get_viewport().get_texture().get_image().save_png("user://capturas/parede_%s.png" % nome)
	print("  %s" % nome)
	camera.queue_free()
	sala.free()


func _profundidade(ponto: Vector2, contorno: PackedVector2Array) -> float:
	var perto := INF
	var total := contorno.size()
	for i in total:
		perto = minf(perto, ponto.distance_to(Geometry2D.get_closest_point_to_segment(
			ponto, contorno[i], contorno[(i + 1) % total])))
	return perto
