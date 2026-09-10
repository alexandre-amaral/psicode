class_name DadosItem
extends Resource
## Um implante: o upgrade passivo que vale ate o fim da run.
##
## A decisao de design daqui: o efeito e DADO, nao codigo. Quem sofre o efeito
## consulta o autoload Modificadores no frame em que precisa, e nada no jogo
## guarda um numero ja multiplicado.
##
## Um implante tem DUAS partes, e vale entender a diferenca antes de criar um:
##
## 1. **efeitos** -- uma lista de EfeitoItem. E aqui que moram os numeros, e e
##    puramente declarativo. Implante numerico novo (mesmo com varios efeitos,
##    mesmo condicional) custa so um .tres.
##
## 2. **comportamento** -- um enum. Cobre o que numero nenhum expressa:
##    ricochetear, dividir o projetil, curar por abate. Cada comportamento e
##    lido por um sistema diferente do jogo (projetil, arma, autoload), entao
##    um comportamento novo custa codigo. Esse e o limite honesto desta
##    abordagem, e nao adianta fingir que nao existe.
##
## Para criar um implante: clique direito em src/items > Novo Recurso >
## DadosItem, salve como implante_<nome>.tres, monte a lista de efeitos, e
## adicione ao pool de loot (src/items/pool_padrao.tres).

## O que o implante faz alem de mexer em numero.
##
## O `parametro` significa uma coisa diferente em cada um -- a doc de cada
## valor diz qual.
enum Comportamento {
	## So os efeitos numericos valem.
	NENHUM,
	## parametro = chance (0..1) de o projetil quicar na parede.
	RICOCHETE,
	## parametro = chance (0..1) de o projetil se dividir ao acertar.
	FRAGMENTAR,
	## parametro = chance (0..1) de curar 1 ao matar.
	VAMPIRISMO,
	## parametro = quantos abates ate curar 1.
	NANOBOTS,
	## parametro = fracao de vida abaixo da qual os efeitos VIDA_BAIXA ligam.
	SOBRECARGA,
	## parametro = quantos tiros depois da recarga contam como "de eco".
	ECO,
	## parametro = multiplicador de dano no alvo marcado.
	MARCADOR,
	## parametro = teto de cargas.
	CARGAS_SEM_DANO,
}

@export var nome: String = "Implante"
@export_multiline var descricao: String = ""

@export_group("Efeito")
@export var efeitos: Array[EfeitoItem] = []
@export var comportamento: Comportamento = Comportamento.NENHUM
@export var parametro: float = 0.0
## Quantas vezes o mesmo implante pode acumular numa run. 0 = sem limite.
@export var maximo_por_run: int = 0

## Em que regiao do corpo este implante estaria instalado.
##
## **ELE ESTA DORMENTE, e a dormencia e declarada.** A primeira aba de itens
## desenhava uma silhueta tecnica com os implantes pendurados por regiao; a
## ideia foi reprovada e a aba virou uma grade, que **nao le este campo**.
##
## Ele ficou por duas razoes. A primeira: e a semente daquela ideia, e refazer
## as dezesseis escolhas no dia em que ela voltar e o mesmo trabalho feito duas
## vezes. A segunda: campo dormente que ninguem confere apodrece em silencio --
## por isso `teste_inventario.gd` continua cobrando os dois lados (todo `.tres`
## esta na tabela, e a tabela concorda com o `.tres`), pelo mesmo motivo que a
## suite da Diretora continua no runner com ela engavetada.
##
## **E se ele voltar a ser desenhado, ele continua sem LIMITAR nada.** O risco
## obvio de um inventario corporal e virar equipamento por localizacao -- um
## slot neural, um de braco, um de torso -- e passar a RECUSAR implante. Isso
## mudaria o sistema de builds inteiro: hoje os implantes sao acumulativos,
## `Modificadores` os soma sem teto por regiao, e as 16 pecas foram balanceadas
## assim.
##
## **Valor novo entra NO FIM.** Enum e gravado como INT no `.tres`: inserir no
## meio reescreve em silencio a regiao de todo implante ja salvo. Mesma
## armadilha de `DadosArma.Comportamento`.
##
## E o valor ZERO e o neutro (`SISTEMA`) de proposito. Um implante que nascesse
## sem declarar categoria diria "eu sou neural" se `NEURAL` fosse o primeiro --
## afirmando uma regiao que ninguem escolheu.
enum CategoriaCorporal {
	## Sistemas internos, sem regiao propria. O default: um implante que nao se
	## encaixa em lugar nenhum aparece aqui em vez de mentir sobre onde esta.
	SISTEMA,
	## Cabeca: processamento, mira assistida, defesa cognitiva.
	NEURAL,
	## Cabeca: leitura do ambiente, deteccao, alcance de percepcao.
	SENSORIAL,
	## Torso: vida, energia, o que sustenta o corpo.
	NUCLEO,
	## Bracos: o que toca a arma -- dano, municao, cadencia.
	BRACOS,
	## Pernas: velocidade, rolamento, o que move o corpo.
	MOBILIDADE,
}

