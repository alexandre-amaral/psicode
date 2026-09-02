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
## O DEFAULT E O PERFIL A -- o estado de hoje, e nao o alvo.
##
## Isso e deliberado: o Pass 1 muda a CONTINUIDADE e nada mais. Trocar a
## espessura no mesmo commit misturaria duas perguntas ("a faixa continua ficou
## melhor?" e "a parede fina ficou melhor?") numa captura so, e nenhuma das duas
## teria resposta. A proporcao e o Pass 2, e ela sai da matriz de comparacao.
var topo_norte: float = 32.0
var face_norte: float = 32.0
var topo_lateral: float = 32.0
var face_lateral: float = 32.0
## O sul mostra so a superficie de cima -- a face dele olha para longe da camera.
var topo_sul: float = 64.0


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
		"B":
			p.topo_norte = 24.0
			p.face_norte = 24.0
			p.topo_lateral = 24.0
			p.face_lateral = 24.0
			p.topo_sul = 24.0
		"C":
			p.topo_norte = 16.0
			p.face_norte = 24.0
			p.topo_lateral = 16.0
			p.face_lateral = 16.0
			p.topo_sul = 16.0
		"D":
			p.topo_norte = 16.0
			p.face_norte = 16.0
			p.topo_lateral = 12.0
			p.face_lateral = 12.0
			p.topo_sul = 12.0
		_:
			pass
	return p


## Quanto este lado desenha ao todo.
func profundidade(lado: int) -> float:
	if lado == RenderizadorParedes.Lado.SUL:
		return topo_sul
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
	return maxf(maxf(topo_norte + face_norte, topo_lateral + face_lateral), topo_sul)
