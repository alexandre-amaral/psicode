extends Node
## O perfil em memoria, e quem sabe o que os dados SIGNIFICAM.
##
## `Save` le e escreve bytes; este aqui responde perguntas: quem esta
## selecionado, o que esta desbloqueado, qual o nivel de um upgrade, como foi a
## ultima run. A divisao paga na primeira vez que houver dois slots ou uma
## migracao -- nada disso encosta em quem interpreta.
##
## **Nenhuma outra cena toca nos `Dictionary` daqui.** Com acesso direto, cada
## consumidor inventa a propria chave e o proprio default, e o dia em que um
## desbloqueio mudar de nome ninguem descobre: `dict.get("nome_velho", false)`
## responde `false` para sempre, em silencio, e o jogador simplesmente nao ganha
## o que ganhou. Por isso a API e de metodos, como no `Configuracao`.

## O perfil carregado. `null` = ninguem entrou em nenhum perfil ainda.
var _dados: DadosSave = null


## Ha perfil em memoria?
func carregado() -> bool:
	return _dados != null


## Adota um perfil ja lido do disco.
func adotar(dados: DadosSave) -> void:
	_dados = dados


## Cria um perfil novo e ja o adota. NAO pergunta se havia um antes -- quem
## pergunta e o menu, porque a confirmacao e conversa com o jogador e nao regra
## de dados.
func criar_novo() -> DadosSave:
	_dados = Save.criar_novo_save()
	return _dados


## Le o perfil do disco. `false` quando nao deu; o motivo fica em
## `Save.ultima_falha`.
func carregar() -> bool:
	var dados := Save.carregar()
	if dados == null:
		return false
	_dados = dados
	return true


## Grava o que esta em memoria.
func salvar() -> bool:
	if _dados == null:
		return false
	return Save.salvar(_dados)


# --- personagem ---------------------------------------------------------------

## O `id` do personagem escolhido.
func personagem_selecionado() -> String:
	return _dados.personagem_selecionado if _dados != null else "raven"


## Escolhe, e **grava na hora**.
##
## Sem botao "Aplicar", como em `Configuracao`: e um passo a mais para o jogador
## errar e um estado intermediario a mais para o codigo carregar. Trocar de
## personagem e fechar o jogo tem de manter a troca.
func selecionar_personagem(id: String) -> bool:
	if _dados == null or not personagem_desbloqueado(id):
		return false
	_dados.personagem_selecionado = id
	return salvar()


func personagem_desbloqueado(id: String) -> bool:
	if _dados == null:
		return false
	return bool(_dados.personagens_desbloqueados.get(id, false))


func desbloquear_personagem(id: String) -> void:
	if _dados == null:
		return
	_dados.personagens_desbloqueados[id] = true
	salvar()


# --- desbloqueios --------------------------------------------------------------

func esta_desbloqueado(id: String) -> bool:
	if _dados == null:
		return false
	return bool(_dados.desbloqueios.get(id, false))


func desbloquear(id: String) -> void:
	if _dados == null:
		return
	_dados.desbloqueios[id] = true
	salvar()


# --- upgrades permanentes ------------------------------------------------------

func nivel_de_upgrade(id: String) -> int:
	if _dados == null:
		return 0
	return int(_dados.upgrades_permanentes.get(id, 0))


func definir_nivel_de_upgrade(id: String, nivel: int) -> void:
	if _dados == null:
		return
	_dados.upgrades_permanentes[id] = maxi(nivel, 0)
	salvar()


func comprar_upgrade(id: String) -> bool:
	if _dados == null:
		return false
	definir_nivel_de_upgrade(id, nivel_de_upgrade(id) + 1)
	return true


# --- moeda ---------------------------------------------------------------------

func moeda(id: String) -> int:
	if _dados == null:
		return 0
	return int(_dados.moedas_persistentes.get(id, 0))


func creditar(id: String, quantidade: int) -> void:
	if _dados == null:
		return
	_dados.moedas_persistentes[id] = moeda(id) + quantidade
	salvar()


# --- historico -----------------------------------------------------------------

## Guarda o resultado de uma run e grava.
##
## E o unico caminho pelo qual uma run entra no perfil. Quem chama e o
## `RegistroRun`, no fim da run -- e nao o inimigo, nem a arma, nem a sala.
func registrar_run(resultado: ResultadoRun) -> bool:
	if _dados == null or resultado == null:
		return false
	_dados.registrar(resultado)
	return salvar()


## O historico, do mais recente para o mais antigo.
func historico() -> Array[ResultadoRun]:
	return _dados.historico_runs if _dados != null else [] as Array[ResultadoRun]


## A ultima run, ou `null` se ainda nao houve nenhuma.
func ultima_run() -> ResultadoRun:
	if _dados == null or _dados.historico_runs.is_empty():
		return null
	return _dados.historico_runs[0]


## Os totais que o terminal mostra.
func estatisticas() -> Dictionary:
	if _dados == null:
		return {}
	return {
		"total_runs": _dados.total_runs,
		"total_vitorias": _dados.total_vitorias,
		"total_derrotas": _dados.total_derrotas,
		"melhor_andar": _dados.melhor_andar,
		"maior_dano_run": _dados.maior_dano_run,
		"maior_numero_kills": _dados.maior_numero_kills,
	}
