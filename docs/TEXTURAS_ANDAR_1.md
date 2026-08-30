# Texturas do andar 1

> **Executado na branch `docs/texturas-andar-1`, em duas ondas.** O que este
> documento prescrevia agora existe, com desvios que a execução obrigou e que
> estão anotados no ponto onde acontecem: são **quatro** variações de chão e
> parede e não um par (§4.1), a arte é **autorada** e não gerada (§8), e G1 virou
> **regra de gamut** em vez de lista de 22 cores (§4.2).
>
> A **onda 2** deu identidade própria a boss, arma e item: mesma linguagem de
> material, matiz próprio — 330–355° no chefe, 25–50° na arma, 150–180° no item,
> contra os **185–320°** da base (ver §13). O corredor fica na noite azul de
> propósito. E o
> chão do chefe leva teto de valor mais baixo que os outros (0,24 contra 0,30):
> é a sala mais densa de projétil do jogo e o matiz dela é vizinho do
> `tiro_diretora`, então a folga de valor vale mais ali do que em qualquer
> outro lugar.

Este documento existe para que alguém consiga **desenhar textura nova para o mapa
sem reinventar a direção de arte a cada vez**. Ele parte de `assets/bg_menu.jpg`
e a converte em números e receitas.

---

## 1. Tese, escopo e o que isto revoga

### 1.1 A tese

A referência é uma **imagem única**. Um cano aqui, um ar-condicionado ali, uma
poça exatamente naquele ponto — nada dela se repete.

O jogo não tem esse luxo. O chão é um tile de 128×128 que aparece **32 vezes na
mesma tela** numa sala de 960×544 (66 na sala grande). A faixa de parede é uma
fila de **30 painéis de 32 px** ao longo de uma parede de 960.

> **Tile é MATERIAL. Prop e decalque são INCIDENTE.**
>
> Material tem de ser quieto o bastante para repetir 30 vezes sem denunciar a
> repetição. Todo detalhe que alguém vá *reconhecer* — e portanto reconhecer de
> novo, e de novo — sai do tile e vira objeto colocado uma vez só.

Quem ignora isso produz uma de duas falhas, e o jogo hoje tem as duas: **tile
rico demais** vira cerca de estacas (é a parede), **composição pobre demais**
vira campo vazio (é o chão). A referência parece rica porque é composta, não
porque seu material é elaborado.

### 1.2 O que este documento governa

| Governa | Não governa |
|---|---|
| `assets/texturas/*.png` — chão, parede, porta, atlas | HUD, menus, tela de fim |
| As rampas de `tools/texturas/paleta.gd` | Cores de UI escritas à mão nos scripts |
| Colocação de prop e decalque em `src/mapa/` | Cor de ator (mora no `.tres` de cada um) |
| O corredor | O minimapa — mas ver §11 |

**Isto importa porque há ~20 azuis quase-pretos escritos à mão na UI**
(`moldura_hud.gd`, `selecao_personagem.gd`, `barra_vida.gd`,
`barra_deterioracao.gd`, `barra_atributo.gd`) que **nenhum portão cobre** —
G1/G2/G3 só leem PNG de `assets/texturas/`. Eles foram calibrados contra o chão
antigo. Este documento **não** os governa; se a noite azul os deixar estranhos,
isso é trabalho declarado e separado.

### 1.3 O que já está em outro lugar

A paleta `N0`–`N7`, os três portões (G1 gamut / G2 leitura / G3 separação), a
grade de 16/32 e as seis regras de leitura de combate estão em
**`docs/IDENTIDADE_VISUAL.md`**. Uma verdade por assunto: onde os dois encostam,
este aponta em vez de copiar.

### 1.4 O que este documento REVOGA

Não é repetição, é contradição — e a regra "o código ganha" não desempata texto
contra texto. Então fica nominal:

| Onde | O que morre |
|---|---|
| `IDENTIDADE_VISUAL.md` §"acento por tipo" | a tabela de 5 rampas **amarrada a chão/parede**. As rampas seguem vivas; o vínculo com o piso, não |
| `IDENTIDADE_VISUAL.md` "as cinco variantes aparecem todas" | passam a ser quatro variações da MESMA noite, sorteadas por célula |
| `IDENTIDADE_VISUAL.md` "Corredor: mesmo chão e parede da variante `combate`" | não há mais variante `combate` |
| `IDENTIDADE_VISUAL.md` "a faixa de 24 px carrega sozinha a identidade da sala" | ela carrega a identidade do ANDAR; a da sala vai para o prop |
| `IDENTIDADE_VISUAL.md` "o disco de perigo é `z=0`, acima do chão" | **é falso hoje** — ver §5.3 |
| `GEMINI.md` linhas 110 e 149 | citam "filete por tipo", removido no commit `73e31c0` |

---

## 2. A referência medida, contra o jogo de hoje

