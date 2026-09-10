extends TesteBase
## O DECORADOR DE SALA (FAB 03): densidade alta, concentrada no perimetro, com o
## miolo livre e organizada em clusters.
##
## Esta suite existe porque `DecoradorDeSala` e logica PURA. Ele nao conhece a
## arvore de cenas, entao as oito regras que ele carrega sao afirmacoes sobre
## numeros -- e da para varrer centenas de salas aqui sem montar andar nenhum.
## Dentro de `sala.gd` a mesma pergunta exigiria instanciar o jogo, que e como
## regra de posicionamento envelhece sem ninguem perceber.
##
## **Nenhum defeito coberto aqui aparece no console.** Decoracao nao tem
## colisao: um prop dentro da parede desenha, um prop no meio da sala desenha, um
## andar inteiro com a mesma decoracao desenha. Todos parecem funcionar. O que
## eles quebram e leitura de combate e variedade, e as duas so aparecem jogando
## -- meses depois, sem pista de quando entraram.
##
## Duas formas de sala em todo caso geometrico: um retangulo e um L. As salas do
## jogo nao sao retangulares (ha a em L, a de pilar, e o chanfro que `Sala`
## aplica em toda quina), e uma regua que so entende retangulo aprova um
## decorador que poe prop do lado de fora do L.

const LARGURA_PADRAO := 960.0
const ALTURA_PADRAO := 544.0

## Quanto da massa de VOLUME tem de vir de conjunto.
##
## A referencia nao tem peca de volume sozinha; o jogo nao precisa chegar la, mas
## precisa sair de "metade solta". Os dois limites existem porque os dois
## extremos sao defeito: tudo avulso le como movel jogado no canto, e tudo em
## conjunto vira tres blocos com parede vazia entre eles.
const PISO_DE_BANCADA := 0.60
const TETO_DE_BANCADA := 0.95


func nome() -> String:
	return "Decoracao"


func executar() -> void:
	_toda_colocacao_fica_na_FAIXA_do_perimetro()
	_nenhuma_colocacao_invade_a_ZONA_LIVRE_de_combate()
	_toda_colocacao_cai_DENTRO_do_poligono_aberto_ou_fechado()
	_a_distribuicao_por_lado_converge_para_os_PESOS_do_perfil()
	_o_HERO_se_concentra_mais_que_a_decoracao_comum()
	_clusters_DIFERENTES_guardam_distancia_e_o_MESMO_cluster_nao()
	_a_mesma_semente_produz_a_MESMA_decoracao()
	_agrupamento_RECENTE_perde_peso_mas_nao_e_proibido()
	_um_lado_fica_RELATIVAMENTE_VAZIO()
	_a_contagem_de_cada_porte_segue_a_faixa_do_perfil()
	_o_perfil_e_o_decorador_concordam_sobre_PORTE_e_LADO()
	_agrupamento_com_listas_DESALINHADAS_e_recusado_INTEIRO()
	_o_DECALQUE_alcanca_o_miolo_e_o_volume_NAO()
	_a_peca_de_PAREDE_fica_colada_na_face()
	_o_VOLUME_vem_em_BANCADA_e_nao_em_pecas_soltas()


# ------------------------------------------------------- a regra da FAIXA ----

## REGRA 1. Toda colocacao vive entre o contorno e `largura_da_faixa_de_perimetro`.
##
## O defeito que isto pega e a peca de um CLUSTER escapando da faixa. A ancora
## do conjunto e conferida por construcao; as pecas nascem deslocadas dela, e um
## deslocamento com `y` grande empurra a peca de tras para dentro da sala. O
## resultado desenha certo, nao tem colisao e nao reclama -- e a sala ganha um
## barril a 200 px da parede, no caminho de quem esquiva.
func _toda_colocacao_fica_na_FAIXA_do_perimetro() -> void:
	var contorno := _sala_retangular()
	var perfil := _perfil_cheio()
	var fora := 0
	var medidas := 0
	for semente in range(40):
		for colocacao in DecoradorDeSala.decorar(contorno, perfil, semente):
			# **O DECALQUE fica de fora desta regra, por decisao.** Ele e chao
			# pintado: na referencia medida (`docs/fabrica_01.png`) a marcacao de
			# galao ocupa o meio da sala e as grades estao espalhadas por todo o
			# piso. Prende-lo a faixa desenharia uma moldura de sujeira em volta
			# da parede, que e o oposto do que a imagem mostra.
			if int(colocacao["porte"]) == DecoradorDeSala.Porte.DECALQUE:
				continue
			medidas += 1
			var posicao: Vector2 = colocacao["posicao"]
			var distancia := DecoradorDeSala.distancia_ao_contorno(posicao, contorno)
			if distancia > perfil.largura_da_faixa_de_perimetro:
				fora += 1
	# Sem esta linha o caso passaria com um decorador que nao devolve nada:
	# "zero colocacoes fora da faixa" e verdade tambem quando nao ha colocacao.
	ok(medidas > 0, "a sala recebe decoracao (%d colocacoes em 40 salas)" % medidas)
	igual(fora, 0, "nenhuma colocacao passa da faixa de perimetro")


# -------------------------------------------------- a regra que mais vale ----

