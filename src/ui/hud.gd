extends CanvasLayer
## Toda a HUD escuta o EventBus. Ela nao tem referencia nenhuma para o Player,
## para os inimigos ou para o gerenciador de ondas -- de proposito. Da para
## apagar a HUD inteira do projeto e o jogo continua rodando.

## Cor de descanso do rotulo de municao. Guardada como constante porque o
## aviso de recarga pinta por cima e precisa saber para onde voltar.
const COR_MUNICAO := Color(0.7, 0.78, 0.9)

## Cor do nome quando o implante foi RECUSADO. Ambar e nao vermelho: nao houve
## dano nem erro, so um limite -- vermelho aqui competiria com o aviso de perigo.
const COR_AVISO_RECUSADO := Color(1.0, 0.72, 0.29)

## Ultimo estado de municao recebido. Guardado porque o texto e remontado
## depois da recarga, quando nenhum sinal novo chega.
var _no_pente: int = 0
var _reserva: int = -1
var _recarregando: bool = false

## Avisos de aquisicao esperando a vez. Fila, e nao substituicao: pegar dois
## implantes em sequencia trocava o primeiro antes de dar tempo de ler, e a
## descricao existe justamente para ser lida.
var _fila_avisos: Array[Dictionary] = []
## O tween do aviso em exibicao. Guardado para saber se ha algo na tela sem
## precisar de um booleano paralelo que possa dessincronizar.
var _tween_aviso_item: Tween
var _tween_leitura: Tween = null

@onready var _rotulo_fase: Label = $Topo/Esquerda/Fase
@onready var _rotulo_arma: Label = $Rodape/Arma
@onready var _rotulo_municao: Label = $Rodape/Municao
@onready var _rotulo_salas: Label = $Topo/Direita/Salas
@onready var _rotulo_inimigos: Label = $Topo/Direita/Inimigos
@onready var _rotulo_tempo: Label = $Topo/Direita/Tempo
@onready var _aviso: Label = $Aviso
@onready var _aviso_sub: Label = $AvisoSub
@onready var _boss: Control = $Boss
@onready var _boss_nome: Label = $Boss/Nome
@onready var _boss_barra: ProgressBar = $Boss/Barra
@onready var _boss_leitura: Label = $Boss/Leitura
@onready var _overlay: ColorRect = $Overlay
@onready var _dica_preditiva: Label = $DicaPreditiva
@onready var _aviso_item: VBoxContainer = $AvisoItem
@onready var _aviso_item_nome: Label = $AvisoItem/Nome
@onready var _aviso_item_desc: Label = $AvisoItem/Descricao

var _mat: ShaderMaterial


func _ready() -> void:
	_mat = _overlay.material as ShaderMaterial
	_boss.visible = false
	_aviso.modulate.a = 0.0
	_aviso_sub.modulate.a = 0.0
	_dica_preditiva.modulate.a = 0.0
	_aviso_item.modulate.a = 0.0

	EventBus.deterioracao_mudou.connect(_ao_deterioracao)
	# Sem isto, desligar o glitch no meio da run so faria efeito no proximo
	# tique da Deterioracao.
	EventBus.configuracao_mudou.connect(
		func() -> void: _ao_deterioracao(Deterioracao.valor, Deterioracao.fase)
	)
	EventBus.fase_deterioracao_mudou.connect(_ao_mudar_fase)
	EventBus.arma_equipada.connect(_ao_equipar_arma)
	EventBus.municao_mudou.connect(_ao_municao)
	EventBus.recarga_iniciada.connect(_ao_recarga_iniciada)
	EventBus.recarga_concluida.connect(_ao_recarga_concluida)
	# andar_gerado tambem, e nao so as transicoes: o total de salas so existe
	# depois que o andar e montado, e sem este a HUD abriria com o campo vazio
	# ate o jogador limpar a primeira sala.
	EventBus.andar_gerado.connect(_atualizar_progresso)
	EventBus.sala_limpa.connect(func(_s: Node2D) -> void: _atualizar_progresso())
	EventBus.transicao_concluida.connect(func(_s: Node2D) -> void: _atualizar_progresso())
	EventBus.contagem_inimigos_mudou.connect(_ao_contagem)
	EventBus.boss_revelado.connect(_ao_boss_revelado)
	EventBus.boss_vida_mudou.connect(_ao_boss_vida)
	EventBus.boss_morreu.connect(_ao_boss_morreu)
	EventBus.boss_leitura.connect(_ao_boss_leitura)
	EventBus.item_coletado.connect(_ao_item_coletado)
	EventBus.item_recusado.connect(_ao_item_recusado)
	EventBus.arma_adquirida.connect(_ao_arma_adquirida)

	_ao_deterioracao(Deterioracao.valor, Deterioracao.fase)


