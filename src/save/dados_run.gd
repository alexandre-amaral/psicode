class_name DadosRun
extends RefCounted
## O que uma run acumula enquanto ela acontece.
##
## Vive so em memoria e morre com a run. Quem sobrevive e o `ResultadoRun` que
## sai de `resultado()` -- e essa separacao e o principio 2.3 do plano: nunca
## salvar o estado da cena como forma principal de persistencia.
##
## Ele nao se enche sozinho. Quem escuta o `EventBus` e preenche isto e o
## autoload `RegistroRun`, e essa divisao existe para o gameplay nunca precisar
## conhecer o save: sem ela, `inimigo_base.gd` incrementaria um contador, a
## `arma.gd` outro, a `sala.gd` outro, e a persistencia estaria espalhada por
## dez arquivos que nao tem nada a ver com ela.

## O `id` do personagem que entrou. String e nao o recurso: e este campo que vai
## para o `ResultadoRun` e de la para o disco.
var personagem: String = ""
## A semente do andar. Guardada porque uma run interessante tem de poder ser
## repetida -- e porque, quando o save no meio da run existir, e por ela que a
## geracao volta identica.
var seed: int = 0
var inicio_timestamp: int = 0

## Em que andar a run esta AGORA.
##
## Nao e enfeite para o futuro: e o campo que impede o codigo de cravar "chefe
## do Andar 1 = fim de toda run". Hoje as duas coisas coincidem, e e exatamente
## por coincidirem que alguem escreveria a suposicao em algum lugar novo.
var andar_atual: int = 1

var kills: int = 0
var dano_causado: int = 0
var dano_recebido: int = 0
var itens_coletados: Array[String] = []
var armas_coletadas: Array[String] = []
var salas_concluidas: int = 0

var venceu: bool = false
var motivo_fim: String = ""


## Quanto tempo a run durou, em segundos.
##
## Sai de `GameState.tempo_run`, que ja desconta pausa e hitstop de graca -- um
## relogio proprio aqui contaria o tempo em que o jogo esteve parado no menu de
## pausa, e a duracao no terminal de historico passaria a premiar quem hesita.
var duracao: float = 0.0


## A versao serializavel deste estado.
##
## `id` e `data` sao preenchidos por quem registra: a run nao sabe qual numero
## ela e no historico, e nao deveria saber -- isso e informacao do PERFIL.
func resultado() -> ResultadoRun:
	var r := ResultadoRun.new()
	r.personagem = personagem
	r.duracao = duracao
	r.andar_alcancado = andar_atual
	r.kills = kills
	r.dano_causado = dano_causado
	r.dano_recebido = dano_recebido
	r.venceu = venceu
	r.motivo_fim = motivo_fim
	r.arma_final = armas_coletadas[-1] if not armas_coletadas.is_empty() else ""
	# Os ULTIMOS itens, e nao os primeiros: o que caracteriza uma build e com o
	# que ela terminou. Tres cabe numa linha do terminal sem quebrar.
	var principais: Array[String] = []
	var de := maxi(itens_coletados.size() - 3, 0)
	for i in range(de, itens_coletados.size()):
		principais.append(itens_coletados[i])
	r.itens_principais = principais
	return r
