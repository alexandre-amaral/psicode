extends TesteBase
## O sistema de luz da fabrica: os dois perfis e as travas do `LuzDeFabrica`.
##
## Por que isto e suite e nao conferencia de olho: **nenhum defeito de luz gera
## erro no console**. Um `raio` zerado por esquecimento e uma luminaria
## invisivel; uma cor trocada entre os dois `.tres` e uma fabrica ciano que
## carrega, roda e passa em tudo; um piscar rapido demais e um estrobo que so
## aparece quando alguem esta jogando -- e o `--headless` do CI nunca olha para
## a tela. Todo caso aqui existe porque a alternativa e descobrir em playtest.
##
## Ela le `tools/texturas/paleta.gd`, o que **so uma suite pode fazer**: a
## Paleta mora em `tools/` e fica fora do export. Nada em `src/fx/` a
## referencia -- o jogo carrega perfil pronto, e quem cobra a fronteira e este
## arquivo.

const AMBAR := "res://src/fx/perfil_ambar.tres"
const FRIO := "res://src/fx/perfil_frio.tres"

## Secao 96: so 10 a 20% das LIGADAS piscam. Piscar e movimento, e movimento no
## cenario compete com movimento de projetil.
const PISO_INSTABILIDADE := 0.10
const TETO_INSTABILIDADE := 0.20

## O ambar do briefing e uma familia de 27 a 36 graus; o frio e azul-ciano.
const FAIXA_QUENTE := Vector2(20.0, 55.0)
const FAIXA_FRIA := Vector2(170.0, 230.0)

## "Lento, nunca estroboscopico" virado numero: quantas vezes por segundo a
## energia pode cruzar a propria media. Duas travessias fecham um ciclo, entao
## 4 por segundo e um teto de 2 Hz -- ja acima do que o olho le como oscilacao
## e bem abaixo do que ele le como estrobo.
const TETO_CRUZAMENTOS_POR_SEGUNDO := 4.0

## E o outro lado da mesma trava: uma luz declarada instavel que NAO se mexe
## passaria no teto de cima sem nunca ter piscado.
const PISO_CRUZAMENTOS := 2

const JANELA_S := 20.0
const PASSOS := 4000

## Sementes bem espalhadas em vez de 0,1,2,...: o que se mede aqui e a
## distribuicao, e sementes vizinhas nao sao a pergunta.
const AMOSTRAS_DE_SEMENTE := 600
const PASSO_DE_SEMENTE := 2654435761
const TOLERANCIA_DE_FRACAO := 0.12


## O valor medio do chao do andar 1, medido em `chao_andar1_a.png`.
const VALOR_DO_CHAO := 0.12

## A luminosidade do `AmbienteDaFabrica`. Gemea do default daquele `@export`, e
## as duas mudam juntas -- uma copia que envelhece faria este portao medir um
## ambiente que o jogo nao usa.
const AMBIENTE_DA_RUN := 0.75

## Quanto a poca precisa somar ao chao para CONTAR como acesa, em luma
## RENDERIZADA. Sem este piso o caso vira so um teto, e teto sozinho aprova a
## luz apagada -- que foi literalmente o estado anterior desta suite.
const GANHO_MINIMO_DA_POCA := 0.08

## Quanto de luma RENDERIZADA a luz soma ao chao por unidade de `cor.v * energia`.
##
## **Este numero foi MEDIDO no motor, e nao derivado.** A conta ingenua
## (`chao + cor.v * energia`) superestima o resultado em mais de dez vezes,
## porque ela ignora duas coisas: o `CanvasModulate` multiplica a contribuicao
## da luz junto com o resto, e a queda radial mais o `blend_mode` atenuam o
## centro. Enquanto o portao usava aquela conta, ele prendia a lampada em
## `energia 0,55` -- e o andar inteiro ficava sem poca nenhuma, com a suite
## verde.
##
## A medicao foi uma varredura de energia com o chao no `Z_CHAO` real e o
## ambiente em 0,45, lendo o pixel do centro:
##
##     energia 0,55 -> centro 0,0879   (fundo 0,0509)
##     energia 1,20 -> centro 0,1335
##     energia 2,00 -> centro 0,1881
##     energia 3,00 -> centro 0,2582
##     energia 4,50 -> centro 0,3635
##
## O delta sobre `cor.v * energia` da 0,086 / 0,088 / 0,088 / 0,088 / 0,0887 --
## **linear**, e por isso uma constante serve.
##
## **Ela envelhece com o ambiente e com a queda.** Mexeu em
## `AmbienteDaFabrica.luminosidade` ou na rampa de `LuzDeFabrica`? Meca de novo:
## uma constante de transferencia herdada de outro regime e um modelo errado com
## cara de medicao.
const FATOR_DE_RENDER := 0.088


