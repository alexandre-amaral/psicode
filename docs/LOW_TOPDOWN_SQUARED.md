# Direção de câmera e arte — Low Top-Down Squared

> **O que este documento é.** A direção de arte e de câmera que o `psicode`
> passa a seguir. Ele descreve o ALVO; quem descreve o caminho até lá, e o que
> quebra no meio, é o [`PIVO_LOW_TOPDOWN.md`](PIVO_LOW_TOPDOWN.md).
>
> Onde este documento e o [`IDENTIDADE_VISUAL.md`](IDENTIDADE_VISUAL.md)
> discordarem, **este ganha na perspectiva e na forma**; aquele continua
> mandando na **paleta** (as três paletas, os portões G1/G2/G3, a grade de
> 16/32). São assuntos diferentes e os dois valem ao mesmo tempo.

## 1. Conceito geral

O estilo **Low Top-Down Squared** é uma visão de cima inclinada levemente para
frente, usada em jogos 2D onde o jogador consegue enxergar claramente o chão,
mas também consegue visualizar a parte frontal dos personagens, paredes e
objetos.

A câmera não fica diretamente em cima do personagem como em um top-down puro.

Ao mesmo tempo, também não utiliza a perspectiva diagonal de um jogo isométrico.

A imagem deve passar a sensação de uma câmera posicionada acima do cenário e
inclinada aproximadamente entre **20° e 35°** — ver a nota de convenção abaixo.

Visualmente:

* grande parte do chão permanece visível;
* personagens mostram cabeça, rosto e torso;
* móveis mostram o topo e a parte frontal;
* paredes mostram sua espessura e sua face vertical;
* portas podem ser vistas frontalmente;
* objetos têm profundidade visual;
* o mapa continua seguindo uma grade quadrada comum.

O resultado deve lembrar um jogo top-down tradicional, porém com mais volume e
profundidade.

> **Nota de convenção sobre o ângulo.** §25 chama top-down puro de "90° sobre o
> chão". Nessa convenção, 20–35° seria uma câmera quase horizontal, o que
> contradiz "grande parte do chão permanece visível". A intenção é **20–35° de
> inclinação a partir da VERTICAL** (≈ 55–70° acima do chão). Como número solto
> não é conferível, o projeto adota a **regra operacional** de §24.

---

## 2. O que significa "Squared"

O termo "Squared" define principalmente a construção do mapa.

O mundo deve utilizar uma grade cartesiana normal:

```text
+---+---+---+---+
|   |   |   |   |
+---+---+---+---+
|   |   |   |   |
+---+---+---+---+
|   |   |   |   |
+---+---+---+---+
```

As paredes seguem principalmente ângulos de 0°, 90°, 180° e 270°.

Portanto, não existe a deformação típica de jogos isométricos:

```text
  /\
 /  \
 \  /
  \/
```

No Low Top-Down Squared, uma sala continua sendo geometricamente:

```text
+-----------------+
|                 |
|                 |
|      PLAYER     |
|                 |
|                 |
+-----------------+
```

Isso facilita bastante a implementação no Godot porque colisões, navegação,
TileMaps e geração procedural continuam funcionando em uma grade quadrada
convencional.

---

## 3. Câmera no Godot

Para um jogo 2D, utilize `Camera2D`. Não é necessário utilizar uma câmera 3D
inclinada. **A perspectiva deve ser criada principalmente pela arte.**

Estrutura básica:

```text
Game
├── World
│   ├── Floor
│   ├── Walls
│   ├── Objects
│   ├── Entities
│   └── Foreground
├── Player
└── Camera2D
```

A `Camera2D` continua olhando diretamente para o plano 2D: `X` horizontal, `Y`
vertical. Não é necessário converter coordenadas para uma grade isométrica.

---

## 4. Perspectiva criada pela arte

O segredo do estilo está nos sprites. Considere uma caixa.

Em um top-down puro você praticamente enxergaria apenas a tampa:

```text
+---------+
|         |
|  CAIXA  |
|         |
+---------+
```

