extends TesteBase
## O SUBTEMA de sala: ele existe, ele sai de dados, e ele MORDE a face.
##
## O tema e a unica peca do andar que responde "esta fabrica tinha organizacao
## interna?". As outras -- textura, prop, decalque -- respondem por trecho, e um
## andar inteiro de trechos bem resolvidos continua sendo decoracao aleatoria.
##
## Tres coisas podem quebrar em SILENCIO aqui, e cada uma tem um caso:
##
##   - **o tema nomear um modulo que nao existe.** `TemaDeSala` acha o favorito
##     por SUFIXO de arquivo; um `modulo_favorito` com erro de digitacao devolve
##     `null`, `aplicar()` desiste e a sala veste a face de sempre. Nada no
##     console.
##   - **o tema nao chegar a sala.** Ele e entregue antes do `add_child`, como
##     `definir_visual()`; entregue depois, ele fica guardado e nunca desenhado.
##   - **um tema dominar o sorteio.** Seis temas de que so dois aparecem sao dois
##     temas com quatro arquivos.

const CENA := preload("res://src/mapa/sala_1_retangular.tscn")
const PASTA := "res://src/mapa"

## Longe da origem, como as outras suites que sobem nos.
const LONGE := Vector2(33000.0, 33000.0)

## Quantos sorteios a varredura de distribuicao faz.
##
## A issue pede "120 andares". Um andar sorteia um tema por sala e tem dez salas,
## entao 1200 sorteios cobrem a mesma amostra sem montar 120 grafos -- e o que se
## mede aqui e o SORTEIO, que nao depende do resto da montagem.
const SORTEIOS := 1200

## Nenhum tema pode passar disto da amostra.
##
## Com seis temas de peso parecido a esperanca fica em 17%; 30% deixa folga larga
## para os pesos serem ajustados sem o portao reclamar, e ainda pega o caso que
## importa -- um peso digitado com um zero a mais.
const DOMINIO_MAXIMO := 0.30

## E nenhum pode sumir: piso de metade da esperanca uniforme.
const PISO_DE_PRESENCA := 0.08


func nome() -> String:
	return "Tema de sala"


func executar() -> void:
	_os_temas_existem_e_estao_na_cena()
	_todo_favorito_nomeado_existe_em_disco()
	_nenhum_tema_domina_e_nenhum_some()
	_o_tema_MORDE_a_face_que_a_sala_veste()
	_sala_sem_tema_continua_funcionando()


func _temas_em_disco() -> Array[TemaDeSala]:
	var lista: Array[TemaDeSala] = []
	var pasta := DirAccess.open(PASTA)
	if pasta == null:
		return lista
	var nomes := pasta.get_files()
	nomes.sort()
	for arquivo in nomes:
		if not arquivo.begins_with("tema_") or not arquivo.ends_with(".tres"):
			continue
		var tema := load("%s/%s" % [PASTA, arquivo]) as TemaDeSala
		if tema != null:
			lista.append(tema)
	return lista


## Os temas em disco sao os temas que o jogo carrega.
##
## Varre a pasta em vez de listar seis nomes: lista fixa aqui teria o mesmo
## defeito que a `AUTORADAS` do teste de texturas ja teve -- tema novo fora dela
## nao seria conferido por nada.
func _os_temas_existem_e_estao_na_cena() -> void:
	var disco := _temas_em_disco()
	ok(disco.size() >= 6, "a varredura achou os temas em disco (%d)" % disco.size())

	var cena := load("res://src/main/main.tscn") as PackedScene
	var main := cena.instantiate()
	var gerenciador := main.find_child("GerenciadorMapa", true, false) as GerenciadorMapa
	ok(gerenciador != null, "main.tscn tem o GerenciadorMapa")
	if gerenciador != null:
		igual(gerenciador.temas.size(), disco.size(),
			"todo tema em disco esta na lista do gerenciador (%d de %d)"
				% [gerenciador.temas.size(), disco.size()])
		var ids := {}
		for tema in gerenciador.temas:
			if tema != null:
				ids[tema.id] = true
		for tema in disco:
			ok(ids.has(tema.id), "o tema %s esta na cena" % tema.id)
	main.free()


## Todo `modulo_favorito` nomeado resolve numa textura de verdade.
##
## E o caso que a busca por sufixo torna necessario. `aplicar()` devolve a lista
## intacta quando nao acha, entao um nome errado nao quebra nada -- ele apenas
## faz o tema deixar de existir, e a sala continua bonita.
func _todo_favorito_nomeado_existe_em_disco() -> void:
	var dados := load("res://src/mapa/tipo_combate.tres") as DadosSala
	ok(dados != null and not dados.texturas_face.is_empty(),
		"o tipo de combate declara faces para o tema escolher")
	if dados == null:
		return
	var com_favorito := 0
	for tema in _temas_em_disco():
		if tema.modulo_favorito == &"":
			continue
		com_favorito += 1
		var antes := dados.texturas_face.duplicate()
		var depois := tema.aplicar(antes, dados.texturas_face)
		ok(depois.size() > antes.size(),
			"o favorito de %s (%s) foi achado e reforcado (%d -> %d)"
				% [tema.id, tema.modulo_favorito, antes.size(), depois.size()])
	ok(com_favorito >= 4,
		"ha temas com modulo favorito para conferir (%d)" % com_favorito)


