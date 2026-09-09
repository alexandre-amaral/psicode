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
| `docs/PIVO_PAREDES.md` | O levantamento por tras do epico das PAREDES: o que o plano pede e o codigo ja faz, as nove formas de sala medidas, e as tres decisoes que precedem o codigo |
| `docs/BRIEFING_PAREDES_FABRICA.md` | **O pedido de arte das paredes**: onde a arte entra no renderizador, os sete portoes que ela tem de passar, os numeros do funil e o prompt de cada modulo. O andar 1 e uma fabrica abandonada e a parede nao diz isso |
| `docs/PROMPTS_FABRICA.md` | **Os prompts do PixelLab para o cenario do andar 1**: o prompt base, um bloco por familia, os parametros de geracao e o funil de cada porte. Prompt novo entra la ANTES de consumir geracao |
| `docs/PLANO_INVENTARIO_CORPORAL.md` | **O plano do inventario corporal e dos dois slots de arma**, em 32 issues `[INV nn]`. Ele registra as tres correcoes que o projeto fez no pedido original -- nomes em portugues, nao existe `RunInventory`, e o F entra sem tirar o Q -- e a medicao que dissolveu o maior risco dele |

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
| **A SILHUETA de um projetil** | `familia_silhueta` em `src/weapons/*.tres`; o desenho de cada familia em `src/util/formas_projetil.gd` |
| **O IMPACTO de um projetil** | `familia_impacto` em `src/weapons/*.tres`; os nove perfis em `src/fx/impactos.gd` |
| **O RASTRO de uma arma** | `rastro_comprimento` em `src/weapons/*.tres` -- **zero desliga, e zero e o default** |
| **A ARTE de um projetil** | `assets/projeteis/`, escrita por `tools/sprites/gerar_projeteis.py`. **Nunca** por `preparar_textura.py` |
| **Ver os projeteis lado a lado** | `godot --path . tools/laboratorio_projeteis.tscn --resolution 960x544`; sem janela ele MEDE e lista colisoes de leitura |
| **A ficha de todo ataque do jogo** | `docs/ATAQUES.md` |
| **Personagem novo** | criar `src/player/personagem_*.tres` e por na lista `personagens` do no `SelecaoPersonagem` |
| **Sprite, miniatura, escala e offset de um personagem** | grupo `Sprite` do `src/player/personagem_*.tres`; os PNGs em `assets/personagens/<id>/` |
| **Moldura chanfrada de qualquer painel** | `@export` do no com `src/ui/moldura_hud.gd` (chanfro, cor, colchetes, margem) |
| **A regua das barras do cartao de selecao** | as consts `*_CHEIO`/`*_CHEIA` em `src/weapons/dados_arma.gd` |
| **Velocidade do ciclo de caminhada** | `fps_andando` no `src/player/personagem_*.tres` |
| **Arte de animacao nova** | por o GIF em `animations/<id>/` e rodar `python tools/sprites/gerar_sprites.py` -- vale para personagem E inimigo, o que muda e a pasta de saida |
| **Ator que nao cabe na moldura de 80 (o chefe)** | `MOLDURAS` em `tools/sprites/gerar_sprites.py` + `Direcoes.MOLDURAS_DE_ATOR`; as duas listas tem de continuar iguais |
| **Gesto de ataque, morte ou atordoamento de um inimigo** | a lista `clipes` do no `Visual/Corpo` -- um `ClipeDirecional` por gesto |
| **Se um gesto segue o TEMPO do estado ou o proprio fps** | `modo` no `.tres` do `ClipeDirecional` (`PROGRESSO`, `LACO`, `UMA_VEZ`) |
| **Arte de gesto nova** | pastas em `animations/<id>/<clipe>/<direcao>/` e rodar `gerar_sprites.py`; do PixelLab, `baixar_pixellab.py` traz os quadros para la -- de um manifesto de URLs ou do PACOTE do personagem (`pacote.zip#animacao`) |
| **Os oito gestos dos quatro ataques do chefe** | `src/enemies/clipe_*.tres`, listados em `clipes` do no `Visual/Corpo` do `boss_guardiao_01.tscn`. Os NOMES sao contrato com `BossGuardiao01.GESTOS` |
| **Sprite e rotacoes de um inimigo** | o no `Visual/Corpo` da `src/enemies/*.tscn`, com `src/enemies/sprite_direcional.gd`: as duas listas de 8 texturas, `quadros_andando`, `fps_andando`, mais `scale` e `position` do proprio no |
| **Arma inicial, Hack e texto do card de um personagem** | `src/player/personagem_*.tres` |
| Dispersao que cresce com o gatilho preso | `dispersao_*` em `src/weapons/*.tres` — zero desliga |
| **Vida, velocidade, dano e todo botao de combate dos cinco inimigos refinados** | `src/enemies/dados_*.tres` (Drone Aranha, Atirador Neon, Cyber-Besta, Sentinela Orbital, Hacker Parasita) |
| Vida e velocidade dos que ainda nao migraram | `@export` em `src/enemies/*.tscn` -- Rastejante, Vigia, Diretora e as pecas da arena dela |
| **Uma CLASSE de Unidade Aprimorada (regeneradora, blindada...)** | `src/enemies/aprimoramento/apr_*.tres`, na lista `aprimoramentos` do `GerenciadorMapa`. Nenhum script de inimigo a conhece |
| **Quao rara a aprimorada e** | `chance_de_aprimorada` no `src/mapa/tipo_*.tres` mais `salas_sem_aprimorada_depois` no `GerenciadorMapa` -- chance por sala e frequencia percebida NAO sao o mesmo numero |
| **Quais inimigos recebem classe com mais frequencia** | `peso_de_aprimoramento` em `src/enemies/dados_*.tres`; zero tiraria o inimigo do sistema em silencio |
| **Ver as 15 combinacoes e o TTK de cada uma** | `godot --headless --path . tools/aprimoramentos/laboratorio.tscn` |
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
| **Provar a ARQUITETURA da sala antes de desenhar parede** | `godot --path . tools/teste_paredes.tscn --resolution 960x544` -- sala de 480x352 em zoom 1.0, tres fotos (geral, jogador ao norte, jogador ao sul). Ela e pobre de proposito: se ficar boa, e a arquitetura funcionando e nao a decoracao |
| **Ajustar o chefe sem jogar a run inteira** | `godot --path . tools/chefe/arena_chefe.tscn -- --hp=0.32` entra na fase 3 direto; sem janela ele varre os quatro pontos e imprime o relatorio |
| Chefe antigo, hoje fora do andar 1 | `src/enemies/diretora.gd` |
| **Como QUALQUER inimigo avisa um ataque** | `src/enemies/telegrafo.gd` -- linha, mancha no chao ou pulso de sprite, sempre nas mesmas quatro fases |
| **Quanto tempo a brasa do Parasita fica no chao** | `tempo_residual` no `@export` do `src/enemies/hacker_parasita.tscn`; zero desliga |
| **O que o chefe le do jogador** | `src/enemies/perfil_jogador.gd` (logica pura, testada) |
| **As travas de identidade do chefe** | `tools/testes/teste_diretora.gd` + a secao no `docs/GDD.md` |
| Layout e conexao das salas | `src/mapa/gerenciador_mapa.gd`, `src/mapa/sala_*.tscn` |
| **Tipo de sala novo (desafio, forja...)** | criar `src/mapa/tipo_*.tres` e por na lista `tipos_de_sala` do `GerenciadorMapa`. A Loja foi feita assim, sem uma linha no gerador |
| **O que a Loja vende e como ela e montada** | `src/loja/sala_loja.gd` -- balcao, tres bancadas e a luz de trabalho. A geometria da parede e a do andar, sem nada proprio |
| **O Sucateiro (arte e prompt)** | `src/loja/sucateiro.gd` e `assets/npc/sucateiro/`. Gerado pelo PixelLab em `mode=v3`, 64 px, `low top-down` |
| **A transacao de compra** | `src/loja/bancada_de_oferta.gd:comprar()` -- a ORDEM e o contrato: entrega antes do debito |
| **Ver a Loja no enquadramento do jogo** | `godot --path . tools/loja/olhar_loja.tscn --resolution 960x544` |
| **Ver as tres abas do inventario e a tela de troca** | `godot --path . tools/inventario/olhar_inventario.tscn --resolution 960x544` -- ele monta a build CHEIA (os 16 implantes de uma vez) e fotografa as TRES abas, e nao so a aberta. Foi ele que achou os quatro defeitos de layout que portao nenhum pega: `draw_string` alinhado a direita desenhando FORA do painel, o nome mais comprido da pool entrando por cima da coluna de barras, nome de implante cortado no meio da palavra, e as tabelas esticadas por 904 px |
| **Onde a Loja pode nascer** | `distancia_minima_da_origem` e `distancia_maxima_da_origem` no `src/mapa/tipo_loja.tres`; o teto e ZERO em todos os outros tipos, e zero desliga |
| **O que um CORREDOR_TECNICO representa** | `src/mapa/corredor_*.tres` (`PerfilDeCorredor`), na lista `perfis_de_corredor` do `GerenciadorMapa`. Ele decora pelo CHAO e pelo DECALQUE -- nunca pela face, que anunciaria a sala vizinha |
| **Quao raro o corredor e** | `peso_corredor_*` em `src/mapa/planta_andar1.tres`; o do chefe e reservado a parte e nao passa pelo sorteio |
| **Estilo novo de uma sala que ja existe** | arrastar a cena para `cenas` no `tipo_*.tres` correspondente |
| **Quanto a parede varia (peso do comum, espacamento das especiais)** | grupo `Variacao` do `src/mapa/estilo_industrial_velho.tres` |
| **A ESPESSURA desenhada da parede** | `corpo`, `cap` e `sombra_de_contato` em `src/mapa/estilo_industrial_velho.tres` -- **-1 herda o default**. Os quatro lados leem o MESMO numero; a assimetria de outro andar passa pelos `escala_*` do `PerfilDeParede`, e nunca por um campo por lado |
| **Ver a geometria da parede sem a arte defende-la** | `godot --path . tools/comparar_caixa.tscn --resolution 960x544` -- o par ATUAL x ALVO em cores chapadas, mais as reducoes de 25%, 10% e cinza. Sem janela ele imprime a dispersao entre lados |
| **O MATERIAL da parede de um andar** | `src/mapa/estilo_industrial_velho.tres` -- topo, cantos e face neutra. Os cinco `tipo_*.tres` apontam o MESMO kit, porque sao o mesmo setor; a face do TIPO continua em `texturas_face` |
| **Preco de uma arma ou item na Loja** | `valor_de_loja` em `src/weapons/*.tres` e `src/items/implante_*.tres`; zero = nao vai a prateleira |
| **As regras da Loja (vagas, duplicata, reroll)** | `src/loja/loja_andar1.tres` (`DadosLoja`). Ela nao lista conteudo -- quem lista e `pool_padrao.tres`, a mesma pool do loot |
| **Calibrar a renda do andar contra os precos** | `godot --headless --path . tools/loja/simulacao_economica.tscn` -- 40 andares, renda de teto e comprabilidade |
| **Quanto um inimigo paga de credito** | `creditos` em `src/enemies/dados_*.tres` -- ele e o valor ESPERADO, e o sorteio de fichas converge para ele |
| **Como o credito vira ficha no chao** | `src/items/drop_credito_andar1.tres` (`DadosDropCredito`): os tres valores, a fracao paga e o teto de fichas por abate |
| **Quanto limpar uma sala paga** | `chance_de_premio`, `premio_minimo` e `premio_maximo` no `src/mapa/tipo_*.tres`; zero nas salas sem combate |
| **Implante novo (so numeros)** | criar `src/items/implante_*.tres` com a lista de `efeitos` e listar em `pool_padrao.tres` |
| **O ICONE de um implante** | `assets/itens/icone_<id>.png`, escrito por `tools/itens/preparar_icone.py` a partir do master de 256 em `tools/art_sources/itens/`. O `<id>` casa com `implante_<id>.tres` por construcao, e `teste_icones_de_item.gd` cobra os dois lados |
| **Arma, item ou cosmetico NOVO que precisa de arte** | abrir issue pelo gabarito `.github/ISSUE_TEMPLATE/arte.md` ANTES da arte. A regra esta em `docs/CONVENCOES.md`; identidade nao informada se preenche por `docs/IDENTIDADE_VISUAL.md` e se DECLARA na issue |
| **O regime de um ICONE (cor, vista, ancora, os numeros do portao)** | secao "O regime de ICONE" do `docs/IDENTIDADE_VISUAL.md` |
| **O ICONE de uma arma** | `assets/armas/icone_<id>.png`, mesmo funil com `--familia arma`. Pasta SEPARADA da de item porque o portao de orfao e por pasta -- um icone de arma em `assets/itens/` nao tem implante que o aponte |
| **Refazer os icones noutro tamanho** | `python tools/itens/refazer_icones.py --lado 48` (e `--familia arma` para as armas) -- ele le os masters versionados, sem uma geracao nova no PixelLab |
| **Ver os icones lado a lado, e medir se dois se confundem** | `godot --path . tools/itens/laboratorio_icones.tscn --resolution 960x544`; sem janela ele mede os 120 pares e lista as colisoes |
| **Quanto um icone pode brilhar** | `ALVO_VALOR_MIOLO` em `tools/itens/preparar_icone.py` (o funil ASSENTA) e a faixa `PISO_VALOR_MIOLO`/`TETO_VALOR_MIOLO` em `tools/itens/laboratorio_icones.gd` (o portao COBRA). Os dois tem de andar juntos |
| **Implante com comportamento novo** | enum em `DadosItem.Comportamento` + o codigo que le, em quem sofre o efeito |
| Pente, tempo de recarga e reserva | `tamanho_pente`, `tempo_recarga`, `municao_maxima` em `src/weapons/*.tres` |
| **Arma que pode cair de loot** | listar o `.tres` em `src/items/pool_padrao.tres` |
| **Quantas armas o jogador carrega** | `InventarioDeArmas.SLOTS`. E `const` e nao `@export` de proposito: "o que cabe nas maos" e decisao de design, e um botao seria girado para tres na primeira vez que alguem achasse que faltava espaco |
| **Quanto a troca de arma demora** | `Player.COOLDOWN_TROCA` -- freio contra spam tecnico, e nao animacao. Mesma razao que faz `Porta.TEMPO_DE_ABERTURA` ser `const` |
| **O que a tela de troca compara** | `PainelDeTroca` -- quatro barras de `DadosArma.perfil_*()` mais as tags de `tags_de()`. Quatro e nao vinte: o objetivo e decisao rapida, e lista longa faz o jogador escolher pelo nome |
| **Em que regiao do corpo um implante aparece** | `categoria_corporal` em `src/items/implante_*.tres`. **Campo DORMENTE**: a aba de itens e uma grade e nao o le. Ele e a semente da ideia do corpo, que foi reprovada e pode voltar -- e `teste_inventario.gd` continua cobrando os dois lados justamente por ninguem o ler |
| **As tres abas do inventario** | `src/ui/aba_de_itens.gd`, `aba_de_armamento.gd` e `aba_de_status.gd`; quem as troca e `tela_inventario.gd`. Aba nova = script novo + no na cena + entrada em `TelaInventario.Aba` |
| **As linhas da aba STATUS** | `AbaDeStatus.linhas_de_diagnostico()` -- todas derivadas de `Modificadores`, nunca recalculadas |
| **Quantos itens cabem por linha na aba ITENS** | `AbaDeItens.LARGURA_CELULA`; a contagem de colunas e CALCULADA do tamanho real, e nao cravada |
| **Quanto a arma largada fica intocavel** | `PickupArma.TRAVA_APOS_LARGAR` |
| **Quanto tempo a abertura do inventario dura** | `TelaInventario.DURACAO_ABERTURA`; abaixo de 0,25 s por decisao |
| Regras de onde cada sala nasce | `@export` do `tipo_*.tres` (beco, distancia da origem, prioridade) |
| Cor e icone de uma sala no minimapa | `cor_mapa` e `icone` do `tipo_*.tres` |
| **Onde o projetil desenha** | `ContainerProjeteis` em `src/main/main.tscn`: IRMAO do `Mundo`, DEPOIS dele, sem Y-sort. Acima de todo cenario ordenado por Y, abaixo so do Foreground |
| **Se um prop tem COLISAO** | NAO tem. A politica do andar 1 e: **decorativo sem colisao, obstaculo com colisao EXPLICITA na cena**, e hoje o andar so tem o primeiro tipo. Quem cobra e `teste_props.gd:_nenhuma_peca_de_decoracao_tem_COLISAO` |
| **ONDE um prop pode ficar** | `DecoradorDeSala.posicoes()`. **Fonte unica**: a `Sala` NAO decide mais isso. Faixa, folga de meia peca, `area_spawn`, bocas de porta e espaco entre pecas moram todos la |
| **QUANTOS props uma sala recebe** | `src/mapa/decoracao_*.tres` (`PerfilDeDecoracao`), apontado por `perfil_de_decoracao` no `tipo_*.tres`. Os `quantidade_props*` do `DadosSala` SAIRAM; a traducao familia -> porte esta nos `DadosSala.faixa_de_*()` |
| **QUAO FUNDO a decoracao entra na sala** | `largura_da_faixa_de_perimetro` no `decoracao_*.tres`. Era `Sala.PROP_AFASTAMENTO_MAXIMO = 44` em paralelo, e o 44 era quem valia |
| **Ver quanto da decoracao pedida a sala REAL coloca** | `godot --headless --path . tools/fabrica/medir_sala.tscn` -- pedido contra colocado, por tipo e por familia. O `laboratorio_decoracao` mede o DECORADOR; este mede a `Sala` montada |
| **A composicao de uma sala decorada (clusters, hero, vazio)** | `src/mapa/decoracao_*.tres` (`PerfilDeDecoracao`) e `src/mapa/agrupamento_*.tres` |
| **Ver a decoracao antes de existir arte** | `godot --path . tools/fabrica/laboratorio_decoracao.tscn`; sem janela ele mede 288 salas |
| **Ver e medir a luz da fabrica** | `godot --path . tools/fabrica/laboratorio_luz.tscn` |
| **Provar que a sala se identifica SEM COR** | `godot --path . tools/fabrica/prova_de_leitura.tscn --resolution 960x544` -- as salas em quatro regimes (com tint, sem tint, cinza, miniatura) mais as reguas das `[FAB 39-42]`. Ele so roda COM janela: le pixel renderizado |
| **Se o andar 1 esta na paleta nova** | `godot --headless --path . tools/texturas/medir_ambiente.tscn` -- ele REPROVA hoje, de proposito |
| **Retingir uma textura sem passar pelo funil** | `python tools/texturas/retingir.py ARQ --matiz-alvo 216 --saturacao 0.30 --conferir` |
| **Prop de cenario que se MEXE (ventilador, luz, pistao)** | `regioes_props_animados` no `src/mapa/tipo_*.tres`: uma regiao a mais na lista, e nada de cena nova |
| **Quantos props podem se mexer numa sala** | `max_props_animados` no `tipo_*.tres` -- e o orcamento, e ele e baixo de proposito |
| **Textura de chao, parede e props de um tipo de sala** | grupo `Visual` do `tipo_*.tres` para chao e face; o TOPO e os cantos vem do `estilo_de_parede`. Os PNGs sao arte autorada passada por `tools/texturas/preparar_textura.py`; porta, canto e props saem do gerador |
| **Baixar a energia de uma textura sem achatar a faixa dinamica** | `--acalmar CORTE_ALTO REALCE_BAIXO` em `preparar_textura.py`: corta a banda alta (rebite, junta) e realca a baixa (a chapa). Desligado por default |
| **Arte de chao ou parede que nao nasceu na paleta** | o pre-passo de `preparar_textura.py`: `--desvinheta` (chapa a iluminacao), `--tingir GRAUS` + `--limiar-neon` (tinge o metal apagado e deixa o acento aceso intacto), `--grampear-matiz`, `--alvo-v`. Tudo desligado por default |
| **Prop volumetrico novo** | desenhar na celula do `props_volume.png` ancorado no FUNDO dela, e declarar a regiao em `regioes_props_volume` do `tipo_*.tres` |
| **Prop que so pode aparecer uma vez por andar (o Robo Desativado)** | `regioes_props_raras` do `tipo_*.tres`; quem escolhe a sala e `GerenciadorMapa._sortear_celula_de_prop_raro()` |
| **Quanto CADA LADO da parede desenha** | `src/mapa/perfil_de_parede.gd`: norte `face 48 / cap 12 / sombra 4`, lateral `face 28 / reveal 8 / sombra 4`, sul `labio 4 / ledge 20 / queda 8`. Os quatro lados sao perfis DIFERENTES, e a simetria era o defeito |
| **O chanfro das quinas** | `chanfro_de_canto` no mesmo perfil; quem o aplica e `Sala._chanfrar()`, em codigo -- as cenas continuam retangulares |
| **Quanto de VAZIO se ve em volta da sala** | `margem_exterior` no perfil, somado em `margens()`. Medido: `vazio` foi de 0,0-0,7% para 12,3-16,3% do quadro |
| **Que PARTE DA FABRICA uma sala era** | `src/mapa/tema_*.tres`, na lista `temas` do `GerenciadorMapa`. Tema novo = `.tres` novo; ele pesa a FACE e o DECALQUE de topo, e nao muda o tipo funcional |
| **Como o topo se divide em borda, chapa e bisel** | `borda_do_topo` e `bisel_do_topo` em `src/mapa/perfil_de_parede.gd`; a chapa e DERIVADA, e `teste_renderizador_paredes` cobra que ela sobre |
| **Os decalques de desgaste do TOPO, e com que frequencia** | `decalques_de_topo` e `chance_de_decalque` no `src/mapa/estilo_industrial_velho.tres` |
| **Os decalques industriais do CHAO** | `atlas_decalques`, `regioes_decalques` e `quantidade_decalques` no `tipo_*.tres`; o andar 1 usa `decalques_andar1.png` e a sala do chefe tem `decalques_boss.png` |
| **Uma cor nova no cenario** | `tools/texturas/paleta.gd` + a tabela de `docs/IDENTIDADE_VISUAL.md`; `teste_texturas.gd` recusa cor que compete com projetil |
| Enquadramento e cores do minimapa | `@export` do no `Minimapa` em `src/ui/hud.tscn` |
| **Volume, buses e quem toca o que** | `src/autoload/audio.gd`; os tres volumes ficam em `Configuracao`, junto das outras preferencias |
| **Os sons da Loja** | `tools/audio/gerar_sons.gd` -- ficha, compra e o zumbido do transformador. As duas fichas sao o MESMO gerador com outra altura |
| **Os gestos do Sucateiro** | `Sucateiro.CLIPES` -- fita, contagem de quadros, fps e se repete. So `parado` repete |
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
| **A arte da porta de UM lado** | `Porta._vestir()`. Norte usa `porta_moldura.png` (face autorada), sul usa `porta_topo.png`, leste usa `porta_lado.png` e oeste e o leste espelhado. NUNCA um `rotation` |
| **A chapa que fecha a porta** | `assets/texturas/porta_folha.png` (autorada, funil `prop`) no norte; `gerar_porta_folha_topo/lado()` nas vistas de cima |
| **Quanto a folha recolhe ao abrir** | `Porta.RECUO_DA_FOLHA`; o teto e o batente da moldura, medido no alfa dela por `teste_porta.gd` |
| **O indicador de porta trancada** | `gerar_porta_trava()` e `gerar_porta_trava_lado()`, as unicas texturas de porta em paleta SINAL |
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

