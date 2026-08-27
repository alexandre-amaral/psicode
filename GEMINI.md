# psicode — contexto para agente de IA

Twin-stick shooter / bullet hell / roguelike cyberpunk em **Godot 4.7.2-stable**
(versao standard, nao .NET) com **GDScript**. Renderer **Compatibility (GL)**,
obrigatorio para o export web.

Feito por tres pessoas. O objetivo era **diversao e aprender fazendo** -- ter
algo jogavel rapido valia mais que infraestrutura bonita. **Isso mudou: o alvo
agora e lancamento comercial** (ver `docs/ROADMAP.md`). O principio de trabalho
continua o mesmo, mas duas coisas passam a pesar mais que antes: acabamento
(som, gamepad, salvamento) e escopo alem de um andar. Duas das tres pessoas
continuam sem conhecer Godot nem Git, e isso segue valendo para tudo que elas
precisem executar.

> O titulo antigo era "Ciberpsicose". O nome fechado e **psicode**.

## Onde esta a verdade

Este arquivo diz como trabalhar no repositorio. O que o jogo **e** esta nos
documentos abaixo — leia antes de propor mecanica nova:

| Documento | Para que |
|---|---|
| `docs/GDD.md` | Design: core loop, Deterioracao, mira preditiva, o chefe, escopo |
| `docs/ROADMAP.md` | Onde o jogo esta hoje, em numeros, e os marcos do que falta |
| `docs/CONVENCOES.md` | Git, divisao de arquivos, estilo de codigo |
| `docs/HANDOFF.md` | Passo a passo para quem nao conhece Godot nem Git |
| `docs/BUILD.md` | Export Windows e web |
| `docs/TUNING.md` | Todos os botoes de balanceamento e o que a medicao ja disse |
| `docs/PLAYTEST.md` | As perguntas do playtest e a mensagem pronta |
| `docs/MCP.md` | Servidor MCP que liga assistente de IA ao editor aberto |
| `docs/IDENTIDADE_VISUAL.md` | Identidade visual: as tres paletas, a grade, as regras de leitura de combate e como adicionar textura nova |
| `docs/TEXTURAS_ANDAR_1.md` | A referencia `bg_menu.jpg` medida e virada receita: a paleta do andar 1, prop contra decalque, e o que copiar dela e o que nao |

Quando o codigo e o texto discordarem, **o codigo ganha e o texto se
atualiza**. Se um pedido contradiz o GDD — genero, camera, mecanica central —
aponte a divergencia antes de implementar, em vez de so seguir o pedido.

## As duas regras que sustentam o projeto

**1. Comunicacao por `EventBus`, nunca por caminho de no.**
Quem faz algo emite; quem se importa escuta. A HUD nao conhece o Player.
Unica excecao legitima: busca por grupo (`get_first_node_in_group("player")`).

```gdscript
# ruim
get_node("/root/Main/HUD").atualizar_vida(vida)
# bom
EventBus.player_dano_recebido.emit(vida, vida_maxima)
```

**2. Toda dificuldade le o autoload `Deterioracao` no frame em que precisa** —
e todo upgrade do jogador le `Modificadores` do mesmo jeito.
Nada guarda um numero ja multiplicado — e isso que faz a barra subindo afetar
inclusive os inimigos que ja estao em tela.

```gdscript
# ruim -- congela a dificuldade no spawn
velocidade = 120.0 * Deterioracao.multiplicador_velocidade()
# bom
func velocidade_atual() -> float:
    return velocidade_base * Deterioracao.multiplicador_velocidade()
```

## Estilo

- Codigo, sinais, variaveis e comentarios em **portugues**. O que o Godot impoe
  (`_ready`, `velocity`, `queue_free`) fica como e.
- `class_name PascalCase`, `var snake_case`, `const MAIUSCULA`,
  `func _privado()`, sinais no passado (`onda_limpa`).
- **Tipar sempre** que der.
- Todo script abre com um bloco `##` dizendo o que ele faz e **qual decisao de
  design ele carrega**.
- Comentar o **porque**, nunca o **que**.
- Numero que alguem vai querer ajustar sem programar vira `@export` ou
  `Resource` `.tres`.
- Preferir composicao por no e cena reutilizavel a heranca profunda de script.
- Nada de `get_node("../../Algo")`. Use `%Nome` (unique name), grupo ou
  `EventBus`.

## Estrutura real

```
src/
  autoload/    event_bus, configuracao, deterioracao, modificadores,
               game_state, juice
  player/      player, eco de rolamento
  weapons/     arma.gd, dados_arma.gd, *.tres (pistola, shotgun, armas do chefe)
  enemies/     inimigo_base, maquina_estados, area_de_perigo,
               sprite_direcional (o Sprite2D de oito rotacoes),
               rastejante, vigia, drone_aranha, sentinela_orbital,
               atirador_neon, cyber_besta, hacker_parasita, diretora (chefe),
               grupo_inimigo.gd + grupo_*.tres (quem nasce, a que custo, e a
               partir de que Deterioracao)
  projectiles/ projetil
  arena/       pickup de arma (instanciado so pela cena da sala de arma)
  mapa/        gerenciador_mapa, sala, porta, corredor, sala_*.tscn,
               dados_sala.gd + tipo_*.tres (o catalogo de tipos de sala)
  items/       efeito_item.gd + dados_item.gd, implante_*.tres,
               pool_loot.gd, pickup de item
  ui/          hud, barra_vida, barra_deterioracao, minimapa, tela_fim,
               menu_inicial, menu_pausa, menu_opcoes, selecao_personagem,
               moldura_hud (a moldura chanfrada), barra_atributo
  fx/          explosao, impacto
  util/        balistica (matematica da mira preditiva),
               direcoes (angulo -> qual dos oito quadros desenhar)
  main/        main.tscn — cena inicial
assets/shaders/  glitch.gdshader
locale/          textos.csv (gerado) -- a tabela de traducao
tools/i18n/      gerar_csv.py (a fonte da tabela)
assets/personagens/ <id>/{8 rotacoes parado, 8 fitas andar_*, miniatura}.png -- gerados
assets/inimigos/    <id>/{8 rotacoes parado, 8 fitas andar_*}.png -- mesmo gerador,
                    sem miniatura (inimigo nao tem cartao de selecao)
tools/sprites/   gerar_sprites.py (GIF -> fita PNG normalizada)
assets/texturas/ chao/parede: arte AUTORADA, preparada por tools/texturas/preparar_textura.py
                 porta e props: ainda gerados por tools/texturas/gerar_texturas.tscn
tools/           teste_fumaca, capturar, testes/ (suites unitarias),
                 texturas/ (paleta.gd + gerar_texturas: a fonte dos PNGs)
docs/
```

