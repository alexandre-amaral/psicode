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
## O corte de meia tela nao e palpite: ele foi calibrado no unico exemplo
## aprovado. A `sala_3_grande` fica acima dele nos dois eixos, com folga
## confortavel e nao absurda -- ou seja, a regra afirma algo cobravel, *"ela e a
## menor sala aberta aceitavel"*, e isso e falsificavel. Se um dia uma sala cair
## no meio e a captura convencer, o corte se move COM a captura anexada. E o
## padrao do `MedidorEscape`: a regua tem os dois lados, e mover o limiar exige
## evidencia e nao gosto.


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
	"sala_1_retangular",
	"sala_6_boss",
]


func nome() -> String:
	return "Enquadramento da sala"


func executar() -> void:
	_toda_sala_esta_num_regime_declarado()
	_a_lista_de_pendentes_nao_mente()
	_os_dois_regimes_existem_de_verdade()
	_uma_sala_do_tamanho_da_tela_REPROVA()


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


## E o lado que morde: a sala do tamanho da tela REPROVA.
##
## Regua que nao reprova nada e um carimbo. Este caso monta o defeito exato que a
## regra existe para barrar -- 960x544, o tamanho de seis cenas de hoje -- e exige
## que ele caia em PROIBIDO nos dois eixos.
func _uma_sala_do_tamanho_da_tela_REPROVA() -> void:
	var tela := _viewport()
	var m := PerfilDeParede.new().margens()
	var folga_x := tela.x + m.x + m.z - tela.x
	var folga_y := tela.y + m.y + m.w - tela.y
	igual(
		_regime(folga_x, 0), "PROIBIDO",
		"uma sala da largura da tela cai no meio termo (folga %.0f)" % folga_x
	)
	igual(
		_regime(folga_y, 1), "PROIBIDO",
		"e a altura tambem (folga %.0f)" % folga_y
	)
	# E o outro extremo continua valido, senao a regra so sabe reprovar.
	igual(_regime(-1.0, 0), "FECHADO", "folga negativa e FECHADO")
	igual(_regime(tela.x, 0), "ABERTO", "folga de uma tela inteira e ABERTO")


# -- helpers ----------------------------------------------------------------


## O regime de UM eixo. O corte de meia tela esta explicado no cabecalho.
func _regime(folga: float, eixo: int) -> String:
	if folga <= 0.0:
		return "FECHADO"
	var tela := _viewport()
	var meia: float = (tela.x if eixo == 0 else tela.y) * 0.5
	return "ABERTO" if folga >= meia else "PROIBIDO"


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