- **`--import` limpo NAO prova que os scripts compilam, e isso custou 6m54s de
  runaway.** O import cuida de RECURSO (textura, cena, som); ele nao carrega
  todo `.gd` para compilar. Dois laboratorios foram escritos com um erro de
  parse cada -- um `const` recebendo `PackedVector2Array`, que nao e expressao
  constante, e um `:=` inferindo de um Variant -- e o import passou limpo, o
  runner passou (ele so confere as suites da lista dele) e o teste de fumaca
  nunca abre ferramenta de `tools/`. O sintoma nao foi erro, foi SILENCIO:
  script que nao carrega faz a cena subir **sem script**, o `_ready` nunca roda,
  nada e impresso, e o processo fica ocioso no main loop para sempre a um sexto
  de nucleo. Hoje quem fecha isso e `teste_scripts_carregam.gd`, que varre
  `src/` e `tools/` (211 scripts) e exige `can_instantiate()` -- porque script
  com erro de parse NAO volta `null`, volta um `GDScript` invalido.
- **Array indexado por enum, dimensionado por literal, e uma bomba com timer.**
  O laboratorio de decoracao tinha dois acumuladores `PackedInt32Array([0, 0,
  0, 0, 0])`; no dia em que `DECALQUE` e `PAREDE` entraram no fim de `Porte` ele
  morreu com *Out of bounds get index 5* -- **depois** de ja ter impresso o
  cabecalho, entao a saida parecia meio certa. O tamanho sai de `Porte.size()`.
- **Campo novo com default UTIL quebra todo helper de "vazio".**
  `contagem_micro` e `contagem_parede` nasceram com default, e o
  `_perfil_vazio()` da suite zerava so os cinco campos antigos: quatro casos
  passaram a reprovar apontando para o DECORADOR, com o defeito no helper. E a
  mesma familia do `regeneracao_por_segundo = 0.02` que fazia todo `.tres` de
  classe mentir.
- **Deslizar uma sala perpendicularmente a uma conexao quebra o encontro das
  duas PORTAS, e o sintoma e um `push_warning`.** A `[SETOR 05]` pede que a sala
  encoste na fronteira que compartilha em vez de ficar centrada na banda -- e a
  leitura literal disso, deslizar sala a sala, desalinha as bocas.
  `Corredor.configurar()` recebe as duas e, quando elas diferem nos dois eixos,
  avisa e monta pelo EIXO DOMINANTE: o corredor sai torto, sem encostar em
  nenhuma das duas, e o jogo continua rodando. Medido ao sabotar a regra de
  proposito: tres conexoes desalinhadas num andar, **uma delas por 672 px**. E
  `push_warning` nao reprova suite nenhuma. Por isso o deslize e por CORRENTE --
  celulas ligadas no eixo perpendicular deslizam juntas -- e por isso existe
  `teste_conexoes.gd:_as_bocas_das_duas_salas_se_ENCONTRAM`.
- **"Sem tint" as cinco salas do andar 1 tem a MESMA assinatura, e isso e
  medido.** A `prova_de_leitura` desliga o acento de tipo -- chao, familia de
  face e luz fria -- e compara os pares contra um CONTROLE: a mesma sala noutra
  celula, que e o ruido do proprio sorteio. Os dez pares ficam ABAIXO desse
  ruido, enquanto tirar o tint move o quadro em 1,9x a 3,1x ele. Em portugues: o
  acento de tipo mexe mais na sala do que a diferenca entre dois tipos, que e o
  FAIL que a secao 110 descreve. Quem conserta isso e a arte propria de cada
  sala (`[FAB 33/35/37]`), e nao codigo.
