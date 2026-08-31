extends TesteBase
## Verifica a AreaDePerigo e o contrato dela com o Hacker Parasita.
##
## Esta suite existe por causa de um buraco que o proprio teste de fumaca
## revelou: ele mata todo inimigo a cada 0,12 s, e o ciclo do Parasita leva mais
## de um segundo entre nascer e semear. Resultado, medido em tres runs seguidas:
## o Parasita apareceu, morreu, a run passou verde -- e **zero areas de perigo
## foram criadas**. A guarda de "nenhuma area orfa no fim" passava sem nunca ter
## olhado uma area.
##
## Um teste que so pode passar e pior que teste nenhum: ele da a sensacao de
## cobertura. Entao o caminho que o fumaca nao alcanca e exercitado aqui, no
## nivel em que da para controlar o tempo: um Parasita de verdade, um alvo
## falso, e frames avancados na mao.
##
## A assercao que mais importa e a ultima. Area que sobrevive ao dono e dano
## vindo de um inimigo que nao existe mais -- o jogador nao consegue atribuir
## aquilo a nada e le como bug, nao como ataque.

const CENA_PARASITA := preload("res://src/enemies/hacker_parasita.tscn")
const CENA_AREA := preload("res://src/enemies/area_de_perigo.tscn")

## Passo grande de proposito: nao interessa simular fisica de verdade, so
## empurrar a maquina de estados ate o ponto que se quer observar.
const PASSO := 0.1
const MAX_FRAMES := 120


## Longe da origem, pelo mesmo motivo das outras suites: o grupo "inimigo" e
## global e sobras de outras suites ficam quase todas perto de (0,0).
const LONGE := Vector2(12000, 12000)

## O boneco tem de responder `receber_dano` -- a area so fere quem responde.
const SCRIPT_BONECO := preload("res://tools/testes/boneco_de_dano.gd")


func nome() -> String:
	return "AreaDePerigo"


func executar() -> void:
	_ciclo_da_area()
	await _quem_esta_parado_dentro_tambem_toma()
	await _a_forma_alternativa_vale()
	_o_aviso_tem_as_quatro_fases()
	await _a_brasa_cobra_quem_fica()
	_a_brasa_nao_encadeia_hitstop()
	_sem_brasa_a_area_some_como_antes()
	_o_parasita_semeia()
	_o_teto_de_areas_continua_valendo()
	_as_areas_morrem_com_o_dono()


# ------------------------------------------------------------ a area --------

## Ela nasce desligada e so passa a machucar na janela de dano.
##
## Enquanto e aviso, encostar nela nao pode custar nada -- senao o telegrafo
## estaria mentindo, e o jogador aprenderia que o circulo ja fere antes de
## explodir, que e o oposto do que ele ensina.
func _ciclo_da_area() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)

	var area := CENA_AREA.instantiate()
	raiz.add_child(area)
	area.configurar(Vector2(100, 100), 48.0, 1)

	ok(not area.monitoring, "a area nasce sem machucar (ainda e so aviso)")
	ok(area.global_position.is_equal_approx(Vector2(100, 100)), "configurar() poe a area no lugar pedido")

	raiz.queue_free()


## FICAR PARADO DENTRO DO CIRCULO NAO PODE SER A FORMA MAIS SEGURA DE
## SOBREVIVER A ELE.
##
## Este caso existe porque o defeito era exatamente esse, e viveu no jogo desde
## que a area foi escrita. `_explodir()` ligava `monitoring` e chamava
## `get_overlapping_bodies()` no MESMO frame -- e aquele metodo responde com o
## estado do ultimo passo de fisica, quando a area ainda estava desligada. A
## lista voltava vazia, sempre. O comentario logo acima dela descrevia o
## conserto que nao acontecia, e o GEMINI.md afirmava que a licao ja tinha sido
## aplicada aqui.
##
## Quem so ENTRA na area continuava tomando dano, via `body_entered` -- e por
## isso nada parecia quebrado. Quem ja estava dentro, nao. Ou seja: o ataque
## punia quem se mexia e perdoava quem congelava, o inverso do que ele existe
## para fazer.
func _quem_esta_parado_dentro_tambem_toma() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)

	var vitima := _boneco()
	raiz.add_child(vitima)
	vitima.global_position = LONGE

	var area := CENA_AREA.instantiate()
	area.tempo_aviso = 0.05
	raiz.add_child(area)
	area.configurar(LONGE, 64.0, 3)

	# Um passo de fisica: corpo recem-adicionado so entra no espaco no passo
	# seguinte, e a varredura pergunta ao espaco.
	await Engine.get_main_loop().physics_frame
	await Engine.get_main_loop().physics_frame
	area._explodir()

	ok(vitima.dano_levado > 0, "quem ja estava parado dentro leva dano (%d)" % vitima.dano_levado)
	raiz.free()


