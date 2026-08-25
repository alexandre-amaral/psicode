# Folha de tuning

Para a sessão dos três. Cada linha é um botão: onde ele mora, quanto vale hoje,
o que acontece quando você mexe, e — quando dá para medir — a consequência
medida em vez de opinada.

**Quase nada aqui exige escrever código.** O que é `.tres` ou `.tscn` você abre
no Godot, clica, e os campos aparecem no painel **Inspetor**, à direita. O que é
`.gd` precisa de alguém que mexa em texto — está marcado.

---

## Antes de mexer: rode a régua

```bash
godot --headless --path . tools/medir_ritmo.tscn
```

Ela gera 60 andares de verdade, converte cada sala em segundos usando a vida
real dos inimigos e o DPS real das armas, e imprime **em que minuto da run cada
limiar da Deterioração cai**. Mude um número, rode de novo, compare.

O único chute dela é o **uptime** — quanto do tempo o jogador passa de fato
atirando, em vez de andando, rolando ou esperando o telegrafo passar. Por isso
ela não usa um valor só: varre 25% (quem joga com cautela), 40% e 55% (quem já
decorou os padrões). Olhe a faixa inteira, não uma coluna.

A outra régua mede quantos inimigos cada sala recebe:

```bash
godot --headless --path . tools/medir_composicao.tscn
```

---

## O que a régua já disse

Medido em 60 andares, com os números de hoje:

| | |
|---|---|
| Duração de uma run | **2min38** (uptime 55%) a **4min36** (uptime 25%) |
| Mira preditiva liga em | 38% a 50% da run |
| Deterioração ao entrar na sala do chefe | 88% |
| Fatia da run com a barra travada no teto | 0% |
| Luta do chefe | **59 s** (uptime 55%) a **2min10** (uptime 25%) |
| Inimigos por sala de combate | 3 (sala em L) a 13 (sala grande), média 7,2 |

**O que está aberto:** a luta do chefe a 25% de uptime dá 2min10, fora da faixa
boa de 60–90 s para um chefe de três fases. A 40% dá 1min22, que está bom. Não
mexemos nos 300 HP porque o tempo é dominado pelo uptime, e não pela vida — e
uptime é justamente o que só o playtest mede. **A tela de fim agora mostra
`LUTA DO CHEFE mm:ss`**, então a resposta vem dos testadores, não de chute.

---

## Deterioração — a curva da run

`src/autoload/deterioracao.gd` **(código)** e `src/mapa/tipo_*.tres`.

| Botão | Onde | Hoje | O que faz |
|---|---|---|---|
| `ganho_passivo_por_segundo` | `deterioracao.gd` | **0.25** | Quanto a barra sobe sozinha. É a pressão de tempo: parar de avançar custa caro |
| `deterioracao_ao_limpar` | `tipo_combate.tres` | **6.0** | Quanto sobe ao limpar uma sala de combate. O andar tem ~6 delas |
| `deterioracao_minima_ao_entrar` | `tipo_boss.tres` | **88.0** | Piso forçado ao entrar na sala do chefe. Garante a luta final em nível crítico |
| `LIMIAR_MEDIO` | `deterioracao.gd` | **50** | Onde a mira preditiva liga |
| `LIMIAR_CRITICO` | `deterioracao.gd` | **85** | Onde as alucinações começam |

Os dois primeiros vinham de quando a run eram cinco ondas numa arena. Com o
andar de dez salas, a régua mostrou a mira preditiva ligando no primeiro terço
da partida — antes de o jogador ter formado o hábito de esquiva que ela existe
para trair. Passaram de `0.35 / 8.0` para `0.25 / 6.0`.

> **Quem domina a curva é o ganho por sala, não o passivo.** Seis salas × 6 = 36
> pontos; o passivo entrega ~30 numa run média. Se for mexer, mexa no primeiro.

