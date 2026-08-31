extends Node
## Teste de fumaca automatizado. Roda o jogo inteiro sem janela e sem humano:
## mata os inimigos por script para limpar as salas, arranha o chefe aos poucos
## para que as tres fases dele realmente executem, ANDA pelo andar de sala em
## sala ate o chefe, e falha se aparecer qualquer erro de script ou se a run nao
## terminar em vitoria dentro do tempo.
##
## Decisao de design deste arquivo: o teste nao simula input. Ele conversa com o
## GerenciadorMapa pela API de teste (`celulas`, `vizinhos_de`,
## `celula_do_chefe`, `ir_para_sala`), porque fazer o boneco caminhar corredor
## afora daria um teste lento e sensivel a colisao -- o que se quer verificar
## aqui e que o andar inteiro carrega, ativa e limpa, nao que o personagem sabe
## andar.
##
## Segunda decisao: a sala do chefe fica por ultimo de proposito. Chegar nela
## termina a run, entao ir direto para la passaria o teste sem ter tocado no
## resto do andar. Entre as demais, o criterio de escolha e aproximar do chefe.
##
## Terceira decisao: o teste mata inimigo por grupo, onde quer que ele esteja --
## e por isso ele nao enxerga POSICAO de graca. Ja passou verde uma build em que
## todas as salas spawnavam na origem do mundo, porque `area_spawn` e local a
## sala e estava sendo usada como coordenada global. Por isso existe aqui a
## conferencia de que todo inimigo nasce dentro da sala que o spawnou, a
## Diretora inclusive. Sem ela, esta ferramenta so prova que o andar carrega e
## limpa, nao que o combate acontece onde o jogador esta.
##
## Use:  godot --headless --path . tools/teste_fumaca.tscn
## Saida 0 = passou. Qualquer outra coisa = quebrou.

const TEMPO_LIMITE := 240.0
const INTERVALO_TICK := 0.12
## O chefe apanha DEVAGAR, e o numero e calibrado e nao chutado: 300 de vida a
## 2 por tique de 0,12 s da ~18 s de luta simulada, e a fase Absoluta (ultimos
## 15% da vida) recebe ~2,7 s -- tempo suficiente para a primeira torre subir,
## que acontece 1,5 s depois do "Recalculando...". Com os 9 antigos a luta
## inteira durava 4 s e a fase 4 nunca chegava a existir: o teste passaria verde
## sobre um trecho do jogo que nunca rodou.
const DANO_POR_TICK_CHEFE := 2

## Quanto o teste espera o GerenciadorMapa aparecer no grupo antes de desistir.
## Falhar aqui e muito melhor que ficar parado ate o tempo limite: a mensagem
## diz o que quebrou, o tempo limite so diz que demorou.
const TEMPO_ESPERA_MAPA := 5.0

## Respiro entre uma sala e a seguinte, para a chegada assentar antes de o teste
## pedir a proxima.
const INTERVALO_AVANCO := 0.35

## Folga aceita entre a borda da sala e o ponto onde o inimigo foi visto pela
## primeira vez. Cobre a espessura da parede e o passo que ele pode ter dado no
## frame entre nascer e ser conferido. E pequena de proposito: o defeito que
## esta conferencia existe para pegar joga o inimigo salas inteiras de
## distancia, nao 48 pixels.
const FOLGA_SPAWN := 64.0

## Um spawn errado costuma errar TODOS os spawns daquela sala. Relatar cada um
## enterraria o resto do diagnostico; o que passar do limite vira uma linha de
## contagem no fim, entao nada e escondido.
const MAX_RELATOS_SPAWN := 6

var _t: float = 0.0
var _t_tick: float = 0.0
var _t_avanco: float = 0.0
var _eventos: Array[String] = []
var _falhas: Array[String] = []
var _terminou := false

var _mapa: GerenciadorMapa = null
var _celula_atual: Vector2i = Vector2i.ZERO
var _visitadas: Dictionary = {}
var _salas_percorridas: int = 0
## Tipo de sala de recompensa -> se um pickup foi visto dentro dela.
var _recompensas_conferidas: Dictionary = {}
## Tipo de sala sem combate -> se ja foi visitada e vista vazia.
var _salas_sem_combate_conferidas: Dictionary = {}

