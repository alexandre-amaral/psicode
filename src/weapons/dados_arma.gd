class_name DadosArma
extends Resource
## Uma arma e so um punhado de numeros. Guardar isso num Resource (.tres)
## em vez de dentro do codigo significa que da para criar e balancear armas
## novas pelo Inspetor do Godot, sem escrever uma linha de GDScript.
##
## Para criar uma arma: clique direito em src/weapons > Novo Recurso >
## DadosArma, salve como .tres, ajuste os campos.

## O que a arma faz ALEM de cuspir um projetil reto.
##
## Mesmo molde de DadosItem.Comportamento, e pelo mesmo motivo: os numeros da
## arma sao declarativos e cabem num .tres, mas ricochetear, explodir ou
## perseguir e comportamento -- e comportamento custa codigo em quem sofre o
## efeito. O enum e a costura entre as duas metades.
##
## **Valor novo entra sempre NO FIM.** O enum e gravado como INT no .tres
## (`comportamento = 3`); inserir no meio reescreve em silencio o significado de
## toda arma ja salva. E a mesma armadilha que o GEMINI.md registra para
## DadosItem.
enum Comportamento {
	## Projetil reto. E o que todas as armas foram ate agora.
	NENHUM,
	## Atravessa parede. `alcance` continua limitando, porque ele vira TEMPO de
	## voo -- entao o projetil nao cruza o andar inteiro.
	FANTASMA,
	## Empurra muito e machuca pouco: o dano esta no `knockback`, nao no `dano`.
	GRAVIDADE,
	## Para no impacto, espera `fuse` e explode em area.
	EXPLOSIVO,
	## Explode ao bater na PAREDE, orientado pela normal da superficie.
	PLASMA,
	## Curva atras do inimigo mais proximo, com teto de graus por segundo.
	TELEGUIADO,
	## Salta entre inimigos proximos, sem repetir alvo.
	CORRENTE,
	## Acumula cargas no alvo; ao encher, consome e detona.
	NANITE,
	## Feixe continuo enquanto o gatilho estiver pressionado. Nao instancia
	## projetil nenhum.
	FEIXE,
}

@export var nome: String = "Arma"
@export_multiline var descricao: String = ""

@export_group("Comportamento")
@export var comportamento: Comportamento = Comportamento.NENHUM

@export_group("Dano")
## Dano por projetil. A shotgun compensa dano baixo com muitos projeteis.
@export var dano: int = 1
@export var knockback: float = 120.0
## Quantos inimigos o projetil atravessa antes de sumir. 0 = para no primeiro.
@export var perfuracao: int = 0

@export_group("Cadencia")
## Tiros por segundo.
@export var cadencia: float = 6.0
## Se falso, precisa clicar a cada tiro.
@export var automatica: bool = true

@export_group("Projetil")
@export var projeteis_por_tiro: int = 1
## Quantos projeteis A MAIS o tiro pode soltar, sorteado a cada disparo.
##
## Zero deixa a contagem fixa, que e como todas as armas antigas se comportam.
## A Riot-12 usa 2 para variar entre 8 e 10 por rajada: contagem fixa faz cada
## disparo de escopeta parecer igual ao anterior, e o que se quer da escopeta e
## justamente nao saber quanto vai sair.
@export var projeteis_extra: int = 0
## Abertura total do leque, em graus. Zero = tiro reto.
@export var abertura_graus: float = 0.0
## Espalhamento aleatorio adicional aplicado a cada projetil, em graus.
@export var impressao_graus: float = 1.5

## Dispersao que CRESCE enquanto se segura o gatilho e volta sozinha ao parar.
##
## Os tres nascem em zero, e isso importa: `_emitir()` e o mesmo caminho do
## jogador e dos inimigos, entao um default acima de zero daria bloom para a
## salva da Diretora sem ninguem ter pedido. Arma sem bloom continua se
## comportando exatamente como antes destes campos existirem.
##
## Teto do que o bloom pode somar a `impressao_graus`. Zero = arma sem bloom.
@export var dispersao_maxima_graus: float = 0.0
## Quanto cada TIRO soma. Um tiro soma uma vez, mesmo que solte oito projeteis.
@export var dispersao_por_tiro: float = 0.0
## Quantos graus voltam por segundo quando o gatilho descansa.
@export var dispersao_recuperacao: float = 0.0
@export var velocidade_projetil: float = 900.0
@export var alcance: float = 544.0
@export var raio_projetil: float = 4.0
@export var cor_projetil: Color = Color("6ee7ff")

