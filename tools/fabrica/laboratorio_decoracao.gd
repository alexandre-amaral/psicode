extends Node2D
## O LABORATORIO DE DECORACAO: o que o `DecoradorDeSala` produz, em formas
## chapadas, ANTES de existir um unico prop desenhado.
##
## ## A decisao de design que este arquivo carrega
##
## **Ele e pobre de proposito, como o `tools/teste_paredes.tscn`.** Cada
## colocacao vira um retangulo em que o TAMANHO diz o porte e a COR diz o
## agrupamento, e mais nada -- sem sprite, sem textura, sem atlas. Se a sala
## fica boa assim, o que esta funcionando e a COMPOSICAO; se ela so ficar boa
## depois da arte, o que se aprovou foi a arte cobrindo um arranjo ruim, e isso
## nao se descobre mais.
##
## E ele vem ANTES da arte tambem por preco. A Fase C do plano custa geracao de
## PixelLab: descobrir com 40 props em disco que a distribuicao concentra tudo
## no norte, ou que os clusters nao cabem na faixa, e o mesmo erro que os cinco
## modulos de face ja pagaram uma vez -- desenhados primeiro, medidos depois, e
## a `tubulacao` nao tem ponto que passe.
##
## ## As tres guias sao o assunto da foto, e nao enfeite
##
## O olho nao julga uma nuvem de retangulos; ele julga onde ela esta em relacao
## ao que a sala e. Por isso a folha desenha, em toda sala:
##
##   CONTORNO     a linha de onde nasce parede, colisao e minimapa.
##   FAIXA        a banda de `largura_da_faixa_de_perimetro` para dentro. Ela e
##                desenhada tira por tira, uma por ARESTA, com a normal interna
##                da propria aresta -- as quinas ficam levemente mais claras
##                porque ali duas tiras se somam, e isso e honesto: aquele
##                pedaco pertence as duas.
##   ZONA LIVRE   o disco de `raio_da_zona_livre` no centro. **E a guia mais
##                importante**: e o miolo onde o jogador esquiva e onde o
##                telegrafo desenha, e prop ali nao e cenario, e uma morte que o
##                jogador nao consegue explicar.
##
## ## E as sementes variam porque o julgamento e sobre a DISTRIBUICAO
##
## Uma sala sorteada da para aprovar por sorte. A folha mostra as mesmas formas
## com sementes diferentes lado a lado, e sem janela a regua varre
## `SEMENTES_MEDIDAS` por forma -- o que se julga e o comportamento do sorteio,
## nao um sorteio.
##
## ## DOIS MODOS, e o modo sai do `DisplayServer` e nao de uma bandeira
##
##   godot --path . tools/fabrica/laboratorio_decoracao.tscn --resolution 960x544
##     Com janela: as formas de sala x as sementes, com as tres guias. Fotografa
##     em `user://capturas/decoracao.png` e encerra.
##
##   godot --headless --path . tools/fabrica/laboratorio_decoracao.tscn
##     Sem janela: contagem por porte, fracao na faixa, quantas cairam na zona
##     livre (tem de ser ZERO), distribuicao por lado contra os pesos do perfil,
##     o lado calmo e a maior area de parede vazia. Encerra com 1 se algo
##     reprovar.
##
## Argumentos, sempre depois de um `--` isolado:
##   --ficar   com janela, nao fecha depois da foto
##
## **A regua nao renderiza nada**, nem no modo com janela: tudo aqui sai da
## geometria que o `DecoradorDeSala` devolve. E por isso que ela roda em
## `--headless`, onde nao ha GPU para ler pixel nenhum.
##
## ENCERRA EM TODO CAMINHO DE SAIDA: cena headless que nao encerra vira runaway,
## e um `runner.tscn` esquecido ja acumulou 1574 s de CPU em tres horas girando
## num nucleo.

## As formas que a folha mostra e a regua varre.
##
## Tres formas e nao uma porque a decoracao e feita por ARESTA: o retangulo e o
## caso facil, a sala em L tem a unica quina CONCAVA do jogo (onde duas faixas
## se sobrepoem em vez de deixar vao) e a grande e a que tem miolo sobrando
## depois da zona livre. Uma regra que so vale no retangulo nao vale.
const CENAS: Array[String] = [
	"res://src/mapa/sala_1_retangular.tscn",
	"res://src/mapa/sala_2_l_shape.tscn",
	"res://src/mapa/sala_3_grande.tscn",
]

## Contorno de reserva, se uma cena nao carregar.
##
## Ele existe para a regua nao virar silencio: uma ferramenta que nao acha as
## cenas e nao mede nada, mas imprime "PASSOU", e pior que uma que reprova.
## **`const` nao aceita `PackedVector2Array`**, e o erro nao aparece no
## `--import`: ele so estoura quando alguem CARREGA o script, e a cena entao
## sobe sem script nenhum e fica ociosa para sempre. Foi assim que esta
## ferramenta virou runaway na primeira execucao. Por isso e uma funcao.
static func contorno_de_reserva() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-384.0, -320.0), Vector2(384.0, -320.0),
		Vector2(384.0, 320.0), Vector2(-384.0, 320.0),
	])

## As sementes da FOLHA: uma linha de paineis por semente.
const SEMENTES_NA_JANELA: Array[int] = [20260908, 31337]

## Quantas sementes a regua varre POR FORMA.
##
## 96 x 3 formas = 288 salas por execucao, e o numero sai de uma conta e nao de
## gosto. A medida mais escassa e a do HERO: **e um por sala**, entao a amostra
## dele e o numero de SALAS e nao o de pecas. Com 288 salas o desvio-padrao de
## uma fracao perto de 0,5 fica em ~0,029, e o portao de `DESVIO_MAXIMO_POR_LADO`
## mora a tres desvios dali -- com 32 sementes ficaria a dois, e a regua reprovaria
## o codigo certo de vez em quando, que e o pior defeito que um portao pode ter.
const SEMENTES_MEDIDAS := 96

const SAIDA := "user://capturas"

