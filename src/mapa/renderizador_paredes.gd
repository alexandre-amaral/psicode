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

## Quanto a fita desenha ALEM do contorno.
##
## Duas celulas: a de fora e topo, a de dentro e face. Este e o numero que a
## camera precisa saber para mostrar a parede inteira e nem um pixel do vazio que
## vem depois -- e ele nasce AQUI, de quem desenha, e nao de
## `Sala.ESPESSURA_PAREDE`, que descreve a GEOMETRIA (colisao, corredor, camera
## da parede antiga).
##
## Os dois valem 64 hoje, e e por isso que a divergencia seria silenciosa: quem
## mudasse um so veria o sintoma como uma tira preta na borda -- ou meia parede
## cortada -- e nao como erro. Por isso o portao de `teste_camera.gd` nao compara
## as duas constantes: ele MEDE onde a fita chegou.
static func alcance(perfil: PerfilDeParede = null) -> float:
	return (perfil if perfil != null else PerfilDeParede.new()).alcance()


## O alcance POR EIXO. Ver `PerfilDeParede.alcance_por_eixo()`.
static func alcance_por_eixo(perfil: PerfilDeParede = null) -> Vector2:
	return (perfil if perfil != null else PerfilDeParede.new()).alcance_por_eixo()


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

## A rampa neutra, ESPELHADA de `tools/texturas/paleta.gd`.
##
## Espelhada e nao lida: `tools/` esta em `exclude_filter` do export, entao
## `Paleta` **nao existe na build**. Um `Paleta.neutro()` aqui roda no editor e
## some no jogo exportado -- o pior tipo de defeito, porque a maquina de quem
## desenvolve nunca o mostra. O precedente ja existe em `Sombra.COR` e em
## `Corredor.COR_CHAO_EMERGENCIA`.
##
## O preco do espelho e divergencia silenciosa, e por isso ele e COBRADO:
## `teste_texturas.gd` compara estas tres com `Paleta.neutro()`, no mesmo desenho
## do espelho de `Paleta.ATOR`.
const N1 := Color("0b0d16")
const N4 := Color("242a3a")
const N7 := Color("5a6480")

## Onde o acabamento desenha, medido do contorno para FORA.
##
## Todos DENTRO de `alcance()` = 64. Um pixel alem e a camera passa a mostrar
## vazio na borda do quadro, sem erro nenhum no console -- e por isso
## `teste_camera.gd` mede toda peca da fita, e nao so os sprites.
## As cores do MODO SILHUETA, e elas nao sao arte.
##
## Chapadas de proposito: o teste que elas servem e "a sala tem forma de sala?".
## Textura nenhuma, detalhe nenhum. Se a silhueta ler como grade de construcao,
## nao ha arte que conserte -- o problema esta na geometria, e e ela que muda.
const COR_TOPO := Color("31384c")
const COR_FACE := Color("1a1e2b")
## O BISEL entre os dois, e o degrau entre as tres cores e o proprio teste: se em
## silhueta a faixa ainda parecer um bloco, nao ha arte que conserte.
const COR_BISEL := N4

## Quanto o BISEL escurece a chapa que ele corta.
##
## Ele e a MESMA textura do topo multiplicada por isto, e nao uma faixa chapada:
## o que se quer ali e "a chapa dobra e pega menos luz", que e material, e nao
## "alguem desenhou uma linha por cima", que e o outline que a meia-esquadria
## existe para nao ter.
##
## Mais azul que cinza porque a rampa neutra do projeto e fria -- N1 e quase
## azul puro --, entao escurecer para o cinza descolaria o bisel da propria
## sombra da parede.
const TINTA_DO_BISEL := Color(0.55, 0.57, 0.66)

const COSTURA := 32.0
const SOMBRA_DA_COSTURA := 2.0
const LABIO := 1.0
const BISEL := 2.0

