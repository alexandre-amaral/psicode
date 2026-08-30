# psicode

Vertical slice de um **twin-stick shooter roguelike cyberpunk**. Você é um
ciborgue mercenário lutando contra a própria degradação: quanto mais a run
avança, mais a barra de **Deterioração** sobe — e a partir de 50% os inimigos
param de mirar em você e passam a mirar **onde você vai estar**.

Um andar de 8–12 salas sorteadas, terminando na **IA Diretora**. Começo, meio e
fim em ~4 minutos.

![Sala de combate](docs/capturas/07_sala_de_combate.png)

Cinco tipos de sala, sorteados a cada run — a cor do minimapa e o acento da
sala são a mesma cor, em intensidades diferentes:

| Sala inicial | Sala de arma | Sala de item |
|---|---|---|
| ![](docs/capturas/01_sala_inicial.png) | ![](docs/capturas/08_sala_de_arma.png) | ![](docs/capturas/09_sala_de_item.png) |

**A Deterioração não é uma barra decorativa.** Ela sobe sozinha e a cada sala
limpa, e tudo que é dificuldade lê o valor dela no frame em que precisa — então
a barra subindo afeta até os inimigos que já estão em tela:

| Estável (0–49%) | Degradando (50%+) | Crítico (85%+) |
|---|---|---|
| ![](docs/capturas/07_sala_de_combate.png) | ![](docs/capturas/02_deterioracao_media.png) | ![](docs/capturas/03_deterioracao_critica.png) |
| inimigos miram em você | **mira preditiva liga** — miram onde você *vai estar* | alucinação: glitch, vinheta, projéteis tremendo |

**A IA Diretora** fecha o andar em quatro fases. Todo ataque dela telegrafa —
o aviso encurta a cada fase, mas nunca some. Na última ela ancora e quem ataca
passa a ser a arena:

| Revelada | Bullet hell | Fase final |
|---|---|---|
| ![](docs/capturas/04_chefe_revelado.png) | ![](docs/capturas/05_chefe_bullet_hell.png) | ![](docs/capturas/06_chefe_fase_final.png) |

---

## Rodar em 3 passos

1. Instale o **Godot 4.7** (versão *standard*, não a .NET) — https://godotengine.org/download
2. Abra o Godot Hub → **Importar** → escolha o `project.godot` desta pasta
3. **F5**

Nunca usou Godot nem Git? Vá direto para **[docs/HANDOFF.md](docs/HANDOFF.md)** —
é um passo a passo do zero, feito para quem nunca abriu nenhum dos dois.

## Controles

| Ação | Tecla |
|---|---|
| Mover | `WASD` ou setas |
| Mirar | mouse |
| Atirar | botão esquerdo |
| Rolar (invulnerável) | `Espaço` ou botão direito |
| Trocar de arma | `Q` |
| Recarregar | `R` |
| Pausar / sair | `Esc` |
| +25% Deterioração (só em debug) | `F1` |

Tela cheia fica em **Opções**, no menu inicial ou no menu de pausa — a escolha
é lembrada na próxima vez que você abrir o jogo. Lá também dá para desligar o
tremor de câmera e a distorção visual.

`R` só reinicia depois que a partida termina; durante o jogo ele recarrega.

`F1` é o atalho mais útil do projeto: com ele você testa as fases da
Deterioração sem precisar limpar meio andar antes.

## Identidade visual

Pixel art de **noite azul com neon** — um complexo industrial escuro onde a luz
vem de filetes finos e telas apagadas, não de um sol.

A regra que sustenta tudo: num bullet hell, **cor saturada e clara é linguagem
de gameplay**. Ciano brilhante significa "seu tiro"; rosa brilhante significa
"tiro do chefe". Se a parede também pudesse ser ciano brilhante, a linguagem
quebrava. Por isso o jogo não tem uma paleta — tem **três**, e a regra é sobre
a fronteira entre elas:

| Paleta | Quem usa | Regra |
|---|---|---|
| **AMBIENTE** | chão, parede, corredor, props, moldura de porta | dessaturada **ou** escura — nunca as duas coisas brilhantes ao mesmo tempo |
| **ATOR** | player, inimigos, projéteis | saturada **e** clara. Exclusiva: nenhuma cor daqui aparece no ambiente |
| **SINAL** | porta trancada, telegrafo, brilho de pickup | brilhante, mas sempre numa forma grande demais para ser confundida com projétil |

