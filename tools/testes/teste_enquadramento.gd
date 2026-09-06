extends TesteBase
## OS DOIS REGIMES DE SALA: ou ela cabe no quadro, ou ela e claramente aberta.
##
## A sala nao lia como cavidade porque a PAREDE quase nunca aparecia. Medido, com
## a camera real do jogo: seis das nove cenas tem EXATAMENTE o tamanho da
## viewport (960x544), entao a camera desliza so 64x68 px e o jogador ve parede
## de **7% do espaco** -- ele passa o combate olhando para uma tela 100% de chao.
##
## O patologico nao e "sala grande". A `sala_3_grande` mostra parede de 38% e 40%
## e funciona como as salas grandes do Isaac: o jogador nao ve tudo de uma vez,
## mas andar traz parede ao quadro o tempo todo. O patologico e o MEIO TERMO --
## grande demais para caber, pequena demais para se atravessar.
##
## Por isso a regra tem duas saidas e proibe o meio:
##
##     folga = contorno + margens - viewport         (por EIXO)
##
##     FECHADO   folga <= 0                  a parede daquele eixo esta SEMPRE em quadro
##     ABERTO    folga >= viewport / 2       a camera anda meia tela antes de encostar
##     PROIBIDO  qualquer coisa entre os dois
##
## **Por EIXO e nao por sala**, e isso e decisao. Uma sala fechada em x e aberta
## em y e um CORREDOR, com as paredes laterais permanentemente em quadro enquanto
## o jogador percorre a vertical. E a melhor forma que existe para mostrar
## parede, e barra-la seria barrar a forma certa por amor a um binario.
##
## O corte nao e palpite, e ele JA SE MOVEU UMA VEZ -- que era a condicao escrita
## aqui desde o inicio: *"se um dia uma sala cair no meio e a captura convencer,
## o corte se move COM a captura anexada"*. A captura chegou.
##
## Ele nascia em meia tela, calibrado na `sala_3_grande`. O dono entao apontou a
## parede norte do **Lobby** como precisamente o que ele quer, e o Lobby cai no
## meio termo por aquele corte: 1024x640, folga **272 x 304**, e 272 e menos que
## os 480 de meia tela em x. Ou o Lobby estava errado, ou o corte estava -- e
## quem foi olhado e aprovado foi o Lobby.
##
## O corte novo e **um terco do eixo** (320 x 181), e ele nao foi escolhido: ele e
## o unico intervalo que separa o que precisa ser separado. Em Y, que e o eixo
## apertado, ha exatamente dois numeros de cada lado:
##
##   REPROVAR   68   as seis salas do defeito original (960x544, perfil C)
##   REPROVAR  136   uma sala da altura da tela com o perfil de hoje
##   ------------------------------------------------------ o corte cai aqui
##   PASSAR    232   as cinco salas de hoje, na altura do Lobby
##   PASSAR    328   a do chefe
##   PASSAR    392   a `sala_3_grande`, que sempre funcionou
##
## Meia tela (272) reprovava as cinco de 232 junto com o defeito; um quarto (136)
## aprovava a sala do tamanho da tela junto com as boas. Um terco e o meio do vao
## real, com folga para os dois lados -- e continua sendo uma afirmacao
## falsificavel: mover qualquer sala para 200 px de folga reprova.
##
## E o padrao do `MedidorEscape`: a regua tem os dois lados, e mover o limiar
## exige evidencia e nao gosto. A evidencia do REGIME e
## `user://capturas/norte_lobby.png`, que `tools/comparar_norte.tscn` regenera.
##
## **O que o Lobby ensina alem do numero**: fechar a sala em Y nao e o ideal, e
## tambem quase nao e possivel. As margens verticais somam 136, entao um eixo Y
## FECHADO exigiria um contorno de no maximo 408 px -- e 408 nao cai na grade de
## 32. O multiplo abaixo, 384, produz um clamp de 520 px contra uma tela de 544,
## e ai quem resolve e `GerenciadorMapa._cabendo_a_tela()`, mostrando 12 px de
## vazio em cima e embaixo. Funciona, mas e uma sala esmagada para caber num
## numero -- 384 px de altura util contra os 640 do Lobby.
##
## Por isso as cinco salas foram para 896x640: X FECHADO, com as duas laterais
## permanentemente em quadro, e Y ABERTO na altura do Lobby, com a parede norte
## entrando quando o jogador sobe. E de quebra a area volta a 573k px2 -- acima
## dos 522k de antes de tudo isto --, entao o orcamento de inimigos nao precisa de
## sessao de tuning para reagir a uma sala menor.
##
## **Folga NEGATIVA continua sendo FECHADO, e nao um erro.** Uma sala mais estreita
## que a tela (o corredor, 768 px) recebe o vazio simetrico dos dois lados por
## `_cabendo_a_tela()`, e a parede daquele eixo fica sempre inteira em quadro --
## que e o que FECHADO afirma. Quem cobra aquele crescimento e
## `teste_camera.gd:_o_clamp_nunca_e_menor_que_o_quadro`, junto do resto da camera.


