extends Node2D
## As variantes de TOPO no enquadramento real do jogo -- e, sem janela, a
## medicao delas.
##
## **Nao se aprova topo olhando PNG de 64x64 ampliado.** A pergunta e "durante o
## gameplay, essa faixa parece uma chapa superior ou um bloco?", e ela so tem
## resposta em 960x544, zoom 1.0, com o personagem encostado -- que e o unico
## lugar onde a massa do topo pode ser comparada com a massa de quem joga.
##
## Ele responde tres coisas, e as tres precisam da mesma foto:
##
##   - **continuidade.** O topo e sorteado uma vez por SALA e atravessa as
##     quinas. A volta norte -> leste -> sul -> oeste nao pode parecer que quatro
##     pisos diferentes foram postos em volta da sala.
##   - **escala.** Com a personagem encostada, o topo nao pode ter a mesma massa
##     que ela.
##   - **ordem de atencao.** O desejado e ator -> interior -> face -> props ->
##     topo -> exterior. Se o olho for primeiro para a moldura, reprova.
##
## **UMA FOTO SO NAO MOSTRA OS QUATRO LADOS, e isso e aritmetica e nao preguica.**
## A issue pedia norte, sul, as duas laterais, uma quina, uma porta e o
## personagem no mesmo quadro. Com contorno de 768x640 e margens de 96, o clamp
## fecha 960 no eixo X -- as duas laterais cabem -- e 832 no Y, contra 544 de
## tela. Norte e sul no mesmo quadro exigiria zoom fracionario, que borra pixel
## art e e proibido no projeto desde a Fase 1 do plano de enquadramento. Por isso
## sao as TRES posicoes de `EnquadramentoDeSala`, compartilhadas com
## `comparar_norte` para as duas ferramentas nao divergirem.
##
## ## O MODO SILHUETA
##
## Ele desliga a textura e pinta cada banda com cor chapada. E o teste que separa
## duas hipoteses que custam muito diferente:
##
##   - se em silhueta a faixa AINDA parecer um bloco, o problema e GEOMETRICO, e
##     a resposta e reduzir o topo (#245);
##   - se em silhueta ficar bom, o problema e de MATERIAL, e as issues #241 a
##     #244 resolvem sem tocar em geometria.
##
## Ele vem antes de qualquer arte nova, de proposito.

const SALA := "res://src/mapa/sala_1_retangular.tscn"

## As composicoes comparadas, na ordem em que aparecem na pasta de capturas.
##
## Nome vazio de perfil = o perfil que o ESTILO daquela sala carrega, ou seja o
## jogo como ele esta hoje. Os prototipos entram aqui conforme forem existindo,
## e cada um e so um `PerfilDeParede` com a subdivisao do topo diferente.
const COMPOSICOES: Array[String] = ["atual", "A", "B", "C"]


func _ready() -> void:
	var com_janela := DisplayServer.get_name() != "headless"
	if com_janela:
		DirAccess.make_dir_recursive_absolute("user://capturas")
	print("COMPARAR_TOPOS  (%s)" % ("fotos" if com_janela else "medicao"))
	for composicao in COMPOSICOES:
		Sala.perfil_de_teste = PerfilDeParede.de_topo(composicao)
		await _medir(composicao)
		if com_janela:
			for silhueta in [false, true]:
				Sala.silhueta_de_teste = silhueta
				await _fotografar(composicao, silhueta)
			Sala.silhueta_de_teste = false
	Sala.perfil_de_teste = null
	get_tree().quit()


