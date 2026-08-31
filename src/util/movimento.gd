class_name Movimento
extends RefCounted
## O VOCABULARIO DE MOVIMENTACAO: perseguir, recuar, orbitar, investir, fugir.
##
## Cinco inimigos escreviam a mesma matematica de tangente mais correcao radial,
## cada um com o nome que lhe pareceu melhor -- `POSICIONAR` no Drone,
## `OBSERVAR` na Cyber-Besta, `_circular` na Sentinela, `REPOSICIONAR` no Hacker.
## E a mesma historia do mapa de angulo -> quadro antes de virar
## `src/util/direcoes.gd`: **duas copias divergem, e o sintoma aparece em tela e
## nao no console** -- um inimigo passa a orbitar de um jeito e o outro de outro,
## sem erro nenhum, e a leitura do campo muda sem ninguem ter decidido isso.
##
## A REGRA QUE ESTE ARQUIVO EXISTE PARA PROTEGER: nenhum helper recebe
## velocidade pronta. Todos recebem o INIMIGO e chamam `velocidade_atual()` no
## frame em que precisam -- e essa funcao le `Deterioracao`. Um helper com
## assinatura `orbitar(velocidade: float, ...)` convidaria o chamador a calcular
## o numero uma vez e guardar, e a barra subindo deixaria de afetar quem ja esta
## em tela, que e a segunda regra do projeto inteiro.
##
## A unica excecao e `investir()`, e ela e declarada: a velocidade de investida
## e um numero PROPRIO do `.tres` (560 no Rastejante, 720 na Cyber-Besta), nao
## deriva de `velocidade_base` e nao escala com a Deterioracao. E de proposito --
## uma investida que acelera com a barra deixa de ser esquivavel pelo mesmo
## timing que o jogador acabou de aprender.
##
## Duas coisas que os helpers preservam sem o chamador precisar lembrar:
##
## - **Todo deslocamento passa por `direcao_de_locomocao()`**, que e o ponto de
##   extensao onde pathfinding vai entrar um dia. A excecao, de novo, e
##   `investir()`: durante a investida o inimigo NAO desvia de nada, e e isso
##   que torna o ataque legivel e faz a parede virar recurso do jogador.
## - **Sem alvo, ninguem sai correndo para lugar nenhum.** Todo verbo com alvo
##   freia quando `direcao_para_alvo()` volta zero.

## Abaixo disto um vetor conta como nulo. Comparar com zero exato num vetor que
## veio de `normalized()` erra por arredondamento.
const EPSILON := 0.000001


# ------------------------------------------------------- a conta, sem no -----
#
# As duas funcoes abaixo sao PURAS: recebem numeros e devolvem uma direcao. Elas
# ficam separadas dos verbos por serem o que da para testar sem montar meia
# arvore de cena -- mesma divisao que `Balistica` faz com a mira preditiva.

## O rumo de quem orbita: tangente mais correcao radial.
##
## E a implementacao da Sentinela, que era a mais madura das cinco, promovida a
## unica. A tangente faz girar; a correcao devolve para a casquinha certa, sem
## precisar de trigonometria.
##
## `banda` escolhe entre os dois temperamentos que os inimigos ja usavam:
##
## - **`banda == 0` (proporcional).** A correcao cresce com o erro, entao o
##   inimigo converge suave para um raio EXATO. E o da Sentinela.
## - **`banda > 0` (faixa morta).** Dentro de `raio +/- banda` ele so circula;
##   fora, corrige com forca cheia. E o do Drone Aranha, e a razao esta escrita
##   la: mirar um raio unico faria todos os drones convergirem para a MESMA
##   circunferencia, que e o empilhamento de novo, so que em anel.
##
## `raio` zero e legitimo e quer dizer "circula fechando": o erro e sempre
## positivo, entao a correcao aponta sempre para o alvo. E o `OBSERVAR` da
## Cyber-Besta, que nao tem raio de orbita nenhum -- ela contorna enquanto se
## aproxima.
static func rumo_orbital(
	para_alvo: Vector2,
	distancia: float,
	raio: float,
	sentido: float,
	correcao_radial: float,
	banda: float = 0.0
) -> Vector2:
	if para_alvo.length_squared() < EPSILON:
		return Vector2.ZERO

	var tangente := para_alvo.orthogonal() * (1.0 if sentido >= 0.0 else -1.0)
	var erro := distancia - raio
	var radial := Vector2.ZERO
	if banda > 0.0:
		if erro > banda:
			radial = para_alvo
		elif erro < -banda:
			radial = -para_alvo
	else:
		# Positivo = longe demais, entao a correcao aponta para o alvo.
		radial = para_alvo * clampf(erro / maxf(raio, 1.0), -1.0, 1.0)

	var rumo := tangente + radial * correcao_radial
	if rumo.length_squared() < EPSILON:
		return tangente
	return rumo.normalized()


