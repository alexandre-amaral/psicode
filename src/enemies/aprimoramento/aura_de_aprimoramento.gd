class_name AuraDeAprimoramento
extends Node2D
## A leitura visual de uma classe, num no que o inimigo hospeda sem saber.
##
## **O sprite do inimigo nao muda em pixel nenhum.** Esta e a regra do epico, e
## ela tem duas razoes: a arte dos cinco foi medida e aprovada, e os dois canais
## de cor do inimigo JA TEM DONO -- o Hack pinta `_corpo.color`, o nanite so
## pinta se nao houver Hack, e `_visual.modulate` e do clarao de dano, que
## termina sempre em branco. Um terceiro escritor produziria uma cor que depende
## da ordem das chamadas, que e uma armadilha ja registrada aqui.
##
## ## Tres FAMILIAS de arte, e nao tres cores
##
## Trocar so a cor faria as tres classes lerem como a mesma coisa em tonalidades
## diferentes -- e o jogo e escuro, entao matiz e a primeira coisa que se perde.
## O que separa as tres e o MOVIMENTO:
##
##     REGENERADORA     particulas CONVERGEM para o corpo, so enquanto cura
##     BLINDADA         placas solidas ORBITAM, e ABREM na janela vulneravel
##     SOBRECARREGADA   faiscas SAEM do corpo, em pulso irregular
##
## Convergir, orbitar e escapar sao tres leituras diferentes a um segundo, e
## continuam diferentes em CINZA -- que e como o portao as confere.
##
## ## Duas travas geometricas, e nao de bom senso
##
## **Ela desenha ABAIXO do corpo** (`z_index` negativo). Zero e a faixa do
## telegrafo, do projetil e dos atores: um efeito ali pode cair na frente do
## aviso que torna um ataque justo, e o jogador perde justamente o que precisa
## ler. Mesma ideia do `Z_EFEITO = -1` do chefe.
##
## **E o alfa tem teto.** Uma aura opaca em volta de cinco inimigos apaga o chao
## por baixo deles, e o chao e onde o telegrafo desenha. Mesma ideia do
## `ALPHA_MAXIMO_EFEITO` e do `alpha_maximo` do shader de glitch.
##
## ## Performance
##
## Sem `PointLight2D`, sem shader por unidade e sem `Timer` como no: pode haver
## um destes em toda sala de combate do andar. Uma aura desenhada em `_draw`,
## poucas particulas, e relogio interno.

## A faixa abaixo do corpo. -2 e nao -1: o -1 ja e do efeito de fase do chefe, e
## uma aprimorada na sala dele desenharia empatada com ele.
const Z_AURA := -2

## Teto de alfa de qualquer coisa que esta aura desenhe.
const ALPHA_MAXIMO := 0.55

## Quantas particulas por familia. Baixo de proposito -- o plano avisa que
## dezenas por unidade custam caro, e a leitura vem do MOVIMENTO e nao da
## quantidade.
const PARTICULAS := 10

## Quantas placas a blindada orbita, e quanto elas se afastam ao abrir.
const PLACAS := 5
const AFASTAMENTO_AO_ABRIR := 14.0

var _dados: DadosAprimoramento = null
var _raio: float = 26.0
var _t: float = 0.0
## REGENERADORA: as particulas so existem enquanto ela cura, e o CORTE e a
## informacao -- e como o jogador ve que a janela dele fechou sem barra de vida.
var _curando: bool = false
var _protegida: bool = true
var _pulso: float = 0.0


func configurar(d: DadosAprimoramento, raio_do_inimigo: float) -> void:
	_dados = d
	_raio = maxf(raio_do_inimigo, 12.0)
	z_index = Z_AURA
	# `z_as_relative` DESLIGADO, pela mesma razao do `Telegrafo`: herdando a
	# camada de quem a pendurou, a aura sobe junto com o inimigo no Y-sort e a
	# garantia de "abaixo do corpo" deixa de ser geometrica.
	z_as_relative = false
	queue_redraw()


func curando(ligado: bool) -> void:
	if _curando == ligado:
		return
	_curando = ligado
	queue_redraw()


func blindada(protegida: bool) -> void:
	_protegida = protegida
	queue_redraw()


func pulsar(fase: float) -> void:
	_pulso = fase


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if _dados == null:
		return
	match _dados.classe:
		DadosAprimoramento.Classe.REGENERADORA:
			_desenhar_convergencia()
		DadosAprimoramento.Classe.BLINDADA:
			_desenhar_placas()
		DadosAprimoramento.Classe.SOBRECARREGADA:
			_desenhar_faiscas()


