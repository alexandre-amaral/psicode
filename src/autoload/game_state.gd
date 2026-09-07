extends Node
## Estado da run atual, e MODO do jogo. Sao dois eixos, e nao um.
##
## `Estado` descreve a RUN: ela esta rolando, pausada, perdida ou ganha. `Modo`
## descreve ONDE o jogador esta: menu, lobby, run.
##
## **Fundir os dois num campo so seria o erro obvio**, e ele quebraria na
## primeira pergunta util: "pausado" e "no lobby" nao sao alternativas, sao
## respostas a perguntas diferentes -- da para estar no lobby com a arvore
## pausada por um painel aberto. Com um campo so, abrir o terminal de historico
## apagaria a informacao de que o jogador esta no lobby.
##
## A meta-progressao NAO mora aqui: quem guarda perfil e `Progressao`, quem le e
## escreve o arquivo e `Save`, e quem conta a run enquanto ela acontece e
## `RegistroRun`. Este autoload conduz o fluxo e nao guarda nada permanente.

enum Estado { MENU, JOGANDO, PAUSADO, GAME_OVER, VITORIA }

## Onde o jogador esta. RESULTADO e um instante, e nao uma cena: o plano diz com
## todas as letras que nao e necessaria cena propria na primeira implementacao.
enum Modo { MENU, LOBBY, RUN, RESULTADO }

var modo: int = Modo.MENU
var estado: int = Estado.MENU
## A run e medida em SALAS. Havia aqui um par onda_atual/total_ondas, de quando
## cada sala rodava uma sequencia de ondas; com a composicao decidida na
## montagem do andar nao existe mais indice de onda para contar.
var salas_limpas: int = 0
var total_salas: int = 0
## O saldo da RUN, e ele nunca se mistura com moeda permanente de Lobby.
##
## **ESCREVER NELE DIRETO E O DEFEITO, e ate a #280 era o unico jeito.** Havia
## uma atribuicao so no jogo inteiro (`GameState.creditos += creditos`, na morte
## do inimigo) e nenhuma forma de GASTAR -- a semente parada que o M1 do roadmap
## existe para fechar.
##
## Hoje tudo passa por `adicionar_creditos`, `pode_pagar` e `gastar_creditos`, e
## `teste_creditos.gd` varre o codigo cobrando que ninguem escreva aqui fora
## deste arquivo. A razao nao e arrumacao: sem uma porta unica, uma transacao
## nao tem como recusar sem deixar rastro, e o jogador paga por uma arma que nao
## recebeu.
var creditos: int = 0
var inimigos_mortos: int = 0
var tempo_run: float = 0.0

## Quanto durou a luta do chefe, do momento em que ela se revela ate a morte
## dela. Existe por causa de uma pergunta do playtest: "quanto a luta PARECEU
## durar, e quanto durou de verdade?". Sem este numero na tela de fim, a segunda
## metade da pergunta depende da memoria do testador -- e memoria de luta dificil
## nao e fonte confiavel de tuning.
var tempo_chefe: float = 0.0
## Marca de `tempo_run` quando a Diretora se revelou. -1 = ela nao apareceu.
var _chefe_comecou: float = -1.0

const CENA_MAIN := "res://src/main/main.tscn"
const CENA_LOBBY := "res://src/lobby/lobby.tscn"

## Quem o jogador escolheu na tela de selecao.
##
## Declarada FORA do bloco de contadores acima, e isso nao e arrumacao: quem
## chama iniciar_run() e o _ready do GerenciadorMapa, ou seja, a run comeca
## DEPOIS de a tela ja ter escrito aqui. Se este campo fosse zerado junto com os
## contadores, a escolha seria apagada no boot da propria cena que ela pediu.
##
## E ela precisa viver num autoload, e nao na cena: o caminho que entra na run
## troca de cena, e sem a escolha guardada aqui o jogador cairia calado na arma
## default do player.tscn.
var personagem: DadosPersonagem = null

## A semente do andar em curso. Zero fora de uma run.
var semente_da_run: int = 0


## O `id` do personagem escolhido, como texto.
##
## O `RegistroRun` e o save guardam `id` e nunca o recurso: uma string nao muda
## de caminho quando alguem reorganiza `src/player/`, e um `.tres` referenciado
## de dentro do save levaria o historico inteiro junto numa refatoracao de pasta.
func id_do_personagem() -> String:
	if personagem == null:
		return Progressao.personagem_selecionado()
	return str(personagem.id)


## Pedido de quem carregou o menu para que ele abra a selecao de operador direto,
## sem o menu piscar antes.
##
## E de MAO UNICA: quem le, CONSOME. Sem apagar, sair da selecao e voltar ao menu
## a reabriria para sempre, e o jogador ficaria preso num painel que acabou de
## fechar -- sem erro nenhum no console, porque nada ali esta quebrado.
var abrir_selecao_ao_entrar: bool = false


## Le e apaga o pedido. Existe como funcao, e nao como leitura crua do campo,
## justamente para o consumo nao poder ser esquecido por quem le.
func consumir_pedido_de_selecao() -> bool:
	var pedido := abrir_selecao_ao_entrar
	abrir_selecao_ao_entrar = false
	return pedido


## Mede pelo `tempo_run`, e nao por um relogio proprio: assim a pausa e o
## hitstop ja saem descontados de graca, sem ninguem lembrar de descontar.
func _ready() -> void:
	EventBus.boss_revelado.connect(func(_nome: String, _vida: int) -> void:
		_chefe_comecou = tempo_run
	)
	EventBus.boss_morreu.connect(func() -> void: _fechar_cronometro_do_chefe())


