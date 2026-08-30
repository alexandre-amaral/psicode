extends InimigoBase
## A IA DIRETORA -- o climax da build.
##
## Ela e a personificacao do sistema que vinha lendo o jogador o tempo todo.
## Conceitualmente: ate agora a Deterioracao mexia nos inimigos; agora ela
## tem corpo. Mecanicamente o MVP fica no que o GDD pediu -- mira preditiva e
## invocacao -- mais salvas radiais que forcam o jogador a usar o rolamento
## para atravessar, e nao so para fugir.
##
## Cada ataque tem telegrafo. Um chefe de bullet hell so e justo se o jogador
## consegue ler a intencao antes do projetil existir.
##
## AUDITORIA DE PERSPECTIVA (LTD 16). Ela foi MEDIDA, e a medicao contrariou
## duas das quatro suspeitas que estavam escritas aqui. O que sobrou:
##
## A arte dela e um ORBE FLUTUANTE RADIALMENTE SIMETRICO -- uma iris mecanica de
## 192x192, autorada a mao, fora do `tools/sprites/gerar_sprites.py`. Disso saem
## quatro consequencias, e duas NAO eram defeito:
##
##  1. **Origem centrada: CERTO.** Estava anotado aqui que os pes dela caiam ~94
##     px abaixo da origem. Ela nao tem pes. O perfil de opacidade e simetrico e
##     o corpo termina em ponta nas duas pontas -- ela flutua. Para um corpo que
##     flutua e nao tem frente nem base, centrado E a ancora certa, e a regra de
##     origem nos pes (LTD 07) simplesmente nao se aplica.
##  2. **Girar o sprite: CERTO.** A issue suspeitava que isso violasse a camera
##     imaginaria unica. Nao viola: um disco radialmente simetrico girando nao
##     muda de perspectiva, ele le como a maquina virando para voce. E a rotacao
##     do `Visual` e o que faz a boca da arma orbitar -- congela-la faria todo
##     tiro nascer 78 px ao lado dela, que e a armadilha da Sentinela.
##  3. **Sem tint de Hack: ERA DEFEITO, corrigido.** `InimigoBase._corpo`
##     procura `Visual/Corpo`; o no dela chamava `SpriteDiretora`, entao `_corpo`
##     ficava nulo e ela era o UNICO inimigo do jogo sem tint de Hack e sem tint
##     de nanite. Ela aceitava o Hack e tomava o dano extra -- `teste_diretora.gd`
##     mede os dois -- e nao mostrava que estava marcada. O no foi renomeado.
##  4. **Sombra invisivel: ERA no morto, removido.** `largura_sombra` valia 28 e
##     `Sombra.base_de()` devolvia 0, entao a elipse nascia no centro dela.
##     Medido: os 377 pixels dela ficavam 100% cobertos por sprite opaco. Uma
##     sombra que cabe dentro do proprio corpo nao responde "onde isto encosta
##     no chao" -- e ela NUNCA encosta. Agora `largura_sombra = 0`, que e o
##     mesmo caminho que a torre e o nucleo da arena dela ja usavam.
##
signal fase_mudou(fase: int)

const CENA_RASTEJANTE := preload("res://src/enemies/rastejante.tscn")
const CENA_VIGIA := preload("res://src/enemies/vigia.tscn")
const CENA_DRONE := preload("res://src/enemies/drone_aranha.tscn")
const CENA_AREA := preload("res://src/enemies/area_de_perigo.tscn")
const CENA_NUCLEO := preload("res://src/enemies/nucleo_sobrecarga.tscn")
const CENA_TORRE := preload("res://src/enemies/torre_diretora.tscn")

## A FASE ABSOLUTA. Abaixo desta fracao de vida ela para de usar o proprio corpo
## e passa a usar a sala.
const FRACAO_ABSOLUTA := 0.15
## A janela de "Recalculando...": tudo desligado, ela vulneravel. E o beat que
## separa as duas metades da luta, e o respiro logo antes do trecho mais denso.
const RECALCULANDO := 1.5
## Teto de torres vivas. Sem teto a arena continua repondo e a luta nao termina.
const MAX_TORRES := 3
const INTERVALO_TORRE := 4.5

## Os nomes do repertorio. StringName porque viram chave de comparacao no
## seletor e na suite de identidade.
const PREDITIVO := &"preditivo"
const ANEL := &"anel"
const ESPIRAL := &"espiral"
const INVOCAR := &"invocar"
const REDE := &"rede"
const SOBRECARGA := &"sobrecarga"

## A Rede de Exterminio: faixas letais no chao, com vao entre elas. As faixas
## LETAIS sao estas; os vaos sao o que sobra, e sao sempre mais numerosos --
## e por construcao que ela nunca fecha a arena.
const FAIXAS_REDE := 3
const LARGURA_FAIXA := 48.0
## Quanto as faixas moveis deslizam durante o aviso. "Algumas linhas permanecem
## fixas enquanto outras se movimentam lentamente em direcao ao jogador."
const DERIVA_REDE := 96.0

