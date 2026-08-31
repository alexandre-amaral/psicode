class_name Telegrafo
extends Node2D
## O AVISO. Um vocabulario unico para o que sete inimigos implementavam cada um
## do seu jeito.
##
## Telegrafo nao e enfeite deste projeto, e a regra central dele: "bullet hell
## so e justo se da para ler a intencao antes do projetil existir" (`GEMINI.md`).
## Mesmo assim, ate aqui cada inimigo tinha o seu -- o laser do Vigia, a linha
## do Neon, o clarao da Sentinela, o pulso do Drone, o circulo do Hacker, o
## Aviso da Diretora. Sete implementacoes da MESMA ideia, e o custo ja apareceu
## duas vezes em bug registrado: a `AreaDePerigo` desenhando abaixo do chao, e
## telegrafo aceso que nao apaga.
##
## As quatro invariantes que antes viviam em prosa passam a viver AQUI:
##
## 1. **Faixa `Z`.** O aviso desenha em `Sala.Z_MUNDO` (0) e com
##    `z_as_relative = false`, entao ele nao herda a faixa de quem o pendurou.
##    Nao ha erro no console para "o aviso existe mas ninguem ve".
## 2. **O aviso nao herda a transformada de quem o criou.** `top_level = true`
##    sempre: um `Visual` que gira, uma torre que orbita ou um corpo que leva
##    knockback arrastariam o desenho junto -- e aviso que se mexe e aviso que
##    mente. Quem cria e MORRE no mesmo frame (um projetil, uma area) usa
##    `na_cena()` em vez de `anexar()`.
## 3. **Apaga sempre.** `apagar()` devolve tudo o que o telegrafo mexeu, e
##    `InimigoBase.morrer()` chama nos telegrafos filhos antes do `queue_free`.
##    Amarrado no `sair` da `MaquinaEstados`, ele apaga inclusive quando a troca
##    de estado vem de fora -- que e o caso da esquiva do Atirador Neon.
## 4. **Piso de duracao.** `DURACAO_MINIMA` e o mesmo 0,35 s que a Diretora
##    crava: o aviso encurta com a fase, mas nunca some. `acender()` passa a
##    duracao por `duracao_segura()` sozinho, entao nao ha como esquecer.
##
## As QUATRO FASES existem porque um aviso de intensidade unica so responde "vem
## coisa"; o jogador tambem precisa de "vem QUANDO". Fraco -> crescendo ->
## piscando -> ativacao da a contagem regressiva de graca, e e a mesma leitura
## em linha, em circulo e em pulso de sprite.
##
## Uso:
## [codeblock]
## _telegrafo = Telegrafo.anexar(self)
## _telegrafo.cor = Color(1.0, 0.25, 0.35)
## # ao entrar no estado de mira:
## _telegrafo.acender(tempo_mira)
## # todo frame do estado:
## _telegrafo.linha(_arma.global_position, _ponto_previsto)
## if _telegrafo.avancar(delta) >= 1.0:
##     _disparar()
## # no `sair` do estado:
## _telegrafo.apagar()
## [/codeblock]

## Trocou de fase. E o GANCHO DE SOM: quem quiser um bip por fase liga aqui e
## nao precisa saber nada sobre o inimigo que avisa. Fica como sinal e nao como
## chamada direta no `Juice` porque nem todo telegrafo soa -- sete avisos
## simultaneos soando viram ruido, e a escolha e de quem monta o inimigo.
signal fase_mudou(fase: int)

enum Forma {
	NENHUMA,
	## Do ponto A ao ponto B. O laser do Vigia, a linha do Neon.
	LINHA,
	## Mancha no chao. O disco do Hacker, a faixa da Rede de Exterminio.
	AREA,
}

enum Fase {
	## Circulo fraco: ele EXISTE, e so.
	FRACO,
	## Aumentando intensidade: da para contar o tempo que falta.
	CRESCENDO,
	## Piscando: o ultimo aviso antes de doer.
	PISCANDO,
	## Ativacao: o ataque saiu.
	ATIVACAO,
}