@export_group("Explosao")
## Valem para EXPLOSIVO (a granada) e PLASMA (o estouro na parede). Sao quatro
## numeros separados de proposito, e nao um "poder de explosao": assim um item
## pode mexer no RAIO sem mexer no dano, ou no knockback sem mexer em nenhum dos
## dois. Foi o pedido explicito de quem desenhou as armas.
@export var raio_explosao: float = 90.0
@export var dano_explosao: int = 4
@export var knockback_explosao: float = 260.0
## Quanto a granada espera parada antes de estourar. Zero explode no impacto,
## que e como o PLASMA se comporta.
@export var fuse: float = 0.6

@export_group("Teleguiado")
## Ate onde a Swarm ENXERGA. Fora deste raio ela voa reto, e e o que a impede de
## virar uma arma que acerta sozinha do outro lado do andar.
@export var raio_busca: float = 260.0
## Teto de curva, em graus por segundo. E o unico botao que separa "teleguiado
## justo" de "teleguiado que nunca erra": com curva infinita o projetil gruda no
## alvo e o inimigo perde a chance de se desviar. Baixo demais e ele voa reto.
@export var curva_graus: float = 260.0

@export_group("Corrente")
## Quantos PULOS depois do alvo original. Zero desliga a corrente.
@export var saltos_corrente: int = 0
## Ate onde cada pulo procura o proximo corpo.
@export var raio_corrente: float = 130.0
## Quanto do dano sobra a cada pulo. Sem decaimento a corrente vira dano em area
## disfarcado, e a arma deixaria de recompensar quem atira na aglomeracao certa.
@export var decaimento_corrente: float = 0.6

@export_group("Nanite")
## Quantas doses o alvo aguenta antes de estourar. Ao contrario do Hack -- que
## RENOVA o tempo -- o nanite EMPILHA: e a diferenca entre um efeito que so
## marca e um efeito que recompensa insistir no mesmo alvo.
@export var stacks_nanite: int = 0
## Quanto tempo uma dose dura sem reforco. Passou disso, o acumulo zera inteiro:
## sem essa janela bastaria acertar o mesmo inimigo uma vez por sala.
@export var duracao_nanite: float = 4.0

@export_group("Feixe")
## Dano por SEGUNDO do feixe continuo, e nao por tiro: o Laser nao dispara, ele
## fica ligado. `dano` continua existindo para os testes e para os implantes,
## mas quem manda no feixe e este numero.
@export var dano_por_segundo: float = 14.0
## Largura do risco na tela. So visual -- o acerto sai de um raycast.
@export var largura_feixe: float = 5.0

@export_group("Municao")
## Quantos tiros cabem no pente antes de precisar recarregar. Zero nao existe:
## uma arma com pente vazio nunca poderia atirar.
@export var tamanho_pente: int = 12
## Quanto tempo a recarga leva. Enquanto ela roda, a arma nao dispara -- e essa
## janela que da ritmo ao combate e que a Celula de Eco recompensa.
@export var tempo_recarga: float = 1.1
## RESERVA, nao o pente. -1 = infinita: a pistola do GDD nunca fica sem balas,
## so pausa para recarregar. Reserva finita e o que faz uma arma de loot ser
## descartada quando acaba.
@export var municao_maxima: int = -1

@export_group("Feedback")
@export var shake_intensidade: float = 2.0
@export var shake_duracao: float = 0.08
## Empurrao no proprio jogador ao atirar. Da peso a shotgun.
@export var recuo_player: float = 0.0


## Reserva infinita. O nome ficou de quando `municao_maxima` era a municao
## inteira da arma; hoje ele so fala da reserva.
func municao_infinita() -> bool:
	return municao_maxima < 0


## Pente utilizavel. Protege de um zero digitado num .tres: pente zero travaria
## a arma para sempre, sem erro nenhum no console.
func pente() -> int:
	return maxi(tamanho_pente, 1)


func intervalo() -> float:
	return 1.0 / maxf(cadencia, 0.01)


