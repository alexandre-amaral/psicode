extends TesteBase
## O gesto do chefe termina no GOLPE, nas duas pontas da luta.
##
## Esta suite existe por uma medicao. O `PREPARAR` do Automato vale **1,0667 s**
## na fase 1 com a barra zerada e **0,3620 s** na fase 3 com ela cheia -- uma
## faixa de **2,95x**. A duracao de um clipe tocado por fps e CONSTANTE, e
## nenhuma constante cabe numa faixa dessas: ela erra numa ponta ou nas duas.
##
## E a ponta que quebra nao e a rapida, que era a suspeita obvia. Com 4 quadros
## a 9 fps (0,4444 s) contra 0,3620 s de estado, `int(0.362/0.444 * 4) = 3` -- o
## ultimo quadro ainda aparece, por 29 ms. **Quem quebra e a ponta LENTA:** na
## fase 1 o clipe acaba em 42% do estado e congela pelo resto; em laco, ele
## RE-ARMA o punho 2,4 vezes antes de socar, e ai a animacao mente sobre a
## CONTAGEM e nao so sobre o tempo.
##
## Por isso o preparo e dirigido pelo PROGRESSO do estado. E por isso esta suite
## mede a fase 1 com a barra em zero E a fase 3 com ela cheia: uma ponta so nao
## enxerga o problema.
##
## O piso de 0,35 s NAO morde no preparo -- sobram 12 ms. Quem ele corta e a
## execucao. Isso e medido aqui de proposito, porque e uma margem e nao uma
## garantia: `tempo_telegrafo` vale 0,80 e o regime vira em 0,7735.

const CENA := preload("res://src/enemies/boss_guardiao_01.tscn")

## Longe da origem: o grupo "player" e global e outras suites deixam bonecos
## nele. Mesma razao de `teste_hack` e `teste_boss_ataques`.
const LONGE := Vector2(9000, 9000)

## O passo de fisica do projeto. E tambem a TOLERANCIA das medicoes de tempo:
## um estado so pode ser medido com a resolucao com que ele e processado.
const PASSO := 1.0 / 60.0

## Quantos quadros um gesto de preparo tem, para efeito de medicao.
##
## Nao ha arte ainda. Quatro e o que a ANIM 04 vai entregar, e o numero esta aqui
## para o teto de permanencia ser cobrado ANTES de a arte existir -- e nao depois
## de ela estar em disco.
const QUADROS_DE_PREPARO := 4

## Teto de quanto tempo UM quadro pode ficar parado na tela.
##
## Nao e um numero escolhido: e `Telegrafo.DURACAO_MINIMA`. O projeto ja declara
## que 0,35 s e o intervalo mais curto em que um aviso de QUATRO fases inteiro
## tem de ser legivel. Um unico quadro parado mais tempo que um telegrafo minimo
## completo e, na regua do proprio projeto, imagem estatica -- e nao animacao.
const TETO_POR_QUADRO := Telegrafo.DURACAO_MINIMA

var _barra_original: float = 0.0


func nome() -> String:
	return "Animacao do chefe"


func executar() -> void:
	_barra_original = Deterioracao.valor
	_o_preparo_termina_no_golpe()
	_o_gesto_de_beat_recomeca_a_cada_beat()
	_nenhum_quadro_fica_parado_alem_do_teto()
	_o_reator_nao_e_dirigido_por_progresso()
	Deterioracao.valor = _barra_original