## A forma alternativa vale, e `configurar()` de fato redesenha.
##
## O segundo defeito da mesma funcao: `_ready` montava a colisao com o `raio`
## padrao e `configurar()` reatribuia o campo depois, sem redesenhar nada. O
## raio pedido nao tinha efeito nem no desenho nem na colisao. Passava
## despercebido porque o unico chamador pedia 60 contra um default de 56.
func _a_forma_alternativa_vale() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)

	# Uma FAIXA, que e o que a Rede de Exterminio da Diretora usa. O alvo esta
	# a 120 px no eixo longo: fora de qualquer circulo de raio 64, dentro da
	# faixa de 400 de comprimento.
	var vitima := _boneco()
	raiz.add_child(vitima)
	vitima.global_position = LONGE + Vector2(120, 0)

	var area := CENA_AREA.instantiate()
	area.tempo_aviso = 0.05
	raiz.add_child(area)
	area.configurar(LONGE, -1.0, 2, PackedVector2Array([
		Vector2(-200, -24), Vector2(200, -24), Vector2(200, 24), Vector2(-200, 24),
	]))

	await Engine.get_main_loop().physics_frame
	await Engine.get_main_loop().physics_frame
	area._explodir()

	ok(vitima.dano_levado > 0, "a faixa alcanca quem esta longe do centro dela (%d)" % vitima.dano_levado)
	raiz.free()


## Um corpo minimo que conta o dano que levou.
func _boneco() -> CharacterBody2D:
	var corpo := CharacterBody2D.new()
	corpo.collision_layer = 1  # player
	corpo.collision_mask = 0
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 11.0
	forma.shape = circulo
	corpo.add_child(forma)
	corpo.set_script(SCRIPT_BONECO)
	return corpo


# ------------------------------------------------------- as quatro fases ----

## O aviso passa pelas quatro fases do `Telegrafo`, e nao machuca em nenhuma.
##
## Fase unica responde "vem coisa"; num ataque que nega chao o jogador tambem
## precisa de "vem QUANDO" -- e a diferenca entre sair andando e sair correndo.
## Que ele nao fira durante o aviso e a outra metade: um circulo que ja cobra
## antes de estourar faria o telegrafo mentir, e o jogador aprenderia a regra
## errada.
func _o_aviso_tem_as_quatro_fases() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)

	var area := CENA_AREA.instantiate()
	area.tempo_aviso = 1.0
	raiz.add_child(area)
	area.configurar(LONGE, 48.0, 1)

	var t: Telegrafo = area._telegrafo
	ok(t != null, "o aviso da area e um Telegrafo, e nao um tween proprio")
	igual(area.fase, area.Fase.AVISO, "ela comeca no aviso")
	igual(t.fase(), Telegrafo.Fase.FRACO, "fase 1: circulo fraco")

	area._physics_process(0.5)
	igual(t.fase(), Telegrafo.Fase.CRESCENDO, "fase 2: aumentando intensidade")
	ok(not area.monitoring, "e durante o aviso ela continua sem machucar")

	area._physics_process(0.3)
	igual(t.fase(), Telegrafo.Fase.PISCANDO, "fase 3: piscando")
	ok(not area.monitoring, "ainda sem machucar na fase 3 -- o aviso e so aviso")

	area._physics_process(0.3)
	igual(area.fase, area.Fase.ESTOURO, "fase 4: ativacao -- a area estourou")
	ok(area.monitoring, "e so agora ela machuca")
	ok(not t.aceso(), "o telegrafo apaga no estouro: aviso aceso durante o dano e ruido")

	raiz.free()


# -------------------------------------------------------- a zona residual ---

