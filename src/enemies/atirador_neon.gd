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
##
## MEDIDO ao avaliar a faixa de 350-500 que o plano sugeria (INIM 02): a camera
## mostra 960x544 centrada no jogador, entao meia tela e 480 px na horizontal e
## 272 na VERTICAL. A 425 px ele estaria fora do quadro por cima ou por baixo, e
## a 500 fora nos dois eixos -- um atirador invisivel tracando uma linha rapida
## e exatamente o que o GDD proibe.
##
## A faixa de hoje (250-350) ja passa dos 272 verticais no topo dela, e isso e
## uma ressalva conhecida e nao um descuido. Aperta-la mudaria a identidade dele
## -- ele e o punidor de longa distancia --, entao e decisao de design e nao de
## implementacao.
@export var distancia_ideal: float = 300.0
@export var margem: float = 50.0
## Abaixo disto ele CANCELA a mira e se afasta.
##
## Sem isso, encostar nele era a forma trivial de mata-lo: ele continuava
## plantado, mirando, enquanto levava tiro a queima-roupa. Um inimigo cuja
## contra-jogada e "chegue perto e fique la" nao ensina nada.
@export var distancia_de_esquiva: float = 120.0

@export_group("Disparo")
@export var intervalo: float = 2.6
## Linha acesa antes do tiro. Mais longa que a do Vigia -- em troca, o projetil
## e muito mais rapido e nao da para reagir depois que ele sai.
@export var tempo_mira: float = 1.0
@export var tempo_cooldown: float = 0.6

@export_group("Esquiva")
## Quanto dura o arranque para longe.
@export var tempo_esquiva: float = 0.4
## Quanto ele corre mais rapido enquanto esquiva.
@export var impulso_esquiva: float = 1.9

const PROCURAR_POSICAO := &"PROCURAR_POSICAO"
const MIRAR := &"MIRAR"
const DISPARAR := &"DISPARAR"
const COOLDOWN := &"COOLDOWN"
const ESQUIVAR := &"ESQUIVAR"

var _maquina: MaquinaEstados
var _arma: Arma
var _telegrafo: Telegrafo
## Travada em `_mirar_entrar`. Nao e recalculada durante a mira.
var _direcao_travada: Vector2 = Vector2.RIGHT
var _t_intervalo: float = 0.0
var _lado: float = 1.0
## Congelada em `_esquivar_entrar`: recalcular durante o arranque faria ele
## curvar atras do jogador, que e perseguir e nao fugir.
var _direcao_esquiva: Vector2 = Vector2.RIGHT


func _ready() -> void:
	super._ready()
	_arma = $Visual/Arma
	_arma.hostil = true
	_telegrafo = Telegrafo.anexar(self)
	# Ciano-esverdeado, distinto do ambar/vermelho do Vigia: a cor e a primeira
	# coisa que o jogador usa para saber qual regra de esquiva aplicar.
	_telegrafo.cor = Color(0.35, 1.0, 0.85)
	_telegrafo.largura_min = 1.0
	_telegrafo.largura_max = 3.5
	_telegrafo.alfa_min = 0.1
	_telegrafo.alfa_max = 0.8
	_t_intervalo = randf_range(0.5, intervalo)
	_lado = 1.0 if randf() < 0.5 else -1.0

	_maquina = MaquinaEstados.new(name)
	_maquina.adicionar(PROCURAR_POSICAO, _procurar)
	_maquina.adicionar(MIRAR, _mirar, _mirar_entrar, _mirar_sair)
	_maquina.adicionar(DISPARAR, _disparar, _disparar_entrar)
	_maquina.adicionar(COOLDOWN, _cooldown)
	_maquina.adicionar(ESQUIVAR, _esquivar, _esquivar_entrar)
	_maquina.iniciar(PROCURAR_POSICAO)


func _comportamento(delta: float) -> void:
	_arma.multiplicador_velocidade = Deterioracao.multiplicador_velocidade_projetil()
	if _deve_esquivar():
		_maquina.trocar(ESQUIVAR)
	_maquina.processar(delta)
	_orientar(delta)


