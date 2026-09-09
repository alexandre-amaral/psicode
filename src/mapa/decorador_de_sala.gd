class_name DecoradorDeSala
extends RefCounted
## ONDE cada peca de decoracao de uma sala vai parar -- em geometria pura.
##
## Ele recebe o contorno da sala, um `PerfilDeDecoracao` e uma semente, e
## devolve uma lista de colocacoes. **Ele nao conhece a arvore de cenas**: nao
## ha `Node`, `add_child` nem `get_tree` aqui, e nao pode haver. Quem instancia
## sprite, escolhe regiao de atlas e resolve z_index e a `Sala`; quem responde
## "isto pode ficar aqui?" e este arquivo.
##
## Essa separacao e o ponto inteiro da issue. As regras que a decoracao precisa
## cumprir -- faixa de perimetro, zona livre de combate, pesos por lado, sem
## sobreposicao, determinismo -- sao afirmacoes sobre NUMEROS, e um teste
## consegue varrer cinquenta salas por segundo sem montar cena nenhuma. Dentro
## de `sala.gd` elas seriam cobraveis so instanciando o andar, que e como
## regras assim envelhecem sem ninguem perceber. Mesmo desenho de
## `src/util/balistica.gd` e de `src/enemies/perfil_jogador.gd`.
##
## ## O que ele NAO sabe, e de proposito
##
## Ele nao sabe onde estao as PORTAS. A sala sabe (`_bocas_locais()`), e e ela
## que descarta uma colocacao encostada numa boca. Passar as portas para ca
## exigiria que a suite montasse portas para testar geometria, e o que se ganha
## -- uma checagem de distancia -- ja existe do outro lado.
##
## ## As oito regras, e a que manda
##
## 1. FAIXA: toda colocacao entre o contorno e `largura_da_faixa_de_perimetro`.
## 2. ZONA LIVRE: nada dentro de `raio_da_zona_livre` do centro. **E a regra que
##    protege o gameplay.** Densidade alta sem ela e obstaculo mentiroso no meio
##    do combate -- prop sem colisao que o jogador le como cobertura.
## 3. DENTRO: toda colocacao dentro do poligono. O contorno chega aberto ou
##    fechado (o `Line2D` "Parede" repete o primeiro ponto no fim) e os dois
##    casos tem de dar o mesmo resultado.
## 4. PESOS POR LADO: a distribuicao converge para os pesos do perfil.
## 5. SEM SOBREPOSICAO ENTRE CLUSTERS -- e COM sobreposicao leve DENTRO de um.
## 6. SEMENTE: a mesma sala com a mesma semente da a mesma decoracao, sempre.
## 7. MEMORIA RECENTE: cluster visto ha pouco entra com peso reduzido.
## 8. VAZIO: um lado fica relativamente calmo.
##
## ## A distincao de design da regra 5
##
## Duas colocacoes de CLUSTERS diferentes guardam distancia derivada do porte.
## Duas pecas do MESMO cluster nao: o barril na frente do tanque, o tubo
## encostando na valvula, e o que faz o conjunto parecer montado por alguem em
## vez de sorteado. Cobrar distancia dentro do cluster produziria conjuntos
## explodidos -- cinco pecas espalhadas que o olho nao reune -- e o cluster
## existe justamente porque prop solto vira ruido uniforme.
##
## ## E a da regra 8
##
## O lado calmo e sorteado com peso INVERSO ao do perfil: o lado que menos
## recebe tende a ser o escolhido, mas nao e sempre o mesmo -- um andar em que o
## sul e sempre vazio ensina o jogador a nao olhar para o sul.
##
## O peso inverso tem ainda uma propriedade que nao e coincidencia: com quatro
## lados e `P(vazio = v) = (1 - w_v) / 3`, a chance de uma peca cair no lado `i`
## e `soma sobre v != i de (1-w_v)/3 * w_i/(1-w_v)`, que da `w_i` EXATO. Ou
## seja: o lado calmo nao distorce a distribuicao declarada, ele so a
## redistribui sala a sala. Um sorteio uniforme do lado vazio nao teria isso, e
## a regra 4 passaria a medir uma mistura em vez dos pesos do perfil.

## Os cinco portes, do que da nome a sala ao que se pisa em cima.
##
## A ORDEM e contrato: `AgrupamentoDeDecoracao.portes` guarda estes ordinais
## como `int` (o enum nao pode morar la sem fechar um ciclo de `class_name`), e
## `DISTANCIA_MINIMA` e indexada por eles. Valor novo entra NO FIM -- inserir no
## meio reescreve em silencio o significado de todo agrupamento ja salvo, a
## mesma armadilha que `DadosArma.Comportamento` ja registra.
enum Porte {
	## Volume, do que da nome a sala ao que se pisa ao lado.
	HERO,
	GRANDE,
	MEDIO,
	PEQUENO,
	MICRO,
	## **CHAO PINTADO, e nao objeto.** Mancha de oleo, marcacao de galao, grade
	## de piso. Ele entrou depois de MEDIR a referencia (`docs/fabrica_01.png`):
	## a sala dela tem um losango de listras no MEIO da area livre e mais de dez
	## grades espalhadas, varias no centro. A primeira versao deste decorador
	## rejeitava tudo dentro da zona livre e deixava o centro chapado -- que e
	## exatamente o que a referencia nao faz.
	##
	## Ele e plano: nao tem silhueta, nao tem brilho e nao compete com projetil.
	## E por isso que ele PODE morar onde o volume nao pode.
	DECALQUE,
	## **PRESO NA FACE, e nao no chao.** Tubo que corre pela parede, caixa de
	## juncao, duto. Na referencia quase nenhum trecho de parede aparece limpo, e
	## sem este porte todo tubo vira prop de piso -- a composicao nunca alcanca a
	## imagem porque a parede continua sendo um plano em vez de uma estante.
	PAREDE,
}

## Os quatro lados, na convencao de tela do projeto: Y cresce para BAIXO, entao
## o NORTE e o lado de cima e a normal que entra na sala a partir dele aponta
## para +Y.
enum Lado { NORTE, LESTE, SUL, OESTE }

