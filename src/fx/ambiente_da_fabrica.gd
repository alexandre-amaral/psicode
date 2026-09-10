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
## `1.0` seria "sem escurecimento". O piso vem do `laboratorio_luz`, que mede o
## degrau entre as superficies: abaixo de ~0,30 aquele degrau fecha e a
## arquitetura some junto com a sombra.
##
## Ele e `@export` e nao `const` porque e exatamente o tipo de numero que a
## sessao de tuning vai querer girar com a tela na frente.
##
## ## POR QUE 0,75, e nao os 0,45 que este arquivo defendeu por duas issues
##
## **Porque a `[FAB 45]` mediu o resultado e ele nao era o que a `[FAB 19]`
## supunha.** Com 0,45 o andar dava **95% de PRETO** (valor <= 0,10) contra os
## 50,75% da referencia, e o cinza azulado -- a superficie que na referencia
## ocupa 35% -- ficava em **0,66%**. A referencia e escura E tem superficie
## legivel; o andar so tinha a primeira metade.
##
## E a alavanca era esta, e nao a que o plano supunha. A nota do `medir_ambiente`
## dizia "a referencia tem sete a oito lampadas por sala e o andar tem tres a
## cinco", e dai se conclui que faltam lampadas. Medido em
## `prova_de_leitura.tscn -- --luz`, cruzando as duas:
##
##     dobrar as lampadas (5 -> 11)   move  3,2 pontos de preto
##     o ambiente (0,45 -> 0,85)      move 46,9 pontos
##
## **A lampada e uma POCA**: ela soma brilho num circulo e deixa o resto do piso
## onde estava. Quem decide quanta superficie o andar mostra e este numero.
##
## 0,75 e a linha em que as duas metades da referencia aparecem juntas -- 69% de
## preto contra 17% de superficie -- sem chegar a 0,85, onde o andar deixa de ser
## escuro e a poca perde o contraste que a justifica.
##
## O que continua valendo da versao anterior deste bloco e a regra que a
## originou: **ambiente escuro MAIS `Light2D` devolvendo luz nos bolsoes**, nunca
## ambiente escuro sozinho. Baixar este numero sem lampada que compense apaga o
## ator junto com o piso.
##
## `teste_luz.AMBIENTE_DA_RUN` e gemeo deste valor e muda junto -- uma copia que
## envelhece faria aquele portao medir um ambiente que o jogo nao usa.
@export_range(0.15, 1.0, 0.01) var luminosidade: float = 0.75:
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
