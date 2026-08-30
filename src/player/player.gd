extends CharacterBody2D
## O protagonista. Twin-stick classico: WASD anda, mouse mira, botao esquerdo
## atira, espaco (ou botao direito) rola.
##
## O rolamento e o coracao do jogo. Ele da i-frames, e a partir de 50% de
## Deterioracao os inimigos passam a prever exatamente para onde voce vai
## rolar. Todo o balanceamento gira em torno desse par.

signal vida_alterada(atual: int, maximo: int)

const GRUPO := "player"
const CENA_ECO := preload("res://src/player/eco_rolamento.tscn")

enum Estado { NORMAL, ROLANDO, MORTO }

@export_group("Movimento")
@export var velocidade_max: float = 330.0
@export var aceleracao: float = 2600.0
@export var atrito: float = 2200.0

@export_group("Rolamento")
@export var roll_velocidade: float = 720.0
@export var roll_duracao: float = 0.22
@export var roll_cooldown: float = 0.55
## Sobra de invulnerabilidade depois que o rolamento termina. Perdoa o jogador
## que rolou um frame cedo demais -- e o que separa "dificil" de "injusto".
@export var roll_graca: float = 0.06

@export_group("Vida")
@export var vida_maxima: int = 6
@export var iframes_apos_dano: float = 1.0

@export_group("Armas")
@export var arma_inicial: DadosArma

@export_group("Personagem")
## Usado so quando ninguem escolheu -- main.tscn aberto direto no editor, e o
## teste de fumaca. Fora esses dois casos quem manda e GameState.personagem.
@export var personagem_padrao: DadosPersonagem

var vida: int = 6
var estado: int = Estado.NORMAL

## Vida maxima sem implante. Guardada a parte porque `vida_maxima` passa a ser
## base + bonus, e recalcular a partir dela mesma acumularia o bonus a cada
## coleta.
var _vida_maxima_base: int = 6

var _dir_roll: Vector2 = Vector2.RIGHT
var _t_roll: float = 0.0
var _t_roll_cd: float = 0.0
var _t_invuln: float = 0.0
var _t_eco: float = 0.0

var _arma: Arma
var _visual: Node2D
var _sprite: Sprite2D
## Abaixo disto o jogador esta parando, nao andando. Sem um piso, o atrito
## deixaria o ciclo tremendo por uma fracao de segundo depois de soltar a tecla.
const VELOCIDADE_ANDANDO := 12.0
## Largura da elipse de sombra do jogador. Perto do dobro do raio de colisao
## (11), que e a pegada real dele no chao.
const LARGURA_SOMBRA := 24.0

## Posicao no ciclo de caminhada, em quadros. Float porque o avanco e continuo;
## quem indexa a fita e o int() dele.
var _t_ciclo: float = 0.0

## O personagem em vigor. Guardado porque `_mirar()` precisa dele todo frame
## para escolher o quadro, e reler GameState a cada frame seria pior.
var _personagem: DadosPersonagem = null
var _camera: Camera2D

## Slot 0 e sempre a pistola infinita; slot 1 e o loot. Q alterna.
var _slots: Array[DadosArma] = [null, null]
var _slot_ativo: int = 0


## Sobrescreve os @export da cena com o que o personagem escolhido pede.
##
## Chamado ANTES de `_vida_maxima_base = vida_maxima`, e isso nao e estilo: uma
## vez congelada a base, todo o recalculo de implantes de vida
## (_ao_modificadores_mudarem) passa a somar em cima do numero errado. Qualquer
## atributo que um personagem venha a mexer entra aqui, no topo, ou nao entra.
##
## Personagem nulo e o caminho normal, nao um erro: main.tscn roda sozinho no
## editor e no teste de fumaca, e nesses casos valem os @export da cena.
func _aplicar_personagem() -> void:
	# personagem_padrao existe porque main.tscn roda sozinho no editor e no teste
	# de fumaca, e nenhum dos dois passa pela tela de selecao. Sem ele o jogador
	# ficaria invisivel exatamente nos dois fluxos em que ninguem escolheu nada.
	_personagem = GameState.personagem if GameState.personagem != null else personagem_padrao
	if _personagem == null:
		return
	if _personagem.arma_inicial != null:
		arma_inicial = _personagem.arma_inicial

	_sprite.scale = Vector2.ONE * _personagem.escala_sprite
	_sprite.position = _personagem.deslocamento_sprite
	# Um quadro ja no _ready: sem isto o Sprite nasce sem textura e a personagem
	# some ate o primeiro movimento de mouse.
	_sprite.texture = _personagem.textura_para(Vector2.DOWN)
	_sprite.hframes = 1


