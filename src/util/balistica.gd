class_name Balistica
extends RefCounted
## Matematica de tiro. Isolada aqui porque e a peca mais facil de errar
## e a mais importante de acertar: e ela que da identidade ao inimigo Ranged
## e ao chefe quando a Deterioracao passa de 50%.


## Resolve o problema do intercepto: dado um atirador parado, um alvo que se
## move em linha reta e um projetil de velocidade constante, para onde apontar?
##
## Resolvemos |alvo + v*t - origem| = vel_projetil * t, que vira a quadratica
##   (|v|^2 - vp^2) t^2 + 2 (d . v) t + |d|^2 = 0
## e devolvemos a menor raiz positiva (o impacto que acontece primeiro).
##
## Se nao existe solucao -- o alvo foge mais rapido que a bala -- caimos no
## comportamento burro de mirar na posicao atual. Isso e proposital: e melhor
## um tiro que erra do que um inimigo que trava.
static func ponto_de_intercepto(
	origem: Vector2,
	alvo_pos: Vector2,
	alvo_vel: Vector2,
	vel_projetil: float
) -> Vector2:
	if vel_projetil <= 0.0:
		return alvo_pos

	var d := alvo_pos - origem
	var a := alvo_vel.length_squared() - vel_projetil * vel_projetil
	var b := 2.0 * d.dot(alvo_vel)
	var c := d.length_squared()

	var t := -1.0

	if absf(a) < 0.0001:
		# Alvo e projetil na mesma velocidade: a quadratica degenera em linear.
		if absf(b) < 0.0001:
			return alvo_pos
		t = -c / b
	else:
		var disc := b * b - 4.0 * a * c
		if disc < 0.0:
			return alvo_pos
		var raiz := sqrt(disc)
		var t1 := (-b + raiz) / (2.0 * a)
		var t2 := (-b - raiz) / (2.0 * a)
		# Menor tempo positivo.
		if t1 > 0.0 and t2 > 0.0:
			t = minf(t1, t2)
		elif t1 > 0.0:
			t = t1
		elif t2 > 0.0:
			t = t2

	if t <= 0.0:
		return alvo_pos

	# Teto de 2s: sem isso, um alvo quase-inalcancavel gera uma previsao
	# absurda do outro lado do mapa e o inimigo atira para o nada.
	t = minf(t, 2.0)
	return alvo_pos + alvo_vel * t


## Mistura entre mirar na posicao atual (peso 0) e no intercepto perfeito
## (peso 1). O peso vem de Deterioracao.precisao_preditiva(), o que faz a
## dificuldade escalar suave em vez de virar uma chave liga/desliga.
static func mira_ponderada(
	origem: Vector2,
	alvo_pos: Vector2,
	alvo_vel: Vector2,
	vel_projetil: float,
	peso: float
) -> Vector2:
	if peso <= 0.0:
		return alvo_pos
	var previsto := ponto_de_intercepto(origem, alvo_pos, alvo_vel, vel_projetil)
	return alvo_pos.lerp(previsto, clampf(peso, 0.0, 1.0))


## Leque de direcoes simetrico em torno de uma direcao base.
## Usado por shotgun e pelos ataques em leque do chefe.
static func leque(direcao: Vector2, quantidade: int, abertura_graus: float) -> Array[Vector2]:
	var saida: Array[Vector2] = []
	if quantidade <= 0:
		return saida
	if quantidade == 1:
		saida.append(direcao.normalized())
		return saida
	var abertura := deg_to_rad(abertura_graus)
	var passo := abertura / float(quantidade - 1)
	var inicio := -abertura * 0.5
	for i in quantidade:
		saida.append(direcao.rotated(inicio + passo * i).normalized())
	return saida


## Anel completo de direcoes. Base dos padroes bullet hell do chefe.
static func anel(quantidade: int, rotacao_inicial: float = 0.0) -> Array[Vector2]:
	var saida: Array[Vector2] = []
	if quantidade <= 0:
		return saida
	var passo := TAU / float(quantidade)
	for i in quantidade:
		saida.append(Vector2.RIGHT.rotated(rotacao_inicial + passo * i))
	return saida
