class_name Paleta
extends RefCounted
## Fonte unica das cores do psicode. Toda textura gerada, e todo teste que
## confere textura, le daqui -- nenhum outro arquivo de tools/ escreve um hex.
##
## A decisao de design que este arquivo carrega: num bullet hell, **cor
## saturada e clara e linguagem de gameplay**. Se a parede pudesse ser ciano
## brilhante, o ciano deixaria de significar "seu tiro". Por isso nao existe UMA
## paleta, existem tres, e a regra e sobre a fronteira entre elas:
##
##   AMBIENTE  chao, parede, corredor, props, moldura de porta.
##             Dessaturado OU escuro -- nunca os dois brilhantes.
##   ATOR      player, inimigos, projeteis. Saturado e claro. Exclusiva.
##   SINAL     porta trancada, telegrafo, brilho de pickup. Brilhante, mas
##             sempre numa forma grande demais para ser confundida com projetil.
##
## Os limiares LIMITE_SATURACAO/LIMITE_VALOR sao o portao G2: nenhuma cor de
## AMBIENTE pode passar dos dois ao mesmo tempo. E em HSV e nao em luminancia
## de proposito -- o vermelho do inimigo tem luminancia MENOR que o cinza N7,
## e uma trava so de brilho deixaria o vermelho passar.
##
## Este script mora em tools/ e fica FORA do export (exclude_filter). Nada em
## src/ pode referencia-lo: o jogo le textura pronta, nunca a paleta.

## O concreto do complexo. N1 e o valor exato do chao que o jogo sempre teve.
const NEUTROS: Dictionary = {
	&"N0": Color("05060b"), # vazio / sombra profunda / clear_color
	&"N1": Color("0b0d16"), # chao base
	&"N2": Color("12151f"), # chao medio
	&"N3": Color("1a1e2b"), # placa / chao claro
	&"N4": Color("242a3a"), # junta, rejunte
	&"N5": Color("31384c"), # metal escuro (corpo da parede)
	&"N6": Color("434b63"), # metal medio (topo da parede)
	&"N7": Color("5a6480"), # aresta iluminada (raro) -- teto do brilho
}

## Uma rampa por tipo de sala. Ela ja foi a versao REBAIXADA do `cor_mapa` do
## `tipo_*.tres` -- minimapa e mundo falando da mesma cor em intensidades
## diferentes --, e a FAB 08 desfez isso: hoje as tres cores sao GUNMETAL, e o
## tipo sobrevive so como um vies de matiz de poucos graus.
##   A0  campo de acento: a chapa pintada (quase neutro)
##   A1  acento medio (luz apagada, conduite)
##   A2  a MARCA: o traco de 2 a 4 px, a unica que guarda croma
##
## **O alvo nao foi escolhido, foi medido.** O topo da parede -- a superficie
## neutra que da a volta na sala -- mede 215,0 de matiz e 0,289 de saturacao,
## contra 216,5 / 0,284 do centro de `docs/fabrica_01.png`. Ele ja estava certo
## e virou o ponto para onde os acentos convergem.
##
## O que eles eram: **S 0,65 a 0,73 nas cinco rampas**, com `item` em 165 graus
## (verde), `arma` em 37 (laranja) e `combate` em 193 (teal). Isso e o mesmo
## defeito que a FAB 09/10 tirou das texturas -- cor chapada por tipo de sala --
## sobrevivendo no gerador, e ele so nao gritava porque hoje os `ACENTOS`
## alcancam UMA textura: as duas celulas de acento do `props_atlas.png`.
##
## **A leitura passa a ser por VALOR, e nao por croma.** A0 (0,19) cai sobre o
## N5 do painel (0,30) e A1 (0,42) cai sobre o A0: a peca continua tendo tres
## degraus, e nenhum deles precisa de saturacao para existir. Foi assim que a
## referencia sempre fez.
##
## **A2 e a excecao, e ela e o que a secao 111 do briefing pede.** Ela nunca
## pinta area -- e um traco de 4 px numa peca e uma marca de 4x2 na outra --,
## entao ela fica em S 0,55 para continuar lendo como LUZ. Marca e indicador;
## campo e tinta. Ela passa no G2 pelo valor (0,52 contra o teto de 0,55), que
## e a mesma folga do N7.
##
## **`boss` mantem o magenta**, pelo mesmo motivo que o chao dele nao girou na
## FAB 09: a secao 11 reserva aquela familia para a sala do chefe, e ela e a
## unica do andar que PODE se anunciar de longe. O que mudou nela foi a
## saturacao, que caiu junto com as outras quatro.
const ACENTOS: Dictionary = {
	&"combate": {&"A0": Color("222830"), &"A1": Color("47566b"), &"A2": Color("3c5a85")},
	&"boss": {&"A0": Color("302227"), &"A1": Color("6b4755"), &"A2": Color("853c58")},
	&"arma": {&"A0": Color("222530"), &"A1": Color("474e6b"), &"A2": Color("3c4a85")},
	&"item": {&"A0": Color("222a30"), &"A1": Color("475c6b"), &"A2": Color("3c6685")},
	&"inicial": {&"A0": Color("222730"), &"A1": Color("47536b"), &"A2": Color("3c5485")},
}