## A LINHA DE CONTATO parede/chao, em px.
##
## Dois e nao um: a 1 px ela some contra a textura da face em metade dos
## trechos, e uma linha que aparece as vezes nao ensina nada. Tres ja le como
## uma faixa propria e comeca a competir com a costura, que fica logo acima.
const CONTATO := 2.0

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
		espacamento: int = 2, abertos: Array[Vector2] = [],
		perfil: PerfilDeParede = null, silhueta: bool = false) -> Node2D:
	var raiz := Node2D.new()
	raiz.name = "ParedeModulos"
	raiz.z_index = Z_FITA
	if contorno.size() < 3:
		return raiz

	var regra := perfil if perfil != null else PerfilDeParede.new()
	# A ANCORA da textura e o canto da sala, e nao o inicio de cada faixa.
	#
	# E ela que faz duas faixas vizinhas continuarem o mesmo desenho em vez de
	# cada uma recomecar a textura do zero -- e recomecar e exatamente o que
	# produz a costura visivel que este epico existe para apagar.
	var ancora := _caixa(contorno).position

	if topos.is_empty() and not silhueta:
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
			semente, topos, faces, peso_comum, espacamento, regra, ancora, silhueta)
	_fechar_quinas(raiz, contorno, regra, topos, faces, ancora, silhueta,
		abertos, semente)
	return raiz


## Um lado vira UMA FAIXA CONTINUA por trecho, e nao N celulas de 32.
##
## **Esta e a mudanca que o epico da moldura existe para fazer.** Antes, cada
## lado instanciava dois `Sprite2D` por celula -- cerca de 360 por sala --, e
## cada um deles recomecava a textura do zero. O resultado era o defeito que o
## dono do projeto descreveu: a parede lia como `|tile|tile|tile|`, uma fileira
## de blocos em volta da sala, e nao como uma superficie que a delimita.
##
## A grade de 32 NAO morreu -- ela so parou de ser desenhada. Colisao, geracao,
## porta, mapa e posicionamento continuam nela. **Grade logica nao e grade
## visual**, e separar as duas e o plano inteiro.
##
## O trecho vem PRIMEIRO agora. Antes ele era acumulado dentro do laco de
## celulas, para o acabamento; agora ele e a primeira etapa e a superficie nasce
## dele. E isso traz de graca o corte da porta: um vao parte a faixa em duas em
## vez de abrir um buraco de celulas puladas.
static func _vestir_lado(raiz: Node2D, contorno: PackedVector2Array, a: Vector2,
		b: Vector2, portas: Array[Porta], semente: int, semente_da_sala: int,
		topos: Array[Texture2D],
		faces: Array[Texture2D], peso_comum: float, espacamento: int,
		perfil: PerfilDeParede, ancora: Vector2, silhueta: bool) -> void:
	var comprimento := a.distance_to(b)
	if comprimento < LADO_MINIMO:
		return
	var normal := normal_externa(contorno, a, b)
	var lado := classificar(normal)

	var fim_face := perfil.fim_da_face(lado)
	var fundo := perfil.profundidade(lado)
	if fundo <= 0.0:
		return

	# A textura de cada superficie e sorteada UMA VEZ por lado, e nao por celula.
	#
	# Sortear por celula era o que produzia a variedade -- e tambem o que
	# denunciava a celula. Com uma escolha por lado, a variedade passa a
	# acontecer entre SALAS e entre LADOS, que e onde o jogador consegue le-la
	# como material e nao como grade.
	# O TOPO e sorteado UMA VEZ POR SALA; a FACE, uma vez por lado.
	#
	# Os dois ja sairam do mesmo sorteio por lado, e o resultado era a sala
	# vestir tres tijolos diferentes ao mesmo tempo -- norte com um, leste com
	# outro, sul com um terceiro. O dono descreveu como "cada orientacao recebe um
	# tamanho e uma quantidade diferentes de tijolos".
	#
	# A distincao nao e capricho: o topo e a superficie NEUTRA e CONTINUA, a
	# mesma que da a volta na sala e atravessa as quinas com a UV ancorada no
	# contorno. Duas variantes na mesma volta quebram essa continuidade num lugar
	# onde ela e a unica coisa que segura a leitura. A FACE e o oposto -- ela
	# carrega identidade, e a variedade entre lados e o que produz a biblioteca.
	var textura_topo := _sorteia(topos, semente_da_sala)
	var textura_face := _face_da_celula(faces, semente,
		_quer_especial(semente, peso_comum))

	# O TOPO ATRAVESSA O VAO; a FACE e que abre. E a regra que o projeto ja
	# escreve e que o codigo nao cumpria.
	#
	# Sobre a porta ha verga: a superficie de cima da parede passa por cima da
	# passagem de verdade. Cortando o topo junto com a face, o que sobrava alem da
	# porta era um retangulo do tamanho do vao vezes a profundidade da faixa --
	# **sem nada desenhado**. Com o perfil C, 32 px de faixa, a arte da porta
	# cobria quase tudo e ninguem via; com 96 e 104, o buraco virou uma janela
	# preta de 64x96 px em cada porta. Medido: 1,9% do quadro numa sala de quatro
	# portas, e o dono viu antes de a regua achar.
	#
	# Quem tem abertura e a face, e so ela -- o resto do acabamento (linha de
	# contato, costura, bisel) acompanha a face, porque e ela que termina ali.
	var fim_topo := fundo
	var borda := perfil.borda_externa_sul if lado == Lado.SUL else 0.0
	if borda > 0.0:
		fim_topo = fundo - borda
	_superficie(raiz, a, b, normal, fim_face, fim_topo, textura_topo,
		ancora, silhueta, COR_TOPO)
	if borda > 0.0:
		_borda_externa_do_sul(raiz, a, b, normal, fim_topo, fundo)

	# A SUBDIVISAO DO TOPO (#241), e ela acompanha o TOPO e nao a face: o topo
	# atravessa o vao da porta, entao desenhar bisel e borda por trecho os
	# interromperia em cima de cada porta -- a mesma falha que a face teve por
	# seis issues, so que ao contrario.
	var bisel := perfil.bisel_do_topo
	if bisel > 0.0 and fim_face + bisel <= fim_topo:
		_superficie(raiz, a, b, normal, fim_face, fim_face + bisel, textura_topo,
			ancora, silhueta, COR_BISEL, TINTA_DO_BISEL)
	var borda_topo := perfil.borda_do_topo
	if borda_topo > 0.0 and fim_topo - borda_topo > fim_face:
		_banda(raiz, a, b, normal, fim_topo - borda_topo, fim_topo, N1)

	for trecho in trechos_livres(contorno, a, b, portas):
		var de: Vector2 = trecho[0]
		var ate: Vector2 = trecho[1]
		if de.distance_to(ate) < 1.0:
			continue
		if fim_face > 0.0:
			_superficie(raiz, de, ate, normal, 0.0, fim_face, textura_face,
				ancora, silhueta, COR_FACE)
		_vestir_acabamento(raiz, de, ate, normal, lado, fim_face <= 0.0, fundo,
			fim_face, perfil.borda_do_topo > 0.0)


