class_name TelaTrocaDeArma
extends CanvasLayer
## A escolha que a TERCEIRA arma cobra: qual dos dois slots ela ocupa.
##
## Ela existe porque o jogo nunca decide pelo jogador (§22 do plano). Mesmo que
## a arma nova seja melhor em todos os quatro atributos, quem troca e ele -- uma
## arma "pior" pode ser a que combina com os implantes que ele pegou, e o jogo
## nao sabe disso.
##
## **Cancelar nao custa nada, e isso e a regra que sustenta o resto.** A arma
## continua no chao, o inventario continua igual e nenhum credito saiu. E o que
## permite o jogador sair da sala, comparar, voltar e trocar depois -- sem essa
## garantia toda tela de troca vira uma armadilha, e o jogador aprende a nao
## encostar em arma nenhuma.
##
## Ela e SEPARADA da tela de inventario de proposito (§58): esta acontece no
## meio de um combate interrompido e precisa ser rapida e contextual; aquela e
## uma consulta. Uma tela so teria de servir aos dois ritmos e nao serviria a
## nenhum.

## O slot escolhido, ou -1 se cancelou.
signal decidida(indice: int)

const CENA := "res://src/ui/tela_troca_de_arma.tscn"

var _painel: PainelDeTroca
var _nova: DadosArma = null
var _decidiu: bool = false

## Ela mesma pausou a arvore? Guardado porque a tela pode ser aberta com o jogo
## ja pausado por outro caminho, e despausar ali devolveria o combate por baixo
## de um menu que continua aberto.
var _pausou: bool = false


## Abre a escolha e devolve a tela, para quem chamou poder `await tela.decidida`.
##
## **A tela e criada por quem PEDE, e nao mora na cena.** O pickup e a bancada
## sao os dois pedintes, e nenhum dos dois sabe da existencia do outro: uma tela
## permanente em `main.tscn` teria de ser encontrada por caminho de no -- que e
## a regra 1 do projeto invertida -- ou por grupo, o que traria de volta a
## loteria de ordem que o `container_projeteis` ja cobrou de duas suites.
static func abrir(pai: Node, nova: DadosArma, inventario: InventarioDeArmas) -> TelaTrocaDeArma:
	var tela: TelaTrocaDeArma = load(CENA).instantiate()
	pai.add_child(tela)
	tela.montar(nova, inventario)
	return tela


func _ready() -> void:
	# Sem isto a tela congela junto com a arvore que ela mesma pausou, e a
	# escolha nunca chega -- o jogo trava num painel que nao aceita tecla.
	# Mesmo cuidado do `menu_pausa` e do reticulo.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_painel = $Painel


func montar(nova: DadosArma, inventario: InventarioDeArmas) -> void:
	_nova = nova
	_painel.nova = nova
	_painel.atuais = [
		inventario.slot(0).dados if inventario.slot(0) != null else null,
		inventario.slot(1).dados if inventario.slot(1) != null else null,
	]
	_painel.queue_redraw()
	_centralizar()

	if not get_tree().paused:
		get_tree().paused = true
		_pausou = true
	# O reticulo devolve a seta do sistema sozinho ao ver a arvore pausada, e por
	# isso esta tela nao mexe em `Input.mouse_mode`: dois donos do cursor
	# produzem uma seta que aparece ou some conforme a ordem das chamadas.


func _centralizar() -> void:
	var tela := get_viewport().get_visible_rect().size
	var alturas: float = _painel.caixa_do_slot(1).end.y + 44.0
	_painel.size = Vector2(PainelDeTroca.LARGURA_PAINEL, alturas)
	_painel.position = ((tela - _painel.size) * 0.5).floor()


func _unhandled_input(evento: InputEvent) -> void:
	if _decidiu:
		return
	if evento.is_action_pressed("selecionar_slot_1"):
		_decidir(0)
	elif evento.is_action_pressed("selecionar_slot_2"):
		_decidir(1)
	elif evento.is_action_pressed("pausar") or evento.is_action_pressed("ui_cancel"):
		_decidir(-1)
	elif evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		_clicar(evento.position)
	elif evento is InputEventMouseMotion:
		_passar(evento.position)


func _clicar(posicao: Vector2) -> void:
	var indice := _slot_sob(posicao)
	if indice >= 0:
		_decidir(indice)


func _passar(posicao: Vector2) -> void:
	var indice := _slot_sob(posicao)
	if _painel.destaque == indice:
		return
	_painel.destaque = indice
	_painel.queue_redraw()


## Qual cartao esta sob o ponto, em coordenada de TELA.
##
## Ela pergunta ao painel onde ele DESENHOU o cartao, em vez de recalcular a
## caixa: dois calculos da mesma geometria divergem, e o sintoma seria a tela
## clicavel num lugar e desenhada noutro -- sem erro nenhum no console.
func _slot_sob(posicao: Vector2) -> int:
	for i in 2:
		var caixa := _painel.caixa_do_slot(i)
		if Rect2(caixa.position + _painel.position, caixa.size).has_point(posicao):
			return i
	return -1


func _decidir(indice: int) -> void:
	_decidiu = true
	if _pausou:
		get_tree().paused = false
	decidida.emit(indice)
	queue_free()