## Um nome por PORTE, na ordem do enum. Ela cresce junto com ele -- e
## `_zeros_por_porte()` existe para ninguem mais escrever um literal de cinco.
const NOMES_DE_PORTE: Array[String] = [
	"HERO", "GRANDE", "MEDIO", "PEQUENO", "MICRO", "DECALQUE", "PAREDE",
]

## Na ordem do enum `DecoradorDeSala.Lado`: NORTE, LESTE, SUL, OESTE.
const NOMES_DE_LADO: Array[String] = ["norte", "leste", "sul", "oeste"]

## O lado do retangulo desenhado por porte, em pixels de SALA (nao de tela).
##
## Eles nao sao o tamanho de nenhum prop -- prop ainda nao existe. Sao a ORDEM
## de grandeza que `DecoradorDeSala.DISTANCIA_MINIMA` ja declara para cada porte,
## para a folha mostrar massa onde o decorador reserva massa. Desenhar todos do
## mesmo tamanho esconderia justamente o que a faixa de perimetro tem de segurar.
const LADO_DESENHADO: Array[float] = [64.0, 44.0, 28.0, 18.0, 10.0]

## De quanto em quanto se amostra o perimetro ao procurar a maior parede vazia.
##
## 16 e a grade do projeto: todo ponto de contorno cai nela, entao amostrar mais
## fino mede a mesma parede duas vezes.
const PASSO_DO_PERIMETRO := 16.0

## Quanto de parede uma peca "ocupa" ao redor de si, no minimo.
##
## O alcance real de cada peca sai de `DecoradorDeSala.distancia_minima_de()`,
## que ja diz quanto espaco aquele porte reserva -- usar o numero do decorador
## em vez de um proprio impede que a regua e o codigo divirjam no dia em que um
## porte mudar de tamanho. Este piso so cobre o MICRO, que reserva 24 px e
## ocuparia menos que um passo de amostragem.
const COBERTURA_MINIMA := 24.0

## A maior parede vazia, como fracao do perimetro, tem de morar nesta faixa.
##
## O PISO cobra a regra 8 pelo lado de fora: uma sala decorada como anel
## uniforme nao tem lado calmo nenhum, e uma fabrica em que toda parede recebe
## a mesma quantidade de coisa le como papel de parede. O TETO existe porque
## regua que so tem piso aprova o caso degenerado -- uma sala onde nada foi
## colocado tem 100% de parede vazia e passaria com louvor.
const FRACAO_MINIMA_DE_VAZIO := 0.12
const FRACAO_MAXIMA_DE_VAZIO := 0.70

## Quanto a distribuicao medida por lado pode se afastar do peso declarado.
##
## Para as pecas COMUNS o sorteio converge para os pesos EXATOS -- o peso inverso
## do lado calmo foi desenhado para isso. Tres coisas gastam a folga:
##
##   GEOMETRIA   candidata recusada por cair na zona livre, fora do poligono ou
##               perto demais de outra peca. A recusa nao e igual nos quatro
##               lados, porque eles nao tem o mesmo comprimento nem a mesma
##               distancia ate o centro -- na sala em L, a parede que nasce na
##               quina concava perde ~40% das ancoras para a zona livre.
##   O HERO      ele tem pesos PROPRIOS, mas o lado calmo e sorteado com o
##               inverso dos pesos COMUNS -- entao a identidade que devolve os
##               pesos exatos nao vale para ele. A conta da 0,470 onde o `.tres`
##               declara 0,500: **0,03 de desvio sistematico, e nao de amostra**.
##   OS MENORES  PEQUENO e MICRO ainda entram no lado calmo, ate o teto de
##               `PECAS_NO_LADO_VAZIO`, e isso achata a distribuicao em ~0,013.
##
## 0,12 cobre as tres com margem e continua bem abaixo da menor distancia entre
## dois pesos declarados (0,35 contra 0,25).
const DESVIO_MAXIMO_POR_LADO := 0.12

const MARGEM_DO_PAINEL := Vector2(14.0, 30.0)

## As cores do diagnostico. **Elas nao sao arte e nao entram no jogo** -- sao
## rotulos, e por isso podem ser chapadas e claras, o que o cenario do andar 1
## nao pode. O portao de paleta olha `assets/`, e nada aqui e escrito em disco
## como textura.
const CORES_DE_AGRUPAMENTO: Array[Color] = [
	Color(0.95, 0.62, 0.25),
	Color(0.40, 0.80, 0.95),
	Color(0.60, 0.90, 0.45),
	Color(0.90, 0.45, 0.70),
	Color(0.85, 0.85, 0.40),
	Color(0.60, 0.55, 0.95),
]
const COR_AVULSO := Color(0.72, 0.74, 0.80)
const COR_FUNDO := Color(0.04, 0.04, 0.06)
const COR_CHAO := Color(0.09, 0.10, 0.14)
const COR_FAIXA := Color(0.55, 0.70, 1.00, 0.14)
const COR_ZONA_LIVRE := Color(0.95, 0.30, 0.25, 0.14)
const COR_BORDA_DA_ZONA := Color(0.95, 0.35, 0.30, 0.45)
const COR_CONTORNO := Color(0.80, 0.86, 1.00, 0.65)
const COR_ROTULO := Color(1.0, 1.0, 1.0, 0.78)

## Os paineis da folha, prontos para o `_draw`. Vazio no modo headless: sem
## janela nada e desenhado, e a medida nao depende de desenho nenhum.
var _paineis: Array[Dictionary] = []

## Quantas afirmacoes a regua chegou a fazer.
##
## Impresso no fim junto do resultado, e nao e enfeite: um erro de dados -- uma
## cena que nao carrega, uma lista vazia -- faz o laco nao rodar e a saida sair
## verde sem nada ter sido conferido. Regua silenciosa que imprime PASSOU e
## pior que regua que reprova.
var _verificacoes: int = 0


func _ready() -> void:
	# Um frame antes de qualquer coisa, pelo mesmo motivo que o `runner.gd`:
	# `quit()` chamado de dentro do `_ready` nao encerra confiavelmente, e cena
	# headless que nao encerra vira runaway.
	await get_tree().process_frame
	var perfil := _perfil()
	var salas := _salas()
	if DisplayServer.get_name() == "headless":
		_medir(perfil, salas)
		return
	_montar_folha(perfil, salas)
	await _fotografar()


