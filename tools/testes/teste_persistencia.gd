extends TesteBase
## O SAVE: formato, defaults, escrita segura e o que uma run anota.
##
## Esta suite guarda a promessa central do epico do Lobby: **o progresso
## sobrevive ao fechamento do jogo.** Nao ha como conferir isso olhando -- o
## sintoma de um save quebrado e o jogador perder horas, e ele aparece depois,
## na maquina de outra pessoa.
##
## **Ela nunca escreve no arquivo real.** `Save._caminho` e sobrescrito para um
## `user://` de teste, pela mesma razao que `Configuracao` ja tem essa valvula:
## uma suite que grava no save de verdade apaga o progresso de quem esta
## desenvolvendo, e isso so aparece quando a pessoa vai jogar.

const CAMINHO_DE_TESTE := "user://teste_save.json"


func nome() -> String:
	return "Persistencia"


func executar() -> void:
	_o_formato_sobrevive_a_ida_e_volta()
	_todo_campo_tem_default()
	_o_resultado_e_serializavel()
	_o_save_escreve_e_le_do_disco()
	_o_save_nao_estoura_com_arquivo_corrompido()
	_a_escrita_e_segura()
	_o_backup_guarda_a_versao_ANTERIOR()
	_o_historico_tem_teto_e_o_teto_morde()
	_o_registro_de_run_so_conta_dentro_da_run()
	_o_lobby_nao_liga_os_sistemas_da_run()
	_o_CICLO_INTEIRO_sobrevive_a_fechar_o_jogo()


## Ida e volta pelo dicionario preserva os valores.
##
## E o portao mais barato e o mais util: quase todo defeito de save e um campo
## que foi escrito e nao foi lido de volta, ou lido com o nome errado. Nada no
## console acusa -- o jogo abre, e o numero esta zerado.
func _o_formato_sobrevive_a_ida_e_volta() -> void:
	var s := DadosSave.novo()
	s.personagem_selecionado = "nova"
	s.total_runs = 7
	s.total_vitorias = 3
	s.total_derrotas = 4
	s.melhor_andar = 2
	s.maior_dano_run = 1234
	s.maior_numero_kills = 88
	s.desbloqueios["floor_02"] = true
	s.upgrades_permanentes["upgrade_x"] = 2
	s.moedas_persistentes["memoria"] = 50

	var r := ResultadoRun.new()
	r.personagem = "raven"
	r.kills = 12
	r.venceu = true
	s.registrar(r)

	var volta := DadosSave.de_dicionario(s.para_dicionario())
	igual(volta.personagem_selecionado, "nova", "o personagem sobrevive")
	igual(volta.total_runs, 8, "os totais sobrevivem (o registrar somou 1)")
	igual(volta.total_vitorias, 4, "as vitorias sobrevivem")
	igual(volta.melhor_andar, 2, "o melhor andar sobrevive")
	igual(volta.maior_numero_kills, 88, "o recorde de kills sobrevive")
	ok(bool(volta.desbloqueios.get("floor_02", false)), "o desbloqueio sobrevive")
	igual(int(volta.upgrades_permanentes.get("upgrade_x", 0)), 2,
		"o nivel do upgrade sobrevive")
	igual(int(volta.moedas_persistentes.get("memoria", -1)), 50, "a moeda sobrevive")
	igual(volta.historico_runs.size(), 1, "o historico sobrevive")
	if not volta.historico_runs.is_empty():
		igual(volta.historico_runs[0].kills, 12, "e o conteudo da run sobrevive")


## Um save INCOMPLETO carrega, e vira um perfil zerado.
##
## Este e o caso que a versao de amanha vai produzir: um arquivo escrito hoje,
## aberto por uma versao que ganhou campos novos. Ler com `dados["stats"]` faria
## o jogo estourar na abertura, e o jogador nao tem como saber que o problema e
## uma chave que faltou. Perfil zerado ainda deixa jogar.
func _todo_campo_tem_default() -> void:
	var minimo := DadosSave.de_dicionario({"version": 1})
	igual(minimo.personagem_selecionado, "raven",
		"sem `selected_character`, cai no padrao")
	igual(minimo.total_runs, 0, "sem `stats`, os totais sao zero")
	igual(minimo.historico_runs.size(), 0, "sem `run_history`, o historico e vazio")

	var vazio := DadosSave.de_dicionario({})
	igual(vazio.versao_save, DadosSave.VERSAO,
		"um dicionario VAZIO ainda produz um perfil valido")

	var parcial := ResultadoRun.de_dicionario({"kills": 5})
	igual(parcial.kills, 5, "o resultado le o que existe")
	igual(parcial.andar_alcancado, 1, "e completa o que falta")


