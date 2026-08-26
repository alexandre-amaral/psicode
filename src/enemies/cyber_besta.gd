extends InimigoBase
## CYBER-BESTA -- observa, trava a direcao e investe em linha reta.
##
## A investida INTEIRA e o comportamento dele, e nao um tempero como no
## Rastejante -- que so investe acima de 50% de Deterioracao, de perto, no meio
## de uma perseguicao. Aqui o ciclo e ler, esquivar e punir: ele avisa, decide, e
## depois fica vulneravel por um tempo longo.
##
## A regra que faz o ataque ser justo: **a direcao e travada quando a investida
## COMECA e nunca mais e atualizada**. Uma investida que corrige a mira no meio
## do caminho e inesquivavel, e transforma "eu li errado" em "nao dava para
## ler" -- que e a diferenca entre dificil e injusto.

@export_group("Investida")
## Quanto tempo ele encara antes de decidir. E o aviso de longe.
@export var tempo_observando: float = 1.6
## Aviso curto e final, com o corpo ja apontado. Aqui a direcao ainda muda.
@export var tempo_preparo: float = 0.5
@export var velocidade_investida: float = 720.0
@export var duracao_investida: float = 0.42
## Janela de punicao. Longa de proposito: e o pagamento pelo dano alto.
@export var tempo_recuperacao: float = 1.1
## So investe a partir daqui. Longe demais a investida vira corrida.
@export var alcance: float = 420.0

const OBSERVAR := &"OBSERVAR"
const PREPARAR := &"PREPARAR"
## Abaixo disto ele esta parando, nao andando. Sem um piso, o `move_toward` da
## preparacao deixaria o ciclo de patas tremendo enquanto ele ja esta travado.
const VELOCIDADE_ANDANDO := 12.0

const INVESTIR := &"INVESTIR"
const RECUPERAR := &"RECUPERAR"

var _maquina: MaquinaEstados
## Guardada em `_investir_entrar` e lida sem reescrever ate o fim do ataque.
var _direcao_travada: Vector2 = Vector2.RIGHT
var _sprite: SpriteDirecional = null
var _rastro: Line2D


func _ready() -> void:
	super._ready()
	_rastro = $Rastro
	# Sem isto o rastro herdaria a rotacao e a posicao do corpo, e desenharia
	# uma linha girando junto com ele em vez de ficar no chao.
	_rastro.top_level = true
	_rastro.visible = false
	_sprite = $Visual/Corpo

	_maquina = MaquinaEstados.new(name)
	_maquina.adicionar(OBSERVAR, _observar)
	_maquina.adicionar(PREPARAR, _preparar, _preparar_entrar, _preparar_sair)
	_maquina.adicionar(INVESTIR, _investir, _investir_entrar)
	_maquina.adicionar(RECUPERAR, _recuperar, _recuperar_entrar)
	_maquina.iniciar(OBSERVAR)


func _comportamento(delta: float) -> void:
	_maquina.processar(delta)
	tentar_dano_contato()


## O quadro que o corpo mostra, e o eixo do agachamento.
##
## Roda em `_pos_movimento` porque aqui a `velocity` ja passou pelo
## `move_and_slide()` -- e o que decide se ele esta ANDANDO ou so escorregando
## contra uma parede no fim da investida.
func _pos_movimento(delta: float) -> void:
	if _sprite == null:
		return
	var andando := _maquina.estado != OBSERVAR and velocity.length() > VELOCIDADE_ANDANDO
	_sprite.apontar(_direcao_encarada(), andando, delta, velocity)


# ------------------------------------------------------------- estados ------

## Ele nao para: circula devagar, mantendo o jogador no campo de visao. Uma
## besta imovel por dois segundos parece bugada.
func _observar(delta: float) -> void:
	var para_alvo := direcao_para_alvo()
	var desejada := para_alvo * 0.35 + para_alvo.orthogonal() * 0.65
	velocity = velocity.move_toward(
		direcao_de_locomocao(desejada.normalized()) * velocidade_atual() * 0.6,
		900.0 * delta
	)
	if _maquina.passou(tempo_observando) and distancia_do_alvo() <= alcance:
		_maquina.trocar(PREPARAR)


func _preparar_entrar() -> void:
	_rastro.visible = true
	# Atualiza a direcao ANTES de montar o agachamento. `_preparar` reescreve
	# isto todo frame, mas no frame da ENTRADA ela ainda guarda a investida
	# ANTERIOR -- e o agachamento sairia no eixo da corrida passada.
	_direcao_travada = direcao_para_alvo()
	if _visual != null:
		var t := create_tween()
		t.tween_property(_visual, "scale", _agachar(0.7, 1.35), tempo_preparo * 0.7)