## A Sobrecarga do Nucleo: quantos pontos de energia nascem e quanto cada um
## destruido tira do alcance do estouro.
const NUCLEOS_SOBRECARGA := 4
const RAIO_SEGURO_SOBRECARGA := 132.0
const CUNHAS_SOBRECARGA := 12

## Piso do telegrafo, em segundos. O GDD crava este numero: o telegrafo encurta
## com a fase, mas NUNCA abaixo disto. E a fronteira entre "dificil" e "mente
## sobre a propria regra".
const TELEGRAFO_MINIMO := 0.35

## Janela de alivio na virada de fase. Sem ela a transicao vira dano gratuito em
## cima de quem estava no meio de uma esquiva.
const ALIVIO_DE_FASE := 0.9

@export_group("Chefe")
@export var nome_exibicao: String = "A IA DIRETORA"
@export var raio_orbita: float = 40.0
@export var velocidade_orbita: float = 0.35
@export var max_invocados: int = 8

@export_group("Protocolo de Supressao")
## Quantos disparos saem na rajada. O PRIMEIRO e sempre intercepto puro, sem
## correcao: o texto dela promete que "o primeiro disparo e relativamente
## previsivel", e e ele que ensina a mecanica antes de cobrar por ela.
@export var disparos_supressao: int = 3
## Quanto a correcao desloca a mira, em pixels, com confianca cheia.
@export var correcao_supressao: float = 130.0
## Intervalo entre os disparos da rajada.
@export var intervalo_supressao: float = 0.16

@export_group("Enxame")
## Quanto tempo depois da invocacao o pulso puxa o enxame para o jogador.
@export var atraso_do_pulso: float = 1.6
@export var forca_do_pulso: float = 520.0

enum Acao { SURGINDO, OCIOSA, TELEGRAFO, EXECUTANDO }

var fase_chefe: int = 1
var _acao: int = Acao.SURGINDO
var _t_acao: float = 0.0
var _ataque_atual: StringName = &""
var _fila: Array[StringName] = []
var _centro: Vector2 = Vector2.ZERO
var _centro_definido: bool = false
var _angulo_orbita: float = 0.0
var _invocados: Array[Node] = []
var _ponto_previsto: Vector2 = Vector2.ZERO
var _giro_espiral: float = 0.0
## O que ela aprendeu sobre o jogador. Nasce vazio: a Diretora entra na luta sem
## saber nada, e e a propria luta que a ensina.
var _perfil := PerfilJogador.new()
## Quantos disparos da rajada de supressao ainda faltam, e o relogio entre eles.
var _restam_disparos: int = 0
var _t_disparo: float = 0.0
## O ultimo padrao que ela anunciou ter identificado. Guardado para nao repetir
## a mesma mensagem duas vezes seguidas na HUD.
var _padrao_anunciado: int = -1
## O ataque anterior, para ela nao travar numa resposta so.
var _ultimo_ataque: StringName = &""
## As faixas da Rede e os nucleos da Sobrecarga vivos agora. Guardados pelo
## mesmo motivo que o Parasita guarda as areas dele: quem semeia e quem limpa,
## senao um aviso sobrevive a quem o pediu.
var _faixas: Array[Node] = []
var _nucleos: Array[Node] = []
var _t_pulso: float = -1.0
var _torres: Array[Node] = []
var _t_torre: float = 0.0
## Ligado quando ela abandona o proprio corpo. Daqui em diante a arena ataca.
var _absoluta: bool = false

var _arma_preditiva: Arma
var _arma_salva: Arma
var _laser: Line2D
var _aviso: Polygon2D


func _ready() -> void:
	super._ready()
	_arma_preditiva = $Visual/ArmaPreditiva
	_arma_salva = $ArmaSalva
	_arma_preditiva.hostil = true
	_arma_salva.hostil = true
	_aviso = $Aviso
	_laser = $Laser
	_laser.top_level = true
	_laser.visible = false
	_aviso.visible = false

	_acao = Acao.SURGINDO
	_t_acao = 1.6
	EventBus.boss_revelado.emit(nome_exibicao, vida_maxima)
	EventBus.boss_vida_mudou.emit(vida, vida_maxima)
	EventBus.pedido_shake.emit(9.6, 1.2)


