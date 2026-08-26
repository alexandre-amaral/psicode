class_name PerfilJogador
extends RefCounted
## O que a Diretora aprendeu sobre quem esta na frente dela.
##
## Ele existe porque a ficcao do chefe e sobre LEITURA: ela nao odeia o jogador,
## ela o classifica. Sem isto, o repertorio dela e um `shuffle()` -- e um sorteio
## nao e um adversario que aprende, por mais bem telegrafado que seja.
##
## E logica PURA, sem no e sem arvore, pelo mesmo motivo que `Balistica` e pura:
## e a peca mais facil de errar e a unica desta feature que da para conferir sem
## subir cena. Um vies com o sinal trocado faz a Diretora mirar exatamente no
## lado para onde o jogador NAO vai -- ela erraria mais do que se nao tivesse
## aprendido nada, e nada no console diria isso.
##
## A decisao de design que mais importa aqui e a `confianca()`. Ela e o freio:
## enquanto a amostra e curta, a Diretora NAO corrige. Sem esse freio ela
## "aprenderia" no primeiro frame e o primeiro disparo ja sairia antecipando um
## habito que o jogador ainda nao teve chance de formar -- a mesma armadilha que
## o GDD descreve para a mira preditiva ("se ela chegar antes de o jogador ter
## formado um habito de esquiva, nao ha habito para trair").

enum Postura { COLADO, MEIO, LONGE }

## Quanto tempo de movimento observado vale confianca total, em segundos.
## Curto demais e ela adivinha; longo demais e ela nunca chega a usar o que
## aprendeu dentro de uma luta de 60 a 90 s.
const SEGUNDOS_PARA_CONFIANCA := 2.5

## Em quantos segundos uma tendencia antiga perde metade do peso. E o que faz
## "eu sempre esquivo para a direita" poder ser DESFEITO pelo jogador -- o texto
## do chefe promete um duelo, e duelo em que a leitura nao pode ser quebrada e
## so uma punicao com nome bonito.
const MEIA_VIDA := 3.0

## Abaixo disto o jogador esta parado, nao andando. Mesmo papel do piso do
## Player: sem ele, o atrito de uma parada conta como movimento lateral.
const VELOCIDADE_PARADO := 24.0

## As fronteiras de postura, em pixels.
const RAIO_COLADO := 160.0
const RAIO_LONGE := 380.0

var _vies: float = 0.0
var _distancia: float = 0.0
var _fracao_parado: float = 0.0
var _segundos_movendo: float = 0.0
var _observou: bool = false


## Uma amostra. Chamada todo frame de fisica por quem observa.
func observar(pos_jogador: Vector2, velocidade: Vector2, pos_chefe: Vector2, delta: float) -> void:
	if delta <= 0.0:
		return
	var peso := clampf(delta / MEIA_VIDA, 0.0, 1.0)
	var rapidez := velocidade.length()
	var parado := 1.0 if rapidez < VELOCIDADE_PARADO else 0.0

	# A distancia e a postura sao amostradas SEMPRE, ate parado -- ficar parado
	# longe e ficar parado colado sao leituras diferentes e pedem respostas
	# diferentes.
	_distancia = lerpf(_distancia, pos_chefe.distance_to(pos_jogador), peso) if _observou else pos_chefe.distance_to(pos_jogador)
	_fracao_parado = lerpf(_fracao_parado, parado, peso) if _observou else parado
	_observou = true

	if parado > 0.5:
		return

	# O lado e medido contra a NORMAL da linha chefe->jogador, e nao contra um
	# eixo do mundo: "ele sempre desvia para a direita" so quer dizer alguma
	# coisa em relacao a linha de tiro. Medido em eixo do mundo, o mesmo habito
	# leria como vies oposto quando o jogador circulasse para o outro lado.
	var radial := (pos_jogador - pos_chefe)
	if radial.length_squared() < 1.0:
		return
	radial = radial.normalized()
	var normal := Vector2(-radial.y, radial.x)
	var lateral := clampf(velocidade.dot(normal) / rapidez, -1.0, 1.0)

	_vies = lerpf(_vies, lateral, peso)
	_segundos_movendo += delta


## Para que lado ele costuma desviar da linha de tiro: -1 a +1, 0 = sem vies.
func lado_previsto() -> float:
	return clampf(_vies, -1.0, 1.0)


func distancia_media() -> float:
	return _distancia


## Quanto do tempo ele passa quieto, atirando em vez de se mexer: 0 a 1.
func fracao_parado() -> float:
	return clampf(_fracao_parado, 0.0, 1.0)


func postura() -> int:
	if _distancia <= RAIO_COLADO:
		return Postura.COLADO
	if _distancia >= RAIO_LONGE:
		return Postura.LONGE
	return Postura.MEIO


## O quanto vale confiar no que foi lido ate agora: 0 a 1.
##
## Quem usa o perfil MULTIPLICA a correcao por isto. E o que garante que os
## primeiros ataques da luta saiam limpos, sem antecipacao -- que e tambem o que
## o texto do chefe pede, ao dizer que o primeiro disparo e previsivel.
func confianca() -> float:
	return clampf(_segundos_movendo / SEGUNDOS_PARA_CONFIANCA, 0.0, 1.0)


## Zera a leitura. Usado na virada de fase quando ela se declara recalculando.
func esquecer() -> void:
	_vies = 0.0
	_segundos_movendo = 0.0
