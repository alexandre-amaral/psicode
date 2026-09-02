extends Node2D
## A MATRIZ DE PROPORCOES: a mesma sala nos quatro perfis, para comparar.
##
## O plano e explicito -- **nao decidir olhando so no editor.** "Parece melhor"
## nao sobrevive a memoria de dez minutos depois, e trocar um numero e olhar de
## novo compara a captura de agora com a lembranca da anterior, que e a pior
## regua possivel.
##
## Ele monta a MESMA sala quatro vezes, com a mesma semente e o mesmo conteudo,
## mudando so a espessura desenhada. E imprime a fracao de quadro que a
## arquitetura ocupa em cada uma -- que e a metrica do §40: 80-90% espaco de
## jogo, 10-20% moldura.

const CENA_SALA := "res://src/mapa/sala_1_retangular.tscn"
const PERFIS := ["A", "B", "C", "D"]


func _ready() -> void:
	for nome in PERFIS:
		await _fotografar(nome)
	print("matriz: %d perfis capturados em user://capturas" % PERFIS.size())
	get_tree().quit()


func _fotografar(nome: String) -> void:
	var perfil := PerfilDeParede.de_nome(nome)
	# O perfil entra por variavel de classe porque a `Sala` monta a fita no
	# proprio `_ready`: nao ha janela entre instanciar e desenhar para passar um
	# parametro. E uma valvula de FERRAMENTA, e por isso ela mora aqui e nao no
	# runtime -- o jogo le o perfil do estilo, como qualquer outro botao.
	Sala.perfil_de_teste = perfil

	var cena: PackedScene = load(CENA_SALA)
	var sala := cena.instantiate() as Sala
	sala.configurar_conexoes([])
	add_child(sala)
	await get_tree().process_frame
	await get_tree().process_frame

	# ZOOM PARA CABER A SALA INTEIRA MAIS A MOLDURA.
	#
	# Sem ele a camera enquadra so o chao: a sala tem o tamanho da tela, e o que
	# se quer comparar e justamente a faixa em volta. O zoom e o MESMO nos quatro
	# perfis -- calculado do maior deles -- senao cada captura teria uma escala
	# e a comparacao mediria o zoom em vez da parede.
	var contorno_zoom := sala.contorno_local()
	var caixa_zoom := Rect2(contorno_zoom[0], Vector2.ZERO)
	for ponto in contorno_zoom:
		caixa_zoom = caixa_zoom.expand(ponto)
	var maior := PerfilDeParede.de_nome("A").alcance()
	var precisa := caixa_zoom.size + Vector2(maior, maior) * 2.2
	var tela := Vector2(get_viewport().size)
	var fator := minf(tela.x / precisa.x, tela.y / precisa.y)

	var camera := Camera2D.new()
	camera.position = sala.global_position + caixa_zoom.get_center()
	camera.zoom = Vector2(fator, fator)
	add_child(camera)
	camera.make_current()
	await get_tree().create_timer(0.25).timeout

	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://capturas")
	img.save_png("user://capturas/matriz_%s.png" % nome)

	# A METRICA DO §40, impressa junto: quanto do quadro e moldura.
	#
	# Ela nao decide sozinha -- o criterio final e a leitura --, mas ela impede a
	# conversa de virar gosto: "parece pesada" e opiniao, "ocupa 23% do quadro" e
	# um numero que a proxima pessoa consegue conferir.
	var alcance := perfil.alcance()
	var contorno := sala.contorno_local()
	var caixa := Rect2(contorno[0], Vector2.ZERO)
	for ponto in contorno:
		caixa = caixa.expand(ponto)
	var quadro := caixa.size + Vector2(alcance, alcance) * 2.0
	var moldura := 1.0 - (caixa.size.x * caixa.size.y) / (quadro.x * quadro.y)
	print("  %s  norte %.0f/%.0f  lateral %.0f/%.0f  sul %.0f  ->  alcance %.0f, moldura %.1f%%"
		% [nome, perfil.topo_norte, perfil.face_norte, perfil.topo_lateral,
			perfil.face_lateral, perfil.topo_sul, alcance, moldura * 100.0])

	camera.queue_free()
	sala.free()
	Sala.perfil_de_teste = null
