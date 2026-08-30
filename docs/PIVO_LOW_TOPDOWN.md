# Pivô para Low Top-Down Squared — mapa e câmera

> **Escopo deste plano.** Não é implementação. É o levantamento do que precisa
> mudar na **construção do mapa** e na **visualização de câmera** para o jogo
> passar a obedecer o documento *Direção de câmera e arte — Low Top-Down
> Squared*, mais o inventário honesto do que quebra no caminho.
>
> Arte de ator (redesenhar sprites) fica **fora**: o levantamento mostra que ela
> quase não precisa mudar, e o pouco que precisa está listado em §7 como
> consequência, não como tarefa deste pivô.

---

## 1. Contexto — por que a mudança

O `psicode` é hoje um top-down **chapado**. A captura
`docs/capturas/07_sala_de_combate.png` mostra o problema sem precisar de
argumento: o quadro é chão texturizado de ponta a ponta e **não há uma parede
visível**. O que existe é uma faixa de 24 px com outra textura, desenhada
*atrás* do chão (`z = -2`), que o jogador só vê se andar até a beira.

O documento de direção pede o oposto: um mundo onde **paredes, móveis e objetos
mostram topo e face frontal**, ordenados por profundidade, com o chão
permanecendo em grade quadrada. O ganho não é decorativo — é de leitura. Hoje
não há nada no quadro que diga "isto é um espaço fechado"; a sala é uma textura
com atores em cima.

**O resultado esperado:** a mesma planta de sala, a mesma física, a mesma
grade — mas com volume. A câmera passa a enquadrar a sala *e a altura visual das
paredes*, e a ordem de desenho passa a ser por posição no chão em vez de
`z_index` decorado à mão.

---

## 2. Ponto de partida — o que já está implementado

Contado do disco, não de memória. Serve para dimensionar o que o pivô mexe.

### 2.1 O jogo

| | |
|---|---|
| Gênero / engine | twin-stick · bullet hell · roguelike · Godot 4.7.2-stable, GDScript, renderer Compatibility (GL) |
| Resolução base | 960×544, `Camera2D` zoom 1.0, stretch `canvas_items`/`expand` |
| Inimigos | 8 tipos + 2 peças da arena do chefe + 1 hazard |
| Implantes | 16, todos no pool de loot |
| Armas | 10 (4 do jogador, 6 de inimigo); 1 cai como loot |
| Tipos de sala | 5, em 9 cenas; andar de 8–12 salas |
| Personagens | 2 (RAVEN, NOVA), 8 direções + ciclo de 9 quadros |
| Idiomas | 2 (pt-BR, en), 81 strings |
| Testes | 22 suítes (~1837 verificações) + teste de fumaça da run inteira, ambos no CI |
| Som | **nenhum** |

**O loop que funciona hoje:** andar de 8–12 salas sorteadas, lockdown por sala,
minimapa com a silhueta real, chefe em 4 fases (a última com a arena atacando),
Deterioração que escala tudo no frame de uso, 16 implantes, seleção de operador,
Hack com duração. Tudo texturizado e em dois idiomas.

### 2.2 A arquitetura visual do mundo, hoje

Existe **uma fonte de verdade geométrica por sala**: o nó `Line2D` chamado
`"Parede"` dentro de cada `src/mapa/sala_*.tscn`. Dele saem **cinco**
consumidores:

| consumidor | onde |
|---|---|
| colisão (`SegmentShape2D` por trecho, sem espessura) | `sala.gd:583` `_montar_paredes()` |
| corpo visual da parede (`Polygon2D` inflado 24 px) | `sala.gd:669` |
| chão (`Polygon2D` do próprio contorno) | `sala.gd:677` |
| clamp e zoom da câmera | `sala.gd:225` → `gerenciador_mapa.gd:1192` `_clampar()` |
| minimapa | `sala.gd:476` `contorno_local()` |

Pilha de desenho atual dentro de uma `Sala`:

