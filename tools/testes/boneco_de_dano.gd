extends CharacterBody2D
## Alvo de teste: existe so para responder `receber_dano` e contar.
##
## As ameacas do jogo so ferem quem tem o metodo -- e o portao que impede uma
## area de tentar machucar uma parede. Um boneco de verdade e mais honesto que
## um dublê que so registra a chamada: ele passa pelo mesmo portao que o jogador.

var dano_levado: int = 0


func receber_dano(quantidade: int, _impulso: Vector2 = Vector2.ZERO) -> bool:
	dano_levado += quantidade
	return true
