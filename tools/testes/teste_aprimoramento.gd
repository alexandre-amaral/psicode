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
const MAIN := "res://src/main/main.tscn"
const TIPO_COMBATE := "res://src/mapa/tipo_combate.tres"

## Quantos andares o encontro mede (#275). Doze foi o numero da Loja, que mede
## "uma por andar" -- pergunta binaria. Taxa e mais ruidosa: cada andar rende
## meia duzia de salas de combate, entao a amostra util e ANDARES x 6, e o erro
## amostral cai com a raiz dela.
##
## Vinte e quatro custa ~30 s no runner, medido: e o preco de montar o andar de
## verdade em vez de simular o sorteio, e simular o sorteio mediria a copia da
## regra escrita aqui em vez do codigo que roda em jogo.
const ANDARES := 24

## Os tipos que declaram zero e nunca podem receber classe. A LOJA nao tem
## constante em `DadosSala` -- ela nasceu como `.tres` novo, que e o desenho --,
## entao o id vai literal aqui.
const SEM_APRIMORADA: Array[StringName] = [
	DadosSala.ID_INICIAL, DadosSala.ID_ARMA, DadosSala.ID_ITEM,
	DadosSala.ID_BOSS, &"loja",
]

var _raiz_do_andar: Node = null


func nome() -> String:
	return "Aprimoramento"


func executar() -> void:
	_sem_classe_nada_muda()
	_o_teto_de_uma_classe_por_inimigo_morde()
	_a_compatibilidade_e_LIDA()
	_a_incompatibilidade_entre_classes_e_LIDA()
	_o_piso_do_telegrafo_sobrevive_a_classe()
	_a_reducao_de_dano_nao_some_no_arredondamento()
	_os_cinco_inimigos_tem_tags()
	_o_contador_de_seguidas_morde()
	_a_taxa_de_aprimorada_por_andar()


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


## A INCOMPATIBILIDADE ENTRE CLASSES E LIDA, e ela nao pode ser confundida com o
## TETO.
##
## `aprimoramentos_incompativeis` esta vazio nas tres classes do MVP, entao ele
## so existe em `.tres` no dia em que alguem o preencher -- e, se ninguem o
## ler, aquele dia chega sem erro nenhum no console: as duas classes brigadas
## nascem juntas e o jogador leva o super-inimigo que o campo existia para
## proibir.
##
## **O que torna este portao dificil e o teto recusar ANTES.** Com
## `MAX_APRIMORAMENTOS = 1`, chamar `aplicar_aprimoramento()` duas vezes devolve
## `false` na segunda de qualquer jeito -- com o campo lido ou morto, e sem
## diferenca visivel. Por isso a regra e uma funcao propria,
## `aprimoramento_incompativel()`, perguntada DIRETAMENTE: e o unico jeito de
## afirmar "esta e a recusa por briga" e nao "esta e a recusa por lotacao".
##
## Ele morde dos dois lados de proposito: a classe NEUTRA nao conflita (e mesmo
## assim nao entra, pelo teto), e esvaziar o campo faz o conflito sumir -- que e
## exatamente o estado em que o codigo estaria se ninguem lesse o campo.
func _a_incompatibilidade_entre_classes_e_LIDA() -> void:
	var inimigo := _nascer()
	if inimigo == null:
		return

	var pendurada := DadosAprimoramento.new()
	pendurada.id = &"teste_pendurada"
	var briguenta := DadosAprimoramento.new()
	briguenta.id = &"teste_briguenta"
	briguenta.aprimoramentos_incompativeis = [&"teste_pendurada"]
	var neutra := DadosAprimoramento.new()
	neutra.id = &"teste_neutra"

	ok(not inimigo.aprimoramento_incompativel(briguenta),
		"num inimigo sem classe nenhuma, nada conflita")
	ok(inimigo.aplicar_aprimoramento(pendurada), "a primeira classe entra")

	ok(inimigo.aprimoramento_incompativel(briguenta),
		"quem DECLARA a pendurada como incompativel conflita com ela")
	ok(not inimigo.aprimoramento_incompativel(neutra),
		"e quem nao declara nada NAO conflita -- as duas recusas sao coisas diferentes")
	ok(not inimigo.aplicar_aprimoramento(neutra),
		"tanto que a neutra tambem nao entra, so que pelo teto de %d"
			% InimigoBase.MAX_APRIMORAMENTOS)

	# A MORDIDA: com o campo vazio a briga some. E o estado em que o codigo
	# estaria se `aprimoramentos_incompativeis` nunca fosse lido -- se este caso
	# passasse dos dois jeitos, ele nao estaria medindo nada.
	briguenta.aprimoramentos_incompativeis = []
	ok(not inimigo.aprimoramento_incompativel(briguenta),
		"com o campo VAZIO o conflito desaparece -- o portao acusaria o campo morto")
	inimigo.free()

	# O OUTRO SENTIDO: quem proibe e a classe JA pendurada. Sao dois `if`
	# diferentes na mesma varredura, e cobrar um so deixaria metade da regra sem
	# dono.
	var outro := _nascer()
	if outro == null:
		return
	var dona := DadosAprimoramento.new()
	dona.id = &"teste_dona"
	dona.aprimoramentos_incompativeis = [&"teste_neutra"]
	ok(outro.aplicar_aprimoramento(dona), "a dona entra")
	ok(outro.aprimoramento_incompativel(neutra),
		"e ela proibe a neutra, que nao declara nada sobre ninguem")
	outro.free()


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