```
z = -2   ParedeCorpo   Polygon2D, contorno inflado 24 px, desenhado ATRÁS do chão
z = -1   Chao          Polygon2D, contorno, UV em pixels ancorada no CANTO do bbox
z = -1   Decoracao     props Sprite2D 32×32, seed por hash(coordenadas_grid)
z =  0   Parede        Line2D — fonte da geometria, invisível em runtime
```

O corpo da parede é o contorno inteiro inflado e sólido; o chão é desenhado por
cima. O que sobra visível é exatamente a faixa de 24 px. **Foi assim que a sala
em L passou a funcionar sem geometria booleana** — e é essa escolha que o pivô
precisa substituir sem perder a propriedade.

**Não existe `TileMap`, `TileSet`, nem constante de "tamanho de célula" em
nenhum lugar de `src/`.** O layout do andar é em **bandas de largura variável**
(`_centros_das_bandas()`, `gerenciador_mapa.gd:975`), não em grade de passo fixo:
o passo entre células é `max(largura das salas daquela coluna) + vao_corredor`.

### 2.3 Geometria real das 9 salas

| cena | bbox | área do contorno | portas |
|---|---|---|---|
| `sala_1_retangular` | 960×544 | 522 240 | N S L O |
| `sala_2_l_shape` | 960×544 | **391 168** (côncava, 6 pontos) | N L |
| `sala_3_grande` | 1440×800 | 1 152 000 | N S L O |
| `sala_4_corredor` | 768×960 | 737 280 | N S |
| `sala_5_pilar` | 960×960 | 921 600 (+ pilar 128×128) | N S L O |
| `sala_6_boss` · `_7_arma` · `_8_item` · `_9_inicial` | 960×544 | 522 240 | — |

Todas múltiplas de 32. Todas as portas no meio do lado. Única concavidade do
projeto: a `sala_2`. Único obstáculo interno: o pilar da `sala_5`.

### 2.4 Constantes que amarram a forma

```
Sala.ESPESSURA_PAREDE      = 24.0   sala.gd:74     ← copiada, não referenciada, em Corredor:39
GerenciadorMapa.margem_da_parede() = ESPESSURA_PAREDE   gerenciador_mapa.gd:1221
Porta.LARGURA              = 80.0   porta.gd:27    ← == largura_corredor, travado por teste
porta_moldura.png          96×48                   ← calibrada contra a espessura 24
porta_campo.png            80×32
GerenciadorMapa.vao_corredor = 256.0
texturas de chão/parede    256×256  (13 arquivos, arte autorada)
props_atlas.png            256×128  (8×4 células de 32)
```

---

## 3. O alvo, e o quanto dele já existe

O ponto que reordena a conversa: **boa parte do documento já é verdade no
projeto.** O pivô é menor do que parece — mas concentrado num lugar caro.

### 3.1 Já conforme (não mexer)

| Requisito do documento | Estado |
|---|---|
| §3 `Camera2D` ortográfica, sem câmera 3D | ✔ `player.tscn`, com limites e smoothing 9.0 |
| §2 grade cartesiana, paredes em 0/90/180/270 | ✔ todo contorno é retilíneo |
| §2 sem transformação isométrica do piso | ✔ chão quadrado, UV em pixels |
| §13 tiles quadrados, não losangos | ✔ |
| §14 grade consistente | ✔ tudo múltiplo de 16; dimensão de sala múltipla de 32 |
| §5 personagem mostra cabeça, rosto, torso, pernas | ✔ RAVEN/NOVA são pixel art 3/4 de corpo inteiro |
| §6 origem lógica nos pés | ✔ **parcial** — `gerar_sprites.py:113` ancora a arte nos pés na moldura 80×80; o offset do nó (`(0,-20)`, `(0,-25)`) desloca o desenho ~16 px acima do centro de colisão |
| §7 colisão pequena na região dos pés | ✔ `CircleShape2D` raio 11 na origem, corpo desenhado bem maior |
| §15 4 ou 8 direções | ✔ 8, com mapa canônico em `src/util/direcoes.gd` |
| §21 colisão = base lógica da parede | ✔ `SegmentShape2D` na linha do contorno, sem espessura |
| §27 gravidade 0, +y para baixo | ✔ |