`tools/testes/teste_deterioracao.gd` protege três relações — que as salas
sozinhas não cheguem ao crítico, que a barra passe do médio antes do chefe, e
que o piso do chefe continue acima do que a run alcança sozinha. Mexer nos
valores é livre; quebrar essas relações o teste acusa.

---

## Jogador

`src/player/player.tscn` (Inspetor) — todos são `@export`.

| Botão | Hoje | O que faz |
|---|---|---|
| `velocidade_max` | 330 | Quão rápido ele anda. Sobe junto a sensação de leveza e a facilidade de kitar |
| `aceleracao` / `atrito` | 2600 / 2200 | Quão rápido ele chega na velocidade e quão rápido para. Altos = controle "grudado" |
| `roll_velocidade` | 720 | Distância coberta pelo rolamento |
| `roll_duracao` | 0.22 | Quanto tempo dura, e portanto quanto tempo de i-frames |
| `roll_cooldown` | **0.55** | Quanto espera até poder rolar de novo. **O botão mais sensível da lista** |
| `roll_graca` | 0.06 | Janela extra de i-frame depois do rolamento acabar |
| `vida_maxima` | 6 | Quantos toques ele aguenta |
| `iframes_apos_dano` | 1.0 | Invulnerabilidade depois de levar dano |

`roll_cooldown` é sensível porque a mira preditiva foi desenhada contra o
rolamento: acima de 50% os inimigos miram onde você **vai** estar. Rolamento
barato demais e a virada não dói; caro demais e ela vira dano inescapável.

---

## Inimigos

`src/enemies/*.tscn` (Inspetor).

| | Vida | Velocidade | Créditos | Custo | Porta | O que ele cobra do jogador |
|---|---|---|---|---|---|---|
| Rastejante | 4 | 118 | 3 | 1 | 0 | espaço — encosta e não larga |
| Vigia | 6 | 96 | 5 | 2 | 0 | a esquiva — acima de 50% mira onde você vai estar |
| Drone Aranha | 5 | 78 | 6 | 2 | 0 | o giro — o anel de 8 não tem lado seguro |
| Sentinela Orbital | 6 | 132 | 7 | 2 | 6 | a saída lateral — ela ocupa a órbita |
| Atirador Neon | 5 | 104 | 6 | 2 | 12 | ficar parado no aberto — mas a linha é travada, sair funciona |
| Cyber-Besta | 8 | 88 | 12 | 3 | 18 | a leitura — investida em linha, direção travada |
| Hacker Parasita | 6 | 110 | 10 | 3 | 24 | a atenção — cobra por ser ignorado |
| Diretora | **300** | 60 | 100 | 1 | — | (sozinha na sala) |

**A coluna `Porta`** é o campo `deterioracao_minima` do `grupo_*.tres`: a partir
de que Deterioração **estimada** aquele inimigo entra no sorteio. É o que faz o
andar apresentar os tipos aos poucos em vez de a primeira sala poder sortear
quatro Cyber-Bestas.

A estimativa é `salas até aqui × deterioracao_ao_limpar`. Ela é necessária
porque a composição de todas as salas é sorteada de uma vez, na montagem do
andar, quando a barra ainda marca zero — comparar com o valor real naquele
instante barraria todo grupo com porta acima de zero, para sempre e em silêncio.
Como a conta ignora o ganho passivo, ela subestima: a porta abre um pouco mais
tarde do que na partida real.

> Com `deterioracao_ao_limpar = 6`, uma porta de 18 quer dizer "a partir da
> terceira sala". Mexer naquele 6 move todas as portas junto — o que é
> correto, mas vale lembrar antes de mexer.

Medido em 120 andares: Drone 100% dos andares, Sentinela 98%, Neon 96%,
Cyber-Besta 73%, Parasita 40%. A régua `medir_composicao` marca com
`<== raro demais` qualquer inimigo abaixo de 20%.

A velocidade e a cadência que você vê em jogo são **maiores** que estas: todo
inimigo lê a Deterioração no frame. No topo da barra, velocidade ×1.55,
cadência ×1.70, velocidade de projétil ×1.25.