## A REGUA DE "DUAS SEGUIDAS" MORDE, e ela e conferida ANTES de medir o andar.
##
## O portao do cooldown responde "quantas vezes duas salas com classe cairam
## coladas". Uma regua quebrada responde ZERO para tudo -- e zero e exatamente o
## que o andar CERTO tambem responde. Sem este caso o portao do cooldown seria um
## carimbo: passaria com a regua contando errado e com o cooldown desligado do
## mesmo jeito.
func _o_contador_de_seguidas_morde() -> void:
	igual(_seguidas([true, false, true, false, true]), 0,
		"alternado nao tem nenhuma colada")
	igual(_seguidas([true, true, false]), 1, "duas coladas contam uma")
	igual(_seguidas([true, true, true]), 2, "tres coladas contam duas")
	igual(_seguidas([false, false]), 0, "e sem classe nenhuma nao ha o que contar")


## O ENCONTRO: quanto de um andar traz Unidade Aprimorada (#275).
##
## **A chance mora no TIPO e a taxa medida e OUTRO numero.** `tipo_combate.tres`
## declara 0,25 por sala, mas o que o jogador encontra sai de tres filtros
## somados: o sorteio, o cooldown de `salas_sem_aprimorada_depois` e o orcamento
## -- uma sala pequena demais para pagar `custo_ameaca` e ainda sobrar corpo
## recusa a classe. Chance por sala e frequencia percebida nao sao o mesmo
## numero, e este portao existe para o segundo ter um valor MEDIDO em vez de uma
## suposicao.
##
## Ele mede quatro coisas de uma vez, montando andares de verdade: a fracao, o
## teto de uma por sala, os tipos proibidos e o cooldown.
func _a_taxa_de_aprimorada_por_andar() -> void:
	var tipo := load(TIPO_COMBATE) as DadosSala
	ok(tipo != null, "o tipo de combate carrega")
	if tipo == null:
		return

	var sorteaveis := 0
	var elegiveis := 0
	var barradas := 0
	var com_classe := 0
	var proibidas_com_classe := 0
	var coladas_no_sorteio := 0
	var coladas_por_distancia := 0
	var andares := 0
	var por_andar: Array[int] = []

	for i in ANDARES:
		var mapa := _montar_andar(9100 + i * 37)
		if mapa == null:
			continue
		andares += 1

		# A ORDEM DO SORTEIO e a ordem em que `_sortear_composicoes()` percorre
		# `_salas`, e e sobre ela que o cooldown foi escrito. Medir so por
		# distancia deixaria o mecanismo real sem portao nenhum.
		var cadeia: Array[bool] = []
		var neste_andar := 0
		# O cooldown comeca LIBERADO em cada andar: `_sortear_composicoes()` poe
		# o contador acima do limite antes do laco, para a primeira sala nao
		# perder a chance sem motivo.
		var anterior_premiada := false
		for celula: Vector2i in mapa._salas:
			var dados := mapa.dados_da_celula(celula)
			if dados == null:
				continue
			var classe := _classe_da_celula(mapa, celula)
			if SEM_APRIMORADA.has(dados.id) and classe != null:
				proibidas_com_classe += 1
			if not dados.tem_combate():
				continue
			# O contador so avanca em quem CHEGA ao sorteio: sala sem grupo
			# valido sai de `_sortear_composicao()` antes de toca-lo.
			cadeia.append(classe != null)
			if dados.chance_de_aprimorada > 0.0:
				sorteaveis += 1
				# **ELEGIVEL e SORTEAVEL nao sao a mesma coisa**, e e essa
				# diferenca que separa a chance declarada da taxa que o jogador
				# encontra: uma sala logo depois de uma premiada nem chega a
				# rolar o dado.
				if anterior_premiada:
					barradas += 1
				else:
					elegiveis += 1
				if classe != null:
					com_classe += 1
					neste_andar += 1
			anterior_premiada = classe != null
		por_andar.append(neste_andar)
		coladas_no_sorteio += _seguidas(cadeia)
		coladas_por_distancia += _seguidas(_cadeia_por_distancia(mapa))

		# UMA POR SALA, conferida onde ela de fato acontece: `_povoar()` poe a
		# classe em UM dos vivos e CONSOME o campo. Ler o campo do gerenciador
		# provaria apenas que ele guarda um objeto so.
		if i == 0:
			_uma_classe_por_sala(mapa)
		_descartar_andar()

	ok(andares >= 10, "montou %d andares de verdade" % andares)
	ok(sorteaveis > 0, "e eles tem %d salas de combate sorteaveis" % sorteaveis)
	if sorteaveis == 0:
		return

	igual(proibidas_com_classe, 0,
		"nenhuma sala inicial, de arma, de item, de Loja ou do chefe recebeu classe (%d)"
			% proibidas_com_classe)
	igual(coladas_no_sorteio, 0,
		"o cooldown de %d MORDE: nenhuma dupla colada na ordem do sorteio (%d)"
			% [_cooldown_declarado(), coladas_no_sorteio])

	# **O COOLDOWN TEM DE BARRAR ALGUEM.** Este e o outro lado de "nenhuma dupla
	# colada": com `salas_sem_aprimorada_depois = 0` nada ficaria colado por
	# acaso na maioria dos andares, e o portao acima passaria verde com o
	# cooldown desligado. Aqui ele so passa se salas de fato perderam a vez.
	ok(barradas > 0,
		"o cooldown barrou %d das %d salas sorteaveis -- sem isso o portao acima seria carimbo"
			% [barradas, sorteaveis])
	ok(elegiveis > 0, "e sobraram %d salas que chegaram a rolar o dado" % elegiveis)
	if elegiveis == 0:
		return

	var declarada := tipo.chance_de_aprimorada
	var bruta := float(com_classe) / float(elegiveis)
	var fracao := float(com_classe) / float(sorteaveis)
	var media := float(com_classe) / float(maxi(andares, 1))
	# **A MARGEM E DA AMOSTRA, e nao do gosto.** Sao poucas centenas de sorteios,
	# e uma faixa cravada em torno da chance declarada reprovaria o codigo certo
	# na primeira vez que alguem mexesse noutra coisa e movesse o RNG. Tres
	# desvios de uma binomial e o que separa "o sorteio nao le mais o `.tres`"
	# (bruta em 0 ou em 1) de ruido.
	var margem := 3.0 * sqrt(declarada * (1.0 - declarada) / float(elegiveis))
	entre(bruta, declarada - margem, declarada + margem,
		"o SORTEIO entrega a chance do .tres: %.1f%% das %d salas elegiveis (o tipo declara %.0f%%, margem de %.1f pontos)"
			% [bruta * 100.0, elegiveis, declarada * 100.0, margem * 100.0])

	# E O NUMERO DO ENCONTRO, que e o que a issue pede: chance por sala e
	# frequencia percebida nao sao o mesmo numero. O teto continua sendo a chance
	# declarada -- o cooldown so pode BAIXAR o que o jogador encontra, nunca
	# subir --, com a mesma margem amostral do sorteio.
	entre(fracao, declarada / (1.0 + declarada) * 0.70, declarada + margem,
		"a TAXA MEDIDA e %.1f%% das salas de combate (%d de %d em %d andares, %.2f aprimoradas por andar; o tipo declara %.0f%%)"
			% [fracao * 100.0, com_classe, sorteaveis, andares, media, declarada * 100.0])
	# A ordem do PERCURSO e relatada, nao cobrada: o cooldown foi escrito sobre a
	# ordem do sorteio, e cobrar aqui seria cobrar uma regra que ninguem
	# implementou -- se este numero deixar de ser zero, e assunto de design.
	ok(true, "coladas por DISTANCIA da entrada: %d em %d andares"
		% [coladas_por_distancia, andares])
	ok(true, "aprimoradas por andar: %s" % str(por_andar))


