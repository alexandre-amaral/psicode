extends InimigoBase
## A IA DIRETORA -- o climax da build.
##
## Ela e a personificacao do sistema que vinha lendo o jogador o tempo todo.
## Conceitualmente: ate agora a Deterioracao mexia nos inimigos; agora ela
## tem corpo. Mecanicamente o MVP fica no que o GDD pediu -- mira preditiva e
## invocacao -- mais salvas radiais que forcam o jogador a usar o rolamento
## para atravessar, e nao so para fugir.
##
## Cada ataque tem telegrafo. Um chefe de bullet hell so e justo se o jogador
## consegue ler a intencao antes do projetil existir.

signal fase_mudou(fase: int)

const CENA_RASTEJANTE := preload("res://src/enemies/rastejante.tscn")
const CENA_VIGIA := preload("res://src/enemies/vigia.tscn")

@export_group("Chefe")
@export var nome_exibicao: String = "A IA DIRETORA"
@export var raio_orbita: float = 90.0
@export var velocidade_orbita: float = 0.35
@export var max_invocados: int = 8

enum Acao { SURGINDO, OCIOSA, TELEGRAFO, EXECUTANDO }

var fase_chefe: int = 1
var _acao: int = Acao.SURGINDO
var _t_acao: float = 0.0
var _ataque_atual: String = ""
var _fila: Array[String] = []
var _centro: Vector2 = Vector2.ZERO
var _angulo_orbita: float = 0.0
var _invocados: Array[Node] = []
var _ponto_previsto: Vector2 = Vector2.ZERO
var _giro_espiral: float = 0.0

var _arma_preditiva: Arma
var _arma_salva: Arma
var _anel: Polygon2D
var _nucleo: Polygon2D
var _laser: Line2D
var _aviso: Polygon2D


func _ready() -> void:
	super._ready()
	_centro = global_position
	_arma_preditiva = $Visual/ArmaPreditiva
	_arma_salva = $ArmaSalva
	_arma_preditiva.hostil = true
	_arma_salva.hostil = true
	_anel = $Visual/Anel
	_nucleo = $Visual/Nucleo
	_aviso = $Aviso
	_laser = $Laser
	_laser.top_level = true
	_laser.visible = false
	_aviso.visible = false

	_acao = Acao.SURGINDO
	_t_acao = 1.6
	EventBus.boss_revelado.emit(nome_exibicao, vida_maxima)
	EventBus.boss_vida_mudou.emit(vida, vida_maxima)
	EventBus.pedido_shake.emit(16.0, 1.2)


func _comportamento(delta: float) -> void:
	_orbitar(delta)
	_girar_anel(delta)
	_limpar_invocados()

	match _acao:
		Acao.SURGINDO:
			_t_acao -= delta
			if _t_acao <= 0.0:
				_acao = Acao.OCIOSA
				_t_acao = 0.6
		Acao.OCIOSA:
			_t_acao -= delta
			if _t_acao <= 0.0:
				_escolher_ataque()
		Acao.TELEGRAFO:
			_t_acao -= delta
			_atualizar_telegrafo()
			if _t_acao <= 0.0:
				_executar_ataque()
		Acao.EXECUTANDO:
			_t_acao -= delta
			_manter_ataque(delta)
			if _t_acao <= 0.0:
				_terminar_ataque()

	tentar_dano_contato()


# ------------------------------------------------------------ movimento ---

func _orbitar(delta: float) -> void:
	# Ela nao persegue. Circula devagar no centro, como um sistema rodando.
	_angulo_orbita += velocidade_orbita * delta * Deterioracao.multiplicador_velocidade()
	var destino := _centro + Vector2.RIGHT.rotated(_angulo_orbita) * raio_orbita
	velocity = (destino - global_position) * 2.4


func _girar_anel(delta: float) -> void:
	if _anel != null:
		_anel.rotation += delta * (0.9 + fase_chefe * 0.55)
	if _nucleo != null:
		var pulso := 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.08
		_nucleo.scale = Vector2(pulso, pulso)


# -------------------------------------------------------------- ataques ---

func _escolher_ataque() -> void:
	if _fila.is_empty():
		_fila = _repertorio_da_fase()
		_fila.shuffle()
	_ataque_atual = _fila.pop_front()

	_acao = Acao.TELEGRAFO
	_t_acao = _duracao_telegrafo(_ataque_atual)
	_iniciar_telegrafo()


func _repertorio_da_fase() -> Array[String]:
	match fase_chefe:
		1:
			return ["preditivo", "preditivo", "invocar"]
		2:
			return ["preditivo", "anel", "invocar", "preditivo"]
		_:
			return ["preditivo", "anel", "espiral", "invocar", "espiral"]


func _duracao_telegrafo(ataque: String) -> float:
	var base := 0.7
	match ataque:
		"preditivo": base = 0.62
		"anel": base = 0.8
		"espiral": base = 0.7
		"invocar": base = 0.55
	# Fases avancadas telegrafam mais rapido, mas nunca abaixo de 0.35s.
	return maxf(base - (fase_chefe - 1) * 0.1, 0.35)


