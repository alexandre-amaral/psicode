class_name AmbienteDaFabrica
extends CanvasModulate
## A ESCURIDAO DE BASE do andar: a fabrica sem uma luz acesa.
##
## Ela existe porque a referencia medida (`docs/fabrica_01.png`) e, antes de
## tudo, ESCURA: **50,75% do quadro esta em valor 0,10 ou menos**. A "sombra
## profunda" que o briefing pede nao e um efeito ocasional -- e a maior parte da
## imagem, e e contra ela que os bolsoes de luz existem.
##
## **Ela NAO deixa preto, e esse e o limite** (secao 16 do briefing). O jogador
## tem de continuar vendo piso, parede e obstaculo mesmo sem lampada nenhuma
## por perto: o `laboratorio_luz` mede o degrau entre o chao e o topo da parede
## e cobra um minimo. Escuridao que apaga a arquitetura nao e atmosfera, e um
## bug de contraste.
##
## ## Onde ela mora, e por que NAO no `.tscn` da sala
##
## Ela e filha do `Mundo` em `src/main/main.tscn`, e nao das cenas de sala. Duas
## razoes, e as duas ja custaram tempo neste projeto:
##
## 1. **A HUD nao pode escurecer junto.** `CanvasModulate` vale para a arvore de
##    canvas em que vive; a HUD e um `CanvasLayer` proprio e fica de fora por
##    construcao. Posta na sala, ela ainda funcionaria -- mas ficaria repetida
##    em nove cenas, que e a definicao de nove fontes para a mesma verdade.
## 2. **As reguas de `tools/` continuam limpas.** `medir_moldura`,
##    `formas_paredes` e `comparar_caixa` montam sala sozinha e MEDEM PIXEL. Se
##    o escurecimento morasse na sala, todas elas passariam a medir a sala
##    escurecida e os numeros historicos daqueles portoes (espessura de corpo,
##    dispersao entre lados, densidade) mudariam de significado de uma vez, sem
##    a arte ter mudado. Ambiente e propriedade da RUN, e nao da sala.
##
## O `Lobby` tambem nao a recebe de proposito: ele e o lugar sem perigo, e a
## mesma razao que tira dele a barra de Deterioracao e o disparo tira dele a
## escuridao.

## Quanto do brilho original sobra quando nenhuma luz alcanca o ponto.
##
## `1.0` seria "sem escurecimento". O alvo veio do `laboratorio_luz`, que mede
## o degrau entre as superficies: com 0,45 o chao fica em luma 0,020 e o topo da
## parede em 0,114 -- um degrau de 0,094, bem acima do minimo de 0,035 que a
## ferramenta cobra. Abaixo de ~0,30 aquele degrau fecha e a arquitetura some
## junto com a sombra.
##
## Ele e `@export` e nao `const` porque e exatamente o tipo de numero que a
## sessao de tuning vai querer girar com a tela na frente.
##
## ## POR QUE ELE NAO ESTA EM 0,45 HOJE
##
## **Porque `CanvasModulate` escurece os ATORES junto, e sem luminaria nao ha o
## que devolva.** Medido em captura: com 0,45 e nenhuma luz na sala, o jogador,
## os inimigos e o detalhe do piso somem juntos -- e a regra numero um deste
## projeto e que o ambiente seja SEMPRE mais escuro que ator e projetil. Um
## ambiente que escurece os dois na mesma proporcao nao cria contraste nenhum,
## so tira luz de todo mundo.
##
## O pipeline certo e o do briefing: ambiente escuro MAIS `Light2D` devolvendo
## luz nos bolsoes. As luminarias JA existem (`[FAB 19]`: `LuminariaDeParede`,
## cinco por sala de combate), e o `PointLight2D` renderiza -- provado num caso
## minimo isolado. **O que ainda nao existe e a CALIBRAGEM do brilho.**
##
## Medido: com o perfil como esta (`cor` V 0,48 x `energia` 0,85), a poca some
## no chao escurecido; turbinado para V 1,0 x 3,0 ela aparece, mas subtil e
## ainda concentrada na parede em vez do piso.
##
## A causa e uma decisao de design que precisa ser tomada e nao adivinhada: o
## `PerfilDeLuz` foi autorado contra `Paleta.compete_com_ator`, que e a regra
## das SUPERFICIES PINTADAS do ambiente. Aplicada a uma FONTE DE LUZ ela obriga
## a lampada a ser escura demais para iluminar. O teto honesto e sobre o
## RESULTADO -- quanto a poca deixa o chao brilhar --, e nao sobre o swatch da
## lampada; e achar esse numero pede o `laboratorio_luz` com janela.
##
## **Entao 0,45 e o ALVO e 0,72 e o estado.** Os dois numeros ficam escritos
## aqui de proposito: um valor de compromisso sem o alvo ao lado vira o valor
## definitivo por esquecimento, e ninguem descobre que a outra metade nunca
## chegou.
@export_range(0.15, 1.0, 0.01) var luminosidade: float = 0.45:
	set(valor):
		luminosidade = valor
		_aplicar()

## A TINTA da sombra, e ela e FRIA de proposito (secao 18 do briefing).
##
## Sombra azulada contra foco ambar e o que da profundidade sem neon: as duas
## temperaturas se separam sozinhas, e o olho le distancia onde ha so diferenca
## de cor. Sombra neutra deixaria a sala cinza e chapada, e sombra quente
## competiria com as proprias lampadas.
##
## Ela e sutil por escolha -- o azul entra como VIES do cinza, e nao como cor.
## `Paleta` proibe ambiente saturado, e escurecer com azul forte pintaria o
## andar inteiro de azul em vez de escurece-lo.
@export var tinta: Color = Color(0.82, 0.88, 1.0):
	set(valor):
		tinta = valor
		_aplicar()


func _ready() -> void:
	_aplicar()


func _aplicar() -> void:
	# `color` multiplica tudo que esta abaixo dela na arvore de canvas. A tinta
	# entra normalizada pela luminosidade para os dois botoes serem
	# independentes: mexer na cor nao pode escurecer, e mexer na escuridao nao
	# pode tingir.
	color = Color(
		tinta.r * luminosidade,
		tinta.g * luminosidade,
		tinta.b * luminosidade,
		1.0,
	)
