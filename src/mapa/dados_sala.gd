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
## As texturas que a Sala monta em codigo no _ready, a partir do contorno. Sao
## os PNGs de assets/texturas/, gerados por tools/texturas/gerar_texturas.tscn
## a partir da paleta (docs/IDENTIDADE_VISUAL.md) -- nunca de editor de imagem.
## Campo vazio cai na variante `combate`, que e a neutra do andar; o teste de
## texturas recusa tipo sem as tres declaradas, para o fallback nao virar
## disfarce de esquecimento.
@export var textura_chao: Texture2D
@export var textura_parede: Texture2D
@export var textura_filete: Texture2D
## Atlas de props e QUAIS celulas dele esta sala pode usar. O atlas e um so
## para o jogo inteiro; a lista e o que da identidade -- a sala do chefe nao
## recebe o painel de acento da sala de arma.
@export var atlas_props: Texture2D
@export var regioes_props: Array[Rect2i] = []
## Quantos props a sala tenta colocar na margem entre a parede e a area de
## spawn. Zero desliga a decoracao.
@export var quantidade_props: int = 0


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
