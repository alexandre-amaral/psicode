extends TesteBase
## Verifica os comportamentos da Onda 3: teleguiado, corrente, nanite e feixe.
##
## As outras suites de arma checam CONTRATO -- que o .tres tem alcance, cor e
## descricao. Esta checa o que a arma FAZ, porque o contrato passaria inteiro
## com a mecanica desligada: um `comportamento = 5` que nunca curva tem os
## mesmos numeros de um que curva.
##
## Tudo roda longe da origem (`LONGE`) pelo mesmo motivo de teste_explosao e
## teste_hack: a busca de alvo e por GRUPO, e um inimigo esquecido por outra
## suite viraria o "vizinho mais proximo" desta.

const CENA_PROJETIL := preload("res://src/projectiles/projetil.tscn")
const CENA_ALVO := preload("res://src/enemies/rastejante.tscn")
const LONGE := Vector2(11000, 11000)
const VIDA_DE_TESTE := 999


func nome() -> String:
	return "ComportamentoArma"


func executar() -> void:
	await _a_corrente_decai_por_elo()
	await _o_nanite_empilha_e_estoura()
	await _o_teleguiado_curva()
	_o_feixe_declara_dano_por_segundo()


# ------------------------------------------------------------- apoio ---------

func _cenario() -> Dictionary:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)
	var cont := Node2D.new()
	# O projetil procura o container por grupo; sem ele a corrente nasceria na
	# cena atual e o arco ficaria orfao entre os casos.
	cont.add_to_group("container_projeteis")
	raiz.add_child(cont)
	return {"raiz": raiz, "cont": cont}


func _alvo(cont: Node2D, pos: Vector2) -> InimigoBase:
	var a := CENA_ALVO.instantiate() as InimigoBase
	cont.add_child(a)
	a.global_position = pos
	a.vida = VIDA_DE_TESTE
	# Parado: quero medir a ARMA. Com a IA ligada o alvo anda durante a medicao
	# e a distancia final passa a falar da perseguicao, nao da curva.
	a.set_physics_process(false)
	return a


func _atirar(cont: Node2D, dados: DadosArma, de: Vector2, dir: Vector2) -> Node2D:
	var p := CENA_PROJETIL.instantiate()
	cont.add_child(p)
	p.configurar(de, dir, dados, false)
	return p


## Deixa o MOTOR rodar a fisica ate o projetil sumir. Chamar `_physics_process`
## na mao parece equivalente e nao e: o motor tambem chama, e o projetil roda
## duas vezes por frame.
func _voar(p: Node2D, teto: int = 120) -> void:
	var frames := 0
	while is_instance_valid(p) and frames < teto:
		await Engine.get_main_loop().physics_frame
		frames += 1


func _dois_passos() -> void:
	# Corpo recem-adicionado so entra no espaco de fisica no passo seguinte.
	await Engine.get_main_loop().physics_frame
	await Engine.get_main_loop().physics_frame


# ------------------------------------------------------------- casos ---------

func _a_corrente_decai_por_elo() -> void:
	var c := _cenario()
	var cont: Node2D = c["cont"]
	var dados: DadosArma = load("res://src/weapons/volt_caster.tres")

	# Fila de quatro com 100px entre cada. `raio_corrente` e 130, entao cada
	# pulo alcanca so o vizinho seguinte -- e e isso que prova que a corrente
	# SERPENTEIA em vez de virar um circulo de dano no primeiro alvo.
	var fila: Array[InimigoBase] = []
	for i in 4:
		fila.append(_alvo(cont, LONGE + Vector2(300 + i * 100, 0)))
	await _dois_passos()

	await _voar(_atirar(cont, dados, LONGE, Vector2.RIGHT))

	var levaram: Array[int] = []
	for inimigo in fila:
		levaram.append(VIDA_DE_TESTE - inimigo.vida)

	ok(levaram[0] > 0, "o alvo atingido leva dano (%d)" % levaram[0])
	ok(levaram[1] > 0, "a corrente salta para o segundo (%d)" % levaram[1])
	ok(levaram[1] < levaram[0], "o segundo elo doi menos que o primeiro (%d < %d)" % [levaram[1], levaram[0]])
	# saltos_corrente = 3, entao ate quatro corpos ao todo. O quinto nao existe.
	igual(levaram.size(), 4, "a fila de teste tem quatro corpos")
	ok(levaram[3] >= 1, "o ultimo elo ainda sente (piso 1, e nao zero): %d" % levaram[3])

	(c["raiz"] as Node).free()