**Consequência prática:** a arte de ator **não precisa ser redesenhada**. Os 115
PNGs direcionais (2 personagens + 5 inimigos + a Diretora) já são a perspectiva
que o documento pede. Isso derruba de longe o maior custo imaginável do pivô.

### 3.2 O que falta — a lista real de trabalho

| # | Requisito | Estado hoje | Peso |
|---|---|---|---|
| F1 | §10–11 parede com **topo + face** | Faixa única de 24 px, sem distinção | **alto** |
| F2 | §8 **Y-Sorting** pela base | Nenhum `y_sort_enabled` no projeto; tudo é `z_index` manual | **alto** |
| F3 | §22 ordem de renderização em camadas | Existe, mas ad-hoc e com empates (chão de sala e de corredor empatam em `z=-1`) | médio |
| F4 | §12/§23 camadas de mapa separadas (Floor / WallFace / WallTop / Props / Foreground) | Duas camadas: `ParedeCorpo` e `Chao` | **alto** |
| F5 | §16 **sombras** sob atores e objetos | Zero | médio |
| F6 | §20 parede inferior escondendo o jogador | Não existe porque não há face — passa a existir | médio |
| F7 | §9 origem dos objetos na base | Props são `Sprite2D` 32×32 centrados, sem base definida | médio |
| F8 | §18 direção de luz global declarada | Não existe regra escrita | baixo |
| F9 | §19 objetos encostados na parede | Props ficam na margem, mas sem relação com a face | baixo |
| F10 | §3 câmera que enquadre a altura visual das paredes | `grow(24)` simétrico nos 4 lados | **alto** |
| F11 | §4 volume em todos os elementos do cenário | 4 inimigos ainda são `Polygon2D` chapado; projéteis, pickups e FX são geometria procedural | médio |

---

## 4. As decisões que precisam ser tomadas antes de escrever código

Cada uma muda materialmente o custo. Estão em ordem de dependência.

### D1 — A fonte da forma: `TileMapLayer` ou continuar no `Line2D`?

O documento pede `TileMapLayer` (§12, §23). O projeto tem cinco sistemas
pendurados no `Line2D "Parede"` (§2.2), e cinco suítes de teste que leem
`contorno_local()`.

**Recomendação: híbrido.** O `Line2D` continua sendo a fonte **lógica** (colisão,
minimapa, câmera, `area_spawn`, `teste_grade`), e passa a alimentar, **em
código**, um conjunto de `TileMapLayer` gerados no `_ready` da `Sala` que
desenham o visual.

| | Reescrever em TileMapLayer puro | Híbrido (recomendado) | Só trocar o desenho dos Polygon2D |
|---|---|---|---|
| Cenas `.tscn` a redesenhar | 9 | **0** | 0 |
| Suítes que quebram | 5 (§6) | **0 por este motivo** | 0 |
| Ganha autotile de quina/topo/face | sim | **sim** | não |
| Abre caminho para pathfinding em grade (dívida do M3) | sim | **sim** | não |
| Precisa de `TileSet` novo | sim | **sim** | não |

O híbrido paga o `TileSet` (que é trabalho de arte inevitável para F1) e não paga
a reescrita das cenas nem dos testes. É a única opção que honra
`CLAUDE.md` — *"a parede nasce do `Line2D`"* aparece quatro vezes como
invariante — e ainda entrega o que o documento pede.

### D2 — Lado do tile: 32 ou 64? — **DECIDIDO: 64**

> **Decisão tomada.** O tile visual é **64 × 64**, conforme o
> `Plano de Implementação`. Esta seção fica registrando o que essa escolha
> custa, porque o custo é real e aparece nas decisões seguintes.

