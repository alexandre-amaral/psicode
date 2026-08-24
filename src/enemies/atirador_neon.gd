extends InimigoBase
## ATIRADOR NEON -- mantem distancia longa, marca a trajetoria e dispara rapido.
##
## Ele e o contraponto deliberado do Vigia. O Vigia, acima de 50% de
## Deterioracao, mira onde voce VAI estar: sair da linha nao resolve, e a licao
## dele e "role depois do disparo". O Neon TRAVA a linha ao comecar a mirar e
## nunca mais a corrige -- sair da linha sempre funciona, e a licao dele e "leia
## a linha e ande".
##
## Duas licoes opostas no mesmo campo e o que faz o jogador ter de identificar
## COM QUEM esta lidando antes de escolher a esquiva. Por isso as silhuetas
## precisam continuar diferentes, e por isso a cor da linha e outra.

@export_group("Posicionamento")
## Mais longe que o Vigia (180): ele e o que pune quem fica parado no aberto.
@export var distancia_ideal: float = 300.0
@export var margem: float = 50.0

@export_group("Disparo")
@export var intervalo: float = 2.6
## Linha acesa antes do tiro. Mais longa que a do Vigia -- em troca, o projetil
## e muito mais rapido e nao da para reagir depois que ele sai.
@export var tempo_mira: float = 1.0
@export var tempo_cooldown: float = 0.6

const PROCURAR_POSICAO := &"PROCURAR_POSICAO"
const MIRAR := &"MIRAR"
const DISPARAR := &"DISPARAR"
const COOLDOWN := &"COOLDOWN"

var _maquina: MaquinaEstados
var _arma: Arma
var _linha: Line2D
## Travada em `_mirar_entrar`. Nao e recalculada durante a mira.
var _direcao_travada: Vector2 = Vector2.RIGHT
var _t_intervalo: float = 0.0
var _lado: float = 1.0


func _ready() -> void:
	super._ready()
	_arma = $Visual/Arma
	_arma.hostil = true
	_linha = $Linha
	_linha.top_level = true
	_linha.visible = false
	_t_intervalo = randf_range(0.5, intervalo)
	_lado = 1.0 if randf() < 0.5 else -1.0

	_maquina = MaquinaEstados.new(name)
	_maquina.adicionar(PROCURAR_POSICAO, _procurar)
	_maquina.adicionar(MIRAR, _mirar, _mirar_entrar, _mirar_sair)
	_maquina.adicionar(DISPARAR, _disparar, _disparar_entrar)
	_maquina.adicionar(COOLDOWN, _cooldown)
	_maquina.iniciar(PROCURAR_POSICAO)


func _comportamento(delta: float) -> void:
	_arma.multiplicador_velocidade = Deterioracao.multiplicador_velocidade_projetil()
	_maquina.processar(delta)
	_orientar(delta)


# ------------------------------------------------------------- estados ------

func _procurar(delta: float) -> void:
	_t_intervalo -= delta * Deterioracao.multiplicador_cadencia()
	_mover(delta, 1.0)
	if _t_intervalo <= 0.0:
		_maquina.trocar(MIRAR)


## A TRAVA. Daqui ate o tiro a linha nao muda -- e o contrato do inimigo.
func _mirar_entrar() -> void:
	_direcao_travada = direcao_para_alvo()
	if _direcao_travada.length_squared() < 0.01:
		_direcao_travada = Vector2.RIGHT
	_linha.visible = true


func _mirar(delta: float) -> void:
	# Quase parado enquanto mira: um atirador que corre atirando fica ilegivel,
	# e a linha travada perde sentido se a ORIGEM dela anda.
	_mover(delta, 0.15)
	_desenhar_linha()
	if _maquina.passou(tempo_mira):
		_maquina.trocar(DISPARAR)


func _mirar_sair() -> void:
	_linha.visible = false


func _disparar_entrar() -> void:
	_arma.atirar(_direcao_travada)
	EventBus.pedido_shake.emit(1.6, 0.1)


func _disparar(_delta: float) -> void:
	if _maquina.passou(0.1):
		_maquina.trocar(COOLDOWN)


func _cooldown(delta: float) -> void:
	_mover(delta, 1.0)
	if _maquina.passou(tempo_cooldown):
		_t_intervalo = intervalo
		_maquina.trocar(PROCURAR_POSICAO)


# ------------------------------------------------------------ movimento -----

func _mover(delta: float, fator: float) -> void:
	var d := distancia_do_alvo()
	var para_alvo := direcao_para_alvo()
	var desejada: Vector2

	if d > distancia_ideal + margem:
		desejada = para_alvo
	elif d < distancia_ideal - margem:
		desejada = -para_alvo
	else:
		desejada = para_alvo.orthogonal() * _lado

	velocity = velocity.move_toward(
		direcao_de_locomocao(desejada) * velocidade_atual() * fator,
		1400.0 * delta
	)


## A linha para no ponto de impacto previsto pelo ALCANCE da arma, e nao no
## jogador: assim ela mostra ate onde o tiro chega, o que ensina que sair pelo
## lado resolve e recuar nao.
func _desenhar_linha() -> void:
	var origem := _arma.global_position
	_linha.clear_points()
	_linha.add_point(origem)
	_linha.add_point(origem + _direcao_travada * _arma.dados.alcance)
	var progresso := clampf(_maquina.tempo_no_estado / maxf(tempo_mira, 0.01), 0.0, 1.0)
	# Ciano-esverdeado, distinto do ambar/vermelho do Vigia: a cor e a primeira
	# coisa que o jogador usa para saber qual regra de esquiva aplicar.
	_linha.default_color = Color(0.35, 1.0, 0.85, lerpf(0.1, 0.8, progresso))
	_linha.width = lerpf(1.0, 3.5, progresso)


func _orientar(delta: float) -> void:
	if _visual == null:
		return
	var d := _direcao_travada if _maquina.estado == MIRAR else direcao_para_alvo()
	if d.length_squared() > 0.01:
		_visual.rotation = lerp_angle(_visual.rotation, d.angle(), 10.0 * delta)


func morrer() -> void:
	if _linha != null:
		_linha.visible = false
	super.morrer()
