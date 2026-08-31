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
## Para quantos bracos o anel cresce com a barra cheia. Negativo desliga.
##
## E o escalonamento por COMPORTAMENTO dele (INIM 09): o anel de 8 tem vao de 45
## graus e o de 12 tem 30, entao o mesmo ataque passa a exigir uma leitura mais
## fina em vez de so doer mais.
@export var projeteis_avancados: int = 12

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
## Duracao do aviso DESTA carga, fixada na entrada do estado.
##
## Fixada e nao recalculada todo frame porque a barra sobe durante a propria
## carga: recalcular faria o aviso encolher enquanto o jogador o le, e o alvo
## do telegrafo e justamente ser previsivel.
var _aviso_atual: float = 0.0
## Indice do proximo anel. Ver `_proximo_offset()`.
var _indice_anel: int = 0


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
	_indice_anel = randi() % 2

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



## Ver `DadosInimigo`. Os nomes locais sao os do DOMINIO dele -- "anel",
## "posicionamento" -- e os do recurso sao os genericos; a traducao mora aqui,
## num lugar so.
func _ler_dados(d: DadosInimigo) -> void:
	tempo_carga = d.tempo_telegrafo
	tempo_recuperacao = d.tempo_recuperacao
	intervalo = d.cooldown_ataque
	alcance_anel = d.alcance
	projeteis = d.projeteis
	projeteis_avancados = d.projeteis_avancados
	distancia_de_posicionamento = d.distancia_preferida
	distancia_de_recuo = d.distancia_minima
	peso_lateral = d.peso_lateral

# ------------------------------------------------------------- estados ------

func _perseguir(delta: float) -> void:
	_t_intervalo -= delta * Deterioracao.multiplicador_cadencia()
	Movimento.perseguir(self, delta)
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

	# `orbitar_na_faixa` e a forma de FAIXA do vocabulario (INIM 07), e e ela e
	# nao a de raio exato que este estado precisa -- ver o paragrafo acima.
	Movimento.orbitar_na_faixa(
		self, delta, distancia_de_recuo, distancia_de_posicionamento,
		_sentido_lateral, peso_lateral
	)


## O anel so sai com o intervalo vencido E dentro do alcance. Os dois estados de
## deslocamento perguntam a mesma coisa, entao ela mora num lugar so.
func _pronto_para_o_anel() -> bool:
	return _t_intervalo <= 0.0 and distancia_do_alvo() <= alcance_anel


## Trava no lugar e acende o aviso. O corpo parado E parte do telegrafo: e o
## sinal que se le de longe, antes mesmo de o circulo ficar visivel.
func _carregar_entrar() -> void:
	_aviso_atual = duracao_do_telegrafo(tempo_carga)
	_aviso.visible = true
	_aviso.scale = Vector2(0.2, 0.2)
	_aviso.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_aviso, "scale", Vector2.ONE, _aviso_atual)
	t.parallel().tween_property(_aviso, "modulate:a", 0.55, _aviso_atual * 0.8)


func _carregar(delta: float) -> void:
	Movimento.frear(self, delta, 1600.0)
	if _maquina.passou(_aviso_atual):
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
	_arma.atirar_varias(Balistica.anel(_projeteis_agora(), deg_to_rad(_proximo_offset())))
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
## deslocamento vira 22,5 -- exatamente o meio do vao.
##
## A CONTA saiu daqui para `Balistica.alternancia()` (BOSS 06): o chefe pede a
## mesma coisa na rajada e no pisao, e tres copias divergiriam. O que sobra aqui
## e o indice, que e estado do drone e nao matematica.
func _proximo_offset() -> float:
	var atual := Balistica.alternancia(_projeteis_agora(), _indice_anel)
	_indice_anel += 1
	return atual


## O setor entre dois bracos do anel, em graus.
func _setor_do_anel() -> float:
	return Balistica.setor(_projeteis_agora())


## Quantos bracos o anel tem AGORA. Lido no frame: com a barra subindo entre dois
## disparos, o segundo anel ja sai mais fechado.
func _projeteis_agora() -> int:
	return Deterioracao.escalonar_int(projeteis, projeteis_avancados)


func _disparar(_delta: float) -> void:
	if _maquina.passou(0.08):
		_maquina.trocar(RECUPERAR)


func _recuperar(delta: float) -> void:
	Movimento.frear(self, delta, 900.0)
	if _maquina.passou(tempo_recuperacao):
		_t_intervalo = intervalo
		_maquina.trocar(PERSEGUIR)