## O rumo de quem foge: para tras se o alvo encostou, de lado se nao.
##
## Fugir em linha reta o tempo todo encosta o inimigo na parede e o prende la.
## Longe o bastante, andar de lado basta para ele nao virar um alvo parado.
##
## NOTA sobre um numero que nunca fez nada: a versao do Hacker multiplicava a
## deriva lateral por 0,5 e normalizava na linha seguinte, o que apagava o 0,5.
## Ele nunca andou mais devagar de lado. O comportamento aqui e o mesmo de
## sempre -- de proposito, isto e extracao e nao rebalanceamento --, e quem
## quiser de fato desacelerar a deriva usa o `fator` de `fugir()`, que atua
## depois da normalizacao e portanto funciona.
static func rumo_de_fuga(para_alvo: Vector2, distancia: float, distancia_minima: float) -> Vector2:
	if para_alvo.length_squared() < EPSILON:
		return Vector2.ZERO
	if distancia < distancia_minima:
		return -para_alvo
	return para_alvo.orthogonal()


## O rumo de um arranque curto para longe: "para tras" misturado com "de lado".
##
## Puro para tras encosta o inimigo na parede e ele fica preso ali; a componente
## lateral o faz contornar. E a esquiva do Atirador Neon.
static func rumo_de_esquiva(para_alvo: Vector2, lado: float, peso_lateral: float = 0.6) -> Vector2:
	var para_longe := -para_alvo
	if para_longe.length_squared() < EPSILON:
		return Vector2.RIGHT
	return (para_longe + para_longe.orthogonal() * lado * peso_lateral).normalized()


# ------------------------------------------------------------- os verbos -----

## Escreve a velocidade a partir de um rumo ja resolvido.
##
## Primitiva dos outros verbos, e util direto para quem ja tem a direcao na mao
## -- a esquiva travada do Neon, por exemplo. `aceleracao` zero escreve a
## velocidade de uma vez; acima de zero, o inimigo chega la por `move_toward`.
static func rumar(
	inimigo: InimigoBase,
	delta: float,
	rumo: Vector2,
	fator: float = 1.0,
	aceleracao: float = 0.0
) -> void:
	var desejada := Vector2.ZERO
	if rumo.length_squared() >= EPSILON:
		# `velocidade_atual()` le a Deterioracao AGORA. Nunca guarde este numero.
		desejada = inimigo.direcao_de_locomocao(rumo.normalized()) * inimigo.velocidade_atual() * fator
	if aceleracao > 0.0:
		inimigo.velocity = inimigo.velocity.move_toward(desejada, aceleracao * delta)
	else:
		inimigo.velocity = desejada


## Vai para cima do alvo.
static func perseguir(
	inimigo: InimigoBase, delta: float, fator: float = 1.0, aceleracao: float = 0.0
) -> void:
	rumar(inimigo, delta, inimigo.direcao_para_alvo(), fator, aceleracao)


## Anda para longe do alvo, em linha reta. Sem componente lateral: quem quer
## contornar quer `fugir()` ou `orbitar()`.
static func recuar(
	inimigo: InimigoBase, delta: float, fator: float = 1.0, aceleracao: float = 0.0
) -> void:
	rumar(inimigo, delta, -inimigo.direcao_para_alvo(), fator, aceleracao)