## Quanto duas colocacoes de clusters DIFERENTES precisam guardar, indexado por
## `Porte`. Cresce com o porte porque a lista de colocados nao sabe o tamanho de
## quem ja esta nela -- e o mesmo motivo do `maxf(PROP_ESPACO, largura)` que
## `Sala._cabe_prop` ja usa.
## O DECALQUE guarda ZERO de propósito: manchas se sobrepoem no chao de uma
## fabrica, e exigir espaco entre elas produziria uma grade regular de sujeira,
## que le como padrao e nao como uso.
const DISTANCIA_MINIMA := [128.0, 96.0, 64.0, 40.0, 24.0, 0.0, 32.0]

## Quao fundo uma peca de PAREDE entra na sala.
##
## Quase nada: o que ela ocupa e a PAREDE, e nao o chao. Deixa-la usar a faixa
## de perimetro inteira a transformaria num prop de piso encostado, que e
## precisamente a confusao que este porte existe para desfazer.
const PROFUNDIDADE_DE_PAREDE := 20.0

## Quanto de CHAO uma peca de volume ocupa, medido da frente para o fundo.
##
## **Ela substitui a pegada QUADRADA, e essa era a regra que impedia o andar de
## ter objeto grande.** A checagem era `Rect2(ponto - largura/2, largura x
## largura)`: um armario de 96 px reservava 96x96 de piso, e como ele ainda
## precisa de meio prop de folga contra a parede, nao existia posicao nenhuma
## dentro da faixa de 96 -- o hero de 96 nunca era colocado, e a saida foi
## encolher a peca. O resultado esta no retorno do dono: "um armario menor do que
## o proprio jogador... nao passa nenhuma sensacao de pertencimento ao lugar ou
## de proporcionalidade".
##
## O quadrado nunca descreveu a peca. Um armario e largo e RASO; um tanque e
## redondo mas apoia numa base estreita. O que nao pode entrar na area de
## combate e o CHAO que a peca ocupa -- porque e nele que o jogador tentaria
## andar --, e nao a altura desenhada. Altura cresce para CIMA da tela, atras de
## todo mundo, e nao tira um pixel de area jogavel.
##
## 24 px e tres quartos de uma celula de 32. Ele e generoso de proposito: a peca
## desenhada avanca mais que isso em perspectiva, e o que se protege aqui e a
## caminhada, nao o desenho.
const PROFUNDIDADE_NO_CHAO := 24.0

## Tentativas por peca (ou por cluster) antes de desistir dela.
##
## Desistir e o comportamento certo: uma sala com um prop a menos e uma sala; um
## prop empurrado para dentro da parede para "caber" e um defeito que nao tem
## linha no console, porque decoracao nao tem colisao para reclamar.
const TENTATIVAS := 24

## Quanto uma ancora se afasta, no minimo, da linha do contorno. Peca com a
## origem exatamente sobre a linha desenha metade dentro da parede.
const BORDA_MINIMA := 8.0

## Aresta curta demais nao vira ancora: ela e chanfro de quina, e conjunto
## ancorado numa quina fica com metade das pecas em dois lados diferentes. Se
## NENHUMA aresta do lado alcancar esta medida, o filtro e dispensado -- sala
## pequena nao pode ficar sem decoracao por causa de um piso.
const COMPRIMENTO_MINIMO_DE_ARESTA := 64.0

## Folga guardada nas duas pontas de uma aresta ao sortear a ancora, para o
## cluster nao nascer em cima da quina.
const MARGEM_DE_QUINA := 48.0

## Que fracao da faixa a ANCORA de um cluster pode usar.
##
## **O conjunto comeca NA parede e cresce para dentro.** Ancorar no meio da
## faixa -- que era o comportamento -- produz o cluster flutuando no vao entre a
## parede e a area util: as pecas ficam proximas UMAS DAS OUTRAS e longe de
## tudo, e o olho le movel jogado no canto em vez de equipamento instalado.
##
## Na referencia medida (`docs/fabrica_01.png`) nao ha um unico objeto solto no
## meio do vao: tanque, armario e engradado encostam na parede, e o que avanca
## para dentro sao os tubos que saem deles. Um terco deixa a ancora colada e
## ainda da aos deslocamentos do cluster espaco para empurrar peca para dentro
## sem estourar a faixa.
const FRACAO_DA_ANCORA := 0.33

## Quanto pesa um agrupamento que apareceu nas ultimas salas.
##
## REDUZIDO, e nao proibido. Proibir deixaria o andar sem opcao no dia em que a
## lista de recentes ficasse maior que a pool de agrupamentos do tipo de sala --
## e o sintoma seria uma sala inteira sem cluster nenhum, sem erro. Reduzir
## resolve o que a memoria existe para resolver (duas salas seguidas nao contam
## a mesma historia) sem criar um estado impossivel.
const PESO_RECENTE := 0.25

## Quantas pecas o lado calmo aceita, e so dos dois portes menores.
##
## "Relativamente vazio" e nao "vazio": uma parede completamente limpa no meio
## de uma fabrica cheia le como cenario nao terminado. O que a regra impede e o
## lado receber MASSA -- hero, grande ou medio.
const PECAS_NO_LADO_VAZIO := 2

## Desvio da semente para o sorteio do lado calmo.
##
## Fluxo de RNG SEPARADO de proposito: assim `lado_vazio()` pode ser perguntado
## de fora, antes ou depois de `decorar()`, sem consumir o sorteio principal. Um
## portao que precisasse reproduzir a sequencia inteira para saber qual lado
## ficou calmo estaria reimplementando o decorador para testa-lo.
const CHAVE_DO_LADO_VAZIO := 0x5f3a97

## Quanto se anda para dentro ao decidir de que lado de uma aresta fica a sala.
const EPSILON_INTERNO := 1.0