# -- modo headless ----------------------------------------------------------


func _medir(perfil: PerfilDeDecoracao, salas: Array) -> void:
	var falhas := 0
	print("\n=== laboratorio de decoracao ===")
	print("  faixa de perimetro %.0f px   zona livre %.0f px   %d agrupamento(s)"
		% [
			perfil.largura_da_faixa_de_perimetro,
			perfil.raio_da_zona_livre,
			perfil.agrupamentos_validos().size(),
		])

	var formas: Array[Dictionary] = []
	# `Array[int]` e nao `PackedInt32Array`: os dois acumuladores ATRAVESSAM a
	# chamada, e array empacotado tem semantica de VALOR -- somar dentro da
	# funcao somaria numa copia, e a tabela sairia com quatro zeros sem erro
	# nenhum no console.
	var lados_comuns: Array[int] = [0, 0, 0, 0]
	var lados_hero: Array[int] = [0, 0, 0, 0]
	for sala in salas:
		var resumo := _varrer_forma(perfil, sala, lados_comuns, lados_hero)
		formas.append(resumo)

	falhas += _tabela_por_forma(formas)
	falhas += _tabela_por_porte(perfil, formas)
	falhas += _tabela_por_lado(perfil, lados_comuns, lados_hero)
	falhas += _tabela_do_vazio(formas)
	_encerrar(falhas)


## Uma forma de sala, `SEMENTES_MEDIDAS` vezes.
##
## Os contadores de lado sao acumulados GLOBALMENTE (chegam por referencia):
## a distribuicao por lado e uma afirmacao sobre o perfil, e nao sobre uma
## forma -- medida sala a sala ela vira ruido de amostra.
func _varrer_forma(
	perfil: PerfilDeDecoracao,
	sala: Dictionary,
	lados_comuns: Array[int],
	lados_hero: Array[int]
) -> Dictionary:
	var contorno: PackedVector2Array = sala["contorno"]
	var centro := DecoradorDeSala.centro_de(contorno)
	var por_porte := _zeros_por_porte()
	var vazios := PackedFloat32Array()
	var total := 0
	var minimo := 1 << 30
	var maximo := 0
	var fora_da_faixa := 0
	var fora_do_poligono := 0
	var na_zona_livre := 0
	var salas_sem_nada := 0
	var massa_no_calmo := 0
	var pecas_no_calmo := 0

	for i in SEMENTES_MEDIDAS:
		var semente := _semente_medida(i)
		var colocacoes := DecoradorDeSala.decorar(contorno, perfil, semente)
		var calmo := DecoradorDeSala.lado_vazio(perfil, semente)
		total += colocacoes.size()
		minimo = mini(minimo, colocacoes.size())
		maximo = maxi(maximo, colocacoes.size())
		if colocacoes.is_empty():
			salas_sem_nada += 1
		for colocacao in colocacoes:
			var posicao: Vector2 = colocacao["posicao"]
			var porte := int(colocacao["porte"])
			var lado := int(colocacao["lado"])
			por_porte[porte] += 1
			# O DECALQUE fica FORA da conta de lados: ele nao mora na faixa de
			# perimetro e nao segue peso de lado nenhum -- sorteado no poligono
			# inteiro, ele diluiria a medicao dos pesos ate ela nao dizer nada.
			# **O DECALQUE nao entra em regra de POSICAO nenhuma.** Ele e chao
			# pintado: sai da faixa de perimetro, entra no miolo e nao tem lado.
			# As tres regras abaixo existem para proteger a leitura do combate
			# contra coisa que OCUPA ESPACO, e ele nao ocupa -- medir o decalque
			# nelas so faria o portao reprovar o comportamento correto.
			# **PAREDE sai da conta da ZONA LIVRE junto com o decalque**, e o caso
			# que provou isso foi a sala em L: `centro_de()` devolve o centro da
			# CAIXA envolvente, e num L essa caixa tem o centro dentro do
			# recorte -- a parede interna do L passa perto dele. Um tubo preso
			# ali esta na parede, e nao na area de combate, mas a distancia ao
			# centro diz o contrario. Medir PAREDE nesta regra reprova a
			# geometria da sala, e nao a colocacao.
			var conta_zona := (porte != DecoradorDeSala.Porte.DECALQUE
				and porte != DecoradorDeSala.Porte.PAREDE)
			var conta_posicao := porte != DecoradorDeSala.Porte.DECALQUE
			if porte == DecoradorDeSala.Porte.DECALQUE:
				pass
			elif porte == DecoradorDeSala.Porte.HERO:
				lados_hero[lado] += 1
			else:
				lados_comuns[lado] += 1
			# Dentro do poligono vale para TODO MUNDO, decalque inclusive: peca
			# desenhada fora da sala e defeito em qualquer porte.
			if not Geometry2D.is_point_in_polygon(posicao, contorno):
				fora_do_poligono += 1
			if conta_zona and posicao.distance_to(centro) < perfil.raio_da_zona_livre - 0.001:
				na_zona_livre += 1
			if not conta_posicao:
				continue
			var profundidade := DecoradorDeSala.distancia_ao_contorno(posicao, contorno)
			if profundidade > perfil.largura_da_faixa_de_perimetro + 0.001:
				fora_da_faixa += 1
			if lado == calmo:
				pecas_no_calmo += 1
				if porte < DecoradorDeSala.Porte.PEQUENO:
					massa_no_calmo += 1
		vazios.append(_maior_vao_vazio(contorno, colocacoes))

	vazios.sort()
	if minimo == (1 << 30):
		minimo = 0
	return {
		"nome": sala["nome"],
		"perimetro": _perimetro(contorno),
		"salas": SEMENTES_MEDIDAS,
		"total": total,
		"minimo": minimo,
		"maximo": maximo,
		"por_porte": por_porte,
		"fora_da_faixa": fora_da_faixa,
		"fora_do_poligono": fora_do_poligono,
		"na_zona_livre": na_zona_livre,
		"salas_sem_nada": salas_sem_nada,
		"massa_no_calmo": massa_no_calmo,
		"pecas_no_calmo": pecas_no_calmo,
		"vazios": vazios,
	}


