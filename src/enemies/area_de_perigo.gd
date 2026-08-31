class_name AreaDePerigo
extends Area2D
## Circulo de energia no chao que avisa, explode, ARDE por um tempo e some.
##
## E a primeira ameaca do jogo que nao e um projetil nem um corpo: ela nega
## ESPACO em vez de mirar. Existe para o Hacker Parasita, mas nao sabe nada
## sobre ele -- quem semeia so chama `configurar()` e segue a vida.
##
## Cinco decisoes de design moram aqui:
##
## 1. **O telegrafo E o ataque.** O aviso e um `Telegrafo` (INIM 06), com as
##    quatro fases: fraco, crescendo, piscando, ativacao. Um aviso de
##    intensidade unica responde "vem coisa"; o jogador tambem precisa de "vem
##    QUANDO", e num ataque que nega chao a resposta a essa segunda pergunta e a
##    diferenca entre sair andando e sair correndo.
##
## 2. **A ZONA RESIDUAL nao e para matar, e para nao deixar voltar.** O estouro
##    sozinho e um instante: quem esta fora nao se importa, quem esta dentro ja
##    tomou, e um segundo depois o chao esta livre de novo. E a brasa que fica
##    que faz o Parasita REDUZIR o espaco em vez de so punir um momento -- ele
##    e o inimigo de controle territorial, e sem ela ele nao controla nada.
##    Por isso o dano dela e baixo e o intervalo e longo: ela cobra ficar, nao
##    passar.
##
## 3. **Ela nao e filha de quem a semeou.** Filha do Parasita, ela andaria junto
##    com ele -- e um aviso no chao que se move e um aviso que mente. Quem semeia
##    passa o container da sala como pai.
##
## 4. **Ela desenha em `z = 0`, acima do chao.** Ficou em `z = -4` por muito
##    tempo, e o chao da sala esta em `-1`: o piso desenhava POR CIMA do aviso, e
##    o telegrafo -- a coisa inteira que torna este ataque justo -- era invisivel.
##    Hoje quem garante a faixa e o proprio `Telegrafo`, com `z_as_relative`
##    desligado, entao nao ha mais como uma cena dizer outra coisa.
##
## 5. **A colisao so existe a partir do estouro.** Enquanto e aviso, o Area2D
##    esta desligado. Assim nao ha como o jogador levar dano "de raspao" ao
##    entrar no circulo antes da hora, o que faria o telegrafo parecer quebrado.

## Layers nomeadas no project.godot: 1 player, 5 projetil_inimigo.
const LAYER_PROJ_INIMIGO := 16
const LAYER_PLAYER := 1

## Quantos lados o poligono do circulo tem. 24 le como circulo e custa pouco.
const LADOS := 24

enum Fase {
	## Telegrafo aceso, sem colisao.
	AVISO,
	## O estouro. Dano cheio, uma vez por corpo.
	ESTOURO,
	## A brasa. Dano baixo, em tiques espacados.
	RESIDUAL,
}

@export var raio: float = 56.0
## Quanto tempo o aviso fica crescendo antes de explodir. O piso de
## `Telegrafo.DURACAO_MINIMA` e aplicado por baixo.
@export var tempo_aviso: float = 1.2
## Quanto tempo a area machuca com dano CHEIO. Curta de proposito: o estouro e
## um instante, e quem segura o lugar depois dele e a residual.
@export var tempo_dano: float = 0.35
@export var dano: int = 1

@export_group("Residual")
## Quanto tempo a brasa fica depois do estouro. Zero desliga.
##
## Desligada por PADRAO, e isso e deliberado: a mesma cena serve a Rede de
## Exterminio e ao Colapso da Diretora, e o repertorio dela foi medido sem
## brasa nenhuma. Quem quer a zona residual liga -- hoje, so o Parasita, para
## quem ela e a razao de existir.
@export var tempo_residual: float = 0.0
## Dano por tique da brasa. Um, e um so: ela tem de cobrar ficar, nao matar.
@export var dano_residual: int = 1
## Espaco entre dois tiques da brasa.
##
## Nao e so tuning: dano continuo ENCADEIA hitstop e prende o jogo em camera
## lenta -- foi o que fez o feixe do Laser entregar 19 de dano onde o `.tres`
## pedia 26, porque ele atrasava a si mesmo. `Juice.INTERVALO_HITSTOP` ja poe um
## piso global de 120 ms, e este intervalo fica uma ordem de grandeza acima
## dele de proposito, para a brasa nunca chegar perto daquele limite.
@export var intervalo_residual: float = 0.55
@export var cor: Color = Color(0.55, 1.0, 0.45)

