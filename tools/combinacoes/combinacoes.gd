extends Node
## AS SALAS DE TESTE DE COMBINACAO (INIM 10).
##
## Cada inimigo foi refinado sozinho nas INIM 01-05, e sozinho cada um se
## comporta. O que este arnes responde e a outra pergunta, que nenhum teste do
## projeto fazia: **o que acontece quando dois deles pedem coisas opostas ao
## mesmo tempo?** A Sentinela empurra o jogador a circular e a Cyber-Besta
## atravessa a rota; o Hacker encolhe o chao enquanto o Atirador cobra que se
## saia da linha. E ai que nasce a situacao inevitavel -- nunca num inimigo so.
##
## O que ele mede sao DOIS numeros da `MedidorEscape`, e sao dois porque o
## jogador tem duas escapatorias com precos diferentes:
##
## 1. **Saidas a pe**, contando ficar parado. E a mesma pergunta que
##    `teste_diretora.gd` faz para cada ataque do chefe -- "quantas aberturas" --,
##    generalizada para o campo inteiro. E o numero de folga.
##
## 2. **A maior janela sem saida a pe, em segundos.** E este que reprova, e nao
##    o frame isolado. O rolamento da i-frames pela duracao inteira (0,22 s mais
##    0,06 s de graca), e ele existe exatamente para isso: uma janela curta sem
##    saida nao e injustica, e o momento em que o jogo cobra o rolamento. Uma
##    janela MAIS LONGA que os i-frames e outra coisa -- ai nem rolar salva, e
##    isso e a situacao inevitavel que o GDD proibe.
##
## Contar frame isolado reprovaria a Cyber-Besta em toda combinacao: uma vez
## comprometida com a investida, ela e mais rapida que o andar do jogador, e
## `nenhuma saida a pe` durante ~0,26 s e o desenho dela e nao um defeito -- o
## aviso de 0,8 s antes da investida e onde a decisao acontece.
##
## POR QUE NAO E UMA SUITE UNITARIA: o Hacker leva mais de um segundo entre
## nascer e semear, e o teste de fumaca mata tudo a cada 0,12 s -- em tres runs
## seguidas ele apareceu e ZERO areas foram criadas. Combinacao que depende de
## ciclo longo precisa de tempo de relogio, e tempo de relogio nao cabe no
## runner de segundos. A regua em si, essa sim, e testada la
## (`teste_combinacoes.gd`).
##
## POR QUE NAO E UM SISTEMA PARALELO: a sala e uma `Sala` de verdade, com a
## parede gerada do `Line2D` e o `ContainerInimigos` da cena, e a composicao
## entra por `definir_composicao()` -- o mesmo caminho que o `GerenciadorMapa`
## usa. Um spawner proprio mediria um jogo que nao existe.
##
## Use:  godot --headless --path . tools/combinacoes/combinacoes.tscn
## Saida 0 = nenhuma combinacao produziu situacao inevitavel.

const CENA_SALA := preload("res://src/mapa/sala_1_retangular.tscn")
const DRONE := preload("res://src/enemies/drone_aranha.tscn")
const NEON := preload("res://src/enemies/atirador_neon.tscn")
const BESTA := preload("res://src/enemies/cyber_besta.tscn")
const SENTINELA := preload("res://src/enemies/sentinela_orbital.tscn")
const HACKER := preload("res://src/enemies/hacker_parasita.tscn")

## As cinco combinacoes que o plano quer avaliar, e o que cada uma cria.
const COMBINACOES := [
	{
		"nome": "Drone + Cyber-Besta",
		"cria": "linhas de projetil enquanto algo forca voce a sair do lugar",
		"cenas": ["drone", "besta"],
	},
	{
		"nome": "Atirador + Hacker",
		"cria": "o espaco encolhe enquanto linhas precisam ser evitadas",
		"cenas": ["neon", "hacker"],
	},
	{
		"nome": "Sentinela + Cyber-Besta",
		"cria": "ela incentiva movimento circular, a Besta atravessa a rota",
		"cenas": ["sentinela", "besta"],
	},
	{
		"nome": "Drone + Hacker",
		"cria": "o Hacker remove as regioes seguras da rajada radial",
		"cenas": ["drone", "hacker"],
	},
	{
		"nome": "Todos juntos",
		"cria": "o teto",
		"cenas": ["drone", "neon", "besta", "sentinela", "hacker"],
	},
]