## REGRA 2. Nada dentro de `raio_da_zona_livre` do centro.
##
## **E a regra que protege o gameplay, e a mais importante da suite.** Prop no
## meio da sala nao tem colisao: o jogador le como cobertura, tenta usar, e leva
## o tiro atravessado. Pior, ele cobre onde o telegrafo desenha.
##
## Medido nas DUAS escalas de proposito. Numa sala de 960x544 a faixa de
## perimetro ja mantem tudo longe do centro e a zona livre nunca morde -- um
## decorador que a ignorasse passaria. Numa sala apertada "perto da parede" e "no
## meio da sala" sao o mesmo lugar, e e la que a regra tem de existir.
func _nenhuma_colocacao_invade_a_ZONA_LIVRE_de_combate() -> void:
	var casos: Array[Dictionary] = [
		{"contorno": _sala_retangular(), "perfil": _perfil_cheio(), "rotulo": "960x544"},
		{"contorno": _sala_retangular(384.0, 384.0), "perfil": _perfil_apertado(), "rotulo": "384x384"},
	]
	for caso in casos:
		var contorno: PackedVector2Array = caso["contorno"]
		var perfil: PerfilDeDecoracao = caso["perfil"]
		var rotulo: String = caso["rotulo"]
		var centro := DecoradorDeSala.centro_de(contorno)
		var dentro_do_miolo := 0
		var medidas := 0
		for semente in range(40):
			for colocacao in DecoradorDeSala.decorar(contorno, perfil, semente):
				# O DECALQUE PODE invadir o miolo -- ver o caso proprio dele
				# logo abaixo. O que a zona livre protege e VOLUME: peca que o
				# jogador leria como cobertura, ou que cobriria o telegrafo.
				# Mancha pintada no chao nao faz nem uma coisa nem outra.
				if int(colocacao["porte"]) == DecoradorDeSala.Porte.DECALQUE:
					continue
				medidas += 1
				var posicao: Vector2 = colocacao["posicao"]
				if posicao.distance_to(centro) < perfil.raio_da_zona_livre:
					dentro_do_miolo += 1
		ok(medidas > 0, "a sala %s recebe decoracao (%d colocacoes)" % [rotulo, medidas])
		igual(dentro_do_miolo, 0, "nada invade a zona livre na sala %s" % rotulo)


# ------------------------------------------------------ a forma da sala ------

## REGRA 3. Toda colocacao dentro do poligono, com o contorno chegando ABERTO ou
## FECHADO.
##
## Sao dois defeitos num caso so.
##
## O primeiro e a sala em L: um decorador que trate a sala como o retangulo que a
## envolve poe decoracao no quadrante que a sala nao tem. Ele desenha, fica atras
## da parede, e ninguem ve -- so a densidade medida da sala nao bate com a
## pedida.
##
## O segundo e o ponto de fechamento. O `Line2D` "Parede" repete o primeiro ponto
## no fim, e `Geometry2D` engasga com o duplicado. Se `decorar` mudar de resposta
## conforme quem chamou tenha limpado o contorno ou nao, metade dos consumidores
## recebe uma sala e metade recebe outra.
func _toda_colocacao_cai_DENTRO_do_poligono_aberto_ou_fechado() -> void:
	var aberto := _sala_em_L()
	var perfil := _perfil_cheio()

	var fora := 0
	var medidas := 0
	for semente in range(40):
		for colocacao in DecoradorDeSala.decorar(aberto, perfil, semente):
			medidas += 1
			var posicao: Vector2 = colocacao["posicao"]
			if not Geometry2D.is_point_in_polygon(posicao, aberto):
				fora += 1
	ok(medidas > 0, "a sala em L recebe decoracao (%d colocacoes)" % medidas)
	igual(fora, 0, "nenhuma colocacao cai no quadrante que a sala em L nao tem")

	var fechado := aberto.duplicate()
	fechado.append(aberto[0])
	var pela_aberta := DecoradorDeSala.decorar(aberto, perfil, 7)
	var pela_fechada := DecoradorDeSala.decorar(fechado, perfil, 7)
	ok(_mesma_decoracao(pela_aberta, pela_fechada),
		"o contorno fechado e o aberto produzem a mesma decoracao")


# --------------------------------------------------------- os pesos ---------

## REGRA 4. Com muitas amostras, a distribuicao por lado converge para os pesos
## do perfil.
##
## O defeito e um decorador que sorteie o lado uniformemente: a sala fica com
## tanta massa no sul quanto no norte, e o sul e o lado por onde o jogador entra
## e o primeiro que a camera corta. Nada quebra; a sala so passa a mostrar
## metade da decoracao pela metade.
##
## A tolerancia e FOLGADA de proposito. O sorteio e pequeno (algumas pecas por
## sala) e a regra do lado vazio remove um lado inteiro em cada sala -- um
## numero apertado aqui produz um teste que reprova sozinho de vez em quando, e
## teste intermitente e pior que teste ausente, porque ensina a ignorar o
## vermelho.
##
## Medido so em GRANDE e MEDIO: o HERO tem pesos proprios e os dois portes
## menores podem cair no lado calmo, o que enviesaria a conta.
func _a_distribuicao_por_lado_converge_para_os_PESOS_do_perfil() -> void:
	var contorno := _sala_retangular()
	var perfil := _perfil_so_comum()
	var por_lado := [0, 0, 0, 0]
	var medidas := 0
	for semente in range(200):
		for colocacao in DecoradorDeSala.decorar(contorno, perfil, semente):
			var porte := int(colocacao["porte"])
			if porte != DecoradorDeSala.Porte.GRANDE and porte != DecoradorDeSala.Porte.MEDIO:
				continue
			por_lado[int(colocacao["lado"])] += 1
			medidas += 1

	ok(medidas > 500, "a amostra e grande o bastante para medir (%d colocacoes)" % medidas)
	var soma := perfil.peso_norte + perfil.peso_leste + perfil.peso_sul + perfil.peso_oeste
	for lado in 4:
		var esperado := DecoradorDeSala.peso_do_lado(perfil, lado) / soma
		var obtido := float(por_lado[lado]) / maxf(float(medidas), 1.0)
		perto(obtido, esperado, "o lado %d recebe a fracao declarada" % lado, 0.07)


