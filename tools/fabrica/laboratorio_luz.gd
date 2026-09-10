extends Node2D
## O LABORATORIO DE LUZ: as luminarias do andar 1 numa sala escura, e a regua
## que responde se aquilo le como ILUMINACAO ou como circulo de engine.
##
## ## As tres perguntas que este arquivo existe para responder
##
## 1. **A escuridao base ainda deixa ver?** O briefing pede luminancia global
##    reduzida e NAO pede preto: o jogador continua tendo de enxergar piso,
##    parede e obstaculo mesmo fora de qualquer poca. Um ambiente que "ficou
##    bonito" e engoliu o obstaculo nao da erro nenhum -- ele so mata o jogador
##    numa sala em que ele nao viu a caixa.
## 2. **A poca e LOCAL?** O que o andar quer e contraste entre escuridao e
##    bolsoes de luz. Raio grande demais ilumina a sala inteira e apaga o
##    contraste -- o mesmo defeito de "se tudo se mover, nada parece
##    importante", visto pelo lado da luz.
## 3. **A borda le como luz ou como disco?** Esta e a unica que nao se responde
##    olhando: **queda abrupta le como DISCO, queda suave le como ILUMINACAO**, e
##    a diferenca entre as duas e um numero -- quanto a luz perde por PIXEL perto
##    da borda. Se ela morre num degrau maior que um passo de 8 bits, o olho
##    encontra um contorno e ve um `PointLight2D`; se ela morre em fracoes de
##    passo espalhadas por dezenas de pixels, nao ha contorno para encontrar.
##
## ## O CONTROLE: um disco chapado, medido pela mesma regua
##
## Regua que nunca reprova e carimbo. Junto das luminarias de verdade, a regua
## mede uma queda em DEGRAU -- a luz "circulo de engine" que a secao 20 do
## briefing proibe -- e exige que ela REPROVE nos mesmos portoes. Sem o controle,
## os numeros do ambar seriam bonitos e nao provariam nada, porque ninguem
## saberia o que um numero ruim pareceria.
##
## ## A medicao e ANALITICA, e nao lida da tela
##
## Nada aqui e amostrado de um viewport renderizado, e isso e proposital em dois
## sentidos. Primeiro, e o que faz a regua rodar em `--headless`, onde nao existe
## GPU e `get_image()` nao devolve o que a tela mostraria. Segundo, a queda da
## luz JA E um dado exato: ela mora na rampa que `LuzDeFabrica` monta, e a regua
## le a rampa DAQUELE no -- nao uma copia dela escrita aqui. Copia diverge do
## codigo no primeiro ajuste, e a divergencia nao aparece no console.
##
## O unico ponto em que a composicao depende do renderizador esta declarado em
## `_atenuacao()`.
##
## ## DOIS MODOS, e o modo sai do `DisplayServer`
##
##   godot --path . tools/fabrica/laboratorio_luz.tscn --resolution 960x544
##     Com janela: a sala escura com as quatro luminarias -- ambar e frio, cada
##     uma estavel e instavel --, mais um marcador de ATOR para mostrar que a luz
##     nao o alcanca. Fotografa em `user://capturas/luz.png` e encerra.
##
##   godot --headless --path . tools/fabrica/laboratorio_luz.tscn
##     Sem janela: a luminancia do ambiente sem luz, a luminancia no centro de
##     cada poca, o raio efetivo, a borda, a amplitude e a repeticao do flicker,
##     e o sorteio de quantas acendem. Encerra com 1 se algo reprovar.
##
## ## OS BOTOES (secao 127), e por que eles sao argumentos e nao teclas
##
##   -- --ambiente=0.45 --energia-ambar=0.85 --raio-ambar=128 --raio-frio=64
##      --energia-frio=0.45 --flicker=0.70 --profundidade=0.35
##
## Tecla giraria o botao so no modo com janela, e ai o numero que se GIRA nunca
## seria o numero que se MEDE. Como argumento, a mesma invocacao serve as duas
## metades: gira-se com janela ate a foto ficar certa, roda-se o mesmo comando
## sem janela e a regua responde sobre exatamente aquilo. E o mesmo desenho do
## `tools/chefe/arena_chefe.tscn --hp=0.32`.
##
## Os botoes mexem em COPIAS dos perfis (`duplicate()`), nunca nos `.tres`: uma
## ferramenta de tuning que escreve no recurso carregado suja o estado do editor
## e some com o valor que estava la.
##
## ENCERRA EM TODO CAMINHO DE SAIDA: cena headless que nao encerra vira runaway.

const PERFIL_AMBAR := "res://src/fx/perfil_ambar.tres"
const PERFIL_FRIO := "res://src/fx/perfil_frio.tres"
const SAIDA := "user://capturas"

## A cor da luz geral: azul-cinza, nunca branca.
##
## O ambiente e um `CanvasModulate`, entao ele MULTIPLICA tudo que esta na tela.
## A tinta separa o escuro do andar 1 de um escuro neutro: com ela, o que sobra
## no fundo da sala e frio, e e contra esse frio que o ambar das luminarias le
## como quente. Multiplicar por cinza puro deixaria o andar sem temperatura, e a
## luz local teria de carregar sozinha a leitura de "fabrica velha".
const TINTA_DO_AMBIENTE := Color(0.78, 0.86, 1.0)

