extends TesteBase
## Verifica que a geometria das salas esta na grade de 16.
##
## Por que isto existe como teste e nao como promessa: a grade de 16 e a base do
## tileset e da pixel art que vem depois, e um unico ponto fora dela anula o
## proposito -- sem produzir erro nenhum em runtime. O jogo roda igual com uma
## parede em x = 837; so o tile e que nao encaixa, meses depois.
##
## Duas regras, e a segunda e a que surpreende:
##
## 1. Toda coordenada de contorno, porta e area de spawn e multipla de 16.
## 2. Toda DIMENSAO de sala e multipla de 32. As salas sao centradas na origem,
##    entao o contorno guarda a MEIA dimensao -- e meia dimensao so cai na grade
##    se a dimensao inteira for multipla de 32.

const GRADE := 16

const SALAS := [
	"res://src/mapa/sala_1_retangular.tscn",
	"res://src/mapa/sala_2_l_shape.tscn",
	"res://src/mapa/sala_3_grande.tscn",
	"res://src/mapa/sala_4_corredor.tscn",
	"res://src/mapa/sala_5_pilar.tscn",
	"res://src/mapa/sala_6_boss.tscn",
	"res://src/mapa/sala_7_arma.tscn",
	"res://src/mapa/sala_8_item.tscn",
	"res://src/mapa/sala_9_inicial.tscn",
]


func nome() -> String:
	return "Grade de 16"


func executar() -> void:
	_resolucao()
	_constantes()
	var conferidas := 0
	for caminho: String in SALAS:
		if _conferir_sala(caminho):
			conferidas += 1
	# Guarda contra a suite virar decoracao: se nenhuma sala carregar, tudo
	# acima passa sem ter olhado nada.
	igual(conferidas, SALAS.size(), "todas as salas foram conferidas")


func _na_grade(v: float) -> bool:
	# Coordenada fracionaria ja falha aqui: 8.5 nao e multiplo de nada.
	if not is_equal_approx(v, roundf(v)):
		return false
	return int(roundf(absf(v))) % GRADE == 0


func _resolucao() -> void:
	var largura := int(ProjectSettings.get_setting("display/window/size/viewport_width", 0))
	var altura := int(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	igual(largura, 960, "a largura do viewport e 960")
	igual(altura, 544, "a altura do viewport e 544")
	ok(largura % GRADE == 0, "a largura do viewport esta na grade")
	ok(altura % GRADE == 0, "a altura do viewport esta na grade")


## As constantes de geometria que decidem onde a parede abre e onde o corredor
## encaixa. Se o vao da porta sair da grade, toda sala sai junto.
func _constantes() -> void:
	ok(_na_grade(Porta.LARGURA), "o vao da porta esta na grade (%.0f)" % Porta.LARGURA)
	ok(_na_grade(Sala.RECUO_ENTRADA), "o recuo de entrada esta na grade (%.0f)" % Sala.RECUO_ENTRADA)
	ok(_na_grade(Sala.PASSO_VARREDURA), "o passo de varredura esta na grade (%.0f)" % Sala.PASSO_VARREDURA)

	var mapa := GerenciadorMapa.new()
	# A largura do corredor TEM de bater com o vao da porta, senao o corredor
	# nao encaixa na boca e sobra parede no meio da passagem.
	perto(mapa.largura_corredor, Porta.LARGURA, "a largura do corredor bate com o vao da porta")
	ok(_na_grade(mapa.vao_corredor), "o vao entre bandas esta na grade (%.0f)" % mapa.vao_corredor)
	mapa.free()


func _conferir_sala(caminho: String) -> bool:
	var cena: PackedScene = load(caminho)
	var etiqueta := caminho.get_file()
	if cena == null:
		ok(false, "%s carrega" % etiqueta)
		return false

	var sala := cena.instantiate() as Sala
	if sala == null:
		ok(false, "%s tem o script Sala na raiz" % etiqueta)
		return false

	var contorno := sala.contorno_local()
	ok(contorno.size() >= 3, "%s tem contorno" % etiqueta)

	var fora := 0
	for ponto in contorno:
		if not _na_grade(ponto.x) or not _na_grade(ponto.y):
			fora += 1
	igual(fora, 0, "%s: todo ponto do contorno esta na grade" % etiqueta)

	# Dimensao multipla de 32, para a meia dimensao cair na grade.
	var caixa := sala.obter_limites()
	var largura := int(roundf(caixa.size.x))
	var altura := int(roundf(caixa.size.y))
	ok(largura % 32 == 0, "%s: largura %d e multipla de 32" % [etiqueta, largura])
	ok(altura % 32 == 0, "%s: altura %d e multipla de 32" % [etiqueta, altura])

	_conferir_portas(sala, etiqueta)
	_conferir_spawn(sala, etiqueta)

	sala.free()
	return true


func _conferir_portas(sala: Sala, etiqueta: String) -> void:
	var raiz := sala.get_node_or_null("Portas")
	if raiz == null:
		return
	var fora := 0
	for filho in raiz.get_children():
		var porta := filho as Node2D
		if porta == null:
			continue
		if not _na_grade(porta.position.x) or not _na_grade(porta.position.y):
			fora += 1
	igual(fora, 0, "%s: toda porta esta na grade" % etiqueta)


## TODA sala e conferida, inclusive as que hoje nao recebem inimigo nenhum.
##
## Antes a area vinha do no "Ondas" e a sala de recompensa era pulada por nao
## ter esse no. Agora `area_spawn` e um @export da propria Sala, entao ela
## sempre existe -- e conferir todas e o certo: o dia em que alguem der combate
## a uma sala de recompensa, a caixa dela ja tera sido validada.
func _conferir_spawn(sala: Sala, etiqueta: String) -> void:
	var area := sala.area_spawn
	var na_grade := _na_grade(area.position.x) and _na_grade(area.position.y) \
		and _na_grade(area.size.x) and _na_grade(area.size.y)
	ok(na_grade, "%s: a area de spawn esta na grade (%s)" % [etiqueta, area])

	# O spawn tem de caber DENTRO da sala. Se vazar, o inimigo nasce na parede
	# -- e o teste de fumaca so descobre isso minutos depois.
	var limites := sala.obter_limites()
	limites.position -= sala.global_position
	ok(
		limites.encloses(area),
		"%s: a area de spawn cabe dentro da sala (sala %s, spawn %s)" % [etiqueta, limites, area]
	)
