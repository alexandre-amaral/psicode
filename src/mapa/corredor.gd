class_name Corredor
extends Node2D
## Trecho de chao procedural que liga a boca de duas portas de salas vizinhas.
##
## Decisao de design que este no carrega: as salas ficam separadas por um vao no
## mundo e o jogador ATRAVESSA ANDANDO, com a camera acompanhando — nao existe
## teleporte entre salas. O corredor e o que torna essa distancia honesta: sem
## ele a camera passearia por cima do vazio e a transicao viraria um corte
## disfarcado. Por isso ele e 100% codigo (sem .tscn): o gerenciador cria um por
## ligacao do grafo, com o comprimento exato daquele vao.

const COR_CHAO := Color(0.0431373, 0.0509804, 0.0862745, 1)
const COR_PAREDE := Color(0.3, 0.9, 1, 0.55)
const ESPESSURA_PAREDE := 8.0
## Layer 3 ("parede") — barreira nao colide com nada, so e colidida.
const CAMADA_PAREDE := 4
## Folga em pixels antes de considerar que os dois pontos nao estao num eixo.
const TOLERANCIA_ALINHAMENTO := 1.0

var _retangulo_local: Rect2 = Rect2()
var _configurado: bool = false


## "de" e "para" sao pontos GLOBAIS (as bocas das duas portas).
## Chamar DEPOIS de add_child: depende de global_position ja valido.
func configurar(de: Vector2, para: Vector2, largura: float = 120.0) -> void:
	_limpar()

	var delta: Vector2 = para - de
	var horizontal: bool = absf(delta.x) >= absf(delta.y)

	# Desalinhamento nos dois eixos so acontece com layout inconsistente. Seguir
	# pelo eixo dominante ainda entrega um corredor navegavel, o que e melhor que
	# deixar o vao aberto e o jogador preso na sala.
	if absf(delta.x) > TOLERANCIA_ALINHAMENTO and absf(delta.y) > TOLERANCIA_ALINHAMENTO:
		push_warning("Corredor: pontos desalinhados (%s -> %s); usando o eixo de maior diferenca." % [de, para])

	var comprimento: float = absf(delta.x) if horizontal else absf(delta.y)
	if comprimento <= 0.0 or largura <= 0.0:
		push_warning("Corredor: medidas invalidas (comprimento %.1f, largura %.1f); nada montado." % [comprimento, largura])
		return

	global_position = (de + para) * 0.5
	# O chao do corredor passa por baixo do chao das salas para a boca nao costurar.
	z_index = -1

	var eixo: Vector2 = Vector2.RIGHT if horizontal else Vector2.DOWN
	var lado: Vector2 = Vector2.DOWN if horizontal else Vector2.RIGHT
	var meio_comprimento: Vector2 = eixo * (comprimento * 0.5)
	var meia_largura: Vector2 = lado * (largura * 0.5)

	_retangulo_local = Rect2(-(meio_comprimento + meia_largura), eixo * comprimento + lado * largura)
	_montar_chao()
	_montar_lateral(-meio_comprimento - meia_largura, meio_comprimento - meia_largura)
	_montar_lateral(-meio_comprimento + meia_largura, meio_comprimento + meia_largura)
	_configurado = true


## Bounding box GLOBAL, largura inteira incluida — o gerenciador expande o clamp
## da camera com isto durante a travessia.
func obter_limites() -> Rect2:
	if not _configurado:
		return Rect2(global_position, Vector2.ZERO)
	return global_transform * _retangulo_local


func _montar_chao() -> void:
	var chao := Polygon2D.new()
	chao.name = "Chao"
	chao.color = COR_CHAO
	chao.polygon = PackedVector2Array([
		_retangulo_local.position,
		Vector2(_retangulo_local.end.x, _retangulo_local.position.y),
		_retangulo_local.end,
		Vector2(_retangulo_local.position.x, _retangulo_local.end.y),
	])
	add_child(chao)


## Cada lateral e desenho e barreira ao mesmo tempo: a linha da a leitura visual
## e o segmento impede o jogador de escapar pelo lado do corredor.
func _montar_lateral(inicio: Vector2, fim: Vector2) -> void:
	var linha := Line2D.new()
	linha.width = ESPESSURA_PAREDE
	linha.default_color = COR_PAREDE
	linha.points = PackedVector2Array([inicio, fim])
	# Sobe de volta ao nivel do chao das salas para a parede nao sumir na boca.
	linha.z_index = 1
	add_child(linha)

	var corpo := StaticBody2D.new()
	corpo.collision_layer = CAMADA_PAREDE
	corpo.collision_mask = 0
	add_child(corpo)

	var colisor := CollisionShape2D.new()
	# Forma criada em codigo: sub-resource de .tscn seria compartilhado entre
	# instancias e todos os corredores acabariam com o mesmo comprimento.
	var segmento := SegmentShape2D.new()
	segmento.a = inicio
	segmento.b = fim
	colisor.shape = segmento
	corpo.add_child(colisor)


func _limpar() -> void:
	_configurado = false
	_retangulo_local = Rect2()
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
