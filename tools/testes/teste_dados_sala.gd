extends TesteBase
## Verifica o catalogo de tipos de sala e as cenas que ele aponta.
##
## Por que isto existe: o catalogo virou o painel onde se adiciona conteudo sem
## programar, e e exatamente por isso que ele quebra em silencio. Um id
## digitado errado, um tipo obrigatorio a mais ou uma sala de recompensa com
## inimigos na lista nao produzem erro nenhum no console -- produzem uma run
## travada ou uma vitoria impossivel, minutos depois, no teste de fumaca.

const TIPOS := [
	"res://src/mapa/tipo_combate.tres",
	"res://src/mapa/tipo_boss.tres",
	"res://src/mapa/tipo_arma.tres",
	"res://src/mapa/tipo_item.tres",
	"res://src/mapa/tipo_inicial.tres",
]

## Os tipos que o pedido diz que NUNCA tem inimigos.
const SEM_COMBATE := [
	DadosSala.ID_INICIAL,
	DadosSala.ID_ARMA,
	DadosSala.ID_ITEM,
]


func nome() -> String:
	return "DadosSala"


func executar() -> void:
	_o_tipo_da_cena_concorda_com_o_tipo_que_a_lista()
	var catalogo := _carregar()
	_contrato(catalogo)
	_regras_do_andar(catalogo)
	_salas_sem_combate(catalogo)
	_arma_so_na_sala_de_arma(catalogo)
	_contornos_desenhaveis(catalogo)
	_todo_tipo_aponta_um_kit_de_parede(catalogo)
	_todo_tipo_EM_DISCO_declara_quanta_decoracao_quer()


## TODO TIPO APONTA UM KIT DE PAREDE, e o kit carrega.
##
## O `EstiloDeParede` e o unico campo novo que a PAREDE 05 acrescentou, e ele e
## opcional por construcao: sala sem dados -- aberta sozinha no editor, ou a
## amostra que o catalogo instancia -- cai na lista neutra em disco, e tem de
## continuar caindo. Mas um TIPO sem kit e outra coisa: ele desenharia a parede
## neutra em silencio, e a sala do chefe sairia com o material do corredor sem
## uma linha no console.
##
## O caso tambem cobra que o kit esteja MONTADO. Um `.tres` que carrega mas tem
## a lista de topos vazia passa em qualquer teste de existencia e desenha uma
## sala sem parede -- que e o pior tipo de defeito deste sistema, porque a sala
## continua jogavel.
func _todo_tipo_aponta_um_kit_de_parede(catalogo: Array[DadosSala]) -> void:
	var conferidos := 0
	for dados in catalogo:
		var kit := dados.estilo_de_parede
		ok(kit != null, "o tipo '%s' aponta um kit de parede" % dados.id)
		if kit == null:
			continue
		conferidos += 1
		ok(kit.vestivel(), "o kit '%s' do tipo '%s' esta montado (%d topos)"
			% [kit.id, dados.id, kit.topos.size()])
		for t in kit.topos:
			ok(t != null, "o kit '%s' nao tem topo nulo na lista" % kit.id)
	igual(conferidos, catalogo.size(), "os %d tipos apontam kit (%d)"
		% [catalogo.size(), conferidos])


func _carregar() -> Array[DadosSala]:
	var lista: Array[DadosSala] = []
	for caminho: String in TIPOS:
		var dados: DadosSala = load(caminho)
		ok(dados != null, "%s carrega" % caminho.get_file())
		if dados != null:
			lista.append(dados)
	return lista


func _contrato(catalogo: Array[DadosSala]) -> void:
	var ids: Array[StringName] = []
	for dados in catalogo:
		var etiqueta := String(dados.id)
		ok(dados.id != &"", "%s tem id" % etiqueta)
		ok(not dados.cenas_validas().is_empty(), "%s tem ao menos uma cena" % etiqueta)
		ok(not ids.has(dados.id), "%s nao repete id de outro tipo" % etiqueta)
		ids.append(dados.id)
		ok(dados.cor_mapa.a > 0.0, "%s tem cor visivel no minimapa" % etiqueta)
		ok(dados.distancia_minima_da_origem >= 0, "%s nao pede distancia negativa" % etiqueta)
		if dados.eh_pendurada():
			ok(dados.celulas_reservadas() >= 1, "%s pendurada reserva ao menos uma celula" % etiqueta)


