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
##
## DIVIDA que este numero criou, anotada aqui porque e aqui que alguem vai
## procurar: a camera folga exatamente `ESPESSURA_PAREDE` alem do contorno, e
## com 64 uma sala do tamanho exato da tela passou a deslizar 64 px por eixo --
## com o jogador no centro, nenhuma parede aparece. O conserto e geometrico
## (sala de 832x416), nao por margem, e a Fase 25 do plano de migracao proibe
## mexer em tamanho de sala enquanto a migracao acontece. A conta inteira esta
## em `GerenciadorMapa.margem_da_parede()`.
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
## Reservada, e hoje VAZIA: a fita de modulos desenha acima do chao.
##
## O topo da parede era um poligono nesta faixa, ATRAS do chao, e quem recortava
## a faixa visivel era o chao por cima -- o truque que fazia a sala em L
## funcionar sem calcular anel com furo. A fita nao precisa dele: toda celula
## mora na faixa, do contorno para fora, e nenhuma toca area jogavel.
##
## A constante fica porque o espacamento entre as faixas e o que permite
## acrescentar uma camada sem renumerar as outras -- e renumerar e o que quebra
## ordem sem erro no console.
const Z_PAREDE_TOPO := -22
const Z_CHAO := -20
## A sombra que a parede projeta no chao (TOPO 02).
##
## Entre o chao e o detalhe de chao, e os dois lados importam: ela tem de
## ESCURECER o piso, entao fica acima dele; e decalque, prop chapado, telegrafo,
## projetil e ator tem de ler POR CIMA dela, entao fica abaixo de todo o resto.
## Efeito que disputa a leitura de combate e efeito cortado, e aqui isso e
## geometria e nao promessa.
##
## Ela coube sem renumerar nada -- e exatamente para isto que as faixas nascem
## espacadas de 2.
const Z_SOMBRA_PAREDE := -19
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
## A face NEUTRA, usada quando o tipo nao declara modulo nenhum -- e tambem pela
## cena aberta sozinha no editor, que nao tem DadosSala. Ela e o modulo
## "simples" da biblioteca: paineis metalicos antigos, sem tubo nem escotilha.
const FACE_NEUTRA := "res://assets/texturas/parede_face.png"

## O TOPO da parede, e ele e o mesmo em todo tipo de sala.
##
## A identidade do tipo mora na FACE desde a LTD 13 (#43), e esta lista e a
## segunda metade daquela issue: enquanto ela nao existia, o topo continuava
## vestido com as `parede_*.png` por tipo -- arte de antes da identidade, com
## saturacao de 0,75 a 0,93 e duas das quatro fora da faixa de densidade da
## familia.
##
## Compartilhada e nao copiada nos cinco `tipo_*.tres`: cinco copias da mesma
## lista divergem no dia em que alguem mudar quatro. Se um tipo um dia precisar
## de topo proprio, isso e uma decisao nova e nao um campo esperando.
## Valvula de FERRAMENTA: o perfil que a matriz de comparacao quer usar.
##
## Ela existe porque a sala monta a fita no proprio `_ready`, e nao ha janela
## entre instanciar e desenhar para passar um parametro. Fica `static` e NULA em
## jogo -- quem manda no perfil em runtime e o `EstiloDeParede`, como todo botao
## de tuning do projeto.
static var perfil_de_teste: PerfilDeParede = null

## O SUBTEMA desta sala: que parte da fabrica ela era.
##
## Recebido antes do `add_child`, como `definir_visual()` e
## `configurar_conexoes()`, porque e o `_ready` que monta as camadas. Fica
## `null` quando ninguem define -- sala aberta sozinha no editor, suite que monta
## sala sem gerenciador --, e nesse caso a face sai do sorteio de sempre.
var _tema: TemaDeSala = null

## Valvula de FERRAMENTA: desenha a fita em cor chapada, sem textura nenhuma.
##
## E o teste que separa duas hipoteses que custam muito diferente. Se em
## silhueta a faixa AINDA parecer um bloco, o problema e GEOMETRICO e nao
## adianta arte nova -- textura melhor so deixa o bloco mais bonito. Se em
## silhueta ficar bom, o problema e de material, e a resposta e a chapa e as
## bandas.
##
## Ela mora aqui pela mesma razao que `perfil_de_teste`: a sala monta a fita no
## proprio `_ready`, e nao ha janela entre instanciar e desenhar.
static var silhueta_de_teste: bool = false

const TOPOS_NEUTROS: Array[String] = [
	"res://assets/texturas/parede_topo_a.png",
	"res://assets/texturas/parede_topo_b.png",
	"res://assets/texturas/parede_topo_c.png",
]
## Cor de emergencia do chao quando a textura nao carrega: o N1 da paleta, que
## e o chao que o jogo sempre teve. Sala invisivel seria pior que sala lisa.
const COR_CHAO_EMERGENCIA := Color("0b0d16")

