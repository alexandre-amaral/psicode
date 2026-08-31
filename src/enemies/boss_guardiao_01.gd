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
## O MOVESET NAO E SUBSTITUIDO ENTRE FASES (BOSS 03 a 06). Os mesmos quatro
## ataques ficam reconheciveis e mais rapidos, e cada um ganha uma camada por
## fase em vez de virar outro ataque -- e essa continuidade que faz a mecanica de
## velocidade ENSINAR em vez de surpreender. Um moveset trocado a cada terco
## seria tres chefes curtos em sequencia, e o jogador nao teria o que dominar.
##
## | ataque   | fase 1            | fase 2                  | fase 3                    |
## |----------|-------------------|-------------------------|---------------------------|
## | SOCO     | uma onda frontal  | leque de tres           | dois golpes, um telegrafo cada |
## | RAJADA   | um leque de 5     | dois, o segundo nos vaos| tres, cada um nos vaos do anterior |
## | INVESTIDA| uma               | ate duas                | ate tres, e recuperacao grande |
## | PISAO    | anel de 8         | anel girado meio setor  | dois aneis intercalados   |

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

const CENA_AREA := preload("res://src/enemies/area_de_perigo.tscn")

## O repertorio. Ele so CRESCE com a fase (a BOSS 08 acrescenta a Falha do
## Reator na 3) -- ataque que some faria o jogador desaprender.
const SOCO := &"SOCO"
const RAJADA := &"RAJADA"
const INVESTIDA := &"INVESTIDA"
const PISAO := &"PISAO"
const REPERTORIO: Array[StringName] = [SOCO, RAJADA, INVESTIDA, PISAO]

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

@export_group("Soco Hidraulico")
## Onde o punho cai, a frente dele.
@export var alcance_soco: float = 92.0
@export var raio_soco: float = 78.0
## Quanto o segundo golpe da fase 3 desloca para o outro lado. E o que faz o par
## ser "esquerdo e direito" e nao "o mesmo golpe duas vezes".
@export var desvio_do_segundo_golpe: float = 46.0
## Abertura do leque de ondas, a partir da fase 2. -25 / 0 / +25.
@export var abertura_onda: float = 50.0

@export_group("Rajada de Sucata")
@export var projeteis_rajada: int = 5
@export var abertura_rajada: float = 60.0
## Espaco entre duas rajadas da mesma salva.
@export var intervalo_rajada: float = 0.28

@export_group("Investida Pesada")
@export var velocidade_investida: float = 620.0
@export var duracao_investida: float = 0.5
## Quanto ele fica aberto depois de bater na parede. E a melhor janela de dano.
@export var tempo_atordoado_parede: float = 1.6

@export_group("Pisao")
@export var projeteis_pisao: int = 8
## Espaco entre as duas ondas da fase 3. Curto: elas tem de ler como UM ataque.
@export var intervalo_pisao: float = 0.25

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

## O ataque em curso, e o que ele ainda tem para fazer.
var _ataque: StringName = SOCO
## Sobe a cada ataque escolhido. Alimenta a alternancia deterministica das
## salvas -- ver `Balistica.alternancia()`.
var _indice_salva: int = 0
## Quantos beats do ataque atual ja sairam: rajadas de uma salva, aneis de um
## pisao, investidas de uma sequencia.
var _beats: int = 0
## Quantos golpes de soco ainda faltam nesta sequencia. Fase 3 pede dois, e cada
## um com telegrafo PROPRIO -- por isso ele volta a PREPARAR em vez de repetir
## dentro de EXECUTAR.
var _golpes_restantes: int = 1
## Travada em PREPARAR e NAO atualizada durante a execucao. E a regra que torna
## a investida justa, e a mesma que a Cyber-Besta ja segue: investida que
## persegue durante a execucao nao da para esquivar, so para sobreviver.
var _direcao_travada: Vector2 = Vector2.RIGHT
## A duracao do telegrafo DESTE ataque, fixada na entrada.
##
## Fixada e nao relida todo frame porque a barra sobe durante o proprio
## telegrafo: relendo, o aviso encolheria enquanto o jogador o le, e o alvo do
## telegrafo e justamente ser previsivel.
var _aviso_atual: float = 0.0
var _arma_onda: Arma
var _arma_sucata: Arma
var _braco: Node2D
## As areas que ele semeou e que ainda vivem. Ver `morrer()`.
var _areas: Array[Node] = []


