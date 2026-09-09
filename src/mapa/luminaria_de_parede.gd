class_name LuminariaDeParede
extends Node2D
## A LUMINARIA INDUSTRIAL presa na parede: a peca que a luz sai de dentro.
##
## Ela existe por causa da secao 92 do briefing, que e categorica: *"luzes devem
## ser associadas a FIXTURES. Nao spawnar `PointLight2D` aleatorio no chao."* Uma
## poca de luz sem lampada visivel le como efeito de engine -- o jogador ve o
## chao aceso e nada acendendo. Com a carcaca desenhada, ele ve uma lampada
## velha ainda funcionando, que e a frase inteira do andar 1.
##
## **Ela e o primeiro consumidor do `DecoradorDeSala.Porte.PAREDE`**, e nao por
## acaso: luminaria industrial e exatamente o que aquele porte descreve -- peca
## que ancora na FACE e quase nao entra no chao. O porte nasceu da referencia
## (`docs/fabrica_01.png`), onde as lampadas estao todas na parede, e ficou sem
## consumidor ate aqui.
##
## ## Por que ela e DESENHADA e nao um sprite
##
## Nao ha arte de luminaria ainda -- ela vem no `[FAB 24]`. Desenhar a carcaca em
## `_draw` e o mesmo caminho que a `BancadaDeOferta`, a ficha de credito e a
## `ReacaoDeArena` ja seguem: forma chapada e legivel enquanto a arte nao chega,
## e um lugar so para troca-la depois. O alternativo -- esperar a arte para ter
## luz -- deixaria o `AmbienteDaFabrica` escurecendo o jogo sem nada devolver,
## que e justamente o estado que este arquivo existe para desfazer.
##
## ## O que ela NAO faz
##
## Ela nao tem colisao e nao entra na lista de ocupados do chao. Ela esta na
## PAREDE: um prop de piso pode ficar embaixo dela sem conflito, do mesmo jeito
## que o Foreground passa por cima de uma caixa.

## A carcaca desenha em `Z_CHAO_DETALHE`, junto dos props chapados e ABAIXO de
## `Z_MUNDO`. Isso e garantia geometrica e nao escolha de gosto: zero e a faixa
## do telegrafo, do projetil e dos atores, e uma luminaria ali poderia cair na
## frente do aviso que torna um ataque justo.
##
## A LUZ e outra coisa -- ela nao desenha forma, ela ilumina o que ja esta
## desenhado --, entao ela nao disputa faixa nenhuma.
const Z_CARCACA := -2

const LARGURA := 18.0
const ALTURA := 7.0

## O REFLEXO no piso molhado, e ele desenha NO CHAO -- nao na carcaca.
##
## `Z_CHAO_DETALHE` da `Sala`, copiado como literal pelo mesmo motivo do
## `Z_CARCACA`: um `const` aqui e um numero que alguem le, e importar a camada de
## mapa para desenhar um efeito seria pior. Quem cruza os dois e
## `teste_luz.gd`.
const Z_REFLEXO := -18

## Quanto o risco desce a partir da lampada, e o comprimento dele.
##
## Ele e ALTO e ESTREITO de proposito: na referencia o reflexo de uma luminaria
## no piso molhado e um risco vertical alongado, e nao uma poca redonda. Poca
## redonda ja existe -- e a propria luz. Repetir a mesma forma duas vezes nao
## acrescenta molhado, acrescenta brilho.
const REFLEXO_DESCIDA := 26.0
const REFLEXO_LARGURA := 14.0
const REFLEXO_COMPRIMENTO := 96.0

## Quao forte o risco aparece.
##
## **Baixo, e esse e o ponto todo.** O briefing pede reflexo "que nao precisa ser
## real" (secao 101), e a regra da casa e que efeito que compete com a leitura do
## combate e efeito cortado. O risco existe para dizer "o piso esta molhado", e
## nao para iluminar: quem ilumina e a `LuzDeFabrica`.
const REFLEXO_ALFA := 0.16

## Cores da carcaca. Metal escuro da `Paleta` (N4/N5), copiadas como literal
## porque `src/` nao pode referenciar `tools/texturas/paleta.gd` -- ele fica FORA
## do export, e o jogo le textura pronta e nunca a paleta.
const COR_CORPO := Color(0.19, 0.22, 0.29)
const COR_SUPORTE := Color(0.14, 0.16, 0.21)
## O vidro APAGADO. A lampada acesa nao pinta o vidro de branco: quem diz que ela
## esta acesa e a luz que sai dela. Vidro chapado de claro competiria com
## projetil por ser exatamente isto -- um ponto pequeno e brilhante.
const COR_VIDRO_APAGADO := Color(0.10, 0.11, 0.14)

## Quanto o vidro clareia quando a lampada esta acesa. Baixo de proposito: e um
## indicio, e nao uma fonte. O teto vem da mesma regra que limita o alfa do
## efeito de fase do chefe.
const CLARAO_DO_VIDRO := 0.45

var _luz: LuzDeFabrica = null
var _reflexo: Sprite2D = null

## A rampa do risco, compartilhada.
static var _risco: GradientTexture2D = null
var _acesa: bool = false
var _cor_da_luz: Color = Color.WHITE


