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
const CENA_PROJETIL := "res://src/projectiles/projetil.tscn"

## A faixa de matiz dentro da qual duas armas leem como a MESMA cor.
##
## Nao sai da distancia entre vizinhos: aquela conta foi medida e da +-1,1 grau,
## que obrigaria arte chapada. Este numero e o que a rampa de sombra de um pixel
## art precisa, e o aperto que ele cria vira pressao sobre a SILHUETA.
const LARGURA_MATIZ := 15.0

## Quanto dois projeteis da mesma familia precisam diferir para nao serem o mesmo
## desenho em tons de cinza.
##
## O raio em px, porque e ele que da o tamanho; o alongamento em fracao, porque
## ele estica no eixo do voo. Os dois numeros sao o menor passo que ainda se ve:
## meio pixel de raio nao se distingue num sprite de 8 px, e 5% de alongamento
## some no primeiro frame de movimento.
const DIFERENCA_DE_RAIO := 0.6
const DIFERENCA_DE_ALONGAMENTO := 0.15

## As armas que desenham o POLIGONO, por DECISAO e nao por atraso.
##
## A Fase C do epico #172 previa arte autorada para as 21 armas. Medida, a
## pipeline mostrou um teto que o plano nao previa: **abaixo de um certo
## orcamento de pixel a arte perde para o poligono**, que e exato, ja e cobrado
## pelos portoes de matiz e de grayscale, e ja da uma familia por arma.
##
## O numero que separa nao e gosto, e o MIOLO -- os pixels interiores, que sao os
## que carregam a forma depois que o contorno e descontado. Medido nas oito artes
## geradas, a separacao e limpa e nao tem caso no meio:
##
##     gravity_gun 206   onda_guardiao 144   tiro_vigia  91
##     tiro_diretora 88  boomer         75   salva_diretora 67
##     ------------------------------------------------ MIOLO_MINIMO = 64
##     tiro_drone     54   sucata_guardiao 12
##
## E o veredicto bate com o olho: `tiro_drone` sai um disco cortado e
## `sucata_guardiao` -- um CLUSTER, que e feito de pedacos soltos -- vira poeira,
## 12 pixels espalhados. As seis acima do corte leem como a forma que pedem.
##
## Duas coisas foram aprendidas e ficam registradas, porque a proxima pessoa vai
## refazer as duas se nao estiverem escritas:
##
##   - **A paleta forcada precisa ter TODOS os degraus competindo** (s > 0,35 e
##     v > 0,55). Com um degrau escuro o gerador o usa para SOMBREAR, e num
##     sprite de 16 px o sombreado ocupa quase todo o miolo: a fonte nasce em
##     15% de miolo competindo, contra o piso de 70%. Nao e a reducao que
##     derruba -- a fonte ja nasce assim.
##   - **O aspecto nao se obtem por prompt.** Cinco reformulacoes deram bbox
##     entre 3:1 e 8:1 onde o alvo era 2:1. Quem resolve e
##     `gerar_projeteis.py --comprimento=N`, que apara a CAUDA ate o comprimento
##     que `FormasProjetil` declara.
##
## A lista so encolhe quando arte NOVA passar do corte -- e o portao abaixo cobra
## o corte, entao ninguem a encolhe com arte que nao leria.
## O `laser_cutter` NAO entra: ele e feixe, nao tem projetil, e `_armas()` o
## exclui na varredura. Uma arma de raio contínuo listada aqui faria a conta de
## pendentes divergir da conta de armas -- e foi exatamente o que aconteceu.
const POLIGONO_POR_DECISAO: Array[String] = [
	"nanite_rifle",
	"phase_blaster",
	"pistola",
	"pistola_cipher",
	"plasma_arc",
	"rail_x",
	"shotgun",
	"smg_mantis",
	"sucata_guardiao",
	"swarm",
	"tiro_drone",
	"tiro_neon",
	"tiro_sentinela",
	"volt_caster",
]

