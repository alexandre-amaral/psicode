# GDD — psicode

> Título provisório. Documento vivo: quando o jogo e o texto discordarem, o
> jogo ganha e o texto se atualiza.

## 1. Visão geral

| | |
|---|---|
| Gênero | Ação rápida · twin-stick shooter · bullet hell · roguelike |
| Engine | Godot 4.7 (2D), GDScript |
| Câmera | Top-down |
| Referências | *Enter the Gungeon* (ritmo, salas, combate), *Nuclear Throne* (agressividade) |

**Identidade narrativa.** Distopia cyberpunk underground. O protagonista é um
ciborgue mercenário lutando contra a própria corrupção mental e física
enquanto busca a cura antes do colapso total do sistema.

**A ideia central em uma frase:** a dificuldade do jogo não é um número no
menu — é o estado mental do personagem, e ele piora enquanto você joga.

> **Nota sobre a engine.** O GDD original especificava Unity. A troca para
> Godot foi feita antes de existir código, por três motivos: cenas em texto
> tornam o merge viável para um time de três; o setup de quem entra é um
> executável sem conta nem licença; e o export para navegador permite mandar
> a build para testadores como um link. Nenhuma mecânica do documento mudou —
> todas são agnósticas de engine.

## 2. Core loop

1. **Entrar na sala** — as portas trancam (lockdown)
2. **Sobreviver** — evadir o bullet hell com esquivas táticas, destruir inimigos
3. **Gerenciar Deterioração** — lutar contra o relógio; tempo e implantes sobem a barra
4. **Limpar a sala** — portas abrem, coletar loot, seguir
5. **Morrer** — a consciência é restaurada num backup na base; gastar Núcleos de Memória em novos implantes para as próximas runs

Hoje o passo 5 ainda é só uma tela de fim: os créditos são ganhos a cada abate
mas nada os consome. Fechar esse passo é o **marco M1** do
[ROADMAP](ROADMAP.md). Os passos 1 a 4 já são literais: o andar tem 10 salas
sorteadas, as portas trancam ao entrar e abrem quando a última ameaça cai.

## 3. Mecânicas

### 3.1 Deterioração (sanidade / percepção)

Um valor de 0 a 100 que sobe passivamente e ao limpar cada sala. **Todo ajuste
de dificuldade do jogo lê daqui** — nenhum inimigo guarda um número já
multiplicado. Isso concentra o balanceamento num arquivo só e garante que a
barra subindo se manifeste no comportamento, não só no visual.

| Fase | Faixa | O que muda |
|---|---|---|
| **Estável** | 0–49 | Inimigos padrão. O Vigia atira na sua posição atual. |
| **Degradando** | 50–84 | **Mira preditiva liga.** Inimigos mais rápidos e com cadência maior. O Rastejante ganha investida. |
| **Crítico** | 85–100 | Alucinações visuais: glitch, vinheta, projéteis inimigos tremendo. Precisão preditiva perto do perfeito. |

Velocidade e cadência escalam **continuamente** com a barra (1,0 → 1,55 e
1,0 → 1,7). A mira preditiva é um **limiar** em 50, mas com precisão que sobe
de 55% para 100% dentro da faixa — a virada é sentida sem virar um muro.

### 3.2 Movimentação e esquiva

Rolamento com i-frames, cooldown, e uma janela de graça de 0,06 s ao fim — o
perdão que separa "difícil" de "injusto". Rastro fantasma comunica a
invulnerabilidade sem HUD: enquanto há ecos, você é intocável.

Pós-MVP: o rolamento é substituível por implantes (dash cortante, jetpack,
escudo estacionário).

### 3.3 Mira preditiva

O diferencial mecânico do jogo. Acima de 50% de Deterioração, o inimigo Ranged
resolve o problema do intercepto — dado onde você está, sua velocidade e a
velocidade do projétil, ele calcula onde você **vai estar** e atira lá.

Isso ataca especificamente o rolamento, porque o rolamento é o momento em que
sua velocidade é mais alta e mais previsível. A esquiva que salvava você nas
primeiras salas vira a armadilha na segunda metade do andar. O jogador precisa
aprender a rolar *depois* do disparo, não antes.

**Onde a virada cai importa tanto quanto o que ela faz.** Se ela chegar antes de
o jogador ter formado um hábito de esquiva, não há hábito para trair — a
mecânica vira só "inimigos mais precisos". A `tools/medir_ritmo.tscn` mede em
que ponto da run o limiar cai; hoje é entre 38% e 50% dela.