## Quanto do brilho original sobra depois do ambiente. O botao `--ambiente`.
const AMBIENTE_PADRAO := 0.45

## As superficies que a sala tem, e que o jogador precisa continuar separando no
## escuro. Sao valores da `Paleta`, e nao invencao desta ferramenta.
const SUPERFICIES: Array[Dictionary] = [
	{&"nome": "chao", &"neutro": &"N1"},
	{&"nome": "chao detalhe", &"neutro": &"N2"},
	{&"nome": "obstaculo", &"neutro": &"N4"},
	{&"nome": "parede corpo", &"neutro": &"N5"},
	{&"nome": "parede topo", &"neutro": &"N6"},
]

## O chao e a superficie contra a qual toda poca de luz e medida.
const NEUTRO_DO_CHAO := &"N1"

## Abaixo disto, uma superficie deixou de existir para o jogador.
##
## E luma linear, e o numero e o piso de "da para ver que ha alguma coisa ali"
## num monitor comum com o jogo em tela cheia. Ele nao e generoso de proposito:
## o briefing pede a sala ESCURA, e uma regua que exigisse conforto de leitura
## brigaria com o proprio alvo. O que ela impede e o preto -- o estado em que
## apagar a lampada apaga a arquitetura.
const PISO_DE_VISIBILIDADE := 0.012

## O degrau minimo entre o chao e o topo da parede, depois do ambiente.
##
## Ver a superficie nao basta: o jogador tem de SEPARAR piso de parede sem luz
## nenhuma, senao a sala vira uma mancha uniforme e a arquitetura so aparece
## debaixo das luminarias. Como o `CanvasModulate` multiplica, o CONTRASTE
## relativo entre as duas sobrevive intacto a qualquer ambiente -- o que o
## ambiente come e a diferenca ABSOLUTA, e e ela que o olho perde.
const DEGRAU_MINIMO := 0.035

## Um passo de 8 bits. Abaixo disto, uma diferenca nao existe na tela.
##
## Ele e a unidade dos dois numeros da borda: o raio EFETIVO da luz e onde ela
## deixa de somar um passo, e a queda na borda e quantos passos ela perde por
## pixel ali. Uma luz que perde menos de um passo por pixel nao tem contorno para
## o olho achar -- e nao ter contorno e a definicao operacional de "nao le como
## circulo de engine".
const PASSO_DE_8_BITS := 1.0 / 255.0

## O quanto a poca tem de ser mais clara que o ambiente para haver bolsao.
const GANHO_MINIMO := 3.0

## A luz nao pode vazar muito alem do raio declarado -- senao o `.tres` deixa de
## descrever o que aparece em tela.
const FOLGA_DO_RAIO := 1.05

## A borda tem de ocupar ao menos este tanto do raio, medida do ponto em que a
## luz cai a metade ate o ponto em que ela some.
##
## Sai da comparacao com o CONTROLE e nao de gosto: o disco chapado mede ~0,00 e
## a rampa do `LuzDeFabrica` mede bem acima de 0,50. 0,25 mora no vao entre os
## dois, longe das duas pontas.
const BORDA_MINIMA := 0.25

## O maximo que a luz pode perder por pixel na borda, em passos de 8 bits.
##
## **3,0 e nao 1,0, e a correcao veio da calibragem do brilho.** A queda ABSOLUTA
## por pixel escala com a energia: a mesma rampa, numa lampada mais forte, perde
## mais niveis por pixel sem ter mudado de FORMA. Com o teto em 1,0 -- escolhido
## quando a energia era 0,85 -- nenhuma lampada capaz de iluminar o chao passava,
## e o portao proibia a luz de existir em vez de proibir a borda dura.
##
## O numero sai da comparacao com o CONTROLE, que e o que a secao 20 do briefing
## de fato quer separar: o disco chapado mede **15,81** passos por pixel; o
## ambar calibrado mede **1,31** e o frio **1,48**. 3,0 fica cinco vezes abaixo
## do disco e com folga sobre os dois -- no vao entre as duas pontas, que e o
## mesmo criterio de `BORDA_MINIMA`.
##
## O que continua guardando a forma e `BORDA_MINIMA`, que e RELATIVA e por isso
## nao se move com o brilho.
const QUEDA_MAXIMA_NA_BORDA := 3.0

## Quanto se anda ao procurar o raio efetivo, em pixels.
const PASSO_DA_VARREDURA := 0.5

## O flicker, amostrado.
const SEGUNDOS_DE_FLICKER := 60.0
const AMOSTRAS_POR_SEGUNDO := 20.0

## Lags conferidos na varredura informativa, em segundos.
const LAG_MINIMO := 0.5
const LAG_MAXIMO := 20.0
const PASSO_DO_LAG := 0.1

## Quantos multiplos do periodo BASE o portao confere.
const MULTIPLOS_DO_PERIODO := 3