## OS TRECHOS de um lado: ele inteiro, menos os vaos de porta.
##
## Cortado no vao EXATO e nao em celulas inteiras. A regra antiga tirava toda
## celula que ENCOSTAVA no vao -- 128 px de buraco para 64 px de passagem --, e
## ela existia porque a peca era uma celula: meia celula nao podia ser desenhada.
## Uma faixa pode acabar em qualquer lugar, entao o buraco passa a ter o tamanho
## da porta.
##
## E isso alinha o visual com a COLISAO, que ja cortava assim em
## `Sala._subtrechos()`. Eram duas respostas para "onde ha parede", e a
## divergencia entre elas ja custou uma issue.
static func trechos_livres(contorno: PackedVector2Array, a: Vector2, b: Vector2,
		portas: Array[Porta]) -> Array[PackedVector2Array]:
	var achados: Array[PackedVector2Array] = []
	var comprimento := a.distance_to(b)
	if comprimento < LADO_MINIMO:
		return achados
	var direcao := (b - a) / comprimento
	var normal := normal_externa(contorno, a, b)

	# Os vaos, medidos AO LONGO do lado.
	var vaos: Array[Vector2] = []
	for porta in portas:
		if porta == null or porta.esta_selada():
			continue
		if porta.vetor().dot(normal) < 0.5:
			continue
		var onde := (porta.position - a).dot(direcao)
		var meia := Porta.LARGURA * 0.5
		vaos.append(Vector2(onde - meia, onde + meia))
	vaos.sort_custom(func(x: Vector2, y: Vector2) -> bool: return x.x < y.x)

	var cursor := 0.0
	for vao in vaos:
		var borda := clampf(vao.x, 0.0, comprimento)
		if borda - cursor > 1.0:
			achados.append(PackedVector2Array([a + direcao * cursor, a + direcao * borda]))
		cursor = maxf(cursor, clampf(vao.y, 0.0, comprimento))
	if comprimento - cursor > 1.0:
		achados.append(PackedVector2Array([a + direcao * cursor, b]))
	return achados