## As sementes da varredura, espalhadas de proposito.
##
## Sementes CONSECUTIVAS nao servem: o PCG comeca sementes vizinhas em estados
## vizinhos, e a primeira saida e a mais correlacionada entre elas -- e a mesma
## razao pela qual `LuzDeFabrica._sortear()` descarta o primeiro saque. Uma
## regua semeada com 0, 1, 2, 3 mede a correlacao do gerador junto com a do
## decorador.
func _semente_medida(indice: int) -> int:
	return 20260908 + indice * 7919


func _tabela_por_forma(formas: Array[Dictionary]) -> int:
	var falhas := 0
	print("\n--- as formas medidas (%d sementes cada) ---\n" % SEMENTES_MEDIDAS)
	print("%-22s %7s %5s %5s %8s %8s %9s" % [
		"forma", "pecas", "min", "max", "na zona", "fora", "vazias",
	])
	print("-".repeat(70))
	for forma in formas:
		var salas := int(forma["salas"])
		print("%-22s %7.1f %5d %5d %8d %8d %9d" % [
			forma["nome"],
			float(forma["total"]) / float(maxi(salas, 1)),
			forma["minimo"],
			forma["maximo"],
			forma["na_zona_livre"],
			int(forma["fora_da_faixa"]) + int(forma["fora_do_poligono"]),
			forma["salas_sem_nada"],
		])
		falhas += _cobrar(
			int(forma["na_zona_livre"]) == 0,
			"%s: nada na zona livre de combate" % forma["nome"])
		falhas += _cobrar(
			int(forma["fora_da_faixa"]) == 0,
			"%s: toda peca dentro da faixa de perimetro" % forma["nome"])
		falhas += _cobrar(
			int(forma["fora_do_poligono"]) == 0,
			"%s: toda peca dentro do poligono" % forma["nome"])
		falhas += _cobrar(
			int(forma["salas_sem_nada"]) == 0,
			"%s: nenhuma sala saiu sem decoracao" % forma["nome"])
	return falhas


## Um acumulador com UMA casa por porte, dimensionado pelo ENUM.
##
## Ele nasceu de um estouro: os dois acumuladores eram literais de cinco casas,
## e no dia em que `DECALQUE` e `PAREDE` entraram no fim do enum a regua morreu
## com "Out of bounds get index '5'" -- depois de ja ter impresso o cabecalho,
## entao a saida parecia meio certa. Literal indexado por enum e uma constante
## esperando o enum crescer.
func _zeros_por_porte() -> PackedInt32Array:
	var zeros := PackedInt32Array()
	zeros.resize(DecoradorDeSala.Porte.size())
	zeros.fill(0)
	return zeros


func _tabela_por_porte(perfil: PerfilDeDecoracao, formas: Array[Dictionary]) -> int:
	print("\n--- contagem por porte (media por sala x faixa declarada) ---\n")
	print("%-10s %10s %14s   %s" % ["porte", "medido", "declarado", "leitura"])
	print("-".repeat(62))
	var salas := 0
	var somas := _zeros_por_porte()
	for forma in formas:
		salas += int(forma["salas"])
		var por_porte: PackedInt32Array = forma["por_porte"]
		for porte in DecoradorDeSala.Porte.size():
			somas[porte] += por_porte[porte]
	for porte in DecoradorDeSala.Porte.size():
		var faixa := DecoradorDeSala.faixa_de_porte(perfil, porte)
		var media := float(somas[porte]) / float(maxi(salas, 1))
		var leitura := "na faixa"
		if media < float(mini(faixa.x, faixa.y)):
			leitura = "abaixo -- as candidatas nao couberam"
		elif media > float(maxi(faixa.x, faixa.y)):
			leitura = "acima -- os clusters pagam por cima do alvo"
		print("%-10s %10.2f %7d a %-6d   %s"
			% [NOMES_DE_PORTE[porte], media, mini(faixa.x, faixa.y),
				maxi(faixa.x, faixa.y), leitura])
	# Nao ha portao aqui, e a ausencia e deliberada: o cluster e ATOMICO e entra
	# inteiro, entao um conjunto hidraulico com dois barris ja entrega dois
	# MEDIO por cima do alvo avulso. Cravar um teto aqui reprovaria o decorador
	# fazendo exatamente o que o cabecalho dele promete.
	print("\n  (o cluster e atomico: ele pode passar do alvo, e passar e certo)")
	return 0


func _tabela_por_lado(
	perfil: PerfilDeDecoracao,
	lados_comuns: Array[int],
	lados_hero: Array[int]
) -> int:
	var falhas := 0
	print("\n--- distribuicao por lado (desvio maximo %.2f) ---\n"
		% DESVIO_MAXIMO_POR_LADO)
	falhas += _uma_distribuicao("comum", lados_comuns, perfil, false)
	falhas += _uma_distribuicao("hero", lados_hero, perfil, true)
	return falhas


## Uma tabela de lados contra os pesos declarados.
##
## HERO e o resto sao medidos SEPARADOS porque o perfil declara dois conjuntos
## de peso, e misturar os dois compararia a distribuicao de um com a soma dos
## dois -- um numero que nao descreve `.tres` nenhum.
func _uma_distribuicao(
	rotulo: String, contagem: Array[int], perfil: PerfilDeDecoracao, hero: bool
) -> int:
	var total := 0
	for lado in 4:
		total += contagem[lado]
	if total <= 0:
		print("  %s: nenhuma peca medida -- a regua nao olhou para nada" % rotulo)
		return 1
	var soma_dos_pesos := 0.0
	for lado in 4:
		soma_dos_pesos += _peso(perfil, lado, hero)
	var pior := 0.0
	print("  %s (%d peca(s)):" % [rotulo, total])
	for lado in 4:
		var medido := float(contagem[lado]) / float(total)
		var declarado := _peso(perfil, lado, hero) / maxf(soma_dos_pesos, 0.0001)
		var desvio := absf(medido - declarado)
		pior = maxf(pior, desvio)
		print("    %-6s medido %5.1f%%   declarado %5.1f%%   desvio %.3f"
			% [NOMES_DE_LADO[lado], medido * 100.0, declarado * 100.0, desvio])
	return _cobrar(
		pior <= DESVIO_MAXIMO_POR_LADO,
		"%s: pior desvio %.3f <= %.2f" % [rotulo, pior, DESVIO_MAXIMO_POR_LADO])


