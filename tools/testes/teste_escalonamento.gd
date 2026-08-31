extends TesteBase
## ESCALONAMENTO POR COMPORTAMENTO (INIM 09).
##
## A Deterioracao ja multiplicava velocidade, cadencia e velocidade de projetil.
## Isso e planilha: o mesmo padrao, mais rapido. O que esta suite cobra e o
## outro escalonamento -- o padrao mudando de FORMA. O anel do Drone passa de 8
## bracos para 12, e o vao cai de 45 graus para 30; a Sentinela raja mais vezes;
## a investida da Cyber-Besta fica mais longa enquanto a janela de punicao
## encolhe; o Parasita segura mais chao.
##
## E cobra a TRAVA que sustenta tudo isso: **o telegrafo encurta com a
## dificuldade, mas nunca some.** E a fronteira entre "dificil" e "mente sobre a
## propria regra", e ela nao da erro no console quando cai -- o inimigo continua
## atacando, so que sem aviso legivel. A Diretora ja crava o piso em
## `TELEGRAFO_MINIMO` e o `teste_diretora.gd` o defende; aqui o mesmo piso vale
## para os outros cinco.
##
## O varrimento e por toda a faixa da barra, e nao so nas pontas: um piso
## aplicado com `if valor > 90` passaria num teste de 0 e 100 e falharia no meio.

const CENAS := {
	"drone_aranha": "res://src/enemies/drone_aranha.tscn",
	"atirador_neon": "res://src/enemies/atirador_neon.tscn",
	"cyber_besta": "res://src/enemies/cyber_besta.tscn",
	"sentinela_orbital": "res://src/enemies/sentinela_orbital.tscn",
	"hacker_parasita": "res://src/enemies/hacker_parasita.tscn",
}

## O telegrafo de cada um: o `@export` de onde a duracao sai.
const TELEGRAFOS := {
	"drone_aranha": "tempo_carga",
	"atirador_neon": "tempo_mira",
	"cyber_besta": "tempo_preparo",
	"sentinela_orbital": "tempo_clarao",
	"hacker_parasita": "tempo_semear",
}

## A tabela de ameaca do epico INIM. Custo no orcamento da sala, por inimigo.
const AMEACA := {
	"grupo_drone_aranha": 1,
	"grupo_cyber_besta": 2,
	"grupo_sentinela_orbital": 2,
	"grupo_atirador_neon": 3,
	"grupo_hacker_parasita": 3,
}

## Longe da origem, como as outras suites que instanciam inimigo.
const LONGE := Vector2(61000.0, 61000.0)

var _barra_original: float = 0.0


func nome() -> String:
	return "Escalonamento"


func executar() -> void:
	_barra_original = Deterioracao.valor
	_o_telegrafo_encurta_mas_nunca_some()
	_o_padrao_muda_de_forma()
	_o_escalonar_e_monotono_e_desligavel()
	_os_custos_batem_com_a_tabela_de_ameaca()
	Deterioracao.valor = _barra_original


## A TRAVA. Nenhum inimigo avisa por menos que o piso, em nenhum valor da barra.
##
## Varre a faixa inteira de 0 a 100 de 5 em 5: um piso escrito como
## `if valor > 90` passaria testando so as pontas e falharia justamente na faixa
## onde o jogador passa a maior parte da run.
func _o_telegrafo_encurta_mas_nunca_some() -> void:
	var piso := Telegrafo.DURACAO_MINIMA
	for id in CENAS:
		var inimigo := _nascer(id)
		var campo: String = TELEGRAFOS[id]
		var base: float = inimigo.get(campo)

		Deterioracao.valor = 0.0
		var na_barra_vazia: float = inimigo.duracao_do_telegrafo(base)
		var menor := na_barra_vazia
		var furou := false
		var passo := 0.0
		while passo <= 100.0:
			Deterioracao.valor = passo
			var agora: float = inimigo.duracao_do_telegrafo(base)
			furou = furou or agora < piso - 0.0001
			menor = minf(menor, agora)
			passo += 5.0

		ok(not furou, "%s: o aviso nunca cai abaixo de %.2f s, em toda a faixa da barra" % [id, piso])
		ok(
			menor < na_barra_vazia or is_equal_approx(na_barra_vazia, piso),
			"%s: e ELE ENCURTA com a barra (%.2f s -> %.2f s)" % [id, na_barra_vazia, menor]
		)
		ok(menor > 0.0, "%s: e nunca chega a zero -- ataque sem aviso e dano vindo do nada" % id)
		inimigo.free()

	# E o piso e o MESMO que a Diretora crava. Dois numeros diferentes para a
	# mesma regra divergiriam na primeira vez que alguem mexesse num deles -- e a
	# metade que continuasse certa esconderia a que quebrou.
	var chefe := preload("res://src/enemies/diretora.tscn").instantiate()
	chefe.position = LONGE
	Engine.get_main_loop().root.add_child(chefe)
	perto(Telegrafo.DURACAO_MINIMA, chefe.TELEGRAFO_MINIMO,
		"o piso dos inimigos e o mesmo que a Diretora crava")
	chefe.free()


