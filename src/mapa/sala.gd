class_name Sala
extends Node2D
## Uma sala do andar: contorno, portas, colisao de parede e o ciclo de combate.
##
## Decisao de design que este script carrega: a **forma da sala e desenhada uma
## vez so**, no Line2D "Parede". Colisao, limites de camera e os vaos das portas
## saem todos desses mesmos pontos, gerados em codigo no _ready. Nao existe
## tamanho de celula declarado em lugar nenhum -- se alguem arrastar um ponto do
## contorno no editor, a parede fisica acompanha sozinha. Sala em L, corredor e
## arena grande usam este mesmo script sem caso especial.
##
## Segunda decisao: porta sem vizinho do outro lado e SELADA, e parede passa
## reta por cima dela. Buraco para o vazio e pior que sala fechada.
##
## Terceira decisao: quem precisa de um ponto DENTRO da sala pergunta a ela, e
## nunca deduz do bounding box. O centro da caixa do L e o canto concavo (fora
## da sala) e o centro da sala de pilar e o pilar -- os dois casos ja nasceram o
## jogador dentro de geometria solida. ponto_seguro() e posicao_livre() existem
## para isso, e olham o contorno real mais os obstaculos.
##
## Quarta decisao: **a sala nao escolhe os proprios inimigos, so os coloca.**
## Quem decide quantos e quais e o GerenciadorMapa, uma vez, na montagem do
## andar -- e entrega a lista pronta em definir_composicao(). Antes isso morava
## num no "Ondas" dentro de cada .tscn, o que amarrava a dificuldade a qual cena
## caiu na celula: a sala inicial podia calhar de ser a arena grande com nove
## inimigos. Com a composicao vindo de fora, o gerador tem palavra sobre o ritmo
## do andar, e a sala continua sem saber que existe um andar.
##
## Quinta decisao: **o visual tambem nasce do contorno, em codigo.** Nenhuma
## cena de sala carrega textura. No _ready, ao lado da parede fisica, a sala
## monta o corpo da parede (o contorno inflado 24 px para fora, atras do chao),
## o chao (o proprio contorno, texturizado com UV ancorada no CANTO) e os props.
## O Line2D "Parede" continua sendo a fonte da geometria, mas fica invisivel em
## runtime. Qual textura e cada uma, o DadosSala do tipo diz em definir_visual();
## sem dados (cena aberta sozinha), cai na variante `combate`.
##
## Houve tambem um filete de neon correndo pelo contorno. Ele saiu quando a
## parede ganhou textura propria: com as duas coisas na tela o neon virava uma
## segunda borda desenhada por cima da primeira, e como a camera para no
## contorno era o neon -- e nao a parede -- que encostava na beira do quadro.

enum Estado { INATIVA, OCUPADA, LIMPA }

## Layer 3 do project.godot. Parede colide com tudo e nao procura ninguem.
const LAYER_PAREDE := 4
## Sub-segmento menor que isso e ruido de arredondamento: vao encostando na
## quina do contorno. Criar a forma so daria uma colisao degenerada.
const COMPRIMENTO_MINIMO := 8.0
## Folga para aceitar que uma porta "esta sobre" um segmento do contorno.
const TOLERANCIA_ENCAIXE := 24.0
## Quanto o jogador entra na sala alem da boca da porta. Menos que isso e o
## lockdown fecha a parede em cima dele no mesmo frame da chegada.
const RECUO_ENTRADA := 48.0
## Folga exigida entre o corpo do jogador e qualquer parede ou obstaculo. O
## CollisionShape2D do player tem raio 11; o resto e margem para ele nao nascer
## raspando numa quina e ser empurrado para dentro do solido pela resolucao.
const FOLGA_CORPO := 24.0
## Quantas posicoes o spawn testa antes de aceitar a melhor que achou. Vinte e
## quatro cobre com folga a sala mais recortada, e o custo e uma vez por
## inimigo, uma vez por sala.
const TENTATIVAS_DE_SPAWN := 24
## Folga exigida em volta de um inimigo recem-colocado. Menor que a do jogador
## porque o corpo deles e menor, e porque exigir a mesma coisa faria o braco
## estreito da sala em L rejeitar quase todo ponto.
const FOLGA_SPAWN := 20.0
## Passo da varredura que procura ponto livre. Cada candidato e validado exato,
## entao o passo so decide o quao estreita pode ser uma passagem para ainda ser
## encontrada: 64 acha qualquer vao maior que isso e custa poucas centenas de
## testes na maior sala, uma vez so por sala.
const PASSO_VARREDURA := 32.0

