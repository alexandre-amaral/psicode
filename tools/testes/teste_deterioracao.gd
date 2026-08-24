extends TesteBase
## Deterioracao e o sistema-assinatura: TODO numero de dificuldade do jogo sai
## daqui. Um erro nesta curva nao quebra o jogo -- ele desbalanceia tudo de uma
## vez, silenciosamente. Por isso as verificacoes aqui sao das mais detalhadas
## do projeto.
##
## A suite mexe no autoload global e o restaura no fim, senao a proxima suite
## rodaria em cima de um valor sujo.


func nome() -> String:
	return "Deterioracao"


func executar() -> void:
	var valor_original := Deterioracao.valor
	var passiva_original := Deterioracao.passiva_ativa

	_limites()
	_fases()
	_multiplicadores()
	_mira_preditiva()
	_glitch()
	_rotulos()
	_ritmo_da_run()

	Deterioracao.passiva_ativa = passiva_original
	Deterioracao.valor = valor_original


## A curva de dificuldade da run inteira, conferida pelos numeros que a
## produzem -- e nao pela sensacao de quem jogou.
##
## Existe por causa de um defeito real, que a `tools/medir_ritmo.tscn` mediu: a
## mira preditiva (o diferencial declarado do GDD) ligava no primeiro terco da
## partida, antes de o jogador ter formado o habito de esquiva que ela existe
## para trair. Quem dominava a curva nao era o ganho passivo, e sim o ganho por
## sala limpa.
##
## As tres assercoes abaixo sao o cerco em volta desse ajuste. Nenhuma delas
## checa "o numero e X" -- todas checam a RELACAO entre os numeros, para a
## sessao de tuning poder mexer nos valores sem o teste virar um muro.
func _ritmo_da_run() -> void:
	var combate: DadosSala = load("res://src/mapa/tipo_combate.tres")
	var chefe: DadosSala = load("res://src/mapa/tipo_boss.tres")
	if combate == null or chefe == null:
		ok(false, "os tipos de sala de combate e de chefe carregam")
		return

	# 1. O andar tem ~6 salas de combate. Se elas sozinhas ja passarem do
	#    limiar critico, a barra chega no teto antes do chefe e a ultima parte
	#    da run roda com a dificuldade travada -- escalada nenhuma.
	var salas_de_combate := 6.0
	var so_das_salas := combate.deterioracao_ao_limpar * salas_de_combate
	ok(
		so_das_salas < Deterioracao.LIMIAR_CRITICO,
		"limpar as ~%.0f salas de combate nao basta para chegar em CRITICO (%.0f de %.0f)" % [
			salas_de_combate, so_das_salas, Deterioracao.LIMIAR_CRITICO,
		]
	)

	# 2. Somando o ganho passivo, a barra TEM de passar do limiar MEDIO antes da
	#    sala do chefe. Se nao passar, a mira preditiva so aconteceria por causa
	#    do piso do chefe, e o jogador nunca a enfrentaria numa sala comum --
	#    que e onde ela foi desenhada para doer.
	#
	#    Os 120 s sao conservadores de proposito: a `tools/medir_ritmo.tscn`
	#    mediu de 1min38 (jogador rapido) a 3min45 (cauteloso) ate a porta do
	#    chefe. Usar o piso da faixa faz a assercao valer para todo mundo.
	var segundos_ate_o_chefe := 120.0
	var antes_do_chefe := so_das_salas + Deterioracao.ganho_passivo_por_segundo * segundos_ate_o_chefe
	ok(
		antes_do_chefe >= Deterioracao.LIMIAR_MEDIO,
		"ate a porta do chefe a barra passa do limiar MEDIO mesmo na run mais rapida (%.0f de %.0f)" % [
			antes_do_chefe, Deterioracao.LIMIAR_MEDIO,
		]
	)
	# E nao pode encostar no teto antes de chegar la: a partir do teto a
	# escalada acabou, e o resto da run roda com a dificuldade travada.
	ok(
		antes_do_chefe < Deterioracao.MAXIMO,
		"a barra nao estoura antes da sala do chefe (%.0f de %.0f)" % [
			antes_do_chefe, Deterioracao.MAXIMO,
		]
	)

	# 3. O piso da sala do chefe tem de ficar ACIMA do que a run alcanca
	#    sozinha, senao ele nunca faz nada e a luta final acontece no nivel em
	#    que a partida por acaso chegou. Foi o defeito que este ajuste corrigiu:
	#    o proximo mexer nos valores nao pode desfaze-lo em silencio.
	ok(
		chefe.deterioracao_minima_ao_entrar > so_das_salas,
		"o piso da sala do chefe (%.0f) ainda vale para uma run que so limpou salas (%.0f)" % [
			chefe.deterioracao_minima_ao_entrar, so_das_salas,
		]
	)
	ok(
		chefe.deterioracao_minima_ao_entrar >= Deterioracao.LIMIAR_CRITICO,
		"a luta do chefe comeca em nivel CRITICO, como o GDD pede (%.0f)" % chefe.deterioracao_minima_ao_entrar
	)

	# O ganho passivo continua existindo: e a pressao de tempo do GDD, e sem ele
	# parar de avancar deixa de custar caro.
	ok(
		Deterioracao.ganho_passivo_por_segundo > 0.0,
		"o ganho passivo nao foi zerado (%.2f/s)" % Deterioracao.ganho_passivo_por_segundo
	)