## O HERO nao divide os pesos da decoracao comum.
##
## Ele e a peca que da nome a sala, e a face desenhada do norte e a unica
## superficie vertical contra a qual uma silhueta grande le como volume. Um
## decorador que reusasse os pesos comuns para o hero passaria em todos os
## outros casos desta suite e mesmo assim poria a prensa da sala no sul, cortada
## pela beira do quadro.
func _o_HERO_se_concentra_mais_que_a_decoracao_comum() -> void:
	var contorno := _sala_retangular()
	var perfil := _perfil_so_hero()
	var por_lado := [0, 0, 0, 0]
	var medidas := 0
	for semente in range(200):
		for colocacao in DecoradorDeSala.decorar(contorno, perfil, semente):
			por_lado[int(colocacao["lado"])] += 1
			medidas += 1

	ok(medidas > 150, "os heros foram colocados (%d em 200 salas)" % medidas)
	var fracao_norte := float(por_lado[DecoradorDeSala.Lado.NORTE]) / maxf(float(medidas), 1.0)
	var fracao_sul := float(por_lado[DecoradorDeSala.Lado.SUL]) / maxf(float(medidas), 1.0)
	ok(fracao_norte > 0.35, "o hero prefere o norte (fracao %.3f)" % fracao_norte)
	ok(fracao_sul < 0.20, "o hero evita o sul (fracao %.3f)" % fracao_sul)


# ----------------------------------------------------- a regra 5, e a excecao -

## REGRA 5. Clusters DIFERENTES guardam distancia derivada do porte; pecas do
## MESMO cluster podem se sobrepor.
##
## As duas metades sao a mesma decisao de design vista dos dois lados, e cobrar
## so a primeira produziria conjuntos explodidos -- cinco pecas espalhadas que o
## olho nao reune num conjunto. O barril na frente do tanque e o que faz o
## cluster parecer montado por alguem; a distancia entre conjuntos e o que
## impede dois tanques ocupando o mesmo lugar.
##
## Sem a segunda asercao, um decorador que aplicasse a distancia tambem dentro do
## cluster passaria: nada erra, nada reclama, e a decoracao volta a ser prop
## solto com outro nome.
func _clusters_DIFERENTES_guardam_distancia_e_o_MESMO_cluster_nao() -> void:
	var contorno := _sala_retangular()
	var perfil := _perfil_so_clusters()
	var colados_no_mesmo := 0
	var colados_entre := 0
	var medidas := 0
	for semente in range(60):
		var colocacoes := DecoradorDeSala.decorar(contorno, perfil, semente)
		medidas += colocacoes.size()
		for i in colocacoes.size():
			for j in range(i + 1, colocacoes.size()):
				var a: Dictionary = colocacoes[i]
				var b: Dictionary = colocacoes[j]
				var pa: Vector2 = a["posicao"]
				var pb: Vector2 = b["posicao"]
				var exigida := maxf(
					DecoradorDeSala.distancia_minima_de(int(a["porte"])),
					DecoradorDeSala.distancia_minima_de(int(b["porte"]))
				)
				if pa.distance_to(pb) >= exigida:
					continue
				var nome_a: StringName = a["agrupamento"]
				var nome_b: StringName = b["agrupamento"]
				if nome_a == nome_b and String(nome_a) != "":
					colados_no_mesmo += 1
				else:
					colados_entre += 1

	ok(medidas > 0, "os clusters foram colocados (%d pecas)" % medidas)
	igual(colados_entre, 0, "dois clusters diferentes nunca se sobrepoem")
	ok(colados_no_mesmo > 0,
		"pecas do mesmo cluster PODEM se encostar (%d pares)" % colados_no_mesmo)


# ------------------------------------------------------- o determinismo ------

## REGRA 6. A mesma sala com a mesma semente da a mesma decoracao, sempre.
##
## O defeito e um `randf()` global esquecido no meio do decorador. Ele nao da
## erro: a sala fica bonita, e so quem volta para uma sala ja visitada -- ou quem
## reproduz um andar para investigar outra coisa -- e que ve a decoracao mudar
## de lugar. Um bug que se reordena a cada execucao nao tem como ser investigado.
##
## A segunda asercao existe para o caso passar por motivo certo: um decorador que
## devolvesse sempre a MESMA sala, ignorando a semente, tambem e deterministico.
func _a_mesma_semente_produz_a_MESMA_decoracao() -> void:
	var contorno := _sala_retangular()
	var perfil := _perfil_cheio()
	for semente in [0, 1, 77, 4096]:
		var primeira := DecoradorDeSala.decorar(contorno, perfil, semente)
		var segunda := DecoradorDeSala.decorar(contorno, perfil, semente)
		ok(primeira.size() > 0 and _mesma_decoracao(primeira, segunda),
			"a semente %d reproduz a sala inteira" % semente)

	var diferentes := 0
	for semente in range(20):
		if not _mesma_decoracao(
			DecoradorDeSala.decorar(contorno, perfil, semente),
			DecoradorDeSala.decorar(contorno, perfil, semente + 1000)
		):
			diferentes += 1
	ok(diferentes >= 18, "sementes diferentes dao salas diferentes (%d de 20)" % diferentes)


