class_name FormasProjetil
extends RefCounted
## A silhueta de um projetil: "que familia ele e" -> "que poligono desenhar".
##
## Isolada aqui pelo mesmo motivo da Balistica e das Direcoes: e a peca mais
## facil de errar, a que menos avisa quando quebra, e a unica parte da aparencia
## de um projetil que da para conferir SEM SUBIR CENA. Uma familia que devolve
## poligono vazio nasce invisivel com a hitbox intacta -- o pior defeito possivel
## num bullet hell, e nao ha uma linha no console.
##
## Ela existe porque as 21 armas do jogo desenhavam A MESMA FORMA. `cor` e
## `raio` eram a unica variacao, e isso deixou dois pares de armas literalmente
## indistinguiveis (`rail_x`/`gravity_gun` e `onda_guardiao`/`sucata_guardiao`,
## RGB identico) mais oito pares a menos de 15 graus de matiz. A `Paleta` ja
## dizia a saida com todas as letras -- "armas da mesma faixa se separam pela
## FORMA (raio e rastro)" -- e nada implementava.
##
## MORA EM `src/util/` E NUNCA EM `tools/`. `tools/` esta no `exclude_filter` do
## `export_presets.cfg`: uma biblioteca ali roda no editor e SOME na build, e a
## maquina de quem desenvolve nunca mostra. Esta parece uma ferramenta e nao e --
## e a mesma armadilha que o `RenderizadorParedes.N1` ja pagou.


## As familias. **Valor novo entra sempre NO FIM.**
##
## O valor e gravado como INT no `.tres`, entao inserir no meio reescreve em
## silencio o significado de toda arma ja salva -- mesma armadilha de
## `DadosArma.Comportamento` e de `DadosItem`.
##
## E LOSANGO tem de continuar sendo ZERO: os 21 `.tres` nao tem a propriedade e
## carregam o default do script. Um default diferente de zero trocaria a forma
## das 21 de uma vez, sem uma linha no console.
enum Familia {
	LOSANGO,   ## O tiro comum. E a forma que TODA arma tinha antes deste epico.
	CAPSULA,   ## Tracante curto e rombudo: metralhadora, pellet, enxame.
	AGULHA,    ## Dardo longo: sniper, perfurante, tiro muito rapido.
	ESFERA,    ## Massa redonda: granada, plasma, "isto e pesado".
	ORBE,      ## Esfera com halo: gravidade, "isto tem campo".
	CLUSTER,   ## Fragmentos disjuntos: nanite, sucata.
	ETEREO,    ## Translucido de borda quebrada: phase, "isto atravessa".
	ARCO,      ## Faixa curva larga: onda de choque, pisao.
}

## Lados de uma familia redonda.
##
## Doze e nao os 24 do `Telegrafo`: aquele desenha um disco de aviso de 60 a 200
## px, e este desenha um corpo de 6 a 32. Num raio de 3 px, 24 lados e mais
## vertice do que pixel -- e o renderer Compatibility nao tem MSAA 2D para
## aproveitar nenhum dos dois.
const LADOS_REDONDO := 12

## Molduras de arte, em pixels, no eixo LATERAL.
##
## Retangular de proposito: a lateral sai do `raio` porque e ela que o portao de
## coerencia amarra a hitbox; o comprimento e LIVRE, porque no eixo do voo a arte
## pode avancar o quanto quiser (o proprio losango avanca 2,4 raios, e e assim
## que ele le direcao).
##
## Multiplos de 8 e nao de 16: a grade de 16 e do LADRILHO (`assets/texturas/`),
## e projetil nao ladrilha.
##
## GEMEA da tabela de molduras de `tools/sprites/gerar_projeteis.py`, e as duas
## mudam juntas -- mesma obrigacao que `MOLDURAS` e `Direcoes.MOLDURAS_DE_ATOR`
## ja carregam, e pela mesma razao: divergentes, o funil produz o que o portao
## recusa, e o erro so aparece depois de a arte estar em disco.
const LATERAIS: Array[int] = [8, 16, 32]

## Teto do halo, em multiplos do raio, e teto do alfa dele.
##
## O halo desenha ALEM da hitbox de proposito -- ele e brilho e nao corpo. E por
## isso ele e limitado nos dois eixos: grande demais ou opaco demais, o jogador
## passa a ler a borda dele como a area que fere, e o projetil volta a mentir por
## outro caminho. Mesma ideia do `alpha_maximo` do shader de glitch.
const HALO_MAXIMO := 2.0
const HALO_ALFA := 0.30

## Quanto ETEREO deixa passar. E o unico valor de alfa que nao e 1.
const ALFA_ETEREO := 0.55