## O resultado nao guarda Node nem Resource.
##
## Guardar o `DadosPersonagem` inteiro pareceria conveniente -- o terminal teria
## nome, miniatura e arma de graca -- e transformaria o save num grafo de
## recursos: o arquivo deixaria de abrir no dia em que aquele `.tres` mudasse de
## caminho, e o jogador perderia o historico por causa de uma refatoracao de
## pasta.
func _o_resultado_e_serializavel() -> void:
	var r := ResultadoRun.new()
	r.personagem = "raven"
	r.itens_principais = ["Nucleo", "Aco"]
	var d := r.para_dicionario()
	var proibidos := 0
	for chave in d:
		var valor: Variant = d[chave]
		if valor is Object:
			proibidos += 1
	igual(proibidos, 0, "nenhum campo do resultado e um Object (%d)" % proibidos)

	# E o JSON tem de conseguir escrever o que sobrou. `stringify` devolve texto
	# vazio para o que ele nao sabe representar.
	var texto := JSON.stringify(d)
	ok(texto.length() > 10, "o resultado vira JSON de verdade (%d bytes)" % texto.length())
	var relido: Variant = JSON.parse_string(texto)
	ok(relido is Dictionary, "e o JSON volta a ser dicionario")


## O ciclo completo: escrever, esquecer, ler do disco.
func _o_save_escreve_e_le_do_disco() -> void:
	var antes := Save._caminho
	Save._caminho = CAMINHO_DE_TESTE
	Save.apagar_save()

	ok(not Save.save_existe(), "sem arquivo, `save_existe` e falso")
	var criado := Save.criar_novo_save()
	ok(criado != null, "`criar_novo_save` devolve um perfil")
	ok(Save.save_existe(), "e ele ja esta em disco -- criar perfil grava na hora")

	criado.personagem_selecionado = "nova"
	criado.total_runs = 3
	ok(Save.salvar(criado), "salvar devolve sucesso")

	var lido := Save.carregar()
	ok(lido != null, "carregar devolve um perfil")
	if lido != null:
		igual(lido.personagem_selecionado, "nova", "o personagem veio do DISCO")
		igual(lido.total_runs, 3, "e os totais tambem")

	Save.apagar_save()
	ok(Save.carregar() == null, "sem arquivo, carregar devolve null")
	igual(Save.ultima_falha, Save.Falha.NAO_EXISTE,
		"e o motivo separa `nao existe` de `corrompido`")
	Save._caminho = antes


## Save corrompido NAO derruba o jogo.
##
## O jogador que abre o jogo e ve um crash nao tem nada a fazer com a
## informacao; o que ele precisa e de uma frase e de um botao. E os dois motivos
## precisam ser distinguiveis, porque "nao ha jogo salvo" e "seu progresso nao
## abriu" sao conversas muito diferentes.
func _o_save_nao_estoura_com_arquivo_corrompido() -> void:
	var antes := Save._caminho
	Save._caminho = CAMINHO_DE_TESTE

	var arquivo := FileAccess.open(CAMINHO_DE_TESTE, FileAccess.WRITE)
	arquivo.store_string("{isto nao e json")
	arquivo.close()

	var lido := Save.carregar()
	ok(lido == null, "JSON invalido devolve null em vez de estourar")
	igual(Save.ultima_falha, Save.Falha.CORROMPIDO, "e o motivo e CORROMPIDO")

	# Um JSON valido que nao e um dicionario tambem tem de ser recusado.
	arquivo = FileAccess.open(CAMINHO_DE_TESTE, FileAccess.WRITE)
	arquivo.store_string("[1, 2, 3]")
	arquivo.close()
	ok(Save.carregar() == null, "JSON valido mas do tipo errado tambem e recusado")

	Save.apagar_save()
	Save._caminho = antes