## REGENERADORA: pontos que CONVERGEM, e um arco que fecha.
##
## Eles entram de fora e caminham para o centro. So aparecem enquanto ela cura --
## e por isso a ausencia deles tambem informa: enquanto o jogador atira, nao ha
## nada ali.
func _desenhar_convergencia() -> void:
	var cor := _dados.cor

	# **O ANEL EXISTE SEMPRE, e as particulas so enquanto ela cura.**
	#
	# A primeira versao desenhava tudo so durante a cura, e a captura mostrou o
	# defeito: um Regenerador de vida CHEIA era indistinguivel de um inimigo
	# normal. O jogador so descobriria a classe depois de ja ter atirado e
	# parado -- e a decisao que ela existe para criar acontece ANTES disso.
	#
	# Entao a leitura tem dois niveis: o anel diz "esta unidade e aprimorada", e
	# as particulas dizem "e ela esta curando AGORA". O segundo e uma escalada do
	# primeiro, e nao a unica forma de ver a classe.
	var segmentos := _dados.cor
	segmentos.a = ALPHA_MAXIMO * 0.45
	for i in 6:
		var a0 := TAU * float(i) / 6.0 + _t * 0.4
		draw_arc(Vector2.ZERO, _raio * 1.25, a0, a0 + TAU / 12.0, 6, segmentos, 2.0)

	if not _curando:
		return
	for i in PARTICULAS:
		# Cada particula tem a propria fase, entao elas nao chegam em bloco --
		# um anel que encolhe junto le como uma onda de choque, que e o oposto.
		var fase := fmod(_t * 0.9 + float(i) / float(PARTICULAS), 1.0)
		var distancia: float = lerpf(_raio * 2.0, _raio * 0.35, fase)
		var angulo := TAU * float(i) / float(PARTICULAS) + _t * 0.35
		var p := Vector2.RIGHT.rotated(angulo) * distancia
		var c := cor
		# Some ao chegar: sem isso as particulas pousam no corpo e viram pontos
		# parados, e ponto parado le como projetil.
		c.a = ALPHA_MAXIMO * (1.0 - fase) * 0.9
		draw_circle(p, lerpf(2.4, 1.0, fase), c)

	# E o anel ACENDE inteiro enquanto ela cura: os segmentos viram um circulo
	# continuo, que e a mesma informacao pela borda para quem esta olhando o
	# outro lado da sala.
	var acesa := _dados.cor
	acesa.a = ALPHA_MAXIMO * 0.75
	draw_arc(Vector2.ZERO, _raio * 1.25, 0.0, TAU, 28, acesa, 2.0)


## BLINDADA: placas SOLIDAS que orbitam, e se afastam ao abrir.
##
## Elas sao desenhadas e nao particulas de proposito: placa e materia, e materia
## e o que o jogador le como "isto esta protegido". Particulas leriam como
## energia, que e a linguagem das outras duas.
##
## **A abertura e um MOVIMENTO**, e e por isso que ela funciona em cinza e a um
## segundo: as placas se afastam, o brilho cai, e o nucleo fica exposto.
func _desenhar_placas() -> void:
	var cor := _dados.cor
	var afastamento := 0.0 if _protegida else AFASTAMENTO_AO_ABRIR
	var giro: float = _t * (0.6 if _protegida else 0.25)
	for i in PLACAS:
		var angulo := TAU * float(i) / float(PLACAS) + giro
		var centro := Vector2.RIGHT.rotated(angulo) * (_raio * 1.15 + afastamento)
		var lado := Vector2.RIGHT.rotated(angulo + PI * 0.5) * 6.0
		var fundo := Vector2.RIGHT.rotated(angulo) * 3.5
		var c := cor
		# O brilho CAI na janela: dois canais dizendo a mesma coisa, porque um
		# jogador olhando o outro lado da sala tem de pegar pelo menos um.
		c.a = ALPHA_MAXIMO * (1.0 if _protegida else 0.35)
		draw_colored_polygon(PackedVector2Array([
			centro - lado - fundo, centro + lado - fundo,
			centro + lado + fundo, centro - lado + fundo,
		]), c)


## SOBRECARREGADA: faiscas que SAEM, num pulso IRREGULAR.
##
## Irregular de proposito: um pulso regular le como barra de recarga, e esta
## classe nao promete janela nenhuma -- ela so aperta. Prometer uma janela que
## nao existe e pior que nao prometer nada.
func _desenhar_faiscas() -> void:
	var cor := _dados.cor
	var irregular := 1.0 + sin(_pulso * 7.3) * 0.5 * _dados.irregularidade_do_pulso \
		+ sin(_pulso * 2.1) * 0.5 * _dados.irregularidade_do_pulso
	for i in PARTICULAS:
		var fase := fmod(_t * 1.4 + float(i) * 0.37, 1.0)
		var distancia: float = lerpf(_raio * 0.5, _raio * 1.9 * irregular, fase)
		var angulo := TAU * float(i) * 0.618 + _t * 0.8
		var direcao := Vector2.RIGHT.rotated(angulo)
		var c := cor
		c.a = ALPHA_MAXIMO * (1.0 - fase)
		# Risco e nao ponto: a faisca tem DIRECAO, e direcao para fora e o que
		# separa esta familia da regeneradora sem depender da cor.
		draw_line(direcao * distancia, direcao * (distancia + 5.0), c, 1.6)
