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
const CENA_FEIXE := preload("res://src/weapons/feixe.tscn")

## Layers nomeadas no project.godot: 2 inimigo, 3 parede, 1 player.
const LAYER_INIMIGO := 2
const LAYER_PAREDE := 4
const LAYER_PLAYER := 1

## Feixe continuo. Vive enquanto o gatilho estiver apertado e some ao soltar.
var _feixe: Feixe = null
## Dano do feixe e por SEGUNDO e o dano do jogo e int: sem acumulador, arredondar
## 14/60 a cada frame daria zero para sempre e o laser nao machucaria ninguem.
var _dano_acumulado: float = 0.0

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
## Graus de dispersao acumulados por segurar o gatilho. Soma-se a
## `impressao_graus` no disparo e volta sozinho ao parar.
var _dispersao_extra: float = 0.0


func _ready() -> void:
	if dados != null:
		equipar(dados)


func _process(delta: float) -> void:
	if _t_cadencia > 0.0:
		_t_cadencia -= delta

	# Antes do return de baixo de proposito: a dispersao tem de continuar
	# baixando DURANTE a recarga. Depois do return, largar o gatilho para
	# recarregar congelaria o bloom, e a arma voltaria do pente novo tao imprecisa
	# quanto estava -- o oposto do que qualquer um espera.
	if dados != null and _dispersao_extra > 0.0:
		_dispersao_extra = dados.dispersao_apos(_dispersao_extra, delta)

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
	# Arma nova chega fria: herdar o bloom da anterior puniria a troca de arma
	# por um gatilho que nem era desta.
	_dispersao_extra = 0.0
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
		# O feixe e a UNICA arma que precisa saber que o gatilho soltou: as
		# outras so precisam saber que ele foi solto ALGUMA vez, para o
		# semi-automatico. Apagar aqui e o que garante que o laser nao fica
		# ligado quando o jogador para de atirar.
		_apagar_feixe()


func atirar(direcao: Vector2) -> bool:
	# O feixe desvia ANTES de pode_atirar(): ele nao tem cadencia por tiro nem
	# gatilho solto -- ele liga e fica ligado. Passar pelo portao normal faria o
	# laser piscar no ritmo da cadencia, que e o oposto de um feixe continuo.
	if dados != null and dados.e_feixe():
		return _manter_feixe(direcao)

	if not pode_atirar():
		# Gatilho puxado com o pente vazio recarrega sozinho: sem isto o
		# jogador clica no nada e nao entende por que parou de atirar.
		if dados != null and municao_pente <= 0 and not recarregando:
			recarregar()
		return false

	_gatilho_solto = false
	_consumir_tiro()
	# sortear_projeteis() e nao projeteis_por_tiro: a Riot-12 varia de 8 a 10 por
	# rajada, e uma escopeta que solta sempre o mesmo numero perde justamente a
	# incerteza que faz a arma. Arma sem variacao devolve o numero fixo.
	_emitir(Balistica.leque(direcao, dados.sortear_projeteis(), dados.abertura_graus))
	_apos_tiro(direcao)
	return true


## Dispara UMA vez em varias direcoes ao mesmo tempo.
##
## Existe porque chamar atirar() num laco NAO funciona: atirar() arma o cooldown
## de cadencia e pode_atirar() recusa todas as chamadas seguintes do mesmo frame
## -- o _process que decrementa esse cooldown so roda ENTRE frames, nunca no meio
## de um for. O anel da Diretora fazia exatamente isso com 20 direcoes e saia um
## projetil so, sem erro nenhum no console.
##
## Uma salva conta como UM tiro: gasta uma bala do pente e um cooldown, do mesmo
## jeito que a shotgun gasta uma bala para oito bagos.
##
## Cada direcao recebida vira um projetil. `projeteis_por_tiro` e
## `abertura_graus` NAO se aplicam aqui -- quem chama ja decidiu a forma da
## salva, e aplicar o leque por cima multiplicaria a quantidade sem ninguem
## pedir.
func atirar_varias(direcoes: Array[Vector2]) -> bool:
	if direcoes.is_empty() or not pode_atirar():
		return false

	_gatilho_solto = false
	_consumir_tiro()
	_emitir(direcoes)
	# O sinal pede uma direcao e uma salva radial nao tem "a" direcao; a
	# primeira serve de referencia para quem so quer saber que houve disparo.
	_apos_tiro(direcoes[0])
	return true


## Cadencia e bala. Um tiro = um cooldown = uma bala, independente de quantos
## projeteis ele coloca na tela.
func _consumir_tiro() -> void:
	# Dividir, nao multiplicar: intervalo e o inverso da cadencia, entao
	# cadencia maior tem de encurtar a espera.
	_t_cadencia = dados.intervalo() / maxf(_multiplicador_cadencia(), 0.01)
	municao_pente -= 1
	# Aqui, e nao em _emitir(): um tiro soma uma vez, mesmo soltando oito
	# projeteis. Em _emitir() uma shotgun encheria o bloom oito vezes mais rapido
	# que uma pistola de mesma cadencia.
	_dispersao_extra = dados.dispersao_apos_tiro(_dispersao_extra)
	# O PORTAO DOS IMPLANTES vale aqui como em tudo que le Modificadores: este
	# mesmo script roda no Vigia e na Diretora, e sem o guard os inimigos
	# comecariam a hackear o jogador.
	if not hostil:
		Modificadores.armar_hack()
	_avisar_municao()