## UMA CLASSE POR SALA, medida no caminho que a aplica.
##
## `Sala._aprimorar_um_dos_vivos()` escolhe UM dos vivos por peso e zera o campo.
## Duas aprimoradas na mesma sala nao dariam erro nenhum -- dariam uma sala com o
## dobro da ameaca que o orcamento pagou.
func _uma_classe_por_sala(mapa: GerenciadorMapa) -> void:
	var alvo: Sala = null
	for celula: Vector2i in mapa._salas:
		if _classe_da_celula(mapa, celula) == null:
			continue
		if mapa.composicao_da_celula(celula).size() < 2:
			continue
		alvo = mapa._salas[celula]
		break
	ok(alvo != null, "o andar tem uma sala com classe e mais de um corpo para medir")
	if alvo == null:
		return

	alvo.ativar()
	var aprimorados := 0
	for vivo in alvo._vivos:
		var inimigo := vivo as InimigoBase
		if inimigo != null and inimigo.esta_aprimorado():
			aprimorados += 1
	igual(aprimorados, 1,
		"a sala nasce com exatamente UMA aprimorada entre %d corpos" % alvo._vivos.size())
	ok(alvo._aprimoramento == null,
		"e a classe foi CONSUMIDA -- reentrar nao aprimora um segundo")