## A ESPESSURA DO SUL, em dois degraus de valor ate o vazio.
##
## O §15 do plano pede que a sul seja construida ao contrario da norte: chao,
## topo, e entao altura para BAIXO, em direcao ao exterior. E o que faz o piso
## parecer encaixado numa caixa em vez de terminar numa linha.
##
## Ela NAO usa textura de face, e a distincao nao e de nome. Face e superficie
## vista de FRENTE, e o lado sul olha para longe da camera -- desenhar
## `parede_face` ali seria pintar o que o jogador nao ve, e e por isso que
## `teste_camada_visual.gd` proibe textura de face abaixo da borda sul. O que a
## espessura precisa dizer nao e "material": e "isto continua, e acaba".
##
## Dois degraus e nao um gradiente, pela mesma razao da `SombraDeParede`: e pixel
## art, e o §64 pede passos de valor claros em vez de rampa suave que pareca 3D
## pre-renderizado.
static func _borda_externa_do_sul(raiz: Node2D, de: Vector2, ate: Vector2,
		normal: Vector2, inicio: float, fim: float) -> void:
	var meio := inicio + (fim - inicio) * 0.5
	_banda(raiz, de, ate, normal, inicio, meio, N1)
	_banda(raiz, de, ate, normal, meio, fim, Color("05060b"))


## Uma SUPERFICIE continua: um quad texturizado que cobre o trecho inteiro.
##
## `Polygon2D` com `texture_repeat` e nao um sprite por celula, e a diferenca
## nao e de desempenho: um sprite por celula so sabe desenhar a textura inteira,
## entao cada celula recomeca o desenho e a emenda aparece. Um quad longo com UV
## ancorada na SALA deixa a textura correr por cima da grade -- ela continua
## ladrilhando de 64 em 64, mas nao ha nada dizendo onde uma peca acaba.
##
## `silhueta` desenha em cor CHAPADA, sem textura. E o modo de diagnostico do
## plano: se a sala parecer uma grade de construcao mesmo sem textura nenhuma, o
## problema e a geometria, e nao a arte -- e nao adianta avancar.
static func _superficie(raiz: Node2D, de: Vector2, ate: Vector2, normal: Vector2,
		inicio: float, fim: float, textura: Texture2D, ancora: Vector2,
		silhueta: bool, cor: Color, tinta: Color = Color.WHITE) -> void:
	if fim - inicio < 0.5:
		return
	# `position` no MEIO da faixa e o poligono relativo a ela.
	#
	# Nao e arrumacao: os portoes que perguntam "onde a parede chegou" e "nenhuma
	# peca cai na area jogavel" leem `position`. Com o poligono em coordenada
	# absoluta e a posicao em zero, toda peca responderia a ORIGEM da sala -- que
	# fica dentro do contorno, e faria o portao acusar invasao em todas elas.
	var centro := (de + ate) * 0.5 + normal * ((inicio + fim) * 0.5)
	var quad := Polygon2D.new()
	quad.position = centro
	quad.polygon = PackedVector2Array([
		de + normal * inicio - centro,
		ate + normal * inicio - centro,
		ate + normal * fim - centro,
		de + normal * fim - centro,
	])
	if silhueta or textura == null:
		quad.color = cor
	else:
		# `color` MULTIPLICA a textura num Polygon2D. E como o bisel escurece a
		# chapa sem deixar de ser a chapa.
		quad.color = tinta
		quad.texture = textura
		# Sem isto a textura sai esticada UMA vez no tamanho do quad: o projeto
		# nao define `default_texture_repeat`, entao o padrao e Disabled.
		quad.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		# A UV anda com a peca: o deslocamento compensa a `position` para o
		# desenho continuar ancorado na SALA. Sem o `+ centro`, cada faixa
		# recomecaria a textura no proprio inicio -- que e a emenda visivel que
		# este epico existe para apagar.
		quad.texture_offset = centro - ancora
	raiz.add_child(quad)


