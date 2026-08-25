extends CanvasLayer
## Tela de fim de run. Cobre tanto derrota quanto vitoria -- e a mesma
## informacao, muda so o tom.

@onready var _fundo: ColorRect = $Fundo
@onready var _titulo: Label = $Painel/Titulo
@onready var _sub: Label = $Painel/Subtitulo
@onready var _stats: Label = $Painel/Stats
@onready var _dica: Label = $Painel/Dica


## Em quantas colunas o rotulo cabe antes do valor.
const LARGURA_ROTULO := 24


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	EventBus.run_terminada.connect(_ao_terminar)


func _ao_terminar(venceu: bool, dados: Dictionary) -> void:
	# Deixa a explosao acontecer antes de cortar para a tela.
	await get_tree().create_timer(1.1, true, false, true).timeout

	visible = true
	_fundo.modulate.a = 0.0
	$Painel.modulate.a = 0.0

	if venceu:
		_titulo.text = tr("DIRETORA OFFLINE")
		_titulo.modulate = Color(0.4, 1.0, 0.85)
		_sub.text = tr("Você sobreviveu à própria cabeça. Por enquanto.")
	else:
		_titulo.text = tr("CONSCIÊNCIA PERDIDA")
		_titulo.modulate = Color(1.0, 0.3, 0.45)
		_sub.text = tr("Restaurando do último backup...")

	var linhas := [
		_linha("SALAS LIMPAS", "%d / %d" % [dados.get("salas_limpas", 0), dados.get("total_salas", 0)]),
		_linha("HOSTIS NEUTRALIZADOS", "%d" % dados.get("inimigos_mortos", 0)),
		_linha("CRÉDITOS", "%d" % dados.get("creditos", 0)),
		_linha("TEMPO", GameState.formatar_tempo(dados.get("tempo", 0.0))),
	]
	# So aparece quando houve luta. Numa run que acabou na terceira sala a linha
	# marcaria 00:00, e um zero na tela le como bug, nao como "nao aconteceu".
	var tempo_chefe: float = dados.get("tempo_chefe", 0.0)
	if tempo_chefe > 0.0:
		linhas.append(_linha("LUTA DO CHEFE", GameState.formatar_tempo(tempo_chefe)))
	linhas.append(_linha("DETERIORAÇÃO FINAL", "%d%%" % int(dados.get("deterioracao_final", 0.0))))
	_stats.text = "\n".join(linhas)
	_dica.text = tr("R  outra run          ESC  trocar de personagem")

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_fundo, "modulate:a", 1.0, 0.5)
	t.tween_property($Painel, "modulate:a", 1.0, 0.6)

	get_tree().paused = true

## ESC volta ao menu; R nao passa por aqui.
##
## R era tratado nos DOIS lados -- aqui trocando para o menu e em main.gd
## chamando GameState.reiniciar() -- e como este `_input` nunca marcava o evento
## como tratado, os dois disparavam no mesmo frame e quem vencia dependia da
## ordem de deferimento da troca de cena. Hoje main.gd e o dono unico do R: ele
## recarrega o andar mantendo o personagem, que e o retry rapido que um
## roguelike quer. Quem quiser TROCAR de personagem sai pelo ESC.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pausar"):
		get_tree().paused = false
		get_tree().change_scene_to_file("res://src/ui/menu_inicial.tscn")
		get_viewport().set_input_as_handled()

## Uma linha da tabela de estatisticas, com o valor alinhado numa coluna.
##
## O rotulo era preenchido com espacos escritos a mao dentro da propria
## string. Traduzido, cada rotulo muda de comprimento e a coluna de valores
## vira uma escada. rpad refaz o alinhamento depois de traduzir.
func _linha(rotulo: String, valor: String) -> String:
	return tr(rotulo).rpad(LARGURA_ROTULO) + valor
