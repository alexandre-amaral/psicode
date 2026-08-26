class_name DadosArma
extends Resource
## Uma arma e so um punhado de numeros. Guardar isso num Resource (.tres)
## em vez de dentro do codigo significa que da para criar e balancear armas
## novas pelo Inspetor do Godot, sem escrever uma linha de GDScript.
##
## Para criar uma arma: clique direito em src/weapons > Novo Recurso >
## DadosArma, salve como .tres, ajuste os campos.

@export var nome: String = "Arma"
@export_multiline var descricao: String = ""

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