## O ACABAMENTO de um trecho: a costura onde a superficie vira, e o bisel da
## aresta externa.
##
## **Isto e a banda que faltava, e ela faltava de forma literal.** Ate aqui NADA
## desenhava em `n*32`: a celula de topo e a de face eram dois recortes de 32x32
## de texturas diferentes coladas lado a lado, e o olho lia "a textura mudou
## aqui" em vez de "a superficie virou aqui". Medido no perfil vertical da
## captura, a passagem de topo para face acontecia em ZERO pixel de transicao.
##
## Na referencia (`docs/objetivo/isaac.png`) o que faz a faixa ler como parede
## nao e a textura dela: e onde as bandas comecam e acabam. Medido la, do chao
## para fora: 3 px de linha de contato a 0,85x o chao, a superficie, um labio
## aceso de 3 px, e so entao a aresta externa.
##
## **Desenhado em CODIGO, e nao em arte, por uma razao de arquitetura e nao de
## economia.** As duas bandas sao direcionais, e `_peca()` sorteia um dos quatro
## quadrantes por hash: arte direcional cairia num lado aleatorio na orientacao
## errada. Assar a costura no topo obrigaria o topo a ter versao por lado -- 3
## variantes x 4 lados = 12 PNGs -- que e a explosao de arquivo que o
## `EstiloDeParede` existe para evitar. E um retangulo nao tem orientacao para
## violar: ele nasce de coordenadas, nao de uma arte girada, entao o portao de
## giro nao precisa de excecao nenhuma.
##
## Cabe na regra que o cabecalho deste arquivo ja escreve: **a ESTRUTURA e
## gerada, a SUPERFICIE e autorada.** Costura e bisel sao onde duas superficies
## se encontram, e nao de que material elas sao.
##
## **A luz vem de cima e da esquerda** (`LOW_TOPDOWN_SQUARED.md` §18), e a tabela
## abaixo nao e nova: e a mesma que `gerar_modulo_n/s/l/o()` ja aplica e ja
## defende. Em especial o OESTE nao e o LESTE espelhado -- espelhar inverteria a
## luz junto, que e o comentario que aquele gerador carrega desde que nasceu.
##
## | lado | aresta interna | costura em `n*32` | aresta externa |
## |---|---|---|---|
## | NORTE | -- (o pe da face ja traz sombra na arte) | sombra + labio | bisel |
## | SUL | N4 e N7: o chanfro aceso virado para a sala | -- (sem face) | bisel |
## | LESTE | N7: a aresta virada para a sala pega a luz | sombra + labio | bisel |
## | OESTE | -- | sombra, SEM labio | bisel, e o labio vai AQUI |
##
## O par claro/escuro e mudanca de VALOR e nao brilho, e isso e deliberado: uma
## linha clara e continua na borda da sala e exatamente o filete de neon que o
## projeto ja removeu uma vez. O labio tem 1 px, e no meio da faixa.
static func _vestir_acabamento(raiz: Node2D, de: Vector2, ate: Vector2,
		normal: Vector2, lado: Lado, so_topo: bool, fundo: float,
		costura: float, tem_borda_de_topo: bool = false) -> void:
	# A COSTURA: onde o topo vira face. Nao existe no sul, que nao tem face.
	if not so_topo and costura > SOMBRA_DA_COSTURA:
		_banda(raiz, de, ate, normal, costura - SOMBRA_DA_COSTURA, costura, N4)
		if lado != Lado.OESTE:
			_banda(raiz, de, ate, normal, costura, costura + LABIO, N7)

	# A LINHA DE CONTATO: onde a parede encontra o chao, e ela e CONTINUA.
	#
	# Ela e a peca mais barata do epico e uma das que mais paga. Sem ela o olho
	# tem de deduzir onde a arena comeca a partir da textura; com ela, a resposta
	# esta desenhada. O plano a chama de `inner_wall_line` e pede 1 a 3 px
	# acompanhando **todo** o contorno interno.
	#
	# **Em todos os quatro lados**, e nao so nos que pegam luz. Uma linha que
	# aparece em tres lados e some no quarto e pior que nenhuma: ela ensina uma
	# regra e depois a quebra, e o lado sem ela passa a ler como um vao. E ela e
	# ESCURA e nao acesa -- o contato entre duas superficies e sombra, e uma
	# linha clara continua na borda da sala e o filete de neon que o projeto ja
	# removeu uma vez.
	_banda(raiz, de, ate, normal, 0.0, CONTATO, N1)

	# A ARESTA ACESA, logo depois dela e so onde a luz bate.
	if lado == Lado.SUL:
		_banda(raiz, de, ate, normal, CONTATO, CONTATO + LABIO, N7)
	elif lado == Lado.LESTE:
		_banda(raiz, de, ate, normal, CONTATO, CONTATO + LABIO, N7)

	# O BISEL EXTERNO: a faixa cai de valor antes de encontrar o vazio.
	#
	# Contra o vazio ele quase nao aparece -- `default_clear_color` do projeto JA
	# e N0 --, e nao e para ele que existe: e para a boca do corredor, onde duas
	# faixas se encontram sem separacao, e para a quina, onde o canto encosta nos
	# dois lados.
	#
	# **Ele SAI quando o topo tem borda propria.** A borda de #241 e a mesma
	# ideia com 4 px e desenhada ao longo do lado inteiro; manter os dois somaria
	# duas faixas escuras encostadas, e a de cima ficaria interrompida em cada
	# porta enquanto a de baixo atravessa -- duas respostas para onde a parede
	# acaba, que e o defeito que a face ja pagou.
	if not tem_borda_de_topo:
		_banda(raiz, de, ate, normal, fundo - BISEL, fundo, N1)
		if lado == Lado.OESTE:
			_banda(raiz, de, ate, normal, fundo - BISEL - LABIO, fundo - BISEL, N7)