## A escrita passa por um temporario, e o temporario nao fica para tras.
##
## Escrever direto sobre o definitivo significa que uma queda no meio da
## gravacao deixa um JSON pela metade -- e isso nao e "um save com menos
## coisas", e um save que nao abre. O jogo perderia todo o progresso no unico
## momento em que estava tentando proteger.
func _a_escrita_e_segura() -> void:
	var antes := Save._caminho
	Save._caminho = CAMINHO_DE_TESTE
	Save.apagar_save()

	var dados := DadosSave.novo()
	dados.total_runs = 42
	ok(Save.salvar(dados), "a gravacao concluiu")
	ok(
		not FileAccess.file_exists(Save._caminho_temporario()),
		"o temporario nao fica para tras depois de uma gravacao boa"
	)
	var lido := Save.carregar()
	ok(lido != null and lido.total_runs == 42, "e o definitivo tem o conteudo novo")

	Save.apagar_save()
	Save._caminho = antes


## O backup guarda a versao ANTERIOR, e ele recupera.
##
## As duas travas cobrem falhas DIFERENTES, e por isso as duas existem: o
## temporario protege contra a gravacao ser interrompida; o backup protege
## contra a gravacao ter dado certo com conteudo ruim -- o caso que nenhuma
## trava de arquivo pega. Um bug que zere o historico e grave com sucesso passa
## limpo pelo temporario.
func _o_backup_guarda_a_versao_ANTERIOR() -> void:
	var antes := Save._caminho
	Save._caminho = CAMINHO_DE_TESTE
	Save.apagar_save()

	var primeira := DadosSave.novo()
	primeira.total_runs = 10
	Save.salvar(primeira)
	ok(not Save.backup_existe(),
		"a primeira gravacao nao gera backup -- nao havia nada anterior")

	var segunda := DadosSave.novo()
	segunda.total_runs = 20
	Save.salvar(segunda)
	ok(Save.backup_existe(), "a segunda gravacao guarda a primeira")

	# O backup e a versao ANTERIOR e nao a atual. Copiar depois de escrever
	# faria as duas serem o mesmo arquivo, e um backup identico ao original nao
	# recupera de nada.
	var arquivo := FileAccess.open(CAMINHO_DE_TESTE, FileAccess.WRITE)
	arquivo.store_string("{corrompido")
	arquivo.close()
	ok(Save.carregar() == null, "o save atual esta corrompido")

	var recuperado := Save.restaurar_backup()
	ok(recuperado != null, "o backup recupera")
	if recuperado != null:
		igual(recuperado.total_runs, 10,
			"e o que volta e a versao ANTERIOR, nao a que quebrou")

	Save.apagar_save()
	ok(Save.restaurar_backup() == null,
		"sem backup, restaurar devolve null em vez de prometer o que nao tem")
	Save._caminho = antes


## O historico tem teto, e o teto MORDE.
##
## Teto que nunca e alcancado e teto que nunca foi testado -- a licao que
## `max_props_animados` ja deixou registrada. Um historico sem corte cresce para
## sempre e o save vira um arquivo de megabytes depois de algumas centenas de
## runs.
func _o_historico_tem_teto_e_o_teto_morde() -> void:
	var s := DadosSave.novo()
	for i in DadosSave.HISTORICO_MAXIMO + 5:
		var r := ResultadoRun.new()
		r.kills = i
		s.registrar(r)
	igual(s.historico_runs.size(), DadosSave.HISTORICO_MAXIMO,
		"o historico para no teto (%d)" % DadosSave.HISTORICO_MAXIMO)
	igual(s.total_runs, DadosSave.HISTORICO_MAXIMO + 5,
		"mas o TOTAL continua contando tudo -- o teto e da lista, nao da conta")
	# O corte e por baixo: o indice 0 e a run mais recente, porque e ela que o
	# terminal mostra primeiro.
	igual(s.historico_runs[0].kills, DadosSave.HISTORICO_MAXIMO + 4,
		"a mais recente fica na frente")
	igual(s.historico_runs[0].id, DadosSave.HISTORICO_MAXIMO + 5,
		"e o id dela e o numero da run")


