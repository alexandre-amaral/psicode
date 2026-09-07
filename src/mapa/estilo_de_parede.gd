class_name EstiloDeParede
extends Resource
## O KIT de parede de um andar: de que material ele e feito.
##
## Ele existe para separar duas coisas que estavam no mesmo lugar: **a geometria
## da sala** e **a identidade do andar**. A forma de uma sala e o `.tscn` dela
## mais o `DadosSala` que diz onde ela pode nascer; o MATERIAL com que a parede
## dela e vestida passa a ser isto. A mesma sala logica pode virar setor
## industrial, laboratorio ou nucleo sem tocar em uma linha da geracao
## procedural.
##
## **`DadosSala` ganha UM campo, e nao uma duzia.** Com a parede virando fita de
## modulos, cada tipo de sala precisaria de listas de topo, de face, de canto e
## de variante -- e o plano avisa contra a explosao de `@export`. Um recurso
## apontado por um campo resolve, e de quebra deixa o kit reusavel entre tipos:
## as cinco salas do andar 1 compartilham o MESMO estilo, porque elas sao o mesmo
## setor.
##
## **O que ele NAO carrega e a face por tipo de sala.** Desde a LTD 13 a face e
## quem diz de que sala se trata -- combate ciano, chefe rosa, arma ambar --, e
## isso continua morando em `DadosSala.texturas_face`. O estilo carrega o que e
## do ANDAR: o topo, que e neutro e compartilhado desde a PAR 04, e a face de
## recurso para quem nao declarar a propria.
##
## A divisao entre os dois se le assim:
##
##   ESTILO      o andar    topo, face neutra
##   DadosSala   a sala     face do tipo, chao, props, regras de colocacao

## O nome do kit, para o Inspetor e para mensagem de erro.
@export var id: StringName = &""

## Os TOPOS, sorteados por celula. Neutros e compartilhados por todo tipo de
## sala: a identidade mora na face, e cinco copias da mesma lista divergiriam no
## dia em que alguem mudasse quatro.
@export var topos: Array[Texture2D] = []

## A face de recurso, usada por quem nao declara `texturas_face`.
@export var face_neutra: Texture2D = null

## Os DECALQUES de topo do andar (#244): evidencia localizada de abandono.
##
## Eles ficam FORA da chapa de proposito. Uma solda desenhada dentro dos 64x64 do
## tile aparece tres vezes por sala em posicoes sorteadas -- a sala deixa de ter
## uma solda e passa a ter um padrao de soldas. Como overlay ela aparece UMA vez,
## onde faz sentido.
##
## E a base fica passavel nos portoes: amplitude, subordinacao e material sao
## medidos numa chapa limpa, e o desgaste nao precisa negociar com eles.
@export var decalques_de_topo: Array[Texture2D] = []

## Com que frequencia um trecho de topo recebe decalque.
##
## **0,14 e um numero e nao uma opiniao**, e ele e irmao de `max_props_animados`:
## se todo trecho tiver uma solda, nenhuma solda significa nada. A issue pede a
## faixa 0,10-0,18 e o default fica no meio dela.
@export_range(0.0, 1.0, 0.01) var chance_de_decalque: float = 0.14

@export_group("Variacao")

## Quanto da parede e o modulo COMUM.
##
## O plano manda o comum dominar, e o motivo nao e economia: **ruido na borda
## compete com o que o jogador precisa ler no meio.** E o mesmo argumento que
## `max_props_animados` ja carrega -- "se tudo se mover, nada parece importante" e
## um NUMERO, e nao uma opiniao, porque opiniao nao sobrevive a proxima pessoa que
## achar o ventilador bonito.
##
## 0,65 sai do plano. Ele e por FAMILIA e nao por modulo: as especiais dividem os
## 35% restantes por igual, porque hoje elas nao sao TIPADAS -- a lista de faces
## de um tipo de sala e uma lista, e nao um catalogo com nomes. Peso por tipo de
## modulo (painel 12%, tubo 10%, desgaste 8%, ventilacao 5%) entra quando o kit
## industrial trouxer a biblioteca nomeada; inventar os quatro numeros agora seria
## cravar uma tabela que ninguem consegue girar.
## 0,80 e nao 0,65, e a mudanca vem da MOLDURA 15.
##
## Ate a faixa continua, este numero era a fracao de CELULAS que vestiam o
## modulo comum -- 65% delas, com as especiais salpicadas ao longo do lado.
## Agora ele e a fracao de LADOS: uma escolha por lado, tiladada no trecho
## inteiro. Um lado que sorteia `ventilada` vira uma parede de grades de ponta a
## ponta, e nao uma parede com uma grade.
##
## O plano pede **80% parede limpa, 20% detalhe**, com grandes regioes vazias --
## e com a escolha por lado, 0,80 entrega literalmente isso: em cinco lados,
## um veste especial.
@export_range(0.0, 1.0, 0.01) var peso_comum: float = 0.80