## A decoracao inteira de uma sala.
##
## `recentes` traz nomes de agrupamento das ultimas salas do andar (ver
## `PESO_RECENTE`). Cada Dictionary devolvido tem:
##   posicao     Vector2, em coordenadas LOCAIS da sala -- as mesmas do contorno
##   porte       int, um `Porte`
##   agrupamento StringName; VAZIO significa peca avulsa, fora de cluster
##   lado        int, um `Lado`
static func decorar(
	contorno: PackedVector2Array, perfil: PerfilDeDecoracao, semente: int,
	recentes: Array = [], restricoes: Dictionary = {}
) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	if perfil == null:
		return saida
	var aberto := normalizar_contorno(contorno)
	if aberto.size() < 3:
		return saida
	var arestas := _arestas(aberto)
	if arestas.is_empty():
		return saida

	var rng := RandomNumberGenerator.new()
	rng.seed = semente

	var ids: Array[int] = []
	var ctx := {
		"perfil": perfil,
		"rng": rng,
		"aberto": aberto,
		"arestas": arestas,
		"por_lado": _arestas_por_lado(arestas),
		"centro": centro_de(aberto),
		# As duas restricoes que so a SALA REAL tem, e que `posicoes()` ja
		# recebia. Elas chegam aqui porque a sala passou a consumir `decorar()`
		# -- ate entao esta funcao so era chamada pelo laboratorio e pela suite,
		# e o jogo montava a decoracao peca a peca, sem cluster nenhum.
		#
		# `zona_livre` e MELHOR que `raio_da_zona_livre`: ela e a area jogavel
		# AUTORADA na cena, e num contorno em L o raio mede a partir do centro
		# da caixa envolvente, que pode cair fora da sala. Quando ela chega
		# vazia -- o laboratorio, a suite -- o raio continua valendo, e por isso
		# os numeros historicos daqueles portoes nao mudam.
		"zona_livre": restricoes.get("zona_livre", Rect2()),
		"bocas": restricoes.get("bocas", []),
		"raio_de_boca": restricoes.get("raio_de_boca", 0.0),
		# A caixa envolvente, para o decalque sortear dentro dela. Calculada uma
		# vez: refaze-la a cada tentativa varreria o contorno inteiro por ponto.
		"caixa": _caixa_de(aberto),
		"vazio": lado_vazio(perfil, semente),
		"saida": saida,
		"ids": ids,
		"proximo_id": 0,
		"no_lado_vazio": 0,
	}

	# O HERO primeiro: ele e a peca de leitura da sala e tem pesos proprios. Se
	# ele entrasse por ultimo, a sala ja estaria ocupada e ele cairia no lugar
	# que sobrou -- que e o oposto de ser a peca principal.
	for _i in _sorteio_na_faixa(rng, perfil.contagem_hero):
		_tentar_avulso(ctx, Porte.HERO, true)

	# Depois os CLUSTERS, que sao a unidade de decoracao. Eles vem antes das
	# pecas avulsas pelo mesmo motivo: conjunto precisa de espaco continuo, e
	# quem chega depois se acomoda no que sobrou.
	var quantos := _sorteio_na_faixa(rng, perfil.quantos_agrupamentos)
	for agrupamento in _escolher_agrupamentos(perfil, rng, recentes, quantos):
		_tentar_agrupamento(ctx, agrupamento)

	# E por fim o completamento avulso, do maior para o menor. A faixa do perfil
	# e o ALVO da sala inteira, e o cluster ja pagou parte dela: um conjunto
	# hidraulico com dois barris ja entregou dois MEDIO. O cluster e atomico,
	# entao ele pode passar do alvo -- cortar um conjunto pela metade para caber
	# num numero produziria o tanque sem o tubo.
	# A ordem importa: o VOLUME primeiro, do maior para o menor, e so entao o
	# que mora na parede e o que e pintado no chao. Decalque colocado antes
	# ocuparia o sorteio sem disputar espaco nenhum -- ele nao guarda distancia
	# de ninguem --, mas gastaria as tentativas do resto.
	for porte in [
		Porte.GRANDE, Porte.MEDIO, Porte.PEQUENO, Porte.MICRO,
		Porte.PAREDE, Porte.DECALQUE,
	]:
		var alvo := _sorteio_na_faixa(rng, faixa_de_porte(perfil, porte))
		for _i in maxi(alvo - _contagem_de(ctx, porte), 0):
			_tentar_avulso(ctx, porte, false)

	return saida