## O VAZIO ALEM DA SALA, e ele e uma decisao e nao um ajuste de viewport.
##
## O §5 do plano de profundidade pede uma camada de exterior atras de toda a
## arquitetura: sem ela a parede perde profundidade, porque nao ha contraste
## entre "mundo jogavel", "arquitetura" e "nada alem da sala".
##
## Ela JA EXISTE, e por acidente feliz: o `default_clear_color` do
## `project.godot` e este mesmo N0. O que faltava era ela ser DECLARADA aqui,
## onde quem le a sala a encontra -- e nao so numa linha de configuracao de
## render, que a proxima pessoa pode mudar por um motivo que nada tem a ver com
## sala (um menu, uma transicao) e apagar a moldura inteira sem tocar em
## `src/mapa/`.
##
## `teste_profundidade.gd` cobra que as duas continuem iguais. Nao ha nó de
## exterior porque nao e preciso: o clear color ja desenha atras de tudo, e um nó
## seria uma segunda fonte da mesma verdade.
const COR_DO_VAZIO := Color("05060b")
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
## Quanto da largura da celula a sombra de um prop volumetrico ocupa. Menor que
## 1 porque a arte nunca preenche a celula inteira -- ela e ancorada na base e
## centrada, com vazio nas laterais. Sombra do tamanho da celula apareceria
## saindo de baixo do prop pelos dois lados.
const PROP_FRACAO_SOMBRA := 0.72

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

## Quao fundo no andar esta sala fica: 0.0 na entrada, 1.0 na mais distante.
##
## Escrito pelo GerenciadorMapa ANTES do add_child, como `coordenadas_grid` --
## e o `_ready` que monta o visual, e ele precisa do numero ja valendo.
##
## Sala montada sozinha (editor, suite, amostra do catalogo de portas) fica em
## 0.0 e veste a variante mais conservada. E o default certo: sem andar, nao ha
## progressao a mostrar.
##
## Ele NAO e a Deterioracao. A barra e estado de runtime e vale zero na hora em
## que o andar e montado -- ler ela aqui daria o andar inteiro conservado, para
## sempre e sem erro nenhum. E a mesma armadilha que a porta por Deterioracao do
## GrupoInimigo ja documenta.
var fracao_do_andar: float = 0.0

## O tipo que veste esta sala. Nulo = variante neutra, sem props.
var _dados_visual: DadosSala = null
## Esta sala pode sortear os props raros? Escrito pelo `GerenciadorMapa` ANTES
## do `add_child`, como `coordenadas_grid` -- e o `_ready` que monta a decoracao,
## e depois dele o dado ja nao muda nada.
var _props_raros := false


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


## O SUBTEMA da sala, e ele roda ANTES do `add_child` como os outros dois.
##
## Nao ha janela depois disso: o `_ready` sela portas, monta a fita e escolhe a
## face. Um tema definido depois seria guardado e nunca desenhado -- sem erro no
## console, que e o modo de falha que `definir_visual()` ja documenta.
func definir_tema(tema: TemaDeSala) -> void:
	_tema = tema


## O tema desta sala, ou `null`. Publico porque o portao e o minimapa perguntam.
func tema() -> TemaDeSala:
	return _tema


## Chamado ANTES de add_child, como configurar_conexoes: e o _ready que monta
## as camadas, e ele precisa saber de que tipo a sala e para escolher textura.
## Aceita nulo de proposito -- a cena aberta sozinha no editor nao tem dados e
## nao pode explodir.
func definir_visual(dados: DadosSala) -> void:
	_dados_visual = dados


## Marca esta sala como a UNICA do andar que pode receber prop raro.
##
## Antes do `add_child`, pela mesma razao de `definir_visual`. Quem escolhe e o
## `GerenciadorMapa`: "um por andar" nao e uma pergunta que a sala consiga
## responder olhando so para si mesma.
func permitir_props_raros() -> void:
	_props_raros = true


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
##
## **E aqui que o CHANFRO entra, e por isso ele nao esta em cena nenhuma.** A
## dimensao logica da sala continua sendo o retangulo desenhado no `.tscn` --
## multipla de 32, com as portas na grade de 16, medida por `teste_grade.gd` --,
## e o chanfro e derivado dela em codigo. Desenha-lo nas nove cenas transformaria
## uma decisao de ARQUITETURA num numero copiado nove vezes, que diverge no dia
## em que alguem mudar oito.
##
## Como todo o resto sai daqui -- chao, colisao, fita, sombra, minimapa --, o
## chanfro chega inteiro a todos eles de uma vez. Era o requisito: "o chanfrado
## deve existir na geometria do poligono do piso E nas faixas de parede, para a
## sombra, a face e o cap acompanharem exatamente a mesma diagonal".
func _pontos_do_contorno() -> PackedVector2Array:
	var parede := get_node_or_null("Parede") as Line2D
	if parede == null:
		return PackedVector2Array()
	var pontos := PackedVector2Array()
	for ponto in parede.points:
		pontos.append(parede.transform * ponto)
	return _chanfrar(pontos)


