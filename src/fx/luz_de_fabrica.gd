class_name LuzDeFabrica
extends PointLight2D
## Uma luminaria do andar 1: acesa, apagada ou agonizando, decidido por sorteio.
##
## Ela carrega TRES decisoes que nao se enxergam lendo so o `PerfilDeLuz`.
##
## **1. A luz para ABAIXO do combate, e isso e geometrico.** `range_z_max` fica
## em `Z_TETO_ILUMINADO`, um degrau abaixo de `Sala.Z_MUNDO` -- a faixa onde
## desenham telegrafo, projetil e atores. Entao a luz alcanca o chao, o detalhe
## de chao, a face e o topo da parede, e **nao alcanca nada que o jogador precise
## ler para sobreviver**. Um inimigo nao fica mais claro por estar sob a
## lampada, um projetil nao muda de cor ao cruzar a poca, e o disco do telegrafo
## nunca e lavado por ela. E a mesma ideia que poe `PropAnimado` em
## `Z_CHAO_DETALHE`: transformar "nao atrapalha a leitura do combate" numa
## garantia de camada em vez de numa intencao de quem monta a sala.
##
## **2. O sorteio e DETERMINISTICO por semente.** Uma luminaria que esta acesa
## quando o jogador entra, apagada quando ele volta e piscando na terceira visita
## nao le como fabrica velha -- le como bug. E o sorteio nao passa pelo RNG
## global de proposito: as luzes de uma sala nascem no meio da montagem do andar,
## e consumir do fluxo global deslocaria todo sorteio seguinte (composicao,
## props, decalque) so por existirem mais lampadas naquela sala. Cada luz tem o
## proprio `RandomNumberGenerator`, semeado por `semear()` -- e sem semente
## explicita a semente sai da POSICAO dela, que e estavel dentro de um andar.
##
## **3. O piscar le RELOGIO DE PAREDE, e nao o delta da arvore.** O `Juice`
## congela `Engine.time_scale` para dar peso ao impacto (hitstop), e uma luz que
## trava junto denuncia o truque: o jogador ve o mundo INTEIRO parar e entende
## que aquilo e um efeito, em vez de sentir um impacto. `PropAnimado` e
## `InimigoBase.INTERVALO_FLASH` ficam fora do `Juice` pelo mesmo motivo.
##
## O renderer e Compatibility (GL) e o alvo inclui a web: nao ha shader aqui,
## nao ha `SCREEN_TEXTURE` e nao ha sombra projetada. O que existe e uma
## `PointLight2D` somando uma queda radial suave.

## O teto da faixa iluminada. Um degrau abaixo de `Sala.Z_MUNDO` (que e 0).
##
## Escrito aqui e nao lido de `Sala` porque `src/fx/` nao deve depender da camada
## de mapa para desenhar um efeito -- mas a duplicata NAO fica solta: quem cruza
## os dois numeros e `tools/testes/teste_luz.gd`, do mesmo jeito que
## `MATIZ_POR_TIPO` vive em dois arquivos com um portao cobrando os dois.
const Z_TETO_ILUMINADO := -1

## O piso do piscar, como fracao da energia do perfil.
##
## `const` e nao `@export`: apagar por completo e reacender le como falha de
## renderizacao, e um numero ajustavel seria ajustado para zero na primeira vez
## que alguem achasse o efeito bonito. Mesma razao de
## `Porta.TEMPO_DE_ABERTURA` e de `Telegrafo.DURACAO_MINIMA`.
const PISO_DO_FLICKER := 0.35

