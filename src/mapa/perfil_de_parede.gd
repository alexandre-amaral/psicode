class_name PerfilDeParede
extends RefCounted
## Quanto a parede DESENHA, por lado.
##
## Ele existe porque a espessura deixou de ser um numero so. Ate aqui os quatro
## lados desenhavam 32 de topo mais 32 de face, e o resultado foi o defeito que
## abriu este epico: uma moldura pesada que le como blocos em volta da sala em
## vez de como a sala.
##
## **Assimetria e necessaria, e nao um ajuste fino.** A perspectiva Low Top-Down
## nao exige simetria visual: a parede NORTE e a unica que mostra a face de
## frente e e ela que carrega a altura; as laterais mostram a face de esguelha e
## podem ser muito mais estreitas; a SUL mostra so a superficie de cima, e
## desenhar 64 px dela e o que mais engorda a moldura sem dar nada em troca.
##
## **A COLISAO NAO MUDA.** Ela continua sendo um segmento sobre o contorno, e a
## grade logica continua 32 para geracao, porta, mapa e posicionamento. O que
## este recurso descreve e so o que se DESENHA -- e separar as duas coisas e o
## plano inteiro: dimensao logica nao e dimensao desenhada.

## Quanto entra em cada lado, do contorno para FORA.
## O DEFAULT E O PERFIL H, escolhido na matriz de ENQUADRAMENTO
## (`tools/matriz_de_sala.tscn`) -- a que mede quanto da TELA vira parede, com a
## camera no regime real do jogo.
##
## Ele concentra TUDO na norte -- 32 de topo mais 72 de face -- e deixa as
## laterais em 16/16.
##
## A lateral e vista de ESGUELHA: engorda-la custa piso e quase nao da altura
## lida.
##
## **A FACE tem a mesma profundidade nos tres lados que a mostram, e isso e a
## regra.** Ela foi escrita depois de o dono olhar o jogo e dizer que a textura
## da parede tinha mudado mas o ASPECTO nao. Medido com
## `tools/medir_moldura.tscn`, na camera real, o motivo estava a vista:
##
##     sala_1, jogador ao NORTE     faixa de parede = 22,8% do quadro
##     sala_1, jogador a LESTE      faixa de parede =  6,1% do quadro
##
## Mesma textura, um quarto da espessura. O norte desenhava 104 px e as laterais
## 32, entao a lateral nunca chegava a ler como parede -- ela lia como uma borda.
##
## Hoje os tres lados vistos desenham **72 px de face**. O que ainda difere e o
## TOPO, e a diferenca e geometrica e nao de gosto: no norte o topo e a
## espessura vista de esguelha (32 px), nas laterais ele e a superficie de cima
## vista quase de frente (24 px), e no sul nao ha face nenhuma para desenhar.
##
## **O sul nao ganha face, e a decisao continua valendo.** A face dele olharia
## para LONGE da camera, escondida pela propria parede. O que ele ganha e
## PROFUNDIDADE igual a do norte, so que toda em superficie de cima -- e assim o
## piso parece encaixado numa caixa em vez de terminar numa linha, que e o que o
## §15 do plano pede.
##
## **Engordar os quatro lados nao e mais "dominado".** A medicao antiga dizia que
## sim (norte 17,6% contra 19,1%, piso 61,2% contra 65,9%), e ela media a coisa
## certa para a pergunta errada: ela comparava quanto da tela a parede NORTE
## ocupa, com o jogador encostado no norte. Nessa pergunta engrossar a lateral so
## rouba espaco. A pergunta que importa e outra -- *"em qualquer posicao, o
## jogador ve parede?"* --, e nela a lateral fina perde: nas tres posicoes em que
## o norte esta fora de quadro, a moldura caia para 6%.
##
## As profundidades sao o que sao porque a GRADE fecha nelas, e nao por gosto:
## com 96 px de lateral, `contorno + margens` fecha 960 exato num contorno de
## 768, que e multiplo de 32 e tem meia-dimensao na grade de 16. Com 104 o
## contorno teria de ter 752, que nao cai na grade -- e o multiplo abaixo deixa
## 16 px de VAZIO PRETO em cada borda, que e exatamente o defeito que esta
## mudanca existe para tirar.
## **Os QUATRO lados desenham a mesma coisa: 32 de topo e 64 de face.**
##
## A uniformidade e o entregavel, e ela veio de uma divida anotada pelo dono: "os
## tijolos que compoem o topo nao estao nem um pouco uniformes, cada orientacao e
## cada canto recebem um tamanho e uma quantidade diferentes". Duas causas, e as
## duas eram codigo:
##
##   - o TOPO era sorteado por LADO entre tres texturas que nao sao variantes
##     do mesmo material -- placas 2x2, tijolo irregular e painel vertical --,
##     entao uma sala vestia tres materiais ao mesmo tempo;
##   - e a faixa de topo tinha 32 px no norte e 24 nas laterais, entao cada lado
##     mostrava uma FATIA diferente da mesma textura de 64 px.
##
## 32 + 64 = 96 nos quatro lados fecha a grade: `contorno + margens` da 960 exato
## num contorno de 768. Com 32 + 72 o lado curto teria de ter 752, que nao cai na
## grade de 32, e o multiplo abaixo devolve vazio preto na borda.
##
## **56 de face e nao 64, e quem manda nisso e a PORTA.** `porta_moldura.png` tem
## 62 px de conteudo opaco, dos quais **58 ficam acima do contorno** -- o resto
## desce para o chao como soleira. A face abre no vao da porta, entao o que cobre
## a face ali e a moldura: uma face mais funda que 58 deixa uma tira de nada
## entre o alto da moldura e o comeco do topo. Com 64 sobravam 6 px, e o dono os
## viu como "um espaco vazio acima da porta, com uma cor parecida mas nao igual a
## da moldura".
##
## 56 fica dois pixels abaixo do teto de 58, e a moldura passa a AVANCAR 2 px
## sobre o topo -- que le como verga, e nao como sobra.
##
## Isto e uma restricao de ARTE virada numero, e ela sobe junto no dia em que a
## moldura crescer: `teste_porta.gd` mede os 58 no alfa do arquivo, entao o teto
## nao e um literal que envelhece.
## OS QUATRO LADOS SAO QUATRO PERFIS DIFERENTES, e a simetria que saiu daqui era
## o defeito.
##
## A regra anterior -- 56 de face mais 40 de topo, igual nos quatro lados -- foi
## medida no jogo e reprovada pelo dono: o piso e as bandas perifericas
## continuavam parecendo o mesmo plano. O topo largo lia como uma faixa de PISO,
## as laterais como bordas retas, e as quinas como encontros de 90 graus sem
## profundidade nenhuma.
##
## O que produz a leitura de cavidade nao e a espessura: e a ASSIMETRIA. A camera
## e uma so, e cada lado esta numa relacao diferente com ela.
##
##     NORTE     a unica face vista de frente. Ela carrega a altura, e o cap e
##               so a espessura dela vista de esguelha.
##     LATERAL   vista de esguelha. Face estreita, e um reveal que mostra a
##               espessura sem virar coluna.
##     SUL       vista de CIMA. Nao ha face para dentro: ha uma soleira que
##               cresce para FORA da area jogavel, como um ledge.
##
##     NORTE                          LATERAL
##       exterior                       exterior
##       ---- cap 12 ----               | reveal 8
##       #### face 48 ###               | face 28
##       ~~~~ sombra 4 ~~               | sombra 4
##            PISO                      | PISO
##
##     SUL
##       PISO | labio 4 | ledge 20 | queda 8 | exterior
##
## **A ESPESSURA LOGICA E A VISUAL DEIXAM DE SER A MESMA COISA.** A grade
## continua em 32 e a colisao continua no limite do piso; o que cada lado desenha
## deixa de ter relacao com isso. Era essa amarra que obrigava os quatro lados a
## medir igual.
##
## A sombra e o labio sao os unicos que crescem para DENTRO. Todo o resto cresce
## para fora, e por isso `profundidade()` nao os conta.
var face_norte: float = 48.0
var cap_norte: float = 12.0
var sombra_norte: float = 4.0

