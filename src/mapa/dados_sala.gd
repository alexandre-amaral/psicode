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

## A faixa de perimetro de uma sala que nao declara `PerfilDeDecoracao`.
##
## Era `Sala.PROP_AFASTAMENTO_MAXIMO`, e ela vem para ca junto com as contagens
## -- deixar o numero na `Sala` seria manter o segundo dono da mesma verdade,
## que e exatamente o que esta migracao veio desfazer.
##
## Ele so alcanca as LUMINARIAS: sem perfil nao ha prop nenhum para colocar, e
## a luz tem contagem propria em `quantidade_luminarias`.
const FAIXA_SEM_PERFIL := 44.0

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
## E quantas, no maximo. **Zero desliga o teto**, e nao "nunca sai da origem":
## zero e o valor de todos os tipos que existiam antes deste campo, e um teto
## real de zero prenderia a sala na entrada.
##
## Ele nasceu com a Loja, e a razao e a mesma dos dois lados: o piso impede que
## ela nasca colada na entrada, quando o jogador ainda nao tem dinheiro; o teto
## impede que ela nasca no fim, quando nao sobra run para aproveitar a compra. O
## plano pede a Loja entre 35% e 70% da progressao, e sem teto so metade disso e
## exigivel.
@export var distancia_maxima_da_origem: int = 0
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

## O KIT de parede do andar: topo e a face de recurso.
##
## UM campo, e nao uma duzia. Com a parede virando fita de modulos, cada tipo de
## sala precisaria de listas de topo e de variante -- e o plano avisa contra a
## explosao de `@export`. O `EstiloDeParede` reune isso e fica reusavel: as cinco
## salas do andar 1 apontam o MESMO recurso, porque elas sao o mesmo setor.
##
## A face do TIPO continua acima, em `texturas_face`, e nao aqui: desde a LTD 13
## e ela que diz de que sala se trata, e o estilo carrega o que e do ANDAR.
##
## Vazio cai na parede neutra em disco -- o mesmo caminho que a sala aberta
## sozinha no editor ja segue.
@export var estilo_de_parede: EstiloDeParede = null
## Atlas de props e QUAIS celulas dele esta sala pode usar. O atlas e um so
## para o jogo inteiro; a lista e o que da identidade -- a sala do chefe nao
## recebe o painel de acento da sala de arma.
@export var atlas_props: Texture2D
@export var regioes_props: Array[Rect2i] = []

## QUANTA decoracao esta sala recebe, e QUAO FUNDO ela entra.
##
## **Este recurso e o dono de QUANTOS; `DadosSala` continua dono de QUAIS.** A
## divisao e a que a `[FAB 17]` deixou declarada como divida: ela trocou a REGRA
## de colocacao por uma so (o `DecoradorDeSala`) e deixou as quatro contagens
## -- `quantidade_props`, `quantidade_props_volume`, `quantidade_decalques` e
## `quantidade_props_frente` -- aqui, para nao reescrever no mesmo passo os
## portoes que as validam. Elas sairam agora, e o campo delas nao ficou para
## tras: **campo que existe e campo que alguem gira**, e dois donos do mesmo
## numero e a armadilha que o `EstiloDeParede` (uma copia do perfil vencia o
## original) e a Loja (o `tipo` clonado mentia) ja cobraram deste repositorio.
##
## A traducao familia -> porte fica em `faixa_de_*()`, logo abaixo, num lugar so.
##
## Nulo = a sala nao recebe decoracao nenhuma. E o caso da sala montada a mao no
## editor e o de qualquer `DadosSala.new()` de suite: nao ha default util aqui
## de proposito, porque campo de decoracao com default util faz toda sala que o
## esqueceu AFIRMAR uma densidade que ninguem escolheu.
@export var perfil_de_decoracao: PerfilDeDecoracao = null

## O atlas de DECALQUES INDUSTRIAIS e as celulas dele que esta sala usa (#233).
##
## **Ele e separado do atlas de props chapados, e a separacao e de regime e nao
## de arrumacao.** `props_atlas.png` e GERADO e trancado pelo determinismo: o
## portao compara o PNG em disco com o que `gerar_texturas.gd` produz, byte a
## byte. Um decalque autorado colado ali quebraria essa comparacao para os doze
## props que ja estao la, e o sintoma seria "o gerador e o disco divergiram" --
## uma mensagem que aponta para o lugar errado.
##
## O decalque tambem tem familia propria no funil (`decalque`, teto de valor
## 0,19 contra 0,42 do prop), e por uma razao que o `TETO_VALOR` do teste ja
## registra: prop vive na margem calma e pode ter volume; decalque e chapado e
## vive ONDE O COMBATE ACONTECE -- o jogador anda por cima dele.
@export var atlas_decalques: Texture2D
@export var regioes_decalques: Array[Rect2i] = []

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