func _peso(perfil: PerfilDeDecoracao, lado: int, hero: bool) -> float:
	if hero:
		return maxf(DecoradorDeSala.peso_de_hero_do_lado(perfil, lado), 0.0)
	return maxf(DecoradorDeSala.peso_do_lado(perfil, lado), 0.0)


## A regra do VAZIO, medida pelos dois lados que ela tem.
##
## Pelo LADO CALMO: o decorador escolhe um lado por sala e so deixa os dois
## portes menores entrarem nele, ate `PECAS_NO_LADO_VAZIO`. Isso e cobravel sem
## reimplementar nada, porque cada colocacao ja devolve o `lado` em que caiu.
##
## E pela PAREDE: a maior corrida de perimetro sem nenhuma peca por perto. Ela
## responde a pergunta que o lado calmo nao responde -- um andar pode ter lado
## calmo e ainda assim vestir todas as paredes de anel uniforme, se as pecas se
## espalharem igualmente pelos outros tres.
func _tabela_do_vazio(formas: Array[Dictionary]) -> int:
	var falhas := 0
	print("\n--- o vazio: lado calmo e a maior parede sem nada ---\n")
	print("%-22s %10s %10s %12s %12s" % [
		"forma", "no calmo", "massa la", "vazio med.", "em px",
	])
	print("-".repeat(70))
	for forma in formas:
		var vazios: PackedFloat32Array = forma["vazios"]
		var mediana := _mediana(vazios)
		var salas := int(forma["salas"])
		print("%-22s %10.2f %10d %11.1f%% %12.0f" % [
			forma["nome"],
			float(forma["pecas_no_calmo"]) / float(maxi(salas, 1)),
			forma["massa_no_calmo"],
			mediana * 100.0,
			mediana * float(forma["perimetro"]),
		])
		falhas += _cobrar(
			int(forma["massa_no_calmo"]) == 0,
			"%s: nenhuma peca de MASSA no lado calmo" % forma["nome"])
		falhas += _cobrar(
			float(forma["pecas_no_calmo"]) / float(maxi(salas, 1))
				<= float(DecoradorDeSala.PECAS_NO_LADO_VAZIO) + 0.001,
			"%s: o lado calmo respeita o teto de %d peca(s)"
				% [forma["nome"], DecoradorDeSala.PECAS_NO_LADO_VAZIO])
		falhas += _cobrar(
			mediana >= FRACAO_MINIMA_DE_VAZIO,
			"%s: ha parede vazia (%.1f%% >= %.0f%%)"
				% [forma["nome"], mediana * 100.0, FRACAO_MINIMA_DE_VAZIO * 100.0])
		falhas += _cobrar(
			mediana <= FRACAO_MAXIMA_DE_VAZIO,
			"%s: a sala nao esta vazia (%.1f%% <= %.0f%%)"
				% [forma["nome"], mediana * 100.0, FRACAO_MAXIMA_DE_VAZIO * 100.0])
	return falhas


## A maior corrida de perimetro sem peca por perto, como fracao do perimetro.
##
## A busca e CIRCULAR: o perimetro nao tem comeco, e uma corrida que atravessa o
## primeiro vertice e tao vazia quanto qualquer outra. Sem isso, uma sala com a
## parede norte inteira limpa mediria dois pedacos pela metade.
## **O DECALQUE nao ocupa parede, e por isso sai desta conta.**
##
## A regra do vazio (secao 29 do briefing) pergunta se sobrou um TRECHO DE
## PAREDE relativamente limpo -- ela existe para a decoracao alternar cheio e
## vazio em vez de virar ruido uniforme. Mancha de oleo no chao perto da parede
## nao deixa a parede ocupada; contando-a, a sala em L media 11,8% de vao
## maximo contra o piso de 12% e reprovava por causa de sujeira PINTADA NO CHAO,
## com a parede de fato vazia atras dela.
func _maior_vao_vazio(contorno: PackedVector2Array, colocacoes: Array[Dictionary]) -> float:
	var amostras := _amostrar_perimetro(contorno)
	var n := amostras.size()
	if n <= 0:
		return 0.0
	var na_parede: Array[Dictionary] = []
	for colocacao in colocacoes:
		if int(colocacao["porte"]) != DecoradorDeSala.Porte.DECALQUE:
			na_parede.append(colocacao)
	var marcas := _projecoes(contorno, na_parede)
	var livre: Array[bool] = []
	for ponto in amostras:
		livre.append(not _coberto(ponto, marcas))
	var maior := 0
	var atual := 0
	for i in n * 2:
		if livre[i % n]:
			atual += 1
			maior = maxi(maior, mini(atual, n))
		else:
			atual = 0
	return float(maior) / float(n)


func _amostrar_perimetro(contorno: PackedVector2Array) -> Array[Vector2]:
	var amostras: Array[Vector2] = []
	var n := contorno.size()
	if n < 2:
		return amostras
	for i in n:
		var a := contorno[i]
		var b := contorno[(i + 1) % n]
		var comprimento := a.distance_to(b)
		var passos := maxi(1, int(ceilf(comprimento / PASSO_DO_PERIMETRO)))
		for k in passos:
			amostras.append(a.lerp(b, float(k) / float(passos)))
	return amostras


