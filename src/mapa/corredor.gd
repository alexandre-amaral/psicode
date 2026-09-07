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
## Cor de emergencia, usada so quando a textura nao carrega: o chao N1 da
## paleta combate (docs/IDENTIDADE_VISUAL.md).
const COR_CHAO_EMERGENCIA := Color("0b0d16")

## O TRECHO PRE-CHEFE veste as texturas da sala do chefe, e nao a noite base.
##
## Isto e a EXCECAO deliberada a regra do corredor, e ela vale registrar. O
## corredor comum fica na noite base de proposito: "pintar cada metade com a cor
## da sala vizinha anunciaria o que ha do outro lado antes de o jogador chegar".
## Aqui anunciar E o objetivo -- e o unico trecho do andar em que a arquitetura
## tem permissao de dizer o que vem.
const TEXTURA_CHAO_CHEFE := "res://assets/texturas/chao_boss.png"
const FACE_CHEFE := "res://assets/texturas/parede_face_boss.png"

## Quanto o chao do trecho pre-chefe escurece.
##
## "Iluminacao mais irregular" e o que o plano pede, e escurecer o CHAO -- e nao
## o corredor inteiro -- e o que sobra depois da regra de leitura: o projetil e o
## telegrafo continuam com o mesmo contraste, porque nada foi posto na frente
## deles. O que muda e o fundo contra o qual eles sao lidos.
const ESCURECER_PRE_CHEFE := 0.72
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

## Quanto o decalque se afasta da borda do corredor.
##
## 48 px cobre a meia-largura da maior peca do atlas (64) mais folga: uma marca
## que cruze a parede lateral aparece cortada, e a lateral do corredor e onde a
## faixa de parede da sala vizinha ja desenha por cima.
const RECUO_DO_DECALQUE := 48.0

var _retangulo_local: Rect2 = Rect2()
var _configurado: bool = false
## Este e o ultimo trecho antes do chefe?
##
## Escrito pelo `GerenciadorMapa` ANTES de `configurar()`, porque e ele quem
## monta a geometria e veste as texturas -- depois dele, mudar a bandeira nao
## muda nada. E "qual e o ultimo" nao e pergunta que o corredor responda olhando
## so para si mesmo: ele conhece dois pontos, e nao o andar.
var pre_chefe := false

## O perfil deste corredor, quando ele e um CORREDOR_TECNICO.
##
## Nulo e o comportamento de sempre: passagem curta e parede compartilhada nao
## recebem perfil, porque elas nao sao um LUGAR -- decorar uma travessia de meio
## segundo poria marca de chao onde ninguem para para ver.
##
## Escrito ANTES do `configurar()`, como `pre_chefe`: e ele que monta chao e
## decalque, e nao ha segunda chance depois disso.
var perfil: PerfilDeCorredor = null


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
	_montar_fita(eixo, lado, comprimento, largura)
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
## A textura de chao ou parede deste corredor.
##
## O trecho pre-chefe sai da lista e vai para a textura do chefe: e a excecao
## deliberada, e ela e resolvida AQUI e nao em quem chama, para nao haver dois
## caminhos de vestir corredor.
func _textura_de_chao() -> Texture2D:
	if pre_chefe:
		var chefe := load(TEXTURA_CHAO_CHEFE) as Texture2D
		if chefe != null:
			return chefe
	# **O PERFIL escolhe entre as texturas da noite base, e nao para fora dela.**
	#
	# As tres SAO a noite base, entao escolher por perfil nao diz nada sobre a
	# sala vizinha -- que e a regra inteira do corredor comum. O que muda e a
	# textura ser DETERMINISTICA pelo que aquele corredor representa em vez de
	# sair do hash da posicao.
	#
	# A ordem importa: o trecho pre-chefe vence o perfil, porque ele e a unica
	# excecao autorizada a anunciar, e resolve-la aqui mantem um caminho so.
	if perfil != null and perfil.textura_chao != null:
		return perfil.textura_chao
	return _textura(TEXTURAS_CHAO, 0)