## O contorno, em coordenadas LOCAIS, com +X sendo o eixo do voo.
##
## Duas invariantes valem para TODA familia, e sao elas que o portao cobra:
##
##   1. o contorno CONTEM `(0, -raio)` e `(0, +raio)` -- nunca desenha MENOS do
##      que fere;
##   2. `max |y| <= raio` sobre todo vertice -- nunca desenha MAIS do que fere.
##
## As duas sao sobre o eixo LATERAL, e so ele: e de lado que o jogador esquiva.
## No eixo do voo a forma e livre, e errar para mais ali e generoso -- o losango
## avanca 2,4 raios justamente para ler direcao.
##
## `alongamento` multiplica SO o x. Nao e descuido: alongar no y quebraria a
## invariante 2 em silencio, e a lateral e a metade que nao pode mentir.
static func contorno(familia: int, raio: float, alongamento: float = 1.0) -> PackedVector2Array:
	var r := maxf(raio, 0.5)
	var pontos: PackedVector2Array
	match familia:
		Familia.CAPSULA: pontos = _capsula(r)
		Familia.AGULHA: pontos = _agulha(r)
		Familia.ESFERA, Familia.ORBE: pontos = _redondo(r)
		Familia.CLUSTER: pontos = _cluster(r)
		Familia.ETEREO: pontos = _etereo(r)
		Familia.ARCO: pontos = _arco(r)
		_: pontos = _losango(r)
	if is_equal_approx(alongamento, 1.0):
		return pontos
	var e := maxf(alongamento, 0.05)
	var esticado := PackedVector2Array()
	esticado.resize(pontos.size())
	for i in pontos.size():
		esticado[i] = Vector2(pontos[i].x * e, pontos[i].y)
	return esticado


## Os sub-poligonos, para as familias feitas de pedacos soltos.
##
## `Polygon2D.polygons` desenha varios blobes disjuntos a partir de UMA lista de
## vertices, e e o que resolve o CLUSTER sem no novo -- o que mata a tentacao de
## uma cena de projetil por familia. Vazio = o contorno inteiro e uma peca so,
## que e o caso de sete das oito.
##
## A PRIMEIRA ilha e sempre o corpo principal, e e nela que os dois pontos
## laterais moram. Sem essa regra, "o contorno contem (0, +-raio)" deixaria de
## ter sentido numa familia de pedacos.
static func ilhas(familia: int, _raio: float, _alongamento: float = 1.0) -> Array[PackedInt32Array]:
	var fora: Array[PackedInt32Array] = []
	if familia != Familia.CLUSTER:
		return fora
	fora.append(PackedInt32Array([0, 1, 2, 3, 4, 5]))
	fora.append(PackedInt32Array([6, 7, 8]))
	fora.append(PackedInt32Array([9, 10, 11]))
	return fora


## O halo, ou vazio quando a familia nao tem.
##
## Desenhado num no FILHO do `Visual` com `z_index = -1`, e nao irmao: o
## `_aplicar_glitch()` do projetil escreve `_visual.position`, e o halo tem de
## tremer JUNTO -- irmao, o projetil se partiria em dois na Deterioracao alta.
static func halo(familia: int, raio: float) -> PackedVector2Array:
	if familia != Familia.ORBE:
		return PackedVector2Array()
	return _redondo(maxf(raio, 0.5) * HALO_MAXIMO)


## A opacidade do nucleo. So ETEREO desce de 1.
static func alfa(familia: int) -> float:
	return ALFA_ETEREO if familia == Familia.ETEREO else 1.0


## A familia existe? O `.tres` guarda um INT, e um valor fora da faixa -- digitado
## a mao, ou sobrevivente de um enum que encolheu -- carrega sem erro nenhum.
static func existe(familia: int) -> bool:
	return Familia.values().has(familia)


static func nome(familia: int) -> StringName:
	var chaves := Familia.keys()
	if familia < 0 or familia >= chaves.size():
		return &"?"
	return StringName(chaves[familia])


## A moldura lateral que cabe um projetil deste raio. A escala em jogo e SEMPRE
## 1 -- escala de pixel art e inteira, e 64 para 96 borra mesmo com Nearest.
static func lateral_de(raio: float) -> int:
	var preciso := int(ceil(maxf(raio, 0.5) * 2.0))
	for lado in LATERAIS:
		if lado >= preciso:
			return lado
	return LATERAIS[LATERAIS.size() - 1]


# -- As familias ------------------------------------------------------------
#
# Toda uma delas poe vertice EXATO em (0, -r) e (0, +r). E o jeito barato de
# garantir a invariante 1: ponto que e vertice esta no poligono por construcao,
# sem depender de o resto da forma o envolver nem de arredondamento.


