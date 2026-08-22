class_name TesteBase
extends RefCounted
## Base minima de suite de teste.
##
## Deliberadamente pequena: o projeto nao usa framework de teste (GUT e afins)
## e nao precisa de um. O que uma suite precisa e comparar valores e explicar o
## que deu errado -- isso cabe em quatro helpers.
##
## Regra dos helpers: a mensagem de falha diz o valor ESPERADO e o OBTIDO. Um
## "[FALHA] multiplicador de velocidade" nao ajuda ninguem; um "esperava 1.55,
## obtive 1.0" aponta o bug direto.

var total: int = 0
var falhas: Array[String] = []

var _linhas: Array[String] = []


## Nome exibido no relatorio. Sobrescreva na suite.
func nome() -> String:
	return "suite sem nome"


## Ponto de entrada. Sobrescreva na suite com as verificacoes.
func executar() -> void:
	pass


func relatorio() -> Array[String]:
	return _linhas


func ok(condicao: bool, descricao: String) -> void:
	total += 1
	if condicao:
		_linhas.append("[ok]    %s" % descricao)
	else:
		_linhas.append("[FALHA] %s" % descricao)
		falhas.append(descricao)


func igual(obtido: Variant, esperado: Variant, descricao: String) -> void:
	ok(obtido == esperado, "%s (esperava %s, obtive %s)" % [descricao, esperado, obtido])


## Comparacao de float com tolerancia. Comparar float com == e a forma mais
## rapida de escrever um teste que falha sozinho depois de qualquer refatoracao
## inofensiva -- lerpf e sqrt nao devolvem o decimal exato que voce escreveu.
func perto(obtido: float, esperado: float, descricao: String, tolerancia: float = 0.0001) -> void:
	var diferenca := absf(obtido - esperado)
	ok(diferenca <= tolerancia, "%s (esperava %.4f +/- %.4f, obtive %.4f)" % [
		descricao, esperado, tolerancia, obtido,
	])


func entre(obtido: float, minimo: float, maximo: float, descricao: String) -> void:
	ok(obtido >= minimo and obtido <= maximo, "%s (esperava entre %.4f e %.4f, obtive %.4f)" % [
		descricao, minimo, maximo, obtido,
	])