# ------------------------------------------------------------- apoio --------

## Quantas vezes dois `true` aparecem colados. E a pergunta do cooldown escrita
## uma vez so, para os dois criterios de ordem usarem a MESMA regua.
func _seguidas(cadeia: Array[bool]) -> int:
	var quantas := 0
	for i in range(1, cadeia.size()):
		if cadeia[i] and cadeia[i - 1]:
			quantas += 1
	return quantas


## A mesma cadeia, na ordem em que o JOGADOR encontra as salas: distancia da
## entrada.
func _cadeia_por_distancia(mapa: GerenciadorMapa) -> Array[bool]:
	var distancias := mapa._distancias()
	var celulas: Array[Vector2i] = []
	for celula: Vector2i in mapa._salas:
		var dados := mapa.dados_da_celula(celula)
		if dados != null and dados.tem_combate():
			celulas.append(celula)
	celulas.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return int(distancias.get(a, 9999)) < int(distancias.get(b, 9999)))
	var cadeia: Array[bool] = []
	for celula in celulas:
		cadeia.append(_classe_da_celula(mapa, celula) != null)
	return cadeia


## A classe que o gerenciador entregou aquela celula. Ela vive na `Sala` ate o
## `_povoar()` consumi-la, entao ler daqui so vale ANTES de ativar a sala.
func _classe_da_celula(mapa: GerenciadorMapa, celula: Vector2i) -> DadosAprimoramento:
	var sala: Sala = mapa._salas.get(celula)
	if not is_instance_valid(sala):
		return null
	return sala._aprimoramento


## O cooldown sai da CENA, e nao de um numero escrito aqui: `main.tscn` e quem
## configura o gerenciador, e portao que crava numero envelhece na primeira
## sessao de tuning que o girar.
func _cooldown_declarado() -> int:
	var cena: PackedScene = load(MAIN)
	var estado := cena.get_state()
	for i in estado.get_node_count():
		if estado.get_node_name(i) != "GerenciadorMapa":
			continue
		for j in estado.get_node_property_count(i):
			if estado.get_node_property_name(i, j) == "salas_sem_aprimorada_depois":
				return int(estado.get_node_property_value(i, j))
	return 1


func _montar_andar(semente: int) -> GerenciadorMapa:
	seed(semente)
	var cena: PackedScene = load(MAIN)
	var main := cena.instantiate()
	Engine.get_main_loop().root.add_child(main)
	# O Player sai logo: o andar ja foi montado no `_ready`, e um boneco a mais
	# no grupo global "player" e o que ja fez outra suite medir a distancia ate o
	# jogador de OUTRO teste.
	var jogador := main.find_child("Player", true, false)
	if jogador != null:
		jogador.get_parent().remove_child(jogador)
		jogador.free()
	_raiz_do_andar = main
	return main.find_child("GerenciadorMapa", true, false) as GerenciadorMapa


func _descartar_andar() -> void:
	if _raiz_do_andar == null:
		return
	# A RAIZ inteira, e nao so o gerenciador: os inimigos que `ativar()` colocou
	# sao filhos da sala, e uma sala orfa deixaria todos eles no grupo global
	# "inimigo" para a proxima suite tropecar.
	Engine.get_main_loop().root.remove_child(_raiz_do_andar)
	_raiz_do_andar.free()
	_raiz_do_andar = null


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
