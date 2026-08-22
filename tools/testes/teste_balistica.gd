extends TesteBase
## Balistica e a peca mais facil de errar do projeto e a que da identidade ao
## Vigia e a Diretora. O teste de fumaca ja cobre o caminho feliz; aqui vao os
## casos de borda que so aparecem em partida real -- alvo mais rapido que a
## bala, alvo em cima do atirador, projetil de velocidade zero.


func nome() -> String:
	return "Balistica"


func executar() -> void:
	_intercepto()
	_degenerados()
	_ponderacao()
	_leque()
	_anel()


func _intercepto() -> void:
	# Alvo parado: o intercepto e a propria posicao dele.
	var p := Balistica.ponto_de_intercepto(Vector2.ZERO, Vector2(100, 0), Vector2.ZERO, 500.0)
	ok(p.is_equal_approx(Vector2(100, 0)), "alvo parado: mira na posicao atual")

	# Alvo cruzando: a previsao cai a frente dele, no sentido do movimento.
	var q := Balistica.ponto_de_intercepto(Vector2.ZERO, Vector2(300, 0), Vector2(0, 200), 600.0)
	ok(q.y > 0.0, "alvo subindo: previsao vai para cima (y=%.1f)" % q.y)
	perto(q.x, 300.0, "alvo subindo: a previsao nao desloca em x")

	# Quanto mais rapido o alvo, mais a frente a previsao.
	var lento := Balistica.ponto_de_intercepto(Vector2.ZERO, Vector2(300, 0), Vector2(0, 100), 600.0)
	var rapido := Balistica.ponto_de_intercepto(Vector2.ZERO, Vector2(300, 0), Vector2(0, 300), 600.0)
	ok(rapido.y > lento.y, "alvo mais rapido gera previsao mais adiantada")

	# Bala mais rapida chega antes, entao antecipa menos.
	var bala_lenta := Balistica.ponto_de_intercepto(Vector2.ZERO, Vector2(300, 0), Vector2(0, 200), 400.0)
	var bala_rapida := Balistica.ponto_de_intercepto(Vector2.ZERO, Vector2(300, 0), Vector2(0, 200), 1200.0)
	ok(bala_rapida.y < bala_lenta.y, "bala mais rapida antecipa menos")


## Casos que devolvem a posicao atual em vez de travar ou devolver NaN. Todos
## acontecem em partida: o jogador rolando e mais rapido que alguns projeteis.
func _degenerados() -> void:
	var fugindo := Balistica.ponto_de_intercepto(Vector2.ZERO, Vector2(100, 0), Vector2(900, 0), 200.0)
	ok(fugindo.is_equal_approx(Vector2(100, 0)), "alvo fugindo mais rapido que a bala: cai na mira burra")

	var parado := Balistica.ponto_de_intercepto(Vector2.ZERO, Vector2(100, 0), Vector2.ZERO, 0.0)
	ok(parado.is_equal_approx(Vector2(100, 0)), "projetil de velocidade zero: cai na mira burra")

	var negativo := Balistica.ponto_de_intercepto(Vector2.ZERO, Vector2(100, 0), Vector2.ZERO, -50.0)
	ok(negativo.is_equal_approx(Vector2(100, 0)), "velocidade negativa: cai na mira burra")

	# Alvo em cima do atirador: distancia zero nao pode virar divisao por zero.
	var colado := Balistica.ponto_de_intercepto(Vector2.ZERO, Vector2.ZERO, Vector2(100, 0), 500.0)
	ok(is_finite(colado.x) and is_finite(colado.y), "alvo colado no atirador devolve ponto finito")

	# Alvo na MESMA velocidade da bala: a quadratica degenera em linear. E o
	# caso que mais quebra implementacao de intercepto.
	var mesma := Balistica.ponto_de_intercepto(Vector2.ZERO, Vector2(300, 0), Vector2(500, 0), 500.0)
	ok(is_finite(mesma.x) and is_finite(mesma.y), "alvo na velocidade da bala devolve ponto finito")

	# Teto de 2s: sem ele um alvo quase-inalcancavel gera previsao do outro lado
	# do mapa e o inimigo atira para o nada.
	var quase := Balistica.ponto_de_intercepto(Vector2.ZERO, Vector2(100, 0), Vector2(0, 499.0), 500.0)
	ok(quase.distance_to(Vector2(100, 0)) <= 499.0 * 2.0 + 1.0, "previsao respeita o teto de 2 segundos")


