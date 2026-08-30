extends TesteBase
## O Drone Aranha (INIM 01): o anel alterna, e ele nao se empilha.
##
## Por que isto e teste e nao revisao de olho: as duas propriedades so aparecem
## COMPARANDO dois momentos. Um anel sozinho parece igual seja a rotacao
## aleatoria ou alternada; dois drones parados parecem iguais seja o
## posicionamento lateral ou nao. O defeito mora na relacao entre eventos, que e
## exatamente o que um olho nao guarda entre um frame e outro.

const CENA := preload("res://src/enemies/drone_aranha.tscn")
## Longe da origem: outras suites deixam no ao redor de (0,0) enquanto o coletor
## nao passa, e isso ja custou um dia de teste vermelho com o codigo certo.
const LONGE := Vector2(15000.0, 15000.0)


func nome() -> String:
	return "DroneAranha"


func executar() -> void:
	_o_anel_alterna_meio_vao()
	_a_alternancia_acompanha_a_contagem()
	_ele_tem_o_estado_que_impede_o_empilhamento()


## Dois aneis seguidos caem INTERCALADOS, e nao um sobre o outro.
##
## E a diferenca entre imprevisivel e dificil. Com a rotacao aleatoria que havia
## antes, o segundo anel as vezes cobria os vaos do primeiro e as vezes nao --
## o jogador nao tinha o que deduzir, so o que reagir. Alternando meio setor, o
## vao de agora e SEMPRE a parede do proximo, e isso da para dominar.
func _o_anel_alterna_meio_vao() -> void:
	var drone := _nascer()
	var setor: float = 360.0 / float(drone.projeteis)

	var primeiro: float = drone._proximo_offset()
	var segundo: float = drone._proximo_offset()
	var terceiro: float = drone._proximo_offset()

	var passo := absf(segundo - primeiro)
	perto(
		passo, setor * 0.5,
		"o anel gira MEIO setor entre disparos (setor %.1f)" % setor
	)
	# E o par alterna para sempre: o terceiro volta ao primeiro. Sem isso o
	# offset cresceria sem limite e a alternancia viraria deriva.
	perto(terceiro, primeiro, "o terceiro anel volta a fase do primeiro")

	# A prova de que os vaos se intercalam: deslocar meio setor poe cada braco
	# do segundo anel no MEIO do vao do primeiro.
	var bracos_a := Balistica.anel(drone.projeteis, deg_to_rad(primeiro))
	var bracos_b := Balistica.anel(drone.projeteis, deg_to_rad(segundo))
	igual(bracos_a.size(), drone.projeteis, "o anel sai com a contagem pedida")
	var menor_diferenca := 999.0
	for a: Vector2 in bracos_a:
		for b: Vector2 in bracos_b:
			menor_diferenca = minf(menor_diferenca, absf(rad_to_deg(a.angle_to(b))))
	perto(
		menor_diferenca, setor * 0.5,
		"nenhum braco do segundo anel cai sobre um do primeiro (menor gap %.1f graus)"
			% menor_diferenca, 0.5
	)
	drone.free()


## O passo acompanha a CONTAGEM, e nao um 22,5 cravado.
##
## `projeteis` e ajustavel e a INIM 09 preve a Deterioracao subi-lo para 10 ou
## 12. Com um passo fixo, o offset deixaria de cair no meio do vao assim que a
## contagem mudasse -- e o defeito seria invisivel: o anel continuaria saindo,
## so pararia de intercalar.
func _a_alternancia_acompanha_a_contagem() -> void:
	for quantidade: int in [6, 8, 12]:
		var drone := _nascer()
		drone.projeteis = quantidade
		var a: float = drone._proximo_offset()
		var b: float = drone._proximo_offset()
		perto(
			absf(b - a), (360.0 / float(quantidade)) * 0.5,
			"com %d projeteis o passo continua meio vao" % quantidade
		)
		drone.free()


## O estado que impede quatro drones de virarem uma parede.
##
## Sem ele todos convergem para cima do jogador e os quatro aneis se somam num
## muro solido -- o oposto do padrao legivel que este inimigo existe para criar.
## A faixa tem de ser uma FAIXA: mirar um raio unico faria todos convergirem
## para a mesma circunferencia, que e o empilhamento de novo, so que em anel.
func _ele_tem_o_estado_que_impede_o_empilhamento() -> void:
	var drone := _nascer()
	ok(
		drone.distancia_de_recuo < drone.distancia_de_posicionamento,
		"a faixa de posicionamento e uma faixa (%.0f a %.0f)"
			% [drone.distancia_de_recuo, drone.distancia_de_posicionamento]
	)
	ok(
		drone.distancia_de_posicionamento > drone.alcance_anel,
		"ele comeca a posicionar ANTES de entrar no alcance do anel (%.0f > %.0f)"
			% [drone.distancia_de_posicionamento, drone.alcance_anel]
	)
	ok(
		drone.peso_lateral > 0.5,
		"o movimento e majoritariamente lateral (%.2f) -- e o que separa os drones"
			% drone.peso_lateral
	)
	drone.free()

	# Dois drones sorteiam lados independentes. A garantia e estatistica, entao
	# o teste pergunta se AMBOS os sentidos acontecem numa amostra, e nao se
	# dois vizinhos especificos sairam opostos.
	var vistos := {}
	for i in 24:
		var d := _nascer()
		vistos[d._sentido_lateral] = true
		d.free()
	igual(
		vistos.size(), 2,
		"os drones sorteiam os dois sentidos de contorno -- todos para o mesmo lado voltaria a empilhar"
	)


func _nascer() -> Node:
	var drone := CENA.instantiate()
	drone.position = LONGE
	Engine.get_main_loop().root.add_child(drone)
	return drone