## O topo do corredor sai da MESMA lista neutra da sala.
##
## O trecho pre-chefe nao tem excecao aqui, e isso e consequencia da PAR 04 e nao
## esquecimento: com o topo neutro em todo o andar, o anuncio do chefe passa a
## viver no CHAO escurecido e na FACE, que continuam sendo dele. Um topo proprio
## para o chefe reintroduziria a identidade de tipo na superficie de onde ela
## acabou de sair.
func _textura_de_parede() -> Texture2D:
	return Sala.topo_neutro(hash(_retangulo_local.position) ^ 0x2f1b3c5d)


func _textura(lista: Array[String], deslocamento: int) -> Texture2D:
	if lista.is_empty():
		return null
	var semente := hash(Vector2i(global_position)) ^ deslocamento
	return load(lista[absi(semente) % lista.size()]) as Texture2D


func obter_limites() -> Rect2:
	if not _configurado:
		return Rect2(global_position, Vector2.ZERO)
	return global_transform * _retangulo_local


## A FITA DE MODULOS do corredor -- o mesmo kit da sala (PAREDE 09).
##
## O corredor espelhava `Sala.ESPESSURA_PAREDE` e `Sala.ALTURA_FACE` de proposito,
## "para parecer construido do mesmo material". Com a parede da sala virando fita
## de modulos ele ficaria para tras: seria a unica superficie do andar ainda
## desenhada como textura continua, e a emenda com a sala apareceria.
##
## Duas coisas nao mudam, e as duas sao decisao registrada:
##
## - **Ele fica na NOITE BASE.** O corredor nao veste a cor da sala vizinha:
##   pintar cada metade anunciaria o que ha do outro lado antes de o jogador
##   chegar. Por isso a face aqui e a NEUTRA, e nao a do tipo.
## - **O trecho pre-chefe e a excecao, e ela e deliberada.** Ali anunciar E o
##   objetivo, e so no ULTIMO trecho -- um andar que escurecesse a cada sala
##   anunciaria o chefe desde a terceira porta.
##
## As duas PONTAS ficam abertas: elas sao a boca do corredor, e fechar uma seria
## por parede no meio da passagem. E nao ha canto, porque um corredor nao tem
## quina -- as pontas dele morrem dentro da parede da sala.
func _montar_fita(eixo: Vector2, lado: Vector2, comprimento: float, largura: float) -> void:
	# **O LIMIAR SAI DO PERFIL, e nao de `ESPESSURA_PAREDE`.**
	#
	# Quando as duas faixas de parede das salas vizinhas ja se encontram no vao,
	# o corredor nao tem o que vestir -- ele nasce como piso e colisao e mais
	# nada, e e isso que faz a parede compartilhada do epico dos setores existir
	# sem peca nova.
	#
	# Escrito como `ESPESSURA_PAREDE * 2` isso funcionava por COINCIDENCIA: 128
	# era exatamente o dobro da profundidade de entao. Com o corpo em 56 a
	# profundidade vai a 68, o vao vai a 144, e o corredor voltaria a desenhar uma
	# faixa POR CIMA das duas que ja se encontram ali -- sem erro nenhum, so uma
	# emenda de parede no meio da passagem.
	var perfil := PerfilDeParede.new()
	var encontro := perfil.profundidade(RenderizadorParedes.Lado.NORTE) 		+ perfil.profundidade(RenderizadorParedes.Lado.SUL)
	if comprimento <= encontro:
		return
	# O mesmo recuo nas pontas que o corpo e a face ja usam: a parede da sala ja
	# cobre esses pixels nas bocas, e pintar duas vezes o mesmo lugar costura.
	var meio := eixo * (comprimento * 0.5 - ESPESSURA_PAREDE)
	var meia := lado * (largura * 0.5)
	var contorno := PackedVector2Array([
		-meio - meia, meio - meia, meio + meia, -meio + meia,
	])

	var topos: Array[Texture2D] = []
	for caminho in Sala.TOPOS_NEUTROS:
		var t := load(caminho) as Texture2D
		if t != null:
			topos.append(t)
	var faces: Array[Texture2D] = []
	var face := load(FACE_CHEFE if pre_chefe else Sala.FACE_NEUTRA) as Texture2D
	if face != null:
		faces.append(face)

	var vazias: Array[Porta] = []
	var abertos: Array[Vector2] = [eixo, -eixo]
	add_child(RenderizadorParedes.construir(
		contorno, vazias, hash(_retangulo_local.position), topos, faces,
		0.65, 2, abertos))

	# A SOMBRA vale para o corredor tambem, e nao por simetria de codigo.
	#
	# Atravessar de uma sala com sombra para um corredor sem ela troca a
	# perspectiva no meio da passagem -- a parede assenta no chao de um lado da
	# porta e flutua do outro. E o mesmo defeito que a LTD 12 existiu para
	# consertar quando o corredor nao desenhava face.
	#
	# So os LADOS entram: as bocas (`abertos`) nao sao parede, e sombra numa boca
	# seria uma faixa escura atravessando exatamente onde o jogador passa.
	var laterais: Array[PackedVector2Array] = []
	var total := contorno.size()
	for i in total:
		var a := contorno[i]
		var b := contorno[(i + 1) % total]
		if RenderizadorParedes.normal_externa(contorno, a, b).dot(eixo) != 0.0:
			continue
		laterais.append(PackedVector2Array([a, b]))
	if not laterais.is_empty():
		add_child(SombraDeParede.construir(laterais, contorno))


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
	_texturizar(chao, _textura_de_chao(), _retangulo_local.position)
	# A iluminacao irregular do trecho pre-chefe. Escurece o CHAO e nada mais:
	# projetil e telegrafo continuam com o mesmo contraste, porque nada foi posto
	# na frente deles -- so mudou o fundo contra o qual sao lidos.
	if pre_chefe:
		chao.modulate = Color(ESCURECER_PRE_CHEFE, ESCURECER_PRE_CHEFE, ESCURECER_PRE_CHEFE, 1.0)
	add_child(chao)
	_montar_decalques()


