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
## **A ESTRUTURA e gerada; a SUPERFICIE e autorada.** Esta divisao foi paga com
## um erro: a primeira versao da fita desenhava tambem a superficie, em chapa
## lisa de N6, e o resultado foi uma faixa CINZA-CLARA em volta da sala. O
## motivo, medido contra a referencia de `docs/objetivo/`: o topo mede V 0,380 e
## a face 0,251, e a parede norte le escura porque METADE do que se ve dela e
## face. Leste, oeste e sul nao tinham face nenhuma -- 64 px de topo puro, 3x
## mais claros que o chao --, e viravam uma fita palida colada na borda.
##
## Entao a fita passa a vestir as texturas AUTORADAS (`parede_topo_*` e
## `parede_face*`), recortadas em celulas de 32, e quem continua gerado e so o
## que e ESTRUTURA: o canto e o batente da porta. E a mesma divisao que o resto
## do projeto ja faz -- chao e parede autorados, porta e prop gerados.
##
## **Nada aqui gira arte.** As celulas sao recortes 32x32 das texturas autoradas,
## colocadas na faixa; nenhuma passa por `rotation` nem por `flip`.

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

## Os cantos, na ordem em que o `EstiloDeParede` os guarda.
##
## Enum e nao indice solto: a PAREDE 06 acrescenta os concavos NO FIM da lista, e
## um numero cru espalhado pelo arquivo seria reescrito em silencio no dia em que
## a ordem mudasse. Mesma armadilha que `DadosArma.Comportamento` ja registra.
enum Canto { NOROESTE, NORDESTE }

## O lado da celula, e ele e o mesmo tile visual do projeto.
##
## A faixa tem 64 px de profundidade, entao cada celula da fita sao DUAS peças
## de 32x32 empilhadas: a de fora e TOPO e a de dentro e FACE -- menos no sul,
## onde as duas sao topo.
const CELULA := 32

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
		semente: int, topos: Array[Texture2D], faces: Array[Texture2D],
		estilo: EstiloDeParede = null) -> Node2D:
	var raiz := Node2D.new()
	raiz.name = "ParedeModulos"
	raiz.z_index = Z_FITA
	if contorno.size() < 3:
		return raiz

	if topos.is_empty():
		return raiz
	for i in contorno.size():
		var a := contorno[i]
		var b := contorno[(i + 1) % contorno.size()]
		_vestir_lado(raiz, contorno, a, b, portas, semente ^ (i * 0x9e3779b1),
			topos, faces)
	_vestir_cantos(raiz, contorno, estilo)
	return raiz


## Um lado vira N celulas de 32 px.
##
## A celula que ENCOSTA num vao de porta fica de fora, e nao meio de fora: a
## parede antiga aparece por baixo dela. O motivo e um numero que o plano nao
## previu -- `Porta.LARGURA` e 80, e 80 nao e multiplo de 32, entao a porta ocupa
## 2,5 celulas e as das pontas ficam meio dentro e meio fora. Resolver isso e a
## PAREDE 07; aqui o desalinhamento fica VISIVEL em vez de disfarcado.
static func _vestir_lado(raiz: Node2D, contorno: PackedVector2Array, a: Vector2,
		b: Vector2, portas: Array[Porta], semente: int, topos: Array[Texture2D],
		faces: Array[Texture2D]) -> void:
	var comprimento := a.distance_to(b)
	if comprimento < LADO_MINIMO:
		return
	var direcao := (b - a) / comprimento
	var normal := normal_externa(contorno, a, b)
	var lado := classificar(normal)

	# O SUL mostra so o topo, e isso e fisica e nao economia: a face de uma
	# parede ao sul olha para longe da camera, escondida pela propria parede. Nos
	# outros tres lados ela aparece -- de frente no norte, de esguelha no leste e
	# no oeste --, e e ela que faz a faixa ler escura.
	var so_topo := lado == Lado.SUL
	var t := 0.0
	var indice := 0
	while t + CELULA <= comprimento + 0.5:
		if not _cai_em_vao(a + direcao * t, a + direcao * (t + CELULA), portas, normal):
			var meio := a + direcao * (t + CELULA * 0.5)
			var chave := semente ^ (indice * 0x85ebca6b)
			# A peça de FORA: topo, sempre.
			_peca(raiz, _sorteia(topos, chave), meio + normal * (CELULA * 1.5))
			# A de DENTRO: face, menos no sul.
			var interna := _sorteia(topos, chave ^ 0x27d4eb2f) if so_topo \
				else _sorteia(faces, chave ^ 0x165667b1)
			_peca(raiz, interna, meio + normal * (CELULA * 0.5))
		t += CELULA
		indice += 1


## Uma celula de 32x32 recortada da textura autorada.
##
## `region_rect` e nao uma textura por celula: as autoradas tem 64x64, entao cada
## uma ja carrega QUATRO celulas diferentes. Recortar multiplica a variedade por
## quatro sem um byte novo em disco, e e o que evita a faixa virar o mesmo
## quadrado repetido.
static func _peca(raiz: Node2D, textura: Texture2D, onde: Vector2) -> void:
	if textura == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = textura
	sprite.region_enabled = true
	var largura := int(textura.get_width())
	var altura := int(textura.get_height())
	var colunas := maxi(largura / CELULA, 1)
	var linhas := maxi(altura / CELULA, 1)
	var i := absi(hash(onde)) % (colunas * linhas)
	sprite.region_rect = Rect2(
		float((i % colunas) * CELULA), float((i / colunas) * CELULA),
		float(CELULA), float(CELULA))
	sprite.position = onde
	raiz.add_child(sprite)


static func _sorteia(lista: Array[Texture2D], chave: int) -> Texture2D:
	if lista.is_empty():
		return null
	return lista[absi(chave) % lista.size()]


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
static func _vestir_cantos(raiz: Node2D, contorno: PackedVector2Array,
		estilo: EstiloDeParede) -> void:
	if estilo == null:
		return
	var total := contorno.size()
	for i in total:
		var anterior := contorno[(i - 1 + total) % total]
		var v := contorno[i]
		var proximo := contorno[(i + 1) % total]
		if anterior.distance_to(v) < LADO_MINIMO or v.distance_to(proximo) < LADO_MINIMO:
			continue
		var n1 := normal_externa(contorno, anterior, v)
		var n2 := normal_externa(contorno, v, proximo)
		var textura := estilo.canto(_canto_de(classificar(n1), classificar(n2)))
		if textura == null:
			continue
		var sprite := Sprite2D.new()
		sprite.texture = textura
		sprite.position = v + (n1 + n2) * (Sala.ESPESSURA_PAREDE * 0.5)
		raiz.add_child(sprite)


## Qual canto do kit cobre esta quina. -1 quando o kit ainda nao tem um.
static func _canto_de(um: Lado, outro: Lado) -> int:
	var lados := [um, outro]
	if lados.has(Lado.NORTE) and lados.has(Lado.OESTE):
		return Canto.NOROESTE
	if lados.has(Lado.NORTE) and lados.has(Lado.LESTE):
		return Canto.NORDESTE
	return -1


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
