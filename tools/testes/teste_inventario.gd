extends TesteBase
## O INVENTARIO: as tres abas, e as categorias dormentes dos 16 implantes.
##
## **Categoria corporal e o pior tipo de campo que existe neste projeto: um que
## so a UI le.** Nada em jogo consulta `categoria_corporal` -- ela nao muda dano,
## nao muda spawn e nao entra em conta nenhuma --, entao um `.tres` que a
## esqueca funciona perfeitamente e simplesmente aparece na regiao errada. Nao
## ha erro no console para "este implante esta pendurado no lugar errado do
## corpo": ha um desenho que parece deliberado e nao e.
##
## Por isso o portao morde nos DOIS lados, como `AUTORADAS` faz com as texturas:
##
## 1. **A tabela abaixo lista os 16 por id.** Implante novo que nao entre nela
##    reprova -- ele nao SOME da conta, que e o defeito que
##    `_nenhum_png_fica_fora_de_regime` existiu para consertar.
## 2. **O `.tres` tem de concordar com a tabela.** Mexer num sem mexer no outro
##    reprova, nos dois sentidos.
##
## **E `categoria_corporal` esta DORMENTE, de propriedade declarada.** A primeira
## versao da aba de itens desenhava um corpo com os implantes pendurados por
## regiao; o dono do projeto reprovou a ideia e a aba virou uma grade. O campo
## ficou, e este portao continua cobrando -- pelo mesmo motivo que a suite da
## Diretora continua no runner sem que nenhuma run passe por ela: e justamente
## por nao ser lido em jogo que ele precisa continuar conferido. No dia em que a
## ideia voltar, os dezesseis ja estao escolhidos; sem o portao, eles teriam
## apodrecido em silencio nesse meio-tempo.

const PASTA := "res://src/items/"

## SISTEMA 0, NEURAL 1, SENSORIAL 2, NUCLEO 3, BRACOS 4, MOBILIDADE 5.
##
## As escolhas nao sao arbitrarias e nem todas sao obvias -- o `dissipador` esta
## em NEURAL porque a descricao dele fala da CABECA esquentando, e a Deterioracao
## e mental; a `predatoria` esta em SENSORIAL e nao em NEURAL porque o que ela
## faz e MARCAR um alvo, que e percepcao e nao processamento.
const ESPERADO := {
	"celula_eco": DadosItem.CategoriaCorporal.SISTEMA,
	"nanobots": DadosItem.CategoriaCorporal.SISTEMA,
	"overclock": DadosItem.CategoriaCorporal.NEURAL,
	"firewall": DadosItem.CategoriaCorporal.NEURAL,
	"daemon": DadosItem.CategoriaCorporal.NEURAL,
	"dissipador": DadosItem.CategoriaCorporal.NEURAL,
	"predatoria": DadosItem.CategoriaCorporal.SENSORIAL,
	"nucleo": DadosItem.CategoriaCorporal.NUCLEO,
	"vampirico": DadosItem.CategoriaCorporal.NUCLEO,
	"sobrecarga": DadosItem.CategoriaCorporal.NUCLEO,
	"gatilho": DadosItem.CategoriaCorporal.BRACOS,
	"municao_inteligente": DadosItem.CategoriaCorporal.BRACOS,
	"penetrador": DadosItem.CategoriaCorporal.BRACOS,
	"fragmentador": DadosItem.CategoriaCorporal.BRACOS,
	"reflexo": DadosItem.CategoriaCorporal.MOBILIDADE,
	"servo": DadosItem.CategoriaCorporal.MOBILIDADE,
}


func nome() -> String:
	return "Inventario"


func executar() -> void:
	_todo_implante_esta_na_tabela_e_concorda_com_ela()
	_o_valor_zero_do_enum_e_o_NEUTRO()
	_toda_regiao_do_enum_e_alcancada_por_algum_implante()
	_a_tela_tem_uma_aba_por_pergunta()
	_a_grade_de_itens_CONTA_o_repetido_em_vez_de_repetir()
	_o_diagnostico_deriva_de_Modificadores_e_nao_recalcula()
	_os_implantes_continuam_ACUMULATIVOS()


func _ids_em_disco() -> Array[String]:
	var ids: Array[String] = []
	var dir := DirAccess.open(PASTA)
	if dir == null:
		return ids
	for arquivo in dir.get_files():
		if arquivo.begins_with("implante_") and arquivo.ends_with(".tres"):
			ids.append(arquivo.trim_prefix("implante_").trim_suffix(".tres"))
	ids.sort()
	return ids