## O progresso do preparo chega a 1,0 no instante em que o golpe sai.
##
## Duas afirmacoes por ataque, e elas pegam defeitos diferentes:
##
## 1. **O estado dura o que `duracao_do_estado()` diz.** E o portao
##    anti-divergencia: se a funcao deixar de concordar com aquilo que
##    `_preparar` compara, o gesto passa a terminar antes ou depois do golpe, e
##    nada mais no projeto acusaria.
## 2. **O ultimo progresso visto ainda em PREPARAR mostra o ULTIMO quadro.** E o
##    que separa "o gesto acompanha o estado" de "o gesto acaba quando quer".
func _o_preparo_termina_no_golpe() -> void:
	for canto in [{"fase": 1, "barra": 0.0}, {"fase": 3, "barra": 100.0}]:
		var chefe := _nascer()
		Deterioracao.valor = canto["barra"]
		for ataque in chefe.repertorio_da_fase(canto["fase"]):
			_forcar_fase(chefe, canto["fase"])
			_entrar_em_preparar(chefe, ataque)

			var esperado: float = chefe.duracao_do_estado()
			var passos := 0
			var ultimo := 0.0
			while chefe._maquina.estado == chefe.PREPARAR and passos < 600:
				ultimo = chefe.progresso_do_gesto()
				chefe._physics_process(PASSO)
				passos += 1

			var medido := float(passos) * PASSO
			perto(
				medido, esperado, "f%d/b%.0f %s: o estado dura o que duracao_do_estado() diz"
					% [canto["fase"], canto["barra"], ataque], PASSO
			)
			var quadro := int(ultimo * float(QUADROS_DE_PREPARO))
			igual(
				mini(quadro, QUADROS_DE_PREPARO - 1), QUADROS_DE_PREPARO - 1,
				"f%d/b%.0f %s: o ultimo quadro do preparo esta em cena quando o golpe sai (progresso %.3f em %.3fs)"
					% [canto["fase"], canto["barra"], ataque, ultimo, esperado]
			)
		chefe.free()


## Num ataque de BEAT o gesto recomeca a cada beat, e nao uma vez por estado.
##
## O pisao da fase 3 sao DOIS pisoes dentro de um `EXECUTAR` so. Dirigido pelo
## progresso do ESTADO, um clipe mostraria meio pisao por pisao -- a perna
## subindo no primeiro e descendo no segundo, com o impacto de nenhum dos dois
## caindo no lugar.
func _o_gesto_de_beat_recomeca_a_cada_beat() -> void:
	var chefe := _nascer()
	Deterioracao.valor = 0.0
	_forcar_fase(chefe, 3)
	_entrar_em_preparar(chefe, chefe.PISAO)
	chefe._maquina.trocar(chefe.EXECUTAR)

	igual(chefe._beats_do_ataque(), 2, "o pisao da fase 3 tem dois beats (pre-condicao)")

	var subiu_e_voltou := 0
	var anterior: float = chefe.progresso_do_gesto()
	var passos := 0
	while passos < 600:
		chefe._physics_process(PASSO)
		passos += 1
		# Sair do estado ANTES de amostrar. `progresso_do_gesto()` responde pelo
		# estado ATUAL: lido ja em RECUPERAR ele devolve quase zero, e essa queda
		# contaria como um reinicio de beat que nao aconteceu.
		if chefe._maquina.estado != chefe.EXECUTAR:
			break
		var agora: float = chefe.progresso_do_gesto()
		# O progresso CAIR quer dizer que um gesto acabou e outro comecou.
		if agora < anterior - 0.3:
			subiu_e_voltou += 1
		anterior = agora

	igual(
		subiu_e_voltou, 1,
		"o gesto do pisao reinicia entre os dois beats, em vez de esticar sobre os dois"
	)
	chefe.free()


## Nenhum quadro de um gesto por PROGRESSO fica parado alem do teto.
##
## Este e o portao que PRODUZ decisao em vez de carimbar uma. Ele divide a
## duracao do estado pelos quadros do gesto e cobra o resultado contra
## `Telegrafo.DURACAO_MINIMA`. Um preparo que estoure o teto nao e um preparo
## ruim -- e um preparo que precisa de mais quadros, ou de outro modo. A Falha do
## Reator e exatamente esse caso, e e por isso que ela esta fora daqui: ver
## `_o_reator_nao_e_dirigido_por_progresso`.
func _nenhum_quadro_fica_parado_alem_do_teto() -> void:
	var chefe := _nascer()
	# A ponta LENTA e a que morde: fase 1 com a barra zerada e o preparo mais
	# longo que existe fora do Reator.
	Deterioracao.valor = 0.0
	_forcar_fase(chefe, 1)
	for ataque in [chefe.SOCO, chefe.RAJADA, chefe.INVESTIDA, chefe.PISAO]:
		_entrar_em_preparar(chefe, ataque)
		var por_quadro: float = chefe.duracao_do_estado() / float(QUADROS_DE_PREPARO)
		ok(
			por_quadro <= TETO_POR_QUADRO,
			"%s: cada quadro do preparo fica %.3fs na tela, dentro do teto de %.2fs"
				% [ataque, por_quadro, TETO_POR_QUADRO]
		)
		ok(
			por_quadro >= PASSO,
			"%s: e nenhum quadro passa despercebido (%.3fs contra o passo de %.4fs)"
				% [ataque, por_quadro, PASSO]
		)
	chefe.free()