`.gd`, `.tscn` e `.tres` moram **juntos por dominio**, nao separados por tipo.

## Onde mexer em que

| Ajuste | Arquivo |
|---|---|
| Quantos inimigos cabem numa sala | `densidade` e `orcamento_*` em `src/mapa/tipo_*.tres` |
| Quem pode nascer, e com que peso | `src/enemies/grupo_*.tres` |
| Quanto a barra sobe ao limpar uma sala | `deterioracao_ao_limpar` em `src/mapa/tipo_*.tres` |
| Dano, cadencia, municao, spread | `src/weapons/*.tres` |
| **Arma que faz algo alem de tiro reto** | `comportamento` em `src/weapons/*.tres` (enum `DadosArma.Comportamento`) |
| **Quanto a rajada da escopeta varia** | `projeteis_extra` em `src/weapons/*.tres`; zero = contagem fixa |
| **Personagem novo** | criar `src/player/personagem_*.tres` e por na lista `personagens` do no `SelecaoPersonagem` |
| **Sprite, miniatura, escala e offset de um personagem** | grupo `Sprite` do `src/player/personagem_*.tres`; os PNGs em `assets/personagens/<id>/` |
| **Moldura chanfrada de qualquer painel** | `@export` do no com `src/ui/moldura_hud.gd` (chanfro, cor, colchetes, margem) |
| **A regua das barras do cartao de selecao** | as consts `*_CHEIO`/`*_CHEIA` em `src/weapons/dados_arma.gd` |
| **Velocidade do ciclo de caminhada** | `fps_andando` no `src/player/personagem_*.tres` |
| **Arte de animacao nova** | por o GIF em `animations/<id>/` e rodar `python tools/sprites/gerar_sprites.py` -- vale para personagem E inimigo, o que muda e a pasta de saida |
| **Sprite e rotacoes de um inimigo** | o no `Visual/Corpo` da `src/enemies/*.tscn`, com `src/enemies/sprite_direcional.gd`: as duas listas de 8 texturas, `quadros_andando`, `fps_andando`, mais `scale` e `position` do proprio no |
| **Arma inicial, Hack e texto do card de um personagem** | `src/player/personagem_*.tres` |
| Dispersao que cresce com o gatilho preso | `dispersao_*` em `src/weapons/*.tres` — zero desliga |
| Vida e velocidade dos inimigos | `@export` em `src/enemies/*.tscn` |
| Limiares de 50% e 85% | `src/autoload/deterioracao.gd` |
| Matematica de mira preditiva | `src/util/balistica.gd` |
| Chefe | `src/enemies/diretora.gd` |
| **O que o chefe le do jogador** | `src/enemies/perfil_jogador.gd` (logica pura, testada) |
| **As travas de identidade do chefe** | `tools/testes/teste_diretora.gd` + a secao no `docs/GDD.md` |
| Layout e conexao das salas | `src/mapa/gerenciador_mapa.gd`, `src/mapa/sala_*.tscn` |
| **Tipo de sala novo (loja, desafio...)** | criar `src/mapa/tipo_*.tres` e por na lista `tipos_de_sala` do `GerenciadorMapa` |
| **Estilo novo de uma sala que ja existe** | arrastar a cena para `cenas` no `tipo_*.tres` correspondente |
| **Implante novo (so numeros)** | criar `src/items/implante_*.tres` com a lista de `efeitos` e listar em `pool_padrao.tres` |
| **Implante com comportamento novo** | enum em `DadosItem.Comportamento` + o codigo que le, em quem sofre o efeito |
| Pente, tempo de recarga e reserva | `tamanho_pente`, `tempo_recarga`, `municao_maxima` em `src/weapons/*.tres` |
| **Arma que pode cair de loot** | listar o `.tres` em `src/items/pool_padrao.tres` |
| Regras de onde cada sala nasce | `@export` do `tipo_*.tres` (beco, distancia da origem, prioridade) |
| Cor e icone de uma sala no minimapa | `cor_mapa` e `icone` do `tipo_*.tres` |
| **Textura de chao, parede e props de um tipo de sala** | grupo `Visual` do `tipo_*.tres`. Chao e parede sao LISTAS: a sala sorteia a variante por `hash(coordenadas_grid)`. Os PNGs sao arte autorada passada por `tools/texturas/preparar_textura.py`; porta e props ainda saem do gerador |
| **Arte de chao ou parede que nao nasceu na paleta** | o pre-passo de `preparar_textura.py`: `--desvinheta` (chapa a iluminacao), `--tingir GRAUS` + `--limiar-neon` (tinge o metal apagado e deixa o acento aceso intacto), `--grampear-matiz`, `--alvo-v`. Tudo desligado por default |
| **Uma cor nova no cenario** | `tools/texturas/paleta.gd` + a tabela de `docs/IDENTIDADE_VISUAL.md`; `teste_texturas.gd` recusa cor que compete com projetil |
| Enquadramento e cores do minimapa | `@export` do no `Minimapa` em `src/ui/hud.tscn` |
| Preferencias do jogador (tela cheia, acessibilidade, idioma) | `src/autoload/configuracao.gd` — grava em `user://config.cfg` |
| **Texto de tela, em qualquer idioma** | `tools/i18n/gerar_csv.py` e rodar; nunca editar `locale/textos.csv` a mao |
| **Idioma novo** | acrescentar em `Configuracao.IDIOMAS` + uma coluna no gerador do CSV |
| Quantas salas o andar tem e o vao do corredor | `@export` do no `GerenciadorMapa` em `src/main/main.tscn` |
| Tamanho de uma sala | os `points` do Line2D `Parede` — multiplos de 16, dimensao multipla de 32 |
| Resolucao base | `[display]` do `project.godot` — 960x544, camera em zoom 1.0 |
| Forma e parede de uma sala | Line2D `Parede` em `src/mapa/sala_*.tscn` — a colisao nasce dele |
| Lockdown e abertura de porta | `src/mapa/sala.gd`, `src/mapa/porta.gd` e a barreira fisica de `src/mapa/porta.tscn` |
| Glitch de alucinacao | `assets/shaders/glitch.gdshader` |

**Balanceamento quase nunca exige codigo.** Se a resposta a um pedido de tuning
for "vou editar um `.gd`", verifique antes se nao deveria ser um `.tres`.

