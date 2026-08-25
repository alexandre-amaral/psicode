extends Area2D
## Projetil generico. O mesmo no serve para o jogador e para os inimigos --
## quem cria decide as camadas de colisao chamando configurar().
##
## Layers do projeto (Projeto > Configuracoes > Camadas):
##   1 player | 2 inimigo | 3 parede | 4 projetil_player | 5 projetil_inimigo

const LAYER_PLAYER := 1
const LAYER_INIMIGO := 2
const LAYER_PAREDE := 4
const LAYER_PROJ_PLAYER := 8
const LAYER_PROJ_INIMIGO := 16

## Quanto o projetil e afastado da parede depois de quicar, para o raycast do
## frame seguinte nao bater na mesma superficie.
const FOLGA_RICOCHETE := 3.0
## Abertura entre os dois fragmentos, em graus.
const ABERTURA_FRAGMENTO := 42.0

const CENA_PROJETIL := preload("res://src/projectiles/projetil.tscn")

var velocidade: Vector2 = Vector2.ZERO
var dano: int = 1
var knockback: float = 0.0
var perfuracao_restante: int = 0
var hostil: bool = false
var cor: Color = Color("6ee7ff")
var raio: float = 4.0

## Quantos ricochetes ainda cabem. Um so, como manda a tabela do implante.
var ricochetes_restantes: int = 0
## 0 = projetil original, 1 = fragmento. E o que impede divisao infinita:
## fragmento nao fragmenta.
var geracao: int = 0

## Guardado para poder criar fragmentos: configurar() exige um DadosArma, e sem
## esta referencia o fragmento nao teria como nascer.
var _dados: DadosArma = null
var _vida_total: float = 2.0
var _vida_restante: float = 2.0
var _atingidos: Array[int] = []
var _rastro: Line2D
var _forma: CollisionShape2D
var _visual: Polygon2D


func _ready() -> void:
	_forma = $Forma
	_visual = $Visual
	_rastro = $Rastro
	_rastro.top_level = true          # ignora a rotacao do pai

	_aplicar_aparencia()

	body_entered.connect(_ao_encostar)


## Cor, tamanho e rastro a partir de `cor` e `raio`.
##
## Isto e chamado DUAS vezes de proposito: uma no _ready, com os defaults, e
## outra no fim de configurar(), com os valores do DadosArma.
##
## O motivo e a ordem em que a Arma monta o projetil: `add_child()` vem antes de
## `configurar()`, entao o _ready sempre roda com os defaults. Sem a segunda
## chamada, TODO projetil do jogo nascia ciano com raio 4 -- o tiro do Vigia e o
## da Diretora ficavam visualmente identicos ao do jogador, e a colisao deles
## menor do que o .tres pedia.
func _aplicar_aparencia() -> void:
	# Cada projetil precisa da propria forma: se compartilhassemos o recurso
	# da cena, mudar o raio de um mudaria o de todos.
	var forma_circulo := CircleShape2D.new()
	forma_circulo.radius = raio
	_forma.shape = forma_circulo

	_visual.color = cor
	_visual.polygon = _montar_polygon(raio)

	_rastro.default_color = Color(cor.r, cor.g, cor.b, 0.35)
	_rastro.width = maxf(raio * 1.5, 4.0)
	_rastro.clear_points()
	_rastro.add_point(global_position)
	_rastro.add_point(global_position)