## UM LOTE de posicoes de um porte so, para quem ja tem a propria contagem.
##
## **Ela existe para acabar com o segundo sistema de colocacao.** Ate a
## integracao, `Sala` tinha o dela -- `_sortear_ponto_de_prop` mais `_cabe_prop`,
## com `PROP_AFASTAMENTO_MINIMO/MAXIMO`, `PROP_ESPACO` e
## `PROP_DISTANCIA_DE_PORTA` -- e este arquivo tinha o novo. Duas respostas para
## "onde um prop pode ficar" e a armadilha que este repositorio ja pagou tres
## vezes: quem for girar um dos botoes gira o que nao esta sendo lido.
##
## Ela e SEPARADA de `decorar()` de proposito. `decorar()` responde "monte a
## decoracao desta sala" e as contagens saem do `PerfilDeDecoracao`; esta
## responde "me de N posicoes legais", e a contagem continua vindo de quem
## chamou. Enquanto `DadosSala` for o dono das quantidades (`quantidade_props`,
## `quantidade_props_volume`, `quantidade_decalques`, `quantidade_props_frente`),
## e esta que a `Sala` usa -- e a migracao daquelas quantidades para o perfil
## fica declarada em vez de forcada junto.
##
## As restricoes que a sala real tem e a sala de teste nao tinha:
##
## - `zona_livre` (`Rect2`): a `area_spawn` da cena. Ela e MELHOR que o raio,
##   porque e a area jogavel AUTORADA -- num contorno em L o raio mede a partir
##   do centro da caixa envolvente, que pode cair fora da sala.
## - `bocas` + `raio_de_boca`: prop encostado numa porta parece que a tapa.
## - `ocupados`: o que ja foi colocado por OUTRAS categorias. Sem isso, o
##   volumetrico nasceria em cima do chapado, que e uma lista diferente.
##
## Chaves aceitas em `restricoes`, todas opcionais:
##   "faixa" float, "zona_livre" Rect2, "raio_livre" float, "centro" Vector2,
##   "bocas" Array[Vector2], "raio_de_boca" float, "ocupados" Array[Vector2],
##   "espaco_minimo" float, "grade" float, "no_chao_todo" bool
static func posicoes(
	contorno: PackedVector2Array, quantas: int, largura: float, semente: int,
	restricoes: Dictionary = {}
) -> Array[Vector2]:
	var saida: Array[Vector2] = []
	if quantas <= 0 or largura <= 0.0:
		return saida
	var aberto := normalizar_contorno(contorno)
	if aberto.size() < 3:
		return saida
	var arestas := _arestas(aberto)
	if arestas.is_empty():
		return saida

	var rng := RandomNumberGenerator.new()
	rng.seed = semente

	var faixa: float = restricoes.get("faixa", 96.0)
	var zona: Rect2 = restricoes.get("zona_livre", Rect2())
	var raio_livre: float = restricoes.get("raio_livre", 0.0)
	var centro: Vector2 = restricoes.get("centro", centro_de(aberto))
	var bocas: Array = restricoes.get("bocas", [])
	var raio_de_boca: float = restricoes.get("raio_de_boca", 0.0)
	var espaco: float = restricoes.get("espaco_minimo", maxf(largura, 40.0))
	var grade: float = restricoes.get("grade", 0.0)
	# "no_chao_todo": sorteia na CAIXA da sala em vez de a partir de uma aresta.
	#
	# O sorteio por aresta e o certo para o que ENCOSTA em parede -- ele carrega
	# de graca a faixa de perimetro e os pesos por lado. Para o DECALQUE ele e o
	# errado, e o defeito nao aparece na contagem: medido, sorteando por aresta
	# com faixa grande, 89% das manchas caiam na area util e so 11% perto da
	# parede, porque a profundidade sorteada e uniforme mas o disco de exclusao
	# de cada porta come justamente a beirada. O piso saia com o miolo sujo e o
	# perimetro limpo -- o inverso do que a referencia mostra, e nenhum portao
	# de contagem veria.
	var no_chao_todo: bool = restricoes.get("no_chao_todo", false)
	var caixa := Rect2(aberto[0], Vector2.ZERO)
	for i in range(1, aberto.size()):
		caixa = caixa.expand(aberto[i])
	# Copia: quem chamou nao pode ter a propria lista mexida por baixo. O lote
	# ainda precisa evitar a si mesmo, e por isso o acumulador e local.
	var ocupados: Array = (restricoes.get("ocupados", []) as Array).duplicate()

	for _i in quantas:
		for _t in TENTATIVAS:
			if no_chao_todo:
				var solto := Vector2(
					rng.randf_range(caixa.position.x, caixa.end.x),
					rng.randf_range(caixa.position.y, caixa.end.y))
				if grade > 0.0:
					solto = (solto / grade).round() * grade
				if _cabe(solto, aberto, arestas, largura, zona, raio_livre, centro,
						bocas, raio_de_boca, ocupados, espaco):
					saida.append(solto)
					ocupados.append(solto)
					break
				continue
			var lado := int(rng.randi_range(0, 3))
			var candidatas: Array = []
			for aresta in arestas:
				if int(aresta["lado"]) == lado:
					candidatas.append(aresta)
			if candidatas.is_empty():
				continue
			var pesos := PackedFloat32Array()
			for aresta in candidatas:
				pesos.append(float(aresta["comprimento"]))
			var indice := _sortear_indice(rng, pesos)
			if indice < 0:
				continue
			var aresta: Dictionary = candidatas[indice]
			var comprimento := float(aresta["comprimento"])
			if comprimento < largura * 2.0:
				continue
			var a: Vector2 = aresta["a"]
			var b: Vector2 = aresta["b"]
			var margem := minf(MARGEM_DE_QUINA, comprimento * 0.25)
			var t := rng.randf_range(margem, comprimento - margem) / comprimento
			var normal: Vector2 = aresta["normal"]
			var fundo := maxf(BORDA_MINIMA + 1.0, faixa)
			var ponto := a.lerp(b, t) + normal * rng.randf_range(BORDA_MINIMA, fundo)
			if grade > 0.0:
				ponto = (ponto / grade).round() * grade

			if not _cabe(ponto, aberto, arestas, largura, zona, raio_livre, centro,
					bocas, raio_de_boca, ocupados, espaco):
				continue

			saida.append(ponto)
			ocupados.append(ponto)
			break
	return saida


## Os SEIS filtros de uma colocacao, num lugar so.
##
## Eles sairam de dentro do laco de `posicoes()` quando o sorteio ganhou um
## segundo modo. Duas copias dos mesmos seis testes divergiriam no primeiro
## ajuste, e o sintoma seria uma familia de decoracao obedecendo uma regra que a
## outra ja nao obedece -- em tela, e nunca no console.
## O CHAO que uma peca ocupa, e o que nao pode invadir a area de combate.
##
## Publica porque o portao precisa fazer a mesma conta: duas formas de medir a
## mesma pegada divergem, e aqui a divergencia seria o jogo colocando uma peca
## que a suite chama de invasora -- ou pior, o contrario.
static func pegada_no_chao(ponto: Vector2, largura: float) -> Rect2:
	return Rect2(
		ponto - Vector2(largura * 0.5, PROFUNDIDADE_NO_CHAO * 0.5),
		Vector2(largura, PROFUNDIDADE_NO_CHAO))


static func _cabe(
	ponto: Vector2, aberto: PackedVector2Array, arestas: Array, largura: float,
	zona: Rect2, raio_livre: float, centro: Vector2, bocas: Array,
	raio_de_boca: float, ocupados: Array, espaco: float
) -> bool:
	if not Geometry2D.is_point_in_polygon(ponto, aberto):
		return false
	# Folga de MEIO prop contra a parede: a posicao e o centro da peca, e uma
	# peca de 64 com a origem a 8 px da linha desenha metade dentro dela -- sem
	# erro, porque decoracao nao tem colisao para reclamar.
	if _distancia_as_arestas(ponto, arestas) < largura * 0.5:
		return false
	if raio_livre > 0.0 and ponto.distance_to(centro) < raio_livre:
		return false
	if zona.size != Vector2.ZERO and zona.intersects(pegada_no_chao(ponto, largura)):
		return false
	for boca in bocas:
		if (boca as Vector2).distance_to(ponto) < raio_de_boca:
			return false
	for outro in ocupados:
		if (outro as Vector2).distance_to(ponto) < espaco:
			return false
	return true


## O lado que fica RELATIVAMENTE calmo nesta sala (regra 8).
##
## Publico porque quem cobra a regra precisa saber qual lado foi escolhido sem
## reproduzir o sorteio principal -- ver `CHAVE_DO_LADO_VAZIO`.
static func lado_vazio(perfil: PerfilDeDecoracao, semente: int) -> int:
	if perfil == null:
		return Lado.SUL
	var rng := RandomNumberGenerator.new()
	rng.seed = semente ^ CHAVE_DO_LADO_VAZIO
	var normais := _pesos_normalizados(perfil)
	var invertidos := PackedFloat32Array()
	for lado in 4:
		invertidos.append(maxf(0.0, 1.0 - normais[lado]))
	var escolhido := _sortear_indice(rng, invertidos)
	return Lado.SUL if escolhido < 0 else escolhido


