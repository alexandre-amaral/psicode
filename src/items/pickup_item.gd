extends Area2D
## Implante no chao. Encoste para instalar; o efeito vale ate o fim da run.
##
## Decisao de design: este pickup NAO chama metodo no Player. Ele entrega o
## implante ao autoload Modificadores e quem sofre o efeito le de la no frame
## em que precisa. E o mesmo caminho da Deterioracao, e e mais fiel a regra do
## EventBus que o `corpo.equipar_arma_loot()` do pickup de arma -- que so ficou
## assim porque arma equipada e estado do proprio Player.

## Preenchido = este implante especifico. Vazio = sorteia do pool ao nascer.
@export var dados: DadosItem
@export var pool: PoolLoot
@export var gira: bool = true

var _t: float = 0.0
var _visual: Node2D
var _rotulo: Label


func _ready() -> void:
	_visual = $Visual
	_rotulo = $Rotulo

	# O sorteio vem ANTES de pintar: o visual e o rotulo leem `dados`, e
	# sortear depois deixaria um implante sem cor e chamado "IMPLANTE".
	if dados == null and pool != null:
		dados = pool.sortear_item()

	if dados != null:
		$Visual/Corpo.color = dados.cor
		_rotulo.text = dados.nome
		_rotulo.modulate = dados.cor
		# Sigla fica FORA do Visual: o Visual gira, e texto girando fica de
		# cabeca para baixo metade do tempo.
		$Sigla.text = dados.sigla
		$Sigla.modulate = dados.cor

	body_entered.connect(_ao_encostar)


func _process(delta: float) -> void:
	_t += delta
	if _visual != null:
		_visual.position.y = sin(_t * 3.0) * 5.0
		if gira:
			_visual.rotation += delta * 1.2


func _ao_encostar(corpo: Node) -> void:
	if not corpo.is_in_group("player") or dados == null:
		return
	# So some se foi mesmo instalado. Implante no limite por run devolve false,
	# e o pickup fica no chao em vez de evaporar sem dar nada.
	if not Modificadores.aplicar(dados):
		return

	var fx := preload("res://src/fx/impacto.tscn").instantiate()
	fx.global_position = global_position
	fx.modulate = dados.cor
	get_parent().add_child(fx)
	queue_free()