func _process(_delta: float) -> void:
	_rotulo_tempo.text = GameState.formatar_tempo(GameState.tempo_run)


func _ao_deterioracao(valor: float, _fase: int) -> void:
	_rotulo_fase.text = "%s  %d%%" % [Deterioracao.nome_fase(), int(valor)]
	_rotulo_fase.modulate = Deterioracao.cor_fase()
	if _mat != null:
		# O fator vem da tela de opcoes: quem tem sensibilidade visual desliga o
		# glitch sem perder a informacao da barra de Deterioracao.
		_mat.set_shader_parameter(
			"intensidade",
			Deterioracao.intensidade_glitch() * Configuracao.fator_glitch()
		)


func _ao_mudar_fase(fase_nova: int, fase_antiga: int) -> void:
	if fase_nova <= fase_antiga:
		return
	match fase_nova:
		Deterioracao.Fase.MEDIA:
			_mostrar_aviso(
				tr("DEGRADAÇÃO EM 50%"),
				# Duas chaves juntadas aqui, e nao uma frase de duas linhas na
				# tabela: o importador de CSV do Godot le quebra de linha como
				# fim de registro, e a chave sairia partida ao meio.
				tr("Eles pararam de mirar em você.")
					+ "\n"
					+ tr("Agora miram onde você vai estar.")
			)
			_piscar_dica()
		Deterioracao.Fase.CRITICA:
			_mostrar_aviso(tr("NÍVEL CRÍTICO"), tr("Não confie no que você está vendo."))


func _piscar_dica() -> void:
	_dica_preditiva.text = tr("MIRA PREDITIVA ATIVA")
	var t := create_tween()
	t.tween_property(_dica_preditiva, "modulate:a", 1.0, 0.25)
	t.tween_interval(3.5)
	t.tween_property(_dica_preditiva, "modulate:a", 0.0, 0.8)


func _ao_equipar_arma(dados: Resource, _slot: int) -> void:
	if dados == null:
		return
	_rotulo_arma.text = dados.nome
	_rotulo_arma.modulate = dados.cor_projetil


func _ao_municao(no_pente: int, reserva: int) -> void:
	_no_pente = no_pente
	_reserva = reserva
	if _recarregando:
		return
	_rotulo_municao.text = _texto_municao()


func _texto_municao() -> String:
	# Reserva infinita vira o simbolo, nao a palavra: o numero que importa
	# durante o tiroteio e o do pente, e "INFINITA" ocupava o lugar dele.
	var texto_reserva := "∞" if _reserva < 0 else str(_reserva)
	return "%d / %s" % [_no_pente, texto_reserva]


## Sem este aviso o jogador clica, nao sai tiro, e ele acha que travou.
func _ao_recarga_iniciada(_duracao: float) -> void:
	_recarregando = true
	_rotulo_municao.text = tr("RECARREGANDO...")
	_rotulo_municao.modulate = Color(1.0, 0.72, 0.29)


func _ao_recarga_concluida() -> void:
	_recarregando = false
	_rotulo_municao.modulate = COR_MUNICAO
	_rotulo_municao.text = _texto_municao()


func _atualizar_progresso() -> void:
	if GameState.total_salas <= 0:
		_rotulo_salas.text = ""
		return
	_rotulo_salas.text = tr("SALAS %d / %d") % [GameState.salas_limpas, GameState.total_salas]


func _ao_contagem(vivos: int) -> void:
	_rotulo_inimigos.text = tr("HOSTIS %d") % vivos


func _mostrar_aviso(titulo: String, subtitulo: String) -> void:
	_aviso.text = titulo
	_aviso_sub.text = subtitulo
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_aviso, "modulate:a", 1.0, 0.28)
	t.tween_property(_aviso_sub, "modulate:a", 0.85, 0.28)
	t.chain().tween_interval(2.1)
	t.chain().set_parallel(true)
	t.tween_property(_aviso, "modulate:a", 0.0, 0.6)
	t.tween_property(_aviso_sub, "modulate:a", 0.0, 0.6)


# --------------------------------------------- aviso de aquisicao ---
# Faixa propria, e nao o $Aviso central, por tres motivos: _mostrar_aviso nao e
# reentrante (dois tweens no mesmo no brigam pelo alpha, e implante durante um
# aviso de Deterioracao faria os dois piscarem errado); o $Aviso e fonte 32 e
# existe para assustar, enquanto implante acontece ~16 vezes por run; e ele fica
# em cima de onde o jogador esta mirando. Aqui o fade roda no modulate do
# CONTAINER, entao e sempre um no e um tween so.