## Uma tira retangular ao longo de um trecho do contorno.
##
## `position` no meio e o poligono RELATIVO a ela: os portoes que medem onde a
## fita chegou leem `position` mais a caixa local, e um poligono em coordenada
## absoluta com `position` em zero faria todos eles medirem a origem da sala.
static func _banda(raiz: Node2D, de: Vector2, ate: Vector2, normal: Vector2,
		inicio: float, fim: float, cor: Color) -> void:
	if fim - inicio < 0.5 or de.distance_to(ate) < 0.5:
		return
	var centro := (de + ate) * 0.5 + normal * ((inicio + fim) * 0.5)
	var poly := Polygon2D.new()
	poly.color = cor
	poly.position = centro
	poly.polygon = PackedVector2Array([
		de + normal * inicio - centro,
		ate + normal * inicio - centro,
		ate + normal * fim - centro,
		de + normal * fim - centro,
	])
	raiz.add_child(poly)


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


## A QUINA E FECHADA, e nao decorada.
##
## Antes cada quina recebia um sprite de **64x64** desenhado POR CIMA das
## celulas vizinhas: uma laje com um pilar, com aresta acesa, cinta e rebites.
## Ele existia porque a quina era um DEGRAU entre um lado com face e outro sem,
## e o pilar escondia o degrau.
##
## Com a faixa fina do perfil C -- 16 a 24 px -- aquela peca passou a ser tres
## vezes maior que a parede que ela fecha, e virou o defeito mais visivel da
## sala: **quatro blocos dominantes nos cantos fazem a sala inteira parecer
## construida com cubos.** E a §28 do plano: o canto CONECTA superficies, ele
## nao e um pilar.
##
## Entao ele deixa de ser arte e vira geometria: um quad do tamanho exato do vao
## entre as duas faixas, com a MESMA textura de topo e a MESMA ancora de UV. Ele
## nao se ve -- e esse e o ponto. A quina passa a ser o lugar onde duas
## superficies se encontram, e nao uma peca em cima delas.
##
## O `cantos` continua na assinatura de `construir()` porque o kit ainda o
## declara; ele so nao e mais desenhado. Tirar o campo e outra issue, e ela nao
## tem pressa -- campo nao usado nao aparece na tela.
static func _fechar_quinas(raiz: Node2D, contorno: PackedVector2Array,
		perfil: PerfilDeParede, topos: Array[Texture2D],
		faces: Array[Texture2D], ancora: Vector2,
		silhueta: bool, abertos: Array[Vector2] = [],
		semente_da_sala: int = 0) -> void:
	var total := contorno.size()
	for i in total:
		var anterior := contorno[(i - 1 + total) % total]
		var v := contorno[i]
		var proximo := contorno[(i + 1) % total]
		if anterior.distance_to(v) < LADO_MINIMO or v.distance_to(proximo) < LADO_MINIMO:
			continue
		var n1 := normal_externa(contorno, anterior, v)
		var n2 := normal_externa(contorno, v, proximo)
		if n1 == Vector2.ZERO or n2 == Vector2.ZERO:
			continue
		# Quina de LADO ABERTO nao se fecha, e isso e o conserto do corredor.
		#
		# `abertos` ja impedia a FITA de vestir a boca; a quina nao sabia disso e
		# fechava as quatro do retangulo. Na boca, uma das duas direcoes aponta ao
		# longo do corredor -- ou seja, para DENTRO da sala vizinha --, entao o
		# quad da quina invadia a sala com `profundidade x profundidade`.
		#
		# Com o perfil C, 16 a 24 px, aquilo cabia debaixo da parede da propria
		# sala e ninguem via. Com 96 e 104 virou um bloco entrando pela porta: o
		# dono viu como "os pilares do corredor vazam para a proxima sala, e
		# voltando vazam para a anterior" -- as DUAS bocas, que e exatamente o
		# numero de bocas que um corredor tem.
		if _e_aberto(n1, abertos) or _e_aberto(n2, abertos):
			continue
		# Quina reta: as duas normais sao perpendiculares. Num contorno
		# degenerado elas podem ser iguais, e ai nao ha vao para fechar.
		if absf(n1.dot(n2)) > 0.5:
			continue
		var d1 := perfil.profundidade(classificar(n1))
		var d2 := perfil.profundidade(classificar(n2))
		if d1 <= 0.0 or d2 <= 0.0:
			continue
		# MEIA ESQUADRIA, e nao um quad unico de topo.
		#
		# O vao da quina e o retangulo que os dois lados nao alcancam. Preenche-lo
		# inteiro com a textura de TOPO funcionava com a faixa fina do perfil C --
		# 16 a 24 px --, mas com 96 e 104 aquele retangulo virou um bloco de
		# 96x104 px de pedra entre duas faces estriadas: a sala voltou a parecer
		# construida com cubos, que e exatamente o defeito que tirar o pilar
		# desenhado existia para resolver.
		#
		# Na referencia (`inspiração/cantos.png`) a quina e uma JUNTA: a
		# superficie de cada lado vira 45 graus e encontra a do outro numa
		# diagonal. Nada e desenhado por cima; o que muda e para onde cada
		# superficie continua.
		#
		# Entao o retangulo e cortado pela diagonal que vai da quina INTERNA (`v`)
		# a EXTERNA (`v + n1*d1 + n2*d2`), e cada metade recebe as bandas do SEU
		# lado -- face colada no contorno, topo por fora. A textura e a mesma e a
		# ancora de UV e a mesma, entao a junta nao aparece como emenda: aparece
		# como a superficie virando.
		var externo := v + n1 * d1 + n2 * d2
		var f1 := perfil.fim_da_face(classificar(n1))
		var f2 := perfil.fim_da_face(classificar(n2))
		var textura_topo_q := _sorteia(topos, semente_da_sala)
		var textura_face_q := _sorteia(faces, semente_da_sala)
		_meia_quina(raiz, v, n1, d1, f1, n2, d2, externo,
			textura_face_q, textura_topo_q, ancora, silhueta)
		_meia_quina(raiz, v, n2, d2, f2, n1, d1, externo,
			textura_face_q, textura_topo_q, ancora, silhueta)


