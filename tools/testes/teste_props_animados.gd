extends TesteBase
## PROPS QUE SE MEXEM, e o ORCAMENTO deles (AND1 02).
##
## A regra que o plano crava e curta: **se tudo se mover, nada parece
## importante.** Esta suite existe porque ela precisa ser executavel -- opiniao
## nao sobrevive a proxima pessoa que achar o ventilador bonito, e o que ela
## custa nao aparece no console: movimento no cenario compete com movimento de
## PROJETIL, e o projetil tem de ganhar sempre.
##
## Tres coisas se cobram, e as duas ultimas sao garantias geometricas em vez de
## intencoes:
##
## 1. O prop animado e declarado por DADO. Cena nova por prop e o modelo que o
##    `GerenciadorMapa` ja teve e perdeu por nao escalar.
## 2. O teto por sala existe e MORDE.
## 3. Eles desenham abaixo de `Sala.Z_MUNDO`, entao nao ha como um deles cair na
##    frente de um telegrafo ou de um projetil.

const CENA_SALA := preload("res://src/mapa/sala_1_retangular.tscn")
const ATLAS := preload("res://assets/texturas/props_atlas.png")

## Longe da origem, como as outras suites que montam sala.
const LONGE := Vector2(14000.0, 14000.0)


func nome() -> String:
	return "PropsAnimados"


func executar() -> void:
	_o_teto_por_sala_morde()
	_eles_desenham_abaixo_do_mundo()
	_o_relogio_e_de_parede_e_nao_do_jogo()
	_cada_um_comeca_numa_fase()
	_prop_animado_e_declarado_por_dado()


## O TETO. Ele existe, e ele MORDE.
##
## Um teto que nunca e alcancado e um teto que nunca foi testado -- por isso o
## caso pede mais props do que o teto permite e conta o que a sala montou.
func _o_teto_por_sala_morde() -> void:
	for teto in [0, 1, 2, 5]:
		var sala := _montar(teto)
		var animados := _animados(sala)
		ok(
			animados <= teto,
			"com teto %d a sala monta no maximo %d prop(s) animado(s) -- montou %d"
				% [teto, teto, animados]
		)
		if teto > 0:
			ok(animados > 0, "e com teto %d ela monta ao menos um" % teto)
		else:
			igual(animados, 0, "teto zero nao monta nenhum, e nem cria a raiz a toa")
		sala.free()

	# O default do projeto e BAIXO de proposito: dois pontos de movimento ja dao
	# vida a uma sala, e o quarto ja e ruido -- e ruido perto de um telegrafo e
	# uma morte que o jogador nao consegue explicar.
	var padrao := DadosSala.new()
	ok(padrao.max_props_animados <= 3,
		"o teto padrao e baixo (%d): a sala nao pode virar um mural de movimento"
			% padrao.max_props_animados)


## A FAIXA. Abaixo de `Z_MUNDO`, sempre.
##
## Zero e onde ficam telegrafo, projetil e atores. Um prop animado ali poderia
## cair na frente do aviso que torna um ataque justo, e nao ha erro no console
## para "o aviso existe mas ficou coberto". Ficar embaixo e o que torna isto uma
## garantia e nao uma intencao.
func _eles_desenham_abaixo_do_mundo() -> void:
	var sala := _montar(3)
	var raiz := sala.get_node_or_null("DecoracaoAnimada") as Node2D
	ok(raiz != null, "a sala monta a camada dos props animados")
	if raiz != null:
		igual(raiz.z_index, Sala.Z_CHAO_DETALHE, "e ela fica na faixa do detalhe de chao")
		ok(raiz.z_index < Sala.Z_MUNDO,
			"abaixo do mundo -- e por isso nenhum deles cobre telegrafo ou projetil")
		for filho in raiz.get_children():
			igual((filho as CanvasItem).z_index, 0,
				"nenhum prop levanta a propria faixa acima da da camada")
	sala.free()