- **Regua que monta sala sozinha NAO tem o `AmbienteDaFabrica`, e para uma
  pergunta de PERCEPCAO isso e medir o que o jogador nunca ve.** Aquele
  `CanvasModulate` mora em `main.tscn` de proposito -- se morasse na cena de
  sala, `medir_moldura`, `comparar_caixa` e `formas_paredes` passariam a medir a
  sala escurecida e os numeros historicos delas mudariam de significado de uma
  vez. Mas a `prova_de_leitura` pergunta o que se VE, e sem o escurecimento ela
  media **17,4% de preto onde o jogo da 95%**. As tres reguas de RAZAO
  sobreviveram ao defeito (elas comparam dois quadros igualmente claros); quem o
  denunciou foi a `[FAB 45]`, a unica que compara com um numero ABSOLUTO.
- **Regua sem CONTROLE inventa o proprio piso.** A primeira versao daquela prova
  comparava os pares contra um `0,12` escrito a mao e reprovou os DEZ -- e regua
  que reprova tudo mede a si mesma. Um histograma de luminancia sobre um quadro
  majoritariamente escuro varia pouco por construcao, entao o numero nao
  significava nada. O controle (a mesma sala com outra semente) da a escala, e e
  o mesmo conserto que o disco chapado faz no laboratorio de luz.
- **E o piso de cinza NAO pode ser herdado de `medir_ambiente.gd`.** Aquele
  `PISO_DESVIO_CINZA = 0,06` e sobre um ARQUIVO de textura, detalhe de ponta a
  ponta; um quadro de jogo tem o vazio alem da parede e um piso escuro debaixo
  do `AmbienteDaFabrica`, e mede 0,044 a 0,055 com a decoracao inteira em tela.
  Aplicado ali, ele reprovaria as cinco salas sem dizer nada -- a mesma
  armadilha da constante de transferencia que o `FATOR_DE_RENDER` registra. O
  piso certo e RELATIVO: a mesma sala SEM decoracao nenhuma.
- **Tabela vazia nao e aprovacao.** Aquele mesmo caso imprimiu "a decoracao soma
  massa em todos os tipos" com ZERO linhas medidas, porque o controle nao tinha
  sido tirado e o laco caiu inteiro no `continue`. Regua silenciosa que diz
  PASSOU e pior que regua que reprova -- e por isso o laboratorio de decoracao
  conta `_verificacoes` e reprova quando elas sao zero.
- **O projetil desenhava acima do cenario por ACIDENTE, e o acidente durou ate a
  sala ficar cheia.** Nao havia no nenhum no grupo `container_projeteis`, entao
  `Arma._container()` caia em `current_scene` -- o proprio `Main` -- e projetil
  adicionado depois do `Mundo` desenha depois dele. Certo por ORDEM DE ARVORE,
  que se perde no dia em que alguem arrasta um no. Com a sala de combate indo de
  4 para ~15 corpos volumetricos, projetil passando ATRAS de um caixote deixou
  de ser hipotese. Hoje `main.tscn` declara o `ContainerProjeteis` como IRMAO do
  `Mundo`, depois dele e sem Y-sort, e `teste_camada_visual.gd` cobra as tres
  coisas. A unica camada que ainda cobre um projetil e o Foreground, que ja e
  declarada como capaz de esconder o jogador.
- **Suite que instancia `main.tscn` tem de liberar a RAIZ, e liberar o `mapa`
  nao e isso.** `teste_loja` e `teste_conexoes` faziam
  `mapa.get_parent().remove_child(mapa)` e depois `mapa.free()`: o `Main` ficava
  na arvore para sempre. Isso era invisivel ate o dia em que o `Main` passou a
  ter um no em GRUPO -- ai sete casos de `teste_arma.gd` e
  `teste_boss_ataques.gd` passaram a medir ZERO projeteis com o codigo certo,
  porque `Arma._container()` achava o container esquecido. E a armadilha do
  `container_projeteis` vista do outro lado: aqui ninguem criou container
  nenhum, so deixou de limpar. E note a ordem -- desligar o no do pai ANTES de
  procurar a raiz faz a busca parar nele mesmo.
- **Prop decorativo NAO tem colisao, e o que o impede de parecer obstaculo e a
  POSICAO.** A politica das secoes 86-88 do briefing e "decorativo sem colisao,
  obstaculo com colisao explicita", e as duas metades falham em silencio: um
  `CollisionShape2D` esquecido num prop vira esbarrao fantasma -- com 15
  volumetricos por sala isso transforma a faixa de perimetro num labirinto, e o
  jogo continua rodando --, e um prop sem colisao DENTRO da area util e
  cobertura que nao cobre, que o jogador so descobre levando um tiro atraves
  dela. Por isso ha dois portoes irmaos em `teste_props.gd` e nao um:
  `_nenhuma_peca_de_decoracao_tem_COLISAO` e
  `_o_CORPO_fica_fora_da_area_util_e_a_MANCHA_entra_nela`. Obstaculo de verdade,
  quando existir, nasce com colisao declarada na CENA -- como a barreira da
  porta -- e entra como excecao nomeada.
- **Duas fontes para a mesma densidade, e a que valia era a errada.** O
  `PerfilDeDecoracao` declarava faixa de perimetro 96 e contagens por porte; a
  `Sala` lia `PROP_AFASTAMENTO_MAXIMO = 44` e `quantidade_props*` do
  `DadosSala`, e os perfis do `[FAB 18]` nao eram apontados por NINGUEM -- seis
  `.tres` orfaos em disco. As cenas de sala autoram exatamente 96 px entre o
  contorno e a `area_spawn`, e `posicoes()` cobra meio prop de folga contra a
  parede: com faixa 44, a fatia util de uma peca de 64 media **DOZE pixels**. A
  sala montada com as 12 pecas do Batch 1 continuava parecendo vazia e a
  conclusao natural era "falta arte". Medido depois da migracao, a sala de
  combate foi de ~16 para **33,8 pecas**, entregando 97% do que o perfil pede.
- **`add_child` renomeia o filho repetido, e contar por NOME acha sempre UM.**
  O prop volumetrico e a unica familia sem raiz -- ele precisa ser filho direto
  da sala para se ordenar por Y --, entao quem o conta so tem o nome. O segundo
  em diante vira `@PropVolume@<id>`: `teste_props.gd` filtrava por
  `name == "PropVolume"` e media **o primeiro prop e mais nada**, verde, desde
  que nasceu. Hoje eles entram em `Sala.GRUPO_PROP_VOLUME` e a contagem e por
  grupo. A primeira execucao da regua nova acusou "volume 1,00, min-max 1-1" em
  todos os seis tipos -- o numero impossivel que denunciou o defeito.
- **Sortear a partir de uma ARESTA nao serve para o que mora no chao todo.** O
  decalque passou a poder cair no miolo (a `[FAB 06]`), e sortear a
  profundidade a partir de um lado com faixa grande PARECE uniforme e nao e: o
  disco de exclusao de cada porta come justamente a beirada, e medido deu
  **89% no miolo contra 11% no perimetro** -- o piso com o centro sujo e a
  parede limpa, o inverso da referencia. `posicoes()` ganhou
  `"no_chao_todo"`, que sorteia na caixa da sala; a distribuicao foi para 72% /
  28%, e `teste_props.gd` cobra as DUAS pontas.
- **A ZONA LIVRE proibe VOLUME, e nao DECALQUE -- e confundir os dois deixa o
  centro chapado.** Medida em `docs/fabrica_01.png`, a sala da referencia tem um
  losango de galao no MEIO da area livre e mais de dez grades espalhadas. A
  primeira versao do decorador rejeitava tudo ali e o piso virava um vazio. Hoje
  volume e barrado, decalque passa, e `PAREDE` tambem passa -- porque ele esta
  na parede por construcao, e numa sala em L o centro da caixa envolvente cai
  perto da parede interna.
- **A regra do VAZIO mede o que esta NA PAREDE.** Contando decalque, a sala em L
  dava 11,8% de vao maximo contra o piso de 12% e reprovava por causa de mancha
  PINTADA NO CHAO, com a parede vazia atras dela. Corrigido medindo so o que
  ocupa parede: 14,0% / 14,1% / 16,3%.
- **A luz da fabrica le TEMPO DE PAREDE, como o `PropAnimado`.** O `Juice`
  congela `Engine.time_scale` no hitstop; luz que trava junto denuncia o truque.
  E o flicker combina frequencias incomensuraveis em vez de uma senoide: medido,
  ele repete 0,457 no periodo contra 1,000 de uma senoide pura, e nunca zera a
  energia -- apagar por completo le como bug de renderizacao.
- **Luz que le como CIRCULO DE ENGINE tem numero.** O laboratorio mede a queda
  na borda da poca: o ambar cai 0,31 por pixel contra **15,81** de um disco
  chapado, com borda 0,63 contra 0,01. E a secao 20 do briefing virada medicao.
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
- **Contador de SEQUENCIA e contador de BEAT sao coisas diferentes, e o que os
  separa e quem os zera.** A investida encadeada usava `_beats`, que
  `_preparar_entrar()` zera -- e a investida volta a PREPARAR entre uma corrida e
  a seguinte, porque cada uma precisa do proprio telegrafo. Entao
  `_beats < investidas_da_fase()` lia `0 < 2` a cada volta e **o chefe investia
  para sempre**: medido a 65% de vida com o alvo parado, em 90 s ele executou SO
  investida e `RECUPERAR` -- a janela de dano da luta -- nunca aconteceu. O soco
  da fase 3 sempre fez isto certo com `_golpes_restantes`; hoje a investida tem
  `_investidas_restantes`, zerado em `_escolher_ataque()`, que e o unico ponto do
  ciclo que uma sequencia NOVA atravessa e uma continuacao nao.
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
- **Percentual sobre `int` some, e isso ja apagou uma classe inteira.** A
  Blindada reduzia 25% do dano com um piso de 1 por acerto -- e os tiros do jogo
  valem 1 ou 2, entao `round(1 x 0.75)` devolvia 1 em TODO acerto. O laboratorio
  mediu **+0% de TTK nas cinco especies**: a classe existia, desenhava a aura e
  nao fazia nada. A saida e acumular a fracao e cobrar quando ela fecha um ponto,
  que e o que a cura ja fazia ao lado. Mesma armadilha que `DANO_PERCENTUAL` ja
  registra para o jogador.
- **E a vida ser `int` limita a reducao a DEGRAUS DE UM ACERTO.** Num inimigo de
  5 de vida: 15-17% de reducao da 6 acertos (+20% de TTK), 18-25% da 7 (+40%).
  Nao ha nada entre os dois. Foi por isso que a Blindada saiu com 0,15 e nao com
  os 0,25 que o plano pedia -- 40% passa do teto de 35% que separa "decisao" de
  "esponja de dano".
- **Campo de classe com default UTIL faz todo `.tres` mentir.**
  `regeneracao_por_segundo = 0.02` no script era herdado pelas tres classes,
  entao qualquer regua que perguntasse *"esta classe cura?"* olhando o campo
  respondia SIM para todas. Nada quebrava em jogo (o controlador decide pela
  classe), e a linha de base do laboratorio saltou de 0,50 s para 4,50 s sem um
  pixel ter mudado. Campo de classe nasce em ZERO.
- **A aura da classe NAO pode escrever em `_corpo.color` nem em
  `_visual.modulate`.** Os dois ja tem dono -- o Hack pinta o corpo e o nanite so
  pinta se nao houver Hack; o modulate e do clarao de dano, que termina sempre em
  branco. Um terceiro escritor produz uma cor que depende da ordem das chamadas.
  A `AuraDeAprimoramento` e no IRMAO do `Visual`, e o sprite do inimigo nao muda
  em pixel nenhum.
- **O que separa as tres classes e o MOVIMENTO da arte, e nao a cor.** O jogo e
  escuro e matiz e a primeira coisa que se perde: a Regeneradora tem particulas
  que CONVERGEM, a Blindada placas solidas que ORBITAM e ABREM, a Sobrecarregada
  faiscas que SAEM. Tres leituras diferentes a um segundo, e diferentes tambem em
  cinza.
- **Aprimorada de vida CHEIA tem de ser reconhecivel.** A primeira Regeneradora
  so desenhava durante a cura -- entao ela era indistinguivel de um inimigo
  normal ate o jogador ja ter atirado e parado, e a decisao que ela existe para
  criar acontece ANTES disso. Hoje o anel existe sempre e as particulas sao a
  escalada.
- **Nao existia funil de cadencia, e os cinco tinham copia propria.**
  `_t_intervalo -= delta * Deterioracao.multiplicador_cadencia()` aparecia cinco
  vezes, entao qualquer coisa que quisesse mexer no ritmo precisaria de codigo
  por especie. Hoje ha `InimigoBase.cadencia_agora()`. A RECUPERACAO continua sem
  funil, e por isso a Sobrecarregada compensa em vida em vez de em recuperacao --
  divida declarada, nao esquecimento.
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
- **Duas armas com a mesma COR e a mesma FORMA sao a mesma arma.** As 21 armas
  desenhavam o mesmo losango, e dez dos 210 pares estavam a menos de 15 graus de
  matiz -- dois com RGB identico (`rail_x`/`gravity_gun`,
  `onda_guardiao`/`sucata_guardiao`). O portao compara MATIZ e nao canal:
  `Paleta.mesma_cor()` tem tolerancia de 1,5/255 por canal e deixaria passar
  `pistola` contra `volt_caster`, a 2,2 graus, que sao os dois o mesmo ciano.
