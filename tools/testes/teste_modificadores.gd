extends TesteBase
## Verifica o acumulo dos implantes, os condicionais e os .tres reais do pool.
##
## Por que testar os .tres junto da conta: implante e o painel de balanceamento
## novo, e ele tem armadilhas proprias. A pior: dano e int no jogo, entao um
## "+10% de dano" numa pistola de dano 2 arredonda de volta para 2 e o implante
## nao faz nada -- sem erro nenhum. Melhor falhar aqui que num playtest.

const POOL := "res://src/items/pool_padrao.tres"


func nome() -> String:
	return "Modificadores"


func executar() -> void:
	_neutro()
	_acumulo()
	_varios_efeitos()
	_condicional_vida_baixa()
	_condicional_por_carga()
	_condicional_tiros_de_eco()
	_limite_por_run()
	_reset_limpa_estado_dinamico()
	_pool_do_projeto()
	# A suite mexe no autoload de verdade; deixar sujo contaminaria quem rodar
	# depois e, se alguem apontar o runner para uma cena de jogo, a run.
	Modificadores.resetar()


# ------------------------------------------------------------ helpers -------

func _efeito(alvo: int, modo: int, valor: float, cond: int = EfeitoItem.Condicao.SEMPRE) -> EfeitoItem:
	var e := EfeitoItem.new()
	e.alvo = alvo
	e.modo = modo
	e.valor = valor
	e.condicao = cond
	return e


func _item(efeitos: Array[EfeitoItem], comportamento: int = DadosItem.Comportamento.NENHUM, parametro: float = 0.0) -> DadosItem:
	var i := DadosItem.new()
	i.efeitos = efeitos
	i.comportamento = comportamento
	i.parametro = parametro
	return i


# ------------------------------------------------------------- casos --------

func _neutro() -> void:
	Modificadores.resetar()
	perto(Modificadores.multiplicador_velocidade(), 1.0, "velocidade neutra apos resetar")
	perto(Modificadores.multiplicador_cadencia(), 1.0, "cadencia neutra apos resetar")
	perto(Modificadores.multiplicador_cooldown_rolamento(), 1.0, "cooldown neutro apos resetar")
	perto(Modificadores.multiplicador_dano(), 1.0, "dano percentual neutro apos resetar")
	perto(Modificadores.multiplicador_ganho_deterioracao(), 1.0, "ganho de deterioracao neutro apos resetar")
	igual(Modificadores.bonus_vida_maxima(), 0, "sem bonus de vida apos resetar")
	igual(Modificadores.bonus_dano(), 0, "sem bonus de dano apos resetar")
	perto(Modificadores.chance_ricochete(), 0.0, "sem ricochete apos resetar")
	perto(Modificadores.chance_fragmentacao(), 0.0, "sem fragmentacao apos resetar")
	ok(Modificadores.itens_ativos().is_empty(), "lista de implantes vazia apos resetar")


func _acumulo() -> void:
	Modificadores.resetar()
	var efeitos: Array[EfeitoItem] = [_efeito(EfeitoItem.Alvo.VELOCIDADE, EfeitoItem.Modo.MULTIPLICA, 1.1)]
	var veloz := _item(efeitos)

	ok(Modificadores.aplicar(veloz), "o primeiro implante e aplicado")
	perto(Modificadores.multiplicador_velocidade(), 1.1, "um implante de 1.1 da 1.1")
	Modificadores.aplicar(veloz)
	# Multiplicativo, nao somado: 1.1 duas vezes e 1.21, nao 1.2.
	perto(Modificadores.multiplicador_velocidade(), 1.21, "dois implantes de 1.1 acumulam por produto")

	var somas: Array[EfeitoItem] = [_efeito(EfeitoItem.Alvo.VIDA_MAXIMA, EfeitoItem.Modo.SOMA, 2.0)]
	var vida := _item(somas)
	Modificadores.aplicar(vida)
	Modificadores.aplicar(vida)
	igual(Modificadores.bonus_vida_maxima(), 4, "dois implantes de +2 somam 4")

	perto(Modificadores.multiplicador_cadencia(), 1.0, "alvo intocado segue neutro")
	igual(Modificadores.itens_ativos().size(), 4, "a lista guarda todos os coletados")


## O caso que o modelo antigo nao conseguia expressar: um item, dois efeitos.
func _varios_efeitos() -> void:
	Modificadores.resetar()
	var efeitos: Array[EfeitoItem] = [
		_efeito(EfeitoItem.Alvo.CADENCIA, EfeitoItem.Modo.MULTIPLICA, 1.2),
		_efeito(EfeitoItem.Alvo.GANHO_DETERIORACAO, EfeitoItem.Modo.MULTIPLICA, 1.1),
	]
	Modificadores.aplicar(_item(efeitos))
	perto(Modificadores.multiplicador_cadencia(), 1.2, "o primeiro efeito do item vale")
	perto(Modificadores.multiplicador_ganho_deterioracao(), 1.1, "o segundo efeito do MESMO item tambem vale")


