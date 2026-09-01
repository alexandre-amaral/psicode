extends Node
## A CAMADA DE AUDIO do jogo: buses, volume e quem toca o que.
##
## O projeto passou a existencia inteira sem som -- nao havia bus, nao havia
## autoload, e `Configuracao` guardava preferencia de video e acessibilidade mas
## nenhuma de volume. Este arquivo e a metade de INFRAESTRUTURA da AND1 08, e ela
## vem antes do conteudo de proposito: som solto tocado por `AudioStreamPlayer`
## espalhado pelas cenas nao tem como ser desligado, nem misturado, nem
## lembrado entre sessoes.
##
## TRES BUSES, e a divisao nao e arbitraria -- ela e a que o jogador precisa
## para consertar o proprio incomodo sem desligar o jogo inteiro:
##
##   MASTER    o mestre, e o unico que silencia tudo.
##   SFX       tiro, impacto, morte. O que RESPONDE a uma acao dele.
##   AMBIENTE  ventilador, motor distante, zumbido eletrico. O que esta la o
##             tempo todo. E o primeiro que alguem quer baixar sem perder a
##             leitura do combate, e por isso ele nao pode dividir bus com o SFX.
##
## A ARMADILHA DO AUTOLOAD, que este arquivo cai em cheio: **autoload nao
## enxerga quem vem depois dele.** `Configuracao` e registrado ANTES daqui, e por
## isso quem PUXA a preferencia e este `_ready`, e nao o `aplicar()` dela. E o
## mesmo contrato que o `Juice` ja segue, e o `EventBus.configuracao_mudou`
## cobre as mudancas em runtime.

## Os buses, na ordem em que existem no `default_bus_layout.tres`.
const BUS_MASTER := &"Master"
const BUS_SFX := &"SFX"
const BUS_AMBIENTE := &"Ambiente"

## Quantos sons podem tocar ao mesmo tempo no bus de SFX.
##
## Nao e economia de CPU: e leitura. Vinte impactos simultaneos viram um estouro
## branco em que nenhum acerto individual se ouve -- o mesmo problema que o
## `alpha_maximo` do glitch resolve na tela, e que `max_props_animados` resolve
## no movimento. Som que nao cabe no teto e descartado, e nao enfileirado:
## enfileirar atrasaria o feedback do tiro que o jogador acabou de dar.
const VOZES_SFX := 12

## Abaixo disto o bus e SILENCIADO em vez de ficar em -60 dB.
##
## Volume zero num slider tem de significar zero. `linear_to_db(0)` devolve -inf,
## que o Godot aceita, mas 0,001 devolveria -60 dB -- audivel num fone. Mutar e
## o unico jeito de "desligado" querer dizer desligado.
const SILENCIO := 0.001

var _vozes: Array[AudioStreamPlayer] = []
var _proxima_voz: int = 0
var _ambiente: AudioStreamPlayer = null


func _ready() -> void:
	# PUXA a preferencia, e nao espera ser empurrado. Ver a armadilha no
	# cabecalho: quando o `_ready` da Configuracao rodou, este no nao existia.
	aplicar_volumes()
	EventBus.configuracao_mudou.connect(aplicar_volumes)


## As vozes de SFX sao criadas UMA vez e reusadas em rodizio.
##
## Criar um `AudioStreamPlayer` por tiro e liberar depois deixa o coletor
## trabalhando no meio do combate, que e justamente quando nao se quer isso. O
## rodizio tambem e o que faz o teto de vozes existir de graca: a voz mais antiga
## e reaproveitada, entao o som novo interrompe o mais velho em vez de somar.
##
## PREGUICOSO de proposito: elas nascem no primeiro som e nao no `_ready`. Um
## autoload e o ultimo no a morrer, e treze players nascendo em toda execucao --
## inclusive nas headless, que nunca tocam nada -- so acrescentavam ruido no
## desligamento. Quem nao toca som nao paga por eles.
func _montar_vozes() -> void:
	if not _vozes.is_empty():
		return
	for i in VOZES_SFX:
		var voz := AudioStreamPlayer.new()
		voz.bus = String(BUS_SFX)
		add_child(voz)
		_vozes.append(voz)


## Le os tres volumes da `Configuracao` e escreve no servidor de audio.
##
## Chamado no `_ready` e a cada `configuracao_mudou`. O parametro existe porque o
## sinal manda um, e ignora-lo aqui e de proposito: qualquer mudanca de
## configuracao reaplica os tres, o que e barato e nao tem como dessincronizar.
func aplicar_volumes(_qualquer: Variant = null) -> void:
	_aplicar(BUS_MASTER, Configuracao.volume_master)
	_aplicar(BUS_SFX, Configuracao.volume_sfx)
	_aplicar(BUS_AMBIENTE, Configuracao.volume_ambiente)


