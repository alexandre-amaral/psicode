class_name AreaDePerigo
extends Area2D
## Circulo de energia no chao que avisa, explode e some.
##
## E a primeira ameaca do jogo que nao e um projetil nem um corpo: ela nega
## ESPACO em vez de mirar. Existe para o Hacker Parasita, mas nao sabe nada
## sobre ele -- quem semeia so chama `configurar()` e segue a vida.
##
## Tres decisoes de design moram aqui:
##
## 1. **O telegrafo E o ataque.** O circulo cresce durante todo o aviso, entao a
##    intencao esta legivel desde o primeiro frame -- que e o que o GDD exige de
##    todo ataque. Sem essa fase, um circulo que aparece ja explodindo seria
##    dano vindo do chao, e o jogador nao teria como aprender nada com a morte.
##
## 2. **Ela nao e filha de quem a semeou.** Filha do Parasita, ela andaria junto
##    com ele -- e um aviso no chao que se move e um aviso que mente. Quem semeia
##    passa o container da sala como pai.
##
## 3. **A colisao so existe na janela de dano.** Enquanto e aviso, o Area2D esta
##    desligado. Assim nao ha como o jogador levar dano "de raspao" ao entrar no
##    circulo antes da hora, o que faria o telegrafo parecer quebrado.

## Layers nomeadas no project.godot: 1 player, 5 projetil_inimigo.
const LAYER_PROJ_INIMIGO := 16
const LAYER_PLAYER := 1

## Quantos lados o poligono do circulo tem. 24 le como circulo e custa pouco.
const LADOS := 24

@export var raio: float = 56.0
## Quanto tempo o aviso fica crescendo antes de explodir.
@export var tempo_aviso: float = 1.2
## Quanto tempo a area machuca. Curta de proposito: o perigo e o lugar, nao a
## duracao -- area que fere por muito tempo vira parede invisivel.
@export var tempo_dano: float = 0.35
@export var dano: int = 1
@export var cor: Color = Color(0.55, 1.0, 0.45)

var _forma: CollisionShape2D
var _visual: Polygon2D
var _borda: Line2D
var _feriu: bool = false


func _ready() -> void:
	collision_layer = LAYER_PROJ_INIMIGO
	collision_mask = LAYER_PLAYER
	# Desligado enquanto e so aviso. Ver decisao 3 no cabecalho.
	monitoring = false

	_forma = $Forma
	_visual = $Visual
	_borda = $Borda

	var circulo := CircleShape2D.new()
	circulo.radius = raio
	_forma.shape = circulo

	var pontos := _poligono(raio)
	_visual.polygon = pontos
	_visual.color = Color(cor.r, cor.g, cor.b, 0.14)
	_borda.points = _fechar(pontos)
	_borda.default_color = Color(cor.r, cor.g, cor.b, 0.5)

	_animar()


## Chamado por quem semeia, ANTES do add_child nao adianta: `global_position` so
## tem significado dentro da arvore. Quem semeia faz add_child e depois isto.
func configurar(posicao: Vector2, raio_novo: float = -1.0, dano_novo: int = -1) -> void:
	global_position = posicao
	if raio_novo > 0.0:
		raio = raio_novo
	if dano_novo > 0:
		dano = dano_novo


## O ciclo inteiro num tween so: cresce, pisca, machuca, some.
##
## `create_tween()` morre junto com o no, entao a area que for liberada no meio
## do aviso -- porque o Parasita morreu -- nao deixa nada rodando.
func _animar() -> void:
	# Os dois crescem juntos. Sao irmaos e nao pai/filho de proposito: o
	# Polygon2D nao pode repetir o ponto de fechamento e o Line2D precisa dele,
	# entao eles nao compartilham geometria -- so a escala.
	_visual.scale = Vector2(0.15, 0.15)
	_borda.scale = Vector2(0.15, 0.15)
	_borda.modulate.a = 0.2

	var t := create_tween()
	t.tween_property(_visual, "scale", Vector2.ONE, tempo_aviso).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_borda, "scale", Vector2.ONE, tempo_aviso).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_borda, "modulate:a", 1.0, tempo_aviso)
	t.tween_callback(_explodir)
	t.tween_interval(tempo_dano)
	t.tween_callback(queue_free)


func _explodir() -> void:
	monitoring = true
	_visual.color = Color(cor.r, cor.g, cor.b, 0.65)
	EventBus.pedido_shake.emit(1.8, 0.12)

	# O corpo que ja esta dentro no instante da explosao nao dispara
	# `body_entered` -- ele nao ENTROU, ele estava la. Sem esta varredura, ficar
	# parado dentro do circulo era a forma mais segura de sobreviver a ele.
	for corpo in get_overlapping_bodies():
		_ferir(corpo)


func _on_body_entered(corpo: Node2D) -> void:
	_ferir(corpo)


## Uma area fere UMA vez. Sem isso, entrar e sair na janela de dano cobraria
## duas vezes pelo mesmo ataque.
func _ferir(corpo: Node) -> void:
	if _feriu or not monitoring:
		return
	if not corpo.has_method("receber_dano"):
		return
	var no := corpo as Node2D
	if no == null:
		return
	var empurrao: Vector2 = (no.global_position - global_position).normalized() * 180.0
	if corpo.receber_dano(dano, empurrao):
		_feriu = true


func _poligono(r: float) -> PackedVector2Array:
	var pontos := PackedVector2Array()
	for i in LADOS:
		pontos.append(Vector2.RIGHT.rotated(TAU * float(i) / float(LADOS)) * r)
	return pontos


## O Line2D precisa repetir o primeiro ponto para fechar o desenho; o Polygon2D
## nao pode repetir. Por isso os dois nao compartilham o mesmo array -- e a
## mesma armadilha que `Sala.contorno_local()` documenta.
func _fechar(pontos: PackedVector2Array) -> PackedVector2Array:
	var saida := PackedVector2Array(pontos)
	if not saida.is_empty():
		saida.append(saida[0])
	return saida
