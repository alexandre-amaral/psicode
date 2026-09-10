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
## O jogador ALTERNOU entre as duas armas que carrega. Existe separado de
## `arma_equipada` porque este e o unico dos quatro momentos em que a arma que
## SAIU continua com o jogador -- quem anima a troca (a HUD desliza uma sobre a
## outra) precisa das duas pontas, e `arma_equipada` so carrega a que chegou.
signal arma_trocada(saiu: Resource, entrou: Resource, slot: int)
## Uma arma foi trocada por outra num slot cheio. `saiu` deixa de ser carregada
## e vira pickup no chao; quem a larga e quem escutou.
signal arma_substituida(saiu: Resource, entrou: Resource, slot: int)
## Uma arma deixou o inventario e foi parar no chao, na posicao dada. Separado
## de `arma_substituida` porque a Loja tambem larga arma no chao, e ali a
## posicao nao e a do jogador e sim a da bancada.
signal arma_descartada(dados: Resource, posicao: Vector2)
## (balas no pente, reserva). Reserva -1 = infinita.
signal municao_mudou(no_pente: int, reserva: int)
signal recarga_iniciada(duracao: float)
signal recarga_concluida()

# --- Inimigos ---
## Dano ENTREGUE a um inimigo, para quem conta estatistica de run.
##
## Existe para o `RegistroRun` nao precisar perguntar nada ao inimigo, e para o
## inimigo nao precisar conhecer o save. E a regra 1 do projeto aplicada a
## persistencia: quem faz algo emite, quem se importa escuta.
##
## Sem ele, a alternativa seria `inimigo_base.gd` incrementando um contador do
## perfil -- e ai a arma faria o mesmo, e a sala tambem, e a persistencia
## estaria espalhada por dez arquivos que nao tem nada a ver com ela.
signal dano_a_inimigo(quantidade: int)
signal inimigo_morreu(posicao: Vector2, creditos: int)
## O saldo da run mudou. `delta` vem junto para o feedback de coleta (`+5`) nao
## ter de guardar o saldo anterior -- e guardar estado para calcular uma
## diferenca e como duas copias comecam a divergir.
signal creditos_mudaram(saldo: int, delta: int)

## Uma ficha foi coletada. A HUD usa para o `+5` flutuante e o `Audio` para o
## som -- nenhum dos dois precisa conhecer o pickup.
signal credito_coletado(posicao: Vector2, valor: int)

## A compra fechou, ou foi recusada. A recusa e um sinal proprio e nao um
## `concluida` com bandeira: quem escuta uma quase nunca escuta a outra -- o som
## de erro e a HUD de saldo nao tem nada em comum.
signal compra_concluida(oferta: RefCounted)
signal compra_recusada(oferta: RefCounted)

signal inimigo_spawnou(inimigo: Node2D)

## Uma Unidade Aprimorada curou. Quem escuta e o laboratorio e as metricas -- o
## jogo nao precisa saber, porque a leitura ja esta na aura.
signal inimigo_regenerou(inimigo: Node2D, pontos: int)

## Uma Unidade Aprimorada trocou de estado de ciclo (a Blindada abrindo ou
## fechando). O som da classe pendura aqui, e nao dentro do controlador: quem
## toca o que e do `Audio`, e ele ja escuta o EventBus.
signal aprimorado_mudou_de_estado(inimigo: Node2D, protegido: bool)

## Uma Unidade Aprimorada nasceu. E por aqui que as metricas da run contam sem
## que a sala precise avisar ninguem.
signal aprimorado_nasceu(inimigo: Node2D, classe_id: StringName)

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
## O chefe anuncia o que leu do jogador. Existe porque a Predicao Comportamental
## tem duas metades: a correcao que ela aplica e o AVISO de que aplicou. Sem o
## aviso o jogador so sente que "o chefe ficou mais certeiro", e o duelo que a
## ficcao dela promete nunca chega a acontecer -- nao da para quebrar um padrao
## que voce nao sabe que foi lido.
signal boss_leitura(rotulo: String, confianca: int)

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
## O jogador SAIU da area de uma porta, e `para_fora` diz por qual lado.
##
## Ele avisa na SAIDA e nao na entrada, e isso e a correcao de um bug que se
## sentia jogando: a area da porta tem 32 px de profundidade, e quem entrava nela
## e recuava sem cruzar deixava a travessia ligada para sempre. A camera ficava no
## enquadramento largo -- meio numa sala, meio na outra -- e a proxima tentativa
## de sair era consumida como "desistiu". Roçar o batente desviando de um tiro
## bastava.
##
## Entrar nao quer dizer nada: o que decide e por qual lado se SAI.
signal porta_atravessada(sala: Node2D, direcao: Vector2, para_fora: bool)
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