Isso não é convenção de boa vontade: `tools/testes/teste_texturas.gd` abre cada
PNG e **reprova** a textura que cruzar a fronteira. Três portões — gamut,
leitura (`S > 0,35` **e** `V > 0,55` é proibido no ambiente) e separação
(`AMBIENTE ∩ ATOR = ∅`) — mais dimensão na grade, alpha sem meio-termo e
determinismo do gerador.

O critério que decide se uma textura entra é sempre o mesmo, e é visual:
**um projétil inimigo continua tão fácil de achar quanto antes dela?**

→ **[IDENTIDADE_VISUAL.md](docs/IDENTIDADE_VISUAL.md)** tem a paleta inteira, a
grade e as seis regras de leitura de combate.

### Em migração: Low Top-Down Squared

O jogo hoje é um top-down **chapado** — repare nas capturas acima: o quadro é
chão texturizado de ponta a ponta, e a parede é uma faixa fina que você só vê se
andar até a beira. Nada no enquadramento diz "isto é um espaço fechado".

A direção nova troca isso por **volume**, sem virar 3D nem isométrico:

```
        HOJE                          ALVO

  +--------------+            ####################  <- topo da parede
  |              |            ::::::::::::::::::::  <- face frontal
  |              |            ::::::::::::::::::::
  |      @       |
  |              |                   +------+
  |              |                   | TOPO |
  +--------------+                   +------+
                                     |FRENTE|       <- prop com volume
   chao ate a borda                  +------+
   parede sem altura                    ..          <- sombra

                                         @          <- ordenado por Y
                                        pes

                               ####################  <- parede sul, so o topo
```

O que muda: paredes com **topo e face frontal**, **Y-Sorting** pela base dos
objetos, **sombras** que ancoram cada coisa no chão, origem dos sprites no ponto
de contato, e uma direção de luz global (de cima/esquerda).

O que **não** muda: a grade continua cartesiana e quadrada, o chão continua sem
deformação de perspectiva, e colisão, navegação e geração procedural continuam
nos eixos X/Y normais. **A regra central é não inclinar o mundo no código** —
quem cria a perspectiva é a arte.

| | |
|---|---|
| Tile visual | 64 × 64 |
| Grade estrutural | 16 (coordenada) / 32 (dimensão de sala) — inalterada |
| Parede | espessura lógica 64, topo 64, face 64 |
| Regra verificável | altura da face ≈ altura do topo, **1:1 ±25%** |

