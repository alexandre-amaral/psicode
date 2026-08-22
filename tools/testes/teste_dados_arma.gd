extends TesteBase
## Verifica o contrato de DadosArma e, principalmente, as armas .tres reais.
##
## Por que testar os .tres e nao so a classe: eles sao o painel de
## balanceamento do jogo e qualquer um mexe neles sem abrir GDScript. Um zero
## digitado errado em cadencia vira divisao por zero; uma pistola com municao
## finita quebra a promessa do GDD de que a arma inicial nunca acaba. Sao
## exatamente os erros que uma sessao de tuning produz.

const ARMAS := [
	"res://src/weapons/pistola.tres",
	"res://src/weapons/shotgun.tres",
	"res://src/weapons/tiro_vigia.tres",
	"res://src/weapons/tiro_diretora.tres",
	"res://src/weapons/salva_diretora.tres",
]


func nome() -> String:
	return "DadosArma"


func executar() -> void:
	_contrato()
	_armas_do_projeto()
	_pistola()


func _contrato() -> void:
	var a := DadosArma.new()

	a.municao_maxima = -1
	ok(a.municao_infinita(), "municao_maxima -1 e infinita")
	a.municao_maxima = 0
	ok(not a.municao_infinita(), "municao_maxima 0 nao e infinita")
	a.municao_maxima = 12
	ok(not a.municao_infinita(), "municao_maxima positiva nao e infinita")

	a.cadencia = 4.0
	perto(a.intervalo(), 0.25, "intervalo e o inverso da cadencia")
	a.cadencia = 10.0
	perto(a.intervalo(), 0.1, "cadencia maior gera intervalo menor")

	# maxf(cadencia, 0.01) existe para isto: uma arma com cadencia 0 salva no
	# Inspetor nao pode virar divisao por zero em tempo de execucao.
	a.cadencia = 0.0
	ok(is_finite(a.intervalo()), "cadencia 0 nao gera intervalo infinito")
	ok(a.intervalo() > 0.0, "cadencia 0 gera intervalo positivo")
	a.cadencia = -5.0
	ok(is_finite(a.intervalo()) and a.intervalo() > 0.0, "cadencia negativa nao quebra o intervalo")


## Sanidade de todas as armas do projeto. Sao invariantes, nao gosto: uma arma
## que viole qualquer uma delas esta quebrada, nao "balanceada diferente".
func _armas_do_projeto() -> void:
	for caminho in ARMAS:
		var arma: DadosArma = load(caminho)
		if arma == null:
			ok(false, "%s carrega" % caminho)
			continue

		var etiqueta := caminho.get_file()
		ok(arma.dano > 0, "%s: dano e positivo" % etiqueta)
		ok(arma.cadencia > 0.0, "%s: cadencia e positiva" % etiqueta)
		ok(arma.projeteis_por_tiro >= 1, "%s: dispara ao menos um projetil" % etiqueta)
		ok(arma.velocidade_projetil > 0.0, "%s: projetil tem velocidade" % etiqueta)
		ok(arma.alcance > 0.0, "%s: projetil tem alcance" % etiqueta)
		ok(arma.raio_projetil > 0.0, "%s: projetil tem raio" % etiqueta)
		ok(arma.perfuracao >= 0, "%s: perfuracao nao e negativa" % etiqueta)
		ok(arma.abertura_graus >= 0.0, "%s: abertura nao e negativa" % etiqueta)
		ok(not arma.nome.is_empty(), "%s: tem nome para a HUD" % etiqueta)

		# Uma arma de tiro unico com abertura configurada nao espalha nada --
		# o leque precisa de dois ou mais projeteis. Sinal de tuning enganoso.
		if arma.projeteis_por_tiro == 1:
			perto(arma.abertura_graus, 0.0, "%s: tiro unico nao declara abertura inutil" % etiqueta)

		# Municao finita tem de ser utilizavel.
		if not arma.municao_infinita():
			ok(arma.municao_maxima > 0, "%s: municao finita e maior que zero" % etiqueta)


## A pistola tem uma promessa explicita no GDD: nunca acaba.
func _pistola() -> void:
	var p: DadosArma = load("res://src/weapons/pistola.tres")
	if p == null:
		ok(false, "pistola.tres carrega")
		return
	ok(p.municao_infinita(), "a pistola inicial tem municao infinita")
	ok(p.automatica, "a pistola e automatica")

	var s: DadosArma = load("res://src/weapons/shotgun.tres")
	if s == null:
		ok(false, "shotgun.tres carrega")
		return
	ok(s.projeteis_por_tiro > 1, "a shotgun dispara varios projeteis")
	ok(s.abertura_graus > 0.0, "a shotgun espalha")
	ok(s.dano < p.dano * s.projeteis_por_tiro, "a shotgun troca dano por projetil por quantidade")
