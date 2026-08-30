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
##
## Visualmente ele veste a variante `combate` das texturas -- a neutra do andar.
## Corredor nao tem tipo, e pintar cada metade com a cor da sala vizinha
## anunciaria o que ha do outro lado antes de o jogador chegar.

## O corredor nao tem tipo nem celula -- a API dele e `configurar(de, para,
## largura)` e mais nada. Ele veste a variante base do andar, sorteada pela
## PROPRIA POSICAO, que e a unica identidade estavel que ele tem: o mesmo
## corredor entre as mesmas duas salas cai sempre na mesma textura.
##
## Continua sem tipo de proposito: pintar cada metade com a cor da sala vizinha
## anunciaria o que ha do outro lado antes de o jogador chegar.
const TEXTURAS_CHAO: Array[String] = [
	"res://assets/texturas/chao_andar1_a.png",
	"res://assets/texturas/chao_andar1_b.png",
	"res://assets/texturas/chao_andar1_c.png",
]
const TEXTURAS_PAREDE: Array[String] = [
	"res://assets/texturas/parede_andar1_a.png",
	"res://assets/texturas/parede_andar1_b.png",
	"res://assets/texturas/parede_andar1_c2.png",
]
## Cor de emergencia, usada so quando a textura nao carrega: o chao N1 da
## paleta combate (docs/IDENTIDADE_VISUAL.md).
const COR_CHAO_EMERGENCIA := Color("0b0d16")
## Espelha Sala.ESPESSURA_PAREDE, para o corredor parecer construido do mesmo
## material. Recuada nas duas pontas para nao pintar por cima da parede da
## sala, que ja cobre essa faixa.
##
## Le da Sala em vez de repetir o numero: eram duas constantes com o mesmo
## valor por disciplina, e a migracao Low Top-Down mudou o valor de 24 para 64
## -- exatamente o tipo de mudanca em que uma das duas copias fica para tras.
const ESPESSURA_PAREDE := Sala.ESPESSURA_PAREDE
## Layer 3 ("parede") — barreira nao colide com nada, so e colidida.
const CAMADA_PAREDE := 4
## Folga em pixels antes de considerar que os dois pontos nao estao num eixo.
const TOLERANCIA_ALINHAMENTO := 1.0

var _retangulo_local: Rect2 = Rect2()
var _configurado: bool = false


## "de" e "para" sao pontos GLOBAIS (as bocas das duas portas).
## Chamar DEPOIS de add_child: depende de global_position ja valido.
func configurar(de: Vector2, para: Vector2, largura: float = 80.0) -> void:
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
	# Zero de proposito: as faixas de z vem de Sala e sao ABSOLUTAS. Antes este
	# no valia -1 e os filhos herdavam o deslocamento, o que fazia o mesmo
	# numero significar coisas diferentes na sala e no corredor -- e o empate
	# entre os dois chaos era desempatado por ordem de arvore, funcionando por
	# acidente. O corredor desenha nas mesmas faixas da sala; a boca nao
	# costura porque os retangulos nao se sobrepoem, e nao porque um esta
	# abaixo do outro.
	z_index = 0

	var eixo: Vector2 = Vector2.RIGHT if horizontal else Vector2.DOWN
	var lado: Vector2 = Vector2.DOWN if horizontal else Vector2.RIGHT
	var meio_comprimento: Vector2 = eixo * (comprimento * 0.5)
	var meia_largura: Vector2 = lado * (largura * 0.5)

	_retangulo_local = Rect2(-(meio_comprimento + meia_largura), eixo * comprimento + lado * largura)
	_montar_parede_corpo(eixo, lado, comprimento, largura)
	_montar_chao()
	_montar_lateral(-meio_comprimento - meia_largura, meio_comprimento - meia_largura)
	_montar_lateral(-meio_comprimento + meia_largura, meio_comprimento + meia_largura)
	_configurado = true


## Bounding box GLOBAL, largura inteira incluida — o gerenciador expande o clamp
## da camera com isto durante a travessia.
## Escolhe a variante pela posicao global, arredondada para inteiro.
##
## `global_position` ja esta valido aqui: `configurar()` a define antes de
## montar as camadas. O deslocamento separa chao de parede pelo mesmo motivo que
## em `Sala._textura()` -- para as duas listas nao andarem casadas.
func _textura(lista: Array[String], deslocamento: int) -> Texture2D:
	if lista.is_empty():
		return null
	var semente := hash(Vector2i(global_position)) ^ deslocamento
	return load(lista[absi(semente) % lista.size()]) as Texture2D


func obter_limites() -> Rect2:
	if not _configurado:
		return Rect2(global_position, Vector2.ZERO)
	return global_transform * _retangulo_local


## A faixa de parede dos dois lados do corredor, atras do chao. Nao encosta nas
## salas: nas pontas, quem cobre esses 24 px e o corpo da parede da propria
## sala, e pintar duas vezes o mesmo lugar com fase de UV diferente costuraria.
func _montar_parede_corpo(eixo: Vector2, lado: Vector2, comprimento: float, largura: float) -> void:
	var meio := eixo * (comprimento * 0.5 - ESPESSURA_PAREDE)
	var meia_largura := lado * (largura * 0.5 + ESPESSURA_PAREDE)
	if comprimento <= ESPESSURA_PAREDE * 2.0:
		return
	var corpo := Polygon2D.new()
	corpo.polygon = PackedVector2Array([
		-meio - meia_largura,
		meio - meia_largura,
		meio + meia_largura,
		-meio + meia_largura,
	])
	corpo.name = "ParedeTopo"
	corpo.z_index = Sala.Z_PAREDE_TOPO
	_texturizar(corpo, _textura(TEXTURAS_PAREDE, 0x2f1b3c5d), _retangulo_local.position)
	add_child(corpo)


func _montar_chao() -> void:
	var chao := Polygon2D.new()
	chao.name = "Chao"
	chao.z_index = Sala.Z_CHAO
	chao.polygon = PackedVector2Array([
		_retangulo_local.position,
		Vector2(_retangulo_local.end.x, _retangulo_local.position.y),
		_retangulo_local.end,
		Vector2(_retangulo_local.position.x, _retangulo_local.end.y),
	])
	_texturizar(chao, _textura(TEXTURAS_CHAO, 0), _retangulo_local.position)
	add_child(chao)


## Cada lateral e SO barreira: quem da a leitura visual e a faixa de parede
## texturizada de `_montar_parede_corpo`, que ja cobre os mesmos 24 px.
##
## Ela tambem desenhava um filete de neon de 8 px por cima. Saiu junto com o das
## salas: com a parede texturizada dos dois lados, o neon virava uma segunda
## borda em cima da primeira -- e um corredor brilhando enquanto a sala nao
## brilha le como se o corredor fosse o caminho certo.
func _montar_lateral(inicio: Vector2, fim: Vector2) -> void:
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


## UV em pixels ancorada no canto do retangulo local, com repeticao ligada --
## o default do projeto e Disabled, e sem isto a textura sai esticada uma vez
## so no comprimento do corredor.
func _texturizar(poligono: Polygon2D, textura: Texture2D, ancora: Vector2) -> void:
	if textura == null:
		poligono.color = COR_CHAO_EMERGENCIA
		return
	poligono.texture = textura
	poligono.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var uv := PackedVector2Array()
	for ponto in poligono.polygon:
		uv.append(ponto - ancora)
	poligono.uv = uv


func _limpar() -> void:
	_configurado = false
	_retangulo_local = Rect2()
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