func _comportamento(delta: float) -> void:
	_observar_jogador(delta)
	_orbitar(delta)
	_limpar_invocados()
	_limpar_semeados()

	# O pulso corre por fora da maquina de acao de proposito: ele acontece
	# DEPOIS que a invocacao ja terminou e ela ja voltou a atacar outra coisa.
	if _t_pulso > 0.0:
		_t_pulso -= delta
		if _t_pulso <= 0.0:
			_pulsar_enxame()

	if _absoluta:
		_manter_arena(delta)

	match _acao:
		Acao.SURGINDO:
			_t_acao -= delta
			if _t_acao <= 0.0:
				_acao = Acao.OCIOSA
				_t_acao = 0.6
		Acao.OCIOSA:
			_t_acao -= delta
			if _t_acao <= 0.0:
				_escolher_ataque()
		Acao.TELEGRAFO:
			_t_acao -= delta
			_atualizar_telegrafo()
			if _t_acao <= 0.0:
				_executar_ataque()
		Acao.EXECUTANDO:
			_t_acao -= delta
			_manter_ataque(delta)
			if _t_acao <= 0.0:
				_terminar_ataque()

	tentar_dano_contato()


# -------------------------------------------------------------- leitura ---

## Uma amostra por frame do que o jogador esta fazendo.
##
## Roda SEMPRE, inclusive durante o telegrafo e a execucao: o que ela le e o
## habito, e habito nao tem pausa. Se so amostrasse enquanto ociosa, a leitura
## descreveria o jogador parado esperando o ataque passar -- exatamente o
## contrario do que ela quer saber.
func _observar_jogador(delta: float) -> void:
	if alvo == null or not is_instance_valid(alvo):
		return
	_perfil.observar(alvo.global_position, velocidade_do_alvo(), global_position, delta)


## O que ela aprendeu. Exposto para a suite de identidade poder provar que o
## perfil e USADO -- sem isso ele poderia virar codigo morto sem nada acusar.
func perfil() -> PerfilJogador:
	return _perfil


# ------------------------------------------------------------ movimento ---

func _orbitar(delta: float) -> void:
	# O centro da orbita e capturado no primeiro frame de movimento, nao no
	# _ready: quem spawna o chefe so atribui a global_position DEPOIS do
	# add_child, e o _ready roda durante o add_child. Ler ali daria a origem do
	# container, e a orbita ignoraria em silencio o area_spawn da sala do chefe.
	if not _centro_definido:
		_centro = global_position
		_centro_definido = true
	# Na fase Absoluta ela ANCORA. Parar de circular nao e ela ficando mais
	# facil: e ela deixando de precisar de corpo. Quem se mexe agora e a sala.
	if _absoluta:
		velocity = (_centro - global_position) * 2.4
		return
	# Ela nao persegue. Circula devagar no centro, como um sistema rodando.
	_angulo_orbita += velocidade_orbita * delta * Deterioracao.multiplicador_velocidade()
	var destino := _centro + Vector2.RIGHT.rotated(_angulo_orbita) * raio_orbita
	velocity = (destino - global_position) * 2.4




# -------------------------------------------------------------- ataques ---

func _escolher_ataque() -> void:
	_ataque_atual = _escolher_pelo_perfil()
	if _ataque_atual == &"":
		if _fila.is_empty():
			_fila = repertorio_da_fase(fase_chefe)
			_fila.shuffle()
		_ataque_atual = _fila.pop_front()

	_acao = Acao.TELEGRAFO
	_t_acao = duracao_telegrafo(_ataque_atual, fase_chefe)
	_iniciar_telegrafo()


## A Predicao Comportamental: ela responde ao que leu, em vez de sortear.
##
## Isto NAO e um ataque a mais -- e o seletor. A ficcao dela nao e "tem muitos
## golpes", e "te classificou": distancia vira resposta que fecha espaco, ficar
## colado vira resposta circular, ficar parado vira enxame em cima de voce.
##
## Devolve `&""` quando ainda nao ha o que ler, e ai o sorteio antigo assume. Sem
## esse portao ela "aprenderia" no primeiro frame e o primeiro ataque da luta ja
## sairia corrigido -- punindo um habito que o jogador nao teve chance de
## formar, que e a mesma armadilha que o GDD descreve para a mira preditiva.
func _escolher_pelo_perfil() -> StringName:
	if _perfil.confianca() < 0.6:
		return &""
	var disponiveis := repertorio_da_fase(fase_chefe)
	var escolha := &""
	var padrao := -1

	if _perfil.fracao_parado() > 0.55 and disponiveis.has(INVOCAR):
		# "O objetivo e impedir que o jogador permaneca parado atacando o boss."
		escolha = INVOCAR
		padrao = 0
	else:
		match _perfil.postura():
			PerfilJogador.Postura.COLADO:
				# "Se permanece proximo ao boss, ela ativa ataques circulares."
				escolha = ESPIRAL if disponiveis.has(ESPIRAL) else ANEL
				padrao = 1
			PerfilJogador.Postura.LONGE:
				# "Se prefere manter distancia, a IA utiliza ataques que fecham
				# o espaco."
				escolha = REDE if disponiveis.has(REDE) else PREDITIVO
				padrao = 2
			_:
				escolha = PREDITIVO
				padrao = 3

	if not disponiveis.has(escolha):
		return &""
	# Ela nao repete o mesmo padrao duas vezes seguidas mesmo lendo a mesma
	# coisa: um chefe que trava numa resposta so vira um puzzle de uma linha.
	if escolha == _ultimo_ataque:
		return &""

	# O anuncio vem DEPOIS das duas recusas acima, e nao antes. Anunciar
	# "PADRAO IDENTIFICADO" e em seguida cair no sorteio seria o chefe mentindo
	# sobre a propria leitura -- e a mensagem existe justamente para o jogador
	# poder confiar nela o bastante para querer quebrar o padrao.
	_anunciar_padrao(padrao)
	return escolha


