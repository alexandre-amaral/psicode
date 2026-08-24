extends Node
## O sistema-assinatura do jogo.
##
## A Deterioracao e um numero de 0 a 100 que representa a corrupcao mental e
## fisica do protagonista. Ele nao e so uma barra na tela: TODO ajuste de
## dificuldade do jogo le daqui. Isso e proposital -- concentra o tuning num
## lugar so e garante que o jogador sinta a barra subindo no comportamento
## dos inimigos, nao so no visual.
##
## Fases:
##   BAIXA   (0-49)   inimigos padrao
##   MEDIA   (50-84)  mira preditiva ligada, inimigos mais rapidos e agressivos
##   CRITICA (85-100) alucinacoes visuais, o chefe se revela

const MAXIMO: float = 100.0
const LIMIAR_MEDIO: float = 50.0
const LIMIAR_CRITICO: float = 85.0

enum Fase { BAIXA, MEDIA, CRITICA }

## Quanto a barra sobe sozinha por segundo enquanto ha combate.
## A pressao de tempo do GDD: parar de avancar tambem custa caro.
##
## Era 0.35, calibrado quando a run eram cinco ondas numa arena. Com o andar de
## dez salas a partida ficou mais longa e ninguem voltou neste numero: a
## `tools/medir_ritmo.tscn` mediu a mira preditiva ligando no primeiro terco da
## run, antes de o jogador ter formado o habito de esquiva que ela existe para
## trair. 0.25 -- junto com o ganho por sala em 6 -- poe o limiar entre 38% e
## 50% da run em toda a faixa de habilidade medida.
@export var ganho_passivo_por_segundo: float = 0.25

var valor: float = 0.0:
	set(v):
		var antigo_fase := fase
		valor = clampf(v, 0.0, MAXIMO)
		_recalcular_fase(antigo_fase)
		EventBus.deterioracao_mudou.emit(valor, fase)

var fase: int = Fase.BAIXA
var passiva_ativa: bool = false


func _process(delta: float) -> void:
	if passiva_ativa and ganho_passivo_por_segundo > 0.0:
		adicionar(ganho_passivo_por_segundo * delta)


## Todo ganho de Deterioracao passa por aqui, e e aqui que o implante entra.
##
## Antes o multiplicador vivia so no _process, entao ele valia para o ganho
## passivo e escapava de todo ganho por EVENTO -- limpar onda, matar inimigo,
## virada de fase do chefe. O Dissipador prometia -20% e entregava bem menos,
## porque a maior parte da barra sobe por evento, nao por segundo.
##
## Lido no frame, nao guardado: pegar o implante no meio da partida tem de
## desacelerar a barra na hora.
func adicionar(quantidade: float) -> void:
	if quantidade > 0.0:
		quantidade *= Modificadores.multiplicador_ganho_deterioracao()
	valor += quantidade


func resetar() -> void:
	passiva_ativa = false
	fase = Fase.BAIXA
	valor = 0.0


## 0.0 na barra vazia, 1.0 na barra cheia. Base de todas as interpolacoes.
func normalizado() -> float:
	return valor / MAXIMO


## Inimigos ficam progressivamente mais rapidos. 1.0 -> 1.55 no maximo.
func multiplicador_velocidade() -> float:
	return lerpf(1.0, 1.55, normalizado())


## Inimigos atiram mais rapido. 1.0 -> 1.7 no maximo.
func multiplicador_cadencia() -> float:
	return lerpf(1.0, 1.7, normalizado())


## Projeteis inimigos ficam mais rapidos, mas de forma mais contida que o resto
## -- projetil rapido demais vira injusto em vez de dificil.
func multiplicador_velocidade_projetil() -> float:
	return lerpf(1.0, 1.25, normalizado())


## O DIFERENCIAL DO MVP: acima de 50%, inimigos ranged param de mirar onde voce
## esta e passam a mirar onde voce VAI estar. Sua esquiva vira armadilha.
func usa_mira_preditiva() -> bool:
	return valor >= LIMIAR_MEDIO


## Quanto da previsao o inimigo realmente acerta (0 = mira na posicao atual,
## 1 = intercepto perfeito). Sobe gradualmente depois do limiar para a virada
## nao ser um muro. Em CRITICA chega perto do perfeito.
func precisao_preditiva() -> float:
	if valor < LIMIAR_MEDIO:
		return 0.0
	var t := (valor - LIMIAR_MEDIO) / (MAXIMO - LIMIAR_MEDIO)
	return lerpf(0.55, 1.0, clampf(t, 0.0, 1.0))


## Intensidade do shader de glitch e dos efeitos de alucinacao. Zero ate 35%.
func intensidade_glitch() -> float:
	if valor < 35.0:
		return 0.0
	return clampf((valor - 35.0) / (MAXIMO - 35.0), 0.0, 1.0)


func nome_fase() -> String:
	match fase:
		Fase.BAIXA: return "ESTAVEL"
		Fase.MEDIA: return "DEGRADANDO"
		Fase.CRITICA: return "CRITICO"
	return "?"


func cor_fase() -> Color:
	match fase:
		Fase.BAIXA: return Color("30d9c4")
		Fase.MEDIA: return Color("f2b134")
		Fase.CRITICA: return Color("ff3860")
	return Color.WHITE


func _recalcular_fase(fase_antiga: int) -> void:
	if valor >= LIMIAR_CRITICO:
		fase = Fase.CRITICA
	elif valor >= LIMIAR_MEDIO:
		fase = Fase.MEDIA
	else:
		fase = Fase.BAIXA
	if fase != fase_antiga:
		EventBus.fase_deterioracao_mudou.emit(fase, fase_antiga)
