class_name DadosSala
extends Resource
## Descreve um TIPO de sala: que cena usar, onde ela pode nascer no andar e
## como ela se apresenta no minimapa.
##
## A decisao de design que este arquivo carrega: antes, cada sala especial
## tinha codigo proprio no GerenciadorMapa -- um @export para a cena, um par de
## variaveis de estado e uma funcao `_pendurar_X` copiada da anterior. Um tipo
## novo custava um terceiro bloco igual. Aqui a regra de colocacao virou dado,
## entao adicionar sala de loja, de desafio ou de descanso e criar um .tres e
## arrasta-lo para a lista do GerenciadorMapa, sem abrir GDScript.
##
## Para criar um tipo: clique direito em src/mapa > Novo Recurso > DadosSala,
## salve como tipo_<nome>.tres, e adicione em `tipos_de_sala` no no
## GerenciadorMapa de src/main/main.tscn.

## Ids que o resto do codigo precisa reconhecer pelo nome. O que nao esta aqui
## e conteudo puro: o gerador trata igual, so o .tres muda.
const ID_COMBATE: StringName = &"combate"
const ID_BOSS: StringName = &"boss"
const ID_ARMA: StringName = &"arma"
const ID_ITEM: StringName = &"item"
const ID_INICIAL: StringName = &"inicial"

## Area de referencia da conta de orcamento. A sala padrao (960x544) tem pouco
## mais de cinco vezes isto, entao `densidade` acaba lida como "orcamento a cada
## cinco tijolos de sala padrao" -- numero pequeno o suficiente para alguem
## ajustar no Inspetor sem calculadora.
const AREA_DE_REFERENCIA := 100000.0

## COMUM entra no sorteio normal do passeio aleatorio e preenche o andar.
## PENDURADA ganha uma celula propria encostada numa ancora ja existente. E o
## que o chefe precisa (ele so tem porta Sul, e quase nunca cairia numa celula
## com o grau certo por sorteio) e o que as recompensas usam para poder exigir
## beco sem saida -- coisa que o passeio nao garante sozinho.
## INICIAL e a sala onde o jogador nasce. Ela nao entra no sorteio das COMUM
## nem se pendura numa ancora: a celula dela e sempre a origem do andar, e e
## isso que garante que ninguem comece dentro de um combate.
enum Colocacao { COMUM, PENDURADA, INICIAL }

@export var id: StringName = ID_COMBATE
## Estilos possiveis deste tipo. E assim que "mais um estilo de sala de
## combate" custa arrastar uma cena aqui em vez de mexer em codigo. A sala de
## combate tem cinco; o chefe tem uma so.
##
## Numa sala PENDURADA o gerador tenta TODOS os estilos ate um caber, nao um
## sorteado: estilos diferentes tem portas em lados diferentes, entao o primeiro
## nao caber nao diz nada sobre o proximo.
@export var cenas: Array[PackedScene] = []

@export_group("Colocacao")
@export var colocacao: Colocacao = Colocacao.COMUM
## Quantas vezes este tipo aparece no andar. So vale para PENDURADA: as COMUM
## dividem entre si o que sobrou do passeio.
@export var quantidade: int = 1
## Ordem de colocacao, menor primeiro. Importa porque quem chega primeiro
## escolhe a melhor ancora: o chefe tem de tomar a celula mais distante antes
## que um premio a ocupe, senao ele cai no meio do andar.
@export var prioridade: int = 100
## Exige beco sem saida (celula de grau 1) como ancora. Recompensa que nao
## custa um desvio nao e recompensa.
@export var exige_beco: bool = false
## Quantas salas, no minimo, entre a origem e esta. Premio encostado na sala
## inicial nao e descoberta, e chefe perto da entrada encurta o andar.
##
## Nao existe um `evita_vizinhanca_de` aqui de proposito: duas salas penduradas
## NUNCA nascem coladas, por regra estrutural do gerador -- ambas podem ter uma
## porta so, e o par se estrangularia. Um campo para reconfigurar isso seria
## decorativo.
@export var distancia_minima_da_origem: int = 0
## Se falso e o tipo nao couber, o andar inteiro e sorteado de novo. O chefe e
## o unico obrigatorio: sem ele a run nao tem como terminar em vitoria.
@export var opcional: bool = true

