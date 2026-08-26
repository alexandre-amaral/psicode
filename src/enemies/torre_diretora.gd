extends InimigoBase
## Uma torre de defesa da arena, na fase Absoluta.
##
## Ela nao e um inimigo que a Diretora invocou -- ela E a Diretora, saindo pelo
## chao. Quando o corpo dela deixa de bastar, o sistema para de usar um corpo:
## "as paredes comecam a se mover, torres de defesa surgem do chao e partes do
## cenario se tornam armas".
##
## Por isso ela nao anda e nao persegue. Uma torre que caminhasse seria mais um
## inimigo; parada, ela e ARQUITETURA -- e o que o jogador sente e que o lugar
## virou hostil, nao que apareceram mais bichos.
##
## Ela nasce pela Diretora e nao pela Sala, entao fica fora de `Sala._vivos`
## pelo mesmo caminho dos invocados: a sala do chefe continua fechando pela
## morte DELA e por mais nada. Uma torre sobrevivente nao segura a vitoria.

## Quanto tempo ela leva subindo antes de poder atirar. E telegrafo de posicao:
## o jogador ve ONDE ela vai estar antes de ela poder machucar.
const TEMPO_SUBIDA := 0.8

## O aviso de cada disparo. Vale o mesmo piso do chefe -- ela e ele.
const TELEGRAFO_TIRO := 0.45

@export var intervalo_tiro: float = 2.2

var _t_subida: float = TEMPO_SUBIDA
var _t_ciclo: float = 0.0
var _mirando: bool = false
var _arma: Arma


func _ready() -> void:
	super._ready()
	_arma = $Visual/Arma
	_arma.hostil = true
	# Nasce pequena e cresce: e a subida. `_ao_nascer` da base ja faz o pop de
	# escala, entao aqui basta o tempo de invulnerabilidade conceitual -- ela so
	# comeca o ciclo depois de estar de pe.
	_t_ciclo = intervalo_tiro
	# Espalha o primeiro tiro do grupo: quatro torres subindo juntas e
	# disparando no mesmo frame seriam uma parede de projeteis, nao um padrao.
	_t_ciclo = randf_range(intervalo_tiro * 0.4, intervalo_tiro)


func _comportamento(delta: float) -> void:
	_arma.multiplicador_velocidade = Deterioracao.multiplicador_velocidade_projetil()
	velocity = Vector2.ZERO

	if _t_subida > 0.0:
		_t_subida -= delta
		return

	_t_ciclo -= delta * Deterioracao.multiplicador_cadencia()
	if _mirando:
		if _t_ciclo <= 0.0:
			_disparar()
		return
	if _t_ciclo <= TELEGRAFO_TIRO:
		_mirar()


## O aviso: ela acende antes de atirar. Sem isto ela seria dano vindo de um
## canto da tela que o jogador nao tinha motivo para estar olhando.
func _mirar() -> void:
	_mirando = true
	_t_ciclo = TELEGRAFO_TIRO
	if _corpo != null:
		var t := create_tween()
		t.tween_property(_corpo, "self_modulate", Color(2.4, 1.2, 2.6), TELEGRAFO_TIRO * 0.7)
		t.tween_property(_corpo, "self_modulate", Color.WHITE, TELEGRAFO_TIRO * 0.3)


func _disparar() -> void:
	_mirando = false
	_t_ciclo = intervalo_tiro
	if alvo == null or not is_instance_valid(alvo):
		return
	_arma.atualizar_gatilho(false)
	_arma.atirar(direcao_para_alvo())