func _preparar(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 2200.0 * delta)
	# Ainda acompanha o jogador -- e a ultima chance dele de reagir ao ANGULO,
	# e nao so ao momento. A trava so acontece na transicao.
	_direcao_travada = direcao_para_alvo()
	_desenhar_rastro()
	if _maquina.passou(tempo_preparo):
		_maquina.trocar(INVESTIR)


func _preparar_sair() -> void:
	_rastro.visible = false
	if _visual != null:
		var t := create_tween()
		t.tween_property(_visual, "scale", Vector2.ONE, 0.12)


## A trava. Depois daqui `_direcao_travada` nao e reescrita ate a proxima
## preparacao -- e por isso que sair da linha funciona.
func _investir_entrar() -> void:
	if _direcao_travada.length_squared() < 0.01:
		_direcao_travada = Vector2.RIGHT
	EventBus.pedido_shake.emit(3.0, 0.14)


func _investir(_delta: float) -> void:
	# Sem `direcao_de_locomocao` aqui, e de proposito: durante a investida ele
	# NAO desvia de nada. E o que torna o ataque legivel, e o que fara a parede
	# ser um recurso do jogador quando o pathfinding entrar.
	velocity = _direcao_travada * velocidade_investida
	if _maquina.passou(duracao_investida):
		_maquina.trocar(RECUPERAR)


func _recuperar_entrar() -> void:
	if _visual != null:
		var t := create_tween()
		t.tween_property(_visual, "scale", _agachar(1.2, 0.8), 0.1)
		t.tween_property(_visual, "scale", Vector2.ONE, tempo_recuperacao * 0.6)


func _recuperar(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 1100.0 * delta)
	if _maquina.passou(tempo_recuperacao):
		_maquina.trocar(OBSERVAR)


## Para onde o corpo aponta: para onde ele VAI, nao para onde o jogador esta.
##
## Durante a investida as duas coisas sao diferentes, e o corpo tem de contar a
## verdade -- e o que faz sair da linha funcionar. A regra nao mudou quando o
## corpo virou sprite; o que mudou foi quem a executa.
##
## Antes isto girava o `_visual` com `lerp_angle`. Agora quem carrega a direcao
## sao as oito rotacoes do sprite, e girar o `_visual` deitaria a arte: ela e
## desenhada em vista 3/4 e so faz sentido de pe. A resolucao caiu de continua
## para oito passos, que e a mesma do jogador -- e ainda assim a leitura MELHOROU,
## porque um bicho desenhado virado para o nordeste diz mais que um hexagono
## girado.
func _direcao_encarada() -> Vector2:
	var d := _direcao_travada if _maquina.estado == INVESTIR else direcao_para_alvo()
	return d if d.length_squared() > 0.01 else _direcao_travada



## Monta a escala do agachamento no EIXO da investida.
##
## Enquanto o `_visual` girava, ele agachava sozinho no eixo certo: comprimir em
## x local era comprimir na direcao da corrida. Sem a rotacao, um `Vector2(0.7,
## 1.35)` cru comprimiria sempre na horizontal da TELA -- e um bicho carregando
## para cima apareceria achatado de lado, contando a anticipacao no eixo errado.
##
## Escolhe o eixo dominante, que e a mesma quantizacao de oito passos que o
## sprite ja usa. Numa diagonal os dois valores servem igual.
func _agachar(ao_longo: float, atravessado: float) -> Vector2:
	var d := _direcao_travada
	if absf(d.x) >= absf(d.y):
		return Vector2(ao_longo, atravessado)
	return Vector2(atravessado, ao_longo)


func _desenhar_rastro() -> void:
	_rastro.clear_points()
	_rastro.add_point(global_position)
	_rastro.add_point(global_position + _direcao_travada * velocidade_investida * duracao_investida)
	var progresso := clampf(_maquina.tempo_no_estado / maxf(tempo_preparo, 0.01), 0.0, 1.0)
	_rastro.default_color = Color(1.0, 0.45, 0.2, lerpf(0.15, 0.6, progresso))
	_rastro.width = lerpf(2.0, 6.0, progresso)


func morrer() -> void:
	if _rastro != null:
		_rastro.visible = false
	super.morrer()