## Forma alternativa, em coordenadas LOCAIS. Vazia = circulo de `raio`.
##
## Existe para a Rede de Exterminio da Diretora, que precisa de FAIXA e nao de
## disco. Fica aqui em vez de virar uma segunda cena de perigo porque duas
## primitivas de telegrafo acabariam divergindo no detalhe que mais importa --
## quanto tempo o aviso dura antes de doer.
var poligono: PackedVector2Array = PackedVector2Array()

var fase: int = Fase.AVISO

var _forma: CollisionShape2D
var _visual: Polygon2D
var _borda: Line2D
var _telegrafo: Telegrafo
var _pontos: PackedVector2Array = PackedVector2Array()
var _feriu: bool = false
var _t_fase: float = 0.0
var _t_tique: float = 0.0
## Fica `true` no primeiro `configurar()`. Sem ele o aviso comecaria no `_ready`,
## quando a area ainda esta em (0,0) com o raio padrao -- a mesma armadilha que
## a `ExplosaoArea` documenta.
var _armada: bool = false


func _ready() -> void:
	collision_layer = LAYER_PROJ_INIMIGO
	collision_mask = LAYER_PLAYER
	# Desligado enquanto e so aviso. Ver decisao 5 no cabecalho.
	monitoring = false

	_forma = $Forma
	_visual = $Visual
	_borda = $Borda
	_visual.visible = false
	_borda.visible = false

	_telegrafo = Telegrafo.anexar(self)
	_telegrafo.cor = cor
	_telegrafo.largura_min = 1.5
	_telegrafo.largura_max = 3.5

	_montar()


## Constroi colisao e desenho a partir de `raio` ou de `poligono`.
##
## Separado do `_ready` porque `configurar()` pode mudar a geometria DEPOIS que
## o no ja entrou na arvore -- e era exatamente esse o defeito antigo: o `_ready`
## montava com o raio padrao, `configurar()` reatribuia o campo, e nada
## redesenhava. O raio novo nao tinha efeito nenhum, nem no desenho nem na
## colisao. Passava despercebido porque o unico chamador pedia 60 contra um
## default de 56.
func _montar() -> void:
	if poligono.size() >= 3:
		_pontos = poligono
		var convexo := ConvexPolygonShape2D.new()
		convexo.points = _pontos
		_forma.shape = convexo
	else:
		_pontos = _poligono(raio)
		var circulo := CircleShape2D.new()
		circulo.radius = raio
		_forma.shape = circulo

	_visual.polygon = _pontos
	_borda.points = _fechar(_pontos)
	_pintar(0.14, 0.5)


## Chamado por quem semeia, ANTES do add_child nao adianta: `global_position` so
## tem significado dentro da arvore. Quem semeia faz add_child e depois isto.
##
## E aqui, e nao no `_ready`, que o aviso ACENDE -- so aqui a area sabe onde
## esta e de que tamanho e. Isso tambem tira a exigencia antiga de escrever
## `tempo_aviso` antes do `add_child`.
func configurar(
	posicao: Vector2,
	raio_novo: float = -1.0,
	dano_novo: int = -1,
	poligono_novo: PackedVector2Array = PackedVector2Array()
) -> void:
	global_position = posicao
	var mudou_geometria := false
	if raio_novo > 0.0 and not is_equal_approx(raio_novo, raio):
		raio = raio_novo
		mudou_geometria = true
	if poligono_novo.size() >= 3:
		poligono = poligono_novo
		mudou_geometria = true
	if dano_novo > 0:
		dano = dano_novo
	if mudou_geometria:
		_montar()

	_armada = true
	fase = Fase.AVISO
	_t_fase = 0.0
	_telegrafo.cor = cor
	_telegrafo.acender(tempo_aviso)
	_telegrafo.forma(global_position, _pontos)


## O ciclo inteiro, contado a mao.
##
## Era um tween encadeado, e deixou de ser quando o aviso virou `Telegrafo`: as
## quatro fases precisam de um `avancar(delta)` por frame, e a brasa precisa de
## tiques. Um tween conduzindo metade disso e um `_process` conduzindo a outra
## metade daria dois relogios para o mesmo ataque.
func _physics_process(delta: float) -> void:
	if not _armada:
		return

	match fase:
		Fase.AVISO:
			if _telegrafo.avancar(delta) >= 1.0:
				_explodir()
		Fase.ESTOURO:
			_t_fase += delta
			if _t_fase >= tempo_dano:
				_entrar_no_residual()
		Fase.RESIDUAL:
			_t_fase += delta
			_pulsar_brasa()
			_t_tique -= delta
			if _t_tique <= 0.0:
				_t_tique = maxf(intervalo_residual, 0.05)
				_varrer_agora(dano_residual)
			if _t_fase >= tempo_residual:
				queue_free()


func _explodir() -> void:
	fase = Fase.ESTOURO
	_t_fase = 0.0
	_telegrafo.apagar()
	monitoring = true
	_visual.visible = true
	_borda.visible = true
	_pintar(0.65, 1.0)
	EventBus.pedido_shake.emit(1.8, 0.12)
	_varrer_agora(dano)