## O miolo minimo para uma arte valer mais que o poligono. A tabela esta acima.
const MIOLO_MINIMO := 64

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
	_toda_familia_declarada_existe_na_biblioteca()
	_cor_proxima_obriga_silhueta_diferente()
	_o_projetil_se_acha_no_chao_do_proprio_matiz()
	_o_rastro_cabe_no_vao_entre_dois_tiros()
	_so_a_Forma_tem_colisao()
	_toda_familia_de_impacto_existe()
	_o_buraco_de_arte_esta_DECLARADO()
	_toda_arte_tem_MIOLO_para_carregar_a_forma()
	_nenhum_tres_grava_campo_que_o_comportamento_nao_le()
	_nenhum_par_e_identico_em_GRAYSCALE()


## Em GRAYSCALE a cor some, e o que resta tem de bastar.
##
## E o §50 do plano aplicado ao elenco: se duas armas so se distinguem por MATIZ,
## elas nao se distinguem para quem tem daltonismo, nem numa captura em tons de
## cinza, nem no canto do olho durante o combate -- que e onde um projetil e
## lido. A cor e a ultima pista, e nao a primeira.
##
## O portao de cor proxima ja obriga silhueta diferente entre armas de matiz
## vizinho. Este e o complemento e ele morde noutro lugar: duas armas de matiz
## DISTANTE, que por isso passam la, e que desenham exatamente a mesma coisa.
##
## Sem cor, o desenho e a familia, o raio e o alongamento. Iguais os tres, sao a
## mesma arma. Medido quando este caso foi escrito: SETE pares, e tres deles
## cruzando a fronteira que mais importa -- `rail_x` contra `tiro_neon`,
## `pistola_cipher` e `shotgun` contra `tiro_sentinela`. O
## `IDENTIDADE_VISUAL.md` diz com todas as letras que *"a distincao que importa e
## tiro-do-jogador contra tiro-de-inimigo"*.
##
## O `alongamento_silhueta` existe para isto: ele estica no eixo do VOO, que e o
## eixo livre, entao duas armas da mesma familia se separam sem nenhuma delas
## mentir sobre a hitbox.
func _nenhum_par_e_identico_em_GRAYSCALE() -> void:
	var nomes := _armas()
	var identicos := 0
	for i in nomes.size():
		for j in range(i + 1, nomes.size()):
			var a := _arma(nomes[i])
			var b := _arma(nomes[j])
			if a == null or b == null:
				continue
			if a.familia_silhueta != b.familia_silhueta:
				continue
			if absf(a.raio_projetil - b.raio_projetil) >= DIFERENCA_DE_RAIO:
				continue
			if absf(a.alongamento_silhueta - b.alongamento_silhueta) >= DIFERENCA_DE_ALONGAMENTO:
				continue
			identicos += 1
			ok(
				false,
				"%s e %s desenham a MESMA coisa sem cor (%s, raio %.1f, alongamento %.2f)"
					% [nomes[i], nomes[j], FormasProjetil.nome(a.familia_silhueta),
						a.raio_projetil, a.alongamento_silhueta]
			)
	igual(identicos, 0, "nenhum par de armas e identico em grayscale")

	# E o outro lado: se NENHUMA arma dividisse familia com outra, este portao
	# nunca teria olhado nada. Ele so tem sentido porque as familias sao oito e as
	# armas sao vinte -- dividir familia e o normal, e o que se cobra e o que
	# separa duas que dividem.
	var compartilham := 0
	for i in nomes.size():
		for j in range(i + 1, nomes.size()):
			var a := _arma(nomes[i])
			var b := _arma(nomes[j])
			if a != null and b != null and a.familia_silhueta == b.familia_silhueta:
				compartilham += 1
	ok(
		compartilham > 0,
		"ha pares que dividem familia (%d) -- senao este portao mede o vazio"
			% compartilham
	)


