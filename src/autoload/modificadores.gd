extends Node
## Os implantes que o jogador pegou nesta run, somados num lugar so.
##
## Este autoload e o espelho deliberado de Deterioracao, e pelo mesmo motivo:
## a regra 2 do projeto diz que ninguem guarda numero ja multiplicado. La a
## dificuldade sobe e todo mundo sente no frame seguinte; aqui o upgrade entra
## e todo mundo sente no frame seguinte -- inclusive a arma que ja estava na
## mao e o rolamento que ja estava em cooldown.
##
## Por isso a API sao getters (`multiplicador_velocidade()`), nunca campos
## publicos: quem chama e obrigado a perguntar de novo a cada uso.
##
## O que este arquivo guarda tem DUAS naturezas:
##
## 1. **acumulo estatico** -- os efeitos SEMPRE, somados uma vez na coleta.
## 2. **estado da run** -- vida atual, cargas, abates, tiros de eco, alvo
##    marcado. Alimentado por sinais do EventBus, muda o tempo todo, e e o que
##    faz implante condicional existir.
##
## Os getters combinam os dois. Quem chama pede `multiplicador_dano()` e nao
## precisa saber se o numero veio de um passivo, de estar com pouca vida ou de
## cinco abates seguidos sem levar dano.

## Acima disto o morto e tratado como chefe. Ver _tentar_vampirismo.
const CREDITOS_DE_CHEFE := 50
## Quanto da chance de vampirismo sobra contra um chefe.
const FATOR_CHEFE := 0.25

## Alvo -> valor acumulado dos efeitos SEMPRE.
var _acumulado: Dictionary = {}
## Ordem de coleta, para a HUD listar e para contar repeticao.
var _itens: Array[DadosItem] = []

# ------------------------------------------------------- estado da run ------

## Fracao de vida do jogador (0..1). O Modulo de Sobrecarga le daqui.
var _fracao_vida: float = 1.0
## Cargas do Daemon de Combate: sobem por abate, zeram ao levar dano.
var _cargas: int = 0
## Abates desde a ultima cura dos Nanobots.
var _abates_desde_cura: int = 0
## Tiros restantes com bonus da Celula de Eco.
var _tiros_eco: int = 0
## Instancia do inimigo marcado pela IA Predatoria, e se o marcador esta
## esperando o proximo alvo atingido.
var _alvo_marcado: int = 0
var _marcador_armado: bool = false

## Config de Hack do personagem da run. null = ninguem hackeia.
var _hack: DadosPersonagem = null
## Um tiro ja sorteou e ganhou o Hack; o proximo projetil dele que ACERTAR
## alguem aplica e desarma.
##
## Espelha _marcador_armado de proposito, e pelo mesmo motivo: o sorteio tem de
## valer por TIRO, mas quem conhece o alvo e o projetil. Sem este passo no meio,
## NOVA com a shotgun rolaria os 10% oito vezes por disparo -- ~57% de chance,
## quase seis vezes o que o personagem promete.
var _hack_armado: bool = false


func _ready() -> void:
	# O estado da run e alimentado por evento. Nada aqui procura no ninguem na
	# arvore: o autoload so escuta o que ja e anunciado.
	EventBus.inimigo_morreu.connect(_ao_inimigo_morrer)
	EventBus.player_dano_recebido.connect(_ao_vida_mudar)
	EventBus.player_curado.connect(_ao_vida_mudar)
	EventBus.recarga_concluida.connect(_ao_recarga_concluida)


## Aplica um implante. Devolve false quando ele bateu no limite por run -- quem
## chama usa isso para nao consumir o pickup.
func aplicar(item: DadosItem) -> bool:
	if item == null:
		return false
	if item.maximo_por_run > 0 and _quantas_vezes(item) >= item.maximo_por_run:
		# Avisa so o limite. O ramo de item == null acima e erro de programacao,
		# nao uma recusa que o jogador precise entender.
		EventBus.item_recusado.emit(item)
		return false

	# So os efeitos SEMPRE entram no acumulo. Os condicionais sao calculados no
	# frame de uso, porque o gatilho deles muda durante a run.
	for efeito in item.efeitos_validos():
		if efeito.condicao == EfeitoItem.Condicao.SEMPRE:
			_acumular(efeito)

	_itens.append(item)
	EventBus.item_coletado.emit(item)
	EventBus.modificadores_mudaram.emit()
	return true


