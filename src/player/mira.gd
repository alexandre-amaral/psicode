extends Sprite2D
## O reticulo de mira, colado no MOUSE e nao no personagem.
##
## Antes a mira era um cano ciano preso ao corpo: ele girava com o `Visual` e
## dizia o angulo do tiro, mas nao dizia PARA ONDE. Num twin-stick isso e meio
## aviso -- o jogador sabia a inclinacao e tinha de adivinhar o alcance daquela
## linha no chao. O reticulo resolve mostrando o ponto.
##
## Ele NAO indica distancia de tiro. O alcance continua sendo o do `.tres` da
## arma, e mirar longe nao faz a bala chegar mais longe. O que ele mostra e a
## DIRECAO, ancorada onde o jogador ja esta olhando.
##
## A rotacao do `Visual` do Player continua igual: e dela que a boca da arma
## herda a posicao, e mexer nisso faria todo projetil nascer no lugar errado.
##
## Ele tambem e o dono do cursor do sistema. Dois cursores na tela -- a seta e o
## reticulo -- e pior que nenhum, e quem sabe quando o reticulo esta em cena e
## este no. Por isso `PROCESS_MODE_ALWAYS`: com a arvore pausada ele ainda
## precisa rodar para devolver a seta ao menu de pausa.

## Acima dos atores, abaixo da HUD (que vive num CanvasLayer proprio).
const Z := 15

var _cursor_escondido: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# `top_level` desliga a transform do pai: o reticulo vive em coordenadas de
	# mundo, e nao presas ao corpo que ele deixou de acompanhar.
	top_level = true
	z_index = Z
	visible = false


func _process(_delta: float) -> void:
	var ativa := _deve_aparecer()
	visible = ativa
	if ativa:
		global_position = get_global_mouse_position()
	_mostrar_cursor(not ativa)


## So durante a run, e so com o jogo correndo. Pausado, o menu precisa da seta
## de volta; na tela de fim, tambem.
func _deve_aparecer() -> bool:
	if get_tree().paused:
		return false
	return GameState.estado == GameState.Estado.JOGANDO


func _exit_tree() -> void:
	# Trocar de cena com o cursor escondido deixaria o menu inteiro sem seta.
	_mostrar_cursor(true)


## Troca o modo SO quando ele muda: chamar `set_mouse_mode` todo frame e pedir
## ao sistema operacional a mesma coisa 60 vezes por segundo.
func _mostrar_cursor(mostrar: bool) -> void:
	if mostrar == not _cursor_escondido:
		return
	_cursor_escondido = not mostrar
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if _cursor_escondido else Input.MOUSE_MODE_VISIBLE
