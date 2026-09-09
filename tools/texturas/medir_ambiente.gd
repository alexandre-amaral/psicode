extends Node
## A REGUA DE AMBIENTE: "qual e a CARA do andar 1?", medida em vez de opinada.
##
## POR QUE ELA NAO E O `tools/testes/teste_texturas.gd`. Aquele portao pergunta
## **"esta cor e legal?"** -- ele varre PNG a PNG e cobra cada arquivo contra a
## faixa de matiz do SEU tipo, contra a paleta declarada e contra a
## nao-competicao com projetil. E uma pergunta LOCAL, e ele a responde bem:
## hoje nenhuma textura do andar 1 esta fora da propria regra. Mesmo assim o
## andar nao parece uma fabrica. A pergunta que faltava e GLOBAL --
## **"qual e a cara do CONJUNTO?"** --, e ela nao se responde arquivo a arquivo:
## 56 texturas individualmente legais somam uma dominancia que ninguem
## escolheu. Dominancia, leitura em CINZA e leitura em MINIATURA sao
## propriedades do conjunto, e e por isso que elas moram aqui e nao la. As duas
## reguas convivem: esta nao substitui aquela nem repete um so dos casos dela.
##
## **ELA NASCE REPROVANDO, DE PROPOSITO.** O defeito ja esta medido e tem nome:
## o TINGIMENTO POR TIPO DE SALA. Ele nao e "ha verde no andar" -- o andar ja e
## azul (topo 215 com S 0,29; porta 232; chao base 235; props 223-235). O que
## ha e chao saindo com saturacao **0,77 (boss), 0,89 (arma) e 0,95 (item)**
## contra 0,40-0,42 do chao base: isso nao e metal tingido, e cor chapada com
## textura por cima. A divida e a Fase B do `docs/PLANO_FABRICA_ANDAR1.md`, e
## este portao existe para ela ficar VISIVEL ate ser paga. **Um portao que ja
## nasce verde nunca testou nada** -- a mesma licao que a Blindada ja cobrou (a
## classe existia, desenhava a aura e nao fazia nada, e nenhuma regua acusou).
##
## **E O QUE FAZ ELE MORDER HOJE E O MAGENTA, NAO O VERDE.** Este criterio foi
## rodado sobre as 56 texturas antes de o portao ser escrito, e as fracoes
## medidas sao: cinza_azulado **42,72%**, preto 15,12%, ferrugem 13,71%, ciano
## **11,77%**, magenta **9,64%**, outro 7,02%, ambar 0,01%, verde 0,01%. Os
## dois tetos que o briefing propunha -- verde e ciano -- **nao mordem**: o
## teal da sala de item mora em 172-176 graus e cai em CIANO e nao em VERDE,
## entao o verde some (0,01%) e o ciano para a 0,23 ponto do teto. Quem paga o
## magenta e a sala do CHEFE, tingida a 334-337 graus: `chao_boss` sozinho tem
## 23591 px e as sete faces `parede_face_boss_*` estao quase inteiras la
## dentro. **Magenta nem esta na paleta do briefing** -- e a familia
## "fora da paleta" --, entao os 9,64% sao o tingimento aparecendo como cor que
## o andar nao deveria ter. Ter descoberto isso ANTES foi o ponto de escrever a
## regua primeiro: a versao com so os tres testes propostos passaria hoje, e
## teria carimbado a divida inteira de verde.
##
## AS QUATRO PERGUNTAS, e so a primeira reprova:
##
##   DOMINANCIA  cada pixel opaco do conjunto cai numa familia de paleta, e a
##               ordem das fracoes E a cara do andar. O briefing pede
##               cinza-azulado dominante, preto secundario, ferrugem terciario,
##               ambar de acento, ciano raro e verde minimo. **PORTAO.**
##   CINZA       o desvio padrao da luminancia dentro de cada textura. A
##               fabrica tem de funcionar SEM COR, com forma, massa e
##               iluminacao carregando a identidade -- e matiz e a primeira
##               coisa que se perde num jogo escuro (a mesma razao que separa
##               as tres classes de Unidade Aprimorada por MOVIMENTO). Textura
##               que desaba aqui perde a silhueta quando a cor sai. RELATA.
##   MINIATURA   quanto desse contraste sobrevive com a textura reduzida a um
##               quarto do lado. Detalhe que evapora na miniatura nao le em
##               jogo: vira ruido, e ruido de cenario compete com movimento de
##               projetil. RELATA.
##   TABELA      arquivo a arquivo: matiz dominante, saturacao e valor medios,
##               familia predominante. E a lista de suspeitos para a Fase B.
##
## CINZA e MINIATURA **relatam e nao reprovam**, e isso e declaracao e nao
## esquecimento: nao existe linha de base para nenhuma das duas. Cravar um piso
## agora seria escolher um numero antes de medir -- e o repositorio ja pagou
## por isso ("suavizar para caber num numero" matou uma familia de textura
## inteira). Os dois pisos abaixo MARCAM a linha no relatorio; quem os
## transformar em portao tem de trazer a medicao junto.
##
## USO (nao precisa de janela; ele so mede):
##
##   godot --headless --path . tools/texturas/medir_ambiente.tscn
##
## ENCERRA EM TODO CAMINHO DE SAIDA -- 0 aprovado, 1 reprovado. Cena headless
## que nao encerra vira runaway, e um `runner.tscn` esquecido ja acumulou
## 1574 s de CPU em tres horas girando num nucleo.


