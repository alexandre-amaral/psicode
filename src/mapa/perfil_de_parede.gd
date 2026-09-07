class_name PerfilDeParede
extends RefCounted
## Quanto a parede DESENHA. Um numero, e os quatro lados nao podem divergir.
##
## **A sala e uma caixa aberta vista de cima.** Essa frase decide este recurso, e
## ela reverte a assimetria que ele carregou por um epico inteiro.
##
## A versao anterior dava um perfil proprio a cada lado -- norte 48 de face, a
## lateral 28, e o sul uma soleira de 4+20+8 sem face nenhuma --, com o argumento
## de que a camera e uma so e cada lado esta numa relacao diferente com ela. O
## argumento e verdadeiro em perspectiva e falso em LEITURA, e o jogo mostrou
## qual das duas importa (baseline em `baseline_assimetrico/`, luma da coluna
## central):
##
##     vazio 6  |  cap 48  |  corpo 44  |  contato 9  |  piso 17
##
## com a lateral em 36 px e o sul em 32. As quinas diziam "ha uma moldura"; os
## lados diziam "ha um acabamento". Numa caixa aberta vista de cima as quatro
## paredes tem a mesma espessura, e a perspectiva vem do chanfro, da sombra e da
## orientacao da textura -- **nunca da diferenca de massa entre os lados**.
##
## **A correcao nao foi escolher valores iguais nos nove campos: foi tirar do
## recurso a capacidade de divergir.** Enquanto houvesse um campo por lado,
## alguem os giraria em separado -- foi exatamente o que aconteceu. Hoje ha UM
## numero de corpo, e os quatro lados o leem.
##
##     NORTE, SUL, LESTE e OESTE, todos:
##
##       exterior
##       ------- cap 12 -------
##       ####### corpo 48 #####
##       ~~~~~ sombra 4 ~~~~~~~
##            PISO
##
## O SUL cresce para FORA da area jogavel, como os outros. A maior parte dele
## fica abaixo do piso na tela, entao ele nao cobre o jogador e nao precisa de
## foreground nenhum -- que era o medo que o transformou em soleira.
##
## **A COLISAO NAO MUDA.** Ela continua sendo um segmento sobre o contorno, e a
## grade logica continua 32 para geracao, porta, mapa e posicionamento. O que
## este recurso descreve e so o que se DESENHA -- e separar as duas coisas
## continua sendo o plano inteiro: dimensao logica nao e dimensao desenhada.

## O CORPO da parede: a massa, e a autoridade estrutural do recurso.
##
## E onde vivem os paineis verticais, a corrosao, a tubulacao, os cabos e a
## ventilacao -- tudo que diz "fabrica abandonada". 48 px e o que devolve espaco
## suficiente para essas categorias voltarem a ser reconheciveis; abaixo disso a
## face vira uma tira e o material deixa de ler.
##
## **48 CONTINUA, e o degrau de 56 foi testado e devolvido.** O dono olhou o jogo
## e disse que a parede continuava fina. A medicao concordou com a queixa e
## discordou do diagnostico:
##
##     corpo    chao     faixa    vazio      (sala_1, jogador no centro)
##       48    80,2%     11,4%     7,3%
##       52    80,2%     12,1%     6,5%
##       56    80,2%     12,8%     5,6%
##
## **O chao nao se move.** A `sala_1_retangular` tem 768 px e o eixo X esta
## FECHADO: `768 + 120 de parede + 72 de vazio = 960` exato. Entao a fracao de
## chao e a razao `768/960`, e engrossar a parede so troca vazio por parede.
##
## O degrau de 56 tinha um ganho real -- o vazio ia de 35 px por lado para 27,
## dentro da faixa de 16 a 24 que a secao 31 pede -- e um custo medido: a
## `sala_5_pilar` caia de 3 para 2 patamares de valor em `formas_paredes`. Trocar
## uma leitura que passa por 1,4 ponto de faixa nao paga.
##
## **Quem manda na dominancia do chao e o TAMANHO DA SALA, e nao esta constante.**
## E 48 tem uma propriedade que 56 nao tem: com margens de 80, uma sala de 384 px
## de altura fecha o eixo Y em 544 EXATO. Com 88 nao fecha em altura nenhuma da
## grade.
##
## Os unicos valores permitidos sao 44, 48, 52 e 56, e **o mesmo nos quatro
## lados**. E a razao de este recurso existir.
var corpo: float = 48.0