func _ponderacao() -> void:
	var origem := Vector2.ZERO
	var alvo := Vector2(300, 0)
	var vel := Vector2(0, 400)

	var peso_zero := Balistica.mira_ponderada(origem, alvo, vel, 600.0, 0.0)
	ok(peso_zero.is_equal_approx(alvo), "peso 0 ignora completamente a previsao")

	var peso_um := Balistica.mira_ponderada(origem, alvo, vel, 600.0, 1.0)
	var puro := Balistica.ponto_de_intercepto(origem, alvo, vel, 600.0)
	ok(peso_um.is_equal_approx(puro), "peso 1 e o intercepto puro")

	var meio := Balistica.mira_ponderada(origem, alvo, vel, 600.0, 0.5)
	ok(meio.y > peso_zero.y and meio.y < peso_um.y, "peso 0.5 fica entre a mira burra e o intercepto")

	# Peso fora de [0,1] tem de ser travado, senao a Diretora com precisao > 1
	# miraria alem do ponto de intercepto.
	var acima := Balistica.mira_ponderada(origem, alvo, vel, 600.0, 5.0)
	ok(acima.is_equal_approx(puro), "peso acima de 1 e travado em 1")
	var abaixo := Balistica.mira_ponderada(origem, alvo, vel, 600.0, -3.0)
	ok(abaixo.is_equal_approx(alvo), "peso negativo e travado em 0")


func _leque() -> void:
	var cinco := Balistica.leque(Vector2.RIGHT, 5, 40.0)
	igual(cinco.size(), 5, "leque devolve a quantidade pedida")
	perto(cinco[0].angle() + cinco[4].angle(), 0.0, "leque e simetrico em torno da direcao base", 0.001)
	perto(cinco[2].angle(), 0.0, "o tiro do meio segue a direcao base", 0.001)

	var um := Balistica.leque(Vector2.RIGHT, 1, 40.0)
	igual(um.size(), 1, "leque de 1 devolve um unico tiro")
	ok(um[0].is_equal_approx(Vector2.RIGHT), "leque de 1 vai reto, sem abertura")

	igual(Balistica.leque(Vector2.RIGHT, 0, 40.0).size(), 0, "leque de 0 devolve vazio")
	igual(Balistica.leque(Vector2.RIGHT, -3, 40.0).size(), 0, "leque negativo devolve vazio")

	var normalizados := true
	for d in Balistica.leque(Vector2(7, 3), 7, 90.0):
		if absf(d.length() - 1.0) > 0.001:
			normalizados = false
	ok(normalizados, "todas as direcoes do leque sao normalizadas")

	# Abertura maior espalha mais -- e o que separa pistola de shotgun.
	var estreito := Balistica.leque(Vector2.RIGHT, 3, 10.0)
	var largo := Balistica.leque(Vector2.RIGHT, 3, 80.0)
	ok(absf(largo[0].angle()) > absf(estreito[0].angle()), "abertura maior espalha mais")


func _anel() -> void:
	var doze := Balistica.anel(12)
	igual(doze.size(), 12, "anel devolve a quantidade pedida")

	var soma := Vector2.ZERO
	for d in doze:
		soma += d
	perto(soma.length(), 0.0, "anel e equilibrado: as direcoes se cancelam", 0.001)

	igual(Balistica.anel(0).size(), 0, "anel de 0 devolve vazio")
	igual(Balistica.anel(-5).size(), 0, "anel negativo devolve vazio")

	# A rotacao inicial e o que faz salvas consecutivas do chefe nao sairem
	# sempre nos mesmos angulos.
	var sem_giro := Balistica.anel(8, 0.0)
	var com_giro := Balistica.anel(8, PI / 8.0)
	ok(not sem_giro[0].is_equal_approx(com_giro[0]), "rotacao inicial desloca o anel")
	perto(com_giro[0].angle(), PI / 8.0, "rotacao inicial e aplicada ao primeiro raio", 0.001)