## O buraco de arte e declarado, e a lista morde dos DOIS lados.
##
## `textura_projetil` nulo nao da erro nenhum: o projetil cai no losango e o jogo
## segue. Sem esta lista as 21 nulas passariam para sempre, e o portao de par
## (cor, silhueta) ficaria provando uma promessa em vez de uma tela.
##
## As duas metades importam igual, e e a segunda que costuma faltar:
##
##   nome FORA da lista  -> tem de ter textura, e ela tem de CARREGAR
##   nome DENTRO da lista -> tem de continuar nulo
##
## Sem a segunda, a linha fica aqui depois de a arte chegar e cobre em silencio o
## dia em que aquele PNG se perder. Mesmo desenho de `POLIGONO_POR_DECISAO` no
## `teste_sprite_direcional.gd` e de `SEM_CLIPE_AINDA` no `teste_boss_animacao.gd`.
##
## Tirar um nome daqui e o interruptor de "a arte chegou".
func _o_buraco_de_arte_esta_DECLARADO() -> void:
	var pendentes := 0
	for nome in _armas():
		var dados := _arma(nome)
		if dados == null:
			continue
		if POLIGONO_POR_DECISAO.has(nome):
			pendentes += 1
			ok(
				dados.textura_projetil == null,
				"%s esta declarada SEM arte, e continua sem -- senao a lista mente" % nome
			)
			continue
		ok(
			dados.textura_projetil != null,
			"%s nao esta na lista de pendentes, entao tem de ter arte" % nome
		)
	igual(
		pendentes, POLIGONO_POR_DECISAO.size(),
		"toda arma listada como pendente foi encontrada no disco"
	)


## Toda arma declara uma silhueta que a biblioteca sabe desenhar.
##
## O enum e gravado como INT no `.tres`. Um valor digitado a mao, ou o
## sobrevivente de um enum que encolheu, **carrega sem erro nenhum** -- e o
## projetil nasce com poligono vazio: invisivel, com a hitbox intacta. E o pior
## defeito possivel num bullet hell, e nao ha uma linha no console.
func _toda_familia_declarada_existe_na_biblioteca() -> void:
	var vistas := 0
	for nome in _armas():
		var dados := _arma(nome)
		if dados == null:
			continue
		vistas += 1
		ok(
			FormasProjetil.existe(dados.familia_silhueta),
			"%s declara uma familia que existe (%d = %s)"
				% [nome, dados.familia_silhueta, FormasProjetil.nome(dados.familia_silhueta)]
		)
	ok(vistas >= 15, "a varredura achou as armas do jogo (%d)" % vistas)


## Cor PROXIMA obriga silhueta DIFERENTE.
##
## Cor repetida continua PERMITIDA, e tem de continuar: a `Paleta` mediu quatro
## faixas de matiz livres para 21 armas -- proibir repeticao de cor seria proibir
## armas. O que se proibe e cor proxima com a MESMA silhueta.
##
## Compara MATIZ, e nao canal. `Paleta.mesma_cor()` responde a outra pergunta --
## "e o mesmo valor gravado?" -- com tolerancia de 1,5/255 por canal, e deixaria
## passar `pistola` contra `volt_caster`, que estao a 2,2 graus e sao os dois o
## mesmo ciano. Medido antes deste epico: DEZ dos 210 pares estavam a menos de
## `LARGURA_MATIZ`, dois deles com RGB identico, e as 21 armas desenhavam a mesma
## forma.
##
## `LARGURA_MATIZ` nao sai da distancia entre vizinhos. A formula obvia -- metade
## da menor distancia -- foi medida e da +-1,1 grau, o que obrigaria arte chapada,
## sem rampa de sombra (rampa de pixel art desloca matiz). O numero e o que a
## ARTE precisa, e o aperto vira pressao sobre a SILHUETA, que e o objetivo.
func _cor_proxima_obriga_silhueta_diferente() -> void:
	var nomes := _armas()
	var colisoes := 0
	var proximos := 0
	for i in nomes.size():
		for j in range(i + 1, nomes.size()):
			var a := _arma(nomes[i])
			var b := _arma(nomes[j])
			if a == null or b == null:
				continue
			var d := _distancia_de_matiz(a.cor_projetil, b.cor_projetil)
			if d >= LARGURA_MATIZ:
				continue
			proximos += 1
			if a.familia_silhueta != b.familia_silhueta:
				continue
			colisoes += 1
			ok(
				false,
				"%s e %s estao a %.1f graus e desenham a MESMA silhueta (%s)"
					% [nomes[i], nomes[j], d, FormasProjetil.nome(a.familia_silhueta)]
			)
	igual(colisoes, 0, "nenhum par de cor proxima divide silhueta")
	ok(
		proximos > 0,
		"a regua encontrou pares proximos de verdade (%d) -- senao ela mede o vazio"
			% proximos
	)


