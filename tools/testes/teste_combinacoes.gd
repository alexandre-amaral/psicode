extends TesteBase
## A REGUA DE ESCAPE e as combinacoes declaradas (INIM 10).
##
## O arnes de combinacao roda em `tools/combinacoes/combinacoes.tscn` e leva
## minutos: ele precisa de tempo de RELOGIO, porque o Parasita leva mais de um
## segundo entre nascer e semear e a area dele vive quase 3,5 s. Isso nao cabe
## num runner de segundos.
##
## O que cabe aqui e a regua em si -- geometria pura --, e ela e a parte que
## pode mentir sem ninguem ver. **Uma regua quebrada passa VERDE**, e foi o que
## aconteceu na primeira versao desta: ela exigia a rota livre em todos os
## instantes do horizonte, entao quem estava DENTRO de um circulo de aviso nunca
## "escapava" -- e sair de dentro dele antes de estourar e literalmente a jogada
## que o telegrafo existe para permitir. O resultado foi reprovar as cinco
## combinacoes, inclusive as que nao tem como ser inevitaveis. Os casos abaixo
## sao essa licao virada teste.

const CENAS := [
	"res://src/enemies/drone_aranha.tscn",
	"res://src/enemies/atirador_neon.tscn",
	"res://src/enemies/cyber_besta.tscn",
	"res://src/enemies/sentinela_orbital.tscn",
	"res://src/enemies/hacker_parasita.tscn",
]

const TODAS := MedidorEscape.DIRECOES + 1


func nome() -> String:
	return "Combinacoes"


func executar() -> void:
	_campo_limpo_tem_todas_as_saidas()
	_ameaca_parada_pergunta_pelo_FIM_do_horizonte()
	_ameaca_em_movimento_pergunta_pelo_CAMINHO()
	_o_cerco_completo_e_a_situacao_inevitavel()
	_ficar_parado_conta_como_saida()
	_as_cinco_combinacoes_estao_declaradas()


## Sem ameaca nenhuma, toda direcao esta livre. O caso trivial existe para pegar
## a regua que reprova por construcao -- e ela ja existiu.
func _campo_limpo_tem_todas_as_saidas() -> void:
	var vazio: Array[Dictionary] = []
	igual(
		MedidorEscape.saidas_livres(Vector2.ZERO, 11.0, 330.0, vazio), TODAS,
		"campo limpo deixa todas as saidas livres"
	)
	ok(not MedidorEscape.inevitavel(Vector2.ZERO, 11.0, 330.0, vazio),
		"e campo limpo nunca e situacao inevitavel")


## A LICAO. Estar DENTRO de um aviso nao e uma sentenca.
##
## O circulo do Hacker fere num instante -- quando o aviso acaba --, entao o que
## importa e onde o jogador esta NO FIM do horizonte. Cobrar o caminho inteiro
## dizia "voce nao escapa" para quem esta dentro do circulo, que e o contrario do
## que o telegrafo promete: ele existe justamente para dar tempo de sair.
func _ameaca_parada_pergunta_pelo_FIM_do_horizonte() -> void:
	# O jogador esta DENTRO de um disco de aviso, quase no centro dele.
	var dentro: Array[Dictionary] = [_disco(Vector2(19.0, 0.0), 60.0)]
	var saidas := MedidorEscape.saidas_livres(Vector2.ZERO, 11.0, 330.0, dentro)
	ok(saidas > 0,
		"de dentro de um aviso ainda ha para onde correr (%d saidas) -- e para isso que o telegrafo existe"
			% saidas)
	ok(saidas < TODAS, "mas nao para todo lado: correr para o miolo continua sendo errado")
	ok(
		MedidorEscape.saidas_livres(Vector2.ZERO, 11.0, 0.0, dentro) == 0,
		"e quem nao anda nao sai: parado dentro do aviso nao ha saida"
	)

	# Um disco pequeno e longe nao tira saida nenhuma.
	var longe: Array[Dictionary] = [_disco(Vector2(600.0, 0.0), 60.0)]
	igual(MedidorEscape.saidas_livres(Vector2.ZERO, 11.0, 330.0, longe), TODAS,
		"aviso fora do alcance do passo nao tira saida")