func _regras_do_andar(catalogo: Array[DadosSala]) -> void:
	var obrigatorios: Array[DadosSala] = []
	var pendurados: Array[DadosSala] = []
	var comuns: Array[DadosSala] = []
	var reservadas := 0
	for dados in catalogo:
		if not dados.opcional:
			obrigatorios.append(dados)
		if dados.eh_pendurada():
			pendurados.append(dados)
			reservadas += dados.celulas_reservadas()
		elif not dados.eh_inicial():
			comuns.append(dados)

	ok(not comuns.is_empty(), "existe ao menos um tipo de preenchimento")

	# Duas propriedades DIFERENTES, que e facil confundir:
	#
	#   encerra a run (id == boss) -- tem de ser exatamente um. Com dois, a
	#     primeira sala limpa terminaria a partida.
	#   obrigatorio (opcional == false) -- pode ser quantos forem. So quer dizer
	#     "re-sorteia o andar se este tipo nao couber".
	#
	# O chefe e as duas coisas; a sala de arma e so a segunda.
	var chefes: Array[DadosSala] = []
	for dados in catalogo:
		if dados.id == DadosSala.ID_BOSS:
			chefes.append(dados)
	igual(chefes.size(), 1, "existe exatamente um tipo que encerra a run")
	if chefes.size() == 1:
		ok(not chefes[0].opcional, "o chefe e obrigatorio: sem ele nao ha vitoria")

	# As duas recompensas sao garantidas e aparecem uma vez cada. A de arma e a
	# UNICA fonte de arma do jogo desde que o drop por onda saiu; opcional aqui
	# significaria uma run inteira so com a pistola inicial.
	for id: StringName in [DadosSala.ID_ARMA, DadosSala.ID_ITEM]:
		var recompensas: Array[DadosSala] = []
		for dados in catalogo:
			if dados.id == id:
				recompensas.append(dados)
		var etiqueta := String(id)
		igual(recompensas.size(), 1, "existe exatamente um tipo de sala de %s" % etiqueta)
		if recompensas.size() == 1:
			ok(not recompensas[0].opcional, "a sala de %s e garantida no andar" % etiqueta)
			igual(recompensas[0].celulas_reservadas(), 1, "a sala de %s aparece uma vez por andar" % etiqueta)

	# A sala de entrada tem de ser exatamente uma, e tem de ser INICIAL e nao
	# PENDURADA: pendurada ganha uma celula em qualquer beco, e a entrada tem de
	# ficar na origem, que e onde o Player nasce em main.tscn.
	var iniciais: Array[DadosSala] = []
	for dados in catalogo:
		if dados.eh_inicial():
			iniciais.append(dados)
	igual(iniciais.size(), 1, "existe exatamente um tipo de sala inicial")
	if iniciais.size() == 1:
		igual(String(iniciais[0].id), String(DadosSala.ID_INICIAL), "o tipo inicial usa o id 'inicial'")
		ok(not iniciais[0].opcional, "a sala inicial e obrigatoria")
		igual(iniciais[0].celulas_reservadas(), 0, "a sala inicial nao reserva celula (ela usa a origem)")

	# Quem chega primeiro escolhe a melhor ancora. Se um premio for colocado
	# antes do chefe, ele toma o beco mais distante e o chefe cai no meio do
	# andar -- sem erro nenhum, so um andar pior.
	if chefes.size() == 1:
		for dados in pendurados:
			if dados.id == DadosSala.ID_BOSS:
				continue
			ok(
				chefes[0].prioridade < dados.prioridade,
				"%s e colocada depois do chefe" % String(dados.id)
			)

	# O passeio recebe (total_salas - reservadas). Se as penduradas comerem o
	# orcamento, o andar encolhe abaixo do minimo e o grafo e re-sorteado 24
	# vezes por nada.
	var gerenciador := GerenciadorMapa.new()
	var total: int = gerenciador.total_salas
	gerenciador.free()
	ok(
		reservadas < total - 2,
		"as salas penduradas (%d) cabem no andar de %d sem sufocar o passeio" % [reservadas, total]
	)


