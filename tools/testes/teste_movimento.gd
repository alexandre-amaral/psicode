extends TesteBase
## O VOCABULARIO DE MOVIMENTACAO (INIM 07): perseguir, recuar, orbitar,
## investir, fugir.
##
## Duas coisas se cobram aqui, e a segunda e a que motivou a issue.
##
## A primeira e a MATEMATICA: `rumo_orbital` tem de continuar produzindo o que
## as cinco copias produziam. Extracao que muda o comportamento nao e extracao,
## e rebalanceamento disfarcado -- e a orbita e o que faz o jogador ler o campo.
##
## A segunda e a REGRA DO PROJETO: nada guarda velocidade ja multiplicada. Toda
## dificuldade le `Deterioracao` no frame em que precisa, e e isso que faz a
## barra subindo afetar inclusive os inimigos que ja estao em tela. Um helper
## que recebesse `velocidade: float` convidaria o chamador a calcular uma vez e
## guardar, e a regra morreria em silencio -- o inimigo continuaria andando,
## so que na velocidade do momento em que nasceu.

const CENA_SENTINELA := preload("res://src/enemies/sentinela_orbital.tscn")
const CENA_DRONE := preload("res://src/enemies/drone_aranha.tscn")
const CENA_HACKER := preload("res://src/enemies/hacker_parasita.tscn")
const CENA_BESTA := preload("res://src/enemies/cyber_besta.tscn")
const CENA_NEON := preload("res://src/enemies/atirador_neon.tscn")

## Longe da origem, como as outras suites que instanciam inimigo.
const LONGE := Vector2(41000.0, 41000.0)


func nome() -> String:
	return "Movimento"


func executar() -> void:
	_a_orbita_gira_e_corrige()
	_a_faixa_morta_deixa_circular_dentro_dela()
	_raio_zero_e_circular_fechando()
	_a_fuga_muda_de_ideia_na_distancia_minima()
	_a_esquiva_mistura_para_tras_com_de_lado()
	await _nenhum_verbo_guarda_velocidade_multiplicada()
	await _a_investida_ignora_a_deterioracao_e_o_desvio()
	_os_inimigos_migrados_usam_o_vocabulario()


# ---------------------------------------------------------- a matematica ----

## Tangente mais correcao radial: gira, e corrige para o raio certo.
##
## A forma proporcional e a da Sentinela, promovida a unica. O sinal da correcao
## e o que nao pode inverter: longe demais ela puxa PARA o alvo, perto demais
## empurra para fora. Trocado, o inimigo espirala para dentro ou para fora e
## ninguem ve erro nenhum.
func _a_orbita_gira_e_corrige() -> void:
	var para_alvo := Vector2.RIGHT

	# Exatamente no raio: so tangente.
	var no_raio := Movimento.rumo_orbital(para_alvo, 200.0, 200.0, 1.0, 0.55)
	perto(no_raio.angle_to(para_alvo.orthogonal()), 0.0,
		"no raio exato, o rumo e a tangente pura", 0.001)

	# Longe demais: a correcao aponta PARA o alvo.
	var longe := Movimento.rumo_orbital(para_alvo, 400.0, 200.0, 1.0, 0.55)
	ok(longe.dot(para_alvo) > 0.0,
		"longe demais, ele fecha a distancia (dot %.2f)" % longe.dot(para_alvo))
	ok(longe.dot(para_alvo.orthogonal()) > 0.0, "e continua girando enquanto fecha")

	# Perto demais: a correcao empurra para FORA.
	var perto_demais := Movimento.rumo_orbital(para_alvo, 40.0, 200.0, 1.0, 0.55)
	ok(perto_demais.dot(para_alvo) < 0.0,
		"perto demais, ele abre a distancia (dot %.2f)" % perto_demais.dot(para_alvo))

	# O sentido inverte a tangente e mais nada.
	var horario := Movimento.rumo_orbital(para_alvo, 400.0, 200.0, 1.0, 0.55)
	var anti := Movimento.rumo_orbital(para_alvo, 400.0, 200.0, -1.0, 0.55)
	perto(horario.dot(para_alvo), anti.dot(para_alvo),
		"o sentido nao mexe na componente radial -- so no lado da orbita", 0.001)
	ok(horario.dot(para_alvo.orthogonal()) > 0.0 and anti.dot(para_alvo.orthogonal()) < 0.0,
		"e os dois sentidos giram para lados opostos")

	perto(horario.length(), 1.0, "o rumo sai normalizado", 0.001)
	igual(Movimento.rumo_orbital(Vector2.ZERO, 0.0, 200.0, 1.0, 0.55), Vector2.ZERO,
		"sem alvo, nao ha rumo -- e ninguem sai correndo para lugar nenhum")