## O repertorio de uma fase. PUBLICA e PURA de proposito: e o que permite a
## suite de identidade enumerar as quatro fases sem subir combate nenhum, e a
## regra que ela cobra -- o repertorio so CRESCE -- e invisivel de qualquer
## outro jeito.
func repertorio_da_fase(fase: int) -> Array[StringName]:
	match fase:
		1:
			return [PREDITIVO, PREDITIVO, INVOCAR]
		2:
			return [PREDITIVO, ANEL, INVOCAR, PREDITIVO, REDE]
		_:
			return [PREDITIVO, ANEL, ESPIRAL, INVOCAR, ESPIRAL, REDE, SOBRECARGA]


## Quanto tempo o aviso deste ataque fica na tela, nesta fase.
##
## Publica e pura pelo mesmo motivo acima: o piso de TELEGRAFO_MINIMO e a
## promessa mais importante que o chefe faz, e uma promessa que ninguem consegue
## medir e uma promessa que um dia se perde num ajuste de numero.
func duracao_telegrafo(ataque: StringName, fase: int) -> float:
	var base := 0.7
	match ataque:
		PREDITIVO: base = 0.62
		ANEL: base = 0.8
		ESPIRAL: base = 0.7
		INVOCAR: base = 0.55
		# A Rede e a Sobrecarga avisam por MUITO mais tempo, e nao e generosidade:
		# elas negam espaco em vez de mirar, entao o que o jogador precisa e de
		# tempo para LER o mapa e escolher para onde ir. Telegrafo curto num
		# ataque de area nao e dificil, e sorteio.
		REDE: base = 0.95
		SOBRECARGA: base = 1.6
	return maxf(base - (fase - 1) * 0.1, TELEGRAFO_MINIMO)


## Quantas aberturas este ataque deixa -- por onde da para escapar dele.
##
## Ela nunca fecha a arena inteira, e isso e identidade e nao balanceamento: o
## proprio conceito dela e o de um sistema que executa uma sentenca, nao o de
## uma armadilha sem saida. Ataque que devolvesse zero aqui seria dano
## inevitavel com telegrafo -- ler a intencao sem poder agir sobre ela e pior do
## que nao ler.
func aberturas_de(ataque: StringName, fase: int) -> int:
	match ataque:
		ANEL:
			return projeteis_do_anel(fase)
		ESPIRAL:
			# Dois bracos opostos: da para ficar entre eles, mas so andando.
			return 2
		REDE:
			# FAIXAS letais em cada eixo deixam (FAIXAS+1) vaos por eixo, e o
			# cruzamento deles e a celula segura. Sao mais celulas seguras do que
			# faixas letais, e isso e por construcao e nao por ajuste.
			return (FAIXAS_REDE + 1) * (FAIXAS_REDE + 1)
		SOBRECARGA:
			# A coroa junto do nucleo. Uma so, e pequena -- "deixando apenas uma
			# pequena area segura proxima ao nucleo".
			return 1
		_:
			# Ataque que nao e de area nao fecha espaco nenhum.
			return -1


func projeteis_do_anel(fase: int) -> int:
	return 14 + fase * 6


func _iniciar_telegrafo() -> void:
	match _ataque_atual:
		PREDITIVO:
			_laser.visible = true
		ANEL, ESPIRAL:
			_aviso.visible = true
			_aviso.scale = Vector2(0.2, 0.2)
			_aviso.modulate = Color(0.75, 0.4, 1.0, 0.0)
			var t := create_tween()
			t.set_parallel(true)
			t.tween_property(_aviso, "scale", Vector2(1.0, 1.0), _t_acao)
			t.tween_property(_aviso, "modulate:a", 0.5, _t_acao * 0.7)
		REDE:
			_semear_rede()
		SOBRECARGA:
			_semear_sobrecarga()
		INVOCAR:
			var t2 := create_tween()
			t2.tween_property(_visual, "modulate", Color(2.2, 1.4, 2.6, 1.0), _t_acao * 0.6)
			t2.tween_property(_visual, "modulate", Color.WHITE, _t_acao * 0.4)