const CENAS := "res://src/mapa/"

## As salas ainda NAO migradas, declaradas.
##
## Mesmo desenho do `SEM_ARTE_AINDA` do portao de origem: tirar um nome daqui e o
## interruptor de "esta sala foi migrada". A lista **so encolhe**, todo nome nela
## tem de existir em disco, e toda sala FORA dela tem de passar.
##
## Sem ela o portao entraria vermelho e seria desligado antes de servir para
## alguma coisa. Com ela ele entra verde e ja morde qualquer sala NOVA.
const PENDENTES: Array[String] = [
]


func nome() -> String:
	return "Enquadramento da sala"


func executar() -> void:
	_toda_sala_esta_num_regime_declarado()
	_a_lista_de_pendentes_nao_mente()
	_a_moldura_ocupa_o_quadro_em_QUALQUER_posicao()
	_os_dois_regimes_existem_de_verdade()
	_uma_folga_no_MEIO_TERMO_REPROVA()


## Toda sala fora da lista de pendentes esta num regime declarado, nos dois eixos.
func _toda_sala_esta_num_regime_declarado() -> void:
	var conferidas := 0
	for nome_cena in _cenas():
		if PENDENTES.has(nome_cena):
			continue
		var sala := _nascer(nome_cena)
		if sala == null:
			continue
		conferidas += 1
		var f := _folga(sala)
		for eixo in [0, 1]:
			var rotulo := "x" if eixo == 0 else "y"
			var valor: float = f.x if eixo == 0 else f.y
			ok(
				_regime(valor, eixo) != "PROIBIDO",
				"%s eixo %s: regime %s (folga %.0f px)"
					% [nome_cena, rotulo, _regime(valor, eixo), valor]
			)
		sala.free()
	ok(conferidas > 0, "houve sala migrada para conferir (%d)" % conferidas)


## Quanto do quadro e MOLDURA, com o jogador em cada canto do clamp.
##
## O regime responde "a parede aparece?"; este responde "aparece QUANTO, e em
## qualquer lugar?". Sao perguntas diferentes e a segunda pegou o que a primeira
## deixou passar.
##
## Medido com `tools/medir_moldura.tscn` quando o dono disse que a textura da
## parede tinha mudado mas o ASPECTO nao:
##
##     sala_1, jogador ao NORTE     moldura 22,8% do quadro
##     sala_1, jogador a LESTE      moldura  6,1% do quadro
##
## O regime aprovava as duas -- o eixo X estava FECHADO, a parede ESTAVA em
## quadro. Ela so era fina demais para ler como parede. Um portao que so pergunta
## "aparece?" nunca ia acusar isso.
##
## O PISO de 15% nao e escolhido: e o meio do vao entre os dois numeros medidos.
## Acima dele estao as posicoes que o dono aprovou; abaixo, a lateral fina que ele
## recusou. Hoje o pior canto de qualquer sala mede 18,1%, e a `sala_3_grande` --
## que sempre funcionou -- mede 9,0% a leste e por isso e a excecao DECLARADA:
## ela e a unica ABERTA nos dois eixos, e numa sala grande a parede ser rara
## quando se esta no meio dela e o desenho, nao o defeito.
const PISO_DA_MOLDURA := 0.15

## As salas cujo pior canto fica abaixo do piso, declaradas.
##
## Mesma disciplina das outras listas: nome nela tem de existir em disco E
## continuar abaixo do piso; nome fora dela tem de passar.
const MOLDURA_MAGRA_ACEITA: Array[String] = [
	"sala_3_grande",
]


