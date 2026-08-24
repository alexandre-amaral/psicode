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
	_versao_do_projeto()


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
	for chave in ["salas_limpas", "total_salas", "inimigos_mortos", "creditos", "tempo", "deterioracao_final"]:
		ok(e.has(chave), "estatisticas tem a chave '%s'" % chave)
	perto(e["deterioracao_final"], Deterioracao.valor, "deterioracao_final reflete o valor atual")


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