## A pasta do AMBIENTE. So ela: ator (personagem, inimigo, projetil) e outra
## linguagem e tem regime proprio -- misturar os dois aqui responderia a
## pergunta errada, porque e justamente a distancia entre ambiente e ator que
## faz o jogo ser legivel.
## O QUE A REFERENCIA MEDE, para os tetos abaixo terem contra o que se comparar
## (`docs/fabrica_01.png`, quadro inteiro):
##
##   preto 50,75% | cinza_azulado 35,43% | ferrugem 3,30%
##   ciano 0,50%  | ambar 0,41%          | magenta 0,17% | verde 0,16%
##
## E o que ESTA PASTA mediu, antes e depois do retingimento da FAB 09/10:
##
##   familia          antes    depois   referencia
##   cinza_azulado   42,61%    68,57%      35,43%
##   ciano           11,77%     0,52%       0,50%
##   ferrugem        13,71%     0,17%       3,30%
##   magenta          9,69%    14,20%       0,17%
##   verde            0,01%     0,01%       0,16%
##
## Duas leituras que valem mais que os tetos:
##
## 1. **O ciano caiu de 11,77% para 0,52% e acertou a referencia (0,50%).** Ele
##    era a sala de item inteira, e era a reclamacao que abriu o briefing.
## 2. **A FERRUGEM sumiu junto, e isso e uma perda.** Ela media 13,71% porque o
##    laranja da sala de arma contava como ferrugem; hoje mede 0,17% contra os
##    3,30% da referencia. O andar ficou sem desgaste quente, e quem devolve isso
##    e ARTE (decalque de ferrugem, oxidacao nas juntas), nao tinta de ambiente.
##
## **O magenta continua reprovando, e a causa e a REGUA e nao a arte.** Esta
## ferramenta mede a PASTA, onde a sala do chefe tem 10 dos 56 arquivos (18%);
## numa run ela e uma sala em dez. O `[FAB 13]` troca isto por uma captura do
## jogo, e e la que o numero passa a querer dizer alguma coisa.
const PASTA_AMBIENTE := "res://assets/texturas/"

## Quanto do quadro da REFERENCIA e preto (valor <= 0,10), medido.
##
## Metade da imagem. A "sombra profunda" do briefing nao e um efeito ocasional:
## e a maior parte do quadro, e e contra ela que os bolsoes de luz existem.
const PRETO_DE_REFERENCIA := 0.5075

## Quanto o andar pode passar disso antes de a regua comentar. Generoso: a
## referencia e um render 3D de UMA sala com sete lampadas, e comparar direto
## exagera a diferenca.
const FOLGA_DO_PRETO := 0.20

## Pixel abaixo disso nao existe para nenhuma medida. Contorno antisserrilhado
## de decalque tem alfa baixo e cor lavada; conta-lo empurraria toda familia
## para OUTRO sem nada ter mudado na arte.
const ALFA_MINIMO := 0.03


## As familias de paleta do briefing. Enum sem `.tres` nenhum por tras -- ele
## nao e gravado em disco, entao a ordem aqui e so a ordem do relatorio.
enum Familia {
	CINZA_AZULADO,
	PRETO,
	FERRUGEM,
	AMBAR,
	CIANO,
	VERDE,
	MAGENTA,
	OUTRO,
}

const NOMES_DE_FAMILIA: Array[String] = [
	"cinza_azulado",
	"preto",
	"ferrugem",
	"ambar",
	"ciano",
	"verde",
	"magenta",
	"outro",
]

## O papel que o briefing da a cada familia, na ordem do enum. Ele nao entra em
## conta nenhuma -- aparece no relatorio para a ordem medida poder ser lida
## contra a ordem pedida sem ninguem ter de decorar o briefing.
const PAPEL_DE_FAMILIA: Array[String] = [
	"dominante",
	"secundario",
	"terciario",
	"acento",
	"raro",
	"minimo",
	"fora da paleta",
	"-",
]

# -- as fronteiras de cada familia ------------------------------------------
#
# Matiz em GRAUS (0-360), saturacao e valor em 0-1. As faixas sao meio-abertas
# no fim (`>= inicio and < fim`), senao 195 pertenceria a ciano E a
# cinza-azulado ao mesmo tempo, e a contagem dependeria da ordem dos `if`.

## O ALVO do andar: cinza azulado, grafite, ferro, aco sujo. Note que o teto de
## saturacao e parte da definicao e nao um detalhe -- um azul de 210 graus com
## S 0,80 esta na faixa de matiz e NAO e este andar; ele cai em OUTRO, que e
## exatamente onde o tingimento por tipo de sala tem de aparecer.
const CINZA_MATIZ := Vector2(195.0, 255.0)
const CINZA_SATURACAO_MAXIMA := 0.45