## A BRASA. Ela nao e para matar; e para impedir voltar.
##
## O estouro sozinho e um instante: quem esta fora nao se importa e o chao esta
## livre um segundo depois. O Parasita e o inimigo de controle territorial, e
## sem a brasa ele nao controla nada -- ele so pune um momento.
##
## O que se cobra aqui: quem FICA continua pagando, o preco por tique e baixo,
## e a area some quando a brasa acaba.
func _a_brasa_cobra_quem_fica() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)

	var vitima := _boneco()
	raiz.add_child(vitima)
	vitima.global_position = LONGE

	var area := CENA_AREA.instantiate()
	area.tempo_aviso = 0.05
	area.tempo_dano = 0.1
	area.tempo_residual = 1.5
	area.intervalo_residual = 0.5
	raiz.add_child(area)
	area.configurar(LONGE, 64.0, 2)

	await Engine.get_main_loop().physics_frame
	await Engine.get_main_loop().physics_frame

	# Passo maior que `Telegrafo.DURACAO_MINIMA`: o piso levanta um `tempo_aviso`
	# de 0,05 s ate 0,35 s, e e para isso que ele existe.
	area._physics_process(0.4)
	igual(area.fase, area.Fase.ESTOURO, "o estouro veio")
	var do_estouro: int = vitima.dano_levado
	igual(do_estouro, 2, "e cobrou o dano cheio uma vez")

	area._physics_process(0.2)
	igual(area.fase, area.Fase.RESIDUAL, "passado o estouro, fica a brasa")
	igual(vitima.dano_levado, do_estouro,
		"o primeiro tique da brasa NAO e no instante do estouro -- seria cobrar duas vezes")

	# Um intervalo inteiro parado dentro dela.
	area._physics_process(0.5)
	ok(vitima.dano_levado > do_estouro,
		"quem fica na brasa continua pagando (%d apos o estouro de %d)"
			% [vitima.dano_levado, do_estouro])
	igual(vitima.dano_levado - do_estouro, area.dano_residual,
		"e paga o dano RESIDUAL, nao o dano cheio de novo")

	# Ate o fim da brasa: o total tem de continuar baixo. Ela cobra ficar, nao
	# mata -- uma brasa letal viraria parede, e parede nao pressiona, bloqueia.
	for _i in 20:
		area._physics_process(0.1)
		if area.is_queued_for_deletion():
			break
	ok(area.is_queued_for_deletion(), "acabada a brasa, a area some sozinha")
	ok(
		vitima.dano_levado - do_estouro <= 4,
		"e o total da brasa fica baixo (%d em %.1f s parado dentro dela)"
			% [vitima.dano_levado - do_estouro, area.tempo_residual]
	)

	raiz.free()


## A brasa nao pode ENCADEAR hitstop.
##
## Dano continuo pede um hitstop a cada acerto, e um hitstop encadeado prende o
## jogo em camera lenta -- foi o que fez o feixe do Laser entregar 19 de dano
## onde o `.tres` pedia 26, porque ele atrasava a si mesmo. `Juice` ja poe um
## piso global de `INTERVALO_HITSTOP`; o que se cobra aqui e que o tique da
## brasa fique bem acima dele, para nunca chegar perto do limite.
func _a_brasa_nao_encadeia_hitstop() -> void:
	var area := CENA_AREA.instantiate()
	var piso_segundos := float(Juice.INTERVALO_HITSTOP) / 1000.0
	ok(
		area.intervalo_residual > piso_segundos * 2.0,
		"o tique da brasa (%.2f s) fica bem acima do piso de hitstop (%.2f s)"
			% [area.intervalo_residual, piso_segundos]
	)
	igual(area.dano_residual, 1, "e o tique cobra pouco: a brasa nega chao, nao mata")
	area.free()


## Sem brasa, a area some no fim do estouro -- exatamente como antes.
##
## A mesma cena serve os ataques de area da Diretora, e o repertorio dela foi
## medido sem brasa nenhuma. Por isso o default e ZERO: ligar a zona residual
## para todo mundo mudaria o chefe de lado, sem ninguem pedir.
func _sem_brasa_a_area_some_como_antes() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)

	var area := CENA_AREA.instantiate()
	perto(area.tempo_residual, 0.0, "a area nasce SEM brasa")
	area.tempo_aviso = 0.05
	area.tempo_dano = 0.1
	raiz.add_child(area)
	area.configurar(LONGE, 48.0, 1)

	area._physics_process(0.4)
	area._physics_process(0.2)
	ok(area.is_queued_for_deletion(), "sem brasa, ela some assim que o estouro termina")

	raiz.free()


# --------------------------------------------------------- o parasita -------