## Acima disto, o piscar SE REPETE no periodo que o perfil declara -- e periodo
## que o olho aprende e pulso ritmico, que e a assinatura de um efeito ligado por
## script.
##
## **O portao pergunta pelo periodo BASE e pelos primeiros multiplos dele, e nao
## pelo pico de uma varredura larga.** A soma de tres senos em razoes irracionais
## produz, ao longo de dezenas de segundos, coincidencias isoladas em que as tres
## fases quase se reencontram -- e um pico solitario num lag que ninguem compara
## nao e periodo, e acaso aritmetico. O que o olho de fato aprenderia e a
## frequencia que a luminaria declara: e ali que a senoide pura mede 1,00 e a
## soma das tres mede ~0,45, e e esse vao que este numero divide.
const TETO_DE_REPETICAO := 0.70

## Sementes do sorteio de estado, e a folga contra as chances declaradas.
##
## 400 sementes poem o desvio-padrao da fracao medida em ~2,3 pontos; 0,10 e
## quatro vezes isso, entao o portao morde uma chance trocada e nao o acaso.
const SEMENTES_DO_SORTEIO := 400
const FOLGA_DA_CHANCE := 0.10

## As camadas da cena de demonstracao, na numeracao de `Sala`.
##
## Elas sao copiadas com nome e nao lidas de `Sala` porque esta e uma sala de
## mentira -- nao ha `Sala` nenhuma aqui --, mas os numeros TEM de ser os do
## jogo: e justamente a relacao entre eles e o `range_z_max` da luz que a foto
## precisa provar. O marcador de ator fica em `Z_MUNDO`, acima do teto
## iluminado, e e por isso que a luz nao encosta nele.
const Z_CHAO := -20
const Z_CHAO_DETALHE := -18
const Z_PAREDE_FACE := -14
const Z_MUNDO := 0

const COR_ROTULO := Color(1.0, 1.0, 1.0, 0.80)

## Quantas afirmacoes a regua chegou a fazer. Impresso junto do resultado: um
## erro de dados faz o laco nao rodar, e uma saida verde que nao conferiu nada e
## pior que uma que reprova.
var _verificacoes: int = 0

## A camada onde os rotulos vivem, fora do alcance do `CanvasModulate`.
var _camada_dos_rotulos: CanvasLayer = null


func _ready() -> void:
	# Um frame antes de qualquer coisa, pelo mesmo motivo que o `runner.gd`:
	# `quit()` chamado de dentro do `_ready` nao encerra confiavelmente.
	await get_tree().process_frame
	var ambar := _perfil(PERFIL_AMBAR, "ambar")
	var frio := _perfil(PERFIL_FRIO, "frio")
	if ambar == null or frio == null:
		print("  perfil de luz ausente em src/fx/ -- nada a medir")
		get_tree().quit(1)
		return
	if DisplayServer.get_name() == "headless":
		_medir(ambar, frio)
		return
	_montar_sala(ambar, frio)
	await _fotografar()


# -- modo headless ----------------------------------------------------------


func _medir(ambar: PerfilDeLuz, frio: PerfilDeLuz) -> void:
	var falhas := 0
	var ambiente := _cor_do_ambiente()
	print("\n=== laboratorio de luz ===")
	print("  ambiente %.2f   ambar: energia %.2f raio %.0f   frio: energia %.2f raio %.0f"
		% [_numero("ambiente", AMBIENTE_PADRAO), ambar.energia, ambar.raio,
			frio.energia, frio.raio])

	falhas += _tabela_do_ambiente(ambiente)
	falhas += _tabela_das_pocas(ambar, frio, ambiente)
	falhas += _tabela_do_flicker(ambar, frio)
	falhas += _tabela_do_sorteio(ambar, frio)
	_encerrar(falhas)


## A sala SEM luz nenhuma: o que sobra depois do `CanvasModulate`.
func _tabela_do_ambiente(ambiente: Color) -> int:
	var falhas := 0
	print("\n--- o ambiente, sem uma luz sequer acesa ---\n")
	print("%-16s %10s %12s   %s" % ["superficie", "luma cru", "com ambiente", "leitura"])
	print("-".repeat(60))
	var chao := 0.0
	var topo := 0.0
	for superficie in SUPERFICIES:
		var crua: Color = Paleta.neutro(superficie[&"neutro"])
		var luma_com := _luma(crua * ambiente)
		var leitura := "visivel"
		if luma_com < PISO_DE_VISIBILIDADE:
			leitura = "SOME -- abaixo do piso de visibilidade"
		print("%-16s %10.4f %12.4f   %s"
			% [superficie[&"nome"], _luma(crua), luma_com, leitura])
		falhas += _cobrar(
			luma_com >= PISO_DE_VISIBILIDADE,
			"%s continua visivel no escuro (%.4f >= %.4f)"
				% [superficie[&"nome"], luma_com, PISO_DE_VISIBILIDADE])
		if superficie[&"neutro"] == NEUTRO_DO_CHAO:
			chao = luma_com
		if superficie[&"neutro"] == &"N6":
			topo = luma_com
	var degrau := topo - chao
	print("\n  degrau chao -> topo da parede: %.4f (minimo %.4f)" % [degrau, DEGRAU_MINIMO])
	falhas += _cobrar(
		degrau >= DEGRAU_MINIMO,
		"da para separar piso de parede sem luz nenhuma")
	return falhas