## Cada peca PROJETADA na parede, com o quanto dela ela ocupa.
##
## A projecao nao e refinamento: sem ela a medida esta simplesmente errada. A
## peca nasce DENTRO da faixa -- de 8 ate quase 96 px do contorno --, entao a
## distancia dela ate a parede ja gasta o alcance inteiro de um MEDIO, e uma
## sala cheia mediria "parede vazia" de ponta a ponta. O que a pergunta quer
## saber e quanto de PAREDE tem alguma coisa na frente, e isso se mede no ponto
## do contorno mais proximo da peca.
##
## O alcance sai de `DecoradorDeSala.distancia_minima_de()` -- quanto aquele
## porte ja reserva para si -- e nao de um numero proprio. Regua com numero
## proprio diverge do codigo no dia em que um porte mudar de tamanho, e a
## divergencia nao aparece no console.
func _projecoes(contorno: PackedVector2Array, colocacoes: Array[Dictionary]) -> Array:
	var marcas: Array = []
	var n := contorno.size()
	for colocacao in colocacoes:
		var posicao: Vector2 = colocacao["posicao"]
		var porte := int(colocacao["porte"])
		var perto := posicao
		var menor := INF
		for i in n:
			var candidato := Geometry2D.get_closest_point_to_segment(
				posicao, contorno[i], contorno[(i + 1) % n])
			var distancia := candidato.distance_to(posicao)
			if distancia < menor:
				menor = distancia
				perto = candidato
		marcas.append([
			perto,
			maxf(COBERTURA_MINIMA, DecoradorDeSala.distancia_minima_de(porte) * 0.5),
		])
	return marcas


func _coberto(ponto: Vector2, marcas: Array) -> bool:
	for marca in marcas:
		var onde: Vector2 = marca[0]
		var alcance: float = marca[1]
		if onde.distance_to(ponto) <= alcance:
			return true
	return false


func _perimetro(contorno: PackedVector2Array) -> float:
	var total := 0.0
	var n := contorno.size()
	for i in n:
		total += contorno[i].distance_to(contorno[(i + 1) % n])
	return total


func _mediana(valores: PackedFloat32Array) -> float:
	if valores.is_empty():
		return 0.0
	return valores[valores.size() / 2]


func _cobrar(condicao: bool, descricao: String) -> int:
	_verificacoes += 1
	if condicao:
		return 0
	print("    [FALHA] %s" % descricao)
	return 1


func _encerrar(falhas: int) -> void:
	print("\n--- resultado ---")
	print("  %d verificacao(oes)" % _verificacoes)
	if _verificacoes <= 0:
		print("  FALHOU: a regua nao chegou a conferir nada")
		get_tree().quit(1)
		return
	if falhas > 0:
		print("  FALHOU: %d problema(s)" % falhas)
		get_tree().quit(1)
		return
	print("  PASSOU")
	get_tree().quit()


# -- modo com janela --------------------------------------------------------


func _montar_folha(perfil: PerfilDeDecoracao, salas: Array) -> void:
	var quadro := get_viewport().get_visible_rect().size
	var colunas := maxi(salas.size(), 1)
	var linhas := maxi(SEMENTES_NA_JANELA.size(), 1)
	var celula := Vector2(quadro.x / float(colunas), quadro.y / float(linhas))
	var cores := _cores_por_agrupamento(perfil)

	for linha in linhas:
		for coluna in colunas:
			var sala: Dictionary = salas[coluna]
			var semente: int = SEMENTES_NA_JANELA[linha]
			var contorno: PackedVector2Array = sala["contorno"]
			var colocacoes := DecoradorDeSala.decorar(contorno, perfil, semente)
			var calmo := DecoradorDeSala.lado_vazio(perfil, semente)
			var caixa := _caixa(contorno)
			var util := celula - Vector2(MARGEM_DO_PAINEL.x * 2.0, MARGEM_DO_PAINEL.y * 2.0)
			var escala := minf(util.x / caixa.size.x, util.y / caixa.size.y)
			var canto := Vector2(celula.x * float(coluna), celula.y * float(linha))
			var origem := canto + (celula - caixa.size * escala) * 0.5
			_paineis.append({
				"contorno": contorno,
				"colocacoes": colocacoes,
				"perfil": perfil,
				"cores": cores,
				"origem": origem - caixa.position * escala,
				"escala": escala,
			})
			_rotulo(
				canto + Vector2(8.0, 4.0),
				"%s  semente %d" % [sala["nome"], semente])
			_rotulo(
				canto + Vector2(8.0, 16.0),
				"%d pecas   lado calmo: %s" % [colocacoes.size(), NOMES_DE_LADO[calmo]])

	_rotulo(
		Vector2(8.0, quadro.y - 16.0),
		("faixa %.0f px (azul)   zona livre %.0f px (vermelho)   "
			+ "tamanho = porte, cor = agrupamento")
			% [perfil.largura_da_faixa_de_perimetro, perfil.raio_da_zona_livre])
	queue_redraw()


## O `_draw` do NO RAIZ, e nao um no por painel.
##
## Os rotulos sao `Label`, que sao filhos e desenham DEPOIS do pai -- entao eles
## ficam por cima sem precisar de camada nenhuma. E o fundo e pintado aqui
## dentro pelo mesmo motivo invertido: um `ColorRect` de fundo seria filho, e
## filho cobriria o desenho inteiro.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size), COR_FUNDO)
	for painel in _paineis:
		var origem: Vector2 = painel["origem"]
		var escala := float(painel["escala"])
		draw_set_transform(origem, 0.0, Vector2.ONE * escala)
		_desenhar_painel(painel)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _desenhar_painel(painel: Dictionary) -> void:
	var contorno: PackedVector2Array = painel["contorno"]
	var perfil: PerfilDeDecoracao = painel["perfil"]
	var cores: Dictionary = painel["cores"]
	var escala := float(painel["escala"])

	draw_colored_polygon(contorno, COR_CHAO)
	_desenhar_faixa(contorno, perfil.largura_da_faixa_de_perimetro)

	var centro := DecoradorDeSala.centro_de(contorno)
	draw_circle(centro, perfil.raio_da_zona_livre, COR_ZONA_LIVRE)
	draw_arc(centro, perfil.raio_da_zona_livre, 0.0, TAU, 64, COR_BORDA_DA_ZONA, 2.0 / escala)

	var fechado := contorno.duplicate()
	fechado.append(contorno[0])
	draw_polyline(fechado, COR_CONTORNO, 2.0 / escala)

	for colocacao in painel["colocacoes"]:
		_desenhar_colocacao(colocacao, cores, escala)


