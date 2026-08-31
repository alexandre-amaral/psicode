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
## A pausa encarando, entre circular e agachar.
##
## Curta de propositio. Ela nao existe para dar tempo de reagir -- o agachamento
## de `PREPARAR` ja faz isso -- e sim para SEPARAR os dois momentos. Sem ela a
## besta sai de contornar e agacha no mesmo frame, e o jogador nao ve o instante
## em que ela escolheu ele.
@export var tempo_encarando: float = 0.3
## Quanto ele fica aberto depois de bater numa parede.
##
## E a principal janela de contra-ataque do inimigo, e sem ela a Cyber-Besta era
## pressao pura sem resposta: a investida terminava por tempo, acertasse ela o
## que acertasse. Errar a esquiva custava dano; ACERTAR nao rendia nada.
@export var tempo_atordoado: float = 1.0
## So investe a partir daqui. Longe demais a investida vira corrida.
@export var alcance: float = 420.0

const OBSERVAR := &"OBSERVAR"
const PREPARAR := &"PREPARAR"
## Abaixo disto ele esta parando, nao andando. Sem um piso, o `move_toward` da
## preparacao deixaria o ciclo de patas tremendo enquanto ele ja esta travado.
const VELOCIDADE_ANDANDO := 12.0

## Quanto ela fecha a distancia enquanto contorna, contra a componente lateral.
##
## Este numero E o antigo `para_alvo * 0.35 + orthogonal * 0.65`, escrito na
## forma que `Movimento.rumo_orbital` usa: 0,35/0,65. Mudar para 1,0 faria ela
## vir direto para cima do jogador em vez de contornar, e o estado perderia o
## nome.
const PESO_APROXIMACAO := 0.538

const ENCARAR := &"ENCARAR"
const INVESTIR := &"INVESTIR"
const RECUPERAR := &"RECUPERAR"
const ATORDOADO := &"ATORDOADO"

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
	_maquina.adicionar(ENCARAR, _encarar)
	_maquina.adicionar(PREPARAR, _preparar, _preparar_entrar, _preparar_sair)
	_maquina.adicionar(INVESTIR, _investir, _investir_entrar)
	_maquina.adicionar(RECUPERAR, _recuperar, _recuperar_entrar)
	_maquina.adicionar(ATORDOADO, _atordoado, _atordoado_entrar)
	_maquina.iniciar(OBSERVAR)


func _comportamento(delta: float) -> void:
	_maquina.processar(delta)
	tentar_dano_contato()


## O quadro que o corpo mostra.
##
## Roda em `_pos_movimento` porque aqui a `velocity` ja passou pelo
## `move_and_slide()` -- e o que decide se ele esta ANDANDO ou so escorregando
## contra uma parede no fim da investida.
##
## `andando` sai SO da velocidade, e nao do estado. Nao ha estado dele que se
## mexa e nao deva animar: PREPARAR e RECUPERAR freiam (as patas tem de
## desacelerar junto), INVESTIR corre, e OBSERVAR **circula o jogador** a ~53
## px/s -- observar aqui nao e ficar parado, e rondar. Uma versao anterior disto
## excluia OBSERVAR achando que sim, e as patas ficavam congeladas justo no
## estado em que ele passa mais tempo se deslocando.
func _pos_movimento(delta: float) -> void:
	# ANTES do retorno antecipado: a batida na parede e regra de combate, e nao
	# de arte. Deixa-la depois faria a besta com sprite ausente atravessar a
	# parede sem se atordoar -- um comportamento que dependeria de ter arte.
	_conferir_batida()
	if _sprite == null:
		return
	var andando := velocity.length() > VELOCIDADE_ANDANDO
	_sprite.apontar(_direcao_encarada(), andando, delta, velocity)


# ------------------------------------------------------------- estados ------

