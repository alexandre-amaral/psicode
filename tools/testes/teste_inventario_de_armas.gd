extends TesteBase
## As regras dos DOIS SLOTS, cobradas sem instanciar cena nenhuma.
##
## Isso e possivel porque `InventarioDeArmas` e `RefCounted` e nao conhece a
## arvore -- e foi por isso que ele nasceu separado do `player.gd`. Enquanto os
## slots eram dois `var` soltos no Player, cobrar "a terceira arma nao entra
## sozinha" exigia montar o jogador, a sala e um pickup.
##
## O que esta suite guarda, e que nenhum teste de comportamento pegaria:
##
## - **Aquisicao com vaga nao pergunta; sem vaga nao mexe em NADA.** O caso que
##   erra calado e o segundo: um `pedir_aquisicao` que ocupasse o slot antes de
##   devolver `PRECISA_ESCOLHER` faria o jogador perder uma arma toda vez que
##   cancelasse a tela de troca -- e cancelar e justamente a acao que nao pode
##   custar nada.
## - **O pente e do SLOT.** Alternar dez vezes tem de devolver os mesmos dois
##   numeros. Com o pente morando no componente `Arma`, que e UM so, a arma
##   guardada voltava sempre cheia.
## - **A regra antiga MORREU.** "Arma vazia volta para a pistola do slot 0" nao
##   e mais verdade, porque nao ha slot privilegiado. O caso abaixo prova que
##   esvaziar o slot ativo passa a mao para o OUTRO, e nao para o zero.

const MANTIS := "res://src/weapons/smg_mantis.tres"
const RAIL_X := "res://src/weapons/rail_x.tres"
const BOOMER := "res://src/weapons/boomer.tres"
const CIPHER := "res://src/weapons/pistola_cipher.tres"


func nome() -> String:
	return "Inventario de Armas"


func executar() -> void:
	_a_run_comeca_com_uma_arma_e_uma_vaga()
	_a_primeira_arma_diferente_ocupa_a_vaga_e_vira_ativa()
	_a_mesma_arma_nao_ocupa_as_duas_vagas()
	_a_terceira_arma_NAO_MEXE_EM_NADA()
	_substituir_devolve_o_que_saiu_e_poe_o_novo_na_mao()
	_alternar_so_funciona_com_duas()
	_o_pente_e_do_slot_e_sobrevive_a_dez_trocas()
	_esvaziar_passa_a_mao_para_o_outro_slot_e_nao_para_o_zero()
	_limpar_nao_deixa_nada_atravessar_para_a_run_seguinte()
	_o_pente_inicial_de_arma_nova_e_o_do_molde()


func _arma(caminho: String) -> DadosArma:
	return load(caminho) as DadosArma


func _a_run_comeca_com_uma_arma_e_uma_vaga() -> void:
	var inv := InventarioDeArmas.new()
	inv.definir_inicial(_arma(MANTIS))

	igual(inv.quantas(), 1, "a run comeca com UMA arma")
	ok(inv.ativa() != null, "e ela esta na mao")
	igual(inv.indice_ativo(), 0, "no slot 0")
	ok(inv.reserva() == null, "o slot 1 comeca vazio")
	ok(inv.tem_vaga(), "e a vaga esta aberta")


func _a_primeira_arma_diferente_ocupa_a_vaga_e_vira_ativa() -> void:
	var inv := InventarioDeArmas.new()
	inv.definir_inicial(_arma(MANTIS))

	var r := inv.pedir_aquisicao(_arma(RAIL_X))
	igual(r, InventarioDeArmas.Resultado.ACEITA, "a primeira arma diferente entra sozinha")
	igual(inv.quantas(), 2, "as duas vagas ficam ocupadas")
	igual(inv.indice_ativo(), 1, "e ela vira a ATIVA")
	# O feedback instantaneo e a razao de ser desta regra: sem ela o jogador
	# atravessa a sala com a arma nova guardada e nada muda na tela.
	ok(inv.ativa().e_o_mesmo_molde(_arma(RAIL_X)), "a arma na mao e a que ele acabou de pegar")
	ok(inv.reserva().e_o_mesmo_molde(_arma(MANTIS)), "e a inicial foi para o coldre")
	ok(not inv.tem_vaga(), "nao ha mais vaga")


func _a_mesma_arma_nao_ocupa_as_duas_vagas() -> void:
	var inv := InventarioDeArmas.new()
	inv.definir_inicial(_arma(MANTIS))

	var r := inv.pedir_aquisicao(_arma(MANTIS))
	igual(r, InventarioDeArmas.Resultado.RECUSADA, "a arma que ele ja carrega e recusada")
	igual(inv.quantas(), 1, "e a vaga continua aberta")
	# O sintoma que isto evita nao aparece no console: com as duas vagas na mesma
	# arma, alternar deixa de trocar qualquer coisa -- uma tecla que simplesmente
	# parou de fazer efeito.
	ok(inv.tem_vaga(), "senao a tecla de troca deixaria de trocar alguma coisa")


func _a_terceira_arma_NAO_MEXE_EM_NADA() -> void:
	var inv := InventarioDeArmas.new()
	inv.definir_inicial(_arma(MANTIS))
	inv.pedir_aquisicao(_arma(RAIL_X))

	var r := inv.pedir_aquisicao(_arma(BOOMER))
	igual(r, InventarioDeArmas.Resultado.PRECISA_ESCOLHER, "a terceira arma cobra uma escolha")
	# **O caso que erra calado.** Um `pedir_aquisicao` que ocupasse o slot antes
	# de devolver `PRECISA_ESCOLHER` faria o jogador perder uma arma toda vez que
	# cancelasse a tela -- e cancelar e a acao que nao pode custar nada.
	ok(inv.slot(0).e_o_mesmo_molde(_arma(MANTIS)), "e o slot 0 continua intacto")
	ok(inv.slot(1).e_o_mesmo_molde(_arma(RAIL_X)), "e o slot 1 tambem")
	igual(inv.indice_ativo(), 1, "e nem a arma na mao mudou")
	ok(not inv.carrega(_arma(BOOMER)), "a arma nova nao entrou de contrabando")