func _iniciar_telegrafo() -> void:
	match _ataque_atual:
		"preditivo":
			_laser.visible = true
		"anel", "espiral":
			_aviso.visible = true
			_aviso.scale = Vector2(0.2, 0.2)
			_aviso.modulate = Color(0.75, 0.4, 1.0, 0.0)
			var t := create_tween()
			t.set_parallel(true)
			t.tween_property(_aviso, "scale", Vector2(1.0, 1.0), _t_acao)
			t.tween_property(_aviso, "modulate:a", 0.5, _t_acao * 0.7)
		"invocar":
			var t2 := create_tween()
			t2.tween_property(_visual, "modulate", Color(2.2, 1.4, 2.6, 1.0), _t_acao * 0.6)
			t2.tween_property(_visual, "modulate", Color.WHITE, _t_acao * 0.4)


func _atualizar_telegrafo() -> void:
	if _ataque_atual != "preditivo" or alvo == null or not is_instance_valid(alvo):
		return
	# A Diretora sempre preve, independente da barra: ela E a Deterioracao.
	_ponto_previsto = Balistica.ponto_de_intercepto(
		_arma_preditiva.global_position,
		alvo.global_position,
		velocidade_do_alvo(),
		_arma_preditiva.dados.velocidade_projetil
	)
	_visual.rotation = lerp_angle(
		_visual.rotation,
		(_ponto_previsto - global_position).angle(),
		0.3
	)
	_laser.clear_points()
	_laser.add_point(_arma_preditiva.global_position)
	_laser.add_point(_ponto_previsto)
	_laser.default_color = Color(1.0, 0.2, 0.5, 0.7)
	_laser.width = 3.0


func _executar_ataque() -> void:
	_acao = Acao.EXECUTANDO
	_laser.visible = false
	_aviso.visible = false

	match _ataque_atual:
		"preditivo":
			_atacar_preditivo()
			_t_acao = 0.35
		"anel":
			_atacar_anel()
			_t_acao = 0.5
		"espiral":
			_giro_espiral = randf() * TAU
			_t_acao = 1.4 + fase_chefe * 0.35
		"invocar":
			_atacar_invocar()
			_t_acao = 0.7


func _manter_ataque(delta: float) -> void:
	if _ataque_atual != "espiral":
		return
	_giro_espiral += delta * 5.2
	# Dois bracos opostos: da para ficar entre eles, mas so andando.
	for i in 2:
		var dir := Vector2.RIGHT.rotated(_giro_espiral + PI * i)
		_arma_salva.atirar(dir)


func _terminar_ataque() -> void:
	_acao = Acao.OCIOSA
	# Respiro entre ataques. Encurta conforme a fase avanca.
	_t_acao = maxf(1.15 - (fase_chefe - 1) * 0.3, 0.45)


func _atacar_preditivo() -> void:
	var direcao := (_ponto_previsto - _arma_preditiva.global_position).normalized()
	if direcao == Vector2.ZERO:
		direcao = direcao_para_alvo()
	_arma_preditiva.atirar(direcao)
	EventBus.pedido_shake.emit(4.0, 0.15)


func _atacar_anel() -> void:
	var quantidade := 14 + fase_chefe * 6
	var offset := randf() * TAU
	for d in Balistica.anel(quantidade, offset):
		_arma_salva.atirar(d)
	EventBus.pedido_shake.emit(8.0, 0.3)


func _atacar_invocar() -> void:
	if _invocados.size() >= max_invocados:
		return
	var quantidade := 2 if fase_chefe == 1 else 3
	var container := get_parent()
	for i in quantidade:
		if _invocados.size() >= max_invocados:
			break
		var cena := CENA_RASTEJANTE
		# Da fase 2 em diante ela tambem chama quem atira -- forca o jogador
		# a resolver o campo, nao so a esquivar do chefe.
		if fase_chefe >= 2 and i == quantidade - 1:
			cena = CENA_VIGIA
		var inimigo := cena.instantiate()
		var angulo := randf() * TAU
		inimigo.global_position = global_position + Vector2.RIGHT.rotated(angulo) * randf_range(110.0, 190.0)
		container.add_child(inimigo)
		_invocados.append(inimigo)
	EventBus.pedido_shake.emit(6.0, 0.25)


func _limpar_invocados() -> void:
	var vivos: Array[Node] = []
	for n in _invocados:
		if is_instance_valid(n):
			vivos.append(n)
	_invocados = vivos


# ------------------------------------------------------------------ vida ---

func receber_dano(quantidade: int, impulso: Vector2 = Vector2.ZERO) -> bool:
	if morto:
		return false
	# O chefe nao e empurrado -- so o dano importa.
	var antes := vida
	vida -= quantidade
	_flash()
	EventBus.boss_vida_mudou.emit(maxi(vida, 0), vida_maxima)
	if antes > 0:
		_checar_fase()
	if vida <= 0:
		morrer()
	return true


func _checar_fase() -> void:
	var razao := float(vida) / float(vida_maxima)
	var nova := 1
	if razao <= 0.33:
		nova = 3
	elif razao <= 0.66:
		nova = 2
	if nova == fase_chefe:
		return
	fase_chefe = nova
	_fila.clear()
	fase_mudou.emit(fase_chefe)
	EventBus.boss_fase_mudou.emit(fase_chefe)
	EventBus.pedido_shake.emit(14.0, 0.6)
	Deterioracao.adicionar(5.0)
	# Pequena janela de alivio na virada de fase, senao a transicao vira
	# dano gratuito em cima de quem estava no meio de uma esquiva.
	_acao = Acao.OCIOSA
	_t_acao = 0.9
	_laser.visible = false
	_aviso.visible = false


func morrer() -> void:
	if morto:
		return
	_laser.visible = false
	_aviso.visible = false
	EventBus.boss_morreu.emit()
	EventBus.pedido_shake.emit(26.0, 1.4)
	super.morrer()