Nada aqui é impressão. Os métodos estão no [apêndice](#apêndice-como-refazer-as-medições).

### 2.1 O delta, lado a lado

| | referência | jogo hoje | veredito |
|---|---|---|---|
| matiz dominante | 209–250° (mediana 228°) | 224–230° | **já está certo** |
| saturação no mesmo escuro | **0,74–1,00** | **0,32–0,50** | dessaturado demais |
| cores por textura | rampa rica | 4 a 7 | chapado |
| V do "chão" | 0,40 (rua) | 0,09 | ver §2.3 |
| V da "parede" | 0,22 (fachada) | 0,30 | ver §2.3 |
| densidade do chão | 44,5% | **12,7%** | ver §2.4 |
| densidade da parede | 31,4% | **59,3%** | ocupado demais |

**A referência é saturada E escura** — não dessaturada. São coisas diferentes, e
o portão G2 aceita as duas (`AMBIENTE` = dessaturado **ou** escuro, nunca
saturado *e* claro).

A rampa `N0`–`N7` do jogo **dessatura conforme clareia** (S cai de 0,55 em `N0`
para 0,30 em `N7`); a referência mantém S alto em todo degrau. É a diferença
entre "concreto azulado" e "noite azul".

### 2.2 O neon é quase todo azul — e é o risco central

Dos pixels em gamut de ator, **72% estão entre 180° e 240°**. O que parece "neon
colorido" é, em massa, **o mesmo azul do ambiente, aceso**.

É exatamente a faixa de seis atores do jogo: `tiro_volt` 188°, `tiro_pistola`
191°, `tiro_sentinela` 210°, `tiro_railx`/`gravity_gun` 233°, `tiro_nanite`
236°, `salva_diretora` 263°.

> **Consequência dura:** indo para o azul-violeta, o mapa perde separação de
> MATIZ contra esses seis. A separação passa a ser de **VALOR** — e é por isso
> que o teto do chão em §4.2 existe. É o que a referência faz: fundo abaixo de
> V 0,30, neon acima de V 0,70.

O acento **não-azul** é só **2,4% da imagem**, e é ele que carrega identidade:
violeta 17,2% do neon (`#ba4de8`), magenta 5,5% (`#c941e9`), âmbar 2,7%
(`#fce8a3` — um branco quente, não laranja), vermelho 0,7%, **verde 0,0%**.

### 2.3 A hierarquia de valor: a referência está ERRADA para o jogo

**Na referência a rua (V 0,40) é mais clara que os prédios (V 0,22). No jogo é o
contrário**, e o jogo está certo.

Vista de cima, a faixa de parede não é fundo: é a **moldura que diz onde a sala
termina** — e desde que o filete de neon saiu, é a *única* coisa que diz isso.
Moldura mais escura que o miolo não delimita nada.

> **Copie a paleta e o vocabulário da referência. Nunca a hierarquia de valor.**
> Quem desenhar olhando a imagem vai copiar uma rua clara sem perceber.

### 2.4 A densidade: o remédio não é o óbvio

Parece dizer "encha o chão, esvazie a parede". **Só a segunda metade está certa**,
pela §1.1:

- **O chão tile em 12,7% está certo.** Ele repete 32 vezes na tela; detalhe
  distintivo ali não enriquece, denuncia. O que falta não está no tile — falta
  **incidente não-repetido**, e o jogo não tem decalque nenhum.
- **A parede em 59,3% está errada, e por motivo estrutural:** `gerar_parede()`
  desenha a mesma moldura embutida, a mesma borda e os mesmos quatro rebites em
  **todos os 16 painéis**. Ao longo de 960 px isso vira 30 molduras idênticas em
  fila. A fachada da referência é calma no geral e concentra detalhe em
  **corridas** — que no jogo são props.

### 2.5 Ela não é pixel art de grade real

Testei passos de 1 a 12 px: nenhum passa de 1,06× a energia média de borda. É uma
imagem de **sabor** pixel art, gerada.

**Não trace a referência.** O resultado sai fora da grade de 16 e reprova em
`tools/testes/teste_grade.gd`. Ela serve de paleta e de vocabulário de motivo.

---

## 3. Os 17,8% proibidos: para onde essa luz vai

Este é o fato mais pesado da medição, e ele elimina receitas antes de serem
escritas.

**17,8% da referência vive no gamut de ATOR** (S > 0,35 **e** V > 0,55). O portão
G2 proíbe isso em AMBIENTE por construção — não é preferência, é o que separa
cenário de gameplay.

Esses 17,8% **não têm para onde ir** dentro da arquitetura atual:

| saída | por que não serve |
|---|---|
| AMBIENTE | G2 reprova, por definição |
| SINAL | `nomes_de_ambiente()` tem exceção **hard-coded a um único arquivo** (`porta_campo.png`), e `IDENTIDADE_VISUAL.md` fixa o piso: *"o menor sinal do jogo é o campo de porta, 80×32"*. Um painel de 32×32 seria o menor SINAL do jogo e quebraria a regra escrita |
| shader | G1 lê PNG, não pixel de shader — a família inteira sairia do alcance dos portões. O único shader do projeto sobrevive por ter `alpha_maximo` como teto duro |

**Duas famílias que eu tinha imaginado morrem aqui, e é melhor dizer agora:**

- **"Painel aceso"** no sentido da referência — um retângulo pequeno e
  genuinamente brilhante — **não pode existir** como textura de ambiente. O que
  pode existir é o painel *apagado* que o jogo já tem (`_prop_painel_acento`):
  carcaça escura com um traço de acento. Ele lê como "há um painel ali", não como
  "há uma luz ali". É a diferença entre a referência e o jogo, e é o preço da
  leitura de combate.
- **"Chuva"** não tem caminho nenhum: nada no pipeline anima textura, e de cima
  a chuva quase não se lê. Fica de fora. O que sobra dela é gotejamento
  pontual, estático, em decalque.

**A regra que fica:** o andar 1 reproduz a *composição* da referência — escuro
dominante, acento raro e alongado — mas **rebaixada em valor**. Onde ela acende,
o jogo insinua. A luz de verdade pertence ao jogador, aos inimigos e aos tiros.

---

## 4. A paleta do andar 1

### 4.1 A decisão: uma noite só

Havia cinco variantes de chão e cinco de parede, uma por tipo. A identidade do
tipo migra para o painel de acento, a marcação de chão (props que já existem,
linhas 2 e 3 do atlas) e o `cor_mapa` do minimapa.

> **Corrigido na execução: são QUATRO variações da mesma noite, sorteadas por
> célula** (`hash(coordenadas_grid)`), e não um par único para o andar. Um par só
> lê como uma sala repetida sete vezes — e as ~7 salas de combate apontam todas
> para a mesma instância de `tipo_combate.tres`, então "por tipo" e "por andar"
> já eram a mesma coisa. O campo virou `Array[Texture2D]`, o que também é o que
> deixa a onda 2 ser mudança de dado e não de código.
>
> O que segue valendo é a **família**: uma noite só para o andar.

**Por quê:** o andar passa a ler como *um complexo*, que é o que a referência é —
uma rua, não cinco. E a variação por tipo nunca foi forte: as cinco variantes de
chão diferem em pouquíssimos pixels num tile que já é 90% neutro.

**O que se perde, e é real:** hoje dá para saber que sala é esta pela cor do
chão, à distância. Isso acaba. Se em playtest alguém se perder, o conserto é
engrossar o prop de acento — não voltar a tingir o chão.

### 4.2 A rampa

Colhida das cores dominantes reais da referência — **não inventada** — e já
validada contra G2:

| | hex | H | S | V | papel |
|---|---|---|---|---|---|
| `B0` | `#000112` | 237° | 1,00 | 0,07 | vão de porta, sombra profunda |
| `B1` | `#05092b` | 234° | 0,88 | 0,17 | chão, tom baixo |
| `B2` | `#0a1030` | 231° | 0,79 | 0,19 | **chão, base** |
| `B3` | `#0d1547` | 232° | 0,82 | 0,28 | chão, aresta e junta clara |
| `B4` | `#112462` | 226° | 0,83 | 0,38 | **parede, base** |
| `B5` | `#1b397f` | 222° | 0,79 | 0,50 | parede, aresta iluminada |

> **Status: proposta.** Estas seis cores ainda **não existem** em `paleta.gd`.
> Nenhum PNG pode usá-las antes disso — G1 exige que todo pixel opaco pertença a
> `Paleta.ambiente()`.

```
V  0,00 ─────────────────────────────────────────── 1,00
        B0   B1  B2  B3      B4     B5     │    atores
        0,07 17  19  28      38     50     │    > 0,55
        └──── CHAO ───┘  └── PAREDE ──┘    │
             teto 0,30       teto 0,50     └─ folga minima 0,25
```

O teto de 0,30 no chão não é estético: garante **0,25 de folga de valor** contra
o piso de qualquer ator. Como o matiz deixou de separar (§2.2), o valor é a única
separação que resta, e precisa ser generosa.

**O teto de cima é duro.** O degrau seguinte da referência, `#2b4a8f`
(S 0,70 / V 0,56), **reprova em G2**. Não existe "só um pouquinho mais claro".

### 4.3 Três armadilhas ao mexer em `paleta.gd`

1. **Não existe teto de V sobre o conjunto.** G2 é `S > 0,35` **E** `V > 0,55`.
   Um cinza-azul dessaturado com V 0,90 passa nos três portões e destrói a noite.
   O único teto hoje é uma asserção que olha `N7` **pelo nome literal** — se `B5`
   virar o topo real de brilho, o teste continua olhando `N7` e não vê nada.
   Ver §12.
2. **`TOLERANCIA_CANAL = 1,5/255` funde cores em silêncio.** `ambiente()` já
   desduplica: são 22 cores e não 23, porque `ACENTOS[inicial][A0]` é
   *exatamente* `N3`. Com `B0`–`B5` você fica com 14 azuis escuros. Conferi que
   nenhum par colide — mas isso tem de virar asserção, não sorte.
3. **`Paleta.acento()` só entende `A0/A1/A2`** e cai em `combate` para tipo
   desconhecido. `B0`–`B5` precisa de acessor próprio ou de ir para `NEUTROS` — e
   se for, a escada semântica N0..N7 fica com dois eixos.

### 4.4 O conflito do verde

A referência tem **0,0% de verde**. O tipo `item` é verde-água
(`cor_mapa #7DF7C4`, `A2 #288a71`), e `SINAL.pickup_item` também.

**Recomendação: manter o verde.**

1. É **código de gameplay**, não decoração. Verde = item é associação já feita, e
   vale mais que fidelidade a uma imagem de menu.
2. A regra vigente diz que **`cor_mapa` nunca é pintado no mundo**. O verde vive
   no minimapa e no pickup — que são SINAL. Ele nunca disputa parede com a noite.
3. É o único acento que **não** colide com a família azul, o que o torna o mais
   legível dos cinco, não o menos.

Alternativa registrada: deslocar `item` para turquesa (~170°). Custa reeducar o
jogador e aproxima do `atirador_neon` (166°). **Não recomendo.**

### 4.5 Orçamento de acento

Alvo: **2 a 3% da superfície**, que é o que a referência mede. Num tile de
128×128 (16.384 px) isso é **~390 px** — menos de um quarto de um painel de
32×32. Acento é tempero.

---

## 5. Ordem de desenho

§7 propõe uma camada nova, e camada nova é indefensável sem isto. Hoje a ordem
só existe num comentário de `sala.gd`.

### 5.1 Como está

```
z=-4  AreaDePerigo   telegrafo do Hacker Parasita   <-- ERRADO, ver 5.3
z=-2  ParedeCorpo    contorno inflado 24 px
z=-1  Chao           contorno, textura de chão
z=-1  Decoracao      props            (move_child 2)
z=-1  ObstaculoCorpo pilar
z=-1  Moldura        da porta, dentro de "Portas"
z= 0  Parede         Line2D, invisível em runtime
z= 0  atores, projéteis
z=+1  Campo          da porta (SINAL)
```

**Empate em z é resolvido pela ordem de filho, não pelo z.** É por isso que
`_montar_visual()` usa `move_child(corpo, 0)` e `move_child(chao, 1)`: a moldura
da porta também está em z=−1 e precisa ficar acima do chão. Essa cadeia de
índices é **load-bearing** e hoje só está documentada num comentário.

### 5.2 Onde o decalque entra

`Decalques` no índice de filho **2**, empurrando `Decoracao` para 3 — ainda antes
de `Portas`. Decalque estritamente **abaixo** do prop: no mesmo nó e mesmo z, a
ordem sairia por RNG.

### 5.3 Um defeito vivo, achado ao escrever isto

**`src/enemies/area_de_perigo.tscn` tem `z_index = -4`. O chão está em `-1`.**

O nó nasce em `ContainerInimigos`, que é filho da Sala (z=0), então o z efetivo é
−4 — **abaixo do chão**. O telégrafo do Hacker Parasita está sendo desenhado por
baixo do piso.

Era inofensivo antes de `_montar_visual()` existir: não havia polígono de chão
para tapar. Passou despercebido porque **nenhum teste olha pixel**: o teste de
fumaça não toca em textura, e `teste_area_de_perigo.gd` verifica lógica.

O GDD é explícito: *"Ataque sem telegrafo. Bullet hell só é justo se dá para ler
a intenção antes do projétil existir."* Um telégrafo invisível é pior que
nenhum — ele existe no código e mente no orçamento de justiça do jogo.

Compare com `explosao_area.tscn`, em z=−1: ela sobrevive só por ordem de irmãos.

**Não é escopo deste documento consertar** — é uma linha em um `.tscn` e um
`.md`. Fica registrado porque um chão mais rico torna isso mais caro, não menos.

---

## 6. Prop e decalque são coisas diferentes

Isto vem **antes** das receitas de propósito: ele decide quais receitas podem
existir.

Hoje só existe prop, e `sala.gd` o prende na margem: `_sortear_ponto_de_prop()`
sorteia um **lado do contorno** e afasta 24–44 px pela normal. O comentário
explica: *"um prop no meio do chão, sem colisão, pareceria um obstáculo
mentiroso"*.

**O raciocínio está certo para volume e errado para mancha.** Uma poça não mente
sobre colisão — ninguém espera contorná-la.

| | Prop | Decalque |
|---|---|---|
| o que é | tem volume, lê como objeto | chapado, lê como piso |
| onde pode | margem, 24–44 px do contorno | qualquer lugar do miolo |
| perto de porta | ≥ 96 px | sem restrição |
| exemplos | caixa, tambor, terminal, AC, cano | reflexo, poça, grelha, cabo, tampa |
| teto de valor | `B5` | **`B2`** — ver abaixo |

> **O teste de qual é qual:** imagine o jogador andando por cima. Se a
> expectativa natural for *"passo por cima"*, é decalque. Se for *"contorno"*,
> é prop.

### 6.1 O guarda que você acha que existe não existe

`_cabe_prop()` rejeita prop que toque a `area_spawn`. Medi as nove salas: a folga
entre contorno e `area_spawn` é **≥ 96 px em oito delas**, e o prop nunca passa de
44+16 = 60. **Essa checagem nunca dispara nessas oito.** Quem impõe "prop fica na
margem" é o `PROP_AFASTAMENTO_MAXIMO`, não ela.

As duas exceções são instrutivas:

- `sala_6_boss`: `area_spawn` é um ponto de 32×32 no centro. Não guarda nada.
- `sala_2_l_shape`: cobre só a faixa norte, e ali a checagem **dispara** — rejeita
  prop sempre que o afastamento passa de 32, o que afina a parede mais longa da
  sala. Ninguém escreveu isso de propósito.

**Portanto: o amostrador de decalque não pode se apoiar em `area_spawn`.** Ela é
`@export` por sala, foi desenhada para spawn de inimigo, e em duas das nove não
descreve o miolo. Use `contorno_local()` com `Geometry2D.is_point_in_polygon` e
`_local_livre()`, que já resolve o L côncavo e o pilar da sala 5.

### 6.2 Por que o decalque é mais apertado que o prop

O decalque vive **onde o combate acontece**. O inimigo vai nascer em cima dele, e
isso é correto — ele é chapado, não tem volume. Mas isso o põe na parte mais
cheia da tela.

Por isso o teto dele é `B2` (V ≤ 0,19) e não `B5`: **mais escuro que o prop, que
vive na margem calma.** É contraintuitivo — o reflexo "deveria" ser o mais
brilhante — e é justamente por isso que precisa estar escrito. Um reflexo em `B5`
no meio da sala é um campo claro sob os projéteis.

E decalque com **borda fechada e brilhante volta a mentir**: lê como tampo de
objeto. Por isso a poça tem borda quebrada (§8.5).

---

## 7. Da rua para a planta baixa

Metade dos motivos não sobrevive à conversão, e saber **qual** metade evita
trabalho jogado fora.

| Motivo na referência | Vira | Onde | Nota |
|---|---|---|---|
| Corrida de cano vertical | corrida ao longo da faixa | **prop** | o motivo mais característico dela |
| Cotovelo de cano | dobra na quina | prop | já existe |
| Persiana de loja (ripas) | ripas transversais | prop | |
| Ar-condicionado, caixa de junção | volume preso à parede | prop | |
| Placa com glifos | placa lida de cima | **prop** | **é aqui que o tipo aparece** |
| Terminal | terminal | prop | já existe |
| Grade de ventilação | grelha no piso | **decalque** | hoje é prop; migra |
| Rua molhada com reflexo | traços horizontais alongados | **decalque** | a família mais importante |
| Poça | mancha de borda irregular | **decalque** | |
| Trilho, costura da rua | junta longa direcional | **tile de chão** | seguro de repetir |
| Bueiro, tampa | tampa | decalque | ⚠ abaixo |
| Cabo atravessando o beco | cabo caído | decalque | |
| Lixeira, vending machine | volume | prop | |
| **Painel genuinamente aceso** | **não traduz** | — | §3 |
| **Chuva** | **não traduz** | — | §3 |
| **Fachada, janela, sacada** | **não traduz** | — | não há alçado visto de cima |
| **Toldo** | **não traduz** | — | é aéreo |
| **Perspectiva, ponto de fuga** | **não traduz** | — | a câmera é ortogonal |

> ⚠ **A tampa de bueiro é a armadilha desta tabela.** Disco isolado de 3 a 6 px é
> literalmente a silhueta de um projétil, e a regra 3 de leitura de combate o
> proíbe. Tampa entra **só grande (≥ 24 px) e com marcação interna** — barras,
> quadrantes — que a afaste de "tiro". Um disco liso de 20 px é um pickup falso.

---

## 8. Receitas

Usam os helpers que `gerar_texturas.gd` já oferece: `_nova`, `_pintar` (é ele que
faz o wrap e garante o seamless), `_ret`, `_disco`, `_anel`, `_cel`, `_ruido`
(hash puro) e `_rng` (semente fixa).

### 8.1 Chão — a receita em vigor (LTD 06)

> **§8.1.1 abaixo é a receita PROCEDURAL, superada.** Ela descreve o chão como
> `gerar_texturas.gd` o desenhava, em 128×128. O chão do andar 1 é arte autorada
> em 256×256 desde a migração Low Top-Down, e §8.1.1 fica só como registro de
> onde os números vieram.

As três variantes (`chao_andar1_a/b/c.png`) foram refeitas na **LTD 06** (issue
#36). O que mudou, e por quê:

| antes | agora |
|---|---|
| foto de metal recortada de `bg_menu.jpg` | pixel art gerada, grade de placas |
| **sem grade** — o deslocamento só cresce (5,3 em 64) | **grade de 64** — cai a 1,1–3,2 em 64 |
| pontos claros redondos: 8 no `a`, 2 no `b` | **0 nos três** |
| S mediano 0,40–0,56, V mediano 0,16 | S 0,40–0,41, V 0,12 |

A medida de grade é `mean(abs(img - roll(img, d)))` por deslocamento `d`: se o
mínimo cai em 64, o olho tem onde se apoiar a cada 64 px. O gabarito é
`chao_boss.png`, que já media 1,03 ali.

**O comando, literal** — o mesmo para as três, mudando só os nomes:

```bash
python tools/texturas/preparar_textura.py preparar ORIGEM.png     assets/texturas/chao_andar1_a.png     --familia chao --tipo andar1 --lado 256     --desvinheta --tingir 235 --saturacao 0.55 --grampear-matiz 195 310
```

Os três pré-passos são obrigatórios aqui e nenhum é enfeite:

- `--desvinheta` porque a arte chega com um facho diagonal, e vinheta em
  ladrilho vira uma cruz escura repetida pela sala inteira;
- `--tingir 235 --saturacao 0.55` porque a arte chega quase cinza (S mediano
  0,10). Sem isso o funil só apara — `teto_s` nunca levanta — e o andar perde a
  noite azul, que é a identidade dele;
- `--grampear-matiz 195 310` porque sem ele o matiz sai em 180–330 e estoura a
  faixa `andar1` (185–320) pelos dois lados.

A origem é gerada pelo PixelLab, `create_image_pixflux`, 256×256, `high
top-down`, `low detail`, `flat shading`, `lineless`. O prompt pede grade 4×4 de
placas — 256/4 = 64, que é como a grade de 64 entra. **Prompt negativo não
funciona**: pedir "no bolts, no rivets" continuou trazendo parafusos nas três
tentativas. O que resolveu foi medir depois e trocar a variante, não insistir no
texto.

### 8.1.1 Chão — `chao_andar1.png`, 128×128 (receita procedural, SUPERADA)

**Mandamento: repete 32 vezes na tela. Nada memorável aqui.**

| # | camada | conteúdo |
|---|---|---|
| 1 | base | `B2` chapado |
| 2 | grão | `_ruido`: `< 0,10` → `B1`; `> 0,90` → `B3`. Simétrico, sem aglomerado |
| 3 | placas 32 | junta de 1 px `B0` em `x==0`/`y==0`; aresta clara 1 px `B3` em `x==1`/`y==1` |
| 4 | costura | **uma** linha de 1 px `B3` atravessando o tile na horizontal — o "trilho"; seguro de repetir porque é infinito por construção |
| 5 | acento | **nenhum** |

Sai a variação por tipo (os três `randf()` por placa: `clara`, `respiro`, `led`),
sai o acento `A0`/`A1`, e a rampa troca de `N1`–`N3` para `B1`–`B3` — o que sobe a
saturação de ~0,45 para ~0,80 sem mexer no valor.

Densidade alvo: **10–15%**. É o que já é, e está certo (§2.4).

### 8.2 Parede — a FACE industrial (identidade do andar 1)

A face da parede é **a superfície que carrega a identidade do setor**. A regra
que governa isso é de legibilidade, não de gosto: o chão é onde o combate é
lido, então ele fica quase liso e a informação visual desce para as bordas da
sala.

Medido no style test:

| | densidade | o que é |
|---|---|---|
| chão | 20–22% | placas, juntas, quase nada mais |
| face | **55%** | painéis rebitados, nervuras, escotilha, fileiras de parafuso |

A face é a única superfície do projeto que **excede a faixa de densidade de
propósito** (18–34% para parede). A faixa foi calibrada quando a parede era
chapada; com topo e face, a face é justamente onde a densidade deve ir.

**Ela saiu do gerador.** `parede_face.png` era procedural e passava por G1 — o
portão que cobra pertinência a uma lista de 22 cores. Arte autorada não passa
por ali: G1 proíbe gradiente, dithering e sombra, que é o que tira a superfície
do chapado. Ela migrou para o regime AUTORADO, como chão e parede já haviam
feito. `gerar_parede_face()` continua no gerador, fora de `nomes()`, como
registro de onde o valor dela veio.

```bash
python tools/texturas/preparar_textura.py preparar ORIGEM.png     assets/texturas/parede_face.png     --familia parede --tipo andar1 --manter-tamanho --sem-costura     --desvinheta --tingir 232 --saturacao 0.50 --grampear-matiz 195 310
```

### Uma sala mostra UMA face — e isso manda no planejamento de arte

Medido nas nove formas de sala: **todas desenham exatamente uma face.**

`Sala.LIMIAR_LADO_NORTE` só desenha face no lado cuja normal aponta para o
norte — a parede do fundo, a única cuja superfície vertical está virada para a
câmera. É geometricamente certo para esta perspectiva, e é o que impede o
cenário de cobrir jogador, inimigo, projétil e telegrafo.

A consequência não é óbvia e vale antes de desenhar: **uma biblioteca de cinco
módulos de face não produz cinco painéis diferentes numa sala.** Ela produz
variedade ao longo do ANDAR — salas vizinhas vestindo módulos diferentes. Quem
produzir os módulos precisa saber disso, senão desenha pensando numa composição
que nunca acontece.

O sorteio é por `(célula, lado)` mesmo assim. Custa nada, e o dia em que uma
sala tiver dois trechos de fundo — um L entalhado por cima — ela já veste os
dois sem mudança nenhuma.

### A identidade do tipo mora na face

Cada `tipo_*.tres` declara `texturas_face`. As cinco são a mesma estrutura
industrial tingida na rampa do tipo:

| tipo | matiz | faixa que o portão cobra |
|---|---|---|
| combate | 200, ciano rebaixado | 185–320 |
| inicial | 221, cinza-azulado | 185–320 |
| boss | 342, rosa rebaixado | 330–355 |
| arma | 37, âmbar rebaixado | 25–50 |
| item | 165, verde-água rebaixado | 150–180 |

Estrutura e acento são eixos **ortogonais** de propósito: a estrutura diz "é o
mesmo setor", o acento diz "é outra sala". Trocar a estrutura por tipo faria o
andar deixar de ser um lugar só.

### A ferrugem: por que ela NÃO é matiz no chão nem na parede

Isto custou quatro gerações e vale ficar escrito.

A faixa de matiz do andar 1 é **185–320**. Ferrugem literal fica em ~25–40°, que
é **exatamente a faixa da sala de arma** (`A1 = #6b4d1e`, matiz 37°). As faixas
são disjuntas de propósito — é o que faz a sala de recompensa se anunciar de
longe.

Pedir ferrugem laranja ao gerador e passar pelo funil produz um resultado pior
que não ter ferrugem: `grampear_matiz` empurra o laranja para dentro da faixa, e
a corrosão vira **manchinhas ciano** — a família de cor dos projéteis do
jogador, salpicada pelo chão. Uma das variantes mediu **68 pontos com silhueta
de projétil** (o gabarito é zero).

Então a regra, que é a do próprio plano de identidade:

> A ferrugem aparece por **padrão, contraste, mancha e valor** — nunca por matiz
> — em qualquer superfície com faixa de matiz (chão, parede). Matiz de ferrugem
> só é permitido nos **props**, que são a única família sem faixa
> (`SEM_FAIXA_DE_MATIZ`).

Na prática, ao gerar arte de chão ou parede: pedir riscos, amassados, placas
remendadas, manchas escuras de óleo — e escrever `no rust, no orange, no
corrosion colour, no speckles` no prompt. Prompt negativo não é confiável, então
**medir depois** com `preparar_textura.py conferir`.

### 8.2.1 Parede — `parede_andar1.png`, 128×128 (receita procedural, SUPERADA)

**Mandamento: 30 painéis em fila. Calma.**

| # | camada | conteúdo |
|---|---|---|
| 1 | base | `B4` chapado |
| 2 | grão | `_ruido`: `< 0,12` → `B3`; `> 0,88` → `B5` |
| 3 | junta | 1 px `B3` em `x==0`/`y==0` — **só a junta, sem moldura embutida** |
| 4 | aresta interna | 1 px `B5` na borda que dá para dentro da sala |
| 5 | rebite | 1 px `B5`, **um por painel** (não quatro), em posição derivada de `_ruido` para não formar fileira |

Densidade alvo: **20–30%**, contra 59,3%.

> **A simetria continua obrigatória.** Só uma faixa de 24 px aparece em jogo, e
> pode ser qualquer fatia em qualquer direção — o desenho tem de ler como
> "parede" em `x` e em `y` igualmente.

### 8.3 Moldura de porta — 96×48

Só troca de rampa: `N0`→`B0` na passagem, `N4`–`N7`→`B3`–`B5`. A geometria
(batente de 8, soleira em 20–27, transparente de 28 a 47, ranhuras a cada 16)
está certa e não se mexe. `porta_campo.png` **não muda** — é SINAL.

### 8.4 Corredor

O corredor sorteia a variante pela própria posição (`hash` de `global_position`),
já que não tem célula, e **não tem decoração nenhuma** — nem prop, nem decalque. É a superfície onde a
"rua molhada" da referência estaria mais disponível, e é a mais pelada do jogo.

**Decisão: o corredor recebe decalque, não prop.** Ele é estreito (80 px de vão) e
um volume ali estreitaria uma passagem que já é apertada — mas uma poça não
estorva ninguém. É a tradução mais direta da referência que o jogo tem.

Isso exige que `corredor.gd` ganhe o amostrador de decalque; hoje ele não tem
nenhum caminho de decoração. Fica em §11 como trabalho de código.

### 8.5 Decalques — a família que não existe

**São a peça que falta para o chão parecer molhado.** Todos chapados, teto `B2`
(§6.2).

| decalque | desenho |
|---|---|
| **reflexo** | 3 a 5 traços horizontais de 1–2 px de altura e 6–14 de largura, em `B1`/`B2`, alinhados no eixo x, com vãos irregulares |
| **poça** | mancha de borda irregular via `_ruido` radial (`_prop_mancha` já faz isso), miolo `B1`, borda `B2` de 1 px **quebrada** |
| **grelha** | 24×16, barras `B0` sobre `B2`, moldura `B2` |
| **cabo caído** | linha de 2 px serpenteando, `B1` com highlight `B2` |
| **tampa** | ≥ 24 px de diâmetro, anel `B2`, miolo `B1`, quatro barras internas `B2` |
| **gotejamento** | 2 ou 3 traços verticais de 1×3 px `B2`, muito esparso |

Regra de forma para todos: **alongado ou grande, nunca disco pequeno.**

### 8.6 Props — as DUAS famílias (LTD 09)

Desde a LTD 09 existem **dois atlas**, e a divisão não é de estilo, é de
perspectiva. §8.6.1 abaixo descreve os chapados, que continuam valendo.

| | `props_atlas.png` | `props_volume.png` |
|---|---|---|
| o que é | coisas **no** chão | coisas **sobre** o chão |
| exemplos | mancha, marcação, grade, painel | caixa, terminal, mesa, armário, máquina |
| célula | 32×32 | 32×64 e 64×64 |
| z | `Z_CHAO_DETALHE`, fora do Y-sort | `Z_MUNDO`, ordenado por Y |
| origem | centro | **base**, com sombra |
| como nasce | gerado por código | arte autorada |
| o que o tranca | **determinismo** byte a byte | gamut e teto de valor medidos |

São dois ARQUIVOS de propósito. Fundir num atlas só obrigaria a escolher um
regime, e o perdedor seria o determinismo — que hoje é o que impede alguém
mexer no gerador e esquecer de rodar.

**O layout de `props_volume.png`** (256×128). Todo `x` e `y` é múltiplo de 32,
que é o que `teste_texturas.gd` cobra:

```text
y= 0  32x64 : 0 caixa | 32 terminal | 64 mesa | 96 armario
              128 barril | 160 duto | 192 caixote | 224 cilindro
y=64  64x64 : 0 maquina | 64 rack | 128 caixas | 192 gerador
```

**A âncora é o contrato, e ela tem duas pontas.** O atlas encosta a arte no
**fundo** da célula; `Sala._montar_props_volumetricos` desloca o sprite em
`-altura/2`. As duas juntas põem a base do prop na origem do nó — que é por
onde o Y-sort o ordena e onde a sombra nasce. Nenhuma das duas se prova
sozinha, e `tools/testes/teste_props.gd` mede as duas: recompor o atlas
centralizando a arte faria **todos** os props flutuarem meio corpo, com a sala
continuando a fazer a conta certa sobre um dado errado, e sem erro no console.

**O comando, literal:**

```bash
python tools/texturas/preparar_textura.py preparar ORIGEM.png \
    assets/texturas/props_volume.png \
    --familia prop --manter-tamanho --sem-costura \
    --tingir 232 --saturacao 0.50 --limiar-neon 0.42 --alvo-v 0.20
```

As três flags que não são óbvias:

- `--manter-tamanho` porque o funil nasceu para **ladrilho**, que é sempre
  quadrado, e `--lado` força `lado × lado`. Um atlas não é ladrilho: esticar
  256×128 para 256×256 deforma cada prop e desalinha **todas** as regiões dos
  `tipo_*.tres` de uma vez. A flag nasceu nesta issue, por ter acontecido.
- `--sem-costura` porque a borda direita de um atlas nunca encosta na esquerda.
  Costurar misturaria o cilindro com a caixa.
- `--limiar-neon 0.42` deixa passar o acento âmbar das cintas do cilindro, que
  é o único acento aceso do conjunto.

A origem sai do PixelLab, `create_image_pixflux`, `low top-down` (e não `high`:
é o ângulo que mostra topo E frente), `basic shading`, `selective outline`,
`no_background`. Um prop por geração, no tamanho exato da célula.

**A arena do chefe fica com zero volumétricos**, e isso é escolha travada em
teste. Ela é a sala mais densa de projétil do jogo; corpo com face vertical ali
é o que a LTD 10 manda dosar e o que o GDD proíbe encostar num telegrafo. O
tipo declara as regiões mesmo assim, para quem experimentar não ter de procurar
quais servem.

### 8.6.1 Props chapados

Todos 32×32, na margem, teto `B5`.

| prop | desenho |
|---|---|
| **corrida de cano** | tubo `B4` de 32×6 com topo `B5` e sombra `B3`, atravessando a célula de lado a lado — pensado para ladrilhar com o vizinho |
| **ar-condicionado** | caixa `B4` 20×16 com grelha de 5 ripas `B3`, aresta `B5`, duto de 4 px |
| **persiana** | 24×20 de ripas alternando `B3`/`B4` a cada 2 px, trilho `B5` nas laterais |
| **respiro de parede** | 16×16 de lâminas `B3` em `B4`, moldura `B5` |

---

## 9. O atlas: o que congela e o que só cresce

O atlas é 256×128 = 32 células de 32, **26 desenhadas e 6 vazias**. As linhas 0 e
1 são props neutros; as linhas 2 e 3 são o painel de acento e a marcação de chão,
**uma coluna por tipo**.

Cresce para **256×256** (64 células). O único número a mexer é `PROPS_ATLAS`.

> **Congele as linhas 0–3 byte a byte. Só acrescente da linha 4 para baixo.**
>
> Os cinco `.tres` carregam **56 `Rect2i` escritos à mão** em pixel absoluto, e
> **nada verifica que uma região contém pixel opaco**. Uma região apontando para
> célula vazia produz um `Sprite2D` invisível que consome uma vaga de prop, e o
> portão aprova — ele só exige `opacos > 0` na imagem **inteira**. Qualquer
> re-layout obriga a reescrever os 56 rects sem rede.

### A armadilha do `TIPOS`

`TIPOS` faz **duas coisas**: o dispatch de chão/parede **e** o loop das linhas 2 e
3 do atlas — que é exatamente onde mora o acento por tipo.

> **Encolher `TIPOS` para colapsar chão e parede mataria em silêncio os props que
> a decisão de §4.1 elegeu como portadores da identidade.**

São duas listas: `TIPOS` (as 5 rampas de acento, **permanece**) e um catálogo de
piso/parede (vira 1). E a ordem de `TIPOS` continua congelada — ela entra na
semente.

### Outros congelamentos

| congela | porque |
|---|---|
| ordem de `TIPOS` | entra em `SEEDS[...] + i`; mudar re-gera o mundo por nada |
| linhas 0–3 do atlas | 56 `Rect2i` à mão nos `.tres` |
| ordem de sorteio em `_montar_decoracao` | o RNG é um fluxo só: sortear decalque antes dos props **re-rola o layout de todo o andar**. Use fluxo próprio (`hash(coordenadas_grid) ^ constante`) |

---

## 10. Orçamento de luz, traduzido

Os 17,8 / 40,8 / 41,4 da §2 **não transferem direto**: a referência é uma
composição **vertical** — os prédios enchem o quadro. O jogo é planta baixa, e
quem enche o quadro é o **chão**.

A faixa de parede ocupa ~10% da tela quando visível, e frequentemente 0% (a
câmera só a mostra quando o jogador anda até a borda).

| | referência | andar 1 |
|---|---|---|
| gamut de ATOR | 17,8% | **0%** — regra dura |
| penumbra (V 0,30–0,55) | 40,8% | ~10%, a faixa de parede |
| escuro (V ≤ 0,30) | 41,4% | ~90%, o chão |
| acento não-azul | 2,4% | **2–3%** — o único que transfere |

O que a referência distribui entre prédios e rua, o jogo concentra: **o chão
carrega quase o quadro inteiro sozinho.** Por isso ele não pode ser chapado — e
também não pode ser claro. A saída, de novo, é composição.

---

## 11. Chegada: o que é dado, o que é código, o que prova

| Passo | Onde | Prova |
|---|---|---|
| `B0`–`B5` em `paleta.gd` | dado | G2 já cobre; falta teto de V (§12) |
| Reescrever `gerar_chao`/`gerar_parede`/`gerar_porta_moldura` | dado | G1 + determinismo |
| Separar `TIPOS` do catálogo de piso | dado | §9 — nada cobre; ver §12 |
| Atlas para 256×256 | dado | dimensão e `encloses` já cobrem |
| 5 `.tres` → o mesmo par de PNGs | dado | `textura_* != null` já cobre |
| **Apagar os 8 PNGs órfãos** | dado | nada cobre — o portão só percorre `nomes()` |
| `TEXTURA_PADRAO` em `sala.gd` | **código** | nada cobre; ver §12 |
| Duas constantes de `corredor.gd` | **código** | idem |
| Amostrador de decalque | **código** | — |
| `regioes_decalques` / `quantidade_decalques` | **código** | asserção análoga à de props |
| Nó `Decalques` no índice 2 | **código** | — |
| Decoração de corredor | **código** | — |

### Um modo de falha silencioso que vale conhecer

Se a textura de fallback sumir sem `TEXTURA_PADRAO` ser ajustada, `_textura()`
devolve `null`, `_texturizar()` cai em `COR_CHAO_EMERGENCIA` e **a sala fica
lisa** — sem erro no console. Nenhuma suíte cobre isso: `teste_grade.gd` nunca
faz `add_child`, então `_ready` não roda, e o teste de fumaça não toca em textura.

Pior: quando a textura da **parede** é null, o fallback pinta
`COR_CHAO_EMERGENCIA`, que é cor de **chão**. Parede quebrada vira chão.

---

## 12. As travas que faltam

Nomeadas, porque "verificação" sem lista é intenção:

| trava | por quê |
|---|---|
| **teto de V sobre todo `ambiente()`** | hoje só existe uma asserção que olha `N7` pelo nome. Um dessaturado com V 0,90 passa nos três portões |
| **teto de V por família** | chão em `B1`–`B3`, parede em `B4`–`B5`, decalque em `B0`–`B2`. Nada impede um `B5` no meio do chão |
| **densidade por textura** | 10–15% no chão, 20–30% na parede. Uma parede de volta a 59% passa calada em todos os portões |
| **toda região do atlas tem pixel opaco** | região em célula vazia consome vaga de prop e é invisível |
| **`TEXTURA_PADRAO` e as constantes do corredor resolvem** | o modo de falha de §11 |
| **os 5 `cor_mapa` são mutuamente distinguíveis** | a decisão de §4.1 pôs todo o peso neles, e hoje só se cobra `alpha > 0` |
| **forma de decalque** | recusar componente conexo aproximadamente circular e menor que 24 px |

### Comandos

```bash
GODOT="/c/Users/alcyn/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path . tools/texturas/gerar_texturas.tscn   # regera os PNGs
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . tools/testes/runner.tscn
"$GODOT" --path . tools/capturar.tscn --resolution 960x544
```

**Todo commit que mexe no gerador tem de rodar o `.tscn` e commitar os PNGs
juntos** — o portão de determinismo compara byte a byte com o disco.

E a conferência que nenhum teste substitui: **olhar a captura.** Textura é coisa
que só se julga vendo.

---

## 13. Migração

- **As 9 capturas de `docs/capturas/` ficam obsoletas no mesmo commit.** E o
  `IDENTIDADE_VISUAL.md` faz delas o critério de aceite ("o projétil continua tão
  fácil de achar quanto em `07_sala_de_combate.png`?"), o que torna o critério
  autorreferente. Pior: `capturar.gd` nomeia por tipo (`08_sala_de_arma`,
  `09_sala_de_item`) — com chão e parede iguais, três das nove viram
  quase-duplicatas e param de provar qualquer coisa. **O conjunto tem de mudar**
  para provar o que é novo: identidade por prop, e o orçamento de luz.
- **`default_clear_color`** é `#05060B` = `N0` exato, garantido só por prosa. Se
  `B0` `#000112` vira o mais escuro, o **vazio entre salas fica mais claro e
  menos azul que o pixel mais escuro do chão** — inversão exata da referência.
  Some a isso `stretch/aspect="expand"`: monitor largo mostra mais vazio.
- **Os 8 PNGs órfãos** (`chao_*`/`parede_*` das variantes que somem) têm de ser
  apagados explicitamente. O portão só percorre `nomes()` e não vê arquivo a
  mais.
- **`GEMINI.md` linhas 110 e 149** citam "filete por tipo", removido no commit
  `73e31c0`. `CLAUDE.md` declara `GEMINI.md` fonte única de contexto, então linha
  morta ali é pior que em `docs/`.

---

## Apêndice: como refazer as medições

Tudo sai de `assets/bg_menu.jpg` e de `assets/texturas/*.png` com Python e PIL.

| medição | recorte |
|---|---|
| imagem inteira | — |
| rua | `(380, 600) – (1000, 768)` |
| fachada | `(1120, 340) – (1376, 700)` |

- **Paleta dominante:** `Image.quantize(colors=N, method=MEDIANCUT)`, `Counter`
  sobre os pixels, cada cor para HSV com `colorsys`.
- **Orçamento de luz:** classificar por `S > 0,35 and V > 0,55` (ator),
  `V ≤ 0,30` (escuro), resto (penumbra).
- **Matiz do neon:** histograma de `H` em faixas de 15°, restrito ao gamut de ator.
- **Tamanho de elemento:** máscara `S > 0,35 and V > 0,70`, componentes conexos
  por busca em largura com vizinhança-4, descartando os de menos de 6 px.
- **Grade nativa:** somar `|diff|` entre colunas (e linhas) vizinhas e comparar a
  média nos índices múltiplos de `p` contra a média geral, `p` de 1 a 12. Nenhum
  passou de 1,06× — daí a conclusão de que não há grade.
- **Densidade:** fração de pixels cuja soma de diferença absoluta de canal contra
  o vizinho à direita **ou** abaixo passa de 24.

Medido em 2026-08-25 contra `bg_menu.jpg` (1376×768) e as 13 texturas de
`assets/texturas/`. Se alguma for regerada, **remeça** — não confie na tabela.

---

## 13. A onda 3 — o piso deixa de ser quase preto

O §2.4 fechou dizendo *"o chão tile em 12,7% está certo"*. Medido de novo, com o
funil já no lugar, os quatro chãos do andar 1 estavam em **0,8% a 4,3%** de
densidade — abaixo até da faixa 8–18% que o próprio `preparar_textura.py`
declara para a família. E a luminância média era **12,6** (a pior, `_b`, dava
8,2) contra os **42,8** que a metade de baixo do `bg_menu.jpg` mede.

O piso não estava calibrado; estava apagado. A queixa que abriu esta onda foi
estética ("não ficou no esperado"), e a régua confirmou.

### 13.1 O que mudou

Três referências autorais de placa metálica entraram no lugar das quatro
variantes anteriores (`chao_andar1_d` foi apagado). O que as diferencia é a
**escala do painel**, e não o brilho nem o matiz — é a leitura de "quatro
variações da mesma noite" do §4.1, mantida:

| arquivo | o que distingue |
|---|---|
| `chao_andar1_a` | painel grande, simétrico, dreno de canto |
| `chao_andar1_b` | retalho de placas pequenas irregulares, mais acento |
| `chao_andar1_c` | painel largo com calha, poucos elementos |

Exposição em `--alvo-v 0.16` (contra o default 0,12 da família). Resultado
medido nas três: luminância **26 a 29**, densidade **9,0% a 10,9%** — dentro da
faixa, e pela primeira vez.

### 13.2 A faixa de matiz do andar 1 alargou: 200–250 → 185–320

As referências trazem acento ciano (~180°) e magenta (~320°). A faixa antiga
grampeava os dois em azul: o acento sobrevivia como brilho e perdia o
vocabulário que motivou a escolha da arte.

Alargar é seguro, e a razão está no §2.2 deste mesmo documento: **o andar 1 já
tinha abandonado a separação por matiz** ao ir para o azul, que é a família de
seis projéteis do jogo. Quem separa mapa de ator é o **valor** — teto de 0,30 no
chão contra o piso de 0,55 do portão G2 — e esse teto **não mudou**. Medido nos
três arquivos: `compete = 0` e nenhum pixel acima do teto.

O que a faixa separa é **tipo de sala**, e isso se preserva: 185 fica 5° acima
do teto do item (180) e 320 fica 10° abaixo do piso do chefe (330). As quatro
faixas seguem disjuntas.

Na tela, a separação medida numa sala de combate cheia: o projétil inimigo pica
em 125 de luminância contra 57 no percentil 99 do piso — **2,2×**. O critério de
aceite do `IDENTIDADE_VISUAL.md` ("um projétil inimigo continua tão fácil de
achar quanto antes dela") se sustenta pelo valor, exatamente como previsto.

### 13.3 O preço, e ele é real: a moldura enfraqueceu

A parede do andar 1 não mudou (luminância 37–45). Com o chão saindo de ~12 para
~28, a razão parede/chão caiu de **~3,5× para ~1,5×** (medido em captura: 1,54×
na variante `a`, 1,36× na `b`).

A parede continua vencendo, e nas capturas ela ainda lê como moldura — mas essa
folga era generosa e agora é justa. **Ela é a única coisa que diz onde a sala
termina** desde que o filete de neon saiu, então é o número a vigiar no próximo
playtest.

Se precisar recuperar, há dois botões, nesta ordem de preferência:

1. **Subir a parede do andar 1** de V 0,30 para ~0,38. A família permite até
   0,50, então há folga, e mexe só em `parede_andar1_*` — as salas especiais
   têm par próprio e a razão interna delas não muda.
2. Baixar `--alvo-v` do chão para 0,14 (chão ~24, razão ~1,7×). Desfaz parte do
   que esta onda foi feita para resolver, então é o segundo botão e não o
   primeiro.

### 13.4 Duas ferramentas novas no funil

`preparar_textura.py` ganhou um **pré-passo**, desligado por default — o funil
continua sendo rede de segurança, e o pré-passo é o contrário dela: ele
acrescenta o que a arte não trouxe.

- `--desvinheta` — chapa a iluminação global. Arte gerada vem com centro aceso e
  cantos apagados, e em ladrilho isso vira uma **cruz escura** repetida pela
  sala inteira.
- `--tingir GRAUS` com `--limiar-neon S` e `--saturacao S` — crava o matiz do
  **metal apagado** na noite azul e deixa o **pixel aceso passar intacto**. O
  limiar é a peça inteira: levantar saturação em tudo pintaria também o ruído
  quase-cinza, cujo matiz é só arredondamento, e o piso viraria confete.
- `--grampear-matiz LO HI` — grampeia na origem, com folga maior que os 3° de
  `MARGEM_MATIZ`. Com acento muito saturado os 3° não bastam: medido, a
  referência simétrica saía em 180–322 contra uma faixa de 185–320.
- `--alvo-v V` — sobrescreve a mediana de valor da família naquela chamada.