No Low Top-Down:

```text
+---------+
|  TOPO   |
+---------+
| FRENTE  |
|         |
+---------+
```

O sprite contém deliberadamente duas superfícies: **Top Surface** (parte de cima)
e **Front Surface** (parte frontal). Essa regra deve ser aplicada
consistentemente em praticamente todos os elementos do cenário.

---

## 5. Personagens

Os personagens não devem parecer vistos diretamente de cima. O jogador deve
conseguir enxergar cabelo, rosto, ombros, peito, braços, pernas e pés.

A cabeça pode ocupar uma área visual relativamente grande. A cabeça ainda mostra
sua superfície superior, mas o rosto permanece claramente visível. Isso cria a
sensação de que a câmera está acima do personagem, porém não completamente
vertical.

---

## 6. Ponto de origem dos personagens

No Godot, o ponto lógico do personagem deve representar seus **pés**, não o
centro do sprite.

```text
      CABECA
        |
       [O]
      /###\
      #####
       | |
       X
    ORIGEM
```

Isso é extremamente importante para colisão, Y-Sorting, portas, objetos,
paredes, projéteis e navegação. O sprite pode ter 80 pixels de altura, mas a
posição do `CharacterBody2D` representa o ponto onde os pés encontram o chão.

---

## 7. Colisão do personagem

A colisão não deve acompanhar o corpo inteiro visualmente. Use uma colisão
relativamente pequena próxima aos pés.

```text
     cabeca
       O
     corpo
     ####
     ####
     +--+
     |##|  <- colisao
     +--+
```

Estrutura recomendada:

```text
CharacterBody2D
├── Sprite2D
├── CollisionShape2D      (na regiao das pernas / pes)
├── AnimationPlayer
├── AnimationTree
└── Marker2D
```

---

## 8. Sistema de profundidade

Objetos precisam passar na frente e atrás uns dos outros corretamente. No Godot
isso é controlado com **Y-Sorting** (`CanvasItem → Y Sort Enabled = true`).

```text
YSort
├── Player
├── Enemies
├── Crate
├── Table
├── Barrel
└── Props
```

A posição Y dos pés ou da base do objeto determina quem aparece na frente.

---

## 9. Origem dos objetos

Assim como os personagens, objetos devem possuir sua origem na região em que
encostam no chão. Para objetos grandes, normalmente a origem fica no **centro da
base inferior**. Essa padronização faz o Y-Sort funcionar corretamente.

---

## 10. Construção das paredes

As paredes devem possuir pelo menos duas partes visuais.

**Topo** — representa a espessura da parede:

```text
##############
```

**Face** — representa a parte frontal:

```text
##############
::::::::::::::
::::::::::::::
```

```text
     TOPO
+---------------+
|               |
+---------------+
|               |
|     FACE      |
|               |
+---------------+
```

Isso cria a sensação de altura vista pela câmera.

---

## 11. Altura visual das paredes

Proporção de referência do documento original (tile de 64):

```text
Tile de chao:                64 x 64 px
Espessura visual do topo:    16-24 px
Face vertical:               32-48 px
Parede desenhada:            64 x 96 px  (ocupando 64 x 64 no espaco logico)
```

> **O que o `psicode` adota** — tile de **64**, com a razão 1:1 de §24 em vez da
> proporção 2:1 do exemplo acima:
>
> ```text
> espessura logica da parede   64 px   (uma celula)
> altura desenhada do TOPO     64 px
> altura desenhada da FACE     64 px
> ```
>
> Presença visual de 128 px sobre uma célula lógica de 64.

---

## 12. TileMap

Separe os elementos em diferentes camadas (`TileMapLayer`):

```text
TileMap
├── Floor          piso principal
├── FloorDetails   rachaduras, cabos, sujeira, marcas
├── WallBase       parte responsavel pelas colisoes
├── WallFaces      parte vertical visivel
├── WallTop        topo das paredes
├── PropsBack
├── Props          objetos com Y-Sorting
└── Foreground     objetos que passam sobre personagens
```

