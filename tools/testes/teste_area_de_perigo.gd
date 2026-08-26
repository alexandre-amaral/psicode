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


func nome() -> String:
	return "AreaDePerigo"


func executar() -> void:
	_ciclo_da_area()
	_o_parasita_semeia()
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