## O padrao muda de FORMA, e nao so de planilha.
func _o_padrao_muda_de_forma() -> void:
	# Drone Aranha: o anel fecha. 8 bracos tem vao de 45 graus; 12 tem 30.
	var drone := _nascer("drone_aranha")
	Deterioracao.valor = 0.0
	var bracos_inicio: int = drone._projeteis_agora()
	var setor_inicio: float = drone._setor_do_anel()
	Deterioracao.valor = 100.0
	var bracos_fim: int = drone._projeteis_agora()
	var setor_fim: float = drone._setor_do_anel()
	ok(bracos_fim > bracos_inicio,
		"o anel do Drone ganha bracos (%d -> %d)" % [bracos_inicio, bracos_fim])
	ok(setor_fim < setor_inicio,
		"e o vao entre eles FECHA (%.0f graus -> %.0f), que e o que muda a leitura"
			% [setor_inicio, setor_fim])
	drone.free()

	# Sentinela: a rajada fica mais frequente.
	var sentinela := _nascer("sentinela_orbital")
	Deterioracao.valor = 0.0
	var espera_inicio: int = sentinela._tiros_ate_rajada_agora()
	Deterioracao.valor = 100.0
	var espera_fim: int = sentinela._tiros_ate_rajada_agora()
	ok(espera_fim < espera_inicio,
		"a Sentinela raja mais vezes (%d tiros unicos antes -> %d)" % [espera_inicio, espera_fim])
	ok(espera_fim > 0,
		"mas a rajada continua sendo a EXCECAO que quebra o ritmo, e nao o ritmo (%d)" % espera_fim)
	sentinela.free()

	# Cyber-Besta: a investida cresce enquanto a punicao encolhe.
	var besta := _nascer("cyber_besta")
	Deterioracao.valor = 0.0
	var investida_inicio: float = besta._duracao_da_investida()
	var punicao_inicio: float = besta._tempo_de_recuperacao()
	Deterioracao.valor = 100.0
	var investida_fim: float = besta._duracao_da_investida()
	var punicao_fim: float = besta._tempo_de_recuperacao()
	ok(investida_fim > investida_inicio,
		"a investida da Cyber-Besta fica mais LONGA (%.2f s -> %.2f)"
			% [investida_inicio, investida_fim])
	perto(besta.velocidade_investida, 720.0,
		"e nao mais rapida: velocidade maior encurtaria a janela de leitura que o agachamento abriu", 0.01)
	ok(punicao_fim < punicao_inicio,
		"e a janela de punicao ENCOLHE (%.2f s -> %.2f)" % [punicao_inicio, punicao_fim])
	ok(punicao_fim > 0.3,
		"mas nao some: acertar a esquiva tem de continuar rendendo (%.2f s)" % punicao_fim)
	besta.free()

	# Hacker Parasita: mais chao negado, com o teto ainda existindo.
	var hacker := _nascer("hacker_parasita")
	Deterioracao.valor = 0.0
	var areas_inicio: int = hacker._max_areas_agora()
	Deterioracao.valor = 100.0
	var areas_fim: int = hacker._max_areas_agora()
	ok(areas_fim > areas_inicio,
		"o Parasita segura mais chao (%d area -> %d)" % [areas_inicio, areas_fim])
	ok(
		areas_fim <= 3,
		"e o TETO continua valendo (%d): sem ele, tres Parasitas cobrem a sala e o jogador"
			% areas_fim
			+ " fica sem lugar para estar -- isso e um cronometro, nao um inimigo"
	)
	hacker.free()