## Os valores de Deterioracao que o andar 1 alcanca. A run termina em 100 -- o
## teste de fumaca mede isso a cada passagem --, entao a faixa inteira vale.
##
## Medir so em zero seria medir o jogo que ninguem joga depois da terceira sala;
## medir so em 100 esconderia uma inevitabilidade que nasce no meio, quando a
## Sentinela ja raja e o Parasita ainda segura pouco chao.
const BARRAS := [0.0, 35.0, 70.0, 100.0]

## Quanto tempo cada combinacao roda, em cada valor de barra.
##
## Longo o bastante para o ciclo mais lento fechar: o Parasita leva ~1 s entre
## nascer e semear, e a area dele vive quase 3,5 s entre aviso, estouro e brasa.
const SEGUNDOS_POR_CENARIO := 8.0

## Raio do corpo do jogador e velocidade dele. Saem da cena do Player, e nao de
## um numero copiado: um Player mais gordo ou mais lento muda a resposta.
var _raio_jogador: float = 11.0
var _velocidade_jogador: float = 330.0
## A janela de invulnerabilidade do rolamento: duracao mais graca. E o teto de
## quanto tempo o jogo pode ficar sem saida a pe sem ser injusto.
var _iframes_rolamento: float = 0.28

var _erros: Array[String] = []
## Cenarios que passaram raspando. Nao reprovam, mas vao para o relatorio.
var _avisos: Array[String] = []
var _linhas: Array[String] = []


func _ready() -> void:
	# Sem isto, a Deterioracao passiva sobe durante a medicao e a barra que se
	# quer fixar deixa de estar fixa.
	Deterioracao.passiva_ativa = false
	_ler_o_jogador()
	await _rodar()


func _ler_o_jogador() -> void:
	var player := preload("res://src/player/player.tscn").instantiate()
	add_child(player)
	_velocidade_jogador = player.velocidade_max
	_iframes_rolamento = player.roll_duracao + player.roll_graca
	var forma := player.get_node_or_null("Forma") as CollisionShape2D
	if forma != null and forma.shape is CircleShape2D:
		_raio_jogador = (forma.shape as CircleShape2D).radius
	player.free()


func _rodar() -> void:
	print("\n=== COMBINACOES DE INIMIGO: psicode ===\n")
	print("  regua: %d direcoes + ficar parado, horizonte de %.2f s" % [
		MedidorEscape.DIRECOES, MedidorEscape.HORIZONTE,
	])
	print("  jogador: raio %.0f px, %.0f px/s\n" % [_raio_jogador, _velocidade_jogador])

	for combinacao: Dictionary in COMBINACOES:
		print("  %s" % combinacao["nome"])
		print("    (%s)" % combinacao["cria"])
		for barra: float in BARRAS:
			await _medir(combinacao, barra)
		print("")

	_relatorio()


