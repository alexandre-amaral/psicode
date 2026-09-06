class_name EnquadramentoDeSala
extends RefCounted
## Monta uma sala no ENQUADRAMENTO REAL DO JOGO e poe o jogador em posicoes
## declaradas.
##
## Ele nasceu de um pedido explicito da #240: `comparar_norte` e `comparar_topos`
## fotografam a mesma parede para responder perguntas diferentes, e **duas copias
## do posicionamento divergem**. O sintoma nao seria um erro: seriam duas
## ferramentas comparando coisas fotografadas de lugares diferentes, cada uma
## convencida de que mediu a mesma parede.
##
## O que ele centraliza e exatamente o que ja se errou aqui:
##
##   - **o `DadosSala` do tipo**, sem o qual `_perfil()` devolve `null` e a
##     ferramenta mede o DEFAULT enquanto o jogo desenha outra coisa. Foi assim
##     que a moldura foi medida em 18% por dois epicos inteiros;
##   - **o clamp de verdade**, que cresce pelas QUATRO margens do perfil e depois
##     ate o quadro. Sem `_cabendo_a_tela()` a sala mais estreita que a tela sai
##     encostada numa borda, e isso se parece com um defeito de clamp sem ser um;
##   - **as tres posicoes**, que sao onde os defeitos moram: a norte mostra a
##     face inteira de frente, a sul mostra a faixa que a regra do sul inverteu,
##     e a quina mostra a meia-esquadria.

const CENA_PADRAO := "res://src/mapa/sala_1_retangular.tscn"

## As tres posicoes do jogador, e elas sao CONTRATO entre as ferramentas.
const POSICOES: Array[String] = ["norte", "sul", "quina"]

## Quanto o jogador para antes do contorno.
##
## 24 px: encostado o bastante para a parede daquele lado entrar inteira no
## quadro pelo clamp, e longe o bastante para o corpo dele nao cobrir a faixa que
## se quer olhar.
const RECUO := 24.0


## A sala, vestida com o estilo de verdade, ja no `pai`.
##
## `definir_visual()` roda ANTES do `add_child`, como `configurar_conexoes`: e o
## `_ready` que monta chao, fita, sombra e colisao, e nao ha janela depois disso.
static func montar(pai: Node, caminho: String = CENA_PADRAO) -> Sala:
	var sala := (load(caminho) as PackedScene).instantiate() as Sala
	sala.definir_visual(dados_do_tipo(caminho))
	pai.add_child(sala)
	return sala


## O jogador com a camera ja clampada no regime do jogo.
static func acompanhar(pai: Node, sala: Sala) -> Node2D:
	var jogador := (load("res://src/player/player.tscn") as PackedScene).instantiate() as Node2D
	pai.add_child(jogador)
	var camera := jogador.get_node_or_null("Camera") as Camera2D
	if camera == null:
		return jogador
	camera.make_current()
	var limites := sala.obter_limites()
	var margens := RenderizadorParedes.margens(sala.perfil_de_parede())
	var visivel := limites.grow_individual(margens.x, margens.y, margens.z, margens.w)
	# O mesmo crescimento que o gerenciador aplica: sem ele uma sala mais estreita
	# que a tela recebe um limite MENOR que o quadro, e o motor escolhe sozinho a
	# que borda encostar.
	var gerenciador := GerenciadorMapa.new()
	visivel = gerenciador._cabendo_a_tela(visivel)
	gerenciador.free()
	camera.limit_left = int(visivel.position.x)
	camera.limit_top = int(visivel.position.y)
	camera.limit_right = int(visivel.end.x)
	camera.limit_bottom = int(visivel.end.y)
	return jogador


static func posicionar(jogador: Node2D, sala: Sala, qual: String) -> void:
	var limites := sala.obter_limites()
	match qual:
		"sul":
			jogador.global_position = Vector2(0.0, limites.end.y - RECUO)
		"quina":
			jogador.global_position = Vector2(
				limites.position.x + RECUO, limites.position.y + RECUO)
		_:
			jogador.global_position = Vector2(0.0, limites.position.y + RECUO)


## O `DadosSala` do tipo daquela cena.
##
## Sem ele a sala nasce com `_dados_visual` nulo, `_perfil()` devolve `null` e a
## ferramenta mede a REGRA enquanto o jogo desenha o estilo -- o ponto cego que
## deixou `medir_moldura` afirmando ter medido o jogo por duas entregas.
static func dados_do_tipo(caminho_cena: String) -> DadosSala:
	var tipo := "combate"
	var nome := caminho_cena.get_file().get_basename()
	if nome.ends_with("_boss"):
		tipo = "boss"
	elif nome.ends_with("_arma"):
		tipo = "arma"
	elif nome.ends_with("_item"):
		tipo = "item"
	elif nome.ends_with("_inicial"):
		tipo = "inicial"
	return load("res://src/mapa/tipo_%s.tres" % tipo) as DadosSala
