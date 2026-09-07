class_name PerfilDeCorredor
extends Resource
## O que um CORREDOR_TECNICO representa, e como isso aparece.
##
## O corredor deixou de ser o conector universal e virou o caso raro -- uma, as
## vezes duas arestas por andar. E por ficar raro que ele passa a parecer um
## corredor de servico de verdade em vez do espaco obrigatorio entre combates; e
## por ficar raro que vale dar-lhe decoracao propria.
##
## ## Por que a decoracao vive no CHAO e no DECALQUE, e nunca na face
##
## A ideia obvia era vestir a face do corredor com os modulos ja entregues --
## tubulacao, tecnica, deteriorada. **Ela colide de frente com a regra da noite
## base**, que existe e e deliberada:
##
##     "Corredor comum nao veste a cor da sala vizinha de proposito: pintar cada
##     metade com a cor da vizinha anunciaria o que ha do outro lado antes de o
##     jogador chegar."
##
## Os modulos de face so existem nos TINGIMENTOS de tipo de sala, entao vesti-los
## anunciaria a vizinha -- e a unica excecao autorizada a anunciar e o trecho
## pre-chefe. Fazer modulos neutros seria arte nova; abrir a excecao seria
## desfazer a regra.
##
## O chao e o decalque nao tem esse problema: as tres texturas de chao do andar 1
## SAO a noite base, entao escolher entre elas por perfil nao diz nada sobre a
## vizinha. E o decalque e industrial e mudo -- uma valvula no chao nao informa
## que sala vem depois.
##
## ## E por que o perfil sai dos DOIS temas das pontas
##
## Um corredor entre `ENERGIA` e `MANUTENCAO` nao e o mesmo que um entre dois
## `ARMAZENAMENTO`. Ele e a ligacao ENTRE duas partes da fabrica, e o que ele
## carrega e o que passa de uma para a outra: forca, agua, ar, peca.
##
## Isso e afinidade e nao regra fechada -- um perfil pede temas, e quem escolhe
## soma quantas pontas ele atende. Assim nenhum par de temas fica sem corredor.

@export var id: StringName = &""

## Os temas de sala que este perfil atende, pelo `id` do `TemaDeSala`.
##
## Uma ponta que bate vale um ponto; duas valem dois. O empate cai no sorteio da
## semente do andar, entao dois perfis igualmente adequados nao produzem sempre
## o mesmo -- que e o que faz dois andares com o mesmo par de temas nao virarem
## a mesma imagem.
@export var temas: Array[StringName] = []

## O chao deste perfil, e ele TEM de estar na noite base.
##
## `teste_conexoes.gd` cobra que todo `textura_chao` declarado aqui esteja em
## `Corredor.TEXTURAS_CHAO`. Sem esse portao, um `.tres` novo apontando para
## `chao_boss.png` desfaria a regra da noite base sem uma linha no console -- e o
## sintoma seria o andar inteiro anunciando o chefe, que e exatamente o defeito
## que a excecao do trecho pre-chefe existe para conter num lugar so.
@export var textura_chao: Texture2D

@export_group("Decalque")
## O atlas e as regioes de onde saem as marcas de chao deste perfil.
##
## Elas sao coordenadas CRUAS no atlas, como em `DadosSala`: o atlas cresce para
## baixo e nunca se recompoe, porque remanejar celulas faz todo decalque ja
## declarado apontar para outro desenho.
@export var atlas_decalques: Texture2D
@export var regioes_decalques: Array[Rect2i] = []
## Quantas marcas o corredor tenta colocar.
##
## Baixo de proposito, e pela mesma razao que `max_props_animados` e baixo: o
## corredor e estreito e o jogador o atravessa em menos de dois segundos. Marca
## demais num espaco de passagem vira ruido sob os pes em vez de leitura.
@export var quantidade_decalques: int = 2


## Quantas pontas deste corredor este perfil atende.
##
## Zero nao desqualifica: um perfil sem afinidade nenhuma continua elegivel, so
## perde para quem tem. Desqualificar deixaria pares de temas sem corredor
## nenhum, e um corredor sem perfil e o corredor pelado de antes desta issue.
func afinidade(tema_a: StringName, tema_b: StringName) -> int:
	var pontos := 0
	if temas.has(tema_a):
		pontos += 1
	if temas.has(tema_b):
		pontos += 1
	return pontos
