extends Node
## As preferencias do jogador, salvas em disco.
##
## E o primeiro `user://` do projeto -- antes disto nada aqui persistia nada. Ele
## e deliberadamente pequeno: guarda PREFERENCIA, nao progresso. Save de run e
## meta-progressao sao outro assunto (Fase 5 do roadmap) e nao devem entrar aqui,
## senao a config vira o save e perde a simplicidade de poder ser apagada sem
## consequencia.
##
## Como todo autoload de estado global do projeto, a API sao metodos e nao
## campos publicos: quem muda uma preferencia chama `definir_*`, que aplica e
## grava na mesma hora. Nao existe botao "Aplicar" -- e um passo a mais para o
## jogador errar, e um estado intermediario a mais para o codigo carregar.

const CAMINHO := "user://config.cfg"
const SECAO_VIDEO := "video"
const SECAO_ACESSIBILIDADE := "acessibilidade"
const SECAO_IDIOMA := "idioma"
const SECAO_AUDIO := "audio"

## Os idiomas que o jogo fala, na ordem em que aparecem no seletor.
##
## O rotulo de cada um esta NO PROPRIO idioma e nunca e traduzido: quem abriu as
## opcoes com o jogo numa lingua que nao entende precisa reconhecer a dele na
## lista, e "Portugues" traduzido para portugues nao ajuda ninguem.
const IDIOMAS := [
	{"codigo": "pt_BR", "rotulo": "Português"},
	{"codigo": "en", "rotulo": "English"},
]

var tela_cheia: bool = false
var shake: bool = true
var glitch: bool = true
## Vazio = ninguem escolheu ainda, e vale o idioma do sistema operacional.
## Guardar o vazio, e nao ja resolver para pt_BR na primeira execucao, e o que
## permite o jogo seguir o SO de quem instala em vez de decidir por ele.
var idioma: String = ""

## Os tres volumes, de 0 a 1.
##
## Volume e PREFERENCIA, e por isso cabe aqui do lado de tela cheia e
## acessibilidade -- save de run e meta-progressao sao outro assunto e nao devem
## entrar neste arquivo, senao apagar a config passa a custar caro.
##
## Comecam em 0,8 e nao em 1,0: o topo do slider tem de ser um lugar para onde
## subir. Jogo que nasce no maximo so oferece "abaixar", e quem quer mais alto
## nao tem para onde ir.
var volume_master: float = 0.8
var volume_sfx: float = 0.8
var volume_ambiente: float = 0.7

## Onde gravar. Existe para a suite de teste nao sujar a config real de quem
## roda o runner na propria maquina.
var _caminho: String = CAMINHO


func _ready() -> void:
	carregar()
	# Idioma antes de tudo: sem esta linha o jogo abriria no locale que o Godot
	# adivinhou do SO, ignorando a escolha salva -- e o comportamento mudaria de
	# maquina para maquina, inclusive na do CI.
	_aplicar_idioma()
	# So a janela aqui. `Juice` e um autoload REGISTRADO DEPOIS deste, entao
	# ainda nao existe neste instante -- escrever nele daria erro. Quem vem
	# depois puxa a preferencia no proprio _ready (Juice faz isso), que e o
	# mesmo padrao que a HUD usa para o glitch.
	_aplicar_tela_cheia()


func carregar() -> void:
	var cfg := ConfigFile.new()
	# Arquivo ausente nao e erro: e a primeira vez que o jogo abre.
	if cfg.load(_caminho) != OK:
		return
	tela_cheia = bool(cfg.get_value(SECAO_VIDEO, "tela_cheia", tela_cheia))
	shake = bool(cfg.get_value(SECAO_ACESSIBILIDADE, "shake", shake))
	glitch = bool(cfg.get_value(SECAO_ACESSIBILIDADE, "glitch", glitch))
	idioma = str(cfg.get_value(SECAO_IDIOMA, "codigo", idioma))
	volume_master = _volume(cfg.get_value(SECAO_AUDIO, "master", volume_master))
	volume_sfx = _volume(cfg.get_value(SECAO_AUDIO, "sfx", volume_sfx))
	volume_ambiente = _volume(cfg.get_value(SECAO_AUDIO, "ambiente", volume_ambiente))


func salvar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECAO_VIDEO, "tela_cheia", tela_cheia)
	cfg.set_value(SECAO_ACESSIBILIDADE, "shake", shake)
	cfg.set_value(SECAO_ACESSIBILIDADE, "glitch", glitch)
	cfg.set_value(SECAO_IDIOMA, "codigo", idioma)
	cfg.set_value(SECAO_AUDIO, "master", volume_master)
	cfg.set_value(SECAO_AUDIO, "sfx", volume_sfx)
	cfg.set_value(SECAO_AUDIO, "ambiente", volume_ambiente)
	var erro := cfg.save(_caminho)
	if erro != OK:
		push_warning("Configuracao: nao consegui gravar em '%s' (erro %d)." % [_caminho, erro])


