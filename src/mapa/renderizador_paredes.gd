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
## A QUEDA externa do sul, no modo silhueta: mais escura que o cap, porque ela
## esta virada para longe da camera e e o ultimo degrau antes do vazio.
const COR_QUEDA := Color("1f2432")

## A LINHA DE CONTATO, e ela e translucida de proposito.
##
## Ela desenha SOBRE o chao (`Z_FITA` fica acima de `Z_CHAO`), entao o que ela
## precisa e escurecer, e nao pintar. Um valor absoluto so funcionaria se por
## acaso fosse mais escuro que aquele piso -- e o piso do andar 1 mede luma 14 a
## 16 contra os 13 do N1: a primeira versao existia em disco e nao aparecia.
##
## O alfa e o mesmo `ALFA_PERTO` da `SombraDeParede`, que ja e a sombra que
## assenta a parede. As duas fazem o mesmo trabalho em escalas diferentes -- esta
## e a linha, aquela e o gradiente -- e falarem o mesmo alfa e o que impede uma
## de anular a outra.
const COR_CONTATO := Color(0.02, 0.024, 0.043, 0.55)

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

## Quanto a FLANGE escurece a face que ela leva para cima.
##
## Menos que o bisel: ela ainda e a face, vista quase de topo. Escurecida demais
## viraria uma segunda costura preta e a juncao voltaria a ler como duas pecas
## empilhadas -- que e exatamente o que ela existe para desfazer.
const TINTA_DA_FLANGE := Color(0.72, 0.74, 0.82)

## Quanto a QUEDA escurece a chapa que ela termina.
##
## Mais que o bisel: ela e a face externa do sul, virada para longe da camera, e
## o que vem depois dela e o vazio. Um degrau raso ali faz a moldura terminar sem
## terminar.
const TINTA_DA_QUEDA := Color(0.42, 0.44, 0.52)

const COSTURA := 32.0
const SOMBRA_DA_COSTURA := 2.0
const LABIO := 1.0
const BISEL := 2.0

## A FLANGE: quantos px da FACE sobem para dentro do topo.
##
## Ate aqui a juncao dizia "esse bloco esta em cima daquela parede": o topo
## acabava, a face comecava, e os dois materiais apenas se encostavam. A flange
## faz a frase virar "essa chapa e a cobertura desta parede" -- a nervura
## vertical da face continua alguns pixels para dentro da faixa de cima e so
## entao para, que e como uma chapa aparafusada numa estrutura se parece de cima.
##
## Tres px, e o numero e o menor que le. Com dois ela some contra o bisel em
## metade dos trechos; com quatro ela come quase metade do bisel e a transicao
## que a #241 montou deixa de acontecer.
const FLANGE := 3.0

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
		peso_comum: float = 0.65,
		espacamento: int = 2, abertos: Array[Vector2] = [],
		perfil: PerfilDeParede = null, silhueta: bool = false,
		decalques: Array[Texture2D] = [], chance_decalque: float = 0.0) -> Node2D:
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
			semente, topos, faces, peso_comum, espacamento, regra, ancora, silhueta,
			decalques, chance_decalque, i)
	_fechar_quinas(raiz, contorno, regra, topos, faces, ancora, silhueta,
		abertos, semente, peso_comum)
	return raiz