## O setter faz clamp. Sem isso um adicionar() generoso levaria a barra a 130% e
## todo lerp que usa normalizado() extrapolaria junto.
func _limites() -> void:
	Deterioracao.valor = -50.0
	perto(Deterioracao.valor, 0.0, "valor negativo e travado em 0")

	Deterioracao.valor = 500.0
	perto(Deterioracao.valor, Deterioracao.MAXIMO, "valor acima do maximo e travado em MAXIMO")

	Deterioracao.valor = 40.0
	Deterioracao.adicionar(15.0)
	perto(Deterioracao.valor, 55.0, "adicionar soma ao valor atual")

	Deterioracao.adicionar(1000.0)
	perto(Deterioracao.valor, Deterioracao.MAXIMO, "adicionar tambem respeita o teto")

	Deterioracao.valor = 70.0
	Deterioracao.passiva_ativa = true
	Deterioracao.resetar()
	perto(Deterioracao.valor, 0.0, "resetar zera o valor")
	ok(not Deterioracao.passiva_ativa, "resetar desliga o ganho passivo")
	igual(Deterioracao.fase, Deterioracao.Fase.BAIXA, "resetar volta para a fase BAIXA")


## Os limiares sao 50 e 85. Testa exatamente nas bordas, que e onde erro de
## >= vs > se esconde.
func _fases() -> void:
	Deterioracao.valor = 0.0
	igual(Deterioracao.fase, Deterioracao.Fase.BAIXA, "0% e fase BAIXA")

	Deterioracao.valor = Deterioracao.LIMIAR_MEDIO - 0.01
	igual(Deterioracao.fase, Deterioracao.Fase.BAIXA, "logo abaixo do limiar medio ainda e BAIXA")

	Deterioracao.valor = Deterioracao.LIMIAR_MEDIO
	igual(Deterioracao.fase, Deterioracao.Fase.MEDIA, "exatamente no limiar medio ja e MEDIA")

	Deterioracao.valor = Deterioracao.LIMIAR_CRITICO - 0.01
	igual(Deterioracao.fase, Deterioracao.Fase.MEDIA, "logo abaixo do limiar critico ainda e MEDIA")

	Deterioracao.valor = Deterioracao.LIMIAR_CRITICO
	igual(Deterioracao.fase, Deterioracao.Fase.CRITICA, "exatamente no limiar critico ja e CRITICA")

	Deterioracao.valor = Deterioracao.MAXIMO
	igual(Deterioracao.fase, Deterioracao.Fase.CRITICA, "100% e fase CRITICA")