func _condicional_vida_baixa() -> void:
	Modificadores.resetar()
	var efeitos: Array[EfeitoItem] = [
		_efeito(EfeitoItem.Alvo.DANO_PERCENTUAL, EfeitoItem.Modo.MULTIPLICA, 1.4, EfeitoItem.Condicao.VIDA_BAIXA),
	]
	Modificadores.aplicar(_item(efeitos, DadosItem.Comportamento.SOBRECARGA, 0.3))

	# Vida cheia: o bonus NAO pode estar valendo.
	EventBus.player_dano_recebido.emit(6, 6)
	perto(Modificadores.multiplicador_dano(), 1.0, "com vida cheia a Sobrecarga fica desligada")

	# Abaixo do limiar: liga.
	EventBus.player_dano_recebido.emit(1, 6)
	perto(Modificadores.multiplicador_dano(), 1.4, "abaixo de 30%% de vida a Sobrecarga liga")

	# Curar de volta desliga -- o bonus nao pode grudar.
	EventBus.player_curado.emit(6, 6)
	perto(Modificadores.multiplicador_dano(), 1.0, "curar acima do limiar desliga a Sobrecarga")


func _condicional_por_carga() -> void:
	Modificadores.resetar()
	var efeitos: Array[EfeitoItem] = [
		_efeito(EfeitoItem.Alvo.DANO_PERCENTUAL, EfeitoItem.Modo.MULTIPLICA, 1.05, EfeitoItem.Condicao.POR_CARGA),
	]
	Modificadores.aplicar(_item(efeitos, DadosItem.Comportamento.CARGAS_SEM_DANO, 5.0))
	EventBus.player_dano_recebido.emit(6, 6)

	perto(Modificadores.multiplicador_dano(), 1.0, "sem carga nenhuma o Daemon nao soma")
	igual(Modificadores.cargas(), 0, "o Daemon comeca sem carga")

	for i in 3:
		EventBus.inimigo_morreu.emit(Vector2.ZERO, 3)
	igual(Modificadores.cargas(), 3, "tres abates viram tres cargas")
	perto(Modificadores.multiplicador_dano(), pow(1.05, 3), "tres cargas de 5%% acumulam por produto")

	# Teto: mais abates que o parametro nao passam de 5.
	for i in 10:
		EventBus.inimigo_morreu.emit(Vector2.ZERO, 3)
	igual(Modificadores.cargas(), 5, "as cargas param no teto do implante")

	# Levar dano zera tudo.
	EventBus.player_dano_recebido.emit(4, 6)
	igual(Modificadores.cargas(), 0, "levar dano zera as cargas do Daemon")
	perto(Modificadores.multiplicador_dano(), 1.0, "sem cargas o bonus some junto")


## O gatilho da Celula de Eco e o FIM da recarga -- so existe porque o sistema
## de pente passou a existir. Antes nao havia evento nenhum para pendurar isto.
func _condicional_tiros_de_eco() -> void:
	Modificadores.resetar()
	var efeitos: Array[EfeitoItem] = [
		_efeito(EfeitoItem.Alvo.DANO_PERCENTUAL, EfeitoItem.Modo.MULTIPLICA, 1.5, EfeitoItem.Condicao.TIROS_DE_ECO),
	]
	Modificadores.aplicar(_item(efeitos, DadosItem.Comportamento.ECO, 3.0))

	igual(Modificadores.tiros_de_eco(), 0, "sem recarregar nao ha tiro de eco")
	perto(Modificadores.multiplicador_dano(), 1.0, "sem tiro de eco o bonus nao vale")

	EventBus.recarga_concluida.emit()
	igual(Modificadores.tiros_de_eco(), 3, "recarregar carrega os tres tiros")
	perto(Modificadores.multiplicador_dano(), 1.5, "com tiro de eco o bonus vale")

	# Consumir os tres apaga o bonus -- e por tiro, nao por projetil.
	for i in 3:
		Modificadores.consumir_tiro_de_eco()
	igual(Modificadores.tiros_de_eco(), 0, "tres tiros consomem a carga inteira")
	perto(Modificadores.multiplicador_dano(), 1.0, "gasto o eco, o bonus some")

	# Consumir a mais nao deixa o contador negativo.
	Modificadores.consumir_tiro_de_eco()
	igual(Modificadores.tiros_de_eco(), 0, "consumir sem carga nao vai a negativo")