## Antes de entregar qualquer alteracao

```bash
godot --headless --path . tools/teste_fumaca.tscn      # precisa imprimir PASSOU
godot --path . tools/capturar.tscn --resolution 960x544   # se mexeu no visual
```

O teste sobe o jogo inteiro sem janela, avanca as ondas, mata o chefe e falha
em qualquer erro de script.

## Armadilhas que ja custaram tempo aqui

- **`custo` zero num `GrupoInimigo` giraria o sorteio para sempre.** Por isso o
  sorteio consome `custo_real()`, que tem piso 1, e nunca o campo cru.
- **A porta por Deterioracao NAO pode ler `Deterioracao.valor`.** A composicao
  do andar inteiro e sorteada em `_montar_andar()`, com a barra em zero;
  comparar com o valor real ali barraria todo grupo com porta acima de zero,
  para sempre e sem erro nenhum. O gerador compara com a Deterioracao ESTIMADA
  da celula (`salas ate aqui x deterioracao_ao_limpar`).
- **Se todo grupo tiver porta acima de zero, as salas de combate nascem
  vazias.** `_sortear_grupo()` devolve `null` e o andar vira uma caminhada, sem
  uma linha no console. `teste_composicao.gd` exige ao menos um grupo liberado
  em zero.
- **Area de perigo tem de morrer com quem a semeou**, e nascer no container da
  sala e nao como filha do Parasita. Filha dele ela anda junto, e aviso no chao
  que se move e aviso que mente.
- **O teste de fumaca nao alcanca inimigo de ciclo longo.** Ele mata tudo a
  cada 0,12s, e o Parasita leva ~1s entre nascer e semear -- em tres runs
  seguidas ele apareceu e ZERO areas foram criadas. Comportamento que demora
  mais que um tick precisa de suite propria (`teste_area_de_perigo.gd`), senao
  a guarda passa verde sem nunca ter olhado nada.
- **`Array[Node].filter()` devolve `Array` sem tipo.** Atribuir de volta a uma
  variavel tipada explode em runtime. Use loop explicito.
- **Referencia de no exportada nao resolve.** Use `NodePath` explicito e
  `get_node_or_null` no `_ready`.
- **Corrotina reentrante no gerenciador de ondas.** Toda funcao que `await`
  antes de mexer em estado global precisa de trava, senao pula uma onda
  inteira — inclusive a do chefe.
- **A onda do chefe nao termina por contagem de inimigos**, so pela morte dele.
- **Timer de hitstop precisa ignorar `time_scale`**:
  `create_timer(d, true, false, true)`.
- **Clarao de dano nao pode reiniciar em andamento** — com dano continuo o
  inimigo fica branco permanente e some a silhueta.
- **Sub-resource num `.tscn` e compartilhado entre instancias.** Crie a forma
  de colisao em codigo no `_ready`.
- **`Line2D` de rastro precisa de `top_level = true`.**
- **MSAA 2D nao existe no renderer Compatibility.** Nao tente ligar.
- **`SCREEN_TEXTURE` quebra no export web.** Prefira efeito procedural — o
  shader de glitch e procedural de proposito.
- **Parede de sala e gerada em codigo a partir do Line2D `Parede`.** Poligono
  de colisao desenhado a mao no `.tscn` desalinha e chega a tapar as portas.
- **`Area2D` nao bloqueia ninguem.** Porta trancada precisa de `StaticBody2D`
  com a colisao habilitada.
- **Porta SELADA nao pode ligar a barreira.** So a TRANCADA precisa de solido
  proprio: `Sala._vaos_no_trecho()` pula porta selada, entao a parede gerada ja
  passa reta por cima daquele lado. E os dois solidos nao ficam no mesmo lugar
  -- a parede e um `SegmentShape2D` sobre a linha do contorno, sem espessura, e
  a barreira e um retangulo de 80x32 CENTRADO nessa linha. Metade dele, 16 px,
  cai DENTRO da area jogavel: uma laje invisivel de 80x16 em todo lado de sala
  sem vizinho, e o jogador esbarrando em nada. Nao ha erro no console para
  colisao a mais, e o teste de fumaca nao encosta na parede. `teste_porta.gd`
  guarda os tres estados.
- **Layer de fisica e nomeada em `project.godot`.** Parede na layer 1
  ("player") em vez da 3 ("parede") faz alguem remendar o mask do Player e
  quebra o resto.
- **A sala do chefe fecha pela morte dele, nunca por contagem do container.**
  `Sala._vivos` guarda so quem a SALA colocou; os invocados da Diretora nascem no
  mesmo `ContainerInimigos` e ficam de fora de proposito. Contar o container
  faria um invocado sobrevivente segurar a vitoria.
- **`ativar()` de sala tem de ser idempotente**, senao voltar para uma sala
  limpa recomeca o combate. E e nele, e nao no `_ready`, que se decide se a sala
  tem combate: a composicao chega depois do `add_child`.
- **A composicao e consumida ao ser usada.** `Sala._povoar()` zera `_composicao`
  antes de instanciar, para uma reativacao nao repovoar a sala.
- **Sala inicial, de arma e de item nunca tem inimigos.** A garantia esta em
  duas pontas: `teste_composicao.gd` recusa lista de inimigos nesses tipos, e o
  teste de fumaca falha se achar alguem dentro delas na chegada.
- **Toda geometria de sala e multipla de 16, e a DIMENSAO e multipla de 32.**
  A resolucao base e 960x544 (ambos /16). As salas sao centradas na origem,
  entao o contorno guarda a MEIA dimensao -- e meia dimensao so cai na grade se
  a dimensao inteira for multipla de 32. Sala nova fora disso nao quebra nada em
  runtime; so o tileset e que nao encaixa, meses depois. A suite
  `tools/testes/teste_grade.gd` recusa.
- **`Porta.LARGURA` e `largura_corredor` tem de ser iguais.** A porta e o vao que
  a parede abre; o corredor encaixa nessa boca. Mudar um sem o outro deixa
  parede no meio da passagem.
- **A sala de arma e a de item sao obrigatorias** (`opcional = false` nos
  `.tres`), como o chefe: se uma delas nao couber no grafo sorteado, o andar
  inteiro e sorteado de novo. Sem isso a run podia acontecer inteira so com a
  pistola inicial, ja que a sala de arma e a unica fonte de arma. Medido em 120
  andares: 100% de presenca dos cinco tipos, media de 10 salas, zero andares
  curtos.