## O contorno sem o ponto de fechamento.
##
## O `Line2D` "Parede" das salas repete o primeiro ponto no fim para fechar o
## desenho, e `Geometry2D` engasga com o ponto duplicado -- a mesma limpeza que
## `Sala.contorno_local()` ja faz. Aceitar as duas formas e requisito: quem
## chama pode vir do `Line2D` cru ou da sala ja montada.
static func normalizar_contorno(contorno: PackedVector2Array) -> PackedVector2Array:
	var pontos := contorno.duplicate()
	while pontos.size() >= 2 and pontos[0].is_equal_approx(pontos[pontos.size() - 1]):
		pontos.remove_at(pontos.size() - 1)
	return pontos


## A caixa envolvente do contorno.
static func _caixa_de(aberto: PackedVector2Array) -> Rect2:
	if aberto.is_empty():
		return Rect2()
	var caixa := Rect2(aberto[0], Vector2.ZERO)
	for ponto in aberto:
		caixa = caixa.expand(ponto)
	return caixa


## O centro da zona livre de combate.
##
## E o centro do retangulo que envolve o contorno, e nao o centroide do
## poligono: as cenas de sala sao centradas na origem e a `area_spawn` delas e
## um `Rect2` centrado no mesmo ponto. O centroide de uma sala em L cairia num
## lugar que nenhum outro sistema do jogo considera "o meio da sala".
static func centro_de(contorno: PackedVector2Array) -> Vector2:
	var aberto := normalizar_contorno(contorno)
	if aberto.is_empty():
		return Vector2.ZERO
	var caixa := Rect2(aberto[0], Vector2.ZERO)
	for ponto in aberto:
		caixa = caixa.expand(ponto)
	return caixa.get_center()


## Distancia de um ponto a LINHA do contorno (nao ao interior).
##
## Publica porque e a forma de um portao medir a regra da faixa sem
## reimplementar a geometria -- reimplementada do outro lado, a regua e o codigo
## concordariam por acidente e divergiriam na primeira sala nao-retangular.
static func distancia_ao_contorno(ponto: Vector2, contorno: PackedVector2Array) -> float:
	var aberto := normalizar_contorno(contorno)
	var n := aberto.size()
	if n < 2:
		return 0.0
	var menor := INF
	for i in n:
		menor = minf(menor, _distancia_ao_segmento(ponto, aberto[i], aberto[(i + 1) % n]))
	return menor


## O mesmo, sobre a lista de arestas ja montada. E o caminho QUENTE: cada
## candidata a colocacao passa por aqui, e normalizar o contorno de novo a cada
## tentativa aloca um `PackedVector2Array` por pergunta.
static func _distancia_as_arestas(ponto: Vector2, arestas: Array) -> float:
	var menor := INF
	for aresta in arestas:
		var a: Vector2 = aresta["a"]
		var b: Vector2 = aresta["b"]
		menor = minf(menor, _distancia_ao_segmento(ponto, a, b))
	return menor


static func _distancia_ao_segmento(ponto: Vector2, a: Vector2, b: Vector2) -> float:
	return Geometry2D.get_closest_point_to_segment(ponto, a, b).distance_to(ponto)


static func distancia_minima_de(porte: int) -> float:
	if porte < 0 or porte >= DISTANCIA_MINIMA.size():
		return float(DISTANCIA_MINIMA[Porte.MEDIO])
	return float(DISTANCIA_MINIMA[porte])


## Porte -> a faixa de contagem que o perfil declara para ele.
##
## A traducao mora AQUI, num lugar so, porque `PerfilDeDecoracao` nao pode
## importar o enum sem fechar um ciclo entre dois `class_name`.
##
## **`MICRO` e `DECALQUE` deixaram de ser a mesma coisa.** Eles eram, e estava
## errado: micro e objeto pequeno (ferramenta, parafuso, sucata) e mora na faixa
## de perimetro como todo volume; decalque e chao pintado e mora em qualquer
## lugar. Fundi-los obrigava a escolher entre nao ter sujeira no centro e ter
## parafusos flutuando no meio do combate.
static func faixa_de_porte(perfil: PerfilDeDecoracao, porte: int) -> Vector2i:
	if perfil == null:
		return Vector2i.ZERO
	match porte:
		Porte.HERO:
			return perfil.contagem_hero
		Porte.GRANDE:
			return perfil.contagem_grande
		Porte.MEDIO:
			return perfil.contagem_medio
		Porte.PEQUENO:
			return perfil.contagem_pequeno
		Porte.MICRO:
			return perfil.contagem_micro
		Porte.DECALQUE:
			return perfil.contagem_decalque
		Porte.PAREDE:
			return perfil.contagem_parede
	return Vector2i.ZERO


static func peso_do_lado(perfil: PerfilDeDecoracao, lado: int) -> float:
	if perfil == null:
		return 0.0
	match lado:
		Lado.NORTE:
			return perfil.peso_norte
		Lado.LESTE:
			return perfil.peso_leste
		Lado.SUL:
			return perfil.peso_sul
		Lado.OESTE:
			return perfil.peso_oeste
	return 0.0


static func peso_de_hero_do_lado(perfil: PerfilDeDecoracao, lado: int) -> float:
	if perfil == null:
		return 0.0
	match lado:
		Lado.NORTE:
			return perfil.peso_hero_norte
		Lado.LESTE:
			return perfil.peso_hero_leste
		Lado.SUL:
			return perfil.peso_hero_sul
		Lado.OESTE:
			return perfil.peso_hero_oeste
	return 0.0


# ------------------------------------------------------------- colocacao -----

## Uma peca sozinha. Ela e o proprio cluster para efeito de distancia: dois
## avulsos guardam a distancia do porte entre si, como dois conjuntos.
static func _tentar_avulso(ctx: Dictionary, porte: int, hero: bool) -> bool:
	# O decalque nao passa pelo sorteio de LADO: ele nao mora na faixa de
	# perimetro, entao nao ha lado a sortear. Dar-lhe um lado e depois afastar
	# pela normal produziria a moldura de sujeira que a referencia nao tem.
	if porte == Porte.DECALQUE:
		for _t in TENTATIVAS:
			var livre := _ancorar_livre(ctx)
			if livre.is_empty():
				continue
			var onde: Vector2 = livre["posicao"]
			if not _no_lugar(ctx, onde, porte):
				continue
			_registrar(ctx, onde, porte, &"", int(livre["lado"]), _novo_id(ctx))
			return true
		return false

	for _t in TENTATIVAS:
		var lado := _sortear_lado(ctx, porte, hero)
		if lado < 0:
			return false
		var fundura := PROFUNDIDADE_DE_PAREDE if porte == Porte.PAREDE else -1.0
		var ancora := _ancorar(ctx, lado, fundura)
		if ancora.is_empty():
			continue
		var posicao: Vector2 = ancora["posicao"]
		if not _no_lugar(ctx, posicao, porte):
			continue
		if not _longe_o_bastante(ctx, posicao, porte, -1):
			continue
		_registrar(ctx, posicao, porte, &"", lado, _novo_id(ctx))
		return true
	return false


