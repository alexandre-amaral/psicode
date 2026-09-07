class_name OfertaDeLoja
extends RefCounted
## Uma das tres vagas da Loja: o que esta a venda, por quanto, e se ja foi.
##
## **Ela nao guarda no nenhum**, e isso e regra e nao estilo. A sala e montada e
## desmontada conforme o jogador entra e sai; uma oferta que apontasse para o
## pedestal dela perderia o estado junto com a cena, e o jogador voltaria a uma
## Loja com o estoque reposto. O que ela guarda e o RECURSO do conteudo, que vive
## em disco e nao depende de arvore.
##
## O `id` e o `resource_path` e nao o nome: dois implantes podem ganhar o mesmo
## nome de exibicao num dia de tuning, e o caminho e unico por construcao.

## O que a vaga vende.
enum Tipo { ARMA, ITEM }

var tipo: Tipo = Tipo.ARMA
var conteudo: Resource = null
var preco: int = 0
var vendida: bool = false
var slot: int = 0


func id() -> String:
	return conteudo.resource_path if conteudo != null else ""


func nome() -> String:
	if conteudo == null:
		return "?"
	# `nome` e o campo que `DadosArma` e `DadosItem` compartilham, e o unico: os
	# dois nao tem base comum, entao perguntar pela propriedade e mais honesto do
	# que fingir uma interface que nao existe.
	var texto: Variant = conteudo.get("nome")
	return str(texto) if texto != null else "?"


func valida() -> bool:
	return conteudo != null and preco > 0
