extends TesteBase
## A CAMADA DE AUDIO: buses, volume e preferencia (AND1 08).
##
## O projeto passou a existencia inteira sem som. Esta suite cobra a
## infraestrutura, e nao o timbre: o que da para quebrar em silencio aqui e o
## volume que nao sobrevive ao reinicio, o bus que nao existe e o "desligado" que
## na verdade toca a -60 dB.
##
## A armadilha do projeto que este dominio cai em cheio: **autoload nao enxerga
## quem vem depois dele.** `Configuracao` e registrado ANTES do `Audio`, entao
## quem PUXA a preferencia e o `_ready` do Audio, e nao o `aplicar()` dela --
## mesmo contrato que o `Juice` ja segue.

const SONS := [
	"ambiente_setor", "valvula", "estalo", "faisca",
	"motor_falhando", "motor_firme", "motor_alem",
]


func nome() -> String:
	return "Audio"


func executar() -> void:
	_os_tres_buses_existem()
	_o_volume_sobrevive_ao_reinicio()
	_desligado_quer_dizer_desligado()
	_os_sons_do_andar_existem_e_tocam_no_web()
	_o_audio_puxa_a_preferencia_em_vez_de_esperar()
	_o_padrao_deixa_espaco_para_um_frame_cheio()
	_o_ambiente_tem_par_para_desligar()


## Os tres buses, e a divisao entre eles.
##
## SFX e AMBIENTE separados nao e capricho: o ambiente e o primeiro que alguem
## quer baixar sem perder a leitura do combate, e num bus so isso seria
## impossivel sem desligar o feedback do proprio tiro.
func _os_tres_buses_existem() -> void:
	for bus in [Audio.BUS_MASTER, Audio.BUS_SFX, Audio.BUS_AMBIENTE]:
		ok(AudioServer.get_bus_index(String(bus)) >= 0, "o bus %s existe" % bus)

	var sfx := AudioServer.get_bus_index(String(Audio.BUS_SFX))
	var ambiente := AudioServer.get_bus_index(String(Audio.BUS_AMBIENTE))
	ok(sfx != ambiente, "SFX e AMBIENTE sao buses diferentes")
	igual(AudioServer.get_bus_send(sfx), StringName("Master"), "SFX manda para o Master")
	igual(AudioServer.get_bus_send(ambiente), StringName("Master"), "AMBIENTE tambem")

	# O teto de vozes existe: vinte impactos simultaneos viram um estouro branco
	# em que nenhum acerto individual se ouve.
	ok(Audio.VOZES_SFX > 0 and Audio.VOZES_SFX <= 24,
		"ha teto de vozes de SFX (%d) -- som demais e ruido, nao feedback" % Audio.VOZES_SFX)


## O volume sobrevive ao reinicio.
##
## Grava num arquivo de teste e le de volta pelo caminho de VERDADE: um teste que
## so escreve e le a variavel em memoria provaria que a atribuicao funciona, que
## nao e o que pode quebrar.
func _o_volume_sobrevive_ao_reinicio() -> void:
	var guardado := [
		Configuracao.volume_master, Configuracao.volume_sfx, Configuracao.volume_ambiente,
	]
	var caminho_original: String = Configuracao._caminho
	Configuracao._caminho = "user://teste_audio.cfg"

	Configuracao.volume_master = 0.42
	Configuracao.volume_sfx = 0.13
	Configuracao.volume_ambiente = 0.66
	Configuracao.salvar()

	Configuracao.volume_master = 1.0
	Configuracao.volume_sfx = 1.0
	Configuracao.volume_ambiente = 1.0
	Configuracao.carregar()

	perto(Configuracao.volume_master, 0.42, "o volume geral volta do disco")
	perto(Configuracao.volume_sfx, 0.13, "o de efeitos tambem")
	perto(Configuracao.volume_ambiente, 0.66, "e o de ambiente tambem")

	# Arquivo de config e editavel a mao: um valor fora da faixa nao pode estourar
	# o audio no boot, antes de o jogador ter chance de chegar nas opcoes.
	var cfg := ConfigFile.new()
	cfg.set_value(Configuracao.SECAO_AUDIO, "master", 40.0)
	cfg.save(Configuracao._caminho)
	Configuracao.carregar()
	entre(Configuracao.volume_master, 0.0, 1.0,
		"volume absurdo gravado a mao e preso na faixa, e nao estoura no boot")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Configuracao._caminho))
	Configuracao._caminho = caminho_original
	Configuracao.volume_master = guardado[0]
	Configuracao.volume_sfx = guardado[1]
	Configuracao.volume_ambiente = guardado[2]
	Configuracao.salvar()


## Zero no slider tem de ser ZERO.
##
## `linear_to_db(0)` devolve -inf, mas 0,001 devolveria -60 dB -- audivel num
## fone. Um "desligado" que ainda se ouve e pior que nao ter a opcao: o jogador
## acha que o jogo esta quebrado.
## Quantos sons cabem num frame de combate movimentado.
##
## Quatro: tiro, impacto, morte e porta e o pior caso comum. Nao e o teto de
## vozes (12) porque doze simultaneos nao acontece -- projetar o padrao para
## eles deixaria o jogo inaudivel no caso normal.
const SONS_JUNTOS := 4