## Recua cada quina do contorno na diagonal.
##
## Uma quina de 90 graus comunica planta baixa; a diagonal comunica que a
## superficie converge para o piso. Ela vale para as quinas CONCAVAS tambem -- na
## sala em L o corte tambem existe, e sem ele o unico canto interno do jogo
## continuaria em esquadro.
##
## **O corte e limitado pelo lado mais curto**, e a trava nao e teorica: sem ela
## um lado de 64 px com 48 de corte em cada ponta viraria um lado de -32, e o
## poligono se dobra sobre si mesmo -- `Geometry2D.triangulate_polygon` devolve
## vazio e a sala fica sem chao, sem uma linha no console.
##
## E ele desce para o multiplo de 16 mais proximo, porque `teste_grade.gd` cobra
## todo ponto do contorno na grade -- inclusive os que este metodo inventa.
func _chanfrar(pontos: PackedVector2Array) -> PackedVector2Array:
	var fechado := pontos.size() >= 2 and pontos[0].is_equal_approx(pontos[pontos.size() - 1])
	var abertos := pontos
	if fechado:
		abertos = pontos.slice(0, pontos.size() - 1)
	var total := abertos.size()
	if total < 3:
		return pontos

	var perfil := _perfil()
	var quanto: float = perfil.chanfro_de_canto if perfil != null \
		else PerfilDeParede.new().chanfro_de_canto
	if quanto < 16.0:
		return pontos

	var saida := PackedVector2Array()
	for i in total:
		var v := abertos[i]
		var anterior := abertos[(i - 1 + total) % total]
		var proximo := abertos[(i + 1) % total]
		var entra := v - anterior
		var sai := proximo - v
		if entra.length() < 1.0 or sai.length() < 1.0:
			saida.append(v)
			continue
		# Colinear: nao ha quina para chanfrar.
		if absf(entra.normalized().cross(sai.normalized())) < 0.01:
			saida.append(v)
			continue
		var corte := minf(quanto, minf(entra.length(), sai.length()) * 0.4)
		corte = floorf(corte / 16.0) * 16.0
		if corte < 16.0:
			saida.append(v)
			continue
		saida.append(v - entra.normalized() * corte)
		saida.append(v + sai.normalized() * corte)

	if fechado:
		saida.append(saida[0])
	return saida


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

	var chao := Polygon2D.new()
	chao.name = "Chao"
	chao.polygon = contorno
	chao.z_index = Z_CHAO
	_texturizar(chao, textura_chao, ancora)
	add_child(chao)

	_montar_sombra(contorno)
	_montar_fita(contorno)
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


## A SOMBRA que a parede projeta no chao (TOPO 02).
##
## Os trechos saem de `_subtrechos()`, que e a MESMA fonte da colisao. Nao e
## economia: quem sabe onde ha porta e esta cena, e recalcular dentro da
## `SombraDeParede` criaria uma segunda resposta para "onde ha parede" -- a
## divergencia exata que a PAR 01 pagou quando o visual e a colisao discordaram
## sobre o vao, e o sintoma foi a face atravessando o batente.
##
## Uma faixa escura cruzando a soleira leria como degrau, e a porta e o lugar
## onde o jogador menos pode hesitar.
func _montar_sombra(contorno: PackedVector2Array) -> void:
	var trechos: Array[PackedVector2Array] = []
	var total := contorno.size()
	for i in total:
		trechos.append_array(_subtrechos(contorno[i], contorno[(i + 1) % total]))
	if trechos.is_empty():
		return
	add_child(SombraDeParede.construir(trechos, contorno))


