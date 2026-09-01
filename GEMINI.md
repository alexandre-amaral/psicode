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
| `docs/LOW_TOPDOWN_SQUARED.md` | **A direcao de camera e arte que o jogo passa a seguir**: parede com topo e face, Y-sort pela base, grade quadrada. Manda na PERSPECTIVA e na FORMA; a paleta continua no `IDENTIDADE_VISUAL.md` |
| `docs/Plano de Implementação — Migração para Low Top-Down Squared.md` | **O plano que comanda a migracao**, em 30 fases. Tile visual 64, grade estrutural 16/32. Dissolvido nas issues `[LTD 00-16]`, epico em #47 |
| `docs/PIVO_LOW_TOPDOWN.md` | O levantamento por tras do plano: o que ja esta conforme, as decisoes e o inventario do que os testes recusam |

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
               game_state, juice, audio (buses, volume e quem toca o que)
  player/      player, eco de rolamento
  weapons/     arma.gd, dados_arma.gd, *.tres (pistola, shotgun, armas do chefe)
  enemies/     inimigo_base, maquina_estados, area_de_perigo,
               telegrafo (o aviso: linha, mancha, pulso e as quatro fases),
               sprite_direcional (o Sprite2D de oito rotacoes),
               rastejante, vigia, drone_aranha, sentinela_orbital,
               atirador_neon, cyber_besta, hacker_parasita, diretora (chefe),
               boss_guardiao_01 (o Automato Enferrujado, chefe do andar 1),
               dados_inimigo.gd + dados_*.tres (os NUMEROS de cada inimigo,
               fora da cena),
               grupo_inimigo.gd + grupo_*.tres (quem nasce, a que custo, e a
               partir de que Deterioracao)
  projectiles/ projetil
  arena/       pickup de arma (instanciado so pela cena da sala de arma)
  mapa/        gerenciador_mapa, sala, porta, corredor, sala_*.tscn,
               prop_animado (o prop de cenario que se mexe, com orcamento),
               reacao_de_arena (a sala do chefe acendendo junto com ele),
               dados_sala.gd + tipo_*.tres (o catalogo de tipos de sala)
  items/       efeito_item.gd + dados_item.gd, implante_*.tres,
               pool_loot.gd, pickup de item
  ui/          hud, barra_vida, barra_deterioracao, minimapa, tela_fim,
               menu_inicial, menu_pausa, menu_opcoes, selecao_personagem,
               moldura_hud (a moldura chanfrada), barra_atributo
  fx/          explosao, impacto
  util/        balistica (matematica da mira preditiva),
               movimento (perseguir, recuar, orbitar, investir, fugir),
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
                 combinacoes/ (medidor_escape.gd + o arnes que poe dois e cinco
                 inimigos na mesma sala e mede se ainda ha para onde correr),
                 chefe/ (arena_chefe: a luta isolada, com HP ajustavel),
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
| **Ator que nao cabe na moldura de 80 (o chefe)** | `MOLDURAS` em `tools/sprites/gerar_sprites.py` + `Direcoes.MOLDURAS_DE_ATOR`; as duas listas tem de continuar iguais |
| **Gesto de ataque, morte ou atordoamento de um inimigo** | a lista `clipes` do no `Visual/Corpo` -- um `ClipeDirecional` por gesto |
| **Se um gesto segue o TEMPO do estado ou o proprio fps** | `modo` no `.tres` do `ClipeDirecional` (`PROGRESSO`, `LACO`, `UMA_VEZ`) |
| **Arte de gesto nova** | pastas em `animations/<id>/<clipe>/<direcao>/` e rodar `gerar_sprites.py`; do PixelLab, `baixar_pixellab.py` traz os quadros para la |
| **Sprite e rotacoes de um inimigo** | o no `Visual/Corpo` da `src/enemies/*.tscn`, com `src/enemies/sprite_direcional.gd`: as duas listas de 8 texturas, `quadros_andando`, `fps_andando`, mais `scale` e `position` do proprio no |
| **Arma inicial, Hack e texto do card de um personagem** | `src/player/personagem_*.tres` |
| Dispersao que cresce com o gatilho preso | `dispersao_*` em `src/weapons/*.tres` — zero desliga |
| **Vida, velocidade, dano e todo botao de combate dos cinco inimigos refinados** | `src/enemies/dados_*.tres` (Drone Aranha, Atirador Neon, Cyber-Besta, Sentinela Orbital, Hacker Parasita) |
| Vida e velocidade dos que ainda nao migraram | `@export` em `src/enemies/*.tscn` -- Rastejante, Vigia, Diretora e as pecas da arena dela |
| **Variante de um inimigo que ja existe (um "de elite")** | criar um `dados_*.tres` novo e apontar `dados` na instancia; NAO duplicar o `.tscn` |
| Limiares de 50% e 85% | `src/autoload/deterioracao.gd` |
| **Quanto o telegrafo encurta com a barra** | `multiplicador_telegrafo()` em `src/autoload/deterioracao.gd`; o PISO fica em `Telegrafo.DURACAO_MINIMA` e nao aqui |
| **Para onde um botao de inimigo caminha com a barra cheia** | grupo `Escalonamento` do `src/enemies/dados_*.tres`; negativo desliga |
| Matematica de mira preditiva | `src/util/balistica.gd` |
| **Alternancia de salva (o anel do Drone, a rajada e o pisao do chefe)** | `Balistica.alternancia()` para anel, `alternancia_de_passo()` para leque -- num lugar so |
| **Pesos, memoria e vies de distancia da selecao de ataque do chefe** | grupo `Selecao de ataque` do `src/enemies/boss_guardiao_01.tscn` |
| **A Falha do Reator (cerco, vaos, telegrafo)** | grupo `Falha do Reator` do mesmo `.tscn`; o vao entre areas e conferido por `vao_do_cerco()` |
| **Os quatro ataques do chefe do andar 1** | `@export_group` por ataque em `src/enemies/boss_guardiao_01.tscn`; as ARMAS dele em `src/weapons/onda_guardiao.tres` e `sucata_guardiao.tres` |
| **Como QUALQUER inimigo se desloca** | `src/util/movimento.gd` -- perseguir, recuar, orbitar, investir, fugir; os numeros continuam nos `@export` de cada inimigo |
| Chefe do andar 1 | `src/enemies/boss_guardiao_01.gd` + `dados_boss_guardiao_01.tres` |
| **Trocar QUEM e o chefe do andar** | o grupo apontado por `inimigos` em `src/mapa/tipo_boss.tres` |
| **Ajustar o chefe sem jogar a run inteira** | `godot --path . tools/chefe/arena_chefe.tscn -- --hp=0.32` entra na fase 3 direto; sem janela ele varre os quatro pontos e imprime o relatorio |
| Chefe antigo, hoje fora do andar 1 | `src/enemies/diretora.gd` |
| **Como QUALQUER inimigo avisa um ataque** | `src/enemies/telegrafo.gd` -- linha, mancha no chao ou pulso de sprite, sempre nas mesmas quatro fases |
| **Quanto tempo a brasa do Parasita fica no chao** | `tempo_residual` no `@export` do `src/enemies/hacker_parasita.tscn`; zero desliga |
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
| **Prop de cenario que se MEXE (ventilador, luz, pistao)** | `regioes_props_animados` no `src/mapa/tipo_*.tres`: uma regiao a mais na lista, e nada de cena nova |
| **Quantos props podem se mexer numa sala** | `max_props_animados` no `tipo_*.tres` -- e o orcamento, e ele e baixo de proposito |
| **Textura de chao, parede e props de um tipo de sala** | grupo `Visual` do `tipo_*.tres`. Chao e parede sao LISTAS: a sala sorteia a variante por `hash(coordenadas_grid)`. Os PNGs sao arte autorada passada por `tools/texturas/preparar_textura.py`; porta e props ainda saem do gerador |
| **Arte de chao ou parede que nao nasceu na paleta** | o pre-passo de `preparar_textura.py`: `--desvinheta` (chapa a iluminacao), `--tingir GRAUS` + `--limiar-neon` (tinge o metal apagado e deixa o acento aceso intacto), `--grampear-matiz`, `--alvo-v`. Tudo desligado por default |
| **Prop volumetrico novo** | desenhar na celula do `props_volume.png` ancorado no FUNDO dela, e declarar a regiao em `regioes_props_volume` do `tipo_*.tres` |
| **Prop que so pode aparecer uma vez por andar (o Robo Desativado)** | `regioes_props_raras` do `tipo_*.tres`; quem escolhe a sala e `GerenciadorMapa._sortear_celula_de_prop_raro()` |
| **Uma cor nova no cenario** | `tools/texturas/paleta.gd` + a tabela de `docs/IDENTIDADE_VISUAL.md`; `teste_texturas.gd` recusa cor que compete com projetil |
| Enquadramento e cores do minimapa | `@export` do no `Minimapa` em `src/ui/hud.tscn` |
| **Volume, buses e quem toca o que** | `src/autoload/audio.gd`; os tres volumes ficam em `Configuracao`, junto das outras preferencias |
| **Os sons do andar 1** | `tools/audio/gerar_sons.gd` -- procedural, como o gerador de texturas. Rode e regrave; nunca edite o `.wav` a mao |
| **O ambiente que toca num andar** | `ambiente_do_andar` no no `GerenciadorMapa` do `main.tscn` |
| **O som de cada fase do chefe** | `som_por_fase` no `src/enemies/boss_guardiao_01.tscn` |
| Preferencias do jogador (tela cheia, acessibilidade, idioma) | `src/autoload/configuracao.gd` — grava em `user://config.cfg` |
| **Texto de tela, em qualquer idioma** | `tools/i18n/gerar_csv.py` e rodar; nunca editar `locale/textos.csv` a mao |
| **Idioma novo** | acrescentar em `Configuracao.IDIOMAS` + uma coluna no gerador do CSV |
| Quantas salas o andar tem e o vao do corredor | `@export` do no `GerenciadorMapa` em `src/main/main.tscn` |
| Tamanho de uma sala | os `points` do Line2D `Parede` — multiplos de 16, dimensao multipla de 32 |
| Resolucao base | `[display]` do `project.godot` — 960x544, camera em zoom 1.0 |
| Forma e parede de uma sala | Line2D `Parede` em `src/mapa/sala_*.tscn` — a colisao nasce dele |
| **Quanto a porta demora para abrir** | `TEMPO_DE_ABERTURA` em `src/mapa/porta.gd` -- const e nao `@export`, com teto cobrado por `teste_porta.gd` |
| **O som do motor e da trava da porta** | `som_do_motor` e `som_da_trava` no `src/mapa/porta.tscn` |
| **Como a arena do chefe reage as fases** | `@export` do no `ReacaoDeArena` em `src/mapa/sala_6_boss.tscn` |
| **Quanto o chefe demora para acordar na baia** | `tempo_despertar` no `src/enemies/boss_guardiao_01.tscn` |
| **O trecho de corredor que anuncia o chefe** | `Corredor.pre_chefe`, decidido por `GerenciadorMapa._e_trecho_pre_chefe()`; as texturas em `TEXTURA_*_CHEFE` do `corredor.gd` |
| Lockdown e abertura de porta | `src/mapa/sala.gd`, `src/mapa/porta.gd` e a barreira fisica de `src/mapa/porta.tscn` |
| Glitch de alucinacao | `assets/shaders/glitch.gdshader` |

