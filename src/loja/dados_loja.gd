class_name DadosLoja
extends Resource
## As regras da Loja: quantas vagas, o que cabe em cada uma, e de onde vem.
##
## Ela nao lista conteudo. **Uma `ListaDeArmasDaLoja` duplicando o `pool_padrao`
## e o defeito que esta issue existe para evitar**: duas listas divergem, e o
## sintoma e uma arma nova aparecendo no loot e nunca na Loja -- sem erro nenhum,
## e so meses depois, quando alguem reparar.
##
## O que ela declara e a REGRA. O conteudo sai da pool real que o andar ja usa.

## O que uma vaga aceita.
##
## Valor novo entra sempre NO FIM: enum e gravado como INT no `.tres`, e inserir
## no meio reescreve em silencio o significado de toda loja ja salva.
enum Vaga { ARMA, ITEM, QUALQUER }

@export var id: StringName = &""

## O que cada vaga aceita, na ordem.
##
## **`ARMA, ITEM, QUALQUER` e o desenho, e nao tres sorteios livres.** Com tres
## vagas livres, uma loja pode sair com tres implantes de dano quase iguais --
## tres opcoes que sao a mesma escolha. Garantir uma arma e um item da variedade
## sem tirar a aleatoriedade: a terceira continua sendo surpresa.
@export var vagas: Array[Vaga] = [Vaga.ARMA, Vaga.ITEM, Vaga.QUALQUER]

## Duas vagas com o mesmo conteudo sao uma vaga so com dois precos.
@export var permite_duplicata: bool = false

## Ainda nao existe. O campo entra agora porque a arquitetura precisa aceita-lo,
## e um campo lido pelo codigo e o unico tipo de campo que nao mente depois.
@export var reroll_habilitado: bool = false
@export var custo_do_reroll: int = 0


func quantidade_de_vagas() -> int:
	return vagas.size()