## Um CLUSTER inteiro, ou nenhuma peca dele.
##
## As pecas nao sao conferidas umas contra as outras -- e a sobreposicao leve
## permitida dentro do conjunto (regra 5). Elas sao conferidas contra a
## geometria (faixa, zona livre, dentro do poligono) e contra o que ja esta na
## sala, porque nada disso e negociavel por estar num conjunto.
static func _tentar_agrupamento(ctx: Dictionary, agrupamento: AgrupamentoDeDecoracao) -> bool:
	if agrupamento == null or agrupamento.contagem_de_pecas() <= 0:
		return false
	for _t in TENTATIVAS:
		# O cluster nunca ancora no lado calmo: ele carrega massa por definicao,
		# e e massa que a regra do vazio existe para manter fora dali.
		var lado := _sortear_lado(ctx, Porte.GRANDE, false)
		if lado < 0:
			return false
		var ancora := _ancorar(ctx, lado)
		if ancora.is_empty():
			continue
		var origem: Vector2 = ancora["posicao"]
		var normal: Vector2 = ancora["normal"]
		var tangente: Vector2 = ancora["tangente"]

		var propostas: Array = []
		var todas_cabem := true
		for i in agrupamento.contagem_de_pecas():
			# O deslocamento e declarado na moldura do lado NORTE (+x ao longo
			# da parede, +y entrando na sala) e girado para o lado sorteado. Sem
			# esse giro, um conjunto desenhado para o norte entraria sala
			# adentro ao cair no leste.
			var deslocamento := agrupamento.deslocamento_da_peca(i)
			var posicao := origem + tangente * deslocamento.x + normal * deslocamento.y
			var porte := agrupamento.porte_da_peca(i)
			if not _no_lugar(ctx, posicao, porte) or not _longe_o_bastante(ctx, posicao, porte, -1):
				todas_cabem = false
				break
			propostas.append([posicao, porte])
		if not todas_cabem:
			continue

		var id := _novo_id(ctx)
		for proposta in propostas:
			var onde: Vector2 = proposta[0]
			var qual_porte: int = proposta[1]
			_registrar(ctx, onde, qual_porte, agrupamento.nome, lado, id)
		return true
	return false


static func _registrar(
	ctx: Dictionary, posicao: Vector2, porte: int, nome: StringName, lado: int, id: int
) -> void:
	var saida: Array = ctx["saida"]
	saida.append({
		"posicao": posicao,
		"porte": porte,
		"agrupamento": nome,
		"lado": lado,
	})
	var ids: Array = ctx["ids"]
	ids.append(id)
	if lado == int(ctx["vazio"]):
		ctx["no_lado_vazio"] = int(ctx["no_lado_vazio"]) + 1


static func _novo_id(ctx: Dictionary) -> int:
	var id := int(ctx["proximo_id"])
	ctx["proximo_id"] = id + 1
	return id


## As regras de GEOMETRIA, na ordem em que elas custam menos.
##
## **Elas dependem do PORTE, e essa e a correcao que a referencia exigiu.** A
## primeira versao aplicava as tres a tudo, e o resultado era um centro de sala
## completamente chapado -- enquanto `docs/fabrica_01.png` mostra marcacao de
## piso e grades espalhadas justamente por ali.
##
## Hoje sao tres regimes:
##
## - **VOLUME** (hero, grande, medio, pequeno, micro): dentro do poligono, FORA
##   da zona livre e DENTRO da faixa de perimetro. E o que protege o combate.
## - **DECALQUE**: so precisa estar dentro do poligono. Ele e plano, nao tem
##   silhueta e nao esconde projetil -- as duas outras regras existem para
##   proteger a leitura de coisas que ocupam espaco, e ele nao ocupa.
## - **PAREDE**: dentro do poligono e colado na face. A zona livre nao se aplica
##   porque ele esta na parede por construcao; numa sala pequena o contorno pode
##   passar a menos de `raio_da_zona_livre` do centro, e ali a regra recusaria
##   uma peca que nao esta na area de combate coisa nenhuma.
static func _no_lugar(ctx: Dictionary, posicao: Vector2, porte: int) -> bool:
	var aberto: PackedVector2Array = ctx["aberto"]
	if not Geometry2D.is_point_in_polygon(posicao, aberto):
		return false

	# A BOCA DE PORTA vale para TODOS os portes, decalque incluido: uma seta
	# pintada metade para dentro do vao le como erro de montagem, e um tanque na
	# frente da passagem e pior. `posicoes()` ja cobrava isso; sem esta linha a
	# troca por `decorar()` teria perdido a regra em silencio.
	var raio_de_boca: float = ctx.get("raio_de_boca", 0.0)
	if raio_de_boca > 0.0:
		for boca in (ctx.get("bocas", []) as Array):
			if (boca as Vector2).distance_to(posicao) < raio_de_boca:
				return false

	if porte == Porte.DECALQUE:
		return true

	var perfil: PerfilDeDecoracao = ctx["perfil"]
	var arestas: Array = ctx["arestas"]
	var fundura := _distancia_as_arestas(posicao, arestas)
	if porte == Porte.PAREDE:
		return fundura <= PROFUNDIDADE_DE_PAREDE

	# A AREA UTIL autorada tem prioridade sobre o raio, quando ela chega.
	var zona: Rect2 = ctx.get("zona_livre", Rect2())
	if zona.size != Vector2.ZERO:
		if zona.has_point(posicao):
			return false
	else:
		var centro: Vector2 = ctx["centro"]
		if posicao.distance_to(centro) < perfil.raio_da_zona_livre:
			return false
	return fundura <= perfil.largura_da_faixa_de_perimetro


