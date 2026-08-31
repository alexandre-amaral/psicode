class_name PropAnimado
extends Sprite2D
## Um prop de cenario que se mexe: ventilador, luz piscando, pistao, ponteiro.
##
## A REGRA QUE ELE EXISTE PARA OBEDECER: **se tudo se mover, nada parece
## importante.** Movimento no cenario compete com movimento de projetil, e o
## projetil tem de ganhar sempre. Por isso o mecanismo carrega duas travas que
## nao sao ajustaveis por quem monta a sala:
##
## 1. **Ele desenha ABAIXO de `Sala.Z_MUNDO`**, na faixa do detalhe de chao.
##    Zero e onde ficam telegrafo, projetil e atores; um prop animado ali
##    poderia cair na frente do aviso que torna um ataque justo. Ficar embaixo e
##    o que torna "nao cobre telegrafo" uma garantia geometrica em vez de uma
##    intencao. E a consequencia disso e que prop animado e CHAPADO por
##    construcao: dar volume a um deles o levaria para `Z_MUNDO`, e a pergunta
##    "isso pode cobrir um projetil?" voltaria a ficar em aberto.
## 2. **O teto de quantos animam por sala e da `DadosSala`**, e nao daqui -- ver
##    `max_props_animados`. O resto do cenario continua estatico.
##
## E ele NAO PASSA PELO `Juice`. O hitstop congela o combate de proposito, com
## `Engine.time_scale`, e um ventilador que trava junto denuncia o truque: o
## jogador ve o mundo inteiro parar e entende que aquilo e um efeito, e nao um
## impacto. Por isso o relogio aqui e de PAREDE, `Time.get_ticks_msec()`, pelo
## mesmo motivo que `Juice.INTERVALO_HITSTOP` e `InimigoBase.INTERVALO_FLASH`
## tambem sao.
##
## E declarado por DADO: quem cria um prop animado novo acrescenta uma regiao em
## `DadosSala.regioes_props_animados` e mais nada. Nao ha cena por prop, pelo
## mesmo motivo que nao ha cena por tipo de sala -- aquele modelo ja existiu no
## `GerenciadorMapa` e foi removido por nao escalar.

## Quantos quadros a fita tem. Os quadros ficam LADO A LADO no atlas, a partir
## da regiao declarada -- a mesma convencao das fitas de ator.
var quadros: int = 4
var fps: float = 6.0
## O quadro em que este prop comeca.
##
## Sorteado por quem monta, e nao zero para todos: dois ventiladores em fase
## batem juntos e leem como um efeito ligado por script, e nao como duas
## maquinas independentes. E a mesma razao pela qual as Sentinelas nascem com o
## contador de rajada sorteado.
var quadro_inicial: int = 0

## A regiao do PRIMEIRO quadro. Os outros saem dela, deslocados em x.
var _primeiro: Rect2 = Rect2()
var _ms_inicial: int = 0


## Monta o prop a partir do dado. Chamado por quem cria, depois do `add_child`.
func configurar(atlas: Texture2D, regiao: Rect2i, quantos: int, cadencia: float, fase: int) -> void:
	texture = atlas
	region_enabled = true
	_primeiro = Rect2(regiao)
	region_rect = _primeiro
	quadros = maxi(quantos, 1)
	fps = maxf(cadencia, 0.01)
	quadro_inicial = fase
	# O relogio comeca AQUI e nao no `_ready`: o prop e configurado depois de
	# entrar na arvore, e comecar no `_ready` daria a todos o mesmo zero.
	_ms_inicial = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if quadros <= 1:
		return
	region_rect = _regiao_do_quadro(quadro_atual())


## Que quadro esta em tela agora.
##
## Publica e derivada do relogio de PAREDE: nao guarda contador proprio, entao
## nao ha estado para dessincronizar, e o hitstop -- que mexe em
## `Engine.time_scale` -- nao alcanca ela. Um ventilador que para junto com o
## combate denuncia que o combate foi congelado por truque.
func quadro_atual() -> int:
	var segundos := float(Time.get_ticks_msec() - _ms_inicial) / 1000.0
	return (quadro_inicial + int(segundos * fps)) % quadros


func _regiao_do_quadro(indice: int) -> Rect2:
	return Rect2(
		_primeiro.position + Vector2(_primeiro.size.x * float(indice), 0.0),
		_primeiro.size
	)