var face_lateral: float = 28.0
var reveal_lateral: float = 8.0
var sombra_lateral: float = 4.0

## O SUL NAO TEM FACE PARA DENTRO, e esta regra ja foi invertida uma vez.
##
## Ela dizia que o sul nao ganha face porque a face dele olha para longe da
## camera. Depois foi invertida: o dono apontou tres vezes que o sul lia como um
## campo de blocos de pedra, e a resposta foi dar face a ele, igual aos outros.
##
## **As duas leituras estavam certas sobre coisas diferentes.** O sul de fato nao
## pode mostrar uma face alta virada para dentro -- ela olharia para longe da
## camera. E de fato nao podia ser um campo liso de topo. O que ele e, e o que
## nenhuma das duas versoes construiu, e uma SOLEIRA: um labio fino que contem o
## piso, um ledge que cresce para fora, e uma queda que termina a moldura antes
## do vazio.
##
## A diferenca entre soleira e faixa e para onde ela cresce. A faixa crescia para
## dentro do quadro e competia com o piso; a soleira cresce para fora e emoldura.
var labio_sul: float = 4.0
var ledge_sul: float = 20.0
var queda_sul: float = 8.0

## O CHANFRO das quinas, e ele e a metade da mudanca.
##
## Reduzir o topo sozinho nao resolve: uma quina de 90 graus comunica planta
## baixa, e nao volume. O contorno interno recua 48 px na diagonal em cada quina
## convexa, e as faixas acompanham -- entao face, cap e sombra convergem para o
## piso em vez de se encontrarem em esquadro.
##
## Ele vive na GEOMETRIA e nao em arte. Um PNG de canto voltaria a ser a peca
## quadrada que a meia-esquadria removeu, e a textura precisa atravessar a quina.
##
## 48 e multiplo de 16, entao o contorno chanfrado continua na grade que
## `teste_grade.gd` cobra.
var chanfro_de_canto: float = 48.0

