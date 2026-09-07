extends Node
## O GERADOR DE SONS do andar 1. Escreve `.wav` em `assets/audio/`.
##
## Procedural, e nao arquivos gravados, pelo mesmo motivo que as texturas do
## projeto sao geradas por `tools/texturas/gerar_texturas.gd`: o time tem tres
## pessoas, duas delas nao programam, e ninguem grava foley. Um som que sai de
## uma FORMULA pode ser ajustado por quem nao tem estudio -- muda-se um numero,
## roda-se de novo --, cabe no repositorio, e nao depende de licenca de
## biblioteca de terceiros.
##
## E ele responde a uma exigencia dura da issue: o export WEB tem de continuar
## funcionando. WAV PCM 16 bits mono e o formato que o Godot toca em qualquer
## lugar sem depender de decodificador do navegador.
##
## O SOM DO ANDAR 1, em cinco peças, e cada uma e uma frase do documento de
## identidade virada sintese:
##
##   ambiente_setor  ventilador + motor distante + zumbido eletrico antigo.
##                   E o loop que responde "onde eu estou" de olhos fechados.
##   valvula         o escape de pressao. Ruido filtrado que abre e fecha.
##   estalo          metal assentando. Transiente curto, sem cauda.
##   faisca          curto, agudo, sujo. O evento mais raro dos tres.
##   motor_falhando  a partida que nao pega. E o som da FASE 1 do chefe: uma
##                   maquina travada tentando girar.
##   motor_firme     a mesma maquina destravada -- fase 2.
##   motor_alem      rotacao acima do limite, com alarme. Fase 3.
##
## Os tres de motor sao a mesma sintese com um parametro diferente, e isso e
## deliberado: a luta inteira do Automato e "o mesmo, mais rapido", e o som tem
## de contar a mesma historia que o ritmo. Tres timbres diferentes diriam que
## sao tres maquinas.
##
## Use:  godot --headless --path . tools/audio/gerar_sons.tscn

const TAXA := 22050
const PASTA := "res://assets/audio/"

## Semente fixa: rodar o gerador duas vezes tem de dar o MESMO arquivo, senao
## todo `--import` sujaria o `git status` e ninguem saberia dizer se algo mudou
## de verdade. Mesma decisao do gerador de texturas.
const SEMENTE := 20260831

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	print("\n=== SONS DO ANDAR 1 ===\n")

	_escrever("ambiente_setor", _ambiente_do_setor(6.0))
	_escrever("valvula", _valvula(0.7))
	_escrever("estalo", _estalo(0.18))
	_escrever("faisca", _faisca(0.12))
	_escrever("motor_falhando", _motor(2.4, 0.55, 0.55, 0.0))
	_escrever("motor_firme", _motor(2.4, 1.0, 0.12, 0.0))
	_escrever("motor_alem", _motor(2.4, 1.45, 0.20, 0.55))

	# A LOJA. Quatro pecas, e as duas de ficha sao o MESMO gerador com um
	# parametro -- mesma razao dos tres de motor: dois timbres diferentes diriam
	# que sao dois recursos, e sao o mesmo em tamanhos diferentes.
	_escrever("ficha_pequena", _ficha(0.14, 1.0))
	_escrever("ficha_grande", _ficha(0.20, 0.72))
	_escrever("compra_ok", _compra(0.34, true))
	_escrever("compra_falha", _compra(0.26, false))
	_escrever("ambiente_loja", _ambiente_da_loja(6.0))

	print("\nok\n")
	get_tree().quit(0)


# ------------------------------------------------------------- as pecas -----

