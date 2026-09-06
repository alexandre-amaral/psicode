extends Node2D
## A FICHA QUADRO A QUADRO dos cinco ataques criticos (PROJETIL 37).
##
## Ela registra, para cada um: **preparacao, lock, spawn, viagem, impacto e
## fim** -- em segundos, medidos no relogio da FISICA, e nao contados em quadros.
##
## **Nao conte quadros.** Sem janela o Godot nao tem vsync e roda centenas de
## quadros por segundo; um laco de 30 `process_frame` cobre 0,05 s de um ataque
## de meio segundo e para dentro do telegrafo, antes de qualquer coisa acontecer.
## Todo laco daqui espera a CONDICAO, com um teto grande so como rede -- e a
## mesma licao que `teste_porta.gd` ja pagou.
##
## Os cinco nao sao escolhidos por gosto:
##
##   Atirador Neon    o lock nao tem expressao visual nenhuma
##   Hacker Parasita  quatro estados encadeados, e uma brasa que fica no chao
##   Laser Cutter     o unico dano continuo do jogo
##   Boomer           o unico projetil que CRAVA e espera pavio antes de estourar
##   Automato         tres dos cinco ataques nao avisavam ate a PROJETIL 31
##
## Com janela ela tambem fotografa cada virada em `user://capturas/quadro_*`.
## Sem janela ela so mede -- e e assim que o CI a roda.

const LONGE := Vector2(9000.0, 9000.0)
const TETO := 12.0

## Quanto tempo sem NENHUMA mudanca conta como "acabou".
##
## E ele so comeca a contar depois do SPAWN, e nunca com o telegrafo aceso. Sem
## essas duas condicoes ele encerrava a observacao DENTRO do aviso: o Neon avisa
## por mais de 0,6 s, e o relatorio saia com "preparacao" e mais nada -- a
## ferramenta declarando fim de ataque antes de o ataque comecar.
const SILENCIO := 1.2

var _capturar := false


func _ready() -> void:
	_capturar = DisplayServer.get_name() != "headless"
	if _capturar:
		DirAccess.make_dir_recursive_absolute("user://capturas")

	print("\n=== QUADRO A QUADRO: os cinco ataques criticos ===\n")
	var falhas: Array[String] = []
	for nome in ["atirador_neon", "hacker_parasita", "laser_cutter", "boomer", "boss"]:
		var erro := await _medir(nome)
		if not erro.is_empty():
			falhas.append(erro)

	print("\n--- resultado ---")
	if falhas.is_empty():
		print("  PASSOU: os cinco ataques tem as fases em ordem e com duracao\n")
		get_tree().quit(0)
		return
	print("  FALHOU:")
	for f in falhas:
		print("    - " + f)
	print("")
	get_tree().quit(1)


## Um ataque: monta, observa ate silenciar, imprime a ficha e devolve o erro.
func _medir(nome: String) -> String:
	var cena := Node2D.new()
	add_child(cena)
	var container := Node2D.new()
	container.add_to_group("container_projeteis")
	cena.add_child(container)

	var alvo := _alvo(cena)
	var ator := _montar(nome, cena, container, alvo)
	if ator == null:
		cena.queue_free()
		return "%s: nao montou" % nome

	# As fases, na ordem em que a issue as pede. `-1` = ainda nao aconteceu.
	var fases := {
		"preparacao": -1.0, "lock": -1.0, "spawn": -1.0,
		"viagem": -1.0, "impacto": -1.0, "fim": -1.0,
	}
	var t := 0.0
	var ultimo_evento := 0.0
	var pico := 0
	var vivos_antes := 0
	var avisou := false

	while t < TETO:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var vivos := _vivos(container) + (1 if _feixe_ligado(ator) else 0)
		var aceso := _telegrafo_aceso(ator)
		# O gatilho tem de continuar puxado: uma arma so dispara no `_process` de
		# quem a segura, e aqui nao ha Player fazendo isso. O feixe precisa disso
		# TODO frame -- ele nao e um disparo, e um estado.
		if ator is Arma:
			_puxar_gatilho(ator as Arma, alvo)

		if aceso and fases["preparacao"] < 0.0:
			fases["preparacao"] = t
			avisou = true
			ultimo_evento = t
			_foto(nome, "1_preparacao")
		if avisou and not aceso and fases["lock"] < 0.0:
			fases["lock"] = t
			ultimo_evento = t
			_foto(nome, "2_lock")
		if vivos > 0 and fases["spawn"] < 0.0:
			fases["spawn"] = t
			ultimo_evento = t
			_foto(nome, "3_spawn")
		if vivos > vivos_antes:
			ultimo_evento = t
		if fases["spawn"] >= 0.0 and fases["viagem"] < 0.0 and t > fases["spawn"] + 0.05:
			fases["viagem"] = t
			_foto(nome, "4_viagem")
		if vivos < vivos_antes and fases["impacto"] < 0.0:
			fases["impacto"] = t
			ultimo_evento = t
			_foto(nome, "5_impacto")
		pico = maxi(pico, vivos)
		vivos_antes = vivos

		if (fases["spawn"] >= 0.0 and not aceso
				and t - ultimo_evento > SILENCIO and ultimo_evento > 0.0):
			fases["fim"] = t
			_foto(nome, "6_fim")
			break

	_relatar(nome, fases, pico)
	var erro := _conferir(nome, fases, pico)
	cena.queue_free()
	await get_tree().process_frame
	return erro