func nome() -> String:
	return "Luz de fabrica"


func executar() -> void:
	_os_dois_perfis_carregam_e_nenhum_campo_ficou_em_zero()
	_o_ambar_e_QUENTE_e_o_frio_e_FRIO()
	_nenhuma_luz_compete_com_ator()
	_o_flicker_nunca_zera_a_energia()
	_o_flicker_nao_e_estroboscopico()
	_o_sorteio_e_deterministico_por_semente()
	_so_lampada_ACESA_molha_o_piso()
	_a_luz_para_abaixo_da_faixa_do_combate()


## Pega: campo esquecido no `.tres`.
##
## Um `raio` ou uma `energia` em zero e uma luz que carrega, entra na arvore,
## desenha nada e nao reclama -- a sala fica escura e parece decisao de arte. E
## `chance_de_estar_ligada` em zero seria um andar inteiro sem uma lampada
## acesa, com os cinco `.tres` intactos em disco.
func _os_dois_perfis_carregam_e_nenhum_campo_ficou_em_zero() -> void:
	for caminho in [AMBAR, FRIO]:
		var perfil := load(caminho) as PerfilDeLuz
		ok(perfil != null, "%s carrega como PerfilDeLuz" % caminho)
		if perfil == null:
			continue
		ok(perfil.id != &"", "%s tem id" % caminho)
		entre(perfil.raio, 48.0, 160.0, "%s: raio dentro das secoes 94/95" % perfil.id)
		# O teto e 6,0 e nao 1,0, e a correcao veio de MEDIR. `Light2D.energy` nao
		# e uma fracao: ela e um multiplicador aditivo, e valores acima de 1 sao
		# normais. O 1,0 daqui era suposicao -- a secao 94 do briefing pede
		# "energia moderada" sem numero -- e ela prendia a lampada num valor em
		# que o andar inteiro ficava sem poca. O que este caso existe para pegar
		# e campo ESQUECIDO EM ZERO, e o piso continua fazendo isso.
		entre(perfil.energia, 0.05, 6.0, "%s: energia declarada" % perfil.id)
		entre(perfil.chance_de_estar_ligada, 0.05, 1.0,
			"%s: chance de estar ligada declarada" % perfil.id)
		entre(perfil.velocidade_do_flicker, 0.05, 2.0,
			"%s: velocidade do flicker declarada e lenta" % perfil.id)
		entre(perfil.profundidade_do_flicker, 0.05, 1.0,
			"%s: profundidade do flicker declarada" % perfil.id)
		perto(perfil.cor.a, 1.0, "%s: a cor e opaca" % perfil.id)
		# Secao 96, virada portao: instabilidade nao e botao livre.
		entre(perfil.chance_de_instabilidade, PISO_INSTABILIDADE, TETO_INSTABILIDADE,
			"%s: so 10 a 20%% das ligadas piscam (secao 96)" % perfil.id)


## Pega: os dois arquivos trocados de lugar, ou um matiz que escorregou.
##
## Nada mais reclamaria. O jogo carregaria o frio como luz de lampada e o andar
## inteiro ficaria ciano -- que e exatamente o defeito que o briefing abriu
## pedindo para corrigir, chegando pelo outro lado.
func _o_ambar_e_QUENTE_e_o_frio_e_FRIO() -> void:
	var ambar := load(AMBAR) as PerfilDeLuz
	var frio := load(FRIO) as PerfilDeLuz
	if ambar == null or frio == null:
		ok(false, "os dois perfis precisam carregar antes de medir matiz")
		return
	entre(ambar.cor.h * 360.0, FAIXA_QUENTE.x, FAIXA_QUENTE.y,
		"o ambar e quente (lampada antiga, secao 94)")
	entre(frio.cor.h * 360.0, FAIXA_FRIA.x, FAIXA_FRIA.y,
		"o frio e azul-ciano (painel tecnico, secao 95)")
	# O frio e o raro, e o raro tambem e mais fraco: painel tecnico agonizando
	# nao ilumina sala, ele marca um canto.
	ok(frio.energia < ambar.energia, "o frio acende menos que o ambar")
	ok(frio.raio < ambar.raio, "o frio alcanca menos que o ambar")