## Registro do que ja esta em uso nos .tscn e .tres de ator. Nao e a fonte
## deles (a cor de cada inimigo mora na cena dele, como manda a convencao) --
## e o espelho que o portao G3 usa para provar que ambiente e ator nao se
## cruzam. teste_texturas.gd confere que o espelho esta em dia.
const ATOR: Dictionary = {
	# O corpo do jogador virou sprite de pixel art e nao tem mais uma cor unica.
	# O que sobrou de geometria ciano nele e o cano da arma, que continua sendo
	# quem mostra o angulo exato do tiro -- e por isso continua no espelho.
	&"player_cano": Color(0.55, 0.97, 1.0),
	&"rastejante": Color(1.0, 0.3, 0.42),
	&"vigia": Color(0.78, 0.36, 1.0),
	&"drone_aranha": Color(1.0, 0.55, 0.2),
	&"sentinela_orbital": Color(0.6, 0.8, 1.0),
	&"atirador_neon": Color(0.35, 1.0, 0.85),
	&"cyber_besta": Color(1.0, 0.45, 0.2),
	&"hacker_parasita": Color(0.55, 1.0, 0.45),
	&"diretora": Color(0.85, 0.25, 0.85),
	# O ponto de energia da Sobrecarga. Ambar de proposito: dentro da sala do
	# chefe tudo o mais e magenta (ela, 300 graus), rosa (o tiro dela, 336) e
	# roxo (a salva, 263), e o chao e a rampa `boss` rebaixada. O ambar fica a
	# ~250 graus de distancia de todos eles, que e o que importa -- a paleta e
	# global, mas a LEITURA e por sala. Ele divide faixa com o tiro da Mantis, e
	# a separacao ali e de FORMA: um hexagono parado de 26 px nao se confunde
	# com um projetil, do mesmo jeito que o drone_aranha divide o laranja com o
	# proprio tiro dele.
	&"nucleo_sobrecarga": Color(1.0, 0.82, 0.25),
	# O Automato Enferrujado, chefe do andar 1. AMARELO-PERIGO, e a escolha e por
	# eliminacao: o andar 1 ja gasta o laranja duas vezes -- drone_aranha em 25
	# graus e cyber_besta em 14 --, e um terceiro laranja no CHEFE seria a peca
	# mais importante da sala usando a cor mais repetida dela. O 72 fica a 32
	# graus do hacker_parasita e a 26 do nucleo_sobrecarga, que e a folga que o
	# drone ja aceita com o proprio tiro.
	#
	# E ele diz a coisa certa: amarelo-perigo e a cor de maquinario industrial
	# que o AND1 pede para o andar, e combina com a ficcao dele -- uma maquina
	# que usa a propria destruicao para funcionar acima do limite.
	&"boss_guardiao_01": Color(0.82, 1.0, 0.15),
	# A torre da fase Absoluta usa o roxo da SALVA dela, e nao uma cor propria:
	# a torre nao e um inimigo novo, e a Diretora saindo pelo chao. Cor propria
	# diria ao jogador que apareceu outra coisa na sala.
	&"torre_diretora": Color(0.6, 0.35, 1.0),
	&"tiro_pistola": Color(0.43, 0.9, 1.0),
	&"tiro_shotgun": Color(1.0, 0.72, 0.29),
	&"tiro_mantis": Color(1.0, 0.93, 0.25),
	&"tiro_cipher": Color(0.45, 1.0, 0.3),
	# As armas de loot dividem QUATRO matizes, nao dez. O jogador segura uma
	# arma por vez, entao a distincao que importa e tiro-do-jogador contra
	# tiro-de-inimigo -- e os inimigos ja ocupam vermelho, laranja, azul-claro,
	# agua, magenta e roxo. Medido: sobram faixas livres em 81, 138, 237 e 318
	# graus. Armas da mesma faixa se separam pela FORMA (raio e rastro).
	&"tiro_railx": Color(0.28, 0.36, 1.0),
	&"tiro_phase": Color(1.0, 0.28, 0.8),
	&"tiro_boomer": Color(0.81, 1.0, 0.28),
	&"tiro_plasma": Color(0.28, 1.0, 0.47),
	&"tiro_swarm": Color(0.57, 1.0, 0.28),
	&"tiro_volt": Color(0.28, 0.9, 1.0),
	&"tiro_nanite": Color(0.28, 0.33, 1.0),
	&"tiro_laser": Color(0.99, 0.28, 1.0),
	&"tiro_vigia": Color(1.0, 0.28, 0.42),
	&"tiro_drone": Color(1.0, 0.55, 0.2),
	&"tiro_sentinela": Color(0.6, 0.8, 1.0),
	&"tiro_neon": Color(0.35, 1.0, 0.85),
	&"tiro_diretora": Color(1.0, 0.24, 0.55),
	&"salva_diretora": Color(0.6, 0.35, 1.0),
}