## Uma das duas metades da quina: as bandas de UM lado, cortadas na diagonal.
##
## `n` e a normal do lado que esta metade continua, `fundo` a profundidade dele e
## `fim_face` onde a face dele acaba. `n_outro`/`fundo_outro` descrevem o vizinho,
## e servem so para medir o retangulo do vao.
##
## O corte usa `Geometry2D.intersect_polygons` e nao um triangulo escrito a mao
## porque as bandas nao chegam todas ate a diagonal: a face acaba antes do topo,
## e cada uma cruza a diagonal num lugar diferente. Recortar cada banda pelo
## triangulo resolve as duas de uma vez, e continua valendo se um lado tiver face
## zero.
static func _meia_quina(raiz: Node2D, v: Vector2, n: Vector2, fundo: float,
		fim_face: float, n_outro: Vector2, fundo_outro: float, externo: Vector2,
		textura_face: Texture2D, textura_topo: Texture2D, ancora: Vector2,
		silhueta: bool) -> void:
	var triangulo := PackedVector2Array([v, v + n * fundo, externo])
	if fim_face > 0.0:
		_banda_da_quina(raiz, v, n, 0.0, fim_face, n_outro, fundo_outro,
			triangulo, textura_face, ancora, silhueta, COR_FACE)
	if fundo > fim_face:
		_banda_da_quina(raiz, v, n, fim_face, fundo, n_outro, fundo_outro,
			triangulo, textura_topo, ancora, silhueta, COR_TOPO)