Um **laser de telegrafo** aparece durante a mira e ensina a mecânica sem
tutorial: o jogador vê a linha parar num ponto vazio à frente dele e entende.
A cor muda — âmbar quando o inimigo aponta, vermelho quando ele prevê.

### 3.4 IA Diretora (heurística)

Pós-MVP: o jogo analisa o estilo do jogador (distância média e uso de esquiva)
e popula as salas seguintes com composições que *counteram* essas estratégias,
forçando adaptação. Hoje a Diretora existe apenas como chefe — o sistema
heurístico é o marco **M4**.

## 4. O que já está implementado

| Item | Estado |
|---|---|
| Movimentação WASD + mira no mouse | ✅ |
| Pistola de reserva infinita (PST-9) — pente de 14, recarrega e nunca fica sem | ✅ |
| Shotgun de loot (BRK-12), pente de 6 | ✅ |
| Pente e recarga (`R`, ou automática ao esvaziar) | ✅ |
| Implantes passivos coletáveis, lidos no frame de uso como a Deterioração | ✅ |
| Rolamento com i-frames e cooldown | ✅ |
| Inimigo melee (Rastejante) com investida acima de 50% | ✅ |
| Inimigo ranged (Vigia) com mira preditiva acima de 50% | ✅ |
| Barra de Deterioração com dois limiares visíveis | ✅ |
| Arena quadrada fechada com paredes e grade | ✅ |
| Andar de 8–12 salas com lockdown, tipos e minimapa | ✅ |
| Composição de inimigos escolhida na montagem do andar, por orçamento de área | ✅ |
| 16 implantes passivos, incluindo condicionais e comportamentais | ✅ |
| Chefe: IA Diretora, 3 fases, telegrafo em todo ataque | ✅ |
| Shader de alucinação, screen shake, hitstop, knockback | ✅ |
| HUD, tela de vitória e derrota com estatísticas | ✅ |
| Teste automatizado da run inteira | ✅ |

### O chefe: A IA Diretora

Conceito: até agora a Deterioração mexia nos inimigos; agora ela tem corpo.

Orbita o centro da arena — não persegue, porque um sistema não corre atrás de
você. Três fases por faixa de vida, com repertório crescente:

| Fase | Vida | Repertório |
|---|---|---|
| 1 | 100–66% | Disparo preditivo triplo, invocação de Rastejantes |
| 2 | 66–33% | + salva radial, passa a invocar Vigias |
| 3 | 33–0% | + espiral de dois braços, telegrafos mais curtos, respiro menor |

**Todo ataque tem telegrafo** (laser, anel de aviso expandindo, ou clarão), e o
telegrafo encurta com a fase mas nunca abaixo de 0,35 s. Na virada de fase há
uma janela de alívio de 0,9 s — sem ela, a transição vira dano gratuito em
cima de quem estava no meio de uma esquiva.

## 5. Fora do escopo — hoje

> **Esta seção mudou de sentido.** Ela dizia "fora do escopo desta build",
> quando o alvo era um vertical slice. **O alvo agora é lançamento comercial**
> (ver [ROADMAP](ROADMAP.md)), então nada aqui está fora do escopo do PROJETO —
> só ainda não foi feito.

Ainda não existe:

- **Som e música.** Nenhum. É o buraco mais visível do jogo hoje
- **Meta-progressão e loja clandestina** — os créditos já são ganhos a cada
  abate, mas nada os consome
- **Implantes que substituem a esquiva** (dash cortante, jetpack, escudo)
- **IA Diretora heurística de verdade** — hoje "Diretora" é só o nome do chefe
- **Vários andares** — o gerador monta um só
- **Gamepad e remapeamento**

Já foi entregue e saiu desta lista: geração de salas, **oito** tipos de inimigo,
arte (personagens com oito direções e ciclo de caminhada, texturas de sala,
sprite do chefe), **quatro** armas de jogador, seleção de operador e dois
idiomas.

## 6. Pergunta que esta build precisa responder

> Atravessar o andar e derrubar a Diretora é divertido **sem arte e sem som**?

Se for, o resto é acabamento. Se não for, nenhuma quantidade de arte salva —
e é melhor descobrir isso agora.

**A resposta que voltou:** sim, mas de forma rasa. O playtest da `v0.2.0-alpha`
não trouxe nenhum problema acionável — e um retorno sem nenhuma reclamação, de
cinco a oito pessoas, diz menos do que parece. O registro completo está no
`ROADMAP.md`, Fase 1.

As perguntas para os testadores, e o porquê de cada uma, estão em
[PLAYTEST.md](PLAYTEST.md).