## A ameaca em movimento fere no CONTATO, entao o caminho inteiro conta.
##
## O projetil que cruza a rota no meio do horizonte e sai antes do fim seria
## invisivel para uma conferencia so do fim -- e ele e justamente o que passa
## raspando.
func _ameaca_em_movimento_pergunta_pelo_CAMINHO() -> void:
	# Um projetil vindo da direita, rapido, mirado no jogador. Ele CRUZA a
	# posicao de quem corre para a direita, e ja passou dela no fim do horizonte.
	var tiro: Array[Dictionary] = [{
		"posicao": Vector2(300.0, 0.0),
		"velocidade": Vector2(-900.0, 0.0),
		"raio": 6.0,
		"tipo": "projetil",
	}]
	var saidas := MedidorEscape.saidas_livres(Vector2.ZERO, 11.0, 330.0, tiro)
	ok(saidas > 0, "da para sair da linha de um tiro (%d saidas)" % saidas)
	ok(saidas < TODAS, "mas correr para dentro dele nao vale -- o caminho conta, nao so o fim")

	# A prova de que o caminho conta: so o FIM do horizonte estaria livre.
	var so_o_fim := Vector2.RIGHT * 330.0 * MedidorEscape.HORIZONTE
	var onde_ele_estara := Vector2(300.0, 0.0) + Vector2(-900.0, 0.0) * MedidorEscape.HORIZONTE
	ok(
		so_o_fim.distance_to(onde_ele_estara) > 17.0,
		"no FIM do horizonte os dois ja se cruzaram e estao longe -- e por isso conferir so o fim mentiria"
	)


## O cerco completo: nenhuma direcao, e nem ficar parado, evita o dano.
##
## E a definicao do que o GDD proibe. A regua tem de saber dizer SIM aqui, senao
## ela e um carimbo -- uma regua que nunca reprova nada e pior que regua nenhuma,
## porque ela da a sensacao de cobertura.
func _o_cerco_completo_e_a_situacao_inevitavel() -> void:
	# Um ANEL de discos ainda deixa o miolo livre, e isso nao e detalhe de teste:
	# e a razao pela qual o teto de `max_areas` do Parasita importa. Enquanto os
	# circulos nao cobrem o centro, ficar parado continua sendo uma saida.
	var anel: Array[Dictionary] = []
	for i in 24:
		anel.append(_disco(Vector2.RIGHT.rotated(TAU * float(i) / 24.0) * 90.0, 70.0))
	igual(MedidorEscape.saidas_livres(Vector2.ZERO, 11.0, 330.0, anel), 1,
		"um anel de avisos ainda deixa o miolo: ficar parado e a unica saida")

	# Fechando o miolo, acaba a saida.
	var cerco := anel.duplicate()
	cerco.append(_disco(Vector2.ZERO, 130.0))
	igual(MedidorEscape.saidas_livres(Vector2.ZERO, 11.0, 330.0, cerco), 0,
		"cercado por todos os lados e com o miolo tomado, nao ha saida")
	ok(MedidorEscape.inevitavel(Vector2.ZERO, 11.0, 330.0, cerco),
		"e a regua chama isso pelo nome: situacao inevitavel")


## Ficar parado e uma entrada do jogador como outra qualquer.
##
## Ha ataque que se evita NAO andando -- a investida da Cyber-Besta passa reta
## por quem nao entrou na linha. Ignorar isso inventaria inevitabilidade onde
## nao ha.
func _ficar_parado_conta_como_saida() -> void:
	# Uma investida passando ao lado: rapida, e ja adiante do jogador.
	var passando: Array[Dictionary] = [{
		"posicao": Vector2(0.0, -200.0),
		"velocidade": Vector2(0.0, 720.0),
		"raio": 34.0,
		"tipo": "corpo",
	}]
	# Quem fica parado e atropelado; quem sai de lado, nao. O que importa e que
	# a regua distingue os dois, e nao qual dos dois acontece.
	var saidas := MedidorEscape.saidas_livres(Vector2.ZERO, 11.0, 330.0, passando)
	ok(saidas > 0, "da para sair da linha de uma investida (%d saidas)" % saidas)

	# E o caso limpo: nada por perto, ficar parado e uma saida valida.
	var so_longe: Array[Dictionary] = [_disco(Vector2(800.0, 0.0), 60.0)]
	igual(MedidorEscape.saidas_livres(Vector2.ZERO, 11.0, 330.0, so_longe), TODAS,
		"com o campo livre, ficar parado conta entre as saidas")


## As cinco combinacoes que o plano pede estao declaradas, e todas apontam para
## cenas que existem.
##
## Le o fonte do arnes: uma combinacao removida ou renomeada faria o arnes rodar
## quatro cenarios em vez de cinco e continuar imprimindo PASSOU.
func _as_cinco_combinacoes_estao_declaradas() -> void:
	var fonte := FileAccess.get_file_as_string("res://tools/combinacoes/combinacoes.gd")
	ok(not fonte.is_empty(), "o arnes de combinacoes foi lido")

	for par in [
		["drone", "besta"], ["neon", "hacker"], ["sentinela", "besta"],
		["drone", "hacker"], ["drone", "neon", "besta", "sentinela", "hacker"],
	]:
		var lista := '["%s"]' % '", "'.join(par)
		ok(fonte.contains(lista), "a combinacao %s esta declarada" % lista)

	for caminho: String in CENAS:
		ok(ResourceLoader.exists(caminho), "%s existe" % caminho.get_file())


func _disco(posicao: Vector2, raio: float) -> Dictionary:
	return {"posicao": posicao, "velocidade": Vector2.ZERO, "raio": raio, "tipo": "area"}