func _emitir(direcoes: Array[Vector2]) -> void:
	var origem := global_position
	var container := _container()
	for d in direcoes:
		var espalhamento := dados.impressao_graus + _dispersao_extra
		var desvio := deg_to_rad(randf_range(-espalhamento, espalhamento))
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


func _apos_tiro(direcao: Vector2) -> void:
	disparou.emit(direcao, dados)

	# O bonus da Celula de Eco vale por TIRO, nao por projetil: uma shotgun de
	# oito bagos consome um tiro de eco, nao oito.
	if not hostil:
		Modificadores.consumir_tiro_de_eco()

	# Pente vazio recarrega sozinho, sem esperar o proximo clique.
	if municao_pente <= 0:
		recarregar()


## Projeteis nunca ficam pendurados no atirador -- se ficassem, herdariam a
## rotacao dele e se moveriam junto. Vao para um container neutro da arena.
# --------------------------------------------------------------- feixe ------
# O Laser Cutter e a unica arma que NAO instancia projetil. Ele existe como
# excecao declarada e nao como um segundo sistema de armas: tudo que da para
# reusar -- municao, pente, recarga, o portao dos implantes -- continua sendo o
# mesmo codigo. So o que acontece entre o cano e o alvo e diferente.


## Liga (ou mantem) o feixe neste frame. Devolve se ele esta ferindo alguem.
func _manter_feixe(direcao: Vector2) -> bool:
	if recarregando or municao_pente <= 0:
		_apagar_feixe()
		if municao_pente <= 0 and not recarregando:
			recarregar()
		return false

	_gatilho_solto = false
	# Delta da FISICA, nao do render. Quem puxa o gatilho e o `_physics_process`
	# do Player, e o raycast do feixe so faz sentido num passo de fisica de
	# qualquer jeito. Com o delta de render o dano por segundo do laser passava
	# a depender do framerate -- medido: 9 de dano onde o .tres pede 26.
	var delta := get_physics_process_delta_time()

	var origem := global_position
	var ponta := origem + direcao.normalized() * dados.alcance
	var alvo := _primeiro_no_caminho(origem, ponta)
	if not alvo.is_empty():
		ponta = alvo["position"]

	if _feixe == null or not is_instance_valid(_feixe):
		_feixe = CENA_FEIXE.instantiate()
		_container().add_child(_feixe)
	_feixe.apontar(origem, ponta, dados.cor_projetil, dados.largura_feixe)

	# Municao escoa por TEMPO, nao por clique: `cadencia` no .tres do laser le
	# como "balas por segundo enquanto ligado". Assim o mesmo campo continua
	# significando a mesma coisa para quem for balancear.
	# NAO se decrementa `_t_cadencia` aqui: o `_process` deste mesmo no ja faz
	# isso todo frame. Decrementar nos dois lugares drenava o pente no DOBRO da
	# velocidade que o .tres pede, e sem erro nenhum -- so uma arma que acaba
	# cedo demais.
	if _t_cadencia <= 0.0:
		_t_cadencia = dados.intervalo() / maxf(_multiplicador_cadencia(), 0.01)
		municao_pente -= 1
		if not hostil:
			Modificadores.armar_hack()
		_avisar_municao()
		# `disparou` sai no tique da municao e nao todo frame: no frame o shake e
		# o recuo seriam somados 60 vezes por segundo e a tela viraria papel.
		disparou.emit(direcao, dados)
		if municao_pente <= 0:
			recarregar()

	return _ferir_com_feixe(alvo, direcao, delta)


## Aplica o dano por segundo a quem estiver na ponta do feixe.
func _ferir_com_feixe(alvo: Dictionary, direcao: Vector2, delta: float) -> bool:
	if alvo.is_empty():
		return false
	var corpo = alvo["collider"]
	if corpo == null or not corpo.has_method("receber_dano"):
		# Bateu em parede: o acumulador ZERA. Sem isto o jogador carregaria dano
		# na parede e o soltaria inteiro no primeiro inimigo que cruzasse a mira.
		_dano_acumulado = 0.0
		return false

	_dano_acumulado += dados.dano_por_segundo * delta * _multiplicador_dano()
	if _dano_acumulado < 1.0:
		return false

	var pedaco := int(_dano_acumulado)
	_dano_acumulado -= float(pedaco)
	corpo.receber_dano(pedaco + _bonus_dano(), direcao.normalized() * dados.knockback)
	if not hostil:
		Modificadores.registrar_acerto(corpo.get_instance_id())
	return true


## O primeiro corpo -- inimigo OU parede -- na linha do feixe.
##
## Uma consulta so com as duas layers, e nao duas consultas: com duas o feixe
## acertaria o inimigo ATRAS da parede sempre que ele estivesse mais perto em
## linha reta, porque cada consulta so conhece o proprio alvo.
func _primeiro_no_caminho(de: Vector2, para: Vector2) -> Dictionary:
	var consulta := PhysicsRayQueryParameters2D.create(de, para)
	consulta.collision_mask = LAYER_PAREDE | (LAYER_PLAYER if hostil else LAYER_INIMIGO)
	consulta.collide_with_areas = false
	return get_world_2d().direct_space_state.intersect_ray(consulta)


func _apagar_feixe() -> void:
	if _feixe != null and is_instance_valid(_feixe):
		_feixe.queue_free()
	_feixe = null
	_dano_acumulado = 0.0


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