A **grade estrutural do projeto não muda**: coordenada continua múltipla de 16 e
dimensão de sala múltipla de 32. O 64 é múltiplo das duas, então **nenhuma
coordenada de parede, porta ou spawn muda de valor e nenhum teste reprova** —
`teste_grade.gd` afere 16, 32 e a resolução, nunca 64.

O que o 64 cobra:

| | fecha em tile inteiro? |
|---|---|
| largura 960 | ✔ `15 × 64` |
| largura 768 · 1440 | ✔ `12 ×` / ✖ `22,5 ×` |
| **altura 544** (5 das 9 salas) | ✖ `8,5 ×` — meio tile na borda |
| altura 800 (sala grande) | ✖ `12,5 ×` |
| altura 960 | ✔ `15 ×` |

O corte cai em 32, que já é subgrade do projeto — então é meio tile limpo, não um
retalho. Aceitar o meio tile ou redimensionar as salas é decisão da Etapa A.

### D3 — As alturas da parede

O documento dá, para tile 64: topo 16–24, face 32–48, sprite 64×96 (§11) — razão
2:1. Isso **contradiz a regra operacional de D8** (face ≈ topo, 1:1 ±25%), que é
a que o `Plano de Implementação` adota como verificável. Vale a 1:1:

```
espessura lógica da parede   64 px   (uma célula; hoje é 24, fora da grade)
altura desenhada do TOPO     64 px
altura desenhada da FACE     64 px
```

Presença visual de **128 px** sobre uma célula lógica de 64.

**`ESPESSURA_PAREDE` sai de 24 e vai para 64** — e ela está copiada à mão em três
lugares (`sala.gd:74`, `corredor.gd:39`, `gerenciador_mapa.gd:1221`); a mudança
tem de ser simultânea, e obriga a regenerar `porta_moldura.png` (hoje 96×48,
calibrada contra a espessura 24).

> **Atenção ao `Porta.LARGURA = 80`.** Ele é múltiplo de 16 mas **não de 64**.
> `teste_grade.gd:66,73` só exige múltiplo de 16 e igualdade com
> `largura_corredor`, então 80 continua passando — mas um vão de 80 numa parede
> ladrilhada de 64 nunca alinha com o tile. Ou a porta vira 64/128, ou a moldura
> tem de cobrir o desalinhamento de propósito.

### D4 — Onde a face é desenhada, e o problema da parede sul (§20)

Numa câmera acima e inclinada, só se vê a face **voltada para o sul**. Portanto:

- **Parede norte** — topo + face, ambos desenhados **para FORA** do contorno
  (acima da linha). A linha do contorno continua sendo a base da parede e a
  colisão, exatamente como §21 pede, e **nenhum pixel de área jogável é
  perdido**. Faixa total ao norte: 128 px.
- **Parede sul** — só o topo (64 px). A face dela apontaria para o observador e
  esconderia o jogador: é o problema clássico de §20, e a **Solução 1** do
  documento (parede inferior com altura visual menor) é a que cabe aqui, porque
  não precisa de código de transparência nem de detecção de região.
- **Paredes leste/oeste** — topo ao longo do lado, mais um trecho de face na
  extremidade sul de cada uma, para fechar a quina.

A alternativa (desenhar a face para DENTRO) come área jogável e mudaria o
balanceamento de todas as salas. Está descartada.

### D5 — O clamp da câmera deixa de ser simétrico

`GerenciadorMapa._clampar()` faz hoje `limites.grow(margem_da_parede())` — 24 px
iguais nos quatro lados. Com D4, a moldura visível deixa de ser simétrica:

```
esquerda / direita  +64     (topo da parede)
baixo               +64     (topo da parede)
cima               +128     (topo 64 + face 64)
```

`grow()` precisa virar `grow_individual()`, e `margem_da_parede()` precisa
devolver quatro números em vez de um. **É o ponto onde o pivô toca a câmera de
verdade.**

### D6 — O enquadramento: aceitar o deslize ou encolher as salas?

Este é o desafio mais consequente, e o `GEMINI.md` já o registra como dívida
aberta: *"Numa sala do tamanho exato da tela, a parede só entra no quadro quando
o jogador anda até a borda."*