## A FITA DE MODULOS (PAREDE 04): a parede como pecas de 32 px.
##
## Ela desenha POR CIMA do topo e da face antigos, que continuam la. Isso nao e
## indecisao: enquanto o sistema novo nao cobre tudo -- faltam as duas quinas de
## baixo e as celulas que encostam no vao da porta --, a parede antiga e o que
## aparece nos buracos. Quem aposenta a antiga e a PAREDE 13, e nao antes, porque
## fallback removido cedo demais vira faixa preta na borda da sala.
##
## A `Sala` nao sabe qual textura e um tubo, e nao deve saber: ela entrega
## contorno, portas e semente. E o renderizador nao mexe em colisao -- o solido
## continua sendo `SegmentShape2D` sobre a linha do contorno, que e a regra do
## Low Top-Down e nao muda neste epico.
func _montar_fita(contorno: PackedVector2Array) -> void:
	# Laco explicito: `Dictionary.values()` devolve `Array` sem tipo, e atribuir
	# isso a um `Array[Porta]` explode em runtime.
	var portas: Array[Porta] = []
	for chave in _portas_por_direcao:
		var porta := _portas_por_direcao[chave] as Porta
		if porta != null:
			portas.append(porta)
	# O MATERIAL sai do kit do andar; a FACE do tipo continua vindo do DadosSala.
	# A divisao e a da PAREDE 05: o estilo diz de que o setor e feito, o tipo de
	# sala diz de que sala se trata.
	var estilo: EstiloDeParede = null
	if _dados_visual != null:
		estilo = _dados_visual.estilo_de_parede

	var topos: Array[Texture2D] = []
	if estilo != null and estilo.vestivel():
		topos = estilo.topos
	else:
		# Sala sem dados -- aberta sozinha no editor, ou a amostra que o catalogo
		# instancia -- cai na lista neutra em disco. Sala lisa e melhor que sala
		# sem parede.
		for caminho in TOPOS_NEUTROS:
			var t := load(caminho) as Texture2D
			if t != null:
				topos.append(t)

	# A FACE COMUM sempre, mais as ESPECIAIS do terco do andar em que esta sala
	# esta. A progressao existia antes da fita -- `_face_do_lado` sorteava por
	# `textura_progressiva` -- e se perdeu quando o desenho virou celula; o portao
	# de camada visual pegou. Ela importa: e o que faz o andar mudar de cara
	# conforme o jogador avanca, em vez de repetir a mesma biblioteca do inicio ao
	# fim.
	#
	# A comum fica FORA do terco de proposito: ela e o modulo que domina 65% da
	# parede, e some-la do meio do andar deixaria um terco inteiro so de
	# especiais.
	var faces: Array[Texture2D] = []
	if _dados_visual != null and not _dados_visual.texturas_face.is_empty():
		var todas := _dados_visual.texturas_face
		if todas[0] != null:
			faces.append(todas[0])
		var especiais: Array[Texture2D] = []
		for i in range(1, todas.size()):
			if todas[i] != null:
				especiais.append(todas[i])
		faces.append_array(
			_dados_visual.faixa_progressiva(especiais, fracao_do_andar))
	if faces.is_empty():
		var neutra: Texture2D = estilo.face_neutra if estilo != null else null
		if neutra == null:
			neutra = load(FACE_NEUTRA) as Texture2D
		if neutra != null:
			faces.append(neutra)

	# O TEMA entra DEPOIS do terco do andar, e nao no lugar dele.
	#
	# O terco faz o andar mudar de cara conforme o jogador avanca; o tema faz a
	# SALA ter identidade. Sao perguntas diferentes e as duas continuam sendo
	# respondidas -- por isso `aplicar()` recebe o catalogo INTEIRO do tipo, e nao
	# a lista ja filtrada: o favorito do tema pode aparecer num terco que nao o
	# incluiria.
	if _tema != null and _dados_visual != null:
		faces = _tema.aplicar(faces, _dados_visual.texturas_face)

	var peso: float = estilo.peso_comum if estilo != null else 0.65
	if _tema != null and _tema.peso_comum >= 0.0:
		peso = _tema.peso_comum
	var espacamento: int = estilo.espacamento_minimo if estilo != null else 2
	var abertos: Array[Vector2] = []

	# Os DECALQUES de topo, com o tema puxando o favorito dele para a frente.
	# O ternario NAO serve aqui: `[]` nasce como `Array` sem tipo e a atribuicao
	# explode em runtime, sem uma linha no editor. E a mesma armadilha que
	# `Array[Node].filter()` ja registra.
	var decalques: Array[Texture2D] = []
	var chance_decalque := 0.0
	if estilo != null:
		decalques = estilo.decalques_de_topo
		chance_decalque = estilo.chance_de_decalque
	if _tema != null:
		decalques = _tema.aplicar_decalques(decalques)

	add_child(RenderizadorParedes.construir(
		contorno, portas, hash(coordenadas_grid), topos, faces,
		peso, espacamento, abertos, _perfil(), silhueta_de_teste,
		decalques, chance_decalque))


## O perfil de espessura desta sala.
##
## Vem do `EstiloDeParede` -- o mesmo recurso que ja carrega topo, face neutra e
## cantos --, porque espessura e botao de tuning e botao de tuning mora em
## `.tres`. A valvula de teste ganha dele so quando esta ligada, e ela so liga
## em ferramenta.
## O perfil que ESTA sala desenha.
##
## Publico porque a CAMERA precisa dele: a margem do clamp tem de sair do mesmo
## perfil que desenhou a parede. Enquanto ela lia o default, um andar com
## espessura propria desenharia parede que a camera nao mostra -- sem erro no
## console, so a moldura saindo do quadro.
func perfil_de_parede() -> PerfilDeParede:
	return _perfil()