func _atualizar_telegrafo() -> void:
	if _ataque_atual != PREDITIVO or alvo == null or not is_instance_valid(alvo):
		return
	# A Diretora sempre preve, independente da barra: ela E a Deterioracao.
	_ponto_previsto = Balistica.ponto_de_intercepto(
		_arma_preditiva.global_position,
		alvo.global_position,
		velocidade_do_alvo(),
		_arma_preditiva.dados.velocidade_projetil
	)
	_visual.rotation = lerp_angle(
		_visual.rotation,
		(_ponto_previsto - global_position).angle(),
		0.3
	)
	_laser.clear_points()
	_laser.add_point(_arma_preditiva.global_position)
	_laser.add_point(_ponto_previsto)
	_laser.default_color = Color(1.0, 0.2, 0.5, 0.7)
	_laser.width = 3.0


func _executar_ataque() -> void:
	_acao = Acao.EXECUTANDO
	_laser.visible = false
	_aviso.visible = false

	match _ataque_atual:
		PREDITIVO:
			_atacar_preditivo()
			_t_acao = 0.35
		ANEL:
			_atacar_anel()
			_t_acao = 0.5
		ESPIRAL:
			_giro_espiral = randf() * TAU
			_t_acao = 1.4 + fase_chefe * 0.35
		INVOCAR:
			_atacar_invocar()
			_t_acao = 0.7
		REDE:
			# As faixas se explodem sozinhas no fim do proprio aviso. Ela so fica
			# parada olhando -- que e o que um sistema faz quando ja executou a
			# ordem.
			_t_acao = 0.45
		SOBRECARGA:
			_estourar_sobrecarga()
			_t_acao = 0.6


func _manter_ataque(delta: float) -> void:
	if _ataque_atual == PREDITIVO:
		_manter_supressao(delta)
		return
	if _ataque_atual != ESPIRAL:
		return
	_giro_espiral += delta * 5.2
	# Dois bracos opostos: da para ficar entre eles, mas so andando.
	#
	# Numa salva so, e nao num for de atirar(): duas chamadas no mesmo frame
	# fariam a segunda cair no cooldown de cadencia e o braco oposto nunca
	# sairia. Com atirar_varias a cadencia passa a limitar SALVAS por segundo,
	# que e o que ela sempre quis dizer aqui.
	var bracos: Array[Vector2] = [
		Vector2.RIGHT.rotated(_giro_espiral),
		Vector2.RIGHT.rotated(_giro_espiral + PI),
	]
	_arma_salva.atirar_varias(bracos)


func _terminar_ataque() -> void:
	_ultimo_ataque = _ataque_atual
	_acao = Acao.OCIOSA
	# Respiro entre ataques. Encurta conforme a fase avanca.
	_t_acao = maxf(1.15 - (fase_chefe - 1) * 0.3, 0.45)


## PROTOCOLO DE SUPRESSAO -- a rajada que aprende.
##
## O primeiro disparo e intercepto PURO, sem correcao nenhuma, e isso e uma
## promessa e nao uma economia: "o primeiro disparo e relativamente previsivel".
## Ele e a aula. Os seguintes e que levam em conta para onde o jogador vem
## desviando -- e ai o preco de ter um habito aparece.
##
## A correcao e multiplicada pela confianca, entao no comeco da luta a rajada
## inteira sai reta. Ela precisa te ver esquivar algumas vezes antes de cobrar.
func _atacar_preditivo() -> void:
	_restam_disparos = disparos_supressao
	_t_disparo = 0.0
	_disparar_supressao(0)


func _manter_supressao(delta: float) -> void:
	if _restam_disparos <= 0:
		return
	_t_disparo -= delta
	if _t_disparo > 0.0:
		return
	_disparar_supressao(disparos_supressao - _restam_disparos)


func _disparar_supressao(indice: int) -> void:
	if _restam_disparos <= 0:
		return
	_restam_disparos -= 1
	_t_disparo = intervalo_supressao

	var mira := _ponto_previsto
	if indice > 0:
		# O deslocamento vai na NORMAL da linha de tiro -- o lado, e nao a
		# distancia. Deslocar ao longo da linha so erraria mais perto ou mais
		# longe; o que o perfil sabe e para que LADO ele vai.
		var linha := (mira - _arma_preditiva.global_position).normalized()
		var normal := Vector2(-linha.y, linha.x)
		var peso := _perfil.lado_previsto() * _perfil.confianca()
		mira += normal * peso * correcao_supressao * float(indice)

	var direcao := (mira - _arma_preditiva.global_position).normalized()
	if direcao == Vector2.ZERO:
		direcao = direcao_para_alvo()
	# A arma preditiva nao e automatica: sem soltar o gatilho, so o PRIMEIRO
	# disparo da rajada sairia e os outros morreriam em pode_atirar().
	_arma_preditiva.atualizar_gatilho(false)
	_arma_preditiva.atirar(direcao)
	EventBus.pedido_shake.emit(2.4, 0.15)