func _a_moldura_ocupa_o_quadro_em_QUALQUER_posicao() -> void:
	var tela := _viewport()
	var area_do_quadro := tela.x * tela.y
	for nome_cena in _cenas():
		var sala := _nascer(nome_cena)
		if sala == null:
			continue
		var limites := sala.obter_limites()
		var m := sala.perfil_de_parede()
		var margens: Vector4 = m.margens() if m != null else PerfilDeParede.new().margens()
		var clamp_ := limites.grow_individual(margens.x, margens.y, margens.z, margens.w)

		# Os quatro cantos do clamp mais o centro: e nos cantos que a camera para,
		# e e no centro que ela mostra menos parede.
		var meia := tela * 0.5
		var cantos := {
			"centro": clamp_.get_center(),
			"noroeste": clamp_.position + meia,
			"nordeste": Vector2(clamp_.end.x - meia.x, clamp_.position.y + meia.y),
			"sudoeste": Vector2(clamp_.position.x + meia.x, clamp_.end.y - meia.y),
			"sudeste": clamp_.end - meia,
		}
		var pior := 1.0
		var onde := ""
		for rotulo: String in cantos:
			var quadro := Rect2(cantos[rotulo] - meia, tela)
			var chao := quadro.intersection(limites)
			var fracao := 1.0 - (chao.size.x * chao.size.y) / area_do_quadro
			if fracao < pior:
				pior = fracao
				onde = rotulo

		if MOLDURA_MAGRA_ACEITA.has(nome_cena):
			ok(
				pior < PISO_DA_MOLDURA,
				"%s esta declarada magra e continua magra (%.1f%% no %s)"
					% [nome_cena, pior * 100.0, onde]
			)
		else:
			ok(
				pior >= PISO_DA_MOLDURA,
				"%s mostra moldura em todo canto (pior %.1f%% no %s, piso %.0f%%)"
					% [nome_cena, pior * 100.0, onde, PISO_DA_MOLDURA * 100.0]
			)
		sala.free()

	for magra in MOLDURA_MAGRA_ACEITA:
		ok(_cenas().has(magra), "%s, declarada magra, existe em disco" % magra)


## A lista morde dos DOIS lados.
##
## Nome nela que nao existe em disco e isencao herdada por engano -- uma sala
## renomeada levaria a isencao da antiga junto. E nome nela que JA passa e uma
## linha que ficou para tras: ela tem de sair, senao a lista deixa de dizer o que
## falta e passa a ser decoracao.
func _a_lista_de_pendentes_nao_mente() -> void:
	var no_disco := _cenas()
	for pendente in PENDENTES:
		ok(no_disco.has(pendente), "%s, listada como pendente, existe em disco" % pendente)

	var ja_passam: Array[String] = []
	for pendente in PENDENTES:
		var sala := _nascer(pendente)
		if sala == null:
			continue
		var f := _folga(sala)
		if _regime(f.x, 0) != "PROIBIDO" and _regime(f.y, 1) != "PROIBIDO":
			ja_passam.append(pendente)
		sala.free()
	igual(
		ja_passam.size(), 0,
		"nenhuma pendente ja passa -- essas sairiam da lista (%s)" % [ja_passam]
	)


## Os dois regimes existem no jogo de verdade.
##
## Sem isto o portao aprovaria um andar em que TODA sala e aberta, ou todo
## fechada, sem nunca ter olhado o outro lado -- e a regra de dois regimes viraria
## uma regra de um.
func _os_dois_regimes_existem_de_verdade() -> void:
	var fechados := 0
	var abertos := 0
	for nome_cena in _cenas():
		var sala := _nascer(nome_cena)
		if sala == null:
			continue
		var f := _folga(sala)
		for eixo in [0, 1]:
			var valor: float = f.x if eixo == 0 else f.y
			match _regime(valor, eixo):
				"FECHADO": fechados += 1
				"ABERTO": abertos += 1
		sala.free()
	ok(fechados > 0, "ha eixo FECHADO no jogo (%d)" % fechados)
	ok(abertos > 0, "e ha eixo ABERTO (%d)" % abertos)


