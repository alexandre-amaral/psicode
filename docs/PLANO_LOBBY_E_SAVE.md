# Plano de Implementação — Lobby, Save e Persistência entre Runs

> Este documento **comanda** a mudança, como o
> `Plano de Implementação — Migração para Low Top-Down Squared.md` comandou a
> anterior. Foi escrito pelo dono do projeto; aqui ele está com a estrutura
> preservada e a prosa apertada. Dissolvido nas issues `[LOBBY nn]`.
>
> Quando o código e este texto discordarem, **o código ganha e o texto se
> atualiza** — a regra do `GEMINI.md` vale aqui como em todo o resto.

## 1. Objetivo

O jogo deixa de iniciar uma run direto do menu.

```
MENU -> NOVO JOGO / CARREGAR -> LOBBY -> escolha do personagem
     -> exploração -> entrada do Andar 1 -> RUN
     -> vitória/derrota -> resultado registrado -> volta ao LOBBY
```

O Lobby passa a ser o espaço **persistente** entre runs. Começa pequeno, mas a
arquitetura já tem de aceitar depois: desbloqueio de personagens, upgrades
permanentes, NPCs, áreas destraváveis, novas entradas de andar, coleções,
estatísticas, desafios, moeda persistente, história, loja, codex e conquistas.

**Evitar sistemas vazios demais, mas estabelecer pontos de extensão claros.**

## 2. Princípios

**2.1 O Lobby não é uma run.** Entrar nele não pode ativar Deterioração
passiva, iniciar contador de run, registrar sala, gerar mapa procedural,
aplicar modificadores temporários, criar inventário de run nem iniciar ondas.

**2.2 O personagem existe antes da run.** A escolha sai do menu e acontece
fisicamente no Lobby. O escolhido vira `personagem_selecionado` e é usado
quando a entrada do Andar 1 é ativada.

**2.3 Save e run são conceitos separados.** Nunca salvar o estado inteiro da
cena como forma principal de persistência. `SaveData` = permanente; `RunData` =
temporário.

**2.4 CARREGAR passa a carregar um PERFIL** — personagem, histórico,
estatísticas, desbloqueios, upgrades. Depois de carregar, entra-se no Lobby.
Restaurar uma run interrompida é recurso futuro e separado.

## 3. Estados globais

```
GameMode { MENU, LOBBY, RUN, RESULTADO }
```

RESULTADO pode ser fluxo interno; **não é necessária cena própria** na primeira
implementação.

## 4. Arquitetura de dados — três níveis

### 4.1 `SaveData` (persistente)

`versao_save`, `slot_id`, `personagem_selecionado`, `total_runs`,
`total_vitorias`, `total_derrotas`, `melhor_andar`, `melhor_sala`,
`maior_dano_run`, `maior_numero_kills`, `historico_runs`,
`personagens_desbloqueados`, `upgrades_permanentes`, `desbloqueios`,
`moedas_persistentes`.

Os quatro últimos podem começar praticamente vazios. O importante é o formato
já ter lugar para eles.

### 4.2 `RunData` (temporário)

`personagem`, `seed`, `inicio_timestamp`, `andar_atual`, `kills`,
`dano_causado`, `dano_recebido`, `itens_coletados`, `armas_coletadas`,
`salas_concluidas`, `venceu`, `motivo_fim`.

Ciclo: run nova -> `RunData` novo; fim -> `RunResult` -> histórico -> `RunData`
descartado.

### 4.3 `RunResult` (compacto e serializável)

`id`, `data`, `personagem`, `duracao`, `andar_alcancado`, `kills`,
`dano_causado`, `dano_recebido`, `venceu`, `motivo_fim`, `itens_principais`,
`arma_final`.

**Não guardar referência de Node nem de cena.**

## 5-6. Formato e versionamento

`user://save_01.json`, versionado desde já:

```json
{ "version": 1, "selected_character": "raven", "stats": {},
  "unlockables": {}, "permanent_upgrades": {}, "run_history": [] }
```

Carregar **sempre com default** (`dados.get(chave, padrao)`), nunca dependendo
da existência do campo. `SAVE_VERSION = 1`, e `migrar_save()` existe desde a
primeira versão mesmo sem fazer nada — é o que evita um problema grande quando
os sistemas permanentes chegarem.

## 7-8. Responsáveis