## O CAP: o acabamento externo, e so isso.
##
## Ele foi resolvido no epico anterior e nao se toca. A tentacao que este arquivo
## precisa resistir e engrossa-lo para "dar corpo" quando a parede parecer fina
## -- isso reabriria o defeito que o cap de 40 px produzia, em que a faixa de
## cima lia como um segundo PISO em volta da sala.
##
## `corpo > cap` sempre, e o portao cobra.
var cap: float = 12.0

## A SOMBRA DE CONTATO, e ela existe nos QUATRO lados.
##
## E o unico numero que cresce para DENTRO do piso, e e o que comunica que o piso
## esta abaixo e a parede acima. No modelo antigo o sul nao tinha nenhuma, e era
## isso que fazia o piso parecer TERMINAR ali em vez de descer.
##
## Ela e o segundo anel: continua em volta de todo o contorno, chanfro incluido.
var sombra_de_contato: float = 4.0

## O CHANFRO das quinas, e ele foi aprovado -- o angulo nao se toca.
##
## O contorno interno recua 48 px na diagonal em cada quina convexa, e as faixas
## acompanham: corpo, cap e sombra convergem para o piso em vez de se encontrarem
## em esquadro. Uma quina de 90 graus comunica planta baixa; esta comunica volume.
##
## Ele vive na GEOMETRIA e nao em arte. Um PNG de canto voltaria a ser a peca
## quadrada que a meia-esquadria removeu, e a textura precisa atravessar a quina.
##
## 48 e multiplo de 16, entao o contorno chanfrado continua na grade que
## `teste_grade.gd` cobra.
var chanfro_de_canto: float = 48.0

## Quanto de VAZIO se quer ver alem da arquitetura, quando a sala cabe no quadro.
##
## Sem um negativo em volta, a arquitetura encosta na borda da tela e o cap passa
## a ler como a moldura da viewport em vez do alto de uma parede. Medido antes de
## ele existir: `vazio` era 0,0% no centro da sala retangular e 0,7% no pior
## canto.
##
## Ele nao desloca camera: e o piso que `GerenciadorMapa._cabendo_a_tela()` tem
## de respeitar ao crescer o clamp.
var margem_exterior: float = 20.0

## Onde o decalque de desgaste pode pousar dentro do CAP.
##
## O bisel e a borda sao as duas faixas que o decalque nao invade -- sem elas ele
## encosta na quebra de valor entre o corpo e o cap, e a marca le como um defeito
## de renderizacao em vez de desgaste.
##
## **Os dois cairam de 10 e 4 para 2 e 2 junto com o cap**, e a conta e o motivo:
## num cap de 12, `12 - 10 - 4` e NEGATIVO -- o decalque nao caberia em lugar
## nenhum e a regra de encaixe o descartaria em silencio. Eles descreviam um cap
## de 40.
var borda_do_topo: float = 2.0
var bisel_do_topo: float = 2.0

## OS QUATRO SCALES EXISTEM PARA OUTRO ANDAR, e no andar 1 valem 1,0.
##
## Eles sao a valvula que impede este recurso de virar uma camisa de forca: um
## andar futuro pode querer a parede norte mais alta por ficcao -- um poco, uma
## galeria. Mas a assimetria passa a ser uma DECLARACAO, feita num lugar so e
## visivel, em vez de nove campos que divergem por descuido.
##
## `teste_perfil_parede.gd` cobra que continuem em 1,0 aqui.
var escala_norte: float = 1.0
var escala_sul: float = 1.0
var escala_leste: float = 1.0
var escala_oeste: float = 1.0


## O TIPO de cada camada, e ele decide o material e nao so a cor.
##
## `FACE` recebe a textura do modulo -- e ela que carrega "fabrica abandonada".
## `CAP` recebe a textura de topo, que e cobertura estrutural e nao conteudo.
## `SOMBRA` e valor puro, sem textura.
##
## **REVEAL, LABIO, LEDGE e QUEDA sairam junto com o modelo assimetrico.** Eles
## descreviam pecas que so existiam num lado -- e camada que so um lado tem e o
## caminho de volta para a divergencia. Valor novo entra sempre NO FIM.
enum Camada { FACE, CAP, SOMBRA }