@export_group("Luz")
## Quantas LUMINARIAS a sala tenta prender na parede.
##
## O numero saiu de MEDIR a referencia (`docs/fabrica_01.png`) e nao da secao 97
## do briefing, e os dois discordam: ela pede "1 a 3 fontes funcionais" numa
## sala de combate, e a imagem tem SETE ou OITO pontos ambar mais um ciano.
##
## A diferenca nao e de gosto, e estrutural: a sensacao de "fabrica que ainda
## funciona precariamente" vem de a luz estar ESPALHADA E FRACA, e nao
## concentrada e forte. Tres lampadas fortes fazem tres holofotes; oito fracas
## fazem uma instalacao eletrica. A divergencia esta registrada em
## `docs/REFERENCIA_FABRICA.md`, secao 2.2.
##
## Nem toda uma acende: `PerfilDeLuz.chance_de_estar_ligada` decide lampada a
## lampada, e a carcaca APAGADA e metade do que conta a historia do abandono.
@export var quantidade_luminarias: int = 0
## O perfil da luz que estas luminarias usam. Nulo = a sala nao tem luz propria.
@export var perfil_de_luz: Resource

## Uma luminaria FRIA no lugar de uma ambar, quando a sala pede acento tecnico.
##
## Ela existe para o `[FAB 12]`: o tipo de sala deixou de ser separado por cor da
## PAREDE, e volta como indicador. Uma unica luz ciano num terminal diz "aqui ha
## equipamento" sem recolorir nada -- e a referencia tem exatamente UMA na sala
## inteira, contra sete ambar.
@export var perfil_de_luz_fria: Resource
@export var quantidade_luminarias_frias: int = 0

## A luz de TRABALHO: a lampada que fica sobre a bancada, e nao no perimetro.
##
## Ela nao acrescenta lampada nenhuma -- ela TROCA O PERFIL da vaga que a
## bancada ja ocupava. `_pontos_de_luminaria()` sempre serviu as bancadas
## primeiro, entao a lampada ja estava no lugar certo; o que faltava era ela ser
## DIFERENTE das outras.
##
## Duas coisas mudam, e as duas sao a mesma decisao vista de angulos opostos:
##
## - ela e mais forte e mais larga, porque a secao 59 pede que a bancada seja o
##   ponto mais claro da sala -- e com o perfil ambar comum ela era exatamente
##   igual as lampadas de parede, entao a sala nao tinha ponto mais claro
##   nenhum;
## - e ela NUNCA nasce apagada. O ambar comum tem `chance_de_estar_ligada` 0,7,
##   que e o que da ao andar o ar de coisa quebrada -- mas aplicado a lampada da
##   bancada isso apagava a maquina em ~30% das salas, e a unica peca que diz
##   "alguem trabalhava aqui" ficava no escuro. Quem carrega a ficcao de
##   abandono e o PERIMETRO; a bancada carrega a ficcao de uso.
##
## Nulo = a sala nao distingue, e toda lampada dela usa `perfil_de_luz`. E o
## caso da sala de combate e da inicial de proposito: elas ja passam a regua de
## massa da `[FAB 41]`, e mexer na luz delas mudaria um numero que esta bom.
@export var perfil_de_luz_de_trabalho: Resource