## Cada poca, e o CONTROLE ao lado delas.
func _tabela_das_pocas(ambar: PerfilDeLuz, frio: PerfilDeLuz, ambiente: Color) -> int:
	var falhas := 0
	var base := Paleta.neutro(NEUTRO_DO_CHAO) * ambiente
	print("\n--- as pocas de luz, sobre o chao a %.4f de luma ---\n" % _luma(base))
	print("%-10s %9s %8s %10s %9s %11s %8s" % [
		"luz", "no centro", "ganho", "raio efet.", "do raio", "borda", "queda/px",
	])
	print("-".repeat(74))

	var medidas: Array[Dictionary] = []
	medidas.append(_medir_poca("ambar", ambar, base, _rampa_de(ambar)))
	medidas.append(_medir_poca("frio", frio, base, _rampa_de(frio)))
	# O CONTROLE: a mesma cor e a mesma energia do ambar, com uma queda em
	# DEGRAU. Ele existe para reprovar -- ver o cabecalho.
	medidas.append(_medir_poca("DISCO", ambar, base, _rampa_de_disco()))

	for medida in medidas:
		print("%-10s %9.4f %7.1fx %9.0f px %8.2f %10.2f %7.2f" % [
			medida["nome"], medida["luma_no_centro"], medida["ganho"],
			medida["raio_efetivo"], medida["fracao_do_raio"],
			medida["borda"], medida["queda_por_pixel"] / PASSO_DE_8_BITS,
		])

	print("")
	for medida in medidas:
		var nome: String = medida["nome"]
		var controle := nome == "DISCO"
		var borda_ok := float(medida["borda"]) >= BORDA_MINIMA
		var queda_ok := float(medida["queda_por_pixel"]) <= \
			QUEDA_MAXIMA_NA_BORDA * PASSO_DE_8_BITS
		if controle:
			# O portao invertido. Se o disco chapado PASSAR, a regua nao mede o
			# que ela diz medir -- e todo numero acima dela vira decoracao.
			falhas += _cobrar(
				not borda_ok and not queda_ok,
				"o CONTROLE (disco chapado) reprova nos dois portoes de borda")
			continue
		falhas += _cobrar(borda_ok,
			"%s: a borda ocupa %.2f do raio (>= %.2f) -- nao le como disco"
				% [nome, medida["borda"], BORDA_MINIMA])
		falhas += _cobrar(queda_ok,
			"%s: perde %.2f passo(s) de 8 bits por pixel na borda (<= %.1f)"
				% [nome, float(medida["queda_por_pixel"]) / PASSO_DE_8_BITS,
					QUEDA_MAXIMA_NA_BORDA])
		falhas += _cobrar(float(medida["ganho"]) >= GANHO_MINIMO,
			"%s: a poca e %.1fx o ambiente (>= %.1fx) -- ha bolsao"
				% [nome, medida["ganho"], GANHO_MINIMO])
		falhas += _cobrar(float(medida["fracao_do_raio"]) <= FOLGA_DO_RAIO,
			"%s: a luz morre dentro do raio declarado (%.2f <= %.2f)"
				% [nome, medida["fracao_do_raio"], FOLGA_DO_RAIO])
		falhas += _cobrar(not bool(medida["compete"]),
			"%s: o centro da poca nao entra na faixa do ator" % nome)
	return falhas


## Uma poca, ponto a ponto, do centro para fora.
##
## O `raio efetivo` e onde a luz deixa de somar um passo de 8 bits: e ate ali
## que ela existe na tela, e nao ate o raio declarado. A `borda` e o trecho
## entre a metade do brilho e esse fim, como fracao do raio -- num disco ela e
## zero, porque a luz vale cheia ate sumir de uma vez.
func _medir_poca(
	nome: String, perfil: PerfilDeLuz, base: Color, rampa: Gradient
) -> Dictionary:
	var raio := maxf(perfil.raio, 1.0)
	var pico := _luma_somada(perfil, rampa, 0.0)
	var metade := pico * 0.5
	var raio_efetivo := 0.0
	var raio_da_metade := 0.0
	var d := 0.0
	while d <= raio * 1.5:
		var somado := _luma_somada(perfil, rampa, d / raio)
		if somado >= metade:
			raio_da_metade = d
		if somado >= PASSO_DE_8_BITS:
			raio_efetivo = d
		d += PASSO_DA_VARREDURA
	var antes := _luma_somada(perfil, rampa, (raio_efetivo - 1.0) / raio)
	var depois := _luma_somada(perfil, rampa, (raio_efetivo + 1.0) / raio)
	var centro := _compor(base, perfil, rampa, 0.0)
	var luma_da_base := maxf(_luma(base), 0.00001)
	return {
		"nome": nome,
		"luma_no_centro": _luma(centro),
		"ganho": _luma(centro) / luma_da_base,
		"raio_efetivo": raio_efetivo,
		"fracao_do_raio": raio_efetivo / raio,
		"borda": (raio_efetivo - raio_da_metade) / raio,
		"queda_por_pixel": absf(antes - depois) * 0.5,
		"compete": Paleta.compete_com_ator(centro),
	}