## Um lado vira uma PILHA DE CAMADAS, e a pilha e diferente em cada direcao.
##
## Ate aqui os quatro lados desenhavam a mesma coisa -- 56 de face mais 40 de
## topo --, e o dono mediu o resultado e reprovou: o piso e as bandas continuavam
## parecendo o mesmo plano. O topo largo lia como faixa de piso, as laterais como
## bordas retas e as quinas como encontros de 90 graus sem profundidade.
##
## O que produz cavidade nao e espessura, e sim ASSIMETRIA: a camera e uma so, e
## cada lado esta numa relacao diferente com ela. O norte mostra a face de
## frente; a lateral mostra de esguelha; o sul e visto de CIMA e por isso ganha
## uma soleira que cresce para FORA em vez de uma face que cresce para dentro.
##
## Quem sabe disso e `PerfilDeParede.camadas()`. Este arquivo nao le campo nenhum
## do perfil -- so a lista. Foi assim que os quatro lados deixaram de poder voltar
## a ser a mesma coisa por acidente.
##
## A camada FACE e a unica que abre no vao da porta. As outras atravessam: sobre a
## porta ha verga, e a superficie de cima passa por cima da passagem de verdade.
static func _vestir_lado(raiz: Node2D, contorno: PackedVector2Array, a: Vector2,
		b: Vector2, portas: Array[Porta], semente: int, semente_da_sala: int,
		topos: Array[Texture2D],
		faces: Array[Texture2D], peso_comum: float, espacamento: int,
		perfil: PerfilDeParede, ancora: Vector2, silhueta: bool,
		decalques: Array[Texture2D] = [], chance_decalque: float = 0.0,
		indice: int = -1) -> void:
	var normal := normal_externa(contorno, a, b)

	# O TRECHO DE CHANFRO nao e um lado: ele e a TRANSICAO entre dois.
	#
	# Desenhado como lado, com profundidade propria e normal diagonal, ele
	# ultrapassa o limite dos vizinhos: medido, a lateral reservava 36 px e o
	# chanfro alcancava 44. E ele nao pode ter profundidade propria mesmo -- se o
	# norte desenha 60 e a lateral 36, a transicao TEM de ir de um a outro.
	#
	# Entao cada ponta dele e deslocada pela normal do SEU vizinho, e a banda vira
	# um trapezio que encosta exatamente onde as duas vizinhas terminaram. A
	# consequencia boa: nao sobra cunha nenhuma para fechar depois -- o chanfro E
	# a quina.
	if indice >= 0 and _e_chanfro(normal):
		_vestir_chanfro(raiz, contorno, indice, perfil, topos, faces, peso_comum,
			ancora, silhueta, semente_da_sala)
		return

	var comprimento := a.distance_to(b)
	if comprimento < LADO_MINIMO:
		return
	var lado := classificar(normal)

	# O TOPO e sorteado UMA VEZ POR SALA; a FACE, uma vez por lado.
	#
	# O topo e a superficie continua que da a volta na sala e atravessa as
	# quinas com a UV ancorada no contorno; duas variantes na mesma volta quebram
	# a continuidade no unico lugar onde ela segura a leitura. A FACE e o oposto
	# -- ela carrega identidade, e a variedade entre lados e o que produz a
	# biblioteca.
	var textura_topo := _sorteia(topos, semente_da_sala)
	var textura_face := _face_da_celula(faces, semente,
		_quer_especial(semente, peso_comum))

	var fim_face := perfil.fim_da_face(lado)
	var fundo := perfil.profundidade(lado)
	var camadas := perfil.camadas(lado)

	# A PORTA E UM RECORTE REAL, e ela atravessa a PILHA INTEIRA.
	#
	# Antes so a face abria, e o resto passava por cima do vao com o argumento de
	# que sobre a porta ha verga. O argumento vale para uma parede de 96 px vista
	# quase de frente; com o perfil direcional ele deixa de valer no SUL, onde a
	# pilha e uma soleira de 32 px vista de CIMA -- a verga ali cobriria a
	# passagem inteira, e o jogador atravessaria por baixo do desenho.
	#
	# E o recorte inteiro e o que a porta precisa para participar do volume: e o
	# batente que mostra a espessura, e sem cortar o cap nao ha batente.
	for trecho in trechos_livres(contorno, a, b, portas):
		var de: Vector2 = trecho[0]
		var ate: Vector2 = trecho[1]
		if de.distance_to(ate) < 1.0:
			continue
		for camada in camadas:
			if int(camada.z) == PerfilDeParede.Camada.FACE:
				_superficie(raiz, de, ate, normal, camada.x, camada.y, textura_face,
					ancora, silhueta, COR_FACE)
				# A FLANGE: a nervura da face sobe alguns px para dentro do cap, e
				# a juncao passa a dizer "essa chapa e a cobertura desta parede"
				# em vez de "esse bloco esta em cima daquela parede".
				if camada.y + FLANGE <= fundo:
					_superficie(raiz, de, ate, normal, camada.y, camada.y + FLANGE,
						textura_face, ancora, silhueta, COR_FACE, TINTA_DA_FLANGE)
			else:
				_camada_continua(raiz, de, ate, normal, camada, textura_topo,
					ancora, silhueta)
		# O DECALQUE nao depende mais de haver face: quem decide e o ENCAIXE.
		#
		# Com o perfil direcional o unico lado largo o bastante para uma peca de
		# 16 px e o SUL, cujo ledge tem 20 -- e ele e justamente o que nao tem
		# face. Amarrar o decalque a `fim_face > 0` o excluia do unico lugar onde
		# ele cabe, e nao havia erro nenhum: a decoracao simplesmente sumia.
		if not silhueta:
			_decalque_no_trecho(raiz, de, ate, normal, lado, perfil, fim_face,
				fundo, decalques, chance_decalque,
				semente ^ int(de.x) ^ int(de.y))


