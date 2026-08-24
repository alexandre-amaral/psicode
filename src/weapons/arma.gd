class_name Arma
extends Node2D
## Componente de disparo. Vive tanto no jogador quanto nos inimigos.
## Toda a personalidade vem do DadosArma equipado -- este script so cuida
## de cadencia, municao e de colocar os projeteis no lugar certo da arvore.

signal disparou(direcao: Vector2, dados: DadosArma)
signal municao_alterada(atual: int, maximo: int)
signal ficou_sem_municao()

const CENA_PROJETIL := preload("res://src/projectiles/projetil.tscn")

@export var dados: DadosArma
## Projeteis disparados por este componente ferem o jogador?
@export var hostil: bool = false
## Multiplicador extra de velocidade de projetil (a Deterioracao mexe aqui).
var multiplicador_velocidade: float = 1.0

var municao: int = -1
var _tempo_recarga: float = 0.0
var _gatilho_solto: bool = true


func _ready() -> void:
	if dados != null:
		equipar(dados)


func _process(delta: float) -> void:
	if _tempo_recarga > 0.0:
		_tempo_recarga -= delta


func equipar(novos_dados: DadosArma) -> void:
	dados = novos_dados
	municao = -1 if dados.municao_infinita() else dados.municao_maxima
	_tempo_recarga = 0.0
	municao_alterada.emit(municao, dados.municao_maxima)


func pode_atirar() -> bool:
	if dados == null or _tempo_recarga > 0.0:
		return false
	if not dados.municao_infinita() and municao <= 0:
		return false
	if not dados.automatica and not _gatilho_solto:
		return false
	return true


## Chame todo frame com o estado do gatilho. Resolve semi-automatico sem que
## quem usa precise controlar "just_pressed" na mao.
func atualizar_gatilho(pressionado: bool) -> void:
	if not pressionado:
		_gatilho_solto = true


func atirar(direcao: Vector2) -> bool:
	if not pode_atirar():
		return false

	_gatilho_solto = false
	# Dividir, nao multiplicar: intervalo e o inverso da cadencia, entao
	# cadencia maior tem de encurtar a espera.
	_tempo_recarga = dados.intervalo() / maxf(_multiplicador_cadencia(), 0.01)

	if not dados.municao_infinita():
		municao -= 1
		municao_alterada.emit(municao, dados.municao_maxima)

	var origem := global_position
	var direcoes := Balistica.leque(direcao, dados.projeteis_por_tiro, dados.abertura_graus)
	var container := _container()

	for d in direcoes:
		var desvio := deg_to_rad(randf_range(-dados.impressao_graus, dados.impressao_graus))
		var p := CENA_PROJETIL.instantiate()
		container.add_child(p)
		p.configurar(origem, d.rotated(desvio), dados, hostil, multiplicador_velocidade, _bonus_dano())

	disparou.emit(direcao, dados)

	if not dados.municao_infinita() and municao <= 0:
		ficou_sem_municao.emit()

	return true


## Projeteis nunca ficam pendurados no atirador -- se ficassem, herdariam a
## rotacao dele e se moveriam junto. Vao para um container neutro da arena.
func _container() -> Node:
	var c := get_tree().get_first_node_in_group("container_projeteis")
	if c != null:
		return c
	return get_tree().current_scene


## O PORTAO DOS IMPLANTES. Este mesmo script roda no Vigia e na Diretora
## (`hostil = true`), entao ler Modificadores sem conferir hostil transformaria
## um upgrade do jogador em buff dos inimigos -- um bug que nao aparece no
## console e quase nao aparece num playtest.
func _multiplicador_cadencia() -> float:
	if hostil:
		return 1.0
	return Modificadores.multiplicador_cadencia()


func _bonus_dano() -> int:
	if hostil:
		return 0
	return Modificadores.bonus_dano()
