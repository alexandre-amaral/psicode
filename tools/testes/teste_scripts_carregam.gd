extends TesteBase
## TODO SCRIPT DO PROJETO COMPILA.
##
## **Esta suite nasceu de um runaway de sete minutos.** Os dois laboratorios da
## fabrica (`tools/fabrica/`) foram escritos com um erro de parse cada -- um
## `const` recebendo `PackedVector2Array`, que nao e expressao constante, e um
## `:=` inferindo de um Variant. Nenhum dos dois apareceu em lugar nenhum:
##
## - `godot --headless --path . --import` **passou limpo**. O import cuida de
##   RECURSO (textura, cena, som); ele nao carrega todo `.gd` para compilar.
## - O `runner.gd` so confere as suites que estao na lista `SUITES` dele.
## - O teste de fumaca nunca abre uma ferramenta de `tools/`.
##
## E o sintoma nao foi um erro: foi SILENCIO. Script com erro de parse nao
## carrega, entao a cena sobe **sem script nenhum**, o `_ready` nunca roda, nada
## e impresso, e o processo fica ocioso no main loop para sempre -- consumindo
## um sexto de um nucleo, dentro do OneDrive, segurando handle. Foram 6m54s de
## relogio antes de alguem desconfiar, e o `GEMINI.md` ja registrava exatamente
## essa forma de falha ("cena headless nem sempre encerra sozinha, e o resto
## vira runaway") sem que houvesse portao para ela.
##
## O que esta suite afirma e barato e obvio depois de escrito: **todo `.gd` do
## repositorio pode ser carregado.** Ela nao roda nada, nao instancia nada e nao
## julga comportamento -- ela so prova que o parser aceita o arquivo.
##
## Por que `can_instantiate()` e nao so `!= null`: um script com erro de parse
## NAO volta `null`, volta um `GDScript` invalido em que `new()` nao existe. E a
## mesma armadilha que o `runner.gd` ja documenta para as suites, aplicada ao
## projeto inteiro.

## As pastas varridas. `src/` e o jogo; `tools/` sao as reguas, e foi justamente
## uma regua que quebrou -- varrer so `src/` teria deixado o defeito passar.
const PASTAS := ["res://src", "res://tools"]

## Arquivos que NAO carregam sozinhos, por motivo declarado.
##
## Nasce vazia de proposito. Ela existe para o dia em que houver um caso
## legitimo (um script que dependa de um autoload que so existe em runtime, por
## exemplo) -- e para esse caso ficar ESCRITO em vez de virar uma excecao
## silenciosa no laco. Mesmo desenho de `SEM_ICONE_AINDA` e `SEM_ARTE_AINDA`.
const NAO_CARREGAM_SOZINHOS: Array[String] = []


func nome() -> String:
	return "Scripts carregam"


func executar() -> void:
	var achados: Array[String] = []
	for pasta in PASTAS:
		_recolher(pasta, achados)

	# Uma varredura que nao acha nada passaria em silencio, e um portao que nao
	# olha nada e um carimbo. O projeto tem centenas de scripts; se este numero
	# desabar, a varredura quebrou e nao o codigo.
	ok(achados.size() >= 100, "a varredura achou %d script(s) (esperava 100+)" % achados.size())

	var quebrados: Array[String] = []
	for caminho in achados:
		var script: GDScript = load(caminho)
		# `can_instantiate()` e o que de fato separa um script bom de um
		# invalido: o com erro de parse volta um objeto, e nao `null`.
		if script == null or not script.can_instantiate():
			quebrados.append(caminho)

	for caminho in quebrados:
		if NAO_CARREGAM_SOZINHOS.has(caminho):
			continue
		ok(false, "%s NAO carrega (erro de parse?)" % caminho)

	var reais := 0
	for caminho in quebrados:
		if not NAO_CARREGAM_SOZINHOS.has(caminho):
			reais += 1
	igual(reais, 0, "nenhum script do projeto esta quebrado")

	# A lista morde dos DOIS lados, como a de icones: um nome que voltou a
	# carregar tem de SAIR dela, senao a divida vira decoracao.
	for caminho in NAO_CARREGAM_SOZINHOS:
		ok(quebrados.has(caminho),
			"%s esta na lista de excecoes mas carrega: tire-o de la" % caminho)


## Varre recursivamente. `DirAccess` nao lista `.gd` dentro de `.godot/`, que e
## cache e nao codigo -- e as pastas varridas nao o incluem de qualquer jeito.
func _recolher(pasta: String, saida: Array[String]) -> void:
	var dir := DirAccess.open(pasta)
	if dir == null:
		return
	dir.list_dir_begin()
	var nome_arquivo := dir.get_next()
	while nome_arquivo != "":
		if nome_arquivo.begins_with("."):
			nome_arquivo = dir.get_next()
			continue
		var caminho := "%s/%s" % [pasta, nome_arquivo]
		if dir.current_is_dir():
			_recolher(caminho, saida)
		elif nome_arquivo.ends_with(".gd"):
			saida.append(caminho)
		nome_arquivo = dir.get_next()
	dir.list_dir_end()
