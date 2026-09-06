class_name TemaDeSala
extends Resource
## O SUBTEMA de uma sala: que parte da fabrica ela era.
##
## Textura e prop respondem "o que existia aqui?" por trecho. Nenhum dos dois
## responde **"esta fabrica tinha organizacao interna?"** -- e sem isso o andar
## continua sendo um conjunto procedural de salas com decoracao aleatoria, por
## melhor que a arte seja.
##
## **Ele NAO muda o tipo funcional.** Sala de combate continua sala de combate,
## sala de arma continua entregando arma. O tema so pesa a DECORACAO: qual
## modulo de face aquela sala veste, e -- quando a biblioteca de props existir --
## quais objetos ela pode receber.
##
## Dirigido por dados como o resto da camada de mapa. Tema novo e um `.tres` novo
## na lista do `GerenciadorMapa`, e nao um `if` a mais: e a mesma regra que
## proibiu `cena_boss`/`cena_tesouro` no gerenciador.
##
## **O modulo se identifica pelo SUFIXO do arquivo**, e nao por uma referencia
## direta a `Texture2D`. Uma referencia obrigaria cada tema a listar a face de
## cada um dos cinco tipos de sala -- 6 temas x 5 tipos = 30 campos, que e a
## explosao de `@export` que o `EstiloDeParede` existe para evitar. O sufixo ja e
## contrato: os arquivos se chamam `parede_face_<tipo>_<modulo>.png` desde a
## LTD 13, e `teste_tema.gd` cobra que todo favorito nomeado exista em disco.

## O nome do tema, para o Inspetor e para mensagem de teste.
@export var id: StringName = &""

## Quanto este tema pesa no sorteio, em relacao aos outros da lista.
@export var peso: float = 1.0

## O sufixo do modulo de face que este tema favorece.
##
## Vazio = o tema favorece a face COMUM, que e a primeira da lista e nao tem
## sufixo. `ARMAZENAMENTO` e `PRODUCAO` sao assim de proposito: nem toda sala de
## uma fabrica tem tubulacao aparente, e um andar em que toda parede grita a
## propria funcao nao tem funcao nenhuma.
@export var modulo_favorito: StringName = &""

## Quantas copias do favorito entram entre as especiais.
##
## O sorteio de face e UMA escolha por lado, e uma sala mostra UM lado
## (`LIMIAR_LADO_NORTE`). Entao "favorecer" aqui nao e enviesar uma distribuicao
## longa: e decidir a cara daquela sala. Tres copias contra as duas ou tres
## especiais do terco corrente poem o favorito por volta de 60% -- alto o
## bastante para o tema se ler, baixo o bastante para duas salas do mesmo tema
## nao serem a mesma foto.
@export var reforco: int = 3

## O sufixo do DECALQUE de topo que este tema favorece (#244).
##
## Mesmo mecanismo do modulo de face, e pela mesma razao: `ENERGIA` favorece
## marca de queimadura, `MANUTENCAO` favorece solda. Vazio = o tema nao puxa
## nenhum, e a lista do estilo vale como esta.
@export var decalque_favorito: StringName = &""

## Quanto da parede continua sendo o modulo COMUM neste tema. Negativo = herda o
## `peso_comum` do `EstiloDeParede`.
##
## Sentinela NEGATIVO e nao zero, pela mesma razao dos campos de `EstiloDeParede`:
## zero e um valor VALIDO aqui -- quer dizer "esta sala nunca veste a comum" --,
## e um tema que quisesse isso seria silenciosamente ignorado.
@export var peso_comum: float = -1.0


## A lista de faces desta sala, com o favorito do tema reforcado.
##
## `disponiveis` e o catalogo do TIPO (`DadosSala.texturas_face`), e nao a lista
## ja filtrada pelo terco do andar: o favorito do tema tem de poder aparecer
## mesmo quando o terco corrente nao o inclui. O terco existe para o andar mudar
## de cara conforme o jogador avanca; o tema existe para a SALA ter identidade, e
## a segunda pergunta nao pode ser vetada pela primeira.
func aplicar(faces: Array[Texture2D],
		disponiveis: Array[Texture2D]) -> Array[Texture2D]:
	if modulo_favorito == &"" or faces.is_empty():
		return faces
	var favorito := _achar(disponiveis)
	if favorito == null:
		return faces
	var saida: Array[Texture2D] = [faces[0]]
	for i in maxi(reforco, 1):
		saida.append(favorito)
	for i in range(1, faces.size()):
		if faces[i] != favorito:
			saida.append(faces[i])
	return saida


## A lista de decalques de topo, com o favorito do tema na frente e reforcado.
##
## Ao contrario da face, aqui NAO ha lista previa a preservar -- o estilo entrega
## o catalogo do andar inteiro e o tema so muda as chances. Por isso os dois
## recebem o mesmo argumento.
func aplicar_decalques(disponiveis: Array[Texture2D]) -> Array[Texture2D]:
	if decalque_favorito == &"" or disponiveis.is_empty():
		return disponiveis
	var alvo := "_%s.png" % decalque_favorito
	var favorito: Texture2D = null
	for d in disponiveis:
		if d != null and d.resource_path.ends_with(alvo):
			favorito = d
			break
	if favorito == null:
		return disponiveis
	var saida: Array[Texture2D] = []
	for i in maxi(reforco, 1):
		saida.append(favorito)
	for d in disponiveis:
		if d != null and d != favorito:
			saida.append(d)
	return saida


func _achar(disponiveis: Array[Texture2D]) -> Texture2D:
	var alvo := "_%s.png" % modulo_favorito
	for t in disponiveis:
		if t != null and t.resource_path.ends_with(alvo):
			return t
	return null
