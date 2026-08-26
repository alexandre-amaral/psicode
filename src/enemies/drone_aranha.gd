extends InimigoBase
## DRONE ARANHA -- persegue devagar e, de vez em quando, para e abre um anel.
##
## O papel dele no campo e NEGAR o "gire em volta do inimigo": um anel de oito
## projeteis nao tem lado seguro, so tem o espaco entre dois bracos. Ele empurra
## o jogador a andar em linha, e nao em circulo -- que e exatamente o habito que
## o Vigia e o Rastejante deixam passar.
##
## Ele e lento de proposito. Um drone rapido que abre anel viraria uma bomba
## perseguidora, e o jogador nao teria escolha nenhuma; lento, a decisao passa a
## ser "eu resolvo ele agora ou eu passo por ele?".

@export_group("Anel")
## Tempo com o aviso crescendo antes do anel sair. E a janela de leitura.
@export var tempo_carga: float = 0.45
## Quanto ele fica parado DEPOIS de atirar. Junto com a carga, da a meia
## segunda de imobilidade que torna o ataque punivel.
@export var tempo_recuperacao: float = 0.5
@export var intervalo: float = 3.4
## Distancia em que ele decide abrir o anel. Longe demais e o anel nunca chega.
@export var alcance_anel: float = 260.0
@export var projeteis: int = 8

## Abaixo disto ele esta parando, nao andando. Sem um piso, o `move_toward` dos
## estados de recuo deixaria o ciclo de pernas tremendo por uma fracao de
## segundo depois de o drone ja ter travado no lugar.
const VELOCIDADE_ANDANDO := 12.0

const PERSEGUIR := &"PERSEGUIR"
const CARREGAR := &"CARREGAR"
const DISPARAR := &"DISPARAR"
const RECUPERAR := &"RECUPERAR"

var _maquina: MaquinaEstados
var _arma: Arma
var _aviso: Polygon2D
var _sprite: SpriteDirecional
var _t_intervalo: float = 0.0


func _ready() -> void:
	super._ready()
	_arma = $Visual/Arma
	_arma.hostil = true
	_aviso = $Aviso
	_aviso.visible = false
	_sprite = $Visual/Corpo
	# Espalha o primeiro anel do grupo: quatro drones nascendo juntos e
	# disparando no mesmo frame seria uma parede de projeteis, nao um padrao.
	_t_intervalo = randf_range(0.6, intervalo)

	_maquina = MaquinaEstados.new(name)
	_maquina.adicionar(PERSEGUIR, _perseguir)
	_maquina.adicionar(CARREGAR, _carregar, _carregar_entrar, _carregar_sair)
	_maquina.adicionar(DISPARAR, _disparar, _disparar_entrar)
	_maquina.adicionar(RECUPERAR, _recuperar)
	_maquina.iniciar(PERSEGUIR)


func _comportamento(delta: float) -> void:
	_arma.multiplicador_velocidade = Deterioracao.multiplicador_velocidade_projetil()
	_maquina.processar(delta)
	tentar_dano_contato()


## Quem encara, e quando as pernas se mexem.
##
## Roda em `_pos_movimento` e nao em `_comportamento` porque aqui o
## `move_and_slide()` ja aconteceu: `velocity` e a de verdade, com a colisao
## descontada, e nao a que a IA pediu.
##
## A direcao vem de `direcao_para_alvo()` e NAO da `velocity`. Em tres dos
## quatro estados o drone esta desacelerando para zero, entao a direcao sairia
## oscilando ou zerada justamente no instante em que o jogador mais precisa ler
## para onde ele aponta.
##
## E o ciclo de caminhada exige `PERSEGUIR`: o corpo travado no lugar e metade
## do telegrafo do anel (ver `_carregar_entrar`). Deixar as pernas andando
## enquanto o aviso cresce apagaria o sinal que se le de longe -- e como nao ha
## arte de ataque, e a pose parada encarando o jogador que faz esse papel.
func _pos_movimento(delta: float) -> void:
	if _sprite == null:
		return
	var andando := _maquina.estado == PERSEGUIR and velocity.length() > VELOCIDADE_ANDANDO
	_sprite.apontar(direcao_para_alvo(), andando, delta, velocity)


# ------------------------------------------------------------- estados ------

func _perseguir(delta: float) -> void:
	_t_intervalo -= delta * Deterioracao.multiplicador_cadencia()
	velocity = direcao_de_locomocao(direcao_para_alvo()) * velocidade_atual()
	if _t_intervalo <= 0.0 and distancia_do_alvo() <= alcance_anel:
		_maquina.trocar(CARREGAR)


## Trava no lugar e acende o aviso. O corpo parado E parte do telegrafo: e o
## sinal que se le de longe, antes mesmo de o circulo ficar visivel.
func _carregar_entrar() -> void:
	_aviso.visible = true
	_aviso.scale = Vector2(0.2, 0.2)
	_aviso.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_aviso, "scale", Vector2.ONE, tempo_carga)
	t.parallel().tween_property(_aviso, "modulate:a", 0.55, tempo_carga * 0.8)


func _carregar(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 1600.0 * delta)
	if _maquina.passou(tempo_carga):
		_maquina.trocar(DISPARAR)


func _carregar_sair() -> void:
	_aviso.visible = false


## O anel inteiro numa salva so.
##
## Um `for` chamando `atirar()` sairia com UM projetil: o cooldown de cadencia e
## setado no primeiro tiro e so decrementa no `_process`, que nao roda no meio
## do laco. `atirar_varias` gasta um cooldown e uma bala pela salva inteira. Foi
## este mesmo defeito que fez o anel da Diretora sair com um projetil.
func _disparar_entrar() -> void:
	velocity = Vector2.ZERO
	_arma.atirar_varias(Balistica.anel(projeteis, randf() * TAU))
	EventBus.pedido_shake.emit(2.0, 0.12)


func _disparar(_delta: float) -> void:
	if _maquina.passou(0.08):
		_maquina.trocar(RECUPERAR)


func _recuperar(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	if _maquina.passou(tempo_recuperacao):
		_t_intervalo = intervalo
		_maquina.trocar(PERSEGUIR)
