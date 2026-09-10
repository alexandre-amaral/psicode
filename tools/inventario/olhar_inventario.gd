extends Node
## As DUAS telas novas no enquadramento real, para a pergunta que nao se
## automatiza.
##
## Os portoes de `teste_inventario.gd` e `teste_troca_de_arma.gd` respondem "as
## abas existem?" e "a caixa clicavel e a desenhada?". Nenhum dos dois responde
## **"da para ler isto de relance no meio de uma run?"**, que e a unica pergunta
## que estas telas existem para acertar. Essa fica como captura -- e foi ela que
## achou os dois defeitos que portao nenhum pega: `draw_string` alinhado a
## direita desenhando FORA do painel, e o nome mais comprido da pool entrando por
## cima da coluna de barras.
##
## Ele monta o pior caso de proposito: os 16 implantes instalados de uma vez,
## que e a build cheia que o §69 do plano pede e que nenhuma run normal produz.
## Com dois implantes qualquer layout funciona; e com dezesseis que se descobre
## se a grade estoura a largura da aba.
##
## Uso: godot --path . tools/inventario/olhar_inventario.tscn --resolution 960x544
## As imagens saem em user://capturas.

const SAIDA := "user://capturas"

const MANTIS := "res://src/weapons/smg_mantis.tres"
const RAIL_X := "res://src/weapons/rail_x.tres"
const BOOMER := "res://src/weapons/boomer.tres"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAIDA)
	# A run precisa estar CORRENDO: a tela de inventario recusa abrir fora dela,
	# e recusar fora da run e justamente uma das regras dela.
	GameState.iniciar_run()
	await _fotografar_inventario()
	await _fotografar_troca()
	get_tree().quit()


## O corpo com a build CHEIA -- os 16 implantes de uma vez.
func _fotografar_inventario() -> void:
	Modificadores.resetar()
	var instalados := 0
	for ident in _ids_de_implante():
		var item: DadosItem = load("res://src/items/implante_%s.tres" % ident)
		if item != null and Modificadores.aplicar(item):
			instalados += 1
	print("  implantes instalados: %d" % instalados)

	var tela: CanvasLayer = load("res://src/ui/tela_inventario.tscn").instantiate()
	add_child(tela)
	# A aba de armamento le o Player por grupo, e aqui nao ha nenhum: as fotos
	# saem com as duas vagas livres, que e o outro extremo util -- a grade cheia
	# ao lado do armamento vazio mostra os dois estados no mesmo conjunto.
	tela.abrir()

	# **As TRES abas, e nao so a primeira.** Fotografar so a aberta e o jeito de
	# entregar um layout quebrado nas outras duas: elas nunca sao desenhadas ate
	# alguem clicar, e ninguem clica antes do playtest.
	var nomes := ["itens", "armamento", "status"]
	for i in nomes.size():
		tela.mostrar_aba(i)
		for _j in 4:
			await get_tree().process_frame
		_salvar("inventario_%d_%s.png" % [i + 1, nomes[i]])

	tela.fechar()
	tela.queue_free()
	Modificadores.resetar()


## A escolha da terceira arma.
func _fotografar_troca() -> void:
	var inv := InventarioDeArmas.new()
	inv.definir_inicial(load(MANTIS) as DadosArma)
	inv.pedir_aquisicao(load(RAIL_X) as DadosArma)
	# Gastar o pente das duas: o numero que a troca preserva so aparece na foto
	# se ele nao for o pente cheio das duas.
	inv.slot(0).pente = 11
	inv.slot(1).pente = 2

	var tela := TelaTrocaDeArma.abrir(self, load(BOOMER) as DadosArma, inv)
	for _i in 4:
		await get_tree().process_frame
	_salvar("troca_de_arma.png")
	# A tela pausa a arvore ao montar. Sem despausar, o `create_timer` da proxima
	# etapa nunca dispara e a ferramenta fica viva ate o timeout.
	get_tree().paused = false
	tela.queue_free()


func _ids_de_implante() -> Array[String]:
	var ids: Array[String] = []
	var dir := DirAccess.open("res://src/items/")
	if dir == null:
		return ids
	for arquivo in dir.get_files():
		if arquivo.begins_with("implante_") and arquivo.ends_with(".tres"):
			ids.append(arquivo.trim_prefix("implante_").trim_suffix(".tres"))
	ids.sort()
	return ids


func _salvar(nome: String) -> void:
	# Sem janela nao ha o que fotografar: o driver headless nao rasteriza. A
	# ferramenta continua util assim mesmo -- ela sobe as duas telas, e um erro
	# de script aparece no console do CI mesmo sem imagem.
	if DisplayServer.get_name() == "headless":
		print("  (headless: %s nao foi salva)" % nome)
		return
	get_viewport().get_texture().get_image().save_png("%s/%s" % [SAIDA, nome])
	print("  %s" % nome)