Com D3+D4 a moldura de uma sala padrão passa a ser **1088 × 736** contra uma tela
de **960 × 544**. O deslize piora bastante — a parede norte sozinha ocupa 23% da
altura do quadro.

| | (a) Aceitar o deslize | (b) Encolher as salas | (c) Zoom out |
|---|---|---|---|
| Sala padrão | 960×544 | **832×352** | 960×544 |
| Moldura visível | 1088×736 | 960×544 — encaixe exato | 1088×736 |
| Área da sala | 522 240 | 292 864 (**−44%**) | 522 240 |
| Custo | deslize de 128 px em x e 192 px em y | `area_spawn` de 9 cenas + rebalanceio pesado de `densidade` | proporções não batem (1,48 vs 1,76) → faixa vazia na lateral |

> **O tile de 64 inverteu a recomendação desta seção.** Com tile 32 a opção (b)
> dava `896×448` (−23% de área) e fechava a dívida de enquadramento que o
> `GEMINI.md` registra. Com tile 64 a parede dobra de presença, e o encaixe exato
> exige `832×352` — uma sala de proporção 2,4:1 com **44% menos área**, o que
> derrubaria o orçamento de inimigos quase pela metade.

**Recomendação: (a), aceitar o deslize.** Dois motivos, e o primeiro decide
sozinho:

1. A **Fase 25 do `Plano de Implementação` proíbe** alterar tamanho de sala,
   geração procedural, spawn e balanceamento durante a migração. (b) é
   exatamente isso.
2. O deslize já existe hoje e é comportamento conhecido; (b) trocaria um
   problema de enquadramento por um problema de balanceamento, que é pior de
   diagnosticar.

A dívida de enquadramento **continua aberta** e passa a ser maior. Fica
registrada para depois da migração, quando houver medição da Fase 22 para
decidir com número em vez de aritmética.

### D7 — Onde mora o Y-sort, e o Player precisa mudar de pai

`src/main/main.tscn` põe o `Player` como **irmão** do `GerenciadorMapa`, não
dentro da sala. Os inimigos ficam em `ContainerInimigos` **dentro** da sala.

Y-sort exige que tudo que se ordena entre si seja **irmão sob o mesmo nó
`y_sort_enabled`**. Portanto:

- ou a `Sala` ganha um nó `MundoOrdenado` (`y_sort_enabled = true`) e o Player é
  reparentado para a sala atual a cada travessia — mexe no ciclo de
  `_sair()`/`_chegar()` e arrisca a câmera, que é filha do Player;
- ou o Y-sort sobe para um nó único do `GerenciadorMapa`, e salas, props,
  inimigos e Player passam a ser ordenados juntos no espaço global.

**Recomendação: a segunda.** Reparentar o Player a cada porta é exatamente o tipo
de mudança que apaga em silêncio as chamadas de
`GameState.iniciar_run()`/`terminar_run()` — armadilha já registrada no
`CLAUDE.md` e que já custou a Deterioração passiva uma vez.

### D8 — O ângulo do documento é ambíguo, e precisa virar um número medível

O documento diz "20° a 35° **em relação ao chão**" (§1) e, em §25, que top-down
puro é "90° sobre o chão". Nessa convenção, 20–35° seria uma câmera quase
horizontal — o que contradiz "grande parte do chão permanece visível". A
intenção é clara (topo + frente), o número é que está na convenção invertida:
o pedido real é **20–35° de inclinação a partir da vertical**, ou seja 55–70°
acima do chão.

Como o projeto trabalha com portões executáveis, a saída é trocar o ângulo por
uma **razão medível**, que é o que §24 realmente quer garantir:

> **Regra operacional:** para todo elemento do cenário, `altura desenhada da
> FACE ≈ altura desenhada do TOPO`, na razão 1:1 (D3), com tolerância de ±25%.

Isso é conferível num teste, e é o que impede o cenário de virar uma mistura de
caixas a 25° com caixas a 60° (§24).

---