## Quanto a parede avanca para FORA do contorno. Combina com a moldura da porta
## (96x128 centrada no vao), que cobre exatamente esta faixa.
##
## Foi 24 ate a migracao Low Top-Down. Virou 64 -- o tile da parede -- porque
## uma faixa de 24 nao tem onde caber topo E face: a face sozinha ficaria com
## 12 px e o volume nao apareceria. 64 e multiplo de 16 e de 32, entao a grade
## estrutural do projeto nao muda.
const ESPESSURA_PAREDE := 64.0
## Quanto da faixa, medido do contorno para fora, e FACE em vez de topo.
##
## Metade: a razao face:topo fica 1:1, que e a regra operavel da direcao de arte
## (LOW_TOPDOWN_SQUARED secao 24) -- a forma conferivel de "todos os elementos
## compartilham a mesma camera imaginaria".
##
## A face fica na metade INTERNA, colada no contorno, e o topo na externa. E a
## ordem que a camera ve: olhando uma parede ao norte, a superficie vertical
## esta na frente e a espessura dela atras.
const ALTURA_FACE := 32.0
## Quao "para cima" a normal de um lado precisa apontar para ele ganhar face.
## So parede voltada para o SUL mostra face; a de baixo mostra so o topo, que e
## a Solucao 1 do documento (parede cortada) e o que impede o cenario de cobrir
## jogador, inimigo, projetil e telegrafo.
const LIMIAR_LADO_NORTE := -0.5
## As faixas de z do mundo, em ordem. Este bloco e o CONTRATO que a migracao
## para Low Top-Down Squared usa (docs/LOW_TOPDOWN_SQUARED.md secao 22): quem
## desenha no mundo escolhe uma faixa daqui, e nunca um numero solto.
##
## Elas sao espacadas de 2 de proposito -- sobra lugar para uma camada nova
## entre duas existentes sem renumerar as outras, e renumerar seria justamente
## o tipo de mudanca que quebra ordem de desenho sem erro no console.
##
## ATENCAO ao ParedeTopo: ele e a UNICA faixa fora da ordem do documento, e o
## motivo e geometrico. O corpo da parede e o contorno inteiro INFLADO e
## solido, desenhado ATRAS do chao -- e o chao, por cima, recorta a faixa de 24
## px que sobra. E isso que faz a sala em L funcionar sem calcular anel com
## furo. Subi-lo para acima do chao, como o documento pede, faria o poligono
## cobrir a sala inteira. Quem sobe para -14 e a FACE da parede (issue LTD 04),
## e ela pode: a face e desenhada FORA do contorno, entao nao cobre nada.
const Z_PAREDE_TOPO := -22
const Z_CHAO := -20
const Z_CHAO_DETALHE := -18
## Reservada para a face vertical da parede (LTD 04). O obstaculo solido usa
## esta faixa desde ja: ele e parede no meio da sala e PRECISA cobrir o chao,
## entao nao pode usar o truque do recorte.
const Z_PAREDE_FACE := -14
## Onde vive quem se ordena por Y: player, inimigos, props com volume, pickups.
## Ainda nao existe nó -- e a issue LTD 02.
const Z_MUNDO := 0
## O que passa POR CIMA do ator: viga, cabo, topo de maquina alta (LTD 10).
const Z_FRENTE := 10
## Onde moram as texturas da variante neutra, usadas quando a sala roda sem
## GerenciadorMapa (aberta sozinha no editor, instanciada por uma suite).
## Fallback quando a sala nao recebeu DadosSala -- cena aberta sozinha no editor,
## ou a amostra que `_montar_catalogo()` instancia para medir portas.
##
## Aponta para a primeira variante da noite base. Nao pode apontar para arquivo
## que nao exista: `_texturizar()` cai em COR_CHAO_EMERGENCIA sem erro nenhum no
## console, e a sala fica LISA. Nenhuma suite pega isso -- `teste_grade.gd` nunca
## faz `add_child`, entao o `_ready` nao roda, e o teste de fumaca nao olha
## textura.
const TEXTURA_PADRAO := "res://assets/texturas/%s_andar1_a.png"
## Cor de emergencia do chao quando a textura nao carrega: o N1 da paleta, que
## e o chao que o jogo sempre teve. Sala invisivel seria pior que sala lisa.
const COR_CHAO_EMERGENCIA := Color("0b0d16")
## Lado de uma celula do atlas de props e passo da grade em que eles assentam.
const PROP_LADO := 32.0
const PROP_GRADE := 8.0
## Faixa, medida da parede para dentro, onde um prop pode ficar. Menos que o
## minimo e o prop entra na parede; mais que o maximo e ele parece bloquear.
const PROP_AFASTAMENTO_MINIMO := 24.0
const PROP_AFASTAMENTO_MAXIMO := 44.0
## Prop perto de porta parece que tapa a porta.
const PROP_DISTANCIA_DE_PORTA := 96.0
## Distancia minima entre dois props, para nao empilharem.
const PROP_ESPACO := 40.0
## Tentativas por prop antes de desistir dele. Sala recortada rejeita muito.
const PROP_TENTATIVAS := 12

## StringName e nao String porque este campo virou chave: o gerenciador e o
## minimapa comparam com os ids de DadosSala, e comparacao de StringName e por
## ponteiro. Os ids conhecidos moram em DadosSala (ID_BOSS, ID_ARMA...), entao
## ninguem precisa repetir string magica.
@export var tipo: StringName = DadosSala.ID_COMBATE

## Retangulo util onde os inimigos podem nascer, em coordenadas LOCAIS da sala.
## Quem monta uma sala no editor pensa nas coordenadas dela, nao nas do andar --
## e e isso que permite a mesma cena servir a varias celulas sem saber onde foi
## parar. O default cobre a sala padrao de 960x544 com margem de parede.
@export var area_spawn: Rect2 = Rect2(-352, -176, 704, 352)
## Distancia minima entre um inimigo recem-colocado e o jogador.
@export var distancia_minima_player: float = 180.0

var estado: Estado = Estado.INATIVA
var coordenadas_grid: Vector2i = Vector2i.ZERO

## Direcoes que o gerenciador confirmou ter vizinho. Vazio nao significa "sem
## vizinho": significa que ninguem configurou (sala aberta solta para teste).
## Por isso a flag separada -- sem ela, rodar a cena isolada selaria tudo.
var _conexoes: Array[Vector2] = []
var _conexoes_definidas: bool = false

var _portas_por_direcao: Dictionary = {}
var _raiz_portas: Node2D = null

## Cenas que esta sala vai colocar quando o jogador entrar. Vazia = sala sem
## combate, e e so isso que separa a de recompensa da de briga.
var _composicao: Array[PackedScene] = []
var _vivos: Array[Node] = []
var _container: Node2D = null
## Sala de recompensa nasce LIMPA no _ready, antes de o jogador existir por
## perto. Sem esta trava ela nunca anunciaria, e a tela de fim mostrava
## "9 / 10" numa run completa; anunciar no _ready contaria as dez salas do
## andar de uma vez, inclusive as que ninguem visitou.
var _anunciou_limpa: bool = false

## Area do contorno em pixels quadrados. Nao muda em runtime, e quem pergunta e
## o sorteio de composicao -- vale a pena pagar a conta uma vez so.
var _area_contorno: float = -1.0

