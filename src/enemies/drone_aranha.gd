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

@export_group("Posicionamento")
## Acima disto ele PERSEGUE; entre este e `distancia_de_recuo` ele POSICIONA.
##
## O estado do meio existe para os drones nao se empilharem. Sem ele, quatro
## drones convergem para o mesmo ponto em cima do jogador e os quatro aneis
## viram uma parede solida -- o oposto do padrao legivel que este inimigo
## existe para criar.
@export var distancia_de_posicionamento: float = 300.0
## Abaixo disto ele deixa de aproximar e passa a andar so de lado.
@export var distancia_de_recuo: float = 180.0
## Quanto do movimento lateral sobra depois de descontar a correcao radial.
## 1.0 e orbita pura; 0.0 e aproximacao pura.
@export var peso_lateral: float = 0.85

## Abaixo disto ele esta parando, nao andando. Sem um piso, o `move_toward` dos
## estados de recuo deixaria o ciclo de pernas tremendo por uma fracao de
## segundo depois de o drone ja ter travado no lugar.
const VELOCIDADE_ANDANDO := 12.0

const PERSEGUIR := &"PERSEGUIR"
const POSICIONAR := &"POSICIONAR"
const CARREGAR := &"CARREGAR"
const DISPARAR := &"DISPARAR"
const RECUPERAR := &"RECUPERAR"

var _maquina: MaquinaEstados
var _arma: Arma
var _aviso: Polygon2D
var _sprite: SpriteDirecional
var _t_intervalo: float = 0.0
## Para que lado ele contorna enquanto posiciona. Sorteado no nascimento, como o
## da Sentinela: dois drones lado a lado abrindo para o mesmo lado voltariam a
## se empilhar, so que mais devagar.
var _sentido_lateral: float = 1.0
## Rotacao do proximo anel, em graus. Ver `_proximo_offset()`.
var _offset_anel: float = 0.0


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
	_sentido_lateral = 1.0 if randf() < 0.5 else -1.0
	# O primeiro anel de cada drone comeca numa fase propria: quatro drones
	# alternando em uniso dariam duas paredes alternadas em vez de um padrao.
	_offset_anel = float(randi() % 2) * (_setor_do_anel() * 0.5)

	_maquina = MaquinaEstados.new(name)
	_maquina.adicionar(PERSEGUIR, _perseguir)
	_maquina.adicionar(POSICIONAR, _posicionar)
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
	# POSICIONAR entra aqui junto com PERSEGUIR, e a omissao seria o mesmo
	# defeito que a Cyber-Besta ja teve: ela circula em OBSERVAR, o estado foi
	# deixado de fora de "esta andando", e as patas congelavam exatamente onde
	# ela mais se desloca. O drone contorna em POSICIONAR pelo mesmo motivo.
	#
	# CARREGAR e RECUPERAR continuam de fora, e isso e o contrario de um
	# esquecimento: o corpo travado no lugar e METADE do telegrafo do anel.
	var se_desloca := _maquina.estado == PERSEGUIR or _maquina.estado == POSICIONAR
	var andando := se_desloca and velocity.length() > VELOCIDADE_ANDANDO
	_sprite.apontar(direcao_para_alvo(), andando, delta, velocity)


# ------------------------------------------------------------- estados ------

func _perseguir(delta: float) -> void:
	_t_intervalo -= delta * Deterioracao.multiplicador_cadencia()
	velocity = direcao_de_locomocao(direcao_para_alvo()) * velocidade_atual()
	if _pronto_para_o_anel():
		_maquina.trocar(CARREGAR)
		return
	if distancia_do_alvo() <= distancia_de_posicionamento:
		_maquina.trocar(POSICIONAR)


## Nem persegue nem para: contorna.
##
## Este e o estado que impede o empilhamento. A velocidade final soma uma
## componente TANGENCIAL -- andar de lado em volta do jogador -- com uma
## correcao radial pequena, que so age quando ele saiu da faixa. Dois drones com
## `_sentido_lateral` oposto se afastam sozinhos, sem nenhum precisar saber que
## o outro existe.
##
## A correcao e por FAIXA e nao por distancia exata: mirar um raio unico faria
## todos convergirem para a mesma circunferencia, que e o empilhamento de novo,
## so que em anel.
func _posicionar(delta: float) -> void:
	_t_intervalo -= delta * Deterioracao.multiplicador_cadencia()
	if _pronto_para_o_anel():
		_maquina.trocar(CARREGAR)
		return
	var distancia := distancia_do_alvo()
	if distancia > distancia_de_posicionamento:
		_maquina.trocar(PERSEGUIR)
		return

	var para_alvo := direcao_para_alvo()
	var tangente := para_alvo.orthogonal() * _sentido_lateral
	var radial := Vector2.ZERO
	if distancia < distancia_de_recuo:
		radial = -para_alvo
	elif distancia > distancia_de_posicionamento:
		radial = para_alvo
	var rumo := (tangente * peso_lateral + radial * (1.0 - peso_lateral)).normalized()
	velocity = direcao_de_locomocao(rumo) * velocidade_atual()


## O anel so sai com o intervalo vencido E dentro do alcance. Os dois estados de
## deslocamento perguntam a mesma coisa, entao ela mora num lugar so.
func _pronto_para_o_anel() -> bool:
	return _t_intervalo <= 0.0 and distancia_do_alvo() <= alcance_anel


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
	_arma.atirar_varias(Balistica.anel(projeteis, deg_to_rad(_proximo_offset())))
	EventBus.pedido_shake.emit(2.0, 0.12)


## A rotacao do proximo anel, alternando meio passo a cada disparo.
##
## Isto era `randf() * TAU`, e a troca nao e cosmetica -- ela muda o que o
## jogador pode APRENDER.
##
## Com rotacao aleatoria, dois aneis seguidos as vezes se intercalam e as vezes
## caem um sobre o outro. Nao ha nada a deduzir: o jogador so pode reagir ao que
## ja esta na tela. Com a alternancia fixa, o segundo anel cai SEMPRE nos vaos do
## primeiro -- entao o buraco de agora e a parede daqui a pouco, e isso e uma
## regra que da para dominar.
##
## Aleatorio e imprevisivel; alternado e dificil. So o segundo vira habilidade.
##
## O passo e meio setor: com oito projeteis o setor tem 45 graus e o
## deslocamento vira 22,5 -- exatamente o meio do vao. `fmod` pelo setor inteiro
## mantem o numero pequeno e faz o par alternar para sempre.
func _proximo_offset() -> float:
	var atual := _offset_anel
	var passo := _setor_do_anel()
	_offset_anel = fmod(_offset_anel + passo * 0.5, passo)
	return atual


## O setor entre dois bracos do anel, em graus. Sai da CONTAGEM e nao de uma
## constante: `projeteis` e ajustavel e a Deterioracao pode subi-lo, e um passo
## fixo de 22,5 deixaria de cair no meio do vao assim que a contagem mudasse.
func _setor_do_anel() -> float:
	return 360.0 / float(maxi(projeteis, 1))


func _disparar(_delta: float) -> void:
	if _maquina.passou(0.08):
		_maquina.trocar(RECUPERAR)


func _recuperar(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	if _maquina.passou(tempo_recuperacao):
		_t_intervalo = intervalo
		_maquina.trocar(PERSEGUIR)