## Um trecho cuja normal aponta na diagonal e um chanfro de quina.
##
## O contorno so tem diagonais porque `Sala._chanfrar()` as criou: as nove salas
## sao retangulos e um L, todos ortogonais em disco.
static func _e_chanfro(normal: Vector2) -> bool:
	return absf(absf(normal.x) - absf(normal.y)) < 0.2


## O trapezio que liga as bandas de dois lados vizinhos.
##
## Cada ponta usa a normal e as camadas do SEU vizinho, entao a borda externa
## passa de 60 px (norte) para 36 (lateral) ao longo do chanfro, sem degrau e sem
## ultrapassar nenhum dos dois.
##
## As camadas sao pareadas por INDICE. Nas quinas norte-lateral isso alinha
## sombra com sombra, face com face e cap com reveal, que e o certo. Nas
## sul-lateral ele pareia o labio (que cresce para fora) com a sombra (que cresce
## para dentro), e a tira resultante atravessa o contorno -- sao 4 px, e o que se
## ve ali e uma linha escura virando a quina, que e o que se quer de qualquer
## jeito.
static func _vestir_chanfro(raiz: Node2D, contorno: PackedVector2Array, indice: int,
		perfil: PerfilDeParede, topos: Array[Texture2D], faces: Array[Texture2D],
		peso_comum: float, ancora: Vector2, silhueta: bool,
		semente_da_sala: int) -> void:
	var total := contorno.size()
	var a := contorno[indice]
	var b := contorno[(indice + 1) % total]
	var antes := (indice - 1 + total) % total
	var depois := (indice + 1) % total
	var n_a := normal_externa(contorno, contorno[antes], a)
	var n_b := normal_externa(contorno, b, contorno[(depois + 1) % total])
	if _e_chanfro(n_a) or _e_chanfro(n_b):
		return

	var camadas_a := perfil.camadas(classificar(n_a))
	var camadas_b := perfil.camadas(classificar(n_b))
	var textura_topo := _sorteia(topos, semente_da_sala)
	var chave := semente_da_sala ^ (antes * 0x9e3779b1)
	var textura_face := _face_da_celula(faces, chave, _quer_especial(chave, peso_comum))

	for k in mini(camadas_a.size(), camadas_b.size()):
		var ca: Vector3 = camadas_a[k]
		var cb: Vector3 = camadas_b[k]
		var poligono := PackedVector2Array([
			a + n_a * ca.x,
			b + n_b * cb.x,
			b + n_b * cb.y,
			a + n_a * ca.y,
		])
		match int(ca.z):
			PerfilDeParede.Camada.SOMBRA, PerfilDeParede.Camada.LABIO:
				_poligono_chapado(raiz, poligono, N1)
			PerfilDeParede.Camada.FACE:
				_poligono_texturizado(raiz, poligono, textura_face, ancora, silhueta,
					COR_FACE, Color.WHITE)
			PerfilDeParede.Camada.QUEDA:
				_poligono_texturizado(raiz, poligono, textura_topo, ancora, silhueta,
					COR_QUEDA, TINTA_DA_QUEDA)
			_:
				_poligono_texturizado(raiz, poligono, textura_topo, ancora, silhueta,
					COR_TOPO, Color.WHITE)


