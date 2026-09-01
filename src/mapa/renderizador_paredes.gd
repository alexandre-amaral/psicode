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
enum Canto { NOROESTE, NORDESTE, SUDOESTE, SUDESTE }

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
		cantos: Array[Texture2D], peso_comum: float = 0.65,
		espacamento: int = 2, abertos: Array[Vector2] = []) -> Node2D:
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
		# LADOS ABERTOS: a boca de um corredor nao e parede.
		#
		# Um corredor e um retangulo com as duas pontas abertas, e sem esta lista
		# a fita fecharia as bocas dele -- uma parede no meio da passagem, que e
		# exatamente o que a armadilha de `Porta.LARGURA` contra
		# `largura_corredor` ja descreve por outro caminho.
		if _e_aberto(normal_externa(contorno, a, b), abertos):
			continue
		_vestir_lado(raiz, contorno, a, b, portas, semente ^ (i * 0x9e3779b1),
			topos, faces, peso_comum, espacamento)
	_vestir_cantos(raiz, contorno, cantos)
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
		faces: Array[Texture2D], peso_comum: float, espacamento: int) -> void:
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

	# A GRADE E ANCORADA NA SALA, e nao no vertice de cada lado.
	#
	# Andar a partir do vertice fazia cada lado ter a propria grade, e a mesma
	# porta caia em lugares diferentes dela conforme a paridade da meia dimensao
	# daquela sala: nos lados de 960 o centro batia numa borda de celula e nos de
	# 544 no MEIO de uma. O sintoma era a porta reservar 2 celulas num lado e 3 no
	# outro para o mesmo vao de 64 -- e os 32 px de sobra apareciam como parede
	# antiga ao lado do batente.
	#
	# Ancorada em multiplos de 32 nas coordenadas da sala, a borda de celula cai
	# no centro da porta em TODO lado, e o vao de 64 reserva 2 celulas exatas em
	# qualquer forma de sala. O preco e a ponta de cada lado poder sobrar menos que
	# uma celula -- e ela nao fica descoberta: a peca da ponta e recortada na
	# medida, o que a arte permite porque a celula ja e um `region_rect`.
	var eixo := Vector2(absf(direcao.x), absf(direcao.y))
	if eixo.x < 0.99 and eixo.y < 0.99:
		# Lado diagonal: nao ha eixo em que ancorar, entao ele volta a andar do
		# vertice. Nenhuma sala em disco tem um, e a saida existe para nao virar
		# buraco no dia em que uma tiver.
		eixo = Vector2(1.0, 0.0) if absf(direcao.x) >= absf(direcao.y) else Vector2(0.0, 1.0)

	var s0 := a.dot(eixo)
	var s1 := b.dot(eixo)
	var passo := direcao.dot(eixo)
	var inicio := minf(s0, s1)
	var fim := maxf(s0, s1)
	var centro_da_faixa := normal * (Sala.ESPESSURA_PAREDE * 0.5)

	# Quantas celulas passaram desde a ultima ESPECIAL. Comeca alto para a
	# primeira celula do lado poder ser especial -- comecar em zero faria toda
	# parede do jogo abrir com `espacamento` celulas comuns, que e um padrao
	# regular nascido de um detalhe de implementacao.
	var desde_especial := espacamento
	var c := floorf(inicio / CELULA) * CELULA
	while c < fim - 0.5:
		var p0 := maxf(c, inicio)
		var p1 := minf(c + CELULA, fim)
		var largura := p1 - p0
		if largura > 0.5:
			var meio := (p0 + p1) * 0.5
			var ponto := a + direcao * ((meio - s0) * passo)
			if not _cai_em_vao_escalar(p0, p1, portas, normal, eixo):
				var chave := semente ^ (int(c / CELULA) * 0x85ebca6b)
				var recorte := Vector2(p0 - c, largura)
				_peca(raiz, _sorteia(topos, chave), ponto + normal * (CELULA * 1.5),
					chave, recorte, direcao)
				var interna: Texture2D = null
				if so_topo:
					interna = _sorteia(topos, chave ^ 0x27d4eb2f)
				else:
					var especial := _quer_especial(chave, peso_comum) \
						and desde_especial >= espacamento
					interna = _face_da_celula(faces, chave, especial)
					desde_especial = 0 if especial else desde_especial + 1
				_peca(raiz, interna, ponto + normal * (CELULA * 0.5),
					chave ^ 0x9e3779b1, recorte, direcao)
		c += CELULA