@export_group("Inimigos")
## O que PODE nascer numa sala deste tipo. **Lista vazia = sala sem combate**, e
## e so isso que separa a sala de recompensa da sala de briga -- nao existe
## flag "tem_combate" em lugar nenhum.
@export var inimigos: Array[GrupoInimigo] = []
## Orcamento por AREA_DE_REFERENCIA de area util. A sala grande tem 2.2x a area
## da padrao, entao recebe 2.2x o orcamento: "sala maior tem mais inimigos" vira
## consequencia da geometria, sem tabela por cena. Zero desliga a conta e deixa
## so o piso valer -- e assim que o chefe pede exatamente um.
@export var densidade: float = 0.0
@export var orcamento_minimo: int = 0
@export var orcamento_maximo: int = 0

@export_group("Ritmo")
## Quanto a barra sobe ao limpar uma sala deste tipo. Herda o papel que o
## `deterioracao_ao_limpar` do DadosOnda tinha.
@export var deterioracao_ao_limpar: float = 0.0
## Piso forcado ao ENTRAR na sala; -1 nao forca nada. Herda o
## `deterioracao_minima_inicial` do DadosOnda, e existe por causa do chefe: o
## GDD pede a luta final em nivel critico, e sem este campo ela aconteceria no
## nivel em que a run por acaso chegou.
@export var deterioracao_minima_ao_entrar: float = -1.0

@export_group("Minimapa")
@export var cor_mapa: Color = Color("3ce0ff")
## Marca curta desenhada no centro da sala no minimapa. Vazio = sem marca.
@export var icone: String = ""

@export_group("Visual")
## As texturas que a Sala monta em codigo no _ready, a partir do contorno.
##
## Sao LISTAS, e nao um campo so, porque um andar inteiro com o mesmo par de
## texturas le como uma sala repetida sete vezes. A sala escolhe a variante pela
## propria celula -- `hash(coordenadas_grid)` -- entao a escolha e estavel:
## reentrar na sala mostra a mesma sala, e um teste consegue reproduzir. E o
## mesmo mecanismo que `_montar_decoracao()` ja usa para os props.
##
## Um tipo com UMA entrada continua valido e e o caso das salas especiais, onde
## variacao nao faz sentido: existe uma sala de chefe por andar.
##
## Os PNGs sao arte autorada, preparada por `tools/texturas/preparar_textura.py`
## -- que costura, forca o gamut e confere. Ate a v0.2 eles nasciam de codigo em
## `gerar_texturas.gd`; porta e props ainda nascem.
##
## Houve tambem um `textura_filete`: o neon que corria pelo contorno. Saiu
## quando a parede ganhou textura propria -- duas bordas desenhadas uma sobre a
## outra, e era o neon que encostava na beira do quadro.
@export var texturas_chao: Array[Texture2D] = []
@export var texturas_parede: Array[Texture2D] = []
## As FACES da parede -- os modulos que a sala pode vestir nos lados que a
## camera enxerga de frente (LTD 13).
##
## Lista, e nao textura unica, pelo mesmo motivo de chao e parede: um andar
## inteiro com o mesmo painel repetido le como corredor de escritorio, nao como
## setor industrial. A diferenca e QUANDO ela e sorteada -- ver
## `Sala._montar_faces()`: a face sorteia por LADO da sala, e nao uma por sala.
##
## E aqui, e nao num caminho fixo no codigo, porque a face e a superficie que
## carrega a identidade de cada tipo de sala: ela e a maior area de ambiente em
## tela desde que a parede ganhou altura, e e nela que o acento rebaixado do
## tipo aparece. Enquanto isto foi um `load()` cravado em `sala.gd`, nenhum
## modulo produzido chegava a tela.
##
## Vazia = cai na face neutra em disco. Sala aberta sozinha no editor nao tem
## DadosSala e nao pode ficar sem face.
@export var texturas_face: Array[Texture2D] = []
## Atlas de props e QUAIS celulas dele esta sala pode usar. O atlas e um so
## para o jogo inteiro; a lista e o que da identidade -- a sala do chefe nao
## recebe o painel de acento da sala de arma.
@export var atlas_props: Texture2D
@export var regioes_props: Array[Rect2i] = []
## Quantos props a sala tenta colocar na margem entre a parede e a area de
## spawn. Zero desliga a decoracao.
@export var quantidade_props: int = 0