## Monta a luminaria com um perfil e uma semente.
##
## A SEMENTE e obrigatoria e vem do lugar: uma lampada que sorteia se esta
## acesa a cada visita a sala pisca quando o jogador volta, e isso le como
## defeito e nao como vida. Mesma razao que faz o `DecoradorDeSala` recusar
## `randi()` global.
func configurar(perfil: PerfilDeLuz, semente: int) -> void:
	if perfil == null:
		return
	_cor_da_luz = perfil.cor
	_luz = LuzDeFabrica.new()
	_luz.perfil = perfil
	_luz.semear(semente)
	add_child(_luz)
	# Lido DEPOIS do `add_child`: e o `_ready` da luz que sorteia o estado.
	_acesa = _luz.ligada
	if _acesa:
		_montar_reflexo()
	queue_redraw()


## O risco de luz no piso molhado.
##
## Ele e um `Sprite2D` proprio e nao um traco no `_draw` desta classe por causa
## do Z: a carcaca mora em `Z_CARCACA` (-2) e o reflexo tem de morar no CHAO
## (-18). Desenhados juntos, o risco passaria por cima de qualquer prop que
## estivesse entre a lampada e o piso -- e reflexo que cobre caixa nao le como
## reflexo, le como mancha.
##
## `z_as_relative = false` porque o pai ja carrega o z da carcaca: sem isso os
## dois numeros somariam e o risco subiria para -20.
##
## Ele NAO pisca junto com a lampada instavel, e isso e escolha. Movimento no
## cenario compete com movimento de PROJETIL -- e a lampada ja pisca. Dois
## elementos piscando em fase no mesmo lugar dobram o movimento sem dobrar a
## informacao.
func _montar_reflexo() -> void:
	_reflexo = Sprite2D.new()
	_reflexo.texture = _textura_do_risco()
	_reflexo.z_index = Z_REFLEXO
	_reflexo.z_as_relative = false
	_reflexo.position = Vector2(0.0, REFLEXO_DESCIDA + REFLEXO_COMPRIMENTO * 0.5)
	var tex := _reflexo.texture.get_size()
	_reflexo.scale = Vector2(
		REFLEXO_LARGURA / maxf(tex.x, 1.0),
		REFLEXO_COMPRIMENTO / maxf(tex.y, 1.0))
	# ADD e nao MIX: o risco e luz REFLETIDA, e luz soma. Misturado, ele
	# clarearia o piso como tinta e apagaria a textura embaixo.
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_reflexo.material = mat
	_reflexo.modulate = Color(_cor_da_luz.r, _cor_da_luz.g, _cor_da_luz.b, REFLEXO_ALFA)
	add_child(_reflexo)


## A rampa do risco: forte no alto, sumindo embaixo.
##
## Compartilhada por todas as luminarias -- uma textura por lampada seriam
## dezenas de gradientes iguais, pela mesma razao que `LuzDeFabrica` compartilha
## a queda dela.
##
## A queda e VERTICAL: o risco nasce logo abaixo da lampada e se dissolve
## descendo, que e o que a agua faz. Um gradiente simetrico leria como uma
## barra flutuando.
static func _textura_do_risco() -> GradientTexture2D:
	if _risco != null:
		return _risco
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	rampa.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(0.55, 0.55, 0.55, 0.55),
		Color(0.0, 0.0, 0.0, 0.0),
	])
	var t := GradientTexture2D.new()
	t.gradient = rampa
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	t.width = 16
	t.height = 64
	_risco = t
	return _risco


func _ready() -> void:
	z_index = Z_CARCACA
	queue_redraw()


func _draw() -> void:
	# O SUPORTE, que e o que prende a peca na parede. Sem ele a carcaca flutua, e
	# "a luz tem de ter de onde sair" vale tambem para o metal.
	draw_rect(Rect2(-3.0, -ALTURA - 3.0, 6.0, 4.0), COR_SUPORTE)

	# A carcaca: um trapezio, mais larga embaixo. E o formato de refletor
	# industrial, e ele diz para onde a luz vai sem precisar de arte.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-LARGURA * 0.35, -ALTURA),
		Vector2(LARGURA * 0.35, -ALTURA),
		Vector2(LARGURA * 0.5, 0.0),
		Vector2(-LARGURA * 0.5, 0.0),
	]), COR_CORPO)

	# O vidro. Aceso ele puxa para a cor da propria luz, e nao para branco: duas
	# lampadas de temperaturas diferentes tem de continuar diferentes na peca,
	# senao a ambar e a fria viram a mesma luminaria com poças de cor distinta.
	var vidro := COR_VIDRO_APAGADO
	if _acesa:
		vidro = COR_VIDRO_APAGADO.lerp(_cor_da_luz, CLARAO_DO_VIDRO)
	draw_rect(Rect2(-LARGURA * 0.38, -1.5, LARGURA * 0.76, 2.5), vidro)


## Esta lampada acendeu? Publico porque o portao conta quantas acenderam numa
## sala sem precisar reproduzir o sorteio.
func acesa() -> bool:
	return _acesa


## Tem risco de reflexo no chao? Publico porque o portao afirma a regra -- so
## lampada ACESA molha o piso -- sem reproduzir o sorteio.
func tem_reflexo() -> bool:
	return _reflexo != null and is_instance_valid(_reflexo)