---

## 13. Chão

O chão deve permanecer praticamente quadrado. Evite transformar tiles quadrados
em losangos.

Correto:

```text
+---+---+---+
|   |   |   |
+---+---+---+
|   |   |   |
+---+---+---+
```

Não:

```text
    <>
  <>  <>
<>  <>  <>
```

A perspectiva deve surgir dos objetos, personagens e paredes, **não** da
transformação completa do piso.

---

## 14. Proporção dos tiles

Para um jogo HD:

```text
Tile logico:   64 x 64
Personagem:    48 x 72  ate  64 x 96
Portas:        64-128 px de largura
Caixas:        48-64 px
Mesas:         96-192 px
```

Para pixel art:

```text
Tile:          32 x 32
Personagem:    24 x 40  ou  32 x 48
```

O importante é manter toda a arte criada usando a mesma perspectiva.

> **O `psicode` usa tile de 64**, com a grade ESTRUTURAL do projeto (16 para
> coordenada, 32 para dimensão de sala) preservada por baixo — 64 é múltiplo das
> duas, então nenhuma coordenada muda e nenhum teste reprova. O custo declarado:
> `960 = 15 × 64` fecha exato, mas `544 = 8,5 × 64` e `800 = 12,5 × 64`, então as
> salas de 544 e a de 1440×800 fecham em **meio tile** na borda. O corte cai em
> 32, que já é subgrade do projeto.

---

## 15. Direções de animação

Para personagens, o ideal é pelo menos quatro direções: `UP`, `DOWN`, `LEFT`,
`RIGHT`.

* `DOWN` mostra rosto, peito e pernas;
* `UP` mostra cabelo, costas e ombros;
* as laterais mostram rosto de perfil, peito parcial e parte superior da cabeça.

Opcionalmente podem existir oito direções (`N NE E SE S SW W NW`). Para um
roguelike de ação, oito direções deixam a movimentação visual mais natural.

> **O `psicode` já tem oito**, com o mapa canônico em `src/util/direcoes.gd`.

---

## 16. Sombras

Sombras são extremamente importantes para vender a perspectiva. A sombra do
personagem deve ficar diretamente próxima aos pés; a do objeto, onde ele encosta
no chão. Use um `Sprite2D` com uma elipse semitransparente ou textura própria.

---

## 17. Iluminação

O estilo funciona bem com luzes suaves (`PointLight2D`, `CanvasModulate`,
`LightOccluder2D`). Porém, **a maior parte do volume deve estar desenhada
diretamente nos sprites**. A iluminação dinâmica complementa a arte; não é
responsável sozinha por criar o efeito 3D.

---

## 18. Direção da luz

Escolha uma direção de iluminação global — por exemplo, **luz vindo de
cima/esquerda**. Então:

```text
Topos:          mais claros
Face frontal:   tom intermediario
Laterais:       mais escuras
Sombras:        baixo/direita
```

Todos os sprites devem obedecer aproximadamente à mesma regra. Isso cria uma
linguagem visual consistente.

---

## 19. Objetos encostados em paredes

Mesas, computadores, armários e prateleiras podem usar sprites desenhados
especificamente para a parede superior:

```text
##################
###  PAREDE  #####

     +---------+
     | MONITOR |
     +---------+
     +---------+
     |  MESA   |
     |         |
     +---------+
```

O jogador vê a superfície da mesa, a frente dela e os objetos sobre ela. Isso
reforça bastante a perspectiva.

---

## 20. Paredes inferiores

Problema clássico: uma parede na parte inferior da sala pode esconder o
personagem.

```text
      PLAYER
        O
##################
##################
```

Três soluções comuns:

1. **Parede cortada** — a parede inferior tem altura visual menor.
2. **Transparência** — `modulate.a = 0.4` quando o jogador passa atrás.
3. **Ocultar automaticamente** — a face frontal some quando o jogador entra na
   região.

