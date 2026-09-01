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
>
> **A segunda metade ainda não existe em código**, e isso está medido em
> `PIVO_PAREDES.md` §7: nenhuma das nove formas de sala tem mais de um lado com
> face. Ela não foi esquecida por acaso — `_montar_faces()` decide por lado
> inteiro, e "ponta sul de um lado leste" não é um lado, é uma **quina**. A
> promessa continua valendo e mudou de dono: ela é `corner_SW` / `corner_SE` na
> issue [PAREDE 06].

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

---

## 28. A porta: a decisão de três vistas foi revertida

> **Esta seção descreve uma decisão que foi tomada, implementada e depois
> REVERTIDA pelo dono do projeto.** Ela fica aqui inteira, e não apagada, porque
> o argumento continua correto e a próxima pessoa que propuser a mesma coisa
> merece saber o que aconteceu quando ela foi tentada.
>
> **O que vale hoje:** a porta usa `porta_moldura.png` — a moldura autorada — nos
> quatro lados, **girada** para a direção de cada um, como era antes da PORTA 03.
>
> **Por que a reversão.** O argumento abaixo é sobre perspectiva e está certo:
> girar uma face deita a face. O que ele não previu é que o substituto teria de
> ser tão bom quanto a arte desenhada. Em três rodadas de correção as vistas de
> cima geradas passaram por chapadas demais, mais claras que a parede, e sem
> cercar o vão — e em nenhuma delas chegaram perto da moldura autorada. Entre
> uma perspectiva correta com arte pobre e uma perspectiva torta com arte boa, o
> dono do projeto escolheu olhando as quatro portas no jogo.
>
> **O que se paga, declarado:** ao leste e ao oeste a face fica deitada; ao sul,
> de cabeça para baixo. O preço é menor do que o argumento sugere porque a
> moldura é quase simétrica nos dois eixos e o que ela mostra — batente, verga e
> soleira — são as peças menos direcionais do desenho.
>
> **O que continua proibido**, e `teste_porta.gd` cobra: giro que não seja um dos
> quatro ângulos retos, giro que discorde de `Porta.direcao`, e `flip_v` — que
> poria a soleira acima da verga, coisa que nenhum giro faz.

### O argumento original, preservado

> **Decisão tomada na PORTA 03 (#101).** Ela estava em aberto e a issue pedia
> que fosse registrada antes de qualquer desenho.

Até essa issue a porta era **a mesma imagem girada** nos quatro lados: 180° no
sul, 90° no leste, −90° no oeste. E `porta_moldura.png` é arte **de face** —
96 px de largura por 128 de altura, com batentes, verga e ferragem desenhados
para serem vistos de frente. Girada 90°, aqueles 128 px de altura viravam 128 px
de extensão horizontal e a face ficava deitada; girada 180°, de cabeça para
baixo. É exatamente o que a §4 proíbe: a perspectiva nasce da arte, e girar uma
face é destruí-la.

### Por que três, e não quatro, duas ou uma

O número **não foi escolhido: ele já estava decidido pela parede.** A §20 diz
que a parede sul recebe só o topo e que a face é desenhada apenas ao norte, e
`Sala._montar_faces()` executa isso — todo lado cuja normal externa não aponta
para a câmera é pulado. Então:

| Lado | O que a parede mostra | O que a porta usa |
|---|---|---|
| Norte | topo **e face** | `porta_moldura` — a face autorada, de frente |
| Sul | só o topo | `porta_topo` — a vista de cima |
| Leste | só o topo | `porta_lado` — a vista de cima, no outro eixo |
| Oeste | só o topo | `porta_lado` **espelhada em x** |

A porta precisa concordar com a parede em que ela está. Uma face na parede sul
seria uma porta mostrando o que a parede ao lado dela não mostra.

As três opções que a issue levantou ficam respondidas assim:

- **Quatro artes** custa uma a mais sem comprar nada: leste e oeste são o mesmo
  lado visto do mesmo ângulo, e espelhar em x reflete sem girar.
- **Duas artes (norte+sul dividindo uma)** não fecha na geometria. A metade
  "para fora" do sprite cai *abaixo* da linha do contorno no sul e *acima* no
  norte; a mesma arte nos dois lados poria a passagem dentro da sala.
- **Uma arte só, sem face**, faria a porta deixar de concordar com a parede
  norte, que tem face.

### O que espelhar e o que girar

**Espelhar em x reflete; girar destrói.** A luz do setor vem de cima e da
esquerda (§18), então uma vista de cima *transposta* leva a iluminação junto e
passa a mentir sobre de onde vem a luz. Por isso `porta_lado` não é `porta_topo`
transposta: nela quem acende é a aresta virada para a sala (a oeste) e o fio de
cima de cada caixa. Espelhar em **y** é proibido pela mesma razão que girar 180°.

`tools/testes/teste_porta.gd:_nenhuma_porta_desenha_arte_girada` varre as cenas
de sala em disco e cobra `global_rotation == 0` e `flip_v == false` em todo
sprite de toda porta. `Porta.direcao` continua sendo a fonte de verdade da
orientação lógica (`vetor()`) — o que mudou é que ela agora escolhe **arte**, e
não um ângulo.

### Uma divergência que fica registrada, e não corrigida aqui

A abertura **visual** da moldura tem 32 px; o vão que a parede abre
(`Porta.LARGURA`) tem 80. Os 24 px de batente de cada lado são chão jogável, e o
jogador passa por baixo deles. Isso é anterior a esta issue — veio com a arte
autorada da LTD 11 — e mexer nisso é redesenhar a moldura, não corrigir uma
rotação. As três vistas usam a **mesma** medida justamente para a divergência ser
uma só, e não quatro.
