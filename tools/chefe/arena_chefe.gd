extends Node
## A ARENA DE TESTE DO CHEFE (BOSS 02), com HP ajustavel.
##
## Puxada para o COMECO do plano de proposito: ela e o instrumento que torna
## todas as outras issues do chefe baratas de ajustar. As BOSS 03 a 08 vao pedir
## dezenas de idas e vindas, e sem ela cada ajuste custa jogar a run inteira ate
## a ultima sala do andar.
##
## O projeto ja tem os dois niveis -- `runner.tscn` em segundos, `teste_fumaca`
## em minutos -- e a diferenca entre eles e exatamente esse custo. Esta e a
## terceira regua, e cobre o buraco que as duas primeiras deixam: o fumaca mata
## tudo a cada 0,12 s, e um chefe com telegrafo de 0,8 s cai exatamente nessa
## faixa. Ja aconteceu com o Parasita -- ele apareceu em tres runs seguidas e
## ZERO areas de perigo foram criadas, e a guarda passou verde sem ter olhado
## nada.
##
## DOIS MODOS, e o modo sai do DisplayServer e nao de uma bandeira:
##
##   godot --path . tools/chefe/arena_chefe.tscn -- --hp=0.32
##     Com janela: entra na luta com o chefe em 32% de vida, ou seja, na fase 3
##     recem-comecada. Da para JOGAR, que e o ponto -- ajuste de chefe se sente,
##     nao se le.
##
##   godot --headless --path . tools/chefe/arena_chefe.tscn
##     Sem janela: percorre os quatro pontos de interesse, imprime o que mediu e
##     encerra. E o que serve de base para as suites das proximas issues.
##
## Ela NAO substitui a suite unitaria. `teste_boss_guardiao.gd` cobra a conta;
## isto aqui cobra que a conta virou jogo.

const CENA_SALA := preload("res://src/mapa/sala_1_retangular.tscn")
const CENA_CHEFE := preload("res://src/enemies/boss_guardiao_01.tscn")
const CENA_PLAYER := preload("res://src/player/player.tscn")

## Os pontos de interesse do plano: onde cada fase COMECA, mais o fim de luta.
##
## 65% e 32% e nao 67% e 34%: entrar exatamente no limiar deixaria a fase
## ambigua por arredondamento, e o que se quer observar e a fase ja comecada.
const PONTOS := [
	{"hp": 1.00, "diz": "fase 1 recem-comecada"},
	{"hp": 0.65, "diz": "logo depois da primeira transicao"},
	{"hp": 0.32, "diz": "logo depois da segunda"},
	{"hp": 0.05, "diz": "fim de luta"},
]

## Quanto tempo cada ponto roda no modo headless. Um ciclo inteiro do chefe na
## fase mais lenta -- escolha, preparo, execucao, recuperacao -- leva ~2,7 s.
const SEGUNDOS_POR_PONTO := 4.0

var _chefe: Node = null
var _sala: Node = null
var _player: Node = null


func _ready() -> void:
	# A barra parada: o que se mede aqui e o multiplicador de FASE, e a
	# Deterioracao passiva subindo por baixo embaralharia os dois.
	Deterioracao.passiva_ativa = false
	if DisplayServer.get_name() == "headless":
		await _medir_os_quatro_pontos()
	else:
		_montar(_hp_pedido())


## `--hp=0.32`, se veio. Fora disso, luta cheia.
##
## Le de `get_cmdline_user_args()` -- o que vem DEPOIS do `--` --, que e o unico
## lugar onde um argumento nosso nao briga com uma opcao do proprio Godot.
func _hp_pedido() -> float:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hp="):
			return clampf(arg.substr(5).to_float(), 0.01, 1.0)
	return 1.0


# ----------------------------------------------------------------- montagem --

func _montar(fracao: float) -> void:
	_sala = CENA_SALA.instantiate()
	add_child(_sala)

	_player = CENA_PLAYER.instantiate()
	add_child(_player)
	_player.global_position = Vector2(0.0, 180.0)

	_chefe = CENA_CHEFE.instantiate()
	_sala.get_node("ContainerInimigos").add_child(_chefe)
	_chefe.global_position = Vector2(0.0, -160.0)
	definir_hp(fracao)

	var camera := Camera2D.new()
	_player.add_child(camera)
	camera.make_current()


