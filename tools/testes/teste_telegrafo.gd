extends TesteBase
## O TELEGRAFO (INIM 06): o vocabulario unico de aviso e as invariantes dele.
##
## Por que isto e teste e nao confianca: telegrafo quebra em SILENCIO, nas duas
## direcoes. Aviso que desenha na faixa errada existe no codigo e nao existe na
## tela -- foi o que aconteceu com a `AreaDePerigo` em `z = -4`, com o chao
## desenhando por cima. E aviso que nao apaga fica na tela depois do tiro, ou
## sobrevive a morte de quem avisava. Nenhum dos dois da uma linha no console, e
## o teste de fumaca nao olha um pixel.
##
## As quatro invariantes do cabecalho de `telegrafo.gd` viram caso aqui, e o
## caso mais caro e o ultimo: o inimigo morrendo NO MEIO da preparacao.
## `queue_free()` e diferido, entao sem `_apagar_telegrafos()` na base o laser
## ainda desenha no frame em que o Vigia explodiu.

const CENA_VIGIA := preload("res://src/enemies/vigia.tscn")
const CENA_NEON := preload("res://src/enemies/atirador_neon.tscn")
const CENA_SENTINELA := preload("res://src/enemies/sentinela_orbital.tscn")

## Longe da origem, como as outras suites que instanciam inimigo: outras deixam
## no ao redor de (0,0) enquanto o coletor nao passa.
const LONGE := Vector2(31000.0, 31000.0)


func nome() -> String:
	return "Telegrafo"


func executar() -> void:
	_as_invariantes_de_no()
	_o_piso_de_duracao_vale_sempre()
	_as_quatro_fases_estao_em_ordem()
	_a_intensidade_cresce_e_pisca()
	_apagar_devolve_o_pulsante()
	_os_tres_inimigos_migrados_avisam()
	_o_aviso_apaga_quando_o_inimigo_morre_mirando()


## Invariantes 1 e 2: faixa `Z` absoluta e transformada propria.
##
## As duas tem de valer sem ninguem configurar nada, porque quem esquece nao
## recebe erro nenhum. `z_as_relative` e o detalhe silencioso: sem ele o aviso
## herda a faixa de quem o pendurou, e um telegrafo pendurado num no de cenario
## desapareceria atras do chao.
func _as_invariantes_de_no() -> void:
	var dono := Node2D.new()
	dono.position = LONGE
	dono.rotation = 1.2
	dono.scale = Vector2(2.0, 0.5)
	dono.z_index = -14
	Engine.get_main_loop().root.add_child(dono)

	var t := Telegrafo.anexar(dono)
	igual(t.z_index, Telegrafo.Z, "o aviso desenha na faixa do mundo (z = 0)")
	igual(t.z_index, 0, "e essa faixa e a mesma de Sala.Z_MUNDO")
	ok(not t.z_as_relative,
		"a faixa e ABSOLUTA -- relativa, o aviso herdaria a camada de quem o pendurou")
	ok(t.top_level,
		"o aviso nao herda a transformada de quem avisa -- aviso que se mexe e aviso que mente")
	igual(t.global_position, Vector2.ZERO, "e desenha em coordenadas globais, sem offset do dono")
	ok(not t.visible, "nasce APAGADO: telegrafo aceso sem ataque e ruido")

	dono.free()


## Invariante 4: o aviso encurta com a fase, mas nunca some.
##
## O piso e aplicado dentro de `acender()` e nao no chamador, porque um piso que
## depende de alguem lembrar de chamar nao e piso. E `duracao_segura()` e
## publica justamente para quem ESPERA o aviso terminar poder esperar o mesmo
## numero -- e o caso da Sentinela, cujo `tempo_clarao` de 0,28 s esta abaixo
## do piso.
func _o_piso_de_duracao_vale_sempre() -> void:
	perto(Telegrafo.DURACAO_MINIMA, 0.35,
		"o piso e o mesmo 0,35 s que a Diretora crava em TELEGRAFO_MINIMO")
	perto(Telegrafo.duracao_segura(0.05), 0.35, "duracao abaixo do piso sobe para o piso")
	perto(Telegrafo.duracao_segura(1.2), 1.2, "duracao acima do piso passa intacta")

	var t := _solto()
	t.acender(0.01)
	perto(t.duracao, Telegrafo.DURACAO_MINIMA,
		"`acender()` aplica o piso sozinho -- nao da para esquecer")
	t.free()