## Pega: poca de luz que entra na faixa reservada ao ator.
##
## ## A REGRA MUDOU, e a versao anterior deixava o jogo sem luz nenhuma
##
## Ela cobrava `Paleta.compete_com_ator(perfil.cor)` -- o portao G2 aplicado ao
## SWATCH da lampada. O argumento parecia bom e estava errado: G2 e a regra das
## SUPERFICIES PINTADAS do ambiente, e existe para que parede e chao nao sejam
## confundidos com tiro e inimigo.
##
## **Uma fonte de luz nao e uma superficie pintada.** O que a torna confundivel
## com projetil seria ser pequena, saturada e de borda dura -- e a poca e o
## oposto disso nos tres eixos: ela e grande, ela MODULA o que ja esta desenhado
## em vez de ser uma forma propria, e a borda dela e macia (o
## `laboratorio_luz` mede queda de 0,31 por pixel contra 15,81 de um disco
## chapado).
##
## O preco da regra antiga foi medido em captura: com a cor presa abaixo de
## `LIMITE_VALOR`, a lampada ficou escura demais para iluminar e o andar inteiro
## saiu sem poca nenhuma -- enquanto esta suite passava verde, porque ela media
## a MATEMATICA do efeito e nao o efeito.
##
## ## O que ela cobra hoje
##
## O RESULTADO composto: o chao do andar, escurecido pelo `AmbienteDaFabrica`,
## MAIS o que a luz soma no centro da poca. E esse valor que o jogador ve, e e
## ele que nao pode entrar na faixa do ator.
##
## O teto continua sendo `Paleta.LIMITE_VALOR`, entao a trava nao afrouxou: ela
## so passou a medir o lugar certo.
func _nenhuma_luz_compete_com_ator() -> void:
	for caminho in [AMBAR, FRIO]:
		var perfil := load(caminho) as PerfilDeLuz
		if perfil == null:
			continue
		# O chao do andar 1 mede valor ~0,12; o ambiente o multiplica.
		var chao := VALOR_DO_CHAO * AMBIENTE_DA_RUN
		var pico := chao + FATOR_DE_RENDER * perfil.cor.v * perfil.energia
		ok(pico <= Paleta.LIMITE_VALOR,
			"%s: o centro da poca fica fora da faixa do ator (V %.3f, teto %.2f)" % [
				perfil.id, pico, Paleta.LIMITE_VALOR,
			])
		# E a poca precisa EXISTIR: uma luz que nao levanta o chao acima do
		# minimo visivel e uma luminaria que nao acende, e foi exatamente o
		# estado que a regra antiga produziu. Portao que so tem teto aprova o
		# zero.
		ok(pico >= chao + GANHO_MINIMO_DA_POCA,
			"%s: a poca de fato ACENDE (chao %.3f -> centro %.3f, minimo +%.2f)" % [
				perfil.id, chao, pico, GANHO_MINIMO_DA_POCA,
			])


## Pega: piscar que apaga a luz por completo.
##
## Apagar e reacender le como falha de renderizacao, e nao como lampada velha.
## O caso NAO mede os `.tres` de hoje: ele monta o perfil mais hostil possivel
## (profundidade 1,0, rapido) e prova que o PISO da conta segura mesmo assim --
## portao que afirma o numero de hoje envelhece na primeira sessao de tuning.
func _o_flicker_nunca_zera_a_energia() -> void:
	var hostil := PerfilDeLuz.new()
	hostil.id = &"hostil"
	hostil.cor = Color(1.0, 1.0, 1.0)
	hostil.energia = 1.0
	hostil.raio = 96.0
	hostil.chance_de_estar_ligada = 1.0
	hostil.chance_de_instabilidade = 1.0
	hostil.velocidade_do_flicker = 3.0
	hostil.profundidade_do_flicker = 1.0

	var luz := LuzDeFabrica.new()
	luz.perfil = hostil
	luz.semear(4242)

	var minimo := 1.0
	for i in 5000:
		var t := 30.0 * float(i) / 5000.0
		minimo = minf(minimo, luz.fator_do_flicker(t))
	luz.free()

	ok(minimo >= LuzDeFabrica.PISO_DO_FLICKER - 0.0001,
		"o piscar nunca desce do piso (minimo %.4f, piso %.4f)" % [
			minimo, LuzDeFabrica.PISO_DO_FLICKER,
		])
	ok(minimo > 0.0, "o piscar nunca chega a zero")