func _substituir_devolve_o_que_saiu_e_poe_o_novo_na_mao() -> void:
	var inv := InventarioDeArmas.new()
	inv.definir_inicial(_arma(MANTIS))
	inv.pedir_aquisicao(_arma(RAIL_X))

	var saiu := inv.substituir(0, _arma(BOOMER))
	ok(saiu != null, "substituir devolve o que saiu")
	ok(saiu.e_o_mesmo_molde(_arma(MANTIS)), "e o que saiu foi a Mantis")
	# Quem chamou precisa do molde para largar a arma no chao. Devolver `null` ou
	# so um bool faria a arma substituida EVAPORAR, que e o comportamento antigo.
	ok(inv.slot(0).e_o_mesmo_molde(_arma(BOOMER)), "a nova ocupou o slot escolhido")
	ok(inv.slot(1).e_o_mesmo_molde(_arma(RAIL_X)), "e o outro slot nao foi tocado")
	igual(inv.indice_ativo(), 0, "quem substituiu quer usar o que escolheu")


func _alternar_so_funciona_com_duas() -> void:
	var inv := InventarioDeArmas.new()
	inv.definir_inicial(_arma(MANTIS))

	ok(not inv.alternar(), "com uma arma so, alternar recusa")
	igual(inv.indice_ativo(), 0, "e o slot ativo nao se mexe")

	inv.pedir_aquisicao(_arma(RAIL_X))
	ok(inv.alternar(), "com duas, alterna")
	igual(inv.indice_ativo(), 0, "de volta para a Mantis")
	ok(inv.alternar(), "e alterna de novo")
	igual(inv.indice_ativo(), 1, "de volta para a Rail-X")


func _o_pente_e_do_slot_e_sobrevive_a_dez_trocas() -> void:
	var inv := InventarioDeArmas.new()
	inv.definir_inicial(_arma(MANTIS))
	inv.pedir_aquisicao(_arma(RAIL_X))

	# O jogo simulado: cada arma gastou alguns tiros antes da primeira troca.
	inv.slot(0).pente = 12
	inv.slot(1).pente = 3

	for _i in 10:
		inv.alternar()

	igual(inv.slot(0).pente, 12, "a Mantis volta com o pente que ela tinha")
	igual(inv.slot(1).pente, 3, "e a Rail-X tambem")
	# Com o pente morando no componente `Arma` -- que e UM para dois slots --
	# `equipar()` o enchia a cada troca, e a arma guardada voltava sempre cheia.
	# Nao havia erro nenhum: so uma arma que nunca precisava recarregar desde que
	# voce alternasse antes.
	ok(inv.slot(0).pente != _arma(MANTIS).pente(), "e nenhuma das duas voltou cheia")


func _esvaziar_passa_a_mao_para_o_outro_slot_e_nao_para_o_zero() -> void:
	var inv := InventarioDeArmas.new()
	inv.definir_inicial(_arma(MANTIS))
	inv.pedir_aquisicao(_arma(RAIL_X))

	# A arma na mao (slot 1) acabou.
	inv.esvaziar(1)
	ok(inv.slot(1) == null, "o slot esvaziou")
	igual(inv.indice_ativo(), 0, "e o OUTRO slot assumiu")
	# **A regra antiga era "volta para a pistola do slot 0", e ela morreu com a
	# simetria.** O caso ao contrario e o que prova isso: esvaziando o slot 0, a
	# mao vai para o 1 -- se ainda houvesse um slot privilegiado, ela voltaria
	# para o zero vazio e o botao de tiro deixaria de fazer alguma coisa.
	var outro := InventarioDeArmas.new()
	outro.definir_inicial(_arma(MANTIS))
	outro.pedir_aquisicao(_arma(RAIL_X))
	outro.alternar()
	igual(outro.indice_ativo(), 0, "com a mao no slot 0...")
	outro.esvaziar(0)
	igual(outro.indice_ativo(), 1, "...esvazia-lo passa a mao para o slot 1")
	ok(outro.ativa() != null, "e o jogador continua com arma na mao")


func _limpar_nao_deixa_nada_atravessar_para_a_run_seguinte() -> void:
	var inv := InventarioDeArmas.new()
	inv.definir_inicial(_arma(MANTIS))
	inv.pedir_aquisicao(_arma(RAIL_X))
	inv.limpar()

	igual(inv.quantas(), 0, "a run seguinte comeca sem arma nenhuma")
	igual(inv.indice_ativo(), 0, "e com a mao no slot 0")
	ok(inv.ativa() == null, "que esta vazio ate alguem definir a inicial")


func _o_pente_inicial_de_arma_nova_e_o_do_molde() -> void:
	var cipher := _arma(CIPHER)
	var inst := InstanciaDeArma.new(cipher)

	igual(inst.pente, cipher.pente(), "arma nova chega com o pente cheio")
	igual(inst.reserva, -1, "e com a reserva infinita que todas as armas tem hoje")
	# A reserva e guardada mesmo sendo sempre -1: o dia em que a primeira arma de
	# reserva finita nascer, o campo tem de estar no lugar certo em vez de ser
	# descoberto como divida.
	ok(inst.valida(), "e a instancia se reconhece valida")
	ok(InstanciaDeArma.new(null).valida() == false, "e a instancia sem molde nao")