## Preto azulado. Medido por VALOR e nao por matiz porque abaixo deste valor o
## matiz e ruido do quantizador: um pixel a 4% de luz nao tem cor que o jogador
## consiga ler, e classifica-lo por matiz espalharia a sombra do andar inteiro
## pelas outras familias.
const PRETO_VALOR_MAXIMO := 0.10

## Ferrugem escura. O piso de saturacao separa ferrugem de um cinza que so por
## acaso caiu no vermelho.
const FERRUGEM_MATIZ := Vector2(5.0, 45.0)
const FERRUGEM_SATURACAO_MINIMA := 0.25

## Ambar de lampada antiga. A faixa cobre 25-55, entao ela SOBREPOE ferrugem
## entre 25 e 45 -- e o piso de valor e o que resolve a sobreposicao: ferrugem
## e escura e lampada e clara. Por isso ambar e testada ANTES de ferrugem em
## `_familia_do_pixel()`; na ordem contraria, todo ponto de luz quente do andar
## seria contado como oxido.
const AMBAR_MATIZ := Vector2(25.0, 55.0)
const AMBAR_VALOR_MINIMO := 0.45

const CIANO_MATIZ := Vector2(165.0, 195.0)
const VERDE_MATIZ := Vector2(90.0, 165.0)
const MAGENTA_MATIZ := Vector2(300.0, 345.0)


# -- os limites do portao ---------------------------------------------------

## Teto de VERDE no conjunto.
##
## De onde o numero veio: hoje as unicas texturas na faixa verde/teal sao as 6
## da sala de item (matiz 172-176), e o briefing pede verde MINIMO. 8% e o
## ponto de partida declarado -- ele deixa passar uma sala inteira tingida de
## um resto de verde, e nao dois. Girar este numero e girar a decisao "quanto
## de verde o andar 1 pode ter", que e do dono do projeto e nao do codigo.
const TETO_VERDE := 0.08

## Teto de CIANO no conjunto.
##
## Mais folgado que o verde de proposito: ciano e o vizinho imediato do
## cinza-azulado e a fronteira em 195 graus corta uma familia continua no meio
## -- uma chapa levemente esverdeada derrama para ca sem ninguem ter pintado
## nada de ciano. 12% acomoda esse derrame e continua recusando "o andar e
## ciano", que e o defeito de leitura que importa.
##
## **MEDIDO: 11,77%, a 0,23 ponto do teto.** Ele nao morde hoje por pouco, e
## quem o enche e a sala de ITEM (172-176 graus) -- a mesma divida do magenta,
## do outro lado da roda. O relatorio imprime a margem de cada linha do portao
## justamente por isso: um teto que passa raspando nao e um teto que passa.
const TETO_CIANO := 0.12

## Teto de MAGENTA no conjunto.
##
## De onde o numero veio: magenta **nao esta na paleta do briefing** -- cinza
## azulado, grafite, ferro, aco sujo, preto azulado, ferrugem escura e ambar.
## Uma familia fora da paleta nao tem faixa de tolerancia a defender, entao o
## teto e o menor que ainda perdoa contorno antisserrilhado e uma laje de
## sombra roxeada: 2%.
##
## **MEDIDO: 9,64%, quase cinco vezes o teto -- e e ISTO que reprova hoje.** A
## origem tem nome e endereco: `chao_boss.png` (23591 px) e as sete
## `parede_face_boss_*`, todas tingidas em 334-337 graus. Quando a Fase B
## derrubar o tingimento por tipo, esta linha vira verde sozinha; ate la ela e
## a divida com numero.
const TETO_MAGENTA := 0.02

## Piso do desvio padrao da luminancia DENTRO de uma textura (0-1).
##
## **Nao e portao, e marcador.** 0,06 equivale a ~15 niveis de 255 de dispersao
## e e o ponto de partida para a conversa, nao uma linha de base medida: ela
## ainda nao existe, e cravar portao antes de medir e como esta regua deixaria
## de servir para a Fase B.
const PISO_DESVIO_CINZA := 0.06

## Piso de quanto do contraste sobrevive a reducao (razao reduzido/original).
##
## **Nao e portao, e marcador.** Mesma condicao do piso acima.
const PISO_SOBREVIVENCIA_MINIATURA := 0.60

## O lado da miniatura, em fracao do lado original. Um quarto e a leitura
## literal do briefing: a textura vista de longe, sem detalhe nenhum a defender.
const FATOR_MINIATURA := 4


## Tudo que se sabe de um PNG depois da varredura.
class Medida:
	var nome: String = ""
	var largura: int = 0
	var altura: int = 0
	var opacos: int = 0
	## Contagem por familia, indexada pelo enum `Familia`.
	var por_familia := PackedInt32Array()
	var matiz_dominante: float = 0.0
	var saturacao_media: float = 0.0
	var valor_medio: float = 0.0
	## Indice do enum `Familia`. Zero cru e nao `Familia.OUTRO` de proposito:
	## classe interna nao enxerga o enum do script de fora, e o campo e sempre
	## escrito por `_medir_imagem()` antes de alguem ler.
	var familia_predominante: int = 0
	var desvio_cinza: float = 0.0
	var desvio_miniatura: float = 0.0
	var sobrevivencia: float = 0.0