## O Parasita chega a semear se ninguem o matar antes.
##
## E exatamente o que o teste de fumaca nao consegue afirmar. Aqui o tempo e
## nosso: avanca-se a maquina de estados dele ate a area aparecer.
func _o_parasita_semeia() -> void:
	var cena := _montar_parasita()
	var parasita: Node = cena["parasita"]
	var container: Node = cena["container"]

	var apareceu := _avancar_ate_semear(parasita, container)
	ok(apareceu, "o Parasita chega a semear uma area de perigo se sobreviver")

	cena["raiz"].queue_free()


## O TETO de areas continua valendo.
##
## A brasa faz cada area viver mais que o dobro do que vivia, e o teto e o unico
## motivo pelo qual o Parasita nao preenche a sala: tres deles com brasa e sem
## teto cobrem o chao inteiro, e nao sobra lugar para o jogador ESTAR. Um
## inimigo de controle territorial que controla o territorio todo nao e um
## inimigo, e um cronometro.
func _o_teto_de_areas_continua_valendo() -> void:
	var cena := _montar_parasita()
	var parasita: Node = cena["parasita"]
	var container: Node = cena["container"]

	var pico := 0
	for _i in MAX_FRAMES * 4:
		parasita._comportamento(PASSO)
		for filho in container.get_children():
			if filho is AreaDePerigo:
				filho._physics_process(PASSO)
		pico = maxi(pico, _contar_areas(container))

	ok(pico >= 1, "o Parasita semeou ao longo da simulacao (pico de %d)" % pico)
	ok(
		pico <= parasita._max_areas_agora(),
		"e nunca passou do teto de %d areas vivas (pico de %d)"
			% [parasita._max_areas_agora(), pico]
	)
	ok(parasita.tempo_residual > 0.0,
		"e a brasa dele esta ligada (%.1f s) -- e ela que faz o teto importar"
			% parasita.tempo_residual)

	cena["raiz"].queue_free()


## A assercao central: matar o Parasita leva as areas dele junto.
func _as_areas_morrem_com_o_dono() -> void:
	var cena := _montar_parasita()
	var parasita: Node = cena["parasita"]
	var container: Node = cena["container"]

	if not _avancar_ate_semear(parasita, container):
		ok(false, "o Parasita semeou (pre-condicao desta verificacao)")
		cena["raiz"].queue_free()
		return

	var antes := _contar_areas(container)
	ok(antes >= 1, "havia area viva antes de o Parasita morrer (%d)" % antes)

	parasita.morrer()

	# `queue_free` so tira o no da arvore no fim do frame, entao contar agora
	# ainda veria as areas. O que da para afirmar de imediato e que elas foram
	# MARCADAS para morrer -- e e isso que impede o dano orfao.
	var pendentes := 0
	for filho in container.get_children():
		if filho is AreaDePerigo and filho.is_queued_for_deletion():
			pendentes += 1
	igual(pendentes, antes, "todas as areas do Parasita foram liberadas junto com ele")

	cena["raiz"].queue_free()


# ----------------------------------------------------------- montagem -------

## Um Parasita numa arvore minima, com um alvo falso no grupo "player".
##
## O alvo precisa existir e estar PERTO: o Parasita semeia em volta do jogador,
## e sem alvo ele nao teria onde plantar.
func _montar_parasita() -> Dictionary:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)

	var jogador := CharacterBody2D.new()
	jogador.add_to_group("player")
	raiz.add_child(jogador)
	jogador.global_position = Vector2(400, 0)

	# O container e o pai das areas, como a Sala faz com os inimigos.
	var container := Node2D.new()
	raiz.add_child(container)

	var parasita := CENA_PARASITA.instantiate()
	container.add_child(parasita)
	parasita.global_position = Vector2.ZERO

	return {"raiz": raiz, "parasita": parasita, "container": container, "jogador": jogador}


## Empurra o comportamento do Parasita ate a primeira area aparecer.
##
## Chama `_comportamento` direto em vez de esperar o `_physics_process`: a suite
## roda sincrona, sem frames de fisica de verdade, e o que interessa e a
## maquina de estados -- nao o deslocamento.
func _avancar_ate_semear(parasita: Node, container: Node) -> bool:
	for _i in MAX_FRAMES:
		parasita._comportamento(PASSO)
		if _contar_areas(container) >= 1:
			return true
	return false


func _contar_areas(container: Node) -> int:
	var n := 0
	for filho in container.get_children():
		if filho is AreaDePerigo and not filho.is_queued_for_deletion():
			n += 1
	return n