## A Falha do Reator NAO pode ser um gesto por progresso, e o numero diz por que.
##
## O preparo dela vale 2,9333 s na fase 1 -- o telegrafo mais longo da luta, e
## por regra do projeto ele tem de continuar sendo, porque ataque capaz de tirar
## grande parte da vida precisa ser facilmente reconhecivel. Quatro quadros
## esticados nisso dao 0,733 s por quadro, o DOBRO do teto: slideshow, e nao
## animacao.
##
## A saida nao e encurtar o aviso, que a issue proibe. E que o Reator ja tem
## contagem regressiva PROPRIA no chao -- o cerco de `AreaDePerigo` com as
## quatro fases do `Telegrafo`. O corpo dele nao precisa responder "quando": a
## pose sobrecarregada e a mensagem, e o anel faz o relogio.
func _o_reator_nao_e_dirigido_por_progresso() -> void:
	var chefe := _nascer()
	Deterioracao.valor = 0.0
	_forcar_fase(chefe, 3)
	_entrar_em_preparar(chefe, chefe.REATOR)

	var por_quadro: float = chefe.duracao_do_estado() / float(QUADROS_DE_PREPARO)
	ok(
		por_quadro > TETO_POR_QUADRO,
		"o preparo do Reator NAO cabe em %d quadros por progresso (%.3fs por quadro, teto %.2fs) -- e por isso que ele e UMA_VEZ"
			% [QUADROS_DE_PREPARO, por_quadro, TETO_POR_QUADRO]
	)

	# E a margem que separa o preparo do piso, medida em vez de assumida. Se
	# `tempo_telegrafo` cair abaixo de 0,7735 o regime vira: o preparo passa a
	# ser cortado pelo piso e o gesto termina antes do golpe.
	Deterioracao.valor = 100.0
	var mais_rapido: float = chefe.tempo_real(chefe.tempo_preparo)
	ok(
		mais_rapido > chefe.TEMPO_MINIMO,
		"o preparo comum NAO e cortado pelo piso: para em %.4fs, %.0f ms acima de %.2f -- quem morde o piso e a execucao"
			% [mais_rapido, (mais_rapido - chefe.TEMPO_MINIMO) * 1000.0, chefe.TEMPO_MINIMO]
	)
	chefe.free()


## Entra em PREPARAR pelo caminho de verdade.
##
## Passa por EXECUTAR antes porque `MaquinaEstados.trocar()` para o estado ATUAL
## e no-op deliberado -- pedir PREPARAR estando em PREPARAR nao roda o
## `_preparar_entrar`, e ai `_aviso_atual` fica com o valor do ataque anterior.
func _entrar_em_preparar(chefe: Node, ataque: StringName) -> void:
	chefe._ataque = ataque
	chefe._maquina.trocar(chefe.EXECUTAR)
	chefe._maquina.trocar(chefe.PREPARAR)


## Poe o chefe na fase pedida pela VIDA, que e de onde a fase sai.
##
## Sao DOIS campos, e escrever so um custou tres falhas ao escrever esta suite.
## `fase_chefe` e o que os multiplicadores leem, mas quem GUARDA a transicao e
## `_fase_anunciada`: `_checar_fase()` compara `fase_por_vida()` contra ele e,
## se a vida ja pede uma fase acima, joga o chefe em TRANSICAO_FASE no primeiro
## `_physics_process`. O sintoma era um PREPARAR de 0,0167 s -- um passo -- e so
## no PRIMEIRO ataque de cada canto, porque a partir do segundo a virada ja
## tinha acontecido.
func _forcar_fase(chefe: Node, fase: int) -> void:
	var fracao: float = [1.0, 0.9, 0.6, 0.2][clampi(fase, 1, 3)]
	chefe.vida = int(float(chefe.vida_maxima) * fracao)
	chefe._fase_anunciada = chefe.fase_por_vida()
	chefe.fase_chefe = chefe.fase_por_vida()


func _nascer() -> Node:
	var chefe := CENA.instantiate()
	Engine.get_main_loop().root.add_child(chefe)
	chefe.global_position = LONGE
	var alvo := Node2D.new()
	chefe.add_child(alvo)
	alvo.global_position = LONGE + Vector2(300.0, 0.0)
	chefe.alvo = alvo
	return chefe
