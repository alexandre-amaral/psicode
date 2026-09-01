class_name RenderizadorParedes
extends RefCounted
## A parede como FITA DE MODULOS de 32 px, e nao como textura esticada.
##
## Antes disto, `Sala._montar_visual()` fazia o topo como um contorno inflado e a
## face como um quad por subtrecho, os dois com uma textura repetida e UV
## ancorada no canto do contorno. Nao havia como o terceiro ladrilho ser um
## ventilador -- **nao existia "terceiro ladrilho"**, existia uma superficie
## continua. Aqui cada celula de 32 px e um sprite, e e nisso que variante,
## verga e canto passam a caber.
##
## `Sala` nao sabe qual textura representa o que. Ela entrega contorno, portas e
## semente; o que sai e uma arvore pronta. Essa separacao e o que permite a mesma
## sala logica ser desenhada como setor industrial, laboratorio ou nucleo sem
## tocar na geracao procedural -- e e a mesma divisao que ja existe entre
## `DadosSala` (a regra de colocacao) e a cena da sala (a forma).
##
## **O recorte do chao nao e mais necessario, e isso resolve a pergunta em
## aberto da issue.** O topo antigo e desenhado ATRAS do chao porque ele e o
## contorno INFLADO E SOLIDO: sem o chao por cima, ele cobriria a sala inteira, e
## e esse truque que faz a sala em L funcionar sem calcular anel com furo. A fita
## nao tem esse problema por construcao -- toda celula mora na FAIXA, do contorno
## para fora, e nenhuma delas encosta em area jogavel. Por isso ela desenha ACIMA
## do chao e mesmo assim nao cobre nada, e por isso a sala em L nao precisa de
## geometria nova.
##
## **Nada aqui gira arte.** Os modulos ja nascem orientados -- 32x64 no norte e no
## sul, 64x32 no leste e no oeste --, e o oeste e desenho proprio e nao o leste
## espelhado, porque o espelho inverteria de que lado vem a luz. E a mesma regra
## que a porta ja carrega desde a PORTA 03.

## O tile visual do projeto, e o unico numero que divide toda dimensao de sala.
const MODULO := 32.0

## Um lado curto demais nao recebe fita: com menos de um modulo nao ha o que
## colocar, e meio sprite mentiria sobre a grade.
const LADO_MINIMO := MODULO

## Onde a fita desenha.
##
## Acima da face antiga (-14) e abaixo de `Sala.Z_MUNDO`, que e onde vivem
## telegrafo, projetil e ator. A faixa foi decidida no `PIVO_PAREDES.md` §4: a
## parede e arquitetura e fica embaixo, e o "raro" que cobre o ator continua
## sendo `Z_FRENTE`.
const Z_FITA := -13

const MODULO_N := preload("res://assets/texturas/modulo_n.png")
const MODULO_S := preload("res://assets/texturas/modulo_s.png")
const MODULO_L := preload("res://assets/texturas/modulo_l.png")
const MODULO_O := preload("res://assets/texturas/modulo_o.png")
const CANTO_NO := preload("res://assets/texturas/modulo_canto_no.png")
const CANTO_NE := preload("res://assets/texturas/modulo_canto_ne.png")

## Como um lado e classificado, e o limiar e o MESMO de `Sala.LIMIAR_LADO_NORTE`.
##
## Ele nao e copiado: um segundo limiar aqui divergiria do que decide se um lado
## ganha face, e o sintoma seria um lado com fita de norte e face de sul.
enum Lado { NORTE, SUL, LESTE, OESTE }


## A fita inteira: um no pronto para a sala pendurar.
##
## `portas` entra como lista e nao como no para o renderizador nao depender de
## onde a cena guarda as portas -- ele precisa saber ONDE ha vao, e nao quem e o
## pai de quem.
static func construir(contorno: PackedVector2Array, portas: Array[Porta],
		semente: int) -> Node2D:
	var raiz := Node2D.new()
	raiz.name = "ParedeModulos"
	raiz.z_index = Z_FITA
	if contorno.size() < 3:
		return raiz

	for i in contorno.size():
		var a := contorno[i]
		var b := contorno[(i + 1) % contorno.size()]
		_vestir_lado(raiz, contorno, a, b, portas, semente)
	_vestir_cantos(raiz, contorno)
	return raiz


