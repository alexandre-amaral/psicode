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
var topo_norte: float = 32.0
var face_norte: float = 64.0
var topo_lateral: float = 32.0
var face_lateral: float = 64.0
## O SUL desenha face e topo como os outros tres. **Esta regra foi INVERTIDA.**
##
## Ela dizia que o sul nao ganha face porque a face dele "olha para longe da
## camera, escondida pela propria parede", e o argumento e geometricamente
## correto: num solido real, a superficie interna da parede sul fica atras do
## topo dela do ponto de vista de quem olha de cima.
##
## O que ele nao previu e o que o jogador ve. Sem face, o sul desenha um campo
## liso da textura de TOPO -- um padrao de blocos de pedra -- enquanto os outros
## tres lados mostram a face estriada. Tres paredes de um material, uma de outro:
## a sala deixa de ler como uma cavidade e passa a ler como um chao de pedra
## colado embaixo. O dono apontou isso tres vezes, em duas profundidades
## diferentes (16 e 88), e nas duas o sintoma foi o mesmo.
##
## A consistencia de MATERIAL entre os quatro lados vale mais aqui que a
## fidelidade do solido, e essa e a decisao. A faixa abaixo da linha do chao le
## como "a parede continua", e o que faz a sala parecer escavada e ela continuar
## com a mesma cara nos quatro sentidos.
##
## `borda_externa_sul` vai a ZERO junto: ela existia como SUBSTITUTA da face --
## era ela que dava ao sul alguma espessura em degraus de valor. Com a face de
## verdade ali, manter as duas somaria 120 px de um lado so e quebraria a
## simetria que a mudanca existe para produzir. O codigo dela fica, guardado por
## `> 0`, porque um andar futuro pode querer o degrau sem a face.
var topo_sul: float = 32.0
var face_sul: float = 64.0
var borda_externa_sul: float = 0.0


## Os quatro perfis da matriz de comparacao do plano.
##
## Eles existem para a escolha ser feita olhando a MESMA sala nos quatro, lado a
## lado, e nao no editor um de cada vez. "Parece melhor" nao sobrevive a memoria
## de dez minutos depois.
static func de_nome(nome: String) -> PerfilDeParede:
	var p := PerfilDeParede.new()
	match nome:
		"A":
			# O estado de referencia: o que o epico existe para substituir.
			p.topo_norte = 32.0
			p.face_norte = 32.0
			p.topo_lateral = 32.0
			p.face_lateral = 32.0
			p.topo_sul = 64.0
			p.borda_externa_sul = 0.0
		"B":
			p.topo_norte = 24.0
			p.face_norte = 24.0
			p.topo_lateral = 24.0
			p.face_lateral = 24.0
			p.topo_sul = 24.0
			p.borda_externa_sul = 0.0
		"C":
			p.topo_norte = 16.0
			p.face_norte = 24.0
			p.topo_lateral = 16.0
			p.face_lateral = 16.0
			p.topo_sul = 16.0
			p.borda_externa_sul = 12.0
		"E":
			# O PERFIL QUE RODA. Ele gasta os px extras na FACE, e nao no topo.
			#
			# A face e a UNICA superficie vista de frente -- e dela que vem a
			# altura da sala. Engordar o topo sobe a fracao de moldura sem subir a
			# leitura, e foi isso que fez o perfil A parecer pesado: 64 px de topo
			# SUL, superficie chapada vista de cima que nao carrega volume nenhum.
			#
			# Medido na matriz de enquadramento, na sala de 896x448:
			#
			#     C   norte  7,4% da tela   moldura 18,0%   piso 76,9%   vazio 5,1%
			#     E   norte 10,3% da tela   moldura 23,1%   piso 76,9%   vazio 0,0%
			#
			# MESMA area jogavel, 40% mais altura de parede -- ele converte em
			# moldura o vazio que o C desperdicava. E as margens verticais dele
			# somam 96, entao 448 + 96 = 544 EXATO.
			p.face_norte = 40.0
			p.borda_externa_sul = 24.0
		"D":
			p.topo_norte = 16.0
			p.face_norte = 16.0
			p.topo_lateral = 12.0
			p.face_lateral = 12.0
			p.topo_sul = 12.0
			p.borda_externa_sul = 0.0
		_:
			pass
	return p


## Quanto este lado desenha ao todo.
func profundidade(lado: int) -> float:
	if lado == RenderizadorParedes.Lado.SUL:
		return topo_sul + face_sul + borda_externa_sul
	if lado == RenderizadorParedes.Lado.NORTE:
		return topo_norte + face_norte
	return topo_lateral + face_lateral


## Onde a FACE deste lado acaba, medindo do contorno para fora. Zero = sem face.
##
## Os QUATRO lados tem face desde que a regra do sul foi invertida -- o porque
## esta no bloco de `face_sul`. Zero continua sendo um valor valido e util: um
## estilo pode zerar a face de um lado, e o renderizador simplesmente nao a
## desenha.
func fim_da_face(lado: int) -> float:
	if lado == RenderizadorParedes.Lado.SUL:
		return face_sul
	if lado == RenderizadorParedes.Lado.NORTE:
		return face_norte
	return face_lateral


## O maior alcance entre os lados.
##
## E o numero que a camera precisa: o clamp tem de mostrar a parede inteira do
## lado mais fundo, e nem um pixel do vazio depois dela. Com a assimetria, os
## lados rasos ficam com folga -- e isso e aceitavel, porque o quadro e um so.
func alcance() -> float:
	return maxf(maxf(topo_norte + face_norte, topo_lateral + face_lateral),
		topo_sul + face_sul + borda_externa_sul)


## O alcance POR EIXO: o maior dos dois lados de cada eixo.
##
## Serve a quem precisa de UM numero por eixo -- portoes de "cabe na faixa". Para
## a camera ele nao basta: ver `margens()`.
func alcance_por_eixo() -> Vector2:
	return Vector2(
		topo_lateral + face_lateral,
		maxf(topo_norte + face_norte, topo_sul + face_sul + borda_externa_sul)
	)


## As quatro margens, na ordem (esquerda, cima, direita, baixo).
##
## **A camera precisa das QUATRO, e nao de duas.** Com a assimetria do perfil C
## o norte desenha 40 px e o sul 16: um unico numero vertical usaria 40 nos dois
## e o quadro passaria a mostrar 24 px de VAZIO embaixo -- exatamente o que o
## clamp existe para impedir, e o portao pegou isso na primeira montagem.
##
## Esquerda e direita sao iguais porque leste e oeste desenham a mesma
## profundidade; cima e baixo nao sao, e e essa diferenca que carrega a
## perspectiva. Norte e sempre -Y neste jogo, entao o mapa lado -> margem e fixo
## e nao depende da forma da sala.
func margens() -> Vector4:
	var lateral := topo_lateral + face_lateral
	return Vector4(lateral, topo_norte + face_norte, lateral,
		topo_sul + face_sul + borda_externa_sul)
