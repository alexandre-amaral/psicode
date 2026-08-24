class_name DadosOnda
extends Resource
## Uma onda descrita como dado, nao como codigo.
## Para mudar o ritmo do vertical slice voce edita .tres no Inspetor --
## nao precisa abrir GDScript. Esse e o principal botao de balanceamento
## do projeto.

@export var titulo: String = "ONDA"
@export_multiline var subtitulo: String = ""

@export_group("Composicao")
@export var rastejantes: int = 3
@export var vigias: int = 0
## Se verdadeiro, ignora a composicao acima e invoca a IA Diretora.
@export var eh_chefe: bool = false

@export_group("Ritmo")
## Intervalo entre os spawns dentro da mesma onda. Zero = todos de uma vez.
@export var intervalo_spawn: float = 0.35
## Pausa depois que a onda e limpa, antes da proxima comecar.
@export var respiro: float = 2.6

@export_group("Deterioracao")
## Quanto a barra sobe ao LIMPAR esta onda. E aqui que a escalada acontece.
@export var deterioracao_ao_limpar: float = 14.0
## Valor minimo forcado ao INICIAR a onda. Use -1 para nao forcar.
## Serve para garantir que a onda do chefe comece em nivel critico.
@export var deterioracao_minima_inicial: float = -1.0