func _todo_implante_esta_na_tabela_e_concorda_com_ela() -> void:
	var ids := _ids_em_disco()
	igual(ids.size(), ESPERADO.size(), "os implantes em disco e a tabela tem o mesmo tamanho")

	for ident in ids:
		# O lado que impede o campo de apodrecer: implante novo REPROVA ate
		# alguem escolher a regiao dele. Sem isto ele nasceria em SISTEMA por
		# default e ninguem saberia que a escolha nao foi feita.
		if not ESPERADO.has(ident):
			ok(false, "o implante '%s' nao esta na tabela de categorias" % ident)
			continue
		var dados: DadosItem = load("%simplante_%s.tres" % [PASTA, ident])
		if dados == null:
			ok(false, "o implante '%s' nao carregou" % ident)
			continue
		igual(dados.categoria_corporal, ESPERADO[ident],
			"'%s' esta na regiao que a tabela declara" % ident)

	for ident: String in ESPERADO.keys():
		ok(ids.has(ident), "'%s' da tabela ainda existe em disco" % ident)


func _o_valor_zero_do_enum_e_o_NEUTRO() -> void:
	# Um implante criado no editor sem tocar no campo cai no valor 0. Se ele
	# fosse NEURAL, toda peca esquecida AFIRMARIA uma regiao que ninguem
	# escolheu -- e afirmar errado e pior que nao afirmar.
	igual(DadosItem.CategoriaCorporal.SISTEMA, 0,
		"o default do enum e SISTEMA, que e o neutro")
	var cru := DadosItem.new()
	igual(cru.categoria_corporal, DadosItem.CategoriaCorporal.SISTEMA,
		"e um DadosItem novo nasce nele")


func _toda_regiao_do_enum_e_alcancada_por_algum_implante() -> void:
	var vistos := {}
	for ident: String in ESPERADO.keys():
		vistos[ESPERADO[ident]] = true
	for regiao: int in DadosItem.CategoriaCorporal.values():
		# Regiao sem nenhum implante seria um ponto do corpo que diz "SEM
		# MODIFICACAO" em 100% das runs -- espaco gasto para nunca dizer nada.
		# Nao e erro fatal de design, mas tem de ser uma DECISAO: se um dia
		# valer a pena, tire a regiao do enum em vez de deixa-la orfa.
		ok(vistos.has(regiao), "a regiao %d tem ao menos um implante" % regiao)


## As tres abas sao tres PERGUNTAS com regras diferentes, e nao arrumacao.
##
## Este caso e o que impede alguem de "simplificar" juntando duas delas: ITENS
## nao tem teto (os aprimoramentos sao acumulativos), ARMAMENTO tem exatamente
## dois, e STATUS e derivado dos outros dois. Fundidas, o jogador teria de
## descobrir sozinho qual das regras vale para o que acabou de pegar.
func _a_tela_tem_uma_aba_por_pergunta() -> void:
	var cena: PackedScene = load("res://src/ui/tela_inventario.tscn")
	ok(cena != null, "a cena do inventario carrega")
	if cena == null:
		return
	var tela := cena.instantiate()
	Engine.get_main_loop().root.add_child(tela)

	igual(TelaInventarioAbas().size(), 3, "sao tres abas")
	for caminho in TelaInventarioAbas():
		ok(tela.get_node_or_null(caminho) != null, "a aba %s existe na cena" % caminho)
	for caminho in TelaInventarioBotoes():
		ok(tela.get_node_or_null(caminho) != null, "o botao %s existe na cena" % caminho)

	# So UMA aba visivel por vez. Duas visiveis desenhariam uma sobre a outra no
	# mesmo retangulo -- e o sintoma seria texto sobreposto, sem erro nenhum.
	var visiveis := 0
	for caminho in TelaInventarioAbas():
		if (tela.get_node(caminho) as Control).visible:
			visiveis += 1
	igual(visiveis, 1, "e so uma esta visivel de cada vez")

	tela.mostrar_aba(2)
	ok((tela.get_node("Painel/Conteudo/Status") as Control).visible,
		"trocar de aba mostra a pedida")
	ok(not (tela.get_node("Painel/Conteudo/Itens") as Control).visible,
		"e esconde a anterior")

	tela.free()


func TelaInventarioAbas() -> Array[String]:
	return [
		"Painel/Conteudo/Itens",
		"Painel/Conteudo/Armamento",
		"Painel/Conteudo/Status",
	]


