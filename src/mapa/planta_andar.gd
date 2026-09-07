class_name PlantaDoAndar
extends Resource
## COMO as arestas do grafo viram geometria neste andar.
##
## Ate aqui uma aresta `A <-> B` significava, literalmente, `criar_corredor(A, B)`
## -- e o resultado era um mapa que parece camaras independentes ligadas por
## tuneis. Funciona para uma dungeon; enfraquece a ideia de que o andar 1 era uma
## fabrica CONTINUA antes de ser abandonada.
##
## Este recurso separa as duas coisas. O grafo continua decidindo QUAIS salas se
## ligam; a planta decide COMO a ligacao existe no espaco.
##
## **Andar sem planta e o comportamento de hoje**, e isso nao e conveniencia: e a
## mesma regra que mantem o Rastejante e o Vigia funcionando sem `DadosInimigo`.
## Um andar futuro pode ter outra planta sem que a geracao logica mude uma linha,
## e nenhum andar que existe muda de graca.
##
## ## Por que os vaos continuam sendo POR EIXO
##
## Eles nasceram assim porque a parede era assimetrica -- 92 px de encontro no
## vertical (sul 32 + norte 60) contra 72 no horizontal (36 x 2) --, e um numero
## unico obrigaria o eixo folgado a usar o do apertado.
##
## **Com a parede simetrica os dois eixos coincidem em 128**, e o par podia virar
## um numero so. Ele nao vira: os `escala_*` do perfil existem justamente para
## um andar futuro poder engrossar um lado, e ali os eixos voltam a divergir. Um
## campo que hoje guarda dois valores iguais custa nada; recriar o eixo depois
## custaria mexer em toda planta ja salva.
##
## ## E por que a escolha e por FRONTEIRA, e nao por aresta
##
## O andar e montado em BANDAS: a largura de cada coluna e a da sala mais larga
## dela, e o vao separa duas fileiras INTEIRAS. Duas salas na mesma fronteira nao
## podem ter vaos diferentes -- uma parede compartilhada ao lado de um corredor
## forcaria as duas ao vao do corredor, e a primeira ficaria com 300 px de chao
## entre as faixas dela.
##
## Entao quem sorteia e a fronteira, e todas as arestas que a cruzam recebem o
## mesmo tipo. E uma restricao do layout, e nao uma escolha.

## Os tres jeitos de duas salas se ligarem.
##
## Valor novo entra sempre NO FIM: enum e gravado como INT no `.tres`, e inserir
## no meio reescreve em silencio o significado de toda planta ja salva. Mesma
## armadilha de `DadosArma.Comportamento` e `DadosItem`.
enum Conexao { PAREDE_COMPARTILHADA, PASSAGEM_CURTA, CORREDOR_TECNICO }

@export var id: StringName = &""

@export_group("Pesos")
## Setores adjacentes do mesmo galpao: as duas faixas de parede se encontram e
## nao sobra piso de corredor nenhum.
@export var peso_parede_compartilhada: float = 0.0
## Uma separacao estrutural curta -- soleira, tubulacao atravessando, viga.
@export var peso_passagem_curta: float = 0.0
## O corredor de hoje. Default 1.0: sem planta, e sem mexer em peso nenhum, o
## andar continua sendo o que sempre foi.
@export var peso_corredor_tecnico: float = 1.0

@export_group("Pesos ENTRE clusters")
## Os mesmos tres pesos, para uma fronteira que separa dois setores funcionais.
##
## **A regra que sai daqui e intuitiva e o jogador a percebe sem que nada a
## diga:** quanto mais relacionadas duas areas sao, mais integrada e a
## arquitetura entre elas. Dentro de um cluster predomina a parede
## compartilhada; entre clusters, a passagem e o corredor.
##
## Ter DOIS conjuntos, e nao um multiplicador, e o que mantem isso legivel: o
## `.tres` mostra as duas situacoes lado a lado em vez de um fator que so faz
## sentido depois de multiplicar.
@export var peso_parede_entre_clusters: float = 0.15
@export var peso_passagem_entre_clusters: float = 0.45
@export var peso_corredor_entre_clusters: float = 0.40

@export_group("Vaos (horizontal, vertical)")
## O vao em que as duas faixas se ENCONTRAM: **128 nos dois eixos**, que e
## `profundidade x 2 = 120` arredondado para a grade de 16.
##
## `teste_grade.gd` cobra o vao entre bandas na grade de 16, entao o
## arredondamento nao e opcional; os 8 px que sobram sao o respiro entre as duas
## faixas de cap.
##
## **E `Corredor._montar_fita()` desiste abaixo desse mesmo numero**, porque ele
## passou a DERIVAR do perfil em vez de ser `ESPESSURA_PAREDE * 2`. Escrito como
## literal, aquilo funcionava por coincidencia -- 128 era o dobro da profundidade
## de entao --, e o corpo indo a 56 fez o vao ir a 144: o corredor voltaria a
## desenhar uma faixa POR CIMA das duas que ja se encontram ali, sem erro nenhum,
## so uma emenda de parede no meio da passagem.
@export var vao_parede_compartilhada := Vector2(128.0, 128.0)
## Curto o bastante para nao virar um lugar: com 136 px ja ocupados pelas duas
## faixas de parede, sobram 72 px de piso -- 0,33 s a 220 px/s.
##
## **Ele subiu de 144 junto com o corpo da parede, e nao por gosto.** Com o
## encontro em 144, uma passagem de 144 seria a MESMA coisa que uma parede
## compartilhada, e `teste_conexoes` cobra que os tres vaos fiquem em ordem
## estrita -- dois tipos que produzem a mesma geometria sao um tipo so com dois
## nomes.
@export var vao_passagem_curta := Vector2(160.0, 176.0)
## Longo o bastante para ser um lugar, e raro o bastante para significar algo.
@export var vao_corredor_tecnico := Vector2(384.0, 384.0)


## Sorteia um tipo por peso. `rng` entra de fora para o andar inteiro sair de uma
## semente so.
func sortear(rng: RandomNumberGenerator, entre_clusters: bool = false) -> Conexao:
	var pesos := [peso_parede_compartilhada, peso_passagem_curta, peso_corredor_tecnico]
	if entre_clusters:
		pesos = [peso_parede_entre_clusters, peso_passagem_entre_clusters,
			peso_corredor_entre_clusters]
	var total := 0.0
	for p: float in pesos:
		total += maxf(p, 0.0)
	if total <= 0.0:
		return Conexao.CORREDOR_TECNICO
	var alvo := rng.randf() * total
	for i in pesos.size():
		alvo -= maxf(pesos[i], 0.0)
		if alvo <= 0.0:
			return i as Conexao
	return Conexao.CORREDOR_TECNICO


## O vao deste tipo no eixo pedido.
func vao(tipo: Conexao, vertical: bool) -> float:
	var par := vao_corredor_tecnico
	match tipo:
		Conexao.PAREDE_COMPARTILHADA:
			par = vao_parede_compartilhada
		Conexao.PASSAGEM_CURTA:
			par = vao_passagem_curta
	return par.y if vertical else par.x


## O nome do tipo, para mensagem de teste e para o minimapa.
static func nome_de(tipo: Conexao) -> String:
	match tipo:
		Conexao.PAREDE_COMPARTILHADA:
			return "parede_compartilhada"
		Conexao.PASSAGEM_CURTA:
			return "passagem_curta"
		_:
			return "corredor_tecnico"
