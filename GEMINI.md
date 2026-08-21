# Contexto do Projeto

Este é o projeto **"Ciberpsicose"** (título provisório), feito na **Godot Engine (2D)** usando **GDScript**.

> ⚠️ Este documento é a fonte da verdade do design do jogo. Ao sugerir código, mecânicas,
> nomes de sistemas ou conteúdo, sempre siga o que está descrito aqui. Se um pedido do
> usuário parecer contradizer o GDD (gênero, câmera, mecânicas centrais), aponte a
> divergência antes de implementar, em vez de simplesmente seguir o pedido.

## 1. Visão Geral

- **Gênero:** Ação rápida / Twin-stick shooter / Bullet hell / Roguelike.
- **Engine:** Godot (2D).
- **Câmera:** Top-down (vista de cima).
- **Referências:** Enter the Gungeon (ritmo, estrutura de salas, combate), Nuclear Throne (agressividade), The Binding of Isaac (exploração).
- **Identidade narrativa:** Distopia cyberpunk underground. O protagonista é um ciborgue/mercenário lutando contra a própria corrupção mental e física enquanto busca a cura antes do colapso total de seu sistema.

## 2. Core Loop

1. **Entrar na sala** — portas trancam (lockdown).
2. **Sobreviver** — evadir bullet hell com esquivas táticas (baseadas em aprimoramentos corporais) e destruir inimigos com armas encontradas no cenário.
3. **Gerenciar Deterioração** — lutar contra o relógio; tempo e implantes aumentam a Deterioração, afetando a percepção da realidade do protagonista e a dificuldade.
4. **Limpar a sala** — portas abrem, coletar loot (Créditos/Recursos), seguir em frente.
5. **Morte** — consciência restaurada em backup na base (Loja Clandestina); jogador gasta "Núcleos de Memória" (meta-progressão) para liberar novos implantes e armas em runs futuras.

## 3. Mecânicas Principais

### Sistema de Deterioração (Sanidade/Percepção)
Aumenta passivamente e/ou ao abusar de aprimoramentos de alto nível.

- **Fase 1 (Baixa):** inimigos padrão.
- **Fase 2 (Média):** inimigos mais rápidos (cadência e movimento).
- **Fase 3 (Alta — Alucinações):** inimigos usam *predictive aiming* (miram no ponto futuro do jogador); ataques ganham efeitos visuais de falha/glitch, representando a mente corrompida completando lacunas com imaginação.

### Movimentação e Esquiva
- Começa com um rolamento de invulnerabilidade (i-frames).
- Pode ser alterada por implantes (ex: dash cortante, jetpack, escudo estacionário).

### IA Diretora (Heurística)
O jogo analisa o estilo do jogador (distância média mantida, uso de esquiva) para popular as próximas salas com composições de inimigos que "counterem" essas estratégias, forçando adaptação.

## 4. Escopo do MVP (Primeiro Protótipo)

- **Personagem:** movimentação WASD + mira no mouse.
- **Combate:** 1 arma básica (pistola infinita) + 1 arma de loot (shotgun).
- **Defesa:** rolamento (com cooldown e i-frames).
- **Inimigos (IA básica):** 1 melee (corre atrás do jogador) e 1 ranged (atira na posição atual do jogador).
- **O diferencial:** barra de Deterioração na UI que, ao passar de 50%, ativa mira preditiva no inimigo ranged e aumenta a velocidade do melee.
- **Cenário:** apenas uma arena quadrada fechada, sem transição de salas ainda.

> Ao trabalhar no MVP, não sugerir ou implementar por conta própria sistemas fora deste
> escopo (ex: múltiplas salas, loja clandestina, meta-progressão) a menos que o usuário
> peça explicitamente. Esses sistemas existem no GDD mas são pós-MVP.

## 5. Pós-MVP: Estrutura de Salas/Mapa (Geração Procedural)

> Esta seção documenta decisões já tomadas para uma fase **pós-MVP**. O MVP atual
> continua sendo apenas uma arena única fechada (ver seção 4). Não implementar o
> conteúdo abaixo a menos que o usuário peça explicitamente para avançar para esta fase.

- **Geração:** o layout do andar é gerado **proceduralmente a cada run**, no estilo *The Binding of Isaac* (grid de salas conectadas por portas, não geração livre/orgânica).
- **Visibilidade do mapa:** o jogador tem acesso a um **mapa visível do andar** (como em Isaac) — salas já visitadas/descobertas aparecem no mapa; salas não visitadas ficam ocultas ou mostradas apenas como "existe uma sala aqui" sem revelar o conteúdo.
- **Tipos de sala definidos:**
  - **Combate:** sala padrão, portas trancam até limpar (ver Core Loop, seção 2).
  - **Loja:** sala **dentro da run**, onde o jogador compra itens/armas/implantes usando Créditos (a moeda de run, coletada como loot). Não confundir com a "Loja Clandestina" da seção 2 (Core Loop), que é a base entre runs onde se gasta Núcleos de Memória — são dois sistemas de loja diferentes: um in-run (Créditos) e um de meta-progressão entre runs (Núcleos de Memória).
  - **Tesouro:** sala com um item ou arma gratuita, tipicamente sem combate ou com desafio opcional para acessar.
  - **Boss:** sala final do andar, encontro mais difícil que marca a progressão para o próximo andar/nível de Deterioração.

> Tipos de sala pendentes de decisão (não confirmados ainda): sala Elite. Não assumir
> detalhes sobre esse tipo até o usuário confirmar se e como será incluído.

## Estrutura de pastas

> Preencher/ajustar conforme a estrutura real do projeto:
- `scenes/` — arquivos `.tscn`
- `scripts/` — arquivos `.gd`
- `assets/` — sprites, sons, fontes
- `resources/` — arquivos `.tres` (armas, inimigos, implantes como Resources customizados)

## Convenções de código (GDScript)

- Classes em `PascalCase` (ex: `PlayerController`, `DeteriorationManager`).
- Variáveis e funções em `snake_case` (ex: `move_speed`, `take_damage()`).
- Constantes em `MAIÚSCULAS_COM_UNDERSCORE`.
- Sinais nomeados como evento (ex: `deterioration_changed`, `room_cleared`, `player_died`).
- Preferir `@export` para variáveis ajustáveis no editor.
- Preferir Resources customizados (`.tres`) para dados de armas/inimigos/implantes, permitindo balanceamento sem mexer em código.
- Preferir composição via nós e cenas reutilizáveis a heranças profundas de script.
- Evitar `get_node("../../Algo")` com caminhos frágeis; usar `@onready var` com unique names (`%Nome`) ou grupos.

## O que evitar

- Não sugerir código em outra engine ou linguagem (o projeto é Godot/GDScript).
- Não expandir escopo além do MVP sem confirmação.
- Não introduzir plugins/dependências externas sem avisar antes.

## Fluxo de trabalho preferido

- Ao editar um script, resumir a mudança antes de aplicar, se for grande.
- Ao propor uma cena nova (`.tscn`), explicar a hierarquia de nós em texto antes.
- Ao implementar mecânicas (ex: Deterioração, IA Diretora), relacionar explicitamente com a seção correspondente deste GDD.