## O piscar: quanto ele varia, e se ele SE REPETE.
##
## `fator_do_flicker()` e publico e puro justamente para isto -- um piscar que
## zera, ou que pisca rapido demais, nao gera erro nenhum no console; ele so fica
## errado em tela, que e onde ninguem esta olhando quando a suite roda.
func _tabela_do_flicker(ambar: PerfilDeLuz, frio: PerfilDeLuz) -> int:
	var falhas := 0
	print("\n--- o flicker, em %.0f s a %.0f Hz ---\n"
		% [SEGUNDOS_DE_FLICKER, AMOSTRAS_POR_SEGUNDO])
	print("%-10s %8s %8s %11s %9s %12s %10s" % [
		"luz", "minimo", "maximo", "amplitude", "media", "no periodo", "pico",
	])
	print("-".repeat(76))

	var casos: Array[Dictionary] = []
	casos.append({&"nome": "ambar", &"perfil": ambar, &"amostras": _amostrar_flicker(ambar)})
	casos.append({&"nome": "frio", &"perfil": frio, &"amostras": _amostrar_flicker(frio)})
	# O CONTROLE do outro portao: uma senoide pura na frequencia base do ambar.
	# Ela e exatamente o que o `LuzDeFabrica` recusa a ser, e tem de reprovar.
	casos.append({&"nome": "SENOIDE", &"perfil": ambar, &"amostras": _amostrar_senoide(ambar)})

	for caso in casos:
		var amostras: PackedFloat32Array = caso[&"amostras"]
		var perfil_do_caso: PerfilDeLuz = caso[&"perfil"]
		var minimo := INF
		var maximo := -INF
		var soma := 0.0
		for valor in amostras:
			minimo = minf(minimo, valor)
			maximo = maxf(maximo, valor)
			soma += valor
		var media := soma / float(maxi(amostras.size(), 1))
		var repeticao := _repeticao_no_periodo(amostras, perfil_do_caso)
		# O pico da varredura larga sai como INFORMACAO e nao como portao: ver o
		# comentario de `TETO_DE_REPETICAO`.
		print("%-10s %8.3f %8.3f %11.3f %9.3f %12.3f %10.3f"
			% [caso[&"nome"], minimo, maximo, maximo - minimo, media, repeticao,
				_maior_repeticao(amostras)])
		if String(caso[&"nome"]) == "SENOIDE":
			falhas += _cobrar(
				repeticao > TETO_DE_REPETICAO,
				"o CONTROLE (senoide pura) reprova o portao de repeticao (%.3f > %.2f)"
					% [repeticao, TETO_DE_REPETICAO])
			continue
		falhas += _cobrar(
			minimo >= LuzDeFabrica.PISO_DO_FLICKER,
			"%s: o piscar nunca apaga (%.3f >= %.2f)"
				% [caso[&"nome"], minimo, LuzDeFabrica.PISO_DO_FLICKER])
		falhas += _cobrar(
			maximo <= 1.0001,
			"%s: o piscar nao passa da energia do perfil" % caso[&"nome"])
		falhas += _cobrar(
			maximo - minimo > 0.02,
			"%s: o piscar de fato pisca" % caso[&"nome"])
		falhas += _cobrar(
			repeticao <= TETO_DE_REPETICAO,
			"%s: nao se repete na propria frequencia (%.3f <= %.2f)"
				% [caso[&"nome"], repeticao, TETO_DE_REPETICAO])
	return falhas


## A correlacao do sinal consigo mesmo no periodo que o perfil DECLARA, e nos
## primeiros multiplos dele.
##
## Este e o lag que o olho teria como referencia: e a frequencia da luminaria.
## Uma senoide pura mede 1,00 aqui, em todos os multiplos; a soma de tres senos
## em razoes irracionais desmonta no primeiro deles.
func _repeticao_no_periodo(amostras: PackedFloat32Array, perfil: PerfilDeLuz) -> float:
	var velocidade := maxf(perfil.velocidade_do_flicker, 0.0001)
	var maior := 0.0
	for k in range(1, MULTIPLOS_DO_PERIODO + 1):
		var lag := float(k) / velocidade
		var passo := int(round(lag * AMOSTRAS_POR_SEGUNDO))
		if passo >= amostras.size() - 8:
			break
		maior = maxf(maior, _correlacao(amostras, passo))
	return maior


## Quantas acendem, quantas agonizam, quantas ficam apagadas.
##
## E a secao 17 do briefing lida como distribuicao, e nao como intencao: uma
## fabrica em que toda luz funciona nao esta abandonada, e uma em que nenhuma
## funciona nao tem infraestrutura nenhuma.
func _tabela_do_sorteio(ambar: PerfilDeLuz, frio: PerfilDeLuz) -> int:
	var falhas := 0
	print("\n--- o sorteio de estado, em %d sementes ---\n" % SEMENTES_DO_SORTEIO)
	print("%-10s %10s %12s %10s %12s" % [
		"luz", "ligadas", "declarado", "piscando", "declarado",
	])
	print("-".repeat(60))
	for perfil in [ambar, frio]:
		var sonda := LuzDeFabrica.new()
		sonda.perfil = perfil
		var ligadas := 0
		var instaveis := 0
		for i in SEMENTES_DO_SORTEIO:
			sonda.semear(20260908 + i * 7919)
			if sonda.ligada:
				ligadas += 1
			if sonda.instavel:
				instaveis += 1
		sonda.free()
		var fracao_ligada := float(ligadas) / float(SEMENTES_DO_SORTEIO)
		var fracao_instavel := float(instaveis) / float(SEMENTES_DO_SORTEIO)
		# Tipo EXPLICITO: `perfil` vem de um `for` sobre um Array sem tipo, entao
		# ele e Variant aqui e o produto nao tem tipo para o `:=` inferir.
		var esperada_instavel: float = (perfil.chance_de_estar_ligada * perfil.chance_de_instabilidade)
		print("%-10s %9.1f%% %11.1f%% %9.1f%% %11.1f%%" % [
			perfil.id, fracao_ligada * 100.0, perfil.chance_de_estar_ligada * 100.0,
			fracao_instavel * 100.0, esperada_instavel * 100.0,
		])
		falhas += _cobrar(
			absf(fracao_ligada - perfil.chance_de_estar_ligada) <= FOLGA_DA_CHANCE,
			"%s: a fracao acesa segue a chance declarada" % perfil.id)
		falhas += _cobrar(
			absf(fracao_instavel - esperada_instavel) <= FOLGA_DA_CHANCE,
			"%s: o piscar e um caso de ACESA, e na fracao declarada" % perfil.id)
	return falhas


