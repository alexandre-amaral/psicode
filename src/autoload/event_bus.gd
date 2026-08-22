extends Node
## Barramento global de eventos.
##
## Regra do projeto: nenhum sistema procura outro pela arvore de nos.
## Quem acontece emite aqui, quem se importa escuta aqui.
## Isso evita que a HUD conheca o Player, que o Player conheca o WaveManager, etc.

# --- Player ---
signal player_pronto(player: Node2D)
signal player_dano_recebido(vida_atual: int, vida_max: int)
signal player_curado(vida_atual: int, vida_max: int)
signal player_morreu()
signal player_rolou()

# --- Armas ---
signal arma_equipada(dados: Resource, slot: int)
signal municao_mudou(atual: int, maximo: int)

# --- Inimigos ---
signal inimigo_morreu(posicao: Vector2, creditos: int)
signal inimigo_spawnou(inimigo: Node2D)

# --- Ondas ---
signal onda_iniciada(indice: int, total: int)
## O texto do anuncio viaja junto do evento: assim a HUD nunca precisa
## procurar o gerenciador de ondas na arvore para descobrir o titulo.
signal onda_anunciada(titulo: String, subtitulo: String)
signal onda_limpa(indice: int)
signal contagem_inimigos_mudou(vivos: int)

# --- Deterioracao ---
signal deterioracao_mudou(valor: float, fase: int)
signal fase_deterioracao_mudou(fase_nova: int, fase_antiga: int)

# --- Chefe ---
signal boss_revelado(nome: String, vida_max: int)
signal boss_vida_mudou(atual: int, maximo: int)
signal boss_fase_mudou(fase: int)
signal boss_morreu()

# --- Run ---
signal run_terminada(venceu: bool, estatisticas: Dictionary)

# --- Mapa e Salas ---
## Emitido pela porta atravessada, com a sala de origem e o lado por onde
## o jogador saiu. Quem monta o mapa decide para onde isso leva.
signal porta_atravessada(sala: Node2D, direcao: Vector2)
signal sala_entrada(sala: Node2D)
signal sala_limpa(sala: Node2D)
signal transicao_iniciada(direcao: Vector2, sala_nova: Node2D)
signal transicao_concluida(sala_nova: Node2D)

# --- Game feel (pedidos, nao comandos) ---
signal pedido_shake(intensidade: float, duracao: float)
signal pedido_hitstop(duracao: float, escala: float)