func _ready() -> void:
	super._ready()

	_braco = $Braco
	_arma_onda = $Braco/ArmaOnda
	_arma_onda.hostil = true
	_arma_sucata = $Braco/ArmaSucata
	_arma_sucata.hostil = true

	_maquina = MaquinaEstados.new(name)
	_maquina.adicionar(IDLE, _idle)
	_maquina.adicionar(ESCOLHER_ATAQUE, _escolher)
	_maquina.adicionar(PREPARAR, _preparar, _preparar_entrar)
	_maquina.adicionar(EXECUTAR, _executar, _executar_entrar)
	_maquina.adicionar(RECUPERAR, _recuperar)
	_maquina.adicionar(TRANSICAO_FASE, _transicao, _transicao_entrar)
	_maquina.adicionar(ATORDOADO, _atordoado, _atordoado_entrar)
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
	# A velocidade de projetil le a Deterioracao no frame, como em todo inimigo.
	_arma_onda.multiplicador_velocidade = Deterioracao.multiplicador_velocidade_projetil()
	_arma_sucata.multiplicador_velocidade = Deterioracao.multiplicador_velocidade_projetil()
	_maquina.processar(delta)


## A batida na parede.
##
## Roda em `_pos_movimento` porque so depois do `move_and_slide()` o
## `is_on_wall()` significa alguma coisa -- antes dele o motor ainda nao tentou
## mover ninguem. Parede e detectada por LAYER e nao por grupo: as paredes
## geradas por `sala.gd` e `corredor.gd` nao entram em grupo nenhum, e o teste
## antigo por grupo foi o que deixava projetil atravessar parede.
func _pos_movimento(_delta: float) -> void:
	if _maquina == null or _maquina.estado != EXECUTAR or _ataque != INVESTIDA:
		return
	if is_on_wall():
		_maquina.trocar(ATORDOADO)


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
		_escolher_ataque()
		_maquina.trocar(PREPARAR)


## Qual ataque vem agora.
##
## PROVISORIO, e declarado como tal: a BOSS 09 troca isto por selecao com peso,
## distancia e memoria. Ate la, o rodizio -- e nao o sorteio -- porque um
## repertorio sorteado pode repetir o mesmo ataque quatro vezes e esconder que os
## outros tres nunca foram exercitados. O rodizio garante que TODO ataque roda
## em toda luta, que e o que as suites e a arena precisam enquanto o resto do
## chefe nao existe.
func _escolher_ataque() -> void:
	_ataque = REPERTORIO[_indice_salva % REPERTORIO.size()]
	_indice_salva += 1
	_golpes_restantes = _golpes_do_soco() if _ataque == SOCO else 1


## O telegrafo. Ele trava o corpo, e o corpo travado E metade do aviso.
##
## A direcao e travada AQUI e nao e mais atualizada -- vale para os quatro
## ataques, e e o que torna a investida justa. A duracao tambem e fixada aqui:
## relida todo frame, ela encolheria enquanto o jogador le o aviso.
func _preparar_entrar() -> void:
	_aviso_atual = tempo_real(tempo_preparo)
	_beats = 0
	var d := direcao_para_alvo()
	if d.length_squared() > 0.01:
		_direcao_travada = d
	if _ataque == SOCO:
		_semear_aviso_do_soco()


func _preparar(delta: float) -> void:
	Movimento.frear(self, delta, 2400.0)
	if _maquina.passou(_aviso_atual):
		_maquina.trocar(EXECUTAR)


func _executar_entrar() -> void:
	_beats = 0
	match _ataque:
		SOCO:
			_bater()
		RAJADA, PISAO:
			_disparar_beat()
		INVESTIDA:
			EventBus.pedido_shake.emit(4.0, 0.18)