## Um lado vira N celulas de 32 px.
##
## A celula que ENCOSTA num vao de porta fica de fora, e nao meio de fora: a
## parede antiga aparece por baixo dela. O motivo e um numero que o plano nao
## previu -- `Porta.LARGURA` e 80, e 80 nao e multiplo de 32, entao a porta ocupa
## 2,5 celulas e as das pontas ficam meio dentro e meio fora. Resolver isso e a
## PAREDE 07; aqui o desalinhamento fica VISIVEL em vez de disfarcado.
static func _vestir_lado(raiz: Node2D, contorno: PackedVector2Array, a: Vector2,
		b: Vector2, portas: Array[Porta], semente: int) -> void:
	var comprimento := a.distance_to(b)
	if comprimento < LADO_MINIMO:
		return
	var direcao := (b - a) / comprimento
	var normal := normal_externa(contorno, a, b)
	var lado := classificar(normal)
	var textura := textura_do_lado(lado)
	if textura == null:
		return

	var centro_da_faixa := normal * (Sala.ESPESSURA_PAREDE * 0.5)
	var t := 0.0
	while t + MODULO <= comprimento + 0.5:
		if not _cai_em_vao(a + direcao * t, a + direcao * (t + MODULO), portas, normal):
			var sprite := Sprite2D.new()
			sprite.texture = textura
			sprite.position = a + direcao * (t + MODULO * 0.5) + centro_da_faixa
			raiz.add_child(sprite)
		t += MODULO


## O canto de cada quina CONVEXA, onde a face do norte termina.
##
## Ele existe porque o norte tem topo e face e as laterais tem so topo: a quina e
## um DEGRAU, e nao um encontro de dois retangulos. Hoje so as duas quinas de
## cima tem peca -- as de baixo fazem a transicao inversa, de lateral alta para
## parede sul baixa, e sao problema proprio (PAREDE 06).
##
## O deslocamento sai da soma das duas normais externas, e nao de uma tabela: com
## tabela, a sala em L entraria com o canto no lugar errado no dia em que uma
## quina nova aparecesse.
static func _vestir_cantos(raiz: Node2D, contorno: PackedVector2Array) -> void:
	var total := contorno.size()
	for i in total:
		var anterior := contorno[(i - 1 + total) % total]
		var v := contorno[i]
		var proximo := contorno[(i + 1) % total]
		if anterior.distance_to(v) < LADO_MINIMO or v.distance_to(proximo) < LADO_MINIMO:
			continue
		var n1 := normal_externa(contorno, anterior, v)
		var n2 := normal_externa(contorno, v, proximo)
		var textura := _canto_de(classificar(n1), classificar(n2))
		if textura == null:
			continue
		var sprite := Sprite2D.new()
		sprite.texture = textura
		sprite.position = v + (n1 + n2) * (Sala.ESPESSURA_PAREDE * 0.5)
		raiz.add_child(sprite)


static func _canto_de(um: Lado, outro: Lado) -> Texture2D:
	var lados := [um, outro]
	if lados.has(Lado.NORTE) and lados.has(Lado.OESTE):
		return CANTO_NO
	if lados.has(Lado.NORTE) and lados.has(Lado.LESTE):
		return CANTO_NE
	return null


## Esta celula encosta no vao de alguma porta deste lado?
static func _cai_em_vao(de: Vector2, ate: Vector2, portas: Array[Porta],
		normal: Vector2) -> bool:
	for porta in portas:
		if porta == null or porta.esta_selada():
			continue
		# A porta pertence a este lado? A normal externa dele e o vetor dela.
		if porta.vetor().dot(normal) < 0.5:
			continue
		var meia := Porta.LARGURA * 0.5
		var eixo := (ate - de).normalized()
		var centro := porta.position.dot(eixo)
		var inicio := de.dot(eixo)
		var fim := ate.dot(eixo)
		if fim > centro - meia and inicio < centro + meia:
			return true
	return false


## Para que lado este trecho aponta.
static func classificar(normal: Vector2) -> Lado:
	if normal.y <= Sala.LIMIAR_LADO_NORTE:
		return Lado.NORTE
	if normal.x >= 0.5:
		return Lado.LESTE
	if normal.x <= -0.5:
		return Lado.OESTE
	return Lado.SUL


static func textura_do_lado(lado: Lado) -> Texture2D:
	match lado:
		Lado.NORTE:
			return MODULO_N
		Lado.SUL:
			return MODULO_S
		Lado.LESTE:
			return MODULO_L
		Lado.OESTE:
			return MODULO_O
	return null


## A normal que aponta para FORA do contorno.
##
## Mesma conta de `Sala._normal_externa`, e ela vive nos dois lugares por um
## motivo: a `Sala` a usa para decidir quem ganha face, e o renderizador para
## decidir qual modulo vestir. Enquanto a fita convive com a parede antiga as
## duas respostas tem de bater -- quando a PAREDE 13 aposentar a antiga, sobra
## esta.
static func normal_externa(contorno: PackedVector2Array, a: Vector2,
		b: Vector2) -> Vector2:
	var direcao := (b - a).normalized()
	if direcao == Vector2.ZERO:
		return Vector2.ZERO
	var candidata := Vector2(direcao.y, -direcao.x)
	var meio := (a + b) * 0.5
	if Geometry2D.is_point_in_polygon(meio + candidata * 4.0, contorno):
		return -candidata
	return candidata