## O jogador encostou, e ele ainda nao esta fugindo.
##
## A checagem fica FORA da maquina, antes do `processar`, porque ela vale em
## qualquer estado -- inclusive no meio da mira. Poe-la dentro de cada estado
## daria tres copias da mesma condicao, e a que faltasse seria justamente a que
## o jogador ia achar.
##
## Trocar de estado aqui cancela a mira de graca: quem apaga a linha e o `sair`
## de MIRAR, que a MaquinaEstados roda mesmo quando a troca vem de fora. E o
## motivo pelo qual a esquiva e um ESTADO e nao um `if` dentro de `_mirar` -- e
## e a invariante 3 do `Telegrafo`, "apaga sempre", amarrada onde ela funciona.
func _deve_esquivar() -> bool:
	if _maquina.estado == ESQUIVAR:
		return false
	return distancia_do_alvo() < distancia_de_esquiva



## Ver `DadosInimigo`. A esquiva dele e um ARRANQUE do vocabulario do recurso:
## sem velocidade propria, so um multiplicador da normal.
func _ler_dados(d: DadosInimigo) -> void:
	distancia_ideal = d.distancia_preferida
	margem = d.margem_de_distancia
	distancia_de_esquiva = d.distancia_minima
	intervalo = d.cooldown_ataque
	tempo_mira = d.tempo_telegrafo
	tempo_cooldown = d.tempo_recuperacao
	tempo_esquiva = d.duracao_arranque
	impulso_esquiva = d.impulso_arranque

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
	_telegrafo.acender(tempo_mira)


func _mirar(delta: float) -> void:
	# Quase parado enquanto mira: um atirador que corre atirando fica ilegivel,
	# e a linha travada perde sentido se a ORIGEM dela anda.
	_mover(delta, 0.15)
	_desenhar_linha()
	# O telegrafo e quem conta: `tempo_mira` abaixo do piso de duracao viraria
	# um tiro saindo antes de o aviso terminar.
	if _telegrafo.avancar(delta) >= 1.0:
		_maquina.trocar(DISPARAR)


func _mirar_sair() -> void:
	_telegrafo.apagar()


func _disparar_entrar() -> void:
	_arma.atirar(_direcao_travada)
	EventBus.pedido_shake.emit(1.6, 0.1)


func _disparar(_delta: float) -> void:
	if _maquina.passou(0.1):
		_maquina.trocar(COOLDOWN)


## Um arranque curto para longe, e nada mais.
##
## Nao e um recuo continuo de propositio: um atirador que recua enquanto o
## jogador avanca vira uma perseguicao invertida que nunca termina, e o combate
## trava. Ele se afasta uma vez, o suficiente para sair do corpo a corpo, e
## volta a rotina -- se o jogador insistir, esquiva de novo, e cada esquiva
## custa a ele o tempo de mira que ele nao esta usando.
##
## A direcao mistura "para longe" com "de lado". Puro para longe o encostaria na
## parede e ele ficaria preso ali; o componente lateral o faz contornar.
func _esquivar_entrar() -> void:
	_direcao_esquiva = Movimento.rumo_de_esquiva(direcao_para_alvo(), _lado)
	# A esquiva CUSTA: ela adia o proximo tiro. Sem isso, chegar perto dele seria
	# de graca para o jogador -- ele esquivaria e atiraria na mesma cadencia.
	_t_intervalo = maxf(_t_intervalo, tempo_esquiva)


func _esquivar(delta: float) -> void:
	# `rumar` e nao `recuar`: a direcao foi CONGELADA na entrada do estado, e
	# recalcular "para longe" todo frame o faria curvar atras do jogador -- que e
	# perseguir de costas, e nao fugir.
	Movimento.rumar(self, delta, _direcao_esquiva, impulso_esquiva)
	if _maquina.passou(tempo_esquiva):
		_maquina.trocar(PROCURAR_POSICAO)


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
	_telegrafo.linha(origem, origem + _direcao_travada * _arma.dados.alcance)


func _orientar(delta: float) -> void:
	if _visual == null:
		return
	var d := _direcao_travada if _maquina.estado == MIRAR else direcao_para_alvo()
	if d.length_squared() > 0.01:
		_visual.rotation = lerp_angle(_visual.rotation, d.angle(), 10.0 * delta)