func _aplicar(bus: StringName, volume: float) -> void:
	var indice := AudioServer.get_bus_index(String(bus))
	if indice < 0:
		return
	AudioServer.set_bus_mute(indice, volume <= SILENCIO)
	AudioServer.set_bus_volume_db(indice, linear_to_db(maxf(volume, SILENCIO)))


## Toca um som de acao. Devolve `false` se nao havia som para tocar.
##
## `tom` desafina o som em semitons: o mesmo impacto tocado tres vezes seguidas
## na mesma altura le como um loop travado, e nao como tres acertos.
func tocar(fluxo: AudioStream, tom: float = 0.0, volume_db: float = 0.0) -> bool:
	if fluxo == null:
		return false
	_montar_vozes()
	var voz := _vozes[_proxima_voz]
	_proxima_voz = (_proxima_voz + 1) % _vozes.size()
	voz.stream = fluxo
	voz.pitch_scale = pow(2.0, tom / 12.0)
	voz.volume_db = volume_db
	voz.play()
	return true


## Troca o ambiente que toca em loop. Passar `null` silencia.
##
## Ele e UM so: dois ambientes ao mesmo tempo viram ruido sem lugar, e o que o
## ambiente faz e dizer ONDE o jogador esta. Trocar de andar troca o som; trocar
## de sala, nao.
func definir_ambiente(fluxo: AudioStream) -> void:
	if _ambiente == null:
		if fluxo == null:
			return
		_ambiente = AudioStreamPlayer.new()
		_ambiente.bus = String(BUS_AMBIENTE)
		add_child(_ambiente)
	if _ambiente.stream == fluxo and _ambiente.playing:
		return
	if fluxo == null:
		_ambiente.stream = null
		_ambiente.stop()
		return
	# O LOOP e forcado AQUI, e nao herdado do arquivo.
	#
	# `save_to_wav` grava um RIFF simples, sem o bloco `smpl` de onde o
	# importador do Godot leria a marca de loop -- entao o `.wav` chega com loop
	# DESLIGADO por mais que o gerador tenha pedido. O sintoma seria o setor
	# ficando mudo depois de seis segundos, sem uma linha no console.
	#
	# Forcar no momento de tocar tambem e mais honesto: ambiente que nao repete
	# nao e ambiente, entao isto e uma propriedade de COMO se toca e nao do
	# arquivo.
	var wav := fluxo as AudioStreamWAV
	if wav != null and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / 2
	_ambiente.stream = fluxo
	_ambiente.play()


## Cala TUDO: o ambiente e as vozes.
##
## Existe porque `definir_ambiente()` nao tinha par, e o defeito que isso
## produzia era permanente. Os `AudioStreamPlayer` moram NESTE autoload, e nao na
## cena: `change_scene_to_file()` libera o `GerenciadorMapa` mas o player
## sobrevive com o `stream` tocando -- e com o loop LIGADO, que e justamente o
## que `definir_ambiente()` forca. O som do setor seguia em laco por cima do menu
## inicial, para sempre.
##
## O `stream` e zerado junto, e nao so parado: um player parado com stream ainda
## responde `ambiente_tocando()` de um jeito ambiguo, e o proximo andar atribui
## um stream novo de qualquer forma.
func silenciar() -> void:
	if _ambiente != null:
		_ambiente.stop()
		_ambiente.stream = null
	for voz in _vozes:
		if is_instance_valid(voz):
			voz.stop()


func ambiente_tocando() -> bool:
	return _ambiente != null and _ambiente.playing


## Larga os fluxos ao sair, e LIBERA os players.
##
## Um autoload e o ultimo no a morrer, e quem ja tocou alguma coisa segura um
## `AudioStreamPlaybackWAV` mais o proprio `AudioStreamWAV`. Se os players
## morrerem depois da varredura de objetos do Godot, isso vira
## "6 ObjectDB instances were leaked" e "2 resources still in use at exit" em
## TODA execucao headless.
##
## Nao quebra nada -- o codigo de saida continua zero --, mas polui a saida de
## todo teste, e saida poluida e onde um aviso de VERDADE se esconde. Zerar o
## `stream` nao basta: e a instancia do player que segura o playback, entao ela
## tem de ser liberada aqui, na mao.
func _exit_tree() -> void:
	for voz in _vozes:
		_desligar(voz)
	_vozes.clear()
	_desligar(_ambiente)
	_ambiente = null


func _desligar(voz: AudioStreamPlayer) -> void:
	if voz == null or not is_instance_valid(voz):
		return
	voz.stop()
	voz.stream = null
	if voz.get_parent() == self:
		remove_child(voz)
	voz.free()