## O anel inteiro sai numa salva so. Percorrer as direcoes chamando atirar()
## nao funciona: o cooldown de cadencia so decrementa entre frames, entao a
## partir da segunda direcao pode_atirar() recusa e o "anel" de 20 projeteis
## virava um projetil.
func _atacar_anel() -> void:
	var quantidade := projeteis_do_anel(fase_chefe)
	var offset := randf() * TAU
	_arma_salva.atirar_varias(Balistica.anel(quantidade, offset))
	EventBus.pedido_shake.emit(4.8, 0.3)


func _atacar_invocar() -> void:
	if _invocados.size() >= max_invocados:
		return
	var quantidade := 2 if fase_chefe == 1 else 3
	var container := get_parent()
	for i in quantidade:
		if _invocados.size() >= max_invocados:
			break
		var cena := CENA_RASTEJANTE
		# Da fase 2 em diante ela tambem chama quem atira -- forca o jogador
		# a resolver o campo, nao so a esquivar do chefe.
		if fase_chefe >= 2 and i == quantidade - 1:
			cena = CENA_VIGIA
		elif fase_chefe >= 3 and i == 0:
			cena = CENA_DRONE
		var inimigo := cena.instantiate()
		var angulo := randf() * TAU
		var destino := global_position + Vector2.RIGHT.rotated(angulo) * randf_range(64.0, 112.0)
		# add_child ANTES de global_position: fora da arvore o setter nao acha o
		# pai e cai no position local, e o container reaplica a propria transform
		# por cima -- o invocado nascia no dobro do offset da sala do chefe.
		container.add_child(inimigo)
		inimigo.global_position = destino
		_invocados.append(inimigo)
	EventBus.pedido_shake.emit(3.6, 0.25)
	# Arma o pulso. E o que separa o Enxame da invocacao antiga: os invocados
	# orbitam por um tempo e SO ENTAO convergem, entao ficar parado atirando no
	# chefe deixa de ser seguro no exato momento em que voce se acostumou.
	_t_pulso = atraso_do_pulso


## O pulso de convergencia. Puxa todo o enxame vivo para onde o jogador esta.
##
## Nao manda em ninguem: escreve no canal de knockback, que a base ja soma por
## fora do comportamento justamente para que empurrar um inimigo nao cancele a
## IA dele. Visto de fora e o campo inteiro dando um passo na sua direcao.
func _pulsar_enxame() -> void:
	if alvo == null or not is_instance_valid(alvo):
		return
	var houve := false
	for n in _invocados:
		var inimigo := n as InimigoBase
		if inimigo == null or inimigo.morto:
			continue
		inimigo.atrair_para(alvo.global_position, forca_do_pulso)
		houve = true
	if houve:
		EventBus.pedido_shake.emit(3.0, 0.18)


func _limpar_invocados() -> void:
	var vivos: Array[Node] = []
	for n in _invocados:
		if is_instance_valid(n):
			vivos.append(n)
	_invocados = vivos


# -------------------------------------------- rede e sobrecarga ------------

## Os limites da arena, para os ataques que usam a SALA como superficie.
##
## Sobe a arvore procurando a Sala em vez de assumir 960x544: a sala do chefe e
## uma cena de dados como qualquer outra, e cravar a dimensao aqui faria a Rede
## sair torta no dia em que alguem desenhar uma arena diferente -- sem erro
## nenhum, so faixas no lugar errado.
func _limites_da_arena() -> Rect2:
	var no := get_parent()
	while no != null:
		if no is Sala:
			return (no as Sala).obter_limites()
		no = no.get_parent()
	return Rect2(_centro - Vector2(480, 272), Vector2(960, 544))


## REDE DE EXTERMINIO -- faixas letais no chao, com vao entre elas.
##
## A grade e construida a partir dos VAOS, e nao das faixas: `FAIXAS_REDE` linhas
## letais por eixo deixam `FAIXAS_REDE + 1` corredores livres por eixo, sempre.
## E por isso que `aberturas_de()` consegue prometer area segura sem depender de
## sorte -- nao ha combinacao de numeros que feche a arena.
##
## Metade das faixas nasce deslocada na direcao do jogador: sao as que "se
## movimentam lentamente em direcao ao jogador". O aviso longo (0,95 s) e o que
## torna isso legivel em vez de aleatorio.
func _semear_rede() -> void:
	var arena := _limites_da_arena()
	var aviso := duracao_telegrafo(REDE, fase_chefe)
	var passo_x := arena.size.x / float(FAIXAS_REDE + 1)
	var passo_y := arena.size.y / float(FAIXAS_REDE + 1)
	var deriva := Vector2.ZERO
	if alvo != null and is_instance_valid(alvo):
		deriva = (alvo.global_position - _centro).normalized() * DERIVA_REDE

	for i in FAIXAS_REDE:
		var x := arena.position.x + passo_x * float(i + 1)
		var desvio_x := deriva.x if i % 2 == 1 else 0.0
		_plantar_faixa(
			Vector2(x + desvio_x, arena.position.y + arena.size.y * 0.5),
			Vector2(LARGURA_FAIXA, arena.size.y),
			aviso
		)
		var y := arena.position.y + passo_y * float(i + 1)
		var desvio_y := deriva.y if i % 2 == 0 else 0.0
		_plantar_faixa(
			Vector2(arena.position.x + arena.size.x * 0.5, y + desvio_y),
			Vector2(arena.size.x, LARGURA_FAIXA),
			aviso
		)


