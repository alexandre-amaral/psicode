extends TesteBase
## A LINGUAGEM dos projeteis: silhueta, coerencia com a hitbox e moldura.
##
## Esta suite existe porque as 21 armas do jogo desenhavam A MESMA FORMA. Um
## losango de quatro vertices servia a pistola, a granada, a sucata do chefe e a
## salva da Diretora; `cor` e `raio` eram a unica variacao. Medido, isso deixou
## **dez dos 210 pares** de armas a menos de 15 graus de matiz -- dois deles com
## RGB IDENTICO (`rail_x`/`gravity_gun` e `onda_guardiao`/`sucata_guardiao`) --,
## e como a forma tambem era a mesma, esses pares eram indistinguiveis em tela.
##
## Ela nao sobe cena e nao toca fisica: le `.tres` e chama funcao pura. E de
## proposito, e e o argumento inteiro de `FormasProjetil` morar em `src/util/` ao
## lado da `Balistica` -- a silhueta e a parte da aparencia de um projetil que da
## para conferir em milissegundos, e um `match` escondido dentro de
## `projetil.gd` so seria alcancado por teste de integracao.
##
## O que ela NAO cobre, e quem cobre: a contagem de projeteis por disparo e do
## `teste_arma.gd`; o que cada comportamento FAZ e do `teste_comportamento_arma.gd`;
## a cor contra a paleta e do `teste_texturas.gd:_espelho_do_ator()`.


const ARMAS := "res://src/weapons/"

## Alongamentos varridos em todo caso de coerencia.
##
## Um leque e nao o default: uma implementacao que vaze o alongamento para o eixo
## Y passa em 1.0 e so aparece longe dele. E o 0.5 existe porque encolher tambem
## e uma forma de vazar.
const ALONGAMENTOS: Array[float] = [0.5, 1.0, 2.0, 4.0]

## Raios varridos, alem dos que a roster de fato usa.
##
## Os extremos entram porque `raio_projetil` e `@export` e ninguem impede alguem
## de digitar 0.5 ou 40 numa sessao de tuning.
const RAIOS_EXTREMOS: Array[float] = [0.5, 1.0, 40.0]

## O losango de antes deste epico, escrito a mao.
##
## Ele mora aqui e nao e lido de `FormasProjetil` de proposito: o portao existe
## para provar que a familia zero continua desenhando EXATAMENTE o que o jogo
## desenhava, e um valor lido da propria fonte que se quer conferir nao prova
## nada. As proporcoes sao as originais de `projetil.gd:_montar_polygon()`.
const LOSANGO_DE_ANTES: Array[Vector2] = [
	Vector2(9.6, 0.0),
	Vector2(0.0, -4.0),
	Vector2(-6.4, 0.0),
	Vector2(0.0, 4.0),
]
const RAIO_DO_LOSANGO_DE_ANTES := 4.0


func nome() -> String:
	return "Linguagem de projetil"


func executar() -> void:
	_a_biblioteca_desenha_toda_familia_que_declara()
	_o_losango_continua_byte_a_byte()
	_nenhuma_silhueta_mente_sobre_a_hitbox()
	_o_halo_nao_vira_corpo()
	_a_moldura_lateral_cabe_o_raio()
	_familia_invalida_e_reconhecida_como_invalida()


## Toda familia declarada desenha alguma coisa.
##
## Sem este caso, o portao que exige "a familia declarada existe na biblioteca"
## aprovaria uma biblioteca VAZIA. E poligono vazio e o pior defeito possivel
## aqui: o projetil nasce invisivel com a hitbox intacta, e nao ha uma linha no
## console -- o jogador leva dano de uma coisa que ele nao ve.
func _a_biblioteca_desenha_toda_familia_que_declara() -> void:
	for familia in FormasProjetil.Familia.values():
		var pontos := FormasProjetil.contorno(familia, 6.0)
		ok(
			pontos.size() >= 3,
			"%s desenha um poligono de verdade (%d vertices)"
				% [FormasProjetil.nome(familia), pontos.size()]
		)
		ok(
			FormasProjetil.existe(familia),
			"%s se reconhece como familia valida" % FormasProjetil.nome(familia)
		)