## O verbo do escalonamento: monotono, e DESLIGAVEL por default.
##
## Negativo desligando importa mais do que parece: e o que faz o Rastejante, o
## Vigia e todo inimigo futuro que nao declare nada continuarem exatamente como
## eram. Um default de zero teria virado "escalona para zero" em silencio.
func _o_escalonar_e_monotono_e_desligavel() -> void:
	Deterioracao.valor = 50.0
	perto(Deterioracao.escalonar(10.0, -1.0), 10.0, "avancado negativo desliga o escalonamento")
	igual(Deterioracao.escalonar_int(8, -1), 8, "e vale igual para contagem")
	perto(Deterioracao.escalonar(10.0, 20.0), 15.0, "no meio da barra, o valor esta no meio")
	igual(Deterioracao.escalonar_int(3, 1), 2, "e a contagem arredonda uma vez so, no fim")

	Deterioracao.valor = 0.0
	perto(Deterioracao.escalonar(10.0, 20.0), 10.0, "barra vazia entrega o valor INICIAL")
	Deterioracao.valor = 100.0
	perto(Deterioracao.escalonar(10.0, 20.0), 20.0, "barra cheia entrega o AVANCADO")

	# Zero e um valor valido de destino, e por isso o sentinela e -1.
	Deterioracao.valor = 100.0
	igual(Deterioracao.escalonar_int(3, 0), 0, "zero e um destino VALIDO, nao um desligamento")

	# Monotono na faixa inteira: um degrau para tras faria o inimigo ficar mais
	# facil no meio da run, e ninguem procuraria por isso.
	var anterior := -1.0
	var caiu := false
	var passo := 0.0
	while passo <= 100.0:
		Deterioracao.valor = passo
		var agora := Deterioracao.escalonar(10.0, 20.0)
		caiu = caiu or agora < anterior
		anterior = agora
		passo += 2.5
	ok(not caiu, "o escalonamento nunca anda para tras no meio da barra")

	# O multiplicador de telegrafo tambem: sempre menor ou igual a 1, e caindo.
	Deterioracao.valor = 0.0
	perto(Deterioracao.multiplicador_telegrafo(), 1.0, "barra vazia nao encurta aviso nenhum")
	Deterioracao.valor = 100.0
	ok(Deterioracao.multiplicador_telegrafo() < 1.0, "barra cheia encurta")
	ok(Deterioracao.multiplicador_telegrafo() > 0.0, "e nunca inverte o sinal")


## Os custos batem com a tabela de ameaca do epico.
##
## O `custo` e o que faz "sala mais dificil" nao ser "sala mais cheia": um
## inimigo de custo 3 ocupa o lugar de tres de custo 1, entao a mesma sala
## recebe menos corpos e mais perigo por corpo. Com todos custando igual, o
## orcamento so mexeria em quantidade.
func _os_custos_batem_com_a_tabela_de_ameaca() -> void:
	for arquivo in AMEACA:
		var grupo: GrupoInimigo = load("res://src/enemies/%s.tres" % arquivo)
		if grupo == null:
			ok(false, "%s.tres foi carregado" % arquivo)
			continue
		igual(grupo.custo, AMEACA[arquivo],
			"%s custa o que a tabela de ameaca diz" % arquivo)
		ok(grupo.custo_real() >= 1,
			"e o piso de custo_real() vale -- custo zero giraria o sorteio para sempre")


func _nascer(id: String) -> Node:
	var no: Node = (load(CENAS[id]) as PackedScene).instantiate()
	no.position = LONGE
	Engine.get_main_loop().root.add_child(no)
	return no
