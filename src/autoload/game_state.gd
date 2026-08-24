extends Node
## Estado da run atual. Nao guarda meta-progressao ainda (fica para o pos-MVP).

enum Estado { MENU, JOGANDO, PAUSADO, GAME_OVER, VITORIA }

var estado: int = Estado.MENU
## A run e medida em SALAS. Havia aqui um par onda_atual/total_ondas, de quando
## cada sala rodava uma sequencia de ondas; com a composicao decidida na
## montagem do andar nao existe mais indice de onda para contar.
var salas_limpas: int = 0
var total_salas: int = 0
var creditos: int = 0
var inimigos_mortos: int = 0
var tempo_run: float = 0.0

## Quanto durou a luta do chefe, do momento em que ela se revela ate a morte
## dela. Existe por causa de uma pergunta do playtest: "quanto a luta PARECEU
## durar, e quanto durou de verdade?". Sem este numero na tela de fim, a segunda
## metade da pergunta depende da memoria do testador -- e memoria de luta dificil
## nao e fonte confiavel de tuning.
var tempo_chefe: float = 0.0
## Marca de `tempo_run` quando a Diretora se revelou. -1 = ela nao apareceu.
var _chefe_comecou: float = -1.0

const CENA_MAIN := "res://src/main/main.tscn"


## Mede pelo `tempo_run`, e nao por um relogio proprio: assim a pausa e o
## hitstop ja saem descontados de graca, sem ninguem lembrar de descontar.
func _ready() -> void:
	EventBus.boss_revelado.connect(func(_nome: String, _vida: int) -> void:
		_chefe_comecou = tempo_run
	)
	EventBus.boss_morreu.connect(func() -> void: _fechar_cronometro_do_chefe())


func _process(delta: float) -> void:
	if estado == Estado.JOGANDO:
		tempo_run += delta


func iniciar_run() -> void:
	estado = Estado.JOGANDO
	salas_limpas = 0
	total_salas = 0
	creditos = 0
	inimigos_mortos = 0
	tempo_run = 0.0
	tempo_chefe = 0.0
	_chefe_comecou = -1.0
	Deterioracao.resetar()
	# Implante e progressao de run, nao meta-progressao: run nova comeca limpa.
	Modificadores.resetar()
	Deterioracao.passiva_ativa = true
	get_tree().paused = false
	Engine.time_scale = 1.0


func terminar_run(venceu: bool) -> void:
	if estado == Estado.GAME_OVER or estado == Estado.VITORIA:
		return
	estado = Estado.VITORIA if venceu else Estado.GAME_OVER
	# Morrer PARA o chefe tambem encerra a luta, e e o caso mais informativo de
	# todos para o tuning: e a luta que passou do ponto.
	_fechar_cronometro_do_chefe()
	Deterioracao.passiva_ativa = false
	EventBus.run_terminada.emit(venceu, estatisticas())


func estatisticas() -> Dictionary:
	return {
		"salas_limpas": salas_limpas,
		"tempo_chefe": tempo_chefe,
		"total_salas": total_salas,
		"inimigos_mortos": inimigos_mortos,
		"creditos": creditos,
		"tempo": tempo_run,
		"deterioracao_final": Deterioracao.valor,
	}


## Idempotente: chamado pela morte da Diretora e de novo pelo fim da run, e o
## segundo nao pode esticar o tempo ate a tela de fim aparecer.
func _fechar_cronometro_do_chefe() -> void:
	if _chefe_comecou < 0.0 or tempo_chefe > 0.0:
		return
	tempo_chefe = maxf(tempo_run - _chefe_comecou, 0.0)


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