## O atlas VOLUMETRICO e as celulas dele que esta sala pode usar (LTD 09).
##
## E uma segunda lista, e nao uma bandeira na primeira, porque as duas familias
## de prop nao sao variacoes de estilo -- elas sao desenhadas em perspectivas
## diferentes e a sala as monta de jeitos diferentes. O chapado esta NO chao,
## fica em `Z_CHAO_DETALHE` e nao se ordena; o volumetrico esta SOBRE o chao,
## entra em `Z_MUNDO`, se ordena por Y e ganha sombra. Uma bandeira numa lista
## so esconderia isso atras de um booleano.
##
## Sao tambem dois ARQUIVOS, e nao um atlas maior. O chapado nasce de codigo
## (`gerar_texturas.gd`) e e trancado byte a byte pelo determinismo; o
## volumetrico e arte autorada e e trancado por propriedade medida, como o chao
## e a parede. Fundir os dois obrigaria a escolher um regime so, e o perdedor
## seria o determinismo -- que hoje e o que impede alguem mexer no gerador e
## esquecer de rodar.
##
## As celulas tem geometrias diferentes de proposito: 32x64 para o que e
## estreito (caixa, terminal, mesa) e 64x64 para o que e largo (maquina,
## gerador). Quem le a largura para saber se o prop cabe e `Sala._cabe_prop`,
## a partir da REGIAO sorteada -- nao ha constante de tamanho aqui.
## Os props que se MEXEM: ventilador, luz piscando, pistao, ponteiro.
##
## Cada regiao aponta o PRIMEIRO quadro de uma fita no mesmo atlas chapado; os
## outros ficam lado a lado, como nas fitas de ator. Prop animado novo e uma
## regiao a mais nesta lista, e nada de cena nova -- o modelo de "uma cena por
## coisa" ja existiu no GerenciadorMapa e saiu de la por nao escalar.
@export var regioes_props_animados: Array[Rect2i] = []
@export var quadros_props_animados: int = 4
@export var fps_props_animados: float = 6.0

## O ORCAMENTO: quantos props podem se mexer ao mesmo tempo nesta sala.
##
## E a regra "se tudo se mover, nada parece importante" virada numero. Sem teto
## ela seria opiniao, e opiniao nao sobrevive a proxima pessoa que achar o
## ventilador bonito: movimento no cenario compete com movimento de PROJETIL, e
## o projetil tem de ganhar sempre.
##
## Baixo de proposito. Dois pontos de movimento numa sala ja dao vida a ela; o
## quarto ja e ruido, e ruido perto de um telegrafo e uma morte que o jogador
## nao consegue explicar.
@export var max_props_animados: int = 2

@export var atlas_props_volume: Texture2D
@export var regioes_props_volume: Array[Rect2i] = []
## A camada FOREGROUND: o que passa POR CIMA do ator (LTD 10).
##
## Viga, tubulacao suspensa, cabo pendurado, topo de maquina alta. Eles moram em
## `Sala.Z_FRENTE`, acima de tudo que se ordena por Y, e e a unica camada do
## jogo que pode esconder o jogador.
##
## Por isso ela e a mais perigosa do projeto, e a regra dela e ESTRUTURAL e nao
## de bom senso: **o Foreground nunca entra na `area_spawn`**. Ele fica na
## margem, entre a parede e a area util -- exatamente onde os props ja ficam.
##
## A alternativa seria confiar em quem posiciona, e a issue LTD 10 pede o
## contrario: "nenhum telegrafo de inimigo ou do chefe fica coberto". Telegrafo
## nasce onde o inimigo esta, e inimigo nasce na `area_spawn`. Mantendo o
## Foreground fora dela, "nao cobre telegrafo" deixa de ser revisao de olho e
## vira uma comparacao de retangulos que uma suite faz.
##
## O jogador AINDA passa por baixo -- ele anda na margem o tempo todo, e e la
## que os props estao. O que ele nao faz e perder de vista um telegrafo no meio
## da sala.
@export var atlas_props_frente: Texture2D
@export var regioes_props_frente: Array[Rect2i] = []
## Quantos elementos de Foreground a sala tenta colocar.
##
## O default e ZERO e a issue pede moderacao com todas as letras: "o objetivo e
## aumentar profundidade, nao esconder constantemente o combate". Sala que quer
## Foreground pede explicitamente.
@export var quantidade_props_frente: int = 0

## Quantos props volumetricos a sala tenta colocar. Contagem propria e nao uma
## fracao de `quantidade_props`: sao ocupacoes diferentes do mesmo chao, e a
## sala do chefe quer muitos chapados e quase nenhum corpo no caminho.
@export var quantidade_props_volume: int = 0


func eh_pendurada() -> bool:
	return colocacao == Colocacao.PENDURADA


func eh_inicial() -> bool:
	return colocacao == Colocacao.INICIAL


## Copia limpa dos estilos, sem os nulos que o Inspetor deixa ao crescer o
## array. Loop explicito: Array.filter() devolve Array sem tipo e a atribuicao
## de volta a um Array[PackedScene] estoura em runtime.
func cenas_validas() -> Array[PackedScene]:
	var lista: Array[PackedScene] = []
	for cena in cenas:
		if cena != null:
			lista.append(cena)
	return lista