# ---------------------------------------------------- a memoria recente ------

## REGRA 7. Cluster que apareceu nas ultimas salas entra com peso REDUZIDO, e nao
## proibido.
##
## As duas metades importam. Sem a reducao, o andar repete o mesmo conjunto sala
## apos sala e a fabrica vira um corredor de escritorio. Com PROIBICAO, o dia em
## que a lista de recentes ficar maior que a pool de clusters do tipo de sala
## produz uma sala inteira sem cluster nenhum -- vazia, sem erro no console, e
## dificil de rastrear ate a lista que cresceu.
func _agrupamento_RECENTE_perde_peso_mas_nao_e_proibido() -> void:
	var contorno := _sala_retangular()
	var perfil := _perfil_pool_de_quatro()
	var alvo := &"hidraulico"

	var sem_memoria := 0
	var com_memoria := 0
	for semente in range(200):
		for colocacao in DecoradorDeSala.decorar(contorno, perfil, semente):
			if colocacao["agrupamento"] == alvo:
				sem_memoria += 1
		for colocacao in DecoradorDeSala.decorar(contorno, perfil, semente, [alvo]):
			if colocacao["agrupamento"] == alvo:
				com_memoria += 1

	ok(sem_memoria > 0, "sem memoria o cluster aparece normalmente (%d)" % sem_memoria)
	ok(com_memoria > 0, "com memoria ele ainda pode aparecer (%d)" % com_memoria)
	ok(com_memoria < sem_memoria,
		"a memoria REDUZ a frequencia (%d contra %d)" % [com_memoria, sem_memoria])


# ------------------------------------------------------- a regra do vazio ----

## REGRA 8. Mesmo em sala densa, um trecho de parede fica relativamente vazio.
##
## Sem ela a decoracao vira ruido uniforme: quatro paredes igualmente cheias nao
## tem hierarquia, e o olho para de encontrar a peca que importa. E o mesmo
## motivo pelo qual `max_props_animados` e baixo -- se tudo se destaca, nada se
## destaca.
##
## "Relativamente" e o numero: o lado calmo aceita ate `PECAS_NO_LADO_VAZIO`
## pecas dos dois portes menores. Zero pecas seria uma parede que parece cenario
## nao terminado.
func _um_lado_fica_RELATIVAMENTE_VAZIO() -> void:
	var contorno := _sala_retangular()
	var perfil := _perfil_cheio()
	var excesso := 0
	var massa_no_calmo := 0
	var soma_no_calmo := 0
	var soma_nos_outros := 0
	for semente in range(60):
		var calmo := DecoradorDeSala.lado_vazio(perfil, semente)
		var no_calmo := 0
		var nos_outros := 0
		for colocacao in DecoradorDeSala.decorar(contorno, perfil, semente):
			# O decalque nao tem lado de verdade: o campo dele guarda a aresta
			# mais proxima, e nao um lado escolhido. Conta-lo aqui mediria o
			# sorteio livre em vez da regra do vazio.
			if int(colocacao["porte"]) == DecoradorDeSala.Porte.DECALQUE:
				continue
			if int(colocacao["lado"]) != calmo:
				nos_outros += 1
				continue
			no_calmo += 1
			if int(colocacao["porte"]) < DecoradorDeSala.Porte.PEQUENO:
				massa_no_calmo += 1
		if no_calmo > DecoradorDeSala.PECAS_NO_LADO_VAZIO:
			excesso += 1
		soma_no_calmo += no_calmo
		soma_nos_outros += nos_outros

	igual(massa_no_calmo, 0, "o lado calmo nunca recebe hero, grande nem medio")
	igual(excesso, 0, "o lado calmo nunca passa do teto de pecas")
	var media_calmo := float(soma_no_calmo) / 60.0
	var media_outros := float(soma_nos_outros) / 180.0
	ok(media_calmo < media_outros,
		"o lado calmo recebe menos que a media dos outros (%.2f contra %.2f)" % [
			media_calmo, media_outros,
		])


# ----------------------------------------------------- a ponte com o perfil --

## A faixa do perfil e o ALVO da sala, e o decorador tem de alcanca-la.
##
## O defeito e um decorador que coloque "o que der" e pare: a sala fica esparsa,
## o `.tres` continua dizendo 3 a 3, e quem for girar o botao de densidade gira
## um botao que nao esta ligado em nada. Medido em soma de 20 salas para nao
## depender de uma unica geometria apertada.
func _a_contagem_de_cada_porte_segue_a_faixa_do_perfil() -> void:
	var contorno := _sala_retangular()
	var perfil := _perfil_so_comum()
	var grandes := 0
	var medios := 0
	for semente in range(20):
		for colocacao in DecoradorDeSala.decorar(contorno, perfil, semente):
			match int(colocacao["porte"]):
				DecoradorDeSala.Porte.GRANDE:
					grandes += 1
				DecoradorDeSala.Porte.MEDIO:
					medios += 1
	entre(float(grandes), 19.0 * 3.0, 20.0 * 3.0, "20 salas entregam 3 GRANDE cada")
	entre(float(medios), 19.0 * 3.0, 20.0 * 3.0, "20 salas entregam 3 MEDIO cada")