## O rastro nao emenda com o tiro seguinte.
##
## Trilha mais longa que o vao entre dois tiros (`velocidade / cadencia`) vira um
## risco SOLIDO na tela, e o jogador perde a CONTAGEM de projeteis -- que e a
## leitura que o bullet hell cobra.
##
## Antes deste campo o rastro era cravado em `raio * 6` para as 21 armas, e tres
## reprovavam esta conta: `onda_guardiao` desenhava 96 px de trilha sobre um vao
## de 26, `sucata_guardiao` 42 sobre 21, `salva_diretora` 36 sobre 32. Os dois
## primeiros sao do CHEFE, na sala mais densa de projetil do jogo.
##
## O piso do outro lado importa tanto quanto: sem ao menos uma arma com rastro, o
## caso mede o conjunto vazio e vira carimbo.
func _o_rastro_cabe_no_vao_entre_dois_tiros() -> void:
	var com_rastro := 0
	for nome in _armas():
		var dados := _arma(nome)
		if dados == null or dados.rastro_comprimento <= 0.0:
			continue
		com_rastro += 1
		var trilha := dados.rastro_comprimento * dados.raio_projetil
		var vao := dados.velocidade_projetil / maxf(dados.cadencia, 0.001)
		ok(
			trilha < vao,
			"%s: a trilha de %.0f px cabe no vao de %.0f px entre dois tiros"
				% [nome, trilha, vao]
		)
	ok(
		com_rastro > 0,
		"ao menos uma arma tem rastro (%d) -- senao este portao e um carimbo"
			% com_rastro
	)


## Toda familia de impacto declarada existe na tabela de perfis.
##
## Mesmo defeito silencioso da silhueta: o valor e INT no `.tres`, um numero fora
## da faixa carrega sem erro, e `vestir()` cairia no perfil default -- o projetil
## bateria como bala sem ninguem ter pedido isso. O eixo e SEPARADO do da
## silhueta de proposito: a forma diz o que voa, o impacto diz o que aquilo fez.
func _toda_familia_de_impacto_existe() -> void:
	var usadas: Array[int] = []
	for nome in _armas():
		var dados := _arma(nome)
		if dados == null:
			continue
		ok(
			Impactos.existe(dados.familia_impacto),
			"%s declara um impacto que existe (%d = %s)"
				% [nome, dados.familia_impacto, Impactos.nome(dados.familia_impacto)]
		)
		if not usadas.has(dados.familia_impacto):
			usadas.append(dados.familia_impacto)
	ok(
		usadas.size() >= 3,
		"e o elenco usa mais de uma familia de impacto (%d) -- senao a tabela e enfeite"
			% usadas.size()
	)
	for familia in Impactos.Familia.values():
		ok(
			Impactos.existe(familia),
			"a tabela tem perfil para %s" % Impactos.nome(familia)
		)