@export_group("Apresentacao")
## Em que regiao do corpo esta peca aparece na tela de inventario.
@export var categoria_corporal: CategoriaCorporal = CategoriaCorporal.SISTEMA
@export var cor: Color = Color("7cf7c4")
## Marca curta desenhada no pickup e na lista da HUD.
##
## Ela NAO sai com a chegada do `icone`: e o fallback DECLARADO. Enquanto um
## implante nao tiver arte, o pickup e a HUD continuam desenhando o losango de
## `cor` com esta letra dentro -- que e o que o jogo faz hoje, e o que permite a
## integracao entrar antes da arte existir.
@export var sigla: String = "+"
## O icone de 64x64 desenhado no lugar do losango de `cor` + `sigla`.
##
## **OPCIONAL, e tem de continuar sendo.** Sem icone valem `cor` e `sigla`, pela
## mesma razao que `DadosInimigo` e opcional no `InimigoBase` e o Rastejante
## segue funcionando sem `.tres` nenhum: torna-lo obrigatorio quebraria todo
## consumidor no dia em que um implante nascer antes da arte dele.
##
## Quem garante que a ausencia nao passa em SILENCIO nao e este campo, e sim o
## portao `tools/testes/teste_icones_de_item.gd` -- a lista `SEM_ICONE_AINDA`
## dele e a divida declarada, e ela morde dos dois lados.
@export var icone: Texture2D


## Loop explicito em vez de filter(): Array.filter() devolve Array sem tipo e a
## atribuicao de volta a um Array tipado estoura em runtime.
func efeitos_validos() -> Array[EfeitoItem]:
	var lista: Array[EfeitoItem] = []
	for efeito in efeitos:
		if efeito != null:
			lista.append(efeito)
	return lista


## Implante que nao mexe em numero nenhum nem tem comportamento e um .tres
## esquecido pela metade -- o defeito mais provavel deste sistema, e invisivel
## em runtime. A suite de teste usa isto para recusar.
func faz_alguma_coisa() -> bool:
	return comportamento != Comportamento.NENHUM or not efeitos_validos().is_empty()


func tem_comportamento() -> bool:
	return comportamento != Comportamento.NENHUM

@export_group("Economia")
## Quanto este conteudo custa na Loja. Zero = nao aparece a venda.
##
## **O preco sai do IMPACTO na run, e nao da raridade estetica.** Uma arma comum
## que resolve o andar inteiro custa mais que uma rara e situacional -- e a
## raridade ja tem o proprio botao no sorteio de loot.
##
## Os numeros de hoje sao PONTO DE PARTIDA e nao valores finais: a renda do andar
## foi medida em 173 creditos numa run completa, contra os 35-55 que o plano da
## Loja assume. A calibragem e da simulacao economica (#284), e ela decide entre
## baixar a renda e subir os precos -- nao adianta girar um dos dois por gosto.
@export var valor_de_loja: int = 0