> **Estado:** direção fechada e planejada, **nenhuma linha implementada ainda**.
> As capturas desta página são do jogo como ele é hoje. O acompanhamento está no
> épico [#47](https://github.com/alexandre-amaral/psicode/issues/47), dissolvido
> em 16 issues com o rótulo `low-topdown`.

→ **[LOW_TOPDOWN_SQUARED.md](docs/LOW_TOPDOWN_SQUARED.md)** (a direção) ·
**[Plano de Implementação](docs/Plano%20de%20Implementa%C3%A7%C3%A3o%20%E2%80%94%20Migra%C3%A7%C3%A3o%20para%20Low%20Top-Down%20Squared.md)** (as 30 fases) ·
**[PIVO_LOW_TOPDOWN.md](docs/PIVO_LOW_TOPDOWN.md)** (o que quebra no caminho)

## Stack

| | |
|---|---|
| Engine | Godot **4.7.2-stable** (standard) — a mesma versão do CI |
| Linguagem | GDScript |
| Renderer | Compatibility (GL) — garante export para web |
| Versionamento | Git + GitHub, LFS já configurado para arte futura |
| CI | GitHub Actions rodando o teste de fumaça a cada PR |
| Arte | pixel art: 2 personagens e **5 dos 8 inimigos** com 8 rotações e ciclo de caminhada, chefe com sprite próprio, texturas de sala autoradas. Atirador Neon, Hacker Parasita, as duas peças da arena do chefe, projéteis e pickups ainda são forma geométrica |
| Som | **nenhum** — é o buraco mais visível do projeto, e o marco M2 do roadmap |

Por que Godot e não Unity: cena (`.tscn`) e recurso (`.tres`) são **texto**,
então merge entre três pessoas funciona de verdade; o setup de quem entra no
projeto é um executável e nada mais; e o export para navegador é imediato, o
que importa muito quando o objetivo é mandar a build para amigos testarem.

## Estrutura

```
src/
  autoload/    EventBus, Deterioracao, GameState, Juice  (singletons)
  player/      jogador, rolamento, ecos
  weapons/     componente de arma + as armas como .tres
  projectiles/ projétil genérico (player e inimigo)
  enemies/     base + 8 inimigos (Rastejante, Vigia, Drone Aranha, Sentinela
               Orbital, Atirador Neon, Cyber-Besta, Hacker Parasita, Diretora)
               + grupo_*.tres: quem pode nascer numa sala, e a que custo
  mapa/        gerador do andar, sala, porta, corredor, as cenas de sala
               + tipo_*.tres: o catálogo de tipos de sala
  items/       implantes (.tres), pool de loot, pickup
  arena/       pickup de arma
  ui/          HUD, minimapa, barras, menus, tela de fim
  fx/          partículas
  util/        Balistica (matemática de mira preditiva)
assets/shaders/ glitch de alucinação
tools/       testes, réguas de tuning e captura de tela
docs/        HANDOFF, GDD, ROADMAP, CONVENCOES, TUNING, PLAYTEST
```

Duas regras de arquitetura sustentam tudo isso:

**1. Ninguém procura ninguém pela árvore de nós.** Quem faz algo emite no
`EventBus`; quem se importa escuta. A HUD não conhece o Player, o Player não
conhece o gerador do andar. Dá para apagar a HUD inteira e o jogo continua
rodando.

**2. Todo número de dificuldade vem de `Deterioracao`.** Nenhum inimigo guarda
uma velocidade já multiplicada — todos leem o autoload a cada frame. Por isso a
barra subir tem efeito imediato até nos inimigos que já estão em tela, e por
isso balancear o jogo é mexer num arquivo só.

## Balancear sem programar

O tuning mora em arquivos `.tres`, editáveis pelo Inspetor do Godot:

| O que ajustar | Onde |
|---|---|
| Dano, cadência, munição, spread das armas | `src/weapons/*.tres` |
| Quantos inimigos cabem numa sala, quanto a barra sobe | `src/mapa/tipo_*.tres` |
| Quem pode nascer numa sala, e com que peso | `src/enemies/grupo_*.tres` |
| Vida e velocidade dos inimigos | campos exportados em `src/enemies/*.tscn` |
| Um implante novo (só números) | `src/items/implante_*.tres` |
| Limiares de 50% e 85% | `src/autoload/deterioracao.gd` |

A lista completa, com o valor de hoje de cada botão e o que a medição já disse
sobre ele, está em **[docs/TUNING.md](docs/TUNING.md)**.

## Testes

```bash
# lógica pura, em segundos: "a conta está certa?"
godot --headless --path . tools/testes/runner.tscn

# o jogo inteiro sem janela: percorre o andar, mata o chefe, vence
godot --headless --path . tools/teste_fumaca.tscn

# réguas de tuning (não são testes: não passam nem falham, medem)
godot --headless --path . tools/medir_ritmo.tscn
godot --headless --path . tools/medir_composicao.tscn

# gera screenshots em user://capturas
godot --path . tools/capturar.tscn --resolution 960x544
```

O teste de fumaça também valida a matemática da mira preditiva e os limiares
da Deterioração. Ele roda sozinho em todo PR pelo GitHub Actions.

## Documentação

- **[HANDOFF.md](docs/HANDOFF.md)** — setup do zero, para quem nunca usou Godot nem Git
- **[GDD.md](docs/GDD.md)** — game design document
- **[ROADMAP.md](docs/ROADMAP.md)** — o que vem depois desta build
- **[CONVENCOES.md](docs/CONVENCOES.md)** — como trabalhamos em três sem pisar um no outro
- **[TUNING.md](docs/TUNING.md)** — todos os botões de balanceamento e o que a medição já disse
- **[BUILD.md](docs/BUILD.md)** — export Windows e web

Identidade visual:

- **[IDENTIDADE_VISUAL.md](docs/IDENTIDADE_VISUAL.md)** — as três paletas, a grade e os portões
- **[TEXTURAS_ANDAR_1.md](docs/TEXTURAS_ANDAR_1.md)** — a referência medida e virada receita
- **[LOW_TOPDOWN_SQUARED.md](docs/LOW_TOPDOWN_SQUARED.md)** — a direção de câmera e arte para onde o jogo está indo
- **[PIVO_LOW_TOPDOWN.md](docs/PIVO_LOW_TOPDOWN.md)** — o levantamento técnico da migração