func _plantar_faixa(centro: Vector2, tamanho: Vector2, aviso: float) -> void:
	var area := CENA_AREA.instantiate()
	# tempo_aviso e lido no _ready, entao tem de ser escrito ANTES do add_child.
	# Escrito depois, a faixa avisaria pelo tempo padrao e explodiria fora de
	# sincronia com o resto da grade -- e uma grade que nao fecha junto nao e
	# uma grade.
	area.tempo_aviso = aviso
	area.cor = cor_base
	var meia := tamanho * 0.5
	var quad := PackedVector2Array([
		Vector2(-meia.x, -meia.y), Vector2(meia.x, -meia.y),
		Vector2(meia.x, meia.y), Vector2(-meia.x, meia.y),
	])
	get_parent().add_child(area)
	area.configurar(centro, -1.0, dano_contato, quad)
	_faixas.append(area)


## SOBRECARGA DO NUCLEO -- o unico ataque dela que o jogador pode DESLIGAR.
##
## Ela para de atacar e comeca a carregar; ao redor nascem pontos de energia.
## Cada um destruido encurta o estouro. E simultaneamente o momento de pressao
## maxima e a janela de dano da luta inteira -- enquanto carrega, ela nao faz
## mais nada, e quem entende isso troca a esquiva por dano.
func _semear_sobrecarga() -> void:
	for i in NUCLEOS_SOBRECARGA:
		var no := CENA_NUCLEO.instantiate()
		var angulo := TAU * float(i) / float(NUCLEOS_SOBRECARGA) + randf() * 0.4
		get_parent().add_child(no)
		no.global_position = global_position + Vector2.RIGHT.rotated(angulo) * 168.0
		_nucleos.append(no)


## O estouro: cunhas radiais que cobrem a arena MENOS uma coroa junto dela.
##
## A coroa nao e generosidade -- e a regra. "Uma pequena area segura proxima ao
## nucleo" e o que impede o ataque de virar dano inevitavel, e e o unico motivo
## pelo qual ele pode ser tao grande quanto e. Correr PARA o perigo e a resposta,
## e essa inversao e o que faz o momento ser lembrado.
func _estourar_sobrecarga() -> void:
	var sobreviveram := 0
	for n in _nucleos:
		if is_instance_valid(n):
			sobreviveram += 1
			n.queue_free()
	_nucleos.clear()

	var arena := _limites_da_arena()
	var alcance_cheio := arena.size.length() * 0.5
	# Cada nucleo destruido tira uma fatia do alcance. Destruir todos deixa o
	# estouro quase inofensivo, que e a recompensa por ter largado a esquiva.
	var fracao := float(sobreviveram) / float(NUCLEOS_SOBRECARGA)
	var alcance := RAIO_SEGURO_SOBRECARGA + (alcance_cheio - RAIO_SEGURO_SOBRECARGA) * fracao
	if alcance <= RAIO_SEGURO_SOBRECARGA + 8.0:
		EventBus.pedido_shake.emit(2.0, 0.2)
		return

	var passo := TAU / float(CUNHAS_SOBRECARGA)
	for i in CUNHAS_SOBRECARGA:
		var a0 := passo * float(i)
		var a1 := a0 + passo * 0.82
		var quad := PackedVector2Array([
			Vector2.RIGHT.rotated(a0) * RAIO_SEGURO_SOBRECARGA,
			Vector2.RIGHT.rotated(a1) * RAIO_SEGURO_SOBRECARGA,
			Vector2.RIGHT.rotated(a1) * alcance,
			Vector2.RIGHT.rotated(a0) * alcance,
		])
		var area := CENA_AREA.instantiate()
		area.tempo_aviso = 0.35
		area.cor = cor_base
		get_parent().add_child(area)
		area.configurar(global_position, -1.0, dano_contato, quad)
		_faixas.append(area)
	EventBus.pedido_shake.emit(9.0, 0.5)


func _limpar_semeados() -> void:
	var vivas: Array[Node] = []
	for a in _faixas:
		if is_instance_valid(a):
			vivas.append(a)
	_faixas = vivas
	var nucleos: Array[Node] = []
	for n in _nucleos:
		if is_instance_valid(n):
			nucleos.append(n)
	_nucleos = nucleos


## Ela anuncia o que leu. E a metade visivel da Predicao Comportamental: sem a
## mensagem, o jogador sofre a correcao sem nunca saber que houve uma.
func _anunciar_padrao(padrao: int) -> void:
	if padrao == _padrao_anunciado:
		return
	_padrao_anunciado = padrao
	EventBus.boss_leitura.emit("PADRÃO IDENTIFICADO", int(round(_perfil.confianca() * 100.0)))


