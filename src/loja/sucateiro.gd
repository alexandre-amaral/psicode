class_name Sucateiro
extends Node2D
## O NPC da Loja: um antigo tecnico que virou comerciante de sucata industrial.
##
## Ele existe para o jogador reconhecer o lugar antes de ler qualquer texto. A
## sala ja tem balcao e tres bancadas, mas balcao vazio le como movel abandonado
## -- e a fabrica INTEIRA e movel abandonado. **O que diz "alguem ocupou este
## pedaco" e haver alguem.**
##
## ## As tres coisas que ele NAO pode parecer
##
## Inimigo, personagem selecionavel, e Unidade Aprimorada. A terceira e a mais
## provavel e a mais cara: as aprimoradas tem aura desenhada em volta do corpo, e
## um NPC com efeito parecido faria o jogador atirar nele antes de perceber.
##
## Por isso o acento dele **nao e anel, nao e placa orbitando e nao e faisca** --
## as tres familias ja tem dono. O que ele tem e uma luz de bancada acesa PERTO
## dele, no chao, que e a mesma linguagem da luz da sala e nao um efeito de ator.
##
## E ele nao aponta nada: postura parada, maos ao lado do corpo. Num jogo em que
## tudo que se move na sala e ameaca, ficar parado e a leitura.
##
## ## Ele NAO controla a compra
##
## O jogador compra direto nas bancadas. Amarrar a economia a falar com o NPC
## transformaria uma decisao em pedagio, e a issue e explicita: *"a compra NAO
## depende de falar com ele"*. O que ele oferece e sabor.

signal conversou

## Quanto o jogador precisa chegar perto para o prompt aparecer.
##
## MENOR que o das bancadas: com os dois no alcance, o prompt tem de ser o da
## bancada. Comprar errado por um pixel e o tipo de defeito que so aparece com o
## jogador andando, e a issue o registra como armadilha.
const RAIO_DE_INTERACAO := 34.0

## O que ele diz. Uma linha, e ela nao explica mecanica nenhuma -- quem explica a
## Loja e a Loja.
const FALA := "O que está na bancada está à venda."

var _sprite: Sprite2D
var _jogador: Node2D = null
var _perto: bool = false


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Corpo"
	# **A ARTE PODE NAO EXISTIR AINDA, e isso nao pode quebrar a sala.** O mesmo
	# desenho do `SEM_ARTE_AINDA` dos chefes: a falta e declarada e nao um erro
	# em runtime -- sem sprite ele desenha a silhueta de reserva do `_draw`.
	var textura := load(CAMINHO_DA_ARTE) as Texture2D
	if textura != null:
		_sprite.texture = textura
		# **A ANCORA E NOS PES, e nao no centro do quadro.** O `Sprite2D` centra a
		# textura na origem do no por padrao; com o Y-sort da sala isso poria a
		# CINTURA dele na linha de profundidade, e ele apareceria atras do balcao
		# que esta a frente dele. E o mesmo erro que arte de projetil ancorada na
		# base ja produz ao contrario.
		#
		# `DESLOCAMENTO_DO_PE` sai do desenho: a arte tem 64 px e os pes caem em
		# 63, entao o centro esta 31 px acima deles.
		_sprite.offset = Vector2(0.0, -DESLOCAMENTO_DO_PE)
	add_child(_sprite)


const CAMINHO_DA_ARTE := "res://assets/npc/sucateiro/south.png"
## Quanto o centro da textura esta acima dos pes, medido no alfa do arquivo.
const DESLOCAMENTO_DO_PE := 31.0


func _process(_delta: float) -> void:
	if _jogador == null or not is_instance_valid(_jogador):
		_jogador = get_tree().get_first_node_in_group("player") as Node2D
	var estava := _perto
	_perto = _jogador != null \
		and global_position.distance_to(_jogador.global_position) <= RAIO_DE_INTERACAO
	if _perto != estava:
		queue_redraw()
	elif _perto:
		queue_redraw()
	if _perto and not _uma_bancada_esta_mais_perto() \
			and Input.is_action_just_pressed("interagir"):
		conversou.emit()


## Se ha uma bancada mais perto do jogador que ele.
##
## **Sem isto o jogador conversa quando queria comprar.** O balcao fica atras das
## bancadas e os dois alcances se tocam; a issue pede que a oferta tenha
## prioridade, e comparar a DISTANCIA e mais honesto que uma constante de
## prioridade -- ela responde certo mesmo se alguem mover as bancadas.
func _uma_bancada_esta_mais_perto() -> bool:
	if _jogador == null:
		return false
	var minha := global_position.distance_to(_jogador.global_position)
	for irmao in get_parent().get_children():
		var bancada := irmao as BancadaDeOferta
		if bancada == null:
			continue
		if bancada.global_position.distance_to(_jogador.global_position) < minha:
			return true
	return false


## A silhueta de reserva, para a sala funcionar antes de a arte chegar.
##
## Ela e chapada e sem detalhe de proposito: uma reserva bonita demais demora
## para ser substituida, e o `GEMINI.md` ja registra o caso da Diretora, que
## ficou anos com o placeholder porque ele "resolvia".
func _draw() -> void:
	# O PROMPT dele so aparece quando nenhuma bancada esta mais perto: e a mesma
	# regra do `_process`, e desenhar sem ela mostraria "Conversar" enquanto a
	# tecla compraria.
	if _perto and not _uma_bancada_esta_mais_perto():
		var fonte := ThemeDB.fallback_font
		var texto := "[E] Conversar"
		var largura := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT,
			-1.0, 10).x
		draw_string(fonte, Vector2(-largura * 0.5, -70.0), texto,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color(0.78, 0.80, 0.86))

	if _sprite != null and _sprite.texture != null:
		return
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10.0, -34.0), Vector2(10.0, -34.0),
		Vector2(13.0, 0.0), Vector2(-13.0, 0.0),
	]), Color(0.30, 0.27, 0.24))
	draw_circle(Vector2(0.0, -40.0), 8.0, Color(0.36, 0.33, 0.29))
