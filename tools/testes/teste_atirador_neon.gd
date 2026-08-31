extends TesteBase
## O Atirador Neon (INIM 02): encostar nele deixou de ser de graca.
##
## Por que isto e teste e nao revisao de olho: o defeito antigo era uma
## AUSENCIA. Ele continuava plantado mirando enquanto levava tiro a queima
## roupa, e nada no console dizia nada -- o inimigo simplesmente tinha uma
## contra-jogada trivial que ninguem tinha decidido dar a ele.

const CENA := preload("res://src/enemies/atirador_neon.tscn")
## Longe da origem, como as outras suites que instanciam inimigo.
const LONGE := Vector2(17000.0, 17000.0)


func nome() -> String:
	return "AtiradorNeon"


func executar() -> void:
	_a_esquiva_e_um_estado_e_nao_um_desvio()
	_a_faixa_de_tiro_cabe_na_tela()


## A esquiva tem de ser um ESTADO.
##
## Ela apaga a linha de telegrafo, e quem apaga e o `sair` de MIRAR, que a
## `MaquinaEstados` roda inclusive quando a troca vem de fora do estado. Um `if`
## dentro de `_mirar` teria de apagar a linha na mao -- e telegrafo aceso que
## nao apaga e o bug classico deste tipo de inimigo.
func _a_esquiva_e_um_estado_e_nao_um_desvio() -> void:
	var atirador := _nascer()
	ok(atirador.distancia_de_esquiva > 0.0,
		"ele declara uma distancia de esquiva (%.0f)" % atirador.distancia_de_esquiva)
	ok(atirador.distancia_de_esquiva < atirador.distancia_ideal - atirador.margem,
		"a esquiva dispara ANTES da faixa de tiro -- senao ele esquivaria da propria posicao ideal")
	ok(atirador.impulso_esquiva > 1.0,
		"a esquiva e mais rapida que o andar normal (%.2f)" % atirador.impulso_esquiva)

	# O estado existe na maquina, e o nome e o contrato: `_deve_esquivar()`
	# troca para ele de qualquer outro estado.
	atirador._maquina.trocar(atirador.MIRAR)
	igual(String(atirador._maquina.estado), "MIRAR", "ele entra em MIRAR")
	var telegrafo: Telegrafo = atirador._telegrafo
	ok(telegrafo != null and telegrafo.aceso(), "mirando, a linha de telegrafo acende")

	atirador._maquina.trocar(atirador.ESQUIVAR)
	igual(String(atirador._maquina.estado), "ESQUIVAR", "e sai para ESQUIVAR")
	ok(
		telegrafo == null or not telegrafo.aceso(),
		"ao esquivar a linha APAGA -- telegrafo aceso que sobrevive e o bug classico"
	)
	atirador.free()


## A faixa de tiro tem de caber no que a camera mostra.
##
## MEDIDO: a camera enquadra 960x544 centrada no jogador, entao meia tela e 480
## px na horizontal e 272 na VERTICAL. Um atirador alem disso traca uma linha
## rapida de fora do quadro, que e exatamente o que o GDD proibe -- "bullet hell
## so e justo se da para ler a intencao antes do projetil existir", e nao da
## para ler o que nao esta na tela.
##
## O teto cobrado e o HORIZONTAL, e a folga vertical fica registrada como
## ressalva conhecida: apertar a faixa ate 272 mudaria a identidade dele, que e
## ser o punidor de longa distancia. Isso e decisao de design, e o teste marca a
## fronteira em vez de fingir que o problema nao existe.
func _a_faixa_de_tiro_cabe_na_tela() -> void:
	var atirador := _nascer()
	var meia_tela_x := 480.0
	var longe: float = atirador.distancia_ideal + atirador.margem
	ok(
		longe <= meia_tela_x,
		"no ponto mais distante ele continua no quadro na horizontal (%.0f de %.0f)"
			% [longe, meia_tela_x]
	)
	atirador.free()


func _nascer() -> Node:
	var atirador := CENA.instantiate()
	atirador.position = LONGE
	Engine.get_main_loop().root.add_child(atirador)
	return atirador