## A familia ZERO continua sendo o losango de sempre, vertice por vertice.
##
## Enquanto o epico nao acabar, quase toda arma do jogo carrega o default do
## script -- entao um erro de digitacao nas proporcoes 2,4 e 1,6 mudaria a
## aparencia de vinte armas de uma vez, sem `.tres` nenhum ter sido tocado e sem
## nada no console.
func _o_losango_continua_byte_a_byte() -> void:
	var pontos := FormasProjetil.contorno(
		FormasProjetil.Familia.LOSANGO, RAIO_DO_LOSANGO_DE_ANTES
	)
	igual(pontos.size(), LOSANGO_DE_ANTES.size(), "o losango tem quatro vertices")
	if pontos.size() != LOSANGO_DE_ANTES.size():
		return
	for i in LOSANGO_DE_ANTES.size():
		ok(
			pontos[i].is_equal_approx(LOSANGO_DE_ANTES[i]),
			"o losango mantem o vertice %d (esperava %s, obtive %s)"
				% [i, LOSANGO_DE_ANTES[i], pontos[i]]
		)


## A silhueta nunca mente sobre a hitbox, e a mentira que importa e LATERAL.
##
## A colisao e um `CircleShape2D` de `raio` -- a forma e so leitura. No eixo do
## VOO ela e livre, e errar para mais ali e generoso: o losango avanca 2,4 raios
## e e assim que ele le direcao. De lado os DOIS sentidos sao cobrados, porque e
## de lado que o jogador esquiva:
##
##   contem (0, +-raio)  ->  nunca desenha MENOS do que fere
##   max |y| <= raio     ->  nunca desenha MAIS do que fere
##
## Varre a roster real mais os extremos, e cada um sob quatro alongamentos.
func _nenhuma_silhueta_mente_sobre_a_hitbox() -> void:
	var raios := _raios_da_roster()
	for r in RAIOS_EXTREMOS:
		if not raios.has(r):
			raios.append(r)
	ok(raios.size() >= 5, "a varredura tem raios de verdade (%d)" % raios.size())

	for familia in FormasProjetil.Familia.values():
		var falhas_estreitas := 0
		var falhas_largas := 0
		for r in raios:
			for e in ALONGAMENTOS:
				var pontos := FormasProjetil.contorno(familia, r, e)
				var corpo := _corpo_principal(familia, pontos, r, e)
				if not (_contem(corpo, Vector2(0.0, -r)) and _contem(corpo, Vector2(0.0, r))):
					falhas_estreitas += 1
				for p in pontos:
					if absf(p.y) > r + 0.001:
						falhas_largas += 1
						break
		igual(
			falhas_estreitas, 0,
			"%s nunca desenha MENOS do que fere" % FormasProjetil.nome(familia)
		)
		igual(
			falhas_largas, 0,
			"%s nunca desenha MAIS do que fere" % FormasProjetil.nome(familia)
		)


## O halo e brilho, e nao corpo.
##
## Ele desenha ALEM da hitbox de proposito, e e a unica peca que faz isso -- por
## isso ele e limitado nos dois eixos. Grande demais ou opaco demais, o jogador
## le a borda dele como a area que fere, e o projetil volta a mentir por um
## caminho que o portao de silhueta nao olha.
func _o_halo_nao_vira_corpo() -> void:
	var r := 8.0
	for familia in FormasProjetil.Familia.values():
		var h := FormasProjetil.halo(familia, r)
		if h.is_empty():
			continue
		var maior := 0.0
		for p in h:
			maior = maxf(maior, p.length())
		ok(
			maior <= r * FormasProjetil.HALO_MAXIMO + 0.001,
			"o halo de %s cabe no teto (%.1f de %.1f)"
				% [FormasProjetil.nome(familia), maior, r * FormasProjetil.HALO_MAXIMO]
		)
		ok(
			maior > r,
			"o halo de %s e maior que o corpo -- senao nao ha halo"
				% FormasProjetil.nome(familia)
		)
	ok(
		FormasProjetil.HALO_ALFA < 1.0,
		"o halo nunca e opaco (%.2f)" % FormasProjetil.HALO_ALFA
	)
	ok(
		FormasProjetil.alfa(FormasProjetil.Familia.ETEREO) < 1.0,
		"ETEREO deixa passar (%.2f)" % FormasProjetil.alfa(FormasProjetil.Familia.ETEREO)
	)
	ok(
		is_equal_approx(FormasProjetil.alfa(FormasProjetil.Familia.LOSANGO), 1.0),
		"e as outras familias sao opacas"
	)