## id de instancia -> true. Cada inimigo e conferido uma vez so, no primeiro
## frame em que aparece no grupo.
var _spawns_conferidos: Dictionary = {}
var _spawns_fora: int = 0
var _chefe_conferido: bool = false
## Como o chefe DESTE andar se chama, e quantas fases ele declara.
##
## Lidos do proprio chefe quando ele aparece, e nao cravados aqui: a Diretora tem
## quatro fases e o Automato tem tres, e um numero fixo reprovaria o chefe certo
## no dia em que o andar trocasse de chefe -- que e exatamente o que a BOSS 11
## faz. O default cobre quem nao declara.
var _nome_do_chefe: String = "o chefe"
var _fases_declaradas: int = 4
## As fases que o chefe de fato executou. O log ja imprimia isso; aqui ele vira
## assert -- um repertorio que nunca roda e um repertorio que ninguem testou.
var _fases_do_chefe: Array[int] = []

## id de instancia -> true, por tipo de inimigo visto. Existe para o relatorio
## dizer QUAIS dos sete tipos a run exercitou -- com porta por Deterioracao,
## nem todos aparecem em todo andar, e "passou" sem essa linha nao diz se o
## inimigo novo chegou a rodar uma vez sequer.
var _tipos_vistos: Dictionary = {}
## Areas de perigo ja contadas. Mesma ideia: prova que o caminho rodou.
var _areas_vistas: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("\n=== TESTE DE FUMACA: psicode ===\n")

	_testar_balistica()

	EventBus.fase_deterioracao_mudou.connect(func(n: int, _a: int) -> void: _log("fase_deterioracao -> %s" % Deterioracao.nome_fase()))
	EventBus.boss_revelado.connect(func(nome: String, hp: int) -> void: _log("boss_revelado %s (%d hp)" % [nome, hp]))
	EventBus.boss_fase_mudou.connect(func(f: int) -> void:
		_log("boss_fase -> %d" % f)
		if not _fases_do_chefe.has(f):
			_fases_do_chefe.append(f)
	)
	EventBus.boss_morreu.connect(func() -> void: _log("boss_morreu"))
	EventBus.sala_limpa.connect(_ao_sala_limpa)
	EventBus.run_terminada.connect(_ao_terminar)

	add_child(preload("res://src/main/main.tscn").instantiate())


func _process(delta: float) -> void:
	if _terminou:
		return
	_t += delta
	if _t > TEMPO_LIMITE:
		_falhar("tempo limite de %.0fs estourado (parou em %s)" % [TEMPO_LIMITE, _descricao_da_sala()])
		_encerrar()
		return

	if not _achar_mapa():
		return

	# O jogador nunca morre no teste -- queremos exercitar o caminho da vitoria.
	var player := get_tree().get_first_node_in_group("player")
	if player != null and is_instance_valid(player) and "vida" in player:
		if player.vida < player.vida_maxima:
			player.vida = player.vida_maxima

	_t_avanco -= delta
	_avancar_se_der()

	# Todo frame, e ANTES do tick de dano: quem apanha ali morre e sai do grupo
	# no mesmo frame. Conferir depois deixaria de olhar justamente os inimigos
	# que nasceram e morreram entre dois ticks.
	_conferir_spawns()
	_contar_areas()

	_t_tick -= delta
	if _t_tick > 0.0:
		return
	_t_tick = INTERVALO_TICK
	_bater_nos_inimigos()


func _bater_nos_inimigos() -> void:
	for no in get_tree().get_nodes_in_group("inimigo"):
		if not is_instance_valid(no) or not no.has_method("receber_dano"):
			continue
		# O chefe apanha devagar de proposito: se morresse de uma vez, as
		# transicoes de fase e os padroes de ataque nunca rodariam.
		var dano := DANO_POR_TICK_CHEFE if no.get("nome_exibicao") != null else 999
		no.receber_dano(dano, Vector2.ZERO)