## Pega: senoide rapida, ou seno unico virado pulso ritmico.
##
## "Lento e irregular" nao se confere de olho num `.tres`: velocidade 0,7 e
## velocidade 7,0 sao um digito de distancia e a segunda e um estrobo. Contar
## travessias da media transforma a frase em numero, e o piso de baixo cobra o
## contrario -- uma luz declarada instavel que ficou parada.
func _o_flicker_nao_e_estroboscopico() -> void:
	for caminho in [AMBAR, FRIO]:
		var perfil := load(caminho) as PerfilDeLuz
		if perfil == null:
			continue
		var luz := LuzDeFabrica.new()
		luz.perfil = perfil
		luz.semear(20260908)

		var amostras: Array[float] = []
		var soma := 0.0
		for i in PASSOS:
			var t := JANELA_S * float(i) / float(PASSOS)
			var v := luz.fator_do_flicker(t)
			amostras.append(v)
			soma += v
		luz.free()

		var media := soma / float(PASSOS)
		var cruzamentos := 0
		var acima := amostras[0] >= media
		for i in range(1, amostras.size()):
			var agora := amostras[i] >= media
			if agora != acima:
				cruzamentos += 1
				acima = agora

		var por_segundo := float(cruzamentos) / JANELA_S
		ok(por_segundo <= TETO_CRUZAMENTOS_POR_SEGUNDO,
			"%s: o piscar e LENTO (%.2f travessias/s, teto %.2f)" % [
				perfil.id, por_segundo, TETO_CRUZAMENTOS_POR_SEGUNDO,
			])
		ok(cruzamentos >= PISO_CRUZAMENTOS,
			"%s: o piscar existe de fato (%d travessias em %.0f s)" % [
				perfil.id, cruzamentos, JANELA_S,
			])


## Pega: luminaria que re-sorteia o estado a cada visita a sala.
##
## Uma lampada acesa na primeira passagem, apagada na segunda e piscando na
## terceira nao le como fabrica velha: le como bug. E o segundo bloco pega o
## oposto -- um sorteio que "e deterministico" porque devolve sempre a mesma
## coisa, ignorando as chances declaradas.
func _o_sorteio_e_deterministico_por_semente() -> void:
	var ambar := load(AMBAR) as PerfilDeLuz
	if ambar == null:
		ok(false, "o perfil ambar precisa carregar antes de medir o sorteio")
		return

	var luz := LuzDeFabrica.new()
	luz.perfil = ambar

	luz.semear(777)
	var ligada_a := luz.ligada
	var instavel_a := luz.instavel
	var fase_a := luz.fator_do_flicker(1.234)

	luz.semear(31337)
	luz.semear(777)
	igual(luz.ligada, ligada_a, "mesma semente, mesmo estado ligado")
	igual(luz.instavel, instavel_a, "mesma semente, mesma instabilidade")
	perto(luz.fator_do_flicker(1.234), fase_a, "mesma semente, mesma fase do piscar")

	var ligadas := 0
	var instaveis := 0
	for i in AMOSTRAS_DE_SEMENTE:
		luz.semear(i * PASSO_DE_SEMENTE)
		if luz.ligada:
			ligadas += 1
			if luz.instavel:
				instaveis += 1
		else:
			# Uma luminaria apagada nunca pisca: piscar e um caso de ligada.
			ok(not luz.instavel, "luz apagada nao pisca")
	luz.free()

	var fracao_ligadas := float(ligadas) / float(AMOSTRAS_DE_SEMENTE)
	perto(fracao_ligadas, ambar.chance_de_estar_ligada,
		"o sorteio obedece a chance de acender", TOLERANCIA_DE_FRACAO)
	if ligadas > 0:
		var fracao_instaveis := float(instaveis) / float(ligadas)
		perto(fracao_instaveis, ambar.chance_de_instabilidade,
			"o sorteio obedece a chance de instabilidade", TOLERANCIA_DE_FRACAO)