## A execucao de cada ataque. Os beats -- rajadas de uma salva, aneis de um
## pisao -- saem daqui, e o tempo entre eles tambem passa por `tempo_real()`:
## na fase 3 a mesma sequencia acontece comprimida, que e a frase inteira do
## chefe.
func _executar(delta: float) -> void:
	match _ataque:
		INVESTIDA:
			Movimento.investir(self, _direcao_travada, velocidade_investida)
			if _maquina.passou(tempo_real(duracao_investida)):
				_fim_da_investida()
			return
		RAJADA, PISAO:
			Movimento.frear(self, delta, 1800.0)
			var intervalo := tempo_real(intervalo_rajada if _ataque == RAJADA else intervalo_pisao)
			if _beats < _beats_do_ataque() and _maquina.passou(intervalo * float(_beats)):
				_disparar_beat()
			if _maquina.passou(intervalo * float(_beats_do_ataque())):
				_maquina.trocar(RECUPERAR)
			return
		_:
			Movimento.frear(self, delta, 1800.0)

	if not _maquina.passou(tempo_real(tempo_execucao)):
		return
	# O soco da fase 3 sao DOIS golpes, e cada um volta a PREPARAR: a issue pede
	# telegrafo por golpe, e repetir dentro de EXECUTAR daria o segundo de graca.
	_golpes_restantes -= 1
	if _ataque == SOCO and _golpes_restantes > 0:
		_maquina.trocar(PREPARAR)
		return
	_maquina.trocar(RECUPERAR)


## A janela de punicao. Ela encolhe com a fase junto com todo o resto -- e por
## isso a fase 3 e mais perigosa sem um numero de dano ter mudado.
func _recuperar(delta: float) -> void:
	Movimento.frear(self, delta, 900.0)
	if _maquina.passou(tempo_real(tempo_recuperacao)):
		_maquina.trocar(ESCOLHER_ATAQUE)


# -------------------------------------------------------- SOCO HIDRAULICO ---

## O aviso do soco e uma `AreaDePerigo` no chao, com o tempo do telegrafo.
##
## Ela e reusada em vez de um circulo proprio, e a economia nao e de linhas: a
## `AreaDePerigo` ja carrega as tres armadilhas registradas deste ataque
## resolvidas. Ela nao estoura no `_ready` (o estouro sai de `configurar()`, e e
## sincrono); ela varre com `intersect_shape` no espaco direto em vez de
## `get_overlapping_bodies()`, que responderia com o passo de fisica anterior e
## voltaria vazia; e o aviso dela desenha na faixa do mundo pelo `Telegrafo`.
## Escrever um circulo proprio aqui seria reencenar os tres bugs.
##
## Ela nasce no container da SALA e nao como filha dele: filha, ela andaria com o
## chefe -- e aviso no chao que se move e aviso que mente.
func _semear_aviso_do_soco() -> void:
	var container := get_parent()
	if container == null:
		return
	var area: AreaDePerigo = CENA_AREA.instantiate()
	area.tempo_aviso = _aviso_atual
	area.tempo_dano = tempo_real(tempo_execucao)
	area.cor = cor_base
	container.add_child(area)
	area.configurar(_ponto_do_soco(), raio_soco, dano_contato)
	_areas.append(area)


## Onde o punho cai. Na fase 3 o segundo golpe sai deslocado para o outro lado,
## que e o que faz o par ser "esquerdo e direito".
func _ponto_do_soco() -> Vector2:
	var frente := global_position + _direcao_travada * alcance_soco
	if _golpes_restantes >= 2:
		return frente + _direcao_travada.orthogonal() * desvio_do_segundo_golpe
	if _ataque == SOCO and _golpes_do_soco() >= 2:
		return frente - _direcao_travada.orthogonal() * desvio_do_segundo_golpe
	return frente


## A onda de choque. Quem cobra o dano do IMPACTO e a area semeada no telegrafo;
## isto aqui e o que sai dele para a frente.
func _bater() -> void:
	EventBus.pedido_shake.emit(7.0, 0.25)
	var direcoes := Balistica.leque(_direcao_travada, _ondas_do_soco(), abertura_onda)
	_arma_onda.atirar_varias(direcoes)


## Uma onda na fase 1, tres a partir da 2. Ele nao vira outro ataque: vira uma
## versao mais eficiente do mesmo.
func _ondas_do_soco() -> int:
	return 1 if fase_chefe <= 1 else 3