## Quanto de VAZIO se quer ver alem da arquitetura, quando a sala cabe no quadro.
##
## Medido antes desta mudanca: `vazio` em 0,0% no centro da sala retangular e
## 0,7% no pior canto. A arquitetura ocupava ate a borda da tela, e sem um
## negativo em volta ela nao le como caixa.
##
## Ele nao desloca camera: ele e o piso que `GerenciadorMapa._cabendo_a_tela()`
## tem de respeitar ao crescer o clamp.
var margem_exterior: float = 20.0

## Campos do modelo ANTIGO, mantidos so para os perfis de comparacao.
##
## Eles nao desenham mais nada -- quem desenha e a lista de camadas por lado.
## Ficam porque `de_nome()` e a matriz de enquadramento ainda os escrevem, e
## apaga-los mudaria o que aquelas ferramentas medem sem ninguem pedir.
var borda_externa_sul: float = 0.0
var borda_do_topo: float = 4.0
var bisel_do_topo: float = 10.0


## O TIPO de cada camada, e ele decide o material e nao so a cor.
##
## `FACE` recebe a textura do modulo -- e ela que carrega "fabrica abandonada".
## `CAP`, `REVEAL`, `LEDGE` e `QUEDA` recebem a textura de topo, que e cobertura
## estrutural e nao conteudo. `SOMBRA` e `LABIO` sao valor puro, sem textura.
enum Camada { FACE, CAP, REVEAL, SOMBRA, LABIO, LEDGE, QUEDA }


