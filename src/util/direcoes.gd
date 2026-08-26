class_name Direcoes
extends RefCounted
## O mapa de "para onde ele olha" -> "qual dos oito quadros desenhar".
##
## Isolada aqui pelo mesmo motivo da Balistica: e a peca mais facil de errar e a
## que menos avisa quando quebra. Trocar dois indices de lugar faz o sprite
## encarar o lado errado -- gritante em tela, invisivel no console -- e e a
## unica parte de um sprite direcional que da para conferir sem subir cena.
##
## Ela nasceu dentro de `DadosPersonagem`, e saiu de la quando o Drone Aranha
## ganhou arte: duas copias do mesmo mapa acabariam divergindo, e o sintoma
## seria o inimigo e a personagem lendo o mesmo angulo de jeitos diferentes.


## Quantos quadros tem uma volta completa.
const TOTAL := 8


## O indice do quadro que encara `direcao`, na ordem canonica:
##
##   0 leste  1 sudeste  2 sul  3 sudoeste  4 oeste  5 noroeste  6 norte  7 nordeste
##
## A ordem nao e arbitraria: e a que sai de `round(angulo / (PI/4))` com o
## angulo de `Vector2.angle()`, em que +y aponta para BAIXO. Quem gera os
## arquivos (tools/sprites/gerar_sprites.py) usa esta mesma ordem em `DIRECOES`,
## e as duas precisam continuar iguais.
static func indice(direcao: Vector2) -> int:
	# Sul: e para onde se olha quando nao ha para onde olhar.
	if direcao.length_squared() < 0.0001:
		return 2
	var passo := TAU / float(TOTAL)
	var i := int(roundi(direcao.angle() / passo)) % TOTAL
	# GDScript herda o modulo de C: -1 % 8 da -1, nao 7. Angulos negativos sao
	# metade do circulo (todo o hemisferio norte), entao sem esta linha o sprite
	# so olharia para baixo.
	if i < 0:
		i += TOTAL
	return i