## A geometria da sala nao muda em runtime, e a varredura e determinista: vale a
## pena pagar uma vez e devolver sempre o mesmo ponto. Nascer em lugar diferente
## a cada reentrada na mesma sala seria ruido, nao variedade.
var _ponto_seguro_local: Vector2 = Vector2.ZERO
var _ponto_seguro_pronto: bool = false

## O tipo que veste esta sala. Nulo = variante neutra, sem props.
var _dados_visual: DadosSala = null


func _ready() -> void:
	add_to_group("salas")
	# O Y-sort do mundo so alcanca os inimigos se a corrente inteira estiver
	# ligada -- Mundo, GerenciadorMapa, Sala e ContainerInimigos. Uma unica
	# ligacao solta faz o jogador deixar de se ordenar contra quem esta dentro
	# da sala, e nao ha erro no console para isso: o jogo continua rodando com
	# a ordem de desenho vindo da arvore.
	#
	# Nao afeta as camadas de chao e parede: elas moram em faixas de z
	# proprias, e z_index tem prioridade sobre Y -- so irmaos no MESMO z se
	# ordenam por posicao.
	y_sort_enabled = true
	# O container que vem da CENA e ligado aqui, e nao so no getter: o getter e
	# preguicoso (so roda quando a sala povoa), entao uma sala que ainda nao
	# lutou -- ou que nunca vai lutar -- ficava com o elo solto. Quem cria o
	# container em codigo e ligado la, porque aqui ele ainda nao existe.
	var container_da_cena := get_node_or_null("ContainerInimigos") as Node2D
	if container_da_cena != null:
		container_da_cena.y_sort_enabled = true
	_mapear_portas()
	_selar_portas_sem_vizinho()
	_montar_paredes()
	_montar_visual()
	_montar_decoracao()


## Le as portas direto dos filhos de $Portas. Vale antes de add_child: o
## gerenciador instancia cada cena uma vez so para montar o catalogo de formas,
## e nesse momento a sala ainda nao esta na arvore.
func direcoes_disponiveis() -> Array[Vector2]:
	var lista: Array[Vector2] = []
	var raiz := get_node_or_null("Portas")
	if raiz == null:
		return lista
	for filho in raiz.get_children():
		var porta := filho as Porta
		if porta != null:
			lista.append(porta.vetor())
	return lista


## Chamado ANTES de add_child. So guarda -- quem age e o _ready, que ja tem as
## portas mapeadas e ainda nao montou parede nenhuma.
func configurar_conexoes(direcoes: Array[Vector2]) -> void:
	_conexoes = direcoes.duplicate()
	_conexoes_definidas = true


## Chamado ANTES de add_child, como configurar_conexoes: e o _ready que monta
## as camadas, e ele precisa saber de que tipo a sala e para escolher textura.
## Aceita nulo de proposito -- a cena aberta sozinha no editor nao tem dados e
## nao pode explodir.
func definir_visual(dados: DadosSala) -> void:
	_dados_visual = dados


## O que vai nascer aqui quando o jogador entrar.
##
## Chamado pelo GerenciadorMapa depois do add_child e antes de ativar(). Lista
## vazia deixa a sala sem combate -- e o que a sala inicial, a de arma e a de
## item recebem.
func definir_composicao(cenas: Array[PackedScene]) -> void:
	_composicao = cenas.duplicate()


## Area do contorno em pixels quadrados, pela formula do shoelace.
##
## E a medida que o gerador usa para dar mais inimigos a uma sala maior. A area
## do bounding box nao serve: a sala em L teria a do retangulo inteiro e
## receberia inimigos para um pedaco que nao existe.
func area_do_contorno() -> float:
	if _area_contorno >= 0.0:
		return _area_contorno
	var pontos := contorno_local()
	var soma := 0.0
	for i in pontos.size():
		var a := pontos[i]
		var b := pontos[(i + 1) % pontos.size()]
		soma += a.x * b.y - b.x * a.y
	_area_contorno = absf(soma) * 0.5
	return _area_contorno


## Bounding box GLOBAL do contorno. E daqui que a camera tira os limites.
func obter_limites() -> Rect2:
	var pontos := _pontos_do_contorno()
	if pontos.is_empty():
		push_warning("Sala '%s': sem Line2D 'Parede', limites indefinidos." % name)
		return Rect2(global_position, Vector2.ZERO)
	var limites := Rect2(to_global(pontos[0]), Vector2.ZERO)
	for i in range(1, pontos.size()):
		limites = limites.expand(to_global(pontos[i]))
	return limites


## Posicao GLOBAL da porta daquele lado. Sem porta no lado pedido, cai no centro
## da sala -- ruim de ver, mas nunca teleporta o jogador para fora do mapa.
func boca_da_porta(direcao: Vector2) -> Vector2:
	var porta := _portas_por_direcao.get(direcao) as Porta
	if porta == null:
		return global_position
	return porta.global_position


## Onde largar o jogador que chegou andando em `direcao_vinda`: ele entra pela
## porta do lado oposto e ja aparece dentro da sala, nao em cima do vao.
func ponto_de_entrada(direcao_vinda: Vector2) -> Vector2:
	return boca_da_porta(-direcao_vinda) + direcao_vinda * RECUO_ENTRADA


## Ponto GLOBAL onde cabe um corpo do tamanho do jogador: dentro do contorno
## real, longe da parede e fora de qualquer obstaculo. Use isto sempre que
## precisar de "um lugar dentro da sala" sem uma porta para se guiar -- o centro
## do bounding box NAO serve, ele cai no entalhe do L e em cima do pilar.
func ponto_seguro() -> Vector2:
	if not _ponto_seguro_pronto:
		_ponto_seguro_local = _procurar_ponto_seguro()
		_ponto_seguro_pronto = true
	return to_global(_ponto_seguro_local)