## Qual pasta medir. Sem argumento vale `PASTA_AMBIENTE`.
##
## ## Por que dar escolha, e qual das duas conta
##
## Medir `assets/texturas/` responde **"existe textura fora da paleta?"** -- uma
## pergunta por ARQUIVO, e util: ela pega uma peca nova nascendo verde.
##
## Mas ela NAO responde "qual e a cara do andar", e o desvio tem tamanho: a sala
## do chefe tem 10 dos 56 arquivos (18%) e e uma sala em dez numa run; a face
## dela aparece num lado so, enquanto o chao cobre o quadro inteiro. Foi assim
## que este portao passou a reprovar em magenta com 14,20% -- com a arte certa.
##
## Um QUADRO DE JOGO pesa cada textura pela area que ela ocupa de fato, e e o
## unico jeito de a dominancia querer dizer alguma coisa. Quem produz os quadros
## e `tools/fabrica/olhar_andar.tscn` -- sem HUD, porque a HUD e SINAL e contaria
## a barra de vida como se fosse parede.
##
##   godot --path . tools/fabrica/olhar_andar.tscn --resolution 960x544
##   godot --headless --path . tools/texturas/medir_ambiente.tscn -- --pasta=user://capturas/andar
## A familia dominante DESCONTANDO o preto.
##
## ## O briefing contradiz a propria referencia aqui
##
## Ele pede a ordem *"cinza-azulado dominante, preto secundario"* (secao 118).
## Medida, a imagem que ele mesmo aponta como referencia diz o contrario:
## **preto 50,75% contra cinza_azulado 35,43%**. Numa fabrica escura o preto
## ganha por construcao -- ele nao e uma cor escolhida, e a ausencia de luz.
##
## Entao o portao cobra o que a referencia de fato sustenta: **entre as familias
## que TEM cor, o cinza azulado domina.** Isso continua pegando o defeito que
## interessa (uma sala que vira verde, laranja ou magenta) sem reprovar a
## escuridao, que e justamente o que o andar deve ter.
##
## Quanto preto ha vira RELATORIO, e nao trava: a distancia ate os 50,75% da
## referencia mede quanta LUZ falta, e luz e tuning de `[FAB 19]` -- nao de
## paleta.
static func _familia_dominante_colorida(total: PackedInt32Array) -> int:
	var melhor := Familia.CINZA_AZULADO
	var maior := -1
	for i in total.size():
		if i == Familia.PRETO or i == Familia.OUTRO:
			continue
		if total[i] > maior:
			maior = total[i]
			melhor = i
	return melhor


func _pasta_pedida() -> String:
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--pasta="):
			var caminho := argumento.substr("--pasta=".length())
			return caminho if caminho.ends_with("/") else caminho + "/"
	return PASTA_AMBIENTE


func _ready() -> void:
	# Um frame antes de qualquer coisa, pelo mesmo motivo que o `runner.gd`:
	# `quit()` chamado de dentro do `_ready` nao encerra confiavelmente.
	await get_tree().process_frame

	var pasta := _pasta_pedida()
	var medidas := _medir_pasta(pasta)
	if medidas.is_empty():
		print("\n[medir_ambiente] nenhum PNG em %s -- a regua nao olhou para nada."
			% pasta)
		# Reprova de proposito: regua que nao mediu nada nao pode devolver
		# "esta tudo bem". Carimbo e pior que portao nenhum, porque parece
		# prova.
		get_tree().quit(1)
		return

	print("\n[medir_ambiente] medindo %s" % pasta)
	var falhas := _relatorio_de_dominancia(medidas)
	_relatorio_de_cinza(medidas)
	_relatorio_de_miniatura(medidas)
	_tabela_por_arquivo(medidas)
	_encerrar(medidas.size(), falhas)


func _encerrar(arquivos: int, falhas: int) -> void:
	print("\n=== resultado (%d arquivo(s) medido(s)) ===" % arquivos)
	if falhas > 0:
		print("  REPROVOU: %d problema(s) de dominancia." % falhas)
		print("  Isto e ESPERADO enquanto a Fase B do PLANO_FABRICA_ANDAR1 nao")
		print("  derrubar o tingimento por tipo de sala. O portao existe para a")
		print("  divida ficar visivel, e nao para ser silenciado.")
		get_tree().quit(1)
		return
	print("  PASSOU")
	get_tree().quit(0)


# -- A) dominancia de paleta ------------------------------------------------