## Uma camada que ATRAVESSA o lado inteiro, sem abrir na porta.
##
## Cap, reveal, ledge, queda, labio e sombra passam por cima do vao: sobre a
## porta ha verga. So a FACE abre, e ela e desenhada por trecho.
static func _camada_continua(raiz: Node2D, a: Vector2, b: Vector2, normal: Vector2,
		camada: Vector3, textura_topo: Texture2D, ancora: Vector2,
		silhueta: bool) -> void:
	var tipo := int(camada.z)
	var inicio: float = camada.x
	var fim: float = camada.y
	if fim - inicio < 0.5:
		return
	match tipo:
		PerfilDeParede.Camada.SOMBRA, PerfilDeParede.Camada.LABIO:
			# A LINHA DE CONTATO, e ela cresce para DENTRO do piso.
			#
			# E a peca que faz o piso parecer estar ABAIXO da face em vez de ao
			# lado dela. No sul o papel e o mesmo com os lados trocados: ali a
			# face esta acima do piso, aqui a soleira esta abaixo.
			#
			# **Ela e TRANSLUCIDA, e a primeira versao opaca era invisivel.**
			# Medido na captura: com N1 opaco (luma 13) sobre um chao que ja mede
			# 14 a 16, a linha existia em disco e nao aparecia em tela. Contato e
			# sombra, e sombra escurece o que esta embaixo -- um valor absoluto so
			# funciona se por acaso ele for mais escuro que aquele piso.
			_banda(raiz, a, b, normal, inicio, fim, COR_CONTATO)
		PerfilDeParede.Camada.QUEDA:
			# A queda externa termina a moldura antes do vazio. Ela e a MESMA
			# chapa escurecida, e nao uma faixa chapada: material que some, e nao
			# uma linha desenhada por cima.
			_superficie(raiz, a, b, normal, inicio, fim, textura_topo, ancora,
				silhueta, COR_QUEDA, TINTA_DA_QUEDA)
		_:
			# CAP, REVEAL e LEDGE sao a mesma cobertura estrutural. O que muda e
			# quanto dela se ve, e isso e o lado que decide.
			_superficie(raiz, a, b, normal, inicio, fim, textura_topo, ancora,
				silhueta, COR_TOPO)


## UM decalque de desgaste na chapa deste trecho, ou nenhum.
##
## **A frequencia e baixa e e um numero, nao uma opiniao.** Ela e irmao de
## `max_props_animados`, cujo default e 2 pelo mesmo motivo: se todo trecho tiver
## uma solda, nenhuma solda significa nada. O abandono aparece por evidencia
## LOCALIZADA, e nao por ruido uniforme.
##
## **Ele nao gira, e nao e por comodidade.** `teste_renderizador_paredes` proibe
## rotacao na fita inteira porque as bandas de acabamento codificam a direcao da
## luz, e uma peca girada mente sobre ela. Um decalque que precisasse girar para
## caber num lado seria a mesma mentira -- entao a regra aqui e de ENCAIXE e nao
## de excecao: a peca so entra no lado em que ela cabe na chapa sem virar.
## Na pratica, o quadrado de 16 cabe nos quatro; a tira de 48x16 cabe so nos
## lados horizontais, e e onde uma solda ao longo da parede faz sentido de
## qualquer jeito.
##
## Ele desenha na CHAPA -- entre o bisel e a borda --, e nao na faixa inteira.
## Fora dela ele cruzaria a dobra que a #241 montou, e o desgaste passaria a
## contradizer a estrutura em vez de assentar nela.
static func _decalque_no_trecho(raiz: Node2D, de: Vector2, ate: Vector2,
		normal: Vector2, lado: Lado, perfil: PerfilDeParede, fim_face: float,
		fim_topo: float, decalques: Array[Texture2D], chance: float,
		chave: int) -> void:
	if decalques.is_empty() or chance <= 0.0:
		return
	if float(absi(chave * 0x27d4eb2d) % 10000) / 10000.0 >= chance:
		return
	var inicio := fim_face + perfil.bisel_do_topo
	var faixa := fim_topo - perfil.borda_do_topo - inicio
	if faixa < 8.0:
		return

	# A peca so entra se couber na chapa SEM girar. `atravessa` e a dimensao dela
	# no eixo da profundidade, e ela muda com a orientacao do lado.
	var horizontal := lado == Lado.NORTE or lado == Lado.SUL
	var candidatas: Array[Texture2D] = []
	for d in decalques:
		if d == null:
			continue
		var atravessa := d.get_height() if horizontal else d.get_width()
		var ao_longo := d.get_width() if horizontal else d.get_height()
		if float(atravessa) <= faixa and float(ao_longo) <= de.distance_to(ate):
			candidatas.append(d)
	if candidatas.is_empty():
		return
	var escolhida := candidatas[absi(chave ^ 0x5bd1e995) % candidatas.size()]

	var comprimento := de.distance_to(ate)
	var meia := (escolhida.get_width() if horizontal else escolhida.get_height()) * 0.5
	var vao := comprimento - meia * 2.0
	var onde := meia
	if vao > 1.0:
		onde += float(absi(chave ^ 0x1b873593) % int(vao))
	var direcao := (ate - de) / comprimento

	var sprite := Sprite2D.new()
	sprite.texture = escolhida
	sprite.position = de + direcao * onde + normal * (inicio + faixa * 0.5)
	raiz.add_child(sprite)


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