## Empurra as preferencias para quem as executa, e avisa o resto.
##
## Nao e chamado no boot -- ver o comentario em _ready. Serve para reaplicar
## tudo de uma vez quando algo externo mexer na configuracao.
func aplicar() -> void:
	_aplicar_idioma()
	_aplicar_tela_cheia()
	Juice.shake_habilitado = shake
	EventBus.configuracao_mudou.emit()


## `por_gesto` diz se esta chamada nasceu de um clique do jogador.
##
## Importa so no navegador: a Fullscreen API do browser exige ativacao do
## usuario, entao aplicar a preferencia salva durante o boot e recusado em
## silencio. No web a preferencia fica lembrada e vale quando ele clicar no
## toggle; no desktop nao ha essa restricao e o boot aplica normalmente.
func _aplicar_tela_cheia(por_gesto: bool = false) -> void:
	if OS.has_feature("web") and not por_gesto:
		return

	var modo := (
		DisplayServer.WINDOW_MODE_FULLSCREEN if tela_cheia
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if DisplayServer.window_get_mode() != modo:
		DisplayServer.window_set_mode(modo)


## Estado REAL da janela, e nao o booleano guardado.
##
## No navegador o jogador sai do fullscreen com ESC pelo proprio browser, sem
## passar por este autoload -- e ai o booleano ficaria mentindo e o checkbox
## apareceria marcado com o jogo em janela. O itch.io ainda por cima oferece um
## botao de fullscreen proprio, entao ha dois caminhos para o mesmo estado.
func esta_em_tela_cheia() -> bool:
	var modo := DisplayServer.window_get_mode()
	return modo == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or modo == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func definir_tela_cheia(valor: bool) -> void:
	tela_cheia = valor
	# Veio de um clique: no navegador e a unica hora em que o fullscreen e aceito.
	_aplicar_tela_cheia(true)
	salvar()
	EventBus.configuracao_mudou.emit()


## Um volume vindo do disco, preso na faixa.
##
## Arquivo de config e editavel a mao, e um `master = 40` gravado por engano
## estouraria o audio no boot -- antes de o jogador ter qualquer chance de
## chegar na tela de opcoes para consertar.
func _volume(valor: Variant) -> float:
	return clampf(float(valor), 0.0, 1.0)


## Muda um volume e AVISA.
##
## O aviso e `EventBus.configuracao_mudou`, e e por ele que o autoload de audio
## reaplica -- ele nao pode ser chamado direto daqui pelo mesmo motivo que o
## `Juice` nao e: este autoload e registrado ANTES dele, e no `_ready` daqui ele
## ainda nao existe.
func definir_volume(qual: StringName, valor: float) -> void:
	var novo := clampf(valor, 0.0, 1.0)
	match qual:
		&"master": volume_master = novo
		&"sfx": volume_sfx = novo
		&"ambiente": volume_ambiente = novo
		_: return
	EventBus.configuracao_mudou.emit()
	salvar()


func volume_de(qual: StringName) -> float:
	match qual:
		&"master": return volume_master
		&"sfx": return volume_sfx
		&"ambiente": return volume_ambiente
	return 0.0


func definir_shake(valor: bool) -> void:
	shake = valor
	# So o shake. O hitstop e o peso do tiro, nao movimento de camera -- quem
	# tem sensibilidade a movimento quer matar um sem perder o outro.
	Juice.shake_habilitado = valor
	salvar()
	EventBus.configuracao_mudou.emit()


## Idioma em vigor, ja resolvido: nunca devolve vazio.
func idioma_atual() -> String:
	if not idioma.is_empty():
		return idioma
	return _idioma_do_sistema()


func definir_idioma(codigo: String) -> void:
	idioma = codigo
	_aplicar_idioma()
	salvar()
	EventBus.configuracao_mudou.emit()


## Qual idioma da lista mais se parece com o do SO.
##
## Compara so o prefixo: o SO pode dizer "pt_PT", "pt", "en_GB" ou "en_US", e
## nenhum desses casa exatamente com os codigos da lista. Sem prefixo, quem
## estivesse em pt_PT cairia no ingles.
func _idioma_do_sistema() -> String:
	var doSistema := OS.get_locale().to_lower()
	for entrada in IDIOMAS:
		var codigo: String = entrada["codigo"]
		if doSistema.begins_with(codigo.to_lower().substr(0, 2)):
			return codigo
	return String(IDIOMAS[0]["codigo"])


func _aplicar_idioma() -> void:
	TranslationServer.set_locale(idioma_atual())


func definir_glitch(valor: bool) -> void:
	glitch = valor
	salvar()
	EventBus.configuracao_mudou.emit()


## Multiplicador que a HUD aplica na intensidade do shader.
##
## Mexer aqui em vez de no `alpha_maximo` do shader e deliberado: aquele knob e
## um teto de seguranca contra efeito que atrapalha a leitura do combate (esta
## escrito no proprio .gdshader), nao um controle de usuario. `intensidade` ja e
## escrita em runtime pela HUD, entao e o ponto natural.
func fator_glitch() -> float:
	return 1.0 if glitch else 0.0