## Dois golpes na fase 3, um antes.
func _golpes_do_soco() -> int:
	return 2 if fase_chefe >= 3 else 1


# ------------------------------------------- RAJADA DE SUCATA e PISAO -------

## Quantos beats esta salva tem: rajadas de sucata, ou aneis de pisao.
func _beats_do_ataque() -> int:
	match _ataque:
		RAJADA:
			return mini(fase_chefe, 3)
		PISAO:
			return 2 if fase_chefe >= 3 else 1
	return 1


## Um beat da salva, ja girado pela alternancia deterministica.
##
## `atirar_varias` e obrigatorio e nao preferencia: um `for` com `atirar()`
## sairia com UM projetil, porque `_t_cadencia` e setado no primeiro tiro e
## `pode_atirar()` recusa o resto -- o `_process` que decrementa nao roda no meio
## do laco. Foi este mesmo defeito que fez o anel da Diretora sair com um
## projetil.
func _disparar_beat() -> void:
	var giro := deg_to_rad(_giro_do_beat())
	if _ataque == PISAO:
		_arma_sucata.atirar_varias(Balistica.anel(projeteis_pisao, giro))
	else:
		_arma_sucata.atirar_varias(
			Balistica.leque(_direcao_travada.rotated(giro), projeteis_rajada, abertura_rajada)
		)
	EventBus.pedido_shake.emit(3.0, 0.12)
	_beats += 1


## De quantos graus este beat sai girado.
##
## A conta e a mesma -- meio vao --, mas o VAO nao: o anel do pisao divide 360
## pela contagem, e o leque da rajada divide a ABERTURA por `contagem - 1`. Usar
## o passo do anel no leque gira demais, e a segunda rajada cai EM CIMA da
## primeira em vez de nos vaos dela. Foi o defeito da primeira versao disto, e o
## unico sintoma era o padrao nao aparecer.
func _giro_do_beat() -> float:
	var indice := _indice_salva + _beats
	if _ataque == PISAO:
		return Balistica.alternancia(projeteis_pisao, indice)
	return Balistica.alternancia_de_passo(
		Balistica.passo_do_leque(projeteis_rajada, abertura_rajada), indice
	)


# ------------------------------------------------------- INVESTIDA PESADA ---

## Fim de uma investida: encadeia outra, ou recupera.
##
## A fase 3 encadeia ate tres e SO ENTAO recupera, e a recuperacao dela e a
## melhor janela de dano da luta -- e o pagamento por um ataque que atravessa a
## sala. Entre uma investida e a seguinte ele volta a PREPARAR, entao a direcao e
## RECALCULADA e telegrafada de novo: sem isso a segunda sairia sem aviso.
func _fim_da_investida() -> void:
	_beats += 1
	if _beats < _investidas_da_fase():
		_maquina.trocar(PREPARAR)
		return
	_maquina.trocar(RECUPERAR)


func _investidas_da_fase() -> int:
	return clampi(fase_chefe, 1, 3)


## Bater na parede e a janela de contra-ataque. Ela e mais longa que o
## atordoamento comum de proposito: errar a investida tem de RENDER ao jogador,
## senao acertar a esquiva nao vale nada e a investida vira pressao pura.
func _atordoado_entrar() -> void:
	velocity = Vector2.ZERO
	EventBus.pedido_shake.emit(6.0, 0.3)


func _atordoado(delta: float) -> void:
	Movimento.frear(self, delta, 3000.0)
	var espera := tempo_atordoado_parede if _ataque == INVESTIDA else tempo_atordoado
	if _maquina.passou(tempo_real(espera)):
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
	# Aviso no chao tem de morrer com quem o pediu: um circulo que sobrevive ao
	# chefe cobra dano depois de a luta ter acabado, e o jogador nao tem como
	# atribuir aquilo a nada. Mesma licao do Parasita e da Diretora.
	for a in _areas:
		if is_instance_valid(a):
			a.queue_free()
	_areas.clear()
	if _maquina != null:
		_maquina.trocar(MORTE)
	EventBus.pedido_shake.emit(10.0, 0.6)
	super.morrer()