## A QUINA e onde a superficie VIRA, e e ela que faz a sala ler como cavidade.
##
## Reduzir o topo sozinho nao resolveria: um encontro reto de duas bandas
## comunica planta baixa, e nao volume. Com o contorno chanfrado, cada quina de
## 90 graus vira dois vertices de 135, e o que sobra entre duas bandas vizinhas e
## uma cunha de 45 -- pequena, mas suficiente para abrir um buraco contra o vazio
## se ninguem a fechar.
##
## Ela e MEIA ESQUADRIA e nao um quad de cobertura: o vao e cortado na bissetriz,
## e cada metade recebe as CAMADAS DO SEU LADO, com a mesma textura e a mesma
## ancora de UV. A superficie vira, em vez de uma peca entrar por cima -- e e
## isso que faz face, cap e sombra convergirem para o piso em vez de se
## encontrarem em esquadro.
##
## As quinas CONCAVAS caem no mesmo tratamento, de proposito: medindo a
## geometria, as duas familias pedem a mesma coisa, e o que muda e so de que lado
## a superficie vira.
##
## **Quina de lado ABERTO nao se fecha.** Na boca de um corredor uma das direcoes
## aponta ao longo dele -- para DENTRO da sala vizinha --, e o quad invadiria a
## sala pela porta.
static func _fechar_quinas(raiz: Node2D, contorno: PackedVector2Array,
		perfil: PerfilDeParede, topos: Array[Texture2D],
		faces: Array[Texture2D], ancora: Vector2,
		silhueta: bool, abertos: Array[Vector2] = [],
		semente_da_sala: int = 0, peso_comum: float = 0.65) -> void:
	var total := contorno.size()
	if total < 3:
		return
	var textura_topo := _sorteia(topos, semente_da_sala)
	for i in total:
		var anterior := (i - 1 + total) % total
		var v := contorno[i]
		var n1 := normal_externa(contorno, contorno[anterior], v)
		var n2 := normal_externa(contorno, v, contorno[(i + 1) % total])
		if n1.dot(n2) > 0.999:
			continue
		if _e_aberto(n1, abertos) or _e_aberto(n2, abertos):
			continue
		# O CHANFRO ja fecha a quina: o trapezio dele encosta nas duas vizinhas.
		# Uma cunha por cima aqui desenharia duas vezes no mesmo lugar, e a de
		# cima tem profundidade propria -- ela e que ultrapassava o limite.
		if _e_chanfro(n1) or _e_chanfro(n2):
			continue
		var soma := n1 + n2
		if soma.length_squared() < 0.001:
			continue

		var c1 := perfil.camadas(classificar(n1))
		var c2 := perfil.camadas(classificar(n2))
		var face1 := _face_da_celula(faces, semente_da_sala ^ (anterior * 0x9e3779b1),
			_quer_especial(semente_da_sala ^ (anterior * 0x9e3779b1), peso_comum))
		var face2 := _face_da_celula(faces, semente_da_sala ^ (i * 0x9e3779b1),
			_quer_especial(semente_da_sala ^ (i * 0x9e3779b1), peso_comum))
		for k in mini(c1.size(), c2.size()):
			_meia_quina(raiz, v, n1, n2, c1[k], c2[k], textura_topo, face1,
				ancora, silhueta)
			_meia_quina(raiz, v, n2, n1, c2[k], c1[k], textura_topo, face2,
				ancora, silhueta)


