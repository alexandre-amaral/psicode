extends Node
## Regua de ritmo: em que minuto da run cada limiar da Deterioracao cai.
##
## Existe porque a pergunta central da Fase 1 -- "a dificuldade sobe no lugar
## certo?" -- nao tem resposta lendo codigo. O ganho passivo, o ganho por sala
## limpa, a vida dos inimigos e a cadencia das armas moram em quatro arquivos
## diferentes, e o que importa e a soma deles ao longo de uma partida inteira.
##
## O que ele faz: gera N andares de verdade pelo GerenciadorMapa, percorre as
## salas na ordem em que um jogador percorreria, e converte cada sala em SEGUNDOS
## usando a vida real dos inimigos e o DPS real da arma. Dai sai a curva.
##
## O unico chute e o UPTIME -- a fracao do tempo em que o jogador esta de fato
## atirando, em vez de andando, rolando ou esperando o telegrafo passar. Por isso
## ele nao e um numero fixo aqui: a ferramenta varre uma faixa e mostra a curva
## para cada valor. A sessao de tuning olha a faixa, nao um numero.
##
## Nao entra no runner e nao roda no CI: e regua de tuning, nao teste. Teste
## falha quando o codigo quebra; isto muda de resposta toda vez que alguem edita
## um .tres, e e para isso que serve.
##
## Use:  godot --headless --path . tools/medir_ritmo.tscn

const ANDARES := 60

## Fracao do tempo em que o jogador esta atirando. 0.25 e quem joga com cautela,
## rolando muito; 0.55 e quem ja decorou os padroes.
const UPTIMES := [0.25, 0.40, 0.55]

## Combinacoes comparadas lado a lado: ganho passivo por segundo, e quanto a
## barra sobe ao limpar uma sala de combate. A primeira e a que esta no jogo
## agora; as outras sao candidatas.
##
## Os dois juntos, e nao um de cada vez, porque a primeira rodada desta regua
## mostrou que quem domina a curva e o ganho POR SALA, nao o passivo -- varrer
## so o passivo respondia a pergunta errada.
const CANDIDATOS := [
	{"passivo": 0.35, "sala": 8.0, "rotulo": "antes"},
	{"passivo": 0.25, "sala": 6.0, "rotulo": "hoje"},
	{"passivo": 0.20, "sala": 5.0, "rotulo": ""},
	{"passivo": 0.15, "sala": 5.0, "rotulo": ""},
	{"passivo": 0.15, "sala": 4.0, "rotulo": ""},
]

## Quanto o jogador leva para atravessar um corredor e chegar na proxima porta,
## alem do deslocamento medido entre os centros das salas. Cobre a desaceleracao
## na boca da porta e a hesitacao de quem esta lendo o minimapa.
const PEDAGIO_POR_TRAVESSIA := 1.5

const TIPOS := [
	"res://src/mapa/tipo_combate.tres",
	"res://src/mapa/tipo_boss.tres",
	"res://src/mapa/tipo_arma.tres",
	"res://src/mapa/tipo_item.tres",
	"res://src/mapa/tipo_inicial.tres",
]

var _vida_por_cena: Dictionary = {}


func _ready() -> void:
	await get_tree().process_frame
	_medir()
	get_tree().quit(0)


func _medir() -> void:
	print("\n=== RITMO DA RUN: %d andares ===\n" % ANDARES)

	var dps := _dps_da_arma("res://src/weapons/pistola.tres")
	var dps_shotgun := _dps_da_arma("res://src/weapons/shotgun.tres")
	var vida_chefe := _vida_da_cena("res://src/enemies/diretora.tscn")

	print("DPS sustentado (pente + recarga, todo tiro acertando):")
	print("  pistola   %.2f/s" % dps)
	print("  shotgun   %.2f/s  (alcance 256 -- so com os 8 fragmentos acertando)" % dps_shotgun)
	print("chefe: %d HP\n" % vida_chefe)

	var andares := _gerar(dps, vida_chefe)
	if andares.is_empty():
		push_error("medir_ritmo: nenhum andar foi gerado.")
		return

	_tempo_de_luta_do_chefe(vida_chefe, dps)
	_curvas(andares)
	_folego(andares)