## A colisao do projetil mora num lugar so.
##
## Nem o rastro, nem o halo, nem a arte, nem o no que alguem pendurar amanha. E
## assim que "rastro nunca tem hitbox" deixa de ser promessa e vira portao.
##
## Le a cena por `PackedScene.get_state()`, sem instanciar -- a mesma receita que
## `teste_texturas` usa para ler `cor_base` sem subir inimigo.
func _so_a_Forma_tem_colisao() -> void:
	var cena: PackedScene = load(CENA_PROJETIL)
	if cena == null:
		ok(false, "a cena do projetil carrega")
		return
	var estado := cena.get_state()
	var formas: Array[String] = []
	for i in estado.get_node_count():
		if estado.get_node_type(i) == &"CollisionShape2D":
			formas.append(String(estado.get_node_name(i)))
	igual(formas.size(), 1, "o projetil tem exatamente uma colisao (%s)" % str(formas))
	if formas.size() == 1:
		igual(formas[0], "Forma", "e ela se chama Forma")


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


## Os `.tres` de arma do disco, sem o FEIXE.
##
## O Laser Cutter nao instancia projetil -- ele desenha um `Line2D` --, entao
## silhueta, rastro e moldura nao querem dizer nada nele. Varre a pasta em vez de
## uma lista fixa: lista fixa apodrece nas duas direcoes.
func _armas() -> Array[String]:
	var fora: Array[String] = []
	var pasta := DirAccess.open(ARMAS)
	if pasta == null:
		return fora
	var arquivos := pasta.get_files()
	arquivos.sort()
	for arquivo in arquivos:
		if not arquivo.ends_with(".tres"):
			continue
		var dados := load(ARMAS + arquivo) as DadosArma
		if dados == null or dados.e_feixe():
			continue
		fora.append(arquivo.get_basename())
	return fora


func _arma(nome: String) -> DadosArma:
	return load(ARMAS + nome + ".tres") as DadosArma


## Distancia angular entre dois matizes, em graus.
##
## Circular: 350 e 10 estao a 20 graus, e nao a 340.
func _distancia_de_matiz(a: Color, b: Color) -> float:
	var d: float = fmod(absf(a.h - b.h), 1.0)
	return minf(d, 1.0 - d) * 360.0


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


## Os CHAOS do andar 1, um por tipo de sala.
##
## As tres variantes de `andar1` sao sorteadas por celula na mesma sala, entao
## para esta pergunta elas sao um chao so -- o que importa e o pior deles.
const CHAOS := {
	"andar1": ["chao_andar1_a", "chao_andar1_b", "chao_andar1_c"],
	"boss": ["chao_boss"],
	"arma": ["chao_arma"],
	"item": ["chao_item"],
}

const PASTA_TEXTURAS := "res://assets/texturas/"

## Quanto o projetil tem de ser mais CLARO que o pixel mais claro do chao, quando
## os dois estao no mesmo matiz.
##
## O portao de paleta ja garante 0,25 por construcao -- o chao tem teto de valor
## 0,30 e o ator tem piso 0,55 --, entao um limiar em 0,25 seria um carimbo:
## ele passaria por definicao, sem nunca olhar um arquivo. Este mede o CHAO REAL
## (percentil 99, e nao o teto declarado) contra o valor do projetil, e o corte
## fica acima do que a construcao garante e abaixo do que a arte de hoje entrega.
##
## Medido nas quatro faixas, contra a arma de matiz mais proximo de cada chao:
##
##     andar1   nanite_rifle    dist 0,8 grau   folga 0,75
##     boss     tiro_diretora   dist 0,1 grau   folga 0,79
##     arma     tiro_drone      dist 1,6 grau   folga 0,74
##     item     tiro_neon       dist 6,6 graus  folga 0,70
##
## O corte em 0,40 morde se o chao clarear ou se um projetil escurecer, e nao
## morde na arte de hoje. E ele existe porque **folga de valor nao e folga de
## matiz**: todo tipo de sala tem ao menos um projetil no matiz do proprio chao,
## e nada provava que a folga de valor bastava.
const FOLGA_DE_VALOR := 0.40


