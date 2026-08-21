extends Node
## Ferramenta de captura: roda o jogo pelo caminho normal (so acelerado) e
## salva screenshots em momentos-chave. Serve para revisar o visual sem abrir
## o editor e para gerar as imagens da documentacao.
##
## Uso: godot --path . tools/capturar.tscn --resolution 1280x720
## As imagens saem em user://capturas.

const SAIDA := "user://capturas"

var _t: float = 0.0
var _feitas: Array[String] = []
var _t_chefe: float = -1.0
var _capturando := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(SAIDA)
	EventBus.boss_revelado.connect(func(_n: String, _v: int) -> void: _t_chefe = _t)
	add_child(preload("res://src/main/main.tscn").instantiate())


func _process(delta: float) -> void:
	_t += delta

	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player) and "vida" in player:
		player.vida = player.vida_maxima

	_acelerar()

	if _t > 1.6:
		_capturar("01_onda1_estavel")
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
		if _t > _t_chefe + 5.0:
			_capturar("05_chefe_bullet_hell")
		if _t > _t_chefe + 9.0:
			_capturar("06_chefe_fase_final")
		if _t > _t_chefe + 12.0:
			get_tree().quit(0)
	if _t > 90.0:
		push_error("captura: tempo limite")
		get_tree().quit(1)


## Limpa a arena depressa para as ondas passarem, mas so arranha o chefe --
## queremos ve-lo atacando, nao morrendo.
func _acelerar() -> void:
	for n in get_tree().get_nodes_in_group("inimigo"):
		if not is_instance_valid(n) or not n.has_method("receber_dano"):
			continue
		if n.get("nome_exibicao") != null:
			n.receber_dano(1, Vector2.ZERO)
		else:
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