## Quantos projeteis ESTE disparo solta. Sorteia dentro da faixa quando a arma
## declara variacao; do contrario devolve o numero fixo.
func sortear_projeteis() -> int:
	var base := maxi(projeteis_por_tiro, 1)
	if projeteis_extra <= 0:
		return base
	return base + randi_range(0, projeteis_extra)


## Se a arma dispensa o projetil comum. Hoje so o FEIXE -- e e por isso que ele
## e o unico que precisa de um caminho proprio em Arma.
func e_feixe() -> bool:
	return comportamento == Comportamento.FEIXE


## Se o projetil desta arma termina em explosao de area.
func explode() -> bool:
	return comportamento == Comportamento.EXPLOSIVO or comportamento == Comportamento.PLASMA


## Se o projetil desta arma curva atras do alvo.
func e_teleguiado() -> bool:
	return comportamento == Comportamento.TELEGUIADO


## Se o acerto salta para os vizinhos. Exige salto configurado: comportamento
## CORRENTE com `saltos_corrente` zero seria uma arma comum que se anuncia como
## corrente, e o teste de contrato recusa.
func encadeia() -> bool:
	return comportamento == Comportamento.CORRENTE and saltos_corrente > 0


## Se o acerto deposita doses que estouram ao acumular.
func semeia_nanite() -> bool:
	return comportamento == Comportamento.NANITE and stacks_nanite > 0


# ------------------------------------------------------- perfil da arma ------
# As quatro barras da tela de selecao. Elas medem a ARMA, e nao a personagem:
# RAVEN e NOVA tem vida, velocidade e rolamento identicos de proposito, entao
# barras de VIDA/DEFESA/AGILIDADE seriam quatro reguas dizendo "empate" -- ou,
# pior, quatro numeros inventados. O que de fato separa as duas e o que sai do
# cano, e e isso que estas funcoes leem.
#
# Os tetos abaixo sao a REGUA, nao o dado: dizem o que conta como "cheio" nesta
# escala de jogo. Arma nova que passe de um deles satura a barra em vez de
# quebrar o desenho.

## Dano de um disparo inteiro. A shotgun solta 8 projeteis de 2 e satura aqui.
const DANO_CHEIO := 8.0
const CADENCIA_CHEIA := 14.0
## Espalhamento total (impressao + o teto do bloom) que conta como pontaria zero.
const DISPERSAO_CHEIA := 10.0
const ALCANCE_CHEIO := 1000.0


## Dano por disparo, nao por projetil: quem aperta o gatilho uma vez sente o
## leque inteiro da shotgun, nao um chumbinho.
func perfil_dano() -> float:
	return clampf(float(dano * maxi(projeteis_por_tiro, 1)) / DANO_CHEIO, 0.0, 1.0)


func perfil_cadencia() -> float:
	return clampf(cadencia / CADENCIA_CHEIA, 0.0, 1.0)


## Invertido: quanto MAIOR o espalhamento, menor a barra. Soma o bloom porque
## uma SMG que abre 7 graus segurando o gatilho nao e precisa, ainda que o
## primeiro tiro seja.
func perfil_precisao() -> float:
	var espalhamento := impressao_graus + dispersao_maxima_graus
	return clampf(1.0 - espalhamento / DISPERSAO_CHEIA, 0.0, 1.0)


func perfil_alcance() -> float:
	return clampf(alcance / ALCANCE_CHEIO, 0.0, 1.0)


## Se esta arma tem dispersao crescente. Um teto de zero desliga o mecanismo
## inteiro -- e como as cinco armas antigas continuam intactas.
func tem_bloom() -> bool:
	return dispersao_maxima_graus > 0.0


## O bloom depois de mais um tiro, saturado no teto.
##
## Existe como funcao pura, e nao como duas linhas dentro de Arma, porque o
## estado do bloom vive num _process que nao roda nos testes sincronos de
## teste_arma.gd. Aqui a conta e conferivel sem subir cena nenhuma -- e o
## projeto ja prefere assim (intervalo() e testado do mesmo jeito).
func dispersao_apos_tiro(atual: float) -> float:
	if not tem_bloom():
		return 0.0
	return minf(atual + dispersao_por_tiro, dispersao_maxima_graus)


## O bloom depois de `delta` segundos sem atirar. Nunca desce de zero.
func dispersao_apos(atual: float, delta: float) -> float:
	if not tem_bloom():
		return 0.0
	return maxf(atual - dispersao_recuperacao * delta, 0.0)