## Os cinco portes e os quatro lados chegam aos campos certos do perfil.
##
## O enum mora no decorador e os numeros moram no recurso, porque um `Array`
## indexado por enum nao aparece no Inspetor de um jeito que alguem sem GDScript
## consiga girar -- e girar sem programar e o requisito. O preco e um `match` que
## liga os dois lados, e `match` com um caso trocado nao da erro: ele entrega o
## numero do porte vizinho. Este caso e o que impede a troca.
func _o_perfil_e_o_decorador_concordam_sobre_PORTE_e_LADO() -> void:
	var perfil := PerfilDeDecoracao.new()
	perfil.contagem_hero = Vector2i(1, 1)
	perfil.contagem_grande = Vector2i(2, 2)
	perfil.contagem_medio = Vector2i(3, 3)
	perfil.contagem_pequeno = Vector2i(4, 4)
	perfil.contagem_decalque = Vector2i(5, 5)
	perfil.contagem_micro = Vector2i(6, 6)
	perfil.contagem_parede = Vector2i(7, 7)
	igual(DecoradorDeSala.faixa_de_porte(perfil, DecoradorDeSala.Porte.HERO),
		Vector2i(1, 1), "HERO le contagem_hero")
	igual(DecoradorDeSala.faixa_de_porte(perfil, DecoradorDeSala.Porte.GRANDE),
		Vector2i(2, 2), "GRANDE le contagem_grande")
	igual(DecoradorDeSala.faixa_de_porte(perfil, DecoradorDeSala.Porte.MEDIO),
		Vector2i(3, 3), "MEDIO le contagem_medio")
	igual(DecoradorDeSala.faixa_de_porte(perfil, DecoradorDeSala.Porte.PEQUENO),
		Vector2i(4, 4), "PEQUENO le contagem_pequeno")
	# **MICRO e DECALQUE tem campos SEPARADOS, e ja foram um so.** Enquanto
	# compartilhavam `contagem_decalque`, era impossivel ter sujeira no centro
	# sem ter parafusos flutuando no meio do combate: micro e volume, decalque e
	# chao pintado, e so o segundo pode sair da faixa de perimetro.
	igual(DecoradorDeSala.faixa_de_porte(perfil, DecoradorDeSala.Porte.MICRO),
		Vector2i(6, 6), "MICRO le contagem_micro")
	igual(DecoradorDeSala.faixa_de_porte(perfil, DecoradorDeSala.Porte.DECALQUE),
		Vector2i(5, 5), "DECALQUE le contagem_decalque")
	igual(DecoradorDeSala.faixa_de_porte(perfil, DecoradorDeSala.Porte.PAREDE),
		Vector2i(7, 7), "PAREDE le contagem_parede")

	perfil.peso_norte = 0.1
	perfil.peso_leste = 0.2
	perfil.peso_sul = 0.3
	perfil.peso_oeste = 0.4
	perto(DecoradorDeSala.peso_do_lado(perfil, DecoradorDeSala.Lado.NORTE), 0.1,
		"NORTE le peso_norte")
	perto(DecoradorDeSala.peso_do_lado(perfil, DecoradorDeSala.Lado.LESTE), 0.2,
		"LESTE le peso_leste")
	perto(DecoradorDeSala.peso_do_lado(perfil, DecoradorDeSala.Lado.SUL), 0.3,
		"SUL le peso_sul")
	perto(DecoradorDeSala.peso_do_lado(perfil, DecoradorDeSala.Lado.OESTE), 0.4,
		"OESTE le peso_oeste")

	perfil.peso_hero_norte = 0.6
	perfil.peso_hero_leste = 0.7
	perfil.peso_hero_sul = 0.8
	perfil.peso_hero_oeste = 0.9
	perto(DecoradorDeSala.peso_de_hero_do_lado(perfil, DecoradorDeSala.Lado.NORTE), 0.6,
		"NORTE le peso_hero_norte")
	perto(DecoradorDeSala.peso_de_hero_do_lado(perfil, DecoradorDeSala.Lado.LESTE), 0.7,
		"LESTE le peso_hero_leste")
	perto(DecoradorDeSala.peso_de_hero_do_lado(perfil, DecoradorDeSala.Lado.SUL), 0.8,
		"SUL le peso_hero_sul")
	perto(DecoradorDeSala.peso_de_hero_do_lado(perfil, DecoradorDeSala.Lado.OESTE), 0.9,
		"OESTE le peso_hero_oeste")


