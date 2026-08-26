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
