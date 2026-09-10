class_name InstanciaDeArma
extends RefCounted
## Uma arma CARREGADA pelo jogador, com o estado que e dela e nao do `.tres`.
##
## A decisao de design que ela carrega: **o `DadosArma` e o molde, e o molde nao
## se lembra de nada.** Duas Rail-X no mundo apontam para o mesmo `.tres`; o que
## as separa e quantas balas cada uma tem no pente agora. Antes de existir esta
## classe o Player guardava `Array[DadosArma]`, entao o pente morava no
## componente `Arma` -- que e UM so -- e a troca de arma o zerava: sair da Mantis
## com 3/32 e voltar meio minuto depois devolvia 32/32, de graca.
##
## **Ela guarda o PENTE e nao a reserva, e isso e uma medicao.** As 21 armas do
## jogo tem `municao_maxima = -1`, ou seja reserva infinita -- nenhuma acaba, e
## `ficou_sem_municao` nunca disparou. O unico numero que a troca de arma pode
## perder e o pente. O campo de reserva existe mesmo assim, porque o dia em que
## a primeira arma de reserva finita nascer ele tem de estar no lugar certo, e
## nao ser descoberto como divida.
##
## `RefCounted` e nao `Node`, pelo mesmo motivo de `PerfilJogador`: isto e estado
## puro, sem desenho e sem fisica, e uma suite tem de conseguir monta-lo sem
## arvore.

## O molde. Nunca escrito -- quem escreve num `.tres` de arma reescreve a arma
## para todo mundo que a carregar, inclusive a proxima run.
var dados: DadosArma = null

## Balas no pente AGORA. Nasce cheio.
var pente: int = 0

## Reserva. -1 = infinita, que e o valor de todas as armas de hoje.
var reserva: int = -1


func _init(molde: DadosArma = null) -> void:
	if molde == null:
		return
	dados = molde
	pente = molde.pente()
	reserva = -1 if molde.municao_infinita() else molde.municao_maxima


## O `.tres` que esta arma instancia. Usado para comparar duas instancias sem
## expor o campo -- duas instancias do MESMO molde sao "a mesma arma" para a
## regra de aquisicao, e diferentes para o pente.
func e_o_mesmo_molde(outro: DadosArma) -> bool:
	return outro != null and dados == outro


func nome() -> String:
	return dados.nome if dados != null else ""


func valida() -> bool:
	return dados != null