# ------------------------------------------------------- geracao dos andares --

## Cada andar vira uma lista de salas na ordem de visita, com o HP de lixo de
## cada uma e a distancia percorrida ate ela. Uptime e passivo NAO entram aqui:
## a mesma lista e reaproveitada por todas as combinacoes.
func _gerar(_dps: float, vida_chefe: int) -> Array:
	var tipos: Array[DadosSala] = []
	for caminho: String in TIPOS:
		tipos.append(load(caminho))

	var lista: Array = []
	for _andar in ANDARES:
		var mapa := GerenciadorMapa.new()
		mapa.tipos_de_sala = tipos
		add_child(mapa)

		var salas: Dictionary = {}
		for filho in mapa.get_children():
			var sala := filho as Sala
			if sala != null:
				salas[sala.coordenadas_grid] = sala

		var percurso: Array = []
		var anterior: Vector2 = Vector2.ZERO
		for celula in _ordem_de_visita(mapa):
			var dados := mapa.dados_da_celula(celula)
			var sala: Sala = salas.get(celula)
			if dados == null or sala == null:
				continue

			var hp := 0
			if dados.id == DadosSala.ID_BOSS:
				hp = vida_chefe
			else:
				for cena in mapa.composicao_da_celula(celula):
					hp += _vida_da_cena_packed(cena)

			var centro := sala.obter_limites().get_center()
			percurso.append({
				"id": dados.id,
				"hp": hp,
				"ganho": dados.deterioracao_ao_limpar,
				"piso": dados.deterioracao_minima_ao_entrar,
				"distancia": 0.0 if percurso.is_empty() else anterior.distance_to(centro),
			})
			anterior = centro

		lista.append(percurso)
		remove_child(mapa)
		mapa.free()
	return lista


## Vizinha nao visitada mais proxima, com o chefe por ultimo -- a mesma regra do
## teste de fumaca, e a mesma que um jogador segue naturalmente: ele varre o
## andar atras dos premios antes de entrar na porta que encerra a run.
func _ordem_de_visita(mapa: GerenciadorMapa) -> Array[Vector2i]:
	var chefe := mapa.celula_do_chefe()
	var visitadas: Dictionary = {Vector2i.ZERO: true}
	var ordem: Array[Vector2i] = [Vector2i.ZERO]
	var atual := Vector2i.ZERO

	while true:
		var proxima := _mais_proxima_nao_visitada(mapa, atual, visitadas, chefe)
		if proxima == atual:
			break
		visitadas[proxima] = true
		ordem.append(proxima)
		atual = proxima

	if not visitadas.has(chefe) and mapa.celulas().has(chefe):
		ordem.append(chefe)
	return ordem


func _mais_proxima_nao_visitada(
	mapa: GerenciadorMapa, de: Vector2i, visitadas: Dictionary, chefe: Vector2i
) -> Vector2i:
	var fila: Array[Vector2i] = [de]
	var vistos: Dictionary = {de: true}
	while not fila.is_empty():
		var atual: Vector2i = fila.pop_front()
		if atual != de and not visitadas.has(atual) and atual != chefe:
			return atual
		for direcao in mapa.vizinhos_de(atual):
			var vizinha := atual + Vector2i(roundi(direcao.x), roundi(direcao.y))
			if vistos.has(vizinha):
				continue
			vistos[vizinha] = true
			fila.append(vizinha)
	return de


# ------------------------------------------------------------------ curvas ----

