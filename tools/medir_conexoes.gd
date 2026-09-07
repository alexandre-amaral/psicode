extends Node2D
## Quanto de CONEXAO ha entre duas salas, e quanto disso e parede.
##
## Ela existe porque a pergunta "o corredor faz o andar parecer camaras ligadas
## por tuneis?" tem uma resposta numerica antes de ter uma artistica: quantos px
## o jogador anda entre o chao de uma sala e o chao da seguinte, e que fracao
## desses px ja e faixa de parede desenhada.
##
## **A distincao importa porque as duas coisas se parecem em captura e nao sao a
## mesma.** A faixa de parede pertence a sala; o piso de corredor e um lugar
## novo. Um andar em que quase tudo entre duas salas ja e parede esta a um ajuste
## de vao de virar parede compartilhada -- e um em que a maior parte e piso de
## corredor precisa de outra coisa.
##
## Ela roda HEADLESS: monta o andar, le a geometria e imprime. Nao fotografa
## nada, entao nao precisa de janela.

const ANDARES := 24


func _ready() -> void:
	var cena: PackedScene = load("res://src/main/main.tscn")
	print("\n=== CONEXOES ENTRE SALAS ===")
	print("vao declarado, faixa de parede de cada lado, e o que sobra de piso\n")

	var por_eixo := {"horizontal": [], "vertical": []}
	var por_tipo := {}
	var total_arestas := 0
	var comprimentos: Array[float] = []

	for i in ANDARES:
		seed(4000 + i * 97)
		var main := cena.instantiate()
		add_child(main)
		await get_tree().process_frame
		var mapa := main.find_child("GerenciadorMapa", true, false) as GerenciadorMapa
		if mapa == null:
			main.free()
			continue

		for ligacao in mapa.ligacoes():
			var a: Vector2i = ligacao["a"]
			var b: Vector2i = ligacao["b"]
			var ca := mapa.contorno_global_de(a)
			var cb := mapa.contorno_global_de(b)
			if ca.is_empty() or cb.is_empty():
				continue
			var caixa_a := _caixa(ca)
			var caixa_b := _caixa(cb)
			var eixo := "vertical" if (b - a).y != 0 else "horizontal"
			var vao := 0.0
			if eixo == "vertical":
				vao = absf(caixa_b.position.y - caixa_a.end.y) if b.y > a.y \
					else absf(caixa_a.position.y - caixa_b.end.y)
			else:
				vao = absf(caixa_b.position.x - caixa_a.end.x) if b.x > a.x \
					else absf(caixa_a.position.x - caixa_b.end.x)
			por_eixo[eixo].append(vao)
			var tipo_da: int = ligacao["tipo"]
			por_tipo[tipo_da] = int(por_tipo.get(tipo_da, 0)) + 1
			comprimentos.append(vao)
			total_arestas += 1

		main.free()
		await get_tree().process_frame

	# **O PAR E ASSIMETRICO, e somar o mesmo lado duas vezes esconde isso.**
	#
	# Numa aresta VERTICAL o que se encontra e o SUL da sala de cima com o NORTE
	# da de baixo -- 32 px contra 60. A primeira versao desta regua usava
	# `profundidade(SUL)` duas vezes e reportava 64 onde ha 92, e o erro apontava
	# para o lado errado: ela dizia que sobra mais piso de corredor do que sobra.
	var perfil := PerfilDeParede.new()
	var norte := perfil.profundidade(RenderizadorParedes.Lado.NORTE)
	var sul := perfil.profundidade(RenderizadorParedes.Lado.SUL)
	var lateral := perfil.profundidade(RenderizadorParedes.Lado.LESTE)
	var faixa_v := sul + norte
	var faixa_h := lateral * 2.0
	print("  parede entre duas salas: %.0f px no vertical (sul %.0f + norte %.0f)"
		% [faixa_v, sul, norte])
	print("                           %.0f px no horizontal (lateral %.0f x 2)"
		% [faixa_h, lateral])
	# O VAO EM QUE AS DUAS FAIXAS SE ENCONTRAM, arredondado para a grade de 16 --
	# `teste_grade.gd` cobra o vao entre bandas nela. E o numero central do epico
	# dos setores: com ele nao sobra piso de corredor nenhum.
	print("  vao em que elas se ENCONTRAM: %.0f vertical, %.0f horizontal" % [ceilf(faixa_v / 16.0) * 16.0, ceilf(faixa_h / 16.0) * 16.0])
	print("")

	for eixo: String in por_eixo:
		var lista: Array = por_eixo[eixo]
		if lista.is_empty():
			continue
		var faixa: float = faixa_v if eixo == "vertical" else faixa_h
		var soma := 0.0
		for v: float in lista:
			soma += v
		var media := soma / float(lista.size())
		var piso := media - faixa
		# A MEDIA sozinha esconde a forma da distribuicao, e aqui ela e o que
		# importa: "quase toda conexao e curta e algumas sao longas" e um andar
		# diferente de "todas sao medias". O minimo diz se o vao declarado chega a
		# acontecer alguma vez.
		lista.sort()
		var minimo: float = lista[0]
		var mediana: float = lista[lista.size() / 2]
		var maximo: float = lista[lista.size() - 1]
		print("  %-11s %3d arestas   vao min %.0f  mediana %.0f  medio %.0f  max %.0f"
			% [eixo, lista.size(), minimo, mediana, media, maximo])
		print("               parede %.0f (%.0f%% da mediana)   piso de corredor %.0f"
			% [faixa, faixa / maxf(mediana, 1.0) * 100.0, mediana - faixa])

	# A DISTRIBUICAO DOS TIPOS, medida em muitos andares e nao numa semente.
	#
	# A issue pede o corredor em 5 a 15% das arestas: e por ficar RARO que ele
	# passa a parecer um corredor de servico de verdade em vez do espaco
	# obrigatorio entre combates. Uma semente sozinha nao responde -- ela pode cair
	# com quatro fronteiras entre clusters e devolver 50%.
	print("")
	print("  --- distribuicao dos tipos ---")
	for tipo: int in por_tipo:
		var quantos: int = por_tipo[tipo]
		print("  %-22s %3d  (%.1f%%)" % [
			PlantaDoAndar.nome_de(tipo as PlantaDoAndar.Conexao), quantos,
			float(quantos) / float(maxi(total_arestas, 1)) * 100.0])
	# **"5 a 15% das arestas" e "uma, as vezes duas" NAO sao o mesmo criterio**, e
	# a issue pede os dois. Com 9 arestas por andar, uma conexao vale 11% e duas
	# valem 22% -- entao "uma, as vezes duas" e a faixa 11-22%, e nao 5-15%.
	#
	# Duas coisas empurram para cima e nenhuma delas e o sorteio: o corredor do
	# chefe e RESERVADO (um por andar garantido, ja 11%), e o tipo e sorteado por
	# FRONTEIRA -- uma fronteira que caia em corredor veste todas as arestas que a
	# cruzam, entao um sorteio pode render duas ou tres.
	#
	# O numero que descreve o desenho e o de CORREDORES POR ANDAR, e e nele que o
	# portao morde.
	var corredores: int = int(por_tipo.get(PlantaDoAndar.Conexao.CORREDOR_TECNICO, 0))
	print("  corredores por andar: %.2f  (a issue pede uma, as vezes duas)"
		% (float(corredores) / float(ANDARES)))
	print("\n  %d arestas em %d andares (%.1f por andar)"
		% [total_arestas, ANDARES, float(total_arestas) / float(ANDARES)])
	print("  a pe, o jogador atravessa %.0f px entre um chao e o proximo"
		% (comprimentos[0] if not comprimentos.is_empty() else 0.0))
	get_tree().quit()


func _caixa(pontos: PackedVector2Array) -> Rect2:
	var caixa := Rect2(pontos[0], Vector2.ZERO)
	for p in pontos:
		caixa = caixa.expand(p)
	return caixa