# ---------------------------------------------------- spawn dentro da sala ---

## Cada inimigo e conferido no primeiro frame em que existe, que e o mais perto
## que da para chegar de "no momento em que nasce" sem depender de sinal: o
## EventBus.inimigo_spawnou e emitido no _ready do InimigoBase, ou seja, durante
## o add_child -- ANTES de quem spawna atribuir a posicao. Escutar aquele sinal
## medira sempre a origem do container, e passaria verde com qualquer defeito de
## coordenada.
func _conferir_spawns() -> void:
	for no in get_tree().get_nodes_in_group("inimigo"):
		var inimigo := no as Node2D
		if inimigo == null or not is_instance_valid(inimigo):
			continue
		var id := inimigo.get_instance_id()
		if _spawns_conferidos.has(id):
			continue
		_spawns_conferidos[id] = true
		_tipos_vistos[inimigo.scene_file_path.get_file().get_basename()] = true
		_conferir_um_spawn(inimigo)


func _conferir_um_spawn(inimigo: Node2D) -> void:
	var eh_chefe: bool = inimigo.get("nome_exibicao") != null
	if eh_chefe:
		_chefe_conferido = true
		_nome_do_chefe = String(inimigo.get("nome_exibicao"))
		var fases: Variant = inimigo.get("total_de_fases")
		if fases != null:
			_fases_declaradas = int(fases)

	var pos := inimigo.global_position
	var dona := _sala_hospedeira(inimigo)
	if dona == null:
		_relatar_spawn_fora("%s nasceu em %s e nao tem nenhuma Sala acima dele na arvore -- foi parar fora do andar" % [
			_apelido(inimigo, eh_chefe),
			_ponto(pos),
		])
		return

	var limites := dona.obter_limites()
	if limites.grow(FOLGA_SPAWN).has_point(pos):
		# Estar dentro de UMA sala nao basta para o chefe: a Diretora tem de
		# nascer na sala do chefe.
		if eh_chefe and dona.tipo != DadosSala.ID_BOSS:
			_relatar_spawn_fora("%s nasceu em %s, dentro da sala %s tipo=%s -- deveria nascer na sala do chefe" % [
				_nome_do_chefe,
				_ponto(pos),
				dona.coordenadas_grid,
				dona.tipo,
			])
		return

	var texto := "%s nasceu FORA da sala que o spawnou. posicao=%s | sala=%s tipo=%s | retangulo=%s | folga aceita=%.0fpx | esta a %.0fpx do centro da sala e a %.0fpx da origem do mundo" % [
		_apelido(inimigo, eh_chefe),
		_ponto(pos),
		dona.coordenadas_grid,
		dona.tipo,
		_retangulo(limites),
		FOLGA_SPAWN,
		pos.distance_to(limites.get_center()),
		pos.length(),
	]
	# O caso que mais engana: Vector2.ZERO literal no spawn parece inocente e
	# so aparece quando a sala nao esta na origem do mundo.
	if pos.length() <= FOLGA_SPAWN:
		texto += " -- nascer colado no (0,0) e sintoma de posicao local usada como global, ou de Vector2.ZERO literal"
	_relatar_spawn_fora(texto)


## Marca as areas novas do frame. So contar no fim nao serviria: elas se
## liberam sozinhas depois de explodir, entao no fim da run o certo e nao haver
## nenhuma -- e a guarda ficaria sem saber se alguma chegou a existir.
func _contar_areas() -> void:
	for area in _todas_as_areas():
		_areas_vistas[area.get_instance_id()] = true


## Todas as AreaDePerigo ainda vivas na arvore.
##
## Varre a arvore em vez de usar um grupo: a area nao entra em grupo nenhum, e
## por o teste a depender de um grupo criaria a chance de a guarda passar verde
## so porque alguem esqueceu o add_to_group.
func _todas_as_areas() -> Array[Node]:
	return _varrer_areas(get_tree().root)