func _o_nanite_empilha_e_estoura() -> void:
	var c := _cenario()
	var cont: Node2D = c["cont"]
	var dados: DadosArma = load("res://src/weapons/nanite_rifle.tres")

	var alvo := _alvo(cont, LONGE + Vector2(200, 0))
	# Vizinho fora do caminho do tiro: so a EXPLOSAO alcanca ele, entao dano
	# nele prova que o estouro aconteceu de verdade.
	var vizinho := _alvo(cont, LONGE + Vector2(200, 40))
	await _dois_passos()

	var vistos: Array[int] = []
	for _tiro in dados.stacks_nanite:
		await _voar(_atirar(cont, dados, LONGE, Vector2.RIGHT), 60)
		vistos.append(alvo.stacks_de_nanite())

	ok(vistos[0] == 1, "o primeiro acerto deposita uma dose (%d)" % vistos[0])
	ok(vistos[1] > vistos[0], "a segunda dose EMPILHA, nao renova (%d > %d)" % [vistos[1], vistos[0]])
	igual(vistos[vistos.size() - 1], 0, "ao encher o teto o acumulo e consumido")
	ok(VIDA_DE_TESTE - vizinho.vida > 0,
		"o vizinho, que nunca foi atingido, sente a explosao (%d)" % (VIDA_DE_TESTE - vizinho.vida))

	(c["raiz"] as Node).free()


func _o_teleguiado_curva() -> void:
	var c := _cenario()
	var cont: Node2D = c["cont"]
	var dados: DadosArma = load("res://src/weapons/swarm.tres")

	# O alvo esta 150px FORA da linha de tiro. Um projetil reto passa a 150px
	# dele e some; e essa diferenca que a suite mede.
	var desvio := 150.0
	var alvo := _alvo(cont, LONGE + Vector2(200, desvio))
	await _dois_passos()

	var p := _atirar(cont, dados, LONGE, Vector2.RIGHT)
	var menor := INF
	var frames := 0
	while is_instance_valid(p) and frames < 120:
		await Engine.get_main_loop().physics_frame
		frames += 1
		if is_instance_valid(p):
			menor = minf(menor, p.global_position.distance_to(alvo.global_position))

	ok(menor < desvio, "o projetil chega mais perto do que chegaria reto (%.0f < %.0f)" % [menor, desvio])
	ok(VIDA_DE_TESTE - alvo.vida > 0, "e acerta o alvo que estava fora da linha")

	# O teto de curva e a arma inteira: sem ele o tiro nunca erra, e o GDD e
	# explicito em que dificuldade se le antes de doer.
	ok(dados.curva_graus > 0.0 and dados.curva_graus < 720.0,
		"a curva tem teto declarado (%.0f graus/s)" % dados.curva_graus)

	(c["raiz"] as Node).free()


func _o_feixe_declara_dano_por_segundo() -> void:
	var dados: DadosArma = load("res://src/weapons/laser_cutter.tres")
	ok(dados.e_feixe(), "o Cortador Laser se declara feixe")
	ok(dados.dano_por_segundo > 0.0, "feixe sem dano por segundo nao machucaria ninguem")
	ok(dados.largura_feixe > 0.0, "feixe sem largura seria invisivel")
	# O feixe passa longe do caminho normal de `atirar()`, entao ele NAO pode
	# depender de projeteis_por_tiro nem de abertura: se alguem ligar um leque
	# num feixe, o numero fica escrito no .tres sem efeito nenhum e engana quem
	# for balancear.
	igual(dados.abertura_graus, 0.0, "feixe nao usa leque, e o .tres nao finge que usa")
