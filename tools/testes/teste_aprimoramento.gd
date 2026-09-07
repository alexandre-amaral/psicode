extends TesteBase
## As travas das Unidades Aprimoradas (#268).
##
## O que esta suite guarda nao e "a classe funciona" -- isso o
## `tools/aprimoramentos/laboratorio.tscn` mede em TTK. E o que falha em
## SILENCIO: um inimigo sem classe mudando de comportamento, um campo de
## compatibilidade que ninguem le, o teto de uma classe por inimigo, e a promessa
## de que o telegrafo nunca some.


const CENA_DRONE := "res://src/enemies/drone_aranha.tscn"
const PASTA := "res://src/enemies/aprimoramento/"
const LONGE := Vector2(44000.0, 44000.0)


func nome() -> String:
	return "Aprimoramento"


func executar() -> void:
	_sem_classe_nada_muda()
	_o_teto_de_uma_classe_por_inimigo_morde()
	_a_compatibilidade_e_LIDA()
	_o_piso_do_telegrafo_sobrevive_a_classe()
	_a_reducao_de_dano_nao_some_no_arredondamento()
	_os_cinco_inimigos_tem_tags()


## UM INIMIGO SEM CLASSE E O INIMIGO DE ANTES, e isto e o primeiro portao.
##
## O sistema inteiro entra por um caminho que TODO inimigo atravessa
## (`receber_dano`, `cadencia_agora`, `duracao_do_telegrafo`), entao um erro ali
## nao afeta os aprimorados: afeta o andar inteiro. E a maioria dos inimigos
## continua normal de proposito, entao o defeito apareceria em todo lugar menos
## onde alguem estaria olhando.
func _sem_classe_nada_muda() -> void:
	var inimigo := _nascer()
	if inimigo == null:
		return
	ok(inimigo.aprimoramentos.is_empty(), "ele nasce sem classe nenhuma")
	ok(not inimigo.esta_aprimorado(), "e nao se diz aprimorado")
	perto(inimigo.cadencia_agora(), Deterioracao.multiplicador_cadencia(),
		"a cadencia e exatamente a da Deterioracao", 0.0001)

	var vida_antes: int = inimigo.vida
	inimigo.receber_dano(2)
	igual(inimigo.vida, vida_antes - 2, "e o dano chega inteiro, sem multiplicador")
	inimigo.free()


## UMA CLASSE POR INIMIGO, e o teto tem de MORDER.
##
## O array e o teto entram juntos: array sem teto deixa duas classes se
## empilharem no dia em que alguem chamar a funcao duas vezes -- sem erro nenhum,
## e com os dois controladores rodando ao mesmo tempo.
func _o_teto_de_uma_classe_por_inimigo_morde() -> void:
	var inimigo := _nascer()
	if inimigo == null:
		return
	var classes := _classes()
	ok(classes.size() >= 2, "ha classes para tentar empilhar (%d)" % classes.size())
	if classes.size() < 2:
		inimigo.free()
		return

	ok(inimigo.aplicar_aprimoramento(classes[0]), "a primeira classe entra")
	ok(not inimigo.aplicar_aprimoramento(classes[1]),
		"e a segunda e RECUSADA -- o teto e %d" % InimigoBase.MAX_APRIMORAMENTOS)
	igual(inimigo.aprimoramentos.size(), 1, "sobra uma so pendurada")
	inimigo.free()


## OS CAMPOS DE COMPATIBILIDADE SAO LIDOS, e este portao existe por isso.
##
## Nenhuma classe do MVP usa tag nenhuma: as tres funcionam em todos. Um campo
## que existe no `.tres` e nao e lido pelo codigo e um campo que MENTE -- quem o
## preencher nao recebe erro, e o aprimoramento nasce onde nao devia sem uma
## linha no console.
##
## Ele cobra os DOIS sentidos com uma classe sintetica: a tag exigida barra quem
## nao a tem, e a incompativel barra quem a tem.
func _a_compatibilidade_e_LIDA() -> void:
	var dados_do_drone := load("res://src/enemies/dados_drone_aranha.tres") as DadosInimigo
	ok(dados_do_drone != null, "o Drone tem DadosInimigo")
	if dados_do_drone == null:
		return

	var exige := DadosAprimoramento.new()
	exige.tags_exigidas = [DadosInimigo.Tag.INVOCADOR]
	ok(not exige.cabe_em(dados_do_drone),
		"a tag EXIGIDA barra quem nao a tem")

	var proibe := DadosAprimoramento.new()
	proibe.tags_incompativeis = [DadosInimigo.Tag.DISTANCIA]
	ok(not proibe.cabe_em(dados_do_drone),
		"a tag INCOMPATIVEL barra quem a tem")

	# E o outro lado: sem regra, todo mundo passa -- inclusive quem nao tem
	# `DadosInimigo`, porque Rastejante, Vigia e Diretora nao tem `.tres` e
	# continuar elegiveis e a razao de `dados` ser opcional.
	var livre := DadosAprimoramento.new()
	ok(livre.cabe_em(dados_do_drone), "sem regra, o Drone passa")
	ok(livre.cabe_em(null), "e um inimigo sem .tres tambem")

	var so_exige := DadosAprimoramento.new()
	so_exige.tags_exigidas = [DadosInimigo.Tag.MOVEL]
	ok(not so_exige.cabe_em(null),
		"mas uma classe que EXIGE tag recusa quem nao tem .tres")


