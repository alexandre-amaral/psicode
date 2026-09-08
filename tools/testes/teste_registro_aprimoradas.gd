extends TesteBase
## Os tres contadores de Unidade Aprimorada da run (#276 -- APR 08).
##
## O que esta suite guarda e uma metrica que falha em SILENCIO. Contador de
## estatistica nao aparece na tela durante o jogo: se ele parar de subir, a run
## roda igual, o combate roda igual, e a unica coisa que muda e o numero no
## terminal de historico -- que ninguem confere contra a partida que acabou de
## acontecer.
##
## E ela guarda em especial a decisao do item 2 da issue: **a morte de uma
## aprimorada nao vem do `EventBus`.** `inimigo_morreu` carrega (posicao,
## creditos) e nao diz quem caiu, entao `RegistroRun` escuta o `morreu` do NO que
## chegou em `aprimorado_nasceu`. Sem portao, a forma mais provavel de isso
## quebrar e alguem "simplificar" para contar toda morte -- e o sintoma seria
## `aprimoradas_mortas` batendo `kills`, que parece certo numa sala de um inimigo
## so.

const CENA_DRONE := "res://src/enemies/drone_aranha.tscn"
const PASTA_CLASSES := "res://src/enemies/aprimoramento/"
const LONGE := Vector2(46000.0, 46000.0)


func nome() -> String:
	return "Registro de Aprimoradas"


func executar() -> void:
	_fora_da_run_nada_e_contado()
	_os_tres_contadores_sobem()
	_so_a_APRIMORADA_conta_como_morta()
	_a_aprimorada_de_outra_run_nao_conta_na_proxima()
	RegistroRun.descartar()


## Fora da run o sinal chega e nao produz nada.
##
## Mesma guarda que ja vale para os outros contadores, e ela precisa valer aqui
## tambem: o `EventBus` e global, o Lobby continua recebendo tudo, e um dia o
## Lobby tera um manequim de treino pendurado numa classe.
func _fora_da_run_nada_e_contado() -> void:
	RegistroRun.descartar()
	var inimigo := _nascer()
	if inimigo == null:
		return
	EventBus.aprimorado_nasceu.emit(inimigo, &"blindada")
	ok(RegistroRun.run() == null, "fora da run, o nascimento nao inventa run nenhuma")
	# E o abate que vem depois tambem nao pode explodir num handler ligado a
	# nada -- fora da run nem chegamos a ligar no `morreu` dele.
	_matar(inimigo)
	ok(RegistroRun.run() == null, "e o abate seguinte tambem nao")


## Os tres contadores sobem, e `classes_vistas` NAO repete.
func _os_tres_contadores_sobem() -> void:
	var run := RegistroRun.comecar("raven", 276)
	igual(run.aprimoradas_encontradas, 0, "a run comeca sem aprimorada nenhuma")
	igual(run.aprimoradas_mortas, 0, "nem morta")
	igual(run.classes_vistas.size(), 0, "nem classe vista")

	# Duas classes em tres nascimentos: a repetida e o caso que separa
	# "quantas apareceram" de "quantas classes DIFERENTES apareceram".
	var a := _nascer_aprimorada(&"regeneradora")
	var b := _nascer_aprimorada(&"blindada")
	var c := _nascer_aprimorada(&"regeneradora")
	if a == null or b == null or c == null:
		return

	igual(run.aprimoradas_encontradas, 3, "os tres nascimentos foram contados")
	igual(run.classes_vistas.size(), 2,
		"mas so DUAS classes distintas entraram na lista")
	ok(run.classes_vistas.has(&"regeneradora"), "a regeneradora esta na lista")
	ok(run.classes_vistas.has(&"blindada"), "a blindada tambem")

	_matar(a)
	igual(run.aprimoradas_mortas, 1, "o primeiro abate conta")
	_matar(b)
	igual(run.aprimoradas_mortas, 2, "e o segundo tambem")
	ok(run.aprimoradas_mortas <= run.aprimoradas_encontradas,
		"e mortas nunca passa de encontradas (%d de %d)" % [
			run.aprimoradas_mortas, run.aprimoradas_encontradas,
		])

	_matar(c)
	igual(run.aprimoradas_mortas, 3, "a terceira fecha a conta")
	RegistroRun.terminar(false, "teste", 1.0)