## Todos os multiplicadores partem de 1.0 na barra vazia e crescem monotonamente.
## Se algum comecar diferente de 1.0, a onda 1 ja nasce mais dificil do que o
## GDD pede.
func _multiplicadores() -> void:
	Deterioracao.valor = 0.0
	perto(Deterioracao.normalizado(), 0.0, "normalizado e 0 na barra vazia")
	perto(Deterioracao.multiplicador_velocidade(), 1.0, "velocidade parte de 1.0")
	perto(Deterioracao.multiplicador_cadencia(), 1.0, "cadencia parte de 1.0")
	perto(Deterioracao.multiplicador_velocidade_projetil(), 1.0, "velocidade de projetil parte de 1.0")

	Deterioracao.valor = Deterioracao.MAXIMO
	perto(Deterioracao.normalizado(), 1.0, "normalizado e 1 na barra cheia")
	perto(Deterioracao.multiplicador_velocidade(), 1.55, "velocidade satura em 1.55")
	perto(Deterioracao.multiplicador_cadencia(), 1.7, "cadencia satura em 1.7")
	perto(Deterioracao.multiplicador_velocidade_projetil(), 1.25, "velocidade de projetil satura em 1.25")

	# Projetil sobe menos que o resto de proposito: projetil rapido demais vira
	# injusto em vez de dificil. Se alguem "arrumar" isso igualando as curvas, o
	# teste avisa.
	ok(Deterioracao.multiplicador_velocidade_projetil() < Deterioracao.multiplicador_velocidade(),
		"projetil escala mais contido que o inimigo")

	Deterioracao.valor = 50.0
	entre(Deterioracao.multiplicador_velocidade(), 1.0, 1.55, "velocidade no meio fica entre os extremos")

	# Monotonia: nunca pode existir um ponto da barra em que subir a
	# deterioracao deixe o jogo mais facil.
	var anterior := 0.0
	var monotono := true
	for i in 21:
		Deterioracao.valor = i * 5.0
		var atual := Deterioracao.multiplicador_velocidade()
		if atual < anterior:
			monotono = false
		anterior = atual
	ok(monotono, "multiplicador de velocidade nunca cai quando a barra sobe")


## O diferencial do MVP. A virada tem de acontecer em 50 e ser suave depois
## dela -- um degrau seco vira muro para o jogador.
func _mira_preditiva() -> void:
	Deterioracao.valor = Deterioracao.LIMIAR_MEDIO - 0.01
	ok(not Deterioracao.usa_mira_preditiva(), "nao preve logo abaixo de 50%")
	perto(Deterioracao.precisao_preditiva(), 0.0, "precisao e 0 abaixo do limiar")

	Deterioracao.valor = Deterioracao.LIMIAR_MEDIO
	ok(Deterioracao.usa_mira_preditiva(), "preve a partir de 50%")
	perto(Deterioracao.precisao_preditiva(), 0.55, "precisao comeca em 0.55, nao em 0")

	Deterioracao.valor = Deterioracao.MAXIMO
	perto(Deterioracao.precisao_preditiva(), 1.0, "precisao satura em 1.0")

	# A rampa entre 50 e 100 tem de ser crescente, senao "suave" nao significa
	# nada.
	Deterioracao.valor = 75.0
	var meio := Deterioracao.precisao_preditiva()
	entre(meio, 0.55, 1.0, "precisao no meio da rampa fica entre os extremos")
	ok(meio > 0.55, "precisao cresce depois do limiar")


## O glitch so aparece a partir de 35%: antes disso o jogo tem de estar limpo,
## senao o jogador nao percebe a degradacao acontecendo.
func _glitch() -> void:
	Deterioracao.valor = 0.0
	perto(Deterioracao.intensidade_glitch(), 0.0, "sem glitch na barra vazia")

	Deterioracao.valor = 34.9
	perto(Deterioracao.intensidade_glitch(), 0.0, "sem glitch logo abaixo de 35%")

	Deterioracao.valor = 35.0
	perto(Deterioracao.intensidade_glitch(), 0.0, "glitch comeca em zero exatamente em 35%")

	Deterioracao.valor = Deterioracao.MAXIMO
	perto(Deterioracao.intensidade_glitch(), 1.0, "glitch satura em 1.0")

	Deterioracao.valor = 70.0
	entre(Deterioracao.intensidade_glitch(), 0.0, 1.0, "glitch intermediario fica normalizado")


## Rotulo e cor alimentam a HUD. Um match sem default devolveria "?" e a HUD
## mostraria isso para o jogador.
func _rotulos() -> void:
	Deterioracao.valor = 10.0
	igual(Deterioracao.nome_fase(), "ESTAVEL", "fase BAIXA se chama ESTAVEL")
	Deterioracao.valor = 60.0
	igual(Deterioracao.nome_fase(), "DEGRADANDO", "fase MEDIA se chama DEGRADANDO")
	Deterioracao.valor = 90.0
	igual(Deterioracao.nome_fase(), "CRITICO", "fase CRITICA se chama CRITICO")

	var cores := {}
	for v in [10.0, 60.0, 90.0]:
		Deterioracao.valor = v
		cores[Deterioracao.cor_fase()] = true
	igual(cores.size(), 3, "cada fase tem uma cor distinta")