## 5. Camadas de desenho depois do pivô

Substitui a pilha de §2.2. Mapeia §22 do documento para os nós que existem.

```
z = -20   Chao            TileMapLayer   piso, grade de 32
z = -18   ChaoDetalhe     TileMapLayer   rachadura, cabo, decalque
z = -16   ParedeTopo      TileMapLayer   topo de TODAS as paredes
z = -14   ParedeFace      TileMapLayer   face vertical (norte + pontas de L/O)
z =   0   MundoOrdenado   Node2D  y_sort_enabled = true
              ├── Player · inimigos · props com volume · pickups · sombras
z = +10   Frente          TileMapLayer   o que passa por cima do ator
z = +15   Mira                           (já existe, mira.gd:32)
z = +100  FX
z = +200  HUD
```

Dois cuidados que o levantamento achou e que precisam sobreviver:

- **`texture_repeat` não é declarado em `project.godot`** — o default do engine é
  `Disabled`, e é por isso que `Sala._texturizar()` liga
  `TEXTURE_REPEAT_ENABLED` na mão (`sala.gd:738`). Qualquer nó novo que desenhe
  textura de chão precisa do mesmo cuidado, ou declarar o default global.
- **Chão de sala e chão de corredor empatam hoje em `z = -1`**, e o desempate é
  ordem de árvore. Funciona por acidente (os retângulos não se sobrepõem). Na
  nova pilha isso precisa ser explícito.

---

## 6. Inventário de quebra — o que os testes recusam

O CI roda `tools/testes/runner.tscn` (22 suítes) e `tools/teste_fumaca.tscn` em
todo push e PR. Nada disto é opcional.

### 6.1 Bloqueantes duros

| # | Trava | Onde | Consequência |
|---|---|---|---|
| B1 | `igual(largura, 960)` / `igual(altura, 544)` — **é `igual`, não `%`** | `teste_grade.gd:57-58` | Só quebra se D6 mudar a resolução. Encolher as SALAS (D6b) **não** toca aqui |
| B2 | `ok(concavas > 0, "existe ao menos uma sala nao-retangular")` | `teste_dados_sala.gd:246` | Se o pivô aposentar a `sala_2_l_shape`, **reprova**. A recomendação é manter a sala em L |
| B3 | Todo ponto de contorno inteiro e múltiplo de 16; `obter_limites().size` múltiplo de 32 | `teste_grade.gd:93-104` | D6b (896×448) passa. Qualquer dimensão ímpar em 32 reprova |
| B4 | As 5 cenas de combate com áreas **estritamente crescentes** nesta ordem: L < retangular < corredor < pilar < grande | `teste_composicao.gd:279`, `:301-307` | Se D6b encolher as salas, tem de encolher **todas proporcionalmente** |
| B5 | `Porta.LARGURA` na grade **e** igual a `largura_corredor` | `teste_grade.gd:66`, `:73` | Se a porta mudar por causa da espessura nova, os dois mudam juntos |
| B6 | `Sala.contorno_local()` triangulável, sem ponto de fechamento repetido | `teste_dados_sala.gd:228-238` | Confirma D1: **o `Line2D` não pode sumir** |
| B7 | Sprites de ator exatamente 80×80 e fitas `80·quadros × 80`; `Direcoes.TOTAL == 8` | `teste_sprite_direcional.gd:28`, `teste_personagem.gd:23` | **Não é tocado** por este pivô — a arte de ator fica |

**B6 é a confirmação mais importante do levantamento:** remover o `Line2D` faz
cascata em cinco suítes, no `_clampar()`, no minimapa, no spawn e no teste de
fumaça. D1 (híbrido) existe para não pagar isso.

### 6.2 Portões de textura — a arte nova de parede tem de passar por seis filtros

`tools/testes/teste_texturas.gd` confere cada PNG de `assets/texturas/`:

| portão | regra | onde |
|---|---|---|
| dimensão | múltipla de 16 | `:264-268` |
| alpha | estritamente 0 ou 1 — **nenhum anti-aliasing, nenhuma sombra suave em PNG** | `:331` |
| G1 gamut | zero pixel com `s > 0,35` **e** `v > 0,55` | `:333` |
| teto de valor | chão ≤ 0,30 (0,24 no chefe); **parede ≤ 0,50** | `:334`, `:201-212` |
| faixa de matiz | por tipo: `andar1` 185–320°, `boss` 330–355°, `arma` 25–50°, `item` 150–180°, ±1° | `:335-340` |
| costura | razão junta/borda ≤ 1,10 nos dois eixos | `:366-369` |

E mais três armadilhas de manutenção:

- **`AUTORADAS` é lista fixa de 13 arquivos** (`:154-168`). Textura nova de topo
  de parede que não entre nessa lista **não é conferida por nada**.
- **`MATIZ_POR_TIPO` é gêmeo** de `tools/texturas/preparar_textura.py:129-134`.
  Mudar num só deixa o funil produzindo o que o portão recusa.
- **Determinismo** (`:400-406`): `porta_moldura.png`, `porta_campo.png` e
  `props_atlas.png` têm de ser byte-a-byte o que `gerar_texturas.gd` produz. D3
  obriga a regenerar a moldura de porta, então o gerador **e** os PNGs mudam
  juntos.

**Consequência de projeto:** a face vertical passa a ser a maior superfície de
ambiente na tela. O teto de valor 0,50 da parede e o portão G1 ficam mais
críticos, não menos — é a superfície onde um projétil pode sumir.

### 6.3 Riscos silenciosos (passam verde e mordem depois)

- **`area_spawn` desatualizado.** Se D6b encolher as salas e os `@export
  area_spawn` das 9 cenas não acompanharem, `teste_grade` pode passar mas o
  `teste_fumaca.gd:195` (`obter_limites().grow(64)`) reprova todo spawn — ou
  pior, degrada em silêncio para `ponto_seguro()`.
- **`Sala.TEXTURA_PADRAO`** (`sala.gd:89`) aponta para
  `"%s_andar1_a.png"`. Se o caminho quebrar, `_texturizar` cai em
  `COR_CHAO_EMERGENCIA` e a sala fica lisa **sem erro no console e sem nenhuma
  suíte pegando**.
- **`default_clear_color` espelha `Paleta.N0` à mão** (`project.godot:132` ↔
  `paleta.gd:27`), sem teste.
- **`capturar.gd:130-133`** só fotografa a sala de combate se ela couber inteira
  no viewport. D6b faz caber; D6a faz a foto 07 cair sempre no fallback.
- **Shake de câmera escreve `offset` fracionário** (`juice.gd:57-60`) sem
  arredondar. `snap_2d_transforms_to_pixel` atua nos nós, não no offset — com
  paredes de face vertical o tremor fica mais visível.

---

## 7. Consequências fora do escopo — registradas, não agendadas

Não são tarefas deste pivô, mas ele as torna visíveis:

- **4 inimigos ainda são `Polygon2D` chapado** (Atirador Neon, Hacker Parasita,
  Núcleo de Sobrecarga, Torre da Diretora). Num mundo com volume, eles passam a
  destoar. Já estão no M3 do roadmap ("sprites dos 7 inimigos restantes").
- **A Diretora gira o próprio sprite** (`diretora.gd:405`, `lerp_angle`). Isso
  viola §24 — a câmera imaginária tem de ser a mesma para todos. Com volume no
  cenário, um chefe girando fica evidente.
- **Dois bugs achados no chefe, ambos silenciosos:** `diretora.gd:135-136` busca
  `Visual/Anel` e `Visual/Nucleo`, que **não existem** na cena — `_girar_anel()`
  é código morto; e como não há `Visual/Corpo`, `InimigoBase._corpo` fica `null`
  e **a Diretora é o único inimigo do jogo sem tint de Hack e sem tint de
  nanite**.