## A cara do andar, e o unico bloco que reprova.
func _relatorio_de_dominancia(medidas: Array[Medida]) -> int:
	var total := PackedInt32Array()
	total.resize(NOMES_DE_FAMILIA.size())
	var opacos := 0
	for m in medidas:
		opacos += m.opacos
		for i in total.size():
			total[i] = total[i] + m.por_familia[i]

	print("\n=== A) dominancia de paleta ===")
	print("\n  %d arquivo(s), %d pixel(s) opaco(s)\n" % [medidas.size(), opacos])
	print("  %-16s %8s %10s   %s" % ["familia", "fracao", "pixels", "papel pedido"])
	print("  " + "-".repeat(58))

	# A ordem impressa e a do BRIEFING e nao a das fracoes: e assim que da para
	# ver de relance qual familia saiu do lugar dela.
	var fracoes := PackedFloat32Array()
	fracoes.resize(total.size())
	for i in total.size():
		fracoes[i] = 0.0 if opacos == 0 else float(total[i]) / float(opacos)
		print("  %-16s %7.2f%% %10d   %s" % [
			NOMES_DE_FAMILIA[i], fracoes[i] * 100.0, total[i], PAPEL_DE_FAMILIA[i],
		])

	var dominante := _familia_dominante(total)
	print("\n  familia dominante medida: %s (%.2f%%)"
		% [NOMES_DE_FAMILIA[dominante], fracoes[dominante] * 100.0])
	print("  ordem medida: %s" % _ordem_medida(fracoes))
	print("  ordem pedida entre as COLORIDAS: cinza_azulado > ferrugem > ambar > ciano > verde")
	print("  preto medido %.2f%%   (a referencia mede 50,75%%)"
		% [fracoes[Familia.PRETO] * 100.0])

	print("\n  -- o portao --\n")
	var falhas := 0
	var dominante_colorida := _familia_dominante_colorida(total)
	falhas += _cobrar(
		dominante_colorida == Familia.CINZA_AZULADO,
		"cinza_azulado domina entre as COLORIDAS (medido: %s, %.2f%%)"
			% [NOMES_DE_FAMILIA[dominante_colorida],
				fracoes[dominante_colorida] * 100.0])
	# RELATORIO, nao portao: a distancia ate a referencia diz quanta LUZ falta
	# no andar, e nao se a paleta esta certa. Ver a doc de
	# `_familia_dominante_colorida`.
	if fracoes[Familia.PRETO] > PRETO_DE_REFERENCIA + FOLGA_DO_PRETO:
		print("  [nota]   o andar esta %.1f pontos mais escuro que a referencia."
			% ((fracoes[Familia.PRETO] - PRETO_DE_REFERENCIA) * 100.0))
		print("           A referencia tem sete a oito lampadas por sala; o andar")
		print("           tem tres a cinco. Isso e tuning de LUZ, e nao de paleta.")
	# **Os tetos so TRAVAM sobre quadro de jogo, e reportam sobre a pasta.**
	#
	# Eles foram calibrados contra a referencia, que e um QUADRO: nela o magenta
	# ocupa 0,17% porque a sala do chefe e uma sala em dez e a face dela aparece
	# num lado so. Na PASTA o mesmo magenta da 14,20%, porque o chefe tem 10 dos
	# 56 arquivos -- e reprovar ali seria reprovar a aritmetica do diretorio, e
	# nao a arte.
	#
	# Quem protege arquivo a arquivo ja existe e e outro portao:
	# `teste_texturas.gd` cobra a faixa de matiz de cada PNG contra o tipo dele.
	# Esta regua responde a outra pergunta -- "qual e a CARA do andar" --, e ela
	# so tem resposta sobre o que o jogador ve.
	var sobre_quadro := _pasta_pedida() != PASTA_AMBIENTE
	for caso in [
		[&"verde", fracoes[Familia.VERDE], TETO_VERDE],
		[&"ciano", fracoes[Familia.CIANO], TETO_CIANO],
		[&"magenta", fracoes[Familia.MAGENTA], TETO_MAGENTA],
	]:
		if sobre_quadro:
			falhas += _cobrar_teto(String(caso[0]), float(caso[1]), float(caso[2]))
		else:
			print("  [nota]   %s %.2f%% na pasta (teto %.0f%% vale sobre QUADRO)"
				% [String(caso[0]), float(caso[1]) * 100.0, float(caso[2]) * 100.0])
	return falhas


## Uma linha do portao, com a MARGEM ao lado.
##
## A margem existe porque "passou" e "passou raspando" nao sao a mesma
## informacao, e a diferenca entre elas ja custou tempo aqui: o ciano mede
## 11,77% contra um teto de 12%, e uma unica sala nova tingida o vira. Sem a
## margem impressa, o dia em que ele reprovar vai parecer uma regressao
## repentina em vez do que e -- uma linha que sempre esteve encostada.
func _cobrar_teto(familia: String, medido: float, teto: float) -> int:
	var passa := medido <= teto
	var descricao := "%s <= %.0f%% (medido: %.2f%%, margem %+.2f ponto)" % [
		familia, teto * 100.0, medido * 100.0, (teto - medido) * 100.0,
	]
	return _cobrar(passa, descricao)


func _cobrar(condicao: bool, descricao: String) -> int:
	print("  %s %s" % ["[ok]    " if condicao else "[FALHA] ", descricao])
	return 0 if condicao else 1