func _acumular(efeito: EfeitoItem) -> void:
	var atual: float = _acumulado.get(efeito.alvo, efeito.neutro())
	if efeito.eh_multiplicativo():
		_acumulado[efeito.alvo] = atual * efeito.valor
	else:
		_acumulado[efeito.alvo] = atual + efeito.valor


## Chamado por GameState.iniciar_run(). Implante e progressao de run, nao
## meta-progressao: comecar de novo comeca limpo -- e isso vale tambem para o
## estado dinamico, senao a dificuldade vaza de uma run para a seguinte.
func resetar() -> void:
	_acumulado.clear()
	_itens.clear()
	_fracao_vida = 1.0
	_cargas = 0
	_abates_desde_cura = 0
	_tiros_eco = 0
	_alvo_marcado = 0
	_marcador_armado = false
	_hack_armado = false
	_hack = null
	EventBus.modificadores_mudaram.emit()


# ---------------------------------------------------------------- hack ------
# O Hack acompanha a PESSOA, nao a arma: NOVA continua hackeando depois de
# trocar a Cipher por um loot. Por isso a config vem do DadosPersonagem e mora
# aqui, no autoload que ja e dono do resto do estado de run do jogador.


## Chamado por GameState.iniciar_run(), sempre depois de resetar().
func configurar_hack(personagem: DadosPersonagem) -> void:
	_hack = personagem if personagem != null and personagem.tem_hack() else null
	_hack_armado = false


func tem_hack() -> bool:
	return _hack != null


## Sorteia UMA vez por tiro. Quem chama e Arma._consumir_tiro(), que ja e o
## lugar canonico de "isto vale por tiro, nao por projetil".
func armar_hack() -> void:
	if _hack == null:
		return
	if randf() < _hack.hack_chance:
		_hack_armado = true


## Devolve a duracao a aplicar e desarma. Zero = este acerto nao hackeia.
func consumir_hack() -> float:
	if not _hack_armado or _hack == null:
		return 0.0
	_hack_armado = false
	return _hack.hack_duracao


## Multiplicador de dano em quem esta hackeado. 1.0 sem personagem com Hack.
func bonus_dano_hack() -> float:
	if _hack == null:
		return 1.0
	return maxf(_hack.hack_bonus_dano, 1.0)


func chance_propagacao_hack() -> float:
	if _hack == null:
		return 0.0
	return clampf(_hack.hack_chance_propagacao, 0.0, 1.0)


func raio_propagacao_hack() -> float:
	if _hack == null:
		return 0.0
	return maxf(_hack.hack_raio_propagacao, 0.0)


func duracao_hack() -> float:
	if _hack == null:
		return 0.0
	return maxf(_hack.hack_duracao, 0.0)


func itens_ativos() -> Array[DadosItem]:
	# Loop explicito: duplicate() de Array tipado que passa por Variant volta
	# sem tipo, e a atribuicao de volta estoura em runtime.
	var lista: Array[DadosItem] = []
	for item in _itens:
		lista.append(item)
	return lista


# ------------------------------------------------------------- getters ------

func multiplicador_velocidade() -> float:
	return _fator(EfeitoItem.Alvo.VELOCIDADE)


func multiplicador_cooldown_rolamento() -> float:
	return _fator(EfeitoItem.Alvo.COOLDOWN_ROLAMENTO)


func multiplicador_cadencia() -> float:
	return _fator(EfeitoItem.Alvo.CADENCIA)


func multiplicador_velocidade_projetil() -> float:
	return _fator(EfeitoItem.Alvo.VELOCIDADE_PROJETIL)