## A regra 5 vista do lado de quem chega: distancia contra tudo que nao e do
## MEU cluster. `id` negativo e "ainda nao registrado", e compara contra tudo.
static func _longe_o_bastante(ctx: Dictionary, posicao: Vector2, porte: int, id: int) -> bool:
	# Decalque se sobrepoe: mancha sobre mancha e o que uma fabrica usada
	# produz, e exigir espaco entre elas desenharia uma grade regular de sujeira.
	if porte == Porte.DECALQUE:
		return true
	var saida: Array = ctx["saida"]
	var ids: Array = ctx["ids"]
	var minha := distancia_minima_de(porte)
	for i in saida.size():
		if id >= 0 and int(ids[i]) == id:
			continue
		var outra: Dictionary = saida[i]
		var exigida := maxf(minha, distancia_minima_de(int(outra["porte"])))
		var posicao_da_outra: Vector2 = outra["posicao"]
		if posicao_da_outra.distance_to(posicao) < exigida:
			return false
	return true


static func _contagem_de(ctx: Dictionary, porte: int) -> int:
	var saida: Array = ctx["saida"]
	var total := 0
	for colocacao in saida:
		if int(colocacao["porte"]) == porte:
			total += 1
	return total


# ----------------------------------------------------------- os sorteios -----

## O lado desta peca, ja descontado o que nao pode receber.
##
## Um lado sai da conta por dois motivos: nao ter aresta longa o bastante para
## ancorar, ou ser o lado calmo. O segundo so vale para os tres portes de massa
## -- os dois menores ainda entram ali, ate `PECAS_NO_LADO_VAZIO`.
static func _sortear_lado(ctx: Dictionary, porte: int, hero: bool) -> int:
	var perfil: PerfilDeDecoracao = ctx["perfil"]
	var por_lado: Array = ctx["por_lado"]
	var pesos := PackedFloat32Array()
	for lado in 4:
		var peso := peso_de_hero_do_lado(perfil, lado) if hero else peso_do_lado(perfil, lado)
		peso = maxf(peso, 0.0)
		var candidatas: Array = por_lado[lado]
		if candidatas.is_empty():
			peso = 0.0
		if lado == int(ctx["vazio"]) and not _cabe_no_lado_vazio(ctx, porte):
			peso = 0.0
		pesos.append(peso)
	var rng: RandomNumberGenerator = ctx["rng"]
	return _sortear_indice(rng, pesos)


static func _cabe_no_lado_vazio(ctx: Dictionary, porte: int) -> bool:
	if porte < Porte.PEQUENO:
		return false
	return int(ctx["no_lado_vazio"]) < PECAS_NO_LADO_VAZIO


