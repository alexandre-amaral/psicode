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
		print("Sala: Sinal onda_completa conectado.")

func ativar() -> void:
	estado = Estado.OCUPADA
	if waves:
		waves.iniciar()
	_trancar_portas()
	EventBus.sala_entrada.emit(self)

func _ao_onda_completa(indice: int) -> void:
	print("Sala: onda_completa recebido. Indice: %d" % indice)
	if waves:
		print("Sala: Total de ondas: %d, Indice atual: %d" % [waves.ondas.size(), waves.indice])
		if waves.indice >= waves.ondas.size() - 1:
			_limpar_sala()

func _limpar_sala() -> void:
	print("Sala: Executando _limpar_sala(). Abrindo portas.")
	estado = Estado.LIMPA
	_abrir_portas()
	EventBus.sala_limpa.emit(self)

func _trancar_portas() -> void:
	for porta in portas.get_children():
		if porta.has_method("fechar"):
			porta.fechar()

func _abrir_portas() -> void:
	print("Sala: Tentando abrir portas. Portas encontradas: %d" % portas.get_child_count())
	for porta in portas.get_children():
		print("Sala: Tentando abrir porta: %s" % porta.name)
		if porta.has_method("abrir"):
			porta.abrir()
			print("Sala: Porta %s aberta com sucesso." % porta.name)

func obter_limites() -> Rect2:
	# Por simplificacao inicial, assume retangulo. 
	# Para formatos L, isso sera expandido.
	var meia := tamanho_celula * 0.5
	return Rect2(global_position - meia, tamanho_celula)