## Sem janela: a energia de cada faixa, como o resto das reguas do projeto.
##
## E a mesma conta que `teste_camada_visual._o_topo_e_subordinado_a_face` cobra,
## impressa em vez de assertada -- o portao diz passou/reprovou, a regua diz
## quanto. As duas leem a fita MONTADA pelo `RasterizadorDeFita`, e nao os PNGs:
## o que o jogador ve no topo e a textura mais as bandas desenhadas em codigo.
func _medir(composicao: String) -> void:
	var sala := EnquadramentoDeSala.montar(self, SALA)
	await get_tree().process_frame
	var fita := sala.get_node_or_null("ParedeModulos") as Node2D
	var perfil := sala.perfil_de_parede()
	if fita == null or perfil == null:
		print("  %-10s SEM FITA" % composicao)
		sala.queue_free()
		return
	var contorno := sala.contorno_local()
	var portas: Array[Porta] = []
	var raiz := sala.get_node_or_null("Portas")
	if raiz != null:
		for filho in raiz.get_children():
			var porta := filho as Porta
			if porta != null:
				portas.append(porta)

	var melhor := PackedVector2Array()
	var normal := Vector2.ZERO
	var maior := 0.0
	for i in contorno.size():
		var a := contorno[i]
		var b := contorno[(i + 1) % contorno.size()]
		var n := RenderizadorParedes.normal_externa(contorno, a, b)
		if RenderizadorParedes.classificar(n) != RenderizadorParedes.Lado.NORTE:
			continue
		for trecho in RenderizadorParedes.trechos_livres(contorno, a, b, portas):
			var comprimento: float = trecho[0].distance_to(trecho[1])
			if comprimento > maior:
				maior = comprimento
				melhor = trecho
				normal = n
	if maior < 64.0:
		print("  %-10s SEM TRECHO LIVRE" % composicao)
		sala.queue_free()
		return

	var fundo := int(perfil.profundidade(RenderizadorParedes.Lado.NORTE))
	var fim_face := int(perfil.fim_da_face(RenderizadorParedes.Lado.NORTE))
	var largura := int(minf(maior, 192.0))
	var meio := (melhor[0] + melhor[1]) * 0.5
	var eixo := (melhor[1] - melhor[0]).normalized()
	var imagem := RasterizadorDeFita.faixa(fita,
		meio - eixo * (largura * 0.5), meio + eixo * (largura * 0.5),
		normal, fundo, largura)
	var margem := 4
	var face := RasterizadorDeFita.energia(imagem, margem, fim_face - margem)
	var topo := RasterizadorDeFita.energia(imagem, fim_face + margem, fundo - margem)
	print("  %-10s face %6.2f   topo %6.2f   topo/face %.3f   (face %d px, topo %d px)"
		% [composicao, face, topo, topo / maxf(face, 0.001), fim_face, fundo - fim_face])

	# A FATIA em disco, ampliada. Ela e a evidencia da medicao: sem ela, um
	# numero errado por amostrar o lado errado da parede continua sendo um
	# numero, e o unico jeito de descobrir e reler o codigo. A fatia mostra na
	# hora se o que foi medido e mesmo face embaixo e topo em cima.
	DirAccess.make_dir_recursive_absolute("user://capturas")
	var ampliada := Image.create(imagem.get_width() * 2, imagem.get_height() * 4,
		false, Image.FORMAT_RGBA8)
	for y in ampliada.get_height():
		for x in ampliada.get_width():
			ampliada.set_pixel(x, y, imagem.get_pixel(x / 2, y / 4))
	ampliada.save_png("user://capturas/fatia_%s.png" % composicao)
	sala.queue_free()


func _fotografar(composicao: String, silhueta: bool) -> void:
	var sala := EnquadramentoDeSala.montar(self, SALA)
	await get_tree().process_frame
	sala.ativar()
	var jogador := EnquadramentoDeSala.acompanhar(self, sala)
	var sufixo := "_silhueta" if silhueta else ""
	for onde in EnquadramentoDeSala.POSICOES:
		EnquadramentoDeSala.posicionar(jogador, sala, onde)
		for i in 5:
			await get_tree().process_frame
		await get_tree().create_timer(0.25).timeout
		var nome := "topos_%s%s_%s.png" % [composicao, sufixo, onde]
		get_viewport().get_texture().get_image().save_png("user://capturas/" + nome)
		print("  %s" % nome)
	jogador.queue_free()
	sala.queue_free()
	await get_tree().process_frame
