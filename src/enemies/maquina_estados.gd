class_name MaquinaEstados
extends RefCounted
## Maquina de estados nomeados, usada pelos inimigos com padrao de ataque.
##
## Decisao de design que este arquivo carrega: um estado e um NOME mais tres
## Callables, e nao um no na arvore nem uma classe por estado. Cinco inimigos
## com quatro estados cada dariam vinte arquivos, e o time tem duas pessoas que
## nao programam -- o comportamento de um inimigo precisa caber num arquivo so
## para continuar legivel. A maquina continua sendo de verdade: os estados sao
## explicitos, as transicoes sao explicitas, e ha um unico lugar que roda tudo.
##
## O que ela existe para resolver, e que cada inimigo antes refazia na mao:
##
## 1. **`tempo_no_estado`.** Todo padrao de ataque e feito de "fique assim por
##    N segundos". Sem a maquina, cada inimigo carrega o proprio `_t_fase` e
##    zera na mao -- e esquecer de zerar produz um estado que passa voando ou
##    que nunca termina.
## 2. **`sair` garantido.** Telegrafo aceso e nao apagado e o bug classico
##    deste tipo de inimigo: o laser fica na tela depois do tiro, ou o circulo
##    de aviso sobrevive a morte. Aqui o `sair` do estado antigo roda sempre,
##    inclusive quando a troca vem de outro lugar do codigo.
## 3. **Um gancho para depois.** O sinal `mudou` e por onde uma IA mais robusta
##    -- ou um log na sessao de tuning -- observa a troca de estado sem que
##    nenhum inimigo precise saber que esta sendo observado.
##
## Uso:
## [codeblock]
## _maquina = MaquinaEstados.new()
## _maquina.adicionar(&"MIRAR", _mirar_entrar, _mirar_processar, _mirar_sair)
## _maquina.adicionar(&"ATIRAR", _atirar_entrar, _atirar_processar)
## _maquina.iniciar(&"MIRAR")
## # e, no _comportamento do inimigo:
## _maquina.processar(delta)
## [/codeblock]

## (estado antigo, estado novo). Na primeira transicao o antigo vem vazio.
signal mudou(de: StringName, para: StringName)

## Estado atual. Vazio antes de `iniciar()`.
var estado: StringName = &""
## Segundos desde a ultima troca. Zera em toda transicao, inclusive na primeira.
var tempo_no_estado: float = 0.0

## nome -> {"entrar": Callable, "processar": Callable, "sair": Callable}
var _estados: Dictionary = {}
## Nome de quem tem este dono, so para a mensagem de erro dizer QUEM quebrou.
var _dono: String = "?"


func _init(dono: String = "?") -> void:
	_dono = dono


## Registra um estado. `ao_entrar` e `ao_sair` sao opcionais -- estado que so
## processa nao precisa declarar Callables vazias.
func adicionar(
	nome: StringName,
	processar_: Callable,
	ao_entrar := Callable(),
	ao_sair := Callable()
) -> void:
	if _estados.has(nome):
		push_error("MaquinaEstados de '%s': estado '%s' registrado duas vezes." % [_dono, nome])
		return
	_estados[nome] = {"entrar": ao_entrar, "processar": processar_, "sair": ao_sair}


## Entra no primeiro estado. Diferente de `trocar()` so por nao ter de onde
## sair; o `entrar` do destino roda igual.
func iniciar(nome: StringName) -> void:
	if not _conhece(nome):
		return
	estado = nome
	tempo_no_estado = 0.0
	_chamar(nome, "entrar")
	mudou.emit(&"", nome)


## Troca de estado. Trocar para o estado ATUAL nao faz nada -- de proposito.
##
## Sem essa guarda, um `trocar(&"MIRAR")` chamado dentro do proprio `MIRAR` (o
## que acontece o tempo todo quando a condicao de transicao e reavaliada todo
## frame) reiniciaria o telegrafo a cada quadro, e o inimigo nunca dispararia.
func trocar(nome: StringName) -> void:
	if nome == estado:
		return
	if not _conhece(nome):
		return
	var antigo := estado
	_chamar(antigo, "sair")
	estado = nome
	tempo_no_estado = 0.0
	_chamar(nome, "entrar")
	mudou.emit(antigo, nome)


## Roda o estado atual. Chame uma vez por frame, do `_comportamento()`.
##
## O tempo e somado ANTES do processar: assim um estado que dura `d` segundos e
## testado com `tempo_no_estado >= d` ja no frame em que ele de fato passou, e
## nao um frame depois.
func processar(delta: float) -> void:
	if estado == &"":
		return
	tempo_no_estado += delta
	_chamar(estado, "processar", delta)


## Passou tempo suficiente neste estado? Acucar para a condicao mais comum de
## todas, que e "fique aqui por N segundos".
func passou(segundos: float) -> bool:
	return tempo_no_estado >= segundos


## Estado desconhecido e erro alto, e nao no-op silencioso.
##
## Um nome digitado errado sem esta guarda deixa o inimigo parado para sempre
## sem uma linha no console -- e "aquele inimigo as vezes trava" e a categoria
## de bug mais cara de perseguir depois.
func _conhece(nome: StringName) -> bool:
	if _estados.has(nome):
		return true
	push_error("MaquinaEstados de '%s': estado '%s' nao existe. Registrados: %s" % [
		_dono, nome, ", ".join(_nomes()),
	])
	return false


func _chamar(nome: StringName, chave: String, delta: float = -1.0) -> void:
	var entrada: Dictionary = _estados.get(nome, {})
	var f: Callable = entrada.get(chave, Callable())
	if not f.is_valid():
		return
	if delta >= 0.0:
		f.call(delta)
	else:
		f.call()


func _nomes() -> Array[String]:
	var lista: Array[String] = []
	for n in _estados:
		lista.append(String(n))
	return lista