## O ponto da BISSETRIZ a `d` px do vertice.
##
## **Ele NAO estende ate o canto do quadrado, e a escolha e deliberada.** A
## esquadria geometrica poria o ponto a `d/cos(meio angulo)` -- 1,08x num vertice
## de 135 graus, 1,41x num de 90 --, e isso ultrapassaria a profundidade que a
## camera reserva para aquele lado. O clamp cresce por `profundidade(lado)`; um
## pixel alem e o quadro passa a mostrar vazio na borda, sem erro no console.
##
## O preco e um pequeno recuo na quina: 8% da profundidade num vertice de 135
## graus, que e o que o contorno chanfrado produz. Contra o vazio N0 ele nao
## aparece, e a margem exterior ja mostra vazio ali de qualquer jeito.
static func _mitra(n1: Vector2, n2: Vector2, d: float) -> Vector2:
	return (n1 + n2).normalized() * d


## Metade de uma quina: do lado `n` ate a bissetriz, para UMA camada.
##
## `camada_outro` entra so para a profundidade do encontro ser a media dos dois
## lados -- e o que faz a borda externa passar de um lado para o outro sem
## degrau, mesmo com norte em 60 e lateral em 36.
static func _meia_quina(raiz: Node2D, v: Vector2, n: Vector2, n_outro: Vector2,
		camada: Vector3, camada_outro: Vector3, textura_topo: Texture2D,
		textura_face: Texture2D, ancora: Vector2, silhueta: bool) -> void:
	var inicio: float = camada.x
	var fim: float = camada.y
	if fim - inicio < 0.5:
		return
	var inicio_m := (inicio + camada_outro.x) * 0.5
	var fim_m := (fim + camada_outro.y) * 0.5
	var poligono := PackedVector2Array([
		v + n * inicio,
		v + n * fim,
		v + _mitra(n, n_outro, fim_m),
		v + _mitra(n, n_outro, inicio_m),
	])
	var tipo := int(camada.z)
	match tipo:
		PerfilDeParede.Camada.SOMBRA, PerfilDeParede.Camada.LABIO:
			_poligono_chapado(raiz, poligono, N1)
		PerfilDeParede.Camada.FACE:
			_poligono_texturizado(raiz, poligono, textura_face, ancora, silhueta,
				COR_FACE, Color.WHITE)
		PerfilDeParede.Camada.QUEDA:
			_poligono_texturizado(raiz, poligono, textura_topo, ancora, silhueta,
				COR_QUEDA, TINTA_DA_QUEDA)
		_:
			_poligono_texturizado(raiz, poligono, textura_topo, ancora, silhueta,
				COR_TOPO, Color.WHITE)


static func _poligono_chapado(raiz: Node2D, pontos: PackedVector2Array,
		cor: Color) -> void:
	var centro := _centro(pontos)
	var poly := Polygon2D.new()
	poly.color = cor
	poly.position = centro
	poly.polygon = _relativo(pontos, centro)
	raiz.add_child(poly)


## A MESMA ancora de UV das faixas: e isso que faz a quina ser a continuacao do
## desenho em vez de um remendo com textura propria.
static func _poligono_texturizado(raiz: Node2D, pontos: PackedVector2Array,
		textura: Texture2D, ancora: Vector2, silhueta: bool, cor: Color,
		tinta: Color) -> void:
	var centro := _centro(pontos)
	var poly := Polygon2D.new()
	poly.position = centro
	poly.polygon = _relativo(pontos, centro)
	if silhueta or textura == null:
		poly.color = cor
	else:
		poly.color = tinta
		poly.texture = textura
		poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		poly.texture_offset = centro - ancora
	raiz.add_child(poly)


static func _centro(pontos: PackedVector2Array) -> Vector2:
	var soma := Vector2.ZERO
	for p in pontos:
		soma += p
	return soma / float(maxi(pontos.size(), 1))


static func _relativo(pontos: PackedVector2Array, centro: Vector2) -> PackedVector2Array:
	var saida := PackedVector2Array()
	for p in pontos:
		saida.append(p - centro)
	return saida


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