## Um agrupamento com `portes` e `deslocamentos` de tamanhos diferentes e
## recusado INTEIRO.
##
## As duas listas sao paralelas por decisao (ver `AgrupamentoDeDecoracao`), e o
## Inspetor cria buraco toda vez que alguem cresce um array. Truncar pelo menor
## seria o comportamento silencioso: o cluster entra na sala com o tanque e sem o
## tubo, o que le como bug de arte e nao tem uma linha no console para explicar.
func _agrupamento_com_listas_DESALINHADAS_e_recusado_INTEIRO() -> void:
	var torto := AgrupamentoDeDecoracao.new()
	torto.nome = &"torto"
	torto.portes = PackedInt32Array([
		DecoradorDeSala.Porte.GRANDE,
		DecoradorDeSala.Porte.MEDIO,
		DecoradorDeSala.Porte.PEQUENO,
	])
	torto.deslocamentos = PackedVector2Array([Vector2.ZERO, Vector2(32.0, 8.0)])
	ok(not torto.valido(), "listas de tamanhos diferentes invalidam o agrupamento")
	igual(torto.contagem_de_pecas(), 0, "agrupamento invalido nao oferece peca nenhuma")

	var perfil := _perfil_vazio()
	perfil.agrupamentos = _lista_de_agrupamentos([torto])
	perfil.quantos_agrupamentos = Vector2i(1, 1)
	var colocado := 0
	for semente in range(20):
		colocado += DecoradorDeSala.decorar(_sala_retangular(), perfil, semente).size()
	igual(colocado, 0, "o decorador nao coloca metade de um cluster torto")


## O DECALQUE alcanca o MIOLO da sala, e o volume nao.
##
## **Este caso e o ponto inteiro da correcao.** Sem ele, um decorador que
## voltasse a rejeitar tudo dentro da zona livre passaria em todos os outros
## casos desta suite -- o de zona livre inclusive, porque ele agora pula
## decalque -- e o centro da sala voltaria a ser um vazio chapado. O portao tem
## de cobrar que o decalque CHEGA la, e nao so que ele pode.
##
## A referencia medida (`docs/fabrica_01.png`) tem um losango de galao no meio
## da area livre e mais de dez grades de piso, varias no centro.
func _o_DECALQUE_alcanca_o_miolo_e_o_volume_NAO() -> void:
	var contorno := _sala_retangular()
	var perfil := _perfil_vazio()
	perfil.contagem_decalque = Vector2i(8, 8)
	var centro := DecoradorDeSala.centro_de(contorno)

	var no_miolo := 0
	var total := 0
	for semente in range(60):
		for colocacao in DecoradorDeSala.decorar(contorno, perfil, semente):
			total += 1
			var posicao: Vector2 = colocacao["posicao"]
			if posicao.distance_to(centro) < perfil.raio_da_zona_livre:
				no_miolo += 1

	ok(total > 200, "os decalques foram colocados (%d em 60 salas)" % total)
	ok(no_miolo > 0, "o decalque CHEGA ao miolo (%d de %d)" % [no_miolo, total])
	# E ele nao fica so' la: sujeira concentrada no centro le como tapete.
	ok(no_miolo < total, "e ele nao mora so no miolo (%d de %d)" % [no_miolo, total])

	# O contra-exemplo, na MESMA sala: volume continua barrado.
	var so_volume := _perfil_vazio()
	so_volume.contagem_medio = Vector2i(6, 6)
	var volume_no_miolo := 0
	var volume_total := 0
	for semente in range(60):
		for colocacao in DecoradorDeSala.decorar(contorno, so_volume, semente):
			volume_total += 1
			var posicao: Vector2 = colocacao["posicao"]
			if posicao.distance_to(centro) < so_volume.raio_da_zona_livre:
				volume_no_miolo += 1
	ok(volume_total > 100, "o volume tambem foi colocado (%d)" % volume_total)
	igual(volume_no_miolo, 0, "mas NENHUM volume entra no miolo")


## A peca de PAREDE fica colada na face, e nao a meia faixa dela.
##
## Ela existe porque na referencia quase nenhum trecho de parede aparece limpo:
## tubo corre por cima dela, caixa de juncao se pendura nela. Sem um porte que
## ancore RASO, todo tubo vira prop de chao encostado -- e a densidade so pode
## crescer onde ela atrapalha o combate.
func _a_peca_de_PAREDE_fica_colada_na_face() -> void:
	var contorno := _sala_retangular()
	var perfil := _perfil_vazio()
	perfil.contagem_parede = Vector2i(6, 6)

	var fundo := 0
	var total := 0
	var mais_fundo := 0.0
	for semente in range(40):
		for colocacao in DecoradorDeSala.decorar(contorno, perfil, semente):
			total += 1
			var posicao: Vector2 = colocacao["posicao"]
			var d := DecoradorDeSala.distancia_ao_contorno(posicao, contorno)
			mais_fundo = maxf(mais_fundo, d)
			if d > DecoradorDeSala.PROFUNDIDADE_DE_PAREDE:
				fundo += 1

	ok(total > 150, "as pecas de parede foram colocadas (%d em 40 salas)" % total)
	igual(fundo, 0, "nenhuma entra mais que %.0f px na sala (mais funda: %.1f)"
		% [DecoradorDeSala.PROFUNDIDADE_DE_PAREDE, mais_fundo])
	# E ela e MAIS rasa que a decoracao comum: se as duas ancorassem igual, o
	# porte novo nao estaria fazendo nada.
	ok(mais_fundo < perfil.largura_da_faixa_de_perimetro * 0.5,
		"e ela e mais rasa que a faixa comum (%.1f < %.1f)"
			% [mais_fundo, perfil.largura_da_faixa_de_perimetro * 0.5])


# ------------------------------------------------------------- montagem ------

## Retangulo centrado na origem, como as cenas de sala do jogo.
func _sala_retangular(largura: float = LARGURA_PADRAO, altura: float = ALTURA_PADRAO) -> PackedVector2Array:
	var meia := Vector2(largura, altura) * 0.5
	return PackedVector2Array([
		Vector2(-meia.x, -meia.y),
		Vector2(meia.x, -meia.y),
		Vector2(meia.x, meia.y),
		Vector2(-meia.x, meia.y),
	])


