class_name ReacaoDeArena
extends Node2D
## A ARENA REAGE AS FASES do chefe: a sala e reativada junto com ele.
##
## Fase 1 luzes fracas; fase 2 os paineis piscam e os motores comecam; fase 3
## luzes de emergencia e faiscas. Nao muda gameplay nenhum -- e feedback
## ambiental, e o papel dele e fazer o jogador sentir que o SETOR esta voltando a
## funcionar, e nao so o robo.
##
## A TRAVA DE LEGIBILIDADE, e ela e a peca inteira: **as luzes ficam junto das
## PAREDES, e nada atravessa a arena.** Esta e a sala mais densa de projetil do
## jogo, e a fase 3 e exatamente quando os dois riscos se somam -- mais efeito na
## tela e mais projetil na tela, no mesmo instante. O `IDENTIDADE_VISUAL.md` ja
## manda cortar efeito que atrapalha leitura e o GDD proibe telegrafo coberto;
## aqui isso vira geometria em vez de bom senso:
##
## 1. Toda luz nasce a no maximo `FAIXA_DA_PAREDE` px do contorno. O miolo da
##    arena -- onde o jogador esquiva e onde o telegrafo desenha -- fica limpo.
## 2. Toda luz desenha ABAIXO de `Sala.Z_MUNDO`, que e a faixa do telegrafo, do
##    projetil e dos atores. Nao ha como uma delas cair na frente do aviso.
## 3. O brilho tem TETO, e ele nao sobe com a fase tanto quanto a ficcao pediria.
##
## Ela e um NO DE CENA e nao um sistema: existe uma arena de chefe, e o custo de
## generalizar isso agora seria maior que o de escrever a segunda quando ela
## aparecer.

## Quanto uma luz pode se afastar do contorno da sala, em px.
##
## Curto: passando disso ela deixa de ser "junto da parede" e vira um ponto
## brilhante no caminho de quem esquiva.
const FAIXA_DA_PAREDE := 40.0

## Faixa de z das luzes. Abaixo de `Sala.Z_MUNDO` (zero), como todo efeito de
## cenario deste projeto.
const Z_LUZ := -1

## Teto de opacidade, na fase mais alta. Mesma ideia do `alpha_maximo` do shader
## de glitch e do `ALPHA_MAXIMO_EFEITO` do chefe.
const ALPHA_MAXIMO := 0.34

@export var quantidade: int = 10
@export var raio_da_luz: float = 9.0
## A cor por fase: apagado, ambar, emergencia. Tres e nao um gradiente porque o
## que se quer e o jogador PERCEBER a troca, e nao a arena mudar sozinha.
@export var cores: Array[Color] = [
	Color(0.55, 0.62, 0.78),
	Color(1.0, 0.72, 0.28),
	Color(1.0, 0.30, 0.28),
]
## Quantas piscadas por segundo em cada fase. Na 1 ela quase nao pisca -- a sala
## ainda esta desligada.
@export var hz_por_fase: Array[float] = [0.4, 1.6, 4.5]

var _fase: int = 1
var _luzes: Array[Polygon2D] = []
var _t: float = 0.0


func _ready() -> void:
	z_index = Z_LUZ
	z_as_relative = false
	EventBus.boss_fase_mudou.connect(_ao_mudar_de_fase)
	_montar_luzes()


## Espalha as luzes ao longo do contorno da sala.
##
## Le `Sala.contorno_local()` -- a MESMA fonte de onde nascem a colisao, a camera
## e o minimapa. Uma lista propria de posicoes seria a primeira coisa a divergir
## no dia em que a arena mudar de forma, e o sintoma seria luz flutuando fora da
## parede.
func _montar_luzes() -> void:
	var sala := get_parent() as Sala
	if sala == null:
		return
	var contorno := sala.contorno_local()
	if contorno.size() < 2:
		return

	for i in maxi(quantidade, 0):
		var t := float(i) / float(maxi(quantidade, 1))
		var ponto := _ponto_no_contorno(contorno, t)
		var luz := Polygon2D.new()
		luz.polygon = _disco(raio_da_luz)
		luz.color = cores[0]
		luz.modulate.a = 0.0
		# Para DENTRO da sala, e so um pouco: junto da parede e onde ela pode
		# estar sem entrar no caminho de quem esquiva.
		luz.position = ponto + (Vector2.ZERO - ponto).normalized() * (FAIXA_DA_PAREDE * 0.5)
		add_child(luz)
		_luzes.append(luz)


## Um ponto a `t` (0..1) do perimetro do contorno.
func _ponto_no_contorno(contorno: PackedVector2Array, t: float) -> Vector2:
	var total := 0.0
	for i in contorno.size():
		total += contorno[i].distance_to(contorno[(i + 1) % contorno.size()])
	var alvo := total * clampf(t, 0.0, 1.0)
	var andado := 0.0
	for i in contorno.size():
		var a := contorno[i]
		var b := contorno[(i + 1) % contorno.size()]
		var d := a.distance_to(b)
		if andado + d >= alvo and d > 0.0:
			return a.lerp(b, (alvo - andado) / d)
		andado += d
	return contorno[0]


func _ao_mudar_de_fase(fase: int) -> void:
	_fase = clampi(fase, 1, cores.size())
	for luz in _luzes:
		if is_instance_valid(luz):
			luz.color = cores[_fase - 1]


func _process(delta: float) -> void:
	if _luzes.is_empty():
		return
	_t += delta * hz_por_fase[clampi(_fase - 1, 0, hz_por_fase.size() - 1)]
	for i in _luzes.size():
		var luz := _luzes[i]
		if not is_instance_valid(luz):
			continue
		# Cada luz numa fase propria: um painel inteiro piscando em uniso le como
		# um efeito ligado por script, e nao como um setor reagindo.
		var onda := 0.5 + 0.5 * sin(TAU * (_t + float(i) * 0.37))
		luz.modulate.a = lerpf(0.06, ALPHA_MAXIMO * (float(_fase) / 3.0), onda)


func _disco(raio: float) -> PackedVector2Array:
	var pontos := PackedVector2Array()
	for i in 12:
		pontos.append(Vector2.RIGHT.rotated(TAU * float(i) / 12.0) * raio)
	return pontos


## Quanto a luz mais distante ficou do contorno. Existe para o portao medir sem
## refazer a conta de fora.
func distancia_maxima_do_contorno() -> float:
	var sala := get_parent() as Sala
	if sala == null:
		return 0.0
	var contorno := sala.contorno_local()
	var pior := 0.0
	for luz in _luzes:
		var perto := INF
		for i in contorno.size():
			var a := contorno[i]
			var b := contorno[(i + 1) % contorno.size()]
			perto = minf(perto, Geometry2D.get_closest_point_to_segment(luz.position, a, b).distance_to(luz.position))
		pior = maxf(pior, perto)
	return pior
