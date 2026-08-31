extends InimigoBase
## AUTOMATO ENFERRUJADO -- o chefe do andar 1. Nome de codigo `boss_guardiao_01`,
## neutro de proposito, para nao amarrar a implementacao ao nome final.
##
## A IDENTIDADE, NUMA FRASE: **quanto mais danificado ele fica, mais rapido
## funciona.**
##
## Ele comeca pesado, enferrujado e quase incapaz de acompanhar o jogador. O dano
## nao o enfraquece -- remove a resistencia mecanica que a corrosao acumulou. Aos
## 2/3 o jogador percebe que ele nao era lento por design: estava travado. Aos
## 1/3, percebe o problema -- a maquina nao esta tentando sobreviver ao dano,
## esta usando a propria destruicao para funcionar acima do limite.
##
## A frase que o jogador deve pensar tres vezes, em fases diferentes:
## "eu ja conheco esse ataque, mas agora ele esta acontecendo mais rapido".
##
## POR QUE ELE E UM INIMIGO NOVO, E NAO UMA REFORMA DA DIRETORA. As duas
## identidades sao OPOSTAS, e uma delas e proibida por portao executavel: a
## trava 7 de `teste_diretora.gd` diz que ela NUNCA persegue, porque "um sistema
## nao corre atras de voce". O Automato faz o inverso -- ele investe, soca e
## pisa. Reformar a Diretora para caber nisso exigiria afrouxar o portao dela, e
## a personagem deixaria de existir sem uma linha no console. Ela continua
## intocada, e sai do andar 1 (BOSS 11).
##
## ESTA ISSUE E SO O ESQUELETO (BOSS 01): corpo, vida, tres fases e o
## multiplicador. Sem ataques. A ordem e deliberada -- se "perder vida muda
## visivelmente a velocidade" nao se sente com ele apenas andando, nenhum ataque
## vai salvar depois. Os estados de ataque ja existem porque a maquina inteira
## tem de estar de pe antes de a BOSS 03 pendurar o primeiro soco nela.

## As tres fases, por FRACAO de vida.
##
## Os limiares sao fracao e nao valor absoluto de proposito: mexer na vida do
## chefe na sessao de tuning nao pode reescrever onde as viradas acontecem.
const LIMIAR_DESTRAVADO := 0.67
const LIMIAR_SOBRECARGA := 0.34

## O PISO de todo tempo derivado do multiplicador.
##
## E o mesmo numero que o `Telegrafo` crava e que a Diretora chama de
## `TELEGRAFO_MINIMO` -- e tem de ser o mesmo, senao a fronteira entre "dificil"
## e "mente sobre a propria regra" passa a ter duas posicoes no mesmo jogo.
##
## O pior caso NAO e o multiplicador de fase 3 sozinho: a Deterioracao multiplica
## dificuldade POR CIMA dele e chega a 1,7x em cadencia. `tempo_real()` divide
## pelos dois e so entao aplica o piso, entao o numero cobrado e o do pior caso
## de verdade -- 1,30 combinado com a barra cheia.
const TEMPO_MINIMO := Telegrafo.DURACAO_MINIMA

const IDLE := &"IDLE"
const ESCOLHER_ATAQUE := &"ESCOLHER_ATAQUE"
const PREPARAR := &"PREPARAR"
const EXECUTAR := &"EXECUTAR"
const RECUPERAR := &"RECUPERAR"
const TRANSICAO_FASE := &"TRANSICAO_FASE"
const ATORDOADO := &"ATORDOADO"
const MORTE := &"MORTE"

@export_group("Fases")
## O multiplicador de cada fase. E o botao central do chefe inteiro: ele alcanca
## movimentacao, cadencia, telegrafo, recuperacao e rotacao de uma vez.
##
## Se ele valesse so para a movimentacao, o jogador veria um robo andando rapido
## com ataques no mesmo ritmo -- e a ideia inteira nao chega.
@export var mult_enferrujado: float = 0.75
@export var mult_destravado: float = 1.0
@export var mult_sobrecarga: float = 1.30