## A faixa, tira por tira -- uma por ARESTA, com a normal interna dela.
##
## Nao ha `offset_polygon` aqui de proposito: o recuo de um poligono depende da
## ORIENTACAO dele, e o contorno chega horario ou anti-horario conforme quem
## desenhou o `Line2D` daquela sala -- a mesma armadilha que
## `DecoradorDeSala._normal_interna()` resolve testando o ponto em vez de
## assumir o sentido. A tira por aresta nao tem esse problema, e o custo e
## visivel e honesto: nas quinas duas tiras se somam e o azul fica mais forte,
## que e exatamente o pedaco de faixa que pertence aos dois lados.
func _desenhar_faixa(contorno: PackedVector2Array, largura: float) -> void:
	var n := contorno.size()
	for i in n:
		var a := contorno[i]
		var b := contorno[(i + 1) % n]
		if a.distance_to(b) < 0.001:
			continue
		var normal := _normal_interna(a, b, contorno)
		if normal == Vector2.ZERO:
			continue
		draw_colored_polygon(
			PackedVector2Array([a, b, b + normal * largura, a + normal * largura]),
			COR_FAIXA)


## Qual perpendicular aponta para dentro. Mesma pergunta que o decorador faz, e
## respondida do mesmo jeito -- por TESTE e nao pela orientacao do poligono.
func _normal_interna(a: Vector2, b: Vector2, contorno: PackedVector2Array) -> Vector2:
	var meio := (a + b) * 0.5
	var candidata := (b - a).orthogonal().normalized()
	if Geometry2D.is_point_in_polygon(meio + candidata, contorno):
		return candidata
	if Geometry2D.is_point_in_polygon(meio - candidata, contorno):
		return -candidata
	return Vector2.ZERO


func _desenhar_colocacao(colocacao: Dictionary, cores: Dictionary, escala: float) -> void:
	var porte := int(colocacao["porte"])
	var lado := LADO_DESENHADO[clampi(porte, 0, LADO_DESENHADO.size() - 1)]
	var posicao: Vector2 = colocacao["posicao"]
	var nome: StringName = colocacao["agrupamento"]
	var cor: Color = cores.get(nome, COR_AVULSO)
	var caixa := Rect2(posicao - Vector2.ONE * lado * 0.5, Vector2.ONE * lado)
	draw_rect(caixa, cor)
	# O HERO ganha contorno em vez de mais uma cor: ele e o unico porte de que so
	# existe um por sala, e achar "qual e a peca principal" na foto nao pode
	# depender de comparar tamanhos a olho.
	if porte == DecoradorDeSala.Porte.HERO:
		draw_rect(caixa, Color(1.0, 1.0, 1.0, 0.85), false, 2.0 / escala)


## Uma cor por agrupamento, na ordem em que o perfil os declara.
##
## Por NOME e nao por indice de colocacao: o nome e a identidade do cluster (e a
## chave da memoria recente), entao o mesmo conjunto sai da mesma cor em todos
## os paineis -- que e o que deixa ver, na folha, que duas salas seguidas nao
## contam a mesma historia.
func _cores_por_agrupamento(perfil: PerfilDeDecoracao) -> Dictionary:
	var cores := {}
	var lista := perfil.agrupamentos_validos()
	for i in lista.size():
		cores[lista[i].nome] = CORES_DE_AGRUPAMENTO[i % CORES_DE_AGRUPAMENTO.size()]
	return cores


## `Label` e nao `Label2D`: este build do Godot nao tem o segundo, e cena de
## ferramenta que nao PARSEIA fica pendurada para sempre -- o erro de parse
## acontece antes de qualquer `quit()` que este arquivo escreva.
func _rotulo(onde: Vector2, texto: String) -> void:
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.position = onde
	etiqueta.add_theme_font_size_override("font_size", 10)
	etiqueta.modulate = COR_ROTULO
	add_child(etiqueta)


func _fotografar() -> void:
	if _tem("--ficar"):
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(SAIDA)
	var caminho := "%s/decoracao.png" % SAIDA
	get_viewport().get_texture().get_image().save_png(caminho)
	print("capturado: %s" % ProjectSettings.globalize_path(caminho))
	get_tree().quit()


# -- de onde saem o perfil e as salas ---------------------------------------


## O contorno de cada forma, tirado da CENA e nao copiado para ca.
##
## `contorno_local()` ja aplica o chanfro de quina, que nao existe em `.tscn`
## nenhum -- ele e derivado em codigo. Uma lista de pontos escrita aqui mediria
## uma sala de quinas retas que o jogo nao desenha desde a LTD.
##
## A cena e instanciada e liberada SEM entrar na arvore: `contorno_local()` le o
## `Line2D` filho e mais nada, entao nao ha `_ready`, parede montada nem textura
## carregada para pagar.
##
## **Mas o `DadosSala` tem de ser entregue mesmo assim**, e essa linha ja custou
## uma entrega inteira noutro lugar: sem ele, `Sala._perfil()` devolve `null` e o
## chanfro de quina cai no DEFAULT do script em vez do que o
## `estilo_de_parede` daquele andar declara -- foi exatamente assim que
## `medir_moldura` mediu o perfil padrao enquanto o jogo desenhava outro. Serve
## qualquer tipo: os cinco `tipo_*.tres` do andar 1 apontam o mesmo kit de
## parede, porque sao o mesmo setor.
func _salas() -> Array:
	var lista: Array = []
	var dados := ResourceLoader.load("res://src/mapa/tipo_combate.tres") as DadosSala
	for caminho in CENAS:
		var nome := caminho.get_file().get_basename()
		var cena: PackedScene = load(caminho)
		var sala: Sala = null
		if cena != null:
			sala = cena.instantiate() as Sala
		if sala == null:
			print("  %s nao carregou -- usando o contorno de reserva" % caminho)
			lista.append({"nome": nome, "contorno": contorno_de_reserva()})
			continue
		sala.definir_visual(dados)
		var contorno := sala.contorno_local()
		sala.free()
		if contorno.size() < 3:
			print("  %s sem contorno -- usando o de reserva" % caminho)
			contorno = contorno_de_reserva()
		lista.append({"nome": nome, "contorno": contorno})
	return lista


