class_name InimigoBase
extends CharacterBody2D
## Base de todo inimigo. Cuida de vida, dano, knockback, flash e morte.
## As subclasses so implementam _comportamento().
##
## Regra importante: NENHUM inimigo guarda os proprios numeros de dificuldade
## multiplicados. Eles leem Deterioracao a cada frame. Assim a barra subir tem
## efeito imediato, inclusive nos inimigos que ja estao na tela.

signal morreu(posicao: Vector2)

const GRUPO := "inimigo"

## Para onde a cor do corpo puxa enquanto o inimigo esta hackeado. Verde do
## Cipher: quem hackeou tem de ser reconhecivel no alvo, nao so no cano.
const COR_HACK := Color(0.45, 1.0, 0.3)

@export_group("Atributos")
@export var vida_maxima: int = 5
@export var velocidade_base: float = 120.0
@export var dano_contato: int = 1
@export var creditos: int = 3
## Quanto este inimigo soma na barra de Deterioracao ao morrer. Zero por
## padrao -- quem move a barra e o fim de onda, nao a matanca.
@export var deterioracao_ao_morrer: float = 0.0

@export_group("Feedback")
@export var cor_base: Color = Color("ff4d6d")
@export var raio_contato: float = 26.0
@export var intervalo_dano_contato: float = 0.7

var vida: int = 5
var alvo: Node2D = null
var morto: bool = false

var _knockback: Vector2 = Vector2.ZERO
var _t_contato: float = 0.0
## Segundos restantes de Hack. O estado mora AQUI e nao num Dictionary do
## autoload por dois motivos: um dicionario chaveado por instance_id acumularia
## ids de inimigos mortos a run inteira sem ninguem podar, e o tint precisa do
## estado localmente de qualquer jeito. Nascer e morrer com o no e o
## comportamento certo.
var _t_hack: float = 0.0
## Doses de nanite acumuladas e o tempo que falta para o acumulo apodrecer.
##
## O nanite EMPILHA onde o Hack RENOVA, e a diferenca e o desenho da arma: o
## Hack quer marcar um alvo, o nanite quer recompensar insistir no mesmo alvo.
## Sem a janela de validade bastaria acertar cada inimigo uma vez por sala e
## voltar depois -- o acumulo tem de ser um compromisso de tiro, nao de memoria.
var _stacks_nanite: int = 0
var _t_nanite: float = 0.0
## Guardados na primeira dose: quem estoura e o inimigo, e a arma que semeou ja
## nao existe mais nesse instante.
var _dados_nanite: DadosArma = null
var _cor_nanite: Color = Color.WHITE
var _visual: Node2D
## O no que carrega a COR do inimigo. `CanvasItem` e nao `Polygon2D` porque a
## partir do Drone Aranha ele pode ser um sprite: quem pinta e `_pintar_corpo`,
## que escolhe o canal certo pelo tipo. Tipar como Polygon2D fazia a atribuicao
## explodir em runtime no primeiro inimigo com arte.
var _corpo: CanvasItem
var _tween_flash: Tween


func _ready() -> void:
	add_to_group(GRUPO)
	vida = vida_maxima
	_visual = get_node_or_null("Visual")
	_corpo = get_node_or_null("Visual/Corpo")
	_pintar_corpo(_cor_neutra())
	_procurar_alvo()
	EventBus.inimigo_spawnou.emit(self)
	_ao_nascer()


func _physics_process(delta: float) -> void:
	if morto:
		return
	if alvo == null or not is_instance_valid(alvo):
		_procurar_alvo()

	_t_contato = maxf(_t_contato - delta, 0.0)

	if _t_hack > 0.0:
		_t_hack = maxf(_t_hack - delta, 0.0)
		if _t_hack <= 0.0:
			_pintar_hack(false)

	if _stacks_nanite > 0:
		_t_nanite = maxf(_t_nanite - delta, 0.0)
		if _t_nanite <= 0.0:
			# Apodrece INTEIRO, nao de uma dose por vez: decaimento gradual faria
			# o acumulo se sustentar sozinho com tiro esporadico, e a arma perde
			# o que ela pede em troca -- foco no mesmo alvo.
			_limpar_nanite()

	_comportamento(delta)

	# Knockback e somado por fora do comportamento para que empurrar um inimigo
	# nunca "cancele" a IA dele -- so desloca.
	if _knockback.length_squared() > 1.0:
		velocity += _knockback
		_knockback = _knockback.move_toward(Vector2.ZERO, 1400.0 * delta)

	move_and_slide()
	_pos_movimento(delta)