func _perfil() -> PerfilDeParede:
	if perfil_de_teste != null:
		return perfil_de_teste
	var estilo: EstiloDeParede = _dados_visual.estilo_de_parede if _dados_visual != null else null
	if estilo == null:
		return null
	return estilo.perfil()


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
## O topo desta celula, sorteado da lista neutra.
##
## A semente e deslocada para chao e topo nao andarem juntos: com a mesma, a
## sala que pega o chao 2 pegaria sempre o topo 2, e as combinacoes possiveis
## viravam uma fila em vez de uma grade.
##
## `static` porque o corredor precisa do mesmo sorteio sem ser uma Sala.
static func topo_neutro(semente: int) -> Texture2D:
	if TOPOS_NEUTROS.is_empty():
		return null
	var i := absi(semente ^ 0x5bf03635) % TOPOS_NEUTROS.size()
	return load(TOPOS_NEUTROS[i]) as Texture2D


func _textura(familia: StringName) -> Texture2D:
	var textura: Texture2D = null
	if familia == &"parede":
		# O topo nao depende do tipo: ele e o mesmo em todo o andar.
		return topo_neutro(hash(coordenadas_grid))
	if _dados_visual != null:
		var semente := hash(coordenadas_grid)
		match familia:
			&"chao":
				textura = _dados_visual.textura_progressiva(
					_dados_visual.texturas_chao, semente, fracao_do_andar
				)
			&"parede":
				textura = topo_neutro(semente)
	if textura == null:
		textura = load(TEXTURA_PADRAO % familia) as Texture2D
	return textura


# ------------------------------------------------------------- decoracao -----

## Props sem colisao na margem entre a parede e a area de spawn. A seed vem
## das coordenadas da celula: reentrar na sala mostra a mesma sala, e um teste
## consegue reproduzir. Sem dados nao ha props -- e o tipo que diz o que cabe.
##
## Sao DUAS FAMILIAS, e a diferenca entre elas e de PERSPECTIVA, nao de arte
## (LTD 09):
##
##   CHAPADO     mancha, marcacao, grade de ventilacao, painel. Coisas que
##               estao NO chao. Ficam em `Z_CHAO_DETALHE`, centradas na
##               propria origem e FORA do Y-sort -- o jogador passa por cima
##               delas, e e isso que se quer. Dar face vertical a uma mancha de
##               oleo seria mentir sobre a perspectiva.
##   VOLUMETRICO caixa, terminal, mesa, armario, maquina. Coisas que estao
##               SOBRE o chao, com topo e face. Sao corpos na sala: entram em
##               `Z_MUNDO`, se ordenam por Y contra o jogador e os inimigos,
##               tem origem na BASE e ganham sombra.
##
## As duas dividem a lista `colocados`, senao uma caixa nasceria em cima de uma
## mancha -- elas nao se conhecem, mas disputam o mesmo chao.
##
## O volumetrico precisa dos TRES de uma vez -- origem na base, `Z_MUNDO` e
## sombra -- e migrar so o z_index e o pior dos mundos: o prop entra na disputa
## de ordem ordenado pelo MEIO do corpo e passa na frente de quem esta mais
## abaixo na tela. E o mesmo defeito que a LTD 07 corrigiu nos atores, e que
## nao aparece parado nem no console: so quando dois corpos se cruzam andando.
func _montar_decoracao() -> void:
	var dados := _dados_visual
	if dados == null:
		return
	var contorno := _pontos_do_contorno()
	if contorno.size() < 4:
		return
	var aberto := contorno_local()

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(coordenadas_grid)
	var bocas := _bocas_locais()
	var colocados: Array[Vector2] = []

	_montar_props_chapados(dados, contorno, aberto, bocas, colocados, rng)
	_montar_props_animados(dados, contorno, aberto, bocas, colocados, rng)
	_montar_props_volumetricos(dados, contorno, aberto, bocas, colocados, rng)
	_montar_props_frente(dados, contorno, aberto, bocas, colocados, rng)
	_montar_decalques(dados, contorno, aberto, bocas, colocados, rng)


## A familia CHAPADA, como sempre foi: uma raiz so, numa faixa de z propria.
func _montar_props_chapados(
	dados: DadosSala, contorno: PackedVector2Array, aberto: PackedVector2Array,
	bocas: Array[Vector2], colocados: Array[Vector2], rng: RandomNumberGenerator
) -> void:
	if dados.atlas_props == null or dados.regioes_props.is_empty() or dados.quantidade_props <= 0:
		return

	var raiz := Node2D.new()
	raiz.name = "Decoracao"
	raiz.z_index = Z_CHAO_DETALHE
	add_child(raiz)

	for _i in dados.quantidade_props:
		for _tentativa in PROP_TENTATIVAS:
			var ponto := _sortear_ponto_de_prop(rng, contorno, aberto, PROP_LADO)
			if ponto == Vector2.INF:
				continue
			if not _cabe_prop(ponto, aberto, bocas, colocados, PROP_LADO):
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


