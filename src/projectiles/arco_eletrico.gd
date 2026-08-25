class_name ArcoEletrico
extends Line2D
## O risco que liga os alvos de uma corrente eletrica.
##
## E so leitura: o dano da corrente ja foi aplicado quando este no aparece. Ele
## existe porque uma arma que fere tres inimigos de uma vez SEM mostrar por onde
## passou le como bug -- o jogador ve vida sumindo de quem ele nao mirou. O
## GDD trata leitura de combate como requisito, nao como enfeite.
##
## Ele nasce na CENA, nunca como filho do projetil: o projetil morre no mesmo
## frame do acerto e levaria o arco junto antes de qualquer um ver.

## Quanto o risco fica na tela. Curto de proposito: e um estalo, nao um cabo.
const DURACAO := 0.18
## Desvio maximo, em pixels, dos pontos que o serrilhado insere entre dois
## alvos. Reta pura le como laser; e a corrente nao e um laser.
const RUIDO := 9.0
## Quantos segmentos entram entre cada par de alvos.
const SEGMENTOS := 4


func _ready() -> void:
	top_level = true
	z_index = 40
	joint_mode = Line2D.LINE_JOINT_ROUND
	begin_cap_mode = Line2D.LINE_CAP_ROUND
	end_cap_mode = Line2D.LINE_CAP_ROUND


func configurar(alvos: PackedVector2Array, tinta: Color, grossura: float) -> void:
	if alvos.size() < 2:
		queue_free()
		return

	width = maxf(grossura, 2.0)
	default_color = Color(tinta.r, tinta.g, tinta.b, 0.95)
	points = _serrilhar(alvos)

	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, DURACAO)
	t.parallel().tween_property(self, "width", width * 0.3, DURACAO)
	t.tween_callback(queue_free)


## Quebra cada trecho reto em pedacos com desvio lateral aleatorio.
func _serrilhar(alvos: PackedVector2Array) -> PackedVector2Array:
	var saida := PackedVector2Array()
	for i in alvos.size() - 1:
		var de := alvos[i]
		var para := alvos[i + 1]
		var normal := (para - de).normalized().orthogonal()
		saida.append(de)
		for passo in range(1, SEGMENTOS):
			var meio := de.lerp(para, float(passo) / float(SEGMENTOS))
			saida.append(meio + normal * randf_range(-RUIDO, RUIDO))
	saida.append(alvos[alvos.size() - 1])
	return saida