## O loop do setor: ventilador, motor distante e zumbido eletrico.
##
## As tres camadas tem periodos que NAO sao multiplos um do outro, e e o que
## impede o loop de "bater" -- um ambiente com batida audivel vira metronomo, e
## o jogador passa a contar o tempo dele em vez de esquece-lo.
func _ambiente_do_setor(segundos: float) -> PackedFloat32Array:
	var n := int(segundos * TAXA)
	var saida := PackedFloat32Array()
	saida.resize(n)
	var passa_baixa := 0.0
	for i in n:
		var t := float(i) / float(TAXA)
		# Ventilador: ruido passado por um filtro lento, com uma ondulacao de
		# pas por cima.
		passa_baixa = lerpf(passa_baixa, _rng.randf_range(-1.0, 1.0), 0.06)
		var pas := 0.72 + 0.28 * sin(TAU * 7.3 * t)
		var ventilador := passa_baixa * 0.34 * pas
		# Motor distante: fundamental baixa mais a oitava, bem abafada.
		var motor := (sin(TAU * 47.0 * t) * 0.5 + sin(TAU * 94.0 * t) * 0.2) * 0.11
		# Zumbido eletrico antigo: 60 Hz sujo, com a terceira harmonica que da o
		# carater de transformador velho em vez de nota limpa.
		var zumbido := (sin(TAU * 60.0 * t) + sin(TAU * 180.0 * t) * 0.35) * 0.045
		saida[i] = ventilador + motor + zumbido
	return _costurar_loop(saida, int(0.25 * TAXA))


## Escape de pressao: ruido que abre rapido e fecha devagar.
func _valvula(segundos: float) -> PackedFloat32Array:
	var n := int(segundos * TAXA)
	var saida := PackedFloat32Array()
	saida.resize(n)
	var filtro := 0.0
	for i in n:
		var p := float(i) / float(n)
		filtro = lerpf(filtro, _rng.randf_range(-1.0, 1.0), 0.35)
		# Abre em 8% da duracao e fecha no resto: um escape que abre devagar soa
		# como vento, e nao como pressao presa saindo de uma vez.
		var env := (p / 0.08) if p < 0.08 else pow(1.0 - (p - 0.08) / 0.92, 1.8)
		saida[i] = filtro * env * 0.55
	return saida


## Metal assentando: transiente com dois modos de ressonancia e sem cauda.
func _estalo(segundos: float) -> PackedFloat32Array:
	var n := int(segundos * TAXA)
	var saida := PackedFloat32Array()
	saida.resize(n)
	for i in n:
		var t := float(i) / float(TAXA)
		var p := float(i) / float(n)
		var env := pow(1.0 - p, 6.0)
		var corpo := sin(TAU * 320.0 * t) * 0.6 + sin(TAU * 517.0 * t) * 0.4
		var batida := _rng.randf_range(-1.0, 1.0) * pow(1.0 - p, 40.0)
		saida[i] = (corpo * 0.45 + batida * 0.7) * env
	return saida


## Faisca: curta, aguda e suja. Ruido filtrado no alto, com decaimento seco.
func _faisca(segundos: float) -> PackedFloat32Array:
	var n := int(segundos * TAXA)
	var saida := PackedFloat32Array()
	saida.resize(n)
	var anterior := 0.0
	for i in n:
		var p := float(i) / float(n)
		var bruto := _rng.randf_range(-1.0, 1.0)
		# Passa-ALTA de um polo: o que sobra do ruido depois de tirar o grave.
		var alto := bruto - anterior
		anterior = bruto
		saida[i] = alto * pow(1.0 - p, 12.0) * 0.5
	return saida


## A FICHA de credito caindo no bolso: chapa fina batendo em chapa fina.
##
## **Ela nao pode soar como moeda de jogo de plataforma.** O credito do psicode e
## sucata industrial reaproveitada, e um "ding" cristalino diria tesouro -- que e
## a ficcao errada e, pior, a mesma familia sonora que um pickup de vida usaria.
##
## Duas parciais nao harmonicas (razao 1,63) mais um transiente de contato: o
## intervalo dissonante e o que faz metal fino soar como CHAPA e nao como sino.
##
## `altura` desce para a ficha grande -- peca maior, som mais grave. E a mesma
## relacao fisica que o jogador conhece sem pensar, entao ela nao precisa de
## legenda.
func _ficha(segundos: float, altura: float) -> PackedFloat32Array:
	var n := int(segundos * TAXA)
	var saida := PackedFloat32Array()
	saida.resize(n)
	var base := 880.0 * altura
	for i in n:
		var t := float(i) / float(TAXA)
		var p := float(i) / float(n)
		# O decaimento e RAPIDO: ate quatro fichas podem ser coletadas no mesmo
		# segundo, e cauda longa vira um borrao. Mesma disciplina que separa o
		# estalo do ambiente.
		var env := pow(1.0 - p, 9.0)
		var corpo := sin(TAU * base * t) * 0.55 			+ sin(TAU * base * 1.63 * t) * 0.35
		var contato := _rng.randf_range(-1.0, 1.0) * pow(1.0 - p, 45.0)
		saida[i] = (corpo * 0.6 + contato * 0.5) * env
	return saida


