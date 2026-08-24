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

var tela_cheia: bool = false
var shake: bool = true
var glitch: bool = true

## Onde gravar. Existe para a suite de teste nao sujar a config real de quem
## roda o runner na propria maquina.
var _caminho: String = CAMINHO


func _ready() -> void:
	carregar()
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


func salvar() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECAO_VIDEO, "tela_cheia", tela_cheia)
	cfg.set_value(SECAO_ACESSIBILIDADE, "shake", shake)
	cfg.set_value(SECAO_ACESSIBILIDADE, "glitch", glitch)
	var erro := cfg.save(_caminho)
	if erro != OK:
		push_warning("Configuracao: nao consegui gravar em '%s' (erro %d)." % [_caminho, erro])


## Empurra as preferencias para quem as executa, e avisa o resto.
##
## Nao e chamado no boot -- ver o comentario em _ready. Serve para reaplicar
## tudo de uma vez quando algo externo mexer na configuracao.
func aplicar() -> void:
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


func definir_shake(valor: bool) -> void:
	shake = valor
	# So o shake. O hitstop e o peso do tiro, nao movimento de camera -- quem
	# tem sensibilidade a movimento quer matar um sem perder o outro.
	Juice.shake_habilitado = valor
	salvar()
	EventBus.configuracao_mudou.emit()


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
