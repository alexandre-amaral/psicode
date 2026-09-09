extends Node2D
## A REGUA DA SALA REAL: quantos props uma `Sala` montada de fato COLOCA.
##
## Ela existe porque `laboratorio_decoracao.tscn` responde outra pergunta. Aquele
## mede o `DecoradorDeSala` -- geometria pura, sem cena nenhuma -- e responde "as
## regras de colocacao estao certas?". Esta monta a `Sala` DE VERDADE, com o
## `DadosSala` do tipo, a `area_spawn` autorada, as portas seladas e os atlas em
## disco, e responde a outra metade: **"o que o jogador ve?"**.
##
## As duas perguntas ja se separaram uma vez neste epico, e caro. O `PerfilDeLuz`
## foi escrito por um agente que nao podia rodar o Godot; a regua analitica dele
## concordou com ele e o andar ficou sem luz nenhuma com a suite verde. **Portao
## que mede a MATEMATICA de um efeito nao prova que o efeito aparece.** O mesmo
## valia aqui: o laboratorio media 28 pecas por sala enquanto a sala real
## colocava um punhado, porque a `Sala` usava uma faixa de 44 px que o perfil nao
## conhecia -- e nada em lugar nenhum comparava os dois numeros.
##
## ## O que ela imprime, e por que essas colunas
##
## Por tipo de sala e por familia: o PEDIDO (a faixa do `PerfilDeDecoracao`) ao
## lado do COLOCADO (o que a sala montou, contado na arvore). A distancia entre
## as duas colunas e a unica coisa que interessa: `_ponto_de_prop()` desiste em
## SILENCIO depois de 24 tentativas, entao uma sala que pede 15 e coloca 3 nao
## produz erro nenhum -- ela so fica vazia.
##
## Nao ha portao aqui, e isso e escolha. Quem cobra piso e teto e
## `teste_props.gd`, que roda no CI; esta e a ferramenta de OLHAR antes de girar
## um botao, como o `laboratorio_icones` e o `comparar_caixa`. Um segundo portao
## medindo a mesma coisa de outro jeito e a duplicata que este epico ja pagou
## duas vezes.

const TIPOS := [
	"res://src/mapa/tipo_combate.tres",
	"res://src/mapa/tipo_inicial.tres",
	"res://src/mapa/tipo_arma.tres",
	"res://src/mapa/tipo_item.tres",
	"res://src/mapa/tipo_loja.tres",
	"res://src/mapa/tipo_boss.tres",
]

## Quantas celulas cada tipo e montado. O sorteio e por celula, e uma sala so
## responderia sobre a sorte daquela semente e nao sobre o tipo.
const SALAS_POR_TIPO := 24

## As quatro familias, e o no em que cada uma pendura o que colocou.
##
## O volumetrico e o unico sem raiz propria: ele PRECISA ser filho direto da
## sala para se ordenar por Y contra jogador e inimigo, e ficar sem raiz e o
## preco de participar da ordenacao. Por isso ele e contado pelo NOME do no.
const RAIZES := {
	"chapado": "Decoracao",
	"decalque": "Decalques",
	"frente": "Frente",
	"luz": "Luminarias",
}


func _ready() -> void:
	print("\n=== a densidade da SALA REAL (%d sementes por tipo) ===\n" % SALAS_POR_TIPO)
	print("%-10s %-9s %-12s %8s %8s   %s" % [
		"tipo", "familia", "pedido", "medio", "min-max", "leitura"])
	print("-".repeat(78))
	for caminho in TIPOS:
		_medir_tipo(caminho)
		print("")
	get_tree().quit()


func _medir_tipo(caminho: String) -> void:
	var dados := load(caminho) as DadosSala
	if dados == null:
		print("  %s nao carrega" % caminho)
		return
	var cenas := dados.cenas_validas()
	if cenas.is_empty():
		print("  %s nao lista cena" % dados.id)
		return

	var contagens := {}
	for familia in RAIZES:
		contagens[familia] = PackedInt32Array()
	contagens["volume"] = PackedInt32Array()

	for i in SALAS_POR_TIPO:
		# A cena gira junto com a semente: um tipo com cinco formas so responde
		# sobre o tipo se as cinco entrarem na conta.
		var sala := cenas[i % cenas.size()].instantiate() as Sala
		if sala == null:
			continue
		sala.coordenadas_grid = Vector2i(i * 13, i * 7)
		sala.definir_visual(dados)
		# Longe da origem: outras cenas de tools ficam por la, e o grupo
		# "player" e global -- a mesma loteria que `teste_hack.gd` ja pagou.
		sala.position = Vector2(9000.0, 9000.0)
		add_child(sala)

		for familia in RAIZES:
			var raiz := sala.get_node_or_null(RAIZES[familia]) as Node2D
			contagens[familia].append(raiz.get_child_count() if raiz != null else 0)
		var volumes := 0
		for filho in sala.get_children():
			if filho.is_in_group(Sala.GRUPO_PROP_VOLUME):
				volumes += 1
		contagens["volume"].append(volumes)

		sala.free()

	var pedidos := {
		"chapado": dados.faixa_de_props_chapados(),
		"volume": dados.faixa_de_props_volume(),
		"decalque": dados.faixa_de_decalques(),
		"frente": dados.faixa_de_props_frente(),
		"luz": Vector2i(
			dados.quantidade_luminarias + dados.quantidade_luminarias_frias,
			dados.quantidade_luminarias + dados.quantidade_luminarias_frias),
	}
	var total_pedido := 0.0
	var total_medido := 0.0
	for familia in ["chapado", "volume", "decalque", "frente", "luz"]:
		var faixa: Vector2i = pedidos[familia]
		var amostras: PackedInt32Array = contagens[familia]
		var media := _media(amostras)
		var alvo := (float(faixa.x) + float(faixa.y)) * 0.5
		total_pedido += alvo
		total_medido += media
		print("%-10s %-9s %-12s %8.2f %8s   %s" % [
			dados.id, familia, "%d a %d" % [faixa.x, faixa.y], media,
			"%d-%d" % [_minimo(amostras), _maximo(amostras)],
			_leitura(alvo, media)])
	print("%-10s %-9s %-12s %8.2f" % [dados.id, "TOTAL", "", total_medido])
	if total_pedido > 0.0:
		print("           entrega %.0f%% do que o perfil pede"
			% [total_medido / total_pedido * 100.0])


## Quanto do pedido chegou a tela. `_ponto_de_prop()` desiste em silencio, entao
## a faixa util e a densidade da sala brigam -- e e essa briga que a coluna diz.
func _leitura(alvo: float, medido: float) -> String:
	if alvo <= 0.0:
		return "nao pede" if medido <= 0.0 else "COLOCOU SEM PEDIR"
	var fracao := medido / alvo
	if fracao >= 0.9:
		return "entrega"
	if fracao >= 0.6:
		return "perde alguma"
	return "PERDE A MAIORIA (%.0f%%)" % (fracao * 100.0)


func _media(amostras: PackedInt32Array) -> float:
	if amostras.is_empty():
		return 0.0
	var soma := 0
	for v in amostras:
		soma += v
	return float(soma) / float(amostras.size())


func _minimo(amostras: PackedInt32Array) -> int:
	if amostras.is_empty():
		return 0
	var m := amostras[0]
	for v in amostras:
		m = mini(m, v)
	return m


func _maximo(amostras: PackedInt32Array) -> int:
	if amostras.is_empty():
		return 0
	var m := amostras[0]
	for v in amostras:
		m = maxi(m, v)
	return m