- **A celula (0,0) e reservada para o tipo `inicial`.** Ela entra em
  `_reservadas` pelo mesmo caminho de uma pendurada, o que traz de graca a regra
  de `_celula_aceita`: nenhum premio nem o chefe nascem colados na entrada.
  `Colocacao.INICIAL` fica fora do sorteio de preenchimento — sem isso uma
  segunda sala de entrada, vazia e sem proposito, apareceria no meio do andar.
- **Arma so nasce na sala de arma.** O `DadosOnda` tinha um campo `solta_arma`
  que fazia a onda largar uma arma ao ser limpa, e a sala GRANDE usava uma onda
  com ele ligado -- entao uma sala de combate entregava de graca o que devia
  custar o desvio ate a sala de recompensa. O mecanismo foi removido inteiro, e
  nao deve voltar: a fonte de arma e o `PickupArma` na cena da sala de arma.
  `tools/testes/teste_dados_sala.gd` recusa pickup de arma em sala de outro tipo.
- **Sala pendurada precisa de porta nos quatro lados.** Boss, arma e item
  nascem numa celula criada so para elas. Com uma porta so, todas disputam a
  mesma posicao relativa e as ultimas quase nunca cabem — a sala de item
  aparecia em 28% dos andares por isso. As portas sem vizinho sao seladas
  sozinhas por `_selar_portas_sem_vizinho()`, entao dar as quatro nao custa
  nada.
- **`Geometry2D.triangulate_polygon` devolve vazio se o poligono repetir o
  primeiro ponto no fim** — e todo `Line2D` `Parede` repete, para fechar o
  desenho. Por isso existe `Sala.contorno_local()` (aberto, para quem desenha)
  separado de `_pontos_do_contorno()` (fechado, para quem monta parede).
- **`Visual/Corpo` pode ser `Polygon2D` OU `Sprite2D`.** E o no que
  `InimigoBase` procura para pintar Hack e nanite, e desde o Drone Aranha ele
  nao e mais so poligono. Por isso `_corpo` e tipado `CanvasItem` e quem escreve
  cor e `_pintar_corpo()`: num poligono vai em `color`, num sprite em
  `self_modulate`. Escrever `.color` direto volta a explodir no inimigo com
  arte, e tipar de volta como `Polygon2D` falha o cast em runtime. O neutro
  tambem muda de canal -- `_cor_neutra()` devolve `cor_base` no poligono e
  BRANCO no sprite, porque `self_modulate` multiplica a arte em vez de
  preenche-la.
- **Telegrafo desenha em `z = 0`, e o chao em `-1`.** A `AreaDePerigo` ficou em
  `z_index = -4` desde que nasceu: o piso da sala desenhava POR CIMA do aviso, e
  o telegrafo -- a unica coisa que torna aquele ataque justo -- era invisivel. O
  `IDENTIDADE_VISUAL.md` ja pedia z=0 com todas as letras, e a cena dizia outra
  coisa. Nao ha erro no console para "o aviso existe mas ninguem ve".
- **A identidade da Diretora tem um portao executavel.**
  `tools/testes/teste_diretora.gd` recusa a mudanca que a descaracteriza: todo
  ataque telegrafa, o aviso encurta por fase mas nunca cai de 0,35 s, o
  repertorio so cresce, todo ataque de area deixa saida, e ela NUNCA persegue.
  A trava da orbita e a mais barata de perder -- trocar `_orbitar` por
  `direcao_para_alvo()` faria dela um Rastejante de 300 de vida sem quebrar
  nada. A prosa que explica cada trava esta em `docs/GDD.md`.
- **`PerfilJogador` so corrige a mira com confianca.** Ela precisa ver o jogador
  se mexer por alguns segundos antes de antecipar o lado da esquiva. Tirar esse
  freio faz o PRIMEIRO disparo da luta ja sair corrigido -- punindo um habito
  que o jogador nao teve chance de formar, que e a mesma armadilha que o GDD
  descreve para a mira preditiva.
- **`Arma` e o mesmo script no jogador e nos inimigos.** Ler `Modificadores`
  sem conferir `hostil` transforma upgrade do jogador em buff do Vigia.
- **Dano e `int`.** Percentual em cima de int some no arredondamento: "+10%" num
  dano 2 volta a ser 2. Por isso `DANO` (soma) e `DANO_PERCENTUAL` (multiplica)
  sao alvos SEPARADOS, e o calculo soma primeiro, multiplica depois e arredonda
  uma vez so.
- **Parede e detectada por LAYER, nao por grupo.** O teste antigo era
  `is_in_group("parede")`, e as paredes geradas por `sala.gd`/`corredor.gd`
  nunca entravam em grupo nenhum -- os projeteis atravessavam parede. Hoje quem
  resolve isso e o raycast de `projetil.gd`, que tambem devolve a normal que o
  ricochete precisa.
- **Todo ganho de Deterioracao passa por `adicionar()`.** O multiplicador de
  implante mora la, e nao no `_process`: antes ele valia so para o ganho passivo
  e escapava de tudo que sobe a barra por evento.
- **`Arma.atirar()` num `for` no mesmo frame so dispara UMA vez.** O
  `_t_cadencia` e setado no primeiro tiro e `pode_atirar()` recusa o resto,
  porque o `_process` que decrementa nao roda no meio do laco. Salva radial usa
  **`Arma.atirar_varias(direcoes)`**, que gasta um cooldown e uma bala para a
  salva inteira. Foi assim que o anel da Diretora passou a sair com 20 projeteis
  em vez de um. `tools/testes/teste_arma.gd` guarda os dois lados: que o laco
  antigo da 1 e que a salva da N.
- **O `_ready` do projetil roda ANTES de `configurar()`**, porque a Arma faz
  `add_child` primeiro. Quem pinta e dimensiona e `_aplicar_aparencia()`,
  chamado nas DUAS pontas. Mexer nisso sem manter a segunda chamada faz todo
  projetil do jogo voltar a nascer ciano com raio 4 -- o tiro do inimigo fica
  igual ao do jogador e a colisao menor do que o `.tres` pede.
- **`Juice` tem DUAS chaves, nao uma.** `shake_habilitado` move a camera e e o
  que a tela de opcoes desliga; `hitstop_habilitado` congela o tempo e da peso ao
  tiro. Eram um booleano so, e desligar o tremor levava junto o impacto do
  combate -- coisas diferentes, para publicos diferentes.
- **`Configuracao` e o primeiro `user://` do projeto.** Ele guarda PREFERENCIA,
  nao progresso: save de run e meta-progressao sao outro assunto e nao devem
  entrar ali, senao apagar a config passa a custar caro.