## Circula o alvo. Ver `rumo_orbital()` para o que `banda` decide.
static func orbitar(
	inimigo: InimigoBase,
	delta: float,
	raio: float,
	sentido: float,
	correcao_radial: float = 0.55,
	fator: float = 1.0,
	aceleracao: float = 0.0,
	banda: float = 0.0
) -> void:
	var para_alvo := inimigo.direcao_para_alvo()
	if para_alvo.length_squared() < EPSILON:
		frear(inimigo, delta, maxf(aceleracao, 900.0))
		return
	var rumo := rumo_orbital(
		para_alvo, inimigo.distancia_do_alvo(), raio, sentido, correcao_radial, banda
	)
	rumar(inimigo, delta, rumo, fator, aceleracao)


## Circula mantendo-se DENTRO de uma faixa de distancia, em vez de num raio
## exato.
##
## E a forma que o Drone Aranha usa, e existe como verbo proprio porque
## `raio_min`/`raio_max` e `peso_lateral` sao o vocabulario dele -- converter
## para `raio`/`banda`/`correcao_radial` na chamada seria ruido no arquivo do
## inimigo. `peso_lateral` 1,0 e orbita pura; 0,0 e aproximacao pura.
static func orbitar_na_faixa(
	inimigo: InimigoBase,
	delta: float,
	raio_min: float,
	raio_max: float,
	sentido: float,
	peso_lateral: float,
	fator: float = 1.0,
	aceleracao: float = 0.0
) -> void:
	var meio := (raio_min + raio_max) * 0.5
	var banda := absf(raio_max - raio_min) * 0.5
	# `tangente * p + radial * (1 - p)` aponta para o mesmo lado que
	# `tangente + radial * (1 - p) / p`, que e a forma que `rumo_orbital` usa.
	var correcao := (1.0 - peso_lateral) / maxf(peso_lateral, 0.01)
	orbitar(inimigo, delta, meio, sentido, correcao, fator, aceleracao, banda)


## Se afasta: para tras quando o alvo encosta, de lado quando ha espaco.
static func fugir(
	inimigo: InimigoBase,
	delta: float,
	distancia_minima: float,
	fator: float = 1.0,
	aceleracao: float = 0.0
) -> void:
	var para_alvo := inimigo.direcao_para_alvo()
	if para_alvo.length_squared() < EPSILON:
		frear(inimigo, delta, maxf(aceleracao, 900.0))
		return
	var rumo := rumo_de_fuga(para_alvo, inimigo.distancia_do_alvo(), distancia_minima)
	rumar(inimigo, delta, rumo, fator, aceleracao)


## A investida: linha reta, velocidade propria, sem desviar de nada.
##
## As duas excecoes do vocabulario moram aqui, e as duas sao de design:
##
## 1. **Recebe a velocidade pronta.** Ela e um numero do `.tres` que nao deriva
##    de `velocidade_base` e nao escala com a Deterioracao -- uma investida que
##    acelera com a barra deixa de ser esquivavel pelo timing que o jogador
##    acabou de aprender.
## 2. **Nao passa por `direcao_de_locomocao()`.** Durante a investida ele nao
##    contorna obstaculo nenhum. E o que torna o ataque legivel e o que faz a
##    parede ser um recurso do jogador -- na Cyber-Besta, bater nela e a
##    principal janela de contra-ataque que ela oferece.
static func investir(inimigo: InimigoBase, direcao: Vector2, velocidade: float) -> void:
	if direcao.length_squared() < EPSILON:
		return
	inimigo.velocity = direcao.normalized() * velocidade


## Freia ate parar. Nao e um verbo de deslocamento, mas e o par de todos eles:
## todo estado de telegrafo do jogo trava o corpo, e travar o corpo E metade do
## aviso.
static func frear(inimigo: InimigoBase, delta: float, desaceleracao: float) -> void:
	inimigo.velocity = inimigo.velocity.move_toward(Vector2.ZERO, desaceleracao * delta)