## O atlas das pecas PRESAS NA FACE da parede, e as celulas que esta sala usa.
##
## Tubo que corre pela parede, caixa de juncao, duto. **Elas nao sao prop de
## chao nem Foreground**, e e por isso que precisaram de lista propria: o prop
## de chao mora em `Z_CHAO_DETALHE` ou `Z_MUNDO` e se ordena contra o jogador; o
## Foreground mora acima de tudo. Uma peca presa na parede fica ENTRE os dois --
## sobre a face, e atras de qualquer ator.
##
## O porte `PAREDE` existe no `DecoradorDeSala` desde a `[FAB 07]` e ate aqui so
## a luminaria o consumia. O plano registrava a divida com todas as letras:
## "peca presa na FACE nao e nem prop de chao nem foreground. Liga-lo ao atlas
## errado seria pior que deixa-lo esperando."
##
## **As celulas sao mais LARGAS que altas, ao contrario das volumetricas.** Um
## tubo corre na horizontal ao longo da parede, e a face tem `Sala.ALTURA_FACE`
## = 32 px de altura -- uma celula de 32x64 nao caberia nela sem invadir o topo,
## que e a espessura vista de cima e nao superficie vertical. Por isso este
## atlas e separado do volumetrico, cujo portao cobra exatamente o contrario.
## O ATLAS DOS CANOS, e eles sao a LIGACAO entre as pecas de uma bancada.
##
## **Eles sao a resposta a "as conexoes com canos... entre si dos moveis com a
## sala deve ser evidente".** Uma bancada e uma fileira de maquinas encostadas; o
## que faz o olho ler "instalacao" em vez de "moveis lado a lado" e alguma coisa
## ATRAVESSANDO as duas. O cano corre ATRAS delas (`Z_FITA + 1`, abaixo do
## `Z_MUNDO` dos volumes) e so aparece nos vaos -- entao ele entra em cada
## maquina por OCLUSAO, sem precisar de peca de encaixe desenhada.
##
## Sao dois trechos e nao um: numa parede norte a bancada corre leste-oeste e o
## cano e horizontal, visto de FRENTE; numa lateral ela corre norte-sul e o cano
## e visto de CIMA. Mesma razao que da duas vistas a cada prop, e a mesma que
## impede girar a arte de face.
##
## Cada trecho e UNIFORME ao longo do comprimento de proposito: assim qualquer
## recorte dele serve para qualquer vao, e nao ha uma peca por largura.
@export var atlas_canos: Texture2D
@export var regiao_cano_horizontal: Rect2i = Rect2i()
@export var regiao_cano_vertical: Rect2i = Rect2i()

@export var atlas_props_parede: Texture2D
@export var regioes_props_parede: Array[Rect2i] = []

## Props que aparecem em UMA sala do andar, e so.
##
## O caso vivo e o Robo Desativado: ele e o que faz o jogador perceber que o
## setor usava robos muito antes de encontrar o chefe. Isso funciona uma vez.
## Repetido em cinco salas ele vira mobilia, e a descoberta que ele existe para
## plantar deixa de acontecer -- e o plano do andar pede "com extrema
## moderacao" com todas as letras.
##
## Sao regioes do MESMO atlas volumetrico, e nao um sistema paralelo: o que muda
## e quem pode sortea-las. Quem decide a sala sorteada e o `GerenciadorMapa`,
## porque "uma por ANDAR" e uma pergunta que nenhuma sala consegue responder
## sozinha.
@export var regioes_props_raras: Array[Rect2i] = []


## ------------------------------------------------- quanta decoracao ---------
##
## As quatro familias de prop da `Sala` traduzidas para os portes do
## `PerfilDeDecoracao`. Elas devolvem a FAIXA (`min`, `max`) e nao um numero: o
## perfil declara intervalo, e quem sorteia dentro dele e a `Sala`, com o `rng`
## da propria celula -- assim a mesma sala devolve sempre a mesma densidade e
## salas diferentes nao ficam todas com a mesma contagem.
##
## **Esta e a unica traducao familia -> porte do projeto**, pelo mesmo motivo
## que `DecoradorDeSala.faixa_de_porte()` e a unica traducao porte -> campo:
## duas copias divergem, e o sintoma aparece em TELA e nunca no console.
##
##   chapado      MICRO           -- o objeto pequeno visto de cima, sem volume
##   volumetrico  HERO + GRANDE + MEDIO + PEQUENO  -- tudo que tem corpo
##   decalque     DECALQUE        -- chao pintado
##   frente       contagem_frente -- a camada que passa por cima do ator
##
## O volumetrico soma QUATRO portes porque a `Sala` nao separa por porte: o
## tamanho de cada peca sai da REGIAO sorteada no atlas, e nao de um campo. Ate
## a arte declarar o proprio porte (`[FAB 22-27]`), somar e o unico jeito
## honesto de nao perder as quatro contagens dentro de uma so.
func faixa_de_props_chapados() -> Vector2i:
	return DecoradorDeSala.faixa_de_porte(perfil_de_decoracao, DecoradorDeSala.Porte.MICRO)


func faixa_de_props_volume() -> Vector2i:
	if perfil_de_decoracao == null:
		return Vector2i.ZERO
	var soma := Vector2i.ZERO
	for porte in [
		DecoradorDeSala.Porte.HERO, DecoradorDeSala.Porte.GRANDE,
		DecoradorDeSala.Porte.MEDIO, DecoradorDeSala.Porte.PEQUENO,
	]:
		soma += DecoradorDeSala.faixa_de_porte(perfil_de_decoracao, porte)
	return soma