`SaveManager` — `criar_novo_save`, `carregar_save`, `salvar`, `save_existe`,
`apagar_save`, `registrar_run`, `migrar_save`. **Ele não controla cenas.**

`ProgressionManager` — interpreta os dados: personagem, desbloqueios, upgrades,
estatísticas, histórico. SaveManager lê/escreve arquivo; ProgressionManager
interpreta.

## 9-12. Menu

**NOVO JOGO**: verificar save -> criar perfil -> defaults -> salvar
imediatamente -> carregar Lobby. Nunca iniciar run.

**Se já existe progresso**, confirmar antes: *"Iniciar um novo jogo substituirá
o progresso atual."* Nunca apagar automaticamente. **Essa proteção existe desde
a primeira versão.**

**CARREGAR**: `save_existe()` -> carregar -> validar/migrar ->
ProgressionManager -> Lobby. Sem save, **botão visualmente desativado**.

**Salvamento automático** em: criação de perfil, mudança de personagem, retorno
de run, desbloqueio, compra de upgrade, mudança importante no Lobby. Nunca a
cada frame.

## 13-20. O Lobby

`lobby.tscn`, com `Floor`, `Walls`, `Props`, `YSortWorld` (Player e objetos
interativos), `CharacterSelection`, `RunHistoryStation`, `Floor01Entrance`,
`SpawnPoint`, `Camera2D` e `UI`.

Mesma linguagem **Low Top-Down Squared**. Ele **não deve parecer um menu em
forma de mapa — deve parecer um lugar.** Pequeno e concentrado: spawn, seleção,
terminal, entrada do andar, e espaço reservado para expansão.

Seleção de personagem em `CharacterBay`, fisicamente no Lobby (cápsulas,
plataformas, terminais). Cada personagem com representação **física**, não um
texto no chão. Feedback óbvio: plataforma ativa contra apagada, na categoria
**SINAL** — grande e controlado, nunca parecido com projétil.

**Troca de personagem sem trocar de cena**: `trocar_personagem(id)` preserva
posição, direção e estado de interação; a vida volta ao máximo e não há
inventário de run.

## 21-22. Interação

`Interactable` — `interaction_id`, `interaction_text`, `enabled`,
`interaction_range`, sinal `interacted(player)`. Serve depois para NPCs, lojas,
portas especiais e coleções.

`InteractionDetector` (Area2D) no Player: mostra prompt e, com vários por
perto, escolhe **o mais próximo**.

## 23-26. Terminal de histórico

Objeto interativo desde a primeira versão — ele **prova** que runs são
registradas, que o save funciona e que o Lobby tem informação persistente.

Mostra ÚLTIMA RUN (personagem, resultado, andar, duração, kills) e RUNS
RECENTES (10 a 20; histórico não precisa ser infinito), mais TOTAL / VITÓRIAS /
DERROTAS / MELHOR RESULTADO. O Lobby pausa enquanto o painel está aberto.

## 27-28. Registro

`RunTracker.start_run()` / `finish_run(venceu, motivo)` -> `RunResult` ->
`ProgressionManager.registrar_run()` -> `SaveManager.salvar()`.

**Não deixar estatística espalhada.** Nada de `inimigo.gd` incrementando o
save. O RunTracker escuta o `EventBus` — é o que desacopla gameplay de
persistência.

## 29-32. Entrada do Andar 1

`Floor01Entrance`, objeto físico. Recomendado: **elevador industrial antigo**,
que conecta visualmente o Lobby ao setor. Confirmação curta antes de entrar
(*"Iniciar run com RAVEN?"*), para evitar entrada acidental.

Ao confirmar: ler personagem, criar `RunData`, gerar seed, resetar temporários,
preparar personagem, estado RUN, ativar sistemas da run, carregar Andar 1,
posicionar, gerar. **É aqui, e não ao entrar no Lobby, que a Deterioração
passiva começa.**

## 33-36. Fim da run

Todo fim passa por `GameState.terminar_run(venceu)` -> `RunTracker.finish_run`
-> registrar, atualizar stats, aplicar desbloqueios, salvar -> **carregar
Lobby**. Derrota **não** volta ao menu.

`RunData.andar_atual` existe porque, no futuro, vencer um andar pode levar ao
próximo sem terminar a run — o sistema **não deve assumir** que boss do Andar 1
é o fim de toda run.

Ao voltar, o terminal já mostra o resultado novo. Evitar tela obrigatória
longa: o jogador tem de poder andar imediatamente.