- **`LARGURA_MATIZ` nao sai da distancia entre vizinhos.** A formula obvia --
  metade da menor distancia -- foi medida e da **+-1,1 grau**, o que obrigaria
  arte chapada sem rampa de sombra. O numero e o que a ARTE precisa, e o aperto
  vira pressao sobre a silhueta. Alargar a faixa depois para um PNG passar e o
  "suavizar para caber num numero" que ja matou uma familia de textura.
- **O portao de paleta INVERTE para projetil, e por isso e funcao irma.**
  `_regra_de_gamut()` exige `compete == 0`; `_regra_de_ator()` exige o
  contrario. Quatro das cinco asercoes invertem -- uma bandeira faria a mesma
  funcao afirmar duas coisas opostas. E ele mede o **MIOLO** e nao o sprite
  inteiro: pixel art tem contorno escuro, e cobrar brilho do contorno e proibir
  contorno.
- **Paleta forcada para projetil precisa ter TODOS os degraus competindo.** Com
  um degrau escuro na rampa, o gerador o usa para SOMBREAR -- e num sprite de
  16 px o sombreado ocupa quase todo o miolo. Medido: a fonte nasce em 15% de
  miolo competindo contra o piso de 70%, e **nao e a reducao que derruba**, a
  fonte ja nasce assim. Num projetil desse tamanho o que carrega a leitura e a
  silhueta mais a cor; sombra e ruido, e a paleta tem de recusa-la.
- **O ASPECTO de um projetil nao se obtem por prompt.** Cinco reformulacoes --
  "exatamente duas vezes mais largo que alto", "encostando nos quatro lados",
  tela na proporcao alvo -- deram bbox entre 3:1 e 8:1 onde o alvo era 2:1. Quem
  resolve e `gerar_projeteis.py --comprimento=N`, que apara a CAUDA ate o
  comprimento que `FormasProjetil` declara. Apara pela cauda e nunca pela frente:
  a frente e o que le direcao.
- **Abaixo de 64 px de MIOLO a arte perde para o poligono.** O portao de paleta
  cobra que o miolo COMPETE; ele nao cobra que o miolo EXISTE, e sao perguntas
  diferentes -- `sucata_guardiao` media 100% de miolo competindo com DOZE pixels
  de miolo. A separacao medida nao tem caso no meio (206, 144, 91, 88, 75, 67
  contra 54 e 12), e por isso `POLIGONO_POR_DECISAO` e uma decisao e nao um
  atraso.
- **O FEIXE tambem pode mentir sobre a hitbox, e mentia.** Ele desenhava 6 px e
  feria numa linha de espessura ZERO -- e escapava do portao de silhueta inteiro,
  porque nao instancia projetil. Hoje a consulta tem a largura desenhada, e a
  ordem importa: o DESENHO para na fracao SEGURA do `cast_motion`, a pergunta de
  QUEM e feita na INSEGURA. Perguntando na segura, `intersect_shape` volta vazia
  justo no frame do acerto.
- **Reduzir arte paletizada com BOX inventa cor.** A media entre o contorno e o
  corpo e uma cor que a fonte nao tem, e ela derrubou a fracao que compete de
  52% para 41% na primeira arte de projetil. `gerar_projeteis.py` reduz e depois
  GRUDA na paleta da fonte.
- **Arte de projetil ancora no CENTRO; a de ator ancora na BASE.** Um projetil
  que herde `Direcoes.BASE_NO_QUADRO` desenha 36 px acima de onde fere, sem uma
  linha no console.
- **Girar arte de TOPO e legitimo; girar arte de FACE nao.** O projetil voa acima
  do chao e e visto de cima -- e topo, como `porta_topo.png`, que o projeto ja
  gira. A regra da secao 28 do `LOW_TOPDOWN_SQUARED.md` continua valendo para
  FACE, e as duas varreduras nunca se cruzam. `flip_h` e `flip_v` continuam
  proibidos nos dois: espelhar REFLETE onde girar TRANSPOE.
- **O rastro cravado emendava com o tiro seguinte.** Ele era
  `maxf(raio * 6, 16)` para as 21 armas, e reprovava a conta
  `rastro * raio < velocidade / cadencia` em tres: `onda_guardiao` desenhava
  96 px de trilha sobre um vao de 26 px, `sucata_guardiao` 42 sobre 21. Trilha
  maior que o vao vira um risco solido e o jogador perde a CONTAGEM de
  projeteis.
- **`Impactos.vestir()` roda ANTES do `add_child`**, ao contrario da convencao da
  casa: `fx_autodestroi.gd._ready()` liga a emissao e agenda a liberacao com o
  `lifetime` DAQUELE instante.
- **`_nenhum_png_fica_fora_de_regime()` so via `assets/texturas/`.** Arte numa
  pasta nova nao reprovava -- ela SUMIA da conta, que e pior. Hoje ha
  `PASTAS_MEDIDAS` e `PASTAS_SEM_REGIME_AINDA`, e `assets/personagens/` e
  `assets/inimigos/` (160+ PNGs de ator sem portao) sao ponto cego DECLARADO em
  vez de silencioso.
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
- **"So a porta norte tem moldura" quase sempre NAO e um defeito de arte.** As
  outras tres estao SELADAS. `Sala._selar_portas_sem_vizinho()` sela todo lado do
  grid que nao tem sala do outro lado, e porta selada esconde tudo -- moldura
  inclusive --, porque ali a parede passa reta e desenhar batente abriria um
  buraco onde ha parede. Medido no andar inteiro: **18 portas conectadas, todas
  as 18 desenhando a moldura, e 19 seladas desenhando nada.** A sala inicial tem
  UMA conexao, entao ela mostra UMA porta. O `sala_prototipo.tscn` engana aqui:
  ele nao chama `configurar_conexoes()`, entao nenhuma porta se sela e as quatro
  aparecem -- foi por isso que a conferencia no prototipo passou tres vezes
  enquanto o jogo mostrava outra coisa. Confira no JOGO, ou selando de proposito.
- **Dois blocos com um vao entre eles NAO sao uma moldura, e a diferenca e
  topologia.** As vistas de cima da porta ganharam grao, rebite, laje escura e
  sombra de contato e continuaram nao lendo como porta, porque nada ATRAVESSAVA a
  abertura: o olho lia "a parede tem um buraco aqui". Na porta norte quem fecha o
  vao em cima e a verga e embaixo e a soleira. De cima nao existe "acima da
  porta", entao a travessa vira DUAS -- soleira na boca voltada para a sala,
  trilho na voltada para o corredor -- e o vao fica cercado nos quatro lados.
  Nenhuma medicao de COR pega isso; `teste_porta.gd:_toda_moldura_CERCA_o_vao`
  pega, contando pixel cercado nos quatro sentidos: antes das travessas as vistas
  de cima tinham ZERO.
- **A porta VOLTOU a ser a mesma arte girada, e isso e uma reversao consciente.**
  A PORTA 03 tinha trocado a moldura girada por tres vistas -- face autorada no
  norte, vistas de cima geradas nos outros --, com o argumento de que girar uma
  FACE destroi a perspectiva. O argumento esta certo e continua escrito no
  `LOW_TOPDOWN_SQUARED.md` secao 28. O que ele nao previu e que o substituto teria
  de ser tao bom quanto a arte desenhada: em TRES rodadas as vistas de cima
  passaram por chapadas demais, mais claras que a parede e sem cercar o vao, e em
  nenhuma chegaram perto. O dono do projeto olhou as quatro portas no jogo e
  reverteu. **Nao proponha as tres vistas de novo sem arte autorada pronta na
  mao** -- o que falhou nao foi a ideia, foi o substituto.
- **O que continua proibido na porta e giro ERRADO, e nao giro.**
  `teste_porta.gd:_o_giro_da_porta_concorda_com_a_direcao` cobra tres coisas: o
  angulo e um dos quatro retos, ele CONCORDA com `Porta.direcao`, e `flip_v` e
  proibido. Espelhar na vertical troca o que esta em cima pelo que esta embaixo --
  poe a soleira acima da verga --, e isso nenhum giro faz.
- **Teste que le pixel de sprite GIRADO tem de usar o transform.** O portao que
  confere se a moldura e vazada sob a folha subtraia posicoes em coordenada de
  mundo, e isso acertava o norte e errava o leste e o oeste: ele apontava para um
  pixel que nao era o que esta sob a chapa. `to_local(to_global(...))` resolve, e
  o sintoma so apareceu quando a moldura voltou a girar.
- **A parede era a MESMA arte girada nos quatro lados, e isso e destruir a
  perspectiva.** 180 graus no sul, 90 no leste, -90 no oeste -- e
  `porta_moldura.png` e arte de FACE, 96x128, com batente e verga desenhados para
  serem vistos de frente. Girada 90 graus, os 128 px de ALTURA viravam 128 px de
  extensao horizontal com a face deitada. O numero de vistas nao e escolha: a
  `Sala._montar_faces()` so poe face nos lados virados para a camera, entao o
  norte mostra FACE e os outros tres mostram TOPO -- e a porta tem de concordar
  com a parede em que ela esta. Sao TRES artes para quatro lados, com o oeste
  espelhado em x. A decisao inteira esta no `LOW_TOPDOWN_SQUARED.md` secao 28, e
  quem a cobra e `teste_porta.gd:_nenhuma_porta_desenha_arte_girada`, que varre
  as cenas de sala em DISCO e exige `global_rotation == 0` e `flip_v == false`.
- **Espelhar em x reflete; girar e transpor NAO.** As vistas de cima da porta
  parecem uma a transposta da outra e nao sao: a luz vem de cima e da esquerda,
  entao transpor os pixels giraria a iluminacao junto. Em `porta_lado` quem
  acende e a aresta virada para a sala mais o fio de cima de cada caixa, e em
  `porta_topo` e a aresta virada para o norte. Espelhar em Y e proibido pela
  mesma razao que girar 180.
- **Poco desenhado DENTRO da moldura tapa a folha, e nenhum portao de arquivo
  pega isso.** A primeira versao das vistas de cima pintava a passagem escura na
  propria textura de moldura -- e a moldura desenha ACIMA da folha. A chapa
  existia, carregava e ficava no lugar certo, com um retangulo opaco em cima: a
  porta trancada voltava a ser um buraco com a barra de sinal na frente, que e o
  defeito inteiro da PORTA 01. As duas texturas estavam certas; era a ORDEM que
  nao estava. Por isso o recesso e peca separada nos QUATRO lados, e nao so no
  norte.
- **A folha some ATRAS do batente, e nao por `visible = false`.** Cada metade
  recolhe `RECUO_DA_FOLHA` (16 px) para dentro de um batente de 24, que e opaco e
  desenha por cima. E por isso que a animacao nao deforma nada: o antigo campo de
  forca ia a `scale (1.0, 0.02)`, que numa grade de listras passava como "recolheu"
  e numa CHAPA le como a porta sendo esmagada. `teste_porta.gd` cobra os dois
  lados -- que a escala nunca sai de 1, e que o recuo cabe no batente MEDIDO no
  alfa da moldura.
- **`_aplicar_estado()` esconde a folha ANTES de a animacao comecar.** ABERTA nao
  tem folha, entao quem abre precisa devolve-la a tela dentro de
  `_encenar_abertura()`. Sem essa linha a porta abre no primeiro quadro (certo) e
  a encenacao inteira acontece sobre nada (silencioso). O campo de forca ja pedia
  o mesmo cuidado antes da PORTA 02, e foi essa linha que se perdeu na migracao.
- **Teste que espera ANIMACAO nao pode contar quadros.** Sem janela o Godot nao
  tem vsync e roda centenas de quadros por segundo: um laco de 30
  `process_frame` cobria 0,05 s de uma abertura de 0,42 s e parava dentro do
  TREMOR, antes de a chapa se mexer. O caso reprovava com o codigo certo. Espere
  a CONDICAO (a folha sumir), com um teto grande so como rede.
- **Portao que mede a moldura tem de achar o FURO primeiro.** A primeira versao
  de `_batente_da_moldura` mediu na linha do meio do sprite -- que e a SOLEIRA,
  opaca de ponta a ponta -- e respondeu 48 px de batente onde ha 24. Um portao
  que mede a coisa errada aprova o dobro do que devia, e continua verde.
- **A parede nao e mais poligono, e o truque do recorte MORREU junto.** O topo
  era o contorno INFLADO e solido desenhado ATRAS do chao, e quem recortava a
  faixa visivel era o chao por cima -- era isso que fazia a sala em L funcionar
  sem calcular anel com furo, e era fragil porque dependia de duas camadas na
  ordem certa. A fita de modulos nao precisa: toda celula mora na FAIXA, do
  contorno para fora, e nenhuma toca area jogavel. Por isso ela desenha ACIMA do
  chao e mesmo assim nao cobre nada, e por isso a sala em L nao precisou de
  geometria nova. Isso e afirmacao geometrica e virou portao --
  `teste_renderizador_paredes.gd` mede as 800 e poucas celulas das nove formas.
