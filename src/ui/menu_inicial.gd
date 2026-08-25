extends Control
## A casca da tela inicial: fundo, logo, versao, e quem hospeda a selecao de
## operador e o painel de opcoes.
##
## Ela ja foi um menu de quatro botoes. NOVO JOGO existia so para abrir a tela
## onde a escolha de verdade acontece, e CARREGAR imprimia "nao implementado" no
## console -- os dois sairam. Hoje escolher o operador E comecar a partida, e
## OPCOES/SAIR moraram para a barra de baixo da propria selecao.
##
## O rotulo de versao le o config/version do project.godot em vez de trazer o
## numero escrito na cena. Estava fixo em "v1.0.3" enquanto o jogo era
## 0.1.0-alpha -- um testador leria a build como 1.0 e reportaria bug achando
## que e versao final.

const CENA_JOGO := "res://src/main/main.tscn"

@onready var _rotulo_versao: Label = $RodapeEsq
@onready var _opcoes: Control = $MenuOpcoes
@onready var _selecao: Control = $SelecaoPersonagem


func _ready() -> void:
	_mostrar_versao()
	_selecao.escolhido.connect(_ao_escolher_personagem)
	_selecao.pediu_opcoes.connect(_abrir_opcoes)
	_selecao.pediu_sair.connect(get_tree().quit)
	_opcoes.fechado.connect(_ao_fechar_opcoes)


func _mostrar_versao() -> void:
	if _rotulo_versao == null:
		return
	var versao: String = str(ProjectSettings.get_setting("application/config/version", ""))
	# Sem versao configurada e melhor nao mostrar nada do que mostrar "v".
	_rotulo_versao.text = "v" + versao if not versao.is_empty() else ""


func _ao_escolher_personagem(dados: DadosPersonagem) -> void:
	# Escrever ANTES da troca de cena: quem le e o Player, no _ready da cena que
	# esta linha carrega.
	GameState.personagem = dados
	get_tree().change_scene_to_file(CENA_JOGO)


## Esconde a selecao enquanto as opcoes estao abertas: dois paineis empilhados
## confundem, e o escurecimento sozinho nao segura as molduras acesas.
func _abrir_opcoes() -> void:
	_selecao.visible = false
	_opcoes.abrir()


## Devolve o foco a selecao. Sem isto a navegacao por teclado fica sem ancora
## depois de fechar, e nenhum cartao aparece aceso.
func _ao_fechar_opcoes() -> void:
	_selecao.visible = true
	_selecao.focar_primeiro()