## Aquele ponto GLOBAL comporta um corpo de raio `folga` sem entrar em parede
## nem em obstaculo? E o teste que falta a quem sorteia posicao (spawn de
## inimigo, pickup) para nao largar nada atras da parede.
func posicao_livre(ponto_global: Vector2, folga: float = FOLGA_CORPO) -> bool:
	var contorno := _pontos_do_contorno()
	if contorno.size() < 3:
		return true
	return _local_livre(to_local(ponto_global), contorno, folga)


## Idempotente de proposito: reentrar numa sala ja limpa nao pode recomecar o
## combate dela. Isso ja custou uma sessao inteira de playtest aqui.
##
## E aqui, e nao no _ready, que se decide se a sala tem combate: a composicao
## chega depois do add_child, entao no _ready a sala ainda nao sabe. Composicao
## vazia vira LIMPA na chegada, que e o mesmo comportamento que a sala de
## recompensa sempre teve.
func ativar() -> void:
	if estado == Estado.LIMPA:
		EventBus.sala_entrada.emit(self)
		_anunciar_limpa()
		return

	EventBus.sala_entrada.emit(self)

	if _composicao.is_empty():
		_limpar()
		return

	estado = Estado.OCUPADA
	_trancar_portas()
	_povoar()


func _mapear_portas() -> void:
	_portas_por_direcao.clear()
	_raiz_portas = get_node_or_null("Portas") as Node2D
	if _raiz_portas == null:
		return
	for filho in _raiz_portas.get_children():
		var porta := filho as Porta
		if porta != null:
			_portas_por_direcao[porta.vetor()] = porta


func _selar_portas_sem_vizinho() -> void:
	if not _conexoes_definidas:
		return
	for direcao in _portas_por_direcao:
		var porta := _portas_por_direcao[direcao] as Porta
		if not _conexoes.has(direcao):
			porta.selar()


## Coloca a composicao inteira de uma vez, no frame da entrada.
##
## Nao ha sequencia nem marcador de telegrafo. Telegrafo existe para o que
## aparece com o jogador ja dentro; aqui nada aparece depois -- ele entra e ja
## ve a sala como ela e.
##
## A composicao e consumida ao ser usada: se a sala for reativada por algum
## caminho, ela nao repovoa.
func _povoar() -> void:
	var cenas := _composicao
	_composicao = []

	var container := _container_de_inimigos()
	for cena in cenas:
		if cena == null:
			continue
		var inimigo := cena.instantiate() as Node2D
		if inimigo == null:
			continue
		# add_child ANTES de global_position: fora da arvore o setter cai no
		# position local e o pai reaplica a propria transform por cima, o que
		# desloca o spawn pelo offset da sala dentro do andar.
		container.add_child(inimigo)
		inimigo.global_position = _sortear_posicao()
		_vivos.append(inimigo)
		if inimigo.has_signal("morreu"):
			inimigo.morreu.connect(_ao_morrer_inimigo)

	EventBus.contagem_inimigos_mudou.emit(_contar_vivos())

	# Composicao que nao produziu ninguem (cena quebrada, array de nulos) nao
	# pode deixar a sala trancada para sempre.
	if _vivos.is_empty():
		_limpar()


## O container e criado quando a cena nao traz um. Assim uma sala nova serve
## para combate sem que quem a desenhou precise lembrar de um no de
## infraestrutura -- e a Diretora continua achando o container por get_parent(),
## como sempre fez.
func _container_de_inimigos() -> Node2D:
	if _container != null and is_instance_valid(_container):
		return _container
	_container = get_node_or_null("ContainerInimigos") as Node2D
	if _container == null:
		_container = Node2D.new()
		_container.name = "ContainerInimigos"
		add_child(_container)
	# Ligado aqui e nao no .tscn de proposito: metade das salas traz o
	# container da cena e metade o cria em codigo, e um elo solto num dos dois
	# caminhos deixaria os inimigos daquelas salas fora do Y-sort em silencio.
	_container.y_sort_enabled = true
	return _container


func _ao_morrer_inimigo(_posicao: Vector2) -> void:
	# O no ainda nao saiu da arvore neste frame; espera um quadro para contar.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var restantes := _contar_vivos()
	EventBus.contagem_inimigos_mudou.emit(restantes)
	if restantes == 0:
		_limpar()


## Poda e conta numa passada so.
##
## So conta quem a SALA colocou. Os invocados da Diretora nascem no mesmo
## container mas nao entram nesta lista, e e isso que preserva o contrato
## antigo: a sala do chefe fecha pela morte dele e por mais nada. Fosse
## contagem do container, um invocado sobrevivente seguraria a vitoria.
##
## Nota: Array.filter() devolve Array sem tipo, o que quebra a atribuicao de
## volta num Array[Node] tipado. Loop explicito e o caminho seguro em GDScript.
func _contar_vivos() -> int:
	var restantes: Array[Node] = []
	for n in _vivos:
		if is_instance_valid(n):
			restantes.append(n)
	_vivos = restantes
	return _vivos.size()


func _limpar() -> void:
	if estado == Estado.LIMPA:
		return
	estado = Estado.LIMPA
	_abrir_portas()
	_anunciar_limpa()