## E o lado que morde: uma folga NO MEIO reprova.
##
## Ele ja montou "uma sala do tamanho exato da tela", que era o defeito original.
## Isso parou de servir quando a parede engordou: com margens de 96 e 104, um
## contorno de 960x544 recebe folga 192x208, e 208 esta ACIMA do corte -- ou seja,
## aquela sala deixou de ser patologica, porque a parede agora aparece nela.
##
## Um caso que afirma "este tamanho reprova" envelhece junto com o perfil. Este
## afirma a REGRA: uma folga no meio termo reprova, seja de que sala for. E ele
## guarda o numero historico ao lado, para a regra continuar ligada ao defeito
## que a gerou -- as seis salas de 960x544 no perfil C mediam folga 64 x 68, e
## continuam reprovando hoje.
func _uma_folga_no_MEIO_TERMO_REPROVA() -> void:
	var tela := _viewport()
	for eixo in [0, 1]:
		var rotulo := "x" if eixo == 0 else "y"
		var corte: float = (tela.x if eixo == 0 else tela.y) * FRACAO_ABERTA
		igual(
			_regime(corte * 0.5, eixo), "PROIBIDO",
			"eixo %s: metade do corte cai no meio termo (folga %.0f)" % [rotulo, corte * 0.5]
		)
		igual(
			_regime(corte - 1.0, eixo), "PROIBIDO",
			"eixo %s: um pixel abaixo do corte ainda reprova (folga %.0f)" % [rotulo, corte - 1.0]
		)
		igual(
			_regime(corte, eixo), "ABERTO",
			"eixo %s: no corte, ja passa (folga %.0f)" % [rotulo, corte]
		)
	# O defeito ORIGINAL, com os numeros que o mediram: seis salas de 960x544 no
	# perfil C, folga 64 x 68. Se um dia o corte descer abaixo disso, ele volta a
	# aprovar o quadro 100% de chao que abriu este epico.
	igual(_regime(64.0, 0), "PROIBIDO", "a folga historica de 64 px em x reprova")
	igual(_regime(68.0, 1), "PROIBIDO", "e a de 68 px em y tambem")
	# E os dois extremos continuam validos, senao a regra so sabe reprovar.
	igual(_regime(-1.0, 0), "FECHADO", "folga negativa e FECHADO")
	igual(_regime(tela.x, 0), "ABERTO", "folga de uma tela inteira e ABERTO")


# -- helpers ----------------------------------------------------------------


## Quanto do eixo a camera precisa percorrer para o eixo contar como ABERTO.
##
## Um terco. A tabela que produz esse numero esta no cabecalho.
const FRACAO_ABERTA := 1.0 / 3.0


## O regime de UM eixo. O corte esta explicado no cabecalho.
func _regime(folga: float, eixo: int) -> String:
	if folga <= 0.0:
		return "FECHADO"
	var tela := _viewport()
	var corte: float = (tela.x if eixo == 0 else tela.y) * FRACAO_ABERTA
	return "ABERTO" if folga >= corte else "PROIBIDO"


## `contorno + margens - viewport`, por eixo.
##
## As margens saem do perfil DAQUELA sala, nunca de um literal: se o teto de
## tamanho aparecesse escrito em dois lugares, o dia em que o perfil mudasse um
## deles ficaria para tras em silencio. E a armadilha do "numero que foi para o
## `.tres` tem de SAIR do `.tscn`", aplicada a geometria.
func _folga(sala: Sala) -> Vector2:
	var limites := sala.obter_limites()
	var m := sala.perfil_de_parede()
	var margens: Vector4 = m.margens() if m != null else PerfilDeParede.new().margens()
	var tela := _viewport()
	return Vector2(
		limites.size.x + margens.x + margens.z - tela.x,
		limites.size.y + margens.y + margens.w - tela.y
	)


func _viewport() -> Vector2:
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 960)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 544))
	)


## As cenas de sala em DISCO. Lista fixa apodrece nas duas direcoes.
func _cenas() -> Array[String]:
	var fora: Array[String] = []
	var pasta := DirAccess.open(CENAS)
	if pasta == null:
		return fora
	var arquivos := pasta.get_files()
	arquivos.sort()
	for arquivo in arquivos:
		if arquivo.begins_with("sala_") and arquivo.ends_with(".tscn"):
			fora.append(arquivo.get_basename())
	return fora


func _nascer(nome_cena: String) -> Sala:
	var cena := load(CENAS + nome_cena + ".tscn") as PackedScene
	if cena == null:
		ok(false, "%s carrega" % nome_cena)
		return null
	var sala := cena.instantiate() as Sala
	Engine.get_main_loop().root.add_child(sala)
	return sala
