# psicode — contexto para agente de IA

Twin-stick shooter / bullet hell / roguelike cyberpunk em **Godot 4.7.2-stable**
(versao standard, nao .NET) com **GDScript**. Renderer **Compatibility (GL)**,
obrigatorio para o export web.

Feito por tres pessoas. Objetivo declarado: **diversao e aprender fazendo** —
ter algo jogavel rapido vale mais que infraestrutura bonita.

> O titulo antigo era "Ciberpsicose". O nome fechado e **psicode**.

## Onde esta a verdade

Este arquivo diz como trabalhar no repositorio. O que o jogo **e** esta nos
documentos abaixo — leia antes de propor mecanica nova:

| Documento | Para que |
|---|---|
| `docs/GDD.md` | Design: core loop, Deterioracao, mira preditiva, o chefe, escopo |
| `docs/ROADMAP.md` | As cinco fases e o que falta em cada uma |
| `docs/CONVENCOES.md` | Git, divisao de arquivos, estilo de codigo |
| `docs/HANDOFF.md` | Passo a passo para quem nao conhece Godot nem Git |
| `docs/BUILD.md` | Export Windows e web |
| `docs/TUNING.md` | Todos os botoes de balanceamento e o que a medicao ja disse |
| `docs/PLAYTEST.md` | As perguntas do playtest e a mensagem pronta |
| `docs/MCP.md` | Servidor MCP que liga assistente de IA ao editor aberto |
| `docs/IDENTIDADE_VISUAL.md` | Identidade visual: as tres paletas, a grade, as regras de leitura de combate e como adicionar textura nova |

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
               menu_inicial, menu_pausa, menu_opcoes
  fx/          explosao, impacto
  util/        balistica (matematica da mira preditiva)
  main/        main.tscn — cena inicial
assets/shaders/  glitch.gdshader
assets/texturas/ PNGs gerados (chao, parede, filete por tipo; porta; props) — nunca editados a mao
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
| Vida e velocidade dos inimigos | `@export` em `src/enemies/*.tscn` |
| Limiares de 50% e 85% | `src/autoload/deterioracao.gd` |
| Matematica de mira preditiva | `src/util/balistica.gd` |
| Chefe | `src/enemies/diretora.gd` |
| Layout e conexao das salas | `src/mapa/gerenciador_mapa.gd`, `src/mapa/sala_*.tscn` |
| **Tipo de sala novo (loja, desafio...)** | criar `src/mapa/tipo_*.tres` e por na lista `tipos_de_sala` do `GerenciadorMapa` |
| **Estilo novo de uma sala que ja existe** | arrastar a cena para `cenas` no `tipo_*.tres` correspondente |
| **Implante novo (so numeros)** | criar `src/items/implante_*.tres` com a lista de `efeitos` e listar em `pool_padrao.tres` |
| **Implante com comportamento novo** | enum em `DadosItem.Comportamento` + o codigo que le, em quem sofre o efeito |
| Pente, tempo de recarga e reserva | `tamanho_pente`, `tempo_recarga`, `municao_maxima` em `src/weapons/*.tres` |
| **Arma que pode cair de loot** | listar o `.tres` em `src/items/pool_padrao.tres` |
| Regras de onde cada sala nasce | `@export` do `tipo_*.tres` (beco, distancia da origem, prioridade) |
| Cor e icone de uma sala no minimapa | `cor_mapa` e `icone` do `tipo_*.tres` |
| **Textura de chao, parede, filete e props de um tipo de sala** | grupo `Visual` do `tipo_*.tres` — os PNGs saem de `tools/texturas/gerar_texturas.tscn`, nunca de editor de imagem |
| **Uma cor nova no cenario** | `tools/texturas/paleta.gd` + a tabela de `docs/IDENTIDADE_VISUAL.md`; `teste_texturas.gd` recusa cor que compete com projetil |
| Enquadramento e cores do minimapa | `@export` do no `Minimapa` em `src/ui/hud.tscn` |
| Preferencias do jogador (tela cheia, acessibilidade) | `src/autoload/configuracao.gd` — grava em `user://config.cfg` |
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
- **O `Line2D "Parede"` fica invisivel em runtime.** Ele continua sendo a fonte
  da geometria (colisao, camera, minimapa, tudo le `points` dele), mas quem
  desenha o filete de neon sao trechos gerados em `_montar_filete()`, os mesmos
  da colisao, para o neon parar no vao da porta. Mexer em `default_color` ou
  `texture` do Line2D da cena nao muda nada na tela.
- **O corpo da parede (24 px para fora do contorno) so aparece na travessia.**
  A camera faz clamp em `obter_limites()`, que e o contorno; numa sala do
  tamanho da tela a faixa fica sempre fora do quadro. Nao e bug, e uma decisao
  deixada em aberto: crescer o clamp em 24 px mostraria a parede, mas faria a
  camera se mexer numa sala que hoje e fixa.
- **`teste_texturas.gd` compara o PNG em disco com o gerador.** Mudou uma cor
  em `paleta.gd` ou um traco em `gerar_texturas.gd`? Rode o gerador e o
  `--import` de novo, senao a suite reprova com "gerou e esqueceu de rodar?".

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

A **Fase 3 (salas, itens e inimigos) esta bem adiantada**: o `GerenciadorMapa`
sorteia um andar de 8–12 salas com ramos, liga as vizinhas por corredor
atravessado a pe, faz lockdown por sala, e o andar tem sete tipos de inimigo,
16 implantes e composicao decidida no layout. A ordem do roadmap manda a
**Fase 2 (arte e som)** vir agora.

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