@export_group("Ritmo")
## Quanto ele leva escolhendo o proximo ataque. E a respiracao entre golpes.
@export var tempo_escolha: float = 0.5
## O telegrafo. Encurta com a fase, e nunca abaixo de `TEMPO_MINIMO`.
@export var tempo_preparo: float = 0.8
@export var tempo_execucao: float = 0.4
## A janela de punicao depois do golpe.
@export var tempo_recuperacao: float = 1.0
## A virada de fase. Ele trava, a maquina reassenta, e SO ENTAO volta a atacar.
@export var tempo_transicao: float = 1.2
@export var tempo_atordoado: float = 1.2

## 1, 2 ou 3. Publico porque a HUD, o tuning e as suites leem daqui.
var fase_chefe: int = 1

var _maquina: MaquinaEstados
## A maior fase ja anunciada. E a bandeira que faz cada transicao acontecer UMA
## vez: sem ela, o HP oscilando em volta do limiar -- e ele oscila, porque a
## vida cai a cada tiro -- reentraria em TRANSICAO_FASE para sempre, e o chefe
## nunca mais atacaria.
var _fase_anunciada: int = 1


func _ready() -> void:
	super._ready()

	_maquina = MaquinaEstados.new(name)
	_maquina.adicionar(IDLE, _idle)
	_maquina.adicionar(ESCOLHER_ATAQUE, _escolher)
	_maquina.adicionar(PREPARAR, _preparar)
	_maquina.adicionar(EXECUTAR, _executar)
	_maquina.adicionar(RECUPERAR, _recuperar)
	_maquina.adicionar(TRANSICAO_FASE, _transicao, _transicao_entrar)
	_maquina.adicionar(ATORDOADO, _atordoado)
	_maquina.adicionar(MORTE, _morte)
	_maquina.iniciar(IDLE)


## Ver `DadosInimigo`. Os numeros de ritmo dele saem do recurso pelo mesmo
## caminho dos cinco inimigos comuns (INIM 08) -- a sessao de tuning gira o
## chefe sem abrir cena.
func _ler_dados(d: DadosInimigo) -> void:
	tempo_escolha = d.cooldown_ataque
	tempo_preparo = d.tempo_telegrafo
	tempo_recuperacao = d.tempo_recuperacao


func _comportamento(delta: float) -> void:
	_checar_fase()
	_maquina.processar(delta)


# --------------------------------------------------------- o multiplicador --

## A fase que a vida ATUAL pede. Pura: nao muda nada, so responde.
func fase_por_vida() -> int:
	var fracao := float(vida) / float(maxi(vida_maxima, 1))
	if fracao > LIMIAR_DESTRAVADO:
		return 1
	if fracao > LIMIAR_SOBRECARGA:
		return 2
	return 3


## O multiplicador da fase, sozinho. E o numero que a ficcao promete.
func multiplicador_de(fase: int) -> float:
	match fase:
		1: return mult_enferrujado
		2: return mult_destravado
		3: return mult_sobrecarga
	return mult_destravado


func multiplicador() -> float:
	return multiplicador_de(fase_chefe)


## Tudo que acelera o chefe, junto: a fase E a Deterioracao.
##
## Existe como funcao propria porque e ELE, e nao o multiplicador de fase, o
## numero contra o qual o piso tem de ser calculado. Cobrar o piso so contra 1,30
## deixaria a barra cheia furar o piso por baixo, sem erro nenhum.
func multiplicador_total() -> float:
	return multiplicador() * Deterioracao.multiplicador_cadencia()


## Converte um tempo de projeto no tempo REAL desta fase, com piso.
##
## Todo tempo do chefe passa por aqui -- telegrafo, execucao, recuperacao,
## escolha, transicao. E o que faz o moveset ficar reconhecivel e mais rapido em
## vez de virar outro moveset: os mesmos gestos, na mesma ordem, comprimidos.
func tempo_real(base: float) -> float:
	return maxf(base / maxf(multiplicador_total(), 0.01), TEMPO_MINIMO)


## A velocidade dele agora. Sobrescreve a base para somar o multiplicador de
## fase ao da Deterioracao, e nada guarda o produto -- perder vida no meio de um
## passo ja acelera aquele passo.
func velocidade_atual() -> float:
	return velocidade_base * Deterioracao.multiplicador_velocidade() * multiplicador()


func em_transicao() -> bool:
	return _maquina.estado == TRANSICAO_FASE


# ------------------------------------------------------------ as viradas ----

