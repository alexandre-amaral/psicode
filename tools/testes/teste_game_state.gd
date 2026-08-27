extends TesteBase
## GameState guarda o estado da run. E dado que qualquer um edita sem
## programar, entao o que se verifica aqui e consistencia -- nao gameplay.
##
## Havia aqui uma checagem da curva das ondas .tres. Ela saiu com o proprio
## sistema de ondas: a curva de dificuldade passou a ser a composicao por sala,
## e quem a verifica agora e teste_composicao.gd.


func nome() -> String:
	return "GameState"


func executar() -> void:
	_formatar_tempo()
	_estatisticas()
	_cronometro_do_chefe()
	_versao_do_projeto()
	_o_pedido_de_selecao_e_de_mao_unica()


## O botao RECOMECAR da tela de fim pede ao menu que abra a selecao de operador
## direto, por uma bandeira no autoload -- a selecao e um PAINEL do menu, e nao
## uma cena, entao nao ha para onde trocar.
##
## O que este caso guarda e o CONSUMO. Uma bandeira que nao se apaga reabre a
## selecao toda vez que o jogador voltar ao menu, prendendo-o num painel que ele
## acabou de fechar. Nada nisso gera erro: o menu esta funcionando, a selecao
## esta funcionando, e o jogo so fica impossivel de sair.
##
## E por isso que ler e apagar moram na MESMA funcao: um `if
## GameState.abrir_selecao_ao_entrar` cru compila igual e esquece de apagar.
func _o_pedido_de_selecao_e_de_mao_unica() -> void:
	GameState.abrir_selecao_ao_entrar = false
	ok(not GameState.consumir_pedido_de_selecao(), "sem pedido, o menu abre normal")

	GameState.abrir_selecao_ao_entrar = true
	ok(GameState.consumir_pedido_de_selecao(), "com pedido, o menu abre a selecao")
	ok(
		not GameState.consumir_pedido_de_selecao(),
		"e o pedido nao sobrevive a propria leitura"
	)
	ok(
		not GameState.abrir_selecao_ao_entrar,
		"a bandeira fica apagada no autoload, e nao so no valor devolvido"
	)


## Usado na tela de fim. Erro aqui aparece para o jogador na ultima tela que ele
## ve na run.
func _formatar_tempo() -> void:
	igual(GameState.formatar_tempo(0.0), "00:00", "zero segundos")
	igual(GameState.formatar_tempo(9.0), "00:09", "segundos tem zero a esquerda")
	igual(GameState.formatar_tempo(59.0), "00:59", "ultimo segundo antes do minuto")
	igual(GameState.formatar_tempo(60.0), "01:00", "vira o minuto certo")
	igual(GameState.formatar_tempo(125.0), "02:05", "minutos e segundos juntos")
	igual(GameState.formatar_tempo(599.0), "09:59", "quase dez minutos")
	igual(GameState.formatar_tempo(3600.0), "60:00", "uma hora conta como 60 minutos")
	# Fracao de segundo trunca, nao arredonda para cima -- senao o cronometro
	# mostraria 00:01 antes de um segundo ter passado.
	igual(GameState.formatar_tempo(1.9), "00:01", "fracao de segundo e truncada")


func _estatisticas() -> void:
	var e := GameState.estatisticas()
	for chave in [
		"salas_limpas", "total_salas", "inimigos_mortos", "creditos", "tempo",
		"tempo_chefe", "deterioracao_final",
	]:
		ok(e.has(chave), "estatisticas tem a chave '%s'" % chave)
	perto(e["deterioracao_final"], Deterioracao.valor, "deterioracao_final reflete o valor atual")


## O cronometro da luta do chefe.
##
## Ele existe para uma pergunta do playtest -- "quanto a luta pareceu durar, e
## quanto durou de verdade?" -- entao o que importa e que o numero seja HONESTO,
## nao que exista. Duas formas de ele mentir, e as duas estao cercadas aqui:
## contar tempo sem nunca ter havido chefe, e continuar contando depois que a
## luta acabou.
##
## A ponta viva fica com o teste de fumaca, que derruba a Diretora em toda run.
func _cronometro_do_chefe() -> void:
	var tempo_original := GameState.tempo_run
	var chefe_original := GameState._chefe_comecou
	var medido_original := GameState.tempo_chefe

	# Sem chefe revelado, nao ha o que cronometrar.
	GameState.tempo_chefe = 0.0
	GameState._chefe_comecou = -1.0
	GameState.tempo_run = 120.0
	GameState._fechar_cronometro_do_chefe()
	perto(GameState.tempo_chefe, 0.0, "sem chefe revelado, a luta marca zero")

	# Com chefe: conta do instante da revelacao ate agora.
	GameState._chefe_comecou = 100.0
	GameState.tempo_run = 175.0
	GameState._fechar_cronometro_do_chefe()
	perto(GameState.tempo_chefe, 75.0, "a luta conta da revelacao ate o fim")

	# Idempotente. A morte da Diretora fecha o cronometro, e `terminar_run`
	# chama de novo logo em seguida -- sem a trava, o segundo esticaria a luta
	# ate o instante em que a tela de fim aparece.
	GameState.tempo_run = 400.0
	GameState._fechar_cronometro_do_chefe()
	perto(GameState.tempo_chefe, 75.0, "fechar de novo nao estica a luta")

	GameState.tempo_run = tempo_original
	GameState._chefe_comecou = chefe_original
	GameState.tempo_chefe = medido_original


## O menu inicial mostra a versao lendo daqui. Ja aconteceu de a cena trazer
## "v1.0.3" escrito na mao enquanto a build era 0.1.0-alpha -- o testador le a
## build como final e reporta bug achando que e versao lancada. Estas
## verificacoes existem para que a versao nunca volte a ser invisivel ou
## invalida.
func _versao_do_projeto() -> void:
	var versao: String = str(ProjectSettings.get_setting("application/config/version", ""))
	ok(not versao.is_empty(), "project.godot declara config/version")
	if versao.is_empty():
		return

	# A tag de release e "v" + esta string. Um espaco aqui gera uma tag
	# invalida e o workflow de release quebra so na hora de publicar.
	igual(versao.strip_edges(), versao, "a versao nao tem espaco sobrando")
	ok(not versao.begins_with("v"), "a versao nao repete o 'v' (quem poe e a tag e o menu)")

	# Formato x.y.z, com sufixo opcional (-alpha, -beta, -rc1).
	var re := RegEx.new()
	re.compile("^\\d+\\.\\d+\\.\\d+(-[0-9A-Za-z.]+)?$")
	ok(re.search(versao) != null, "a versao segue x.y.z[-sufixo] (obtive '%s')" % versao)