- **Autoload nao enxerga quem vem depois dele.** `Configuracao` e registrado
  antes de `Juice`, entao no `_ready` dela o `Juice` ainda nao existe. Quem vem
  depois PUXA a preferencia no proprio `_ready`; o sinal
  `EventBus.configuracao_mudou` cobre as mudancas em runtime.
- **No navegador, tela cheia so vale a partir de um clique.** A Fullscreen API
  exige gesto do usuario, entao reaplicar a preferencia salva no boot e recusado
  em silencio. Por isso `_aplicar_tela_cheia` recebe `por_gesto`.
- **Conecte o sinal ANTES de `equipar()`.** `equipar()` emite `municao_alterada`
  na hora; ligar o sinal depois perde esse primeiro aviso e a HUD fica com o
  texto que estava escrito na cena.
- **Area que estoura NAO pode estourar no `_ready`.** A convencao do projeto e
  `add_child` ANTES de `configurar` -- entao no `_ready` a `ExplosaoArea` ainda
  esta em (0,0) com o raio padrao, e varre o lugar errado. A primeira versao
  disfarcava com uma segunda varredura diferida, e "as vezes acerta" e PIOR que
  "nunca acerta": passa no teste e falha na sala cheia, que e quando a granada
  importa. Hoje o estouro sai de `configurar()` e e sincrono.
- **`get_overlapping_bodies()` nao serve para explosao.** Ele responde com o
  estado do ultimo passo de fisica, e a area nasceu NESTE frame -- no instante
  do estouro ela nao existia para o servidor. Pior: quem ja esta dentro do raio
  nunca *entra* nele, e e onde esta a maioria dos alvos. Use
  `intersect_shape` no espaco direto.
  **Esta linha dizia que a licao "ja estava em `AreaDePerigo._explodir()`", e
  nao estava** -- a area do Parasita chamava `get_overlapping_bodies()` no mesmo
  frame em que ligava `monitoring`, entao a varredura voltava sempre vazia e
  ficar PARADO dentro do circulo era a forma mais segura de sobreviver a ele. O
  ataque punia quem se mexia e perdoava quem congelava, o inverso do que ele
  existe para fazer. Corrigido, com regressao em `teste_area_de_perigo.gd`.
- **Granada nao machuca ao encostar.** Dano de contato MAIS explosao cobraria
  duas vezes do alvo colado e apagaria o falloff, que existe justamente para
  premiar quem acerta no meio do grupo. `EXPLOSIVO` crava e some; quem fere e a
  explosao.
- **Projetil explosivo tem de sair do alcance explodindo, nao sumindo.** O
  `_vida_restante` chega a zero e faz `queue_free()` -- numa granada isso le
  como tiro engolido. E o pavio aceso precisa de saida antecipada no
  `_physics_process`, senao o alcance continua correndo por baixo e a granada
  morre antes de estourar.
- **Explosao na parede nasce afastada pela NORMAL.** Sem o `+ normal * raio` a
  area nasce meio enterrada no solido, e metade do raio nao alcanca ninguem --
  numa arma que existe para usar o corredor a favor.
- **Suite de teste que precisa de passo de fisica exige `await` no runner.** Um
  corpo recem-adicionado so entra no espaco no passo seguinte. O `runner.gd` faz
  `await suite.executar()` por isso; sem o await ele imprime o relatorio antes
  de a suite terminar e as verificacoes dela somem da conta, sem erro nenhum.
- **Dano continuo encadeia hitstop e prende o jogo em camera lenta.** O
  `_hitstop_ativo` do `Juice` impede EMPILHAR, mas nao impede o proximo tique
  ligar outro no instante em que o anterior acaba -- e `receber_dano()` pede um
  hitstop a CADA acerto. O feixe do Laser entregava 19 de dano onde o `.tres`
  pedia 26, porque ele atrasava a si mesmo. Por isso existe
  `Juice.INTERVALO_HITSTOP`, medido em relogio de PAREDE: um timer da arvore
  andaria devagar durante o proprio hitstop, que e justo o intervalo em questao.
- **Arma que le tempo tem de ler o delta da FISICA.** Quem puxa o gatilho e o
  `_physics_process` do Player, entao `get_process_delta_time()` num efeito
  continuo faz o dano por segundo depender do framerate. E o raycast do feixe
  so faz sentido num passo de fisica de qualquer jeito.
- **`_t_cadencia` ja e decrementado pelo `_process` da `Arma`.** Decrementar de
  novo dentro de um caminho proprio (o do feixe fazia isso) drena o pente no
  DOBRO da velocidade que o `.tres` pede, sem erro nenhum no console.
- **Projetil teleguiado precisa de teto de graus por segundo.** Sem teto ele
  gruda no alvo e vira um tiro que nao erra -- o oposto do que o GDD pede, que e
  poder ler a ameaca antes de ela doer. O teto e `curva_graus`, e o
  `teste_comportamento_arma.gd` exige que ele exista e seja finito.
- **Projetil hostil NAO procura alvo.** `_procurar_alvo()` devolve `null` quando
  `hostil` -- um Vigia com arma teleguiada teria mira perfeita atras do jogador.
  E o mesmo portao que `Arma` ja aplica para os implantes.
- **Corrente mede distancia a partir do ULTIMO atingido, nao do impacto.** Do
  ponto de impacto ela vira um circulo de dano centrado no primeiro alvo; do
  ultimo elo ela serpenteia por uma fila, que e o que a arma promete.
- **Nanite EMPILHA onde o Hack RENOVA.** Sao efeitos com desenhos opostos, e por
  isso nao compartilham codigo: o Hack quer marcar um alvo, o nanite quer
  recompensar insistir nele. O acumulo apodrece INTEIRO ao expirar -- decaimento
  dose a dose se sustentaria com tiro esporadico e a arma perderia o que pede em
  troca.
- **Dois tints brigam pelo mesmo `_corpo.color`.** Hack e nanite escrevem no
  mesmo canal, entao a cor final dependeria da ordem das chamadas. O nanite so
  pinta se nao houver Hack ativo, e `_pintar_hack(false)` DEVOLVE o canal ao
  nanite ao sair -- voltar direto para `cor_base` apagaria o aviso de que o
  inimigo esta carregado, e a explosao chegaria sem leitura nenhuma.
- **Arco e feixe nascem na CENA, nunca como filhos de quem os criou.** O
  projetil morre no mesmo frame do acerto e levaria o arco junto antes de
  alguem ver. Mesma licao da `AreaDePerigo` do Parasita.