## O dissipador REDUZ o ganho, entao o valor util aqui e menor que 1.0. Fica
## multiplicando, nunca subtraindo: subtrair poderia inverter o sinal e fazer a
## barra descer sozinha.
func multiplicador_ganho_deterioracao() -> float:
	return maxf(_fator(EfeitoItem.Alvo.GANHO_DETERIORACAO), 0.0)


func bonus_vida_maxima() -> int:
	return int(round(_soma(EfeitoItem.Alvo.VIDA_MAXIMA)))


func bonus_dano() -> int:
	return int(round(_soma(EfeitoItem.Alvo.DANO)))


## Multiplicador percentual de dano, ja com os condicionais ligados. Separado
## de bonus_dano() porque um e int e o outro e fator -- quem calcula o dano
## final soma primeiro e multiplica depois, arredondando uma vez so.
func multiplicador_dano() -> float:
	return _fator(EfeitoItem.Alvo.DANO_PERCENTUAL)


func chance_ricochete() -> float:
	return clampf(_parametro_de(DadosItem.Comportamento.RICOCHETE), 0.0, 1.0)


func chance_fragmentacao() -> float:
	return clampf(_parametro_de(DadosItem.Comportamento.FRAGMENTAR), 0.0, 1.0)


## Multiplicador extra quando o alvo e o inimigo marcado pela IA Predatoria.
## 1.0 quando nao ha marcador ou o alvo e outro.
func multiplicador_no_alvo(id: int) -> float:
	if _alvo_marcado == 0 or id != _alvo_marcado:
		return 1.0
	return maxf(_parametro_de(DadosItem.Comportamento.MARCADOR), 1.0)


## O projetil avisa quem acertou. Se o marcador estava armado, ele gruda neste
## alvo; se ja estava neste alvo, o bonus e consumido.
func registrar_acerto(id: int) -> void:
	if _alvo_marcado == id:
		_alvo_marcado = 0
		return
	if _marcador_armado:
		_marcador_armado = false
		_alvo_marcado = id


func cargas() -> int:
	return _cargas


func tiros_de_eco() -> int:
	return _tiros_eco


## Chamado pela Arma a cada disparo do jogador: e o que consome o bonus da
## Celula de Eco tiro a tiro.
func consumir_tiro_de_eco() -> void:
	if _tiros_eco > 0:
		_tiros_eco -= 1


# ------------------------------------------------- reacao a eventos ---------

func _ao_vida_mudar(atual: int, maximo: int) -> void:
	var anterior := _fracao_vida
	_fracao_vida = float(atual) / maxf(float(maximo), 1.0)
	# Levar dano quebra o Daemon. Curar nao: so perder vida zera as cargas.
	if _fracao_vida < anterior:
		_cargas = 0


func _ao_inimigo_morrer(_posicao: Vector2, creditos: int) -> void:
	_acumular_carga()
	_tentar_vampirismo(creditos)
	_tentar_nanobots()
	# A IA Predatoria arma o marcador na morte; ele so gruda no PROXIMO
	# inimigo que o jogador acertar.
	if _tem_comportamento(DadosItem.Comportamento.MARCADOR):
		_marcador_armado = true
		_alvo_marcado = 0


func _ao_recarga_concluida() -> void:
	var tiros := int(_parametro_de(DadosItem.Comportamento.ECO))
	if tiros > 0:
		_tiros_eco = tiros


func _acumular_carga() -> void:
	var teto := int(_parametro_de(DadosItem.Comportamento.CARGAS_SEM_DANO))
	if teto <= 0:
		return
	_cargas = mini(_cargas + 1, teto)


## Chefe tem chance reduzida. Nao ha campo de "eh chefe" no sinal, e creditos e
## o unico dado que chega junto -- a Diretora vale 100 contra 3 a 5 dos comuns,
## entao o corte em 50 separa os dois sem ambiguidade. Se algum dia um inimigo
## comum valer tanto assim, isto precisa virar um campo de verdade.
func _tentar_vampirismo(creditos: int) -> void:
	var chance := _parametro_de(DadosItem.Comportamento.VAMPIRISMO)
	if chance <= 0.0:
		return
	if creditos >= CREDITOS_DE_CHEFE:
		chance *= FATOR_CHEFE
	if randf() < chance:
		EventBus.pedido_cura.emit(1)