## A FAIXA MORTA. Dentro dela o inimigo so circula, e e isso que impede o
## empilhamento do Drone Aranha.
##
## Mirar um raio unico faria todos os drones convergirem para a MESMA
## circunferencia -- que e o empilhamento de novo, so que em anel, e os quatro
## aneis viram uma parede solida em vez de um padrao legivel.
func _a_faixa_morta_deixa_circular_dentro_dela() -> void:
	var para_alvo := Vector2.RIGHT
	var dentro := Movimento.rumo_orbital(para_alvo, 240.0, 240.0, 1.0, 0.18, 60.0)
	perto(absf(dentro.dot(para_alvo)), 0.0,
		"dentro da faixa ele NAO corrige: so circula", 0.001)

	var quase_no_limite := Movimento.rumo_orbital(para_alvo, 295.0, 240.0, 1.0, 0.18, 60.0)
	perto(absf(quase_no_limite.dot(para_alvo)), 0.0,
		"ainda dentro da faixa, ainda sem correcao", 0.001)

	var fora := Movimento.rumo_orbital(para_alvo, 320.0, 240.0, 1.0, 0.18, 60.0)
	ok(fora.dot(para_alvo) > 0.0, "passou da faixa: corrige com forca cheia, para dentro")

	var perto_demais := Movimento.rumo_orbital(para_alvo, 150.0, 240.0, 1.0, 0.18, 60.0)
	ok(perto_demais.dot(para_alvo) < 0.0, "e por baixo da faixa corrige para fora")

	# A conversao de faixa para raio+banda tem de dar exatamente a faixa pedida.
	var drone := _nascer(CENA_DRONE)
	var meio: float = (drone.distancia_de_recuo + drone.distancia_de_posicionamento) * 0.5
	var banda: float = (drone.distancia_de_posicionamento - drone.distancia_de_recuo) * 0.5
	perto(meio - banda, drone.distancia_de_recuo, "a faixa comeca na distancia de recuo do Drone")
	perto(meio + banda, drone.distancia_de_posicionamento, "e termina na de posicionamento")
	drone.free()


## `raio` zero nao e um caso degenerado: e "circula fechando".
##
## E o `OBSERVAR` da Cyber-Besta, que nao tem raio de orbita nenhum. Com raio
## zero o erro e sempre positivo, entao a correcao aponta sempre para o jogador
## -- ela contorna enquanto se aproxima. E o estado em que ela passa mais tempo
## se deslocando: se ele virasse "parado", as patas congelariam justamente onde
## ela mais anda.
func _raio_zero_e_circular_fechando() -> void:
	var para_alvo := Vector2.RIGHT
	for distancia in [50.0, 200.0, 600.0]:
		var rumo := Movimento.rumo_orbital(para_alvo, distancia, 0.0, 1.0, 0.538)
		ok(rumo.dot(para_alvo) > 0.0,
			"a %.0f px ela fecha a distancia (dot %.2f)" % [distancia, rumo.dot(para_alvo)])
		ok(rumo.dot(para_alvo.orthogonal()) > 0.0, "e contorna ao mesmo tempo, a %.0f px" % distancia)

	# E a mistura e a MESMA que o codigo antigo dela fazia: 0,35 para a frente
	# contra 0,65 de lado. Mudar isso a faria vir direto para cima do jogador, e
	# o estado perderia o nome.
	var antigo := (para_alvo * 0.35 + para_alvo.orthogonal() * 0.65).normalized()
	var novo := Movimento.rumo_orbital(para_alvo, 300.0, 0.0, 1.0, 0.538)
	perto(novo.angle_to(antigo), 0.0, "e bate com a conta que estava escrita nela", 0.002)


