class_name DadosAprimoramento
extends Resource
## Uma CLASSE de Unidade Aprimorada: os numeros e as regras, fora do inimigo.
##
## Uma Unidade Aprimorada e um inimigo normal MAIS uma classe modular. Ela nao e
## inimigo novo, nao e skin, nao e variante fixa de especie e nao e miniboss --
## qualquer inimigo compativel nasce normal (a grande maioria) ou com uma classe.
##
## **Nenhum script de inimigo conhece este recurso**, e essa e a regra que faz o
## sistema valer a pena: uma classe nova entra sem tocar nos cinco, e um inimigo
## novo aceita as tres sem codigo proprio. Quem le isto e o `Aprimoramento`, um
## no que o inimigo hospeda sem saber o que ele faz.
##
## ## A dificuldade sai de DECISAO, e nao de vida inflada
##
## A regra de balanceamento e uma so: **uma mecanica central mais, no maximo, um
## ajuste auxiliar pequeno.** Somar `+50% vida, +20% dano, +20% velocidade e uma
## habilidade` produz um super-inimigo generico -- a classe deixa de significar
## algo e vira um numero maior. A meta de aumento de TTK e de 10% a 35%.
##
## E a velocidade fica em 100% nas tres classes. Mexer nela quebra IA, contorno e
## ataque, e o projeto ja tem a licao escrita para a Cyber-Besta: ela escala a
## investida em DURACAO e nunca em velocidade, porque velocidade maior encurtaria
## a janela de leitura que o agachamento abriu.

## As tres classes do MVP.
##
## **Valor novo entra sempre NO FIM.** Enum e gravado como INT no `.tres`, entao
## inserir no meio reescreve em silencio o significado de todo aprimoramento ja
## salvo -- a mesma armadilha de `DadosArma.Comportamento` e `DadosItem`.
##
## Ela e um ENUM e nao um `Script` exportado, seguindo o precedente da casa. Um
## script por classe daria extensibilidade que este sistema ja tem de outro jeito
## (o inimigo nao conhece a classe), ao preco de um `.tres` que aponta para
## codigo -- e de um erro de carga que aparece como "o aprimoramento nao faz
## nada" em vez de como erro.
enum Classe { REGENERADORA, BLINDADA, SOBRECARREGADA }

@export var id: StringName = &""
@export var nome_exibicao: String = ""
@export var classe: Classe = Classe.REGENERADORA

## Peso relativo no sorteio da classe. Permite uma classe futura ser mais rara
## sem mexer nas que existem.
@export var peso: float = 1.0

## Quanto esta classe custa do orcamento de ameaca da sala.
##
## **Este campo e o epico inteiro.** Sem ele a sala fica com os mesmos corpos
## MAIS uma ameaca, que e dificuldade por quantidade com um chapeu. Com ele, um
## Hacker Regenerador (3 + 2) ocupa o lugar de um Hacker e dois Drones -- menos
## corpos, mais decisao.
@export var custo_ameaca: int = 2

@export_group("Atributos")
## Multiplicadores aplicados no nascimento. Um deles longe de 1,0 e um ajuste
## auxiliar; DOIS ja e o super-inimigo generico que a regra proibe.
@export var multiplicador_vida: float = 1.0
@export var multiplicador_dano: float = 1.0
## Acima de 1,0 o inimigo ataca MAIS RAPIDO -- ele multiplica o consumo do
## intervalo, como `Deterioracao.multiplicador_cadencia()` ja faz.
@export var multiplicador_cadencia: float = 1.0
## Abaixo de 1,0 o aviso encurta. **O piso do `Telegrafo` continua por baixo**, e
## nao mora aqui: quem garante que o aviso nao SOME e `Telegrafo.duracao_segura`,
## aplicado por `InimigoBase.duracao_do_telegrafo()`. Telegrafo que some e a
## fronteira entre "dificil" e "mente sobre a propria regra".
@export var multiplicador_telegrafo: float = 1.0