**Balanceamento quase nunca exige codigo.** Se a resposta a um pedido de tuning
for "vou editar um `.gd`", verifique antes se nao deveria ser um `.tres`.

## Antes de entregar qualquer alteracao

```bash
godot --headless --path . tools/teste_fumaca.tscn      # precisa imprimir PASSOU
godot --headless --path . tools/combinacoes/combinacoes.tscn  # se mexeu em inimigo
godot --headless --path . tools/chefe/arena_chefe.tscn        # se mexeu no chefe
godot --headless --path . tools/audio/gerar_sons.tscn         # se mexeu no gerador de som
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
- **O `Audio` PUXA a preferencia, como o `Juice`.** `Configuracao` e registrado
  ANTES dele no `project.godot`, entao no `_ready` dela este autoload ainda nao
  existe -- e a mesma armadilha, no mesmo lugar. Quem vem depois puxa no proprio
  `_ready`; `EventBus.configuracao_mudou` cobre o runtime.
- **O slider de volume e LINEAR e passa por `linear_to_db()`, entao 0,8 nao
  quer dizer 80%.** Da -1,94 dB, que e 97% do fundo de escala -- o padrao antigo
  parecia moderado no menu e entregava praticamente o maximo. Junte a isso que
  `gerar_sons.gd` normaliza TODO som para -3 dBFS e que ate 12 vozes tocam
  juntas sem limitador: dois tiros no mesmo frame estouravam o fundo de escala.
  Nao era "um pouco alto", era clipping. Os padroes de hoje (0,70 / 0,45 / 0,30)
  saem de uma conta e nao de gosto: um SFX sozinho fica em -13,0 dBFS e QUATRO
  simultaneos chegam a -1,0 dBFS, logo abaixo do teto. `teste_audio.gd` refaz a
  conta a partir dos padroes, entao mexer neles sem refazer a conta reprova.
- **`definir_ambiente()` tem de ter par, e o par nao mora nos botoes de sair.**
  Os `AudioStreamPlayer` moram no AUTOLOAD e nao na cena, entao
  `change_scene_to_file()` libera o `GerenciadorMapa` e o ambiente segue tocando
  -- com o loop LIGADO, que e justamente o que `definir_ambiente()` forca. O som
  do setor ficava em laco por cima do menu inicial, para sempre. Quem liga
  desliga: `GerenciadorMapa._exit_tree()` chama `Audio.silenciar()`, e vale para
  toda saida (menu, tela de fim, reinicio) sem depender de ninguem lembrar.
  Espalhar isso pelos dois botoes de "voltar ao menu" e o desenho que ja perdeu
  o `terminar_run` uma vez, com sintoma silencioso.
- **Volume zero tem de MUTAR o bus, e nao ir para -60 dB.** `linear_to_db(0)`
  devolve -inf, mas qualquer epsilon acima de zero vira -60 dB -- audivel num
  fone. Um "desligado" que ainda se ouve e pior que nao ter a opcao: o jogador
  acha que o jogo esta quebrado.
- **O loop do ambiente e forcado por quem TOCA, nao pelo arquivo.**
  `AudioStreamWAV.save_to_wav()` grava um RIFF simples, sem o bloco `smpl` de
  onde o importador leria a marca de loop -- o `.wav` chega com loop DESLIGADO
  por mais que o gerador tenha pedido. O sintoma seria o setor ficando mudo
  depois de seis segundos, sem uma linha no console. `Audio.definir_ambiente()`
  liga o loop na hora de tocar.
- **Som e `.wav` PCM, e nao OGG.** O import de OGG depende de um decodificador
  no runtime, e a build que vai para o testador e a WEB. Os sete sons do andar 1
  somam poucas centenas de KB.
- **A saida headless avisa "ObjectDB instances were leaked" desde que o audio
  existe.** Sao os `AudioStreamPlaybackWAV` dos players que tocaram, liberados
  DEPOIS da varredura de objetos do Godot -- ordem de desligamento do driver de
  audio headless, e nao um no esquecido na arvore. `Audio._exit_tree()` ja para
  e libera os players na mao e nao resolve. O codigo de saida continua ZERO e o
  CI passa; se um dia isso mascarar um aviso de verdade, o caminho e nao tocar
  som em suite.
- **Prop animado e CHAPADO por construcao, e isso nao e escolha de arte.** Ele
  mora em `Z_CHAO_DETALHE`, abaixo de `Z_MUNDO` -- que e onde ficam telegrafo,
  projetil e atores. E o que torna "animacao de cenario nao cobre telegrafo"
  uma garantia GEOMETRICA em vez de uma intencao. Dar volume a um prop animado o
  levaria para `Z_MUNDO` e reabriria a pergunta, entao isso e uma decisao e nao
  um ajuste.
- **"Se tudo se mover, nada parece importante" e um NUMERO, nao uma opiniao.**
  `max_props_animados` limita quantos props se mexem por sala, e o default e 2.
  Opiniao nao sobrevive a proxima pessoa que achar o ventilador bonito, e o que
  ela custa nao aparece no console: movimento no cenario compete com movimento
  de PROJETIL. `teste_props_animados.gd` cobra que o teto MORDE -- teto que
  nunca e alcancado e teto que nunca foi testado.
- **Animacao de cenario fica FORA do `Juice`.** O hitstop congela o combate de
  proposito, mexendo em `Engine.time_scale`; um ventilador que trava junto
  denuncia o truque -- o jogador ve o mundo inteiro parar e entende que aquilo e
  um efeito, e nao um impacto. `PropAnimado` le `Time.get_ticks_msec()`, pela
  mesma razao que `Juice.INTERVALO_HITSTOP` e `InimigoBase.INTERVALO_FLASH`.
- **O clarao de dano tem DUAS guardas, e a primeira sozinha nao basta.**
  `_tween_flash.is_valid()` impede EMPILHAR, mas nao impede ENCADEAR: com dano
  continuo o proximo acerto liga um clarao novo no instante em que o anterior
  acaba, e o inimigo fica branco PERMANENTE. O comentario antigo dizia que isso
  estava resolvido e nao estava -- apareceu no chefe do andar 1, que saia lavado
  de branco nas capturas em vez de enferrujado. A segunda guarda e
  `INTERVALO_FLASH`, em relogio de PAREDE pela mesma razao do
  `Juice.INTERVALO_HITSTOP`: um timer da arvore andaria devagar durante o
  hitstop que o proprio dano acabou de pedir.
- **Sobre ARTE, o sinal de desgaste e o que se ACRESCENTA.** Com placeholder de
  poligono, "a placa caiu" era esconder um no; com a carcaca desenhada, esconder
  um poligono por cima dela nao tira nada, porque as placas ja estao pintadas.
  O que le e a fumaca aparecendo e o remendo de motor exposto -- e
  `estado_de_desgaste()` devolve os tres estados que a BOSS 10 pede, cobrados
  por nos diferentes e nao por um numero interno.
- **Ator grande passa pelo GERADOR, com moldura propria -- nao vira arte
  autorada.** A Diretora e o contra-exemplo inteiro: sprite de 192x192 num no
  `Visual/SpriteDiretora`, entao `InimigoBase._corpo` procura `Visual/Corpo`,
  nao acha, e o tint de Hack e de nanite nao pintam nela; e o portao de origem
  a pula em silencio. O chefe do andar 1 tem moldura 160 declarada em
  `MOLDURAS`, que e 2x a de 80 -- a proporcao entre chefe e jogador fica a mesma
  em pixels e em moldura, e a escala continua INTEIRA.
- **A base de uma moldura sai de `Direcoes.base_de_quadro()`, nao de uma
  constante por tamanho.** Com 80 da os 36 de sempre; com 160 da 76. Duas
  constantes soltas fariam a proxima moldura entrar com o numero calculado a
  mao, e um erro de 4 px na ancora so aparece quando dois corpos se cruzam em
  movimento.
- **Chefe sem arte tem de estar DECLARADO em `SEM_ARTE_AINDA`.** O portao de
  origem pula `Visual/Corpo` que e `Polygon2D` -- certo para os inimigos
  desenhados em volta da propria origem, e foi tambem como a Diretora passou
  anos fora da ancora. Um chefe nao pode cair nessa categoria por acidente:
  sprite grande fora da ancora e o caso em que o Y-sort mais erra. Tirar o nome
  da lista e o interruptor de "a arte chegou".
- **A Diretora esta ENGAVETADA, e `teste_diretora.gd` e o que a segura.** Ela
  saiu do andar 1 (BOSS 11) mas continua intocada em disco, sem sala que a
  chame. Codigo que ninguem roda apodrece: um refactor em `InimigoBase`, na
  `Arma` ou na `Balistica` a quebraria e ninguem descobriria, porque nenhuma run
  passa por ela. NAO tire aquela suite do runner "porque ela nao e usada" -- e
  justamente por nao ser usada que ela precisa continuar rodando.
- **O chefe do andar e reconhecido por `nome_exibicao`, e as fases dele sao
  DECLARADAS.** `teste_fumaca.gd` acha o chefe por
  `inimigo.get("nome_exibicao") != null` e exige que todas as viradas tenham
  acontecido -- com o numero cravado, trocar de chefe reprovava o chefe certo,
  porque a Diretora tem quatro fases e o Automato tem tres. Quem declara e
  `total_de_fases`, no proprio chefe.
- **Chefe novo tem de emitir os tres sinais da HUD.** `boss_revelado` acende a
  barra dele, `boss_vida_mudou` a move e `boss_fase_mudou` marca a virada. A HUD
  nao sabe qual chefe esta na sala e nao precisa saber -- mas um chefe que nao
  emite entra na luta sem barra nenhuma, sem erro no console.
- **O vies de distancia do chefe NAO vale na fase 1.** E a licao do
  `PerfilJogador` aplicada a selecao de ataque: ele so corrige com CONFIANCA,
  depois de ver o jogador se mexer. A fase 1 existe para ENSINAR, e um chefe que
  ja escolhe bem no primeiro terco pune um habito que o jogador nao teve chance
  de formar -- ele parece burro porque precisa parecer. A MEMORIA, essa sim,
  vale desde a fase 1: nao repetir e legibilidade e nao esperteza.
- **O desgaste visual do chefe NUNCA decresce.** Placa que caiu nao volta. Se
  ele seguisse a vida para cima, curar o chefe remontaria a carcaca e o jogador
  leria isso como o chefe se recuperando -- o oposto da ficcao, em que o dano e
  o que o destrava. Mesmo padrao da deterioracao visual das salas.
- **Efeito de fase do chefe desenha ABAIXO de `Z_MUNDO`, com teto de alpha.**
  Zero e a faixa do telegrafo, dos projeteis e dos atores; um efeito ali poderia
  cair na frente de um projetil e o jogador perderia justamente o que precisa
  ler. A garantia e geometrica e nao de bom senso: `Z_EFEITO = -1` e
  `ALPHA_MAXIMO_EFEITO`, na mesma ideia do `alpha_maximo` do shader de glitch.
- **Suite que monta inimigo tem de APONTAR o alvo a mao.** O grupo "player" e
  global e outras suites deixam bonecos nele enquanto o coletor nao passa;
  `_procurar_alvo()` devolve qualquer um. Escrevendo `teste_boss_selecao.gd` o
  chefe media a distancia ate o jogador de OUTRO teste, a 91 mil px -- tudo era
  "longe" e o vies de distancia parecia nao existir. Mesma loteria que o
  `container_projeteis` ja cobrou.
- **LEQUE e ANEL tem passos diferentes, e confundi-los apaga o padrao.** O anel
  divide 360 pela contagem; o leque divide a ABERTURA por `contagem - 1`.
  Alternar um leque com o passo do anel gira demais e a segunda salva cai EM
  CIMA da primeira em vez de nos vaos dela -- o oposto do que a alternancia
  existe para fazer. Aconteceu na primeira versao da rajada do chefe, e o unico
  sintoma era o padrao nao aparecer. Por isso ha
  `Balistica.alternancia_de_passo()` ao lado de `alternancia()`.
- **A cadencia da ARMA nao pode ser o que limita uma salva por script.** A
  sucata do chefe tinha `cadencia = 3.0` (0,33 s entre tiros) e o chefe pede
  beats a cada 0,28 s: a segunda e a terceira rajada eram recusadas por
  `pode_atirar()` e sumiam em SILENCIO -- sem erro, sem nada na tela, so um
  ataque que "as vezes sai menor". Quem espaca beat e o inimigo; a arma so
  precisa nao atrapalhar. `teste_boss_ataques.gd` cobra isso contra o intervalo
  mais curto que o chefe consegue produzir (fase 3 com a barra cheia).
- **O aviso do soco e uma `AreaDePerigo` reusada, e a economia nao e de
  linhas.** Ela ja carrega as tres armadilhas registradas daquele ataque
  resolvidas: nao estoura no `_ready`, varre com `intersect_shape` em vez de
  `get_overlapping_bodies()`, e desenha na faixa do mundo pelo `Telegrafo`.
  Escrever um circulo proprio ali reencenaria os tres bugs de uma vez.
- **Suite que dispara arma nao pode assumir o proprio
  `container_projeteis`.** `Arma._container()` resolve por
  `get_first_node_in_group()` no instante do disparo, e a ORDEM de um grupo no
  Godot nao e a de insercao -- um container vazado de outra suite vem na frente.
  Escrevendo `teste_boss_ataques.gd` foi exatamente isso: a rajada "nao
  disparava", e os projeteis caiam na caixa da suite anterior. Pergunte a arma
  onde ela vai colocar (`arma._container()`) em vez de adivinhar.
- **O multiplicador de fase do Automato tem de alcancar TEMPO e MOVIMENTO ao
  mesmo tempo.** So no movimento, o jogador ve um robo andando rapido com
  ataques no mesmo ritmo; so nos tempos, um robo lento com ataques nervosos. Nos
  dois, ele ve a frase que o chefe existe para produzir: "eu ja conheco esse
  ataque, mas agora ele esta acontecendo mais rapido". Todo tempo dele passa por
  `tempo_real()`, e e isso que faz o moveset ficar reconhecivel e mais rapido em
  vez de virar outro moveset.
- **O pior caso do chefe NAO e o multiplicador de fase 3.** A Deterioracao
  multiplica dificuldade por cima dele e chega a 1,7x em cadencia, entao o pior
  caso e 1,30 combinado com a barra cheia. `tempo_real()` divide pelos DOIS e so
  entao aplica o piso -- um piso conferido so contra 1,30 passa no teste e fura
  em jogo.
- **A fase do chefe muda na ENTRADA da transicao, e nao quando o HP cruza o
  limiar.** Subindo `fase_chefe` no `_checar_fase`, o ataque em curso terminaria
  com o timing da fase NOVA no meio do proprio gesto: o jogador leria o
  telegrafo de uma fase e levaria o golpe de outra. E a bandeira
  `_fase_anunciada` faz cada virada acontecer UMA vez -- sem ela, o HP oscilando
  em volta do limiar reentraria na transicao a cada frame e o chefe nunca mais
  atacaria.
- **A vitoria da run NAO sai da morte do chefe.** Quem chama
  `GameState.terminar_run(true)` e o `GerenciadorMapa`, quando a sala do tipo
  `boss` fica LIMPA. Trocar quem e o chefe do andar nao mexe nesse caminho, e e
  bom que seja assim -- mas a chamada ja se perdeu uma vez ao trocar quem
  hospeda a run, com sintoma silencioso, e por isso `teste_boss_guardiao.gd`
  cobra os dois lados: que o GerenciadorMapa ainda chama, e que o chefe NAO
  chama.
- **Cor de ator nova entra em `Paleta.ATOR`, senao `teste_texturas.gd`
  reprova.** O espelho existe para provar que ambiente e ator nao se cruzam, e
  ele pegou o Automato no primeiro `--import`. A escolha de matiz e por
  eliminacao e vai comentada junto: o andar 1 ja gasta o laranja duas vezes
  (drone 25 graus, besta 14), e um terceiro laranja no CHEFE seria a peca mais
  importante da sala usando a cor mais repetida dela.
- **"Situacao inevitavel" tem numero, e o numero nao e "zero saidas num
  frame".** O rolamento da i-frames pela duracao inteira (0,22 s mais 0,06 s de
  graca), entao uma JANELA CURTA sem saida a pe nao e injustica: e o momento em
  que o jogo cobra o rolamento. O que reprova em
  `tools/combinacoes/combinacoes.tscn` e a janela ser MAIS LONGA que esses
  i-frames -- ai nem rolar salva. Contar frame isolado reprovava a Cyber-Besta em
  toda combinacao: uma vez comprometida com a investida ela e mais rapida que o
  andar do jogador, e ~0,26 s sem saida a pe e o desenho dela, com o aviso de
  0,8 s antes sendo onde a decisao acontece.
- **Na `MedidorEscape`, ameaca PARADA e ameaca em MOVIMENTO sao perguntas
  diferentes.** O circulo do Hacker fere num instante, entao so o FIM do
  horizonte importa -- sair de dentro dele antes de estourar e a jogada que o
  telegrafo existe para permitir. O projetil fere no CONTATO, entao o caminho
  inteiro conta. A primeira versao da regua tratava as duas igual e reprovava as
  CINCO combinacoes, inclusive as que nao tem como ser inevitaveis: quem estava
  dentro de um aviso nunca "escapava". Regua que reprova tudo mede a si mesma, e
  regua que nao reprova nada e um carimbo -- `teste_combinacoes.gd` guarda os
  dois lados.
- **O telegrafo encurta com a barra, mas o PISO nao mora na Deterioracao.**
  `Deterioracao.multiplicador_telegrafo()` responde "quanto encurta", que e
  tuning; quem garante que ele nao SOME e `Telegrafo.duracao_segura()`, aplicado
  por `InimigoBase.duracao_do_telegrafo()`. Um piso escrito no autoload poderia
  ser contornado por quem multiplicasse a duracao noutro lugar -- e telegrafo
  que some e a fronteira entre "dificil" e "mente sobre a propria regra". Todo
  inimigo que avisa passa por `duracao_do_telegrafo()`, e e isso que torna a
  trava cobravel: `teste_escalonamento.gd` varre a barra de 0 a 100 de 5 em 5,
  porque um piso escrito como `if valor > 90` passaria testando so as pontas.
- **O sentinela de "nao escalona" e NEGATIVO, nunca zero.** Zero e destino
  valido em quase todo campo de `Escalonamento` -- uma Sentinela com
  `tiros_ate_salva_avancado = 0` raja toda vez. Com zero desligando, aquele
  ajuste viraria silenciosamente "nao faz nada".
- **A duracao do aviso e fixada na ENTRADA do estado, nao recalculada todo
  frame.** A barra sobe durante a propria carga: recalcular faria o aviso
  encolher enquanto o jogador o le, e o telegrafo existe justamente para ser
  previsivel. O Drone guarda isso em `_aviso_atual`.
- **A Cyber-Besta escala a investida em DURACAO, nunca em velocidade.**
  Velocidade maior encurtaria a janela de leitura que o agachamento abriu;
  duracao maior cobra a mesma leitura de mais longe. E a recuperacao encolhe
  junto, mas nao some -- acertar a esquiva tem de continuar rendendo.
- **`DadosInimigo` e aplicado no TOPO do `_ready()`, e a linha seguinte
  congela.** `InimigoBase._ready()` faz `vida = vida_maxima` logo abaixo de
  `_aplicar_dados()`. Invertidas as duas, todo inimigo com `.tres` nasceria com
  a vida do DEFAULT do script -- 5 para todo mundo -- e a Cyber-Besta, que tem
  8, viraria de vidro sem uma linha no console. E o mesmo padrao que o Player ja
  paga com `_vida_maxima_base`.
- **`dados` e OPCIONAL, e tem de continuar sendo.** Sem recurso valem os
  `@export` da cena, e e por isso que o Rastejante, o Vigia, a Diretora e as
  pecas da arena dela seguem funcionando sem `.tres` nenhum. Torna-lo
  obrigatorio quebraria quem ainda nao migrou.
- **Numero que foi para o `.tres` tem de SAIR do `.tscn`.** Deixado nos dois, o
  da cena e simplesmente sobrescrito em runtime: nenhum teste de comportamento
  acusa nada, e o proximo a girar aquele botao no Inspetor da cena passa uma
  tarde sem entender por que nao muda nada. `teste_dados_inimigo.gd` le o fonte
  do `.tscn` justamente porque isso nao da para cobrar de outro jeito.
- **A traducao de nome mora em `_ler_dados()`, um por inimigo.** O recurso fala
  generico (`distancia_preferida`, `tempo_telegrafo`) e cada inimigo fala o
  proprio dominio (`raio_orbita`, `tempo_clarao`). Espalhar o `dados.` pelo
  comportamento acabaria com um `if dados != null` em cada estado.
- **Se entrar enum em `DadosInimigo`, valor novo entra NO FIM.** Enum e gravado
  como INT no `.tres`; inserir no meio reescreve em silencio o significado de
  todo inimigo ja salvo. Mesma armadilha de `DadosArma.Comportamento` e
  `DadosItem`.
- **Movimentacao nova nao se escreve na mao: usa-se o `Movimento`.** Cinco
  inimigos tinham a propria copia da tangente mais correcao radial, com nomes
  diferentes para a mesma coisa. Duas copias divergem, e o sintoma aparece em
  TELA e nunca no console -- um inimigo passa a orbitar de um jeito e o outro de
  outro, e a leitura do campo muda sem ninguem ter decidido isso. Mesma historia
  do mapa de angulo -> quadro antes de virar `src/util/direcoes.gd`.
- **Nenhum verbo de `Movimento` recebe velocidade pronta.** Todos recebem o
  INIMIGO e chamam `velocidade_atual()` no frame -- e e essa funcao que le a
  Deterioracao. Uma assinatura `orbitar(velocidade: float, ...)` convidaria o
  chamador a calcular uma vez e guardar, e a barra subindo deixaria de afetar
  quem ja esta em tela. A unica excecao e `investir()`, e ela e declarada: a
  velocidade de investida e numero proprio do `.tres`, nao deriva de
  `velocidade_base` e NAO escala com a barra de proposito -- uma investida que
  acelera junto deixa de ser esquivavel pelo timing que o jogador aprendeu.
- **`Movimento.investir()` tambem nao passa por `direcao_de_locomocao()`.**
  Durante a investida o inimigo nao contorna nada, e e isso que torna o ataque
  legivel e faz a parede virar recurso do jogador -- bater nela e a principal
  janela de contra-ataque que a Cyber-Besta oferece.
- **`Movimento.orbitar()` tem DOIS temperamentos, e trocar um pelo outro
  empilha inimigo.** `banda = 0` corrige proporcionalmente e converge para um
  raio EXATO (e a Sentinela); `banda > 0` deixa uma faixa morta em que ele so
  circula (e o Drone, por `orbitar_na_faixa`). Dar raio exato ao Drone faria
  todos convergirem para a mesma circunferencia -- o empilhamento de novo, so
  que em anel. E `raio = 0` nao e caso degenerado: e "circula fechando", que e o
  `OBSERVAR` da Cyber-Besta.
- **O Rastejante e o Vigia ficam FORA do vocabulario, de proposito.** E a mesma
  razao que os mantem fora de `direcao_de_locomocao()`: eles sao a base que o
  playtest da v0.2.0-alpha validou, e mexer neles sem uma segunda rodada
  invalidaria aquele retorno.
- **Telegrafo novo nao se escreve na mao: usa-se o `Telegrafo`.** Eram sete
  implementacoes da mesma ideia, e as duas que quebraram quebraram em silencio
  -- a `AreaDePerigo` desenhando abaixo do chao, e aviso aceso que nao apaga. As
  quatro invariantes moram no componente: faixa `z` ABSOLUTA (`z_as_relative`
  desligado, senao o aviso herda a camada de quem o pendurou), `top_level`
  sempre (aviso que herda a rotacao de um `Visual` e aviso que mente), `apagar()`
  amarrado no `sair` da `MaquinaEstados`, e o piso de `DURACAO_MINIMA` aplicado
  DENTRO de `acender()`.
- **Quem ESPERA o aviso terminar tem de esperar `Telegrafo.duracao_segura()`.**
  O piso levanta um `tempo_clarao` de 0,28 s ate 0,35 s. Aplicado so no desenho,
  o tiro sairia antes de o telegrafo acabar -- o aviso terminando DEPOIS do
  ataque que ele avisa. Por isso `SentinelaOrbital._duracao_do_aviso()` passa
  pelo piso, e por isso o Vigia e o Neon disparam por
  `_telegrafo.avancar(delta) >= 1.0` em vez de um contador paralelo.
- **`InimigoBase.morrer()` apaga os telegrafos filhos, e isso nao e redundante.**
  `queue_free()` e diferido: o no ainda desenha no frame em que morreu. A
  garantia mora na BASE de proposito -- na subclasse, o proximo inimigo com
  telegrafo que esquecesse de sobrescrever `morrer()` traria o defeito de volta.
- **A brasa do Parasita nasce DESLIGADA na `AreaDePerigo`.** `tempo_residual` e
  zero por padrao porque a mesma cena serve a Rede de Exterminio e o Colapso da
  Diretora, e o repertorio dela foi medido sem brasa. Quem liga e o Parasita,
  para quem ela e a razao de existir: sem a zona residual o estouro e um
  instante, e o inimigo de controle territorial nao controla nada.
- **A brasa ignora `body_entered` de proposito.** Se o sinal valesse nela,
  atravessar a mancha custaria o mesmo que ficar parado dentro -- e a brasa
  existe justamente para separar as duas coisas. Quem passa correndo tem de
  conseguir passar; quem fica paga no tique de `intervalo_residual`, que fica
  uma ordem de grandeza acima de `Juice.INTERVALO_HITSTOP` para dano continuo
  nunca encadear hitstop.
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
- **`_vaos_no_trecho()` vale para o VISUAL tambem, e por seis issues nao valeu.**
  Ela e `_subtrechos()` cortam o lado da sala nas portas, e ate a PAR 01 tinham
  UM consumidor: a colisao (`sala.gd:704`). `_montar_faces` usava o par de
  vertices cru, entao o quad de face atravessava a porta inteira -- duas
  respostas para "onde ha parede". Como so o lado NORTE ganha face
  (`LIMIAR_LADO_NORTE`), era la que o modulo autorado aparecia DENTRO do batente,
  e a porta lia como uma janela para a parede. O TOPO continua inteiro de
  proposito: sobre a porta ha verga, e a superficie de cima atravessa o vao de
  verdade. Quem tem abertura e a face.
- **Arte autorada pode PERDER uma peca que a versao gerada tinha.** A
  `porta_moldura.png` da LTD 11 e boa arte e tem um buraco literal: 32x34 px de
  alfa zero. A moldura GERADA que ela substituiu preenchia o vao com N0 opaco --
  `gerar_porta_moldura()` ainda tem a linha, comentada como "corredor nao
  revelado e escuridao" --, e a migracao levou junto o preenchimento sem ninguem
  notar, porque nenhum portao perguntava "o que ha atras deste furo?". Hoje quem
  pergunta e `teste_porta.gd:_o_recesso_cobre_o_vao_da_moldura`, que cruza as
  coordenadas locais das DUAS imagens em vez de comparar numeros escritos a mao.
- **Furo de arte tem de ser cercado nos QUATRO lados para contar como vao.**
  Cercar so na horizontal acha 1240 px de "abertura" numa moldura cuja porta tem
  1088, e os 152 restantes nao sao defeito: a linha 6 e o vao ENTRE os blocos de
  canto (ali se ve a parede de proposito) e as linhas 65-67 estao abaixo da
  SOLEIRA, ja dentro da sala, onde o que tem de aparecer e o chao. So a porta e
  fechada em cima, embaixo e dos dois lados.
- **Teste que conta POLIGONOS de face conta a coisa errada.** A pergunta e sempre
  "quantos MODULOS a sala veste", e a contagem de filhos de `ParedeFace` era um
  atalho: com a face abrindo no vao, um lado com porta no meio vira DOIS quads da
  mesma textura. `_texturas_de_face` deduplica por isso -- senao a resposta muda
  quando uma sala ganha uma porta, sem nada sobre a arte ter mudado.
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
- **O nucleo do chefe fica APAGADO enquanto ele dorme na baia.** A apresentacao
  dele e o jogador acreditar que o robo e CENARIO, e um chefe que pulsa antes de
  acordar entrega o truque no primeiro quadro. E a partida FALHA duas vezes
  antes de pegar -- a falha e a peca, e nao o ruido: uma maquina que liga de
  primeira e uma maquina nova.
- **Efeito de arena fica junto da PAREDE, nunca no miolo.** A sala do chefe e a
  mais densa de projetil do jogo, e a fase 3 e quando os dois riscos se somam --
  mais efeito e mais projetil na tela, no mesmo instante. `ReacaoDeArena` nasce
  as luzes no contorno lido de `Sala.contorno_local()` (a mesma fonte da colisao
  e do minimapa) e `teste_props.gd` mede a distancia: o miolo, onde o jogador
  esquiva e o telegrafo desenha, fica limpo.
- **Decalque da sala do chefe nao pode ser amarelo.** A faixa dela e 330-355, e
  faixa de perigo amarela cai em 25-50 -- a da sala de ARMA. A baia le por FORMA
  (retangulo com listras e ancoras nos cantos) e nao por matiz, que e a mesma
  licao que a ferrugem da face ja tinha ensinado.
- **O corredor pre-chefe e a UNICA excecao a regra da noite base, e ela e
  deliberada.** Corredor comum nao veste a cor da sala vizinha de proposito --
  "pintar cada metade com a cor da vizinha anunciaria o que ha do outro lado
  antes de o jogador chegar". No ultimo trecho anunciar E o objetivo. So o
  ultimo: um andar que escurecesse a cada sala anunciaria o chefe desde a
  terceira porta, e a virada deixaria de acontecer num lugar so.
- **`celula_do_chefe()` devolve ZERO quando NAO ha chefe, e ZERO e uma celula
  valida** -- a inicial mora nela. Quem compara com o retorno dela precisa
  conferir a reserva antes; sem isso, um andar sem chefe veste os corredores da
  ENTRADA com as texturas dele.
- **O escurecimento do trecho pre-chefe vai no CHAO, nunca no corredor.**
  Escurecer o no inteiro levaria junto projetil e telegrafo que passam por ali, e
  a regra do projeto e que efeito que atrapalha a leitura do combate e efeito
  cortado. Escurecendo so o chao, o que muda e o FUNDO contra o qual eles sao
  lidos.
- **A abertura da porta e LEITURA, e nao pedagio.** A barreira cai no PRIMEIRO
  quadro, antes de a animacao rodar -- quem quer correr atravessa ja, e ve a
  porta terminar de abrir pelas costas. Se a passagem so liberasse no fim, cada
  porta cobraria a propria duracao em toda travessia: dez salas por andar
  transformam meio segundo em cinco segundos parados, num jogo cuja dificuldade
  sobe com o TEMPO. E o teto e `const` e nao `@export` de proposito -- limite de
  design nao e botao de tuning, e um numero ajustavel seria ajustado para cima na
  primeira vez que alguem achasse a animacao bonita.
- **Atlas de prop CRESCE para baixo; nunca se recompoe.** As regioes ja
  declaradas nos `tipo_*.tres` sao coordenadas cruas, e a ancora depende delas:
  a arte encosta no FUNDO da celula e a sala desloca o sprite em `-altura/2`.
  Recompor centralizando, ou remanejar celulas, faz TODOS os props flutuarem sem
  erro no console. Ao acrescentar props, copie as linhas antigas byte a byte e
  confira o hash -- foi assim que o atlas foi de 256x128 para 256x192.
- **Prop novo passa pelo funil SOZINHO, e nao junto do atlas inteiro.**
  `preparar_textura.py` processa a imagem toda: rodar no atlas completo mexeria
  no valor e na saturacao dos doze props ja aprovados. Prepare a tira nova, e so
  entao cole.
- **"Uma por ANDAR" nao e pergunta que a `Sala` responda.** Ela so ve a si
  mesma. Por isso o prop raro tem duas metades: o `GerenciadorMapa` escolhe a
  celula (antes do `add_child`, como `coordenadas_grid`), e a sala tem um PORTAO
  -- sala nao autorizada nunca desenha a regiao rara, por mais que sorteie. Sem
  o portao a regra dependeria de o gerenciador nunca errar, e regra que depende
  de ninguem errar nao e regra.
- **`--sem-costura` e para arte que JA NASCE ladrilhavel.** A face base do
  andar 1 usa a bandeira porque foi desenhada assim; arte gerada nao e, e passar
  a bandeira nela reprova o portao de costura (`costura x=1.23, teto 1.10`).
  Sem a bandeira o funil costura, e o preco e um borrao na juncao -- visivel no
  modulo `ventilada`, cuja grade e horizontal.
- **Densidade de face e o unico numero que a issue pede e o funil NAO cobra.**
  `preparar_textura.py` marca densidade como informativa, e com razao: a face
  excede a faixa de parede de proposito. Mas "os cinco modulos caem na mesma
  faixa" precisava virar portao, senao vira prosa -- `teste_texturas.gd` cobra
  piso (acima do teto de parede, 34%) e teto (1,4x a base). Os dois limites saem
  de decisoes que ja existiam, e nao da amostra medida.
- **Uma sala desenha UMA face, entao cinco modulos nunca aparecem juntos em
  jogo.** `LIMIAR_LADO_NORTE` so veste o lado virado para a camera; a biblioteca
  produz variedade ao longo do ANDAR, com salas vizinhas vestindo modulos
  diferentes. Por isso `sala_prototipo.tscn` tem um MOSTRUARIO: sem ele, ver o
  terceiro modulo exigiria gerar andares ate um cair na sala fotografada.
- **A faixa de matiz de um tipo de sala mora em DOIS arquivos.**
  `MATIZ_POR_TIPO` existe igual em `tools/texturas/preparar_textura.py` (quem
  escreve) e em `tools/testes/teste_texturas.gd` (quem confere). Mudar num so
  deixa o funil produzindo o que o portao recusa -- e o erro so aparece na
  suite, depois de a arte ja estar em disco. A do `andar1` e larga de proposito
  (185-320): ela separa TIPO DE SALA, e quem separa mapa de ATOR e o teto de
  valor (chao em 0,30 contra o piso de 0,55 do portao G2), que nao muda.
- **O TOPO da parede e neutro e compartilhado; quem carrega a identidade do tipo
  e a FACE.** Isso foi decidido na LTD 13 (#43), que entregou os cinco modulos de
  face -- e a segunda metade, trocar o topo, ficou por pagar por seis issues. Ate
  a PAR 04 o topo continuava vestido com `parede_andar1_*` de antes da
  identidade: S medio de 0,75 a 0,93, duas das quatro fora da faixa de densidade
  da familia, e uma delas com 37 pontos de silhueta de projetil. A lista vive em
  `Sala.TOPOS_NEUTROS` e nao copiada nos cinco `tipo_*.tres`: cinco copias da
  mesma lista divergem no dia em que alguem mudar quatro.
- **Textura autorada se gera GRANDE e se reduz no funil -- gerar direto no tile
  final enche cada pixel de detalhe.** Medido na PAR 03: as mesmas ideias em
  64x64 sairam com 55% a 61% de densidade contra a faixa de 18-34% da parede; em
  256x256 reduzidas para 64 pelo BOX do funil, 24% a 31%. E o funil ja dizia isso
  ao explicar por que reduz ANTES de costurar.
- **Suavizar para caber num numero e o jeito errado.** Um filtro de mediana
  derrubou a densidade de 41% para 24% e MATOU a arte: os topos viraram borroes
  sem aresta, que nao leem como metal. Quantizar nao move nada (a densidade e
  espacial, nao de paleta). O proprio `preparar_textura.py` avisa: "uma trava em
  que nao se confia empurra a arte para o lado errado com a autoridade de um
  numero" -- e por isso densidade e informativa la, e nao portao.
- **Baixar saturacao SOBE a densidade.** Nao e contra-intuitivo por acaso: o
  funil renormaliza o valor depois, e o contraste de luminancia cresce. Medido:
  de `--saturacao 0.78` para `0.35`, o mesmo arquivo foi de 33,7% para 41,4%.
- **A contagem de `AUTORADAS` nao acusa arquivo que nunca entrou nela.** Ela
  confere o que esta na lista contra o que foi conferido: um PNG fora da lista
  nao aparece nos dois lados, ele SOME, e a suite fica verde. Os quatro modulos
  de face da AND1 03 e a `baia_chefe.png` da AND1 07 passaram assim -- cinco
  arquivos, tres ondas de arte, nenhum erro no console. Hoje quem fecha isso e
  `_nenhum_png_fica_fora_de_regime()`, que VARRE `assets/texturas/` e exige que
  todo PNG esteja em `AUTORADAS` ou em `GeradorTexturas.nomes()`. Os cinco
  passaram assim que foram conferidos, e e esse o pior caso: o portao nao estava
  barrando arte ruim, estava deixando arte boa passar sem prova.
- **`TETO_VALOR` do teste e GEMEO de `FAMILIAS` do funil, e faltava uma linha.**
  A familia `decalque` nao estava na tabela, entao a `baia_chefe.png` era medida
  contra o default de 0,55 -- quase tres vezes os 0,19 que o funil aplicou ao
  escreve-la. Mesma armadilha que o `MATIZ_POR_TIPO` ja documenta: os dois lados
  tem de mudar juntos, e "esta no funil" nao quer dizer "esta cobrado".
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
- **A selecao de operador nao e uma cena: e um PAINEL do menu.** Quem quiser
  "voltar para a selecao" de outra tela nao tem para onde trocar -- carrega o
  `menu_inicial.tscn` e pede que ele abra o painel. O pedido e a bandeira
  `GameState.abrir_selecao_ao_entrar`, lida por `consumir_pedido_de_selecao()`,
  que LE E APAGA na mesma funcao. Ler o campo cru compila igual e esquece de
  apagar -- e ai a selecao reabre toda vez que o jogador volta ao menu, prendendo
  ele num painel que acabou de fechar, sem erro nenhum no console.
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
- **O `Visual` do Player nao desenha mais nada, e mesmo assim nao pode sumir.**
  A mira deixou de ser o cano ciano preso ao corpo e virou um reticulo colado no
  MOUSE, entao `Aura` e `Cano` sairam da cena. O que sobrou dentro do `Visual` e
  o no `Arma`, em (27, 0) -- e e a rotacao do `Visual` que faz a boca orbitar.
  Apagar o `Visual` por "estar vazio" faria todo projetil do jogador nascer 27 px
  a direita dele, para sempre e sem erro no console.
- **O reticulo e o dono do cursor do sistema.** `src/player/mira.gd` esconde a
  seta enquanto aparece e a devolve ao sair -- inclusive no `_exit_tree`, que e o
  que cobre a troca de cena para o menu. Ele roda em `PROCESS_MODE_ALWAYS` de
  proposito: com a arvore pausada ele ainda precisa rodar para devolver a seta
  ao menu de pausa. Dois cursores na tela e pior que nenhum, e nenhum e pior
  ainda -- um menu sem seta nao da erro, so nao da para usar.
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
- **Inimigo com ARMA no `Visual` precisa de uma TORRE, e nao de parar de girar.**
  Vale para a Sentinela e para o Vigia. A Sentinela pendura `Arma` e `Clarao` em `Visual` numa posicao deslocada, e e
  a rotacao do `Visual` que faz a boca orbitar. Congelar o `Visual` para acomodar
  o sprite faria todo tiro nascer 26 px ao lado dela, para sempre e sem erro no
  console -- a mesma armadilha que o `Sprite` do Player evita saindo de dentro do
  `Visual`. A saida aqui e o contrario: quem SAI e a arma. Um no `Torre` irmao
  gira livre com a boca e o clarao, o `Visual` fica parado com o sprite, e as
  duas resolucoes de mira convivem -- a boca mostra o angulo exato, o corpo
  mostra oito passos. E o `Visual` parado mantem de graca o clarao de dano, o
  pop de nascimento e o canal de tint, que sairiam todos se o sprite virasse
  irmao.

  No Vigia isso e ainda mais critico: o **laser de telegrafo** e desenhado a
  partir de `_arma.global_position`, e ele e a aula que ensina a mira preditiva
  sem tutorial. Boca no lugar errado = a linha saindo do lugar errado, e a
  mecanica central do jogo passa a mentir.
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
- **A torre do chefe SALTA, a da Sentinela interpola -- e a diferenca tem
  motivo.** Na Sentinela o giro suave le como "ela esta calculando". No Automato
  a direcao e TRAVADA na entrada do preparo, e uma torre interpolando ainda
  estaria a caminho no instante do disparo: a boca apontando para um lado
  enquanto a salva sai para outro. Isso troca um desalinhamento fixo por um que
  se MEXE, que e pior de ler. O no `Torre` dele ficou cravado em (0, -84) da
  BOSS 01 ate a ANIM 08, com as duas armas em cima -- todo projetil de RAJADA,
  PISAO e REATOR nascia 84 px acima do centro dele, sem relacao com o lado
  encarado. A DIRECAO dos tiros nunca esteve errada: ela sai do leque, calculado
  de `_direcao_travada`. Era a boca que nao batia com o corpo.
- **Forcar a fase do chefe num teste exige DOIS campos.** `fase_chefe` e o que
  os multiplicadores leem, mas quem GUARDA a transicao e `_fase_anunciada`:
  `_checar_fase()` compara `fase_por_vida()` contra ele e, se a vida ja pede uma
  fase acima, joga o chefe em `TRANSICAO_FASE` no primeiro `_physics_process`.
  Escrevendo `teste_boss_animacao.gd` isso custou tres falhas, e o sintoma
  mandava para o lugar errado: um `PREPARAR` de 0,0167 s (um passo) e so no
  PRIMEIRO ataque de cada canto medido, porque a partir do segundo a virada ja
  tinha acontecido.
- **Progresso de gesto so vale DENTRO do estado.** `progresso_do_gesto()`
  responde pelo estado ATUAL. Amostrado depois de um `_physics_process` que ja
  trocou de estado, ele devolve quase zero -- e num teste que conta reinicios de
  beat aquela queda vira um beat que nunca existiu. Saia do laco antes de
  amostrar, e nao depois.
- **Nos ataques de BEAT o gesto e o BEAT, e nao o estado.** O pisao da fase 3
  sao DOIS pisoes dentro de um `EXECUTAR` so, e a rajada sao ate tres. Um clipe
  esticado sobre o estado inteiro mostraria meio pisao por pisao -- a perna
  subindo no primeiro e descendo no segundo, com o impacto de nenhum dos dois
  caindo no lugar. Mesma distincao que ja separa `Balistica.alternancia()` de
  `alternancia_de_passo()`: a conta e igual, o vao e que nao.
- **O piso de 0,35 s NAO morde no preparo do chefe -- e isso e margem, nao
  garantia.** `tempo_telegrafo` vale 0,80, e o pior caso e
  `0.8 / (1.30 x 1.7) = 0,3620 s`: sobram 12 ms. Quem o piso corta e a EXECUCAO
  (`0.4 / 2.21 = 0,181`). O regime vira se `tempo_telegrafo` cair abaixo de
  **0,7735** -- uma sessao de tuning que o baixe de 0,80 para 0,77 passa a ter o
  preparo clampado, e o gesto termina antes do golpe. Por isso
  `teste_boss_animacao.gd` MEDE a margem em vez de assumi-la. E note que
  `multiplicador_cadencia()` vai a **1,7**, e nao a 1,55 -- esse e o de
  velocidade.
- **A ancora de um CLIPE e do ator, nunca do quadro.** `montar_fita()` ancora
  cada quadro pela base do proprio bbox de alfa, e para caminhada isso e o
  certo: os pes voltam ao chao todo passo. Num GESTO isso CANCELA a animacao --
  subir cada quadro ate a linha dos pes apaga exatamente o agachamento que o
  quadro tinha; num pisao, a perna erguida vira o corpo inteiro descendo. O
  clipe se achata sozinho, sem erro e sem nada em tela que aponte a causa. Por
  isso existe `montar_fita_de_clipe()`, que mede o deslocamento UMA vez, no
  primeiro quadro com desenho, e o aplica a todos. Medido num par sintetico com
  o desenho 20 px mais alto no segundo quadro: o clipe preserva 76 -> 56, a
  caminhada achata para 76 -> 76.
- **Clipe e SUBPASTA, e nao prefixo de arquivo.** `_gif_da_direcao()` casa por
  SUFIXO com prefixo livre -- e o que deixa `Idle_custom-walking_foward_east.gif`
  e `andar_east.gif` conviverem. Com clipe por prefixo, um `abrir_east.gif`
  ordenaria antes de `andar_east.gif` e sairia escrito como `andar_east.png`,
  comendo o ciclo de caminhada em silencio, com o arquivo no tamanho certo e
  passando em todo portao de runtime. Pastas nao colidem. E `andar` e nome
  RESERVADO de clipe: o gerador sai com erro duro se achar um.
- **O modo de um clipe e do GESTO, e nao de quem chama.** Ele mora no
  `ClipeDirecional` e nao num parametro de `encenar()`: com dois chamadores a
  mesma arte poderia rodar por progresso num lugar e por fps noutro, e o sintoma
  seria em TELA e nunca no console. Mesma razao que tirou o mapa de angulos de
  dentro de `DadosPersonagem`.
- **`encenar()` nao da `push_error` quando o gesto falta.** Um erro por frame
  afoga o console e torna a cena inutilizavel no editor, e o dono ja tem para
  onde cair -- `apontar()`. O barulho fica no PORTAO, que cruza os nomes pedidos
  com os clipes declarados sem rodar a luta: quieto em jogo, alto no CI.
- **Arte declarada na cena nao prova que alguem a DESENHA.** O
  `boss_guardiao_01.tscn` declarava as 8 poses e as 8 fitas desde a BOSS 10, e
  `boss_guardiao_01.gd` **nunca chamava `apontar()`** -- nao havia sequer um
  campo `_sprite` nas 1060 linhas dele. O chefe passou a luta inteira no quadro
  que o `_ready()` do `SpriteDirecional` escreve, `south.png` quadro 0:
  deslizando para o norte encarando o sul. Nada acusou, porque os arquivos
  estavam certos, casados e medidos -- e era exatamente isso que a suite
  conferia. **Faltava o CHAMADOR, e chamador ausente nao aparece em teste de
  arquivo.** Hoje quem fecha isso e
  `teste_sprite_direcional.gd:_a_arte_declarada_e_exercitada`, que monta cada
  inimigo, poe um alvo A OESTE e exige duas coisas em 4 s: que o par (textura,
  quadro) mude, e que o corpo DEIXE o sul. O alvo e a oeste de proposito -- ao
  sul, "virou" ficaria indistinguivel de "nunca se mexeu", porque o sul e o que
  o `_ready` ja escreveu. Os 4 s saem do chefe, que nasce dormente e leva 2,0 s
  so para acordar.
- **O portao que existe cravado num inimigo so cobre um inimigo so.** O caso
  acima ja existia em espirito: `_andar_em_qualquer_estado_anima` nasceu de uma
  regressao da Cyber-Besta, com o docstring certo ("a trava e sobre o inimigo
  montado, e nao sobre o sprite solto") e apontado para ela sozinha. O chefe
  quebrou ao lado dele por seis issues. Portao de classe tem de VARRER, como o
  cabecalho da propria suite ja mandava.
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
