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
@export var velocidade_projetil: float = 900.0
@export var alcance: float = 900.0
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
