extends CanvasLayer
## Tela de fim de run. Cobre tanto derrota quanto vitoria -- e a mesma
## informacao, muda so o tom.
##
## Ela era a unica tela do jogo operada por TECLA DECORADA: imprimia
## "R outra run / ESC trocar de personagem" num rotulo e esperava que o jogador
## lesse e decorasse. As outras tres -- menu, opcoes e selecao de operador --
## sempre foram listas de botoes navegaveis por mouse e teclado. Agora esta
## tambem e.
##
## O visual segue a SELECAO DE OPERADOR, e nao o menu inicial: a moldura
## chanfrada e a linguagem nova do projeto, e o menu ainda nao migrou. Dela vem
## o quadro central e a barra de acoes de 800x50; do menu vem o tratamento de
## botao (marcador ">", laranja de acao, ambar de foco).
##
## A cor da moldura segue o DESFECHO em vez de ser neutra. A `MolduraHud` existe
## para ser tingida, e aqui o tingimento carrega informacao: verde-agua quando
## se venceu, vermelho quando se perdeu, antes de qualquer texto ser lido.

## Em quantas colunas o rotulo cabe antes do valor.
const LARGURA_ROTULO := 24

const COR_VITORIA := Color(0.4, 1.0, 0.85)
const COR_DERROTA := Color(1.0, 0.3, 0.45)

## Alfa da moldura secundaria contra a principal. Hierarquia por alfa, e nao por
## matiz -- e o que a selecao de operador ja faz entre o quadro e a barra.
const ALFA_BARRA := 0.7
## Alfa do filete separador, o mesmo divisor de 1 px que os cartoes usam.
const ALFA_SEPARADOR := 0.22

@onready var _fundo: ColorRect = $Fundo
@onready var _quadro: MolduraHud = $Quadro
@onready var _barra: MolduraHud = $BarraInferior
@onready var _titulo: Label = $Quadro/Conteudo/Titulo
@onready var _sub: Label = $Quadro/Conteudo/Subtitulo
@onready var _separador: ColorRect = $Quadro/Conteudo/Separador
@onready var _stats: Label = $Quadro/Conteudo/Stats
@onready var _btn_recomecar: Button = $BarraInferior/Botoes/BtnRecomecar
@onready var _btn_menu: Button = $BarraInferior/Botoes/BtnMenu

var _botoes: Array[Button] = []
## botao -> o texto em portugues, que e a CHAVE de traducao.
var _chaves: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_botoes = [_btn_recomecar, _btn_menu]

	for btn in _botoes:
		# A chave e capturada ANTES de qualquer reescrita: depois que o marcador
		# entra, o texto na tela deixa de ser a chave -- e em ingles deixa de ser
		# duas vezes.
		_chaves[btn] = btn.text.strip_edges()
		# "> RECOMEÇAR" nao existe na tabela. Com a traducao automatica ligada, o
		# botao ficaria em portugues no jogo em ingles, sem erro nenhum.
		btn.auto_translate_mode = Control.AUTO_TRANSLATE_MODE_DISABLED
		# Booleano primeiro, no depois: focus_entered nao passa argumento, entao
		# o que o bind anexa chega na ordem em que foi ligado. Invertido, cada
		# foco cospe um erro de conversao no console.
		btn.focus_entered.connect(_ao_focar.bind(true, btn))
		btn.focus_exited.connect(_ao_focar.bind(false, btn))
		# Unifica mouse e teclado num estado so, como no menu.
		btn.mouse_entered.connect(btn.grab_focus)
		_ao_focar(false, btn)

	_btn_recomecar.pressed.connect(_recomecar)
	_btn_menu.pressed.connect(_ir_para_o_menu)
	EventBus.run_terminada.connect(_ao_terminar)


func _ao_terminar(venceu: bool, dados: Dictionary) -> void:
	# Deixa a explosao acontecer antes de cortar para a tela.
	await get_tree().create_timer(1.1, true, false, true).timeout

	visible = true
	_fundo.modulate.a = 0.0
	_quadro.modulate.a = 0.0
	_barra.modulate.a = 0.0

	var cor := COR_VITORIA if venceu else COR_DERROTA
	if venceu:
		_titulo.text = tr("DIRETORA OFFLINE")
		_sub.text = tr("Você sobreviveu à própria cabeça. Por enquanto.")
	else:
		_titulo.text = tr("CONSCIÊNCIA PERDIDA")
		_sub.text = tr("Restaurando do último backup...")
	_titulo.modulate = cor
	_quadro.cor_borda = cor
	_barra.cor_borda = Color(cor, ALFA_BARRA)
	_separador.color = Color(cor, ALFA_SEPARADOR)

	_stats.text = "\n".join(_linhas(dados))

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_fundo, "modulate:a", 1.0, 0.5)
	t.tween_property(_quadro, "modulate:a", 1.0, 0.6)
	t.tween_property(_barra, "modulate:a", 1.0, 0.6)

	get_tree().paused = true
	# Depois do paused: o foco precisa da arvore ja estavel, e este no roda em
	# PROCESS_MODE_ALWAYS de qualquer jeito.
	_btn_recomecar.grab_focus()


func _linhas(dados: Dictionary) -> Array[String]:
	var linhas: Array[String] = [
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
	return linhas


# ------------------------------------------------------------- acoes --------

## RECOMECAR volta para a escolha de operador, e nao para a mesma run.
##
## Antes o R recarregava a cena mantendo o personagem -- um retry rapido que
## pulava a escolha. Passar pela selecao custa um clique e devolve a decisao que
## abre a run: morrer com a RAVEN e a hora mais provavel de querer tentar a NOVA.
func _recomecar() -> void:
	GameState.abrir_selecao_ao_entrar = true
	_ir_para_o_menu()


func _ir_para_o_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/ui/menu_inicial.tscn")


## ESC continua valendo, como atalho do botao de voltar.
##
## Marcar o evento como tratado e OBRIGATORIO: `main.gd` escuta `pausar` em
## `_unhandled_input` e, com a run ja terminada, aquele ramo chama
## `get_tree().quit()`. Sem esta linha o mesmo ESC voltaria ao menu e fecharia o
## jogo no mesmo frame.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pausar"):
		_ir_para_o_menu()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------- botoes -------

## O marcador de foco. Le a chave guardada em vez de raspar o proprio texto:
## raspar so funciona enquanto o texto na tela E a chave, e em ingles ele deixa
## de ser.
##
## O prefixo fora do foco sao DOIS ESPACOS, e nao string vazia -- a largura fica
## constante e o rotulo nao pula de lugar a cada troca de foco.
func _ao_focar(focado: bool, btn: Button) -> void:
	var base: String = _chaves.get(btn, btn.text.strip_edges())
	btn.text = ("> " if focado else "  ") + tr(base)


## O jogador trocou de idioma nas opcoes. Como estes botoes tem a traducao
## automatica desligada, ninguem os reescreve por conta propria.
func _notification(que: int) -> void:
	if que != NOTIFICATION_TRANSLATION_CHANGED:
		return
	for btn in _botoes:
		if is_instance_valid(btn):
			_ao_focar(btn.has_focus(), btn)


## Uma linha da tabela de estatisticas, com o valor alinhado numa coluna.
##
## O rotulo era preenchido com espacos escritos a mao dentro da propria
## string. Traduzido, cada rotulo muda de comprimento e a coluna de valores
## vira uma escada. rpad refaz o alinhamento depois de traduzir.
func _linha(rotulo: String, valor: String) -> String:
	return tr(rotulo).rpad(LARGURA_ROTULO) + valor