## Piso de duracao, em segundos. O mesmo numero que `Diretora.TELEGRAFO_MINIMO`
## crava, e pelo mesmo motivo: abaixo disso o aviso existe no codigo e nao
## existe para quem joga. O telegrafo encurta com a fase, nunca some.
const DURACAO_MINIMA := 0.35

## Onde o aviso desenha. `Sala.Z_MUNDO`, escrito como numero para o telegrafo
## nao depender da camada de mapa -- ele e usado tambem em cena de teste, onde
## nao ha `Sala` nenhuma.
const Z := 0

## Fronteiras das fases, em fracao da duracao.
const FIM_FRACO := 0.35
const FIM_CRESCENDO := 0.72

## Piscadas por segundo na fase 3.
const HZ_PISCA := 9.0
## Quanto o brilho CAI no vale da piscada. Zero apagaria o aviso metade do
## tempo, e um aviso que some e pior que um aviso fraco.
const VALE_PISCA := 0.42

## Lados do poligono do circulo. 24 le como circulo e custa pouco -- o mesmo
## numero que a `AreaDePerigo` ja usava.
const LADOS := 24

## Escala inicial do circulo. Ele CRESCE durante o aviso inteiro: e o
## crescimento, e nao a cor, que diz quanto tempo falta.
const ESCALA_INICIAL := 0.15

@export var cor: Color = Color(1.0, 0.25, 0.35)
## Espessura da linha nas pontas do aviso. Nao afeta o circulo.
@export var largura_min: float = 1.0
@export var largura_max: float = 3.0
## Opacidade nas pontas do aviso.
@export var alfa_min: float = 0.12
@export var alfa_max: float = 0.8

## Duracao do aviso em curso. Sempre >= DURACAO_MINIMA depois de `acender()`.
var duracao: float = DURACAO_MINIMA

var _forma: int = Forma.NENHUMA
var _t: float = 0.0
var _aceso: bool = false
var _fase: int = Fase.FRACO
var _a: Vector2 = Vector2.ZERO
var _b: Vector2 = Vector2.ZERO
var _centro: Vector2 = Vector2.ZERO
## Contorno da mancha, em coordenadas LOCAIS em volta de `_centro`. Circulo e
## faixa passam pelo mesmo campo de proposito: duas primitivas de aviso
## acabariam divergindo justamente no detalhe que mais importa -- quanto tempo o
## aviso dura antes de doer.
var _pontos: PackedVector2Array = PackedVector2Array()

## Sprite/poligono que pulsa junto. Ver `pulsar()`.
var _pulsante: CanvasItem = null
var _escala_pulsante: Vector2 = Vector2.ONE
var _alfa_pulsante: float = 1.0
var _escala_alvo: float = 1.3


# --------------------------------------------------------------- fabrica ----

## Pendura o telegrafo em quem avisa.
##
## Usado por quem SOBREVIVE ao proprio aviso -- todo inimigo. O no fica filho do
## dono (entao morre com ele, que e o comportamento certo: nao pode sobrar
## laser na tela depois que o Vigia explodiu) mas com `top_level`, entao nao
## herda posicao, rotacao nem escala dele.
static func anexar(dono: Node, nome_no: String = "Telegrafo") -> Telegrafo:
	var t := Telegrafo.new()
	t.name = nome_no
	dono.add_child(t)
	return t


## Solta o telegrafo na CENA, ao lado de quem o pediu.
##
## Para quem morre no mesmo frame em que avisa -- um projetil que estoura, uma
## area que some. Filho dele, o aviso iria junto antes de alguem ver. Mesma
## licao que o arco do Corrente e a `AreaDePerigo` do Parasita ja carregam.
static func na_cena(criador: Node, nome_no: String = "Telegrafo") -> Telegrafo:
	var pai := criador.get_parent()
	if pai == null:
		pai = criador
	var t := Telegrafo.new()
	t.name = nome_no
	pai.add_child(t)
	return t