## O losango de sempre, byte a byte.
##
## As proporcoes 2,4 na frente e 1,6 atras nao sao estetica: sao o que fazia o
## tiro LER DIRECAO sem nenhuma outra pista. Mudar isto muda a aparencia de toda
## arma que ainda nao escolheu familia -- e enquanto o epico nao acabar, sao
## quase todas.
static func _losango(r: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r * 2.4, 0.0),
		Vector2(0.0, -r),
		Vector2(-r * 1.6, 0.0),
		Vector2(0.0, r),
	])


static func _capsula(r: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r * 1.7, 0.0),
		Vector2(r * 1.35, -r * 0.72),
		Vector2(0.0, -r),
		Vector2(-r * 1.0, -r * 0.72),
		Vector2(-r * 1.3, 0.0),
		Vector2(-r * 1.0, r * 0.72),
		Vector2(0.0, r),
		Vector2(r * 1.35, r * 0.72),
	])


static func _agulha(r: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r * 4.2, 0.0),
		Vector2(r * 2.6, -r * 0.42),
		Vector2(0.0, -r),
		Vector2(-r * 1.4, -r * 0.46),
		Vector2(-r * 2.0, 0.0),
		Vector2(-r * 1.4, r * 0.46),
		Vector2(0.0, r),
		Vector2(r * 2.6, r * 0.42),
	])


## O circulo, com vertice cravado em cima e embaixo.
##
## `LADOS_REDONDO` e par, entao os indices de 90 e 270 graus caem exatos e os
## dois pontos laterais sao vertices de verdade -- nao dependem de tolerancia de
## ponto flutuante para satisfazer a invariante 1.
static func _redondo(r: float) -> PackedVector2Array:
	var pontos := PackedVector2Array()
	pontos.resize(LADOS_REDONDO)
	for i in LADOS_REDONDO:
		var a := TAU * float(i) / float(LADOS_REDONDO)
		pontos[i] = Vector2(cos(a) * r, sin(a) * r)
	return pontos


## Tres pedacos: um corpo e dois estilhacos. Os indices sao contrato com
## `ilhas()` -- 0..5 o corpo, 6..8 e 9..11 os cacos.
static func _cluster(r: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r * 1.15, -r * 0.30),
		Vector2(0.0, -r),
		Vector2(-r * 0.75, -r * 0.62),
		Vector2(-r * 1.05, r * 0.10),
		Vector2(0.0, r),
		Vector2(r * 0.85, r * 0.45),

		Vector2(r * 2.05, -r * 0.90),
		Vector2(r * 2.55, -r * 0.30),
		Vector2(r * 1.75, -r * 0.15),

		Vector2(r * 1.85, r * 0.55),
		Vector2(r * 2.60, r * 0.70),
		Vector2(r * 1.95, r * 0.95),
	])


## A borda quebrada: os degraus dizem "isto nao e solido" pela FORMA, e nao so
## pelo alfa -- em grayscale o alfa quase some e a silhueta tem de continuar
## falando sozinha.
static func _etereo(r: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r * 1.9, 0.0),
		Vector2(r * 1.1, -r * 0.35),
		Vector2(r * 1.25, -r * 0.78),
		Vector2(r * 0.45, -r * 0.60),
		Vector2(0.0, -r),
		Vector2(-r * 0.95, -r * 0.55),
		Vector2(-r * 0.70, -r * 0.15),
		Vector2(-r * 1.55, r * 0.20),
		Vector2(-r * 0.60, r * 0.50),
		Vector2(0.0, r),
		Vector2(r * 0.80, r * 0.52),
		Vector2(r * 1.15, r * 0.30),
	])


## A onda: as pontas ANCORAM em (0, +-r) e ela boja para a FRENTE.
##
## Uma onda quer ser larga na perpendicular, e e justamente isso que a invariante
## 2 proibe. A saida nao e isentar a familia -- e faze-la crescer para onde o eixo
## e livre. Arma que quer uma onda mais larga sobe `raio_projetil`, e ai a hitbox
## acompanha, que e honesto. `onda_guardiao` ja esta em raio 16, o maior do jogo.
static func _arco(r: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, -r),
		Vector2(r * 1.05, -r * 0.72),
		Vector2(r * 1.55, 0.0),
		Vector2(r * 1.05, r * 0.72),
		Vector2(0.0, r),
		Vector2(r * 0.30, r * 0.60),
		Vector2(r * 0.72, 0.0),
		Vector2(r * 0.30, -r * 0.60),
	])