- **`Arma` nao tem cena.** E `class_name Arma extends Node2D`, script puro
  pendurado num no dentro de outras cenas -- nao existe `arma.tscn`.
- **Quem hospeda a run e dono de `GameState.iniciar_run()`/`terminar_run()`.**
  Perder essa chamada desliga a Deterioracao passiva sem erro nenhum no console.
- **Textura em `Polygon2D` nao repete sozinha.** O projeto nao define
  `default_texture_repeat`, entao o default e Disabled: sem
  `texture_repeat = TEXTURE_REPEAT_ENABLED` a textura sai esticada UMA vez no
  tamanho da sala. E a UV e em pixels, ancorada no CANTO do contorno -- no
  centro, o tile sai cortado ao meio nas bordas norte e sul (272 nao e
  multiplo de 32).
- **`class_name` novo em `tools/` so existe depois de `--import`.** Rodar uma
  cena headless logo apos criar `paleta.gd` da "Identifier 'Paleta' not
  declared" e o processo NAO encerra sozinho (fica ate o timeout). Em maquina
  limpa, `--import` vem antes de tudo -- inclusive antes do gerador de texturas.
- **O `Line2D "Parede"` fica invisivel em runtime.** Ele e a fonte da geometria
  (colisao, camera, minimapa, tudo le `points` dele) e o que o editor mostra
  para quem desenha a sala, mas nunca aparece em jogo -- desenha-lo atravessaria
  o vao das portas. Quem esconde e `_montar_visual()`. Mexer em `default_color`
  ou `texture` do Line2D da cena nao muda nada na tela.
- **NAO existe mais filete de neon.** O contorno das salas e dos corredores era
  desenhado por um `_montar_filete()` de trechos coloridos por `filete_*.png`.
  Saiu quando a parede ganhou textura propria: viravam duas bordas uma sobre a
  outra, e como a camera parava no contorno era o NEON -- e nao a parede -- que
  encostava na beira do quadro. Foram junto o `DadosSala.textura_filete`, os
  cinco PNGs, `GeradorTexturas.gerar_filete()` e a borda do pilar. A cor `A2` da
  paleta continua viva: o gerador a usa em outros dois lugares.
- **O clamp da camera cresce `Sala.ESPESSURA_PAREDE` ALEM do contorno**, e e o
  que faz a faixa de parede aparecer. Ele e aplicado em
  `GerenciadorMapa._clampar()` e nunca em `Sala.obter_limites()`: aquele
  retangulo tambem posiciona as celulas em `_montar_andar()`, entao inflar na
  origem afastaria as salas e desalinharia os corredores.
- **Numa sala do tamanho exato da tela, a parede so entra no quadro quando o
  jogador anda ate a borda.** Contorno 960x544 mais 24 px de cada lado da
  1008x592 contra uma tela de 960x544: sobram 24 px de deslize por eixo, e com o
  jogador no centro nenhuma parede aparece. Nao ha conserto por zoom -- as
  proporcoes nao batem (1.70 contra 1.76), entao encolher para caber deixaria
  faixa de vazio na lateral. O unico conserto completo seria geometrico: parede
  de 16 px e salas de 928x512 fecham exatamente 960x544, e ambos caem na grade
  de 32. Isso mexe em todas as cenas de sala e ainda nao foi feito.
- **A faixa de matiz de um tipo de sala mora em DOIS arquivos.**
  `MATIZ_POR_TIPO` existe igual em `tools/texturas/preparar_textura.py` (quem
  escreve) e em `tools/testes/teste_texturas.gd` (quem confere). Mudar num so
  deixa o funil produzindo o que o portao recusa -- e o erro so aparece na
  suite, depois de a arte ja estar em disco. A do `andar1` e larga de proposito
  (185-320): ela separa TIPO DE SALA, e quem separa mapa de ATOR e o teto de
  valor (chao em 0,30 contra o piso de 0,55 do portao G2), que nao muda.
- **`teste_texturas.gd` compara o PNG em disco com o gerador.** Mudou uma cor
  em `paleta.gd` ou um traco em `gerar_texturas.gd`? Rode o gerador e o
  `--import` de novo, senao a suite reprova com "gerou e esqueceu de rodar?".

- **`DadosArma.Comportamento` e gravado como INT no .tres.** Valor novo entra
  sempre NO FIM do enum; inserir no meio reescreve em silencio o significado de
  toda arma ja salva. Mesma armadilha que ja vale para `DadosItem`.
- **Teste que monta um `container_projeteis` tem de liberar com `free()`.** A
  suite roda inteira num frame, entao um `queue_free()` deixa o container no
  grupo e os casos SEGUINTES pedem `get_first_node_in_group` e recebem aquele --
  contando zero no proprio. Sintoma: testes que passavam comecam a devolver 0
  projeteis assim que um caso novo entra antes deles.
- **Arma semiautomatica precisa de `atualizar_gatilho(false)` entre os tiros num
  harness.** `pode_atirar()` exige `_gatilho_solto`, entao sem soltar so o
  PRIMEIRO disparo sai -- e a medicao passa achando que mediu 40 amostras.
- **A CHAVE de traducao e o proprio texto em portugues.** Nao ha codigo tipo
  `ITEM_NUCLEO_NOME`: o `.tres` guarda "Nucleo de Reserva" e a tabela mapeia
  para "Reserve Core". Isso mantem o Inspetor legivel e faz o portugues rodar
  sem tabela nenhuma (tr() devolve a chave quando nao acha entrada). O preco:
  **editar o texto em portugues quebra o ingles em silencio**. Por isso existe
  `tools/testes/teste_traducao.gd`, que exige par na tabela para toda string de
  dado que chega a tela.
- **`locale/fallback` tem de ser `pt_BR`, nao o padrao `en`.** So o ingles esta
  na tabela; em portugues nao ha traducao carregada. Com o fallback em "en",
  pedir portugues cairia no ingles em vez de devolver a chave.
- **Chave de traducao nao pode ter quebra de linha.** O importador de CSV do
  Godot le a quebra como fim de registro e parte a tabela ao meio. Frase de duas
  linhas vira duas chaves juntadas em codigo -- e o que `hud.gd` faz no aviso de
  50% de Deterioracao.
- **Botao com marcador `>` precisa de `auto_translate_mode = DISABLED`.** O
  marcador e escrito DENTRO de `text`, e "> NOVO JOGO" nao existe na tabela; com
  a traducao automatica ligada o botao fica em portugues no jogo em ingles, sem
  erro nenhum. `menu_inicial.gd` guarda a chave num dicionario, traduz na mao e
  se reescreve em `NOTIFICATION_TRANSLATION_CHANGED`.
