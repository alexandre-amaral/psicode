extends TesteBase
## Verifica a MaquinaEstados, que os cinco inimigos com padrao de ataque usam.
##
## Por que isto existe: um defeito aqui nao quebra o jogo, ele deixa UM inimigo
## esquisito -- travado num estado, ou com o telegrafo aceso para sempre. Num
## campo com sete tipos e meia duzia de corpos, isso passa por "comportamento
## estranho" num playtest inteiro sem ninguem conseguir descrever o que viu.
##
## As quatro assercoes cobrem exatamente os quatro jeitos de errar uma maquina
## de estados, e cada uma delas ja produziu bug em algum projeto: nao chamar o
## `sair`, nao zerar o tempo, reentrar no estado atual, e engolir um nome
## errado em silencio.

var _log: Array[String] = []


func nome() -> String:
	return "MaquinaEstados"


func executar() -> void:
	_transicao_completa()
	_tempo_no_estado()
	_nao_reentra_no_atual()
	_sinal_mudou()


## A troca chama `sair` do antigo e `entrar` do novo, nessa ordem.
##
## E a assercao que protege todo telegrafo do jogo: o laser do Atirador Neon, o
## anel do Drone e a aura do Parasita sao apagados no `sair`. Um `sair` que nao
## roda deixa o aviso aceso na tela para sempre.
func _transicao_completa() -> void:
	_log.clear()
	var m := MaquinaEstados.new("teste")
	m.adicionar(&"A", _nada, _marcar.bind("A.entrar"), _marcar.bind("A.sair"))
	m.adicionar(&"B", _nada, _marcar.bind("B.entrar"), _marcar.bind("B.sair"))

	m.iniciar(&"A")
	igual(_log, ["A.entrar"], "iniciar() chama o entrar do primeiro estado")

	m.trocar(&"B")
	igual(
		_log, ["A.entrar", "A.sair", "B.entrar"],
		"trocar() chama o sair do antigo ANTES do entrar do novo"
	)
	igual(String(m.estado), "B", "o estado atual e o novo")


## O tempo acumula no processar e zera na troca -- inclusive na primeira.
##
## Sem o zeramento, o estado seguinte nasceria com o tempo do anterior e
## terminaria no primeiro frame: uma investida sem preparo, um anel sem carga.
func _tempo_no_estado() -> void:
	var m := MaquinaEstados.new("teste")
	m.adicionar(&"A", _nada)
	m.adicionar(&"B", _nada)
	m.iniciar(&"A")

	perto(m.tempo_no_estado, 0.0, "o estado comeca com tempo zero")
	m.processar(0.1)
	m.processar(0.2)
	perto(m.tempo_no_estado, 0.3, "processar acumula o tempo")
	ok(m.passou(0.25), "passou() reconhece a duracao atingida")
	ok(not m.passou(0.5), "passou() recusa duracao ainda nao atingida")

	m.trocar(&"B")
	perto(m.tempo_no_estado, 0.0, "a troca zera o tempo")

	# O tempo entra ANTES do processar do frame, para um estado de duracao `d`
	# terminar no frame em que `d` de fato passou -- e nao um frame depois.
	m.processar(1.0)
	perto(m.tempo_no_estado, 1.0, "o tempo do frame ja conta no proprio frame")


## Trocar para o estado ATUAL nao faz nada.
##
## Esta e a que mais importa na pratica: a condicao de transicao e reavaliada
## todo frame, entao `trocar(&"MIRAR")` de dentro do proprio MIRAR acontece o
## tempo todo. Sem a guarda, o telegrafo reiniciaria a cada quadro e o inimigo
## nunca chegaria a disparar -- um inimigo que mira para sempre.
func _nao_reentra_no_atual() -> void:
	_log.clear()
	var m := MaquinaEstados.new("teste")
	m.adicionar(&"A", _nada, _marcar.bind("A.entrar"), _marcar.bind("A.sair"))
	m.iniciar(&"A")
	m.processar(0.5)

	m.trocar(&"A")
	igual(_log, ["A.entrar"], "trocar para o estado atual nao reentra")
	perto(m.tempo_no_estado, 0.5, "trocar para o estado atual nao zera o tempo")


## O sinal `mudou` e o gancho para depois -- uma IA mais robusta ou um log de
## tuning observa por ele sem que nenhum inimigo saiba que esta sendo olhado.
func _sinal_mudou() -> void:
	var vistas: Array[String] = []
	var m := MaquinaEstados.new("teste")
	m.adicionar(&"A", _nada)
	m.adicionar(&"B", _nada)
	m.mudou.connect(func(de: StringName, para: StringName) -> void:
		vistas.append("%s>%s" % [de, para])
	)

	m.iniciar(&"A")
	m.trocar(&"B")
	m.trocar(&"B")

	igual(vistas, [">A", "A>B"], "mudou() emite so nas trocas de verdade")


func _nada(_delta: float) -> void:
	pass


func _marcar(etiqueta: String) -> void:
	_log.append(etiqueta)
