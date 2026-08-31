extends TesteBase
## A porta como SOLIDO: quem bloqueia, quando, e onde.
##
## Esta suite nasceu de um defeito que ninguem via e todo mundo sentia: a porta
## SELADA -- a do lado da sala que nao tem vizinho -- continuava ligando a
## propria barreira. E a barreira nao fica no mesmo lugar que a parede.
##
## A parede gerada por `Sala._montar_paredes()` e um `SegmentShape2D` sobre a
## linha do contorno, sem espessura. A barreira da porta e um retangulo de 80x32
## CENTRADO nessa linha. Metade dele -- 16 px -- caia DENTRO da area jogavel.
## Resultado: uma laje invisivel de 80x16 encostada na parede, em todo lado de
## sala sem vizinho, e o jogador esbarrando em nada.
##
## Nao ha erro no console para colisao a mais, e o teste de fumaca nao pega:
## ele nunca tenta encostar na parede. Por isso a trava e aqui.
##
## A pergunta que a suite faz de cada estado e sempre a mesma: **este estado
## precisa de um solido proprio, ou ja existe um solido ali?**

const CENA_PORTA := preload("res://src/mapa/porta.tscn")
const CENA_SALA := preload("res://src/mapa/sala_1_retangular.tscn")

const CAMINHO_BARREIRA := "Barreira/Colisao"

## Longe da origem, como as outras suites que sobem nos: sobras de outras
## suites ficam quase todas perto de (0,0).
const LONGE := Vector2(15000, 15000)


func nome() -> String:
	return "Porta"


func executar() -> void:
	await _cada_estado_e_seu_solido()
	await _sala_sem_vizinho_nao_deixa_solido_sobrando()
	await _a_abertura_nao_cobra_pedagio()


## A ANIMACAO DE ABERTURA e leitura, e nao pedagio (AND1 05).
##
## Duas coisas se cobram, e as duas sao sobre o mesmo risco: o jogador atravessa
## dez salas por andar, num jogo cujo sistema-assinatura e uma barra que sobe com
## o TEMPO.
##
## 1. **A BARREIRA CAI NO PRIMEIRO QUADRO**, e nao no fim da animacao. Se a
##    passagem so liberasse ao terminar, cada porta cobraria a propria duracao em
##    toda travessia -- meio segundo por porta sao cinco segundos parados por
##    run. Quem quer correr atravessa ja; quem olha, ve a maquina velha pegando.
## 2. **A duracao tem TETO, e ele e const e nao `@export`.** E limite de design e
##    nao botao de tuning: um numero ajustavel aqui seria ajustado para cima na
##    primeira vez que alguem achasse a animacao bonita.
func _a_abertura_nao_cobra_pedagio() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)
	var porta := _porta_solta(raiz)
	ok(porta.TEMPO_DE_ABERTURA <= porta.TEMPO_MAXIMO_DE_ABERTURA,
		"a abertura cabe no teto (%.2f s de %.2f)"
			% [porta.TEMPO_DE_ABERTURA, porta.TEMPO_MAXIMO_DE_ABERTURA])
	ok(porta.TEMPO_MAXIMO_DE_ABERTURA <= 0.6,
		"e o teto e curto: dez portas por andar transformam meio segundo em cinco")

	# A barreira cai ANTES de a animacao terminar -- de fato, no mesmo frame.
	porta.trancar()
	var colisao := porta.get_node_or_null("Barreira/Colisao") as CollisionShape2D
	ok(colisao != null, "a porta tem barreira")
	await Engine.get_main_loop().physics_frame
	ok(not colisao.disabled, "trancada, ela bloqueia (pre-condicao)")

	porta.abrir()
	await Engine.get_main_loop().physics_frame
	ok(colisao.disabled,
		"aberta, a passagem libera no MESMO frame -- a animacao nao e pedagio")
	igual(porta.estado, porta.Estado.ABERTA, "e o estado ja e ABERTA desde o inicio dela")

	# O campo de forca -- o unico elemento que o jogador le num quadro so -- some
	# ao fim da encenacao, e nao antes: e a unica chance de mostrar a tranca
	# soltando.
	var campo := porta.get_node_or_null("Campo") as Sprite2D
	ok(campo != null, "a porta tem campo de forca")
	if campo != null:
		ok(campo.visible, "e ele ainda esta em tela enquanto a porta abre")

	raiz.free()