func _ready() -> void:
	add_to_group(GRUPO)
	_visual = $Visual
	_sprite = $Sprite
	_arma = $Visual/Arma
	_camera = $Camera

	# A sombra e irma do Visual e do Sprite, como os dois sao entre si: o
	# Visual gira e o piscar de i-frames escreve em `_sprite.modulate`, e a
	# sombra nao pode girar nem piscar.
	#
	# Criada DEPOIS de _aplicar_personagem(): o deslocamento do sprite vem do
	# .tres da personagem, e antes dessa chamada ele ainda e o default da cena.
	_aplicar_personagem()
	var sombra := Sombra.criar(LARGURA_SOMBRA, Sombra.base_de(_sprite))
	add_child(sombra)
	move_child(sombra, 0)

	Juice.registrar_camera(_camera)

	_vida_maxima_base = vida_maxima
	vida_maxima = _vida_maxima_base + Modificadores.bonus_vida_maxima()
	vida = vida_maxima
	# Vida maxima e a unica excecao a regra de "ler no frame": ela e um
	# recipiente, nao um multiplicador -- se fosse recalculada por frame, a vida
	# atual teria de ser reescalada junto e o dano viraria fracao. Entao ela
	# reage ao evento, uma vez por implante.
	EventBus.modificadores_mudaram.connect(_ao_modificadores_mudarem)
	_slots[0] = arma_inicial
	_arma.hostil = false

	# Conectar ANTES de equipar: equipar() emite municao_alterada, e ligar o
	# sinal depois perdia esse primeiro aviso -- a HUD ficava com o texto que
	# estava escrito na cena ate o primeiro tiro.
	_arma.municao_alterada.connect(_ao_mudar_municao)
	_arma.ficou_sem_municao.connect(_ao_acabar_municao)
	_arma.disparou.connect(_ao_disparar)
	_arma.recarga_iniciada.connect(func(d: float) -> void: EventBus.recarga_iniciada.emit(d))
	_arma.recarga_concluida.connect(func() -> void: EventBus.recarga_concluida.emit())

	# Cura pedida por implante (Nanobots, Vampirico). O pedido nao sabe quem
	# cura -- mesmo padrao de pedido_shake e pedido_hitstop.
	EventBus.pedido_cura.connect(curar)

	if arma_inicial != null:
		_arma.equipar(arma_inicial)

	# A camera agora e gerenciada pelo mapa ou sala. 
	EventBus.player_pronto.emit(self)
	vida_alterada.emit(vida, vida_maxima)
	EventBus.player_dano_recebido.emit(vida, vida_maxima)
	EventBus.arma_equipada.emit(_slots[0], 0)


func _physics_process(delta: float) -> void:
	if estado == Estado.MORTO:
		return

	_t_roll_cd = maxf(_t_roll_cd - delta, 0.0)
	_t_invuln = maxf(_t_invuln - delta, 0.0)

	_mirar(delta)

	match estado:
		Estado.NORMAL:
			_processar_normal(delta)
		Estado.ROLANDO:
			_processar_rolamento(delta)

	move_and_slide()
	_atualizar_visual()


func _processar_normal(delta: float) -> void:
	var entrada := Input.get_vector("mover_esquerda", "mover_direita", "mover_cima", "mover_baixo")

	if entrada != Vector2.ZERO:
		velocity = velocity.move_toward(entrada * velocidade_atual(), aceleracao * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, atrito * delta)

	if Input.is_action_just_pressed("rolar") and _t_roll_cd <= 0.0:
		_iniciar_rolamento(entrada)
		return

	if Input.is_action_just_pressed("trocar_arma"):
		_alternar_slot()

	if Input.is_action_just_pressed("recarregar"):
		_arma.recarregar()

	_arma.atualizar_gatilho(Input.is_action_pressed("atirar"))
	if Input.is_action_pressed("atirar"):
		_arma.atirar(_direcao_mira())


func _processar_rolamento(delta: float) -> void:
	_t_roll -= delta
	# Desacelera no fim do rolamento em vez de parar seco: o corpo "assenta".
	var progresso := clampf(_t_roll / roll_duracao, 0.0, 1.0)
	var vel := lerpf(velocidade_atual() * 0.8, roll_velocidade, progresso)
	velocity = _dir_roll * vel

	_t_eco -= delta
	if _t_eco <= 0.0:
		_t_eco = 0.045
		_soltar_eco()

	if _t_roll <= 0.0:
		estado = Estado.NORMAL
		_t_invuln = maxf(_t_invuln, roll_graca)


