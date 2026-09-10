extends Control
## A faixa de implantes instalados, no pe da coluna de status da HUD.
##
## A decisao de design que ela carrega: **isto e um REGISTRO, nao um aviso.** O
## nome que pisca em `AvisoItem` conta o que acabou de acontecer e some em 3 s;
## esta faixa responde "o que eu instalei nesta run", que e uma pergunta feita
## vinte minutos depois da coleta. Sem ela `Modificadores.itens_ativos()` existe
## e ninguem desenha: o jogador carrega ate 16 implantes sem ter onde conferir.
##
## Por isso ela **nao anima**. Movimento no HUD compete com movimento de
## PROJETIL, que e pior do que competir com o cenario -- e o cenario ja tem teto
## por causa disso (`max_props_animados`). A faixa aparece, fica, e so muda
## quando o conjunto de implantes muda.
##
## E por isso **repetido CONTA em vez de repetir**: dois `nanobots` sao uma vaga
## com "2" e nao duas vagas. Desenhando a lista crua a faixa cresceria com o
## numero de COLETAS -- que nao tem teto -- em vez de com o numero de implantes
## distintos, que tem teto de 16 e cabe na coluna.

## O lado desenhado de um icone. O arquivo tem 64 px, entao 16 e uma reducao de
## 1/4 EXATA: cada pixel na tela e um bloco de 4x4 do arquivo, sem amostra caindo
## no meio de dois pixels. 20 ou 24 leriam melhor e sao 3,2x e 2,67x -- a mesma
## razao pela qual a arte de personagem dobra para 128 e nunca vai para 96.
const LADO := 16.0
## Vao entre vagas. Existe para as silhuetas nao se lerem como uma barra so.
const ESPACO := 4.0
## Vagas por linha. Oito porque `8 * 16 + 7 * 4 = 156` cabe nos 208 px da barra
## de vida logo acima -- a coluna de status inteira alinha na mesma largura. Os
## 16 implantes do andar 1 ocupam entao DUAS linhas, que sao os 36 px que a cena
## reserva; implante novo alem disso desenha uma terceira e nao empurra nada,
## porque a bandeja e o ultimo no da coluna.
const POR_LINHA := 8

const TAMANHO_SIGLA := 9
const TAMANHO_CONTAGEM := 8

## A faixa e a informacao MENOS urgente da coluna (vida, Deterioracao, e so
## entao o que esta instalado). Desenhada em alpha cheio ela disputa a leitura
## com as duas barras que decidem o proximo segundo.
const ALPHA_REPOUSO := 0.85

## Fundo de UMA vaga -- nunca da faixa. Ele existe para o icone ler sobre o chao
## claro de uma sala e nasce junto com o implante: sem implante nao ha retangulo
## nenhum na tela.
const COR_FUNDO_VAGA := Color(0.06, 0.07, 0.11, 0.55)
## Tinta escura da sigla e da contagem. Mesma familia do fundo da HUD.
const COR_TINTA := Color(0.04, 0.05, 0.08, 1.0)

## Uma entrada por implante DISTINTO: {"dados": DadosItem, "contagem": int}.
var _vagas: Array[Dictionary] = []


func _ready() -> void:
	# So `modificadores_mudaram`, e nao `item_coletado`: a doc dele no EventBus
	# diz que ele existe justamente porque a HUD precisa redesenhar tambem
	# quando a run recomeca e a lista esvazia. `aplicar()` emite os dois, entao
	# escutar so o de coleta nao perderia nenhum implante -- perderia o
	# `resetar()`, e a bandeja atravessaria para a run seguinte cheia.
	EventBus.modificadores_mudaram.connect(_recolher)
	# PUXA a lista em vez de esperar o proximo sinal. `iniciar_run()` chama
	# `resetar()` no _ready do GerenciadorMapa e a HUD pode nascer depois disso
	# (troca de cena, reinicio): a mesma armadilha que o saldo de creditos ja
	# paga logo ali em `hud.gd`.
	_recolher()


## Reconta a partir do autoload. Nada aqui procura o Player nem o pickup: quem
## sabe o que esta instalado e `Modificadores`, e ele ja e global.
func _recolher() -> void:
	_vagas.clear()
	for item in Modificadores.itens_ativos():
		if item == null:
			continue
		var vaga := _vaga_de(item)
		if vaga < 0:
			_vagas.append({"dados": item, "contagem": 1})
		else:
			_vagas[vaga]["contagem"] = int(_vagas[vaga]["contagem"]) + 1
	# Sem implante a bandeja SAI da tela, e nao fica como moldura vazia: ela
	# ocupa o primeiro minuto de toda run, quando ainda nao ha nada para
	# registrar, e ruido permanente no HUD e pior que a informacao que ele daria.
	# Escondida, o VBoxContainer da coluna nem reserva o espaco dela.
	visible = not _vagas.is_empty()
	queue_redraw()