# -- a fisica da poca, em numero --------------------------------------------


## A atenuacao da luz a `t` raios do centro, lida da rampa DAQUELE no.
##
## **O ponto em que isto depende do renderizador, declarado.** A rampa do
## `LuzDeFabrica` cai em RGB e em alfa juntos, e o pipeline 2D usa os dois -- se
## ele pre-multiplicar a cor pela propria alfa, a atenuacao real e o QUADRADO
## desta. A regua usa a alfa sozinha por ser o caso mais severo na borda (a alfa
## chega a zero mais depressa que o quadrado dela), entao um numero que passa
## aqui passa nos dois. A comparacao com o CONTROLE, que e o que a regua de fato
## afirma, nao se mexe em nenhuma das duas hipoteses.
func _atenuacao(rampa: Gradient, t: float) -> float:
	if rampa == null:
		return 0.0
	return rampa.sample(clampf(t, 0.0, 1.0)).a


## O que a luz ACRESCENTA, em luma, a `t` raios do centro.
func _luma_somada(perfil: PerfilDeLuz, rampa: Gradient, t: float) -> float:
	return _luma(perfil.cor * perfil.energia * _atenuacao(rampa, t))


## A cor final sobre uma base. A luz SOMA, e nao mistura -- e o que a fabrica
## acrescenta a escuridao, que e o `BLEND_MODE_ADD` que `LuzDeFabrica` liga.
func _compor(base: Color, perfil: PerfilDeLuz, rampa: Gradient, t: float) -> Color:
	var somada: Color = perfil.cor * perfil.energia * _atenuacao(rampa, t)
	return Color(
		minf(base.r + somada.r, 1.0),
		minf(base.g + somada.g, 1.0),
		minf(base.b + somada.b, 1.0)
	)


## A rampa que a luminaria de verdade usa -- pedida ao NO, e nao reescrita aqui.
func _rampa_de(perfil: PerfilDeLuz) -> Gradient:
	var luz := LuzDeFabrica.new()
	luz.perfil = perfil
	luz.aplicar_perfil()
	var textura := luz.texture as GradientTexture2D
	var rampa: Gradient = null
	if textura != null:
		rampa = textura.gradient
	luz.free()
	return rampa


## O CONTROLE: brilho cheio ate a borda, e zero depois dela.
func _rampa_de_disco() -> Gradient:
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.97, 1.0])
	rampa.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 1.0),
		Color(0.0, 0.0, 0.0, 0.0),
	])
	return rampa


func _amostrar_flicker(perfil: PerfilDeLuz) -> PackedFloat32Array:
	var luz := LuzDeFabrica.new()
	luz.perfil = perfil
	# Semeia so para fixar a FASE: `fator_do_flicker()` nao pergunta se a
	# luminaria acendeu, e o que se mede aqui e a forma da onda.
	luz.semear(20260908)
	var amostras := PackedFloat32Array()
	var total := int(SEGUNDOS_DE_FLICKER * AMOSTRAS_POR_SEGUNDO)
	for i in total:
		amostras.append(luz.fator_do_flicker(float(i) / AMOSTRAS_POR_SEGUNDO))
	luz.free()
	return amostras


## A senoide pura de controle, na mesma frequencia e profundidade do perfil.
func _amostrar_senoide(perfil: PerfilDeLuz) -> PackedFloat32Array:
	var amostras := PackedFloat32Array()
	var total := int(SEGUNDOS_DE_FLICKER * AMOSTRAS_POR_SEGUNDO)
	for i in total:
		var segundos := float(i) / AMOSTRAS_POR_SEGUNDO
		var onda := sin(segundos * perfil.velocidade_do_flicker * TAU)
		amostras.append(1.0 - perfil.profundidade_do_flicker * (1.0 - onda) * 0.5)
	return amostras