## Sorteia um ponto util longe do jogador e livre de parede e obstaculo, ja em
## coordenadas GLOBAIS.
##
## Duas armadilhas moram aqui, e as duas ja custaram tempo:
##
## 1. A conversao para global vem ANTES de medir a distancia. Comparar um ponto
##    local com a global_position do jogador mede espacos diferentes, e a
##    garantia de "nao nasce na cara dele" so valia por acidente na sala que
##    estivesse na origem do mundo.
## 2. Distancia do jogador nao basta. O sorteio antigo nao olhava geometria, e
##    nada impedia um inimigo de nascer dentro do pilar da sala 5 ou fora do
##    braco do L. posicao_livre() ja existia aqui e nao era usado.
##
## Nunca trava num loop: tenta um numero fixo de vezes e, se nada perfeito
## aparecer, aceita o melhor candidato livre; em ultimo caso, o ponto seguro da
## propria sala, que e o mesmo lugar onde o jogador nasceria.
func _sortear_posicao() -> Vector2:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var melhor := Vector2.ZERO
	var melhor_dist := -1.0

	for _tentativa in TENTATIVAS_DE_SPAWN:
		var ponto := to_global(Vector2(
			randf_range(area_spawn.position.x, area_spawn.end.x),
			randf_range(area_spawn.position.y, area_spawn.end.y)
		))
		if not posicao_livre(ponto, FOLGA_SPAWN):
			continue
		if player == null or not is_instance_valid(player):
			return ponto
		var d := ponto.distance_to(player.global_position)
		if d >= distancia_minima_player:
			return ponto
		if d > melhor_dist:
			melhor_dist = d
			melhor = ponto

	if melhor_dist >= 0.0:
		return melhor
	return ponto_seguro()


## Uma sala so conta como limpa uma vez. Quem escuta sala_limpa incrementa
## contador, entao reemitir ao reentrar inflaria a estatistica da run.
func _anunciar_limpa() -> void:
	if _anunciou_limpa:
		return
	_anunciou_limpa = true
	EventBus.sala_limpa.emit(self)


func _trancar_portas() -> void:
	for direcao in _portas_por_direcao:
		var porta := _portas_por_direcao[direcao] as Porta
		if not porta.esta_selada():
			porta.trancar()


func _abrir_portas() -> void:
	for direcao in _portas_por_direcao:
		var porta := _portas_por_direcao[direcao] as Porta
		if not porta.esta_selada():
			porta.abrir()


## Contorno da sala em coordenadas LOCAIS, para quem precisa da silhueta e nao
## so do bounding box -- o minimapa desenha a forma real, entao um Rect2 nao
## serve: a sala em L viraria um quadrado.
##
## O ultimo ponto do Line2D repete o primeiro para fechar o desenho. Aqui ele e
## removido, porque quem consome poligono (Geometry2D, draw_colored_polygon)
## trata o fechamento sozinho e engasga com o ponto duplicado.
func contorno_local() -> PackedVector2Array:
	var pontos := _pontos_do_contorno()
	if pontos.size() >= 2 and pontos[0].is_equal_approx(pontos[pontos.size() - 1]):
		pontos.remove_at(pontos.size() - 1)
	return pontos


## Pontos do contorno em coordenadas locais da sala. O Line2D pode ter offset
## proprio, entao a transform dele entra na conta.
func _pontos_do_contorno() -> PackedVector2Array:
	var parede := get_node_or_null("Parede") as Line2D
	if parede == null:
		return PackedVector2Array()
	var pontos := PackedVector2Array()
	for ponto in parede.points:
		pontos.append(parede.transform * ponto)
	return pontos


## Varredura determinista em coordenadas locais. O centro do bounding box e
## testado primeiro porque, quando ele serve, e o enquadramento que quem montou
## a sala espera; so quando ele cai em solido a grade entra, e entre os pontos
## validos vence o mais proximo desse centro -- assim a sala em L larga o
## jogador no braco, nao numa quina distante.
func _procurar_ponto_seguro() -> Vector2:
	var contorno := _pontos_do_contorno()
	if contorno.size() < 3:
		return Vector2.ZERO

	var caixa := Rect2(contorno[0], Vector2.ZERO)
	for i in range(1, contorno.size()):
		caixa = caixa.expand(contorno[i])

	var centro := caixa.get_center()
	if _local_livre(centro, contorno, FOLGA_CORPO):
		return centro

	var melhor := centro
	var melhor_distancia := INF
	var x := caixa.position.x
	while x <= caixa.end.x:
		var y := caixa.position.y
		while y <= caixa.end.y:
			var candidato := Vector2(x, y)
			var distancia := candidato.distance_squared_to(centro)
			if distancia < melhor_distancia and _local_livre(candidato, contorno, FOLGA_CORPO):
				melhor_distancia = distancia
				melhor = candidato
			y += PASSO_VARREDURA
		x += PASSO_VARREDURA

	if melhor_distancia == INF:
		push_warning("Sala '%s': nenhum ponto livre para o jogador; caindo no centro." % name)
	return melhor


func _local_livre(ponto: Vector2, contorno: PackedVector2Array, folga: float) -> bool:
	if not Geometry2D.is_point_in_polygon(ponto, contorno):
		return false
	# Dentro do contorno ainda pode ser em cima da parede: o teste de poligono
	# aceita o ponto colado na linha, e ali o corpo do jogador ja atravessa.
	for i in range(contorno.size() - 1):
		var perto := Geometry2D.get_closest_point_to_segment(ponto, contorno[i], contorno[i + 1])
		if perto.distance_to(ponto) < folga:
			return false
	return not _dentro_de_obstaculo(ponto, folga)


## Usa a propria forma de colisao do obstaculo contra um disco do tamanho do
## corpo: assim vale para retangulo, circulo ou poligono sem um caso por tipo.
func _dentro_de_obstaculo(ponto: Vector2, folga: float) -> bool:
	var raiz := get_node_or_null("Obstaculos")
	if raiz == null:
		return false
	var corpo := CircleShape2D.new()
	corpo.radius = folga
	var onde_o_corpo_esta := Transform2D(0.0, ponto)
	for forma in _formas_de(raiz):
		if forma.shape == null or forma.disabled:
			continue
		if forma.shape.collide(_transform_relativa(forma), corpo, onde_o_corpo_esta):
			return true
	return false


## Transform do no medida a partir DESTA sala, subindo a cadeia. Nao usa
## global_transform de proposito: assim a conta tambem vale para a instancia que
## o gerenciador cria fora da arvore so para ler o catalogo de formas.
func _transform_relativa(no: Node2D) -> Transform2D:
	var acumulada := Transform2D.IDENTITY
	var atual: Node2D = no
	while atual != null and atual != self:
		acumulada = atual.transform * acumulada
		atual = atual.get_parent() as Node2D
	return acumulada