## Onde todo som deste jogo nasce, em dBFS.
##
## Nao e um numero escolhido aqui: `gerar_sons.gd` normaliza toda amostra com
## `ganho = 0.707 / pico`, de proposito, para mexer numa formula nao mudar o
## volume. 0,707 e -3 dBFS.
const PICO_DA_FONTE_DB := -3.0


## O padrao de volume deixa espaco para um frame cheio sem clipar.
##
## O defeito que este caso fecha: o slider e LINEAR e passa por `linear_to_db()`,
## entao 0,8 nao quer dizer 80% -- da -1,94 dB, que e 97% do fundo de escala. O
## padrao antigo (0,8 / 0,8) parecia moderado no menu e entregava o maximo, e com
## a fonte ja em -3 dBFS bastavam DOIS sons no mesmo frame para estourar.
##
## O limite deriva do fundo de escala e nao da amostra: som somado nao pode
## passar de 0 dBFS, porque acima disso o driver corta a onda.
func _o_padrao_deixa_espaco_para_um_frame_cheio() -> void:
	# Instanciado do SCRIPT, e nao lido do autoload: o autoload ja carregou
	# `user://config.cfg` e responde com a preferencia de quem joga nesta
	# maquina. O que este caso afirma e o PADRAO, que e o que chega a quem nunca
	# abriu o menu de opcoes.
	var script := load("res://src/autoload/configuracao.gd") as GDScript
	var cfg: Node = script.new()

	var master := linear_to_db(cfg.volume_master)
	var sfx := linear_to_db(cfg.volume_sfx)
	var ambiente := linear_to_db(cfg.volume_ambiente)

	var um_som := PICO_DA_FONTE_DB + master + sfx
	# Somar N fontes coerentes e +20*log10(N) dB. E o pior caso, e e o que se
	# quer barrar.
	var cheio := um_som + 20.0 * (log(float(SONS_JUNTOS)) / log(10.0))

	ok(
		cheio < 0.0,
		"%d sons juntos no padrao ficam em %.1f dBFS, abaixo do teto (um som sozinho: %.1f)"
			% [SONS_JUNTOS, cheio, um_som]
	)
	# E o ambiente e uma CAMA: ele fica abaixo da acao, senao a musica compete
	# com o feedback que o jogador precisa ouvir para reagir.
	ok(
		PICO_DA_FONTE_DB + master + ambiente < um_som,
		"o ambiente (%.1f dBFS) nasce abaixo de um SFX (%.1f dBFS)"
			% [PICO_DA_FONTE_DB + master + ambiente, um_som]
	)
	cfg.free()


## `definir_ambiente()` tem par, e o par desliga de verdade.
##
## Sem isto o som do setor sobrevivia a run inteira: os players moram no
## AUTOLOAD, nao na cena, entao `change_scene_to_file()` liberava o
## `GerenciadorMapa` e o ambiente seguia em laco por cima do menu inicial, para
## sempre. E o loop e forcado por `definir_ambiente()`, que e justamente o que
## garante que ele nao pare sozinho.
func _o_ambiente_tem_par_para_desligar() -> void:
	var fluxo := load("res://assets/audio/ambiente_setor.wav") as AudioStream
	if fluxo == null:
		ok(false, "o ambiente do setor existe em disco")
		return

	Audio.definir_ambiente(fluxo)
	ok(Audio.ambiente_tocando(), "definir_ambiente poe o setor no ar")

	Audio.silenciar()
	ok(not Audio.ambiente_tocando(), "silenciar tira o setor do ar")

	# E nao pode ser permanente: reiniciar a run tem de voltar a tocar.
	Audio.definir_ambiente(fluxo)
	ok(Audio.ambiente_tocando(), "e o andar seguinte volta a ligar o ambiente")
	Audio.silenciar()

	# O par mora em quem LIGA, e nao nos botoes de voltar ao menu: espalhar isso
	# pelos call sites e o desenho que ja perdeu o `terminar_run` uma vez.
	var fonte := FileAccess.get_file_as_string("res://src/mapa/gerenciador_mapa.gd")
	ok(
		fonte.contains("func _exit_tree") and fonte.contains("Audio.silenciar()"),
		"quem liga o ambiente desliga, no _exit_tree -- e nao os botoes de saida"
	)


func _desligado_quer_dizer_desligado() -> void:
	var guardado := Configuracao.volume_ambiente
	var indice := AudioServer.get_bus_index(String(Audio.BUS_AMBIENTE))

	Configuracao.volume_ambiente = 0.0
	Audio.aplicar_volumes()
	ok(AudioServer.is_bus_mute(indice), "volume zero MUTA o bus, e nao o deixa em -60 dB")

	Configuracao.volume_ambiente = 0.5
	Audio.aplicar_volumes()
	ok(not AudioServer.is_bus_mute(indice), "e qualquer valor acima de zero volta a tocar")
	var meio := AudioServer.get_bus_volume_db(indice)
	Configuracao.volume_ambiente = 1.0
	Audio.aplicar_volumes()
	ok(AudioServer.get_bus_volume_db(indice) > meio,
		"e subir o slider sobe o bus (%.1f dB contra %.1f)"
			% [AudioServer.get_bus_volume_db(indice), meio])

	Configuracao.volume_ambiente = guardado
	Audio.aplicar_volumes()