## Uma sala em L: falta o pedaco nordeste. O centro da caixa que a envolve
## continua DENTRO do poligono, que e o caso que interessa -- a zona livre e
## medida a partir dele.
func _sala_em_L() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-480.0, -272.0),
		Vector2(160.0, -272.0),
		Vector2(160.0, -80.0),
		Vector2(480.0, -80.0),
		Vector2(480.0, 272.0),
		Vector2(-480.0, 272.0),
	])


func _perfil_vazio() -> PerfilDeDecoracao:
	var perfil := PerfilDeDecoracao.new()
	perfil.contagem_hero = Vector2i.ZERO
	perfil.contagem_grande = Vector2i.ZERO
	perfil.contagem_medio = Vector2i.ZERO
	perfil.contagem_pequeno = Vector2i.ZERO
	perfil.contagem_decalque = Vector2i.ZERO
	# **Campo novo tem de entrar AQUI tambem, e esquecer isso nao da erro.**
	# `contagem_micro` e `contagem_parede` nasceram com default util; enquanto
	# este helper nao os zerava, TODO caso que pedia "uma sala sem decoracao"
	# recebia de cinco a treze pecas em silencio, e quatro casos desta suite
	# reprovaram apontando para o decorador em vez de para o helper.
	perfil.contagem_micro = Vector2i.ZERO
	perfil.contagem_parede = Vector2i.ZERO
	perfil.quantos_agrupamentos = Vector2i.ZERO
	return perfil


## O perfil de trabalho: hero, avulsos e dois clusters. E o que uma sala de
## combate do andar 1 deve parecer.
func _perfil_cheio() -> PerfilDeDecoracao:
	var perfil := PerfilDeDecoracao.new()
	perfil.contagem_hero = Vector2i(1, 1)
	perfil.contagem_grande = Vector2i(2, 3)
	perfil.contagem_medio = Vector2i(2, 4)
	perfil.contagem_pequeno = Vector2i(3, 5)
	perfil.contagem_decalque = Vector2i(2, 3)
	perfil.quantos_agrupamentos = Vector2i(1, 2)
	perfil.agrupamentos = _lista_de_agrupamentos([
		_agrupamento(&"hidraulico", [
			DecoradorDeSala.Porte.GRANDE,
			DecoradorDeSala.Porte.MEDIO,
			DecoradorDeSala.Porte.PEQUENO,
		], [Vector2.ZERO, Vector2(40.0, 8.0), Vector2(-32.0, 12.0)]),
		_agrupamento(&"eletrico", [
			DecoradorDeSala.Porte.GRANDE,
			DecoradorDeSala.Porte.MICRO,
		], [Vector2.ZERO, Vector2(28.0, 20.0)]),
	])
	return perfil


## Sala apertada: aqui a faixa de perimetro e a zona livre se encostam, e e a
## zona livre que segura o miolo.
func _perfil_apertado() -> PerfilDeDecoracao:
	var perfil := _perfil_vazio()
	perfil.contagem_grande = Vector2i(1, 1)
	perfil.contagem_medio = Vector2i(1, 2)
	perfil.contagem_pequeno = Vector2i(1, 2)
	return perfil


## So decoracao comum, para medir os pesos sem o hero e sem cluster: um cluster
## joga varias pecas no MESMO lado e engrossaria a variancia da medida.
func _perfil_so_comum() -> PerfilDeDecoracao:
	var perfil := _perfil_vazio()
	perfil.contagem_grande = Vector2i(3, 3)
	perfil.contagem_medio = Vector2i(3, 3)
	return perfil


func _perfil_so_hero() -> PerfilDeDecoracao:
	var perfil := _perfil_vazio()
	perfil.contagem_hero = Vector2i(1, 1)
	return perfil


## Dois clusters com pecas GRANDE encostadas: a distancia minima de GRANDE e 96
## e as pecas ficam a ~30 px uma da outra, entao o par so pode existir DENTRO do
## conjunto.
func _perfil_so_clusters() -> PerfilDeDecoracao:
	var perfil := _perfil_vazio()
	perfil.quantos_agrupamentos = Vector2i(2, 2)
	perfil.agrupamentos = _lista_de_agrupamentos([
		_agrupamento(&"prensa", [
			DecoradorDeSala.Porte.GRANDE, DecoradorDeSala.Porte.GRANDE,
		], [Vector2.ZERO, Vector2(28.0, 10.0)]),
		_agrupamento(&"fundicao", [
			DecoradorDeSala.Porte.GRANDE, DecoradorDeSala.Porte.GRANDE,
		], [Vector2.ZERO, Vector2(-28.0, 10.0)]),
	])
	return perfil


## Pool de quatro clusters de UMA peca, sorteando UM por sala: e a unica forma
## de a memoria recente ser mensuravel -- com a pool do tamanho do sorteio,
## todos entram sempre e o peso nao muda nada.
func _perfil_pool_de_quatro() -> PerfilDeDecoracao:
	var perfil := _perfil_vazio()
	perfil.quantos_agrupamentos = Vector2i(1, 1)
	perfil.agrupamentos = _lista_de_agrupamentos([
		_agrupamento(&"hidraulico", [DecoradorDeSala.Porte.GRANDE], [Vector2.ZERO]),
		_agrupamento(&"eletrico", [DecoradorDeSala.Porte.GRANDE], [Vector2.ZERO]),
		_agrupamento(&"estoque", [DecoradorDeSala.Porte.GRANDE], [Vector2.ZERO]),
		_agrupamento(&"ferramentaria", [DecoradorDeSala.Porte.GRANDE], [Vector2.ZERO]),
	])
	return perfil


