extends TesteBase
## Confere os DadosPersonagem reais do projeto.
##
## Mesma pergunta que teste_dados_arma faz das armas: o dado que alimenta o jogo
## esta bem formado? Personagem e escolhido antes da run e nao tem como ser
## trocado depois -- um .tres torto aqui nao trava nada, so entrega uma run
## inteira com a arma errada ou um card em branco.
##
## A trava que mais importa e a da arma inicial nao estar no pool de loot. A
## arma de personagem ocupa o slot 0 e nunca sai; se ela tambem pudesse cair na
## sala de arma, o jogador ganharia de graca o que define outro personagem.

const PASTA := "res://src/player/"
const POOL := "res://src/items/pool_padrao.tres"

## Mesmo teto das outras descricoes que vao para a tela.
const MAXIMO_DESCRICAO := 300


func nome() -> String:
	return "Personagem"


func executar() -> void:
	_os_personagens_do_projeto()


func _os_personagens_do_projeto() -> void:
	var pasta := DirAccess.open(PASTA)
	if pasta == null:
		ok(false, "src/player/ pode ser aberta")
		return

	var pool: PoolLoot = load(POOL)
	var achados := 0

	for arquivo in pasta.get_files():
		if not arquivo.begins_with("personagem_") or not arquivo.ends_with(".tres"):
			continue
		achados += 1
		var p: DadosPersonagem = load(PASTA + arquivo)
		if p == null:
			ok(false, "%s carrega" % arquivo)
			continue

		ok(not String(p.id).is_empty(), "%s tem id" % arquivo)
		ok(not p.nome.is_empty(), "%s tem nome" % arquivo)
		ok(not p.papel.is_empty(), "%s tem papel para o card" % arquivo)
		ok(not p.descricao.is_empty(), "%s tem descricao" % arquivo)
		ok(
			p.descricao.length() <= MAXIMO_DESCRICAO,
			"%s: descricao cabe no card (%d de %d)" % [arquivo, p.descricao.length(), MAXIMO_DESCRICAO]
		)
		ok(p.cor.a > 0.0, "%s tem cor visivel" % arquivo)

		ok(p.arma_inicial != null, "%s tem arma inicial" % arquivo)
		if p.arma_inicial != null:
			# A arma do slot 0 nunca e descartada. Reserva finita deixaria o
			# personagem sem arma no meio da run, e o GDD promete o contrario.
			ok(
				p.arma_inicial.municao_infinita(),
				"%s: a arma inicial tem reserva infinita" % arquivo
			)
			if pool != null:
				var no_pool := false
				for a in pool.armas_validas():
					if a.resource_path == p.arma_inicial.resource_path:
						no_pool = true
				ok(not no_pool, "%s: a arma inicial nao cai como loot" % arquivo)

		# Coerencia do Hack: os numeros so precisam fazer sentido em quem tem.
		if p.tem_hack():
			entre(p.hack_chance, 0.0, 1.0, "%s: chance de Hack e uma probabilidade" % arquivo)
			ok(p.hack_duracao > 0.0, "%s: o Hack dura algum tempo" % arquivo)
			ok(p.hack_bonus_dano > 1.0, "%s: o Hack aumenta o dano recebido" % arquivo)
			entre(
				p.hack_chance_propagacao, 0.0, 1.0,
				"%s: chance de propagacao e uma probabilidade" % arquivo
			)
			ok(p.hack_raio_propagacao > 0.0, "%s: a propagacao tem raio" % arquivo)

	# Guarda contra a suite virar decoracao, como em teste_efeito_item.
	ok(achados >= 2, "a varredura achou os personagens (%d encontrados)" % achados)