## Os DECALQUES INDUSTRIAIS: o que nao cabe num tile (#233).
##
## O tile de 64x64 e usado com wrap nos dois eixos e deslocamento arbitrario,
## entao **nenhuma linha ou coluna pode ser especial**. Um numero estampado
## dentro da textura aparece tres vezes por sala em posicoes sorteadas, e a sala
## deixa de TER um numero -- ela passa a ter um padrao de numeros. Tudo que e
## elemento unico e posicionado sai da textura e vira isto.
##
## **Eles NAO espelham, e essa e a unica coisa que os separa de um prop
## chapado.** `_montar_props_chapados` sorteia `flip_h` para multiplicar a
## variedade de graca; num decalque com texto isso escreve `30-A` na metade das
## salas, e nao ha erro no console para uma placa lida ao contrario. Espelhar
## REFLETE, e a mesma razao pela qual `flip_v` e proibido na porta.
##
## Eles dividem `colocados` com as outras familias pelo mesmo motivo que elas se
## dividem entre si: nao se conhecem, mas disputam o mesmo chao.
func _montar_decalques(
	dados: DadosSala, contorno: PackedVector2Array, aberto: PackedVector2Array,
	bocas: Array[Vector2], colocados: Array[Vector2], rng: RandomNumberGenerator
) -> void:
	if dados.atlas_decalques == null or dados.regioes_decalques.is_empty():
		return
	if dados.quantidade_decalques <= 0:
		return

	var raiz := Node2D.new()
	raiz.name = "Decalques"
	# A MESMA faixa dos props chapados, e nao uma nova. Zero e onde ficam
	# telegrafo, projetil e atores: um decalque ali poderia cair na frente do
	# aviso que torna um ataque justo. Dar volume a um decalque o levaria para
	# `Z_MUNDO` e reabriria a pergunta -- e por isso ele e chapado por
	# construcao, como o prop animado.
	raiz.z_index = Z_CHAO_DETALHE
	add_child(raiz)

	for _i in dados.quantidade_decalques:
		for _tentativa in PROP_TENTATIVAS:
			var regiao := dados.regioes_decalques[
				rng.randi_range(0, dados.regioes_decalques.size() - 1)]
			# O RAIO da peca, e nao `PROP_LADO`: o decalque e maior que um prop
			# de 32 ("poucos por sala, GRANDES e gastos"), e usar a folga do prop
			# deixaria metade dele por cima da parede.
			var lado := float(maxi(regiao.size.x, regiao.size.y))
			var ponto := _sortear_ponto_de_prop(rng, contorno, aberto, lado)
			if ponto == Vector2.INF:
				continue
			if not _cabe_prop(ponto, aberto, bocas, colocados, lado):
				continue
			var sprite := Sprite2D.new()
			sprite.texture = dados.atlas_decalques
			sprite.region_enabled = true
			sprite.region_rect = Rect2(regiao)
			sprite.position = ponto
			raiz.add_child(sprite)
			colocados.append(ponto)
			break


## A familia que se MEXE, e ela e a menor das quatro de proposito (AND1 02).
##
## Duas coisas aqui nao sao ajuste de sala, e sim garantia:
##
## 1. **O TETO.** `max_props_animados` limita quantos se mexem ao mesmo tempo, e
##    e a regra "se tudo se mover, nada parece importante" virada numero. Sem
##    ele ela seria opiniao, e opiniao nao sobrevive a proxima pessoa que achar
##    o ventilador bonito.
## 2. **A FAIXA.** Eles moram em `Z_CHAO_DETALHE`, junto dos chapados e ABAIXO
##    de `Z_MUNDO`. Zero e onde ficam telegrafo, projetil e atores: um prop
##    animado ali poderia cair na frente do aviso que torna um ataque justo. A
##    consequencia e que prop animado e CHAPADO por construcao -- dar volume a
##    um deles o levaria para `Z_MUNDO` e reabriria a pergunta.
##
## Eles dividem `colocados` com as outras familias pelo mesmo motivo que elas se
## dividem entre si: nao se conhecem, mas disputam o mesmo chao.
func _montar_props_animados(
	dados: DadosSala, contorno: PackedVector2Array, aberto: PackedVector2Array,
	bocas: Array[Vector2], colocados: Array[Vector2], rng: RandomNumberGenerator
) -> void:
	if dados.atlas_props == null or dados.regioes_props_animados.is_empty():
		return
	var teto := mini(dados.max_props_animados, dados.regioes_props_animados.size() * 4)
	if teto <= 0:
		return

	var raiz := Node2D.new()
	raiz.name = "DecoracaoAnimada"
	raiz.z_index = Z_CHAO_DETALHE
	add_child(raiz)

	for _i in teto:
		for _tentativa in PROP_TENTATIVAS:
			var ponto := _sortear_ponto_de_prop(rng, contorno, aberto, PROP_LADO)
			if ponto == Vector2.INF:
				continue
			if not _cabe_prop(ponto, aberto, bocas, colocados, PROP_LADO):
				continue
			var prop := PropAnimado.new()
			prop.position = ponto
			raiz.add_child(prop)
			# A fase e sorteada: dois ventiladores em fase batem juntos e leem
			# como um efeito ligado por script, e nao como duas maquinas.
			prop.configurar(
				dados.atlas_props,
				dados.regioes_props_animados[rng.randi_range(0, dados.regioes_props_animados.size() - 1)],
				dados.quadros_props_animados,
				dados.fps_props_animados,
				rng.randi_range(0, maxi(dados.quadros_props_animados - 1, 0))
			)
			colocados.append(ponto)
			break