## Fora de uma run, o `RegistroRun` ignora TUDO.
##
## E o que faz o Lobby ser barato: os sinais continuam chegando -- o EventBus e
## global -- e cada `_ao_*` sai na primeira linha. Sem essa guarda, andar pelo
## Lobby contaria salas, e um dia o Lobby teria props que emitem coisas.
func _o_registro_de_run_so_conta_dentro_da_run() -> void:
	RegistroRun.descartar()
	ok(not RegistroRun.ativo(), "fora da run, o registro esta inativo")
	EventBus.dano_a_inimigo.emit(50)
	EventBus.inimigo_morreu.emit(Vector2.ZERO, 1)
	ok(RegistroRun.run() == null, "e os sinais nao criam run nenhuma")

	var run := RegistroRun.comecar("nova", 123)
	ok(RegistroRun.ativo(), "depois de comecar, o registro esta ativo")
	igual(run.personagem, "nova", "a run sabe quem entrou")
	igual(run.seed, 123, "e guarda a semente")

	EventBus.dano_a_inimigo.emit(10)
	EventBus.dano_a_inimigo.emit(5)
	EventBus.inimigo_morreu.emit(Vector2.ZERO, 1)
	EventBus.inimigo_morreu.emit(Vector2.ZERO, 1)
	igual(run.dano_causado, 15, "o dano entregue e somado")
	igual(run.kills, 2, "e os abates contados")

	# O dano RECEBIDO e por diferenca, e o primeiro aviso so estabelece a base:
	# ele chega com a vida cheia e nao representa dano nenhum.
	EventBus.player_dano_recebido.emit(6, 6)
	igual(run.dano_recebido, 0, "o primeiro aviso de vida nao conta como dano")
	EventBus.player_dano_recebido.emit(4, 6)
	igual(run.dano_recebido, 2, "o segundo conta a diferenca")

	var resultado := RegistroRun.terminar(false, "morte", 61.0)
	ok(resultado != null, "terminar devolve o resultado")
	if resultado != null:
		igual(resultado.kills, 2, "o resultado carrega os abates")
		perto(resultado.duracao, 61.0, "e a duracao que veio de fora")
		ok(not resultado.venceu, "e a derrota")
	ok(RegistroRun.terminar(false, "morte", 1.0) == null,
		"terminar de novo devolve null -- duas chamadas nao inventam duas derrotas")


## O LOBBY NAO E UMA RUN, e este e o portao da primeira regra do plano.
##
## Ele mede o autoload em vez de ler o codigo: entrar no lobby e conferir que a
## Deterioracao passiva continua desligada e que nao ha run em curso. A falha
## que ele previne e silenciosa dos dois lados -- uma barra subindo no lobby, ou
## uma run fantasma contando salas enquanto o jogador escolhe personagem.
func _o_lobby_nao_liga_os_sistemas_da_run() -> void:
	Deterioracao.passiva_ativa = true
	RegistroRun.comecar("raven", 1)

	GameState.entrar_lobby()
	igual(GameState.modo, GameState.Modo.LOBBY, "o modo vira LOBBY")
	ok(not Deterioracao.passiva_ativa,
		"entrar no lobby DESLIGA a Deterioracao passiva")
	ok(not RegistroRun.ativo(), "e nao ha run em curso no lobby")
	ok(not Engine.get_main_loop().paused, "e a arvore nao fica pausada")

	# E os dois eixos sao independentes: `modo` diz onde o jogador esta, `estado`
	# diz como a run esta. Fundir os dois faria abrir um painel no lobby apagar a
	# informacao de que ele esta no lobby.
	ok(GameState.Modo.RUN != GameState.Modo.LOBBY, "MODO tem valor proprio para RUN")
	ok(GameState.Estado.PAUSADO != GameState.Estado.JOGANDO,
		"e ESTADO continua descrevendo a run")


