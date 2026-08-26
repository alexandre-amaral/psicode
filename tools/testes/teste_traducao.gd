extends TesteBase
## Confere que o ingles cobre tudo que o jogador le, e que o portugues nao
## depende de tabela nenhuma.
##
## Esta suite existe por causa do preco da decisao de design da traducao: a
## CHAVE e o proprio texto em portugues, e nao um codigo tipo ITEM_NUCLEO_NOME.
## Isso mantem os .tres legiveis no Inspetor e faz o portugues funcionar mesmo
## sem traducao carregada -- mas cobra caro num ponto: **editar o portugues
## quebra o ingles em silencio**. tr() nao acha a chave nova, devolve ela
## mesma, e o jogo em ingles passa a mostrar uma frase em portugues sem que
## nada acuse.
##
## O que se afirma aqui e sempre "existe par na tabela", nunca "a traducao esta
## boa" -- qualidade de texto nao e coisa que teste julgue.

const PASTA_ITENS := "res://src/items/"
const PASTA_PERSONAGENS := "res://src/player/"

## Armas que o jogador de fato ve. As de inimigo (tiro_vigia, tiro_diretora,
## salva_diretora) nunca chegam a tela: nao ha onde ler o nome nem a descricao
## delas, entao exigir traducao seria exigir trabalho que ninguem consome.
const ARMAS_DO_JOGADOR := [
	"res://src/weapons/pistola.tres",
	"res://src/weapons/shotgun.tres",
	"res://src/weapons/smg_mantis.tres",
	"res://src/weapons/pistola_cipher.tres",
]

## Textos de interface que nascem em GDScript. Os que moram em .tscn sao
## traduzidos sozinhos pelo Godot e apareceriam errados na tela na hora; estes
## so aparecem quando o evento acontece, e por isso passam despercebidos.
const UI_EM_CODIGO := [
	"ESTÁVEL", "DEGRADANDO", "CRÍTICO",
	"SALAS %d / %d", "HOSTIS %d", "RECARREGANDO...",
	"MIRA PREDITIVA ATIVA",
	"DEGRADAÇÃO EM 50%",
	"Eles pararam de mirar em você.",
	"Agora miram onde você vai estar.",
	"NÍVEL CRÍTICO",
	"Não confie no que você está vendo.",
	"Você já instalou o máximo deste implante.",
	"DIRETORA OFFLINE",
	"Você sobreviveu à própria cabeça. Por enquanto.",
	"CONSCIÊNCIA PERDIDA",
	"Restaurando do último backup...",
	"SALAS LIMPAS", "HOSTIS NEUTRALIZADOS", "CRÉDITOS", "TEMPO",
	"LUTA DO CHEFE", "DETERIORAÇÃO FINAL",
	"RECOMEÇAR", "VOLTAR PARA O MENU",
	"NOVO JOGO", "CARREGAR", "OPÇÕES", "SAIR",
	"DANO", "CADÊNCIA", "PRECISÃO", "ALCANCE",
	"ESCOLHA O OPERADOR",
]

var _idioma_antes := ""


func nome() -> String:
	return "Traducao"


func executar() -> void:
	_idioma_antes = TranslationServer.get_locale()
	_o_portugues_nao_depende_da_tabela()
	_o_ingles_cobre_a_ui()
	_o_ingles_cobre_os_dados()
	_a_lista_de_idiomas()
	TranslationServer.set_locale(_idioma_antes)


## Em portugues nao ha traducao carregada, entao tr() tem de devolver a chave.
## E o que garante que apagar a tabela inteira nao quebre o jogo em portugues.
func _o_portugues_nao_depende_da_tabela() -> void:
	TranslationServer.set_locale("pt_BR")
	for chave: String in UI_EM_CODIGO:
		igual(tr(chave), chave, "em portugues '%s' devolve a propria chave" % chave.left(28))


func _o_ingles_cobre_a_ui() -> void:
	TranslationServer.set_locale("en")
	for chave: String in UI_EM_CODIGO:
		ok(tr(chave) != chave, "'%s' tem ingles" % chave.left(40))


func _o_ingles_cobre_os_dados() -> void:
	TranslationServer.set_locale("en")
	var conferidos := 0

	var pasta := DirAccess.open(PASTA_ITENS)
	if pasta == null:
		ok(false, "src/items/ pode ser aberta")
	else:
		for arquivo in pasta.get_files():
			if not arquivo.begins_with("implante_") or not arquivo.ends_with(".tres"):
				continue
			var item: DadosItem = load(PASTA_ITENS + arquivo)
			if item == null:
				continue
			conferidos += 2
			ok(tr(item.nome) != item.nome, "%s: o nome tem ingles" % arquivo)
			ok(tr(item.descricao) != item.descricao, "%s: a descricao tem ingles" % arquivo)

	for caminho: String in ARMAS_DO_JOGADOR:
		var arma: DadosArma = load(caminho)
		if arma == null:
			ok(false, "%s carrega" % caminho.get_file())
			continue
		conferidos += 1
		# So a descricao: o NOME e marca. "PST-9 \"Teimosa\"" e "SMG \"Mantis\""
		# sao como a arma se chama, nao uma frase -- traduzir faria a mesma arma
		# ter dois nomes na conversa de quem faz o jogo.
		ok(tr(arma.descricao) != arma.descricao, "%s: a descricao tem ingles" % caminho.get_file())

	var jogadores := DirAccess.open(PASTA_PERSONAGENS)
	if jogadores != null:
		for arquivo in jogadores.get_files():
			if not arquivo.begins_with("personagem_") or not arquivo.ends_with(".tres"):
				continue
			var p: DadosPersonagem = load(PASTA_PERSONAGENS + arquivo)
			if p == null:
				continue
			conferidos += 2
			ok(tr(p.papel) != p.papel, "%s: o papel tem ingles" % arquivo)
			# A descricao voltou a aparecer no cartao quando ele ganhou o layout
			# de HUD, entao voltou a precisar de ingles.
			ok(tr(p.descricao) != p.descricao, "%s: a descricao tem ingles" % arquivo)

	# Guarda contra a suite virar decoracao, como em teste_efeito_item: se a
	# varredura nao achar arquivo nenhum, tudo acima passa sem ter olhado nada.
	ok(conferidos >= 36, "a varredura achou os dados (%d strings)" % conferidos)


func _a_lista_de_idiomas() -> void:
	ok(Configuracao.IDIOMAS.size() >= 2, "ha mais de um idioma para escolher")
	var vistos: Array[String] = []
	for entrada in Configuracao.IDIOMAS:
		var codigo := String(entrada["codigo"])
		var rotulo := String(entrada["rotulo"])
		ok(not codigo.is_empty(), "todo idioma tem codigo")
		ok(not rotulo.is_empty(), "todo idioma tem rotulo")
		ok(not vistos.has(codigo), "o codigo %s nao se repete" % codigo)
		vistos.append(codigo)
	# O primeiro e o default quando o SO nao bate com nenhum: tem de ser o
	# idioma em que o jogo foi escrito, senao o fallback vira uma traducao.
	igual(String(Configuracao.IDIOMAS[0]["codigo"]), "pt_BR", "o primeiro idioma e o pt_BR")
