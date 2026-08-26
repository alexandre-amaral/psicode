extends Node
## Ferramenta de captura: roda o jogo pelo caminho normal (so acelerado) e
## salva screenshots em momentos-chave. Serve para revisar o visual sem abrir
## o editor e para gerar as imagens da documentacao.
##
## Uso: godot --path . tools/capturar.tscn --resolution 960x544
## As imagens saem em user://capturas.
##
## Ele ANDA pelo andar, como o teste de fumaca faz: pede sala por sala ao
## GerenciadorMapa pela API publica (`celulas`, `celula_do_chefe`,
## `ir_para_sala`). Sem isso ele ficava parado na primeira sala, e desde que o
## jogo virou um andar de salas as capturas 04..06 -- o chefe -- nunca saiam.

const SAIDA := "user://capturas"

var _t: float = 0.0
var _feitas: Array[String] = []
var _t_chefe: float = -1.0
## Desgaste do chefe: 20 de dano por segundo derruba 300 de vida em 15 s, que e
## o que cabe entre as fotos 04 e o fim.
const INTERVALO_DESGASTE := 0.05
const DESGASTE_DO_CHEFE := 1
var _t_desgaste: float = 0.0
var _capturando := false

var _mapa: GerenciadorMapa = null
var _visitadas: Dictionary = {}
## Respiro entre uma sala e a seguinte, para a chegada assentar e a captura nao
## pegar a camera no meio do deslize.
var _t_avanco: float = 0.0
## Quantas salas de combate ja foram vistas. Depois de algumas, a foto de
## combate sai em qualquer uma, mesmo mal enquadrada -- melhor uma imagem torta
## que imagem nenhuma.
var _combates_vistos: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(SAIDA)
	# A sala inicial nasce LIMPA, entao o percurso sairia dela no primeiro
	# frame. Este respiro e o que da tempo de fotografa-la.
	_t_avanco = 1.2
	EventBus.boss_revelado.connect(func(_n: String, _v: int) -> void: _t_chefe = _t)
	add_child(preload("res://src/main/main.tscn").instantiate())


func _process(delta: float) -> void:
	_t += delta
	_t_avanco -= delta

	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player) and "vida" in player:
		player.vida = player.vida_maxima

	# A sala de combate e fotografada ANTES de o acelerador limpar a sala: a
	# captura que importa aqui e "o jogador entrou e os inimigos ja estao
	# distribuidos", e ela dura o intervalo de um frame.
	_capturar_sala_atual()
	_acelerar(delta)
	_avancar_se_der()

	if _t > 4.2:
		if not "02_deterioracao_media" in _feitas:
			Deterioracao.valor = maxf(Deterioracao.valor, 58.0)
		_capturar("02_deterioracao_media")
	if _t > 7.0:
		if not "03_deterioracao_critica" in _feitas:
			Deterioracao.valor = maxf(Deterioracao.valor, 90.0)
		_capturar("03_deterioracao_critica")
	if _t_chefe > 0.0:
		if _t > _t_chefe + 1.6:
			_capturar("04_chefe_revelado")
		if _t > _t_chefe + 6.0:
			_capturar("05_chefe_bullet_hell")
		# A fase ABSOLUTA comeca nos ultimos 15% da vida. Com o desgaste abaixo,
		# isso cai por volta dos 13 s -- e e ela que a foto 06 precisa mostrar,
		# porque e a unica em que a arena, e nao o corpo, e o inimigo.
		if _t > _t_chefe + 13.5:
			_capturar("06_chefe_fase_final")
		if _t > _t_chefe + 17.0:
			get_tree().quit(0)
	if _t > 90.0:
		push_error("captura: tempo limite")
		get_tree().quit(1)


## Nome fixo por TIPO de sala, e nao por ordem de visita: assim rodar de novo
## produz o mesmo conjunto de arquivos mesmo com outro andar sorteado.
func _capturar_sala_atual() -> void:
	if not _achar_mapa():
		return
	var sala := _mapa.sala_atual
	if sala == null or sala.tipo == DadosSala.ID_BOSS:
		return
	match String(sala.tipo):
		"inicial":
			_capturar("01_sala_inicial")
		"combate":
			_capturar_combate(sala)
		"arma":
			_capturar("08_sala_de_arma")
		"item":
			_capturar("09_sala_de_item")