func _ao_item_coletado(dados: Resource) -> void:
	if dados == null:
		return
	_enfileirar_aviso(tr(dados.nome), tr(dados.descricao), dados.cor)


## O implante bateu o limite por run e continua no chao. Sem isto o jogador
## passa por cima e nao acontece nada -- nem o item, nem a explicacao.
func _ao_item_recusado(dados: Resource) -> void:
	if dados == null:
		return
	_enfileirar_aviso(
		tr(dados.nome),
		tr("Você já instalou o máximo deste implante."),
		COR_AVISO_RECUSADO
	)


func _ao_arma_adquirida(dados: Resource) -> void:
	if dados == null:
		return
	_enfileirar_aviso(dados.nome, tr(dados.descricao), dados.cor_projetil)


func _enfileirar_aviso(titulo: String, texto: String, cor: Color) -> void:
	var aviso := {"titulo": titulo, "texto": texto, "cor": cor}
	# Repetido nao entra: o pickup recusado fica no chao, e andar por cima dele
	# de novo redispara body_entered. Sem esta guarda, atravessar a sala duas
	# vezes enfileirava a mesma frase duas vezes.
	if _fila_avisos.size() > 0 and _fila_avisos[_fila_avisos.size() - 1] == aviso:
		return
	_fila_avisos.append(aviso)
	if not _exibindo_aviso():
		_proximo_aviso()


## is_valid() e nao "!= null": um tween morto na troca de cena ou no fim da run
## continua sendo um objeto, e testar so por null deixaria a fila travada para
## sempre com um tween que nunca vai emitir finished.
func _exibindo_aviso() -> bool:
	return _tween_aviso_item != null and _tween_aviso_item.is_valid()


func _proximo_aviso() -> void:
	if _fila_avisos.is_empty():
		_tween_aviso_item = null
		return

	var aviso: Dictionary = _fila_avisos.pop_front()
	_aviso_item_nome.text = aviso["titulo"]
	_aviso_item_desc.text = aviso["texto"]
	# So o nome recebe a cor: a descricao em cor de item perderia contraste, e o
	# que precisa ser reconhecido de relance e o tipo, nao o texto.
	_aviso_item_nome.modulate = aviso["cor"]

	_tween_aviso_item = create_tween()
	_tween_aviso_item.tween_property(_aviso_item, "modulate:a", 1.0, 0.25)
	# Segura mais que o aviso de Deterioracao (2,1s) porque aqui sao duas linhas
	# para ler, nao um titulo de duas palavras.
	_tween_aviso_item.tween_interval(2.6)
	_tween_aviso_item.tween_property(_aviso_item, "modulate:a", 0.0, 0.5)
	_tween_aviso_item.finished.connect(_proximo_aviso, CONNECT_ONE_SHOT)


func _ao_boss_revelado(nome: String, vida_max: int) -> void:
	# Na onda do chefe a contagem de hostis so confunde -- o que importa
	# esta na barra dele.
	_rotulo_inimigos.visible = false
	_boss.visible = true
	_boss_nome.text = nome
	_boss_barra.max_value = vida_max
	_boss_barra.value = vida_max


func _ao_boss_vida(atual: int, _maximo: int) -> void:
	var t := create_tween()
	t.tween_property(_boss_barra, "value", float(atual), 0.15)


## O chefe anunciando o que leu do jogador.
##
## Vai num rotulo PROPRIO dentro do painel do chefe, e nao na fila de avisos de
## item: a fila e para coisa que aconteceu UMA vez e precisa ser lida com calma,
## e isto aqui pisca varias vezes por luta. Misturar os dois faria a leitura do
## chefe empurrar da tela o nome do implante que o jogador acabou de pegar.
##
## Os 42 px sob a barra ja estavam reservados no layout -- o rotulo nasce dentro
## deles, sem empurrar nada.
func _ao_boss_leitura(rotulo: String, confianca: int) -> void:
	if _boss_leitura == null:
		return
	_boss_leitura.text = "%s   %d%%" % [tr(rotulo), confianca]
	if _tween_leitura != null and _tween_leitura.is_valid():
		_tween_leitura.kill()
	_boss_leitura.modulate.a = 1.0
	_tween_leitura = create_tween()
	_tween_leitura.tween_interval(1.6)
	_tween_leitura.tween_property(_boss_leitura, "modulate:a", 0.0, 0.6)


func _ao_boss_morreu() -> void:
	var t := create_tween()
	t.tween_property(_boss, "modulate:a", 0.0, 0.8)
	t.tween_callback(func() -> void: _boss.visible = false)
