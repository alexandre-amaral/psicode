extends Node
## Quem le e escreve o arquivo de progresso. **E so isso.**
##
## Ele nao troca de cena, nao decide o que um desbloqueio significa e nao sabe o
## que e uma run. Quem interpreta os dados e o `Progressao`; quem conduz o
## jogador e o menu e o Lobby. A separacao parece cerimonia com um arquivo so, e
## ela paga na primeira vez que houver dois slots, ou um save na nuvem, ou uma
## migracao: nada disso encosta em quem interpreta.
##
## **Ele nao mora no `Configuracao`, e isso e decisao registrada.** Aquele
## autoload guarda PREFERENCIA, e o cabecalho dele diz que apagar a config nao
## pode custar caro. Progresso e o contrario: e o unico arquivo do jogo cuja
## perda o jogador sente. Misturar os dois faria "resetar as opcoes" e "perder o
## historico" virarem a mesma acao.

## O `class_name` da forma dos dados vive em `src/save/`; aqui so o arquivo.
const CAMINHO := "user://save_01.json"

## Motivos de falha, para quem chamou poder dizer a coisa certa ao jogador.
enum Falha { NENHUMA, NAO_EXISTE, ILEGIVEL, CORROMPIDO }

## O ultimo motivo de falha de `carregar()`. Lido pelo menu para escolher entre
## "nao ha jogo salvo" e "nao foi possivel carregar o arquivo de progresso" --
## as duas frases dizem coisas muito diferentes ao jogador, e um booleano
## sozinho nao separaria as duas.
var ultima_falha: int = Falha.NENHUMA

## Sobrescrevivel para a suite nao escrever no arquivo real.
##
## `Configuracao` ja tem exatamente esta valvula, e pelo mesmo motivo: uma suite
## que grava no `user://` de verdade apaga o progresso de quem esta
## desenvolvendo, e o sintoma so aparece quando a pessoa vai jogar.
var _caminho: String = CAMINHO


func _caminho_temporario() -> String:
	return _caminho + ".tmp"


## O backup: a copia do save ANTERIOR, guardada antes de cada gravacao boa.
##
## Nao e redundancia da escrita segura -- as duas cobrem falhas diferentes. O
## temporario protege contra a gravacao ser INTERROMPIDA; o backup protege
## contra a gravacao ter dado certo com conteudo ruim, que e o caso que nenhuma
## trava de arquivo pega. Um bug que zere o historico e grave com sucesso passa
## limpo pelo temporario.
func _caminho_de_backup() -> String:
	return _caminho + ".bak"


## Ha um perfil em disco?
func save_existe() -> bool:
	return FileAccess.file_exists(_caminho)


## Um perfil novo, ja gravado.
##
## Grava na hora e nao "quando o jogador fizer algo": se o jogo fechar entre
## criar o perfil e a primeira acao dele, o NOVO JOGO teria sido uma promessa
## vazia -- e na proxima abertura o CARREGAR estaria apagado de novo, sem
## explicacao.
func criar_novo_save() -> DadosSave:
	var dados := DadosSave.novo()
	salvar(dados)
	return dados


## Le o perfil. `null` quando nao da, com `ultima_falha` dizendo por que.
##
## **Nao estoura em save corrompido.** O jogador que abre o jogo e ve um crash
## nao tem nada a fazer com a informacao; o que ele precisa e de uma frase e de
## um botao. Quem decide a frase e quem chamou.
func carregar() -> DadosSave:
	ultima_falha = Falha.NENHUMA
	if not FileAccess.file_exists(_caminho):
		ultima_falha = Falha.NAO_EXISTE
		return null
	var arquivo := FileAccess.open(_caminho, FileAccess.READ)
	if arquivo == null:
		ultima_falha = Falha.ILEGIVEL
		return null
	var texto := arquivo.get_as_text()
	arquivo.close()
	var bruto: Variant = JSON.parse_string(texto)
	if not (bruto is Dictionary):
		ultima_falha = Falha.CORROMPIDO
		return null
	var dados := DadosSave.de_dicionario(bruto)
	migrar(dados)
	return dados


