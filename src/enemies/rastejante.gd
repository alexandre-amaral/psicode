extends InimigoBase
## RASTEJANTE -- o inimigo melee do MVP.
## Corre atras de voce e machuca no toque. Sozinho e trivial; a graca e a
## composicao. Conforme a Deterioracao sobe ele nao so acelera: passa a dar
## investidas, o que quebra o ritmo de "recuar andando" do jogador.

@export_group("Investida")
## So investe a partir da fase MEDIA da Deterioracao.
@export var investida_alcance: float = 128.0
@export var investida_preparo: float = 0.32
@export var investida_velocidade: float = 560.0
@export var investida_duracao: float = 0.26
@export var investida_cooldown: float = 2.2

enum Fase { PERSEGUINDO, PREPARANDO, INVESTINDO }

var _fase: int = Fase.PERSEGUINDO
var _t_fase: float = 0.0
var _t_investida_cd: float = 0.0
var _dir_investida: Vector2 = Vector2.RIGHT
var _sprite: SpriteDirecional = null


## Abaixo disto ele esta parando, nao andando. Sem um piso, o `move_toward` da
## preparacao deixaria o ciclo tremendo enquanto ele ja esta travado no lugar.
const VELOCIDADE_ANDANDO := 12.0


func _ready() -> void:
	super._ready()
	_sprite = $Visual/Corpo


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


## Monta a escala do bote no EIXO da investida.
##
## Enquanto o `_visual` girava, esticar em x LOCAL era esticar na direcao da
## corrida -- o corpo se alongava para a frente, como quem se joga. Sem a
## rotacao, um `Vector2(1.35, 0.72)` cru estica sempre na horizontal da TELA, e
## um Rastejante partindo para cima apareceria alongado de lado: a anticipacao
## contada no eixo errado.
##
## Escolhe o eixo dominante, que e a mesma quantizacao de oito passos do sprite.
func _esticar(ao_longo: float, atravessado: float) -> Vector2:
	var d := _dir_investida
	if absf(d.x) >= absf(d.y):
		return Vector2(ao_longo, atravessado)
	return Vector2(atravessado, ao_longo)


func _pode_investir() -> bool:
	if Deterioracao.fase == Deterioracao.Fase.BAIXA:
		return false
	if _t_investida_cd > 0.0:
		return false
	return distancia_do_alvo() < investida_alcance


func _iniciar_preparo() -> void:
	_fase = Fase.PREPARANDO
	_t_fase = investida_preparo
	# Atualiza a direcao ANTES de montar o bote. `Fase.PREPARANDO` a reescreve
	# todo frame, mas no frame da ENTRADA ela ainda guarda a investida anterior,
	# e o alongamento sairia no eixo da corrida passada.
	_dir_investida = direcao_para_alvo()
	if _visual != null:
		var t := create_tween()
		t.tween_property(_visual, "scale", _esticar(1.35, 0.72), investida_preparo * 0.8)
		t.tween_property(_visual, "scale", Vector2.ONE, 0.1)


## Para onde o corpo aponta, e se as patas se mexem.
##
## Roda em `_pos_movimento` porque aqui a `velocity` ja passou pelo
## `move_and_slide()`: e o que separa "andando" de "escorregando contra a parede
## no fim da investida".
##
## `andando` sai SO da velocidade, e nao da fase. Nenhuma fase dele fica parada:
## PERSEGUINDO corre, PREPARANDO freia (e as patas tem de desacelerar junto) e
## INVESTINDO dispara em linha reta.
func _pos_movimento(delta: float) -> void:
	if _sprite == null:
		return
	var andando := velocity.length() > VELOCIDADE_ANDANDO
	_sprite.apontar(_direcao_encarada(), andando, delta, velocity)


## Aponta para onde ele VAI. Antes isto girava o `_visual` com `lerp_angle`;
## agora quem carrega a direcao sao as oito rotacoes do sprite, e girar o
## `_visual` deitaria a arte, que e desenhada em vista 3/4.
func _direcao_encarada() -> Vector2:
	var d := velocity if velocity.length_squared() > 25.0 else direcao_para_alvo()
	return d if d.length_squared() > 0.01 else _dir_investida
