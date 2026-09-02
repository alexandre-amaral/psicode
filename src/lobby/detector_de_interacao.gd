class_name DetectorDeInteracao
extends Area2D
## O lado do JOGADOR da interacao: quem esta perto, e o que a tecla aciona.
##
## Ele existe separado do `Interativo` porque as duas perguntas sao diferentes.
## O objeto sabe o que ele e; o detector sabe **qual deles ganha** quando ha
## mais de um por perto -- e essa segunda pergunta nao tem dono natural entre os
## objetos, porque nenhum deles enxerga os outros.
##
## Ele vive no Lobby e nao no jogo inteiro de proposito: a run nao tem nada com
## que interagir, e um detector varrendo a cada frame durante o combate seria
## trabalho de fisica pago para sempre por uma resposta que e sempre `null`.

## Emitido quando o alvo muda. `null` = nao ha nada por perto.
##
## Entrega o OBJETO e nao o texto dele. Com o texto, quem escuta sabia o QUE
## dizer e nao ONDE dizer -- e o prompt precisa das duas coisas para nascer em
## cima da peca certa.
signal alvo_mudou(alvo: Interativo)

@export var dono: Node2D = null

var _perto: Array[Interativo] = []
var _alvo: Interativo = null


## O RAIO do detector, e ele e pequeno de proposito.
##
## Quem decide a que distancia se pode interagir e o OBJETO, pelo `alcance`
## dele: um terminal encostado na parede e um elevador de dois metros nao pedem
## a mesma aproximacao. Entao o detector representa so o CORPO do jogador, e o
## encontro acontece quando esse corpo entra no circulo do objeto.
##
## Um detector grande inverteria a autoridade -- o alcance passaria a ser o
## maior dos dois --, e o `alcance` de cada peca viraria enfeite.
const RAIO := 8.0


func _ready() -> void:
	# A FORMA, e ela nasce aqui porque sem forma uma `Area2D` NAO DETECTA NADA.
	#
	# A primeira versao nao tinha: monitoring ligado, mask aberta, o objeto
	# monitorable e a 44 px de um alcance de 64 -- e zero sobreposicoes. Nao ha
	# erro no console para uma area sem forma; ela simplesmente nunca encontra
	# ninguem, e o prompt nunca aparece.
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = RAIO
	forma.shape = circulo
	add_child(forma)

	monitoring = true
	monitorable = false
	area_entered.connect(_ao_entrar)
	area_exited.connect(_ao_sair)
	if dono == null:
		dono = get_parent() as Node2D


func _process(_delta: float) -> void:
	_reavaliar()


func _unhandled_input(evento: InputEvent) -> void:
	if not evento.is_action_pressed("interagir"):
		return
	if _alvo == null:
		return
	# `set_input_as_handled` para o mesmo aperto nao vazar para outra coisa que
	# escute "interagir" -- o pickup de arma escuta, e acionar o elevador nao
	# pode trocar a arma do jogador no mesmo frame.
	get_viewport().set_input_as_handled()
	_alvo.acionar(dono)


## Quem esta acionavel agora, ou `null`.
func alvo() -> Interativo:
	return _alvo


func _ao_entrar(area: Area2D) -> void:
	var alvo := area as Interativo
	if alvo != null and not _perto.has(alvo):
		_perto.append(alvo)


func _ao_sair(area: Area2D) -> void:
	var alvo := area as Interativo
	if alvo != null:
		_perto.erase(alvo)


## O MAIS PROXIMO ganha, e a distancia e recalculada todo frame.
##
## Nao basta pegar o ultimo que entrou: com duas capsulas de personagem lado a
## lado, andar de uma para a outra sem sair do raio da primeira deixaria o
## prompt preso na errada -- o jogador leria "Selecionar Raven" parado na frente
## da Nova, e apertaria a tecla acreditando na tela.
##
## O laco tambem limpa quem morreu: um `Interativo` liberado enquanto o jogador
## estava dentro dele nunca emite `area_exited`.
func _reavaliar() -> void:
	var melhor: Interativo = null
	var menor := INF
	var vivos: Array[Interativo] = []
	for alvo in _perto:
		if not is_instance_valid(alvo):
			continue
		vivos.append(alvo)
		if not alvo.habilitado:
			continue
		var d := global_position.distance_squared_to(alvo.global_position)
		if d < menor:
			menor = d
			melhor = alvo
	_perto = vivos
	if melhor == _alvo:
		return
	_alvo = melhor
	alvo_mudou.emit(_alvo)