## Por identidade, e nao por nome: e assim que `Modificadores._quantas_vezes()`
## conta para cobrar o `maximo_por_run`. Contar por outra chave aqui faria a
## bandeja discordar do limite que o proprio jogo aplica -- dois `.tres`
## diferentes com o mesmo nome apareceriam como um so.
func _vaga_de(item: DadosItem) -> int:
	for indice in _vagas.size():
		if _vagas[indice]["dados"] == item:
			return indice
	return -1


func _draw() -> void:
	# `visible` ja impede o desenho; esta linha e a segunda metade da mesma
	# garantia, para quem ligar a visibilidade de fora nao ver um fundo de vaga
	# sem implante dentro.
	if _vagas.is_empty():
		return
	for indice in _vagas.size():
		var vaga: Dictionary = _vagas[indice]
		_desenhar_vaga(_canto_da_vaga(indice), vaga["dados"] as DadosItem, int(vaga["contagem"]))


func _canto_da_vaga(indice: int) -> Vector2:
	var coluna := indice % POR_LINHA
	var linha := indice / POR_LINHA
	return Vector2(float(coluna) * (LADO + ESPACO), float(linha) * (LADO + ESPACO))


func _desenhar_vaga(canto: Vector2, dados: DadosItem, contagem: int) -> void:
	if dados == null:
		return
	var quadro := Rect2(canto, Vector2(LADO, LADO))
	draw_rect(quadro, COR_FUNDO_VAGA, true)
	if dados.icone != null:
		draw_texture_rect(dados.icone, quadro, false, Color(1.0, 1.0, 1.0, ALPHA_REPOUSO))
	else:
		_desenhar_losango(quadro, dados)
	if contagem > 1:
		_desenhar_contagem(quadro, contagem, dados.cor)


## O fallback DECLARADO de `DadosItem`: sem icone valem `cor` e `sigla`, o mesmo
## losango que o pickup no chao desenha. Ele nao e defensividade -- e o que
## permite um implante novo nascer antes da arte dele.
func _desenhar_losango(quadro: Rect2, dados: DadosItem) -> void:
	var meio := quadro.position + quadro.size * 0.5
	var raio := quadro.size.x * 0.5 - 1.0
	var cor := dados.cor
	cor.a = ALPHA_REPOUSO
	draw_colored_polygon(
		PackedVector2Array([
			meio + Vector2(0.0, -raio),
			meio + Vector2(raio, 0.0),
			meio + Vector2(0.0, raio),
			meio + Vector2(-raio, 0.0),
		]),
		cor
	)
	var fonte := get_theme_default_font()
	if fonte == null or dados.sigla.is_empty():
		return
	var medida := fonte.get_string_size(dados.sigla, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_SIGLA)
	# A sigla vai ESCURA sobre o losango aceso. Escrita na cor do implante ela
	# sumiria dentro da propria cor, que e o que ela existe para identificar.
	draw_string(
		fonte,
		meio + Vector2(-medida.x * 0.5, medida.y * 0.32),
		dados.sigla,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		TAMANHO_SIGLA,
		COR_TINTA
	)


## A contagem de um implante empilhado, no canto inferior direito da vaga.
##
## Digito puro, e nao "x2": glifo que a fonte nao tem SOME sem erro nenhum, e a
## bandeja nao tem como saber qual fonte a tela vai usar. Digito e ASCII.
func _desenhar_contagem(quadro: Rect2, contagem: int, cor: Color) -> void:
	var fonte := get_theme_default_font()
	if fonte == null:
		return
	var texto := str(contagem)
	var medida := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TAMANHO_CONTAGEM)
	var caixa := Vector2(medida.x + 2.0, float(TAMANHO_CONTAGEM) + 2.0)
	# Tampa opaca sob o numero: sobre um icone claro o digito na cor do implante
	# seria mais um detalhe do desenho em vez de uma quantidade.
	draw_rect(Rect2(quadro.end - caixa, caixa), COR_TINTA, true)
	var forte := cor
	forte.a = 1.0
	draw_string(
		fonte,
		quadro.end - Vector2(medida.x + 1.0, 2.0),
		texto,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		TAMANHO_CONTAGEM,
		forte
	)