## A TRANSACAO: trava mecanica que fecha, ou que recusa.
##
## As duas sao o mesmo gerador porque sao o mesmo GESTO -- a trava do balcao
## girando --, e o que muda e se ela COMPLETA. Dois sons sem relacao fariam a
## recusa parecer um erro do jogo em vez de uma resposta do lugar.
##
## Aceita: duas notas subindo, e a segunda sustenta. Recusa: a mesma primeira
## nota e uma segunda MAIS GRAVE que morre curta -- a trava que gira e volta.
func _compra(segundos: float, aceita: bool) -> PackedFloat32Array:
	var n := int(segundos * TAXA)
	var saida := PackedFloat32Array()
	saida.resize(n)
	var virada := int(float(n) * 0.38)
	for i in n:
		var t := float(i) / float(TAXA)
		var p := float(i) / float(n)
		var segunda := i >= virada
		var altura := 300.0
		if segunda:
			altura = 470.0 if aceita else 210.0
		# A cauda da recusa cai muito mais rapido: a diferenca de DURACAO e o que
		# o jogador le antes de qualquer diferenca de altura.
		var queda := 3.0 if aceita else 9.0
		var env := pow(1.0 - p, queda)
		var corpo := sin(TAU * altura * t) * 0.5 			+ sin(TAU * altura * 2.02 * t) * 0.22
		# O clique da trava, uma vez por nota.
		var borda := absi(i - virada) < 90 or i < 90
		var clique := (_rng.randf_range(-1.0, 1.0) * 0.6) if borda else 0.0
		saida[i] = (corpo * 0.7 + clique * 0.5) * env
	return saida


## O AMBIENTE DA LOJA: a mesma fabrica, com energia funcionando.
##
## Ele e o `ambiente_setor` com uma camada a mais e uma a menos. A fabrica esta
## abandonada; a Loja nao -- entao entra um zumbido de transformador ESTAVEL, que
## e o som de algo ligado de proposito, e sai a irregularidade do motor distante.
##
## **Ele nao pode ser agradavel demais.** Musica de loja diria showroom, e a sala
## inteira existe para dizer o contrario. O que muda em relacao ao setor e ter
## uma nota que se sustenta, e nada mais.
func _ambiente_da_loja(segundos: float) -> PackedFloat32Array:
	var n := int(segundos * TAXA)
	var saida := PackedFloat32Array()
	saida.resize(n)
	var anterior := 0.0
	for i in n:
		var t := float(i) / float(TAXA)
		# Transformador: a nota estavel. 120 Hz mais a terceira harmonica, que e
		# o que da o carater de bobina em vez de tom puro.
		var transformador := sin(TAU * 120.0 * t) * 0.30 			+ sin(TAU * 360.0 * t) * 0.10
		# Ventilacao: ruido passa-baixa, como no setor.
		var bruto := _rng.randf_range(-1.0, 1.0)
		anterior = anterior * 0.96 + bruto * 0.04
		var ar := anterior * 0.55
		# E a lampada de trabalho, com um tremor lento e IRREGULAR: dois periodos
		# que nao sao multiplos, para o loop de 6 s nao denunciar o proprio ciclo.
		var tremor := 1.0 + sin(TAU * 0.31 * t) * 0.05 + sin(TAU * 0.73 * t) * 0.03
		saida[i] = (transformador * tremor + ar) * 0.6
	return _costurar_loop(saida, int(TAXA * 0.25))