## A maior correlacao do sinal com ele mesmo deslocado no tempo.
##
## Perto de 1 significa que existe um LAG em que o sinal se repete -- e isso e
## exatamente o que o olho aprende e le como pulso ritmico. Lags abaixo de
## `LAG_MINIMO` sao ignorados porque todo sinal continuo se parece consigo mesmo
## um instante depois, e isso nao e periodo, e suavidade.
func _maior_repeticao(amostras: PackedFloat32Array) -> float:
	var n := amostras.size()
	if n < 8:
		return 0.0
	var maior := 0.0
	var lag := LAG_MINIMO
	while lag <= LAG_MAXIMO:
		var passo := int(lag * AMOSTRAS_POR_SEGUNDO)
		if passo >= n - 8:
			break
		maior = maxf(maior, _correlacao(amostras, passo))
		lag += PASSO_DO_LAG
	return maior


func _correlacao(amostras: PackedFloat32Array, deslocamento: int) -> float:
	var n := amostras.size() - deslocamento
	if n <= 1:
		return 0.0
	var media_a := 0.0
	var media_b := 0.0
	for i in n:
		media_a += amostras[i]
		media_b += amostras[i + deslocamento]
	media_a /= float(n)
	media_b /= float(n)
	var cruzado := 0.0
	var var_a := 0.0
	var var_b := 0.0
	for i in n:
		var da := amostras[i] - media_a
		var db := amostras[i + deslocamento] - media_b
		cruzado += da * db
		var_a += da * da
		var_b += db * db
	var denominador := sqrt(var_a * var_b)
	if denominador <= 0.00001:
		return 0.0
	return cruzado / denominador


func _luma(cor: Color) -> float:
	return cor.r * 0.2126 + cor.g * 0.7152 + cor.b * 0.0722


# -- modo com janela --------------------------------------------------------


## A sala escura: chao, parede, obstaculos, as quatro luminarias e um ator.
##
## As camadas nao sao arbitrarias -- elas sao a prova visual da decisao 1 do
## `LuzDeFabrica`. Chao, detalhe e parede vivem ABAIXO de `range_z_max`, entao a
## luz os alcanca; o marcador de ator vive em `Z_MUNDO`, acima do teto
## iluminado, e por isso ele tem o MESMO brilho dentro e fora da poca. Se um dia
## alguem subir aquele teto, e esta foto que muda.
func _montar_sala(ambar: PerfilDeLuz, frio: PerfilDeLuz) -> void:
	var quadro := get_viewport().get_visible_rect().size
	var ambiente := CanvasModulate.new()
	ambiente.color = _cor_do_ambiente()
	add_child(ambiente)

	_superficie(Rect2(Vector2.ZERO, quadro), Paleta.neutro(NEUTRO_DO_CHAO), Z_CHAO)
	# A faixa de parede em cima: topo e face, os dois valores que o jogador tem
	# de continuar separando do piso no escuro.
	_superficie(Rect2(0.0, 0.0, quadro.x, 72.0), Paleta.neutro(&"N6"), Z_PAREDE_FACE)
	_superficie(Rect2(0.0, 72.0, quadro.x, 32.0), Paleta.neutro(&"N5"), Z_PAREDE_FACE)

	var luzes: Array[Dictionary] = [
		{&"perfil": ambar, &"instavel": false, &"rotulo": "ambar estavel"},
		{&"perfil": ambar, &"instavel": true, &"rotulo": "ambar INSTAVEL"},
		{&"perfil": frio, &"instavel": false, &"rotulo": "frio estavel"},
		{&"perfil": frio, &"instavel": true, &"rotulo": "frio INSTAVEL"},
	]
	var passo := quadro.x / float(luzes.size())
	for i in luzes.size():
		var caso: Dictionary = luzes[i]
		var perfil: PerfilDeLuz = caso[&"perfil"]
		var centro := Vector2(passo * (float(i) + 0.5), quadro.y * 0.58)
		# Um obstaculo DEBAIXO de cada poca e outro FORA dela: e a comparacao que
		# responde a pergunta 1 -- o que a caixa parece iluminada, e o que ela
		# parece so com o ambiente.
		_superficie(
			Rect2(centro + Vector2(-56.0, -76.0), Vector2(40.0, 40.0)),
			Paleta.neutro(&"N4"), Z_CHAO_DETALHE)
		_superficie(
			Rect2(Vector2(passo * float(i) + 12.0, quadro.y - 96.0), Vector2(40.0, 40.0)),
			Paleta.neutro(&"N4"), Z_CHAO_DETALHE)

		var luz := LuzDeFabrica.new()
		luz.perfil = perfil
		luz.position = centro
		luz.semear(_semente_com_estado(perfil, bool(caso[&"instavel"])))
		add_child(luz)
		_rotulo(Vector2(passo * float(i) + 8.0, 118.0), caso[&"rotulo"])
		_rotulo(
			Vector2(passo * float(i) + 8.0, 130.0),
			"raio %.0f  energia %.2f" % [perfil.raio, perfil.energia])

	# O ATOR: em `Z_MUNDO`, fora do alcance da luz de proposito.
	var ator := Rect2(Vector2(passo * 0.5 - 10.0, quadro.y * 0.58 - 10.0), Vector2(20.0, 20.0))
	_superficie(ator, Color(0.55, 0.97, 1.0), Z_MUNDO)
	_rotulo(ator.position + Vector2(-40.0, 24.0), "ator (a luz nao alcanca)")

	_rotulo(Vector2(8.0, 8.0),
		"ambiente %.2f -- e a escuridao base; as pocas sao o que a fabrica acrescenta"
			% _numero("ambiente", AMBIENTE_PADRAO))
	_rotulo(Vector2(8.0, quadro.y - 20.0),
		"botoes: -- --ambiente= --energia-ambar= --raio-ambar= --raio-frio= "
			+ "--energia-frio= --flicker= --profundidade=")


