extends Node
## Runner das suites de teste unitario.
##
## Por que existe separado do teste de fumaca: o teste de fumaca sobe o jogo
## inteiro e leva minutos -- ele responde "a run inteira funciona?". Este aqui
## nao instancia cena nenhuma e roda em menos de um segundo; ele responde "a
## conta esta certa?". Sao perguntas diferentes e quebram por motivos
## diferentes, entao rodam separados: quando este falha voce sabe que e logica
## pura, sem precisar ler 200 linhas de log de gameplay.
##
## Cada suite e um script que estende TesteBase e implementa executar().
## Para adicionar uma suite: crie o arquivo, herde de TesteBase, e liste em
## SUITES abaixo.
##
## Use:  godot --headless --path . tools/testes/runner.tscn
## Saida 0 = passou. Qualquer outra coisa = quebrou.

const SUITES := [
	"res://tools/testes/teste_deterioracao.gd",
	"res://tools/testes/teste_balistica.gd",
	"res://tools/testes/teste_dados_arma.gd",
	"res://tools/testes/teste_game_state.gd",
	"res://tools/testes/teste_dados_sala.gd",
	"res://tools/testes/teste_modificadores.gd",
	"res://tools/testes/teste_efeito_item.gd",
	"res://tools/testes/teste_grade.gd",
	"res://tools/testes/teste_arma.gd",
	"res://tools/testes/teste_configuracao.gd",
	"res://tools/testes/teste_composicao.gd",
	"res://tools/testes/teste_maquina_estados.gd",
	"res://tools/testes/teste_area_de_perigo.gd",
	"res://tools/testes/teste_texturas.gd",
	"res://tools/testes/teste_personagem.gd",
	"res://tools/testes/teste_hack.gd",
	"res://tools/testes/teste_traducao.gd",
	"res://tools/testes/teste_explosao.gd",
]


func _ready() -> void:
	# Roda depois da arvore montar. get_tree().quit() chamado de dentro do
	# _ready nao encerra de forma confiavel -- a cena ainda esta sendo
	# construida e o pedido se perde, deixando o processo vivo ate o timeout do
	# runner de CI. O teste de fumaca acerta isso porque so encerra a partir do
	# _process; aqui nao ha _process, entao o await faz o mesmo papel.
	await get_tree().process_frame
	_rodar()


func _rodar() -> void:
	print("\n=== TESTES UNITARIOS: psicode ===\n")

	var total := 0
	var falhas: Array[String] = []
	var suites_quebradas := 0

	for caminho: String in SUITES:
		var script: GDScript = load(caminho)
		# Um script com erro de parse NAO volta null: volta um GDScript
		# invalido, em que `new()` nao existe. Testar so por null deixava o
		# .new() estourar e o runner morria antes de imprimir o relatorio --
		# sem encerrar o processo, segurando o job de CI ate o timeout.
		# can_instantiate() e o que de fato separa um dos outros.
		if script == null or not script.can_instantiate():
			print("  [FALHA] a suite %s nao carregou (erro de sintaxe?)" % caminho)
			falhas.append("suite nao carregou: %s" % caminho)
			suites_quebradas += 1
			continue

		var suite: TesteBase = script.new()
		# `await` e nao chamada direta: suite que precisa de passo de FISICA --
		# a explosao, por exemplo, so enxerga um corpo depois que ele entrou no
		# espaco -- tem de poder esperar. Sem isto o runner imprime o relatorio
		# antes de a suite terminar, e as verificacoes dela somem da conta sem
		# uma linha de erro. Suite sincrona nao paga nada por este await.
		await suite.executar()

		print("  %s" % suite.nome())
		for linha in suite.relatorio():
			print("    %s" % linha)

		total += suite.total
		for f in suite.falhas:
			falhas.append("%s :: %s" % [suite.nome(), f])

	print("\n--- resultado ---")
	if falhas.is_empty():
		print("  PASSOU: %d verificacoes em %d suites\n" % [total, SUITES.size()])
		get_tree().quit(0)
	else:
		# Conta as suites que rodaram de verdade: dizer "em 4 suites" quando
		# uma nem carregou esconde justamente o pior caso.
		print("  FALHOU: %d problema(s) em %d verificacoes (%d de %d suites rodaram)" % [
			falhas.size(), total, SUITES.size() - suites_quebradas, SUITES.size(),
		])
		for f in falhas:
			print("    - " + f)
		print("")
		get_tree().quit(1)