## Brilhante de proposito, e por isso restrita a formas grandes: a barra de
## trancada atravessa a abertura inteira da porta, o telegrafo e um disco no
## chao, o pickup pulsa.
##
## A porta era o contra-exemplo desta regra ate a PORTA 01: o `porta_campo.png`
## de 80x32 nao era um sinal SOBRE a porta, era a porta INTEIRA feita de sinal --
## listras rosa-vermelhas sobre um vao vazio, sem folha nenhuma atras. Hoje a
## chapa e AMBIENTE e o sinal e a barra que a atravessa.
const SINAL: Dictionary = {
	&"porta_trancada": Color("ff3366"),
	&"porta_trancada_sombra": Color("99203f"),
	&"telegrafo": Color(0.55, 1.0, 0.45),
	&"pickup_arma": Color(1.0, 0.72, 0.29),
	&"pickup_item": Color(0.49, 0.97, 0.77),
}

## A MARCA de tipo de sala: a segunda metade do acento que a FAB 12 devolve.
##
## O briefing e explicito nas secoes 111 a 114: **depois** que a ambientacao
## funcionar sem cor, o acento de tipo volta discreto -- luz tecnica no item,
## marca ambar na arma, luz quente na loja. Nunca recolorindo a sala.
##
## A luz ja tinha voltado na FAB 19 (a luminaria FRIA do item e da arma contra
## as ambar do resto). Isto aqui e a marca: a faixa pintada NO CHAO, que ocupa
## 28x6 px numa celula de 32 e aparece uma vez ou outra por sala.
##
## **Ela nao desfaz a FAB 08.** O que aquela issue tirou foi a TINTA -- a rampa
## de superficie que pintava painel e chapa de verde ou laranja. Marca e outra
## coisa: e pequena, e no chao, e ela EXISTE para dizer o tipo. A diferenca
## entre as duas e area, e nao matiz.
##
## Dois tipos so, e por eliminacao. `combate` e `inicial` sao a fabrica sem
## adjetivo -- eles nao tem funcao para anunciar --, e `boss` ja se anuncia pelo
## unico tingimento que sobreviveu. Quem nao esta aqui cai na rampa gunmetal, e
## e assim que o campo continua sendo excecao em vez de virar tabela.
##
## A `loja` divide a celula da `arma` (a cena dela nasceu clonada) e por isso
## herda esta faixa. Nao e descuido: a identidade dela vem do balcao, das tres
## bancadas, do Sucateiro e das seis luminarias quentes -- ela e um posto
## improvisado DENTRO da fabrica, e nao um setor proprio.
##
## O amarelo e ENVELHECIDO de proposito (S 0,42): amarelo aceso e paleta de
## SINAL, e a barra de porta trancada e quem mora la.
const MARCAS: Dictionary = {
	&"arma": {&"faixa": Color("756a44"), &"tique": Color("857542")},
	&"item": {&"faixa": Color("40596b"), &"tique": Color("466880")},
}

