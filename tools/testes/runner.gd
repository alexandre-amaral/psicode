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

	for caminho in SUITES:
		var script: GDScript = load(caminho)
		if script == null:
			# Uma suite que nao carrega e uma falha, nao um aviso. Sem isso um
			# erro de sintaxe faria a suite sumir silenciosamente do relatorio
			# e o CI passaria verde sem ter rodado nada dela.
			print("  [FALHA] nao consegui carregar a suite %s" % caminho)
			falhas.append("suite nao carregou: %s" % caminho)
			suites_quebradas += 1
			continue

		var suite: TesteBase = script.new()
		suite.executar()

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
		print("  FALHOU: %d de %d verificacoes" % [falhas.size(), total])
		for f in falhas:
			print("    - " + f)
		print("")
		get_tree().quit(1)