- **Teste que le texto de tela tem de FIXAR o idioma.** `nome_fase()` passa por
  `tr()`: sem fixar, a suite passa na maquina de quem tem o SO em portugues e
  quebra no CI, que roda em ingles.
- **A selecao de operador e um PAINEL do menu, nao uma tela.** Ela alterna
  `visible` como o menu_opcoes, e por isso precisa de `abrir()`, `fechar()` e do
  sinal `fechado`. O botao SAIR da barra de baixo existe para quem joga no
  MOUSE: quem usa teclado sai pelo ESC, e sem o botao o jogador de mouse ficava
  sem saida a nao ser escolher um operador.
- **As barras do cartao de selecao medem a ARMA, nao a personagem.** RAVEN e
  NOVA tem vida, velocidade e rolamento identicos de proposito; barras de
  VIDA/DEFESA/AGILIDADE seriam quatro reguas dizendo "empate", ou quatro numeros
  inventados. `DadosArma.perfil_*()` le o `.tres`, entao a barra nunca descola do
  que a arma faz de fato.
- **`MolduraHud` e MarginContainer, nao Control.** Como Control puro ela nao tem
  altura minima vinda do conteudo: um cartao com `size_flags_vertical =
  SHRINK_CENTER` nasce com altura ZERO e o conteudo inteiro vaza para fora da
  borda. Sendo container ela cresce com o que esta dentro, e o `_draw` do pai
  roda antes dos filhos, entao a borda fica atras do conteudo de graca.
- **Retrato do cartao usa `miniatura.png`, nao o sprite de 80.** A moldura de 80
  existe para o quadro mais largo do conjunto de rotacoes e deixa vazio dos dois
  lados; no cartao o personagem sairia pequeno demais. O gerador recorta no
  alpha e dobra -- 128 e o tamanho certo E escala inteira, a unica que nao borra
  pixel art. Qualquer outra caixa que nao 128 reescala e borra.
- **O sprite do jogador e IRMAO de `Visual`, nunca filho.** O no `Arma` mora em
  `Visual` na posicao (27, 0), e e a rotacao do `Visual` que faz a boca da arma
  orbitar o jogador. Por em `Visual` um sprite direcional o faria girar junto
  (arte 3/4 deitada); parar de girar o `Visual` para acomodar o sprite faria
  todo projetil nascer 27px a direita do jogador, para sempre e sem erro no
  console. Por isso o `Sprite` fica fora, e por isso os i-frames e a morte
  precisam mexer nos DOIS nos -- fora de `Visual`, o sprite nao herda o
  `modulate`.
- **O Godot NAO importa GIF.** Nao existe importador; um `.gif` em `res://` e
  ignorado sem aviso. Por isso `tools/sprites/gerar_sprites.py` e Python e nao
  GDScript como o gerador de texturas: ele roda FORA do motor, e o que entra no
  jogo e o PNG que ele escreve.
- **Todo sprite de personagem vive numa moldura 80x80 ancorada nos PES.** A arte
  chega com molduras diferentes (64 no parado, 88 ou 92 no andando) mas com o
  personagem do mesmo tamanho -- so muda o vazio em volta. Usar como chega faz a
  personagem saltar de lugar toda vez que comeca ou para de andar. A ancora e
  horizontal pelo CENTRO DA MOLDURA de origem (a arte tem deslocamento lateral
  intencional, e centralizar pelo desenho o apagaria) e vertical pela BASE do
  bbox de alpha.
- **Ciclo de caminhada dirigido por TEMPO desliza.** O passo tem de seguir o
  CHAO, e nao o relogio: `fps_andando` sozinho so acerta se o bicho tiver uma
  velocidade so -- e isso nao existe aqui, porque a Deterioracao multiplica a
  velocidade de todo inimigo ate 1,55x. O caso extremo foi a Cyber-Besta, que
  anda a 88 px/s e investe a 720: as patas corriam 8,2x mais devagar que o chao.
  Quem liga isso e `velocidade_referencia` no `SpriteDirecional` (zero =
  cadencia fixa), e `aceleracao_maxima_do_ciclo` poe teto para a corrida nao
  virar estrobo. Sobra deslize acima do teto, e e proposital.
- **`OBSERVAR` da Cyber-Besta nao e ficar parado, e CIRCULAR.** `_observar()`
  anda a 0,6 da velocidade numa direcao 65% ortogonal ao jogador, e e o estado
  em que ela passa mais tempo. Excluir esse estado de "esta andando" congela as
  patas exatamente onde ela mais se desloca -- ja aconteceu.
- **Sprite direcional e rotacao de `Visual` nao convivem.** O `Visual` do
  inimigo pode estar girando (`lerp_angle` para o alvo) -- seis dos oito fazem
  isso. Por um sprite de oito rotacoes dentro de um `Visual` que gira DEITA a
  arte, que e desenhada em vista 3/4. Quando o corpo vira sprite, a rotacao sai
  e quem passa a carregar a direcao sao os oito quadros. **Mas o motivo pelo
  qual aquele inimigo girava tem de sobreviver**: na Cyber-Besta a rotacao
  existia para o corpo apontar para onde ele VAI durante a investida, e nao para
  onde o jogador esta -- e essa regra continua, so mudou quem a executa.
- **Agachamento anisotropico depende do `Visual` girado.** `scale(0.7, 1.35)`
  comprime no x LOCAL: com o `Visual` girado, isso e comprimir na direcao da
  corrida. Tirada a rotacao, o mesmo vetor comprime sempre na horizontal da
  TELA, e um bicho carregando para cima aparece achatado de lado -- a
  anticipacao contada no eixo errado. `CyberBesta._agachar()` escolhe o eixo
  dominante, a mesma quantizacao de oito passos do sprite.
- **O mapa de angulo -> quadro mora em `src/util/direcoes.gd`, e so ali.** Ele
  nasceu dentro de `DadosPersonagem` e saiu de la quando o Drone Aranha ganhou
  arte. Duas copias acabariam divergindo, e o sintoma seria o inimigo e a
  personagem lendo o mesmo angulo de jeitos diferentes -- gritante em tela,
  invisivel no console.
- **`hframes` anda junto de `texture`, sempre.** Trocar a textura para uma fita
  de caminhada sem trocar o `hframes` desenha os nove quadros espremidos no
  lugar da personagem; o inverso mostra um nono dela. Nenhum dos dois gera erro.
  Vale para o `Sprite` do Player e para o eco de rolamento, que copia os dois.
