# Plano de Implementação — Low Top-Down Squared

> **Este plano está dissolvido em issues.** O épico de acompanhamento é
> [#47](https://github.com/alexandre-amaral/psicode/issues/47); as 16 issues de
> execução são `[LTD 01]` a `[LTD 16]` (#31–#46), com o rótulo `low-topdown`.
> A direção de arte está em [`LOW_TOPDOWN_SQUARED.md`](LOW_TOPDOWN_SQUARED.md) e
> o levantamento técnico que sustenta as decisões, em
> [`PIVO_LOW_TOPDOWN.md`](PIVO_LOW_TOPDOWN.md).

## Objetivo

Migrar a apresentação visual atual do jogo para o estilo **Low Top-Down Squared**, mantendo o funcionamento lógico do mapa em uma grade cartesiana 2D convencional.

A câmera não deve se tornar isométrica e o mapa não deve ser deformado. O chão continua quadrado e toda lógica de movimentação, geração procedural, colisões e navegação permanece baseada nos eixos X/Y normais.

A mudança deve acontecer principalmente através de:

- perspectiva dos sprites;
- paredes com topo e face frontal;
- personagens vistos de cima, mas com rosto e torso visíveis;
- objetos com topo e frente;
- origem dos sprites posicionada na base;
- Y-Sorting;
- sombras;
- nova organização das camadas visuais;
- padronização da perspectiva de todos os assets.

A resolução base permanece **960×544**, utilizando tiles lógicos de **64×64 px**. Toda coordenada estrutural importante continua obedecendo à grade já estabelecida pelo projeto — a **grade estrutural continua em 16 (coordenada) / 32 (dimensão de sala)**; o 64 é a grade **visual** do tile, e é múltiplo de ambas.

> **Consequência do tile de 64, declarada.** `960 = 15 × 64` fecha exato, mas
> `544 = 8,5 × 64` e `800 = 12,5 × 64`. As salas de 544 de altura (retangular,
> boss, arma, item, inicial) e a sala grande (1440×800) fecham em **meio tile**
> nas bordas. O corte cai em 32 — ou seja, exatamente na subgrade que o projeto
> já usa — então nenhum teste reprova e nenhuma coordenada sai da grade. O que
> muda é que a última fileira de tiles aparece pela metade. Aceitar isso, ou
> redimensionar as salas, é decisão de execução da Etapa A (Fase 24).

---

# Fase 1 — Congelar as regras técnicas da perspectiva

Antes de substituir qualquer asset, definir as regras que todo novo elemento deverá seguir.

## 1.1 Câmera

Continuar utilizando:

`Camera2D`

com:

- projeção ortográfica 2D;
- zoom base `1.0`;
- resolução interna `960×544`;
- sem rotação;
- sem transformação isométrica;
- sem inclinação física da câmera.

A sensação de câmera inclinada deve ser produzida pela arte.

A câmera imaginária deve representar aproximadamente uma visão de cima inclinada, de forma que sejam simultaneamente visíveis:

- o chão;
- o topo dos objetos;
- a parte frontal dos objetos;
- o rosto e torso dos personagens;
- o topo e a face das paredes.

Não utilizar um valor angular isolado como regra de produção.

A regra visual verificável do projeto será:

**altura visual da FACE ≈ altura visual do TOPO**

com tolerância aproximada de ±25%.

Essa proporção deverá ser utilizada como referência para paredes, caixas, máquinas, mesas e outros elementos volumétricos.

---

# Fase 2 — Preservar completamente a geometria lógica

O Low Top-Down Squared deve alterar a representação visual, mas não o funcionamento geométrico do mapa.

Continuar utilizando:

- grade quadrada;
- paredes em 0°, 90°, 180° e 270°;
- Tile de 64×64;
- posições estruturais múltiplas de 16;
- dimensões de salas múltiplas de 32.

O tile visual de 64 **não substitui** a grade estrutural de 16/32 — ele é
múltiplo dela. Nenhuma coordenada de parede, porta ou spawn muda de valor.

O chão não deve receber nenhuma transformação de perspectiva.

Portanto:

`64×64 lógico → 64×64 visual no chão`

O efeito tridimensional deverá começar apenas quando objetos sobem visualmente a partir dessa superfície.

Isso evita ter que modificar:

- geração procedural;
- posições das portas;
- cálculo das salas;
- spawn de inimigos;
- navegação;
- colisões;
- corredores;
- coordenadas do mapa.

---

# Fase 3 — Reestruturar a composição visual da sala

A montagem atual da sala deverá evoluir para uma estrutura de renderização mais explícita.

Estrutura visual desejada:

```text
Room

Floor
    Chao
    FloorDetails

Walls
    WallBase
    WallFaces
    WallTop

YSortWorld
    Player
    Enemies
    Crates
    Tables
    Machines
    InteractiveObjects

Foreground

Lights

Doors
```

O sistema atual de `sala.gd` pode continuar sendo responsável pela geração visual, mas `_montar_visual()` deverá passar a construir essas categorias separadamente.

---

# Fase 4 — Reconstruir as paredes

Essa é a mudança visual mais importante da migração.

Atualmente a parede funciona principalmente como uma faixa ao redor do contorno da sala.

No novo estilo, cada parede precisa comunicar claramente **altura**.

Uma parede deverá ser composta conceitualmente por:

```text
TOPO
████████████████

FACE
████████████████
████████████████
```

Para o tile de 64 px usado pelo projeto:

```text
espessura lógica da parede = 64 px
altura visual do topo      ≈ 64 px
altura visual da face      ≈ 64 px
```

Assim uma parede pode ocupar apenas uma célula lógica de profundidade, mas possuir aproximadamente 128 px de presença visual.

> **O que isso cobra da câmera.** A faixa visível ao norte passa de 24 px (hoje)
> para 128, e ao sul para 64. Uma sala de 960×544 passa a ocupar
> **1088 × 736** de moldura contra uma tela de 960×544 — o deslize da câmera
> cresce, e a parede norte sozinha come 23% da altura do quadro. É o preço
> direto do tile de 64 e precisa ser medido na Fase 22, não estimado.

## Parede norte

A parede localizada no topo da sala deverá mostrar:

- topo;
- face frontal completa.

Ela será a principal responsável por vender a perspectiva Low Top-Down.

## Paredes leste e oeste

Devem seguir a mesma câmera imaginária.

Precisam mostrar:

- topo;
- porção lateral/frontal compatível com a perspectiva.

Não devem parecer paredes vistas diretamente de cima.

## Parede sul

Utilizar a solução já definida no documento:

**parede cortada.**

A parede inferior deve mostrar principalmente o topo e evitar uma grande face frontal.

Isso impede que o cenário cubra:

- jogador;
- inimigos;
- projéteis;
- telegraphs.

Não implementar transparência dinâmica inicialmente.

---

# Fase 5 — Separar parede lógica de parede visual

A colisão continuará representando somente a base física.

Nunca utilizar toda a altura desenhada da parede como colisão.

Exemplo:

```text
TOPO
██████████

FACE
██████████
██████████

---------- ← base lógica / colisão
```

Isso permitirá que o jogador visualmente se aproxime das paredes sem colidir com uma área invisível correspondente à parte vertical do sprite.

O sistema de colisão existente deve, portanto, ser preservado sempre que possível.

---

# Fase 6 — Recriar os assets de chão

O chão deve continuar sendo o elemento visual mais simples da sala.

A identidade definida continua sendo:

**pixel art de noite azul com neon, complexo industrial escuro.**

Entretanto, o chão deve competir o mínimo possível com os elementos de combate.

Utilizar principalmente:

- N1 `#0B0D16`;
- N2 `#12151F`;
- juntas utilizando N0;
- pequenas quantidades de N3.

Evitar:

- luzes circulares;
- pontos brilhantes;
- neon decorativo;
- detalhes pequenos que possam parecer projéteis.

A maior parte da identidade visual deve estar nas paredes e props, não no chão.

O chão deve continuar utilizando texturas seamless e respeitando a grade visual de 64 px.

---

# Fase 7 — Adaptar props para Low Top-Down

Todos os props importantes deverão ser redesenhados.

Cada prop volumétrico deve possuir pelo menos:

```text
TOP SURFACE
+
FRONT SURFACE
```

Exemplos:

## Caixa

Mostrar:

- tampa superior;
- frente;
- pequena lateral quando necessário;
- sombra no chão.

## Terminal

Mostrar:

- parte superior da máquina;
- monitor inclinado ou frontal;
- estrutura frontal;
- base tocando o chão.

## Mesa

Mostrar:

- superfície superior;
- espessura;
- frente;
- pernas ou suporte inferior.

## Armário

Mostrar:

- topo;
- grande face frontal;
- base claramente identificável.

## Computadores e máquinas

Devem possuir silhuetas verticais maiores do que os props atuais puramente top-down.

---

# Fase 8 — Definir origem padrão dos props

Todo objeto deverá utilizar o ponto de contato com o chão como referência lógica.

Para um prop:

```text
     sprite

   +-------+
   |       |
   | PROP  |
   |       |
   +-------+
       X
      BASE
```

A posição lógica deve ficar aproximadamente no:

**centro inferior da base.**

Isso será obrigatório para que o Y-Sorting funcione corretamente.

Não utilizar o centro geométrico do sprite como posição lógica.

---

# Fase 9 — Migrar Player e inimigos para origem nos pés

A mesma regra deve ser aplicada aos personagens.

O `CharacterBody2D` representa a posição dos pés.

O sprite sobe visualmente a partir dessa posição.

Estrutura:

```text
       cabeça
         O
        /|\
        / \
         X
        pés

CharacterBody2D.position = X
```

A colisão também deverá ficar próxima aos pés.

Não envolver todo o torso com a `CollisionShape2D`.

Estrutura desejada:

```text
CharacterBody2D
    Sprite2D
    CollisionShape2D
    AnimationPlayer
    AnimationTree
    Marker2D
```

A `CollisionShape2D` deve representar aproximadamente pernas/pés.

---

# Fase 10 — Redesenhar os personagens

Raven, Nova e inimigos devem deixar de parecer vistos verticalmente de cima.

Na direção `DOWN`, devem ser visíveis:

- cabelo/topo da cabeça;
- rosto;
- ombros;
- peito;
- braços;
- pernas;
- pés.

Na direção `UP`:

- topo da cabeça;
- cabelo;
- costas;
- ombros.

Nas laterais:

- topo da cabeça;
- rosto de perfil;
- torso parcialmente frontal;
- pernas.

O projeto já utiliza oito direções, então preservar:

```text
N
NE
E
SE
S
SW
W
NW
```

Não reduzir para quatro direções durante a migração.

---

# Fase 11 — Manter a legibilidade específica do Player

Raven e Nova podem continuar utilizando sprites escuros e relativamente dessaturados.

Entretanto, deve ser preservada a regra visual da identidade existente:

**a aura ciano nos pés é a âncora de leitura do jogador.**

Manter:

`Visual/Aura`

com aproximadamente:

`#33D9FF`

e baixa opacidade.

A aura deve permanecer posicionada exatamente na região de contato com o chão, o que também reforça a nova origem baseada nos pés.

O cano/arma também continua utilizando o destaque claro já estabelecido.

---

# Fase 12 — Implementar Y-Sorting real

Criar ou consolidar um nó comum:

`YSortWorld`

com:

`y_sort_enabled = true`

Todos os elementos que podem passar visualmente na frente ou atrás uns dos outros devem estar nele:

- Player;
- inimigos;
- caixas;
- mesas;
- máquinas;
- objetos interativos;
- props com volume.

A comparação deve acontecer pela coordenada Y da base.

Exemplo:

```text
       CAIXA
      ██████
      ██████
--------X-------- base

           PLAYER
             O
            /|\
            / \
-------------X------ pés
```

Se os pés do player estão abaixo da base da caixa:

**Player desenha na frente.**

Se estão acima:

**caixa desenha na frente.**

---

# Fase 13 — Não usar apenas z_index

Definir faixas gerais:

```text
-20 Floor
-10 FloorDetails

  0 YSortWorld

 10 estruturas superiores / WallFaces quando necessário
 20 Foreground

100 Effects
200 UI
```

Entretanto, objetos do mundo não devem depender de `z_index` individual para determinar profundidade.

A profundidade principal precisa vir do Y-Sorting.

---

# Fase 14 — Introduzir Foreground

Criar uma camada explícita para elementos que podem passar sobre personagens.

Exemplos possíveis:

- partes superiores de máquinas altas;
- tubulações;
- cabos suspensos;
- vigas;
- extremidades superiores de paredes;
- estruturas industriais.

Usar com moderação.

O objetivo é aumentar profundidade, não esconder constantemente o combate.

---

# Fase 15 — Implementar sombras

Adicionar sombras simples aos elementos que possuem volume.

Personagens:

- elipse pequena;
- diretamente próxima aos pés.

Props:

- sombra projetada a partir da base.

Direção global definida no documento:

**luz vindo de cima/esquerda.**

Consequentemente:

```text
Topo       → mais claro
Frente     → intermediário
Laterais   → mais escuras
Sombras    → baixo/direita
```

Essa regra deve aparecer diretamente nos sprites.

Não depender de iluminação dinâmica para gerar o volume.

---

# Fase 16 — Atualizar o atlas de props

O `props_atlas.png` atual deverá ser progressivamente substituído por versões Low Top-Down.

Cada novo prop deverá:

- seguir a paleta AMBIENTE;
- usar dimensão múltipla de 16;
- encaixar na grade visual de 64;
- possuir base identificável;
- mostrar topo e frente;
- usar a mesma direção de iluminação;
- respeitar a mesma câmera imaginária;
- evitar detalhes circulares brilhantes.

As regiões continuarão sendo declaradas nos `tipo_*.tres`.

Não criar um sistema paralelo de configuração.

---

# Fase 17 — Preservar as três paletas

A mudança de perspectiva não substitui a identidade visual atual.

Continuar utilizando rigorosamente:

## AMBIENTE

Para:

- chão;
- paredes;
- props;
- corredores;
- molduras.

Escuro ou dessaturado.

## ATOR

Para:

- projéteis;
- inimigos;
- elementos importantes dos personagens.

Saturado e claro.

## SINAL

Para:

- telegraphs;
- porta bloqueada;
- pickups;
- indicadores importantes.

Grande e visualmente impossível de confundir com um projétil.

Nunca transformar as novas faces das paredes em grandes áreas de neon.

---

# Fase 18 — Transferir a identidade das salas para as paredes

A mudança de perspectiva cria uma oportunidade importante.

Como as paredes agora terão uma face frontal significativamente maior, essa face deve assumir parte da identidade visual de cada tipo de sala.

Por exemplo:

```text
COMBATE
parede → ciano rebaixado

BOSS
parede → rosa rebaixado

ARMA
parede → âmbar rebaixado

ITEM
parede → verde-água rebaixado

INICIAL
parede → cinza-azulado
```

Sempre utilizar A0–A2.

Nunca utilizar diretamente a cor brilhante do minimapa no mundo.

---

# Fase 19 — Adaptar portas

A porta deve ser redesenhada para aproveitar a nova parede vertical.

Ela deve parecer realmente instalada em uma parede.

Manter conceitualmente:

```text
Moldura
Campo
```

A moldura deve possuir:

- batentes;
- parte superior;
- soleira;
- profundidade compatível com a parede.

Quando trancada:

`Campo`

continua sendo um grande elemento da paleta SINAL.

Quando aberta:

o espaço além da porta utiliza N0 enquanto o corredor ainda não estiver visível.

Quando SELADA:

o vão não deve existir visualmente.

---

# Fase 20 — Adaptar corredores

O corredor deve seguir exatamente a mesma perspectiva das salas.

Não criar um estilo separado.

Deve utilizar:

- mesmo chão;
- mesmo formato das paredes;
- mesma altura de face;
- mesma iluminação;
- mesmo tile 64;
- mesma origem de props.

A variante visual base continua sendo a de combate.

---

# Fase 21 — Criar uma sala de teste visual

Antes de converter todas as salas, criar uma sala específica para validar a perspectiva.

Ela deverá conter:

```text
1 Raven ou Nova

1 inimigo

1 caixa

1 mesa

1 terminal

1 parede norte

1 parede sul

1 parede leste

1 parede oeste

1 porta

1 pickup

1 telegraph

projéteis do player

projéteis inimigos
```

A sala deve ser usada para validar a câmera imaginária.

Não iniciar a conversão em massa antes dessa cena estar visualmente correta.

---

# Fase 22 — Validar sobreposição

Realizar testes específicos:

### Player atrás de caixa

A caixa deve cobrir parte das pernas/corpo corretamente.

### Player na frente da caixa

O personagem deve cobrir a caixa.

### Player próximo da parede norte

A parede deve parecer alta sem gerar colisão invisível.

### Player próximo da parede sul

A parede não deve bloquear o combate.

### Dois inimigos em Y diferente

O mais abaixo na tela deve aparecer à frente.

### Projétil passando próximo de prop

O projétil precisa continuar claramente identificável.

---

# Fase 23 — Validar bullet hell

A alteração visual não pode reduzir a legibilidade do combate.

Esse é um requisito central.

Para cada screenshot, verificar:

**"O projétil inimigo continua tão fácil de identificar quanto antes?"**

Se a resposta for não:

não aumentar brilho dos projéteis imediatamente.

Primeiro reduzir:

- detalhe do chão;
- contraste dos props;
- saturação das paredes;
- excesso de luz;
- ruído visual.

O cenário continua sendo o palco.

Os atores continuam sendo o foco.

---

# Fase 24 — Migrar os assets em ordem

Não converter tudo simultaneamente.

Ordem recomendada:

### Etapa A

- parede norte;
- parede sul;
- parede lateral;
- chão.

Resultado esperado:

a sala já deve parecer Low Top-Down mesmo vazia.

### Etapa B

- Player;
- colisão do Player;
- origem nos pés;
- aura;
- Y-Sorting.

Resultado esperado:

movimentação e perspectiva do personagem corretas.

### Etapa C

- inimigos;
- origens;
- colisões;
- sprites direcionais.

### Etapa D

- caixa;
- mesa;
- terminal;
- máquinas.

### Etapa E

- portas;
- corredores.

### Etapa F

- detalhes decorativos;
- foreground;
- sombras adicionais;
- iluminação.

---

# Fase 25 — Evitar alterar gameplay durante a migração

Durante essa implementação, não alterar simultaneamente:

- dano;
- velocidade;
- IA;
- tamanhos de sala;
- geração procedural;
- spawn;
- armas;
- itens;
- balanceamento;
- Deterioração.

A migração deve ser considerada uma mudança de:

**representação visual + organização espacial de sprites.**

Isso facilita identificar regressões.

---

# Fase 26 — Atualizar o gerador de texturas

Os novos assets de ambiente devem continuar utilizando o pipeline já estabelecido.

Fluxo:

```text
paleta
↓
gerador
↓
catálogo
↓
PNG
↓
import
↓
tipo_*.tres
↓
sala.gd
```

Para texturas geradas:

- usar somente cores autorizadas;
- tamanho múltiplo de 16;
- alpha 0 ou 1;
- geração determinística;
- respeitar G1;
- respeitar G2;
- respeitar G3.

Não editar os PNGs finais manualmente como principal método de produção quando o asset pertencer ao sistema gerado.

---

# Fase 27 — Criar biblioteca de módulos visuais

Depois que o estilo estiver validado, criar componentes reutilizáveis.

Exemplo:

```text
WallNorth
WallSouth
WallSide

CrateSmall
CrateLarge

TerminalLow
TerminalHigh

TableSmall
TableLarge

MachineSmall
MachineLarge
```

Todos devem obedecer à mesma proporção visual.

Isso evita que cada sala desenvolva sua própria perspectiva.

---

# Fase 28 — Critério de aprovação de um asset

Um asset só deve entrar no jogo se responder "sim" para todas estas perguntas:

1. O topo está visível?

2. A frente está visível quando deveria?

3. A proporção topo/frente parece próxima à dos outros objetos?

4. A base visual está claramente identificável?

5. A origem está na região de contato com o chão?

6. O Y-Sorting funciona corretamente?

7. A iluminação parece vir de cima/esquerda?

8. O asset permanece dentro da paleta correspondente?

9. Ele pode ser confundido com um projétil?

10. Ele parece pertencer à mesma câmera imaginária das paredes?

Se uma caixa parece vista de um ângulo e a mesa de outro, mesmo que ambas sejam bonitas isoladamente, uma delas deve ser refeita.

---

# Fase 29 — Testes técnicos finais

Após cada grupo de mudanças executar:

```text
geração das texturas
↓
importação
↓
testes de textura G1/G2/G3
↓
testes de grade
↓
teste de fumaça
↓
capturas
↓
inspeção visual
```

Dar atenção especial às capturas de:

- sala de combate;
- boss;
- sala inicial;
- arma;
- item.

O teste automatizado pode validar paleta e grade.

A perspectiva Low Top-Down precisa também de inspeção visual.

---

# Fase 30 — Resultado esperado

Ao final da migração, uma sala deve continuar logicamente sendo:

```text
+----------------------+
|                      |
|                      |
|       PLAYER         |
|                      |
|                      |
+----------------------+
```

Mas visualmente deverá transmitir:

```text
        TOPO DA PAREDE
  ████████████████████████

        FACE DA PAREDE
  ████████████████████████
  ████████████████████████


        ┌────────┐
        │  TOPO  │
        ├────────┤
        │ FRENTE │
        └────────┘
           caixa


             O
            /|\
            / \
             ●
            pés


  ████████████████████████
      topo da parede sul
```

O jogador deve perceber que está olhando o cenário de cima, mas não diretamente de cima.

O chão permanece quadrado.

Os objetos possuem volume.

Os personagens mostram rosto e torso.

As paredes possuem altura.

O Y-Sorting cria profundidade.

E nenhuma dessas mudanças exige transformar o jogo em 3D ou isométrico.

---

# Prioridade resumida de implementação

**Prioridade 1 — Fundação**

Camera2D atual + tile visual 64 (grade estrutural 16/32) + estrutura de camadas + YSortWorld.

**Prioridade 2 — Perspectiva**

Paredes com topo/frente + regra 1:1 + parede sul cortada.

**Prioridade 3 — Personagens**

Origem nos pés + colisão nos pés + sprites Low Top-Down.

**Prioridade 4 — Mundo**

Props com topo/frente + origem na base + sombras.

**Prioridade 5 — Integração**

Portas + corredores + foreground.

**Prioridade 6 — Polimento**

Iluminação + variações de props + decoração.

**Prioridade 7 — Validação**

Paleta + G1/G2/G3 + grid + fumaça + screenshots + legibilidade de projéteis.

---

# Regra central da migração

A principal regra para não perder a direção visual é:

**não tente inclinar o mundo no código.**

A grade, a câmera e as colisões continuam sendo um jogo top-down 2D convencional.

Quem cria o Low Top-Down é a arte:

**chão quadrado + topo visível + face frontal + origem na base + Y-Sorting + sombras coerentes.**