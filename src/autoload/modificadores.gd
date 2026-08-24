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
## A tabela interna e generica (Alvo -> acumulado), entao acrescentar um alvo
## novo em DadosItem custa so o getter correspondente aqui.

## Alvo -> valor acumulado. So tem chave para alvo que algum item ja tocou.
var _acumulado: Dictionary = {}
## Ordem de coleta, para a HUD listar e para contar repeticao.
var _itens: Array[DadosItem] = []


## Aplica um implante. Devolve false quando ele bateu no limite por run -- quem
## chama usa isso para nao consumir o pickup.
func aplicar(item: DadosItem) -> bool:
	if item == null:
		return false
	if item.maximo_por_run > 0 and _quantas_vezes(item) >= item.maximo_por_run:
		return false

	var atual: float = _acumulado.get(item.alvo, item.neutro())
	if item.modo == DadosItem.Modo.MULTIPLICA:
		_acumulado[item.alvo] = atual * item.valor
	else:
		_acumulado[item.alvo] = atual + item.valor

	_itens.append(item)
	EventBus.item_coletado.emit(item)
	EventBus.modificadores_mudaram.emit()
	return true


## Chamado por GameState.iniciar_run(). Implante e progressao de run, nao
## meta-progressao: comecar de novo comeca limpo.
func resetar() -> void:
	_acumulado.clear()
	_itens.clear()
	EventBus.modificadores_mudaram.emit()


func itens_ativos() -> Array[DadosItem]:
	# Loop explicito: duplicate() de Array tipado que passa por Variant volta
	# sem tipo, e a atribuicao de volta estoura em runtime.
	var lista: Array[DadosItem] = []
	for item in _itens:
		lista.append(item)
	return lista


# ------------------------------------------------------------- getters ------

func multiplicador_velocidade() -> float:
	return _fator(DadosItem.Alvo.VELOCIDADE)


func multiplicador_cooldown_rolamento() -> float:
	return _fator(DadosItem.Alvo.COOLDOWN_ROLAMENTO)


func multiplicador_cadencia() -> float:
	return _fator(DadosItem.Alvo.CADENCIA)


func multiplicador_velocidade_projetil() -> float:
	return _fator(DadosItem.Alvo.VELOCIDADE_PROJETIL)


## O implante de dissipador REDUZ o ganho passivo, entao o valor util aqui e
## menor que 1.0. Fica multiplicando o ganho, nunca subtraindo dele: subtrair
## poderia inverter o sinal e fazer a barra descer sozinha.
func multiplicador_ganho_deterioracao() -> float:
	return maxf(_fator(DadosItem.Alvo.GANHO_DETERIORACAO), 0.0)


func bonus_vida_maxima() -> int:
	return int(round(_soma(DadosItem.Alvo.VIDA_MAXIMA)))


func bonus_dano() -> int:
	return int(round(_soma(DadosItem.Alvo.DANO)))


# -------------------------------------------------------------- interno -----

## Alvo sem nenhum item coletado devolve 1.0: nao mexe em nada.
func _fator(alvo: int) -> float:
	return float(_acumulado.get(alvo, 1.0))


## Alvo sem nenhum item coletado devolve 0.0: nao soma nada.
func _soma(alvo: int) -> float:
	return float(_acumulado.get(alvo, 0.0))


func _quantas_vezes(item: DadosItem) -> int:
	var total := 0
	for coletado in _itens:
		if coletado == item:
			total += 1
	return total
