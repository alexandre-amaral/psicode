extends TesteBase
## Verifica o acumulo dos implantes e os .tres reais do pool.
##
## Por que testar os .tres junto da conta: implante e o painel de balanceamento
## novo, e ele tem uma armadilha propria -- dano e int. Um "+10% de dano" numa
## pistola de dano 2 arredonda de volta para 2 e o implante nao faz nada, sem
## erro nenhum. Melhor falhar aqui que num playtest.

const POOL := "res://src/items/pool_padrao.tres"


func nome() -> String:
	return "Modificadores"


func executar() -> void:
	_neutro()
	_acumulo()
	_limite_por_run()
	_pool_do_projeto()
	# A suite mexe no autoload de verdade; deixar sujo contaminaria quem rodar
	# depois e, se alguem apontar o runner para uma cena de jogo, a run.
	Modificadores.resetar()


func _neutro() -> void:
	Modificadores.resetar()
	perto(Modificadores.multiplicador_velocidade(), 1.0, "velocidade neutra apos resetar")
	perto(Modificadores.multiplicador_cadencia(), 1.0, "cadencia neutra apos resetar")
	perto(Modificadores.multiplicador_cooldown_rolamento(), 1.0, "cooldown neutro apos resetar")
	perto(Modificadores.multiplicador_ganho_deterioracao(), 1.0, "ganho de deterioracao neutro apos resetar")
	igual(Modificadores.bonus_vida_maxima(), 0, "sem bonus de vida apos resetar")
	igual(Modificadores.bonus_dano(), 0, "sem bonus de dano apos resetar")
	ok(Modificadores.itens_ativos().is_empty(), "lista de implantes vazia apos resetar")


func _acumulo() -> void:
	Modificadores.resetar()

	var veloz := DadosItem.new()
	veloz.alvo = DadosItem.Alvo.VELOCIDADE
	veloz.modo = DadosItem.Modo.MULTIPLICA
	veloz.valor = 1.1

	ok(Modificadores.aplicar(veloz), "o primeiro implante e aplicado")
	perto(Modificadores.multiplicador_velocidade(), 1.1, "um implante de 1.1 da 1.1")
	Modificadores.aplicar(veloz)
	# Multiplicativo, nao somado: 1.1 duas vezes e 1.21, nao 1.2.
	perto(Modificadores.multiplicador_velocidade(), 1.21, "dois implantes de 1.1 acumulam por produto")

	var vida := DadosItem.new()
	vida.alvo = DadosItem.Alvo.VIDA_MAXIMA
	vida.modo = DadosItem.Modo.SOMA
	vida.valor = 2.0
	Modificadores.aplicar(vida)
	Modificadores.aplicar(vida)
	igual(Modificadores.bonus_vida_maxima(), 4, "dois implantes de +2 somam 4")

	# Alvo que ninguem tocou continua neutro mesmo com outros acumulados.
	perto(Modificadores.multiplicador_cadencia(), 1.0, "alvo intocado segue neutro")
	igual(Modificadores.itens_ativos().size(), 4, "a lista guarda todos os coletados")


func _limite_por_run() -> void:
	Modificadores.resetar()
	var unico := DadosItem.new()
	unico.alvo = DadosItem.Alvo.CADENCIA
	unico.modo = DadosItem.Modo.MULTIPLICA
	unico.valor = 1.5
	unico.maximo_por_run = 1

	ok(Modificadores.aplicar(unico), "implante limitado entra na primeira vez")
	ok(not Modificadores.aplicar(unico), "implante limitado recusa a segunda vez")
	perto(Modificadores.multiplicador_cadencia(), 1.5, "o recusado nao acumulou")

	Modificadores.resetar()
	perto(Modificadores.multiplicador_cadencia(), 1.0, "resetar limpa o acumulo")


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

		# Dano e vida sao int no jogo: percentual some no arredondamento.
		if item.alvo == DadosItem.Alvo.DANO or item.alvo == DadosItem.Alvo.VIDA_MAXIMA:
			ok(
				item.modo == DadosItem.Modo.SOMA,
				"%s mexe num valor inteiro, entao tem de somar e nao multiplicar" % item.nome
			)
		if item.modo == DadosItem.Modo.MULTIPLICA:
			ok(item.valor > 0.0, "%s multiplica por valor positivo" % item.nome)
		else:
			ok(not is_equal_approx(item.valor, 0.0), "%s soma algo diferente de zero" % item.nome)

	# A arma do inimigo nao pode virar loot do jogador. O que impede isso e nao
	# estar no pool, entao vale conferir explicitamente.
	var proibidas := [
		"res://src/weapons/tiro_vigia.tres",
		"res://src/weapons/tiro_diretora.tres",
		"res://src/weapons/salva_diretora.tres",
		"res://src/weapons/pistola.tres",
	]
	for arma in pool.armas_validas():
		ok(
			not proibidas.has(arma.resource_path),
			"%s nao e arma de inimigo nem a pistola inicial" % arma.nome
		)
		ok(arma.municao_maxima > 0, "%s de loot tem municao finita" % arma.nome)