## A foto de combate so vale se der para VER os inimigos, e a camera nunca
## afasta: numa sala maior que a tela ela segue o jogador e mostra um pedaco.
## Entao a primeira escolha e uma sala que caiba no viewport -- a retangular de
## 960x544 e a mais comum do andar. Depois de algumas tentativas, qualquer uma
## serve.
func _capturar_combate(sala: Sala) -> void:
	if "07_sala_de_combate" in _feitas:
		return

	# Sem inimigo vivo NA SALA nao ha o que fotografar: uma foto de "sala de
	# combate" com HOSTIS 0 nao mostra nada do que a captura existe para
	# mostrar. Isto tambem cobre o caso de o acelerador ter chegado antes.
	var vivos := 0
	for no in get_tree().get_nodes_in_group("inimigo"):
		var inimigo := no as Node2D
		if inimigo != null and is_instance_valid(inimigo) and sala.obter_limites().has_point(inimigo.global_position):
			vivos += 1
	if vivos == 0:
		return

	_combates_vistos += 1
	# A camera nunca AFASTA: numa sala maior que a tela ela segue o jogador e
	# mostra so um pedaco, e os inimigos podem estar todos fora do quadro. Por
	# isso a primeira escolha e uma sala que caiba inteira.
	var tela := Vector2(get_viewport().get_visible_rect().size)
	var caixa := sala.obter_limites().size
	var cabe := caixa.x <= tela.x and caixa.y <= tela.y
	if cabe or _combates_vistos >= 4:
		_capturar("07_sala_de_combate")


func _achar_mapa() -> bool:
	if _mapa != null and is_instance_valid(_mapa):
		return true
	_mapa = get_tree().get_first_node_in_group("gerenciador_mapa") as GerenciadorMapa
	return _mapa != null


## Sala limpa, segue em frente. A do chefe fica por ultimo: entrar nela termina
## a run, e as capturas 04..06 sao dela.
func _avancar_se_der() -> void:
	if _t_avanco > 0.0 or not _achar_mapa():
		return
	var sala := _mapa.sala_atual
	if sala == null or sala.estado != Sala.Estado.LIMPA:
		return
	_visitadas[sala.coordenadas_grid] = true

	var alvo := _proxima_celula()
	if alvo == sala.coordenadas_grid:
		return
	_t_avanco = 0.5
	_mapa.ir_para_sala(alvo)


## Qualquer celula ainda nao visitada; a do chefe so quando nao sobrar outra.
## Nao precisa de caminho minimo como o teste de fumaca: `ir_para_sala` salta, e
## aqui o que se quer sao as fotos, nao a travessia.
func _proxima_celula() -> Vector2i:
	var atual := _mapa.sala_atual.coordenadas_grid
	var chefe := _mapa.celula_do_chefe()
	for celula in _mapa.celulas():
		if celula != chefe and not _visitadas.has(celula):
			return celula
	if not _visitadas.has(chefe):
		return chefe
	return atual


## Limpa a sala depressa para o percurso andar, mas so arranha o chefe --
## queremos ve-lo atacando, nao morrendo.
##
## O desgaste do chefe e por RELOGIO e nao por frame. Por frame ele levava 60 de
## dano por segundo e caia em 5 s: as fotos 05 e 06, marcadas para 6 s e 13,5 s,
## fotografavam a tela de fim. As tres imagens do chefe sao o portao visual que
## o IDENTIDADE_VISUAL.md cita pelo nome, e elas estavam fotografando o chefe
## morto ha varias versoes.
func _acelerar(delta: float) -> void:
	# Nao mata nada enquanto ha foto pendente. `_capturar` e assincrono: ele
	# reserva o nome de imediato mas so grava depois do frame_post_draw, e sem
	# esta guarda o acelerador limpava a sala nesse intervalo -- a foto da sala
	# de combate saia com "HOSTIS 0" e nenhum inimigo em tela.
	if _capturando:
		return
	_t_desgaste -= delta
	var pode_desgastar := _t_desgaste <= 0.0
	if pode_desgastar:
		_t_desgaste = INTERVALO_DESGASTE

	for n in get_tree().get_nodes_in_group("inimigo"):
		if not is_instance_valid(n) or not n.has_method("receber_dano"):
			continue
		if n.get("nome_exibicao") != null:
			if pode_desgastar:
				n.receber_dano(DESGASTE_DO_CHEFE, Vector2.ZERO)
			continue
		# O que NAO anda e arquitetura da arena -- os nucleos da Sobrecarga e as
		# torres da fase Absoluta. Mata-los na hora apagaria da foto justamente
		# o que a fase 4 tem de novo. Nas salas comuns nada tem velocidade zero,
		# entao esta regra nao afeta o percurso.
		if n.get("velocidade_base") != null and float(n.velocidade_base) <= 0.0:
			continue
		n.receber_dano(999, Vector2.ZERO)


func _capturar(nome: String) -> void:
	if nome in _feitas or _capturando:
		return
	_capturando = true
	_feitas.append(nome)
	await RenderingServer.frame_post_draw
	var caminho := "%s/%s.png" % [SAIDA, nome]
	get_viewport().get_texture().get_image().save_png(caminho)
	print("capturado: ", ProjectSettings.globalize_path(caminho))
	_capturando = false