func TelaInventarioBotoes() -> Array[String]:
	return ["Painel/Abas/BtnItens", "Painel/Abas/BtnArmamento", "Painel/Abas/BtnStatus"]


## Dois nanobots sao UMA celula com "2", e nao duas celulas.
##
## Desenhando a lista crua, a grade cresceria com o numero de COLETAS -- que nao
## tem teto -- em vez de com o de implantes distintos, que tem teto de 16 e cabe
## na aba. Mesma regra da bandeja da HUD.
func _a_grade_de_itens_CONTA_o_repetido_em_vez_de_repetir() -> void:
	Modificadores.resetar()
	var aba := AbaDeItens.new()
	Engine.get_main_loop().root.add_child(aba)

	aba.recolher()
	igual(aba.distintos(), 0, "sem implante nenhum a grade esta vazia")

	var nanobots: DadosItem = load("res://src/items/implante_nanobots.tres")
	var servo: DadosItem = load("res://src/items/implante_servo.tres")
	Modificadores.aplicar(nanobots)
	Modificadores.aplicar(nanobots)
	Modificadores.aplicar(servo)
	aba.recolher()
	igual(Modificadores.itens_ativos().size(), 3, "tres coletas entraram")
	igual(aba.distintos(), 2, "mas a grade mostra DUAS celulas")

	# A grade tambem nao pode estourar a largura: `colunas()` e calculado a
	# partir do tamanho real, e nao cravado.
	aba.size = Vector2(400.0, 300.0)
	var por_linha := aba.colunas()
	ok(por_linha >= 1, "sempre cabe ao menos uma coluna")
	ok(aba.caixa_da_celula(por_linha - 1).end.x <= aba.size.x + 1.0,
		"e a ultima coluna da linha nao passa da borda")

	aba.free()
	Modificadores.resetar()


func _o_diagnostico_deriva_de_Modificadores_e_nao_recalcula() -> void:
	Modificadores.resetar()
	var limpo := AbaDeStatus.linhas_de_diagnostico(Vector2i(4, 6))
	var antes := _valor_da_linha(limpo, "MOVIMENTO")
	igual(antes, "--", "sem implante nenhum, o movimento nao mostra multiplicador")

	var servo: DadosItem = load("res://src/items/implante_servo.tres")
	ok(Modificadores.aplicar(servo), "o Servo-Motor entra")
	var depois := AbaDeStatus.linhas_de_diagnostico(Vector2i(4, 6))
	var texto := _valor_da_linha(depois, "MOVIMENTO")
	ok(texto != "--", "e o painel passa a mostrar o multiplicador (%s)" % texto)
	# **A prova de que ele DERIVA.** O texto tem de bater com o que o autoload
	# responde no mesmo instante -- uma UI que recalculasse o efeito dos
	# implantes viraria a segunda fonte de verdade sobre a build, e diria +12%
	# onde o tiro entrega +10%.
	igual(texto, "x%.2f" % Modificadores.multiplicador_velocidade(),
		"e o numero e exatamente o que Modificadores responde")

	# INTEGRIDADE tambem nao e inventada: ela vem da vida passada por quem monta.
	igual(_valor_da_linha(depois, "INTEGRIDADE"), "4 / 6", "a integridade vem do Player")
	Modificadores.resetar()


func _valor_da_linha(linhas: Array, rotulo: String) -> String:
	for linha in linhas:
		if str(linha[0]) == rotulo:
			return str(linha[1])
	return ""


func _os_implantes_continuam_ACUMULATIVOS() -> void:
	Modificadores.resetar()
	var overclock: DadosItem = load("res://src/items/implante_overclock.tres")
	var firewall: DadosItem = load("res://src/items/implante_firewall.tres")
	var daemon: DadosItem = load("res://src/items/implante_daemon.tres")

	# Os tres sao NEURAL. **A regiao nao tem vaga**, e este caso e o que impede
	# alguem de transformar o corpo em equipamento por localizacao sem perceber:
	# no dia em que uma regiao passar a recusar, esta asercao cai.
	ok(Modificadores.aplicar(overclock), "o primeiro NEURAL entra")
	ok(Modificadores.aplicar(firewall), "o segundo NEURAL tambem")
	ok(Modificadores.aplicar(daemon), "e o terceiro")
	igual(Modificadores.itens_ativos().size(), 3, "os tres continuam instalados")
	Modificadores.resetar()
