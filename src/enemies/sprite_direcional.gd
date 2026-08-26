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


## Anda o ciclo, para a frente ou para tras.
func _avancar_ciclo(delta: float, direcao: Vector2, movimento: Vector2) -> void:
	var sentido := -1.0 if movimento.dot(direcao) < 0.0 else 1.0
	_t_ciclo += delta * fps_andando * sentido
	# fposmod e nao fmod: com sentido negativo o fmod devolve negativo, e o
	# int() disso indexaria fora da fita.
	_t_ciclo = fposmod(_t_ciclo, float(quadros_andando))


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