## O piso, aplicado. Publica porque quem espera o aviso terminar tem de esperar
## a MESMA duracao que o desenho usa -- se o inimigo atirasse em `tempo_clarao`
## cru e o aviso durasse o piso, o tiro sairia antes do telegrafo acabar.
static func duracao_segura(segundos: float) -> float:
	return maxf(segundos, DURACAO_MINIMA)


func _ready() -> void:
	# As invariantes que nao podem depender de quem instanciou.
	top_level = true
	position = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE
	z_as_relative = false
	z_index = Z
	visible = false


# ------------------------------------------------------------------ ciclo ---

## Acende o aviso e zera a contagem. `duracao` passa pelo piso aqui, e nao no
## chamador, para nao haver como esquecer.
func acender(segundos: float) -> void:
	duracao = duracao_segura(segundos)
	_t = 0.0
	_aceso = true
	visible = true
	_trocar_fase(Fase.FRACO)
	_aplicar_pulsante()
	queue_redraw()


## Avanca o aviso e devolve o progresso (0..1+). Chame do `_physics_process` de
## quem avisa; o telegrafo nao roda sozinho de proposito -- quem manda no tempo
## do ataque e o inimigo, e um aviso com relogio proprio dessincroniza do tiro.
func avancar(delta: float) -> float:
	if not _aceso:
		return 0.0
	_t += delta
	var p := progresso()
	var nova := _fase_de(p)
	if nova != _fase:
		_trocar_fase(nova)
	_aplicar_pulsante()
	queue_redraw()
	return p


## Apaga e devolve tudo o que o telegrafo mexeu.
##
## Idempotente: chamar duas vezes -- o `sair` do estado E o `morrer()` -- nao
## pode fazer diferenca, porque nas duas pontas o certo e insistir.
func apagar() -> void:
	_aceso = false
	visible = false
	_forma = Forma.NENHUMA
	if _pulsante != null and is_instance_valid(_pulsante):
		_pulsante.visible = false
		if _pulsante is Node2D:
			(_pulsante as Node2D).scale = _escala_pulsante
		_pulsante.modulate.a = _alfa_pulsante
	queue_redraw()


func aceso() -> bool:
	return _aceso


func progresso() -> float:
	return _t / maxf(duracao, 0.0001)


func fase() -> int:
	return _fase


## Brilho no instante atual, 0..1. Sai daqui a leitura das quatro fases, e e o
## mesmo numero para linha, circulo e pulso -- o aviso tem de contar a mesma
## historia qualquer que seja o desenho.
func intensidade() -> float:
	if not _aceso:
		return 0.0
	var p := progresso()
	match _fase_de(p):
		Fase.FRACO:
			return alfa_min
		Fase.CRESCENDO:
			var q := clampf((p - FIM_FRACO) / maxf(FIM_CRESCENDO - FIM_FRACO, 0.0001), 0.0, 1.0)
			return lerpf(alfa_min, alfa_max, q)
		Fase.PISCANDO:
			# Onda quadrada e nao senoide: o jogador precisa PERCEBER a troca de
			# fase, e uma senoide na velocidade certa le como brilho constante.
			var aceso_agora := fmod(_t * HZ_PISCA, 1.0) < 0.5
			return alfa_max if aceso_agora else alfa_max * VALE_PISCA
		_:
			return 1.0


## Quanto o desenho ja cresceu, 0..1. Quadratica de entrada: o aviso passa mais
## tempo pequeno e estoura no fim, que e a curva que a `AreaDePerigo` ja usava.
func crescimento() -> float:
	var p := clampf(progresso(), 0.0, 1.0)
	return ESCALA_INICIAL + (1.0 - ESCALA_INICIAL) * p * p


# ----------------------------------------------------------------- formas ---