## Uma banda (face ou topo) da quina, recortada pelo triangulo daquela metade.
static func _banda_da_quina(raiz: Node2D, v: Vector2, n: Vector2, de: float,
		ate: float, n_outro: Vector2, fundo_outro: float,
		triangulo: PackedVector2Array, textura: Texture2D, ancora: Vector2,
		silhueta: bool, cor: Color) -> void:
	var banda := PackedVector2Array([
		v + n * de,
		v + n * ate,
		v + n * ate + n_outro * fundo_outro,
		v + n * de + n_outro * fundo_outro,
	])
	for pedaco in Geometry2D.intersect_polygons(banda, triangulo):
		if pedaco.size() < 3:
			continue
		var caixa := Rect2(pedaco[0], Vector2.ZERO)
		for ponto in pedaco:
			caixa = caixa.expand(ponto)
		var centro := caixa.get_center()
		var quad := Polygon2D.new()
		quad.position = centro
		var relativos := PackedVector2Array()
		for ponto in pedaco:
			relativos.append(ponto - centro)
		quad.polygon = relativos
		if silhueta or textura == null:
			quad.color = cor
		else:
			quad.texture = textura
			quad.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			# A MESMA ancora das faixas: e isso que faz a quina ser a continuacao
			# do desenho em vez de um remendo com textura propria.
			quad.texture_offset = centro - ancora
		raiz.add_child(quad)


## Qual canto do kit cobre esta quina.## Qual canto do kit cobre esta quina. -1 quando a quina nao e um encontro de um
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


static func _caixa(pontos: PackedVector2Array) -> Rect2:
	if pontos.is_empty():
		return Rect2()
	var caixa := Rect2(pontos[0], Vector2.ZERO)
	for i in range(1, pontos.size()):
		caixa = caixa.expand(pontos[i])
	return caixa


## As quatro margens da camera. Ver `PerfilDeParede.margens()`.
static func margens(perfil: PerfilDeParede = null) -> Vector4:
	return (perfil if perfil != null else PerfilDeParede.new()).margens()