## Monta a sala, poe a combinacao dentro, e conta as saidas a cada frame.
##
## O jogador aqui e um ISCA parada, e isso e deliberado: a pergunta e "existe
## saida?", nao "o boneco acha a saida". Um boneco que se mexe mediria a IA dele,
## e a IA dele nao existe. Parado, ele e o pior caso -- todo inimigo converge
## para ele -- e a resposta continua sendo sobre o campo.
func _medir(combinacao: Dictionary, barra: float) -> void:
	Deterioracao.valor = barra

	var raiz := Node2D.new()
	add_child(raiz)

	var sala: Sala = CENA_SALA.instantiate()
	raiz.add_child(sala)

	var isca := _isca()
	raiz.add_child(isca)
	isca.global_position = sala.global_position

	var composicao: Array[PackedScene] = []
	for chave: String in combinacao["cenas"]:
		composicao.append(_cena_de(chave))
	sala.definir_composicao(composicao)
	sala.ativar()

	var pior := MedidorEscape.DIRECOES + 1
	var janela := 0.0
	var pior_janela := 0.0
	var frames := 0
	var decorrido := 0.0
	while decorrido < SEGUNDOS_POR_CENARIO:
		await get_tree().physics_frame
		var passo := get_physics_process_delta_time()
		decorrido += passo
		frames += 1
		# A barra e reescrita todo frame: matar um inimigo soma Deterioracao, e
		# o cenario tem de continuar sendo o cenario que se pediu medir.
		Deterioracao.valor = barra
		var saidas := MedidorEscape.saidas_livres(
			isca.global_position, _raio_jogador, _velocidade_jogador,
			MedidorEscape.ameacas(raiz, isca)
		)
		pior = mini(pior, saidas)
		# A JANELA e o que reprova, e nao o frame: e ela que se compara com os
		# i-frames do rolamento.
		if saidas == 0:
			janela += passo
			pior_janela = maxf(pior_janela, janela)
		else:
			janela = 0.0

	print("    barra %3.0f%%: pior momento deixou %d saidas de %d; maior janela sem saida a pe %.2f s (teto %.2f)" % [
		barra, pior, MedidorEscape.DIRECOES + 1, pior_janela, _iframes_rolamento,
	])
	_linhas.append("%s @ %.0f%%" % [combinacao["nome"], barra])
	# Margem fina nao reprova, mas nao pode passar calada: 0,01 s de folga e um
	# numero que a proxima mudanca de tuning derruba sem ninguem perceber, e a
	# sessao de tuning precisa saber onde ela esta pisando.
	if pior_janela <= _iframes_rolamento and pior_janela > _iframes_rolamento * 0.8:
		_avisos.append(
			"%s a %.0f%%: %.2f s sem saida a pe contra %.2f s de i-frames -- so %.2f s de folga"
				% [combinacao["nome"], barra, pior_janela, _iframes_rolamento,
					_iframes_rolamento - pior_janela]
		)
	if pior_janela > _iframes_rolamento:
		_erros.append(
			"%s a %.0f%% de Deterioracao: %.2f s sem saida a pe, mais que os %.2f s de i-frames do rolamento"
				% [combinacao["nome"], barra, pior_janela, _iframes_rolamento]
		)

	raiz.queue_free()
	await get_tree().process_frame


## Um corpo minimo no grupo "player": os inimigos precisam de alvo, e o alvo
## precisa responder `receber_dano` para o combate acontecer de verdade.
func _isca() -> CharacterBody2D:
	var corpo := CharacterBody2D.new()
	corpo.name = "Isca"
	corpo.add_to_group("player")
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = _raio_jogador
	forma.shape = circulo
	corpo.add_child(forma)
	corpo.set_script(preload("res://tools/testes/boneco_de_dano.gd"))
	return corpo


func _cena_de(chave: String) -> PackedScene:
	match chave:
		"drone": return DRONE
		"neon": return NEON
		"besta": return BESTA
		"sentinela": return SENTINELA
		"hacker": return HACKER
	return null


func _relatorio() -> void:
	print("--- resultado ---")
	if not _avisos.is_empty():
		print("  MARGEM FINA em %d cenario(s) -- passou, mas com pouca folga:" % _avisos.size())
		for a in _avisos:
			print("    ! " + a)
	if _erros.is_empty():
		print("  PASSOU: %d cenarios, nenhum instante sem saida\n" % _linhas.size())
		get_tree().quit(0)
		return
	print("  FALHOU: %d cenario(s) com situacao inevitavel" % _erros.size())
	for e in _erros:
		print("    - " + e)
	print("")
	get_tree().quit(1)