- **A textura de face chega a tela INTEIRA desde a fita.** A armadilha antiga
  dizia que so a metade de baixo aparecia: a UV do quad era em pixels ancorada no
  canto do contorno, o quad tinha 32 px e a textura 64, entao a repeticao
  amostrava as linhas 32..63. Com a celula sendo um `region_rect` de 32x32 dentro
  da textura de 64x64 e o quadrante saindo do hash da celula, os quatro sao
  alcancaveis -- e numa parede longa os quatro aparecem.
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
- **`Porta.LARGURA` e o UNICO botao do vao, e o corredor deriva dele.** Os dois
  tinham de ser iguais e eram escritos duas vezes; hoje
  `GerenciadorMapa.largura_corredor` nasce de `Porta.LARGURA` e a duplicata
  sumiu. Continua `@export` porque ainda e botao de tuning -- o que mudou e o
  default deixar de ser um literal.
- **O vao e 64 porque 80 nao cabe na grade, e isso e aritmetica.** Para um vao
  cobrir celulas inteiras de 32, as duas bordas tem de cair em multiplos de 32 --
  e a diferenca entre elas e a propria largura. Com 80, `80 mod 32 = 16`: **nao
  existe centro que resolva**. A porta ocupava 2,5 celulas e a reserva na fita
  saia 96 px numa sala e 128 noutra, conforme a paridade da meia dimensao
  daquela sala. 96 tambem fecharia a conta e foi descartado por MEDICAO: o
  desenho da `porta_moldura.png` ocupa 95 px dos 96 do arquivo, entao sobre um
  vao de 96 a moldura fica MENOR que a passagem. Com 64 ela cobre o vao e ainda
  avanca 15 px sobre a parede de cada lado.
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
- **`Sala.tipo` e um `@export` do `.tscn`, e nao algo derivado do `DadosSala`.**
  Sao duas fontes para a mesma verdade, e elas divergiram no dia em que a Loja
  nasceu como COPIA da sala de arma: o `.tscn` clonado trouxe `tipo = &"arma"`
  junto, e a Loja passou a se apresentar como sala de arma para todo mundo que
  pergunta. O sintoma foi o teste de fumaca reprovando em **~25% das execucoes**
  com *"a sala tipo=arma nao tem nenhum pickup"* -- ele visitava a LOJA, lia o
  tipo `arma` e procurava uma arma que nunca existiu ali. A intermitencia vinha
  de qual das duas o jogador visitava primeiro, porque a conferencia acontece uma
  vez por tipo. **Clonar cena e o caminho normal para criar sala nova, e campo
  que mente nao da erro**: hoje `teste_dados_sala.gd` cruza as duas fontes.
- **Diagnostico por `git stash` mente se o bug ja esta COMMITADO.** Conclui que a
  intermitencia acima era anterior ao epico porque ela aparecia com o stash
  aplicado -- mas o stash foi feito sobre um commit que ja continha a Loja, entao
  os dois lados tinham o defeito. `git stash` compara o nao-commitado; para
  perguntar "isto e meu?" a comparacao tem de ser contra o commit ANTERIOR a
  mudanca, e nao contra a arvore suja.
- **A ORDEM da compra e o contrato, e nao um detalhe de implementacao.**
  Entregar ANTES de debitar: `Modificadores.aplicar()` RECUSA um implante unico
  que o jogador ja tenha e devolve `false` justamente para quem chama nao
  consumir o pickup. Com o debito primeiro, o jogador paga por um implante que
  nao recebe -- e numa economia isso nao tem desfazer. `teste_loja.gd` inverteu a
  ordem de proposito e o portao acusou 22 creditos sumindo sem entrega.
- **Chance por sala e frequencia PERCEBIDA sao numeros diferentes, e a diferenca
  tem tamanho.** O `tipo_combate.tres` declara 25% de chance de aprimorada;
  medido em 24 andares, a taxa e **21,7% das salas de combate** (1,08 por andar).
  A distancia entre os dois e o cooldown: 22 das 120 salas sorteaveis nem chegam
  a rolar o dado. Entre as 98 que rolam, o sorteio devolve os 26,5% declarados --
  entao o `.tres` esta certo e o numero que o jogador sente e outro.
- **A morte de uma aprimorada NAO vem do `EventBus`.** `inimigo_morreu` carrega
  `(posicao, creditos)` e nao diz quem caiu. Um sinal novo faria o inimigo
  conhecer a metrica; engrossar a assinatura mexeria num sinal com outros
  ouvintes para servir a um so. `RegistroRun` escuta o `InimigoBase.morreu`
  DAQUELE no, que chega no parametro de `aprimorado_nasceu` -- com o `DadosRun`
  AMARRADO, porque uma aprimorada sobrevive ao abandono pelo menu e pode cair com
  a run seguinte ja em curso: sem a amarra sairia `mortas > encontradas`.
- **A incompatibilidade entre classes seria INALCANCAVEL dentro de
  `aplicar_aprimoramento()`.** Com `MAX_APRIMORAMENTOS` em 1, o teto recusa antes
  de haver classe pendurada com quem brigar -- e as duas recusas devolvem `false`,
  entao nenhum portao as separaria e o campo passaria por lido estando morto. Por
  isso a regra e `InimigoBase.aprimoramento_incompativel()`, publica e perguntada
  direto.
- **O ambiente da Loja e POSICIONAL, e nao passa por `definir_ambiente()`.**
  Aquele metodo troca o ambiente GLOBAL, e trocar ao entrar exigiria alguem
  lembrar de restaurar o do andar ao sair -- "quem liga desliga" ja custou um som
  de setor tocando em laco por cima do menu inicial. O zumbido e um
  `AudioStreamPlayer2D` FILHO da sala: nasce e morre com ela, sem estado global
  para restaurar, e o ambiente do andar continua por baixo (a Loja e um pedaco da
  mesma fabrica).
- **A fita de um clipe do PixelLab NAO se reancora quadro a quadro.** Ele entrega
  todos na mesma tela, entao concatenar preserva o gesto; ancorar cada quadro
  pela propria base CANCELA a animacao -- o braco que se estende volta ao lugar.
  E as fitas vem em tela MAIOR que a rotacao (88 contra 64), com os pes em 75
  contra 63: nos dois casos 31 px abaixo do centro, entao um `offset` so atende
  os quatro clipes.
- **Glifo que a fonte nao tem SOME sem erro.** O preco na bancada saia como
  `12   [E]`, com um buraco onde deveria estar o losango da moeda:
  `ThemeDB.fallback_font` nao tem `◆`, e a fonte do projeto tem -- a HUD
  mostrava certo e a bancada nao, o que faz parecer bug de layout. Onde o glifo
  importa, desenhe a forma em vez de escreve-la.
- **Ator com arte de 64 px ancora pelo PE, e o `Sprite2D` centra por padrao.**
  Sem `offset`, o Y-sort poe a CINTURA do Sucateiro na linha de profundidade e
  ele desenha atras do balcao que esta a frente dele. O numero sai do alfa do
  arquivo (pes em 63 de 64), e nao de uma constante escrita a mao.
- **A luz da Loja e ELIPSE e quase transparente, e a primeira versao lia como
  DECALQUE.** Tres aneis concentricos de alfa 0,10 somam 0,30 no centro sobre um
  chao de luma 20: o resultado e uma mancha laranja desenhada no piso. E o
  circulo perfeito piora -- luminaria pendurada sobre bancada faz uma poca LARGA
  e baixa; circulo le como holofote de vitrine, que e o primeiro item da lista
  do que nao fazer.
- **`distancia_maxima_da_origem` ZERO e "sem teto", e nao "na origem".** Todos os
  tipos anteriores a esse campo valem zero, e um teto real de zero os prenderia
  na entrada -- e a mesma armadilha do sentinela negativo do `EstiloDeParede` e
  do `Escalonamento` dos inimigos, vista de outro angulo: aqui o valor neutro e
  zero porque o campo conta DISTANCIA, e distancia zero ja significa a origem.
- **Cena de sala clonada herda o `uid` da original.** Copiar `sala_7_arma.tscn`
  para criar a Loja levou junto o `uid://` -- dois recursos com o mesmo
  identificador, e o Godot resolve um deles em silencio. Trocar o `uid` faz parte
  de clonar cena, e nao ha aviso.
- **Os quatro alvos de comprabilidade do plano da Loja NAO coexistem, e a
  medicao mostra por que.** Ele pede "ao menos uma compra em 70-85%" e
  "exatamente duas em 15-35%" ao mesmo tempo: subir a renda para o segundo cair
  na faixa derruba o primeiro e o "nenhuma compra" juntos, porque mais dinheiro e
  menos runs sem compra por construcao. Medido em 40 andares -- fracao 0,20 da
  85% / 2,5% / 15%; 0,24 da 92,5% / 15% / 7,5%; 0,28 da 95% / 32,5% / 5%. Fica
  em 0,20, que acerta tres dos quatro E as duas faixas de renda. O "exatamente
  2" so entra por outro caminho: garantir uma oferta BARATA por loja em vez de
  sortear os tres precos livres.
- **Portao que crava um NUMERO envelhece com o botao de tuning.** O portao do
  teto de fichas afirmava "o chefe paga 60" e passava so porque `fracao_do_valor`
  era 1,0 -- calibrar a renda para 0,20 reprovou o codigo CERTO. Ele afirmava um
  numero em vez da regra, e a regra e que o teto JUNTE o resto em vez de
  descartar. Mesma licao que `teste_enquadramento` ja pagou com o tamanho de
  sala.
- **`GameState.creditos` so muda pela API, e `teste_creditos.gd` LE O CODIGO
  para provar.** Nenhum teste de comportamento pega uma atribuicao direta: ela
  funciona, some do sinal `creditos_mudaram`, e a HUD para de atualizar naquele
  caminho especifico. E `gastar_creditos()` devolve `bool` e nao altera nada
  quando recusa -- debitar e deixar o chamador conferir depois e a forma de o
  jogador pagar por uma arma que nao recebeu, e numa economia isso nao tem
  desfazer.
- **Campo novo do inimigo vai para `DadosInimigo`, e nao para um `@export` do
  nó.** Escrevi `drop_de_credito` no `.tres` e declarei o `@export` no
  `InimigoBase`: **o Godot ignora a propriedade desconhecida em SILENCIO**, o
  campo do no fica nulo, e a run rendeu 11 creditos em vez de 173. Nada no
  console. `teste_dados_inimigo.gd` ja cobra o inverso (numero que foi para o
  `.tres` tem de sair do `.tscn`), e esta e a mesma fronteira vista do outro
  lado.
- **A ficha de credito nao pode depender de o jogador PASSAR por cima dela.**
  Medido no teste de fumaca: so com atracao por raio, uma run de 33 abates
  terminou com **zero** creditos -- as fichas caem onde o inimigo morreu e o
  jogador sai da sala. Ao limpar a sala elas passam a ir ate ele de qualquer
  distancia, e o voo TERMINA em credito depois de 2 s: com o voo sendo uma
  corrida que da para perder, a run rendeu 12 de 266. Renda que depende de
  geometria nao e economia, e sorte.
- **A ficha e LOSANGO e desenha em `Z_CHAO_DETALHE`, e as duas coisas sao a
  mesma regra.** Circulo pequeno e brilhante e exatamente o que um projetil e
  neste jogo, e a faixa zero e onde o telegrafo desenha. Dinheiro que se confunde
  com perigo, ou que cobre o aviso, e o pior defeito que a economia pode
  introduzir.