func _formas_de(raiz: Node) -> Array[CollisionShape2D]:
	var lista: Array[CollisionShape2D] = []
	for filho in raiz.get_children():
		var forma := filho as CollisionShape2D
		if forma != null:
			lista.append(forma)
		lista.append_array(_formas_de(filho))
	return lista


func _montar_paredes() -> void:
	var pontos := _pontos_do_contorno()
	if pontos.size() < 2:
		return

	var corpo := StaticBody2D.new()
	corpo.name = "Paredes"
	corpo.collision_layer = LAYER_PAREDE
	corpo.collision_mask = 0
	add_child(corpo)

	for i in range(pontos.size() - 1):
		for trecho in _subtrechos(pontos[i], pontos[i + 1]):
			_adicionar_forma(corpo, trecho[0], trecho[1])


## Um lado do contorno vira um ou mais trechos, dependendo de quantas portas
## abrem vao nele. Cada trecho e um par (inicio, fim). E a lista da COLISAO: o
## solido segue a parede fisica e para no vao da porta, em vez de atravessa-lo.
func _subtrechos(inicio: Vector2, fim: Vector2) -> Array[PackedVector2Array]:
	var trechos: Array[PackedVector2Array] = []
	var comprimento := inicio.distance_to(fim)
	if comprimento <= COMPRIMENTO_MINIMO:
		return trechos
	var direcao := (fim - inicio) / comprimento

	var vaos := _vaos_no_trecho(inicio, direcao, comprimento)
	vaos.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

	var cursor := 0.0
	for vao in vaos:
		var borda := clampf(vao.x, 0.0, comprimento)
		if borda - cursor > COMPRIMENTO_MINIMO:
			trechos.append(PackedVector2Array([inicio + direcao * cursor, inicio + direcao * borda]))
		cursor = maxf(cursor, clampf(vao.y, 0.0, comprimento))

	if comprimento - cursor > COMPRIMENTO_MINIMO:
		trechos.append(PackedVector2Array([inicio + direcao * cursor, fim]))
	return trechos


## Intervalos (inicio, fim) medidos ao longo do trecho onde a parede nao existe.
## Porta selada nao entra na lista: a parede passa reta por cima dela.
func _vaos_no_trecho(inicio: Vector2, direcao: Vector2, comprimento: float) -> Array[Vector2]:
	var vaos: Array[Vector2] = []
	for chave in _portas_por_direcao:
		var porta := _portas_por_direcao[chave] as Porta
		if porta.esta_selada():
			continue
		var ponto: Vector2 = _raiz_portas.transform * porta.position
		var avanco := (ponto - inicio).dot(direcao)
		if avanco < -TOLERANCIA_ENCAIXE or avanco > comprimento + TOLERANCIA_ENCAIXE:
			continue
		var mais_proximo := inicio + direcao * clampf(avanco, 0.0, comprimento)
		if ponto.distance_to(mais_proximo) > TOLERANCIA_ENCAIXE:
			continue
		var meia := Porta.LARGURA * 0.5
		vaos.append(Vector2(avanco - meia, avanco + meia))
	return vaos


func _adicionar_forma(corpo: StaticBody2D, de: Vector2, para: Vector2) -> void:
	var segmento := SegmentShape2D.new()
	segmento.a = de
	segmento.b = para
	var forma := CollisionShape2D.new()
	forma.shape = segmento
	corpo.add_child(forma)


# ---------------------------------------------------------------- visual -----

## Monta as camadas visuais a partir do contorno, cada uma na sua faixa de z.
##
## Antes as camadas geradas precisavam entrar no INICIO da lista de filhos:
## chao e moldura da porta empatavam em z = -1, e nos com o mesmo z desenham na
## ordem dos filhos. Era uma dependencia frouxa -- bastava alguem chamar
## add_child depois para a moldura sumir atras do chao, sem erro nenhum.
## Com as faixas separadas (chao -20, moldura -1) a moldura fica por cima por
## construcao, e os move_child sairam.
func _montar_visual() -> void:
	var contorno := contorno_local()
	if contorno.size() < 3:
		return
	var ancora := _caixa_de(contorno).position
	var textura_chao := _textura(&"chao")
	var textura_parede := _textura(&"parede")

	var topo := Polygon2D.new()
	topo.name = "ParedeTopo"
	topo.polygon = _inflar(contorno, ESPESSURA_PAREDE)
	topo.z_index = Z_PAREDE_TOPO
	_texturizar(topo, textura_parede, ancora)
	add_child(topo)

	var chao := Polygon2D.new()
	chao.name = "Chao"
	chao.polygon = contorno
	chao.z_index = Z_CHAO
	_texturizar(chao, textura_chao, ancora)
	add_child(chao)

	_montar_faces(contorno, ancora)
	_montar_obstaculos_visuais(textura_parede, ancora)

	# O Line2D "Parede" do .tscn nunca aparece em jogo: ele e a fonte da
	# geometria -- colisao, camera, minimapa e o corpo acima leem os `points`
	# dele -- e o que o editor mostra para quem desenha a sala. Desenha-lo
	# atravessaria o vao das portas, porque os pontos nao podem ser mexidos sem
	# mexer na colisao. Quem esconde e esta linha; antes era o _montar_filete,
	# que ja nao existe.
	var linha_fonte := get_node_or_null("Parede") as Line2D
	if linha_fonte != null:
		linha_fonte.visible = false