func _varrer_areas(raiz: Node) -> Array[Node]:
	var lista: Array[Node] = []
	for filho in raiz.get_children():
		if filho is AreaDePerigo:
			lista.append(filho)
		lista.append_array(_varrer_areas(filho))
	return lista


## Sobe pelos pais ate achar a Sala dona. Em ferramenta de teste isto e leitura
## de estado, nao acoplamento de jogo: e o unico jeito de saber qual sala
## spawnou aquele inimigo em particular, incluindo os invocados pelo chefe.
func _sala_hospedeira(inimigo: Node) -> Sala:
	var atual: Node = inimigo.get_parent()
	while atual != null:
		var sala := atual as Sala
		if sala != null:
			return sala
		atual = atual.get_parent()
	return null


func _relatar_spawn_fora(texto: String) -> void:
	_spawns_fora += 1
	if _spawns_fora <= MAX_RELATOS_SPAWN:
		_falhar(texto)


func _apelido(inimigo: Node2D, eh_chefe: bool) -> String:
	if eh_chefe:
		return _nome_do_chefe
	return "o inimigo '%s'" % inimigo.name


func _ponto(v: Vector2) -> String:
	return "(%.0f, %.0f)" % [v.x, v.y]


func _retangulo(r: Rect2) -> String:
	return "x[%.0f..%.0f] y[%.0f..%.0f]" % [r.position.x, r.end.x, r.position.y, r.end.y]


# --------------------------------------------------------------- travessia ---

## Busca por grupo e a excecao legitima ao EventBus, e aqui ela e ainda mais
## defensavel: isto e ferramenta de teste, nao codigo de jogo.
func _achar_mapa() -> bool:
	if _mapa != null and is_instance_valid(_mapa):
		return true

	_mapa = get_tree().get_first_node_in_group("gerenciador_mapa") as GerenciadorMapa
	if _mapa == null:
		if _t > TEMPO_ESPERA_MAPA:
			_falhar("nenhum GerenciadorMapa no grupo 'gerenciador_mapa' apos %.0fs -- o andar nao foi gerado" % TEMPO_ESPERA_MAPA)
			_encerrar()
		return false

	if _mapa.celulas().is_empty():
		_falhar("GerenciadorMapa apareceu sem nenhuma celula -- grafo vazio")
		_encerrar()
		return false

	# A run acabou de comecar, entao nenhum implante pode estar ativo. Conferir
	# aqui, e nao no fim: no fim o proprio teste ja instalou os dele.
	if not Modificadores.itens_ativos().is_empty():
		_falhar("a run comecou com %d implante(s) ativos -- iniciar_run parou de resetar Modificadores, e a dificuldade vaza de uma run para a seguinte" % Modificadores.itens_ativos().size())

	_log("mapa pronto: %d celulas, chefe em %s" % [_mapa.celulas().size(), _mapa.celula_do_chefe()])
	_instalar_todos_os_implantes()
	_registrar_chegada()
	return true


## So sai da sala quando ela esta LIMPA.
##
## Sonda o ESTADO em vez de esperar o sinal `sala_limpa` de proposito. A sala de
## recompensa nasce limpa no _ready, entao o sinal dela sai por outro caminho e
## noutro instante (em `ativar()`, na chegada) do que o de uma sala de combate.
## Depender do sinal amarraria o avanco a essa diferenca; o estado e o mesmo
## para as duas.
func _avancar_se_der() -> void:
	if _t_avanco > 0.0:
		return
	var sala := _mapa.sala_atual
	if sala == null or sala.estado != Sala.Estado.LIMPA:
		return

	var passo := _proximo_passo()
	if passo.is_empty():
		# Andar inteiro percorrido: so falta o chefe cair, e quem termina a run e
		# a morte dele.
		return

	_t_avanco = INTERVALO_AVANCO
	_mapa.ir_para_sala(passo[0])
	_registrar_chegada()