## Entra em TRANSICAO_FASE quando a vida cruza um limiar, uma vez por virada.
##
## NAO troca de fase durante a propria transicao nem depois de morto: no
## primeiro caso a virada se reiniciaria a cada frame em que o dano continuasse
## chegando, e o chefe ficaria preso no gesto de virar.
func _checar_fase() -> void:
	if morto or em_transicao():
		return
	var pedida := fase_por_vida()
	if pedida <= _fase_anunciada:
		return
	_fase_anunciada = pedida
	_maquina.trocar(TRANSICAO_FASE)


## A fase so muda AQUI, na entrada da transicao -- e nao no instante em que o HP
## cruza o limiar.
##
## A diferenca importa: se `fase_chefe` subisse no `_checar_fase`, o ataque em
## curso terminaria com o timing da fase NOVA no meio do proprio gesto. O
## jogador leria o telegrafo de uma fase e levaria o golpe de outra, que e a
## definicao de mentir sobre a propria regra.
func _transicao_entrar() -> void:
	fase_chefe = _fase_anunciada
	EventBus.pedido_shake.emit(6.0, 0.35)


func _transicao(delta: float) -> void:
	Movimento.frear(self, delta, 2000.0)
	if _maquina.passou(tempo_real(tempo_transicao)):
		_maquina.trocar(ESCOLHER_ATAQUE)


# ------------------------------------------------------------- os estados ---

## Espera o jogador aparecer. Sem alvo ele nao tem para onde ir.
func _idle(delta: float) -> void:
	Movimento.frear(self, delta, 1200.0)
	if alvo != null and is_instance_valid(alvo):
		_maquina.trocar(ESCOLHER_ATAQUE)


## Anda para cima do jogador enquanto decide.
##
## PERSEGUIR e a diferenca inteira entre ele e a Diretora, e e onde o
## multiplicador de fase aparece primeiro: e andando que o jogador percebe que
## ele destravou, antes de qualquer ataque existir. Por isso a BOSS 01 e so isto.
func _escolher(delta: float) -> void:
	Movimento.perseguir(self, delta, 1.0, 900.0)
	if alvo == null or not is_instance_valid(alvo):
		_maquina.trocar(IDLE)
		return
	if _maquina.passou(tempo_real(tempo_escolha)):
		_maquina.trocar(PREPARAR)


## O telegrafo. Ele trava o corpo, e o corpo travado E metade do aviso.
##
## O ataque ainda nao existe (BOSS 03 a 08 penduram aqui): o que existe e a
## janela, ja com o tempo da fase e ja com o piso.
func _preparar(delta: float) -> void:
	Movimento.frear(self, delta, 2400.0)
	if _maquina.passou(tempo_real(tempo_preparo)):
		_maquina.trocar(EXECUTAR)


func _executar(delta: float) -> void:
	Movimento.frear(self, delta, 1800.0)
	if _maquina.passou(tempo_real(tempo_execucao)):
		_maquina.trocar(RECUPERAR)


## A janela de punicao. Ela encolhe com a fase junto com todo o resto -- e por
## isso a fase 3 e mais perigosa sem um numero de dano ter mudado.
func _recuperar(delta: float) -> void:
	Movimento.frear(self, delta, 900.0)
	if _maquina.passou(tempo_real(tempo_recuperacao)):
		_maquina.trocar(ESCOLHER_ATAQUE)


func _atordoado(delta: float) -> void:
	Movimento.frear(self, delta, 3000.0)
	if _maquina.passou(tempo_real(tempo_atordoado)):
		_maquina.trocar(ESCOLHER_ATAQUE)


func _morte(delta: float) -> void:
	Movimento.frear(self, delta, 4000.0)


## A vitoria da run NAO sai daqui, e isso e deliberado.
##
## Quem chama `GameState.terminar_run(true)` e o `GerenciadorMapa`, quando a
## sala do tipo `boss` fica LIMPA -- e a sala fica limpa pela morte de quem ela
## colocou. Trocar o chefe do andar (BOSS 11) nao mexe nesse caminho, e e bom que
## seja assim: a chamada ja se perdeu uma vez neste projeto ao trocar quem
## hospeda a run, e o sintoma foi silencioso.
func morrer() -> void:
	if morto:
		return
	if _maquina != null:
		_maquina.trocar(MORTE)
	EventBus.pedido_shake.emit(10.0, 0.6)
	super.morrer()