## Uma semente que produz o estado pedido, procurada com a propria API do no.
##
## O estado de uma luminaria e SORTEIO, e nao campo que se escreve: `_ready()`
## re-sorteia a partir da semente e desfaria qualquer coisa atribuida por fora.
## Entao a foto nao forca o estado, ela procura a semente que o produz -- e como
## o sorteio e deterministico, aquela luminaria vai estar assim toda vez que
## alguem rodar esta cena.
func _semente_com_estado(perfil: PerfilDeLuz, quer_instavel: bool) -> int:
	var sonda := LuzDeFabrica.new()
	sonda.perfil = perfil
	var escolhida := 0
	for i in 4096:
		var semente := 20260908 + i * 7919
		sonda.semear(semente)
		if sonda.ligada and sonda.instavel == quer_instavel:
			escolhida = semente
			break
	sonda.free()
	return escolhida


func _superficie(onde: Rect2, cor: Color, camada: int) -> void:
	var retangulo := ColorRect.new()
	retangulo.color = cor
	retangulo.position = onde.position
	retangulo.size = onde.size
	retangulo.z_index = camada
	add_child(retangulo)


## `Label` e nao `Label2D`: este build do Godot nao tem o segundo, e cena de
## ferramenta que nao PARSEIA fica pendurada para sempre.
##
## Os rotulos moram numa `CanvasLayer` PROPRIA, e nao ao lado da sala. O
## `CanvasModulate` escurece o canvas inteiro em que ele vive -- inclusive
## texto --, e uma foto cuja legenda esta a 45% de brilho e uma foto que nao se
## le. A camada separada e o mesmo motivo pelo qual a HUD do jogo nao e filha do
## mundo.
func _rotulo(onde: Vector2, texto: String) -> void:
	if _camada_dos_rotulos == null:
		_camada_dos_rotulos = CanvasLayer.new()
		add_child(_camada_dos_rotulos)
	var etiqueta := Label.new()
	etiqueta.text = texto
	etiqueta.position = onde
	etiqueta.add_theme_font_size_override("font_size", 10)
	etiqueta.modulate = COR_ROTULO
	_camada_dos_rotulos.add_child(etiqueta)


func _fotografar() -> void:
	if _tem("--ficar"):
		return
	# O flicker le relogio de parede, entao a foto sai um instante DEPOIS do
	# nascimento das luzes: no frame zero as instaveis ainda estao no topo da
	# onda e a foto nao mostraria diferenca nenhuma entre elas e as estaveis.
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(SAIDA)
	var caminho := "%s/luz.png" % SAIDA
	get_viewport().get_texture().get_image().save_png(caminho)
	print("capturado: %s" % ProjectSettings.globalize_path(caminho))
	get_tree().quit()


# -- os botoes --------------------------------------------------------------


## O perfil de disco com os botoes aplicados por cima, numa COPIA.
func _perfil(caminho: String, chave: String) -> PerfilDeLuz:
	var original := ResourceLoader.load(caminho) as PerfilDeLuz
	if original == null:
		return null
	var copia := original.duplicate() as PerfilDeLuz
	copia.energia = _numero("energia-%s" % chave, copia.energia)
	copia.raio = _numero("raio-%s" % chave, copia.raio)
	copia.velocidade_do_flicker = _numero("flicker", copia.velocidade_do_flicker)
	copia.profundidade_do_flicker = _numero("profundidade", copia.profundidade_do_flicker)
	return copia


func _cor_do_ambiente() -> Color:
	var intensidade := _numero("ambiente", AMBIENTE_PADRAO)
	return Color(
		TINTA_DO_AMBIENTE.r * intensidade,
		TINTA_DO_AMBIENTE.g * intensidade,
		TINTA_DO_AMBIENTE.b * intensidade
	)


## Le de `get_cmdline_user_args()` -- o que vem DEPOIS do `--` --, que e o unico
## lugar onde um argumento nosso nao briga com uma opcao do proprio Godot.
func _numero(chave: String, padrao: float) -> float:
	var prefixo := "--%s=" % chave
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with(prefixo):
			return float(argumento.substr(prefixo.length()))
	return padrao


func _tem(bandeira: String) -> bool:
	return OS.get_cmdline_user_args().has(bandeira)


# -- relatorio --------------------------------------------------------------


func _cobrar(condicao: bool, descricao: String) -> int:
	_verificacoes += 1
	if condicao:
		return 0
	print("    [FALHA] %s" % descricao)
	return 1


func _encerrar(falhas: int) -> void:
	print("\n--- resultado ---")
	print("  %d verificacao(oes)" % _verificacoes)
	if _verificacoes <= 0:
		print("  FALHOU: a regua nao chegou a conferir nada")
		get_tree().quit(1)
		return
	if falhas > 0:
		print("  FALHOU: %d problema(s)" % falhas)
		get_tree().quit(1)
		return
	print("  PASSOU")
	get_tree().quit()
