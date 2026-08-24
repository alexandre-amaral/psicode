extends Control
## O mapa do andar no canto da HUD.
##
## Duas decisoes de design moram aqui.
##
## 1. **Desenha a forma real, nao um quadradinho por sala.** O contorno vem do
##    mesmo Line2D "Parede" de onde nasce a colisao, entao a sala em L aparece
##    em L e o corredor vertical aparece alto e estreito. E o que faz o mapa
##    servir para se orientar: o jogador reconhece a sala pela silhueta antes de
##    ler qualquer icone.
##
## 2. **Escala unica para o andar inteiro.** O layout do GerenciadorMapa e em
##    bandas -- a largura de uma coluna e a da sala mais larga dela --, entao as
##    celulas NAO estao num grid uniforme. Normalizar sala por sala mentiria
##    sobre as distancias; uma escala so mantem o mapa fiel ao mundo.
##
## Como todo o resto da HUD, isto nao conhece o jogo: acha o GerenciadorMapa
## pelo grupo (a excecao legitima do projeto) e redesenha por sinal do EventBus.

@export_group("Enquadramento")
@export var margem: float = 10.0
@export var largura_contorno: float = 1.5
## Espessura da borda da sala em que o jogador esta.
@export var largura_atual: float = 3.0

@export_group("Cores")
@export var cor_fundo: Color = Color(0.04, 0.05, 0.09, 0.55)
@export var cor_desconhecida: Color = Color(0.45, 0.5, 0.62, 0.35)
@export var cor_corredor: Color = Color(0.3, 0.9, 1.0, 0.35)
@export var cor_atual: Color = Color(1, 1, 1, 0.95)
## Preenchimento de sala visitada mas ainda nao limpa.
@export var alpha_visitada: float = 0.22
## Preenchimento de sala ja limpa. Mais forte de proposito: o que o jogador
## procura no mapa e "onde ainda falta ir".
@export var alpha_limpa: float = 0.55

var _mapa: GerenciadorMapa = null
var _escala: float = 0.0
var _deslocamento: Vector2 = Vector2.ZERO
var _pulso: float = 0.0


func _ready() -> void:
	EventBus.andar_gerado.connect(_ao_mudar)
	# transicao_iniciada tambem: o destino ja foi revelado no mundo quando o
	# jogador entra no corredor, e o mapa tem de acompanhar no mesmo frame.
	EventBus.transicao_iniciada.connect(func(_d: Vector2, _s: Node2D) -> void: _ao_mudar())
	EventBus.transicao_concluida.connect(func(_s: Node2D) -> void: _ao_mudar())
	EventBus.sala_limpa.connect(func(_s: Node2D) -> void: _ao_mudar())
	# A transformacao depende de size, e o projeto estica em "expand".
	resized.connect(_ao_mudar)


func _process(delta: float) -> void:
	# So a sala atual pulsa. Sem isso, num andar de dez salas o jogador precisa
	# procurar onde esta antes de ler para onde vai.
	_pulso = fposmod(_pulso + delta, 2.0)
	queue_redraw()


func _ao_mudar() -> void:
	_resolver_mapa()
	_recalcular_transformacao()
	queue_redraw()


## Preguicoso de proposito: a HUD e o primeiro filho de main.tscn, entao no
## _ready dela o GerenciadorMapa ainda nao existe. O sinal andar_gerado resolve
## o caso normal; isto aqui cobre o resto.
func _resolver_mapa() -> void:
	if _mapa != null and is_instance_valid(_mapa):
		return
	_mapa = get_tree().get_first_node_in_group("gerenciador_mapa") as GerenciadorMapa


func _recalcular_transformacao() -> void:
	_escala = 0.0
	if _mapa == null:
		return
	var mundo := _mapa.limites_do_andar()
	if mundo.size.x <= 0.0 or mundo.size.y <= 0.0:
		return
	var util := size - Vector2(margem, margem) * 2.0
	if util.x <= 0.0 or util.y <= 0.0:
		return
	_escala = minf(util.x / mundo.size.x, util.y / mundo.size.y)
	_deslocamento = Vector2(margem, margem) \
		+ (util - mundo.size * _escala) * 0.5 \
		- mundo.position * _escala


func _para_tela(ponto: Vector2) -> Vector2:
	return ponto * _escala + _deslocamento


func _draw() -> void:
	if cor_fundo.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), cor_fundo, true)

	_resolver_mapa()
	if _mapa == null:
		return
	if _escala <= 0.0:
		_recalcular_transformacao()
		if _escala <= 0.0:
			return

	_desenhar_corredores()

	var atual := _mapa.celula_atual()
	for celula in _mapa.celulas():
		if not _mapa.e_conhecida(celula):
			continue
		_desenhar_sala(celula, celula == atual)


