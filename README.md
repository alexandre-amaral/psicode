# psicode

Vertical slice de um **twin-stick shooter roguelike cyberpunk**. Você é um
ciborgue mercenário lutando contra a própria degradação: quanto mais a run
avança, mais a barra de **Deterioração** sobe — e a partir de 50% os inimigos
param de mirar em você e passam a mirar **onde você vai estar**.

Um andar de 10 salas sorteadas, terminando na **IA Diretora**. Começo, meio e
fim em ~4 minutos.

![Sala de combate](docs/capturas/07_sala_de_combate.png)

| Deterioração média | Chefe final |
|---|---|
| ![](docs/capturas/02_deterioracao_media.png) | ![](docs/capturas/05_chefe_bullet_hell.png) |

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

## Stack

| | |
|---|---|
| Engine | Godot **4.7.2-stable** (standard) — a mesma versão do CI |
| Linguagem | GDScript |
| Renderer | Compatibility (GL) — garante export para web |
| Versionamento | Git + GitHub, LFS já configurado para arte futura |
| CI | GitHub Actions rodando o teste de fumaça a cada PR |
| Arte | pixel art: personagens com 8 direções e ciclo de caminhada, texturas de sala geradas por código, sprite do chefe. Projéteis, pickups e 7 dos 8 inimigos ainda são forma geométrica |

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
  enemies/     base + Rastejante (melee) + Vigia (ranged) + Diretora (chefe)
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
