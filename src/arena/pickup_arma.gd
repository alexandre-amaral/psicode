class_name PickupArma
extends Area2D
## Loot no chao. Encoste para pegar.
##
## **Com vaga ele entrega e some; sem vaga ele abre a escolha e CONTINUA NO
## CHAO.** A segunda metade e a regra que sustenta o epico dos dois slots:
## cancelar a troca nao pode custar nada, e um pickup consumido antes da decisao
## apagaria a arma do mundo em toda desistencia.
##
## Ele tambem e quem sabe LARGAR arma (`soltar_no_chao`), e a Loja usa o mesmo
## caminho -- uma segunda funcao de largar divergiria, e a arma trocada no balcao
## voltaria a ser recolhivel no mesmo frame.

## Preenchido = esta arma. Vazio = sorteia do pool ao nascer. Ficava fixo em
## shotgun.tres dentro do .tscn, e por isso TODA arma dropada no jogo era a
## mesma shotgun -- inclusive a da sala de recompensa.
@export var dados: DadosArma
@export var pool: PoolLoot
@export var gira: bool = true

## O icone de 64 px reduzido ao tamanho em que ele foi MEDIDO.
##
## Gemeo de `PickupItem.ESCALA_ICONE`, e pelo mesmo motivo: 32 px e o contexto do
## chao, e metade e a unica reducao que a pixel art aceita sem reamostrar.
const ESCALA_ICONE := 0.5

## Quanto tempo a arma recem-largada ignora o jogador.
##
## **Sem ela a substituicao vira um laco fechado.** A arma trocada cai onde o
## jogador esta -- ele acabou de encostar no pickup --, entao o `body_entered`
## dela dispara no frame seguinte, os dois slots continuam cheios, e a tela de
## escolha reabre sobre a arvore ja pausada. Nao ha erro no console para isso:
## e uma tela que volta sozinha para sempre.
const TRAVA_APOS_LARGAR := 0.5

var _t: float = 0.0
var _visual: Node2D
var _rotulo: Label
var _icone: Sprite2D
var _t_trava: float = 0.0
## Ha uma tela de escolha aberta por ESTE pickup? Sem a guarda, atravessar o
## pickup enquanto a tela abre (o `body_entered` dispara de novo no frame em que
## a arvore pausa) empilharia duas telas, e a segunda decidiria sobre um
## inventario que a primeira ja mudou.
var _escolhendo: bool = false


func _ready() -> void:
	_visual = $Visual
	_rotulo = $Rotulo
	_icone = $Icone
	_icone.scale = Vector2.ONE * ESCALA_ICONE

	# Antes de pintar: o visual e o rotulo leem `dados`.
	if dados == null and pool != null:
		dados = pool.sortear_arma()

	if dados != null:
		# Mesma divisao do `PickupItem`: havendo icone, o losango SOLIDO sai e a
		# cor da arma passa para o HALO. Os dois desenhados juntos empilhavam duas
		# respostas para a mesma pergunta, e o solido, sendo opaco, emoldurava o
		# desenho em vez de ficar atras dele.
		$Visual/Halo.color = Color(dados.cor_projetil, $Visual/Halo.color.a)
		$Visual/Corpo.color = dados.cor_projetil
		$Visual/Corpo.visible = dados.icone == null
		_icone.texture = dados.icone
		_icone.visible = dados.icone != null
		_rotulo.text = dados.nome
		_rotulo.modulate = dados.cor_projetil
	body_entered.connect(_ao_encostar)


## Marca esta arma como recem-largada: ela ignora o jogador por um instante.
##
## Chamada por quem a largou (a substituicao no chao, a troca na Loja) logo
## depois do `add_child`.
func largar_agora() -> void:
	_t_trava = TRAVA_APOS_LARGAR


func _process(delta: float) -> void:
	_t += delta
	_t_trava = maxf(_t_trava - delta, 0.0)
	if _visual != null:
		_visual.position.y = sin(_t * 3.0) * 5.0
		if gira:
			_visual.rotation += delta * 1.6
		# O icone flutua junto, mas de FORA do `Visual`, que tambem gira: arte de
		# 64 px girando em angulo quebrado reamostra fora da grade.
		_icone.position.y = _visual.position.y


func _ao_encostar(corpo: Node) -> void:
	if not corpo.is_in_group("player") or dados == null or _t_trava > 0.0 or _escolhendo:
		return
	if not corpo.has_method("pedir_arma"):
		return

	var resultado: int = corpo.pedir_arma(dados)
	if resultado == InventarioDeArmas.Resultado.PRECISA_ESCOLHER:
		# **A arma continua no chao.** Quem decide e o jogador, na tela de troca,
		# e ate ela terminar nada foi tirado dele -- inclusive se ele cancelar.
		# Consumir o pickup aqui e abrir a tela depois faria o cancelamento
		# apagar a arma do mundo.
		_pedir_escolha(corpo)
		return
	if resultado != InventarioDeArmas.Resultado.ACEITA:
		return

	_faiscar()
	queue_free()


## Os dois slots estao cheios: o jogador escolhe qual sai.
##
## O `await` acontece com a arvore pausada, e este no sobrevive porque quem
## pausa nao libera ninguem. **A ordem aqui e o contrato**, e ela e a mesma da
## compra na Loja: primeiro a escolha, so entao a troca, e o pickup so some
## quando a arma dele de fato entrou.
func _pedir_escolha(jogador: Node) -> void:
	_escolhendo = true
	var tela := TelaTrocaDeArma.abrir(get_tree().current_scene, dados, jogador.inventario())
	var indice: int = await tela.decidida
	_escolhendo = false

	# **Cancelar nao custa nada.** A arma continua no chao e o inventario
	# continua igual -- e a trava entra assim mesmo, senao o jogador, que nunca
	# saiu de cima do pickup, reabre a tela que acabou de fechar.
	if indice < 0:
		_t_trava = TRAVA_APOS_LARGAR
		return

	var saiu: DadosArma = jogador.substituir_arma(indice, dados)
	if saiu != null:
		soltar_no_chao(saiu, get_parent(), global_position)
	_faiscar()
	queue_free()


## Poe uma arma no chao como pickup novo, ja travada contra recoleta imediata.
##
## `static` porque a Loja larga arma pelo mesmo caminho, e ela nao tem um
## `PickupArma` na mao para pedir. Uma segunda funcao de largar divergiria da
## primeira, e o sintoma seria a arma trocada na Loja voltando a ser recolhivel
## no mesmo frame -- exatamente o laco que a trava existe para fechar.
static func soltar_no_chao(molde: DadosArma, pai: Node, posicao: Vector2) -> Node:
	if molde == null or pai == null:
		return null
	var novo: Node2D = load("res://src/arena/pickup_arma.tscn").instantiate()
	novo.dados = molde
	# O pool tem de sair: com ele preenchido e `dados` tambem, o `_ready` mantem
	# `dados` -- mas deixar os dois apontados e deixar duas respostas para "que
	# arma e esta", e a proxima pessoa a mexer no `_ready` escolhe a errada.
	novo.pool = null
	pai.add_child(novo)
	novo.global_position = posicao
	novo.largar_agora()
	EventBus.arma_descartada.emit(molde, posicao)
	return novo


func _faiscar() -> void:
	var fx := preload("res://src/fx/impacto.tscn").instantiate()
	fx.global_position = global_position
	fx.modulate = dados.cor_projetil
	get_parent().add_child(fx)