## So o corredor com as duas pontas conhecidas, espelhando o que o mundo faz:
## caminho iluminado terminando no escuro entrega o que a nevoa esconde.
func _desenhar_corredores() -> void:
	for ligacao in _mapa.ligacoes():
		if not _mapa.e_conhecida(ligacao["a"]) or not _mapa.e_conhecida(ligacao["b"]):
			continue
		var caixa: Rect2 = ligacao["caixa"]
		var canto := _para_tela(caixa.position)
		var tamanho := caixa.size * _escala
		draw_rect(Rect2(canto, tamanho), cor_corredor, true)


func _desenhar_sala(celula: Vector2i, eh_atual: bool) -> void:
	var mundo := _mapa.contorno_global_de(celula)
	if mundo.size() < 3:
		return

	var tela := PackedVector2Array()
	for ponto in mundo:
		tela.append(_para_tela(ponto))

	var visitada := _mapa.foi_visitada(celula)
	var dados := _mapa.dados_da_celula(celula)
	var cor_tipo: Color = dados.cor_mapa if dados != null else cor_desconhecida

	if not visitada:
		# Vizinha ainda nao pisada: so o contorno. Da orientacao sem entregar o
		# que tem dentro.
		_contornar(tela, cor_desconhecida, largura_contorno)
		return

	var preenchimento := cor_tipo
	preenchimento.a = alpha_limpa if _mapa.esta_limpa(celula) else alpha_visitada
	_preencher(tela, preenchimento)

	var cor_borda := cor_atual if eh_atual else cor_tipo
	var largura := largura_atual if eh_atual else largura_contorno
	if eh_atual:
		# Respira devagar: chama o olho sem competir com o combate.
		cor_borda.a = lerpf(0.55, 1.0, 0.5 + 0.5 * sin(_pulso * PI))
	_contornar(tela, cor_borda, largura)

	if dados != null and dados.icone != "":
		_desenhar_icone(tela, dados.icone, cor_tipo)


## Triangula antes de preencher. draw_colored_polygon renderiza poligono
## concavo errado, e a sala em L e concava -- sem isto ela apareceria como um
## retangulo cheio, justamente a forma que este mapa existe para nao mostrar.
func _preencher(pontos: PackedVector2Array, cor: Color) -> void:
	var indices := Geometry2D.triangulate_polygon(pontos)
	if indices.is_empty():
		# Poligono degenerado: melhor so o contorno que uma mancha errada.
		return
	for i in range(0, indices.size(), 3):
		draw_colored_polygon(PackedVector2Array([
			pontos[indices[i]],
			pontos[indices[i + 1]],
			pontos[indices[i + 2]],
		]), cor)


## Fecha o poligono na mao: o contorno vem sem o ponto repetido (Geometry2D
## engasga com ele), entao o ultimo lado precisa ser desenhado a parte.
##
## A largura NAO e multiplicada pela escala de proposito: em andar grande a
## borda sumiria, e e ela que identifica a sala.
func _contornar(pontos: PackedVector2Array, cor: Color, largura: float) -> void:
	var fechado := PackedVector2Array(pontos)
	fechado.append(pontos[0])
	# antialiased = false: o renderer Compatibility nao tem MSAA 2D e o projeto
	# usa filtro Nearest.
	draw_polyline(fechado, cor, largura, false)


## Media dos vertices, MAS so quando ela cai dentro da sala. Numa sala em L a
## media cai exatamente na quina concava, que e fora do poligono -- o icone
## ficaria pendurado no vazio. Nesse caso vale o centro do maior triangulo, que
## por construcao esta dentro.
func _centro_interno(pontos: PackedVector2Array) -> Vector2:
	var media := Vector2.ZERO
	for ponto in pontos:
		media += ponto
	media /= float(pontos.size())
	if Geometry2D.is_point_in_polygon(media, pontos):
		return media

	var indices := Geometry2D.triangulate_polygon(pontos)
	var melhor := media
	var maior := -1.0
	for i in range(0, indices.size(), 3):
		var a := pontos[indices[i]]
		var b := pontos[indices[i + 1]]
		var c := pontos[indices[i + 2]]
		var area := absf((b - a).cross(c - a)) * 0.5
		if area > maior:
			maior = area
			melhor = (a + b + c) / 3.0
	return melhor


func _desenhar_icone(pontos: PackedVector2Array, texto: String, cor: Color) -> void:
	var fonte := ThemeDB.fallback_font
	if fonte == null:
		return
	var centro := _centro_interno(pontos)
	var tamanho := 11
	var medida := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tamanho)
	var cor_forte := cor
	cor_forte.a = 1.0
	draw_string(
		fonte,
		centro + Vector2(-medida.x * 0.5, medida.y * 0.32),
		texto,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		tamanho,
		cor_forte
	)
