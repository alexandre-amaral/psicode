extends TesteBase
## A SALA E UMA CAVIDADE: a sequencia de valor que produz profundidade.
##
## Esta suite existe porque a sala parava de ler como sala. A geometria estava
## certa -- topo, face, sombra de contato, vazio exterior, faixa continua, tudo
## entregue pelos epicos PAREDE, TOPO e MOLDURA --, e mesmo assim a tela lia como
## **uma grande superficie de placas** com uma borda em volta.
##
## Medido, o motivo nao era a geometria: era a DISTANCIA DE VALOR.
##
##     topo    0,161      passo topo -> face    0,020
##     face    0,141      passo face -> piso    0,020
##     piso    0,122      passo piso -> sombra  0,027
##     sombra  0,095
##
## A ordem estava correta. O que nao existia era separacao: a arquitetura inteira
## cabia em **17 niveis de 255**. Quatro superficies com o mesmo valor sao uma
## superficie so, por mais que a geometria diga que sao quatro -- e nenhum portao
## do projeto olhava isso, porque `teste_texturas.gd` mede cada familia contra o
## proprio teto e nunca uma contra a outra.
##
## O que esta suite cobra e a RELACAO. `docs/LOW_TOPDOWN_SQUARED.md` cuida da
## perspectiva e `teste_texturas.gd` cuida do gamut; aqui a pergunta e a do §48
## do plano: **o piso parece estar dentro de uma caixa?**


const TEXTURAS := "res://assets/texturas/"

## As tres familias que formam a sequencia, e os arquivos que as representam.
##
## Sao os arquivos NEUTROS de cada uma: a variacao por tipo de sala muda o matiz
## e nao o valor, e e o valor que esta em jogo aqui.
const CHAO: Array[String] = ["chao_andar1_a", "chao_andar1_b", "chao_andar1_c"]
const TOPO: Array[String] = ["parede_topo_a", "parede_topo_b", "parede_topo_c"]
const FACE: Array[String] = ["parede_face", "parede_face_combate"]

## O passo minimo de valor entre duas superficies vizinhas.
##
## Ele nao e escolhido: sai da propria rampa de neutros da `Paleta`. Os degraus
## dela vao de 0,04 a 0,09 de distancia -- N1->N2 e 0,036, N4->N5 e 0,071 --, e
## um passo abaixo do MENOR degrau da rampa e uma diferenca que a propria paleta
## nao considera uma cor nova.
##
## Medido antes deste portao: os tres passos valiam 0,020, 0,020 e 0,027. Todos
## abaixo do menor degrau, e e por isso que a sala lia como uma superficie so.
const PASSO_MINIMO := 0.036

## Quanto a sombra tem de escurecer o chao, em fracao do valor dele.
const FRACAO_MINIMA_DA_SOMBRA := 0.20

## Quanto a sombra escurece o que esta sob ela, no trecho mais perto da parede.
## Espelha `SombraDeParede.ALFA_PERTO`, e muda junto com ele.
const ALFA_SOMBRA := 0.34


func nome() -> String:
	return "Profundidade da sala"


func executar() -> void:
	_a_sequencia_de_valor_esta_na_ordem()
	_e_os_passos_sao_grandes_o_bastante_para_serem_vistos()
	_a_arquitetura_nao_cabe_num_punhado_de_niveis()


## topo > face > piso > sombra.
##
## A ordem E a profundidade: o topo pega a luz porque olha para cima, a face
## recebe de esguelha, o piso esta no fundo da cavidade e a sombra e o contato.
## Trocar duas delas nao da erro nenhum -- so faz a parede afundar ou o chao
## flutuar.
func _a_sequencia_de_valor_esta_na_ordem() -> void:
	var topo := _valor(TOPO)
	var face := _valor(FACE)
	var piso := _valor(CHAO)
	var sombra := _sombra_sobre(piso)
	if topo < 0.0 or face < 0.0 or piso < 0.0:
		ok(false, "as texturas das tres familias carregam")
		return

	ok(topo > face, "o topo e mais claro que a face (%.3f > %.3f)" % [topo, face])
	ok(face > piso, "a face e mais clara que o piso (%.3f > %.3f)" % [face, piso])
	ok(piso > sombra, "o piso e mais claro que a sombra (%.3f > %.3f)" % [piso, sombra])