## A EXCECAO quente do ambiente: a lampada de trabalho que ainda funciona.
##
## Ela existe porque a regua achou um buraco. `medir_ambiente.tscn` pede ambar
## como ACENTO do andar e mede **0,00%** nas 56 texturas, contra 0,41% da
## referencia -- o andar tinha zero luz quente em textura, e o que sobrava era a
## luz de engine da `LuzDeFabrica`, que nao aparece em pasta nenhuma.
##
## **Ela e ambar APAGADO, e o numero e o portao.** `AMBAR_VALOR_MINIMO` da regua
## e 0,45 (abaixo disso o pixel conta como ferrugem) e o G2 recusa saturada E
## clara ao mesmo tempo: sobra a faixa de 0,45 a 0,55 de valor, e o LED fica em
## **0,52**. Ele nao brilha na textura -- quem brilha e a luz de engine por cima
## dele --, e essa e a divisao certa: textura e materia, luz e luz.
##
## `led_ambar_base` e a carcaca em volta, escura o bastante para cair em
## FERRUGEM na regua. Ela e o que impede o LED de parecer um pixel solto: um
## ponto quente sem soquete le como ruido de compressao.
const LUZES: Dictionary = {
	&"led_ambar": Color("855f14"),
	&"led_ambar_base": Color("3d2f1c"),
}

## Portao G2. Uma cor de AMBIENTE pode ser saturada OU clara, nunca as duas.
## N7 (S=0.30, V=0.50) e o teto e passa de raspao de proposito.
const LIMITE_SATURACAO := 0.35
const LIMITE_VALOR := 0.55

## Duas cores a menos de um passo de 8 bits sao a mesma cor: PNG e RGBA8, e
## comparar float exato faria toda textura reprovar por arredondamento.
const TOLERANCIA_CANAL := 1.5 / 255.0


static func ambiente() -> Array[Color]:
	var lista: Array[Color] = []
	for chave in NEUTROS:
		lista.append(NEUTROS[chave])
	for tipo in ACENTOS:
		for faixa in ACENTOS[tipo]:
			var cor: Color = ACENTOS[tipo][faixa]
			if not pertence(cor, lista):
				lista.append(cor)
	for chave in LUZES:
		var luz: Color = LUZES[chave]
		if not pertence(luz, lista):
			lista.append(luz)
	for tipo in MARCAS:
		for faixa in MARCAS[tipo]:
			var traco: Color = MARCAS[tipo][faixa]
			if not pertence(traco, lista):
				lista.append(traco)
	return lista


static func ator() -> Array[Color]:
	var lista: Array[Color] = []
	for chave in ATOR:
		lista.append(ATOR[chave])
	return lista


static func sinal() -> Array[Color]:
	var lista: Array[Color] = []
	for chave in SINAL:
		lista.append(SINAL[chave])
	return lista


static func neutro(nome: StringName) -> Color:
	return NEUTROS[nome]


static func luz(nome: StringName) -> Color:
	return LUZES[nome]


## A marca do tipo de sala, quando ele tem uma. Tipo sem marca devolve a rampa
## gunmetal -- e o fallback e o que mantem `MARCAS` uma excecao curta em vez de
## uma tabela que alguem preenche por simetria.
static func marca(tipo: StringName, faixa: StringName) -> Color:
	if not MARCAS.has(tipo):
		return acento(tipo, &"A0" if faixa == &"faixa" else &"A1")
	return MARCAS[tipo][faixa]


## Acento de um tipo de sala. Tipo desconhecido cai em `combate`, que e a rampa
## neutra do andar -- o mesmo fallback que a sala usa quando roda sem dados.
static func acento(tipo: StringName, faixa: StringName) -> Color:
	var rampa: Dictionary = ACENTOS.get(tipo, ACENTOS[&"combate"])
	return rampa[faixa]


## Verdadeiro quando a cor entra no territorio do ator: e o que G2 proibe no
## ambiente e o que todo ator deveria satisfazer.
static func compete_com_ator(cor: Color) -> bool:
	return cor.s > LIMITE_SATURACAO and cor.v > LIMITE_VALOR


static func mesma_cor(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= TOLERANCIA_CANAL \
		and absf(a.g - b.g) <= TOLERANCIA_CANAL \
		and absf(a.b - b.b) <= TOLERANCIA_CANAL


static func pertence(cor: Color, lista: Array[Color]) -> bool:
	for candidata in lista:
		if mesma_cor(cor, candidata):
			return true
	return false