## O perfil que o andar 1 usa, se ele ja existir em disco; senao, o de
## referencia escrito aqui.
##
## A busca varre `src/mapa/` procurando um recurso que SEJA `PerfilDeDecoracao`,
## em vez de carregar um caminho fixo. Um caminho chutado aqui vira uma
## ferramenta que mede o perfil errado no dia em que o `.tres` nascer com outro
## nome -- e ela continuaria imprimindo numeros, que e a pior forma de errar.
func _perfil() -> PerfilDeDecoracao:
	var achado := _perfil_do_disco()
	if achado != null:
		return achado
	return _perfil_de_referencia()


func _perfil_do_disco() -> PerfilDeDecoracao:
	var pasta := DirAccess.open("res://src/mapa/")
	if pasta == null:
		return null
	var arquivos := pasta.get_files()
	arquivos.sort()
	for arquivo in arquivos:
		if not arquivo.ends_with(".tres"):
			continue
		var recurso := ResourceLoader.load("res://src/mapa/%s" % arquivo)
		if recurso is PerfilDeDecoracao:
			print("  perfil: src/mapa/%s" % arquivo)
			return recurso as PerfilDeDecoracao
	return null


## O perfil de REFERENCIA, montado em codigo.
##
## Ele existe porque o laboratorio precisa medir alguma coisa no dia em que
## ainda nao ha `.tres` -- e esse dia e HOJE, que e justamente quando as
## respostas dele valem mais. Os numeros sao os defaults do proprio
## `PerfilDeDecoracao`; o que este metodo acrescenta sao os AGRUPAMENTOS, porque
## sem cluster nenhum o laboratorio mediria so pecas avulsas e a regra 5 -- a que
## separa "sobreposicao permitida DENTRO do conjunto" de "distancia obrigatoria
## ENTRE conjuntos" -- nao apareceria em foto nenhuma.
##
## Os deslocamentos ficam na moldura do lado NORTE (+x ao longo da parede, +y
## entrando na sala) e nao passam de ~40 px em y: a ancora e sorteada ate a
## METADE da faixa, entao um conjunto que se estenda mais que isso para dentro
## estoura a faixa pela peca de tras e o cluster inteiro e recusado.
func _perfil_de_referencia() -> PerfilDeDecoracao:
	print("  perfil: nenhum .tres em src/mapa/ -- usando o de referencia deste arquivo")
	var perfil := PerfilDeDecoracao.new()
	# Montado item a item, e nao com um literal atribuido direto: o campo e
	# `Array[AgrupamentoDeDecoracao]`, e um literal sem tipo atribuido a um array
	# tipado estoura em runtime -- e a mesma fronteira que o `filter()` do
	# `GEMINI.md` ja registra.
	var lista: Array[AgrupamentoDeDecoracao] = []
	lista.append(
		_agrupamento(&"hidraulico",
			[DecoradorDeSala.Porte.GRANDE, DecoradorDeSala.Porte.MEDIO,
				DecoradorDeSala.Porte.PEQUENO, DecoradorDeSala.Porte.PEQUENO,
				DecoradorDeSala.Porte.MICRO],
			[Vector2(0.0, 0.0), Vector2(36.0, 8.0), Vector2(60.0, 2.0),
				Vector2(12.0, 34.0), Vector2(30.0, 40.0)]))
	lista.append(
		_agrupamento(&"estoque",
			[DecoradorDeSala.Porte.MEDIO, DecoradorDeSala.Porte.MEDIO,
				DecoradorDeSala.Porte.PEQUENO, DecoradorDeSala.Porte.PEQUENO,
				DecoradorDeSala.Porte.MICRO],
			[Vector2(0.0, 0.0), Vector2(30.0, 6.0), Vector2(54.0, 2.0),
				Vector2(14.0, 30.0), Vector2(40.0, 34.0)]))
	lista.append(
		_agrupamento(&"manutencao",
			[DecoradorDeSala.Porte.GRANDE, DecoradorDeSala.Porte.PEQUENO,
				DecoradorDeSala.Porte.MICRO, DecoradorDeSala.Porte.MEDIO],
			[Vector2(0.0, 0.0), Vector2(40.0, 4.0), Vector2(20.0, 32.0),
				Vector2(-34.0, 10.0)]))
	lista.append(
		_agrupamento(&"energia",
			[DecoradorDeSala.Porte.GRANDE, DecoradorDeSala.Porte.MEDIO,
				DecoradorDeSala.Porte.MICRO],
			[Vector2(0.0, 0.0), Vector2(34.0, 2.0), Vector2(16.0, 30.0)]))
	perfil.agrupamentos = lista
	return perfil


func _agrupamento(
	nome: StringName, portes: Array, deslocamentos: Array
) -> AgrupamentoDeDecoracao:
	var agrupamento := AgrupamentoDeDecoracao.new()
	agrupamento.nome = nome
	var inteiros := PackedInt32Array()
	for porte in portes:
		inteiros.append(int(porte))
	var pontos := PackedVector2Array()
	for ponto in deslocamentos:
		pontos.append(ponto)
	agrupamento.portes = inteiros
	agrupamento.deslocamentos = pontos
	return agrupamento


func _caixa(contorno: PackedVector2Array) -> Rect2:
	var caixa := Rect2(contorno[0], Vector2.ZERO)
	for ponto in contorno:
		caixa = caixa.expand(ponto)
	return caixa


## Le de `get_cmdline_user_args()` -- o que vem DEPOIS do `--` --, que e o unico
## lugar onde um argumento nosso nao briga com uma opcao do proprio Godot.
func _tem(bandeira: String) -> bool:
	return OS.get_cmdline_user_args().has(bandeira)