## As camadas de um lado, do contorno para FORA.
##
## Cada entrada e `(inicio, fim, tipo)` em px, e **inicio pode ser NEGATIVO**: a
## sombra e o unico que cresce para dentro do piso, porque e ela que faz o piso
## parecer estar abaixo da face. Todo o resto cresce para fora, e por isso
## `profundidade()` conta so o que passa de zero.
##
## Ela e a unica fonte da geometria: o renderizador nao conhece campo nenhum
## deste recurso, so esta lista. Foi assim que os quatro lados deixaram de poder
## ser a mesma coisa por acidente.
func camadas(lado: int) -> Array[Vector3]:
	if lado == RenderizadorParedes.Lado.NORTE:
		return [
			Vector3(-sombra_norte, 0.0, Camada.SOMBRA),
			Vector3(0.0, face_norte, Camada.FACE),
			Vector3(face_norte, face_norte + cap_norte, Camada.CAP),
		]
	if lado == RenderizadorParedes.Lado.SUL:
		return [
			Vector3(0.0, labio_sul, Camada.LABIO),
			Vector3(labio_sul, labio_sul + ledge_sul, Camada.LEDGE),
			Vector3(labio_sul + ledge_sul, labio_sul + ledge_sul + queda_sul, Camada.QUEDA),
		]
	return [
		Vector3(-sombra_lateral, 0.0, Camada.SOMBRA),
		Vector3(0.0, face_lateral, Camada.FACE),
		Vector3(face_lateral, face_lateral + reveal_lateral, Camada.REVEAL),
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


## Onde a FACE deste lado acaba, medindo do contorno para fora. Zero = sem face.
##
## **O SUL devolve zero, e isso e a regra e nao uma falta.** Ele nao tem face
## para dentro: tem soleira. Quem consome isto e o corte da porta e o
## acabamento, e os dois ja tratam zero -- era assim antes de o sul ganhar face,
## e voltou a ser.
func fim_da_face(lado: int) -> float:
	for camada in camadas(lado):
		if int(camada.z) == Camada.FACE:
			return camada.y
	return 0.0


## O maior alcance entre os lados. E o que a camera precisa quando ela so pode
## ter um numero.
func alcance() -> float:
	return maxf(maxf(profundidade(RenderizadorParedes.Lado.NORTE),
		profundidade(RenderizadorParedes.Lado.SUL)),
		profundidade(RenderizadorParedes.Lado.LESTE))


## O alcance POR EIXO: o maior dos dois lados de cada eixo.
func alcance_por_eixo() -> Vector2:
	return Vector2(
		profundidade(RenderizadorParedes.Lado.LESTE),
		maxf(profundidade(RenderizadorParedes.Lado.NORTE),
			profundidade(RenderizadorParedes.Lado.SUL))
	)


## As quatro margens, na ordem (esquerda, cima, direita, baixo).
##
## **A camera precisa das QUATRO, e agora mais do que antes.** Com os quatro
## lados iguais um numero por eixo bastava; com norte 60, lateral 36 e sul 32 um
## unico numero vertical usaria 60 nos dois e o quadro mostraria 28 px de VAZIO
## a mais embaixo -- exatamente o que o clamp existe para controlar.
##
## A MARGEM EXTERIOR entra aqui, e nao no crescimento ate a tela. Ela e o negativo
## que faz a arquitetura ler como caixa, e sem ela a parede encosta na borda do
## quadro: medido antes desta mudanca, `vazio` era 0,0% no centro da sala
## retangular e 0,7% no pior canto.
func margens() -> Vector4:
	return Vector4(
		profundidade(RenderizadorParedes.Lado.LESTE) + margem_exterior,
		profundidade(RenderizadorParedes.Lado.NORTE) + margem_exterior,
		profundidade(RenderizadorParedes.Lado.OESTE) + margem_exterior,
		profundidade(RenderizadorParedes.Lado.SUL) + margem_exterior
	)