## Sala inicial, de arma e de item nunca tem inimigos.
##
## E a garantia literal do pedido, e ela precisa de teste porque a lista de
## inimigos e um array no Inspetor: arrastar um grupo para o .tres errado nao
## produz erro nenhum -- produz um jogador nascendo dentro de um combate, ou uma
## sala de recompensa trancada ate ele limpar o que nao esperava encontrar.
##
## Confere tambem o orcamento, e nao so a lista: com a lista vazia o orcamento
## nao e usado, mas deixa-lo em pe seria uma armadilha para quem no futuro
## adicionar um inimigo ao tipo e receber uma quantidade que ninguem escolheu.
func _salas_sem_combate(catalogo: Array[DadosSala]) -> void:
	var conferidos := 0
	for dados in catalogo:
		if not SEM_COMBATE.has(dados.id):
			continue
		conferidos += 1
		var etiqueta := String(dados.id)
		ok(not dados.tem_combate(), "a sala de %s nunca tem inimigos" % etiqueta)
		igual(dados.orcamento_para(1000000.0), 0, "a sala de %s tem orcamento zero" % etiqueta)

	# Guarda contra a assercao virar decoracao: se um id for renomeado, o laco
	# acima passa inteiro sem ter olhado nada.
	igual(conferidos, SEM_COMBATE.size(), "os tres tipos sem combate estao no catalogo")


## Arma so existe na sala de arma.
##
## Isto passou a ser verificavel agora: antes o drop vinha por CODIGO (o campo
## `solta_arma` do DadosOnda, removido), entao uma sala de combate podia soltar
## arma sem ter pickup nenhum na cena. Sem esse caminho, a unica fonte de arma
## e o pickup instanciado no .tscn -- e e exatamente ai que uma regressao
## entraria, arrastando um PickupArma para dentro de uma sala de combate sem
## nada acusar.
func _arma_so_na_sala_de_arma(catalogo: Array[DadosSala]) -> void:
	var com_pickup := 0
	for dados in catalogo:
		for cena in dados.cenas_validas():
			var tem := _tem_pickup_de_arma(cena)
			var etiqueta := cena.resource_path.get_file()
			if dados.id == DadosSala.ID_ARMA:
				ok(tem, "%s (tipo arma) tem o pickup de arma" % etiqueta)
				if tem:
					com_pickup += 1
			else:
				ok(
					not tem,
					"%s (tipo %s) NAO tem pickup de arma" % [etiqueta, String(dados.id)]
				)

	# Guarda contra a assercao virar decoracao: se nenhuma sala tiver pickup, o
	# laco acima passa inteiro sem ter olhado o caso que importa.
	ok(com_pickup >= 1, "existe ao menos uma sala que de fato entrega arma")


## Procura pelo NOME do no, e nao pela cena instanciada: instanciar so para
## contar filhos custa caro numa suite que roda em menos de um segundo.
func _tem_pickup_de_arma(cena: PackedScene) -> bool:
	var estado := cena.get_state()
	for i in range(estado.get_node_count()):
		if estado.get_node_name(i) == &"PickupArma":
			return true
	return false


## O contorno que o minimapa desenha tem de ser triangulavel, senao a sala sai
## sem preenchimento e ninguem percebe ate olhar a HUD.
##
## O caso que motiva isto: Geometry2D.triangulate_polygon devolve VAZIO quando o
## poligono repete o primeiro ponto no fim -- e todo Line2D "Parede" do projeto
## repete, para fechar o desenho. Sala.contorno_local() remove a repeticao; se
## alguem desfizer isso, a sala em L vira um buraco no mapa em silencio.
func _contornos_desenhaveis(catalogo: Array[DadosSala]) -> void:
	var concavas := 0
	for dados in catalogo:
		for cena in dados.cenas_validas():
			var sala := cena.instantiate() as Sala
			if sala == null:
				ok(false, "%s tem o script Sala na raiz" % cena.resource_path.get_file())
				continue

			var contorno := sala.contorno_local()
			var etiqueta := cena.resource_path.get_file()
			ok(contorno.size() >= 3, "%s tem contorno com ao menos 3 pontos" % etiqueta)

			if contorno.size() >= 3:
				ok(
					not contorno[0].is_equal_approx(contorno[contorno.size() - 1]),
					"%s nao repete o ponto de fechamento" % etiqueta
				)
				ok(
					not Geometry2D.triangulate_polygon(contorno).is_empty(),
					"%s e triangulavel (o minimapa consegue preencher)" % etiqueta
				)
				if contorno.size() > 4:
					concavas += 1

			sala.free()

	# Guarda contra a assercao virar decoracao: se um dia so restarem
	# retangulos, o teste acima passaria sem nunca exercitar o caso dificil.
	ok(concavas > 0, "existe ao menos uma sala nao-retangular para exercitar a triangulacao")


