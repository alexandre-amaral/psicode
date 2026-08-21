extends Node
## Estado da run atual. Nao guarda meta-progressao ainda (fica para o pos-MVP).

enum Estado { MENU, JOGANDO, PAUSADO, GAME_OVER, VITORIA }

var estado: int = Estado.MENU
var onda_atual: int = 0
var total_ondas: int = 0
var creditos: int = 0
var inimigos_mortos: int = 0
var tempo_run: float = 0.0

const CENA_MAIN := "res://src/main/main.tscn"


func _process(delta: float) -> void:
	if estado == Estado.JOGANDO:
		tempo_run += delta


func iniciar_run() -> void:
	estado = Estado.JOGANDO
	onda_atual = 0
	creditos = 0
	inimigos_mortos = 0
	tempo_run = 0.0
	Deterioracao.resetar()
	Deterioracao.passiva_ativa = true
	get_tree().paused = false
	Engine.time_scale = 1.0


func terminar_run(venceu: bool) -> void:
	if estado == Estado.GAME_OVER or estado == Estado.VITORIA:
		return
	estado = Estado.VITORIA if venceu else Estado.GAME_OVER
	Deterioracao.passiva_ativa = false
	EventBus.run_terminada.emit(venceu, estatisticas())


func estatisticas() -> Dictionary:
	return {
		"ondas": onda_atual,
		"total_ondas": total_ondas,
		"inimigos_mortos": inimigos_mortos,
		"creditos": creditos,
		"tempo": tempo_run,
		"deterioracao_final": Deterioracao.valor,
	}


func reiniciar() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	Deterioracao.resetar()
	estado = Estado.MENU
	get_tree().reload_current_scene()


func alternar_pausa() -> void:
	if estado == Estado.JOGANDO:
		estado = Estado.PAUSADO
		get_tree().paused = true
	elif estado == Estado.PAUSADO:
		estado = Estado.JOGANDO
		get_tree().paused = false


func formatar_tempo(segundos: float) -> String:
	var m := int(segundos) / 60
	var s := int(segundos) % 60
	return "%02d:%02d" % [m, s]
