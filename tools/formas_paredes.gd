extends Node2D
## As NOVE FORMAS e o corredor, cada um numa foto, com o mesmo zoom.
##
## O criterio 12 do plano: **o mesmo sistema funciona em sala em L.** Ela e a
## forma que quebra parede escrita so para retangulo -- seis lados e uma quina
## CONCAVA, onde as duas faixas se sobrepoem em vez de deixarem vao.
##
## E o corredor entra junto porque atravessar de uma sala para ele nao pode
## trocar a leitura no meio da passagem. Se a moldura fechar na sala e abrir no
## corredor, o jogador ve a perspectiva mudar quando passa a porta.

const CENAS := [
	"res://src/mapa/sala_1_retangular.tscn",
	"res://src/mapa/sala_2_l_shape.tscn",
	"res://src/mapa/sala_5_pilar.tscn",
	"res://src/mapa/sala_6_boss.tscn",
]


func _ready() -> void:
	for caminho in CENAS:
		await _fotografar(caminho)
	await _fotografar_corredor()
	print("formas: %d fotos em user://capturas" % (CENAS.size() + 1))
	get_tree().quit()


func _fotografar(caminho: String) -> void:
	var cena: PackedScene = load(caminho)
	if cena == null:
		print("  %s NAO CARREGOU" % caminho)
		return
	var sala := cena.instantiate() as Sala
	sala.configurar_conexoes([])
	add_child(sala)
	await get_tree().process_frame
	await get_tree().process_frame
	await _fotografar_no(sala, sala.contorno_local(), caminho.get_file().get_basename())
	sala.free()


func _fotografar_corredor() -> void:
	var corredor := Corredor.new()
	add_child(corredor)
	corredor.configurar(Vector2.ZERO, Vector2(480.0, 0.0), Porta.LARGURA)
	await get_tree().process_frame
	await get_tree().process_frame
	var caixa := PackedVector2Array([
		Vector2(-260.0, -80.0), Vector2(260.0, -80.0),
		Vector2(260.0, 80.0), Vector2(-260.0, 80.0),
	])
	await _fotografar_no(corredor, caixa, "corredor")
	corredor.free()


func _fotografar_no(alvo: Node2D, contorno: PackedVector2Array, nome: String) -> void:
	var caixa := Rect2(contorno[0], Vector2.ZERO)
	for ponto in contorno:
		caixa = caixa.expand(ponto)
	var margem := RenderizadorParedes.margens()
	var precisa := caixa.size + Vector2(margem.x + margem.z, margem.y + margem.w) * 1.6
	var tela := Vector2(get_viewport().size)
	var fator := minf(tela.x / precisa.x, tela.y / precisa.y)

	var camera := Camera2D.new()
	camera.position = alvo.global_position + caixa.get_center()
	camera.zoom = Vector2(fator, fator)
	add_child(camera)
	camera.make_current()
	await get_tree().create_timer(0.25).timeout

	DirAccess.make_dir_recursive_absolute("user://capturas")
	get_viewport().get_texture().get_image().save_png("user://capturas/forma_%s.png" % nome)
	print("  %s" % nome)
	camera.queue_free()
