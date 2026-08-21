extends InimigoBase
## RASTEJANTE -- o inimigo melee do MVP.
## Corre atras de voce e machuca no toque. Sozinho e trivial; a graca e a
## composicao. Conforme a Deterioracao sobe ele nao so acelera: passa a dar
## investidas, o que quebra o ritmo de "recuar andando" do jogador.

@export_group("Investida")
## So investe a partir da fase MEDIA da Deterioracao.
@export var investida_alcance: float = 210.0
@export var investida_preparo: float = 0.32
@export var investida_velocidade: float = 560.0
@export var investida_duracao: float = 0.26
@export var investida_cooldown: float = 2.2

enum Fase { PERSEGUINDO, PREPARANDO, INVESTINDO }

var _fase: int = Fase.PERSEGUINDO
var _t_fase: float = 0.0
var _t_investida_cd: float = 0.0
var _dir_investida: Vector2 = Vector2.RIGHT


func _comportamento(delta: float) -> void:
	_t_investida_cd = maxf(_t_investida_cd - delta, 0.0)

	match _fase:
		Fase.PERSEGUINDO:
			velocity = direcao_para_alvo() * velocidade_atual()
			if _pode_investir():
				_iniciar_preparo()

		Fase.PREPARANDO:
			# Freia e "mira". O jogador tem esse tempo para reagir -- e o que
			# torna a investida justa.
			velocity = velocity.move_toward(Vector2.ZERO, 1800.0 * delta)
			_dir_investida = direcao_para_alvo()
			_t_fase -= delta
			if _t_fase <= 0.0:
				_fase = Fase.INVESTINDO
				_t_fase = investida_duracao

		Fase.INVESTINDO:
			velocity = _dir_investida * investida_velocidade
			_t_fase -= delta
			if _t_fase <= 0.0:
				_fase = Fase.PERSEGUINDO
				_t_investida_cd = investida_cooldown

	tentar_dano_contato()
	_orientar()


func _pode_investir() -> bool:
	if Deterioracao.fase == Deterioracao.Fase.BAIXA:
		return false
	if _t_investida_cd > 0.0:
		return false
	return distancia_do_alvo() < investida_alcance


func _iniciar_preparo() -> void:
	_fase = Fase.PREPARANDO
	_t_fase = investida_preparo
	if _visual != null:
		var t := create_tween()
		t.tween_property(_visual, "scale", Vector2(1.35, 0.72), investida_preparo * 0.8)
		t.tween_property(_visual, "scale", Vector2.ONE, 0.1)


func _orientar() -> void:
	if _visual == null:
		return
	var d := velocity if velocity.length_squared() > 25.0 else direcao_para_alvo()
	if d.length_squared() > 0.01:
		_visual.rotation = lerp_angle(_visual.rotation, d.angle(), 0.25)