## A FACE vertical da parede: a metade interna da faixa, so nos lados voltados
## para o sul. E ela que da altura ao cenario, e sem ela a parede volta a ler
## como faixa chapada.
##
## Desenhada para FORA do contorno, nunca para dentro: a linha do contorno
## continua sendo a base da parede e a colisao (LOW_TOPDOWN_SQUARED secao 21), e
## nenhum pixel de area jogavel e perdido. Face para dentro comeria espaco de
## combate e mudaria o balanceamento de todas as salas de uma vez.
##
## Um quad por lado, e nao um anel: `offset_polygon` nao sabe inflar um lado so,
## e sao justamente os lados que tem orientacoes diferentes. O topo continua
## vindo do contorno inflado, que ja resolve quina e concavidade -- este passo
## so pinta por cima da metade que a camera ve de frente.
func _montar_faces(contorno: PackedVector2Array, ancora: Vector2) -> void:
	if contorno.size() < 3:
		return
	var textura := load("res://assets/texturas/parede_face.png") as Texture2D
	if textura == null:
		# Sem face o jogo continua jogavel, so volta a parecer chapado. Avisar
		# importa porque nenhuma suite instancia a sala com textura em disco.
		push_warning("Sala '%s': parede_face.png nao carregou; parede sem volume." % name)
		return

	var raiz := Node2D.new()
	raiz.name = "ParedeFace"
	raiz.z_index = Z_PAREDE_FACE
	add_child(raiz)

	for i in contorno.size():
		var a := contorno[i]
		var b := contorno[(i + 1) % contorno.size()]
		var normal := _normal_externa(contorno, a, b)
		if normal.y > LIMIAR_LADO_NORTE:
			continue
		var recuo := normal * ALTURA_FACE
		var quad := Polygon2D.new()
		quad.polygon = PackedVector2Array([a, b, b + recuo, a + recuo])
		_texturizar(quad, textura, ancora)
		raiz.add_child(quad)


## Normal para FORA de um lado do contorno.
##
## Testada contra o poligono em vez de deduzida do sentido de giro: o Line2D de
## cada sala foi desenhado a mao e nada garante que todas girem no mesmo
## sentido. `_inflar()` ja convive com isso tentando os dois offsets; aqui o
## equivalente e perguntar de que lado esta o lado de fora.
func _normal_externa(contorno: PackedVector2Array, a: Vector2, b: Vector2) -> Vector2:
	var direcao := (b - a).normalized()
	if direcao == Vector2.ZERO:
		return Vector2.ZERO
	var candidata := Vector2(direcao.y, -direcao.x)
	var meio := (a + b) * 0.5
	# Um passo curto: perto o bastante da aresta para nao atravessar a sala
	# inteira num contorno estreito, longo o bastante para sair da linha.
	if Geometry2D.is_point_in_polygon(meio + candidata * 4.0, contorno):
		return -candidata
	return candidata


## Obstaculo solido (o pilar) recebe o mesmo corpo de parede, lido da forma de
## colisao: sem isso ele seria o unico solido sem textura da sala. So retangulo
## por enquanto -- e o unico que existe.
##
## Ele perdeu a borda de neon junto com a parede. Manter so a do pilar deixaria
## o unico objeto brilhante da sala sendo o obstaculo, o que le como "isto e
## interativo" -- e ele e so um bloco.
func _montar_obstaculos_visuais(textura_parede: Texture2D, ancora: Vector2) -> void:
	var raiz := get_node_or_null("Obstaculos")
	if raiz == null:
		return
	for forma in _formas_de(raiz):
		var retangulo := forma.shape as RectangleShape2D
		if retangulo == null or forma.disabled:
			continue
		var tr := _transform_relativa(forma)
		var meia := retangulo.size * 0.5
		var pontos := PackedVector2Array([
			tr * Vector2(-meia.x, -meia.y),
			tr * Vector2(meia.x, -meia.y),
			tr * Vector2(meia.x, meia.y),
			tr * Vector2(-meia.x, meia.y),
		])

		var bloco := Polygon2D.new()
		bloco.name = "ObstaculoCorpo"
		bloco.polygon = pontos
		bloco.z_index = Z_PAREDE_FACE
		_texturizar(bloco, textura_parede, ancora)
		add_child(bloco)


## Textura repetida com UV em pixels, ancorada no canto do contorno. As duas
## armadilhas previstas moram aqui: sem texture_repeat a textura aparece UMA
## vez esticada no tamanho da sala (o default do projeto e Disabled); ancorada
## no centro, o tile sai cortado ao meio nas bordas norte e sul, porque a meia
## altura da sala padrao (272) nao e multipla de 32.
func _texturizar(poligono: Polygon2D, textura: Texture2D, ancora: Vector2) -> void:
	if textura == null:
		poligono.color = COR_CHAO_EMERGENCIA
		return
	poligono.texture = textura
	poligono.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	poligono.color = Color.WHITE
	var uv := PackedVector2Array()
	for ponto in poligono.polygon:
		uv.append(ponto - ancora)
	poligono.uv = uv


## Contorno inflado para fora. offset_polygon com JOIN_MITER e seguro porque
## todo contorno do projeto e retilineo (so 90 e 270 graus), e o resultado
## certo e o que ENVOLVE a caixa original -- a checagem existe porque a
## direcao do offset depende da orientacao do poligono, e o Line2D pode ter
## sido desenhado em qualquer sentido.
func _inflar(contorno: PackedVector2Array, quanto: float) -> PackedVector2Array:
	var caixa := _caixa_de(contorno)
	for delta: float in [quanto, -quanto]:
		for candidato in Geometry2D.offset_polygon(contorno, delta, Geometry2D.JOIN_MITER):
			if candidato.size() >= 3 and _caixa_de(candidato).encloses(caixa.grow(quanto * 0.5)):
				return candidato
	push_warning("Sala '%s': nao consegui inflar o contorno; parede sem corpo." % name)
	return contorno


func _caixa_de(pontos: PackedVector2Array) -> Rect2:
	if pontos.is_empty():
		return Rect2()
	var caixa := Rect2(pontos[0], Vector2.ZERO)
	for i in range(1, pontos.size()):
		caixa = caixa.expand(pontos[i])
	return caixa