## Os sons do andar existem, e no formato que o export WEB toca.
##
## WAV PCM e nao OGG: o import de OGG depende de um decodificador no runtime, e a
## build que vai para o testador e a web. E os que fazem LOOP tem de estar
## marcados -- um ambiente que toca uma vez e para deixa o setor mudo depois de
## seis segundos, sem nada no console.
func _os_sons_do_andar_existem_e_tocam_no_web() -> void:
	for nome_som: String in SONS:
		var caminho := "res://assets/audio/%s.wav" % nome_som
		var fluxo: AudioStream = load(caminho)
		ok(fluxo != null, "%s.wav existe" % nome_som)
		if fluxo == null:
			continue
		var wav := fluxo as AudioStreamWAV
		ok(wav != null, "%s e WAV -- OGG dependeria de decodificador no navegador" % nome_som)
		if wav == null:
			continue
		ok(wav.get_length() > 0.05, "%s tem duracao (%.2f s)" % [nome_som, wav.get_length()])

	# O LOOP do ambiente e garantido por quem TOCA, e nao pelo arquivo.
	#
	# `save_to_wav` grava um RIFF simples, sem o bloco `smpl` de onde o importador
	# leria a marca -- entao cobrar o loop do `.wav` seria cobrar do lugar errado,
	# e o sintoma real e o setor ficando mudo depois de seis segundos.
	var ambiente: AudioStream = load("res://assets/audio/ambiente_setor.wav")
	Audio.definir_ambiente(ambiente)
	var wav_ambiente := ambiente as AudioStreamWAV
	ok(wav_ambiente != null and wav_ambiente.loop_mode != AudioStreamWAV.LOOP_DISABLED,
		"tocar o ambiente LIGA o loop dele -- ambiente que nao repete nao e ambiente")
	ok(Audio.ambiente_tocando(), "e ele fica tocando")

	# O motor do chefe e o contrario: um TOQUE de virada, e nao um loop.
	var motor := load("res://assets/audio/motor_falhando.wav") as AudioStreamWAV
	igual(motor.loop_mode, AudioStreamWAV.LOOP_DISABLED,
		"o motor do chefe NAO faz loop: ele soa uma vez, na virada de fase")

	Audio.definir_ambiente(null)
	ok(not Audio.ambiente_tocando(), "e passar nulo silencia o ambiente")

	# Os tres motores sao a MESMA sintese com um parametro diferente: a luta e
	# "o mesmo, mais rapido", e tres timbres diriam que sao tres maquinas.
	var fonte := FileAccess.get_file_as_string("res://tools/audio/gerar_sons.gd")
	igual(fonte.count("func _motor("), 1,
		"os tres motores saem de UM gerador -- o chefe e uma maquina so, em tres rotacoes")


## O `Audio` PUXA a preferencia, e nao espera ser empurrado.
##
## `Configuracao` e registrado ANTES dele no `project.godot`, entao no `_ready`
## dela este autoload ainda nao existe. Quem vem depois puxa; o
## `EventBus.configuracao_mudou` cobre o runtime. E a mesma armadilha que o
## `Juice` ja documenta, no mesmo lugar.
func _o_audio_puxa_a_preferencia_em_vez_de_esperar() -> void:
	var projeto := FileAccess.get_file_as_string("res://project.godot")
	var i_config := projeto.find("Configuracao=")
	var i_audio := projeto.find("Audio=")
	ok(i_config >= 0 and i_audio >= 0, "os dois autoloads estao registrados")
	ok(i_config < i_audio,
		"e a Configuracao vem ANTES do Audio -- por isso e o Audio que puxa")

	var fonte := FileAccess.get_file_as_string("res://src/autoload/audio.gd")
	ok(fonte.contains("EventBus.configuracao_mudou.connect"),
		"e ele escuta `configuracao_mudou` para as mudancas em runtime")

	# A mudanca em runtime chega de fato: mexer no volume pelo caminho publico
	# reaplica no servidor sem ninguem chamar o Audio na mao.
	var guardado := Configuracao.volume_sfx
	var indice := AudioServer.get_bus_index(String(Audio.BUS_SFX))
	Configuracao.definir_volume(&"sfx", 0.25)
	var baixo := AudioServer.get_bus_volume_db(indice)
	Configuracao.definir_volume(&"sfx", 0.95)
	ok(AudioServer.get_bus_volume_db(indice) > baixo,
		"mexer no volume pelo caminho publico chega ao servidor de audio")
	Configuracao.definir_volume(&"sfx", guardado)
