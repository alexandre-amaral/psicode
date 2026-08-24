extends TesteBase
## Verifica o catalogo de tipos de sala e as cenas que ele aponta.
##
## Por que isto existe: o catalogo virou o painel onde se adiciona conteudo sem
## programar, e e exatamente por isso que ele quebra em silencio. Um id
## digitado errado, um tipo obrigatorio a mais ou uma sala de recompensa com no
## "Ondas" nao produzem erro nenhum no console -- produzem uma run travada ou
## uma vitoria impossivel, minutos depois, no teste de fumaca.

const TIPOS := [
	"res://src/mapa/tipo_combate.tres",
	"res://src/mapa/tipo_boss.tres",
	"res://src/mapa/tipo_arma.tres",
	"res://src/mapa/tipo_item.tres",
]

## Salas sem combate: quem NAO pode ter um no "Ondas".
const SEM_COMBATE := [
	"res://src/mapa/sala_7_arma.tscn",
	"res://src/mapa/sala_8_item.tscn",
]


func nome() -> String:
	return "DadosSala"


func executar() -> void:
	var catalogo := _carregar()
	_contrato(catalogo)
	_regras_do_andar(catalogo)
	_salas_de_recompensa()
	_contornos_desenhaveis(catalogo)


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
		else:
			comuns.append(dados)

	ok(not comuns.is_empty(), "existe ao menos um tipo de preenchimento")

	# Sem chefe a run nao tem como terminar em vitoria, e com dois o primeiro a
	# ser limpo encerraria tudo.
	igual(obrigatorios.size(), 1, "existe exatamente um tipo obrigatorio")
	if obrigatorios.size() == 1:
		igual(obrigatorios[0].id, DadosSala.ID_BOSS, "o tipo obrigatorio e o chefe")

	# Quem chega primeiro escolhe a melhor ancora. Se um premio for colocado
	# antes do chefe, ele toma o beco mais distante e o chefe cai no meio do
	# andar -- sem erro nenhum, so um andar pior.
	for dados in pendurados:
		if dados.opcional:
			ok(
				obrigatorios.is_empty() or obrigatorios[0].prioridade < dados.prioridade,
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


## A armadilha mais cara deste sistema: sala de recompensa com um no "Ondas" de
## composicao vazia nunca completa a onda, fica OCUPADA para sempre e o teste
## de fumaca queima os 240s de CI. Sem no "Ondas" ela nasce LIMPA e abre as
## portas, que e o contrato de Sala._conectar_ondas().
func _salas_de_recompensa() -> void:
	for caminho: String in SEM_COMBATE:
		var cena: PackedScene = load(caminho)
		ok(cena != null, "%s carrega" % caminho.get_file())
		if cena == null:
			continue
		var estado := cena.get_state()
		var tem_ondas := false
		for i in range(estado.get_node_count()):
			if estado.get_node_name(i) == &"Ondas":
				tem_ondas = true
		ok(not tem_ondas, "%s nao tem no 'Ondas' (senao trava a run)" % caminho.get_file())


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