## As quatro fases que a INIM 05 pede, na ordem, com a ativacao so no fim.
func _as_quatro_fases_estao_em_ordem() -> void:
	var t := _solto()
	t.acender(1.0)
	igual(t.fase(), Telegrafo.Fase.FRACO, "acende na fase 1 (circulo fraco)")

	t.avancar(0.2)
	igual(t.fase(), Telegrafo.Fase.FRACO, "com 20% do tempo ainda e fase 1")
	t.avancar(0.3)
	igual(t.fase(), Telegrafo.Fase.CRESCENDO, "com 50% e fase 2 (aumentando intensidade)")
	t.avancar(0.3)
	igual(t.fase(), Telegrafo.Fase.PISCANDO, "com 80% e fase 3 (piscando)")
	ok(t.aceso(), "e na fase 3 ele ainda esta aceso -- a fase 3 nao e o fim")
	t.avancar(0.3)
	igual(t.fase(), Telegrafo.Fase.ATIVACAO, "passado o tempo e fase 4 (ativacao)")
	ok(t.progresso() >= 1.0, "e o progresso passa de 1 -- e por ele que quem avisa dispara")
	t.free()


## A leitura tem de MUDAR entre as fases, senao as quatro fases sao so um enum.
##
## Fase 1 fraca, fase 2 subindo, fase 3 alternando entre aceso e apagado. E o
## vale da piscada nao pode ser zero: um aviso que some metade do tempo e pior
## que um aviso fraco -- na metade apagada o jogador nao tem o que ler.
func _a_intensidade_cresce_e_pisca() -> void:
	var t := _solto()
	t.alfa_min = 0.1
	t.alfa_max = 0.8
	t.acender(1.0)

	var i_fraco := t.intensidade()
	perto(i_fraco, t.alfa_min, "na fase 1 o brilho e o minimo declarado")

	t.avancar(0.5)
	var i_meio := t.intensidade()
	ok(i_meio > i_fraco, "na fase 2 o brilho subiu (%.2f contra %.2f)" % [i_meio, i_fraco])
	ok(i_meio < t.alfa_max, "e ainda nao chegou no maximo -- senao nao ha o que crescer")

	# Varre a fase 3 inteira procurando os dois lados da piscada.
	t.acender(1.0)
	t.avancar(0.75)
	var teto := 0.0
	var piso := 1.0
	for i in 40:
		t.avancar(0.005)
		if t.fase() != Telegrafo.Fase.PISCANDO:
			break
		teto = maxf(teto, t.intensidade())
		piso = minf(piso, t.intensidade())
	ok(teto > piso, "na fase 3 o brilho ALTERNA (%.2f no pico, %.2f no vale)" % [teto, piso])
	ok(piso > 0.0, "e o vale nunca apaga: aviso que some e pior que aviso fraco")

	# O crescimento e monotono: e ele, e nao a cor, que conta o tempo que falta.
	t.acender(1.0)
	var antes := t.crescimento()
	var encolheu := false
	for i in 10:
		t.avancar(0.1)
		var agora := t.crescimento()
		encolheu = encolheu or agora < antes
		antes = agora
	ok(not encolheu, "o desenho nunca encolhe no meio do aviso")
	perto(antes, 1.0, "e chega em tamanho cheio no fim do aviso", 0.001)
	t.free()


## Invariante 3, no caso menos obvio: o telegrafo que dirige um no de FORA.
##
## O `pulsar` mexe em `visible`, `scale` e `modulate` de um no que ja existia na
## cena -- o clarao da Sentinela. Apagar sem devolver os tres deixaria o cano
## dela permanentemente inchado e translucido depois do primeiro tiro.
func _apagar_devolve_o_pulsante() -> void:
	var alvo := Polygon2D.new()
	alvo.polygon = PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4)])
	alvo.scale = Vector2(1.5, 1.5)
	alvo.visible = false
	var t := _solto()
	t.add_child(alvo)

	t.pulsar(alvo, 2.0)
	t.acender(0.5)
	t.avancar(0.25)
	ok(alvo.visible, "enquanto avisa, o no pulsante aparece")
	ok(alvo.scale.x > 1.5 * 0.4, "e cresceu a partir da escala original dele")

	t.apagar()
	ok(not alvo.visible, "ao apagar, o no pulsante some")
	perto(alvo.scale.x, 1.5, "e a escala ORIGINAL volta -- nao a escala 1")
	perto(alvo.modulate.a, 1.0, "e o alfa original volta junto")

	# Idempotente: `sair` do estado e `morrer()` chamam os dois, e insistir e o
	# certo nas duas pontas.
	t.apagar()
	ok(not t.aceso(), "apagar duas vezes continua apagado")
	t.free()