## Quantas celulas este tipo ocupa de fato. Uma COMUM nao reserva celula: ela
## concorre pelo que o passeio produziu. A INICIAL tambem nao entra nesta conta:
## a celula dela nasce do proprio passeio, que sempre comeca na origem.
## A variante de textura desta celula, estavel por `hash`.
##
## Recebe o hash pronto em vez da celula para o corredor tambem poder usar: ele
## nao tem celula nenhuma, so posicao. Lista vazia devolve null, e quem chama
## cai no fallback.
func textura_de(lista: Array[Texture2D], semente: int) -> Texture2D:
	var validas: Array[Texture2D] = []
	for t in lista:
		if t != null:
			validas.append(t)
	if validas.is_empty():
		return null
	# absi() porque hash() devolve negativo, e o modulo de negativo em GDScript
	# devolve negativo -- indice negativo aqui seria um crash intermitente que so
	# aparece em algumas celulas do andar.
	return validas[absi(semente) % validas.size()]


## A textura desta lista para uma sala que esta a `fracao` do caminho ate o
## chefe -- 0.0 na entrada, 1.0 na sala mais funda do andar (AND1 01).
##
## A LISTA E ORDENADA, e essa e a convencao que este metodo cria: da variante
## mais CONSERVADA para a mais CRITICA. O andar conta uma historia conforme o
## jogador avanca -- "antigo mas funcional", depois "isto deveria ter sido
## reformado", depois "o sistema esta no limite" -- e e isso que prepara a
## mecanica do chefe antes da luta.
##
## Ele NAO troca o sorteio por um indice fixo. A fracao escolhe o TERCO da lista
## e o hash escolhe dentro do terco, entao duas salas do mesmo terco continuam
## podendo ser diferentes. Um indice fixo por profundidade daria um andar com
## tres aparencias e nada mais.
##
## Com uma lista de tres, cada terco tem uma variante e o resultado e o mapa
## direto -- o que esta certo, e o caso de hoje. A janela so comeca a valer com
## listas maiores, e ela existe para nao precisar mexer aqui quando elas vierem.
func textura_progressiva(lista: Array[Texture2D], semente: int, fracao: float) -> Texture2D:
	var validas: Array[Texture2D] = []
	for t in lista:
		if t != null:
			validas.append(t)
	if validas.is_empty():
		return null
	var n := validas.size()
	# clampi antes de int(): fracao 1.0 daria terco 3, que e fora da lista.
	var terco := clampi(int(clampf(fracao, 0.0, 1.0) * 3.0), 0, 2)
	var inicio := (terco * n) / 3
	var fim := ((terco + 1) * n) / 3
	if fim <= inicio:
		fim = inicio + 1
	fim = mini(fim, n)
	var largura := fim - inicio
	# absi() porque hash() devolve negativo, e o modulo de negativo em GDScript
	# devolve negativo -- indice negativo aqui seria um crash intermitente.
	return validas[inicio + absi(semente) % largura]


func celulas_reservadas() -> int:
	if not eh_pendurada():
		return 0
	return maxi(quantidade, 0)


## Copia limpa dos grupos, sem os nulos e sem cena faltando. Mesmo motivo de
## cenas_validas(): o Inspetor deixa buraco ao crescer o array, e filter()
## devolve Array sem tipo.
func grupos_validos() -> Array[GrupoInimigo]:
	var lista: Array[GrupoInimigo] = []
	for grupo in inimigos:
		if grupo != null and grupo.valido():
			lista.append(grupo)
	return lista


func tem_combate() -> bool:
	return not grupos_validos().is_empty()


## Quanto uma sala de `area_px` pixels quadrados pode gastar em inimigos.
##
## Funcao PURA de proposito: e o unico botao de dificuldade do andar, e um teste
## unitario precisa poder conferir a curva sem subir um andar inteiro.
##
## `densidade` zerada nao significa "sala vazia": significa "nao escale por
## tamanho". O que sobra e o piso, e e assim que a sala do chefe recebe
## exatamente 1 (minimo = maximo = 1) e a de recompensa exatamente 0.
func orcamento_para(area_px: float) -> int:
	var teto := maxi(orcamento_maximo, orcamento_minimo)
	if densidade <= 0.0 or area_px <= 0.0:
		return clampi(orcamento_minimo, 0, teto)
	var bruto := int(floorf(area_px / AREA_DE_REFERENCIA * densidade))
	return clampi(bruto, orcamento_minimo, teto)