## O motor do chefe, nas tres fases.
##
## `giro` e a rotacao relativa (fase 1 abaixo de 1,0, fase 3 acima). `falha` e o
## quanto ele engasga: em zero o giro e continuo, em 0,55 ele PRENDE -- e o que
## faz a fase 1 soar como uma maquina travada tentando girar em vez de uma
## maquina lenta. `alarme` acrescenta o bipe interno da fase 3.
##
## Um so gerador para os tres de proposito: a luta e "o mesmo, mais rapido", e
## tres timbres diferentes diriam que sao tres maquinas.
func _motor(segundos: float, giro: float, falha: float, alarme: float) -> PackedFloat32Array:
	var n := int(segundos * TAXA)
	var saida := PackedFloat32Array()
	saida.resize(n)
	var base := 52.0 * giro
	var passa_baixa := 0.0
	for i in n:
		var t := float(i) / float(TAXA)
		# O engasgo: uma ondulacao lenta que chega a ZERAR o ganho quando `falha`
		# e alto. E a diferenca entre "devagar" e "preso".
		var ciclo := 0.5 + 0.5 * sin(TAU * 2.6 * giro * t)
		var ganho := 1.0 - falha * pow(ciclo, 3.0)
		var corpo := sin(TAU * base * t) * 0.5 + sin(TAU * base * 2.0 * t) * 0.22
		passa_baixa = lerpf(passa_baixa, _rng.randf_range(-1.0, 1.0), 0.12)
		var atrito := passa_baixa * 0.18 * giro
		var bip := 0.0
		if alarme > 0.0:
			# Bipe intermitente: liga metade do tempo, a 2 Hz.
			var liga := 1.0 if fmod(t * 2.0, 1.0) < 0.5 else 0.0
			bip = sin(TAU * 880.0 * t) * 0.12 * alarme * liga
		saida[i] = (corpo + atrito) * ganho * 0.55 + bip
	return _costurar_loop(saida, int(0.12 * TAXA))


# ------------------------------------------------------------ a costura -----

## Faz o fim cruzar com o comeco, para o loop nao estalar.
##
## Sem isto, um loop de ambiente da um clique audivel a cada volta -- e um clique
## periodico e a coisa mais facil de ouvir num som que deveria desaparecer.
func _costurar_loop(dados: PackedFloat32Array, cruzamento: int) -> PackedFloat32Array:
	var n := dados.size()
	if cruzamento <= 0 or cruzamento * 2 >= n:
		return dados
	var saida := PackedFloat32Array(dados)
	for i in cruzamento:
		var peso := float(i) / float(cruzamento)
		var fim := dados[n - cruzamento + i]
		saida[i] = lerpf(fim, dados[i], peso)
	saida.resize(n - cruzamento)
	return saida


# ------------------------------------------------------------- o arquivo ----

## Grava PCM 16 bits mono.
##
## `AudioStreamWAV` e nao OGG porque o import de OGG depende de um decodificador
## no runtime, e a build que vai para o testador e a WEB. WAV curto e barato: os
## sete somam poucas centenas de KB.
func _escrever(nome: String, amostras: PackedFloat32Array) -> void:
	_rng.seed = hash(nome) ^ SEMENTE
	var bytes := PackedByteArray()
	bytes.resize(amostras.size() * 2)
	var pico := 0.0
	for v in amostras:
		pico = maxf(pico, absf(v))
	# Normaliza para -3 dBFS. Sem isto, mexer numa formula muda o volume do som
	# junto, e a mixagem inteira teria de ser refeita a cada ajuste.
	var ganho := (0.707 / pico) if pico > 0.0001 else 1.0
	for i in amostras.size():
		var v := int(clampf(amostras[i] * ganho, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = TAXA
	wav.stereo = false
	wav.data = bytes
	# So o AMBIENTE tem loop. O motor do chefe e um TOQUE de virada -- ele soa
	# uma vez, quando a fase muda, e um motor em loop competiria com o ambiente
	# pelo mesmo lugar na mistura.
	#
	# E a marca aqui e INTENCAO e nao garantia: `save_to_wav` grava um RIFF
	# simples, sem o bloco `smpl` de onde o importador leria o loop. Quem garante
	# e `Audio.definir_ambiente()`, no momento de tocar.
	if nome.begins_with("ambiente"):
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = amostras.size()

	# `save_to_wav` e nao `ResourceSaver.save`: `.wav` e formato de IMPORT e nao
	# de resource, entao o ResourceSaver devolve ERR_FILE_UNRECOGNIZED. O arquivo
	# tem de sair como wav de verdade para o importador do Godot pega-lo -- que
	# e o mesmo caminho de todo asset do projeto.
	var caminho := PASTA + nome + ".wav"
	var erro := wav.save_to_wav(caminho)
	if erro != OK:
		push_error("nao consegui gravar %s (erro %d)" % [caminho, erro])
		return
	print("  %-16s %.2f s, %d KB" % [nome, float(amostras.size()) / TAXA, bytes.size() / 1024])