## A fuga troca de ideia na distancia minima: para tras perto, de lado longe.
##
## Fugir em linha reta o tempo todo encosta o inimigo na parede e o prende la --
## e um semeador preso na parede morre no primeiro segundo, sem semear nada.
func _a_fuga_muda_de_ideia_na_distancia_minima() -> void:
	var para_alvo := Vector2.RIGHT

	var perto_do_alvo := Movimento.rumo_de_fuga(para_alvo, 100.0, 240.0)
	perto(perto_do_alvo.dot(para_alvo), -1.0, "com o jogador em cima, ele vai para tras", 0.001)

	var longe := Movimento.rumo_de_fuga(para_alvo, 400.0, 240.0)
	perto(absf(longe.dot(para_alvo)), 0.0, "com espaco, ele so deriva de lado")
	perto(longe.length(), 1.0, "e a deriva sai em velocidade cheia -- o `* 0.5` antigo era apagado pela normalizacao", 0.001)

	igual(Movimento.rumo_de_fuga(Vector2.ZERO, 0.0, 240.0), Vector2.ZERO, "sem alvo, sem rumo")


## A esquiva mistura "para tras" com "de lado", e a mistura e o ponto.
##
## Puro para tras encosta o Atirador Neon na parede e ele fica preso ali; a
## componente lateral o faz contornar.
func _a_esquiva_mistura_para_tras_com_de_lado() -> void:
	var para_alvo := Vector2.RIGHT
	var esquiva := Movimento.rumo_de_esquiva(para_alvo, 1.0, 0.6)
	ok(esquiva.dot(para_alvo) < 0.0, "a esquiva se afasta do jogador")
	ok(absf(esquiva.dot(para_alvo.orthogonal())) > 0.1, "mas com componente lateral, para nao encostar na parede")
	ok(
		absf(esquiva.dot(para_alvo)) > absf(esquiva.dot(para_alvo.orthogonal())),
		"e o afastamento pesa mais que o lado -- e uma esquiva, nao uma orbita"
	)

	var outro_lado := Movimento.rumo_de_esquiva(para_alvo, -1.0, 0.6)
	perto(esquiva.dot(para_alvo), outro_lado.dot(para_alvo),
		"os dois lados se afastam igual", 0.001)
	ok(esquiva.dot(para_alvo.orthogonal()) * outro_lado.dot(para_alvo.orthogonal()) < 0.0,
		"e contornam para lados opostos")

	perto(Movimento.rumo_de_esquiva(Vector2.ZERO, 1.0).length(), 1.0,
		"sem alvo ela ainda devolve uma direcao valida -- um arranque para lugar nenhum e melhor que um NaN")


# ------------------------------------------------ a regra que nao pode cair --

## A REGRA: nenhum verbo guarda velocidade ja multiplicada.
##
## Todos leem `velocidade_atual()` no frame em que sao chamados, e essa funcao
## le `Deterioracao`. O teste sobe a barra entre duas chamadas identicas e exige
## que a segunda saia mais rapida -- e o que faz a barra subindo afetar
## inclusive quem ja esta em tela.
func _nenhum_verbo_guarda_velocidade_multiplicada() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)
	var jogador := CharacterBody2D.new()
	jogador.add_to_group("player")
	raiz.add_child(jogador)
	jogador.global_position = LONGE + Vector2(300.0, 0.0)

	var inimigo := CENA_SENTINELA.instantiate()
	raiz.add_child(inimigo)
	inimigo.global_position = LONGE
	await Engine.get_main_loop().process_frame

	var estado := Deterioracao.valor
	Deterioracao.valor = 0.0
	var lento := _medir(inimigo)
	Deterioracao.valor = 100.0
	var rapido := _medir(inimigo)
	Deterioracao.valor = estado

	for verbo in lento:
		ok(
			rapido[verbo] > lento[verbo] + 0.01,
			"`%s` le a Deterioracao no frame (%.0f com a barra em zero, %.0f com ela cheia)"
				% [verbo, lento[verbo], rapido[verbo]]
		)

	raiz.free()


## Roda cada verbo uma vez e devolve a velocidade que ele escreveu.
func _medir(inimigo: InimigoBase) -> Dictionary:
	var saida := {}
	inimigo.velocity = Vector2.ZERO
	Movimento.perseguir(inimigo, 0.016)
	saida["perseguir"] = inimigo.velocity.length()

	inimigo.velocity = Vector2.ZERO
	Movimento.recuar(inimigo, 0.016)
	saida["recuar"] = inimigo.velocity.length()

	inimigo.velocity = Vector2.ZERO
	Movimento.orbitar(inimigo, 0.016, 190.0, 1.0)
	saida["orbitar"] = inimigo.velocity.length()

	inimigo.velocity = Vector2.ZERO
	Movimento.orbitar_na_faixa(inimigo, 0.016, 180.0, 300.0, 1.0, 0.85)
	saida["orbitar_na_faixa"] = inimigo.velocity.length()

	inimigo.velocity = Vector2.ZERO
	Movimento.fugir(inimigo, 0.016, 240.0)
	saida["fugir"] = inimigo.velocity.length()

	inimigo.velocity = Vector2.ZERO
	Movimento.rumar(inimigo, 0.016, Vector2.RIGHT)
	saida["rumar"] = inimigo.velocity.length()
	return saida