## O portao MORDE: um inimigo comum que morre nao entra na conta.
##
## Este e o caso que separa o contador certo do atalho. Contar toda morte passa
## em qualquer teste que so mate aprimoradas -- e aqui os DOIS contadores sao
## medidos no mesmo instante: `kills` tem de subir (prova que o abate aconteceu
## de verdade e que o sinal global chegou) enquanto `aprimoradas_mortas` fica
## parado.
func _so_a_APRIMORADA_conta_como_morta() -> void:
	var run := RegistroRun.comecar("raven", 277)
	var aprimorada := _nascer_aprimorada(&"sobrecarregada")
	var comum := _nascer()
	if aprimorada == null or comum == null:
		return
	igual(run.aprimoradas_encontradas, 1, "so uma aprimorada nasceu")

	var kills_antes: int = run.kills
	_matar(comum)
	igual(run.kills, kills_antes + 1, "o inimigo COMUM morreu de verdade")
	igual(run.aprimoradas_mortas, 0,
		"e mesmo assim nao entrou na conta de aprimoradas")

	_matar(aprimorada)
	igual(run.kills, kills_antes + 2, "a aprimorada tambem morreu")
	igual(run.aprimoradas_mortas, 1, "e SO ela subiu o contador de aprimoradas")
	RegistroRun.terminar(false, "teste", 1.0)


## Aprimorada que sobrevive ao fim da run nao conta na run SEGUINTE.
##
## Quem abandona pelo menu deixa a sala cheia, e aqueles nos podem ser liberados
## depois de a proxima run ja ter comecado. Sem a run amarrada na ligacao, o
## abate atrasado apareceria como uma aprimorada morta que a run nova nunca viu
## nascer -- `mortas > encontradas`, que e um numero impossivel.
func _a_aprimorada_de_outra_run_nao_conta_na_proxima() -> void:
	var primeira := RegistroRun.comecar("raven", 278)
	var sobrevivente := _nascer_aprimorada(&"blindada")
	if sobrevivente == null:
		return
	igual(primeira.aprimoradas_encontradas, 1, "a primeira run viu uma nascer")
	RegistroRun.terminar(false, "abandono", 1.0)

	var segunda := RegistroRun.comecar("nova", 279)
	_matar(sobrevivente)
	igual(segunda.aprimoradas_encontradas, 0,
		"a run nova nao viu aprimorada nenhuma nascer")
	igual(segunda.aprimoradas_mortas, 0,
		"e o abate atrasado da run anterior nao entrou nela")
	igual(primeira.aprimoradas_mortas, 0,
		"nem foi parar na run ja fechada")
	RegistroRun.terminar(false, "teste", 1.0)


# ------------------------------------------------------------- apoio --------

func _nascer() -> InimigoBase:
	var cena := load(CENA_DRONE) as PackedScene
	if cena == null:
		ok(false, "a cena do Drone carrega")
		return null
	var inimigo := cena.instantiate() as InimigoBase
	Engine.get_main_loop().root.add_child(inimigo)
	inimigo.global_position = LONGE
	# Sem credito nao ha ficha caindo na raiz da arvore de teste. O que se mede
	# aqui e o contador, e ficha solta na raiz e lixo que a proxima suite acha
	# pelo grupo.
	inimigo.creditos = 0
	return inimigo


## Um drone com classe, anunciado como a `Sala` anuncia.
##
## Ele passa por `aplicar_aprimoramento()` de verdade em vez de so emitir o
## sinal: emitir sozinho provaria o contador contra um inimigo que nao esta
## aprimorado, e o portao passaria a valer para um estado que o jogo nao produz.
func _nascer_aprimorada(classe_id: StringName) -> InimigoBase:
	var classe := _classe_de_id(classe_id)
	if classe == null:
		ok(false, "a classe %s existe em disco" % classe_id)
		return null
	var inimigo := _nascer()
	if inimigo == null:
		return null
	if not inimigo.aplicar_aprimoramento(classe):
		ok(false, "a classe %s entra no drone" % classe_id)
		inimigo.free()
		return null
	EventBus.aprimorado_nasceu.emit(inimigo, classe.id)
	return inimigo


## Mata pelo caminho de verdade e limpa o que o abate deixou na raiz.
##
## `morrer()` e o unico ponto que emite `morreu` -- forjar o sinal a mao provaria
## o handler e nao a corrente. O preco e a explosao, que nasce como filha do PAI
## do inimigo: aqui isso e a raiz da arvore de teste, e um no sobrando ali
## reaparece na suite seguinte.
func _matar(inimigo: InimigoBase) -> void:
	if inimigo == null or not is_instance_valid(inimigo):
		return
	var raiz: Node = (Engine.get_main_loop() as SceneTree).root
	var antes: Array[Node] = []
	for filho in raiz.get_children():
		antes.append(filho)
	inimigo.morrer()
	for filho in raiz.get_children():
		if not antes.has(filho):
			filho.free()
	if is_instance_valid(inimigo):
		inimigo.free()


func _classe_de_id(qual: StringName) -> DadosAprimoramento:
	var pasta := DirAccess.open(PASTA_CLASSES)
	if pasta == null:
		return null
	for nome_do_arquivo in pasta.get_files():
		if not nome_do_arquivo.begins_with("apr_") or not nome_do_arquivo.ends_with(".tres"):
			continue
		var d := load(PASTA_CLASSES + nome_do_arquivo) as DadosAprimoramento
		if d != null and d.id == qual:
			return d
	return null