## A textura desta familia PARA ESTA SALA.
##
## A variante sai de `hash(coordenadas_grid)`, e o momento em que isso funciona
## nao e obvio: `coordenadas_grid` e escrito pelo GerenciadorMapa ANTES do
## `add_child`, e portanto ja vale quando o `_ready` chama `_montar_visual()`.
## E o mesmo pre-requisito que `_montar_decoracao()` explora.
##
## Sala aberta sozinha no editor, e a amostra que `_montar_catalogo()` instancia
## para medir portas, chegam aqui com celula (0,0) e sem dados -- as duas caem no
## fallback, que e o comportamento certo e nao um caso a tratar.
func _textura(familia: StringName) -> Texture2D:
	var textura: Texture2D = null
	if _dados_visual != null:
		var semente := hash(coordenadas_grid)
		match familia:
			&"chao":
				textura = _dados_visual.textura_de(_dados_visual.texturas_chao, semente)
			&"parede":
				# Desloca a semente para chao e parede nao andarem juntos: com a
				# mesma semente, a sala que pega o chao 2 pegaria sempre a parede
				# 2, e quatro combinacoes possiveis virariam quatro de fato em vez
				# das dezesseis que as listas oferecem.
				textura = _dados_visual.textura_de(_dados_visual.texturas_parede, semente ^ 0x5bf03635)
	if textura == null:
		textura = load(TEXTURA_PADRAO % familia) as Texture2D
	return textura


# ------------------------------------------------------------- decoracao -----

## Props sem colisao na margem entre a parede e a area de spawn. A seed vem
## das coordenadas da celula: reentrar na sala mostra a mesma sala, e um teste
## consegue reproduzir. Sem dados nao ha props -- e o tipo que diz o que cabe.
func _montar_decoracao() -> void:
	var dados := _dados_visual
	if dados == null or dados.atlas_props == null or dados.regioes_props.is_empty() or dados.quantidade_props <= 0:
		return
	var contorno := _pontos_do_contorno()
	if contorno.size() < 4:
		return
	var aberto := contorno_local()

	var raiz := Node2D.new()
	raiz.name = "Decoracao"
	raiz.z_index = Z_CHAO_DETALHE
	add_child(raiz)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(coordenadas_grid)
	var bocas := _bocas_locais()
	var colocados: Array[Vector2] = []

	for _i in dados.quantidade_props:
		for _tentativa in PROP_TENTATIVAS:
			var ponto := _sortear_ponto_de_prop(rng, contorno, aberto)
			if ponto == Vector2.INF:
				continue
			if not _cabe_prop(ponto, aberto, bocas, colocados):
				continue
			var sprite := Sprite2D.new()
			sprite.texture = dados.atlas_props
			sprite.region_enabled = true
			sprite.region_rect = Rect2(dados.regioes_props[rng.randi_range(0, dados.regioes_props.size() - 1)])
			sprite.flip_h = rng.randf() < 0.5
			sprite.position = ponto
			raiz.add_child(sprite)
			colocados.append(ponto)
			break


## Um ponto encostado num lado do contorno, para DENTRO. O lado e sorteado com
## peso pelo comprimento, senao o braco curto do L recebe tanto quanto a parede
## longa. Vector2.INF quando o sorteio nao serviu.
func _sortear_ponto_de_prop(rng: RandomNumberGenerator, contorno: PackedVector2Array, aberto: PackedVector2Array) -> Vector2:
	var perimetro := 0.0
	for i in range(contorno.size() - 1):
		perimetro += contorno[i].distance_to(contorno[i + 1])
	var alvo := rng.randf() * perimetro
	for i in range(contorno.size() - 1):
		var a := contorno[i]
		var b := contorno[i + 1]
		var comprimento := a.distance_to(b)
		if alvo > comprimento:
			alvo -= comprimento
			continue
		if comprimento < PROP_LADO * 2.0:
			return Vector2.INF
		var direcao := (b - a) / comprimento
		var normal := Vector2(-direcao.y, direcao.x)
		var ao_longo := clampf(alvo, PROP_LADO, comprimento - PROP_LADO)
		var afastamento := rng.randf_range(PROP_AFASTAMENTO_MINIMO, PROP_AFASTAMENTO_MAXIMO)
		var base := a + direcao * ao_longo
		var ponto := base + normal * afastamento
		if not Geometry2D.is_point_in_polygon(ponto, aberto):
			ponto = base - normal * afastamento
		if not Geometry2D.is_point_in_polygon(ponto, aberto):
			return Vector2.INF
		return (ponto / PROP_GRADE).round() * PROP_GRADE
	return Vector2.INF


func _cabe_prop(ponto: Vector2, aberto: PackedVector2Array, bocas: Array[Vector2], colocados: Array[Vector2]) -> bool:
	# Dentro do contorno com folga de meio prop, e fora de qualquer obstaculo.
	if not _local_livre(ponto, aberto, PROP_LADO * 0.5 + 8.0):
		return false
	# Fora da area util: prop no meio do chao, sem colisao, e obstaculo mentiroso.
	if area_spawn.intersects(Rect2(ponto - Vector2.ONE * PROP_LADO * 0.5, Vector2.ONE * PROP_LADO)):
		return false
	for boca in bocas:
		if boca.distance_to(ponto) < PROP_DISTANCIA_DE_PORTA:
			return false
	for outro in colocados:
		if outro.distance_to(ponto) < PROP_ESPACO:
			return false
	return true


## Posicao LOCAL de todas as portas, seladas inclusive: prop encostado numa
## porta selada tambem parece que tapa alguma coisa.
func _bocas_locais() -> Array[Vector2]:
	var lista: Array[Vector2] = []
	if _raiz_portas == null:
		return lista
	for chave in _portas_por_direcao:
		var porta := _portas_por_direcao[chave] as Porta
		lista.append(_raiz_portas.transform * porta.position)
	return lista