## A familia VOLUMETRICA. Cada prop e um Node2D no ponto em que ele ENCOSTA no
## chao, com o sprite subindo a partir dali e a sombra no pe.
##
## Eles sao filhos DIRETOS da sala, e nao de uma raiz propria, e isso e a peca
## inteira: a sala tem `y_sort_enabled`, e z_index tem prioridade sobre Y --
## uma raiz com z_index proprio congelaria a ordem, e o prop voltaria a ser
## chapado, so que desenhado por cima de todo mundo. Ficar sem raiz e o preco
## de participar da ordenacao.
##
## O deslocamento do sprite e `-altura/2`, e nao uma tabela por prop: o atlas e
## composto com a base de cada arte ancorada no FUNDO da celula, entao a regra
## vale para os doze e para qualquer um que entre depois. E o mesmo contrato que
## `Direcoes.BASE_NO_QUADRO` carrega para os atores, e pelo mesmo motivo -- duas
## copias do numero divergiriam com o sintoma so aparecendo em tela.
func _montar_props_volumetricos(
	dados: DadosSala, contorno: PackedVector2Array, aberto: PackedVector2Array,
	bocas: Array[Vector2], colocados: Array[Vector2], rng: RandomNumberGenerator
) -> void:
	if dados.atlas_props_volume == null:
		return
	# A sala sorteada ganha o raro NO POOL, e nao a mais dele: ele ocupa a vaga
	# de um prop comum. Somar um a mais faria a sala escolhida ser tambem a mais
	# cheia, e o jogador leria a mobilia extra antes de reparar no robo.
	var regioes := dados.regioes_props_volume.duplicate()
	if _props_raros:
		regioes.append_array(dados.regioes_props_raras)
	if regioes.is_empty():
		return
	if dados.quantidade_props_volume <= 0:
		return

	for _i in dados.quantidade_props_volume:
		var regiao: Rect2i = regioes[rng.randi_range(0, regioes.size() - 1)]
		var largura := float(regiao.size.x)
		for _tentativa in PROP_TENTATIVAS:
			var ponto := _sortear_ponto_de_prop(rng, contorno, aberto, largura)
			if ponto == Vector2.INF:
				continue
			if not _cabe_prop(ponto, aberto, bocas, colocados, largura):
				continue

			var corpo := Node2D.new()
			corpo.name = "PropVolume"
			corpo.position = ponto
			# Sem z_index proprio: Z_MUNDO e o default, e e o unico jeito de ele
			# se ordenar por Y contra jogador e inimigo.
			add_child(corpo)

			# A sombra entra ANTES do sprite para desenhar por baixo dele. Ela
			# nasce na origem do corpo, que ja e o ponto de contato com o chao.
			var sombra := Sombra.criar(largura * PROP_FRACAO_SOMBRA, 0.0)
			corpo.add_child(sombra)

			var sprite := Sprite2D.new()
			sprite.texture = dados.atlas_props_volume
			sprite.region_enabled = true
			sprite.region_rect = Rect2(regiao)
			sprite.flip_h = rng.randf() < 0.5
			sprite.position = Vector2(0.0, -float(regiao.size.y) * 0.5)
			corpo.add_child(sprite)

			colocados.append(ponto)
			break