## O relogio e de PAREDE, e nao o do jogo.
##
## O hitstop congela o combate de proposito, mexendo em `Engine.time_scale`. Um
## ventilador que trava junto denuncia o truque: o jogador ve o mundo inteiro
## parar e entende que aquilo e um efeito, e nao um impacto. E a mesma razao pela
## qual `Juice.INTERVALO_HITSTOP` e `InimigoBase.INTERVALO_FLASH` tambem sao
## medidos em relogio de parede.
func _o_relogio_e_de_parede_e_nao_do_jogo() -> void:
	var prop := PropAnimado.new()
	Engine.get_main_loop().root.add_child(prop)
	prop.position = LONGE
	prop.configurar(ATLAS, Rect2i(0, 0, 32, 32), 4, 1000.0, 0)

	# Com fps altissimo, alguns ms de relogio de parede ja bastam para o quadro
	# andar -- e o teste nao depende de frames do jogo passarem.
	var comecou := prop.quadro_atual()
	var mudou := false
	var inicio := Time.get_ticks_msec()
	while Time.get_ticks_msec() - inicio < 40:
		mudou = mudou or prop.quadro_atual() != comecou
	ok(mudou, "o quadro anda com o relogio de PAREDE, sem depender do frame do jogo")

	# E o quadro nunca sai da fita, que e o defeito silencioso do `hframes`
	# desalinhado: o Sprite mostra uma fatia cortada e nada aponta para a cena.
	var fora := false
	for _i in 200:
		var q := prop.quadro_atual()
		fora = fora or q < 0 or q >= prop.quadros
	ok(not fora, "e nunca indexa fora da fita")

	prop.free()

	# E a fonte confirma de onde o tempo vem: um `delta` do `_process` seria
	# escalado pelo `time_scale` do hitstop, e o defeito e invisivel num teste
	# que roda com o jogo em velocidade normal.
	var fonte := FileAccess.get_file_as_string("res://src/mapa/prop_animado.gd")
	ok(fonte.contains("Time.get_ticks_msec()"),
		"o prop le o relogio de parede, e nao o delta do jogo")


## Cada prop comeca numa fase propria.
##
## Dois ventiladores em fase batem juntos e leem como um efeito ligado por
## script, e nao como duas maquinas independentes. E a mesma razao pela qual as
## Sentinelas nascem com o contador de rajada sorteado.
func _cada_um_comeca_numa_fase() -> void:
	var fases := {}
	for semente in 16:
		var sala := _montar(3, semente)
		var raiz := sala.get_node_or_null("DecoracaoAnimada")
		if raiz != null:
			for filho in raiz.get_children():
				fases[(filho as PropAnimado).quadro_inicial] = true
		sala.free()
	ok(fases.size() >= 2,
		"os props nao comecam todos no mesmo quadro (%d fases vistas)" % fases.size())


## Declarado por DADO: uma regiao a mais na lista, e nada de cena nova.
func _prop_animado_e_declarado_por_dado() -> void:
	var dados := DadosSala.new()
	ok("regioes_props_animados" in dados, "o tipo de sala declara as fitas animadas")
	ok("quadros_props_animados" in dados, "e quantos quadros cada uma tem")
	ok("fps_props_animados" in dados, "e a cadencia delas")
	ok("max_props_animados" in dados, "e o teto de quantas rodam juntas")

	# Nao ha cena por prop: a sala instancia `PropAnimado` em codigo, a partir do
	# atlas que ela ja usa para os chapados.
	var fonte := FileAccess.get_file_as_string("res://src/mapa/sala.gd")
	ok(fonte.contains("PropAnimado.new()"),
		"a sala monta o prop em codigo, a partir do dado -- sem cena por prop")


# ------------------------------------------------------------- montagem -----

## Uma sala com um tipo sintetico: fitas animadas apontando para o atlas real.
##
## Sintetico e nao um `tipo_*.tres` de verdade porque a ARTE animada ainda nao
## existe (ela e a AND1 03/04). O mecanismo precisa estar de pe antes dela --
## produzir fitas de ventilador sem saber quem as toca daria quadros que ninguem
## sabe rodar, que e exatamente o que a issue pede para evitar.
func _montar(teto: int, semente: int = 0) -> Sala:
	var dados := DadosSala.new()
	dados.atlas_props = ATLAS
	dados.regioes_props_animados = [
		Rect2i(0, 0, 32, 32), Rect2i(0, 32, 32, 32), Rect2i(0, 64, 32, 32),
	]
	dados.quadros_props_animados = 4
	dados.fps_props_animados = 6.0
	dados.max_props_animados = teto

	var sala: Sala = CENA_SALA.instantiate()
	# ANTES do add_child, como o GerenciadorMapa faz: o `_ready` da sala e quem
	# monta a decoracao, e depois dele o dado ja nao muda nada.
	sala.definir_visual(dados)
	sala.coordenadas_grid = Vector2i(semente, 0)
	sala.position = LONGE
	Engine.get_main_loop().root.add_child(sala)
	return sala


func _animados(sala: Sala) -> int:
	var raiz := sala.get_node_or_null("DecoracaoAnimada")
	return raiz.get_child_count() if raiz != null else 0
