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
## Arma nova entrou na mao do jogador pela PRIMEIRA vez, por loot. Existe
## separado de arma_equipada porque aquele dispara em quatro momentos -- inicio
## de run, loot, troca com Q e volta ao slot 0 -- e quem quer apresentar a arma
## ao jogador so tem interesse no segundo. Pendurar a apresentacao em
## arma_equipada mostrava a pistola inicial toda run e a cada tecla Q.
signal arma_adquirida(dados: Resource)
## (balas no pente, reserva). Reserva -1 = infinita.
signal municao_mudou(no_pente: int, reserva: int)
signal recarga_iniciada(duracao: float)
signal recarga_concluida()

# --- Inimigos ---
signal inimigo_morreu(posicao: Vector2, creditos: int)
signal inimigo_spawnou(inimigo: Node2D)

# --- Combate na sala ---
## Quantos inimigos ainda respiram na sala em que o jogador esta. Emitido pela
## propria Sala, que e quem os colocou. Os tres sinais de onda que viviam aqui
## sairam junto com o sistema de ondas: a composicao passou a ser escolhida na
## montagem do andar, e nao existe mais um indice de onda para anunciar.
signal contagem_inimigos_mudou(vivos: int)

# --- Deterioracao ---
signal deterioracao_mudou(valor: float, fase: int)
signal fase_deterioracao_mudou(fase_nova: int, fase_antiga: int)

# --- Chefe ---
signal boss_revelado(nome: String, vida_max: int)
signal boss_vida_mudou(atual: int, maximo: int)
signal boss_fase_mudou(fase: int)
signal boss_morreu()

# --- Itens ---
## O implante ja foi aplicado quando isto chega: quem escuta le o efeito ja
## somado em Modificadores, nao aplica nada por conta propria.
signal item_coletado(dados: Resource)
## O implante NAO foi aplicado: ja estava no maximo_por_run. O pickup fica no
## chao de proposito, e sem este sinal o jogador andava por cima dele e nao
## acontecia nada -- nem o item, nem uma explicacao de por que nao.
signal item_recusado(dados: Resource)
## Qualquer mudanca no conjunto de implantes, coleta ou reset de run. Existe
## separado de item_coletado porque a HUD precisa redesenhar tambem quando a
## run recomeca e a lista esvazia.
signal modificadores_mudaram()

# --- Run ---
signal run_terminada(venceu: bool, estatisticas: Dictionary)

# --- Mapa e Salas ---
## Emitido pela porta atravessada, com a sala de origem e o lado por onde
## o jogador saiu. Quem monta o mapa decide para onde isso leva.
## O andar terminou de ser montado e ja da para consultar o GerenciadorMapa.
## Existe porque a HUD sobe antes do mapa em main.tscn: sem este aviso, o
## minimapa faria _ready com o grupo 'gerenciador_mapa' ainda vazio.
signal andar_gerado()
signal porta_atravessada(sala: Node2D, direcao: Vector2)
signal sala_entrada(sala: Node2D)
signal sala_limpa(sala: Node2D)
signal transicao_iniciada(direcao: Vector2, sala_nova: Node2D)
signal transicao_concluida(sala_nova: Node2D)

# --- Configuracao ---
## O jogador mudou uma preferencia. Quem executa a preferencia le do autoload
## Configuracao -- este sinal so avisa que e hora de reler.
signal configuracao_mudou()

# --- Game feel (pedidos, nao comandos) ---
signal pedido_shake(intensidade: float, duracao: float)
signal pedido_hitstop(duracao: float, escala: float)
## Implante que cura (Nanobots, Vampirico) pede por aqui em vez de procurar o
## Player na arvore. Quem tem vida decide o que fazer com o pedido.
signal pedido_cura(quantidade: int)