func _familia_dominante(contagem: PackedInt32Array) -> int:
	var melhor: int = Familia.OUTRO
	var maior := -1
	for i in contagem.size():
		if contagem[i] > maior:
			maior = contagem[i]
			melhor = i
	return melhor


## As familias em ordem decrescente de fracao, para a ordem medida poder ser
## comparada com a pedida sem ninguem ler a tabela de tras para frente.
func _ordem_medida(fracoes: PackedFloat32Array) -> String:
	var indices: Array[int] = []
	for i in fracoes.size():
		indices.append(i)
	indices.sort_custom(func(a: int, b: int) -> bool: return fracoes[a] > fracoes[b])
	var nomes: Array[String] = []
	for i in indices:
		if fracoes[i] <= 0.0:
			continue
		nomes.append(NOMES_DE_FAMILIA[i])
	return " > ".join(nomes)


# -- C) o teste em cinza ----------------------------------------------------


## O contraste interno de cada textura com a cor fora.
##
## RELATA e nao reprova: sem linha de base, um piso aqui seria um numero
## escolhido antes da medicao. O que ele faz e MARCAR quem cai abaixo do piso
## de partida, que e a lista por onde a conversa comeca.
func _relatorio_de_cinza(medidas: Array[Medida]) -> void:
	print("\n=== C) teste em CINZA -- desvio padrao da luminancia ===")
	print("\n  A fabrica precisa funcionar sem cor. Textura abaixo do piso de")
	print("  partida (%.3f) perde a silhueta quando o matiz sai." % PISO_DESVIO_CINZA)
	print("  RELATORIO, nao portao: ainda nao ha linha de base.\n")

	# `assign()` e nao `duplicate()`: a copia tem de continuar tipada, senao o
	# `sort_custom` recebe Variant e a tipagem some no meio da regua.
	var ordenadas: Array[Medida] = []
	ordenadas.assign(medidas)
	ordenadas.sort_custom(_por_cinza)

	print("  %-38s %8s  %s" % ["arquivo", "desvio", "leitura"])
	print("  " + "-".repeat(62))
	var marcadas := 0
	var soma := 0.0
	for m in ordenadas:
		soma += m.desvio_cinza
		var abaixo := m.desvio_cinza < PISO_DESVIO_CINZA
		if abaixo:
			marcadas += 1
		print("  %-38s %8.4f  %s" % [
			m.nome, m.desvio_cinza, "MARCADA (chapada em cinza)" if abaixo else "",
		])
	var media := 0.0 if medidas.is_empty() else soma / float(medidas.size())
	print("\n  media do conjunto: %.4f | marcadas: %d de %d"
		% [media, marcadas, medidas.size()])


# -- D) o teste em miniatura ------------------------------------------------


## Quanto do contraste sobrevive a um quarto do lado.
##
## Tambem RELATA. A razao e o numero que interessa e nao o desvio absoluto: uma
## textura calma que continua calma nao perdeu nada, e uma textura nervosa que
## vira cinza uniforme perdeu tudo -- as duas podem ter o mesmo desvio reduzido.
func _relatorio_de_miniatura(medidas: Array[Medida]) -> void:
	print("\n=== D) teste em MINIATURA -- 1/%d do lado ===" % FATOR_MINIATURA)
	print("\n  Detalhe que evapora aqui vira ruido em jogo, e ruido de cenario")
	print("  compete com movimento de projetil. Piso de partida: %.2f."
		% PISO_SOBREVIVENCIA_MINIATURA)
	print("  RELATORIO, nao portao.\n")

	# `assign()` e nao `duplicate()`: a copia tem de continuar tipada, senao o
	# `sort_custom` recebe Variant e a tipagem some no meio da regua.
	var ordenadas: Array[Medida] = []
	ordenadas.assign(medidas)
	ordenadas.sort_custom(_por_sobrevivencia)

	print("  %-38s %8s %8s %8s  %s"
		% ["arquivo", "cheio", "mini", "razao", "leitura"])
	print("  " + "-".repeat(80))
	var marcadas := 0
	for m in ordenadas:
		var abaixo := m.sobrevivencia < PISO_SOBREVIVENCIA_MINIATURA
		if abaixo:
			marcadas += 1
		print("  %-38s %8.4f %8.4f %7.2f%%  %s" % [
			m.nome, m.desvio_cinza, m.desvio_miniatura, m.sobrevivencia * 100.0,
			"MARCADA (detalhe evapora)" if abaixo else "",
		])
	print("\n  marcadas: %d de %d" % [marcadas, medidas.size()])


# -- E) a tabela por arquivo ------------------------------------------------


