extends Node2D
## O ANDAR 1 fotografado SEM HUD, para o portao de paleta medir o que o jogador
## de fato ve.
##
## ## Por que ela existe
##
## `tools/texturas/medir_ambiente.tscn` mede a PASTA `assets/texturas/`, e a
## pasta mente sobre o andar. A sala do chefe tem **10 dos 56 arquivos (18%)**;
## numa run ela e uma sala em dez, e as faces dela so aparecem num lado de uma
## sala. Por isso aquele portao reprova hoje em magenta (14,20% contra um teto
## de 2%) **por causa da regua, e nao da arte**.
##
## Um quadro de jogo pesa cada textura pela area que ela de fato ocupa: o chao
## domina, a face aparece num lado so, o decalque e uma peca por sala. E o unico
## jeito de a dominancia querer dizer alguma coisa.
##
## ## Por que SEM HUD
##
## A HUD e ciano e magenta de proposito -- ela e SINAL, e sinal e a familia que
## o portao existe para manter rara no AMBIENTE. Fotografar com ela dentro
## contaria a barra de vida como se fosse parede, e o andar reprovaria por causa
## da interface. `capturar.tscn` fotografa o jogo inteiro e continua servindo
## para revisao visual; esta aqui serve para MEDIR.
##
## Uso:
##   godot --path . tools/fabrica/olhar_andar.tscn --resolution 960x544
##   godot --headless --path . tools/texturas/medir_ambiente.tscn -- --pasta=user://capturas/andar
##
## Sem janela ela nao tem o que fotografar e diz isso -- e encerra, porque cena
## headless que nao encerra vira runaway.

const SAIDA := "user://capturas/andar"

## Uma cena por TIPO, que e o que o portao precisa separar. Nao sao todas as
## nove formas: a pergunta aqui e sobre COR, e duas salas do mesmo tipo com
## formas diferentes vestem exatamente as mesmas texturas.
const SALAS: Array[Dictionary] = [
	{&"nome": "combate", &"cena": "res://src/mapa/sala_1_retangular.tscn"},
	{&"nome": "inicial", &"cena": "res://src/mapa/sala_9_inicial.tscn"},
	{&"nome": "arma", &"cena": "res://src/mapa/sala_7_arma.tscn"},
	{&"nome": "item", &"cena": "res://src/mapa/sala_8_item.tscn"},
	{&"nome": "boss", &"cena": "res://src/mapa/sala_6_boss.tscn"},
	{&"nome": "loja", &"cena": "res://src/mapa/sala_10_loja.tscn"},
]

## Quantos quadros esperar antes de fotografar cada sala.
##
## A sala monta chao, fita de parede, props e luminarias no proprio `_ready`, e o
## `GradientTexture2D` das luzes so existe depois do primeiro desenho. Fotografar
## cedo demais pega a sala sem luz -- e o portao mediria um andar mais escuro do
## que o jogo entrega.
const QUADROS_DE_ESPERA := 6

var _ambiente: CanvasModulate = null


func _ready() -> void:
	# Um frame antes de tudo, pelo mesmo motivo do `runner.gd`: `quit()` chamado
	# de dentro do `_ready` nao encerra de forma confiavel.
	await get_tree().process_frame

	if DisplayServer.get_name() == "headless":
		print("\n=== olhar_andar ===")
		print("  sem janela nao ha o que fotografar.")
		print("  rode: godot --path . tools/fabrica/olhar_andar.tscn --resolution 960x544")
		get_tree().quit()
		return

	# O MESMO escurecimento do jogo. Sem ele a foto mediria um andar que nao
	# existe -- e a escuridao e metade da identidade que o portao confere.
	_ambiente = AmbienteDaFabrica.new()
	add_child(_ambiente)

	DirAccess.make_dir_recursive_absolute(SAIDA)
	print("\n=== olhar_andar ===")
	for caso in SALAS:
		await _fotografar(String(caso[&"nome"]), String(caso[&"cena"]))
	print("\n  %d sala(s) em %s" % [SALAS.size(), SAIDA])
	print("  agora meca: godot --headless --path . tools/texturas/medir_ambiente.tscn"
		+ " -- --pasta=%s" % SAIDA)
	get_tree().quit()


func _fotografar(nome: String, cena: String) -> void:
	var palco := Node2D.new()
	add_child(palco)

	var sala := EnquadramentoDeSala.montar(palco, cena)
	sala.ativar()
	var jogador := EnquadramentoDeSala.acompanhar(palco, sala)
	# O jogador entra so pela CAMERA: ela e quem aplica o clamp do jogo, e sem o
	# clamp a foto mostraria vazio em volta da sala que o jogador nunca ve.
	# O corpo dele sai de quadro -- ele e ATOR, e o portao mede AMBIENTE.
	jogador.global_position = sala.global_position + Vector2(0.0, 100000.0)

	for _i in QUADROS_DE_ESPERA:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var caminho := "%s/%s.png" % [SAIDA, nome]
	get_viewport().get_texture().get_image().save_png(caminho)
	print("  %s" % caminho)

	palco.queue_free()
	await get_tree().process_frame
