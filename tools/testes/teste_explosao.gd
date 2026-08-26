extends TesteBase
## Verifica a ExplosaoArea: o dano cai com a distancia, respeita o raio e cobra
## uma vez so.
##
## Esta suite existe porque a primeira versao da explosao **acertava as vezes**.
## Ela estourava no `_ready`, e a convencao do projeto e `add_child` ANTES de
## `configurar` -- no _ready a area ainda estava em (0,0) com o raio padrao,
## varrendo o lugar errado. Uma segunda varredura diferida salvava o caso as
## vezes, dependendo de quantos passos de fisica tinham corrido.
##
## "As vezes acerta" e pior que "nunca acerta": passa no teste, passa no
## playtest, e falha na sala cheia -- que e exatamente quando a granada importa.
## Hoje o estouro e uma consulta direta ao espaco de fisica, feita em
## `configurar()`, e e sincrona: o dano ja aconteceu quando a funcao retorna.
##
## Por isso os casos abaixo NAO esperam frame nenhum depois do estouro. Se
## alguem devolver a explosao para um caminho diferido, eles quebram na hora --
## que e o ponto.

const CENA_EXPLOSAO := preload("res://src/projectiles/explosao_area.tscn")
const CENA_ALVO := preload("res://src/enemies/rastejante.tscn")

## Longe da origem: os inimigos das outras suites vivem perto de (0,0) e a
## explosao varre por LAYER, sem saber de quem e cada corpo. E a mesma licao que
## teste_hack.gd ja registra.
const LONGE := Vector2(9000, 9000)

## Vida alta para o alvo nao morrer no meio da medicao e sumir da conta.
const VIDA_DE_TESTE := 999


func nome() -> String:
	return "Explosao"


func executar() -> void:
	await _o_dano_cai_com_a_distancia()
	await _cobra_uma_vez_so()


func _montar(raiz: Node2D, distancias: Array) -> Array:
	var alvos: Array = []
	for d: float in distancias:
		var alvo := CENA_ALVO.instantiate() as InimigoBase
		raiz.add_child(alvo)
		alvo.global_position = LONGE + Vector2(d, 0.0)
		alvo.vida = VIDA_DE_TESTE
		alvos.append(alvo)
	return alvos


func _estourar(raiz: Node2D, dados: DadosArma) -> void:
	var explosao := CENA_EXPLOSAO.instantiate()
	raiz.add_child(explosao)
	# Sincrono: quando esta linha retorna, o dano ja foi aplicado.
	explosao.configurar(LONGE, dados, Color.WHITE)


func _dados(raio: float, dano: int) -> DadosArma:
	var d := DadosArma.new()
	d.raio_explosao = raio
	d.dano_explosao = dano
	d.knockback_explosao = 300.0
	return d


func _o_dano_cai_com_a_distancia() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)
	var dados := _dados(108.0, 6)
	# Quatro distancias: centro, metade, quase a borda, e FORA.
	var alvos := _montar(raiz, [0.0, 54.0, 104.0, 160.0])

	# Dois passos de fisica: um corpo recem-adicionado so entra no espaco no
	# passo seguinte, e a consulta do estouro pergunta ao espaco.
	await Engine.get_main_loop().physics_frame
	await Engine.get_main_loop().physics_frame

	_estourar(raiz, dados)

	var centro: int = VIDA_DE_TESTE - (alvos[0] as InimigoBase).vida
	var meio: int = VIDA_DE_TESTE - (alvos[1] as InimigoBase).vida
	var borda: int = VIDA_DE_TESTE - (alvos[2] as InimigoBase).vida
	var fora: int = VIDA_DE_TESTE - (alvos[3] as InimigoBase).vida

	igual(centro, dados.dano_explosao, "no centro o dano e integral")
	ok(meio < centro, "na metade do raio doi menos que no centro (%d < %d)" % [meio, centro])
	ok(borda < meio, "perto da borda doi menos que na metade (%d < %d)" % [borda, meio])
	ok(borda >= 1, "quem foi pego pela borda ainda sente (dano %d)" % borda)
	igual(fora, 0, "fora do raio nao ha dano")

	# O empurrao segue o mesmo falloff: explosao que arremessa igual de qualquer
	# distancia tiraria o sentido de mirar no meio do grupo.
	var k_centro: float = (alvos[0] as InimigoBase)._knockback.length()
	var k_borda: float = (alvos[2] as InimigoBase)._knockback.length()
	ok(k_borda < k_centro, "o empurrao tambem cai com a distancia")
	perto((alvos[3] as InimigoBase)._knockback.length(), 0.0, "fora do raio nao ha empurrao")

	# free() e nao queue_free(): a suite roda num frame so, e um alvo que
	# continua na arvore aparece na varredura do caso seguinte.
	raiz.free()


func _cobra_uma_vez_so() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)
	var dados := _dados(108.0, 5)
	var alvos := _montar(raiz, [0.0])

	await Engine.get_main_loop().physics_frame
	await Engine.get_main_loop().physics_frame

	_estourar(raiz, dados)
	var levou: int = VIDA_DE_TESTE - (alvos[0] as InimigoBase).vida
	igual(levou, dados.dano_explosao, "uma explosao cobra exatamente uma vez")

	raiz.free()
