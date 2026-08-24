class_name Arma
extends Node2D
## Componente de disparo. Vive tanto no jogador quanto nos inimigos.
## Toda a personalidade vem do DadosArma equipado -- este script so cuida
## de cadencia, municao e de colocar os projeteis no lugar certo da arvore.

signal disparou(direcao: Vector2, dados: DadosArma)
## (balas no pente, reserva). Reserva -1 = infinita. Antes do sistema de pente
## isto era (municao, municao_maxima) -- quem escuta precisa ler os dois campos
## com o significado novo.
signal municao_alterada(no_pente: int, reserva: int)
signal ficou_sem_municao()
signal recarga_iniciada(duracao: float)
signal recarga_concluida()

const CENA_PROJETIL := preload("res://src/projectiles/projetil.tscn")

@export var dados: DadosArma
## Projeteis disparados por este componente ferem o jogador?
@export var hostil: bool = false
## Multiplicador extra de velocidade de projetil (a Deterioracao mexe aqui).
var multiplicador_velocidade: float = 1.0

## Balas no pente agora. `municao` continua sendo a RESERVA (-1 = infinita),
## para nao quebrar quem ja le esse campo.
var municao_pente: int = 0
var municao: int = -1
var recarregando: bool = false

## Cooldown ENTRE TIROS (vem da cadencia). Nada a ver com recarregar o pente.
var _t_cadencia: float = 0.0
## Tempo restante da recarga em andamento.
var _t_recarga: float = 0.0
var _gatilho_solto: bool = true


func _ready() -> void:
	if dados != null:
		equipar(dados)


func _process(delta: float) -> void:
	if _t_cadencia > 0.0:
		_t_cadencia -= delta

	if not recarregando:
		return
	_t_recarga -= delta
	if _t_recarga <= 0.0:
		_concluir_recarga()


func equipar(novos_dados: DadosArma) -> void:
	dados = novos_dados
	municao = -1 if dados.municao_infinita() else dados.municao_maxima
	municao_pente = dados.pente()
	_t_cadencia = 0.0
	recarregando = false
	_t_recarga = 0.0
	_avisar_municao()


func pode_atirar() -> bool:
	if dados == null or _t_cadencia > 0.0 or recarregando:
		return false
	if municao_pente <= 0:
		return false
	if not dados.automatica and not _gatilho_solto:
		return false
	return true


## Da para recarregar? Pente cheio nao recarrega (evita cancelar o proprio tiro
## sem querer), e reserva vazia tambem nao.
func pode_recarregar() -> bool:
	if dados == null or recarregando:
		return false
	if municao_pente >= dados.pente():
		return false
	if not dados.municao_infinita() and municao <= 0:
		return false
	return true


func recarregar() -> bool:
	if not pode_recarregar():
		return false
	recarregando = true
	_t_recarga = maxf(dados.tempo_recarga, 0.05)
	recarga_iniciada.emit(_t_recarga)
	return true


func _concluir_recarga() -> void:
	recarregando = false
	_t_recarga = 0.0

	var falta := dados.pente() - municao_pente
	if dados.municao_infinita():
		municao_pente = dados.pente()
	else:
		# Reserva finita entrega so o que tem.
		var tirado := mini(falta, municao)
		municao_pente += tirado
		municao -= tirado

	_avisar_municao()
	recarga_concluida.emit()

	# Reserva acabou E o pente tambem: so agora a arma esta de fato morta.
	# E isto que faz uma arma de loot ser descartada -- com reserva infinita
	# nunca acontece, e a arma fica para sempre.
	if not dados.municao_infinita() and municao <= 0 and municao_pente <= 0:
		ficou_sem_municao.emit()


func _avisar_municao() -> void:
	municao_alterada.emit(municao_pente, municao)


## Chame todo frame com o estado do gatilho. Resolve semi-automatico sem que
## quem usa precise controlar "just_pressed" na mao.
func atualizar_gatilho(pressionado: bool) -> void:
	if not pressionado:
		_gatilho_solto = true


func atirar(direcao: Vector2) -> bool:
	if not pode_atirar():
		# Gatilho puxado com o pente vazio recarrega sozinho: sem isto o
		# jogador clica no nada e nao entende por que parou de atirar.
		if dados != null and municao_pente <= 0 and not recarregando:
			recarregar()
		return false

	_gatilho_solto = false
	# Dividir, nao multiplicar: intervalo e o inverso da cadencia, entao
	# cadencia maior tem de encurtar a espera.
	_t_cadencia = dados.intervalo() / maxf(_multiplicador_cadencia(), 0.01)

	municao_pente -= 1
	_avisar_municao()

	var origem := global_position
	var direcoes := Balistica.leque(direcao, dados.projeteis_por_tiro, dados.abertura_graus)
	var container := _container()

	for d in direcoes:
		var desvio := deg_to_rad(randf_range(-dados.impressao_graus, dados.impressao_graus))
		var p := CENA_PROJETIL.instantiate()
		container.add_child(p)
		p.configurar(
			origem,
			d.rotated(desvio),
			dados,
			hostil,
			multiplicador_velocidade * _multiplicador_velocidade_projetil(),
			_bonus_dano(),
			_multiplicador_dano()
		)

	disparou.emit(direcao, dados)

	# O bonus da Celula de Eco vale por TIRO, nao por projetil: uma shotgun de
	# oito bagos consome um tiro de eco, nao oito.
	if not hostil:
		Modificadores.consumir_tiro_de_eco()

	# Pente vazio recarrega sozinho, sem esperar o proximo clique.
	if municao_pente <= 0:
		recarregar()

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


func _multiplicador_dano() -> float:
	if hostil:
		return 1.0
	return Modificadores.multiplicador_dano()


func _multiplicador_velocidade_projetil() -> float:
	if hostil:
		return 1.0
	return Modificadores.multiplicador_velocidade_projetil()
