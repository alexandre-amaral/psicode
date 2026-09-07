class_name Aprimoramento
extends Node
## O controlador de uma classe de Unidade Aprimorada, pendurado no inimigo.
##
## **O inimigo hospeda este no sem saber o que ele faz.** `InimigoBase` chama
## quatro coisas -- `multiplicador_de_dano_recebido()`, `ao_receber_dano()`,
## `multiplicador_de_cadencia()` e `multiplicador_de_telegrafo()` -- e nenhuma
## delas menciona classe nenhuma. E isso que faz uma classe nova entrar sem tocar
## nos cinco inimigos, e um inimigo novo aceitar as tres sem codigo proprio.
##
## Ele roda em `_process` e nao em `_physics_process`, com temporizadores
## INTERNOS: nada de `Timer` como no. E a mesma disciplina do `PropAnimado` e do
## `Juice`, e aqui ela pesa mais, porque pode haver um destes por sala em toda
## sala de combate do andar.
##
## ## O que ele NAO toca
##
## O sprite do inimigo, `_corpo.color` e `_visual.modulate`. Os dois canais de
## cor ja tem dono: o Hack pinta o corpo e o nanite so pinta se nao houver Hack,
## e o modulate e do clarao de dano, que termina sempre em branco. Um terceiro
## escritor produziria uma cor que depende da ordem das chamadas.
##
## A leitura da classe vem toda da `AuraDeAprimoramento`, um no IRMAO do
## `Visual` -- e por isso o visual do inimigo continua sendo o dele.

var dados: DadosAprimoramento = null

var _inimigo: InimigoBase = null
var _aura: AuraDeAprimoramento = null

## REGENERADORA: quanto faz que ela nao leva dano, e a cura fracionaria que ainda
## nao virou um ponto de vida inteiro.
##
## A fracao existe porque vida e `int`: com 2% de 8 de vida por segundo, arredondar
## a cada frame devolveria ZERO para sempre. E o mesmo motivo pelo qual `DANO` e
## `DANO_PERCENTUAL` sao alvos separados nos modificadores.
var _t_sem_dano: float = 0.0
var _cura_parcial: float = 0.0

## BLINDADA: onde o ciclo esta, e ha quanto tempo.
var _protegida: bool = true
var _t_ciclo: float = 0.0
## A fracao de dano que a reducao engoliu e ainda nao virou um ponto inteiro.
##
## **Sem ela a Blindada nao existe, e o laboratorio provou isso: +0% de TTK nas
## cinco especies.** Dano e `int` e os tiros do jogo valem 1 ou 2 -- entao 25%
## de 1 vira `roundf(0.75) = 1`, e a reducao some no arredondamento em TODO
## acerto. E a mesma armadilha que o projeto ja registra para `DANO_PERCENTUAL`
## ("+10% num dano 2 volta a ser 2"), e a saida e a mesma que a cura ja usa:
## acumular a fracao e cobrar quando ela fecha um ponto.
var _dano_parcial: float = 0.0

## SOBRECARREGADA: a fase do pulso irregular, so para a aura.
var _fase_do_pulso: float = 0.0


## Liga a classe ao inimigo. Chamado DEPOIS do `add_child` do inimigo na sala.
##
## **A vida e escalada aqui, e as duas linhas andam juntas.** `InimigoBase._ready`
## ja congelou `vida = vida_maxima`; escalar so o teto deixaria o inimigo nascer
## ferido, e escalar so a vida atual deixaria o teto mentindo para a barra. E a
## mesma armadilha que `_aplicar_dados()` documenta -- aplicar atributo depois de
## um congelamento faz todo recalculo somar em cima do numero errado.
func configurar(inimigo: InimigoBase, d: DadosAprimoramento) -> void:
	_inimigo = inimigo
	dados = d
	if _inimigo == null or dados == null:
		return

	if not is_equal_approx(dados.multiplicador_vida, 1.0):
		_inimigo.vida_maxima = maxi(1,
			int(roundf(float(_inimigo.vida_maxima) * dados.multiplicador_vida)))
		_inimigo.vida = _inimigo.vida_maxima
	if not is_equal_approx(dados.multiplicador_dano, 1.0):
		_inimigo.dano_contato = maxi(1,
			int(roundf(float(_inimigo.dano_contato) * dados.multiplicador_dano)))

	_protegida = true
	_t_ciclo = 0.0
	_t_sem_dano = 0.0

	_aura = AuraDeAprimoramento.new()
	_aura.name = "AuraDeAprimoramento"
	_aura.configurar(dados, _inimigo.raio_contato)
	_inimigo.add_child(_aura)


func _process(delta: float) -> void:
	if _inimigo == null or not is_instance_valid(_inimigo) or _inimigo.morto:
		return
	match dados.classe:
		DadosAprimoramento.Classe.REGENERADORA:
			_regenerar(delta)
		DadosAprimoramento.Classe.BLINDADA:
			_ciclar_blindagem(delta)
		DadosAprimoramento.Classe.SOBRECARREGADA:
			_fase_do_pulso += delta
			if _aura != null:
				_aura.pulsar(_fase_do_pulso)


