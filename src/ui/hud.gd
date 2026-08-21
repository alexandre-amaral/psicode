extends CanvasLayer
## Toda a HUD escuta o EventBus. Ela nao tem referencia nenhuma para o Player,
## para os inimigos ou para o gerenciador de ondas -- de proposito. Da para
## apagar a HUD inteira do projeto e o jogo continua rodando.

@onready var _rotulo_fase: Label = $Topo/Esquerda/Fase
@onready var _rotulo_arma: Label = $Rodape/Arma
@onready var _rotulo_municao: Label = $Rodape/Municao
@onready var _rotulo_onda: Label = $Topo/Direita/Onda
@onready var _rotulo_inimigos: Label = $Topo/Direita/Inimigos
@onready var _rotulo_tempo: Label = $Topo/Direita/Tempo
@onready var _aviso: Label = $Aviso
@onready var _aviso_sub: Label = $AvisoSub
@onready var _boss: Control = $Boss
@onready var _boss_nome: Label = $Boss/Nome
@onready var _boss_barra: ProgressBar = $Boss/Barra
@onready var _overlay: ColorRect = $Overlay
@onready var _dica_preditiva: Label = $DicaPreditiva

var _mat: ShaderMaterial


func _ready() -> void:
	_mat = _overlay.material as ShaderMaterial
	_boss.visible = false
	_aviso.modulate.a = 0.0
	_aviso_sub.modulate.a = 0.0
	_dica_preditiva.modulate.a = 0.0

	EventBus.deterioracao_mudou.connect(_ao_deterioracao)
	EventBus.fase_deterioracao_mudou.connect(_ao_mudar_fase)
	EventBus.arma_equipada.connect(_ao_equipar_arma)
	EventBus.municao_mudou.connect(_ao_municao)
	EventBus.onda_iniciada.connect(_ao_onda_iniciada)
	EventBus.contagem_inimigos_mudou.connect(_ao_contagem)
	EventBus.boss_revelado.connect(_ao_boss_revelado)
	EventBus.boss_vida_mudou.connect(_ao_boss_vida)
	EventBus.boss_morreu.connect(_ao_boss_morreu)

	_ao_deterioracao(Deterioracao.valor, Deterioracao.fase)


func _process(_delta: float) -> void:
	_rotulo_tempo.text = GameState.formatar_tempo(GameState.tempo_run)


func _ao_deterioracao(valor: float, _fase: int) -> void:
	_rotulo_fase.text = "%s  %d%%" % [Deterioracao.nome_fase(), int(valor)]
	_rotulo_fase.modulate = Deterioracao.cor_fase()
	if _mat != null:
		_mat.set_shader_parameter("intensidade", Deterioracao.intensidade_glitch())


func _ao_mudar_fase(fase_nova: int, fase_antiga: int) -> void:
	if fase_nova <= fase_antiga:
		return
	match fase_nova:
		Deterioracao.Fase.MEDIA:
			_mostrar_aviso("DEGRADACAO EM 50%", "Eles pararam de mirar em voce.\nAgora miram onde voce vai estar.")
			_piscar_dica()
		Deterioracao.Fase.CRITICA:
			_mostrar_aviso("NIVEL CRITICO", "Nao confie no que voce esta vendo.")


func _piscar_dica() -> void:
	_dica_preditiva.text = "MIRA PREDITIVA ATIVA"
	var t := create_tween()
	t.tween_property(_dica_preditiva, "modulate:a", 1.0, 0.25)
	t.tween_interval(3.5)
	t.tween_property(_dica_preditiva, "modulate:a", 0.0, 0.8)


func _ao_equipar_arma(dados: Resource, _slot: int) -> void:
	if dados == null:
		return
	_rotulo_arma.text = dados.nome
	_rotulo_arma.modulate = dados.cor_projetil


func _ao_municao(atual: int, maximo: int) -> void:
	_rotulo_municao.text = "INFINITA" if maximo < 0 else "%d / %d" % [atual, maximo]


func _ao_onda_iniciada(indice: int, total: int) -> void:
	_rotulo_onda.text = "ONDA %d / %d" % [indice + 1, total]
	var dados: DadosOnda = _dados_da_onda(indice)
	if dados != null:
		_mostrar_aviso(dados.titulo, dados.subtitulo)


func _dados_da_onda(indice: int) -> DadosOnda:
	var g := get_tree().get_first_node_in_group("gerenciador_ondas")
	if g == null or indice >= g.ondas.size():
		return null
	return g.ondas[indice]


func _ao_contagem(vivos: int) -> void:
	_rotulo_inimigos.text = "HOSTIS %d" % vivos


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


func _ao_boss_morreu() -> void:
	var t := create_tween()
	t.tween_property(_boss, "modulate:a", 0.0, 0.8)
	t.tween_callback(func() -> void: _boss.visible = false)