## Linha do ponto A ao ponto B, em coordenadas GLOBAIS (o no e `top_level`).
func linha(origem: Vector2, ponta: Vector2) -> void:
	_forma = Forma.LINHA
	_a = origem
	_b = ponta
	queue_redraw()


## Disco no chao. `centro` e GLOBAL.
func circulo(centro: Vector2, raio: float) -> void:
	var pontos := PackedVector2Array()
	for i in LADOS:
		pontos.append(Vector2.RIGHT.rotated(TAU * float(i) / float(LADOS)) * raio)
	forma(centro, pontos)


## Mancha de contorno qualquer. `centro` e GLOBAL, `pontos_locais` sao relativos
## a ele. E o que a faixa da Rede de Exterminio precisa: aviso de FAIXA, e nao
## de disco, na mesma linguagem de fases.
func forma(centro: Vector2, pontos_locais: PackedVector2Array) -> void:
	_forma = Forma.AREA
	_centro = centro
	_pontos = pontos_locais
	queue_redraw()


## Faz um no que ja existe na cena pulsar junto com o aviso.
##
## E o caso do clarao da Sentinela: o telegrafo dela nao e uma forma no chao, e
## o proprio cano brilhando. Em vez de duas linguagens (um componente para
## forma, outro para sprite), o telegrafo dirige o no de fora -- e as quatro
## fases valem igual.
##
## A escala e o alfa originais sao guardados AQUI e devolvidos em `apagar()`.
func pulsar(no: CanvasItem, escala_alvo: float = 1.3) -> void:
	_pulsante = no
	_escala_alvo = escala_alvo
	if no is Node2D:
		_escala_pulsante = (no as Node2D).scale
	_alfa_pulsante = no.modulate.a
	_aplicar_pulsante()


# ------------------------------------------------------------------ tinta ---

func _draw() -> void:
	if not _aceso:
		return
	var c := cor
	c.a = intensidade()
	var largura := lerpf(largura_min, largura_max, clampf(progresso(), 0.0, 1.0))
	match _forma:
		Forma.LINHA:
			draw_line(_a, _b, c, largura)
		Forma.AREA:
			if _pontos.size() < 3:
				return
			var f := crescimento()
			var pontos := PackedVector2Array()
			for ponto in _pontos:
				pontos.append(_centro + ponto * f)
			# O miolo e discreto e a borda e o aviso: um disco chapado do
			# tamanho de meia sala esconderia o proprio chao, e o jogador
			# precisa ver ONDE esta pisando enquanto sai de cima.
			var preenchimento := c
			preenchimento.a = c.a * 0.28
			draw_colored_polygon(pontos, preenchimento)
			draw_polyline(_fechar(pontos), c, largura)
		_:
			pass


func _aplicar_pulsante() -> void:
	if _pulsante == null or not is_instance_valid(_pulsante):
		return
	if not _aceso:
		return
	_pulsante.visible = true
	if _pulsante is Node2D:
		var f := lerpf(0.4, _escala_alvo, clampf(progresso(), 0.0, 1.0))
		(_pulsante as Node2D).scale = _escala_pulsante * f
	_pulsante.modulate.a = _alfa_pulsante * intensidade() / maxf(alfa_max, 0.0001)


func _fase_de(p: float) -> int:
	if p >= 1.0:
		return Fase.ATIVACAO
	if p >= FIM_CRESCENDO:
		return Fase.PISCANDO
	if p >= FIM_FRACO:
		return Fase.CRESCENDO
	return Fase.FRACO


func _trocar_fase(nova: int) -> void:
	_fase = nova
	fase_mudou.emit(nova)


## O `draw_polyline` precisa repetir o primeiro ponto para fechar; o
## `draw_colored_polygon` nao pode repetir. Mesma armadilha que
## `Sala.contorno_local()` documenta.
func _fechar(pontos: PackedVector2Array) -> PackedVector2Array:
	var saida := PackedVector2Array(pontos)
	if not saida.is_empty():
		saida.append(saida[0])
	return saida