## Uma celula recortada da textura autorada, e ela pode ser MENOR que 32.
##
## `region_rect` e nao uma textura por celula: as autoradas tem 64x64, entao cada
## uma ja carrega QUATRO celulas diferentes. Recortar multiplica a variedade por
## quatro sem um byte novo em disco.
##
## `recorte` e (deslocamento, largura) dentro da celula nominal, e ele existe para
## a ponta de um lado nao ficar descoberta quando ela sobra menos que 32 px. A
## peca curta mostra um PEDACO da mesma arte, e nao a arte espremida -- esticar
## quebraria a escala de pixel, que no projeto e sempre inteira.
static func _peca(raiz: Node2D, textura: Texture2D, onde: Vector2, chave: int,
		recorte: Vector2, direcao: Vector2) -> void:
	if textura == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = textura
	sprite.region_enabled = true
	var colunas := maxi(int(textura.get_width()) / CELULA, 1)
	var linhas := maxi(int(textura.get_height()) / CELULA, 1)
	var i := absi(chave) % (colunas * linhas)
	var base := Vector2(float((i % colunas) * CELULA), float((i / colunas) * CELULA))
	# O recorte corre no eixo da PAREDE: em x nos lados horizontais, em y nos
	# verticais. Trocar os dois faria a peca curta cortar a altura da faixa em vez
	# do comprimento dela.
	if absf(direcao.x) >= absf(direcao.y):
		sprite.region_rect = Rect2(base + Vector2(recorte.x, 0.0),
			Vector2(recorte.y, float(CELULA)))
	else:
		sprite.region_rect = Rect2(base + Vector2(0.0, recorte.x),
			Vector2(float(CELULA), recorte.y))
	sprite.position = onde
	raiz.add_child(sprite)


## Este trecho do lado encosta no vao de alguma porta dele?
##
## Escalar e nao vetorial: com a grade ancorada na sala, o que se compara e a
## posicao AO LONGO da parede, e projetar duas vezes o mesmo ponto so criaria
## chance de erro de sinal.
static func _cai_em_vao_escalar(de: float, ate: float, portas: Array[Porta],
		normal: Vector2, eixo: Vector2) -> bool:
	for porta in portas:
		if porta == null or porta.esta_selada():
			continue
		if porta.vetor().dot(normal) < 0.5:
			continue
		var centro := porta.position.dot(eixo)
		var meia := Porta.LARGURA * 0.5
		if ate > centro - meia + 0.5 and de < centro + meia - 0.5:
			return true
	return false


## Esta celula sorteou uma ESPECIAL?
##
## O sorteio e puro: mesma chave, mesma resposta. Sair da sala e voltar mostra a
## mesma parede, que e a regra que o projeto ja aplica ao chao, a face e ao prop.
static func _quer_especial(chave: int, peso_comum: float) -> bool:
	return float(absi(chave) % 10000) / 10000.0 >= peso_comum


## A face de uma celula: a COMUM, ou uma das especiais.
##
## A comum e a primeira da lista, e isso e contrato com o `tipo_*.tres`: a face
## que da nome ao tipo (`parede_face_combate`) vem primeiro, e os modulos vem
## depois. Lista de um elemento so nunca sorteia especial, e e o que faz um tipo
## sem modulos continuar funcionando.
static func _face_da_celula(faces: Array[Texture2D], chave: int,
		especial: bool) -> Texture2D:
	if faces.is_empty():
		return null
	if not especial or faces.size() < 2:
		return faces[0]
	return faces[1 + absi(chave ^ 0x165667b1) % (faces.size() - 1)]


static func _e_aberto(normal: Vector2, abertos: Array[Vector2]) -> bool:
	for lado in abertos:
		if normal.dot(lado) > 0.5:
			return true
	return false


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
## O renderizador recebe LISTAS de textura, e nao o `EstiloDeParede`.
##
## Quem resolve o kit e a `Sala`, que sabe cair no neutro quando nao ha
## `DadosSala` -- e isso acontece de verdade: sala aberta sozinha no editor, a
## amostra que o catalogo instancia, e toda suite que monta uma sala sem visual.
## Com o renderizador lendo o recurso, essas salas perdiam os cantos em silencio
## enquanto a fita continuava desenhando, e o portao pegou exatamente isso.
static func _vestir_cantos(raiz: Node2D, contorno: PackedVector2Array,
		cantos: Array[Texture2D]) -> void:
	if cantos.is_empty():
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
		var indice := _canto_de(classificar(n1), classificar(n2))
		var textura: Texture2D = cantos[indice] if indice >= 0 and indice < cantos.size() else null
		if textura == null:
			continue
		var sprite := Sprite2D.new()
		sprite.texture = textura
		sprite.position = v + (n1 + n2) * (Sala.ESPESSURA_PAREDE * 0.5)
		raiz.add_child(sprite)


## Qual canto do kit cobre esta quina. -1 quando a quina nao e um encontro de um
## lado horizontal com um vertical -- o que so acontece em contorno degenerado.
##
## As quinas CONCAVAS caem no mesmo mapa, de proposito. Medindo a geometria, as
## duas familias pedem o mesmo desenho: em ambas o pilar fica na quina virada
## para a sala, e o que muda e so de que lado ela esta. Numa convexa as duas
## faixas contornam o pilar por fora; numa concava elas se sobrepoem debaixo
## dele. O plano previa oito pecas; quatro fazem o trabalho, e o enum tem espaco
## para as concavas ganharem desenho proprio se um dia alguem provar que precisam.
static func _canto_de(um: Lado, outro: Lado) -> int:
	var lados := [um, outro]
	var norte := lados.has(Lado.NORTE)
	var sul := lados.has(Lado.SUL)
	if lados.has(Lado.OESTE):
		if norte:
			return Canto.NOROESTE
		if sul:
			return Canto.SUDOESTE
	if lados.has(Lado.LESTE):
		if norte:
			return Canto.NORDESTE
		if sul:
			return Canto.SUDESTE
	return -1


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