func configurar(
	posicao: Vector2,
	direcao: Vector2,
	dados: DadosArma,
	eh_hostil: bool,
	multiplicador_velocidade: float = 1.0,
	bonus_dano: int = 0,
	multiplicador_dano: float = 1.0
) -> void:
	global_position = posicao
	hostil = eh_hostil
	_dados = dados
	# Congelado no disparo de proposito: o projetil que ja esta no ar nao muda
	# de dano quando o implante e pego. Quem filtra por hostil e a Arma -- aqui
	# o bonus ja chega zerado para inimigo.
	#
	# Soma primeiro, multiplica depois, arredonda UMA vez: arredondar no meio
	# comeria os percentuais pequenos, que e justamente a armadilha de dano ser
	# int neste jogo.
	dano = maxi(roundi(float(dados.dano + bonus_dano) * multiplicador_dano), 1)
	if not hostil:
		ricochetes_restantes = 1 if randf() < Modificadores.chance_ricochete() else 0
	knockback = dados.knockback
	perfuracao_restante = dados.perfuracao
	cor = dados.cor_projetil
	raio = dados.raio_projetil

	var vel := dados.velocidade_projetil * multiplicador_velocidade
	velocidade = direcao.normalized() * vel
	rotation = velocidade.angle()
	_vida_total = dados.alcance / maxf(vel, 1.0)
	_vida_restante = _vida_total

	if hostil:
		collision_layer = LAYER_PROJ_INIMIGO
		collision_mask = LAYER_PLAYER | LAYER_PAREDE
	else:
		collision_layer = LAYER_PROJ_PLAYER
		collision_mask = LAYER_INIMIGO | LAYER_PAREDE

	# Por ultimo: so agora `cor` e `raio` valem o que o DadosArma manda. O _ready
	# ja pintou com os defaults, porque a Arma faz add_child antes de configurar.
	_aplicar_aparencia()


func _physics_process(delta: float) -> void:
	var anterior := global_position
	global_position += velocidade * delta

	# Parede e resolvida por RAYCAST, nao pelo body_entered.
	#
	# Dois motivos, e o primeiro era um bug de verdade: o teste antigo era
	# `corpo.is_in_group("parede")`, e as paredes do jogo nascem em codigo
	# (sala.gd, corredor.gd) sem entrar em grupo nenhum -- so a arena legada
	# tinha o grupo. Na pratica os projeteis atravessavam parede e so sumiam
	# por tempo de vida. Testar pela LAYER funciona para as duas, e ninguem
	# precisa lembrar de chamar add_to_group numa parede nova.
	#
	# O segundo: body_entered nao entrega a normal da superficie, e sem normal
	# nao ha ricochete. O raycast entrega.
	var batida := _raycast_parede(anterior, global_position)
	if not batida.is_empty():
		_ao_bater_na_parede(batida)
		return

	_vida_restante -= delta
	if _vida_restante <= 0.0:
		queue_free()
		return
	_atualizar_rastro()
	_aplicar_glitch()


## Dicionario vazio quando o caminho do frame nao cruzou parede.
func _raycast_parede(de: Vector2, para: Vector2) -> Dictionary:
	var espaco := get_world_2d().direct_space_state
	var consulta := PhysicsRayQueryParameters2D.create(de, para)
	consulta.collision_mask = LAYER_PAREDE
	consulta.collide_with_areas = false
	consulta.collide_with_bodies = true
	return espaco.intersect_ray(consulta)


func _ao_bater_na_parede(batida: Dictionary) -> void:
	global_position = batida["position"]
	_impacto()

	if ricochetes_restantes <= 0:
		queue_free()
		return

	ricochetes_restantes -= 1
	velocidade = velocidade.bounce(batida["normal"])
	# A rotacao so era escrita em configurar(); sem reescrever aqui, o losango
	# e o rastro continuariam apontando para o lado de onde a bala veio.
	rotation = velocidade.angle()
	# Sai de dentro da parede antes do proximo passo, senao o raycast do frame
	# seguinte bate na mesma superficie e o quique vira um tremor no lugar.
	global_position += batida["normal"] * FOLGA_RICOCHETE
	# Alcance renovado: _vida_restante e TEMPO, e uma arma de alcance curto
	# (shotgun, 420) mataria a bala refletida quase na hora.
	_vida_restante = _vida_total
	# Quem ja foi atingido pode ser atingido de novo depois do quique.
	_atingidos.clear()


func _atualizar_rastro() -> void:
	if _rastro == null:
		return
	_rastro.set_point_position(0, global_position)
	# O ponto de tras fica sempre alguns frames atras, na direcao oposta.
	_rastro.set_point_position(1, global_position - velocidade.normalized() * maxf(raio * 6.0, 16.0))