## As invariantes da ficha, e elas valem para os cinco.
##
## O que se cobra nao e um numero e sim a ORDEM: um ataque cujo projetil nasce
## antes do aviso acabar e um ataque que mente sobre o proprio telegrafo, e isso
## nao aparece em teste de dano nenhum.
func _conferir(nome: String, fases: Dictionary, pico: int) -> String:
	if pico <= 0:
		return "%s: nada nasceu em %.0f s" % [nome, TETO]
	if fases["spawn"] < 0.0:
		return "%s: nunca houve spawn" % nome
	var prep: float = fases["preparacao"]
	var spawn: float = fases["spawn"]
	if prep >= 0.0 and spawn >= 0.0 and spawn < prep:
		return "%s: o projetil nasceu ANTES do aviso comecar" % nome
	var lock: float = fases["lock"]
	if lock >= 0.0 and spawn >= 0.0 and spawn + 0.001 < lock:
		return "%s: o projetil nasceu antes de o aviso APAGAR (%.3f contra %.3f)" % [
			nome, spawn, lock]
	return ""


func _relatar(nome: String, fases: Dictionary, pico: int) -> void:
	print("  %s" % nome)
	var ordem := ["preparacao", "lock", "spawn", "viagem", "impacto", "fim"]
	var anterior := -1.0
	for fase: String in ordem:
		var quando: float = fases[fase]
		if quando < 0.0:
			print("    %-12s --" % fase)
			continue
		var passo := "" if anterior < 0.0 else "  (+%.3f s)" % (quando - anterior)
		print("    %-12s %6.3f s%s" % [fase, quando, passo])
		anterior = quando
	print("    pico de %d projeteis vivos" % pico)


# -- montagem -----------------------------------------------------------------

func _alvo(cena: Node2D) -> Node2D:
	var p: Node2D = (load("res://src/player/player.tscn") as PackedScene).instantiate()
	cena.add_child(p)
	p.global_position = LONGE + Vector2(200.0, 0.0)
	# Parado: quero medir o ATAQUE. Com o jogador andando a distancia muda no
	# meio da medicao e as fases passam a falar da perseguicao.
	p.set_physics_process(false)
	return p


func _montar(nome: String, cena: Node2D, container: Node2D, alvo: Node2D) -> Node:
	match nome:
		"atirador_neon", "hacker_parasita":
			var inimigo: Node2D = (load("res://src/enemies/%s.tscn" % nome) as PackedScene).instantiate()
			container.add_child(inimigo)
			inimigo.global_position = LONGE
			return inimigo
		"boss":
			var chefe: Node2D = (load("res://src/enemies/boss_guardiao_01.tscn") as PackedScene).instantiate()
			container.add_child(chefe)
			chefe.global_position = LONGE
			return chefe
		"laser_cutter", "boomer":
			var arma := Arma.new()
			arma.dados = load("res://src/weapons/%s.tres" % nome)
			arma.hostil = false
			cena.add_child(arma)
			arma.global_position = LONGE
			_puxar_gatilho(arma, alvo)
			return arma
	return null


## Segura o gatilho por alguns frames: uma arma so dispara no `_process` de quem
## a segura, e aqui nao ha Player fazendo isso.
func _puxar_gatilho(arma: Arma, alvo: Node2D) -> void:
	var direcao := (alvo.global_position - arma.global_position).normalized()
	arma.atualizar_gatilho(false)
	arma.atirar(direcao)


# -- observacao ---------------------------------------------------------------

## O feixe nao e um projetil: ele nao entra no container e nao tem raio.
##
## Sem esta pergunta o Laser Cutter media ZERO em tudo -- a unica arma de dano
## continuo do jogo saindo da ficha por nao caber na contagem das outras.
func _feixe_ligado(ator: Node) -> bool:
	var arma := ator as Arma
	if arma == null:
		return false
	return arma._feixe != null and is_instance_valid(arma._feixe)


func _vivos(container: Node2D) -> int:
	var n := 0
	for filho in container.get_children():
		if filho.get("raio") != null:
			n += 1
	return n


## O telegrafo daquele ator esta aceso?
##
## Por PROPRIEDADE e nao por cast: `Telegrafo` e um no filho e cada inimigo o
## guarda com um nome proprio. Varrer os filhos e mais barato que conhecer cinco
## APIs diferentes, e continua valendo no dia em que um sexto ator entrar.
func _telegrafo_aceso(ator: Node) -> bool:
	for filho in ator.get_children():
		var t := filho as Telegrafo
		if t != null and t.visible:
			return true
	return false


func _foto(nome: String, fase: String) -> void:
	if not _capturar:
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		"user://capturas/quadro_%s_%s.png" % [nome, fase])