func _tabela_por_arquivo(medidas: Array[Medida]) -> void:
	print("\n=== E) por arquivo ===\n")
	print("  %-38s %6s %6s %6s %6s  %-14s %s" % [
		"arquivo", "px", "matiz", "sat", "valor", "familia", "tamanho",
	])
	print("  " + "-".repeat(98))
	# `assign()` e nao `duplicate()`: a copia tem de continuar tipada, senao o
	# `sort_custom` recebe Variant e a tipagem some no meio da regua.
	var ordenadas: Array[Medida] = []
	ordenadas.assign(medidas)
	ordenadas.sort_custom(_por_nome)
	for m in ordenadas:
		# Matiz negativo e a marca de "sem matiz" que `_matiz_circular()` devolve
		# para uma chapa neutra. Imprimir -1 grau ali seria inventar um vermelho.
		var matiz := "   --" if m.matiz_dominante < 0.0 else "%4.0fd" % m.matiz_dominante
		print("  %-38s %6d %6s %6.2f %6.2f  %-14s %dx%d" % [
			m.nome, m.opacos, matiz, m.saturacao_media,
			m.valor_medio, NOMES_DE_FAMILIA[m.familia_predominante],
			m.largura, m.altura,
		])


# -- os criterios de ordem ---------------------------------------------------
#
# Metodos nomeados e nao lambdas: cada relatorio ordena pelo eixo que ELE
# mede, e a pior textura tem de aparecer no topo da lista -- e onde a
# conversa da Fase B comeca.


func _por_cinza(a: Medida, b: Medida) -> bool:
	return a.desvio_cinza < b.desvio_cinza


func _por_sobrevivencia(a: Medida, b: Medida) -> bool:
	return a.sobrevivencia < b.sobrevivencia


func _por_nome(a: Medida, b: Medida) -> bool:
	return a.nome < b.nome


# -- a varredura ------------------------------------------------------------


func _medir_pasta(caminho: String) -> Array[Medida]:
	var fora: Array[Medida] = []
	var pasta := DirAccess.open(caminho)
	if pasta == null:
		print("[medir_ambiente] nao consegui abrir %s" % caminho)
		return fora
	var arquivos := pasta.get_files()
	arquivos.sort()
	for arquivo in arquivos:
		if not arquivo.ends_with(".png"):
			continue
		var imagem := _carregar_png(caminho + arquivo)
		if imagem == null:
			print("[medir_ambiente] %s nao carrega" % arquivo)
			continue
		fora.append(_medir_imagem(arquivo, imagem))
	return fora


func _carregar_png(caminho: String) -> Image:
	if not FileAccess.file_exists(caminho):
		return null
	# Caminho absoluto de proposito, como em `teste_texturas._carregar_png()`:
	# `load_from_file` com `res://` avisa que "nao funciona no export", e aqui e
	# exatamente o PNG FONTE que se quer ler -- nao a versao importada, que ja
	# passou pelo filtro do motor.
	var imagem := Image.load_from_file(ProjectSettings.globalize_path(caminho))
	if imagem == null or imagem.is_empty():
		return null
	if imagem.is_compressed():
		imagem.decompress()
	imagem.convert(Image.FORMAT_RGBA8)
	return imagem


func _medir_imagem(nome: String, imagem: Image) -> Medida:
	var m := Medida.new()
	m.nome = nome
	m.largura = imagem.get_width()
	m.altura = imagem.get_height()
	m.por_familia.resize(NOMES_DE_FAMILIA.size())

	var soma_saturacao := 0.0
	var soma_valor := 0.0
	var soma_luma := 0.0
	var soma_luma_quadrada := 0.0
	# A MEDIA DE MATIZ E CIRCULAR. Matiz e angulo: somar 350 com 10 e dividir
	# por dois da 180 graus, que e o OPOSTO da resposta certa. Acumula-se o
	# vetor unitario de cada pixel e o angulo sai no fim, por `atan2`. O peso e
	# a SATURACAO porque um cinza puro tem matiz arbitrario -- deixa-lo votar
	# com o mesmo peso de uma chapa colorida faria a media apontar para o ruido
	# do quantizador.
	var soma_seno := 0.0
	var soma_cosseno := 0.0

	for y in m.altura:
		for x in m.largura:
			var cor := imagem.get_pixel(x, y)
			if cor.a < ALFA_MINIMO:
				continue
			m.opacos += 1
			var familia := _familia_do_pixel(cor)
			m.por_familia[familia] = m.por_familia[familia] + 1

			soma_saturacao += cor.s
			soma_valor += cor.v
			var angulo := deg_to_rad(cor.h * 360.0)
			soma_seno += sin(angulo) * cor.s
			soma_cosseno += cos(angulo) * cor.s

			var l := _luma(cor)
			soma_luma += l
			soma_luma_quadrada += l * l

	if m.opacos > 0:
		m.saturacao_media = soma_saturacao / float(m.opacos)
		m.valor_medio = soma_valor / float(m.opacos)
		m.matiz_dominante = _matiz_circular(soma_seno, soma_cosseno)
		var media_luma := soma_luma / float(m.opacos)
		m.desvio_cinza = sqrt(maxf(0.0,
			soma_luma_quadrada / float(m.opacos) - media_luma * media_luma))
	m.familia_predominante = _familia_dominante(m.por_familia)

	m.desvio_miniatura = _desvio_da_miniatura(imagem)
	# Razao e nao diferenca: o que interessa e quanto SOBREVIVEU. Uma textura
	# calma que continua calma nao perdeu nada, e uma nervosa que vira chapa
	# perdeu tudo -- as duas podem ter o mesmo desvio reduzido.
	if m.desvio_cinza > 0.0:
		m.sobrevivencia = m.desvio_miniatura / m.desvio_cinza
	return m