## Array tipado montado em loop explicito: um literal solto atribuido a um
## `Array[AgrupamentoDeDecoracao]` depende de inferencia, e a mesma armadilha
## que `Array.filter()` ja cobra no projeto -- array sem tipo atribuido a
## variavel tipada estoura em runtime, e nao na hora de escrever.
func _lista_de_agrupamentos(itens: Array) -> Array[AgrupamentoDeDecoracao]:
	var lista: Array[AgrupamentoDeDecoracao] = []
	for item in itens:
		lista.append(item)
	return lista


func _agrupamento(
	nome_do_conjunto: StringName, portes: Array, deslocamentos: Array
) -> AgrupamentoDeDecoracao:
	var agrupamento := AgrupamentoDeDecoracao.new()
	agrupamento.nome = nome_do_conjunto
	agrupamento.portes = PackedInt32Array(portes)
	agrupamento.deslocamentos = PackedVector2Array(deslocamentos)
	return agrupamento


## Comparacao campo a campo, e nao por `==` de Dictionary.
##
## O que interessa e o CONTEUDO das colocacoes; um `==` que compare estrutura
## aninhada mudaria de semantica junto com a engine, e o portao de determinismo e
## justamente o que nao pode depender de detalhe de implementacao.
func _mesma_decoracao(a: Array[Dictionary], b: Array[Dictionary]) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var x: Dictionary = a[i]
		var y: Dictionary = b[i]
		var px: Vector2 = x["posicao"]
		var py: Vector2 = y["posicao"]
		if not px.is_equal_approx(py):
			return false
		if int(x["porte"]) != int(y["porte"]):
			return false
		if int(x["lado"]) != int(y["lado"]):
			return false
		if String(x["agrupamento"]) != String(y["agrupamento"]):
			return false
	return true


## Quanto da MASSA de uma sala vem de conjunto, e nao de peca solta.
##
## **E a queixa "nao e para ser distribuido aleatoriamente" virada numero.** A
## sala monta em duas etapas: os CLUSTERS primeiro, que sao bancadas de pecas
## encostadas, e depois um completamento AVULSO, peca a peca, que guarda
## `DISTANCIA_MINIMA` de todo mundo. A segunda etapa e literalmente um sorteio de
## pontos espacados, e e ela que produz a leitura de movel jogado no canto.
##
## Na referencia (`docs/fabrica_01.png`) nao ha uma unica peca de volume sozinha:
## tudo esta em bancada, com trechos de parede completamente limpos entre elas. O
## piso aqui e a fracao da massa que pertence a um agrupamento.
##
## Ele mede VOLUME e mais nada. Micro e decalque continuam avulsos de proposito
## -- sao sujeira, e sujeira espalhada e o que uma fabrica usada produz; exigir
## que ela venha em conjunto desenharia manchas em fileira.
func _o_VOLUME_vem_em_BANCADA_e_nao_em_pecas_soltas() -> void:
	# Os perfis REAIS do jogo, e nao um sintetico da suite: a fracao depende de
	# `quantos_agrupamentos` e das contagens por porte, que sao exatamente os
	# botoes que esta regra existe para vigiar. Medir um perfil de teste
	# responderia sobre o perfil de teste.
	var contorno := _sala_retangular()
	var volumes := 0
	var em_bancada := 0
	var detalhe := ""
	for arquivo in ["tipo_combate.tres", "tipo_arma.tres", "tipo_item.tres",
			"tipo_inicial.tres", "tipo_loja.tres"]:
		var dados := load("res://src/mapa/%s" % arquivo) as DadosSala
		if dados == null or dados.perfil_de_decoracao == null:
			continue
		var deste := 0
		var juntas := 0
		for semente in 24:
			for peca in DecoradorDeSala.decorar(
					contorno, dados.perfil_de_decoracao, semente * 31 + 7):
				if int(peca["porte"]) > DecoradorDeSala.Porte.PEQUENO:
					continue
				deste += 1
				if StringName(peca["agrupamento"]) != &"":
					juntas += 1
		volumes += deste
		em_bancada += juntas
		detalhe += " %s=%.0f%%" % [
			dados.id, 100.0 * float(juntas) / maxf(float(deste), 1.0)]

	ok(volumes > 0, "houve volume para conferir (%d)%s" % [volumes, detalhe])
	var fracao := float(em_bancada) / maxf(float(volumes), 1.0)
	ok(fracao >= PISO_DE_BANCADA,
		"a massa da sala vem de conjunto, e nao de peca solta (%.0f%% em bancada, piso %.0f%%)"
			% [fracao * 100.0, PISO_DE_BANCADA * 100.0])
	# A outra ponta: peca avulsa nao pode SUMIR. Ela e o que preenche o vao entre
	# duas bancadas, e uma sala 100% em conjunto vira tres blocos e nada mais --
	# o oposto do defeito, mas defeito igual.
	ok(fracao <= TETO_DE_BANCADA,
		"e ainda sobra peca avulsa entre as bancadas (%.0f%%, teto %.0f%%)"
			% [fracao * 100.0, TETO_DE_BANCADA * 100.0])