func _process(delta: float) -> void:
	if estado == Estado.JOGANDO:
		tempo_run += delta


## Entra no LOBBY, e o ponto e tudo que ele NAO faz.
##
## Nao liga a Deterioracao passiva, nao zera contador de run, nao mexe em
## `Modificadores`, nao gera mapa, nao spawna. O Lobby e um estado persistente
## separado, e a primeira regra do plano e essa.
##
## Ele DESLIGA a passiva de proposito em vez de so nao ligar: quem chega aqui
## pode estar vindo de uma run que terminou, e uma barra que continua subindo no
## lobby seria a mesma falha silenciosa que o projeto ja pagou uma vez -- so que
## ao contrario.
func entrar_lobby() -> void:
	modo = Modo.LOBBY
	estado = Estado.MENU
	Deterioracao.passiva_ativa = false
	RegistroRun.descartar()
	get_tree().paused = false
	Engine.time_scale = 1.0


## Credita, e avisa quem escuta.
##
## Quantidade nao positiva e ignorada em silencio de proposito: um drop que
## sorteie zero e caso normal, e nao erro. O que NAO e normal e debitar por aqui
## -- para isso ha `gastar_creditos`, que devolve `bool`.
func adicionar_creditos(quantidade: int) -> void:
	if quantidade <= 0:
		return
	creditos += quantidade
	EventBus.creditos_mudaram.emit(creditos, quantidade)


func pode_pagar(quantidade: int) -> bool:
	return quantidade >= 0 and creditos >= quantidade


## Debita, e devolve se conseguiu.
##
## **Quando devolve `false` ela nao muda NADA**, e isso e contrato e nao detalhe:
## a transacao da Loja valida a entrega antes de pagar, e uma funcao que debita e
## deixa o chamador conferir depois e a forma de o jogador pagar por uma arma que
## nao recebeu. Numa economia isso nao tem desfazer.
func gastar_creditos(quantidade: int) -> bool:
	if not pode_pagar(quantidade):
		return false
	creditos -= quantidade
	EventBus.creditos_mudaram.emit(creditos, -quantidade)
	return true


func creditos_atuais() -> int:
	return creditos


func iniciar_run() -> void:
	modo = Modo.RUN
	estado = Estado.JOGANDO
	salas_limpas = 0
	total_salas = 0
	creditos = 0
	# O saldo zerado tambem e uma mudanca: a HUD tem de largar o numero da run
	# anterior, e ela so sabe pelo sinal.
	EventBus.creditos_mudaram.emit(0, 0)
	inimigos_mortos = 0
	tempo_run = 0.0
	tempo_chefe = 0.0
	_chefe_comecou = -1.0
	Deterioracao.resetar()
	# Implante e progressao de run, nao meta-progressao: run nova comeca limpa.
	Modificadores.resetar()
	# Depois do resetar, nunca antes: ele limpa o Hack junto com o resto, entao
	# configurar primeiro seria configurar para o lixo.
	Modificadores.configurar_hack(personagem)
	Deterioracao.passiva_ativa = true
	get_tree().paused = false
	Engine.time_scale = 1.0
	# A semente e guardada na run e nao usada aqui: e por ela que uma run
	# interessante podera ser repetida, e que a geracao voltara identica quando
	# houver save no meio da run.
	semente_da_run = randi()
	RegistroRun.comecar(id_do_personagem(), semente_da_run)


func terminar_run(venceu: bool) -> void:
	if estado == Estado.GAME_OVER or estado == Estado.VITORIA:
		return
	estado = Estado.VITORIA if venceu else Estado.GAME_OVER
	# Morrer PARA o chefe tambem encerra a luta, e e o caso mais informativo de
	# todos para o tuning: e a luta que passou do ponto.
	_fechar_cronometro_do_chefe()
	Deterioracao.passiva_ativa = false
	modo = Modo.RESULTADO

	# REGISTRA ANTES DE EMITIR, e a ordem importa.
	#
	# Quem escuta `run_terminada` troca de cena. Se o registro viesse depois, o
	# terminal de historico do Lobby poderia abrir antes de a run ter entrado no
	# perfil -- e o jogador veria a tela que existe para provar que o save
	# funciona sem o resultado que ele acabou de produzir.
	var resultado := RegistroRun.terminar(
		venceu, "chefe" if venceu else "morte", tempo_run)
	if resultado != null and Progressao.carregado():
		Progressao.registrar_run(resultado)

	EventBus.run_terminada.emit(venceu, estatisticas())


func estatisticas() -> Dictionary:
	return {
		"salas_limpas": salas_limpas,
		"tempo_chefe": tempo_chefe,
		"total_salas": total_salas,
		"inimigos_mortos": inimigos_mortos,
		"creditos": creditos,
		"tempo": tempo_run,
		"deterioracao_final": Deterioracao.valor,
	}


## Idempotente: chamado pela morte da Diretora e de novo pelo fim da run, e o
## segundo nao pode esticar o tempo ate a tela de fim aparecer.
func _fechar_cronometro_do_chefe() -> void:
	if _chefe_comecou < 0.0 or tempo_chefe > 0.0:
		return
	tempo_chefe = maxf(tempo_run - _chefe_comecou, 0.0)


func alternar_pausa() -> void:
	if estado == Estado.JOGANDO:
		estado = Estado.PAUSADO
		get_tree().paused = true
	elif estado == Estado.PAUSADO:
		estado = Estado.JOGANDO
		get_tree().paused = false


func formatar_tempo(segundos: float) -> String:
	var m := int(segundos) / 60
	var s := int(segundos) % 60
	return "%02d:%02d" % [m, s]
