extends CanvasLayer
## A tela do TAB, em tres abas: ITENS, ARMAMENTO e STATUS.
##
## Ela responde uma pergunta que a HUD nao responde: **o que eu tenho.** A
## bandeja de 16 px no canto e um REGISTRO e cabe onde esta justamente por nao
## competir com o combate; esta tela e uma CONSULTA, acontece com o jogo parado,
## e por isso pode gastar o quadro inteiro.
##
## **As tres abas nao sao arrumacao: sao tres perguntas com regras diferentes.**
## ITENS responde "o que eu instalei" e nao tem teto -- os aprimoramentos sao
## acumulativos. ARMAMENTO responde "o que eu carrego" e sao exatamente duas.
## STATUS responde "e no que isso deu", e so faz sentido depois da primeira.
## Numa tela so, o jogador teria de descobrir sozinho qual das regras vale para
## o que ele acabou de pegar -- e a lista, que e a mais importante, perderia
## coluna para a tabela derivada.
##
## **Uma versao anterior desenhava um CORPO** com os implantes pendurados por
## regiao. O dono do projeto olhou e reprovou: a ideia pode voltar, mas por
## enquanto o inventario e uma consulta e nao um retrato. `categoria_corporal`
## continua nos 16 `.tres` e continua cobrada -- e a semente daquela ideia, e
## refazer os dezesseis no dia em que ela voltar e trabalho jogado fora duas
## vezes.
##
## **Ela nao abre sozinha ao pegar um implante.** Interromper o combate para
## mostrar o que o jogador acabou de escolher e cobrar duas vezes pela mesma
## decisao -- quem avisa e o `AvisoItem` da HUD, que pisca o nome e some em 3 s.

enum Aba { ITENS, ARMAMENTO, STATUS }

const COR_ROTULO := Color(0.55, 0.70, 0.80)

var _abas: Array[Control] = []
var _botoes: Array[Button] = []
var _aba: int = Aba.ITENS

var _itens: AbaDeItens
var _armamento: AbaDeArmamento
var _status: AbaDeStatus
var _tooltip: Control
var _tooltip_nome: Label
var _tooltip_texto: Label

var _aberta: bool = false
## Ela mesma pausou a arvore? Sem a guarda, fechar o inventario aberto por cima
## de outra pausa devolveria o combate por baixo de um menu aberto.
var _pausou: bool = false


func _ready() -> void:
	# Com a arvore pausada por ela mesma, so `ALWAYS` continua rodando -- sem
	# isto o TAB abre a tela e nunca mais a fecha. Mesmo cuidado do `menu_pausa`,
	# do reticulo e da tela de troca.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_itens = $Painel/Conteudo/Itens
	_armamento = $Painel/Conteudo/Armamento
	_status = $Painel/Conteudo/Status
	_abas = [_itens, _armamento, _status]

	_botoes = [$Painel/Abas/BtnItens, $Painel/Abas/BtnArmamento, $Painel/Abas/BtnStatus]
	for i in _botoes.size():
		# `bind` e nao uma lambda por botao: tres lambdas quase iguais e onde a
		# quarta aba entraria com o indice copiado errado.
		_botoes[i].pressed.connect(_mostrar_aba.bind(i))

	_tooltip = $Painel/Tooltip
	_tooltip_nome = $Painel/Tooltip/Nome
	_tooltip_texto = $Painel/Tooltip/Texto
	_itens.apontou.connect(_ao_apontar)

	# **O titulo nao diz mais "CORPORAIS".** Ele veio da versao que desenhava um
	# corpo; com a grade no lugar dela, a palavra prometia uma leitura que a tela
	# nao entrega mais.
	$Painel/Titulo.text = tr("INVENTÁRIO")
	# **As setas sao ASCII e nao `←`/`→`.** Glifo que a fonte nao tem some sem
	# erro nenhum -- foi assim que o losango da moeda virou um buraco no preco da
	# bancada, e a HUD mostrava certo enquanto a Loja nao.
	$Painel/Rodape.text = tr("[TAB] FECHAR") + "     " + tr("[<] [>] TROCAR DE ABA")
	_tooltip.visible = false
	_mostrar_aba(Aba.ITENS)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("abrir_inventario"):
		# **So durante a run.** No menu e no Lobby nao ha build para consultar, e
		# uma tela que abre sobre o menu inicial pausaria uma arvore que ninguem
		# despausaria.
		if not _aberta and GameState.estado != GameState.Estado.JOGANDO:
			return
		get_viewport().set_input_as_handled()
		if _aberta:
			fechar()
		else:
			abrir()
		return

	if not _aberta:
		return
	if evento.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_mostrar_aba((_aba + 1) % _abas.size())
	elif evento.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_mostrar_aba((_aba - 1 + _abas.size()) % _abas.size())
	elif evento.is_action_pressed("pausar"):
		# ESC fecha o inventario em vez de abrir a pausa por baixo dele. Sem
		# isto o jogador sai com dois menus empilhados e o de baixo invisivel.
		get_viewport().set_input_as_handled()
		fechar()


func abrir() -> void:
	if _aberta:
		return
	_aberta = true
	visible = true

	# LE os sistemas reais no instante em que abre. Guardar uma copia dos
	# implantes ou dos slots aqui criaria a segunda fonte de verdade que este
	# epico existe para nao criar.
	_itens.recolher()
	var jogador := get_tree().get_first_node_in_group("player")
	if jogador != null and jogador.has_method("inventario"):
		_armamento.inventario = jogador.inventario()
		_status.vida = Vector2i(jogador.vida, jogador.vida_maxima)
	else:
		_armamento.inventario = null
		_status.vida = Vector2i.ZERO
	_armamento.queue_redraw()
	_status.queue_redraw()
	_tooltip.visible = false
	_mostrar_aba(_aba)

	if not get_tree().paused:
		get_tree().paused = true
		_pausou = true


func fechar() -> void:
	if not _aberta:
		return
	_aberta = false
	visible = false
	if _pausou:
		get_tree().paused = false
		_pausou = false


## Troca de aba. Publica porque a regua visual fotografa as tres.
func mostrar_aba(indice: int) -> void:
	_mostrar_aba(indice)


func _mostrar_aba(indice: int) -> void:
	_aba = clampi(indice, 0, _abas.size() - 1)
	for i in _abas.size():
		_abas[i].visible = i == _aba
		# O botao da aba em vigor fica APAGADO, e nao aceso: ele e o unico que
		# nao leva a lugar nenhum. Acender o atual e apagar os outros diz o
		# contrario -- que os apagados e que estao indisponiveis.
		_botoes[i].disabled = i == _aba
	# O tooltip pertence a aba de itens. Deixado visivel ao trocar, ele
	# descreveria um implante que nao esta mais na tela.
	_tooltip.visible = false


func _ao_apontar(dados: DadosItem) -> void:
	if dados == null or _aba != Aba.ITENS:
		_tooltip.visible = false
		return
	# O `.tres` guarda o portugues, que e a CHAVE. A tela pode estar em ingles.
	_tooltip_nome.text = tr(dados.nome)
	_tooltip_nome.modulate = dados.cor
	_tooltip_texto.text = tr(dados.descricao)
	_tooltip.visible = true