- **Escala de pixel art e INTEIRA.** 64 -> 128 (2x) fica nitido; 64 -> 96
  (1,5x) borra mesmo com o filtro Nearest do projeto, porque um pixel da arte
  deixa de cair num numero redondo de pixels de tela.
- **Suite que precisa fixar o quadro do jogador tem de desligar o
  `_physics_process` dele.** `_mirar()` roda todo frame e reescreve a textura a
  partir da posicao real do mouse; num harness o mouse nao se mexe, entao o
  quadro que voce setou vira sempre o mesmo e o teste "prova" a coisa errada.
- **A escolha de personagem NAO pode ser zerada por `iniciar_run()`.** Quem
  chama `iniciar_run()` e o `_ready` do GerenciadorMapa -- a run comeca DEPOIS
  de a tela de selecao ja ter escrito em `GameState.personagem`. Se o campo
  entrasse no bloco de contadores que a funcao limpa, a escolha seria apagada no
  boot da propria cena que ela pediu. E e o mesmo campo que faz o R da tela de
  fim funcionar, ja que `reiniciar()` recarrega a cena sem passar pelo menu.
- **Atributo de personagem se aplica no TOPO do `_ready` do Player.** A linha
  `_vida_maxima_base = vida_maxima` congela a base; qualquer coisa aplicada
  depois dela deixa todo o recalculo de implantes de vida somando em cima do
  numero errado.
- **A chance do Hack e sorteada por TIRO, em `Arma._consumir_tiro()`.** Sortear
  dentro do projetil parece mais simples -- e la que existe alvo -- mas uma
  shotgun rolaria os 10% oito vezes por disparo, ~57%. Por isso existe o par
  `Modificadores.armar_hack()` / `consumir_hack()`, espelhando o
  `_marcador_armado` da IA Predatoria, que resolve o mesmo problema.
- **O bonus de dano do Hack entra em `projetil._dano_no_alvo()`, nunca em
  `receber_dano`.** A Diretora reimplementa `receber_dano` sem chamar `super`:
  aplicado la, o chefe seria o unico do jogo imune ao Hack, e em silencio.
- **O tint de hackeado vai em `_corpo.color`, nunca em `_visual.modulate`.**
  Aquele e do clarao de dano, que termina sempre em `Color.WHITE` e apagaria o
  tint no primeiro tiro que acertasse. O modulate do pai multiplica por cima da
  cor do poligono, entao os dois convivem sem se conhecer.
- **Os tres campos de dispersao nascem em ZERO e tem de continuar assim.**
  `Arma._emitir()` e o mesmo caminho do jogador e dos inimigos; um default acima
  de zero daria bloom para a salva da Diretora sem ninguem pedir.
- **Suite que cria inimigo tem de afastar o cenario da origem.** A propagacao do
  Hack busca no grupo `inimigo`, que e global: inimigos de OUTRAS suites que
  ainda nao foram coletados aparecem na busca, e quase todos ficam perto de
  (0,0). `teste_hack.gd` monta o cenario em (6000, 6000) por isso -- foi um dia
  de teste vermelho com o codigo certo.

## Ambiente

- O projeto esta em `C:\Users\alcyn\OneDrive\Documents\psicode`. Isso e dentro
  do OneDrive, contra a recomendacao geral, por decisao consciente. Se aparecer
  arquivo travado, reimport fantasma ou "abriu tudo vermelho", suspeite da
  sincronizacao antes de qualquer outra coisa.
- A pasta `.godot/` e cache. Nunca commitar. Apagar resolve a maioria dos
  problemas de import.
- Os arquivos `.uid` (Godot 4.4+) **devem** ser commitados.
- Ativar o plugin `godot_mcp` injeta tres autoloads no `project.godot` e os
  remove ao desativar. Nao commitar essas linhas, e **desativar o plugin antes
  de exportar build**.

## Trabalho em equipe

Dois dos tres **nao conhecem Godot nem Git**. Ao propor qualquer coisa que eles
vao executar, escreva no nivel do `docs/HANDOFF.md`: passo a passo, comando
literal, sem jargao.

Branches: `feat/`, `fix/`, `tune/`, `docs/`. Nunca commitar no `main`.
Commits em portugues, imperativo, minusculo. **Uma pessoa por cena `.tscn` por
vez** — cena e onde o merge doi.

## Disciplina de escopo

A **Fase 1 (game feel e primeiro playtest) esta CONCLUIDA**. A build
`v0.2.0-alpha` saiu, foi para o itch.io e para os testadores, e o retorno voltou
positivo e sem problemas acionaveis. Ficaram adiados dois itens, registrados no
`ROADMAP.md`: a sessao de tuning a tres e o rebalance da vida do chefe.

**Nao volte a tratar todo pedido como divida contra o playtest** -- ele
aconteceu. O que sobrou dele e uma ressalva, nao um bloqueio: cinco a oito
pessoas sem nenhuma reclamacao e sinal fraco, entao a base foi validada de forma
rasa. Se alguem apostar alto em cima disso -- reescrever o core loop, por
exemplo -- vale lembrar uma vez que a validacao e magra. Fora isso, siga.

**As fases numeradas nao existem mais.** O `ROADMAP.md` foi reescrito em marcos,
porque o trabalho nao seguiu a ordem das fases: arte entrou no meio da Fase 3, a
selecao de personagem entrou fora de qualquer fase, e dois itens da Fase 5 sairam
sem ninguem abrir aquela secao. Se um pedido citar "Fase 2" ou "Fase 3", traduza
para o marco do roadmap antes de agir.

O marco atual e o **M1 -- o loop fecha**: creditos com ralo, loot dropado, loja e
meta-progressao. A semente ja esta no codigo e parada: `GameState.creditos`
acumula a cada abate e **nada consome**.

A regra de escopo que continua valendo: **numero de balanceamento novo tem de
nascer medivel**. As reguas de `tools/` existem para isso, e um botao que
ninguem consegue medir e um botao que a sessao de tuning nao consegue girar.

## O que evitar

- Sugerir codigo em outra engine ou linguagem.
- Introduzir plugin ou dependencia externa sem avisar antes.
- Efeito visual que atrapalha a leitura do combate, por mais bonito que seja.
  O shader tem `alpha_maximo` justamente para isso.
- Ataque sem telegrafo. Bullet hell so e justo se da para ler a intencao antes
  do projetil existir. Telegrafo encurta com a fase, nunca some.