### Quantos aparecem por sala

`src/mapa/tipo_combate.tres`:

| Botão | Hoje | O que faz |
|---|---|---|
| `densidade` | 1.2 | Orçamento a cada 100.000 px² de sala. É o que faz sala maior receber mais |
| `orcamento_minimo` | 4 | Piso, para a sala em L não nascer vazia |
| `orcamento_maximo` | 13 | Teto, para a sala grande não virar parede de corpos |

Medido com os sete tipos: sala em L 2,5 inimigos em média; retangular 3,5;
corredor 4,7; pilar 6,4; grande 7,5. São menos corpos do que quando só existiam
dois tipos (era 3,4 / 4,5 / 5,9 / 8,1 / 9,5), porque os inimigos novos custam 2
ou 3 — **menos corpos, mais perigo por corpo**, que é o que o `custo` existe
para comprar.

### Quem aparece

`src/enemies/grupo_rastejante.tres` e `grupo_vigia.tres`:

| Botão | O que faz |
|---|---|
| `peso` | Chance relativa no sorteio, entre os que já passaram da porta |
| `custo` | Quanto consome do orçamento da sala |
| `deterioracao_minima` | A porta, explicada acima |

Pesos de hoje: Rastejante 3.0; Vigia, Drone e Sentinela 2.0; Neon e Cyber-Besta
1.5; Parasita 1.0.

**`custo` é o botão de "mais difícil sem mais corpos".** Subir o custo do Vigia
faz a mesma sala caber menos inimigos, porém mais perigosos.

Inimigo novo não precisa de código: cria a cena, cria um `grupo_*.tres`, e
arrasta para a lista `inimigos` do `tipo_combate.tres`.

---

## Armas

`src/weapons/*.tres`.

| | Pistola (PST-9) | Shotgun (BRK-12) |
|---|---|---|
| Dano por projétil | 2 | 2 |
| Projéteis por tiro | 1 | 8 |
| Cadência | 6.5/s | 1.7/s |
| Pente / recarga | 14 / 0.9 s | 6 / 1.5 s |
| Alcance | 544 | **256** |
| **DPS sustentado** | **9.17/s** | **19.09/s** |

O DPS já desconta pente e recarga. O da shotgun supõe os **oito** fragmentos
acertando — o que, com alcance 256, só acontece encostado. Essa é a troca que a
pergunta 3 do playtest existe para checar: *"a shotgun valeu a pena pegar, ou
você ficou na pistola?"*.

> Dano é `int`. Um "+10%" em cima de dano 2 volta a ser 2 no arredondamento —
> por isso os implantes têm `DANO` (soma) e `DANO_PERCENTUAL` (multiplica) como
> alvos separados.

---

## Ritmo do andar

`src/main/main.tscn`, nó `GerenciadorMapa` (Inspetor).

| Botão | Hoje | O que faz |
|---|---|---|
| `total_salas` | 10 | Tamanho do andar. Mexe direto na duração da run |
| `vao_corredor` | 256 | Distância entre salas. Mexe no tempo de caminhada |
| `largura_corredor` | 80 | **Tem de bater com `Porta.LARGURA`**, senão sobra parede no vão |

Os tipos de sala e as regras de colocação (exige beco, distância da origem,
prioridade) estão em `src/mapa/tipo_*.tres`. Sala nova = `.tres` novo na lista
`tipos_de_sala`; nenhum código.

---

## Depois de mexer

```bash
godot --headless --path . tools/testes/runner.tscn     # segundos
godot --headless --path . tools/teste_fumaca.tscn      # minutos
```

O primeiro pega relação quebrada (barra que estoura antes do chefe, sala sem
inimigo que trava a run). O segundo sobe o jogo inteiro e confirma que a run
ainda termina.

Commit de balanceamento vai em branch `tune/`, como manda o `CONVENCOES.md`.