## As tres frequencias do piscar, em razao da base.
##
## **Senoide pura esta proibida aqui**: um seno unico le como PULSO RITMICO, e
## pulso ritmico e a assinatura de um efeito ligado por script -- exatamente o
## que a secao 20 do briefing pede para evitar ("o jogador deve perceber luz no
## ambiente, e nao um circulo de engine"). Somando tres senos em razoes
## IRRACIONAIS entre si (1, 1/phi, 1/phi ao cubo) a soma nunca se repete: nao ha
## periodo que o olho possa aprender, e o que sobra e uma oscilacao lenta que as
## vezes afunda mais -- que e como um reator de lampada velha se comporta.
const RAZAO_B := 0.6180339887
const RAZAO_C := 0.2360679775

## A queda radial e compartilhada por TODAS as luzes, e o `raio` do perfil vira
## `texture_scale`. Uma textura por luminaria seria dezenas de gradientes iguais
## em memoria para uma diferenca que a escala ja resolve.
const RESOLUCAO_DA_QUEDA := 128
const RAIO_DA_QUEDA := 64.0

@export var perfil: PerfilDeLuz = null

## Se esta luminaria acendeu. Escrito pelo sorteio; publico para quem monta a
## sala poder decidir, por exemplo, se vale desenhar o prop de lampada quebrada.
var ligada: bool = false

## Se ela pisca. Sempre falso quando `ligada` e falso -- lampada apagada nao
## pisca, ela so esta apagada.
var instavel: bool = false

var _semente: int = 0
var _semeada: bool = false
var _fase: float = 0.0
var _ms_inicial: int = 0

static var _queda: GradientTexture2D = null


func _ready() -> void:
	_ms_inicial = Time.get_ticks_msec()
	aplicar_perfil()
	if not _semeada:
		_semente = _semente_do_lugar()
	# Re-sorteia SEMPRE, mesmo ja semeada: `semear()` pode ter sido chamado
	# antes de `perfil` ser atribuido, e ali as chances ainda eram zero -- a
	# luminaria nasceria apagada para sempre, sem uma linha no console. Como a
	# semente e fixa, sortear de novo devolve o mesmo estado: e idempotente de
	# proposito, e e isso que tira a ordem das chamadas do caminho critico.
	_sortear()


## Semeia o sorteio desta luminaria e re-sorteia na hora.
##
## Publica e chamavel ANTES do `add_child`: quem monta a sala ja tem uma semente
## por celula, e passar a mesma semente na mesma celula e o que faz a lampada da
## sala 4 estar apagada hoje e apagada tambem quando o jogador voltar por ela.
func semear(valor: int) -> void:
	_semente = valor
	_semeada = true
	_sortear()


## Escreve o perfil na `PointLight2D`. Chamada pelo `_ready`, e publica para
## quem trocar o perfil em runtime nao precisar remontar o no.
func aplicar_perfil() -> void:
	if perfil == null:
		return
	texture = _textura_de_queda()
	texture_scale = maxf(perfil.raio, 1.0) / RAIO_DA_QUEDA
	color = perfil.cor
	energy = perfil.energia
	# Somar e nao misturar: a luz e o que a fabrica ACRESCENTA a escuridao base.
	blend_mode = Light2D.BLEND_MODE_ADD
	# Sombra projetada exigiria occluder por parede e desenha aresta dura --
	# aresta dura e justamente o "circulo de engine" da secao 20.
	shadow_enabled = false
	range_z_min = -1024
	range_z_max = Z_TETO_ILUMINADO


## A energia da luz no instante pedido, em segundos desde que ela nasceu.
##
## Pura e publica porque e a unica parte disto que da para PROVAR sem subir o
## jogo: um piscar que zera, ou que pisca rapido demais, nao gera erro nenhum no
## console -- ele so fica errado em tela, que e onde ninguem esta olhando quando
## a suite roda.
func energia_no_instante(segundos: float) -> float:
	if perfil == null or not ligada:
		return 0.0
	if not instavel:
		return perfil.energia
	return perfil.energia * fator_do_flicker(segundos)


