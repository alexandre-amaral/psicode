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
	"res://src/weapons/smg_mantis.tres",
	"res://src/weapons/pistola_cipher.tres",
	"res://src/weapons/rail_x.tres",
	"res://src/weapons/phase_blaster.tres",
	"res://src/weapons/gravity_gun.tres",
	"res://src/weapons/boomer.tres",
	"res://src/weapons/plasma_arc.tres",
	"res://src/weapons/tiro_vigia.tres",
	"res://src/weapons/tiro_diretora.tres",
	"res://src/weapons/salva_diretora.tres",
]

## Mesmo teto do implante: os dois textos vao para o mesmo Label da HUD.
const MAXIMO_DESCRICAO := 140


func nome() -> String:
	return "DadosArma"


## O perfil que a tela de selecao desenha em barras.
##
## A PRECISAO e invertida -- espalhamento maior significa barra menor -- e e
## exatamente o tipo de conta que erra calado: trocado o sinal, a SMG apareceria
## como a arma mais precisa do jogo e nada no console reclamaria.
func _perfil_da_arma() -> void:
	var mantis: DadosArma = load("res://src/weapons/smg_mantis.tres")
	var cipher: DadosArma = load("res://src/weapons/pistola_cipher.tres")
	if mantis == null or cipher == null:
		ok(false, "as armas de personagem carregam")
		return

	ok(mantis.perfil_cadencia() > cipher.perfil_cadencia(), "a SMG dispara mais rapido que a Cipher")
	ok(cipher.perfil_dano() > mantis.perfil_dano(), "a Cipher bate mais forte que a SMG")
	ok(cipher.perfil_precisao() > mantis.perfil_precisao(), "a Cipher e mais precisa que a SMG")
	ok(cipher.perfil_alcance() > mantis.perfil_alcance(), "a Cipher alcanca mais que a SMG")

	# O bloom conta na precisao: uma SMG que abre 7 graus segurando o gatilho nao
	# e precisa, ainda que o primeiro tiro seja.
	var sem_bloom := DadosArma.new()
	sem_bloom.impressao_graus = mantis.impressao_graus
	ok(
		sem_bloom.perfil_precisao() > mantis.perfil_precisao(),
		"a mesma arma sem bloom aparece mais precisa"
	)

	# Toda barra e uma fracao: fora de 0..1 o desenho estoura o numero de
	# segmentos, e uma arma exagerada satura em vez de quebrar o layout.
	for arma: DadosArma in [mantis, cipher, load("res://src/weapons/shotgun.tres")]:
		for valor: float in [arma.perfil_dano(), arma.perfil_cadencia(),
				arma.perfil_precisao(), arma.perfil_alcance()]:
			entre(valor, 0.0, 1.0, "%s: barra dentro de 0..1" % arma.nome)


func executar() -> void:
	_perfil_da_arma()
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
	for caminho: String in ARMAS:
		var arma: DadosArma = load(caminho)
		if arma == null:
			ok(false, "%s carrega" % caminho)
			continue

		var etiqueta: String = caminho.get_file()
		ok(arma.dano > 0, "%s: dano e positivo" % etiqueta)
		ok(arma.cadencia > 0.0, "%s: cadencia e positiva" % etiqueta)
		ok(arma.projeteis_por_tiro >= 1, "%s: dispara ao menos um projetil" % etiqueta)
		ok(arma.velocidade_projetil > 0.0, "%s: projetil tem velocidade" % etiqueta)
		ok(arma.alcance > 0.0, "%s: projetil tem alcance" % etiqueta)
		ok(arma.raio_projetil > 0.0, "%s: projetil tem raio" % etiqueta)
		ok(arma.perfuracao >= 0, "%s: perfuracao nao e negativa" % etiqueta)
		ok(arma.abertura_graus >= 0.0, "%s: abertura nao e negativa" % etiqueta)
		ok(not arma.nome.is_empty(), "%s: tem nome para a HUD" % etiqueta)
		# A descricao virou texto de tela quando o aviso de aquisicao passou a
		# mostra-la: arma sem descricao agora e uma linha em branco na HUD.
		ok(not arma.descricao.is_empty(), "%s: tem descricao para o aviso" % etiqueta)
		ok(
			arma.descricao.length() <= MAXIMO_DESCRICAO,
			"%s: descricao cabe no aviso (%d de %d)" % [etiqueta, arma.descricao.length(), MAXIMO_DESCRICAO]
		)

		# Uma arma de tiro unico com abertura configurada nao espalha nada --
		# o leque precisa de dois ou mais projeteis. Sinal de tuning enganoso.
		if arma.projeteis_por_tiro == 1:
			perto(arma.abertura_graus, 0.0, "%s: tiro unico nao declara abertura inutil" % etiqueta)

		# Municao finita tem de ser utilizavel.
		if not arma.municao_infinita():
			ok(arma.municao_maxima > 0, "%s: municao finita e maior que zero" % etiqueta)

		# Pente zero travaria a arma para sempre: ela nunca poderia atirar e
		# nada apareceria no console. Mesma classe de erro que cadencia zero.
		ok(arma.tamanho_pente >= 1, "%s: pente cabe ao menos um tiro" % etiqueta)
		igual(arma.pente(), maxi(arma.tamanho_pente, 1), "%s: pente() protege do zero" % etiqueta)
		ok(arma.tempo_recarga > 0.0, "%s: recarga leva tempo positivo" % etiqueta)


## A pistola tem uma promessa explicita no GDD: nunca acaba.
func _pistola() -> void:
	var p: DadosArma = load("res://src/weapons/pistola.tres")
	if p == null:
		ok(false, "pistola.tres carrega")
		return
	# A promessa do GDD virou "RESERVA infinita": a pistola nunca fica sem
	# balas, mas agora pausa para recarregar como qualquer arma.
	ok(p.municao_infinita(), "a pistola inicial tem reserva infinita")
	ok(p.automatica, "a pistola e automatica")
	ok(p.tamanho_pente >= 10, "o pente da pistola e generoso (ela e a arma de base)")

	var s: DadosArma = load("res://src/weapons/shotgun.tres")
	if s == null:
		ok(false, "shotgun.tres carrega")
		return
	ok(s.projeteis_por_tiro > 1, "a shotgun dispara varios projeteis")
	ok(s.abertura_graus > 0.0, "a shotgun espalha")
	ok(s.dano < p.dano * s.projeteis_por_tiro, "a shotgun troca dano por projetil por quantidade")