## O angulo resultante da soma vetorial, em graus 0-360.
##
## Vetor nulo (a textura inteira e cinza puro, sem saturacao nenhuma) nao tem
## matiz: devolver 0 ali diria "vermelho" sobre uma chapa neutra. Devolve -1,
## que a tabela imprime como o que e -- ausencia de matiz e nao matiz zero.
func _matiz_circular(soma_seno: float, soma_cosseno: float) -> float:
	if is_zero_approx(soma_seno) and is_zero_approx(soma_cosseno):
		return -1.0
	var graus := rad_to_deg(atan2(soma_seno, soma_cosseno))
	return fposmod(graus, 360.0)


## A qual familia um pixel pertence.
##
## A ORDEM DOS TESTES E A REGRA, e nao um detalhe de escrita -- duas faixas se
## cruzam de proposito:
##
##   PRETO vem primeiro porque ele e definido por VALOR e vale para qualquer
##   matiz: abaixo de 10% de luz o matiz e ruido, e deixar a sombra do andar
##   votar por matiz espalharia preto pelas outras seis familias.
##   AMBAR vem antes de FERRUGEM porque as duas faixas se sobrepoem em 25-45
##   graus, e o que as separa e o valor: ferrugem e oxido escuro, ambar e
##   lampada acesa. Na ordem contraria, todo ponto de luz quente do andar seria
##   contado como oxido.
func _familia_do_pixel(cor: Color) -> int:
	if cor.v <= PRETO_VALOR_MAXIMO:
		return Familia.PRETO
	var matiz := cor.h * 360.0
	if _na_faixa(matiz, AMBAR_MATIZ) and cor.v >= AMBAR_VALOR_MINIMO:
		return Familia.AMBAR
	if _na_faixa(matiz, FERRUGEM_MATIZ) and cor.s > FERRUGEM_SATURACAO_MINIMA:
		return Familia.FERRUGEM
	if _na_faixa(matiz, CINZA_MATIZ) and cor.s <= CINZA_SATURACAO_MAXIMA:
		return Familia.CINZA_AZULADO
	if _na_faixa(matiz, CIANO_MATIZ):
		return Familia.CIANO
	if _na_faixa(matiz, VERDE_MATIZ):
		return Familia.VERDE
	if _na_faixa(matiz, MAGENTA_MATIZ):
		return Familia.MAGENTA
	return Familia.OUTRO


## Faixa meio-aberta no fim, senao o limite entre duas faixas vizinhas
## pertenceria as duas e a contagem passaria a depender da ordem dos `if`.
func _na_faixa(valor: float, faixa: Vector2) -> bool:
	return valor >= faixa.x and valor < faixa.y


## O desvio padrao da luminancia depois de reduzir a textura por BOX.
##
## A reducao e feita na mao, e nao por `Image.resize`: o filtro do motor
## amostra poucos texels e o que se quer aqui e exatamente a MEDIA do bloco --
## a mesma conta que o funil de textura ja usa quando reduz arte grande. E note
## que isto so MEDE: reduzir arte paletizada inventa cor, e por isso nenhum
## pixel daqui volta para o disco.
##
## **A razao pode passar de 100%, e isso nao e defeito.** Media de bloco so
## nunca sobe o desvio quando os blocos sao cheios e do mesmo tamanho; aqui os
## pixels transparentes ficam de fora, entao numa peca recortada -- medido,
## `porta_vao.png` da 130,9% -- alguns blocos guardam so a borda desenhada e a
## dispersao entre blocos cresce. Ler isso como bug levaria alguem a "consertar"
## a conta e apagar justamente o caso que ela descreve: arte de silhueta que
## continua legivel de longe.
func _desvio_da_miniatura(imagem: Image) -> float:
	var largura := imagem.get_width()
	var altura := imagem.get_height()
	var blocos: Array[float] = []
	var y := 0
	while y < altura:
		var x := 0
		while x < largura:
			var soma := 0.0
			var contados := 0
			for dy in FATOR_MINIATURA:
				for dx in FATOR_MINIATURA:
					var px := x + dx
					var py := y + dy
					if px >= largura or py >= altura:
						continue
					var cor := imagem.get_pixel(px, py)
					if cor.a < ALFA_MINIMO:
						continue
					soma += _luma(cor)
					contados += 1
			if contados > 0:
				blocos.append(soma / float(contados))
			x += FATOR_MINIATURA
		y += FATOR_MINIATURA

	if blocos.size() < 2:
		return 0.0
	var media := 0.0
	for l in blocos:
		media += l
	media /= float(blocos.size())
	var variancia := 0.0
	for l in blocos:
		variancia += (l - media) * (l - media)
	return sqrt(maxf(0.0, variancia / float(blocos.size())))


## Rec. 601, a mesma conta de `assinatura_de_superficie.gd` e do
## `laboratorio_icones.gd`. Duas formulas de luminancia no mesmo repositorio
## fariam duas reguas discordarem sobre a mesma arte.
func _luma(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
