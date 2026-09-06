class_name AssinaturaDeSuperficie
extends RefCounted
## A ASSINATURA ESTRUTURAL de uma textura: (orientacao, densidade).
##
## Duas perguntas do epico da fabrica precisam comparar texturas entre si, e as
## duas sao sobre ESTRUTURA e nunca sobre cor:
##
##   - os cinco modulos de FACE tem de estar LONGE uns dos outros (identidade);
##   - os tres TOPOS tem de estar PERTO uns dos outros (mesmo material).
##
## Sao afirmacoes opostas, e cada uma tem a sua razao: a face carrega identidade
## e existe para variar entre salas; o topo e a superficie continua que da a
## volta na sala e atravessa as quinas, entao tres materiais ali poem uma sala
## de metal ao lado de uma de pedra.
##
## **Cor esta fora da assinatura de proposito.** Os cinco modulos de um tipo sao
## tingidos no MESMO matiz -- e o tingimento e o que os faz pertencer ao mesmo
## setor. Comparar cor entre eles nao separaria nada, e comparar cor entre topos
## os aprovaria sempre.
##
## Ela mora aqui, e nao dentro de uma suite, porque duas suites a consomem. Duas
## copias divergem, e o sintoma aparece em TELA e nunca no console -- e a mesma
## razao que tirou o mapa de angulos de dentro de `DadosPersonagem` e o telegrafo
## de dentro de sete inimigos.

## Dois pixels vizinhos contam como mudanca quando a soma das diferencas de canal
## passa disto. Gemeo de `teste_texturas.LIMIAR_DETALHE`, do `LIMIAR_DETALHE` de
## `teste_profundidade` e do de `preparar_textura.py`.
const LIMIAR_DETALHE := 24


## (orientacao, densidade) de uma textura.
##
## `orientacao` vai de -1 (horizontal) a +1 (vertical); `densidade` e a fracao de
## pixels que muda em relacao ao vizinho da direita ou de baixo.
##
## Le com WRAP nos dois eixos: estas texturas ladrilham, entao a coluna 63 e
## vizinha da 0 no jogo. Medir sem o wrap ignoraria a juncao, que e onde uma
## nervura mal fechada apareceria.
static func medir(imagem: Image) -> Vector2:
	if imagem == null or imagem.is_empty():
		return Vector2(INF, INF)
	var l := imagem.get_width()
	var a := imagem.get_height()
	var energia_x := 0.0
	var energia_y := 0.0
	var muda := 0
	for y in a:
		for x in l:
			var c := imagem.get_pixel(x, y)
			var d := imagem.get_pixel((x + 1) % l, y)
			var e := imagem.get_pixel(x, (y + 1) % a)
			var v := _luma(c)
			energia_x += absf(_luma(d) - v)
			energia_y += absf(_luma(e) - v)
			if _diferenca(c, d) > LIMIAR_DETALHE or _diferenca(c, e) > LIMIAR_DETALHE:
				muda += 1
	var soma := energia_x + energia_y
	var orientacao := 0.0 if soma <= 0.0 else (energia_x - energia_y) / soma
	return Vector2(orientacao, float(muda) / float(maxi(l * a, 1)))


## A distancia entre duas assinaturas: soma das diferencas absolutas.
##
## Soma e nao euclidiana, e a escolha e deliberada. Os dois eixos ja estao na
## mesma escala -- orientacao em [-1, 1] e densidade em [0, 1] -- e a soma pesa
## os dois por igual. A euclidiana perdoaria um par que difere MUITO num eixo e
## nada no outro, que e exatamente o caso de dois modulos com a mesma silhueta e
## sujeiras diferentes.
static func distancia(a: Vector2, b: Vector2) -> float:
	return absf(a.x - b.x) + absf(a.y - b.y)


static func _luma(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


static func _diferenca(a: Color, b: Color) -> int:
	return (
		absi(int(round(a.r * 255.0)) - int(round(b.r * 255.0)))
		+ absi(int(round(a.g * 255.0)) - int(round(b.g * 255.0)))
		+ absi(int(round(a.b * 255.0)) - int(round(b.b * 255.0)))
	)