func _registrar_chegada() -> void:
	var sala := _mapa.sala_atual
	if sala == null:
		return
	_celula_atual = sala.coordenadas_grid
	var revisita := _visitadas.has(_celula_atual)
	_visitadas[_celula_atual] = true
	if not revisita:
		_salas_percorridas += 1
	_conferir_recompensa(sala)
	_conferir_sala_sem_combate(sala)
	_log("sala %d/%d %s tipo=%s%s" % [
		_salas_percorridas,
		_mapa.celulas().size(),
		_celula_atual,
		sala.tipo,
		"  (voltando)" if revisita else "",
	])


## Instala TODOS os implantes do pool antes da run comecar.
##
## Sem isto o teste nunca exercita ricochete, fragmentacao, vampirismo, cargas
## nem marcador: ele nao anda ate os pickups, entao a run inteira roda com o
## sistema de implantes zerado e um crash em qualquer um desses caminhos passa
## despercebido. Ligando todos de uma vez, cada tiro do jogador atravessa o
## codigo novo -- e um erro vira falha aqui, nao no playtest.
##
## O efeito colateral e proposital: a run fica mais facil. Nao importa, porque
## o que este teste verifica e que ela TERMINA, nao o balanceamento.
func _instalar_todos_os_implantes() -> void:
	var pool: PoolLoot = load("res://src/items/pool_padrao.tres")
	if pool == null:
		_falhar("pool_padrao.tres nao carregou -- nenhum implante foi exercitado")
		return

	var instalados := 0
	for item in pool.itens_validos():
		if Modificadores.aplicar(item):
			instalados += 1

	if instalados == 0:
		_falhar("nenhum implante do pool pode ser instalado -- o codigo de implante nao vai rodar nesta run")
		return
	_log("implantes instalados: %d de %d" % [instalados, pool.itens_validos().size()])


## Sala de recompensa entregou mesmo a recompensa?
##
## Sem isto o teste passa verde com uma sala de arma vazia: ele visita, marca
## como limpa (ela nasce limpa) e segue. E o mesmo buraco que a conferencia de
## spawn existe para tapar -- o pickup esta no .tscn, e .tscn quebra calado.
##
## Confere tambem que o pickup nasceu DENTRO da sala, porque um pickup fora da
## geometria e inalcancavel e equivale a nao existir.
func _conferir_recompensa(sala: Sala) -> void:
	if sala.tipo != DadosSala.ID_ARMA and sala.tipo != DadosSala.ID_ITEM:
		return
	if _recompensas_conferidas.get(sala.tipo, false):
		return

	var achados := 0
	for filho in sala.get_children():
		var area := filho as Area2D
		if area == null or not ("dados" in area):
			continue
		achados += 1
		if area.get("dados") == null:
			_falhar("a sala %s tipo=%s tem um pickup sem dados -- o sorteio do pool falhou" % [
				sala.coordenadas_grid, sala.tipo,
			])
		if not sala.obter_limites().grow(FOLGA_SPAWN).has_point(area.global_position):
			_falhar("o pickup da sala %s tipo=%s nasceu fora da geometria dela (pos=%s, sala=%s)" % [
				sala.coordenadas_grid, sala.tipo, area.global_position, sala.obter_limites(),
			])

	if achados == 0:
		_falhar("a sala %s tipo=%s nao tem nenhum pickup dentro -- a recompensa nao existe" % [
			sala.coordenadas_grid, sala.tipo,
		])
	else:
		_recompensas_conferidas[sala.tipo] = true
		_log("recompensa conferida em %s tipo=%s (%d pickup)" % [
			sala.coordenadas_grid, sala.tipo, achados,
		])