## Quantas celulas COMUNS tem de haver entre duas especiais.
##
## `vent + vent + vent` por sorteio puro nao pode acontecer, e o plano pede
## espacamento minimo. Duas celulas e o piso: com uma, duas especiais encostam e
## a parede ganha um bloco de ruido; com zero, o peso sozinho nao impede a
## sequencia -- ele so a torna improvavel, e improvavel acontece.
@export_range(0, 8, 1) var espacamento_minimo: int = 2


## Este estilo esta montado o bastante para vestir uma parede?
##
## Irma de `ClipeDirecional.desenhavel()` e de `SpriteDirecional.tem_ciclo()`, e
## pelo mesmo motivo: quem pergunta nao precisa saber que "desmontado" quer dizer
## lista vazia.
func vestivel() -> bool:
	return not topos.is_empty()


@export_group("Espessura desenhada")
## Quanto cada lado DESENHA, do contorno para fora. **-1 = herda o default.**
##
## O sentinela e NEGATIVO e nao zero pela mesma razao do `Escalonamento` dos
## inimigos: zero e um valor valido aqui -- um lado que nao desenha face tem
## `face = 0` de verdade --, entao zero como "herda" transformaria um ajuste
## legitimo em "nao faz nada", em silencio.
##
## **Ele existe porque estes campos ja foram uma SEGUNDA COPIA dos mesmos
## numeros, e a copia venceu.** Eram literais (16/24, 16/16, 16), que sao o
## perfil C -- de antes do epico da profundidade --, e `perfil()` os escrevia por
## cima de um `PerfilDeParede` recem-criado. Efeito: o Lobby, que nao passa
## perfil e cai no default, recebeu o epico inteiro; **as salas do andar 1, que
## passam por aqui, nunca receberam nada.** Duas entregas de parede foram
## medidas, aprovadas e nao chegaram ao jogo.
##
## E `borda_externa_sul` nem estava na lista, entao ela vazava o default no meio
## de um perfil que deveria ser inteiro do estilo -- um perfil metade de um
## lugar, metade de outro.
##
## A COLISAO nao muda: ela e um segmento sobre o contorno, e a grade logica
## continua 32. Isto descreve so o que se desenha.
##
## **NOVE CAMPOS VIRARAM TRES, e a reducao e o entregavel.** Havia um campo por
## lado -- `face_norte`, `face_lateral`, `labio_sul`, `ledge_sul`... --, e foi
## essa liberdade que produziu norte 48 / lateral 28 / sul 24. O estilo PERMITIA
## a divergencia, entao ela aconteceu. Hoje o corpo e um numero e os quatro lados
## o leem; a assimetria de outro andar, se um dia existir, passa pelos `escala_*`
## do perfil, que sao uma declaracao visivel em vez de nove botoes soltos.
@export var corpo: float = -1.0
@export var cap: float = -1.0
@export var sombra_de_contato: float = -1.0
@export var chanfro_de_canto: float = -1.0
@export var margem_exterior: float = -1.0


## O perfil que o renderizador consome.
##
## Comeca no DEFAULT e so sobrescreve o que este estilo declarou. Assim o estilo
## continua sendo o botao de tuning que ele foi feito para ser, sem ser tambem
## uma copia silenciosa da regra.
func perfil() -> PerfilDeParede:
	var p := PerfilDeParede.new()
	if corpo >= 0.0:
		p.corpo = corpo
	if cap >= 0.0:
		p.cap = cap
	if sombra_de_contato >= 0.0:
		p.sombra_de_contato = sombra_de_contato
	if chanfro_de_canto >= 0.0:
		p.chanfro_de_canto = chanfro_de_canto
	if margem_exterior >= 0.0:
		p.margem_exterior = margem_exterior
	return p