## Um projetil no matiz do proprio chao continua achavel, pelo VALOR.
##
## O andar 1 abriu mao de separar por matiz -- as faixas de chao e as cores de
## arma se cruzam de proposito, porque o setor tem uma paleta so. O que sobrou
## para separar ator de ambiente e o VALOR, e este caso e o que prova que sobrou
## o bastante.
##
## Ele mede o chao pelo percentil 99 e nao pelo maximo: um punhado de pixels de
## acento nao decide se o jogador acha o tiro, e o maximo faria a medicao
## depender do pixel mais claro de um decalque.
func _o_projetil_se_acha_no_chao_do_proprio_matiz() -> void:
	var conferidos := 0
	for tipo: String in CHAOS:
		var claro := -1.0
		var matiz_do_chao := -1.0
		for nome_arquivo: String in CHAOS[tipo]:
			var medida := _chao(nome_arquivo)
			if medida.x < 0.0:
				ok(false, "%s abre" % nome_arquivo)
				continue
			if medida.x > claro:
				claro = medida.x
			matiz_do_chao = medida.y
		if claro < 0.0:
			continue

		# A arma de matiz mais PROXIMO daquele chao -- e o pior caso do tipo.
		var pior := ""
		var menor := 999.0
		for nome_arma in _armas():
			var dados := _arma(nome_arma)
			if dados == null:
				continue
			var d := absf(fposmod(dados.cor_projetil.h * 360.0 - matiz_do_chao + 180.0, 360.0) - 180.0)
			if d < menor:
				menor = d
				pior = nome_arma
		if pior.is_empty():
			continue

		var dados_pior := _arma(pior)
		var folga := dados_pior.cor_projetil.v - claro
		conferidos += 1
		ok(
			folga >= FOLGA_DE_VALOR,
			"chao %s (matiz %.0f, p99 do valor %.2f) contra %s (dist %.1f grau): folga %.2f, minimo %.2f"
				% [tipo, matiz_do_chao, claro, pior, menor, folga, FOLGA_DE_VALOR]
		)
		# A premissa da issue, virada afirmacao: todo tipo TEM um projetil no
		# proprio matiz. No dia em que deixar de ter, este caso passa a medir uma
		# coincidencia em vez do pior caso, e a linha avisa.
		ok(
			menor <= LARGURA_MATIZ,
			"e %s esta mesmo no matiz do chao %s (%.1f grau, faixa %.0f)"
				% [pior, tipo, menor, LARGURA_MATIZ]
		)
	igual(conferidos, CHAOS.size(), "os quatro chaos foram medidos")


## (percentil 99 do valor, matiz mediano) de um chao. `x < 0` quando nao abre.
func _chao(nome_arquivo: String) -> Vector2:
	if not FileAccess.file_exists(PASTA_TEXTURAS + nome_arquivo + ".png"):
		return Vector2(-1.0, -1.0)
	var imagem := Image.load_from_file(
		ProjectSettings.globalize_path(PASTA_TEXTURAS + nome_arquivo + ".png"))
	if imagem == null or imagem.is_empty():
		return Vector2(-1.0, -1.0)
	imagem.convert(Image.FORMAT_RGBA8)
	var valores: Array[float] = []
	var matizes: Array[float] = []
	for y in imagem.get_height():
		for x in imagem.get_width():
			var cor := imagem.get_pixel(x, y)
			valores.append(cor.v)
			if cor.s > 0.02:
				matizes.append(cor.h * 360.0)
	if valores.is_empty():
		return Vector2(-1.0, -1.0)
	valores.sort()
	matizes.sort()
	return Vector2(
		valores[mini(valores.size() - 1, valores.size() * 99 / 100)],
		matizes[matizes.size() / 2] if not matizes.is_empty() else 0.0
	)


