extends TesteBase
## Verifica a composicao de inimigos: quem pode nascer em que sala, e quantos.
##
## Por que isto existe como suite propria: a composicao virou o UNICO botao de
## dificuldade do andar, e ele e feito de dado no Inspetor -- um `custo` zerado,
## um grupo arrastado para o .tres errado ou uma densidade esquecida em zero nao
## produzem erro nenhum no console. Produzem um andar sem briga, uma sala
## intransponivel ou o jogador nascendo no meio de um combate, e so o teste de
## fumaca perceberia, minutos depois e por acidente.
##
## A conta do orcamento e conferida aqui como funcao pura, sem subir andar: e
## por isso que `DadosSala.orcamento_para()` recebe a area em vez de ler uma
## sala. Testar a curva de dificuldade em segundos vale a assinatura extra.

const GRUPOS := [
	"res://src/enemies/grupo_rastejante.tres",
	"res://src/enemies/grupo_vigia.tres",
	"res://src/enemies/grupo_diretora.tres",
]

const TIPOS := [
	"res://src/mapa/tipo_combate.tres",
	"res://src/mapa/tipo_boss.tres",
	"res://src/mapa/tipo_arma.tres",
	"res://src/mapa/tipo_item.tres",
	"res://src/mapa/tipo_inicial.tres",
]

## As cenas de combate, da menor area para a maior. A ordem e o teste: e ela
## que transforma "sala maior tem mais inimigos" de intencao em verificacao.
const CENAS_DE_COMBATE := [
	"res://src/mapa/sala_2_l_shape.tscn",
	"res://src/mapa/sala_1_retangular.tscn",
	"res://src/mapa/sala_4_corredor.tscn",
	"res://src/mapa/sala_5_pilar.tscn",
	"res://src/mapa/sala_3_grande.tscn",
]


func nome() -> String:
	return "Composicao de inimigos"


func executar() -> void:
	_grupos()
	var catalogo := _carregar_tipos()
	_orcamento_e_funcao_pura()
	_tipo_de_combate(catalogo)
	_tipo_de_chefe(catalogo)
	_escala_por_area(catalogo)


# ------------------------------------------------------------ os grupos -----

func _grupos() -> void:
	var conferidos := 0
	for caminho: String in GRUPOS:
		var grupo: GrupoInimigo = load(caminho)
		var etiqueta := caminho.get_file()
		ok(grupo != null, "%s carrega" % etiqueta)
		if grupo == null:
			continue
		conferidos += 1

		ok(grupo.cena != null, "%s aponta uma cena" % etiqueta)
		ok(grupo.peso > 0.0, "%s tem peso positivo (peso zero nunca e sorteado)" % etiqueta)
		# custo_real() e o piso, nao `custo`: e ele que o sorteio consome, e um
		# zero digitado no Inspetor faria o laco de compra girar para sempre.
		ok(grupo.custo_real() >= 1, "%s custa ao menos 1 do orcamento" % etiqueta)
		ok(grupo.valido(), "%s se considera valido" % etiqueta)

		if grupo.cena != null:
			var inimigo := grupo.cena.instantiate()
			ok(
				inimigo is InimigoBase,
				"%s aponta para um InimigoBase (senao a Sala nao consegue contar a morte dele)" % etiqueta
			)
			inimigo.free()

	igual(conferidos, GRUPOS.size(), "todos os grupos foram conferidos")


func _carregar_tipos() -> Array[DadosSala]:
	var lista: Array[DadosSala] = []
	for caminho: String in TIPOS:
		var dados: DadosSala = load(caminho)
		ok(dados != null, "%s carrega" % caminho.get_file())
		if dados != null:
			lista.append(dados)
	return lista


# ---------------------------------------------------------- o orcamento -----

