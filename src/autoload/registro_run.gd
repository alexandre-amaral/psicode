extends Node
## Quem OLHA a run acontecer e anota, sem que a run saiba disso.
##
## Ele existe para responder uma pergunta de arquitetura antes de ela virar
## problema: **onde ficam as estatisticas?** A resposta preguicosa e "cada um
## incrementa o seu" -- o inimigo conta kill, a arma conta dano, a sala conta
## sala. Isso espalha a persistencia por dez arquivos que nao tem nada a ver com
## ela, e faz cada sistema novo que queira contar alguma coisa precisar conhecer
## o save.
##
## Aqui a conta e feita num lugar so, escutando o `EventBus`. E a regra 1 do
## projeto -- quem faz algo emite, quem se importa escuta -- aplicada a
## progressao. O gameplay continua sem saber que existe um arquivo em disco.
##
## **Ele nao decide nada.** Nao sabe quando a run comeca (quem chama e o
## `GameState`), nao sabe o que fazer com o resultado (quem registra e o
## `Progressao`), e nao troca de cena.

## A run em curso, ou `null` fora de uma.
##
## `null` fora da run e o que faz o Lobby ser barato: os sinais continuam
## chegando e todo `_ao_*` sai na primeira linha. Sem isso, andar pelo Lobby
## contaria salas.
var _run: DadosRun = null

## A vida do jogador no ultimo aviso, para medir o dano RECEBIDO por diferenca.
##
## `player_dano_recebido` entrega a vida atual e a maxima, e nao o quanto doeu --
## ele nasceu para a HUD, que precisa do estado e nao do delta. Guardar o
## anterior aqui e mais barato que mudar a assinatura de um sinal que ja tem
## outros ouvintes.
var _vida_anterior: int = -1


func _ready() -> void:
	EventBus.dano_a_inimigo.connect(_ao_dano_a_inimigo)
	EventBus.inimigo_morreu.connect(_ao_inimigo_morreu)
	EventBus.sala_limpa.connect(_ao_sala_limpa)
	EventBus.item_coletado.connect(_ao_item_coletado)
	EventBus.arma_adquirida.connect(_ao_arma_adquirida)
	EventBus.player_dano_recebido.connect(_ao_player_dano)


## Ha run em curso?
func ativo() -> bool:
	return _run != null


## A run em curso, ou `null`.
func run() -> DadosRun:
	return _run


## Comeca a contar. Chamado por quem inicia a run, nunca pelo Lobby.
func comecar(personagem: String, semente: int) -> DadosRun:
	_run = DadosRun.new()
	_run.personagem = personagem
	_run.seed = semente
	_run.inicio_timestamp = int(Time.get_unix_time_from_system())
	_vida_anterior = -1
	return _run


## Fecha a conta e devolve o que vai para o disco.
##
## `duracao` vem de fora, do `GameState.tempo_run`, porque aquele relogio ja
## desconta pausa e hitstop -- um cronometro proprio aqui contaria o tempo parado
## no menu de pausa, e a duracao no terminal passaria a premiar quem hesita.
##
## Devolve `null` se nao havia run: chamar duas vezes nao pode inventar uma
## segunda derrota no historico.
func terminar(venceu: bool, motivo: String, duracao: float) -> ResultadoRun:
	if _run == null:
		return null
	_run.venceu = venceu
	_run.motivo_fim = motivo
	_run.duracao = duracao
	var resultado := _run.resultado()
	resultado.data = int(Time.get_unix_time_from_system())
	_run = null
	return resultado


## Descarta a run sem registrar nada. Para quem abandona pelo menu.
func descartar() -> void:
	_run = null


func _ao_dano_a_inimigo(quantidade: int) -> void:
	if _run == null:
		return
	_run.dano_causado += maxi(quantidade, 0)


func _ao_inimigo_morreu(_posicao: Vector2, _creditos: int) -> void:
	if _run == null:
		return
	_run.kills += 1


func _ao_sala_limpa(_sala: Node2D) -> void:
	if _run == null:
		return
	_run.salas_concluidas += 1


func _ao_item_coletado(dados: Resource) -> void:
	if _run == null or dados == null:
		return
	_run.itens_coletados.append(str(dados.get("nome")))


func _ao_arma_adquirida(dados: Resource) -> void:
	if _run == null or dados == null:
		return
	_run.armas_coletadas.append(str(dados.get("nome")))


## Dano recebido, medido por DIFERENCA.
##
## O primeiro aviso de uma run so estabelece a base -- ele chega com a vida
## cheia e nao representa dano. Sem o `_vida_anterior < 0`, toda run comecaria
## contando a vida maxima inteira como dano tomado.
func _ao_player_dano(vida_atual: int, _vida_max: int) -> void:
	if _run == null:
		return
	if _vida_anterior >= 0 and vida_atual < _vida_anterior:
		_run.dano_recebido += _vida_anterior - vida_atual
	_vida_anterior = vida_atual
