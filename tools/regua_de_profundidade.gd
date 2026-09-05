class_name ReguaDeProfundidade
extends RefCounted
## As duas reguas do §49 e do §50: a sala sobrevive a miniatura e ao grayscale?
##
## Ela mora aqui, e nao dentro de uma das cenas de captura, porque DUAS ferramentas
## precisam da mesma resposta -- `teste_paredes.tscn` mede a sala retangular de
## perto e `formas_paredes.tscn` mede as nove formas e o corredor. Duas copias
## divergiriam, e a divergencia apareceria como uma forma "passando" numa
## ferramenta e "reprovando" na outra sem ninguem ter mudado arte nenhuma.
##
## Ela vive em `tools/` de proposito -- ela mede CAPTURA, e captura e coisa de
## ferramenta. Vale o de sempre: `tools/` esta no `exclude_filter`, entao nada de
## `src/` pode depender disto.
##
## O METODO: uma coluna de pixels dentro da sala atravessa, de cima para baixo,
## exterior -> topo -> face -> piso. Se as quatro leem como valores separaveis e
## AFASTADOS, a cavidade existe.
##
## Quatro armadilhas ja foram pagas aqui, e todas eram a regua medindo a coisa
## errada -- as quatro passariam despercebidas:
##
## 1. **Contar transicao nao e contar superficie.** A primeira versao devolvia 81:
##    contava a borda de cada placa do piso.
## 2. **A coluna do meio atravessa a PORTA**, que nasce centrada no lado.
## 3. **As fracoes eram da IMAGEM e nao da SALA.** A sala nao preenche o quadro --
##    ha exterior em volta, que e o ponto --, entao colunas caiam no vazio.
## 4. **A contagem sozinha e um CARIMBO.** Medido em A/B trocando so as texturas:
##    a arte de ANTES do epico tambem devolvia quatro patamares, porque 0,039 de
##    distancia passa de raspao do degrau minimo. A regua aprovava exatamente a
##    imagem que abriu o epico. Quem separa sala rasa de sala funda e a
##    AMPLITUDE: 0,192 antes, 0,388 depois.


## O degrau minimo para dois patamares contarem como superficies diferentes.
## Gemeo do `PASSO_MINIMO` de `teste_profundidade.gd`: o menor degrau da rampa de
## neutros da `Paleta`. Abaixo dele a propria paleta nao considera que houve cor
## nova.
const DEGRAU := 0.036

## Quantos pixels um valor precisa SUSTENTAR para contar como superficie. Abaixo
## disto e detalhe: rebite, junta, contorno de placa.
const ALTURA_DE_PATAMAR := 8

## Quantas superficies distintas a coluna tem de atravessar: exterior,
## arquitetura e piso.
const PATAMARES_MINIMOS := 3

## A distancia minima entre a superficie mais clara e a mais escura. Ver a
## armadilha 4 no cabecalho -- e este numero que faz a regua morder.
const AMPLITUDE_MINIMA := 0.25

## Colunas amostradas, em fracao da largura. Fogem do meio porque a porta nasce
## centrada no lado, e ficam dentro da sala porque a sala nao preenche o quadro.
const COLUNAS: Array[float] = [0.30, 0.38, 0.62, 0.70]


## Mede uma captura e devolve `{superficies, superficies_25, amplitude, passou}`.
static func medir(imagem: Image) -> Dictionary:
	if imagem == null or imagem.is_empty():
		return {"superficies": 0, "superficies_25": 0, "amplitude": 0.0, "passou": false}
	var cheia := _medianos(imagem, 1)
	var reduzida := _medianos(_reduzir(imagem, 4), 4)
	var amplitude := _amplitude(imagem)
	return {
		"superficies": cheia,
		"superficies_25": reduzida,
		"amplitude": amplitude,
		"passou": (cheia >= PATAMARES_MINIMOS and reduzida >= PATAMARES_MINIMOS
			and amplitude >= AMPLITUDE_MINIMA),
	}


## Uma linha de relatorio, no formato que as duas ferramentas imprimem.
static func relatar(nome: String, medida: Dictionary) -> String:
	var selo := "ok" if medida["passou"] else "REPROVA"
	return "  %-28s %d superficies, a 25%% %d, amplitude %.3f  [%s]" % [
		nome, medida["superficies"], medida["superficies_25"],
		medida["amplitude"], selo,
	]


static func _medianos(imagem: Image, escala: int) -> int:
	var contagens: Array[int] = []
	for fracao in COLUNAS:
		contagens.append(_na_coluna(imagem, int(imagem.get_width() * fracao), escala))
	contagens.sort()
	return contagens[contagens.size() / 2]


## Quantos PATAMARES de valor a coluna atravessa.
##
## A coluna e SUAVIZADA antes. Sem isso a parede texturizada nunca sustenta um
## patamar: ela tem ~57% de densidade, entao o valor oscila mais que o degrau a
## cada poucos pixels e a superficie se dissolve em ruido. O olho integra a
## distancia; a regua tem de integrar tambem, senao ela reprova justamente a
## superficie que TEM material.
static func _na_coluna(imagem: Image, x: int, escala: int) -> int:
	var altura := imagem.get_height()
	var suave := _suavizar(imagem, x, maxi(9 / escala, 3))
	var minimo := maxi(ALTURA_DE_PATAMAR / escala, 2)

	var patamares: Array[float] = []
	var inicio := 0
	var soma := 0.0
	var referencia := suave[0]
	for y in altura + 1:
		var v := suave[mini(y, altura - 1)]
		if y < altura and absf(v - referencia) < DEGRAU:
			soma += v
			continue
		var comprimento := y - inicio
		if comprimento >= minimo:
			patamares.append(soma / maxf(float(comprimento), 1.0))
		inicio = y
		soma = v
		referencia = v

	# Dois patamares do mesmo valor sao a MESMA superficie vista duas vezes -- o
	# exterior aparece em cima e embaixo.
	var distintos: Array[float] = []
	for p in patamares:
		var novo := true
		for d in distintos:
			if absf(p - d) < DEGRAU:
				novo = false
				break
		if novo:
			distintos.append(p)
	return distintos.size()


static func _amplitude(imagem: Image) -> float:
	var maior := 0.0
	for fracao in COLUNAS:
		var suave := _suavizar(imagem, int(imagem.get_width() * fracao), 9)
		var alto := 0.0
		var baixo := 1.0
		for v in suave:
			alto = maxf(alto, v)
			baixo = minf(baixo, v)
		maior = maxf(maior, alto - baixo)
	return maior


## Mediana movel: ela ignora o rebite isolado sem arrastar a borda da superficie,
## que e o que uma media faria.
static func _suavizar(imagem: Image, x: int, janela: int) -> Array[float]:
	var altura := imagem.get_height()
	var coluna := clampi(x, 0, imagem.get_width() - 1)
	var cru: Array[float] = []
	for y in altura:
		cru.append(imagem.get_pixel(coluna, y).v)
	var suave: Array[float] = []
	for i in altura:
		var a := maxi(0, i - janela / 2)
		var b := mini(altura, i + janela / 2 + 1)
		var fatia := cru.slice(a, b)
		fatia.sort()
		suave.append(fatia[fatia.size() / 2])
	return suave


## Media de area, que e o que o olho faz de longe -- e o que uma miniatura faz.
static func _reduzir(imagem: Image, fator: int) -> Image:
	var menor := imagem.duplicate() as Image
	menor.resize(maxi(imagem.get_width() / fator, 1), maxi(imagem.get_height() / fator, 1),
		Image.INTERPOLATE_LANCZOS)
	return menor
