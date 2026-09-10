extends Area2D
## Implante no chao. Encoste para instalar; o efeito vale ate o fim da run.
##
## Decisao de design: este pickup NAO chama metodo no Player. Ele entrega o
## implante ao autoload Modificadores e quem sofre o efeito le de la no frame
## em que precisa. E o mesmo caminho da Deterioracao, e e mais fiel a regra do
## EventBus que o `corpo.pedir_arma()` do pickup de arma -- que so ficou assim
## porque o que o jogador CARREGA e estado do proprio Player, e nao um efeito
## global. E porque a arma pode ser RECUSADA: com os dois slots cheios o pickup
## precisa da resposta para saber se continua no chao, e um autoload que so
## recebe nao tem o que responder.
##
## A segunda decisao que ele carrega e sobre APRESENTACAO: quem tem arte mostra
## a arte, quem nao tem mostra a letra -- e nunca os dois. Ver `_vestir_icone()`.

## Quanto a letra do fallback escurece em relacao a cor do implante.
##
## Alto de proposito: o losango atras dela e a cor CHEIA, e um escurecimento
## timido devolveria o defeito que este numero existe para consertar. Ver
## `_ready()`.
const ESCURECIMENTO_DA_SIGLA := 0.75

## O icone de 64 px reduzido ao tamanho em que ele foi MEDIDO.
##
## `tools/itens/laboratorio_icones.gd` declara os tres contextos de leitura --
## "64 no cartao, 48 na bancada da Loja, **32 no chao** e na bandeja da HUD" --
## e mede silhueta e cinza no pior deles (`LADO_MEDIDO = 32`). Entao 32 px nao e
## o que coube: e o tamanho contra o qual os 16 icones foram aprovados, e
## desenhar menor que isso jogaria fora a prova de que dois deles nao viram a
## mesma mancha.
##
## Meio e a unica reducao que a pixel art aceita de graca aqui: dois pixels da
## fonte viram um da tela, sem pixel caindo em numero quebrado. A licao
## registrada e sobre AUMENTAR (64 -> 96 borra), e a saida dela e a mesma --
## fator simples, nunca 0,7 escolhido no olho.
##
## Ele nao e repetido no `.tscn` de proposito: numero escrito nos dois lugares e
## o da cena sendo sobrescrito em silencio no `_ready`, e a proxima pessoa a
## girar aquele campo no Inspetor passa a tarde sem entender por que nada muda.
const ESCALA_ICONE := 0.5

## Preenchido = este implante especifico. Vazio = sorteia do pool ao nascer.
@export var dados: DadosItem
@export var pool: PoolLoot
@export var gira: bool = true

var _t: float = 0.0
var _visual: Node2D
var _rotulo: Label
var _icone: Sprite2D