## A camada FOREGROUND (LTD 10): o que passa POR CIMA do ator.
##
## Viga, tubulacao, cabo suspenso. Eles ficam em `Z_FRENTE`, acima de tudo que
## se ordena por Y -- sao a unica coisa do jogo que pode cobrir o jogador.
##
## A trava e ESTRUTURAL: eles nascem na margem e `_cabe_prop` ja recusa qualquer
## ponto que toque a `area_spawn`. Telegrafo nasce onde o inimigo esta, e inimigo
## nasce na area util; ficando fora dela, "o Foreground nao cobre telegrafo"
## deixa de ser revisao de olho e vira comparacao de retangulos.
##
## Eles NAO tem sombra, e isso nao e esquecimento: sombra responde "onde isto
## encosta no chao", e uma viga suspensa nao encosta. Dar sombra a ela diria que
## ha um obstaculo no piso onde nao ha.
##
## Eles tambem nao entram na lista `colocados`. Um cabo suspenso passa por cima
## de uma caixa sem conflito -- eles estao em alturas diferentes, e disputar o
## mesmo chao seria justamente o erro de trata-los como corpo.
func _montar_props_frente(
	dados: DadosSala, contorno: PackedVector2Array, aberto: PackedVector2Array,
	bocas: Array[Vector2], colocados: Array[Vector2], rng: RandomNumberGenerator
) -> void:
	if dados.atlas_props_frente == null or dados.regioes_props_frente.is_empty():
		return
	if dados.quantidade_props_frente <= 0:
		return

	var raiz := Node2D.new()
	raiz.name = "Frente"
	raiz.z_index = Z_FRENTE
	add_child(raiz)

	for _i in dados.quantidade_props_frente:
		var regiao: Rect2i = dados.regioes_props_frente[
			rng.randi_range(0, dados.regioes_props_frente.size() - 1)
		]
		var largura := float(regiao.size.x)
		for _tentativa in PROP_TENTATIVAS:
			var ponto := _sortear_ponto_de_prop(rng, contorno, aberto, largura)
			if ponto == Vector2.INF:
				continue
			# Passa a lista VAZIA de propositio: a checagem de contorno, porta e
			# area util continua valendo, mas um elemento suspenso nao precisa de
			# espaco livre no chao -- ele nao esta no chao.
			var vazia: Array[Vector2] = []
			if not _cabe_prop(ponto, aberto, bocas, vazia, largura):
				continue
			var sprite := Sprite2D.new()
			sprite.texture = dados.atlas_props_frente
			sprite.region_enabled = true
			sprite.region_rect = Rect2(regiao)
			sprite.flip_h = rng.randf() < 0.5
			sprite.position = ponto
			raiz.add_child(sprite)
			break


## Um ponto encostado num lado do contorno, para DENTRO. O lado e sorteado com
## peso pelo comprimento, senao o braco curto do L recebe tanto quanto a parede
## longa. Vector2.INF quando o sorteio nao serviu.
func _sortear_ponto_de_prop(
	rng: RandomNumberGenerator, contorno: PackedVector2Array,
	aberto: PackedVector2Array, largura: float
) -> Vector2:
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
		if comprimento < largura * 2.0:
			return Vector2.INF
		var direcao := (b - a) / comprimento
		var normal := Vector2(-direcao.y, direcao.x)
		var ao_longo := clampf(alvo, largura, comprimento - largura)
		var afastamento := rng.randf_range(PROP_AFASTAMENTO_MINIMO, PROP_AFASTAMENTO_MAXIMO)
		var base := a + direcao * ao_longo
		var ponto := base + normal * afastamento
		if not Geometry2D.is_point_in_polygon(ponto, aberto):
			ponto = base - normal * afastamento
		if not Geometry2D.is_point_in_polygon(ponto, aberto):
			return Vector2.INF
		return (ponto / PROP_GRADE).round() * PROP_GRADE
	return Vector2.INF


## `largura` e a PEGADA do prop, e vem da regiao sorteada em vez de `PROP_LADO`:
## o atlas volumetrico tem celulas de 32 e de 64, e cobrar 32 de uma maquina de
## 64 a deixaria com metade do corpo dentro da parede -- sem erro no console,
## porque prop nao tem colisao para reclamar.
func _cabe_prop(
	ponto: Vector2, aberto: PackedVector2Array, bocas: Array[Vector2],
	colocados: Array[Vector2], largura: float
) -> bool:
	# Dentro do contorno com folga de meio prop, e fora de qualquer obstaculo.
	if not _local_livre(ponto, aberto, largura * 0.5 + 8.0):
		return false
	# Fora da area util: prop no meio do chao, sem colisao, e obstaculo mentiroso.
	if area_spawn.intersects(Rect2(ponto - Vector2.ONE * largura * 0.5, Vector2.ONE * largura)):
		return false
	for boca in bocas:
		if boca.distance_to(ponto) < PROP_DISTANCIA_DE_PORTA:
			return false
	for outro in colocados:
		# O espaco minimo cresce com o prop: dois props de 64 a 40 px um do outro
		# se sobrepoem, e a lista nao sabe o tamanho de quem ja esta nela.
		if outro.distance_to(ponto) < maxf(PROP_ESPACO, largura):
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