func _nenhum_tema_domina_e_nenhum_some() -> void:
	var cena := load("res://src/main/main.tscn") as PackedScene
	var main := cena.instantiate()
	var gerenciador := main.find_child("GerenciadorMapa", true, false) as GerenciadorMapa
	if gerenciador == null:
		ok(false, "o gerenciador existe para sortear")
		main.free()
		return
	var conta := {}
	for tema in gerenciador.temas:
		if tema != null:
			conta[tema.id] = 0
	for i in SORTEIOS:
		var tema := gerenciador._sortear_tema()
		if tema != null:
			conta[tema.id] = int(conta[tema.id]) + 1
	for id: StringName in conta:
		var fracao := float(conta[id]) / float(SORTEIOS)
		entre(fracao, PISO_DE_PRESENCA, DOMINIO_MAXIMO,
			"o tema %s aparece sem dominar (%.1f%%)" % [id, fracao * 100.0])
	main.free()


## O tema tem de mudar o que a sala DESENHA, e nao so o que ela guarda.
##
## E o caso que pega a entrega pela metade: `definir_tema()` chamado depois do
## `add_child` compila, guarda o recurso e nao muda um pixel -- o `_ready` ja
## escolheu a face. A pergunta aqui e sobre a textura que esta na arvore.
##
## **O tema medido e `ventilacao`, e a escolha nao e arbitraria.** A primeira
## versao usou `manutencao`, e ela mediu 12 contra 11: quase nenhuma diferenca.
## O motivo e `faixa_progressiva` -- no primeiro terco do andar a lista de
## especiais tem UM elemento, e ele e justamente `tubulacao`, o favorito daquele
## tema. O teste comparava o tema com um sorteio que ja so tinha uma opcao, e a
## que o tema queria.
##
## `ventilada` e a ULTIMA da lista, entao ela esta fora do primeiro terco -- e e
## exatamente por isso que ela prova a peca que interessa: `aplicar()` recebe o
## catalogo INTEIRO e nao a fatia do terco, entao o favorito do tema aparece num
## terco que nao o incluiria. Sem essa decisao, um tema so teria efeito no terco
## do andar em que a sua face ja ia aparecer sozinha.
func _o_tema_MORDE_a_face_que_a_sala_veste() -> void:
	var dados := load("res://src/mapa/tipo_combate.tres") as DadosSala
	var tema := load("res://src/mapa/tema_ventilacao.tres") as TemaDeSala
	if dados == null or tema == null:
		ok(false, "o tipo de combate e o tema de ventilacao existem")
		return

	var com := 0
	var sem := 0
	var celulas := 12
	for i in celulas:
		com += _quads_do_favorito(dados, tema, Vector2i(i, i * 5))
		sem += _quads_do_favorito(dados, null, Vector2i(i, i * 5))
	igual(sem, 0,
		"sem tema, o modulo fora do terco corrente nao aparece (%d quads)" % sem)
	ok(com >= celulas,
		"com o tema, ele veste ao menos um lado de cada sala (%d quads em %d salas)"
			% [com, celulas])


## Quantos quads de FACE desta sala vestem o modulo favorito do tema.
##
## Conta quads e nao "achou/nao achou": os QUATRO lados desenham face desde que a
## regra do sul foi invertida, e cada um sorteia a sua. Uma resposta booleana
## satura -- com quatro sorteios independentes, "algum lado usou X" e quase
## sempre sim, e foi o que a primeira versao deste caso mediu.
func _quads_do_favorito(dados: DadosSala, tema: TemaDeSala, celula: Vector2i) -> int:
	var sala := CENA.instantiate() as Sala
	sala.coordenadas_grid = celula
	sala.definir_visual(dados)
	sala.definir_tema(tema)
	sala.position = LONGE
	Engine.get_main_loop().root.add_child(sala)
	var achados := 0
	var fita := sala.get_node_or_null("ParedeModulos") as Node2D
	if fita != null:
		for filho in fita.get_children():
			var poly := filho as Polygon2D
			if poly == null or poly.texture == null:
				continue
			if poly.texture.resource_path.ends_with("_ventilada.png"):
				achados += 1
	sala.free()
	return achados


## Sala sem tema continua vestindo parede.
##
## E o estado de toda sala aberta sozinha no editor, do prototipo do catalogo e
## de metade das suites -- e do Lobby, que nao passa pelo gerenciador. Um tema
## obrigatorio quebraria os tres sem uma linha no console.
func _sala_sem_tema_continua_funcionando() -> void:
	var dados := load("res://src/mapa/tipo_combate.tres") as DadosSala
	var sala := CENA.instantiate() as Sala
	sala.definir_visual(dados)
	sala.position = LONGE
	Engine.get_main_loop().root.add_child(sala)
	ok(sala.tema() == null, "sem tema definido, a sala nao tem tema")
	var fita := sala.get_node_or_null("ParedeModulos") as Node2D
	ok(fita != null and fita.get_child_count() >= 8,
		"e ela veste a parede assim mesmo (%d pecas)"
			% (fita.get_child_count() if fita != null else 0))
	sala.free()
