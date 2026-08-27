class_name SpriteDirecional
extends Sprite2D
## Um Sprite2D que sabe encarar oito direcoes e rodar um ciclo de caminhada.
##
## A decisao de design: sprite direcional e um NO, nao um trecho de codigo
## copiado para dentro de cada inimigo. Composicao em vez de heranca, como manda
## o GEMINI.md, e com um motivo concreto -- o mapa de angulo para quadro erra
## calado, entao o proximo inimigo com arte tem de custar um `.tscn` e nao uma
## segunda copia da mesma matematica.
##
## Escala e deslocamento NAO sao `@export` daqui: este script E o Sprite2D,
## entao `scale` e `position` do proprio no ja fazem esse papel no Inspetor. Um
## campo a menos para divergir do que esta desenhado.
##
## Ele nao le nada sozinho: quem chama `apontar()` e o dono, que e quem sabe se
## esta perseguindo, telegrafando ou apenas escorregando por knockback.

## As oito rotacoes paradas, NESTA ORDEM:
##
##   0 leste  1 sudeste  2 sul  3 sudoeste  4 oeste  5 noroeste  6 norte  7 nordeste
##
## E a ordem de `Direcoes`, e a mesma que tools/sprites/gerar_sprites.py usa.
@export var sprites_parado: Array[Texture2D] = []
## As mesmas oito direcoes, mas cada entrada e uma FITA horizontal com o ciclo
## inteiro -- lida por `hframes`, nao por textura solta. Vazio desliga a
## animacao e o inimigo anda na pose de parado, sem erro nenhum.
@export var sprites_andando: Array[Texture2D] = []
## Quantos quadros cada fita tem. Precisa bater com a largura do arquivo: fita
## de 9 quadros lida como 8 mostra fatias cortadas de dois quadros ao mesmo
## tempo, sem uma linha no console.
@export var quadros_andando: int = 9
## Cadencia do ciclo. NAO e a do arquivo: os GIFs de origem vem a 5 FPS, o que
## deixaria o ciclo em camera lenta.
@export var fps_andando: float = 12.0

## A velocidade em que `fps_andando` esta certo, em px/s. Acima dela o ciclo
## acelera; abaixo, desacelera. ZERO = cadencia fixa, o comportamento antigo.
##
## Ciclo de caminhada deveria seguir o CHAO, e nao o relogio -- senao qualquer
## bicho com mais de uma velocidade desliza. E "uma velocidade so" nao existe de
## verdade neste jogo: a Deterioracao multiplica a velocidade de todo inimigo
## ate 1,55x. O caso extremo e a Cyber-Besta, que anda a 88 px/s e investe a 720:
## com cadencia fixa, a investida corria 8,2x mais rapido que o passo que as
## patas mostravam.
##
## Fica opcional em vez de virar padrao porque um sprite direcional pode um dia
## animar PARADO -- um bicho que respira, uma torre que gira. Zero mantem esse
## caso possivel, e deixa a escolha legivel no `.tscn` de quem a fez.
@export var velocidade_referencia: float = 0.0

## Teto do multiplicador de cadencia. So vale com `velocidade_referencia` > 0.
##
## Sem teto, a investida da Cyber-Besta rodaria o ciclo de 9 quadros 4,6 vezes
## em 0,42 s: com filtro Nearest isso vira ruido, e a investida e justamente o
## momento que precisa ser lido. A 3x, ela sai a 36 fps -- galope, nao estrobo.
@export var aceleracao_maxima_do_ciclo: float = 3.0

## Posicao no ciclo, em quadros. Float porque o avanco e continuo; quem indexa a
## fita e o int() dele.
var _t_ciclo: float = 0.0


func _ready() -> void:
	# Um quadro ja aqui: sem isto o no nasce sem textura e o inimigo some ate o
	# primeiro passo de fisica.
	_trocar_quadro(_parado_para(Vector2.DOWN), 1, 0)


## Encara `direcao` e, se `andando`, avanca o ciclo de caminhada.
##
## `movimento` e para onde o corpo de fato desliza, e serve so para escolher o
## SENTIDO do ciclo. Separado de `direcao` de proposito: o inimigo continua
## encarando o alvo enquanto o knockback o empurra para tras, e rodar o ciclo
## para a frente nesse instante e moonwalk.
func apontar(direcao: Vector2, andando: bool, delta: float, movimento := Vector2.ZERO) -> void:
	var fita: Texture2D = _andando_para(direcao) if andando else null
	if fita != null:
		_avancar_ciclo(delta, direcao, movimento)
		_trocar_quadro(fita, quadros_andando, int(_t_ciclo) % quadros_andando)
		return
	_t_ciclo = 0.0
	_trocar_quadro(_parado_para(direcao), 1, 0)


## Se este conjunto tem ciclo de caminhada. Existe para quem le nao precisar
## saber que o desligamento e "lista vazia".
func tem_ciclo() -> bool:
	return sprites_andando.size() >= Direcoes.TOTAL and quadros_andando >= 2


func _parado_para(direcao: Vector2) -> Texture2D:
	if sprites_parado.size() < Direcoes.TOTAL:
		return null
	return sprites_parado[Direcoes.indice(direcao)]


func _andando_para(direcao: Vector2) -> Texture2D:
	if not tem_ciclo():
		return null
	return sprites_andando[Direcoes.indice(direcao)]


## Anda o ciclo, para a frente ou para tras, no ritmo do chao.
func _avancar_ciclo(delta: float, direcao: Vector2, movimento: Vector2) -> void:
	var sentido := -1.0 if movimento.dot(direcao) < 0.0 else 1.0
	_t_ciclo += delta * fps_andando * _fator_de_cadencia(movimento) * sentido
	# fposmod e nao fmod: com sentido negativo o fmod devolve negativo, e o
	# int() disso indexaria fora da fita.
	_t_ciclo = fposmod(_t_ciclo, float(quadros_andando))


## Quantas vezes a cadencia base, dada a velocidade de agora.
##
## Com `velocidade_referencia` zerada devolve 1.0 e nada muda -- e o que mantem
## intacto quem nao optou por seguir o chao.
func _fator_de_cadencia(movimento: Vector2) -> float:
	if velocidade_referencia <= 0.0:
		return 1.0
	return clampf(
		movimento.length() / velocidade_referencia,
		0.0,
		maxf(aceleracao_maxima_do_ciclo, 0.0)
	)


## Textura, hframes e quadro SEMPRE juntos.
##
## Trocar `texture` sem trocar `hframes` desenha a fita de 9 quadros inteira
## espremida no lugar do inimigo -- e o inverso, uma pose parada com hframes 9,
## mostra um nono dele. Nao ha erro no console em nenhum dos dois casos.
func _trocar_quadro(textura: Texture2D, colunas: int, quadro: int) -> void:
	if textura == null:
		return
	if texture != textura:
		texture = textura
		hframes = colunas
	if frame != quadro:
		frame = quadro