@export_group("Regeneradora")
## **Os campos de classe nascem em ZERO, e isso nao e detalhe.**
##
## Com default util, TODO `.tres` herda o numero -- inclusive os das outras
## classes --, e um campo que so faz sentido numa classe passa a responder
## `0.02` para as tres. Nenhum comportamento quebra (o controlador decide pela
## classe), mas qualquer regua que pergunte *"esta classe cura?"* olhando o campo
## responde SIM para todas.
##
## Foi exatamente isso no laboratorio: ele passou a medir a pausa de troca de
## alvo nas tres, e a linha de base saltou de 0,50 s para 4,50 s sem nada ter
## mudado no jogo. Zero e o unico default que nao mente.
@export var espera_para_regenerar: float = 0.0
## Fracao da vida maxima curada por segundo.
@export var regeneracao_por_segundo: float = 0.0

@export_group("Blindada")
## Fracao do dano que ela NAO recebe enquanto protegida.
##
## **O plano pedia 0,25 e a medicao devolveu 0,15, e a razao e a vida ser `int`.**
## O elenco tem 5 a 8 pontos de vida, entao o efeito da reducao so existe em
## degraus de UM ACERTO:
##
##     reducao   acertos num inimigo de 5      TTK
##       0%              5                     --
##      15-17%           6                    +20%
##      18-25%           7                    +40%
##
## Nao ha nada entre 6 e 7. Com 0,25 as duas especies de 5 de vida saem em +40%,
## acima do teto de 35% que separa "decisao" de "esponja de dano" -- e o teto e a
## regra do epico, nao um enfeite. 0,15 poe as cinco na faixa: +20%, +25% e +33%.
##
## Se a vida do elenco subir, este numero pode voltar a 0,25 sem mudar nada mais.
@export var reducao_de_dano: float = 0.0
@export var tempo_protegida: float = 0.0
@export var tempo_vulneravel: float = 0.0
## Dano EXTRA recebido na janela vulneravel. E o que transforma "esperar" numa
## jogada em vez de uma pausa.
@export var dano_extra_vulneravel: float = 0.0

@export_group("Sobrecarregada")
## Amplitude do pulso de faiscas, em fracao. Ele e IRREGULAR de proposito: um
## pulso regular le como barra de recarga, e esta classe nao promete janela.
@export var irregularidade_do_pulso: float = 0.0

@export_group("Visual")
## A cor da aura. Ela e o ultimo canal de leitura e nao o primeiro -- quem separa
## as tres classes e o MOVIMENTO da arte (convergir, orbitar, escapar), porque o
## jogo e escuro e matiz e a primeira coisa que se perde.
##
## Menos saturada que projetil, sempre: `teste_texturas.gd` ja guarda essa
## fronteira para o cenario, e a razao e a mesma aqui.
@export var cor: Color = Color(0.35, 0.95, 0.70)

@export_group("Compatibilidade")
## Tags que o inimigo PRECISA ter, e tags que o impedem.
##
## **Nenhuma classe do MVP usa nenhuma das duas, e elas existem assim mesmo.** Um
## campo que existe no `.tres` e nao e lido pelo codigo e um campo que MENTE:
## quem o preencher nao recebe erro, e o aprimoramento nasce onde nao devia sem
## uma linha no console. `teste_aprimoramento.gd` prova que os dois sao LIDOS.
@export var tags_exigidas: Array[DadosInimigo.Tag] = []
@export var tags_incompativeis: Array[DadosInimigo.Tag] = []
## Outras classes que nao convivem com esta. Vazio no MVP, porque
## `max_aprimoramentos` e 1 -- mas o campo entra agora pela mesma razao acima.
@export var aprimoramentos_incompativeis: Array[StringName] = []
@export var max_por_sala: int = 1


## Se esta classe pode nascer neste inimigo.
##
## A ausencia de `DadosInimigo` NAO desqualifica: Rastejante, Vigia e Diretora
## nao tem `.tres`, e `dados` e opcional de proposito. Sem tags, o inimigo passa
## em qualquer regra que nao EXIJA uma -- o que mantem os tres elegiveis para as
## tres classes do MVP, que nao exigem nada.
func cabe_em(dados_do_inimigo: DadosInimigo) -> bool:
	if tags_exigidas.is_empty() and tags_incompativeis.is_empty():
		return true
	if dados_do_inimigo == null:
		return tags_exigidas.is_empty()
	for tag in tags_exigidas:
		if not dados_do_inimigo.tem_tag(tag):
			return false
	for tag in tags_incompativeis:
		if dados_do_inimigo.tem_tag(tag):
			return false
	return true