- **`docs/IDENTIDADE_VISUAL.md:120-126` descreve um `Visual/Aura` sob os pés do
  jogador que não existe mais em `player.tscn`.** O doc chama a aura de "âncora
  de leitura" do personagem contra o chão texturizado. Ela sumiu sem substituto —
  e é exatamente o papel que a **sombra** de §16 passaria a cumprir. Vale
  resolver junto com F5.
- **Pathfinding.** D1 (híbrido com `TileMapLayer`) entrega a grade de graça, o
  que destrava a dívida que o `ROADMAP.md` marca como bloqueante do M3: hoje
  quem persegue encalha na sala em L e na do pilar. O ponto de extensão já existe
  e está pré-aberto: `InimigoBase.direcao_de_locomocao()`.

---

## 8. Ordem de ataque sugerida

Cada etapa é um PR revertível sozinho, na convenção do `docs/CONVENCOES.md`.
Nenhuma etapa deixa o `main` sem passar no CI.

1. **Decidir D1–D8.** Nada abaixo começa antes. D6 em especial é decisão de
   produto, não técnica.
2. **`feat/tileset-parede`** — o `TileSet` de 64 px com topo, face e quinas, e a
   arte nova. Passa pelos seis portões de §6.2 antes de qualquer código de sala.
   Entra em `AUTORADAS` no mesmo PR.
3. **`feat/parede-topo-e-face`** — `Sala._montar_visual()` passa a gerar as
   camadas de §5 a partir do `Line2D`. `ESPESSURA_PAREDE` 24→64 nos três lugares.
   Regenerar `porta_moldura.png`. Sem tocar em câmera ainda.
4. **`feat/camera-low-topdown`** — `margem_da_parede()` devolve quatro margens,
   `_clampar()` usa `grow_individual()`. É aqui que o enquadramento muda.
5. **`feat/y-sort`** — nó `MundoOrdenado` e a pilha de z de §5. Sombras (F5)
   entram junto, porque são o que ancora o ator no chão depois que o chão ganha
   volume.
6. **`tune/densidade-salas`** — fora da migração (Fase 25); só se D6b for revisitada: reajustar `densidade`
   nos `tipo_*.tres` contra a área nova, medindo com
   `tools/medir_composicao.tscn`.
7. **`docs/identidade-low-topdown`** — reescrever `docs/IDENTIDADE_VISUAL.md`
   com a direção de luz global (§18, F8), a regra operacional de D8, a nova pilha
   de camadas, e revogar as afirmações que este pivô torna falsas (a faixa de
   24 px, a pilha de z antiga, o `Visual/Aura` fantasma).

---

## 9. Como verificar

```bash
GODOT="/c/Users/alcyn/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

"$GODOT" --headless --path . --import
"$GODOT" --headless --path . tools/texturas/gerar_texturas.tscn   # se a moldura de porta mudou
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . tools/testes/runner.tscn             # 22 suítes, tem de passar
"$GODOT" --headless --path . tools/teste_fumaca.tscn              # tem de imprimir PASSOU
"$GODOT" --path . tools/capturar.tscn --resolution 960x544        # 9 capturas em user://capturas
```

**Suítes novas que este pivô justifica:**

- `teste_camada_visual.gd` — a sala monta as camadas de §5, na ordem de §5, e o
  `ParedeTopo` existe nos quatro lados enquanto o `ParedeFace` existe só ao norte
  e nas pontas sul de leste/oeste.
- A regra operacional de **D8** como asserção: face/topo na razão 1:1 ±25% no
  `TileSet`.
- `teste_camera.gd` — `margem_da_parede()` devolve as quatro margens de D5, e o
  retângulo clampado contém o contorno inflado.

**O portão que decide de verdade** continua sendo o de sempre, e é visual:
comparar `docs/capturas/07_sala_de_combate.png` antes e depois com a pergunta do
`IDENTIDADE_VISUAL.md` — *"um projétil inimigo continua tão fácil de achar quanto
antes?"*. Com a face vertical ocupando a faixa superior do quadro, essa pergunta
fica mais difícil de responder com sim, e é por isso que ela é o portão.