## O multiplicador do piscar, sempre entre `PISO_DO_FLICKER` e 1.
func fator_do_flicker(segundos: float) -> float:
	if perfil == null:
		return 1.0
	var w := segundos * perfil.velocidade_do_flicker * TAU
	# A fase entra com multiplos DIFERENTES em cada componente: com a mesma fase
	# nos tres, duas luminarias com sementes vizinhas comecariam a bater juntas.
	var onda := (
		sin(w + _fase)
		+ sin(w * RAZAO_B + _fase * 2.0)
		+ sin(w * RAZAO_C + _fase * 3.0)
	) / 3.0
	var fator := 1.0 - perfil.profundidade_do_flicker * (1.0 - onda) * 0.5
	return maxf(fator, PISO_DO_FLICKER)


func _process(_delta: float) -> void:
	# Relogio de PAREDE, nao delta da arvore -- ver o cabecalho, decisao 3.
	var segundos := float(Time.get_ticks_msec() - _ms_inicial) / 1000.0
	energy = energia_no_instante(segundos)


func _sortear() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _semente
	# Um saque descartado antes dos que importam. Sementes vizinhas comecam com
	# estados vizinhos no PCG, e a PRIMEIRA saida e a mais proxima de ser
	# correlacionada entre elas -- duas luminarias lado a lado, semeadas por
	# celulas consecutivas, acenderiam juntas mais vezes do que a chance diz. O
	# defeito nao apareceria em erro nenhum, so num corredor de lampadas em
	# fase.
	rng.randf()
	var chance_ligada := 0.0
	var chance_instavel := 0.0
	if perfil != null:
		chance_ligada = perfil.chance_de_estar_ligada
		chance_instavel = perfil.chance_de_instabilidade
	# A ORDEM destes tres saques e contrato: trocar dois de lugar muda o estado
	# de toda luminaria do jogo sem mudar uma unica chance, e o sintoma seria uma
	# fabrica com outra cara depois de um refactor que "nao mexeu em nada".
	ligada = rng.randf() < chance_ligada
	instavel = ligada and rng.randf() < chance_instavel
	_fase = rng.randf() * TAU
	_aplicar_estado()


func _aplicar_estado() -> void:
	enabled = ligada
	if perfil != null:
		energy = perfil.energia
	# Luminaria estavel nao tem o que atualizar. Uma fabrica inteira de lampadas
	# acesas custaria um `_process` por soquete para escrever o mesmo numero.
	set_process(ligada and instavel)


## Semente de reserva, para quem esquecer de semear.
##
## Sai da POSICAO e nao de um contador: posicao e estavel dentro do andar, entao
## a lampada volta ao mesmo estado quando o jogador reentra na sala -- que e a
## unica coisa que este sorteio precisa garantir.
func _semente_do_lugar() -> int:
	var p := global_position
	return hash(Vector2i(roundi(p.x), roundi(p.y)))


static func _textura_de_queda() -> GradientTexture2D:
	if _queda != null:
		return _queda
	var rampa := Gradient.new()
	# Quatro paradas, e nenhuma delas e uma rampa reta ate a borda. Rampa reta
	# deixa uma quebra de derivada no fim, e o olho le essa quebra como o
	# CONTORNO de um disco -- o "circulo evidente de PointLight2D" da secao 20.
	# A curva aqui cai depressa perto do nucleo e encosta em zero devagar.
	rampa.offsets = PackedFloat32Array([0.0, 0.25, 0.55, 1.0])
	rampa.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(0.62, 0.62, 0.62, 0.62),
		Color(0.22, 0.22, 0.22, 0.22),
		Color(0.0, 0.0, 0.0, 0.0),
	])
	var textura := GradientTexture2D.new()
	textura.gradient = rampa
	textura.fill = GradientTexture2D.FILL_RADIAL
	textura.fill_from = Vector2(0.5, 0.5)
	textura.fill_to = Vector2(1.0, 0.5)
	textura.width = RESOLUCAO_DA_QUEDA
	textura.height = RESOLUCAO_DA_QUEDA
	_queda = textura
	return _queda