## E os passos sao grandes o bastante para serem VISTOS.
##
## A ordem sozinha nao prova nada: quatro superficies a 0,02 de distancia estao
## na ordem certa e leem como uma so. Este e o caso que reprovava o estado que
## abriu o epico, e ele reprovava nos TRES passos.
##
## O piso e o unico que ja estava certo -- o problema era o topo, escuro pela
## metade do que o §34 pede (N5/N6 = 0,30 a 0,39).
func _e_os_passos_sao_grandes_o_bastante_para_serem_vistos() -> void:
	var topo := _valor(TOPO)
	var face := _valor(FACE)
	var piso := _valor(CHAO)
	var sombra := _sombra_sobre(piso)

	_passo("topo -> face", topo, face)
	_passo("face -> piso", face, piso)

	# A SOMBRA E MEDIDA EM FRACAO, e nao no mesmo passo absoluto.
	#
	# Ela nao e material: e N0 com alfa por cima do que estiver embaixo, e o alfa
	# tem teto proprio (`SombraDeParede.ALFA_MAXIMO`, 0,40) que existe para ela
	# nao invadir a leitura de combate -- a area dela ja e cobrada abaixo de 6% do
	# chao. Cobrar dela o mesmo passo absoluto das superficies seria pedir que ela
	# estourasse esse teto, ou seja, que uma trava quebrasse a outra.
	#
	# O que se cobra e o que ela promete: escurecer o chao de forma perceptivel no
	# ponto de contato. Um quinto e o degrau relativo que a rampa de neutros usa
	# entre vizinhos na faixa escura.
	var queda := (piso - sombra) / maxf(piso, 0.001)
	ok(
		queda >= FRACAO_MINIMA_DA_SOMBRA,
		"piso -> sombra: a sombra escurece o chao em %.0f%% (minimo %.0f%%)"
			% [queda * 100.0, FRACAO_MINIMA_DA_SOMBRA * 100.0]
	)


## A arquitetura inteira nao pode caber num punhado de niveis.
##
## O caso acima cobra vizinho contra vizinho; este cobra a AMPLITUDE. Tres passos
## de exatamente `PASSO_MINIMO` passariam ali e ainda deixariam a sala num vao de
## 0,11 -- pouco mais do que os 0,066 que ela ocupava quando o epico abriu.
##
## O teto do chao e 0,30 e o da parede e 0,50 (`teste_texturas.TETO_VALOR`), o que
## deixa a rampa inteira disponivel. Nao usar essa folga e desenhar quatro
## superficies com a mesma tinta.
func _a_arquitetura_nao_cabe_num_punhado_de_niveis() -> void:
	var topo := _valor(TOPO)
	var piso := _valor(CHAO)
	var vao := topo - _sombra_sobre(piso)
	ok(
		vao >= PASSO_MINIMO * 3.0,
		"do topo a sombra ha amplitude de verdade (%.3f, piso %.3f)"
			% [vao, PASSO_MINIMO * 3.0]
	)


# -- helpers ----------------------------------------------------------------


func _passo(rotulo: String, de: float, para: float) -> void:
	var passo := de - para
	ok(
		passo >= PASSO_MINIMO,
		"%s: passo de %.3f, e o minimo e %.3f (o menor degrau da rampa de neutros)"
			% [rotulo, passo, PASSO_MINIMO]
	)


## O valor MEDIANO das texturas de uma familia.
##
## Mediana e nao media: um rebite claro isolado ou uma junta escura nao podem
## mover a superficie inteira, e e justamente disso que estas texturas sao feitas.
func _valor(familia: Array[String]) -> float:
	var todos: Array[float] = []
	for nome_arquivo in familia:
		var imagem := _abrir(TEXTURAS + nome_arquivo + ".png")
		if imagem == null:
			continue
		for y in imagem.get_height():
			for x in imagem.get_width():
				var cor := imagem.get_pixel(x, y)
				if cor.a < 0.5:
					continue
				todos.append(cor.v)
	if todos.is_empty():
		return -1.0
	todos.sort()
	return todos[todos.size() / 2]


## O valor do piso depois de a sombra passar por cima dele.
##
## A sombra nao tem textura propria: ela e N0 com alfa sobre o que estiver
## embaixo. Medi-la isolada mediria a cor do recurso, e nao o que o jogador ve.
func _sombra_sobre(piso: float) -> float:
	var n0 := Color("05060b").v
	return piso * (1.0 - ALFA_SOMBRA) + n0 * ALFA_SOMBRA


func _abrir(caminho: String) -> Image:
	if not FileAccess.file_exists(caminho):
		return null
	var imagem := Image.load_from_file(ProjectSettings.globalize_path(caminho))
	if imagem == null or imagem.is_empty():
		return null
	imagem.convert(Image.FORMAT_RGBA8)
	return imagem
