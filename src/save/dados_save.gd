class_name DadosSave
extends RefCounted
## O progresso PERMANENTE do jogador.
##
## O `Configuracao` e o outro `user://` do projeto, e o cabecalho dele ja
## avisava: *"guarda PREFERENCIA, nao progresso. Save de run e meta-progressao
## sao outro assunto e nao devem entrar aqui, senao apagar a config passa a
## custar caro."* Este arquivo e o lugar certo que aquele comentario prometia.
##
## **Metade dos campos abaixo comeca vazia de proposito.** Desbloqueio, upgrade
## permanente e moeda nao tem conteudo nenhum ainda, e o plano manda nao inventar
## conteudo agora. Mas acrescentar CAMPO a um formato depois e barato -- todo
## carregamento aqui tem default --, enquanto mudar a FORMA do arquivo depois
## quebra o save de quem ja jogou. O custo de reservar o lugar hoje e uma linha;
## o de nao reservar e uma migracao.

## A versao do FORMATO, e ela existe desde a primeira gravacao.
##
## `migrar_save()` tambem, mesmo sem fazer nada ainda. Escrever a valvula depois
## e escrever ela quando ja ha saves antigos no mundo para consertar -- e ai o
## codigo de migracao precisa adivinhar o que a versao sem numero continha.
const VERSAO := 1

## Quantas runs o historico guarda.
##
## O historico nao precisa ser infinito, e um teto que nunca morde e um teto que
## nunca foi testado. Vinte cabe numa rolagem curta do terminal e ainda mostra
## uma sessao inteira de jogo.
const HISTORICO_MAXIMO := 20

var versao_save: int = VERSAO
var slot_id: int = 1

## O `id` do personagem escolhido, nunca o recurso.
var personagem_selecionado: String = "raven"

var total_runs: int = 0
var total_vitorias: int = 0
var total_derrotas: int = 0

var melhor_andar: int = 0
var melhor_sala: int = 0
var maior_dano_run: int = 0
var maior_numero_kills: int = 0

var historico_runs: Array[ResultadoRun] = []

## Os quatro reservados. Ver o cabecalho: eles existem vazios porque o formato
## precisa ter lugar antes de o conteudo existir.
var personagens_desbloqueados: Dictionary = {"raven": true, "nova": true}
var upgrades_permanentes: Dictionary = {}
var desbloqueios: Dictionary = {}
var moedas_persistentes: Dictionary = {"memoria": 0}


## Um perfil novo, com os defaults do plano.
static func novo() -> DadosSave:
	return DadosSave.new()


## O dicionario que vai virar JSON.
##
## As chaves sao as do plano e estao em INGLES enquanto o resto do projeto e em
## portugues. Nao e descuido: elas sao o FORMATO DE ARQUIVO, e formato e
## contrato com o disco -- renomear uma chave depois invalida todo save ja
## gravado, entao ela vale menos ao gosto de quem le o codigo do que a
## estabilidade. Os campos do objeto continuam em portugues, como todo o resto.
func para_dicionario() -> Dictionary:
	var historico: Array = []
	for r in historico_runs:
		historico.append(r.para_dicionario())
	return {
		"version": versao_save,
		"slot_id": slot_id,
		"selected_character": personagem_selecionado,
		"stats": {
			"total_runs": total_runs,
			"total_vitorias": total_vitorias,
			"total_derrotas": total_derrotas,
			"melhor_andar": melhor_andar,
			"melhor_sala": melhor_sala,
			"maior_dano_run": maior_dano_run,
			"maior_numero_kills": maior_numero_kills,
		},
		"run_history": historico,
		"unlocked_characters": personagens_desbloqueados,
		"permanent_upgrades": upgrades_permanentes,
		"unlockables": desbloqueios,
		"currencies": moedas_persistentes,
	}


## O caminho de volta, e **todo campo tem default**.
##
## Nunca `dados["stats"]["total_runs"]`. Um save escrito por uma versao que nao
## tinha aquele bloco derrubaria o jogo na abertura, e o jogador nao tem como
## saber que o problema e uma chave ausente. Com default, um arquivo que so tem
## `{"version": 1}` carrega e vira um perfil zerado -- que e o comportamento
## certo, porque um perfil zerado ainda deixa jogar.
static func de_dicionario(dados: Dictionary) -> DadosSave:
	var s := DadosSave.new()
	s.versao_save = int(dados.get("version", VERSAO))
	s.slot_id = int(dados.get("slot_id", 1))
	s.personagem_selecionado = str(dados.get("selected_character", "raven"))

	var stats: Dictionary = dados.get("stats", {})
	s.total_runs = int(stats.get("total_runs", 0))
	s.total_vitorias = int(stats.get("total_vitorias", 0))
	s.total_derrotas = int(stats.get("total_derrotas", 0))
	s.melhor_andar = int(stats.get("melhor_andar", 0))
	s.melhor_sala = int(stats.get("melhor_sala", 0))
	s.maior_dano_run = int(stats.get("maior_dano_run", 0))
	s.maior_numero_kills = int(stats.get("maior_numero_kills", 0))

	var historico: Array[ResultadoRun] = []
	for bruto in dados.get("run_history", []):
		if bruto is Dictionary:
			historico.append(ResultadoRun.de_dicionario(bruto))
	s.historico_runs = historico

	s.personagens_desbloqueados = dados.get(
		"unlocked_characters", {"raven": true, "nova": true})
	s.upgrades_permanentes = dados.get("permanent_upgrades", {})
	s.desbloqueios = dados.get("unlockables", {})
	s.moedas_persistentes = dados.get("currencies", {"memoria": 0})
	return s


## Poe um resultado no historico e atualiza os totais.
##
## O corte e por CIMA da lista, e nao por baixo: o terminal mostra a run mais
## recente primeiro, entao o indice 0 e a ultima e quem cai fora e a mais velha.
func registrar(resultado: ResultadoRun) -> void:
	total_runs += 1
	if resultado.venceu:
		total_vitorias += 1
	else:
		total_derrotas += 1
	resultado.id = total_runs
	melhor_andar = maxi(melhor_andar, resultado.andar_alcancado)
	maior_dano_run = maxi(maior_dano_run, resultado.dano_causado)
	maior_numero_kills = maxi(maior_numero_kills, resultado.kills)
	historico_runs.insert(0, resultado)
	while historico_runs.size() > HISTORICO_MAXIMO:
		historico_runs.remove_at(historico_runs.size() - 1)