## A conta em si, sem depender de nenhum .tres. Se a formula mudar, e aqui que
## a mudanca aparece -- e nao num andar gerado que por acaso ficou estranho.
func _orcamento_e_funcao_pura() -> void:
	var d := DadosSala.new()
	d.densidade = 1.0
	d.orcamento_minimo = 0
	d.orcamento_maximo = 99

	igual(d.orcamento_para(DadosSala.AREA_DE_REFERENCIA), 1, "a area de referencia vale 1 de orcamento")
	igual(d.orcamento_para(DadosSala.AREA_DE_REFERENCIA * 5.0), 5, "cinco vezes a area vale cinco vezes o orcamento")
	# Trunca em vez de arredondar: metade de um inimigo nao existe, e arredondar
	# para cima daria um inimigo a mais em toda sala pequena.
	igual(d.orcamento_para(DadosSala.AREA_DE_REFERENCIA * 1.9), 1, "sobra de area nao vira meio inimigo")
	igual(d.orcamento_para(0.0), 0, "area zero nao gera orcamento")

	d.densidade = 2.0
	ok(
		d.orcamento_para(DadosSala.AREA_DE_REFERENCIA * 3.0) > d.orcamento_para(DadosSala.AREA_DE_REFERENCIA * 2.0),
		"area maior gera orcamento maior"
	)

	# Os limites sao o que impede a sala grande de virar uma parede de corpos e
	# a sala em L de nascer vazia.
	d.orcamento_minimo = 4
	d.orcamento_maximo = 6
	igual(d.orcamento_para(1.0), 4, "o piso vale mesmo numa sala minuscula")
	igual(d.orcamento_para(DadosSala.AREA_DE_REFERENCIA * 50.0), 6, "o teto vale mesmo numa sala enorme")

	# Densidade zerada nao significa sala vazia: significa "nao escale por
	# tamanho". E assim que o chefe pede exatamente um.
	d.densidade = 0.0
	d.orcamento_minimo = 1
	d.orcamento_maximo = 1
	igual(d.orcamento_para(DadosSala.AREA_DE_REFERENCIA * 12.0), 1, "densidade zero deixa so o piso valer")


# ------------------------------------------------------------- os tipos -----

func _tipo_de_combate(catalogo: Array[DadosSala]) -> void:
	var combate := _por_id(catalogo, DadosSala.ID_COMBATE)
	ok(combate != null, "o tipo de combate esta no catalogo")
	if combate == null:
		return

	ok(combate.tem_combate(), "a sala de combate tem ao menos um grupo de inimigo")
	ok(combate.densidade > 0.0, "a sala de combate escala por area (densidade %.2f)" % combate.densidade)
	ok(combate.orcamento_minimo >= 1, "a sala de combate nunca nasce vazia")
	ok(
		combate.orcamento_maximo >= combate.orcamento_minimo,
		"o teto da sala de combate nao e menor que o piso"
	)
	# Sala sem escalada de Deterioracao ao limpar faria a barra so subir pela
	# passiva, e a fase CRITICA nunca chegaria numa run limpa.
	ok(combate.deterioracao_ao_limpar > 0.0, "limpar uma sala de combate faz a barra subir")

	# Custos diferentes sao o que permite "menos inimigos, porem piores". Com
	# todos custando igual, o orcamento so mexeria em quantidade.
	var custos: Array[int] = []
	for grupo in combate.grupos_validos():
		if not custos.has(grupo.custo_real()):
			custos.append(grupo.custo_real())
	ok(custos.size() >= 2, "os inimigos de combate tem custos diferentes entre si")