# ------------------------------------------------------- REGENERADORA -------

## Ela cria PRIORIDADE DE FOCO, e nada mais.
##
## Nao depende do tipo de ataque nem da locomocao -- so de `receber_dano()`, que e
## da base --, e e por isso que ela funciona nos cinco sem uma linha de codigo de
## especie.
##
## **O DOT zera o relogio a cada tique, e isso e desenho.** O nanite e DOT, entao
## um alvo com nanite nunca regenera enquanto os tiques durarem: os dois falam a
## mesma lingua, que e pressao continua.
func _regenerar(delta: float) -> void:
	_t_sem_dano += delta
	if _t_sem_dano < dados.espera_para_regenerar:
		if _aura != null:
			_aura.curando(false)
		return
	if _inimigo.vida >= _inimigo.vida_maxima:
		if _aura != null:
			_aura.curando(false)
		return

	if _aura != null:
		_aura.curando(true)
	_cura_parcial += float(_inimigo.vida_maxima) * dados.regeneracao_por_segundo * delta
	if _cura_parcial < 1.0:
		return
	var pontos := int(floorf(_cura_parcial))
	_cura_parcial -= float(pontos)
	# O TETO e `vida_maxima`, e ele vale mesmo se uma classe futura mexer nele:
	# a conta le o campo no frame em vez de guardar o numero do nascimento.
	_inimigo.vida = mini(_inimigo.vida + pontos, _inimigo.vida_maxima)
	EventBus.inimigo_regenerou.emit(_inimigo, pontos)


# ----------------------------------------------------------- BLINDADA -------

## Ela cria uma JANELA DE DANO, e nao vida extra.
##
## Vida extra alonga a luta inteira por igual. O ciclo cria um RITMO: o jogador
## aprende a guardar a arma pesada para a janela, e a decisao acontece antes de
## ela abrir.
##
## **Status nao para o relogio.** Stun, Hack e knockback nao interrompem o ciclo
## -- se interrompessem, atordoar viraria o jeito de nunca ver a janela, e a
## classe passaria a premiar o oposto do que ela existe para pedir.
func _ciclar_blindagem(delta: float) -> void:
	_t_ciclo += delta
	var limite: float = dados.tempo_protegida if _protegida else dados.tempo_vulneravel
	if _t_ciclo < limite:
		return
	_t_ciclo = 0.0
	_protegida = not _protegida
	if _aura != null:
		_aura.blindada(_protegida)
	EventBus.aprimorado_mudou_de_estado.emit(_inimigo, _protegida)


func esta_protegida() -> bool:
	return dados != null and dados.classe == DadosAprimoramento.Classe.BLINDADA \
		and _protegida


# ------------------------------------------------------- o que a base le ----

## Quanto do dano recebido chega de fato.
##
## So a BLINDADA mexe nisto. As outras devolvem 1,0 -- e devolver 1,0 e diferente
## de nao ser chamado: o inimigo pergunta sempre, e e isso que mantem o caminho
## unico.
func multiplicador_de_dano_recebido() -> float:
	if dados == null or dados.classe != DadosAprimoramento.Classe.BLINDADA:
		return 1.0
	if _protegida:
		return maxf(0.0, 1.0 - dados.reducao_de_dano)
	return 1.0 + dados.dano_extra_vulneravel


## Quanto dano de fato entra, com a fracao acumulada.
##
## Ela devolve INTEIRO porque vida e `int`, e guarda o resto para o proximo
## acerto. Com 25% de reducao sobre tiros de 1, o alvo recebe 0, 1, 1, 1, 0, 1,
## 1, 1... -- tres pontos a cada quatro, que e exatamente a reducao declarada.
##
## Arredondar por acerto devolveria 1 sempre e a classe nao existiria; um piso de
## 1 faz o mesmo. **O acerto que entrega zero continua acendendo o clarao**,
## entao o jogador ve que acertou -- e ver o acerto sem ver a vida cair e
## justamente a leitura que a blindagem promete.
func dano_efetivo(quantidade: int) -> int:
	var multiplicador := multiplicador_de_dano_recebido()
	if is_equal_approx(multiplicador, 1.0):
		return quantidade
	_dano_parcial += float(quantidade) * multiplicador
	var inteiro := int(floorf(_dano_parcial))
	_dano_parcial -= float(inteiro)
	return maxi(inteiro, 0)


## O inimigo levou dano. Quem avisa e `InimigoBase.receber_dano()`.
func ao_receber_dano() -> void:
	_t_sem_dano = 0.0
	_cura_parcial = 0.0
	if _aura != null:
		_aura.curando(false)


func multiplicador_de_cadencia() -> float:
	return dados.multiplicador_cadencia if dados != null else 1.0


func multiplicador_de_telegrafo() -> float:
	return dados.multiplicador_telegrafo if dados != null else 1.0
