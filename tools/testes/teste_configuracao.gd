extends TesteBase
## Verifica que a preferencia do jogador sobrevive a fechar o jogo.
##
## Este e o primeiro `user://` do projeto -- antes dele nada aqui persistia nada.
## Por isso a assercao central e o ROUND-TRIP: gravar, esquecer o que esta em
## memoria, reler do disco e conferir. Verificar so que `salvar()` nao deu erro
## provaria unicamente que a funcao existe.
##
## A suite grava num caminho proprio e o apaga no fim: rodar o runner nao pode
## sujar a configuracao real de quem esta desenvolvendo.

const CAMINHO_TESTE := "user://config_teste.cfg"


func nome() -> String:
	return "Configuracao"


func executar() -> void:
	var original := Configuracao._caminho
	Configuracao._caminho = CAMINHO_TESTE
	_limpar()

	_defaults()
	_round_trip()
	_fator_glitch()
	_shake_nao_mexe_no_hitstop()

	_limpar()
	Configuracao._caminho = original
	# Devolve o autoload ao estado do disco real, para nao contaminar quem rodar
	# depois nem uma cena de jogo apontada para este runner.
	Configuracao.carregar()


func _limpar() -> void:
	if FileAccess.file_exists(CAMINHO_TESTE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CAMINHO_TESTE))


## Sem arquivo, valem os defaults -- e o estado de quem abre o jogo pela
## primeira vez. Janela (nao tela cheia) e os dois efeitos ligados.
func _defaults() -> void:
	Configuracao.tela_cheia = true
	Configuracao.shake = false
	Configuracao.glitch = false

	# carregar() com arquivo ausente nao pode zerar nem inventar: ele mantem o
	# que estava, e quem define o default e a declaracao da variavel.
	Configuracao.tela_cheia = false
	Configuracao.shake = true
	Configuracao.glitch = true
	Configuracao.carregar()

	ok(not Configuracao.tela_cheia, "sem arquivo, o jogo abre em janela")
	ok(Configuracao.shake, "sem arquivo, o tremor de camera vem ligado")
	ok(Configuracao.glitch, "sem arquivo, a distorcao vem ligada")


## A assercao que importa: o que foi gravado volta do DISCO, nao da memoria.
func _round_trip() -> void:
	Configuracao.tela_cheia = true
	Configuracao.shake = false
	Configuracao.glitch = false
	Configuracao.salvar()

	# Esquece tudo. Se carregar() nao ler mesmo do arquivo, estes valores e que
	# vao sobrar, e as tres verificacoes abaixo falham.
	Configuracao.tela_cheia = false
	Configuracao.shake = true
	Configuracao.glitch = true

	Configuracao.carregar()
	ok(Configuracao.tela_cheia, "tela cheia sobreviveu ao disco")
	ok(not Configuracao.shake, "tremor desligado sobreviveu ao disco")
	ok(not Configuracao.glitch, "distorcao desligada sobreviveu ao disco")

	ok(FileAccess.file_exists(CAMINHO_TESTE), "o arquivo de configuracao foi criado")


func _fator_glitch() -> void:
	Configuracao.glitch = true
	perto(Configuracao.fator_glitch(), 1.0, "glitch ligado nao altera a intensidade")
	Configuracao.glitch = false
	perto(Configuracao.fator_glitch(), 0.0, "glitch desligado zera a intensidade")


## A separacao que a tela de opcoes introduziu: `Juice` tinha UMA flag para os
## dois efeitos, e desligar o tremor levava junto o hitstop -- que e o peso do
## tiro, nao movimento de camera.
func _shake_nao_mexe_no_hitstop() -> void:
	Juice.shake_habilitado = true
	Juice.hitstop_habilitado = true

	Configuracao.definir_shake(false)
	ok(not Juice.shake_habilitado, "desligar a opcao desliga o tremor no Juice")
	ok(Juice.hitstop_habilitado, "o hitstop NAO e desligado junto com o tremor")

	Configuracao.definir_shake(true)
	ok(Juice.shake_habilitado, "religar a opcao devolve o tremor")