## Que CELULAS do atlas cada porte pode usar, em faixas de area.
##
## **Ela saiu da `Sala`, e a mudanca nao e arrumacao.** `Sala._regiao_do_porte()`
## sorteava a regiao DEPOIS de o `DecoradorDeSala` ja ter decidido a vaga: o
## decorador escolhia ONDE sem saber o TAMANHO, e a `Sala` escolhia o tamanho sem
## poder mudar o lugar. Nenhum dos dois podia responder "esta peca cabe aqui?", e
## e por isso que o vaso de pressao de 96x160 desenhava 92 px fora da parede sem
## um erro no console.
##
## Com o catalogo na mao, o decorador passa a escolher o GABARITO QUE CABE
## naquele ponto -- e o HERO de 160 px continua existindo no sul, no leste e no
## oeste, onde nada vaza, enquanto a parede norte recebe a peca mais baixa. Um
## teto global de altura teria custado a peca de leitura da sala nos quatro
## lados para salvar um deles.
##
## As quatro faixas sobre a lista ordenada por AREA sao as mesmas de antes, e
## fatiar em vez de cravar tamanhos e o que faz o mapeamento sobreviver a um
## atlas que cresca: com dez pecas ou com quarenta, HERO continua pegando do topo.
##
## Por AREA e nao por largura: com as celulas altas (96x160, 64x128) a largura
## deixou de ordenar -- uma esteira de 96x64 e mais larga que um armario de
## 64x128 e muito menor que ele.
## **As regioes vem em PARES: `[frente_0, ponta_0, frente_1, ponta_1, ...]`.**
##
## Uma peca encostada na parede NORTE mostra a FRENTE dela e corre com o eixo
## longo leste-oeste, paralelo ao muro. A mesma peca na parede LESTE tem de
## correr norte-sul para encostar -- e dai o que a camera ve e a PONTA dela, com
## outra silhueta e outra largura. Sao duas artes, e nao uma girada: girar arte
## de FACE destroi a perspectiva, e isso e decisao fechada do projeto.
##
## Sem o par, um motor largo colocado na parede leste aponta o comprimento para
## DENTRO da sala, com uma quina no muro e um vao atras -- que e exatamente a
## reclamacao do dono: *"usar a orientacao reta, norte-sul ou leste-oeste, para
## que caiba encostado na parede"*.
##
## O SUL reusa a frente e o OESTE reusa a ponta. Medido numa peca de teste, a
## vista de costas de uma maquina cilindrica sai quase identica a de frente --
## gerar as quatro produziria duas artes iguais e mais atlas. Peca com frente
## FORTE (armario, bancada, painel) ganha uma vista de costas propria quando ela
## for desenhada; ate la a divida esta declarada aqui.
func gabaritos_de_volume() -> Dictionary:
	var saida := {}
	if regioes_props_volume.size() < 2:
		return saida
	var pares: Array[Dictionary] = []
	for i in range(0, regioes_props_volume.size() - 1, 2):
		pares.append({
			"frente": regioes_props_volume[i],
			"ponta": regioes_props_volume[i + 1],
		})
	# Ordenadas pela area da FRENTE, que e a vista canonica da peca. Usar a maior
	# das duas faria a mesma peca trocar de porte conforme o lado em que caisse.
	pares.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var ra: Rect2i = a["frente"]
			var rb: Rect2i = b["frente"]
			return ra.size.x * ra.size.y > rb.size.x * rb.size.y)
	var por_area := pares
	var n := por_area.size()
	var faixas := [
		Vector2i(0, maxi(1, n / 4)),
		Vector2i(n / 4, maxi(n / 4 + 1, n / 2)),
		Vector2i(n / 2, maxi(n / 2 + 1, n * 3 / 4)),
		Vector2i(n * 3 / 4, n),
	]
	for porte in 4:
		var faixa: Vector2i = faixas[porte]
		var inicio := clampi(faixa.x, 0, n - 1)
		var fim := clampi(faixa.y, inicio + 1, n)
		var lote: Array[Dictionary] = []
		for i in range(inicio, fim):
			lote.append(por_area[i])
		saida[porte] = lote
	return saida


## A vista que uma peca mostra quando encosta naquele lado.
##
## Publica e estatica porque o portao precisa da mesma resposta: duas tabelas de
## "que lado usa que vista" divergem, e a divergencia seria a peca desenhando uma
## silhueta e reservando o chao de outra.
static func vista_do_lado(gabarito: Dictionary, lado: int) -> Rect2i:
	if lado == DecoradorDeSala.Lado.LESTE or lado == DecoradorDeSala.Lado.OESTE:
		return gabarito.get("ponta", Rect2i())
	return gabarito.get("frente", Rect2i())


func faixa_de_decalques() -> Vector2i:
	return DecoradorDeSala.faixa_de_porte(perfil_de_decoracao, DecoradorDeSala.Porte.DECALQUE)


