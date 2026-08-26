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

## Uma rampa por tipo de sala. Cada uma e a versao REBAIXADA do `cor_mapa` que
## o tipo_*.tres declara: minimapa e mundo falam da mesma cor em intensidades
## diferentes. O cor_mapa puro nunca e pintado no mundo.
##   A0  fundo de acento (quase neutro)
##   A1  acento medio (luz apagada, conduite)
##   A2  filete (o neon da parede)
const ACENTOS: Dictionary = {
	&"combate": {&"A0": Color("0e2b33"), &"A1": Color("1e5a6b"), &"A2": Color("2a7285")},
	&"boss": {&"A0": Color("33101c"), &"A1": Color("6b1f36"), &"A2": Color("8a2a47")},
	&"arma": {&"A0": Color("332512"), &"A1": Color("6b4d1e"), &"A2": Color("8a6528")},
	&"item": {&"A0": Color("0e332a"), &"A1": Color("1e6b57"), &"A2": Color("288a71")},
	&"inicial": {&"A0": Color("1a1e2b"), &"A1": Color("333b52"), &"A2": Color("48546f")},
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

## Brilhante de proposito, e por isso restrita a formas grandes: o campo de
## forca da porta tem 80x32, o telegrafo e um disco no chao, o pickup pulsa.
const SINAL: Dictionary = {
	&"porta_trancada": Color("ff3366"),
	&"porta_trancada_sombra": Color("99203f"),
	&"telegrafo": Color(0.55, 1.0, 0.45),
	&"pickup_arma": Color(1.0, 0.72, 0.29),
	&"pickup_item": Color(0.49, 0.97, 0.77),
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