## Sala inicial, de arma e de item tem de estar VAZIAS na chegada.
##
## E a verificacao em runtime do que os .tres prometem. teste_composicao.gd ja
## confere que esses tipos tem lista de inimigos vazia; esta aqui confere o
## outro lado -- que ninguem MAIS pos inimigo la dentro. Um chefe invocando por
## cima do limite, um pickup que spawna guarda, um tipo novo herdando a lista
## errada: nada disso aparece no .tres, e todos poriam o jogador diante de um
## combate onde ele deveria estar em paz.
##
## Conferida na chegada, que e quando `ativar()` acabou de rodar e a composicao
## ja foi colocada. Antes disso a sala esta vazia por nao ter comecado.
func _conferir_sala_sem_combate(sala: Sala) -> void:
	if sala.tipo != DadosSala.ID_INICIAL and sala.tipo != DadosSala.ID_ARMA \
			and sala.tipo != DadosSala.ID_ITEM:
		return

	var dentro: Array[String] = []
	for no in get_tree().get_nodes_in_group("inimigo"):
		var inimigo := no as Node2D
		if inimigo == null or not is_instance_valid(inimigo):
			continue
		if _sala_hospedeira(inimigo) == sala:
			dentro.append(inimigo.name)

	if dentro.is_empty():
		_salas_sem_combate_conferidas[sala.tipo] = true
		return

	_falhar("a sala %s tipo=%s tem %d inimigo(s) dentro (%s) -- este tipo de sala nunca pode ter combate" % [
		sala.coordenadas_grid, sala.tipo, dentro.size(), ", ".join(dentro),
	])


## Primeiro passo do caminho mais curto ate a celula nao visitada mais proxima.
## Sai de graca dai o retorno por beco sem saida: se a celula atual nao tem
## vizinho novo, o caminho mais curto simplesmente comeca voltando.
## Devolve lista vazia quando nao ha mais para onde ir.
func _proximo_passo() -> Array[Vector2i]:
	var vazio: Array[Vector2i] = []
	var alvos := _alvos()
	if alvos.is_empty():
		return vazio

	var anterior: Dictionary = {_celula_atual: _celula_atual}
	var fila: Array[Vector2i] = [_celula_atual]
	while not fila.is_empty():
		var atual: Vector2i = fila.pop_front()
		if atual != _celula_atual and alvos.has(atual):
			var passo := atual
			while anterior[passo] != _celula_atual:
				passo = anterior[passo]
			var rota: Array[Vector2i] = [passo]
			return rota
		for direcao in _rumo_ao_chefe(_mapa.vizinhos_de(atual), atual):
			var proxima := atual + _para_grid(direcao)
			if anterior.has(proxima):
				continue
			anterior[proxima] = atual
			fila.append(proxima)

	_falhar("celula %s nao alcanca nenhuma das %d salas que faltam -- grafo desconexo" % [_celula_atual, alvos.size()])
	_encerrar()
	return vazio


## Celulas que ainda faltam. A do chefe fica de fora ate ser a ultima: entrar
## nela termina a run, entao ela e o fim do percurso, nunca um atalho.
func _alvos() -> Array[Vector2i]:
	var pendentes: Array[Vector2i] = []
	var chefe := _mapa.celula_do_chefe()
	var chefe_pendente := false
	for celula in _mapa.celulas():
		if _visitadas.has(celula):
			continue
		if celula == chefe:
			chefe_pendente = true
			continue
		pendentes.append(celula)
	if pendentes.is_empty() and chefe_pendente:
		pendentes.append(chefe)
	return pendentes


## Empate entre vizinhos vai para quem encosta mais no chefe: o percurso desce o
## andar em direcao a ele em vez de zigue-zaguear. As distancias sao calculadas
## antes e o comparador so le o dicionario -- lambda que chama metodo do proprio
## script dentro de sort_custom e terreno onde ja se perdeu tempo aqui.
func _rumo_ao_chefe(direcoes: Array[Vector2], origem: Vector2i) -> Array[Vector2]:
	var chefe := _mapa.celula_do_chefe()
	var distancias: Dictionary = {}
	var lista: Array[Vector2] = []
	for direcao in direcoes:
		lista.append(direcao)
		distancias[direcao] = _distancia_grid(origem + _para_grid(direcao), chefe)
	lista.sort_custom(func(a: Vector2, b: Vector2) -> bool: return int(distancias[a]) < int(distancias[b]))
	return lista