## Toda arte de projetil tem MIOLO suficiente para carregar a forma.
##
## O portao de paleta ja cobra que o miolo COMPETE com ator; este cobra que ele
## EXISTE. Sao perguntas diferentes e a segunda pegou o que a primeira deixou
## passar: `sucata_guardiao` media 100% de miolo competindo com **12 pixels de
## miolo** -- todos competiam, e nao havia forma nenhuma.
##
## Sem ele, a lista `POLIGONO_POR_DECISAO` poderia encolher com arte que nao le,
## e a decisao viraria um carimbo.
func _toda_arte_tem_MIOLO_para_carregar_a_forma() -> void:
	var conferidas := 0
	for nome in _armas():
		var dados := _arma(nome)
		if dados == null or dados.textura_projetil == null:
			continue
		var imagem := dados.textura_projetil.get_image()
		if imagem == null or imagem.is_empty():
			ok(false, "%s: a arte abre" % nome)
			continue
		imagem.convert(Image.FORMAT_RGBA8)
		var miolo := 0
		for y in imagem.get_height():
			for x in imagem.get_width():
				if not _opaco(imagem, x, y):
					continue
				if (_opaco(imagem, x - 1, y) and _opaco(imagem, x + 1, y)
						and _opaco(imagem, x, y - 1) and _opaco(imagem, x, y + 1)):
					miolo += 1
		conferidas += 1
		ok(
			miolo >= MIOLO_MINIMO,
			"%s tem miolo para carregar a forma (%d px, minimo %d)"
				% [nome, miolo, MIOLO_MINIMO]
		)
	ok(conferidas > 0, "houve arte para medir (%d)" % conferidas)


func _opaco(imagem: Image, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= imagem.get_width() or y >= imagem.get_height():
		return false
	return imagem.get_pixel(x, y).a >= 0.5


## Nenhum `.tres` grava campo que o proprio comportamento nunca le.
##
## `laser_cutter` gravava `raio_projetil` e `velocidade_projetil`, e FEIXE nao
## instancia projetil -- nao ha raio nem velocidade para ter. `volt_caster` e
## CORRENTE e gravava `largura_feixe`, que so o feixe consulta.
##
## E a armadilha de "numero que foi para o `.tres` tem de SAIR do `.tscn`",
## aplicada a arma: o campo continua no Inspetor, com um valor que parece
## significar algo, e a proxima pessoa que for balancear gira um botao que nao
## esta ligado em nada. Nao ha erro, nao ha sintoma -- so uma tarde perdida.
##
## O portao compara com o DEFAULT do script e nao com uma lista de literais: um
## campo tocado e um campo que alguem quis mudar, e e disso que se trata.
func _nenhum_tres_grava_campo_que_o_comportamento_nao_le() -> void:
	var padrao := DadosArma.new()
	var conferidas := 0
	for nome in _todas_as_armas():
		var dados := _arma(nome)
		if dados == null:
			continue
		conferidas += 1
		if dados.e_feixe():
			# O feixe nao instancia projetil: raio e velocidade nao existem nele.
			perto(
				dados.raio_projetil, padrao.raio_projetil,
				"%s e FEIXE e nao grava raio_projetil" % nome, 0.001
			)
			perto(
				dados.velocidade_projetil, padrao.velocidade_projetil,
				"%s e FEIXE e nao grava velocidade_projetil" % nome, 0.001
			)
		else:
			perto(
				dados.largura_feixe, padrao.largura_feixe,
				"%s nao e feixe e nao grava largura_feixe" % nome, 0.001
			)
	ok(conferidas > 0, "houve arma para conferir (%d)" % conferidas)


## TODAS as armas, feixes inclusive.
##
## `_armas()` pula os feixes de proposito -- os casos de silhueta nao tem o que
## medir num raio que nao existe --, e este caso precisa justamente deles.
func _todas_as_armas() -> Array[String]:
	var fora: Array[String] = []
	var pasta := DirAccess.open(ARMAS)
	if pasta == null:
		return fora
	var arquivos := pasta.get_files()
	arquivos.sort()
	for arquivo in arquivos:
		if arquivo.ends_with(".tres"):
			fora.append(arquivo.get_basename())
	return fora