## Um ponto na FAIXA de perimetro daquele lado, mais a moldura local dele.
##
## A ancora fica na METADE interna da faixa no maximo, porque os deslocamentos
## do cluster ainda vao empurrar pecas para dentro a partir dela -- ancorar no
## fundo da faixa faria todo conjunto estourar a regra 1 pela peca de tras.
## `profundidade_maxima` negativa = metade da faixa de perimetro, que e o
## default de sempre. Quem passa numero e o porte PAREDE, que mora colado na
## face.
static func _ancorar(ctx: Dictionary, lado: int, profundidade_maxima: float = -1.0) -> Dictionary:
	var perfil: PerfilDeDecoracao = ctx["perfil"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var por_lado: Array = ctx["por_lado"]
	var candidatas: Array = por_lado[lado]
	if candidatas.is_empty():
		return {}

	# Aresta sorteada por COMPRIMENTO: uma parede de 960 px recebe mais que um
	# trecho de 128 do mesmo lado, senao o trecho curto fica lotado.
	var pesos := PackedFloat32Array()
	for aresta in candidatas:
		pesos.append(float(aresta["comprimento"]))
	var indice := _sortear_indice(rng, pesos)
	if indice < 0:
		return {}

	var aresta: Dictionary = candidatas[indice]
	var comprimento := float(aresta["comprimento"])
	var margem := minf(MARGEM_DE_QUINA, comprimento * 0.25)
	var a: Vector2 = aresta["a"]
	var b: Vector2 = aresta["b"]
	var t := rng.randf_range(margem, comprimento - margem) / comprimento
	var normal: Vector2 = aresta["normal"]
	var fundo := maxf(
		BORDA_MINIMA + 1.0,
		BORDA_MINIMA + (perfil.largura_da_faixa_de_perimetro - BORDA_MINIMA) * FRACAO_DA_ANCORA)
	if profundidade_maxima > 0.0:
		fundo = maxf(BORDA_MINIMA + 1.0, profundidade_maxima)
	return {
		"posicao": a.lerp(b, t) + normal * rng.randf_range(BORDA_MINIMA, fundo),
		"normal": normal,
		"tangente": normal.orthogonal(),
	}


## Uma posicao em QUALQUER lugar da sala, para o decalque.
##
## Ela sorteia na caixa envolvente e repete ate cair dentro do poligono, em vez
## de sortear numa aresta e afastar pela normal. E a diferenca entre "sujeira
## onde a fabrica foi usada" e "sujeira em volta da parede": a segunda desenha
## uma moldura, e moldura nao e o que a referencia mostra.
##
## O `lado` devolvido e o da aresta mais PROXIMA -- ele existe para quem quiser
## agrupar, e nao para a regra de pesos, que nao vale para decalque.
static func _ancorar_livre(ctx: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = ctx["rng"]
	var aberto: PackedVector2Array = ctx["aberto"]
	var caixa: Rect2 = ctx["caixa"]
	for _t in TENTATIVAS:
		var posicao := Vector2(
			rng.randf_range(caixa.position.x, caixa.end.x),
			rng.randf_range(caixa.position.y, caixa.end.y))
		if Geometry2D.is_point_in_polygon(posicao, aberto):
			return {"posicao": posicao, "lado": _lado_mais_proximo(ctx, posicao)}
	return {}


## O lado da aresta mais proxima de um ponto solto.
static func _lado_mais_proximo(ctx: Dictionary, posicao: Vector2) -> int:
	var arestas: Array = ctx["arestas"]
	var melhor := Lado.NORTE
	var menor := INF
	for aresta in arestas:
		var d := Geometry2D.get_closest_point_to_segment(
			posicao, aresta["a"], aresta["b"]).distance_to(posicao)
		if d < menor:
			menor = d
			melhor = int(aresta["lado"])
	return melhor


## Os clusters desta sala, SEM REPOSICAO e com a memoria recente aplicada.
##
## Sem reposicao porque o mesmo conjunto duas vezes na mesma sala vira mobilia
## -- e a mesma razao pela qual `DadosSala.regioes_props_raras` existe.
static func _escolher_agrupamentos(
	perfil: PerfilDeDecoracao, rng: RandomNumberGenerator, recentes: Array, quantos: int
) -> Array[AgrupamentoDeDecoracao]:
	var escolhidos: Array[AgrupamentoDeDecoracao] = []
	var pool := perfil.agrupamentos_validos()
	if pool.is_empty():
		return escolhidos
	var pesos := PackedFloat32Array()
	for agrupamento in pool:
		pesos.append(PESO_RECENTE if _esta_em(recentes, agrupamento.nome) else 1.0)
	var alvo := mini(maxi(quantos, 0), pool.size())
	while escolhidos.size() < alvo:
		var indice := _sortear_indice(rng, pesos)
		if indice < 0:
			break
		escolhidos.append(pool[indice])
		# Zerar o peso e o "sem reposicao": remover do array desalinharia os
		# dois lados, que e a armadilha que este projeto ja paga noutro lugar.
		pesos[indice] = 0.0
	return escolhidos


## Comparacao por TEXTO, e nao por `Array.has()`.
##
## `recentes` chega do gerenciador do andar e pode carregar `String` onde o
## recurso guarda `StringName`. Um `has()` que erre por tipo nao da erro: ele
## responde "nao vi esse cluster" e a memoria recente vira decoracao morta.
static func _esta_em(recentes: Array, nome: StringName) -> bool:
	for item in recentes:
		if String(item) == String(nome):
			return true
	return false


static func _sorteio_na_faixa(rng: RandomNumberGenerator, faixa: Vector2i) -> int:
	var minimo := maxi(mini(faixa.x, faixa.y), 0)
	var maximo := maxi(maxi(faixa.x, faixa.y), minimo)
	return rng.randi_range(minimo, maximo)


## Sorteio ponderado. -1 quando nao ha nenhuma opcao viva -- e quem chama tem de
## tratar isso, porque "todos os lados estao cheios" e um estado normal.
static func _sortear_indice(rng: RandomNumberGenerator, pesos: PackedFloat32Array) -> int:
	var total := 0.0
	for peso in pesos:
		total += maxf(peso, 0.0)
	if total <= 0.0:
		return -1
	var alvo := rng.randf() * total
	var acumulado := 0.0
	for i in pesos.size():
		acumulado += maxf(pesos[i], 0.0)
		if alvo <= acumulado:
			return i
	return pesos.size() - 1


static func _pesos_normalizados(perfil: PerfilDeDecoracao) -> PackedFloat32Array:
	var pesos := PackedFloat32Array()
	var total := 0.0
	for lado in 4:
		var peso := maxf(peso_do_lado(perfil, lado), 0.0)
		pesos.append(peso)
		total += peso
	if total <= 0.0:
		for lado in 4:
			pesos[lado] = 0.25
		return pesos
	for lado in 4:
		pesos[lado] = pesos[lado] / total
	return pesos


# ------------------------------------------------------------- geometria -----

## As arestas do contorno, cada uma com a normal que aponta para DENTRO e o lado
## a que ela pertence.
##
## Sai daqui e nao de um retangulo porque as salas do jogo tem formas
## nao-retangulares -- a sala em L, a de pilar, e o chanfro que `Sala` aplica em
## toda quina. Trabalhar por aresta faz a sala em L funcionar sem geometria
## nova, do mesmo jeito que a fita de parede ja faz.
static func _arestas(aberto: PackedVector2Array) -> Array:
	var lista: Array = []
	var n := aberto.size()
	for i in n:
		var a := aberto[i]
		var b := aberto[(i + 1) % n]
		var comprimento := a.distance_to(b)
		if comprimento <= 0.001:
			continue
		var normal := _normal_interna(a, b, aberto)
		if normal == Vector2.ZERO:
			continue
		lista.append({
			"a": a,
			"b": b,
			"normal": normal,
			"comprimento": comprimento,
			"lado": _lado_da_normal(normal),
		})
	return lista


## Qual das duas perpendiculares aponta para dentro da sala.
##
## Decidido por TESTE e nao pela orientacao do poligono: o contorno pode chegar
## horario ou anti-horario conforme quem desenhou o `Line2D`, e assumir um
## sentido inverteria a faixa inteira -- todos os props do lado de fora da
## parede, sem uma linha no console.
static func _normal_interna(a: Vector2, b: Vector2, aberto: PackedVector2Array) -> Vector2:
	var meio := (a + b) * 0.5
	var candidata := (b - a).orthogonal().normalized()
	if Geometry2D.is_point_in_polygon(meio + candidata * EPSILON_INTERNO, aberto):
		return candidata
	if Geometry2D.is_point_in_polygon(meio - candidata * EPSILON_INTERNO, aberto):
		return -candidata
	return Vector2.ZERO


## O lado a que uma normal interna pertence, pelo eixo DOMINANTE.
##
## Y cresce para baixo: a parede de cima (norte) tem normal apontando para +Y.
## O eixo dominante e o que trata o chanfro de quina -- ele nao e um lado, e a
## transicao entre dois, e atribui-lo ao vizinho mais proximo e melhor que criar
## um quinto lado que nenhum peso do perfil conhece.
static func _lado_da_normal(normal: Vector2) -> int:
	if absf(normal.y) >= absf(normal.x):
		return Lado.NORTE if normal.y > 0.0 else Lado.SUL
	return Lado.OESTE if normal.x > 0.0 else Lado.LESTE


## As arestas ANCORAVEIS de cada lado.
##
## O piso de comprimento tira chanfro e trecho curto da conta; se um lado ficar
## sem nenhuma, ele recupera as proprias arestas curtas -- sala pequena nao pode
## perder um lado inteiro por causa de um piso pensado para sala grande.
static func _arestas_por_lado(arestas: Array) -> Array:
	var por_lado: Array = [[], [], [], []]
	var curtas: Array = [[], [], [], []]
	for aresta in arestas:
		var lado := int(aresta["lado"])
		curtas[lado].append(aresta)
		if float(aresta["comprimento"]) >= COMPRIMENTO_MINIMO_DE_ARESTA:
			por_lado[lado].append(aresta)
	for lado in 4:
		if (por_lado[lado] as Array).is_empty():
			por_lado[lado] = curtas[lado]
	return por_lado
