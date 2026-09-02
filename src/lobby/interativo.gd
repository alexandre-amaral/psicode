class_name Interativo
extends Area2D
## Uma coisa com que da para interagir. Generico desde o primeiro dia.
##
## Hoje ele veste tres objetos -- a estacao de personagem, o terminal de
## historico e o elevador. Amanha ele veste NPC, loja, codex, porta especial e
## colecao, e e por isso que ele nasce generico em vez de cada um dos tres
## resolver a propria deteccao.
##
## O projeto ja pagou duas vezes por nao fazer isso: o telegrafo eram SETE
## implementacoes da mesma ideia e as duas que quebraram quebraram em silencio,
## e o mapa de angulo -> quadro so virou `Direcoes` depois de existir em dois
## lugares. Duas copias divergem, e a divergencia aparece em TELA e nunca no
## console.
##
## Ele nao sabe o que faz -- so avisa que foi acionado. Quem decide e quem
## conecta `interagido`.

## Emitido quando o jogador aciona. `quem` e o corpo que interagiu.
signal interagido(quem: Node2D)

## O identificador, para quem precisa saber QUAL objeto foi acionado sem
## comparar referencia de no.
@export var id: StringName = &""

## O que o prompt mostra: "Selecionar Raven", "Historico de Runs".
##
## Sem o "[E]" -- o prefixo e a TECLA, e ela e do detector e nao do objeto. Um
## dia isso vira um icone de gamepad, e nao da para reescrever vinte objetos.
@export var texto: String = "Interagir"

## Desligado nao aparece no prompt e nao aceita acionamento.
##
## Existe porque area fechada, upgrade nao comprado e personagem bloqueado sao
## os tres casos que o plano ja preve, e todos os tres sao "o objeto esta la mas
## nao serve ainda" -- que le muito melhor que o objeto simplesmente nao existir.
@export var habilitado: bool = true:
	set(valor):
		habilitado = valor
		monitorable = valor

## O raio em que o jogador precisa entrar.
@export var alcance: float = 48.0:
	set(valor):
		alcance = valor
		if _forma != null:
			_forma.shape = _circulo(valor)

var _forma: CollisionShape2D = null


func _ready() -> void:
	# A forma nasce em codigo e nao no `.tscn`.
	#
	# Sub-resource num `.tscn` e COMPARTILHADO entre instancias -- a armadilha
	# ja registrada no projeto. Com tres estacoes usando esta cena, mudar o
	# alcance de uma mudaria o das outras duas, sem erro nenhum.
	_forma = CollisionShape2D.new()
	_forma.shape = _circulo(alcance)
	add_child(_forma)
	monitorable = habilitado
	# Ele e detectado, nao detecta: quem varre e o `DetectorDeInteracao` do
	# jogador. Dois lados monitorando seria o dobro de trabalho da fisica para a
	# mesma resposta.
	monitoring = false


## Aciona, se puder. `false` quando esta desligado.
func acionar(quem: Node2D) -> bool:
	if not habilitado:
		return false
	interagido.emit(quem)
	return true


func _circulo(raio: float) -> CircleShape2D:
	var forma := CircleShape2D.new()
	forma.radius = maxf(raio, 1.0)
	return forma
