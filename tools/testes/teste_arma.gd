extends TesteBase
## Verifica que um tiro coloca na tela a quantidade de projeteis que promete.
##
## Esta suite nasceu de um bug que passou despercebido por meses: o anel da
## Diretora percorria 20 direcoes chamando `atirar()` e saia UM projetil,
## porque `atirar()` arma o cooldown de cadencia e `pode_atirar()` recusa o
## resto do frame -- o `_process` que decrementa esse cooldown so roda ENTRE
## frames, nunca no meio de um for.
##
## Nada no jogo acusava isso: sem erro no console, sem falha no teste de fumaca
## (que exercita o chefe mas nao conta projeteis). So olhando a tela.
##
## Por isso o que se afirma aqui e sempre a CONTAGEM, nunca "a funcao devolveu
## true".

const DIRECOES_DA_SALVA := 12


func nome() -> String:
	return "Arma"


func executar() -> void:
	_o_laco_antigo_nao_funciona()
	_salva_dispara_tudo()
	_salva_respeita_a_cadencia()
	_salva_gasta_uma_bala_so()
	_salva_vazia_nao_faz_nada()
	_leque_continua_inteiro()


# ------------------------------------------------------------ montagem ------

## Uma Arma pronta para atirar, com um container proprio no grupo que
## `Arma._container()` procura. Sem container na arvore os projeteis iriam para
## a cena atual e nao daria para conta-los.
func _montar() -> Dictionary:
	var raiz := Node2D.new()
	var container := Node2D.new()
	container.add_to_group("container_projeteis")
	raiz.add_child(container)

	var arma := Arma.new()
	arma.hostil = true
	raiz.add_child(arma)

	# A cena principal e o pai de todo mundo aqui: e ela que o
	# get_tree().get_first_node_in_group() enxerga.
	Engine.get_main_loop().root.add_child(raiz)

	var dados := DadosArma.new()
	dados.cadencia = 8.0
	dados.projeteis_por_tiro = 1
	dados.impressao_graus = 0.0
	dados.tamanho_pente = 99
	dados.municao_maxima = -1
	arma.equipar(dados)

	return {"raiz": raiz, "arma": arma, "container": container, "dados": dados}


func _desmontar(ctx: Dictionary) -> void:
	var raiz: Node2D = ctx["raiz"]
	raiz.get_parent().remove_child(raiz)
	raiz.free()


func _contar(ctx: Dictionary) -> int:
	var container: Node2D = ctx["container"]
	return container.get_child_count()


func _direcoes(quantidade: int) -> Array[Vector2]:
	return Balistica.anel(quantidade)


# --------------------------------------------------------------- casos ------

## Prova o bug que originou tudo, e por isso e o primeiro caso: chamar atirar()
## em laco NAO dispara o laco inteiro.
##
## Existe como assercao permanente por dois motivos. Primeiro, uma suite que so
## verifica o caminho certo nunca demonstra o problema que ela veio resolver.
## Segundo, e o guarda contra alguem "simplificar" atirar_varias() de volta para
## um for de atirar() -- o codigo pareceria equivalente, compilaria, e o anel do
## chefe voltaria a sair com um projetil.
func _o_laco_antigo_nao_funciona() -> void:
	var ctx := _montar()
	var arma: Arma = ctx["arma"]

	for d in _direcoes(DIRECOES_DA_SALVA):
		arma.atirar(d)

	igual(
		_contar(ctx),
		1,
		"o laco de atirar() so dispara UMA vez por frame -- e por isso que atirar_varias existe"
	)

	_desmontar(ctx)


## A asserção central: N direcoes, N projeteis, num frame so. E esta que falha
## com o bug original.
func _salva_dispara_tudo() -> void:
	var ctx := _montar()
	var arma: Arma = ctx["arma"]

	ok(arma.atirar_varias(_direcoes(DIRECOES_DA_SALVA)), "a salva e aceita")
	igual(
		_contar(ctx),
		DIRECOES_DA_SALVA,
		"a salva coloca um projetil por direcao no mesmo frame"
	)

	_desmontar(ctx)


## A cadencia continua valendo para a salva INTEIRA -- ela nao virou passe
## livre. Sem isto, um chamador descuidado dispararia um anel por frame.
func _salva_respeita_a_cadencia() -> void:
	var ctx := _montar()
	var arma: Arma = ctx["arma"]

	arma.atirar_varias(_direcoes(4))
	var depois_da_primeira := _contar(ctx)

	ok(not arma.atirar_varias(_direcoes(4)), "a segunda salva do mesmo frame e recusada")
	igual(_contar(ctx), depois_da_primeira, "a salva recusada nao criou projetil nenhum")

	_desmontar(ctx)


## Uma salva e UM tiro: gasta uma bala, nao uma por projetil. Mesmo contrato da
## shotgun, que gasta uma bala para oito bagos.
func _salva_gasta_uma_bala_so() -> void:
	var ctx := _montar()
	var arma: Arma = ctx["arma"]
	var antes := arma.municao_pente

	arma.atirar_varias(_direcoes(DIRECOES_DA_SALVA))
	igual(arma.municao_pente, antes - 1, "a salva gasta uma bala do pente, nao uma por projetil")

	_desmontar(ctx)


func _salva_vazia_nao_faz_nada() -> void:
	var ctx := _montar()
	var arma: Arma = ctx["arma"]
	var antes := arma.municao_pente
	var vazio: Array[Vector2] = []

	ok(not arma.atirar_varias(vazio), "salva sem direcao devolve false")
	igual(_contar(ctx), 0, "salva sem direcao nao cria projetil")
	igual(arma.municao_pente, antes, "salva sem direcao nao gasta bala")

	_desmontar(ctx)


## Guarda de regressao da refatoracao: atirar() e atirar_varias() passaram a
## compartilhar codigo, entao o leque da shotgun tem de continuar inteiro.
func _leque_continua_inteiro() -> void:
	var ctx := _montar()
	var arma: Arma = ctx["arma"]
	var dados: DadosArma = ctx["dados"]
	dados.projeteis_por_tiro = 8
	dados.abertura_graus = 34.0

	ok(arma.atirar(Vector2.RIGHT), "o tiro comum e aceito")
	igual(_contar(ctx), 8, "atirar() continua criando projeteis_por_tiro projeteis")

	_desmontar(ctx)
