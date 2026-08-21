extends Node2D
## Classe base para uma sala.
## Gerencia seu estado (trancada/limpa) e limites.

enum Estado { INATIVA, OCUPADA, LIMPA }

@export var tamanho_celula: Vector2 = Vector2(1600, 900)
@export var tipo: String = "combate"

var estado: int = Estado.INATIVA
var coordenadas_grid: Vector2 = Vector2.ZERO

@onready var portas: Node2D = $Portas
@onready var waves: GerenciadorOndas = $Ondas

func _ready() -> void:
	add_to_group("salas")
	if waves:
		waves.onda_completa.connect(_ao_onda_completa)

func ativar() -> void:
	estado = Estado.OCUPADA
	if waves:
		waves.iniciar()
	_trancar_portas()
	EventBus.sala_entrada.emit(self)

func _ao_onda_completa(_indice: int) -> void:
	if waves and waves.indice >= waves.ondas.size() - 1:
		_limpar_sala()

func _limpar_sala() -> void:
	estado = Estado.LIMPA
	_abrir_portas()
	EventBus.sala_limpa.emit(self)

func _trancar_portas() -> void:
	for porta in portas.get_children():
		if porta.has_method("fechar"):
			porta.fechar()

func _abrir_portas() -> void:
	for porta in portas.get_children():
		if porta.has_method("abrir"):
			porta.abrir()

func obter_limites() -> Rect2:
	# Por simplificacao inicial, assume retangulo. 
	# Para formatos L, isso sera expandido.
	var meia := tamanho_celula * 0.5
	return Rect2(global_position - meia, tamanho_celula)