## O PISO DO TELEGRAFO SOBREVIVE A CLASSE, e o pior caso e a soma dos dois.
##
## A Sobrecarregada encurta o aviso em 10%, e a Deterioracao ja o encurta ate o
## proprio limite. O pior caso e a barra CHEIA mais a classe, e nao um dos dois
## sozinho -- a mesma conta que o chefe faz contra `1,30 x 1,7`.
##
## Telegrafo que some e a fronteira entre "dificil" e "mente sobre a propria
## regra", e essa fronteira nao pode depender de ninguem lembrar dela.
func _o_piso_do_telegrafo_sobrevive_a_classe() -> void:
	var barra := Deterioracao.valor
	Deterioracao.valor = 100.0
	var inimigo := _nascer()
	if inimigo == null:
		Deterioracao.valor = barra
		return
	var rapida := _classe_de_id(&"sobrecarregada")
	ok(rapida != null, "a Sobrecarregada existe")
	if rapida != null:
		inimigo.aplicar_aprimoramento(rapida)
	# Varre a faixa inteira em vez de olhar so um valor: um piso escrito como
	# `if base > 0.5` passaria testando so as pontas.
	var furou := 0
	var base := 0.1
	while base <= 2.0:
		if inimigo.duracao_do_telegrafo(base) < Telegrafo.DURACAO_MINIMA - 0.0001:
			furou += 1
		base += 0.05
	igual(furou, 0,
		"nenhuma duracao fura o piso de %.2fs com a barra cheia MAIS a classe"
			% Telegrafo.DURACAO_MINIMA)
	inimigo.free()
	Deterioracao.valor = barra


## A REDUCAO DE DANO NAO SOME NO ARREDONDAMENTO.
##
## **Este portao guarda um defeito que ja aconteceu, e que nenhum teste de
## comportamento pegaria.** Vida e `int` e os tiros do jogo valem 1 ou 2: com um
## piso de 1 por acerto, `round(1 x 0.85)` devolvia 1 e a Blindada media +0% de
## TTK nas cinco especies -- a classe existia, desenhava a aura, e nao fazia
## nada. E a mesma armadilha que `DANO_PERCENTUAL` ja registra.
##
## A saida e acumular a fracao, como a cura ja faz. O que se cobra aqui e o
## RESULTADO: vinte acertos de 1 com 15% de reducao tem de tirar 17 de vida, e
## nao 20.
func _a_reducao_de_dano_nao_some_no_arredondamento() -> void:
	var blindada := _classe_de_id(&"blindada")
	ok(blindada != null, "a Blindada existe")
	if blindada == null:
		return
	var controlador := Aprimoramento.new()
	controlador.dados = blindada
	# Sem inimigo: `dano_efetivo` e conta pura, e monta-lo so para somar seria
	# arrastar fisica para uma pergunta de aritmetica.
	var total := 0
	for _i in 20:
		total += controlador.dano_efetivo(1)
	var esperado := int(roundf(20.0 * (1.0 - blindada.reducao_de_dano)))
	igual(total, esperado,
		"20 acertos de 1 entregam %d com %.0f%% de reducao (deu %d)"
			% [esperado, blindada.reducao_de_dano * 100.0, total])
	ok(total < 20, "e a reducao existe de fato (%d de 20)" % total)
	controlador.free()


## OS CINCO INIMIGOS REFINADOS TEM TAGS.
##
## As tags nao fazem nada no MVP -- nenhuma classe usa. Elas existem para as
## classes futuras poderem ter excecoes sem um `if` por especie, e um inimigo sem
## tag ficaria fora dessas regras em silencio no dia em que a primeira aparecer.
func _os_cinco_inimigos_tem_tags() -> void:
	var esperados := [
		"dados_drone_aranha", "dados_atirador_neon", "dados_cyber_besta",
		"dados_sentinela_orbital", "dados_hacker_parasita",
	]
	for nome_do_arquivo: String in esperados:
		var d := load("res://src/enemies/%s.tres" % nome_do_arquivo) as DadosInimigo
		ok(d != null, "%s carrega" % nome_do_arquivo)
		if d == null:
			continue
		ok(not d.tags.is_empty(), "%s declara tags (%d)" % [nome_do_arquivo, d.tags.size()])
		ok(d.peso_de_aprimoramento > 0.0,
			"%s continua elegivel (peso %.1f)" % [nome_do_arquivo, d.peso_de_aprimoramento])


# ------------------------------------------------------------- apoio --------

func _nascer() -> InimigoBase:
	var cena := load(CENA_DRONE) as PackedScene
	if cena == null:
		ok(false, "a cena do Drone carrega")
		return null
	var inimigo := cena.instantiate() as InimigoBase
	Engine.get_main_loop().root.add_child(inimigo)
	inimigo.global_position = LONGE
	return inimigo


func _classes() -> Array[DadosAprimoramento]:
	var saida: Array[DadosAprimoramento] = []
	var pasta := DirAccess.open(PASTA)
	if pasta == null:
		return saida
	var nomes := pasta.get_files()
	nomes.sort()
	for nome_do_arquivo in nomes:
		if not nome_do_arquivo.begins_with("apr_") or not nome_do_arquivo.ends_with(".tres"):
			continue
		var d := load(PASTA + nome_do_arquivo) as DadosAprimoramento
		if d != null:
			saida.append(d)
	return saida


func _classe_de_id(qual: StringName) -> DadosAprimoramento:
	for d in _classes():
		if d.id == qual:
			return d
	return null