Para um roguelike de salas, normalmente a **primeira** é a mais simples e
legível.

> **O `psicode` adota a Solução 1.** A parede sul recebe só o topo (32 px); a
> face é desenhada apenas ao norte e nas pontas sul de leste/oeste.

---

## 21. Colisão das paredes

A colisão deve representar apenas a base lógica da parede. Não use toda a área
visual.

```text
############  <- topo
############
############  <- face
------------  <- colisao / base
```

Assim o personagem consegue caminhar visualmente próximo à parede sem parecer
estar colidindo com uma área invisível enorme.

---

## 22. Ordem recomendada de renderização

```text
Z Index -20    Floor
Z Index -10    Floor Details
Z Index   0    Y-Sorted World Objects (Player, Enemies, Crates, Tables, Barrels)
Z Index  10    Wall Faces / elementos superiores
Z Index  20    Foreground
Z Index 100    Effects
Z Index 200    UI
```

**Não dependa exclusivamente do `z_index`.** Dentro da camada principal dos
objetos, utilize Y-Sorting.

---

## 23. Estrutura de uma sala no Godot

```text
Room
├── Floor
│   └── TileMapLayer
├── Walls
│   ├── WallBase
│   ├── WallFaces
│   └── WallTop
├── YSortWorld
│   ├── Player
│   ├── Enemies
│   ├── Crates
│   ├── Tables
│   └── InteractiveObjects
├── Foreground
├── Lights
└── Doors
```

---

## 24. Regra visual mais importante

Todos os elementos precisam compartilhar aproximadamente a **mesma câmera
imaginária**. Ela não existe no Godot: existe como regra para quem desenha.
Se uma caixa parece vista a 25° e outra a 60°, o cenário começa a parecer
inconsistente.

> **Regra operacional do `psicode`** (a forma conferível de §24, já que o ângulo
> em graus não é medível num teste):
>
> Para todo elemento do cenário, **altura desenhada da FACE ≈ altura desenhada
> do TOPO**, na razão **1:1 com tolerância de ±25%**.

---

## 25. Diferença para outros estilos

| Estilo | Câmera | O que se vê | Grade |
|---|---|---|---|
| Top-down puro | 90° sobre o chão | principalmente o topo | quadrada |
| **Low Top-Down Squared** | ~20–35° de inclinação | **topo + frente** | **quadrada** |
| Isométrico | ~30°/45°, grade diagonal | topo + duas faces | losangos |

Low Top-Down Squared **não** utiliza a transformação isométrica.

---

## 26. Resultado desejado

```text
       #########################
       #     parede traseira   #
       #                       #
       #   +----+   +-----+    #
       #   |mesa|   |caixa|    #
       #   +----+   +-----+    #
       #                       #
       #          O            #
       #         /#\           #
       #         / \           #
       #                       #
       #######       ###########
               PORTA
```

Cada objeto apresenta volume através de seu sprite. O chão continua perfeitamente
organizado em uma grade quadrada enquanto paredes, móveis e personagens mostram
suas faces frontais.

---

## 27. Resumo técnico para o projeto

| | |
|---|---|
| Renderização | 2D |
| Câmera | `Camera2D` ortográfica |
| Mapa | grade quadrada |
| Tile | **64 × 64** (grade estrutural do projeto segue em 16 / 32) |
| Perspectiva artística | Low Top-Down, ~20–35° de inclinação a partir da vertical |
| Ordenação | Y-Sorting baseado na posição dos pés/base |
| Origem dos sprites | centro inferior / contato com o chão |
| Colisões | somente base física dos objetos |
| Personagens | 4 ou 8 direções (**o `psicode` usa 8**) |
| Paredes | topo + face frontal |
| Objetos | topo + frente + sombra |
| Perspectiva do chão | sem transformação isométrica |

**A filosofia central:** o mundo funciona como um top-down 2D tradicional, mas a
arte é desenhada como se uma câmera estivesse posicionada um pouco mais baixa,
permitindo enxergar as faces verticais dos elementos.