## Identidade visual da Deterioracao alta: os projeteis inimigos passam a
## tremer, como se a percepcao do protagonista nao conseguisse fixa-los.
func _aplicar_glitch() -> void:
	if not hostil or _visual == null:
		return
	var g := Deterioracao.intensidade_glitch()
	if g <= 0.0:
		if _visual.position != Vector2.ZERO:
			_visual.position = Vector2.ZERO
		return
	_visual.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * g * 3.0


func _ao_encostar(corpo: Node) -> void:
	# Parede nao chega aqui: quem resolve e o raycast do _physics_process.
	var id := corpo.get_instance_id()
	if id in _atingidos:
		return
	_atingidos.append(id)

	var acertou := false
	if corpo.has_method("receber_dano"):
		acertou = corpo.receber_dano(_dano_no_alvo(corpo), velocidade.normalized() * knockback)

	if not acertou:
		return

	if not hostil:
		# A IA Predatoria precisa saber em quem o tiro pegou: e assim que o
		# marcador gruda no proximo alvo e depois e consumido.
		Modificadores.registrar_acerto(id)
		_tentar_hackear(corpo)
		_tentar_fragmentar()

	_impacto()
	if perfuracao_restante > 0:
		perfuracao_restante -= 1
	else:
		queue_free()


## Dano ja com os bonus que dependem de QUEM foi atingido -- o resto do calculo
## foi congelado no disparo.
##
## Recebe o NO e nao so o id porque o Hack e estado do proprio inimigo, nao do
## autoload. E o bonus entra aqui, e nao em InimigoBase.receber_dano, porque a
## Diretora reimplementa receber_dano sem chamar super: aplicado la, o chefe
## seria o unico do jogo imune ao Hack, e em silencio.
func _dano_no_alvo(corpo: Node) -> int:
	if hostil:
		return dano
	var fator := Modificadores.multiplicador_no_alvo(corpo.get_instance_id())
	if corpo.has_method("esta_hackeado") and corpo.esta_hackeado():
		fator *= Modificadores.bonus_dano_hack()
	return maxi(roundi(float(dano) * fator), 1)


## 10% por TIRO, nao por projetil: quem sorteia e Arma._consumir_tiro(), e o que
## chega aqui e so a pergunta "este tiro ganhou o Hack?".
func _tentar_hackear(corpo: Node) -> void:
	if not corpo.has_method("aplicar_hack"):
		return
	var duracao := Modificadores.consumir_hack()
	if duracao > 0.0:
		corpo.aplicar_hack(duracao)


## Divide o projetil em dois ao acertar. So a geracao 0 divide -- sem isso os
## fragmentos fragmentariam e a tela viraria uma bomba em cadeia.
func _tentar_fragmentar() -> void:
	if geracao > 0 or _dados == null:
		return
	if randf() >= Modificadores.chance_fragmentacao():
		return

	var container := get_parent()
	if container == null:
		return
	var base := velocidade.normalized()
	for direcao in Balistica.leque(base, 2, ABERTURA_FRAGMENTO):
		var frag := CENA_PROJETIL.instantiate()
		container.add_child(frag)
		frag.configurar(global_position, direcao, _dados, hostil)
		frag.geracao = 1
		# Metade do dano, e nunca menos que 1 -- fragmento de dano zero seria
		# um projetil que nao faz nada e confunde quem esta olhando.
		frag.dano = maxi(_dados.dano / 2, 1)
		# Fragmento nao ricocheteia: dois quiques em cadeia a partir de um tiro
		# so enchem a sala de projetil sem ninguem conseguir ler o que aconteceu.
		frag.ricochetes_restantes = 0


func _impacto() -> void:
	var fx := preload("res://src/fx/impacto.tscn").instantiate()
	fx.global_position = global_position
	fx.modulate = cor
	get_tree().current_scene.add_child(fx)


func _montar_polygon(r: float) -> PackedVector2Array:
	# Losango alongado no eixo X -- parece um dardo de energia e le bem
	# a direcao do tiro sem precisar de sprite.
	return PackedVector2Array([
		Vector2(r * 2.4, 0.0),
		Vector2(0.0, -r),
		Vector2(-r * 1.6, 0.0),
		Vector2(0.0, r),
	])