## ABERTA deixa passar, TRANCADA bloqueia, SELADA nao poe nada.
##
## O caso do meio e o unico que o jogo ja exercitava; os outros dois sao os que
## erram calados. ABERTA com barreira prenderia o jogador na sala limpa --
## visivel na hora. SELADA com barreira e invisivel para sempre.
func _cada_estado_e_seu_solido() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)
	var porta := _porta_solta(raiz)

	porta.trancar()
	await Engine.get_main_loop().process_frame
	ok(not _barreira_de(porta).disabled, "TRANCADA poe barreira: e o lockdown do GDD")

	porta.abrir()
	await Engine.get_main_loop().process_frame
	ok(_barreira_de(porta).disabled, "ABERTA tira a barreira: da para atravessar")

	porta.trancar()
	await Engine.get_main_loop().process_frame
	porta.selar()
	await Engine.get_main_loop().process_frame
	ok(
		_barreira_de(porta).disabled,
		"SELADA NAO poe barreira -- quem fecha aquele lado e a parede da sala"
	)
	ok(porta.esta_selada(), "e selar e permanente")

	# Selar depois de trancar e o caminho real: a sala tranca tudo no _ready e
	# so depois descobre quem nao tem vizinho. Se `selar()` nao desfizesse a
	# barreira do `trancar()`, o defeito voltaria por esse lado.
	porta.abrir()
	await Engine.get_main_loop().process_frame
	ok(porta.esta_selada(), "porta selada nao reabre")
	ok(_barreira_de(porta).disabled, "e continua sem barreira depois de tentar abrir")

	raiz.free()


## O caso de verdade: uma sala montada com UMA conexao so.
##
## Aqui nao se testa a porta, e a SALA -- que sela sozinha os lados sem vizinho
## no `_ready`, antes de gerar a parede. O que se cobra e o resultado combinado:
## o lado conectado tem barreira (esta trancado), e os outros tres nao tem
## solido nenhum alem da parede.
func _sala_sem_vizinho_nao_deixa_solido_sobrando() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)

	var sala := CENA_SALA.instantiate() as Sala
	# ANTES do add_child: e o `_ready` que sela e monta a parede, e ele precisa
	# ja saber quem sao os vizinhos.
	sala.configurar_conexoes([Vector2.DOWN])
	raiz.add_child(sala)
	sala.global_position = LONGE
	await Engine.get_main_loop().process_frame

	var portas := sala.get_node_or_null("Portas")
	ok(portas != null, "a sala tem o no Portas")
	if portas == null:
		raiz.free()
		return

	var conferidas := 0
	var seladas := 0
	for filho in portas.get_children():
		var porta := filho as Porta
		if porta == null:
			continue
		conferidas += 1
		var barreira := _barreira_de(porta)
		if barreira == null:
			continue
		if porta.vetor() == Vector2.DOWN:
			ok(not barreira.disabled, "o lado COM vizinho fica trancado ate a sala limpar")
		else:
			seladas += 1
			ok(
				barreira.disabled,
				"o lado sem vizinho (%s) nao deixa solido dentro da sala" % porta.vetor()
			)

	ok(conferidas >= 2, "a varredura achou as portas da sala (%d)" % conferidas)
	ok(seladas >= 1, "e ao menos um lado ficou sem vizinho neste cenario (%d)" % seladas)

	raiz.free()


# ------------------------------------------------------------- helpers ------

func _porta_solta(raiz: Node) -> Porta:
	# A porta espera morar em Sala/Portas/Porta -- ela sobe dois niveis para
	# achar a dona. Sem os dois nos, o _ready dela solta push_error e a suite
	# passaria com o console sujo.
	var sala := CENA_SALA.instantiate() as Sala
	sala.configurar_conexoes([])
	raiz.add_child(sala)
	sala.global_position = LONGE
	var portas := sala.get_node("Portas")
	var porta := CENA_PORTA.instantiate() as Porta
	portas.add_child(porta)
	return porta


func _barreira_de(porta: Porta) -> CollisionShape2D:
	return porta.get_node_or_null(CAMINHO_BARREIRA) as CollisionShape2D