func _ready() -> void:
	_visual = $Visual
	_rotulo = $Rotulo
	_icone = $Icone
	_icone.scale = Vector2.ONE * ESCALA_ICONE

	# O sorteio vem ANTES de pintar: o visual e o rotulo leem `dados`, e
	# sortear depois deixaria um implante sem cor e chamado "IMPLANTE".
	if dados == null and pool != null:
		dados = pool.sortear_item()

	if dados != null:
		# **O losango solido SAI quando ha icone, e o halo herda a cor dele.**
		#
		# Os dois desenhados juntos empilhavam duas respostas para a mesma
		# pergunta: o icone dizia QUAL implante e o solido dizia a mesma coisa numa
		# linguagem mais pobre, por cima da qual o icone ficava. E o solido e
		# opaco, entao ele nao ficava atras -- ele emoldurava o desenho e roubava
		# a silhueta, que e justamente o que a regua mede.
		#
		# O que o solido carregava e a mancha de cor que diz "isto e loot"
		# atravessando a sala, antes de um desenho de 32 px ter chance de ser lido.
		# Isso nao se perde: passa para o HALO, que ja existia e ja pulsa junto do
		# resto -- ele so nunca tinha recebido a cor do implante, e era mint fixo
		# para os dezesseis. A leitura a distancia continua, e vira EFEITO em vez
		# de peca solida.
		$Visual/Halo.color = Color(dados.cor, $Visual/Halo.color.a)
		$Visual/Corpo.color = dados.cor
		# O .tres guarda o portugues, que e a chave; a tela pode estar em ingles.
		_rotulo.text = tr(dados.nome)
		_rotulo.modulate = dados.cor
		# Sigla fica FORA do Visual: o Visual gira, e texto girando fica de
		# cabeca para baixo metade do tempo.
		$Sigla.text = dados.sigla
		# **A letra NAO pode ser `dados.cor`**, e por muito tempo foi. O `Corpo` e
		# pintado dessa MESMA cor logo acima, e a `Sigla` desenha em cima dele:
		# contando as cores do recorte de um pickup sem icone so existiam duas, o
		# fundo e o corpo -- nenhum tom do glifo. A letra existia, ninguem a via, e
		# nada acusava, porque o `Label` estava certo e visivel.
		#
		# Isso nao doia enquanto a letra era o unico desenho do pickup; passou a
		# doer no dia em que ela virou o FALLBACK declarado de um implante sem arte,
		# porque um fallback invisivel e o mesmo que nao ter fallback. Escurecer a
		# propria cor, em vez de usar um cinza fixo, mantem a identidade do implante
		# na letra e ainda separa do losango.
		$Sigla.modulate = dados.cor.darkened(ESCURECIMENTO_DA_SIGLA)
		_vestir_icone(dados.icone)

	body_entered.connect(_ao_encostar)


## Icone quando ha arte, letra quando nao ha -- e nunca os dois.
##
## Quem manda e a PRESENCA da textura, e nao uma bandeira que alguem teria de
## lembrar de ligar: `DadosItem.icone` e opcional por decisao e `sigla` e o
## fallback declarado, e e isso que deixa um implante nascer antes da arte dele
## sem quebrar caminho nenhum aqui.
##
## O icone NAO recebe `modulate = dados.cor`. Ele ja sai do funil na cor certa, e
## multiplicar por cima escureceria a peca inteira -- o mesmo canal que o Hack e
## o nanite disputam no inimigo, onde um terceiro escritor produz uma cor que
## depende da ordem das chamadas.
##
## E ele mora FORA do `Visual` pela mesma razao que a `Sigla`: aquele no gira, e
## arte girando em angulo quebrado reamostra fora da grade -- o oposto do que a
## escala inteira existe para preservar.
func _vestir_icone(arte: Texture2D) -> void:
	_icone.texture = arte
	_icone.visible = arte != null
	$Sigla.visible = arte == null
	# O solido e a LETRA sao a mesma peca de fallback, e saem juntos.
	$Visual/Corpo.visible = arte == null


func _process(delta: float) -> void:
	_t += delta
	if _visual != null:
		_visual.position.y = sin(_t * 3.0) * 5.0
		if gira:
			_visual.rotation += delta * 1.2
		# O icone e a letra flutuam JUNTO com o halo, mas de fora do `Visual`:
		# aquele no tambem GIRA, e arte girando em angulo quebrado reamostra fora
		# da grade (e texto girando fica de cabeca para baixo metade do tempo).
		# Copiar so a altura pega o unico dos dois movimentos que eles podem
		# acompanhar sem pagar por isso.
		_icone.position.y = _visual.position.y
		$Sigla.position.y = _visual.position.y


func _ao_encostar(corpo: Node) -> void:
	if not corpo.is_in_group("player") or dados == null:
		return
	# So some se foi mesmo instalado. Implante no limite por run devolve false,
	# e o pickup fica no chao em vez de evaporar sem dar nada.
	if not Modificadores.aplicar(dados):
		return

	var fx := preload("res://src/fx/impacto.tscn").instantiate()
	fx.global_position = global_position
	fx.modulate = dados.cor
	get_parent().add_child(fx)
	queue_free()