## O `tipo` DA CENA CONCORDA COM O `id` DO TIPO QUE A LISTA.
##
## **`Sala.tipo` e um `@export` gravado no `.tscn`, e nao algo derivado do
## `DadosSala`.** Sao duas fontes para a mesma verdade, e elas divergiram no dia
## em que a Loja nasceu como COPIA da sala de arma: o `.tscn` clonado trouxe
## `tipo = &"arma"` junto, e a Loja passou a se apresentar como sala de arma para
## todo mundo que pergunta.
##
## O sintoma foi o teste de fumaca reprovando em ~25% das execucoes com *"a sala
## tipo=arma nao tem nenhum pickup"* -- ele visitava a LOJA, via o tipo `arma`, e
## procurava uma arma no chao que nunca existiu ali. Nada no console, e a
## intermitencia vinha de qual das duas salas o jogador visitava primeiro.
##
## Clonar cena e o caminho normal para criar sala nova, e o campo que mente nao
## da erro nenhum. Por isso o portao cruza as duas fontes em vez de confiar numa.
func _o_tipo_da_cena_concorda_com_o_tipo_que_a_lista() -> void:
	var conferidas := 0
	var divergentes: Array[String] = []
	for caminho in _tipos_em_disco():
		var dados := load(caminho) as DadosSala
		if dados == null:
			continue
		for cena in dados.cenas_validas():
			var sala := cena.instantiate() as Sala
			if sala == null:
				continue
			conferidas += 1
			if sala.tipo != dados.id:
				divergentes.append("%s diz tipo=%s mas e listada por %s" % [
					cena.resource_path.get_file(), sala.tipo, dados.id])
			sala.free()
	ok(conferidas > 0, "houve cena para conferir (%d)" % conferidas)
	igual(divergentes.size(), 0,
		"toda cena declara o tipo de quem a lista (%s)" % ", ".join(divergentes))


## TODO TIPO declara um `PerfilDeDecoracao`, e a varredura e por DISCO.
##
## Desde a migracao das contagens, quem responde "quantos props esta sala
## recebe" e o perfil -- e `perfil_de_decoracao` nulo devolve ZERO em todas as
## quatro familias. Um tipo novo criado por CLONE (que e o caminho normal aqui:
## foi assim que a Loja nasceu) e salvo sem apontar perfil monta uma sala
## perfeitamente jogavel, com chao, parede, porta e inimigo, e **completamente
## pelada** -- sem uma linha no console, porque decoracao nao tem colisao para
## reclamar e contagem zero nao e erro.
##
## A varredura le a PASTA e nao a lista `TIPOS` de propósito. A lista nao tem a
## Loja, e um tipo fora dela nao reprovaria: ele SUMIRIA da conta, que e o
## defeito que `_nenhum_png_fica_fora_de_regime` ja existiu para consertar.
##
## O caso tambem cobra que o perfil PECA alguma coisa. Um `.tres` com as sete
## contagens em zero carrega, aponta e desenha uma sala vazia -- e passaria em
## qualquer teste que perguntasse so `!= null`.
func _todo_tipo_EM_DISCO_declara_quanta_decoracao_quer() -> void:
	var conferidos := 0
	for caminho in _tipos_em_disco():
		var dados := load(caminho) as DadosSala
		if dados == null:
			continue
		conferidos += 1
		var perfil := dados.perfil_de_decoracao
		ok(perfil != null, "o tipo '%s' aponta um perfil de decoracao" % dados.id)
		if perfil == null:
			continue
		var pedido := (
			dados.faixa_de_props_chapados().y
			+ dados.faixa_de_props_volume().y
			+ dados.faixa_de_decalques().y
		)
		ok(pedido > 0, "o perfil do tipo '%s' pede decoracao de fato (teto %d)"
			% [dados.id, pedido])
		# A faixa e a segunda metade da migracao, e a que fazia a sala parecer
		# vazia com a arte toda em disco: 44 px de faixa contra os 96 de margem
		# que as cenas autoram deixam DOZE pixels uteis para uma peca de 64.
		ok(dados.largura_da_faixa_de_decoracao() > DadosSala.FAIXA_SEM_PERFIL,
			"o tipo '%s' decora numa faixa maior que a de quem nao declara perfil (%.0f)"
				% [dados.id, dados.largura_da_faixa_de_decoracao()])
	ok(conferidos >= 6, "a varredura achou os tipos em disco (%d)" % conferidos)


func _tipos_em_disco() -> Array[String]:
	var saida: Array[String] = []
	var pasta := DirAccess.open("res://src/mapa/")
	if pasta == null:
		return saida
	for nome_do_arquivo in pasta.get_files():
		if nome_do_arquivo.begins_with("tipo_") and nome_do_arquivo.ends_with(".tres"):
			saida.append("res://src/mapa/" + nome_do_arquivo)
	return saida