## O CICLO INTEIRO, que e o criterio de pronto do epico.
##
## ```
## NOVO JOGO -> Lobby -> selecionar Nova -> FECHAR -> abrir -> CARREGAR
## -> Nova continua selecionada -> iniciar run -> morrer -> Lobby
## -> o terminal mostra a derrota -> FECHAR -> carregar -> o historico esta la
## ```
##
## O plano e explicito: **se esse fluxo funcionar, o sistema basico esta
## correto.** Ele existe como um caso so, e nao dividido em seis, porque o que
## ele prova nao esta em nenhum dos passos -- esta na CORRENTE. Cada elo ja tem
## portao proprio nesta suite; o que falta e provar que nenhum deles perde o
## anterior.
##
## "Fechar o jogo" aqui e reler do disco: o processo continua vivo, entao o que
## se testa e o unico canal que sobreviveria a um fechamento de verdade -- o
## arquivo. Um teste que reaproveitasse o objeto em memoria passaria com o save
## quebrado, que e exatamente o defeito que ele existe para pegar.
func _o_CICLO_INTEIRO_sobrevive_a_fechar_o_jogo() -> void:
	var antes := Save._caminho
	Save._caminho = CAMINHO_DE_TESTE
	Save.apagar_save()

	# --- NOVO JOGO -------------------------------------------------------
	Progressao.criar_novo()
	ok(Progressao.carregado(), "NOVO JOGO cria um perfil")
	ok(Save.save_existe(), "e ele ja esta em disco antes de o jogador fazer nada")
	igual(Progressao.personagem_selecionado(), "raven", "que comeca na Raven")

	# --- escolher a NOVA no lobby ----------------------------------------
	ok(Progressao.selecionar_personagem("nova"), "a selecao aceita a Nova")

	# --- FECHAR e abrir de novo ------------------------------------------
	Progressao.adotar(null)
	ok(not Progressao.carregado(), "fechar o jogo esvazia o perfil em memoria")
	ok(Progressao.carregar(), "CARREGAR le o perfil de volta")
	igual(Progressao.personagem_selecionado(), "nova",
		"e a NOVA continua selecionada -- veio do DISCO")

	# --- iniciar a run ---------------------------------------------------
	GameState.personagem = null
	GameState.iniciar_run()
	igual(GameState.modo, GameState.Modo.RUN, "iniciar a run muda o modo para RUN")
	ok(Deterioracao.passiva_ativa,
		"e AGORA a Deterioracao passiva liga -- e no lobby ela nao tinha ligado")
	ok(RegistroRun.ativo(), "e ha run em curso")
	if RegistroRun.run() != null:
		igual(RegistroRun.run().personagem, "nova",
			"a run entra com quem o perfil dizia")

	EventBus.inimigo_morreu.emit(Vector2.ZERO, 1)
	EventBus.inimigo_morreu.emit(Vector2.ZERO, 1)
	EventBus.inimigo_morreu.emit(Vector2.ZERO, 1)

	# --- morrer ----------------------------------------------------------
	GameState.terminar_run(false)
	igual(GameState.modo, GameState.Modo.RESULTADO, "terminar leva ao RESULTADO")
	ok(not Deterioracao.passiva_ativa, "e desliga a passiva")
	ok(not RegistroRun.ativo(), "e fecha a run")

	# --- o terminal ja mostra a derrota ----------------------------------
	var ultima := Progressao.ultima_run()
	ok(ultima != null, "o historico ja tem a run")
	if ultima != null:
		ok(not ultima.venceu, "e ela e uma derrota")
		igual(ultima.kills, 3, "com os abates que a run produziu")
		igual(ultima.personagem, "nova", "e o personagem certo")
		igual(ultima.id, 1, "e ela e a run numero 1")
	igual(int(Progressao.estatisticas().get("total_derrotas", 0)), 1,
		"e a derrota entrou no total")

	# --- FECHAR de novo, e o historico continua la -----------------------
	Progressao.adotar(null)
	ok(Progressao.carregar(), "o perfil abre de novo")
	var depois := Progressao.ultima_run()
	ok(depois != null, "e o historico sobreviveu ao fechamento")
	if depois != null:
		igual(depois.kills, 3, "com os numeros intactos")
		igual(depois.personagem, "nova", "e o personagem intacto")

	# --- e o LOBBY continua sendo lobby ----------------------------------
	GameState.entrar_lobby()
	igual(GameState.modo, GameState.Modo.LOBBY, "voltar ao lobby fecha o ciclo")
	ok(not Deterioracao.passiva_ativa, "sem a passiva ligada")

	Save.apagar_save()
	Save._caminho = antes
	Progressao.adotar(null)
	GameState.estado = GameState.Estado.MENU
	GameState.modo = GameState.Modo.MENU