## Passa do estouro para a brasa -- ou some, se a brasa estiver desligada.
##
## O `_feriu` e zerado aqui de proposito: ele existe para o ESTOURO cobrar uma
## vez so, e mante-lo levantado deixaria a brasa inofensiva sem uma linha no
## console. Da brasa em diante quem espaca o dano e `intervalo_residual`, mais
## os i-frames de quem leva.
func _entrar_no_residual() -> void:
	if tempo_residual <= 0.0:
		queue_free()
		return
	fase = Fase.RESIDUAL
	_t_fase = 0.0
	_feriu = false
	# O primeiro tique da brasa vem DEPOIS de um intervalo cheio: cobrar no
	# instante em que o estouro acaba seria o estouro cobrando duas vezes.
	_t_tique = maxf(intervalo_residual, 0.05)
	_pintar(0.22, 0.55)


## A brasa respira. Ela nao pode parecer o estouro -- se parecer, o jogador le
## como "ainda vai doer muito" e nao chega perto, e a area vira parede em vez de
## pressao. E nao pode parecer chao limpo tambem.
func _pulsar_brasa() -> void:
	var onda := 0.5 + 0.5 * sin(_t_fase * 7.0)
	_pintar(lerpf(0.12, 0.26, onda), lerpf(0.35, 0.6, onda))


func _pintar(alfa_miolo: float, alfa_borda: float) -> void:
	_visual.color = Color(cor.r, cor.g, cor.b, alfa_miolo)
	_borda.default_color = Color(cor.r, cor.g, cor.b, alfa_borda)


## Pergunta ao servidor de fisica quem esta dentro AGORA.
##
## O corpo que ja esta dentro no instante da explosao nao dispara
## `body_entered` -- ele nao ENTROU, ele estava la. Sem esta varredura, ficar
## parado dentro do circulo e a forma mais segura de sobreviver a ele. E vale
## dobrado para a brasa, que so cobra de quem FICA.
##
## E tem de ser `intersect_shape` no espaco direto, NAO
## `get_overlapping_bodies()`: aquele responde com o estado do ultimo passo de
## fisica, e `monitoring` acabou de sair de `false` neste mesmo frame -- para o
## servidor esta area nao existia ainda, e a lista voltava VAZIA. A varredura
## estava aqui desde o inicio e nunca varreu ninguem. Mesma licao que
## `ExplosaoArea._varrer_agora()` ja tinha aprendido.
func _varrer_agora(quanto: int) -> void:
	var consulta := PhysicsShapeQueryParameters2D.new()
	consulta.shape = _forma.shape
	consulta.transform = Transform2D(0.0, global_position)
	consulta.collision_mask = collision_mask
	consulta.collide_with_areas = false
	consulta.collide_with_bodies = true
	for achado in get_world_2d().direct_space_state.intersect_shape(consulta, 8):
		_ferir(achado["collider"], quanto)


## Quem ENTRA na area durante o estouro leva na hora.
##
## Na brasa o sinal e ignorado: se ele valesse, atravessar a mancha custaria o
## mesmo que ficar parado nela, e a brasa existe justamente para separar as duas
## coisas. Quem passa correndo tem de conseguir passar.
func _on_body_entered(corpo: Node2D) -> void:
	if fase != Fase.ESTOURO:
		return
	_ferir(corpo, dano)


## O estouro fere UMA vez. Sem isso, entrar e sair na janela de dano cobraria
## duas vezes pelo mesmo ataque.
func _ferir(corpo: Node, quanto: int) -> void:
	if _feriu or not monitoring or quanto <= 0:
		return
	if not corpo.has_method("receber_dano"):
		return
	var no := corpo as Node2D
	if no == null:
		return
	var empurrao: Vector2 = (no.global_position - global_position).normalized() * 180.0
	if corpo.receber_dano(quanto, empurrao):
		# So o estouro trava. Na brasa quem espaca e o intervalo de tique.
		_feriu = fase == Fase.ESTOURO


func _poligono(r: float) -> PackedVector2Array:
	var pontos := PackedVector2Array()
	for i in LADOS:
		pontos.append(Vector2.RIGHT.rotated(TAU * float(i) / float(LADOS)) * r)
	return pontos


## O Line2D precisa repetir o primeiro ponto para fechar o desenho; o Polygon2D
## nao pode repetir. Por isso os dois nao compartilham o mesmo array -- e a
## mesma armadilha que `Sala.contorno_local()` documenta.
func _fechar(pontos: PackedVector2Array) -> PackedVector2Array:
	var saida := PackedVector2Array(pontos)
	if not saida.is_empty():
		saida.append(saida[0])
	return saida