func _tentar_nanobots() -> void:
	var alvo := int(_parametro_de(DadosItem.Comportamento.NANOBOTS))
	if alvo <= 0:
		return
	_abates_desde_cura += 1
	if _abates_desde_cura >= alvo:
		_abates_desde_cura = 0
		EventBus.pedido_cura.emit(1)


# -------------------------------------------------------------- interno -----

## Fator final de um alvo: o acumulo estatico vezes o que os condicionais
## ligados acrescentam agora.
func _fator(alvo: int) -> float:
	return float(_acumulado.get(alvo, 1.0)) * _fator_condicional(alvo)


func _soma(alvo: int) -> float:
	return float(_acumulado.get(alvo, 0.0)) + _soma_condicional(alvo)


## Percorre os condicionais dos implantes coletados e multiplica os que valem
## AGORA. Lido no frame de uso: e isto que faz o bonus de vida baixa aparecer
## e sumir sozinho.
func _fator_condicional(alvo: int) -> float:
	var fator := 1.0
	for item in _itens:
		for efeito in item.efeitos_validos():
			if efeito.alvo != alvo or not efeito.eh_multiplicativo():
				continue
			fator *= _peso_da_condicao(item, efeito)
	return fator


func _soma_condicional(alvo: int) -> float:
	var total := 0.0
	for item in _itens:
		for efeito in item.efeitos_validos():
			if efeito.alvo != alvo or efeito.eh_multiplicativo():
				continue
			if efeito.condicao == EfeitoItem.Condicao.SEMPRE:
				continue
			total += efeito.valor * _repeticoes_da_condicao(item, efeito)
	return total


## Quanto um efeito condicional multiplica agora. 1.0 = nao vale.
func _peso_da_condicao(item: DadosItem, efeito: EfeitoItem) -> float:
	match efeito.condicao:
		EfeitoItem.Condicao.SEMPRE:
			# Ja entrou no acumulo estatico na coleta; contar de novo dobraria.
			return 1.0
		EfeitoItem.Condicao.VIDA_BAIXA:
			return efeito.valor if _fracao_vida <= item.parametro else 1.0
		EfeitoItem.Condicao.POR_CARGA:
			# Uma vez por carga: 5% com 5 cargas vira 1.05^5.
			return pow(efeito.valor, float(_cargas))
		EfeitoItem.Condicao.TIROS_DE_ECO:
			return efeito.valor if _tiros_eco > 0 else 1.0
	return 1.0


## Quantas vezes um efeito somativo condicional conta agora.
func _repeticoes_da_condicao(item: DadosItem, efeito: EfeitoItem) -> float:
	match efeito.condicao:
		EfeitoItem.Condicao.VIDA_BAIXA:
			return 1.0 if _fracao_vida <= item.parametro else 0.0
		EfeitoItem.Condicao.POR_CARGA:
			return float(_cargas)
		EfeitoItem.Condicao.TIROS_DE_ECO:
			return 1.0 if _tiros_eco > 0 else 0.0
	return 0.0


## Maior parametro entre os implantes com aquele comportamento. Maior, e nao
## soma, porque parametro e chance ou limiar: somar duas chances de 15% daria
## 30% sem ninguem ter pedido isso.
func _parametro_de(comportamento: int) -> float:
	var maior := 0.0
	for item in _itens:
		if item.comportamento == comportamento:
			maior = maxf(maior, item.parametro)
	return maior


func _tem_comportamento(comportamento: int) -> bool:
	for item in _itens:
		if item.comportamento == comportamento:
			return true
	return false


func _quantas_vezes(item: DadosItem) -> int:
	var total := 0
	for coletado in _itens:
		if coletado == item:
			total += 1
	return total
