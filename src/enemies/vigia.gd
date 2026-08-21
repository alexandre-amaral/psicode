extends InimigoBase
## VIGIA -- o inimigo ranged do MVP e o portador do diferencial do jogo.
##
## Abaixo de 50% de Deterioracao ele atira na sua posicao ATUAL: andar de lado
## resolve. Acima de 50% ele resolve o problema do intercepto e atira onde voce
## VAI estar -- inclusive prevendo o rolamento, porque o rolamento e o momento
## em que sua velocidade e mais alta e mais previsivel.
##
## O laser de telegrafo existe justamente para ensinar isso sem tutorial:
## o jogador ve a linha parar em um ponto vazio a frente dele e entende.

@export_group("Posicionamento")
@export var distancia_ideal: float = 300.0
@export var margem: float = 70.0
## Velocidade lateral relativa. Andar de lado mantem o Vigia dificil de acertar.
@export var fator_strafe: float = 0.75

@export_group("Disparo")
@export var intervalo_disparo: float = 2.1
## Tempo com o laser aceso antes do tiro sair. E a janela de reacao do jogador.
@export var tempo_mira: float = 0.55

enum Fase { REPOSICIONANDO, MIRANDO }

var _fase: int = Fase.REPOSICIONANDO
var _t_ciclo: float = 0.0
var _t_mira: float = 0.0
var _dir_strafe: float = 1.0
var _t_troca_strafe: float = 0.0
var _ponto_previsto: Vector2 = Vector2.ZERO

var _arma: Arma
var _laser: Line2D


func _ready() -> void:
	super._ready()
	_arma = $Visual/Arma
	_arma.hostil = true
	_laser = $Laser
	_laser.top_level = true
	_laser.visible = false
	_t_ciclo = randf_range(0.4, intervalo_disparo)
	_dir_strafe = 1.0 if randf() < 0.5 else -1.0


func _comportamento(delta: float) -> void:
	if alvo == null or not is_instance_valid(alvo):
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		return

	_arma.multiplicador_velocidade = Deterioracao.multiplicador_velocidade_projetil()
	_mover(delta)
	_orientar()

	match _fase:
		Fase.REPOSICIONANDO:
			_t_ciclo -= delta * Deterioracao.multiplicador_cadencia()
			if _t_ciclo <= 0.0:
				_fase = Fase.MIRANDO
				_t_mira = tempo_mira
				_laser.visible = true
		Fase.MIRANDO:
			_t_mira -= delta
			_atualizar_previsao()
			_desenhar_laser()
			if _t_mira <= 0.0:
				_disparar()


func _mover(delta: float) -> void:
	var d := distancia_do_alvo()
	var para_alvo := direcao_para_alvo()
	var desejada := Vector2.ZERO

	if d > distancia_ideal + margem:
		desejada = para_alvo
	elif d < distancia_ideal - margem:
		desejada = -para_alvo
	else:
		# Na faixa boa: so circula.
		_t_troca_strafe -= delta
		if _t_troca_strafe <= 0.0:
			_t_troca_strafe = randf_range(1.2, 2.6)
			_dir_strafe *= -1.0
		desejada = para_alvo.orthogonal() * _dir_strafe * fator_strafe

	# Enquanto mira, quase para: um inimigo que atira correndo fica ilegivel.
	var fator := 0.25 if _fase == Fase.MIRANDO else 1.0
	velocity = velocity.move_toward(desejada * velocidade_atual() * fator, 1500.0 * delta)


## O coracao do diferencial. peso 0 = mira burra, peso 1 = intercepto perfeito.
func _atualizar_previsao() -> void:
	var peso := Deterioracao.precisao_preditiva()
	_ponto_previsto = Balistica.mira_ponderada(
		_arma.global_position,
		alvo.global_position,
		velocidade_do_alvo(),
		_arma.dados.velocidade_projetil * _arma.multiplicador_velocidade,
		peso
	)


func _desenhar_laser() -> void:
	var origem := _arma.global_position
	_laser.clear_points()
	_laser.add_point(origem)
	_laser.add_point(_ponto_previsto)
	# Vermelho quando esta prevendo, ambar quando so aponta. O jogador aprende
	# a ler a cor antes de entender a matematica.
	var prevendo := Deterioracao.usa_mira_preditiva()
	var cor := Color(1.0, 0.22, 0.35) if prevendo else Color(1.0, 0.7, 0.25)
	var progresso := 1.0 - clampf(_t_mira / maxf(tempo_mira, 0.01), 0.0, 1.0)
	cor.a = lerpf(0.12, 0.75, progresso)
	_laser.default_color = cor
	_laser.width = lerpf(1.0, 3.0, progresso)


func _disparar() -> void:
	var direcao := (_ponto_previsto - _arma.global_position).normalized()
	if direcao == Vector2.ZERO:
		direcao = direcao_para_alvo()
	_arma.atirar(direcao)
	_laser.visible = false
	_fase = Fase.REPOSICIONANDO
	_t_ciclo = intervalo_disparo


func _orientar() -> void:
	if _visual == null:
		return
	var d := direcao_para_alvo()
	if d.length_squared() > 0.01:
		_visual.rotation = lerp_angle(_visual.rotation, d.angle(), 0.18)


func morrer() -> void:
	if _laser != null:
		_laser.visible = false
	super.morrer()