## As marcas de chao do perfil, na mesma faixa chapada dos decalques de sala.
##
## `Z_CHAO_DETALHE` e ABAIXO de `Z_MUNDO`, e isso e garantia geometrica e nao
## intencao: um decalque na faixa zero poderia cair na frente do telegrafo ou de
## um projetil que atravessa o corredor, e o corredor e estreito -- ali o jogador
## tem menos espaco para reler a ameaca do que numa sala.
##
## Elas ficam no MIOLO, longe das bocas: uma marca cortada ao meio pela parede da
## sala vizinha le como erro de montagem, e as bocas sao onde o corredor e a sala
## se encontram.
func _montar_decalques() -> void:
	if perfil == null or perfil.atlas_decalques == null:
		return
	if perfil.regioes_decalques.is_empty() or perfil.quantidade_decalques <= 0:
		return
	var raiz := Node2D.new()
	raiz.name = "Decalques"
	raiz.z_index = Sala.Z_CHAO_DETALHE
	add_child(raiz)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(global_position)) ^ hash(perfil.id)
	var util := _retangulo_local.grow(-RECUO_DO_DECALQUE)
	if util.size.x <= 0.0 or util.size.y <= 0.0:
		return
	for _i in perfil.quantidade_decalques:
		var regiao: Rect2i = perfil.regioes_decalques[
			rng.randi_range(0, perfil.regioes_decalques.size() - 1)]
		var sprite := Sprite2D.new()
		sprite.texture = perfil.atlas_decalques
		sprite.region_enabled = true
		sprite.region_rect = Rect2(regiao)
		sprite.position = Vector2(
			rng.randf_range(util.position.x, util.end.x),
			rng.randf_range(util.position.y, util.end.y))
		raiz.add_child(sprite)


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