## O criterio de aceite da issue: ao menos tres inimigos migrados.
##
## O caso do Vigia cobra a ponta que nao pode mudar: a linha sai da BOCA da
## arma. Ela e a aula que ensina a mira preditiva sem tutorial, e boca no lugar
## errado faz a mecanica central do jogo mentir.
func _os_tres_inimigos_migrados_avisam() -> void:
	var vigia := _nascer(CENA_VIGIA)
	var t_vigia: Telegrafo = vigia._telegrafo
	ok(t_vigia != null, "o Vigia usa o Telegrafo")
	vigia._fase = vigia.Fase.MIRANDO
	t_vigia.acender(vigia.tempo_mira)
	vigia._desenhar_laser()
	igual(t_vigia._a, (vigia.get_node("Torre/Arma") as Node2D).global_position,
		"e a linha dele sai da BOCA da arma, nao do centro do corpo")
	ok(t_vigia.aceso(), "mirando, o laser do Vigia acende")
	vigia.free()

	var neon := _nascer(CENA_NEON)
	ok(neon._telegrafo != null, "o Atirador Neon usa o Telegrafo")
	ok(neon._telegrafo.cor != Color(1.0, 0.22, 0.35),
		"e com cor propria: a cor e como o jogador escolhe a regra de esquiva")
	neon.free()

	var sentinela := _nascer(CENA_SENTINELA)
	ok(sentinela._telegrafo != null, "a Sentinela Orbital usa o Telegrafo")
	ok(
		sentinela._duracao_do_aviso() >= Telegrafo.DURACAO_MINIMA,
		"e o aviso dela respeita o piso (%.2f s, com tempo_clarao de %.2f)"
			% [sentinela._duracao_do_aviso(), sentinela.tempo_clarao]
	)
	# A regra da INIM 04 continua valendo por cima do piso.
	sentinela._ate_rajada = 5
	var unico: float = sentinela._duracao_do_aviso()
	sentinela._ate_rajada = 0
	ok(sentinela._duracao_do_aviso() > unico,
		"e o aviso da rajada continua mais longo que o do tiro unico, mesmo com o piso")
	sentinela.free()


## O caso caro: o inimigo morre NO MEIO da preparacao.
##
## `queue_free()` e diferido -- o no ainda desenha no frame em que morreu. Sem
## `InimigoBase._apagar_telegrafos()`, o laser fica na tela por um frame apos a
## explosao, e pior: qualquer inimigo futuro que esqueca de sobrescrever
## `morrer()` volta a ter o defeito. Por isso a garantia mora na BASE.
func _o_aviso_apaga_quando_o_inimigo_morre_mirando() -> void:
	var vigia := _nascer(CENA_VIGIA)
	var t: Telegrafo = vigia._telegrafo
	vigia._fase = vigia.Fase.MIRANDO
	t.acender(vigia.tempo_mira)
	ok(t.aceso(), "o Vigia esta no meio da mira, com o laser aceso")

	vigia.morrer()
	ok(not t.aceso(), "morrer no meio da mira APAGA o laser -- no mesmo frame")
	ok(not t.visible, "e o no fica invisivel, sem esperar o queue_free diferido")

	var sentinela := _nascer(CENA_SENTINELA)
	var clarao: Polygon2D = sentinela._clarao
	sentinela._telegrafo.pulsar(clarao, 2.0)
	sentinela._telegrafo.acender(0.5)
	sentinela._telegrafo.avancar(0.2)
	ok(clarao.visible, "a Sentinela esta carregando o clarao")
	sentinela.morrer()
	ok(not clarao.visible, "e morrer carregando apaga o clarao tambem")
	# Nao ha `free()` aqui: `morrer()` ja chamou `queue_free()` nos dois.


func _solto() -> Telegrafo:
	var t := Telegrafo.new()
	t.name = "TelegrafoSolto"
	Engine.get_main_loop().root.add_child(t)
	return t


func _nascer(cena: PackedScene) -> Node:
	var no := cena.instantiate()
	no.position = LONGE
	Engine.get_main_loop().root.add_child(no)
	return no