## 37-39. Preparado para o futuro

`is_unlocked(id)` / `unlock(id)`; `get_upgrade_level(id)` /
`purchase_upgrade(id)` / `apply_permanent_modifiers()`; `currencies`.
**Nenhuma outra cena acessa o Dictionary direto.** Não implementar o conteúdo
agora — só garantir que o save tem lugar.

## 40-44. Identidade e limites

O Lobby aceita expansão (upgrades, NPC, codex, loja, Andar 2, desafios) em
áreas que podem começar fechadas ou apagadas — **sem criar dez espaços enormes
vazios.**

Identidade: Low Top-Down Squared, pixel art, metal azul-escuro, luz controlada,
Y-sort, chão pouco ruidoso. Mas **mais seguro que o Andar 1**: mais organizado,
menos ferrugem, iluminação estável. O contraste é o ponto.

**Sem combate no Lobby**: disparo desativado. **HUD reduzido**: nada de vida de
combate, Deterioração, contador de sala. Só prompt de interação e menus.
Câmera: a mesma, com clamp próprio — não criar sistema separado.

## 45-47. Robustez

Escrita segura: `save.tmp` -> concluída -> substitui o real. Se falhar, mantém
o anterior. Save corrompido **não pode crashar**: mensagem e VOLTAR, com
`save_backup.json` a cada salvamento relevante.

Debug: resetar save, run falsa, finalizar como vitória/derrota, desbloquear
personagem, limpar histórico.

## 48-51. Testes

Save (criar, salvar, carregar, igualdade, inexistente, incompleto, versão
antiga, histórico, seleção), Lobby (spawn, câmera, interação, seleção,
persistência, terminal, entrada) e Run (Lobby não ativa sistemas da run,
`RunData` criado, derrota/vitória registradas, resultado aparece).

**O fluxo de integração obrigatório:**

```
abrir -> NOVO JOGO -> Lobby -> selecionar Nova -> fechar -> abrir
-> CARREGAR -> Lobby -> Nova continua selecionada -> iniciar run
-> morrer -> Lobby -> terminal mostra derrota -> fechar -> carregar
-> histórico ainda existe
```

Se esse fluxo funcionar, o sistema básico está correto.

## 52-53. As issues, e a ordem

| Fase | Issues | Objetivo |
|---|---|---|
| **A — Fundação** | 01, 02, 03, 10, 11 | estado global e dados antes de existir Lobby |
| **B — Menu** | 04, 05, 09 | NOVO JOGO e CARREGAR com significado real |
| **C — Lobby mínimo** | 06, 07, 08, 18 | entrar, andar, selecionar |
| **D — Início de run** | 14, 15 | o Lobby vira a única entrada do Andar 1 |
| **E — Retorno** | 12, 13, 16, 17 | o loop Lobby -> Run -> Lobby fecha |
| **F — Future-proofing** | 19, 20, 21 | expandir sem reescrever o save |
| **G — Validação** | 22, 23 | o loop inteiro é persistente e confiável |

01 estados MENU/LOBBY/RUN · 02 SaveData versionado · 03 SaveManager ·
04 NOVO JOGO · 05 CARREGAR · 06 cena do Lobby · 07 interação genérica ·
08 estação de personagens · 09 persistir personagem · 10 RunData/RunTracker ·
11 RunResult · 12 histórico no save · 13 terminal · 14 entrada do Andar 1 ·
15 Lobby -> Andar 1 · 16 derrota -> Lobby · 17 vitória -> Lobby · 18 HUD
separado · 19 desbloqueios · 20 upgrades · 21 backup · 22 suíte de
persistência · 23 teste integrado.

## 54-55. MVP, e o que NÃO entra

MVP: abrir, NOVO JOGO, Lobby, andar, escolher, entrar no Andar 1, morrer ou
vencer, voltar, consultar o terminal, fechar, abrir, CARREGAR, o personagem
continua escolhido e o histórico continua lá.

**Não implementar junto:** árvore de upgrades, moeda real, vários slots, NPCs,
quests, várias entradas de andar, equipamento persistente, dezenas de
estatísticas, save no meio da run, dificuldade, multiplayer.

## 56. O ciclo final

```
MENU -> SAVE/PROFILE -> LOBBY -> RUN -> RESULTADO -> PROGRESSÃO -> SAVE -> LOBBY
```

O menu deixa de ser o centro. O Lobby assume.
