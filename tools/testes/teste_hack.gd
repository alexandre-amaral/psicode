extends TesteBase
## Verifica o Hack de NOVA: duracao, bonus de dano e propagacao na morte.
##
## Esta suite existe pelo mesmo motivo que teste_area_de_perigo: **o teste de
## fumaca nao alcanca comportamento com duracao**. Ele mata todo inimigo a cada
## 0,12 s, e o Hack dura 4 s -- uma run inteira passaria verde sem que um unico
## inimigo chegasse a expirar marcado, e sem que a propagacao rodasse uma vez.
##
## O sorteio de 10% tambem nao da para observar por amostragem sem tornar a
## suite instavel. A saida e a mesma que o projeto ja usa para ricochete: em vez
## de medir a chance, forca-se chance 1.0 e 0.0 e verifica-se o caminho
## deterministico dos dois lados.
##
## A assercao que mais importa e a do armar/consumir por TIRO. Se o sorteio
## escorregar para dentro do projetil, NOVA com a shotgun passa a rolar os 10%
## oito vezes por disparo -- ~57% -- e nada no jogo acusa, porque continua
## "funcionando".

const CENA_RASTEJANTE := preload("res://src/enemies/rastejante.tscn")

const PASSO := 0.1
const MAX_FRAMES := 120

## Longe da origem de proposito. A propagacao busca no grupo "inimigo", que e
## global: inimigos de OUTRAS suites que ainda nao foram coletados aparecem na
## busca, e quase todos ficam perto de (0,0). Medido: a busca via 6 inimigos
## onde esta suite tinha criado 4, e o vizinho mais proximo era de outra suite.
## Afastar o cenario e o que torna este caso independente da ordem das suites.
const LONGE := Vector2(6000, 6000)


func nome() -> String:
	return "Hack"


func executar() -> void:
	_a_config_liga_e_desliga()
	_armar_e_consumir_valem_por_tiro()
	_a_marca_expira()
	_a_marca_propaga_para_o_mais_proximo()
	Modificadores.resetar()


## Personagem sem Hack tem de desligar o mecanismo inteiro, e nao so zerar a
## chance: e assim que RAVEN se declara.
func _a_config_liga_e_desliga() -> void:
	Modificadores.resetar()

	Modificadores.configurar_hack(_personagem(0.0))
	ok(not Modificadores.tem_hack(), "personagem com chance zero nao hackeia")
	perto(Modificadores.bonus_dano_hack(), 1.0, "sem Hack o bonus de dano e neutro")
	perto(Modificadores.chance_propagacao_hack(), 0.0, "sem Hack nao ha propagacao")

	Modificadores.configurar_hack(_personagem(1.0))
	ok(Modificadores.tem_hack(), "personagem com chance positiva hackeia")
	perto(Modificadores.bonus_dano_hack(), 1.25, "o bonus de dano vem do personagem")

	Modificadores.configurar_hack(null)
	ok(not Modificadores.tem_hack(), "personagem nulo nao hackeia")


## Um armar = um consumir. E o que garante que o sorteio valha por tiro mesmo
## quando o tiro solta oito projeteis.
func _armar_e_consumir_valem_por_tiro() -> void:
	Modificadores.resetar()
	Modificadores.configurar_hack(_personagem(1.0))

	perto(Modificadores.consumir_hack(), 0.0, "sem armar, consumir nao devolve nada")

	Modificadores.armar_hack()
	perto(Modificadores.consumir_hack(), 4.0, "armado, o primeiro acerto leva a duracao")
	# O segundo projetil do MESMO tiro nao pode hackear de novo.
	perto(Modificadores.consumir_hack(), 0.0, "o segundo projetil do mesmo tiro nao hackeia")

	# Chance zero nunca arma, mesmo chamando armar_hack a cada tiro.
	Modificadores.configurar_hack(_personagem(0.0))
	for i in 20:
		Modificadores.armar_hack()
	perto(Modificadores.consumir_hack(), 0.0, "chance zero nunca arma")

	Modificadores.resetar()
	Modificadores.armar_hack()
	perto(Modificadores.consumir_hack(), 0.0, "resetar solta o Hack armado")


func _a_marca_expira() -> void:
	Modificadores.resetar()
	Modificadores.configurar_hack(_personagem(1.0))

	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)
	var alvo := _nascer(raiz, LONGE)

	ok(not alvo.esta_hackeado(), "inimigo nasce sem marca")

	alvo.aplicar_hack(0.3)
	ok(alvo.esta_hackeado(), "aplicar_hack marca o alvo")

	# Renova, nao soma: dois tiros seguidos nao viram meio minuto de marca.
	alvo.aplicar_hack(0.2)
	ok(alvo.esta_hackeado(), "marca renovada continua valendo")

	_avancar(alvo, 0.35)
	ok(not alvo.esta_hackeado(), "a marca expira sozinha")

	# free() e nao queue_free(): a suite roda inteira num frame so, entao um
	# queue_free nao chega a acontecer antes do proximo caso. A propagacao busca
	# por grupo, e este inimigo -- que fica em (0,0) -- apareceria como o vizinho
	# mais proximo do caso seguinte. Foi exatamente o que aconteceu.
	raiz.free()


## O Hack pula para o vizinho VIVO mais proximo dentro do raio -- e nao para o
## primeiro que a busca por grupo devolver.
func _a_marca_propaga_para_o_mais_proximo() -> void:
	Modificadores.resetar()
	Modificadores.configurar_hack(_personagem(1.0, 1.0))

	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)

	var morrendo := _nascer(raiz, LONGE)
	var longe := _nascer(raiz, LONGE + Vector2(180, 0))
	var perto_ := _nascer(raiz, LONGE + Vector2(60, 0))
	var fora := _nascer(raiz, LONGE + Vector2(900, 0))

	morrendo.aplicar_hack(4.0)
	morrendo.morrer()

	ok(perto_.esta_hackeado(), "o Hack pula para o vizinho mais proximo")
	ok(not longe.esta_hackeado(), "o vizinho mais distante nao recebe")
	ok(not fora.esta_hackeado(), "quem esta fora do raio nao recebe")

	raiz.free()


# ------------------------------------------------------------ helpers -------

func _personagem(chance: float, propagacao: float = 0.5) -> DadosPersonagem:
	var p := DadosPersonagem.new()
	p.hack_chance = chance
	p.hack_duracao = 4.0
	p.hack_bonus_dano = 1.25
	p.hack_chance_propagacao = propagacao
	p.hack_raio_propagacao = 220.0
	return p


func _nascer(raiz: Node, posicao: Vector2) -> InimigoBase:
	var inimigo := CENA_RASTEJANTE.instantiate() as InimigoBase
	raiz.add_child(inimigo)
	inimigo.global_position = posicao
	return inimigo


## Avanca o relogio do inimigo na mao. O _physics_process nao roda numa suite
## sincrona, e esperar frames de verdade tornaria a suite lenta e instavel.
func _avancar(inimigo: InimigoBase, segundos: float) -> void:
	var passos := int(ceil(segundos / PASSO))
	for i in mini(passos, MAX_FRAMES):
		inimigo._physics_process(PASSO)