## A moldura lateral cabe o diametro, e sai da tabela.
##
## Escala de pixel art e INTEIRA: quem escolhe o tamanho e a moldura, e nao um
## `scale` fracionario -- 64 para 96 borra mesmo com o filtro Nearest do projeto.
## Uma moldura menor que o diametro cortaria a arte no eixo que o portao de
## coerencia acabou de amarrar a hitbox.
func _a_moldura_lateral_cabe_o_raio() -> void:
	for r in _raios_da_roster():
		var lado := FormasProjetil.lateral_de(r)
		ok(
			FormasProjetil.LATERAIS.has(lado),
			"raio %.1f cai numa moldura da tabela (%d)" % [r, lado]
		)
		ok(
			float(lado) >= r * 2.0,
			"a moldura de %d px cabe o diametro de %.1f px" % [lado, r * 2.0]
		)
	igual(
		FormasProjetil.lateral_de(2.0), 8,
		"o menor projetil cabe na menor moldura"
	)
	igual(
		FormasProjetil.lateral_de(16.0), 32,
		"a onda do chefe (raio 16) pede a moldura de 32"
	)


## Familia fora da faixa e RECUSADA, e nao silenciosamente desenhada.
##
## O valor e um INT no `.tres`. Um numero digitado a mao, ou o sobrevivente de um
## enum que encolheu, carrega sem erro nenhum -- e sem esta pergunta o portao que
## varre as armas nao teria como reprovar.
func _familia_invalida_e_reconhecida_como_invalida() -> void:
	ok(not FormasProjetil.existe(-1), "familia negativa e invalida")
	ok(
		not FormasProjetil.existe(FormasProjetil.Familia.size()),
		"familia acima do enum e invalida"
	)
	igual(String(FormasProjetil.nome(-1)), "?", "familia invalida nao tem nome")
	ok(
		FormasProjetil.contorno(999, 5.0).size() >= 3,
		"e mesmo assim ela cai no losango, em vez de nascer invisivel"
	)


# -- helpers ----------------------------------------------------------------


## Os raios que as armas do jogo de fato usam, lidos do disco.
##
## Lista fixa apodrece nas duas direcoes -- arma nova nao seria varrida, e arma
## removida deixaria um numero orfao. E a mesma razao que faz
## `teste_texturas._espelho_do_ator()` varrer a pasta.
func _raios_da_roster() -> Array[float]:
	var fora: Array[float] = []
	var pasta := DirAccess.open(ARMAS)
	if pasta == null:
		return fora
	for arquivo in pasta.get_files():
		if not arquivo.ends_with(".tres"):
			continue
		var dados := load(ARMAS + arquivo) as DadosArma
		if dados == null:
			continue
		if not fora.has(dados.raio_projetil):
			fora.append(dados.raio_projetil)
	return fora


## O poligono em que os dois pontos laterais tem de morar.
##
## Nas familias de peca unica e o contorno inteiro. No CLUSTER e a PRIMEIRA ilha:
## com pedacos soltos, perguntar "o contorno contem (0, +-raio)" sobre a lista
## concatenada nao quer dizer nada.
func _corpo_principal(
	familia: int, pontos: PackedVector2Array, raio: float, alongamento: float
) -> PackedVector2Array:
	var grupos := FormasProjetil.ilhas(familia, raio, alongamento)
	if grupos.is_empty():
		return pontos
	var corpo := PackedVector2Array()
	for i in grupos[0]:
		corpo.append(pontos[i])
	return corpo


## O ponto esta no poligono?
##
## Vertice conta. `Geometry2D.is_point_in_polygon` nao promete nada para ponto
## exatamente sobre a borda, e as oito familias poem vertice EXATO em (0, +-r)
## justamente para a garantia nao depender de tolerancia de ponto flutuante --
## entao a pergunta e feita nas duas formas.
func _contem(pontos: PackedVector2Array, alvo: Vector2) -> bool:
	for p in pontos:
		if p.is_equal_approx(alvo):
			return true
	return Geometry2D.is_point_in_polygon(alvo, pontos)