func faixa_de_props_frente() -> Vector2i:
	return perfil_de_decoracao.contagem_frente if perfil_de_decoracao != null else Vector2i.ZERO


func faixa_de_props_parede() -> Vector2i:
	return DecoradorDeSala.faixa_de_porte(perfil_de_decoracao, DecoradorDeSala.Porte.PAREDE)


## Quao fundo, a partir do contorno, a decoracao desta sala pode entrar.
##
## **Ela era a segunda metade da divida da `[FAB 17]`, e a mais cara das duas.**
## A `Sala` tinha `PROP_AFASTAMENTO_MAXIMO = 44` enquanto o perfil declarava 96,
## e as cenas de sala autoram uma margem de exatamente 96 px entre o contorno e
## a `area_spawn` (medido em `sala_1_retangular`: contorno 768x640, area
## 576x448). Com 44, e com a `posicoes()` exigindo meio prop de folga contra a
## parede, a faixa util de uma peca de 64 media DOZE pixels -- praticamente uma
## linha. Era isso, e nao a falta de arte, que fazia a sala montada com o Batch 1
## continuar parecendo vazia.
##
## Sem perfil nao ha decoracao para colocar; o numero so serve as luminarias,
## que tem contagem propria, e para elas a faixa antiga continua valendo.
func largura_da_faixa_de_decoracao() -> float:
	if perfil_de_decoracao == null:
		return FAIXA_SEM_PERFIL
	return perfil_de_decoracao.largura_da_faixa_de_perimetro


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
	var faixa := faixa_progressiva(lista, fracao)
	if faixa.is_empty():
		return null
	# absi() porque hash() devolve negativo, e o modulo de negativo em GDScript
	# devolve negativo -- indice negativo aqui seria um crash intermitente.
	return faixa[absi(semente) % faixa.size()]


## O TERCO da lista que este ponto do andar pode usar.
##
## A conta dos tercos mora aqui e nao em dois lugares: quem sorteia UMA textura
## (`textura_progressiva`) e quem precisa da FATIA inteira -- a fita de modulos,
## que sorteia por celula e nao por lado -- leem a mesma divisao. Duas copias
## divergiriam com o sintoma aparecendo em tela e nunca no console: metade do
## andar vestindo o terco errado.
func faixa_progressiva(lista: Array[Texture2D], fracao: float) -> Array[Texture2D]:
	var validas: Array[Texture2D] = []
	for t in lista:
		if t != null:
			validas.append(t)
	if validas.is_empty():
		return validas
	var n := validas.size()
	# clampi antes de int(): fracao 1.0 daria terco 3, que e fora da lista.
	var terco := clampi(int(clampf(fracao, 0.0, 1.0) * 3.0), 0, 2)
	var inicio := (terco * n) / 3
	var fim := ((terco + 1) * n) / 3
	if fim <= inicio:
		fim = inicio + 1
	fim = mini(fim, n)
	return validas.slice(inicio, fim)


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
## Chance de esta sala conter uma Unidade Aprimorada.
##
## **Zero na inicial, na de arma, na de item e na do chefe**, e isso e a mesma
## garantia em duas pontas que ja impede inimigo nelas: o tipo declara, e o
## portao cobra. No chefe a razao e outra e mais forte -- ele ja e a excecao do
## andar, e uma aprimorada ali competiria com a leitura dele.
##
## 0,25 na sala de combate da uma a cada tres a seis salas com o cooldown do
## gerenciador por cima. **Chance por sala e frequencia percebida nao sao o mesmo
## numero**, e e o cooldown que separa os dois.
@export var chance_de_aprimorada: float = 0.0

@export_group("Premio de limpeza")
## Chance de limpar esta sala pagar creditos, e a faixa do que ela paga.
##
## **Zero nas salas sem combate**, e nao por economia: pagar por "limpar" uma
## sala que nunca teve inimigo transformaria atravessar o andar numa fonte de
## renda, e o jogador passaria a andar em circulos em vez de lutar. A garantia e
## a mesma de duas pontas que ja impede inimigo nelas.
@export var chance_de_premio: float = 0.0
@export var premio_minimo: int = 2
@export var premio_maximo: int = 5


func orcamento_para(area_px: float) -> int:
	var teto := maxi(orcamento_maximo, orcamento_minimo)
	if densidade <= 0.0 or area_px <= 0.0:
		return clampi(orcamento_minimo, 0, teto)
	var bruto := int(floorf(area_px / AREA_DE_REFERENCIA * densidade))
	return clampi(bruto, orcamento_minimo, teto)
