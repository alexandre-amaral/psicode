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

const ANDARES := 12


func _ready() -> void:
	var cena: PackedScene = load("res://src/main/main.tscn")
	print("\n=== CONEXOES ENTRE SALAS ===")
	print("vao declarado, faixa de parede de cada lado, e o que sobra de piso\n")

	var por_eixo := {"horizontal": [], "vertical": []}
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
			comprimentos.append(vao)
			total_arestas += 1

		main.free()
		await get_tree().process_frame

	var perfil := PerfilDeParede.new()
	var faixa_v := perfil.profundidade(RenderizadorParedes.Lado.SUL)
	var faixa_h := perfil.profundidade(RenderizadorParedes.Lado.LESTE)
	print("  faixa de parede desenhada: %.0f px no eixo vertical, %.0f no horizontal"
		% [faixa_v, faixa_h])
	print("  (cada lado desenha isso, entao entre duas salas ha o DOBRO)\n")

	for eixo: String in por_eixo:
		var lista: Array = por_eixo[eixo]
		if lista.is_empty():
			continue
		var faixa: float = faixa_v if eixo == "vertical" else faixa_h
		var soma := 0.0
		for v: float in lista:
			soma += v
		var media := soma / float(lista.size())
		var piso := media - faixa * 2.0
		print("  %-11s %3d arestas   vao medio %.0f px   parede %.0f (%.0f%%)   piso de corredor %.0f (%.0f%%)"
			% [eixo, lista.size(), media, faixa * 2.0, faixa * 2.0 / media * 100.0,
				piso, piso / media * 100.0])

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