## Ele nao para: circula devagar, mantendo o jogador no campo de visao. Uma
## besta imovel por dois segundos parece bugada.
## `raio` zero, e nao um raio de orbita: ela CIRCULA FECHANDO.
##
## Com raio zero o erro e sempre positivo, entao a correcao radial aponta sempre
## para o jogador -- ela contorna enquanto se aproxima, que e o que este estado
## sempre fez. E ele nao e ficar parado: `OBSERVAR` e onde ela passa mais tempo
## se deslocando, e excluir este estado de "esta andando" congelaria as patas
## exatamente onde ela mais anda. Ja aconteceu.
func _observar(delta: float) -> void:
	Movimento.orbitar(self, delta, 0.0, 1.0, PESO_APROXIMACAO, 0.6, 900.0)
	if _maquina.passou(tempo_observando) and distancia_do_alvo() <= alcance:
		_maquina.trocar(ENCARAR)


## Ela para e vira para o jogador antes de agachar.
##
## O corpo travado e o sinal que se le de LONGE -- antes de o agachamento ficar
## visivel, e muito antes do rastro. E o instante em que ela escolheu voce, e
## ele precisa existir separado do preparo para o jogador poder ler os dois.
##
## Ela continua acompanhando o angulo aqui: a trava so acontece na transicao
## para INVESTIR, e adiantar isso tiraria do jogador a ultima chance de mudar de
## lado.
func _encarar(delta: float) -> void:
	Movimento.frear(self, delta, 2400.0)
	_direcao_travada = direcao_para_alvo()
	if _maquina.passou(tempo_encarando):
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
	Movimento.frear(self, delta, 2200.0)
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
	# `Movimento.investir` nao passa por `direcao_de_locomocao`, e isso e a
	# decisao e nao um atalho: durante a investida ela NAO desvia de nada. E o
	# que torna o ataque legivel, e o que faz a parede ser um recurso do jogador.
	Movimento.investir(self, _direcao_travada, velocidade_investida)
	if _maquina.passou(duracao_investida):
		_maquina.trocar(RECUPERAR)


## A batida.
##
## Roda em `_pos_movimento` porque so depois do `move_and_slide()` o
## `is_on_wall()` significa alguma coisa -- antes dele, o motor ainda nao tentou
## mover ninguem.
##
## Esta e a peca que faltava no inimigo. A investida terminava por TEMPO,
## acertasse ela o que acertasse: errar a esquiva custava dano ao jogador, e
## acertar nao rendia nada. Agora esquivar tem premio, e o premio e uma janela
## em que ela nao pode fazer nada.
##
## O jogador nao precisa saber que existe uma layer de parede -- ele so aprende
## que dar um passo para o lado no momento certo poe a besta contra o muro.
func _conferir_batida() -> void:
	if _maquina.estado != INVESTIR:
		return
	if is_on_wall():
		_maquina.trocar(ATORDOADO)


func _atordoado_entrar() -> void:
	velocity = Vector2.ZERO
	EventBus.pedido_shake.emit(5.0, 0.2)
	if _visual != null:
		# Achatamento no eixo da CORRIDA, e nao na horizontal da tela: e o mesmo
		# raciocinio do agachamento, e sem ele uma besta que bateu numa parede ao
		# norte apareceria amassada de lado.
		var t := create_tween()
		t.tween_property(_visual, "scale", _agachar(0.75, 1.3), 0.08)
		t.tween_property(_visual, "scale", Vector2.ONE, tempo_atordoado * 0.5)


func _atordoado(delta: float) -> void:
	Movimento.frear(self, delta, 4000.0)
	if _maquina.passou(tempo_atordoado):
		_maquina.trocar(OBSERVAR)


func _recuperar_entrar() -> void:
	if _visual != null:
		var t := create_tween()
		t.tween_property(_visual, "scale", _agachar(1.2, 0.8), 0.1)
		t.tween_property(_visual, "scale", Vector2.ONE, tempo_recuperacao * 0.6)


func _recuperar(delta: float) -> void:
	Movimento.frear(self, delta, 1100.0)
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
## ATORDOADO entra junto com INVESTIR, e nao e detalhe: atordoada contra a
## parede ela continua encarando PARA ONDE CORREU. Deixa-la virar para o jogador
## faria a pose ler como alerta -- exatamente o oposto da janela de
## contra-ataque que o estado existe para anunciar.
func _direcao_encarada() -> Vector2:
	var travada := _maquina.estado == INVESTIR or _maquina.estado == ATORDOADO
	var d := _direcao_travada if travada else direcao_para_alvo()
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