func _limite_por_run() -> void:
	Modificadores.resetar()
	var efeitos: Array[EfeitoItem] = [_efeito(EfeitoItem.Alvo.CADENCIA, EfeitoItem.Modo.MULTIPLICA, 1.5)]
	var unico := _item(efeitos)
	unico.maximo_por_run = 1

	ok(Modificadores.aplicar(unico), "implante limitado entra na primeira vez")
	ok(not Modificadores.aplicar(unico), "implante limitado recusa a segunda vez")
	perto(Modificadores.multiplicador_cadencia(), 1.5, "o recusado nao acumulou")


## Se o reset esquecer o estado dinamico, a dificuldade vaza de uma run para a
## seguinte -- e isso nao aparece em erro nenhum, so em bug de balanceamento.
func _reset_limpa_estado_dinamico() -> void:
	Modificadores.resetar()
	var efeitos: Array[EfeitoItem] = [
		_efeito(EfeitoItem.Alvo.DANO_PERCENTUAL, EfeitoItem.Modo.MULTIPLICA, 1.05, EfeitoItem.Condicao.POR_CARGA),
	]
	Modificadores.aplicar(_item(efeitos, DadosItem.Comportamento.CARGAS_SEM_DANO, 5.0))
	EventBus.inimigo_morreu.emit(Vector2.ZERO, 3)
	EventBus.player_dano_recebido.emit(1, 6)

	Modificadores.resetar()
	igual(Modificadores.cargas(), 0, "resetar zera as cargas")
	igual(Modificadores.tiros_de_eco(), 0, "resetar zera os tiros de eco")
	perto(Modificadores.multiplicador_dano(), 1.0, "resetar limpa o acumulo")
	# Vida volta a cheia: senao a proxima run comecaria com a Sobrecarga ligada.
	perto(Modificadores.multiplicador_no_alvo(123), 1.0, "resetar solta o alvo marcado")


func _pool_do_projeto() -> void:
	var pool: PoolLoot = load(POOL)
	ok(pool != null, "pool_padrao.tres carrega")
	if pool == null:
		return

	ok(not pool.itens_validos().is_empty(), "o pool tem ao menos um implante")
	ok(not pool.armas_validas().is_empty(), "o pool tem ao menos uma arma")

	for item in pool.itens_validos():
		ok(item.nome != "", "implante tem nome")
		ok(item.maximo_por_run >= 0, "%s nao tem limite negativo" % item.nome)
		ok(item.cor.a > 0.0, "%s tem cor visivel" % item.nome)
		# Implante sem efeito e sem comportamento e um .tres esquecido pela
		# metade: ele aparece no chao, e coletado, e nao faz nada.
		ok(item.faz_alguma_coisa(), "%s faz alguma coisa (efeito ou comportamento)" % item.nome)

		# Comportamento que depende de parametro e inutil com parametro zero.
		if item.tem_comportamento():
			ok(item.parametro > 0.0, "%s tem parametro utilizavel" % item.nome)

		for efeito in item.efeitos_validos():
			# A armadilha do arredondamento: percentual sobre valor inteiro
			# some. Dano e vida somam; quem quer percentual usa DANO_PERCENTUAL.
			if EfeitoItem.alvo_e_inteiro(efeito.alvo):
				ok(
					not efeito.eh_multiplicativo(),
					"%s mexe num valor inteiro, entao soma em vez de multiplicar" % item.nome
				)
			if efeito.alvo == EfeitoItem.Alvo.DANO_PERCENTUAL:
				ok(
					efeito.eh_multiplicativo(),
					"%s usa DANO_PERCENTUAL, que so faz sentido multiplicando" % item.nome
				)
			if efeito.eh_multiplicativo():
				ok(efeito.valor > 0.0, "%s multiplica por valor positivo" % item.nome)
			else:
				ok(not is_equal_approx(efeito.valor, 0.0), "%s soma algo diferente de zero" % item.nome)

	# A arma do inimigo nao pode virar loot do jogador. O que impede isso e nao
	# estar no pool, entao vale conferir explicitamente.
	var proibidas := [
		"res://src/weapons/tiro_vigia.tres",
		"res://src/weapons/tiro_diretora.tres",
		"res://src/weapons/salva_diretora.tres",
		"res://src/weapons/pistola.tres",
		"res://src/weapons/smg_mantis.tres",
		"res://src/weapons/pistola_cipher.tres",
	]
	for arma in pool.armas_validas():
		ok(
			not proibidas.has(arma.resource_path),
			"%s nao e arma de inimigo nem a pistola inicial" % arma.nome
		)
		# Reserva infinita e uma DECISAO, nao um descuido: com ela a arma de
		# loot nunca e descartada e o slot 1 vira permanente. Quem quiser a arma
		# temporaria de volta poe uma reserva finita no .tres.
		ok(arma.pente() >= 1, "%s tem pente utilizavel" % arma.nome)
		ok(arma.tempo_recarga > 0.0, "%s recarrega em tempo positivo" % arma.nome)