## A escala de corpo deste lado. Um lugar so, para os quatro consumidores.
func escala(lado: int) -> float:
	match lado:
		RenderizadorParedes.Lado.NORTE:
			return escala_norte
		RenderizadorParedes.Lado.SUL:
			return escala_sul
		RenderizadorParedes.Lado.OESTE:
			return escala_oeste
		_:
			return escala_leste


## As camadas de um lado, do contorno para FORA.
##
## Cada entrada e `(inicio, fim, tipo)` em px, e **inicio pode ser NEGATIVO**: a
## sombra e a unica que cresce para dentro do piso. Todo o resto cresce para
## fora, e por isso `profundidade()` conta so o que passa de zero.
##
## Ela e a unica fonte da geometria: o renderizador nao conhece campo nenhum
## deste recurso, so esta lista. **E a pilha e a MESMA nos quatro lados** -- e
## isso que faz o anel nascer da caminhada por arestas, sem offset de poligono e
## sem arriscar a UV ancorada no contorno.
func camadas(lado: int) -> Array[Vector3]:
	var c := corpo * escala(lado)
	return [
		Vector3(-sombra_de_contato, 0.0, Camada.SOMBRA),
		Vector3(0.0, c, Camada.FACE),
		Vector3(c, c + cap, Camada.CAP),
	]


## Quanto este lado desenha para FORA do contorno.
##
## A sombra fica de fora da conta de proposito: ela desenha sobre o piso, dentro
## da area jogavel, e quem consome este numero e a CAMERA -- o clamp cresce por
## ele para mostrar a parede inteira e nem um pixel do vazio depois dela.
func profundidade(lado: int) -> float:
	var fundo := 0.0
	for camada in camadas(lado):
		fundo = maxf(fundo, camada.y)
	return fundo


## Onde a FACE deste lado acaba, medindo do contorno para fora.
##
## **O SUL deixou de devolver zero.** Ele tinha soleira e nao face, e quem
## consome isto -- o corte da porta e o acabamento -- tratava o zero como caso
## especial. Hoje os quatro respondem a mesma coisa, e o caso especial saiu.
func fim_da_face(lado: int) -> float:
	for camada in camadas(lado):
		if int(camada.z) == Camada.FACE:
			return camada.y
	return 0.0


## O maior alcance entre os lados. E o que a camera precisa quando ela so pode
## ter um numero -- e com os quatro iguais, ele e simplesmente o alcance.
func alcance() -> float:
	return maxf(maxf(profundidade(RenderizadorParedes.Lado.NORTE),
		profundidade(RenderizadorParedes.Lado.SUL)),
		maxf(profundidade(RenderizadorParedes.Lado.LESTE),
			profundidade(RenderizadorParedes.Lado.OESTE)))


## O alcance POR EIXO: o maior dos dois lados de cada eixo.
func alcance_por_eixo() -> Vector2:
	return Vector2(
		maxf(profundidade(RenderizadorParedes.Lado.LESTE),
			profundidade(RenderizadorParedes.Lado.OESTE)),
		maxf(profundidade(RenderizadorParedes.Lado.NORTE),
			profundidade(RenderizadorParedes.Lado.SUL))
	)


## As quatro margens, na ordem (esquerda, cima, direita, baixo).
##
## Continuam sendo QUATRO mesmo com os lados iguais, porque os scales podem
## separa-las noutro andar -- e porque um unico numero por eixo escondeu, no
## modelo antigo, 28 px de vazio a mais embaixo sem ninguem notar.
##
## A MARGEM EXTERIOR entra aqui, e nao no crescimento ate a tela: ela e o
## negativo que faz a arquitetura ler como caixa.
func margens() -> Vector4:
	return Vector4(
		profundidade(RenderizadorParedes.Lado.LESTE) + margem_exterior,
		profundidade(RenderizadorParedes.Lado.NORTE) + margem_exterior,
		profundidade(RenderizadorParedes.Lado.OESTE) + margem_exterior,
		profundidade(RenderizadorParedes.Lado.SUL) + margem_exterior
	)