## A tabela principal: para cada ganho passivo e cada uptime, em que minuto os
## limiares caem e quanto a barra marca ao ENTRAR na sala do chefe.
##
## "no chefe" e o numero que mais importa. Se ele encosta em 100 muito antes,
## a escalada acabou no meio da run e a ultima metade e plana; se fica muito
## abaixo, quem forca a barra e so o piso do .tres do chefe, e a Deterioracao
## deixou de ser a curva de dificuldade que o GDD promete.
func _curvas(andares: Array) -> void:
	var velocidade: float = _velocidade_do_player()
	print("--- curva da Deterioracao (media de %d andares) ---" % andares.size())
	print("A coluna que decide e MEDIA: e a mira preditiva ligando, o diferencial")
	print("declarado do GDD. Ela precisa cair DEPOIS de o jogador ter formado um")
	print("habito de esquiva, senao nao ha habito para virar armadilha.
")
	print("passivo sala uptime | run   | MEDIA(50)      | CRITICA(85)  | no chefe")

	for candidato: Dictionary in CANDIDATOS:
		var passivo: float = candidato["passivo"]
		var por_sala: float = candidato["sala"]
		for uptime: float in UPTIMES:
			var soma_run := 0.0
			var soma_media := 0.0
			var soma_critica := 0.0
			var soma_chefe := 0.0
			var n := 0

			for percurso: Array in andares:
				var r := _simular(percurso, passivo, uptime, velocidade, por_sala)
				soma_run += r["run"]
				soma_media += r["media"]
				soma_critica += r["critica"]
				soma_chefe += r["no_chefe"]
				n += 1

			var run: float = soma_run / n
			var media: float = soma_media / n
			var rotulo := String(candidato.get("rotulo", ""))
			var marca := "" if rotulo.is_empty() else "  <-- " + rotulo
			print("  %.2f   %.0f    %d%%   | %s | %s (%2.0f%% da run) | %s        | %5.1f%%%s" % [
				passivo, por_sala, int(uptime * 100.0),
				_mmss(run),
				_mmss(media),
				0.0 if media < 0.0 else 100.0 * media / maxf(run, 0.01),
				_mmss(soma_critica / n),
				soma_chefe / n,
				marca,
			])
		print("")


## Uma run. Devolve os instantes em segundos; -1 quer dizer "nunca aconteceu".
func _simular(
	percurso: Array, passivo: float, uptime: float, velocidade: float, por_sala: float = -1.0
) -> Dictionary:
	var dps: float = _dps_da_arma("res://src/weapons/pistola.tres") * uptime
	var t := 0.0
	var barra := 0.0
	var media := -1.0
	var critica := -1.0
	var teto := -1.0
	var no_chefe := -1.0

	for sala: Dictionary in percurso:
		# Deslocamento ate a porta desta sala.
		var caminhada: float = float(sala["distancia"]) / maxf(velocidade, 1.0)
		if float(sala["distancia"]) > 0.0:
			caminhada += PEDAGIO_POR_TRAVESSIA
		t += caminhada
		barra = minf(barra + passivo * caminhada, Deterioracao.MAXIMO)

		# O piso do tipo vale na ENTRADA, antes do combate -- e o que poe a luta
		# do chefe em nivel critico mesmo numa run rapida.
		if float(sala["piso"]) >= 0.0:
			barra = maxf(barra, float(sala["piso"]))
		if StringName(sala["id"]) == DadosSala.ID_BOSS:
			no_chefe = barra

		var combate: float = float(sala["hp"]) / maxf(dps, 0.01)
		t += combate
		barra = minf(barra + passivo * combate, Deterioracao.MAXIMO)
		# `por_sala` sobrescreve o valor do .tres, para a regua poder comparar
		# candidatos sem ninguem editar arquivo entre uma rodada e outra.
		var ganho: float = float(sala["ganho"])
		if por_sala >= 0.0 and ganho > 0.0:
			ganho = por_sala
		barra = minf(barra + ganho, Deterioracao.MAXIMO)

		if media < 0.0 and barra >= Deterioracao.LIMIAR_MEDIO:
			media = t
		if critica < 0.0 and barra >= Deterioracao.LIMIAR_CRITICO:
			critica = t
		if teto < 0.0 and barra >= Deterioracao.MAXIMO:
			teto = t

	return {"run": t, "media": media, "critica": critica, "teto": teto, "no_chefe": no_chefe}


## Quanto da run acontece DEPOIS de a barra encostar no teto. E a medida direta
## do defeito: tudo nessa fatia roda com a dificuldade travada no maximo, e
## nenhum ajuste de escalada muda coisa alguma ali.
func _folego(andares: Array) -> void:
	var velocidade: float = _velocidade_do_player()
	print("--- fatia da run com a barra ja no teto (100%) ---")
	print("passivo sala        | uptime 25%  40%  55%")
	for candidato: Dictionary in CANDIDATOS:
		var passivo: float = candidato["passivo"]
		var por_sala: float = candidato["sala"]
		var rotulo := String(candidato.get("rotulo", ""))
		var linha := "  %.2f   %.0f %-6s|  " % [passivo, por_sala, rotulo]
		for uptime: float in UPTIMES:
			var soma := 0.0
			for percurso: Array in andares:
				var r := _simular(percurso, passivo, uptime, velocidade, por_sala)
				var run: float = r["run"]
				var teto: float = r["teto"]
				soma += 0.0 if teto < 0.0 else (run - teto) / maxf(run, 0.01)
			linha += "%3.0f%% " % (100.0 * soma / andares.size())
		print(linha)
	print("")


## Tempo de luta do chefe por uptime. E o numero que o roadmap pede observado --
## aqui esta o intervalo em que a observacao deve cair, para a sessao saber se o
## que o testador relatar e normal ou sintoma.
func _tempo_de_luta_do_chefe(vida: int, dps: float) -> void:
	print("--- luta do chefe: %d HP ---" % vida)
	for uptime: float in UPTIMES:
		print("  uptime %d%%  ->  %s   (%.0f s)" % [
			int(uptime * 100.0), _mmss(float(vida) / (dps * uptime)), float(vida) / (dps * uptime),
		])
	print("  faixa boa para tres fases: 60 a 90 s\n")


# ------------------------------------------------------------------ leitura ---

## DPS sustentado: o pente e a recarga entram na conta. Sem eles a pistola
## pareceria 30% mais forte do que e, e a comparacao com a shotgun mentiria --
## a shotgun tem pente 6 e recarga 1.5 s, entao ela perde MAIS para o ciclo.
func _dps_da_arma(caminho: String) -> float:
	var dados: DadosArma = load(caminho)
	if dados == null or dados.cadencia <= 0.0:
		return 1.0
	var por_tiro := float(dados.dano * dados.projeteis_por_tiro)
	if dados.tamanho_pente <= 0 or dados.tamanho_pente > 999:
		return por_tiro * dados.cadencia
	var ciclo := float(dados.tamanho_pente) / dados.cadencia + dados.tempo_recarga
	return por_tiro * float(dados.tamanho_pente) / maxf(ciclo, 0.01)


func _vida_da_cena(caminho: String) -> int:
	return _vida_da_cena_packed(load(caminho))


func _vida_da_cena_packed(cena: PackedScene) -> int:
	if cena == null:
		return 0
	if _vida_por_cena.has(cena):
		return int(_vida_por_cena[cena])
	var no := cena.instantiate()
	var vida := int(no.get("vida_maxima")) if no.get("vida_maxima") != null else 0
	no.free()
	_vida_por_cena[cena] = vida
	return vida


func _velocidade_do_player() -> float:
	var cena: PackedScene = load("res://src/player/player.tscn")
	if cena == null:
		return 330.0
	var no := cena.instantiate()
	var v := float(no.get("velocidade_max")) if no.get("velocidade_max") != null else 330.0
	no.free()
	return v


func _mmss(segundos: float) -> String:
	if segundos < 0.0:
		return "  --  "
	return "%02d:%02d" % [int(segundos) / 60, int(segundos) % 60]