## Grava. `false` quando nao deu, e o arquivo anterior continua intacto.
##
## **Escreve num temporario e so entao substitui o real.** Escrever direto sobre
## o definitivo significa que uma queda de energia no meio da gravacao deixa um
## JSON pela metade -- e um JSON pela metade nao e "um save com menos coisas", e
## um save que nao abre. O jogo perderia todo o progresso no unico momento em
## que estava tentando protege-lo.
func salvar(dados: DadosSave) -> bool:
	if dados == null:
		return false
	var temporario := _caminho_temporario()
	var arquivo := FileAccess.open(temporario, FileAccess.WRITE)
	if arquivo == null:
		push_warning("Save: nao foi possivel abrir %s para escrita" % temporario)
		return false
	arquivo.store_string(JSON.stringify(dados.para_dicionario(), "\t"))
	arquivo.close()

	# So a partir daqui o arquivo definitivo corre risco, e ele corre pelo tempo
	# de um rename.
	var acesso := DirAccess.open(_caminho.get_base_dir())
	if acesso == null:
		return false
	if acesso.file_exists(_caminho.get_file()):
		# O backup e a versao ANTERIOR, e nao a que esta sendo escrita. Copiar
		# depois faria as duas serem o mesmo arquivo -- e um backup identico ao
		# original nao recupera de nada.
		# Caminho ABSOLUTO, e nao relativo ao `DirAccess`: com nome solto a copia
		# falha em silencio quando o diretorio corrente nao e o que se espera, e
		# um backup que nao existe so se descobre no dia em que ele e preciso.
		DirAccess.copy_absolute(_caminho, _caminho_de_backup())
		acesso.remove(_caminho.get_file())
	var erro := acesso.rename(temporario.get_file(), _caminho.get_file())
	if erro != OK:
		push_warning("Save: nao foi possivel substituir o save (%d)" % erro)
		return false
	return true


func apagar_save() -> void:
	var acesso := DirAccess.open(_caminho.get_base_dir())
	if acesso == null:
		return
	for caminho in [_caminho, _caminho_de_backup(), _caminho_temporario()]:
		if acesso.file_exists(caminho.get_file()):
			acesso.remove(caminho.get_file())


## Ha uma copia anterior para oferecer?
func backup_existe() -> bool:
	return FileAccess.file_exists(_caminho_de_backup())


## Promove o backup a save e o le.
##
## `null` se nao havia backup ou se ele tambem nao abre -- dois saves ruins
## seguidos e uma situacao real, e nela o jogo tem de dizer isso em vez de
## prometer uma recuperacao que nao aconteceu.
func restaurar_backup() -> DadosSave:
	if not backup_existe():
		ultima_falha = Falha.NAO_EXISTE
		return null
	var acesso := DirAccess.open(_caminho.get_base_dir())
	if acesso == null:
		ultima_falha = Falha.ILEGIVEL
		return null
	if acesso.file_exists(_caminho.get_file()):
		acesso.remove(_caminho.get_file())
	if DirAccess.copy_absolute(_caminho_de_backup(), _caminho) != OK:
		ultima_falha = Falha.ILEGIVEL
		return null
	return carregar()


## Traz um perfil antigo para o formato de hoje.
##
## **Ela existe vazia de proposito.** Escrever a valvula depois e escreve-la
## quando ja ha saves antigos no mundo para consertar, e ai o codigo de migracao
## precisa adivinhar o que a versao sem numero continha. Com ela aqui desde a
## primeira gravacao, todo save em disco tem numero e a proxima mudanca de
## formato tem de onde partir.
func migrar(dados: DadosSave) -> void:
	if dados == null or dados.versao_save >= DadosSave.VERSAO:
		return
	# Ainda nao ha versao anterior a 1. Quando houver, cada degrau entra aqui
	# como um `if dados.versao_save < N`, em ordem, sem pular nenhum.
	dados.versao_save = DadosSave.VERSAO
