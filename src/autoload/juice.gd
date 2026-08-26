extends Node
## "Game feel" centralizado: screen shake e hitstop.
##
## Por que autoload: qualquer coisa (bala, inimigo, chefe) precisa pedir um
## tremor sem saber onde a camera esta. A camera se registra aqui no _ready.

var _camera: Camera2D = null
var _shake_intensidade: float = 0.0
var _shake_decaimento: float = 0.0
var _hitstop_ativo: bool = false
## Quando o ultimo hitstop TERMINOU, em ms de relogio de parede.
##
## `_hitstop_ativo` sozinho impede EMPILHAR, mas nao impede ENCADEAR: uma fonte
## de dano continuo -- o feixe do Laser Cutter, a shotgun encostada, o chefe
## sendo metralhado -- pede um hitstop novo no instante em que o anterior
## acaba, e o jogo fica presa em camera lenta permanente. Medido: o feixe
## entregava 19 de dano onde o .tres pedia 26, porque ele atrasava a si mesmo.
##
## Relogio de PAREDE (`get_ticks_msec`) e nao um timer da arvore: o timer
## andaria devagar durante o proprio hitstop, que e exatamente o intervalo que
## se quer medir.
var _fim_do_ultimo_hitstop: int = 0

## Intervalo minimo entre dois hitstops. Acima disso o efeito continua sendo
## pontuacao de impacto; abaixo, vira uma segunda velocidade de jogo.
const INTERVALO_HITSTOP := 120

## Duas chaves, e nao uma, de proposito: sao efeitos diferentes.
##
## O shake move a CAMERA -- e o que incomoda quem tem sensibilidade a movimento,
## e e o que a tela de opcoes desliga. O hitstop congela o tempo por alguns
## milissegundos e e o que da peso ao tiro; matar os dois juntos tiraria o
## impacto do combate de quem so queria parar de enjoar.
var shake_habilitado: bool = true
var hitstop_habilitado: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.pedido_shake.connect(shake)
	EventBus.pedido_hitstop.connect(hitstop)
	# Puxa a preferencia em vez de esperar ser empurrado: `Configuracao` e
	# registrado ANTES deste autoload, entao no _ready dela este aqui ainda nao
	# existia.
	shake_habilitado = Configuracao.shake


func registrar_camera(cam: Camera2D) -> void:
	_camera = cam


func _process(delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	if _shake_intensidade > 0.0:
		_shake_intensidade = maxf(_shake_intensidade - _shake_decaimento * delta, 0.0)
		_camera.offset = Vector2(
			randf_range(-1.0, 1.0) * _shake_intensidade,
			randf_range(-1.0, 1.0) * _shake_intensidade
		)
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


## intensidade em pixels de deslocamento, duracao em segundos.
func shake(intensidade: float, duracao: float = 0.25) -> void:
	if not shake_habilitado:
		return
	# Um tremor forte nunca e substituido por um fraco em andamento.
	_shake_intensidade = maxf(_shake_intensidade, intensidade)
	_shake_decaimento = maxf(_shake_intensidade / maxf(duracao, 0.01), 1.0)


## Congela quase tudo por alguns milissegundos. E o que faz um tiro "pesar".
func hitstop(duracao: float = 0.06, escala: float = 0.05) -> void:
	if not hitstop_habilitado or _hitstop_ativo:
		return
	if Time.get_ticks_msec() - _fim_do_ultimo_hitstop < INTERVALO_HITSTOP:
		return
	_hitstop_ativo = true
	Engine.time_scale = escala
	# O 4o argumento (ignore_time_scale) e essencial: sem ele o proprio timer
	# ficaria lento junto com o jogo e o congelamento nunca terminaria.
	await get_tree().create_timer(duracao, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_ativo = false
	_fim_do_ultimo_hitstop = Time.get_ticks_msec()


func resetar() -> void:
	_shake_intensidade = 0.0
	_hitstop_ativo = false
	_fim_do_ultimo_hitstop = 0
	Engine.time_scale = 1.0
	if is_instance_valid(_camera):
		_camera.offset = Vector2.ZERO
