# psicode

Vertical slice de um **twin-stick shooter roguelike cyberpunk**. Você é um
ciborgue mercenário lutando contra a própria degradação: quanto mais a run
avança, mais a barra de **Deterioração** sobe — e a partir de 50% os inimigos
param de mirar em você e passam a mirar **onde você vai estar**.

Cinco ondas numa arena fechada, terminando na **IA Diretora**. Começo, meio e
fim em ~5 minutos.

![Onda 1](docs/capturas/01_onda1_estavel.png)

| Deterioração média | Chefe final |
|---|---|
| ![](docs/capturas/02_deterioracao_media.png) | ![](docs/capturas/05_chefe_bullet_hell.png) |

---

## Rodar em 3 passos

1. Instale o **Godot 4.6** (versão *standard*, não a .NET) — https://godotengine.org/download
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
| Reiniciar | `R` |
| Pausar / sair | `Esc` |
| +25% Deterioração (só em debug) | `F1` |

`F1` é o atalho mais útil do projeto: com ele você testa as fases da
Deterioração sem precisar limpar quatro ondas antes.

## Stack

| | |
|---|---|
| Engine | Godot **4.6-stable** (standard) |
| Linguagem | GDScript |
| Renderer | Compatibility (GL) — garante export para web |
| Versionamento | Git + GitHub, LFS já configurado para arte futura |
| CI | GitHub Actions rodando o teste de fumaça a cada PR |
| Arte | nenhuma ainda — tudo é forma geométrica desenhada por código |

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
  arena/       arena, ondas (.tres), spawn, pickups
  ui/          HUD, barras, tela de fim
  fx/          partículas
  util/        Balistica (matemática de mira preditiva)
assets/shaders/ glitch de alucinação
tools/       teste de fumaça e ferramenta de captura de tela
docs/        HANDOFF, GDD, ROADMAP, CONVENCOES
```

Duas regras de arquitetura sustentam tudo isso:

**1. Ninguém procura ninguém pela árvore de nós.** Quem faz algo emite no
`EventBus`; quem se importa escuta. A HUD não conhece o Player, o Player não
conhece o gerenciador de ondas. Dá para apagar a HUD inteira e o jogo continua
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
| Quantos inimigos por onda, quanto a barra sobe | `src/arena/onda_*.tres` |
| Vida e velocidade dos inimigos | campos exportados em `src/enemies/*.tscn` |
| Limiares de 50% e 85% | `src/autoload/deterioracao.gd` |

## Testes

```bash
# roda o jogo inteiro sem janela: 5 ondas, chefe, vitória
godot --headless --path . tools/teste_fumaca.tscn

# gera screenshots em user://capturas
godot --path . tools/capturar.tscn --resolution 1280x720
```

O teste de fumaça também valida a matemática da mira preditiva e os limiares
da Deterioração. Ele roda sozinho em todo PR pelo GitHub Actions.

## Documentação

- **[HANDOFF.md](docs/HANDOFF.md)** — setup do zero, para quem nunca usou Godot nem Git
- **[GDD.md](docs/GDD.md)** — game design document
- **[ROADMAP.md](docs/ROADMAP.md)** — o que vem depois desta build
- **[CONVENCOES.md](docs/CONVENCOES.md)** — como trabalhamos em três sem pisar um no outro
