extends InimigoBase
## SENTINELA ORBITAL -- circula o jogador a distancia fixa e pontua com tiros.
##
## Ele nao ameaca sozinho: um tiro pequeno de vez em quando nao mata ninguem. O
## que ele faz e OCUPAR o espaco em volta do jogador, tirando dele a esquiva
## lateral -- que e a saida barata contra quase tudo no jogo. Com uma sentinela
## girando, andar de lado passa a levar voce para dentro do proximo tiro.
##
## Por isso ele e um inimigo de composicao: sozinho e chato, em dupla com um
## Rastejante ele fecha o campo. E por isso o custo dele no orcamento e baixo.
##
## A orbita e o `direcao.orthogonal()` -- perpendicular a direcao do jogador, o
## mesmo `rotated(PI/2)` de sempre e a mesma conta que o Vigia usa para o
## strafe. A diferenca e que aqui ela e o comportamento inteiro, e nao um
## intervalo entre disparos.

@export_group("Orbita")
@export var raio_orbita: float = 190.0
## Tolerancia do raio. Sem ela a sentinela oscila entrando e saindo.
@export var margem: float = 30.0
## Peso do ajuste radial contra o tangencial. Alto demais e ela vai e vem em vez
## de circular; baixo demais e ela nunca chega no raio.
@export var correcao_radial: float = 0.55

@export_group("Disparo")
@export var intervalo: float = 1.5
## Clarao no cano antes do tiro. Curto, porque o tiro e fraco -- telegrafo longo
## para dano pequeno vira ruido, nao leitura.
@export var tempo_clarao: float = 0.28

@export_group("Rajada")
## Quantos tiros unicos saem antes de uma rajada. Zero desliga a rajada.
##
## Ela existe para quebrar o RITMO. Com tiro unico a intervalo fixo o jogador
## encontra uma cadencia de orbita e fica nela; a rajada obriga a mudar a
## movimentacao no meio do circulo, que e a pergunta que esta inimiga faz.
@export var tiros_ate_rajada: int = 3
@export var projeteis_rajada: int = 3
## Abertura TOTAL do leque, em graus. 24 da -12 / 0 / +12.
@export var abertura_rajada: float = 24.0
## Quanto o aviso da rajada dura a mais que o do tiro unico.
##
## Nao e enfeite: a regra do projeto e "quanto mais forte o ataque, maior o
## telegrafo". Se a rajada avisasse igual ao tiro unico, o jogador nao teria
## como saber qual esta vindo -- e um ataque que nao da para distinguir do
## outro nao da para preparar.
@export var fator_aviso_rajada: float = 1.6

const APROXIMAR := &"APROXIMAR"
const ORBITAR := &"ORBITAR"
const DISPARAR := &"DISPARAR"

var _maquina: MaquinaEstados
var _arma: Arma
var _clarao: Polygon2D
var _t_intervalo: float = 0.0
## Quantos tiros unicos ainda faltam para a proxima rajada. Comeca sorteado para
## duas sentinelas na mesma sala nao rajarem no mesmo momento -- duas rajadas
## simultaneas viram seis projeteis, que e outro ataque.
var _ate_rajada: int = 0
## Sentido da orbita. Sorteado no nascimento: duas sentinelas girando para lados
## opostos fecham o campo de verdade.
var _sentido: float = 1.0
var _sprite: SpriteDirecional = null
## O que gira: a boca da arma e o clarao. NAO e o `_visual`.
var _torre: Node2D = null


## Abaixo disto ela esta parando, nao orbitando.
const VELOCIDADE_ANDANDO := 12.0
## Quanto o clarao cresce a mais quando a proxima salva e rajada. E o unico
## sinal que o jogador tem para distinguir os dois ataques, entao ele e visivel
## de proposito.
const ESCALA_CLARAO_RAJADA := 1.9


func _ready() -> void:
	super._ready()
	_torre = $Torre
	_sprite = $Visual/Corpo
	_arma = $Torre/Arma
	_arma.hostil = true
	_clarao = $Torre/Clarao
	_clarao.visible = false
	_sentido = 1.0 if randf() < 0.5 else -1.0
	_ate_rajada = randi_range(0, maxi(tiros_ate_rajada, 0))
	_t_intervalo = randf_range(0.3, intervalo)

	_maquina = MaquinaEstados.new(name)
	_maquina.adicionar(APROXIMAR, _aproximar)
	_maquina.adicionar(ORBITAR, _orbitar)
	_maquina.adicionar(DISPARAR, _disparar, _disparar_entrar, _disparar_sair)
	_maquina.iniciar(APROXIMAR)


func _comportamento(delta: float) -> void:
	_arma.multiplicador_velocidade = Deterioracao.multiplicador_velocidade_projetil()
	_maquina.processar(delta)
	_orientar(delta)


# ------------------------------------------------------------- estados ------

func _aproximar(delta: float) -> void:
	velocity = velocity.move_toward(
		direcao_de_locomocao(direcao_para_alvo()) * velocidade_atual(),
		1200.0 * delta
	)
	if absf(distancia_do_alvo() - raio_orbita) <= margem:
		_maquina.trocar(ORBITAR)