- **A RENDA ATUAL E 3 A 5 VEZES A QUE O PLANO DA LOJA ASSUME.** Medido numa run
  completa: **173 creditos** contra os 35-55 que o plano propoe como total do
  andar 1. `DadosDropCredito.fracao_do_valor` existe para baixar isso sem tocar
  em inimigo nenhum -- mas a escolha entre baixar a renda e subir os precos e da
  simulacao economica (#284), e nao de gosto.
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
- **Sala do tamanho exato da tela e o pior caso, e o conserto NAO foi encolher.**
  Contorno 960x544 mais a faixa de parede sobrava 64 px de deslize por eixo: com
  o jogador no centro, nenhuma parede aparecia, e ele passava o combate olhando
  para uma tela 100% de chao. A primeira tentativa foi fechar a sala -- 896x384,
  para `contorno + margens` caber em 960x544 --, e ela esta errada por
  ARITMETICA: as margens verticais somam 136, entao o contorno teria de ter 408
  px, que nao cai na grade de 32. Com 384, o clamp sai 520 contra 544 e a camera
  recebe um limite MENOR que o proprio quadro. Cinco cenas ficaram assim uma
  entrega inteira sem nada acusar, porque o portao de regime respondia FECHADO --
  `folga <= 0` nao distingue "encaixa exato" de "falta um pedaco".
  O conserto e o **regime do Lobby**, que o dono apontou como certo: 896x640, X
  fechado (as duas laterais sempre em quadro) e Y aberto na altura dele (a parede
  norte entra quando o jogador sobe), como as salas grandes do Isaac. De quebra a
  area sobe para 573k px2, ACIMA dos 522k originais, entao o orcamento de
  inimigos nao precisa reagir a nada. Quem cobra os dois lados hoje sao
  `teste_enquadramento.gd` (o regime, com corte em um terco do eixo) e
  `teste_camera.gd:_o_clamp_nunca_e_menor_que_o_quadro`.
- **Sala mais estreita que a tela nao e defeito: e vazio.** O corredor tem 768 px
  de largura contra 960 de tela. Antes o `_ajustar_zoom` dava zoom para dentro
  ate a sala preencher o quadro -- e reamostrava aquela sala inteira em zoom
  1,15, que e o "64 para 96 borra" aplicado a uma sala. Hoje o zoom e sempre
  inteiro e quem resolve e `GerenciadorMapa._cabendo_a_tela()`, crescendo o
  retangulo do clamp ate o quadro, CENTRADO. O que aparece nos 96 px de cada lado
  e o vazio alem da parede, e isso e desejado: e ele que diz que a sala e
  cavidade escavada em algo. Crescer para um lado so encostaria a sala numa borda
  -- exatamente o que o motor faz sozinho quando o limite e impossivel.
- **O TOPO e sorteado UMA VEZ POR SALA; a FACE, uma vez por lado.** Os dois ja
  sairam do mesmo sorteio por lado (`semente ^ (i * 0x9e3779b1)`), e o resultado
  era a sala vestir tres tijolos diferentes ao mesmo tempo -- norte com um, leste
  com outro, sul com um terceiro. O topo e a superficie NEUTRA e CONTINUA, a
  mesma que da a volta na sala e atravessa as quinas com a UV ancorada no
  contorno; duas variantes na mesma volta quebram a continuidade no unico lugar
  onde ela segura a leitura. A FACE e o oposto: ela carrega identidade, e a
  variedade entre lados e o que produz a biblioteca.
- **DIVIDA DE ARTE: os tres `parede_topo_*` nao sao variantes, sao tres
  MATERIAIS.** Medidos: `_a` sao placas 2x2 com rebite (orientacao -0,01), `_b` e
  tijolo irregular (-0,12), `_c` e painel de listras verticais (+0,10). Sortear
  entre eles nao produz "a mesma parede com outra cara" e sim uma sala de metal
  ao lado de uma de alvenaria. Hoje isso e uniforme DENTRO de uma sala e continua
  gritante ENTRE salas. O conserto e arte -- tres variantes do mesmo material --
  e nao codigo; o sorteio ja esta no lugar certo para receber.
- **A quina e MEIA ESQUADRIA, e nao um quad de topo.** O vao entre as duas
  faixas era preenchido inteiro com a textura de topo. Com 16 a 24 px ninguem
  via; com 96 virou um bloco de pedra entre duas faces, e a sala voltou a parecer
  feita de cubos -- o defeito que tirar o pilar desenhado existia para resolver.
  Hoje o retangulo e cortado na diagonal da quina interna a externa, e cada
  metade recebe as bandas do SEU lado, com a mesma textura e a mesma ancora de
  UV: a superficie vira, em vez de uma peca entrar por cima.
- **Quina de lado ABERTO nao se fecha.** `abertos` impedia a fita de vestir a
  boca de um corredor; a quina nao sabia disso e fechava as quatro do retangulo.
  Na boca, uma das direcoes aponta ao longo do corredor -- para DENTRO da sala
  vizinha --, entao o quad invadia a sala com `profundidade x profundidade`. Com
  o perfil raso cabia debaixo da parede da propria sala; com 96 virou um bloco
  entrando pela porta, nas DUAS bocas.
- **`EstiloDeParede` carregava uma SEGUNDA COPIA do perfil, e a copia venceu.**
  Os campos de espessura eram literais do perfil C e `perfil()` os escrevia por
  cima de um `PerfilDeParede` novo. O Lobby nao passa perfil e cai no default,
  entao ele recebeu dois epicos de parede inteiros; **as salas do andar 1 nao
  receberam nada**, e as duas entregas foram medidas, aprovadas e mergeadas sem
  tocar o jogo. Hoje os campos sao sentinela NEGATIVO (-1 = herda). E a regua
  tinha o mesmo ponto cego: `medir_moldura` montava a sala sem `DadosSala`, entao
  `_perfil()` devolvia null e ela media o DEFAULT enquanto o jogo desenhava
  outra coisa.
- **A SALA E UMA CAIXA ABERTA VISTA DE CIMA, e os quatro lados desenham a mesma
  coisa.** `corpo 48 + cap 12 + sombra 4`, nos quatro. Esta regra ja foi o
  contrario duas vezes, e a ultima virada tem medicao: o modelo direcional dava
  norte 60, lateral 36 e sul 32, e o jogo mostrou que as quinas diziam "ha uma
  moldura" enquanto os lados diziam "ha um acabamento". A dispersao entre lados
  era de **40%** contra o teto de 10% que o plano pede. A perspectiva passa a vir
  do chanfro, da sombra e da orientacao da textura -- **nunca da diferenca de
  massa**. `tools/comparar_caixa.tscn` guarda o par, e
  `baseline_assimetrico/` guarda a foto do estado anterior.
- **A correcao nao foi igualar nove campos: foi TIRAR do recurso a capacidade de
  divergir.** `PerfilDeParede` tinha `face_norte`, `face_lateral`, `labio_sul`,
  `ledge_sul`... -- e foi essa liberdade que produziu a assimetria. Enquanto
  houver um campo por lado, alguem os gira em separado. Hoje ha UM `corpo`, e os
  quatro lados o leem; a assimetria de um andar futuro passa pelos `escala_*`,
  que sao uma declaracao visivel num lugar so. Mesma ideia do sentinela negativo
  do `EstiloDeParede`: campo que existe e campo que alguem gira.
- **O SUL tem corpo, e ele cresce para FORA da area jogavel.** Ele ja foi face
  cheia, depois campo de topo, depois soleira (`labio + ledge + queda`), e agora
  a mesma parede dos outros tres. O medo que produziu a soleira era concreto --
  uma face alta ao sul cobriria o jogador --, e a resposta nao e tirar a face: e
  faze-la crescer para fora. A maior parte dela fica abaixo do piso na tela,
  entao nao ha nada a esconder e nenhum foreground e necessario. Sem face, aquele
  lado media 32 px contra 60 do norte e lia como uma linha.
- **A SOMBRA DE CONTATO existe nos QUATRO lados, e o sul nao tinha nenhuma.** Era
  isso que fazia o piso parecer TERMINAR ali em vez de descer. Ela e o segundo
  anel: contorna a sala inteira, chanfro incluido -- e no chanfro ela precisou
  passar a ser TRANSLUCIDA como no lado reto, senao o anel quebra na quina (N1
  opaco mede luma 13 sobre um chao de 14 a 16, e some).
- **O portao que mede espessura tem de ler o POLIGONO, e reconhecer o corpo pela
  FRONTEIRA e nao pela cor.** A primeira versao procurava `COR_FACE` e mediu ZERO
  nos quatro lados das nove formas, com o codigo certo: num `Polygon2D` com
  textura, `color` MULTIPLICA a arte, entao `_superficie()` escreve ali a TINTA
  (branco) e a cor de familia so sobrevive no modo silhueta. A fronteira nao
  mente -- so o corpo comeca no contorno; a sombra comeca em -4, e o cap e a
  flange comecam em 48.
- **Decalque de cap nao e medido pela grade de 16: e medido pelo CAP.** As cinco
  tiras foram desenhadas com 16 px para um cap de 40. Com o cap em 12,
  `_decalque_no_trecho()` recusa toda peca que nao cabe e a decoracao inteira do
  #244 SUMIRIA -- sem erro, com os cinco arquivos intactos em disco. Medido: 0%
  dos trechos receberam decalque, contra os 2 a 35% esperados. Hoje elas tem 8 px
  (`cap - borda - bisel`), e quem separa as duas familias e o campo `onde: cap`
  em `AUTORADAS` -- e nao o prefixo do nome, porque renomear nao da erro nenhum.
  Os atlas de decalque de CHAO continuam na grade.
- **A regua de profundidade varria SO COLUNAS, e isso era cegueira herdada.**
  Uma coluna vertical atravessa as bandas norte e sul e nunca encontra as
  laterais, que sao bandas VERTICAIS. Com o jogador encostado a leste, a
  `sala_1_retangular` media amplitude **0,059** com a parede leste ocupando a
  beira inteira do quadro. Isso nao doia enquanto a parede era assimetrica --
  a massa vivia no norte e era la que se olhava --, e virou defeito no dia em
  que os quatro lados passaram a valer igual. Foi essa cegueira, e nao a arte,
  que reprovava a `sala_5_pilar` em `formas_paredes`: varrendo os dois eixos ela
  vai de 0,196 para **0,345**.
- **E a janela da suavizacao e ESPACIAL, entao ela tem de seguir o zoom.**
  `formas_paredes` da zoom para fora ate a sala inteira caber; no pilar
  (960x960) o fator e 0,486 e o cap de 12 px chega a 5,8 na tela, onde a mediana
  movel de 9 px o apaga inteiro. A regua respondia sobre o ZOOM em vez de sobre a
  arquitetura. Hoje `ReguaDeProfundidade.medir()` recebe a escala da captura;
  quem fotografa em zoom 1,0 passa o default e nada muda.
- **O aviso de area desenhava em coordenada de MUNDO, e o rasterizador e
  float32.** `Telegrafo._draw` somava `_centro` em cada vertice, entao um disco
  de 12 px de raio a 71 mil px da origem chegava com as diferencas entre
  vertices vizinhos perdidas na cancelacao: `Invalid polygon data, triangulation
  failed`, duas linhas por execucao da suite, rodando ha muito tempo sem dono --
  erro de rasterizacao nao volta como valor. No JOGO nao aparecia, porque o andar
  cabe em poucos milhares de px; era por isso mesmo que valia consertar, porque
  um aviso que depende de a sala ficar perto da origem some no dia em que o mapa
  crescer. O centro foi para a transformacao, e `poligono_desenhado()` existe
  para o portao poder conferir sem renderizar.
- **A profundidade tem de fechar a GRADE, e nao e escolha de gosto.** Com 60 px
  por lado, `contorno + margens` cabe em 960 num contorno de 768 -- multiplo de
  32, com meia-dimensao na grade de 16 -- e sobram 36 px de vazio de cada lado. E
  o vao da parede compartilhada do #246 deriva disso: `60 x 2 = 120`, arredondado
  para **128**. Esse numero e exatamente o limiar em que
  `Corredor._montar_fita()` desiste de desenhar parede propria (`<= 128`), entao
  a conexao continua nascendo como piso e colisao e mais nada. A coincidencia e
  feliz e fragil: quem mexer no corpo tem de olhar aquele limiar junto.
- **"A parede aparece?" e "aparece QUANTO?" sao portoes diferentes, e o primeiro
  sozinho aprovou 6,1%.** O regime de enquadramento respondia SIM para a lateral
  fina: o eixo estava FECHADO, a parede ESTAVA em quadro, ela so era fina demais
  para ler. Quem pergunta o quanto e
  `teste_enquadramento.gd:_a_moldura_ocupa_o_quadro_em_QUALQUER_posicao`, com
  piso de 15% no PIOR canto do clamp -- e a `sala_3_grande` e excecao declarada,
  porque numa sala aberta nos dois eixos a parede ser rara no meio dela e o
  desenho.
- **Portao que afirma um TAMANHO envelhece junto com o perfil.** O caso que
  mordia em `teste_enquadramento` montava "uma sala do tamanho exato da tela" e
  exigia que ela reprovasse. Com a parede mais grossa aquele tamanho deixou de
  ser patologico -- margens de 96 e 104 dao folga 192x208, acima do corte -- e o
  caso passou a reprovar o codigo certo. Hoje ele afirma a REGRA (uma folga no
  meio termo reprova, seja de que sala for) e guarda os numeros historicos, 64 e
  68 px, ao lado.
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
- **O perfil do corredor decora pelo CHAO e pelo DECALQUE, nunca pela face.** A
  solucao obvia -- vestir a face do corredor com os modulos de tubulacao,
  tecnica e deteriorada -- colide de frente com a regra da noite base: aqueles
  modulos so existem nos TINGIMENTOS de tipo de sala, entao vestir um deles
  anuncia qual sala vem. As tres texturas de chao SAO a noite base, entao
  escolher entre elas por perfil nao diz nada; e uma valvula desenhada no piso e
  muda. Quem guarda a fronteira e
  `teste_conexoes.gd:_o_perfil_de_corredor_nao_anuncia_a_vizinha`, porque um
  `.tres` novo apontando `textura_chao` para `chao_boss.png` compila, carrega,
  desenha e desfaz a regra do andar inteiro sem uma linha no console.
- **"5 a 15% das arestas" e "uma, as vezes duas" NAO sao o mesmo criterio.** Com
  9 arestas por andar, uma conexao vale 11% e duas valem 22%. Medido em 24
  andares: **15,3% das arestas e 1,38 corredor por andar** -- fora da primeira
  faixa e dentro da segunda. Duas coisas empurram a fracao para cima e nenhuma e
  o sorteio: o corredor do chefe e RESERVADO (11% sozinho), e o tipo e sorteado
  por FRONTEIRA -- uma fronteira que caia em corredor veste TODAS as arestas que
  a cruzam. O portao morde em corredor POR ANDAR, que e o que descreve o desenho.
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
- **So a METADE DE BAIXO de cada modulo de face chega a tela.** Medido no motor:
  o quad de face tem `Sala.ALTURA_FACE` = 32 px e a UV, que e em PIXELS ancorada
  no canto do contorno, vai de -32 a 0 -- numa textura de 64, com repeticao,
  isso amostra as linhas 32..63. A metade de cima nunca aparece, e nada avisa:
  o arquivo continua valido e o portao media o arquivo INTEIRO. Hoje o portao
  de densidade e o mostruario do `sala_prototipo` medem e mostram a faixa
  desenhada. Nao mude `ALTURA_FACE` para 64 para "consertar": o
  `LOW_TOPDOWN_SQUARED.md` secao 24 exige face ~= topo na razao 1:1, e hoje isso
  ESTA satisfeito (a face cobre os 32 px internos da faixa de 64 e o topo os 32
  externos). Subir a face zera o topo visivel; o conserto certo, se um dia
  valer, e a faixa inteira de 128 px, que e outro epico.
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
- **A SUBORDINACAO DO TOPO e a NAO-COMPETICAO DO CHAO sao dois portoes em
  oposicao direta, e o gargalo e o CHAO.** A #242 pede o topo abaixo de 0,75 da
  energia da face; ele esta em 1,547. Calmar o topo funciona -- medido, ele desce
  a 0,780 --, mas cada ponto de calma tira detalhe da PAREDE, e
  `_o_piso_nao_compete_com_a_parede` exige que o piso use no maximo 40% do
  detalhe dela:

      corte      subordinacao (teto 0,75)   detalhe da parede   chao/parede (teto 40%)
      sem calmar         1,547                    49,7%                33%
      0,70               1,213                    38,5%                43%
      0,38               0,780                    22,5%                73%
      0,34               0,786                    20,2%                81%

  **Nao ha janela**: o calmante mais brando ja quebra o portao do chao, e a
  subordinacao ESTACIONA em ~0,78 (de 0,38 para 0,34 ela piora). O piso de
  16,4% de detalhe do chao e o que limita quao calma a parede pode ficar --
  entao a proxima tentativa comeca pelo CHAO e nao pelo topo. A ferramenta
  (`--acalmar`) fica pronta e desligada.
- **Desfoque numa textura que LADRILHA tem de dar a volta.** O filtro do PIL
  grampeia na borda, entao a banda baixa perto do limite sai calculada com o
  pixel de borda repetido em vez de com o outro lado do tile: medido, a costura
  em x saltou de 0,96 para 1,45 contra um teto de 1,10, e a textura deixou de
  ladrilhar. Ladrilhar tres por tres e recortar o miolo resolve.
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
- **A porta tem de cortar a PILHA INTEIRA, e nao so a face.** A regra antiga --
  "o topo atravessa o vao porque sobre a porta ha verga" -- vale para uma parede
  de 96 px vista quase de frente. No SUL, onde a pilha e uma soleira de 32 px
  vista de CIMA, a verga cobre a passagem inteira e o jogador atravessa por baixo
  do desenho, sem erro nenhum no console.
- **O chanfro de quina nao e um LADO: e a TRANSICAO entre dois.** Desenhado como
  lado, com normal diagonal e profundidade propria, ele ultrapassa o limite dos
  vizinhos -- medido, a lateral reservava 36 px e o chanfro alcancava 44, e o
  quadro passava a mostrar vazio na borda. Cada ponta dele e deslocada pela
  normal do SEU vizinho, e a banda vira um trapezio que encosta exatamente onde
  as duas terminaram. De graca: nao sobra cunha nenhuma para fechar depois, e
  `_fechar_quinas` pula todo vertice que e ponta de chanfro.
- **E ele nao projeta SOMBRA propria.** As sombras dos dois lados ja se encontram
  na quina; uma terceira na diagonal soma por cima. Medido na sala em L, que tem
  seis quinas: a sombra saltou de 8% do chao para 12,8%, e o teto existe porque
  sombra e o que come area de combate.
- **Linha de contato opaca e invisivel.** N1 tem luma 13 e o piso do andar 1 mede
  14 a 16: a primeira versao existia em disco e nao aparecia em tela. Contato e
  SOMBRA, e sombra escurece o que esta embaixo -- um valor absoluto so funciona
  se por acaso ele for mais escuro que aquele piso. Ela e translucida, no mesmo
  alfa da `SombraDeParede`.
- **Regua que mede "faixa de parede" tem de inflar por LADO.** `margens()` inclui
  a margem exterior, e `medir_moldura` inflava por ela: o vazio declarado entrava
  na conta como "faixa que ninguem pintou", e `crua` saltou de 0,9% para 9,5% sem
  um pixel mudar de dono. Inflar por um numero so tambem nao serve com a parede
  assimetrica -- os 28 px que o sul nao desenha viravam defeito.
- **Decalque que apenas "nao e mais claro que o chao" SOME.** A regra estava
  escrita e nao bastava: com o default da familia (`alvo_v` 0,10) o decalque sai
  com luma mediana **0,080** contra **0,079** do `chao_andar1_a` -- ele nao fica
  mais claro, ele fica EXATAMENTE em cima. Composta sobre o piso, a seta e a
  faixa de perigo desapareciam e so a base de maquina se via, porque ela tem
  parafusos claros. O que faz a peca ler e separar para BAIXO: `--alvo-v 0.055
  --compressao-v 0.30` poe o p90 dela em 0,061, logo abaixo do p10 do chao, e ela
  vira silhueta escura -- que e como uma marcacao gasta se ve. O chao do CHEFE e
  mais escuro ainda (p10 0,042), entao o decalque dele desce junto, para 0,038.
- **O TINGIMENTO muda a orientacao medida, e escolher composicao por um tipo so
  aprova arte que reprova noutro.** A `parede_face_deteriorada` media +0,203 no
  tingimento de combate (200 graus) e **+0,198** no do chefe (337) -- dois
  milesimos abaixo do piso de `_a_face_le_como_superficie_VERTICAL`. Luma pesa os
  canais de forma diferente, entao girar o matiz gira o balanco entre `energia_x`
  e `energia_y`. Toda varredura de composicao mede os DOIS extremos da rampa.
- **Reprocessar pelo funil um PNG que ja passou por ele COME detalhe.** Medido
  nos tres chaos do andar 1: densidade de 16,4% / 16,9% / 12,3% cai para 8,1% /
  6,1% / 4,0%, e a razao piso/parede sai do piso de 15% em duas das tres. A causa
  e a requantizacao para a paleta, que acontece de novo. Arte pronta se
  ACRESCENTA (decalque, prop, overlay); ela nao se "melhora" passando pelo funil
  outra vez.
- **A verticalidade da face e a distinguibilidade entre modulos PUXAM PARA LADOS
  OPOSTOS.** `_a_face_le_como_superficie_VERTICAL` exige orientacao >= 0,20 de
  toda face, o que comprime UM dos dois eixos da assinatura para todas ao mesmo
  tempo -- sobra a densidade para separar cinco pecas. Numa composicao sobre a
  mesma chapa da para ver a troca linha a linha: peca maior deixa o modulo
  distinto e horizontal, peca menor faz o contrario. O ponto que passa nos dois
  existe e nao se acha a olho: varra arranjo x escala e meca. Foi assim que
  sairam o `energia` do chefe e a `deteriorada`; a `tubulacao` nao tem ponto
  nenhum, porque tubo vertical sobre chapa vertical cai na regiao de `comum` e
  `ventilada`.
- **`teste_texturas.gd` compara o PNG em disco com o gerador.** Mudou uma cor
  em `paleta.gd` ou um traco em `gerar_texturas.gd`? Rode o gerador e o
  `--import` de novo, senao a suite reprova com "gerou e esqueceu de rodar?".

- **`Arma.ficou_sem_municao` NUNCA disparou, e por isso a regra que ele executava
  estava errada em silencio.** As 21 armas do jogo tem `municao_maxima = -1`
  (reserva infinita), conferido arquivo a arquivo -- entao
  `Player._ao_acabar_municao()` e codigo morto desde que as armas nasceram. Ele
  dizia "arma vazia volta para a pistola do slot 0", e essa regra morreu no dia
  em que os dois slots viraram simetricos: nao existe mais slot privilegiado
  para onde voltar. Codigo morto que afirma uma regra falsa e pior que codigo
  morto -- ele volta a rodar no dia em que alguem escrever a primeira arma de
  reserva finita, e faz a coisa errada sem uma linha no console. Hoje ele
  esvazia o slot e passa a mao para o outro.
- **O PENTE e estado do SLOT, e o componente `Arma` e UM so.** `equipar()`
  enchia o pente toda vez, entao sair da Mantis com 3/32 e voltar meio minuto
  depois devolvia 32/32 de graca -- uma arma que nunca precisa recarregar desde
  que voce alterne antes. Hoje `Arma.equipar(dados, pente_inicial)` recebe o
  numero, e quem o guarda e a `InstanciaDeArma`. O default continua sendo "pente
  cheio", entao os cinco inimigos e o chefe nao mudaram uma linha.
- **`pedir_aquisicao()` com os dois slots cheios NAO PODE MEXER EM NADA.** Ele
  devolve `PRECISA_ESCOLHER` e sai. Uma versao que ocupasse o slot antes de
  perguntar faria o jogador perder uma arma toda vez que cancelasse a tela de
  troca -- e cancelar e justamente a acao que nao pode custar nada, porque e ela
  que permite sair, comparar e voltar depois.
- **A arma substituida cai EXATAMENTE onde o jogador esta, e isso e um laco
  fechado.** Ele acabou de encostar no pickup para disparar a troca, entao a
  arma largada dispara o `body_entered` no frame seguinte, os dois slots
  continuam cheios, e a tela reabre sobre uma arvore que ja esta pausada: um
  painel que volta sozinho, para sempre, com o console limpo. Por isso
  `PickupArma.soltar_no_chao()` ja nasce travada -- e por isso a trava entra
  tambem no CANCELAMENTO, porque quem cancelou tambem nao saiu de cima do
  pickup.
- **Tela que pausa a arvore precisa de `PROCESS_MODE_ALWAYS`.** Sem isso ela
  congela junto com o que ela mesma pausou e a escolha nunca chega -- o jogo
  trava num painel que nao aceita tecla. Vale para a tela de troca e para a de
  inventario, pela mesma razao que ja valia para o `menu_pausa` e para o
  reticulo.
- **Nenhuma das duas telas mexe em `Input.mouse_mode`.** O reticulo e o dono do
  cursor e ele ja devolve a seta ao ver `get_tree().paused` -- um segundo dono
  produziria uma seta que aparece ou some conforme a ordem das chamadas.
- **Suite que abre a tela de troca tem de DESPAUSAR no fim.** Ela pausa a arvore
  ao montar; deixada pausada, TODAS as suites seguintes que esperam passo de
  fisica congelam, e o runner fica vivo ate o timeout do CI sem imprimir nada.
- **`comprar()` da Loja continua SINCRONA, e a arma que nao cabe sai dela
  inteira.** Transformar aquela funcao em corrotina faria o `not
  bancada.comprar()` de `teste_loja.gd` comparar um `Signal` com `false`, e o
  portao da ordem da transacao viraria carimbo. Ela delega para
  `_comprar_com_escolha()` e devolve `false` -- nada foi comprado NAQUELE frame,
  que e a verdade. O contrato so ganha um passo na frente: escolha, entrega,
  debito.
- **`categoria_corporal` e o pior tipo de campo deste projeto: um que so a UI
  le.** Nada em jogo o consulta, entao um `.tres` que o esqueca funciona
  perfeitamente e so aparece na regiao errada -- um desenho que parece
  deliberado e nao e. Por isso `teste_inventario.gd` tem a tabela
  `ESPERADO` com os 16 por id, e ela morde dos dois lados: implante fora dela
  reprova em vez de SUMIR da conta, que e o defeito que
  `_nenhum_png_fica_fora_de_regime` existiu para consertar.
- **E o valor ZERO do enum de categoria e o NEUTRO (`SISTEMA`).** Um implante
  criado no editor sem tocar no campo cai no valor 0; se ele fosse `NEURAL`,
  toda peca esquecida AFIRMARIA uma regiao que ninguem escolheu. Afirmar errado
  e pior que nao afirmar.
- **O CORPO FOI REPROVADO, e `categoria_corporal` ficou.** A primeira versao da
  aba de itens desenhava uma silhueta tecnica com os implantes pendurados por
  regiao, ligados por linhas; o dono do projeto olhou e reprovou -- a ideia pode
  voltar, mas por enquanto o inventario responde "o que eu tenho" e nao "no que
  eu me transformei". O campo continua nos 16 `.tres` e continua cobrado, pelo
  mesmo motivo que a suite da Diretora continua no runner sem que nenhuma run
  passe por ela: **e justamente por nao ser lido em jogo que ele precisa
  continuar conferido.** Sem o portao, os dezesseis apodreceriam em silencio ate
  o dia em que a ideia voltasse -- e ai seriam reescolhidos do zero.
- **Os implantes continuam ACUMULATIVOS, e a aba de itens NAO pode prometer o
  contrario.** Ela desenha uma grade que cresce, e nao uma fileira de vagas:
  vaga desenhada promete um limite que nao existe. `Modificadores` continua
  somando sem teto, e as 16 pecas continuam balanceadas assim.
  `_os_implantes_continuam_ACUMULATIVOS` cai no dia em que alguem transformar
  isso em equipamento por localizacao sem perceber.
- **As tres abas sao tres PERGUNTAS, e nao arrumacao.** ITENS nao tem teto,
  ARMAMENTO tem exatamente dois, e STATUS e derivado dos outros dois. Fundir
  duas delas obriga o jogador a descobrir sozinho qual das regras vale para o
  que ele acabou de pegar -- e a lista, que e a mais importante, perde coluna
  para a tabela derivada.
- **A aba STATUS DERIVA, nunca recalcula.** Cada linha pergunta ao
  `Modificadores` no instante do desenho. Uma UI que refizesse a conta dos
  implantes viraria a segunda fonte de verdade sobre a build e divergiria na
  primeira mexida num `EfeitoItem`: o painel diria +12% e o tiro entregaria
  +10%, sem erro nenhum. `teste_inventario.gd` compara o texto com o
  que o autoload responde no mesmo instante.
- **`tags_de()` e `linhas_de_diagnostico()` sao `static` e devolvem a CHAVE em
  portugues.** `tr()` e metodo de `Node` e nao existe em funcao estatica -- mas o
  motivo maior e outro: uma suite que lesse texto ja traduzido passaria na
  maquina de quem tem o SO em portugues e quebraria no CI, que roda em ingles.
  Quem traduz e quem desenha.
- **A geometria do clique sai de quem DESENHOU.** `TelaTrocaDeArma._slot_sob()`
  pergunta a `PainelDeTroca.caixa_do_slot()` em vez de recalcular a caixa: dois
  calculos da mesma geometria divergem, e o sintoma e a tela clicavel num lugar
  e desenhada noutro, sem erro nenhum no console.
- **A HUD LE o inventario em vez de acumular o proprio par de armas.** Uma copia
  ali divergiria na primeira substituicao feita pela Loja, que nao emite
  `arma_equipada` para o slot que saiu.
- **O inventario nao abre sozinho ao pegar um implante.** Interromper o combate
  para mostrar o que o jogador acabou de escolher e cobrar duas vezes pela mesma
  decisao. Quem avisa e o `AvisoItem` da HUD, que pisca o nome e some em 3 s.
- **`draw_string` com `HORIZONTAL_ALIGNMENT_RIGHT` alinha dentro de
  [`pos.x`, `pos.x + width`], e `pos.x` e a borda ESQUERDA.** Passando a borda
  direita ali, o texto e desenhado INTEIRO para fora do painel: a coluna de
  valores do diagnostico sumiu assim, e o rotulo `ATIVA` do slot tambem. Nao ha
  erro nenhum -- ha um painel pela metade que parece proposital, e portao de
  logica nenhum pega isso. Quem pegou foi a captura.
- **Largura maxima de tabela nao e gosto.** Esticada pela aba inteira (904 px),
  cada linha do diagnostico vira um rotulo numa ponta e um numero na outra com
  meio quadro de vazio no meio; e os dois cartoes de arma viram faixas em que o
  nome e as barras da MESMA arma ficam a meia tela de distancia. Duas armas e
  oito linhas nao preenchem uma tela, e fingir que preenchem e o que faz a aba
  parecer vazia.
- **Nome cortado por `width` le como texto QUEBRADO, e nao como abreviado.**
  `draw_string` com largura maxima apenas CLIPA, no meio da palavra. O corte tem
  de ser explicito -- e com `..` ASCII e nao com reticencia unicode, porque
  glifo que a fonte nao tem some sem erro e o nome volta a parecer quebrado.
  Mesma armadilha do losango da moeda no preco da bancada.
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
- **Template do PixelLab DEFORMA ator com silhueta propria.** O `throw-object`
  com `ai_freedom = 0` prende o desenho ao esqueleto do template: o Automato --
  que e largo, de ombros e bracos grossos -- saiu com a MESMA altura e METADE da
  largura (bbox de 130 px caiu para 67), virando um humanoide magro no meio do
  proprio ataque. A paleta e a ferrugem passavam intactas, entao um portao de cor
  nao acusaria; o que muda e a silhueta, que e justamente o que o jogador le. Em
  ator com forma propria use `mode = "v3"` com `action_description`, que foi o
  que manteve os 130 px. Custa 2 geracoes por direcao em vez de 1, e o preco de
  descobrir isso depois sao 8 geracoes jogadas fora.
- **Palavra de ENERGIA no `action_description` vira efeito desenhado.**
  "exploding into a charge" produziu literalmente uma estrela de explosao amarela
  cobrindo o chefe ao sul e jatos de chama ao leste -- fora da paleta, brilhante,
  e diferente em cada direcao. O prompt de gesto descreve o CORPO e mais nada:
  "bending the knees deep and leaning far forward with one shoulder dropped low"
  deu o agachamento que a investida pede. Mesma licao para o pisao: "massive leg"
  nao produziu movimento nenhum, "lifting one knee up to chest height" produziu.
- **Manifesto de URLs do PixelLab expira, e le-lo custa caro.** As URLs sao
  assinadas no proprio link e caducam, entao manifesto velho falha no download.
  Pior que isso: para montar um manifesto e preciso ler o `get_character`, cuja
  saida cresce com cada animacao -- num chefe com quatro ataques em oito direcoes
  ela ja passa de dez mil palavras, das quais se aproveita uma URL por direcao. O
  PACOTE do personagem resolve os dois: `baixar_pixellab.py <id> <clipe>
  pacote.zip#animacao [a-b]`.
- **UMA geracao vira DOIS clipes, e o corte tem de cair no golpe.** O preparo e o
  golpe saem da MESMA fita cortada em 0-3 e 4-6, e nao de duas geracoes: o punho
  que sobe no preparo e o mesmo que desce no golpe, sem risco de duas geracoes
  discordarem. `QUADROS_DE_PREPARO` em `teste_boss_animacao.gd` e cobrado contra
  o `.tres` desde a ANIM 04 -- antes ele era uma constante escrita antes de a arte
  existir, e um clipe redesenhado com 6 quadros continuaria sendo medido como 4.
- **Clipe declarado nao prova que alguem o DESENHA, e e a armadilha que criou
  este epico.** `encenar()` devolve `false` em silencio quando o nome nao existe
  ou o clipe nao e desenhavel, e o corpo cai na pose parada. Todo caso de TEMPO
  desta suite continuaria verde: eles medem a duracao do ESTADO, que nao depende
  de quem desenha. Por isso ha dois portoes e nao um --
  `_o_gesto_pedido_existe_e_tem_a_contagem_medida` confere o NOME, e
  `_o_corpo_do_chefe_TROCA_para_a_fita_do_gesto` confere o PIXEL, entrando em
  PREPARAR e exigindo que `sprite.texture` esteja na lista de fitas do clipe.
- **Gesto que falta e DECLARADO em `SEM_CLIPE_AINDA`, e a lista morde dos dois
  lados.** Mesmo desenho do `SEM_ARTE_AINDA`: nome fora dela tem de existir, nome
  DENTRO dela tem de continuar faltando. Sem a segunda metade a ANIM 05 entregaria
  o Reator e a linha ficaria ali para sempre, cobrindo em silencio o dia em que
  aquele clipe se perdesse.
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
- **`no_background` do PixelLab NAO devolve alfa.** As 16 pecas de icone voltaram
  **100% opacas**, com o fundo pintado de chapado -- e o passo "recorta no alfa"
  do funil nao tinha no que morder. Pior que isso, o fundo vem em **dois tons
  quase iguais** (medido: 73,6% de um e 26,4% de outro, a 9 de distancia), entao
  uma tolerancia apertada deixa o segundo tom para tras e a peca sai com a
  moldura inteira colada, bbox 256x256 onde o objeto tem 90x232. `preparar_icone.py`
  recorta por PREENCHIMENTO A PARTIR DA BORDA com tolerancia 24 -- o MEIO do
  plato medido, porque 24 e 32 dao resultado byte a byte identico.
- **E o recorte tem de ser por conexao, nunca por cor.** O fundo do `vampirico` e
  `(171,170,170)`, um cinza da mesma familia do aco da propria seringa: "apague
  todo pixel igual a cor do fundo" abriria buraco DENTRO da peca. So sai o fundo
  que ALCANCA a borda -- e de graca isso resolve os dois casos opostos, porque o
  vao entre as metades do `fragmentador` alcanca a borda (e sai, certo) e o furo
  cercado de um anel nao alcanca.
- **Mas fundo CERCADO pelo desenho e furo, e nao desenho.** O miolo do anel do
  `gatilho` saiu um disco BRANCO opaco, e o laco de cabo do `servo` tambem.
  `--vazar-furos` apaga esses comparando por COR, e por isso nasce DESLIGADO e e
  ligado peca a peca: `daemon` tem **12519 px** de fundo cercado que sao a face
  lavanda do proprio chip, e vazar ali apagaria a peca inteira. A mesma bandeira
  que salva uma arte destroi a vizinha.
- **A arte generativa nasce clara demais para este jogo, e isso e um NUMERO.**
  Cruas, **doze das dezesseis** reprovaram a faixa de leitura do
  `laboratorio_icones`, e tres passaram do teto de competicao com projetil
  (`gatilho` 82%, `dissipador` 80%, `celula_eco` 70%). Icone que compete com tiro
  e o defeito que a ficha de credito ja existe em losango para evitar. O funil
  assenta o VALOR ate a mediana do MIOLO cair em 0,42 -- e **so o valor**: girar
  matiz faria o icone discordar do campo `cor` do `.tres`, que o pickup e a HUD ja
  leem, e o jogador veria a ficha de uma cor e o aviso de outra.
- **E o assentamento so DESCE.** As duas pecas que ficaram escuras demais
  (`penetrador` 0,290 contra o piso de 0,30, `vampirico` 0,235) foram
  REDESENHADAS com a cor do item pintando o corpo, e nao clareadas. Um funil que
  clareia para passar num numero esta inventando iluminacao -- e o "suavizar para
  caber num numero" que ja matou uma familia de textura aqui.
- **Master que ja tem alfa nao pode ser rechaveado.** O master versionado e o que
  faz `refazer_icones.py --lado 48` funcionar sem geracao nova; numa segunda
  passada, `cor_de_fundo()` leria o RGB dos pixels TRANSPARENTES -- que e preto --
  e o preenchimento comeria todo contorno escuro encostado na borda. A peca
  perderia a silhueta com o arquivo intacto e sem uma linha no console. Com a
  guarda, reprocessar o master e byte a byte identico.
- **Prompt de icone descreve o OBJETO, e uma palavra de funcao vira outra coisa.**
  "grupo de gatilho com solenoide" produziu uma **pistola inteira** -- e arma esta
  fora do escopo, entao o jogador leria a ficha como pickup de arma. So
  `"there is no gun, no barrel, no grip, only the trigger part"` resolveu. E o
  mesmo defeito que "exploding into a charge" ja tinha produzido no chefe, visto
  de outro angulo: o gerador desenha o que a frase diz, inclusive o que ela
  sugere sem querer.
- **Peca que "le otimo" pode estar errada pelo conjunto.** O `firewall` saiu um
  escudo medieval bonito e legivel, e foi refeito: as 16 pecas sao hardware da
  mesma fabrica, e um brasao ao lado de dezesseis modulos industriais quebra a
  unica coisa que faz o conjunto parecer um conjunto. Nenhuma regua de cor ou de
  silhueta pega isso -- ele passava em todas.
- **Prateleira metade ilustrada nao le como duas categorias: le como icone
  quebrado.** Os icones entraram so nos implantes, com as armas declaradas fora de
  escopo -- e o dono jogou e reportou "alguns icones nao estao funcionando na
  Loja". Medido: **303 de 600** ofertas sao ARMA, entao mais da metade da
  prateleira mostrava a forma antiga ao lado de uma peca desenhada. Nenhum portao
  pegava isso, porque cada metade estava certa sozinha. Familia visual so pode
  ser entregue INTEIRA, ou o que era "ainda nao" vira "quebrado".
- **Familia nova de icone = PASTA nova, e isso e o portao mandando.**
  `teste_icones_de_item.gd` exige que todo PNG de uma pasta tenha um `.tres` que o
  aponte, entao um icone de arma dentro de `assets/itens/` seria orfao e
  reprovaria -- com razao. O que NAO se separa e a medicao: `laboratorio_icones`
  le as duas pastas na MESMA matriz, porque item e arma dividem as tres bancadas
  da Loja e e ali que dois icones viram a mesma mancha. Separar o dono do arquivo
  nao pode virar separar a pergunta. Sao 26 pecas e **325 pares**.
- **Icone e losango solido juntos empilham duas respostas para a mesma
  pergunta.** O pickup desenhava os dois: o icone dizia QUAL item, e o solido
  dizia a mesma coisa numa linguagem mais pobre -- e sendo opaco ele nao ficava
  atras, ele emoldurava o desenho e roubava a silhueta, que e justamente o que a
  regua mede. O solido saiu e a cor dele passou para o HALO, que ja existia, ja
  pulsa junto e nunca tinha recebido a cor da peca (era mint fixo para os
  dezesseis). A leitura a distancia continua e vira EFEITO em vez de peca.
- **Arte que nao passa por `Visual` nao flutua sozinha.** O icone mora FORA do
  `Visual` de proposito (aquele no GIRA, e arte girando em angulo quebrado
  reamostra fora da grade), so que e o `Visual` que faz o bob -- entao o icone
  ficava parado enquanto o halo subia e descia debaixo dele. Copiar so a ALTURA
  no `_process` pega o unico dos dois movimentos que ele pode acompanhar sem
  pagar por isso.
- **Quem precisa de icone e quem tem PRECO, e nao quem esta na pasta.**
  `src/weapons/` guarda tambem a `pistola` (inicial, nunca vendida) e as duas
  armas do chefe. Cobrar arte delas encomendaria desenho que ninguem ve, e a
  lista de divida ficaria com tres nomes permanentes -- que e como uma lista de
  divida deixa de ser lida. O portao usa `valor_de_loja > 0`, o mesmo teste que
  `GeradorDeLoja._sortear()` ja faz para decidir o que vai a prateleira.

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