## Pega: luz lavando o telegrafo, o projetil e o inimigo.
##
## E a regra numero um do projeto virada camada em vez de intencao: a luz para
## um degrau abaixo de `Sala.Z_MUNDO`. Sem a trava, uma lampada ambar sobre um
## disco de telegrafo mudaria a cor do aviso que torna o ataque justo -- e nada
## acusaria, porque a sala continuaria bonita.
##
## O caso tambem cruza a duplicata: `LuzDeFabrica` escreve o proprio teto para
## nao depender da camada de mapa, e sem este cruzamento os dois numeros
## divergiriam em silencio no dia em que a faixa do mundo mudasse.
func _a_luz_para_abaixo_da_faixa_do_combate() -> void:
	igual(LuzDeFabrica.Z_TETO_ILUMINADO, Sala.Z_MUNDO - 1,
		"o teto iluminado fica um degrau abaixo de Sala.Z_MUNDO")

	var luz := LuzDeFabrica.new()
	luz.perfil = load(AMBAR) as PerfilDeLuz
	luz.aplicar_perfil()

	igual(luz.range_z_max, LuzDeFabrica.Z_TETO_ILUMINADO,
		"a luz nao alcanca a faixa do combate")
	ok(luz.range_z_min <= Sala.Z_PAREDE_TOPO,
		"a luz alcanca ate o topo da parede, que e a camada mais funda do cenario")
	ok(luz.texture != null, "a luz tem queda radial (sem textura ela e invisivel)")
	ok(luz.texture_scale > 0.0, "o raio do perfil virou escala da queda")
	ok(not luz.shadow_enabled, "sem sombra projetada: aresta dura le como circulo de engine")
	igual(luz.blend_mode, Light2D.BLEND_MODE_ADD, "a luz SOMA sobre a escuridao base")
	luz.free()


## Pega: reflexo no chao sob uma lampada APAGADA.
##
## O risco de piso molhado existe porque na referencia (`docs/fabrica_01.png`)
## ele e METADE do efeito de luz: sao os traços verticais no piso, e nao os
## halos, que dizem "ha luz aqui". Mas ele so faz sentido sob luz -- reflexo sem
## fonte le como mancha de tinta, e a sala ganharia riscos claros no escuro sem
## nada acendendo.
##
## O caso monta as DUAS pontas com sementes forcadas em vez de confiar no
## sorteio: uma luminaria de chance 1,0 e uma de chance 0,0. Testar so a acesa
## deixaria passar exatamente o defeito que importa.
func _so_lampada_ACESA_molha_o_piso() -> void:
	var raiz := Node2D.new()
	Engine.get_main_loop().root.add_child(raiz)

	for caso in [{"chance": 1.0, "acesa": true}, {"chance": 0.0, "acesa": false}]:
		var perfil := PerfilDeLuz.new()
		perfil.id = &"reflexo"
		perfil.cor = Color(0.78, 0.52, 0.25)
		perfil.raio = 128.0
		perfil.energia = 1.0
		perfil.chance_de_estar_ligada = float(caso["chance"])
		perfil.chance_de_instabilidade = 0.0

		var luminaria := LuminariaDeParede.new()
		raiz.add_child(luminaria)
		luminaria.configurar(perfil, 20260908)

		var esperado: bool = caso["acesa"]
		igual(luminaria.acesa(), esperado,
			"chance %.0f: a lampada %s" % [
				caso["chance"], "acende" if esperado else "fica apagada"])
		igual(luminaria.tem_reflexo(), esperado,
			"chance %.0f: o piso %s molhado" % [
				caso["chance"], "esta" if esperado else "NAO esta"])

	# E o risco nao pode competir com a leitura do combate: ele desenha no CHAO
	# e com alfa baixo. Um reflexo em `Z_MUNDO` cairia na faixa do telegrafo.
	ok(LuminariaDeParede.Z_REFLEXO < 0,
		"o reflexo desenha abaixo da faixa do combate (z %d)" % LuminariaDeParede.Z_REFLEXO)
	ok(LuminariaDeParede.REFLEXO_ALFA <= 0.25,
		"e ele e discreto (alfa %.2f)" % LuminariaDeParede.REFLEXO_ALFA)
	# Risco mais LONGO que largo: poca redonda ja e a propria luz, e repetir a
	# mesma forma nao acrescenta molhado.
	ok(LuminariaDeParede.REFLEXO_COMPRIMENTO > LuminariaDeParede.REFLEXO_LARGURA * 2.0,
		"e ele e um RISCO e nao uma poca (%.0f x %.0f)" % [
			LuminariaDeParede.REFLEXO_LARGURA, LuminariaDeParede.REFLEXO_COMPRIMENTO])

	raiz.queue_free()