func _orbitar(delta: float) -> void:
	_circular(delta, 1.0)
	_t_intervalo -= delta * Deterioracao.multiplicador_cadencia()
	if _t_intervalo <= 0.0:
		_maquina.trocar(DISPARAR)
	elif absf(distancia_do_alvo() - raio_orbita) > margem * 3.0:
		# Perdeu a orbita (levou knockback, o jogador correu): reaproxima em vez
		# de tentar circular de um raio errado.
		_maquina.trocar(APROXIMAR)


## Continua circulando enquanto avisa. Parar para atirar transformaria a
## sentinela num alvo facil e mataria a pressao que ela existe para fazer.
func _disparar_entrar() -> void:
	_clarao.visible = true
	_clarao.scale = Vector2(0.4, 0.4)
	# O aviso da rajada e MAIOR e mais longo. Sem isso os dois ataques ficam
	# indistinguiveis ate o projetil existir, e o jogador so pode reagir.
	var alvo := 1.3 * (ESCALA_CLARAO_RAJADA if _vai_rajar() else 1.0)
	var t := create_tween()
	t.tween_property(_clarao, "scale", Vector2(alvo, alvo), _duracao_do_aviso())


func _disparar(delta: float) -> void:
	_circular(delta, 0.7)
	if not _maquina.passou(_duracao_do_aviso()):
		return
	if _vai_rajar():
		# `atirar_varias` e obrigatorio aqui, e nao preferencia: um `for` com
		# `atirar()` sairia com UM projetil. O `_t_cadencia` e setado no primeiro
		# tiro e `pode_atirar()` recusa o resto, porque o `_process` que
		# decrementa nao roda no meio do laco. Foi este mesmo defeito que fez o
		# anel da Diretora sair com um projetil.
		_arma.atirar_varias(
			Balistica.leque(direcao_para_alvo(), projeteis_rajada, abertura_rajada)
		)
		_ate_rajada = maxi(tiros_ate_rajada, 0)
	else:
		_arma.atirar(direcao_para_alvo())
		_ate_rajada -= 1
	_t_intervalo = intervalo
	_maquina.trocar(ORBITAR)


## A proxima salva e rajada?
##
## Consultado em DOIS lugares -- no aviso e no tiro -- e por isso e uma pergunta
## e nao uma bandeira levantada no meio do caminho. Se o aviso decidisse e o
## tiro relesse um contador ja alterado, o clarao grande sairia antes do tiro
## unico: o telegrafo mentiria, que e o pior defeito possivel neste projeto.
func _vai_rajar() -> bool:
	return tiros_ate_rajada > 0 and _ate_rajada <= 0


## Quanto o aviso dura nesta salva.
func _duracao_do_aviso() -> float:
	return tempo_clarao * (fator_aviso_rajada if _vai_rajar() else 1.0)


func _disparar_sair() -> void:
	_clarao.visible = false


# ------------------------------------------------------------ movimento -----

## Tangente mais uma correcao radial. A soma e o que mantem o raio estavel sem
## precisar de trigonometria: a tangente faz girar, a correcao devolve para a
## casquinha certa.
func _circular(delta: float, fator: float) -> void:
	var para_alvo := direcao_para_alvo()
	if para_alvo.length_squared() < 0.01:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		return

	var tangente := para_alvo.orthogonal() * _sentido
	var erro := distancia_do_alvo() - raio_orbita
	# Positivo = longe demais, entao a correcao aponta para o jogador.
	var radial := para_alvo * clampf(erro / maxf(raio_orbita, 1.0), -1.0, 1.0)
	var desejada := (tangente + radial * correcao_radial).normalized()

	velocity = velocity.move_toward(
		direcao_de_locomocao(desejada) * velocidade_atual() * fator,
		1300.0 * delta
	)


## Duas resolucoes de mira convivendo, e e de proposito -- a mesma divisao que o
## jogador tem.
##
## A TORRE gira livre e continua: e dela que a boca da arma e o clarao herdam a
## posicao, entao ela mostra o angulo EXATO do tiro. O corpo, que agora e sprite,
## mostra a direcao geral em oito passos.
##
## Foi por isso que a torre nasceu como no separado em vez de o `_visual` parar
## de girar: com a arma pendurada em `Visual` na posicao (26, 0), congelar o
## `_visual` faria todo tiro nascer 26 px a direita da sentinela, para sempre e
## sem erro no console. E a mesma armadilha que o `Sprite` do Player evita saindo
## de dentro do `Visual` -- aqui e o contrario, quem sai e a arma.
func _orientar(delta: float) -> void:
	var d := direcao_para_alvo()
	if _torre != null and d.length_squared() > 0.01:
		_torre.rotation = lerp_angle(_torre.rotation, d.angle(), 9.0 * delta)


## O corpo encara o jogador -- ela nunca vira as costas, e o nome dela e o que
## promete isso.
func _pos_movimento(delta: float) -> void:
	if _sprite == null:
		return
	var andando := velocity.length() > VELOCIDADE_ANDANDO
	_sprite.apontar(direcao_para_alvo(), andando, delta, velocity)