func _iniciar_rolamento(entrada: Vector2) -> void:
	# Sem direcao de movimento, rola para onde estiver mirando.
	_dir_roll = entrada.normalized() if entrada != Vector2.ZERO else _direcao_mira()
	estado = Estado.ROLANDO
	_t_roll = roll_duracao
	_t_roll_cd = cooldown_rolamento_atual()
	_t_invuln = maxf(_t_invuln, roll_duracao)
	_t_eco = 0.0
	EventBus.player_rolou.emit()


## O `Visual` gira livre (e dele que a boca da arma herda a posicao, e por isso
## ele NAO pode parar de girar); o `Sprite`, que e irmao e nao filho, so troca de
## quadro. Sao duas resolucoes de mira convivendo de proposito: o corpo mostra a
## direcao geral em oito passos, e quem mostra o alvo exato e o reticulo no
## mouse -- que substituiu o cano ciano que ficava preso ao corpo.
func _mirar(delta: float) -> void:
	var direcao := _direcao_mira()
	_visual.rotation = direcao.angle()
	if _personagem == null:
		return

	# Rolando nao troca de animacao: o eco ja comunica o rolamento, e trocar de
	# fita no meio de 0,22 s so piscaria.
	var andando := estado == Estado.NORMAL and velocity.length() > VELOCIDADE_ANDANDO
	var fita: Texture2D = _personagem.textura_andando_para(direcao) if andando else null

	if fita != null:
		_avancar_ciclo(delta, direcao)
		_trocar_quadro(fita, _personagem.quadros_andando, int(_t_ciclo) % _personagem.quadros_andando)
	else:
		_t_ciclo = 0.0
		_trocar_quadro(_personagem.textura_para(direcao), 1, 0)


## Anda o ciclo, para a frente ou para tras.
##
## Andar de re com o ciclo normal e o moonwalk: a personagem continua encarando
## o alvo (e twin-stick, isso e o certo) enquanto desliza para o outro lado com
## as pernas indo para frente. Inverter o ciclo quando o movimento contraria a
## mira resolve sem arte nova, e e o que o corpo de fato faz.
func _avancar_ciclo(delta: float, direcao: Vector2) -> void:
	var sentido := -1.0 if velocity.dot(direcao) < 0.0 else 1.0
	_t_ciclo += delta * _personagem.fps_andando * sentido
	var total := float(_personagem.quadros_andando)
	# fposmod e nao fmod: com sentido negativo o fmod devolve negativo, e o
	# int() disso indexaria fora da fita.
	_t_ciclo = fposmod(_t_ciclo, total)


## Textura, hframes e quadro SEMPRE juntos.
##
## Trocar `texture` sem trocar `hframes` desenha a fita de 9 quadros inteira
## espremida no lugar da personagem -- e o inverso, um idle com hframes 9,
## mostra um nono dela. Nao ha erro no console em nenhum dos dois casos.
func _trocar_quadro(textura: Texture2D, colunas: int, quadro: int) -> void:
	if textura == null:
		return
	if _sprite.texture != textura:
		_sprite.texture = textura
		_sprite.hframes = colunas
	if _sprite.frame != quadro:
		_sprite.frame = quadro


func _direcao_mira() -> Vector2:
	var d := get_global_mouse_position() - global_position
	if d.length_squared() < 1.0:
		return Vector2.RIGHT.rotated(_visual.rotation)
	return d.normalized()


func _atualizar_visual() -> void:
	# Pisca durante a invulnerabilidade pos-dano (mas nao durante o rolamento,
	# senao o eco ja comunica e vira poluicao visual).
	#
	# So o Sprite: desde que a mira virou reticulo no mouse, o `Visual` nao
	# desenha mais nada -- ele existe para girar e carregar a boca da arma. O
	# `modulate` dele nao alcanca o `Sprite`, que e irmao e nao filho, e por isso
	# o piscar sempre morou aqui de qualquer jeito.
	var alfa := 1.0
	if estado != Estado.ROLANDO and _t_invuln > 0.0:
		alfa = 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() * 0.02))
	_sprite.modulate.a = alfa