## A investida e a excecao declarada, nos DOIS sentidos.
##
## Ela recebe velocidade pronta porque o numero e proprio do `.tres` e nao
## escala com a barra -- uma investida que acelera junto deixa de ser esquivavel
## pelo timing que o jogador acabou de aprender. E ela nao passa por
## `direcao_de_locomocao()`, porque durante a investida o inimigo nao contorna
## nada: e isso que faz a parede ser um recurso do jogador.
func _a_investida_ignora_a_deterioracao_e_o_desvio() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)
	var besta := CENA_BESTA.instantiate()
	raiz.add_child(besta)
	besta.global_position = LONGE
	await Engine.get_main_loop().process_frame

	var estado := Deterioracao.valor
	Deterioracao.valor = 0.0
	Movimento.investir(besta, Vector2.RIGHT, besta.velocidade_investida)
	var lenta: Vector2 = besta.velocity
	Deterioracao.valor = 100.0
	Movimento.investir(besta, Vector2.RIGHT, besta.velocidade_investida)
	var rapida: Vector2 = besta.velocity
	Deterioracao.valor = estado

	perto(lenta.length(), besta.velocidade_investida, "a investida sai na velocidade do .tres", 0.01)
	perto(rapida.length(), lenta.length(),
		"e NAO acelera com a barra: o timing da esquiva continua o que o jogador aprendeu", 0.01)
	perto(rapida.angle_to(Vector2.RIGHT), 0.0, "e vai em linha reta na direcao travada", 0.001)

	Movimento.investir(besta, Vector2.ZERO, 720.0)
	var depois: Vector2 = besta.velocity
	perto(depois.length(), lenta.length(),
		"direcao nula nao zera a investida no meio dela", 0.01)

	raiz.free()


# ------------------------------------------------------- quem ja migrou -----

## O criterio de aceite: ao menos tres inimigos usando os helpers, e nenhum
## deles com uma copia da conta de volta.
##
## Le o FONTE, e nao o comportamento, porque e a regressao que importa aqui: o
## comportamento continuaria certo se alguem reescrevesse a tangente na mao num
## inimigo so -- e seria exatamente a divergencia que esta issue existe para
## impedir, que aparece em tela e nunca no console.
##
## O Rastejante e o Vigia continuam de fora de proposito: eles sao a base que o
## playtest da v0.2.0-alpha validou, e a mesma razao que os mantem fora de
## `direcao_de_locomocao()` os mantem fora daqui.
func _os_inimigos_migrados_usam_o_vocabulario() -> void:
	var migrados := {
		"sentinela_orbital": "orbitar",
		"drone_aranha": "orbitar_na_faixa",
		"hacker_parasita": "fugir",
		"cyber_besta": "investir",
		"atirador_neon": "rumar",
	}
	var quantos := 0
	for arquivo in migrados:
		var fonte := FileAccess.get_file_as_string("res://src/enemies/%s.gd" % arquivo)
		if fonte.is_empty():
			ok(false, "%s.gd foi lido" % arquivo)
			continue
		var verbo: String = migrados[arquivo]
		if ok_e_conta(fonte.contains("Movimento.%s(" % verbo),
				"%s usa `Movimento.%s()` do vocabulario" % [arquivo, verbo]):
			quantos += 1
		# A conta nao pode ter voltado para o arquivo do inimigo.
		ok(not fonte.contains("orthogonal() * _sentido"),
			"%s nao guarda uma copia da tangente da orbita" % arquivo)
	ok(quantos >= 3, "ao menos tres inimigos migrados (%d)" % quantos)


## `ok()` que tambem devolve o resultado, para contar quantos passaram.
func ok_e_conta(condicao: bool, descricao: String) -> bool:
	ok(condicao, descricao)
	return condicao


func _nascer(cena: PackedScene) -> Node:
	var no := cena.instantiate()
	no.position = LONGE
	Engine.get_main_loop().root.add_child(no)
	return no