## Poe o chefe numa fracao de vida e deixa a fase COERENTE com ela.
##
## Escrever `vida` sozinho deixaria `fase_chefe` em 1 com o chefe em 32% -- os
## tempos sairiam da fase errada e a arena mediria um chefe que nao existe.
## Como as transicoes sao "uma vez por virada", a bandeira tambem tem de avancar,
## senao entrar em 32% dispararia as DUAS transicoes em sequencia.
func definir_hp(fracao: float) -> void:
	if _chefe == null:
		return
	_chefe.vida = maxi(int(round(float(_chefe.vida_maxima) * fracao)), 1)
	var fase: int = _chefe.fase_por_vida()
	_chefe.fase_chefe = fase
	_chefe._fase_anunciada = fase


# ----------------------------------------------------------------- medicao ---

func _medir_os_quatro_pontos() -> void:
	print("\n=== ARENA DO CHEFE: Automato Enferrujado ===\n")

	var falhas: Array[String] = []
	for ponto: Dictionary in PONTOS:
		var linha := await _medir(ponto)
		if not linha.is_empty():
			falhas.append(linha)

	print("\n--- resultado ---")
	if falhas.is_empty():
		print("  PASSOU: os quatro pontos entram na fase certa e respeitam o piso\n")
		get_tree().quit(0)
		return
	print("  FALHOU:")
	for f in falhas:
		print("    - " + f)
	print("")
	get_tree().quit(1)


## Roda um ponto e devolve a mensagem de falha, ou vazio se passou.
func _medir(ponto: Dictionary) -> String:
	_montar(ponto["hp"])
	await get_tree().physics_frame

	var fase: int = _chefe.fase_chefe
	var mult: float = _chefe.multiplicador()
	var preparo: float = _chefe.tempo_real(_chefe.tempo_preparo)
	var recuperacao: float = _chefe.tempo_real(_chefe.tempo_recuperacao)
	var velocidade: float = _chefe.velocidade_atual()

	# Quantos estados diferentes ele visita: um chefe travado num estado so e o
	# defeito que "ele parece parado" descreve, e ele nao da erro no console.
	var vistos := {}
	var decorrido := 0.0
	while decorrido < SEGUNDOS_POR_PONTO:
		await get_tree().physics_frame
		decorrido += get_physics_process_delta_time()
		vistos[String(_chefe._maquina.estado)] = true

	print("  %3.0f%% de vida -- %s" % [ponto["hp"] * 100.0, ponto["diz"]])
	print("    fase %d, multiplicador %.2f, %.0f px/s" % [fase, mult, velocidade])
	print("    telegrafo %.2f s, recuperacao %.2f s (piso %.2f)" % [
		preparo, recuperacao, _chefe.TEMPO_MINIMO,
	])
	print("    estados visitados em %.0f s: %s" % [SEGUNDOS_POR_PONTO, ", ".join(vistos.keys())])

	var erro := ""
	var esperada: int = _chefe.fase_por_vida()
	if fase != esperada:
		erro = "com %.0f%% de vida ele entrou na fase %d, e a vida pede a %d" % [
			ponto["hp"] * 100.0, fase, esperada,
		]
	elif preparo < _chefe.TEMPO_MINIMO - 0.0001 or recuperacao < _chefe.TEMPO_MINIMO - 0.0001:
		erro = "com %.0f%% de vida um tempo furou o piso (%.2f / %.2f contra %.2f)" % [
			ponto["hp"] * 100.0, preparo, recuperacao, _chefe.TEMPO_MINIMO,
		]
	elif vistos.size() < 2:
		erro = "com %.0f%% de vida ele ficou parado num estado so (%s)" % [
			ponto["hp"] * 100.0, ", ".join(vistos.keys()),
		]

	_limpar()
	await get_tree().process_frame
	return erro


func _limpar() -> void:
	for no in [_sala, _player]:
		if no != null and is_instance_valid(no):
			no.queue_free()
	_sala = null
	_player = null
	_chefe = null