func _soltar_eco() -> void:
	var eco := CENA_ECO.instantiate()
	get_parent().add_child(eco)
	eco.global_position = global_position + _sprite.position
	eco.scale = _sprite.scale
	# hframes e frame junto da textura: sem eles o rastro do rolamento vira a
	# fita de nove quadros esticada atras do jogador.
	eco.hframes = _sprite.hframes
	eco.frame = _sprite.frame
	# Sem rotacao: o quadro ja carrega a direcao, e girar arte 3/4 a deitaria.
	eco.iniciar(_sprite.texture, Color(0.35, 0.95, 1.0, 0.5))


# ---------------------------------------------------------------- combate ---

## Lidas no frame de uso, como manda a regra 2 do projeto: um implante pego na
## sala 6 vale para o movimento que ja esta acontecendo.
func velocidade_atual() -> float:
	return velocidade_max * Modificadores.multiplicador_velocidade()


func cooldown_rolamento_atual() -> float:
	return roll_cooldown * Modificadores.multiplicador_cooldown_rolamento()


## Coracao novo nasce cheio: dar vida maxima sem dar a vida junto faria o
## implante parecer que nao fez nada ate a proxima cura.
func _ao_modificadores_mudarem() -> void:
	var novo := _vida_maxima_base + Modificadores.bonus_vida_maxima()
	if novo == vida_maxima:
		return
	var ganho := novo - vida_maxima
	vida_maxima = maxi(novo, 1)
	if ganho > 0:
		vida = mini(vida + ganho, vida_maxima)
	else:
		vida = mini(vida, vida_maxima)
	vida_alterada.emit(vida, vida_maxima)
	EventBus.player_dano_recebido.emit(vida, vida_maxima)


func invulneravel() -> bool:
	return estado == Estado.ROLANDO or _t_invuln > 0.0


## Contrato usado por projeteis e inimigos. Devolve true se o dano valeu --
## quem chamou usa isso para decidir se gasta o projetil.
func receber_dano(quantidade: int, impulso: Vector2 = Vector2.ZERO) -> bool:
	if estado == Estado.MORTO or invulneravel():
		return false

	vida = maxi(vida - quantidade, 0)
	_t_invuln = iframes_apos_dano
	velocity += impulso * 0.5

	vida_alterada.emit(vida, vida_maxima)
	EventBus.player_dano_recebido.emit(vida, vida_maxima)
	EventBus.pedido_shake.emit(6.6, 0.35)
	EventBus.pedido_hitstop.emit(0.1, 0.04)

	if vida <= 0:
		_morrer()
	return true


func curar(quantidade: int) -> void:
	if estado == Estado.MORTO:
		return
	vida = mini(vida + quantidade, vida_maxima)
	vida_alterada.emit(vida, vida_maxima)
	EventBus.player_curado.emit(vida, vida_maxima)


func _morrer() -> void:
	estado = Estado.MORTO
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	var fx := preload("res://src/fx/explosao.tscn").instantiate()
	fx.global_position = global_position
	fx.modulate = Color(0.4, 0.95, 1.0)
	get_parent().add_child(fx)
	_visual.visible = false
	_sprite.visible = false
	EventBus.pedido_shake.emit(12.0, 0.7)
	EventBus.player_morreu.emit()
	GameState.terminar_run(false)


# ----------------------------------------------------------------- armas ---

func equipar_arma_loot(dados: DadosArma) -> void:
	_slots[1] = dados
	_slot_ativo = 1
	_arma.equipar(dados)
	EventBus.arma_equipada.emit(dados, 1)
	# Depois de equipar, e so aqui: e a unica das quatro emissoes de
	# arma_equipada em que a arma e NOVA para o jogador.
	EventBus.arma_adquirida.emit(dados)


func _alternar_slot() -> void:
	if _slots[1] == null:
		return
	_slot_ativo = 1 - _slot_ativo
	_arma.equipar(_slots[_slot_ativo])
	EventBus.arma_equipada.emit(_slots[_slot_ativo], _slot_ativo)


func _ao_acabar_municao() -> void:
	# Arma de loot sem municao e descartada e voltamos para a pistola.
	_slots[1] = null
	_slot_ativo = 0
	_arma.equipar(_slots[0])
	EventBus.arma_equipada.emit(_slots[0], 0)


func _ao_mudar_municao(no_pente: int, reserva: int) -> void:
	EventBus.municao_mudou.emit(no_pente, reserva)


func _ao_disparar(direcao: Vector2, dados: DadosArma) -> void:
	EventBus.pedido_shake.emit(dados.shake_intensidade, dados.shake_duracao)
	if dados.recuo_player > 0.0:
		velocity -= direcao * dados.recuo_player
