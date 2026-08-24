extends TesteBase
## Contrato de EfeitoItem e conferencia dos .tres de implante do projeto.
##
## Separado de teste_modificadores porque a pergunta e outra: la e "a conta do
## acumulo esta certa?", aqui e "o dado que alimenta a conta esta bem formado?".
## Um .tres torto passa pelo acumulo sem erro nenhum e so aparece como implante
## que nao faz nada.

const PASTA := "res://src/items/"


func nome() -> String:
	return "EfeitoItem"


func executar() -> void:
	_neutro_por_modo()
	_alvos_inteiros()
	_resumo()
	_implantes_do_projeto()


func _neutro_por_modo() -> void:
	var mult := EfeitoItem.new()
	mult.modo = EfeitoItem.Modo.MULTIPLICA
	perto(mult.neutro(), 1.0, "o neutro de MULTIPLICA e 1.0")
	ok(mult.eh_multiplicativo(), "MULTIPLICA e multiplicativo")

	var soma := EfeitoItem.new()
	soma.modo = EfeitoItem.Modo.SOMA
	perto(soma.neutro(), 0.0, "o neutro de SOMA e 0.0")
	ok(not soma.eh_multiplicativo(), "SOMA nao e multiplicativo")


## Dano e vida sao int no jogo. Percentual em cima deles some no arredondamento
## -- e a armadilha que fez DANO_PERCENTUAL existir como alvo separado.
func _alvos_inteiros() -> void:
	ok(EfeitoItem.alvo_e_inteiro(EfeitoItem.Alvo.DANO), "DANO guarda inteiro")
	ok(EfeitoItem.alvo_e_inteiro(EfeitoItem.Alvo.VIDA_MAXIMA), "VIDA_MAXIMA guarda inteiro")
	ok(not EfeitoItem.alvo_e_inteiro(EfeitoItem.Alvo.DANO_PERCENTUAL), "DANO_PERCENTUAL nao e inteiro")
	ok(not EfeitoItem.alvo_e_inteiro(EfeitoItem.Alvo.CADENCIA), "CADENCIA nao e inteiro")
	ok(not EfeitoItem.alvo_e_inteiro(EfeitoItem.Alvo.VELOCIDADE), "VELOCIDADE nao e inteiro")


func _resumo() -> void:
	var e := EfeitoItem.new()
	e.modo = EfeitoItem.Modo.MULTIPLICA
	e.valor = 1.2
	igual(e.resumo(), "+20%", "resumo de multiplicador vira percentual")

	e.modo = EfeitoItem.Modo.SOMA
	e.valor = 2.0
	igual(e.resumo(), "+2", "resumo de soma vira numero direto")


## Varre os .tres de implante de verdade. Todo implante que existe no disco tem
## de estar bem formado, esteja ele no pool ou nao -- um .tres orfao hoje e o
## implante que alguem arrasta para o pool amanha.
func _implantes_do_projeto() -> void:
	var pasta := DirAccess.open(PASTA)
	if pasta == null:
		ok(false, "src/items/ pode ser aberta")
		return

	var achados := 0
	for arquivo in pasta.get_files():
		if not arquivo.begins_with("implante_") or not arquivo.ends_with(".tres"):
			continue
		achados += 1
		var item: DadosItem = load(PASTA + arquivo)
		if item == null:
			ok(false, "%s carrega" % arquivo)
			continue

		ok(item.faz_alguma_coisa(), "%s tem efeito ou comportamento" % arquivo)
		ok(not item.nome.is_empty(), "%s tem nome" % arquivo)
		ok(not item.descricao.is_empty(), "%s tem descricao para o jogador" % arquivo)
		ok(not item.sigla.is_empty(), "%s tem sigla para o pickup" % arquivo)

		for efeito in item.efeitos_validos():
			if EfeitoItem.alvo_e_inteiro(efeito.alvo):
				ok(not efeito.eh_multiplicativo(), "%s: alvo inteiro nao multiplica" % arquivo)
			# Multiplicador 1.0 e o neutro: um efeito assim nao faz nada e
			# quase sempre e um campo esquecido no Inspetor.
			if efeito.eh_multiplicativo():
				ok(
					not is_equal_approx(efeito.valor, 1.0),
					"%s: efeito multiplicativo nao e o neutro 1.0" % arquivo
				)

	# Guarda contra a suite virar decoracao: se a varredura nao achar arquivo
	# nenhum, tudo acima passa sem ter olhado nada.
	ok(achados >= 10, "a varredura achou os implantes (%d encontrados)" % achados)