func _tipo_de_chefe(catalogo: Array[DadosSala]) -> void:
	var boss := _por_id(catalogo, DadosSala.ID_BOSS)
	ok(boss != null, "o tipo de chefe esta no catalogo")
	if boss == null:
		return

	# Exatamente um, em qualquer sala: dois chefes na mesma sala e a run
	# terminando na morte do primeiro.
	igual(boss.orcamento_para(1.0), 1, "a sala do chefe da orcamento 1 mesmo minuscula")
	igual(
		boss.orcamento_para(DadosSala.AREA_DE_REFERENCIA * 40.0), 1,
		"a sala do chefe nao ganha um segundo chefe por ser grande"
	)
	igual(boss.grupos_validos().size(), 1, "o tipo de chefe aponta um unico grupo")
	ok(
		boss.deterioracao_minima_ao_entrar >= Deterioracao.LIMIAR_MEDIO,
		"a luta do chefe comeca ao menos na fase MEDIA (valor=%.0f)" % boss.deterioracao_minima_ao_entrar
	)


# ------------------------------------------------------- escala por area -----

## Sala maior recebe mais orcamento -- medido nas cenas de verdade, e nao numa
## area inventada. E a assercao que da sentido ao pedido: a curva de
## dificuldade sai da geometria, sem tabela por cena.
func _escala_por_area(catalogo: Array[DadosSala]) -> void:
	var combate := _por_id(catalogo, DadosSala.ID_COMBATE)
	if combate == null:
		return

	var anterior_area := -1.0
	var anterior_orcamento := -1
	var conferidas := 0

	for caminho: String in CENAS_DE_COMBATE:
		var cena: PackedScene = load(caminho)
		var etiqueta := caminho.get_file()
		if cena == null:
			ok(false, "%s carrega" % etiqueta)
			continue
		var sala := cena.instantiate() as Sala
		if sala == null:
			ok(false, "%s tem o script Sala na raiz" % etiqueta)
			continue

		var area := sala.area_do_contorno()
		var orcamento := combate.orcamento_para(area)
		conferidas += 1

		ok(area > 0.0, "%s tem area positiva (%.0f px2)" % [etiqueta, area])
		ok(orcamento >= 1, "%s recebe ao menos um inimigo (orcamento %d)" % [etiqueta, orcamento])
		ok(
			orcamento <= combate.orcamento_maximo,
			"%s respeita o teto (orcamento %d, teto %d)" % [etiqueta, orcamento, combate.orcamento_maximo]
		)

		# A lista esta ordenada da menor area para a maior. Uma sala maior que a
		# anterior nao pode receber MENOS -- monotonia, nao crescimento estrito:
		# o teto empata as duas maiores de proposito.
		if anterior_area >= 0.0:
			ok(area > anterior_area, "%s e maior que a cena anterior da lista" % etiqueta)
			ok(
				orcamento >= anterior_orcamento,
				"%s nao recebe menos que uma sala menor (%d contra %d)" % [
					etiqueta, orcamento, anterior_orcamento,
				]
			)
		anterior_area = area
		anterior_orcamento = orcamento
		sala.free()

	igual(conferidas, CENAS_DE_COMBATE.size(), "todas as cenas de combate foram medidas")

	# Guarda contra a suite virar decoracao: com todas as salas empatadas no
	# piso ou no teto, as assercoes acima passariam sem nunca exercitar a
	# escala. A menor e a maior TEM de diferir.
	var menor: PackedScene = load(CENAS_DE_COMBATE[0])
	var maior: PackedScene = load(CENAS_DE_COMBATE[CENAS_DE_COMBATE.size() - 1])
	if menor != null and maior != null:
		var sa := menor.instantiate() as Sala
		var sb := maior.instantiate() as Sala
		if sa != null and sb != null:
			ok(
				combate.orcamento_para(sb.area_do_contorno()) > combate.orcamento_para(sa.area_do_contorno()),
				"a maior sala de combate recebe mais que a menor (%d contra %d)" % [
					combate.orcamento_para(sb.area_do_contorno()),
					combate.orcamento_para(sa.area_do_contorno()),
				]
			)
		if sa != null:
			sa.free()
		if sb != null:
			sb.free()


func _por_id(catalogo: Array[DadosSala], id: StringName) -> DadosSala:
	for dados in catalogo:
		if dados.id == id:
			return dados
	return null