# --------------------------------------------------- fase absoluta ---------

## "Recalculando..." -- e entao a arena assume.
##
## O corpo dela para de orbitar e ANCORA. Nao e derrota: e o oposto. Ate aqui
## ela usava um corpo porque um corpo bastava; a partir daqui ela nao precisa
## mais de um, e o que ataca e o lugar.
##
## A janela vulneravel antes disso e literal do texto dela ("todas as armas da
## arena sao desligadas por alguns segundos. A Diretora permanece vulneravel"),
## e ela paga um problema real de ritmo: da ao jogador um respiro logo antes do
## trecho mais denso da luta, em vez de empilhar as duas coisas.
func _entrar_em_absoluta() -> void:
	if _absoluta:
		return
	_absoluta = true
	_t_acao = RECALCULANDO
	_t_torre = RECALCULANDO
	# Ela esquece o que aprendeu e recomeca a ler. E o que a palavra
	# "recalculando" promete, e o que devolve ao jogador a chance de construir
	# um habito novo em vez de carregar a leitura da luta inteira.
	_perfil.esquecer()
	EventBus.boss_leitura.emit("RECALCULANDO", 0)


## As torres sobem enquanto a fase durar, respeitando o teto.
func _manter_arena(delta: float) -> void:
	var vivas: Array[Node] = []
	for t in _torres:
		if is_instance_valid(t) and not (t as InimigoBase).morto:
			vivas.append(t)
	_torres = vivas

	_t_torre -= delta
	if _t_torre > 0.0 or _torres.size() >= MAX_TORRES:
		return
	_t_torre = INTERVALO_TORRE

	var arena := _limites_da_arena()
	# Nas quinas, e nunca no meio: torre no miolo bloquearia o espaco que o
	# jogador precisa para atravessar a Rede, e dois perigos que se sobrepoem
	# viram um so, sem saida.
	var margem := Vector2(arena.size.x * 0.22, arena.size.y * 0.24)
	var cantos := [
		arena.position + margem,
		arena.position + Vector2(arena.size.x - margem.x, margem.y),
		arena.position + Vector2(margem.x, arena.size.y - margem.y),
		arena.position + arena.size - margem,
	]
	var torre := CENA_TORRE.instantiate()
	get_parent().add_child(torre)
	torre.global_position = cantos[randi() % cantos.size()]
	_torres.append(torre)
	EventBus.pedido_shake.emit(4.2, 0.3)


# ------------------------------------------------------------------ vida ---

func receber_dano(quantidade: int, impulso: Vector2 = Vector2.ZERO) -> bool:
	if morto:
		return false
	# O chefe nao e empurrado -- so o dano importa.
	var antes := vida
	vida -= quantidade
	_flash()
	EventBus.boss_vida_mudou.emit(maxi(vida, 0), vida_maxima)
	if antes > 0:
		_checar_fase()
	if vida <= 0:
		morrer()
	return true


func _checar_fase() -> void:
	var razao := float(vida) / float(vida_maxima)
	var nova := 1
	if razao <= FRACAO_ABSOLUTA:
		nova = 4
	elif razao <= 0.33:
		nova = 3
	elif razao <= 0.66:
		nova = 2
	if nova == fase_chefe:
		return
	fase_chefe = nova
	_fila.clear()
	fase_mudou.emit(fase_chefe)
	EventBus.boss_fase_mudou.emit(fase_chefe)
	EventBus.pedido_shake.emit(8.4, 0.6)
	Deterioracao.adicionar(5.0)
	# Pequena janela de alivio na virada de fase, senao a transicao vira
	# dano gratuito em cima de quem estava no meio de uma esquiva.
	_acao = Acao.OCIOSA
	_t_acao = ALIVIO_DE_FASE
	_laser.visible = false
	_aviso.visible = false
	if fase_chefe >= 4:
		_entrar_em_absoluta()


func morrer() -> void:
	if morto:
		return
	# Aviso no chao tem de morrer com quem o pediu. Um perigo que sobrevive ao
	# chefe cobra dano depois de a luta ter acabado -- e a mesma licao que o
	# Parasita ja tinha aprendido com as areas dele.
	for a in _faixas:
		if is_instance_valid(a):
			a.queue_free()
	_faixas.clear()
	for n in _nucleos:
		if is_instance_valid(n):
			n.queue_free()
	_nucleos.clear()
	# As torres SAO ela. Morto o sistema, a arena volta a ser so uma sala.
	for t in _torres:
		if is_instance_valid(t):
			(t as Node).queue_free()
	_torres.clear()
	_laser.visible = false
	_aviso.visible = false
	EventBus.boss_morreu.emit()
	EventBus.pedido_shake.emit(15.6, 1.4)
	super.morrer()