## Ponto de extensao principal: cada inimigo escreve so isto.
func _comportamento(_delta: float) -> void:
	pass


func _pos_movimento(_delta: float) -> void:
	pass


## Ponto de extensao do MOVIMENTO: recebe para onde o inimigo QUER ir e devolve
## para onde ele de fato vai.
##
## Hoje devolve a direcao crua, e e de proposito -- o comportamento nao muda em
## nada. O que ele cria e o lugar: quando entrar pathfinding ou desvio de
## obstaculo, esta e a unica funcao que muda, em vez de sete arquivos de
## inimigo. A divida esta declarada no ROADMAP ("sem pathfinding -- o melee anda
## em linha reta") e as salas com pilar e as em L a tornaram real.
##
## Quem escreve inimigo novo passa o movimento por aqui. O Rastejante e o Vigia
## ainda nao passam: eles sao o que a v0.2.0-alpha esta testando com os amigos, e
## mexer neles agora invalidaria esse retorno.
func direcao_de_locomocao(desejada: Vector2) -> Vector2:
	return desejada


func _ao_nascer() -> void:
	# Pop de entrada -- comunica "algo novo apareceu" sem precisar de animacao.
	if _visual == null:
		return
	_visual.scale = Vector2(0.1, 0.1)
	var t := create_tween()
	t.tween_property(_visual, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func velocidade_atual() -> float:
	return velocidade_base * Deterioracao.multiplicador_velocidade()


func direcao_para_alvo() -> Vector2:
	if alvo == null or not is_instance_valid(alvo):
		return Vector2.ZERO
	return (alvo.global_position - global_position).normalized()


func distancia_do_alvo() -> float:
	if alvo == null or not is_instance_valid(alvo):
		return INF
	return global_position.distance_to(alvo.global_position)


## Velocidade do alvo, usada pela mira preditiva. Isolado aqui para que o
## chefe e o Vigia leiam exatamente a mesma coisa.
func velocidade_do_alvo() -> Vector2:
	if alvo == null or not is_instance_valid(alvo):
		return Vector2.ZERO
	if "velocity" in alvo:
		return alvo.velocity
	return Vector2.ZERO


func tentar_dano_contato() -> void:
	if _t_contato > 0.0 or alvo == null or not is_instance_valid(alvo):
		return
	if distancia_do_alvo() > raio_contato:
		return
	if alvo.has_method("receber_dano"):
		var acertou: bool = alvo.receber_dano(dano_contato, direcao_para_alvo() * 260.0)
		if acertou:
			_t_contato = intervalo_dano_contato
			_knockback = -direcao_para_alvo() * 220.0


## Puxa este inimigo na direcao de `ponto`, sem mandar nele.
##
## Escreve no MESMO canal do knockback, e e por isso que nao precisa de uma
## linha de codigo em nenhuma IA: o knockback ja e somado por fora do
## comportamento justamente para que empurrar um inimigo nunca cancele a IA
## dele -- so desloque. O pulso de convergencia da Diretora e exatamente isso
## visto de fora: o campo inteiro dando um passo na sua direcao, sem nenhum
## inimigo mudar de ideia sobre o que estava fazendo.
func atrair_para(ponto: Vector2, forca: float) -> void:
	if morto or forca <= 0.0:
		return
	var direcao := ponto - global_position
	if direcao.length_squared() < 1.0:
		return
	_knockback += direcao.normalized() * forca


func receber_dano(quantidade: int, impulso: Vector2 = Vector2.ZERO) -> bool:
	if morto:
		return false
	vida -= quantidade
	_knockback += impulso
	_flash()
	EventBus.pedido_hitstop.emit(0.025, 0.25)
	if vida <= 0:
		morrer()
	return true


## Clarao branco ao levar dano.
##
## Nao reinicia um clarao que ja esta em andamento. Parece detalhe, mas com
## dano continuo (shotgun encostada, chefe sendo metralhado) reiniciar a cada
## acerto deixa o inimigo branco permanente e some com a silhueta dele.
func _flash() -> void:
	if _visual == null:
		return
	if _tween_flash != null and _tween_flash.is_valid():
		return
	_visual.modulate = Color(5.0, 5.0, 5.0, 1.0)
	_tween_flash = create_tween()
	_tween_flash.tween_property(_visual, "modulate", Color.WHITE, 0.16)


func morrer() -> void:
	if morto:
		return
	morto = true
	set_physics_process(false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	var fx := preload("res://src/fx/explosao.tscn").instantiate()
	fx.global_position = global_position
	fx.modulate = cor_base
	get_parent().add_child(fx)

	GameState.inimigos_mortos += 1
	GameState.creditos += creditos
	if deterioracao_ao_morrer > 0.0:
		Deterioracao.adicionar(deterioracao_ao_morrer)

	# Antes do queue_free, e aqui e o unico lugar possivel: este e o unico ponto
	# do jogo com a identidade do morto, a posicao dele e o no ainda na arvore.
	# EventBus.inimigo_morreu so carrega (posicao, creditos) -- quem escuta la
	# nao tem como saber que foi um hackeado que caiu.
	if _t_hack > 0.0:
		_propagar_hack()

	morreu.emit(global_position)
	EventBus.inimigo_morreu.emit(global_position, creditos)
	queue_free()


## Marca este inimigo por `duracao` segundos. Chamado pelo projetil.
func aplicar_hack(duracao: float) -> void:
	if morto or duracao <= 0.0:
		return
	# Renova em vez de somar: dois tiros seguidos nao empilham oito segundos.
	_t_hack = maxf(_t_hack, duracao)
	_pintar_hack(true)


func esta_hackeado() -> bool:
	return _t_hack > 0.0


## Deposita uma dose de nanite. Ao encher, consome tudo e estoura.
##
## Recebe o DadosArma inteiro porque o estouro le raio, dano e knockback dele --
## e no instante do estouro o projetil que semeou ja morreu ha segundos.
func aplicar_nanite(dados: DadosArma, tinta: Color) -> void:
	if morto or dados == null or not dados.semeia_nanite():
		return

	_dados_nanite = dados
	_cor_nanite = tinta
	_stacks_nanite += 1
	_t_nanite = dados.duracao_nanite
	_pintar_nanite()

	if _stacks_nanite >= dados.stacks_nanite:
		_estourar_nanite()


func stacks_de_nanite() -> int:
	return _stacks_nanite


## Troca o acumulo por uma explosao em area, centrada no proprio inimigo.
##
## Reusa a ExplosaoArea da Onda 2 inteira, com falloff e tudo: uma segunda
## implementacao de dano em area seria um segundo conjunto de bugs para o mesmo
## problema, e o falloff aqui tem o mesmo papel -- premiar quem juntou os
## inimigos antes de encher o ultimo stack.
func _estourar_nanite() -> void:
	var dados := _dados_nanite
	var tinta := _cor_nanite
	# Zera ANTES de estourar: a explosao pode matar este inimigo, e um estouro
	# que reentrasse aqui somaria dano em cima de um alvo que ja morreu.
	_limpar_nanite()

	var explosao := preload("res://src/projectiles/explosao_area.tscn").instantiate()
	var pai := get_parent()
	if pai == null:
		pai = get_tree().current_scene
	pai.add_child(explosao)
	explosao.configurar(global_position, dados, tinta)


func _limpar_nanite() -> void:
	_stacks_nanite = 0
	_t_nanite = 0.0
	_dados_nanite = null
	_pintar_nanite()


## Escurece o corpo conforme o acumulo sobe.
##
## Vai no canal do corpo pelo mesmo motivo do tint de Hack -- `_visual.modulate`
## e do clarao de dano e termina sempre em branco, apagando qualquer tint no
## primeiro tiro. E ele SO pinta se nao houver Hack ativo: dois tints brigando
## pelo mesmo canal deixariam a cor final dependendo da ordem das chamadas.
func _pintar_nanite() -> void:
	if _corpo == null or esta_hackeado():
		return
	if _stacks_nanite <= 0:
		_pintar_corpo(_cor_neutra())
		return
	var fracao := 1.0
	if _dados_nanite != null and _dados_nanite.stacks_nanite > 0:
		fracao = float(_stacks_nanite) / float(_dados_nanite.stacks_nanite)
	_pintar_corpo(_cor_neutra().lerp(_cor_nanite, clampf(fracao, 0.0, 1.0) * 0.7))


## O Hack pula para o vizinho vivo mais proximo dentro do raio.
##
## A busca e por grupo, a excecao que o GEMINI.md sanciona: Sala._vivos nao
## serve porque ela guarda so quem a SALA colocou, e os invocados da Diretora
## ficam de fora de proposito -- pelo grupo eles entram.
func _propagar_hack() -> void:
	if randf() >= Modificadores.chance_propagacao_hack():
		return
	var raio := Modificadores.raio_propagacao_hack()
	if raio <= 0.0:
		return

	var melhor: Node2D = null
	var menor := raio
	for outro in get_tree().get_nodes_in_group(GRUPO):
		if outro == self or not is_instance_valid(outro):
			continue
		var inimigo := outro as InimigoBase
		# Ja hackeado nao conta como destino: propagar para ele desperdicaria o
		# pulo e o Hack morreria com o proximo abate em vez de se espalhar.
		if inimigo == null or inimigo.morto or inimigo.esta_hackeado():
			continue
		var d := global_position.distance_to(inimigo.global_position)
		if d < menor:
			menor = d
			melhor = inimigo

	if melhor != null:
		melhor.aplicar_hack(Modificadores.duracao_hack())


## Tint de hackeado.
##
## Vai no canal do corpo e NUNCA em `_visual.modulate`: aquele e do clarao de
## dano, que termina sempre em Color.WHITE e apagaria o tint no primeiro tiro
## que acertasse. Como o modulate do pai multiplica por cima do corpo, os dois
## efeitos convivem sem se conhecer.
func _pintar_hack(ligado: bool) -> void:
	if _corpo == null:
		return
	if ligado:
		_pintar_corpo(_cor_neutra().lerp(COR_HACK, 0.55))
		return
	# Ao SAIR do Hack devolve o canal para o nanite, se houver acumulo. Voltar
	# direto para a cor neutra apagaria o aviso de que o inimigo esta carregado
	# -- e a explosao chegaria sem leitura nenhuma.
	_pintar_nanite()


## Escreve `cor` no canal de cor do corpo, seja ele poligono ou sprite.
##
## Um `Polygon2D` e preenchido por `color`; um `Sprite2D` nao tem essa
## propriedade, e o equivalente e `self_modulate`. `self_modulate` e nao
## `modulate` porque `modulate` desce para os filhos e ja e do clarao de dano --
## sao dois canais que nao podem se cruzar, e e essa separacao que faz Hack e
## clarao conviverem.
func _pintar_corpo(cor: Color) -> void:
	if _corpo == null:
		return
	var poligono := _corpo as Polygon2D
	if poligono != null:
		poligono.color = cor
		return
	_corpo.self_modulate = cor


## A cor de "nada acontecendo", e ela depende do canal.
##
## Num poligono o corpo E a cor solida, entao o neutro e `cor_base`. Num sprite
## o `self_modulate` MULTIPLICA a arte, entao o neutro e branco -- usar
## `cor_base` ali pintaria a carcaca de laranja e, pior, faria
## `cor_base.lerp(COR_HACK, 0.55)` escurecer o inimigo em vez de esverdea-lo.
func _cor_neutra() -> Color:
	return cor_base if _corpo is Polygon2D else Color.WHITE


func _procurar_alvo() -> void:
	alvo = get_tree().get_first_node_in_group("player")
