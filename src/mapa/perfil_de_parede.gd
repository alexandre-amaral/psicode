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
## lida. Medido na matriz, contra um perfil que engorda os quatro lados por igual:
##
##     quatro lados iguais   norte 17,6% da tela   piso 61,2%
##     so a norte (este)     norte 19,1% da tela   piso 65,9%
##
## Ele ganha nos DOIS eixos. Engordar os quatro por igual e dominado, e era
## exatamente o que o perfil A fazia.
##
## A norte ocupa 19,1% da altura do quadro, que e a faixa em que a parede do
## Isaac vive. Nos perfis anteriores ela ocupava 7,4% (C) e 10,3% (E), e o dono
## olhou os dois no jogo e disse que a parede continuava pequena.
##
## `tools/matriz_paredes.tscn` monta a mesma sala nos quatro perfis com o mesmo
## zoom e imprime quanto do quadro vira moldura:
##
##     A  32/32  32/32  64  ->  28,6%
##     B  24/24  24/24  24  ->  22,7%
##     C  16/24  16/16  16  ->  19,5%
##     D  16/16  12/12  12  ->  16,1%
##
## O alvo do plano e 10-20% de arquitetura contra 80-90% de espaco de jogo. O A
## -- o estado que abriu este epico -- estava em 28,6%, meia vez acima do teto.
##
## C e nao D porque a NORTE nao pode encolher junto: ela e a unica que mostra a
## face de FRENTE, e e dela que vem a altura da sala inteira. No D a face norte
## cai a 16 e a sala perde o volume junto com o peso. C a mantem em 24 e encolhe
## o que nao carrega nada -- o topo, as laterais de esguelha e o sul.
##
## Os tres numeros caem dentro das faixas que o plano sugere: norte topo 16-24 e
## face 20-28, laterais 12-20, sul 8-16.
var topo_norte: float = 32.0
var face_norte: float = 72.0
var topo_lateral: float = 16.0
var face_lateral: float = 16.0
## O sul mostra so a superficie de cima -- a face dele olha para longe da camera.
## 16 e nao 64: desenhar 64 px de superficie chapada ali era o que mais engordava
## a moldura sem dar nada em troca.
var topo_sul: float = 16.0
## A BORDA EXTERNA do sul: a espessura que escurece do topo ate o vazio.
##
## O §15 do plano de profundidade pede que a sul seja construida ao contrario da
## norte -- chao, topo, e entao altura para BAIXO, em direcao ao exterior. E o
## que faz o piso parecer encaixado numa caixa em vez de terminar numa linha.
##
## Ela NAO e uma face, e a distincao nao e de nome. Face e superficie vista de
## FRENTE, e o lado sul olha para longe da camera: desenhar `parede_face` ali
## seria pintar o que o jogador nao ve, e e por isso que
## `teste_camada_visual.gd` proibe textura de face abaixo da borda sul. Isto e
## espessura em degraus de VALOR, na mesma lingua da `SombraDeParede`.
var borda_externa_sul: float = 16.0


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
		return topo_sul + borda_externa_sul
	if lado == RenderizadorParedes.Lado.NORTE:
		return topo_norte + face_norte
	return topo_lateral + face_lateral


## Onde a FACE deste lado acaba, medindo do contorno para fora. Zero = sem face.
##
## O sul nao tem face de proposito: ela olharia para longe da camera, escondida
## pela propria parede. Desenha-la seria pintar uma superficie que nao existe do
## ponto de vista de quem olha.
func fim_da_face(lado: int) -> float:
	if lado == RenderizadorParedes.Lado.SUL:
		return 0.0
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
		topo_sul + borda_externa_sul)


## O alcance POR EIXO: o maior dos dois lados de cada eixo.
##
## Serve a quem precisa de UM numero por eixo -- portoes de "cabe na faixa". Para
## a camera ele nao basta: ver `margens()`.
func alcance_por_eixo() -> Vector2:
	return Vector2(
		topo_lateral + face_lateral,
		maxf(topo_norte + face_norte, topo_sul + borda_externa_sul)
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
		topo_sul + borda_externa_sul)