func _distancia_grid(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _para_grid(direcao: Vector2) -> Vector2i:
	return Vector2i(roundi(direcao.x), roundi(direcao.y))


func _descricao_da_sala() -> String:
	if _mapa == null or not is_instance_valid(_mapa) or _mapa.sala_atual == null:
		return "nenhuma sala ativa"
	return "%s tipo=%s estado=%d (%d/%d salas)" % [
		_celula_atual,
		_mapa.sala_atual.tipo,
		_mapa.sala_atual.estado,
		_salas_percorridas,
		_mapa.celulas().size(),
	]


# ------------------------------------------------------------------ fim ------

func _ao_sala_limpa(sala: Node2D) -> void:
	var limpa := sala as Sala
	if limpa != null:
		_log("sala_limpa %s tipo=%s" % [limpa.coordenadas_grid, limpa.tipo])
	else:
		_log("sala_limpa de um no que nao e Sala: %s" % sala)
	# Limpou: pode seguir ja no proximo frame, sem esperar o respiro acabar.
	_t_avanco = 0.0


func _ao_terminar(venceu: bool, dados: Dictionary) -> void:
	if _terminou:
		return
	_log("run_terminada venceu=%s %s" % [venceu, dados])
	var tipos := _tipos_vistos.keys()
	tipos.sort()
	_log("tipos de inimigo vistos (%d): %s" % [tipos.size(), ", ".join(tipos)])
	if not venceu:
		_falhar("a run terminou em derrota")

	# Assercao que nunca olhou ninguem passa verde igual a assercao que passou.
	# Estes dois checks existem para que a conferencia de spawn nao possa virar
	# decoracao sem alguem perceber.
	if _spawns_conferidos.is_empty():
		_falhar("nenhum inimigo apareceu no grupo 'inimigo' durante a run inteira -- a conferencia de spawn nao chegou a rodar")
	# Todas as viradas tem de ter acontecido. A fase 1 e o estado inicial e nao
	# emite sinal, entao o que se cobra sao as transicoes -- e quantas sao vem do
	# CHEFE e nao daqui: a Diretora tem quatro fases e o Automato tem tres.
	if venceu:
		for f in range(2, _fases_declaradas + 1):
			if not _fases_do_chefe.has(f):
				_falhar("a luta terminou sem a fase %d de %s -- fases vistas: %s" % [
					f, _nome_do_chefe, _fases_do_chefe,
				])

	if venceu and not _chefe_conferido:
		_falhar("a run venceu sem que o teste visse o chefe vivo -- a posicao de nascimento dele nao foi conferida")

	# Os tipos de recompensa sao opcionais no andar, entao nao da para exigir os
	# dois. Mas se NENHUM apareceu em nenhuma run, algo esta errado na colocacao
	# -- e a conferencia acima nunca rodou.
	# Area de perigo que sobrevive ao dono e dano vindo de um inimigo que nao
	# existe mais -- o jogador nao consegue atribuir aquilo a nada, e le como
	# bug. O Hacker Parasita morre em toda run, entao as areas dele tem de ir
	# junto; e as que ele semeou e explodiram tem de se liberar sozinhas.
	var orfas := _todas_as_areas().size()
	if orfas > 0:
		_falhar("sobraram %d area(s) de perigo vivas no fim da run -- elas nao morreram com quem as semeou" % orfas)
	# O Hacker Parasita tem porta por Deterioracao, entao ele NAO aparece em
	# todo andar. Exigir que a guarda tenha visto uma area deixaria este teste
	# vermelho por sorteio; o que da para afirmar sem ser instavel e quantas
	# foram vistas, e a linha abaixo poe isso no relatorio.
	_log("areas de perigo criadas nesta run: %d" % _areas_vistas.size())

	if venceu and _recompensas_conferidas.is_empty():
		_falhar("o andar inteiro saiu sem sala de arma nem de item -- a colocacao das recompensas nao rodou")

	# A sala inicial existe em toda run, entao esta e a unica das guardas que
	# pode ser exigida por tipo: se ela nao foi conferida vazia, a conferencia
	# de sala sem combate nao rodou nenhuma vez.
	if not _salas_sem_combate_conferidas.get(DadosSala.ID_INICIAL, false):
		_falhar("a sala inicial nunca foi conferida vazia -- ou ela nao existe no andar, ou a guarda de sala sem combate nao rodou")

	_encerrar()


# ------------------------------------------------------------- asserts ---

func _testar_balistica() -> void:
	# Alvo parado: o intercepto tem de ser a propria posicao do alvo.
	var p := Balistica.ponto_de_intercepto(Vector2.ZERO, Vector2(100, 0), Vector2.ZERO, 500.0)
	_checar(p.is_equal_approx(Vector2(100, 0)), "intercepto de alvo parado")

	# Alvo cruzando: a previsao tem de cair a frente dele, nunca atras.
	var q := Balistica.ponto_de_intercepto(Vector2.ZERO, Vector2(300, 0), Vector2(0, 200), 600.0)
	_checar(q.y > 0.0, "intercepto antecipa alvo em movimento (y=%.1f)" % q.y)

	# Alvo mais rapido que o projetil e fugindo: sem solucao, cai na posicao atual.
	var r := Balistica.ponto_de_intercepto(Vector2.ZERO, Vector2(100, 0), Vector2(900, 0), 200.0)
	_checar(r.is_equal_approx(Vector2(100, 0)), "sem solucao volta para a posicao atual")

	# Peso 0 tem de ignorar completamente a previsao.
	var s := Balistica.mira_ponderada(Vector2.ZERO, Vector2(300, 0), Vector2(0, 400), 600.0, 0.0)
	_checar(s.is_equal_approx(Vector2(300, 0)), "peso 0 = mira burra")

	# Leque simetrico com a quantidade pedida.
	var leque := Balistica.leque(Vector2.RIGHT, 5, 40.0)
	_checar(leque.size() == 5, "leque devolve 5 direcoes")
	_checar(absf(leque[0].angle() + leque[4].angle()) < 0.001, "leque e simetrico")

	# Anel fechado.
	var anel := Balistica.anel(12)
	_checar(anel.size() == 12, "anel devolve 12 direcoes")
	var soma := Vector2.ZERO
	for d in anel:
		soma += d
	_checar(soma.length() < 0.001, "anel e equilibrado")

	# Limiares da Deterioracao.
	Deterioracao.valor = 49.0
	_checar(not Deterioracao.usa_mira_preditiva(), "49% ainda nao preve")
	Deterioracao.valor = 50.0
	_checar(Deterioracao.usa_mira_preditiva(), "50% comeca a prever")
	_checar(Deterioracao.precisao_preditiva() > 0.0, "precisao preditiva > 0 no limiar")
	Deterioracao.valor = 100.0
	_checar(Deterioracao.precisao_preditiva() >= 0.99, "precisao preditiva satura em 100%")
	Deterioracao.resetar()


func _checar(condicao: bool, descricao: String) -> void:
	if condicao:
		print("  [ok]    %s" % descricao)
	else:
		_falhar(descricao)


func _falhar(descricao: String) -> void:
	print("  [FALHA] %s" % descricao)
	_falhas.append(descricao)


func _log(texto: String) -> void:
	_eventos.append("%6.2fs  %s" % [_t, texto])


func _encerrar() -> void:
	_terminou = true
	if _spawns_fora > MAX_RELATOS_SPAWN:
		_falhar("e mais %d inimigo(s) nasceram fora da propria sala alem dos %d relatados acima" % [
			_spawns_fora - MAX_RELATOS_SPAWN,
			MAX_RELATOS_SPAWN,
		])
	print("\n--- linha do tempo ---")
	for e in _eventos:
		print("  " + e)
	print("\n--- resultado ---")
	if _falhas.is_empty():
		print("  PASSOU: %d eventos, %d salas, %d spawns conferidos, %.1fs simulados\n" % [
			_eventos.size(),
			_salas_percorridas,
			_spawns_conferidos.size(),
			_t,
		])
		get_tree().quit(0)
	else:
		print("  FALHOU com %d problema(s):" % _falhas.size())
		for f in _falhas:
			print("    - " + f)
		print("")
		get_tree().quit(1)
