extends InimigoBase
## Um ponto de energia da Sobrecarga do Nucleo. Existe para ser destruido.
##
## E o unico "inimigo" do jogo que nao ameaca ninguem: nao anda, nao atira, nao
## machuca no contato. O papel dele e ser uma PERGUNTA -- vale a pena parar de
## esquivar para atirar em mim? -- e a resposta muda o tamanho do estouro que
## vem a seguir.
##
## Herda de InimigoBase em vez de ser um corpo proprio porque tudo que ele
## precisa ja mora la: vida, clarao de dano, morte com explosao, e a entrada no
## grupo "inimigo" que faz as armas do jogador o enxergarem. O que ele NAO herda
## e o que importa: sem `_comportamento`, ele nao faz nada.
##
## Ele nao segura a vitoria da sala. Nasce pela Diretora e nao pela Sala, entao
## fica fora de `Sala._vivos` pelo mesmo caminho que os invocados dela -- a sala
## do chefe continua fechando pela morte DELA e por mais nada.


func _ready() -> void:
	super._ready()
	# Dano de contato zero: ele nega tempo, nao espaco. Um ponto que tambem
	# machucasse transformaria "vale a pena atirar nele?" em "nao da para chegar
	# perto", e a pergunta que ele existe para fazer desapareceria.
	dano_contato = 0


func _comportamento(_delta: float) -> void:
	pass
