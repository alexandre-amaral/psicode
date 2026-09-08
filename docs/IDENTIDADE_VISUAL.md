# Identidade visual

Referência viva para toda textura, cor e forma que entra no mundo do `psicode`.
O objetivo dela é simples: a próxima textura tem de sair igual às que já
existem **sem ninguém precisar perguntar**. Se uma decisão aqui mudar, mude o
documento e o `tools/texturas/paleta.gd` juntos — o segundo é a versão em código
do primeiro, e os testes leem o código.

**Quando o código e o texto discordarem, o código ganha e o texto se atualiza.**

---

## O mood, em uma frase

Pixel art de **noite azul com neon** — um complexo industrial escuro onde a luz
vem de filetes finos e telas apagadas, não de um sol. A referência de estilo é
`assets/bg_menu.jpg` (o fundo do menu: azul-noite, neon rosa e ciano, pixel art
limpa). As outras imagens em `inspiração/` (`interiores.webp` e o concept de
loja da CD Projekt) são **fotorrealistas** e servem só de mood de iluminação —
que superfície brilha, onde a sombra cai — **não** de estilo.

> **`bg_menu.jpg` foi medida.** A paleta dela, o orçamento de luz, o tamanho do
> elemento aceso e as três coisas que ela faz e o jogo **não deve copiar** estão
> em **`docs/TEXTURAS_ANDAR_1.md`**, junto com as receitas de textura do andar 1.
> Este arquivo aqui continua sendo o vocabulário compartilhado — paleta, portões,
> grade, camadas; aquele é a bíblia de produção de um andar.

O que tira dessa referência: fundo muito escuro e azulado; o brilho é raro e
concentrado; o detalhe é geométrico, não orgânico. O que **não** tira: a
quantidade de neon. Na cidade do menu, neon é decoração; na sala do jogo, neon é
projétil. A regra abaixo existe por isso.

---

## A regra central: três paletas, não uma

Num bullet hell, **cor saturada e clara é linguagem de gameplay**. Ciano
brilhante significa "seu tiro", rosa brilhante significa "tiro do chefe".
Se a parede também pudesse ser ciano brilhante, a linguagem quebrava. Por isso
o jogo não tem uma paleta — tem três, e a regra é sobre a fronteira entre elas.

| Paleta | Quem usa | Regra |
|---|---|---|
| **AMBIENTE** | chão, parede, corredor, props, moldura de porta | dessaturada **ou** escura — nunca as duas coisas brilhantes ao mesmo tempo |
| **ATOR** | player, inimigos, projéteis | saturada **e** clara. Exclusiva: nenhuma cor daqui aparece no ambiente |
| **SINAL** | porta trancada, telegrafo, brilho de pickup | brilhante, mas sempre numa forma grande demais para ser confundida com projétil |

O ambiente é o palco. Ele pode ter identidade — e tem, uma cor por tipo de sala
— mas em intensidade que nunca disputa o olho com o que se move.

### AMBIENTE — neutros (o concreto do complexo)

Oito valores, do vazio ao brilho máximo permitido. `N1` é o exato chão que o
jogo sempre teve; a rampa foi construída em volta dele.

| | Hex | Papel |
|---|---|---|
| N0 | `#05060B` | vazio entre salas, sombra profunda, `clear_color` |
| N1 | `#0B0D16` | chão base |
| N2 | `#12151F` | chão médio (placa alternada) |
| N3 | `#1A1E2B` | placa clara, entulho |
| N4 | `#242A3A` | junta, rejunte, sombra de painel |
| N5 | `#31384C` | metal escuro — o corpo da parede |
| N6 | `#434B63` | metal médio — o topo da parede, borda de caixa |
| N7 | `#5A6480` | aresta iluminada. **Raro.** É o teto do brilho do ambiente |

### AMBIENTE — um acento por tipo de sala

Cada tipo de sala já declarava uma cor no `cor_mapa` do seu `tipo_*.tres`, para
o minimapa. A rampa de acento é essa **mesma cor, rebaixada** em três degraus:
minimapa e mundo falam da mesma cor em intensidades diferentes, e quem vê a
sala rosa no mapa acha a sala rosa no mundo.

| Tipo | `cor_mapa` (só minimapa/UI) | A0 fundo | A1 luz apagada | A2 acento vivo |
|---|---|---|---|---|
| combate | `#4CE5FF` ciano | `#0E2B33` | `#1E5A6B` | `#2A7285` |
| boss | `#FF3366` rosa | `#33101C` | `#6B1F36` | `#8A2A47` |
| arma | `#FFB84A` âmbar | `#332512` | `#6B4D1E` | `#8A6528` |
| item | `#7DF7C4` verde-água | `#0E332A` | `#1E6B57` | `#288A71` |
| inicial | `#BFCCE5` cinza-azul | `#1A1E2B` | `#333B52` | `#48546F` |

**O `cor_mapa` puro nunca é pintado no mundo.** O mundo usa A0–A2.

Por que cada matiz:

- **Combate é ciano** porque é a cor "neutra" do complexo. É o padrão; as
  outras são desvios dele.
- **Boss é rosa** porque o projétil da Diretora é rosa (`tiro_diretora.tres`).
  A sala anuncia o dono antes de ele aparecer — e o rosa rebaixado da parede
  faz o rosa cheio do tiro saltar mais, não menos.
- **Arma é âmbar** porque o pickup de arma e a shotgun são âmbar. Mesma lógica.
- **Item é verde-água** pelo pickup de item.
- **Inicial é cinza-azul**, quase sem saturação: é a sala onde nada acontece,
  e ela não deve chamar por nada.

### ATOR

Não é definida aqui — cada ator carrega a própria cor na cena dele
(`cor_base` nos `inimigo_*.tscn`, `cor_projetil` nos `*.tres` de arma), como
manda a convenção de "número ajustável mora em `.tres`". O que `paleta.gd` tem
é um **espelho** dessas cores, usado só para provar que ambiente e ator não se
cruzam (portão G3). O teste confere que o espelho está em dia; se você trocar
a cor de um inimigo, o teste manda atualizar o espelho.

Regra para uma cor de ator nova: **S > 0,35 e V > 0,55** (HSV). Fora disso ela
some no cenário.

**As armas de personagem ocupam os dois matizes que sobravam.** Os projéteis
inimigos já cobrem vermelho, laranja, azul-claro, água, rosa e roxo; o jogador
tinha ciano (pistola) e âmbar (shotgun). Restavam amarelo e verde:

| | Cor | De quem |
|---|---|---|
| `tiro_mantis` | `#FFED40` | SMG da RAVEN — traçante amarelo |
| `tiro_cipher` | `#73FF4D` | Pistola da NOVA — verde de Hack |

O verde do Cipher é o mesmo `COR_HACK` que tinge o inimigo hackeado, e isso é
deliberado: quem hackeia tem de ser reconhecível no alvo, não só no cano.

**O jogador é a exceção à regra, e de propósito.** RAVEN e NOVA são pixel art
escura e dessaturada — pela regra acima, cenário. O que os mantém achráveis é a
**aura ciano sob os pés** (`Visual/Aura`, `#33D9FF` a 13% de alpha) e o **cano
da arma** (`#8CF7FF`), os dois herdados do visual geométrico anterior. Se um dia
alguém remover a aura para "limpar", a personagem passa a competir em valor com
o chão texturizado: a aura não é enfeite, é a âncora de leitura.

### SINAL

| | Cor | Forma |
|---|---|---|
| porta trancada | `#FF3366` sobre `#99203F` | barra de 32×6 atravessando a abertura |
| telegrafo | `#8CFF73` | disco no chão, com borda |
| pickup de arma | `#FFB84A` | halo pulsando |
| pickup de item | `#7DF7C4` | halo pulsando |

Sinal pode ser tão brilhante quanto ator. O que o separa do ator é o **tamanho e
a forma**: nada de sinal tem raio de projétil.

---

## Os três portões — e como rodá-los

"Número de balanceamento novo tem de nascer medível" vale para cor também. A
suite `tools/testes/teste_texturas.gd` abre cada PNG de `assets/texturas/` e
confere:

- **G1 — gamut.** Todo pixel opaco de textura de ambiente pertence a
  `Paleta.ambiente()` (neutros + as cinco rampas). Nenhum hex fora da lista,
  nem por anti-aliasing.
- **G2 — leitura.** Nenhuma cor de ambiente tem `S > 0,35` **e** `V > 0,55` ao
  mesmo tempo. É a trava que impede o cenário de competir com o projétil.
  `N7` passa de raspão (S = 0,30, V = 0,50) de propósito: é o teto.
- **G3 — separação.** `AMBIENTE ∩ ATOR = ∅`, e todo ator está do lado certo de
  G2 (saturado e claro).

G2 é em saturação/valor e não em luminância porque o vermelho do inimigo
(`#FF3366`) tem luminância 0,38 — *abaixo* de `N7`. Uma trava só de brilho
deixaria o vermelho passar e barraria o cinza.

A mesma suite confere ainda: dimensão múltipla de 16, sem exceção — o filete
era a única textura fora da grade e saiu junto com o neon; alpha só 0 ou 1 (nada de borda semitransparente), toda textura
declarada nos `tipo_*.tres` carrega, e **determinismo** — o gerador rodando
duas vezes produz os mesmos bytes, e o PNG em disco é o que o gerador produz
hoje. Também confere que o espelho `Paleta.ATOR` bate com o `cor_base` de cada
inimigo e o `cor_projetil` de cada arma.

```bash
GODOT="/c/Users/alcyn/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

"$GODOT" --headless --path . tools/texturas/gerar_texturas.tscn   # escreve os PNGs
"$GODOT" --headless --path . --import                             # importa
"$GODOT" --headless --path . tools/testes/runner.tscn             # G1/G2/G3
"$GODOT" --path . tools/capturar.tscn --resolution 960x544        # olhar
```

As capturas cobrem sala inicial, combate, arma, item e as três fases do chefe —
as cinco variantes aparecem todas. O critério que decide se uma textura entra:
**um projétil inimigo continua tão fácil de achar quanto antes dela.** Se não
continuar, o problema é G2 estar frouxo, não a textura.

---

## A grade: 16 de unidade, 32 de tile

- A resolução base é **960×544**, câmera em zoom 1.0. Ambos são múltiplos de 16.
- Toda coordenada de parede, porta e spawn é múltipla de **16**. Toda dimensão
  de sala é múltipla de **32** — as salas são centradas na origem, então o
  contorno guarda a *meia* dimensão, e meia dimensão só cai na grade se a
  inteira for múltipla de 32. `tools/testes/teste_grade.gd` recusa o resto.
- O tile visual é **32 px**: é o que divide 960, 544, 1440, 800, 768 e 960 —
  todas as dimensões de sala. 64 não divide 544.
- As texturas de chão e parede têm **256×256** e ladrilham. O *seamless* já não
  vem de construção: desde que a arte passou a ser autorada, quem devolve a
  garantia é `costurar()` em `tools/texturas/preparar_textura.py`, e quem a
  confere é `medir_costura()`. 256 não divide 544, e não precisa: o olho lê a
  sub-grade de 32, e essa está alinhada com todas as bordas.
- A UV é ancorada no **canto** do retângulo do contorno, nunca no centro. 272
  (meia altura da sala padrão) não é múltiplo de 32; ancorar no centro cortaria
  o tile no meio nas bordas norte e sul.

---

## Como o mundo é montado

Nenhuma cena de sala carrega textura. Tudo nasce em código, no `_ready` de
`sala.gd`, a partir do mesmo `Line2D "Parede"` de onde já nascia a colisão —
sala nova recebe textura de graça, como recebe parede.

```
z=-2  ParedeCorpo  Polygon2D   contorno inflado 24 px para fora (offset_polygon, MITER)
z=-1  Chao         Polygon2D   contorno_local(), textura de chão, UV no canto
z=-1  Decoracao    Node2D      props (Sprite2D do atlas), seed por célula
z= 0  Parede       Line2D      fonte da geometria — invisível em runtime
```

O corpo da parede é o contorno inflado, desenhado **atrás** do chão. O chão
cobre o miolo e sobra uma faixa de 24 px do lado de fora. Isso resolve a sala em
L e qualquer forma côncava futura sem calcular anel com furo.

**Essa faixa de 24 px é o que a câmera mostra além do contorno.** O clamp de
`GerenciadorMapa._clampar()` cresce exatamente `Sala.ESPESSURA_PAREDE`, então a
parede aparece inteira e nem um pixel do vazio que vem depois. Numa sala do
tamanho da tela sobram 24 px de deslize por eixo: a parede entra no quadro
quando o jogador anda até a borda, e não com ele no centro.

**Não há mais filete de neon.** Cada contorno era percorrido por uma linha de
8 px colorida em A2. Ela saiu quando a parede ganhou textura própria: as duas
juntas eram duas bordas desenhadas uma sobre a outra, e como a câmera parava no
contorno era o neon — não a parede — que encostava na beira do quadro. O pilar
e o corredor perderam a mesma borda, pelo mesmo motivo.

**Porta** (`porta.tscn`): cinco `Sprite2D`, e **arte por lado, nunca arte
girada** (PORTA 03 — a decisão está registrada em
`LOW_TOPDOWN_SQUARED.md` §28). `Moldura` (96×128) é o batente e aparece sempre
que há vão; `Vao` é o recesso atrás dela, pintado de `N0` porque o corredor ainda
não revelado é escuridão e não parede; `FolhaA` e `FolhaB` são as duas metades da
chapa que fecha a passagem, só quando TRANCADA; e `Trava` é a **única peça em
SINAL** — uma barra atravessando a abertura. Porta SELADA esconde todas: o vão
nem é aberto na parede.

A moldura muda com o lado, e não com um `rotation`: o norte usa a face autorada
(`porta_moldura.png`), o sul e o leste usam as vistas de cima
(`porta_topo.png`, `porta_lado.png`), e o oeste é o leste **espelhado em x**.
Espelhar reflete; girar destrói a perspectiva.

**Corredor** (`corredor.gd`): mesmo chão e mesma parede da variante `combate`,
que é a neutra do andar. As laterais dele são só barreira: quem dá a leitura é
a faixa de parede, igual à das salas.

**Props** (`Decoracao`): `Sprite2D` sem colisão lendo regiões de
`assets/texturas/props_atlas.png`. Quais regiões e quantos, o `tipo_*.tres`
decide. Ficam na margem entre a parede e a `area_spawn`, longe das portas: um
prop no meio do chão, sem colisão, pareceria um obstáculo mentiroso. A seed
vem de `coordenadas_grid`, então reentrar na sala mostra a mesma sala.

Os `@export` de `DadosSala` no grupo **Visual** são o único lugar onde uma
textura é apontada: `texturas_chao`, `texturas_parede`, `atlas_props`,
`regioes_props`, `quantidade_props`. As duas primeiras são **listas**, e a sala
escolhe a variante por `hash(coordenadas_grid)` — um andar inteiro com o mesmo
par lê como uma sala repetida sete vezes.

---

## Regras de leitura de combate

1. **O chão é quase liso.** Placas `N1`/`N2`, junta `N0`, um grão raro de
   `N3`. Nenhum pixel de acento `A1` no chão em densidade maior que 0,5% —
   o chão é onde o projétil voa.
2. **O acento mora na parede e nos props.** A faixa de 24 px do corpo da parede
   carrega sozinha a identidade da sala, desde que o filete saiu — o que torna
   a regra mais apertada, não menos: era o neon que dizia de que tipo era a
   sala, e agora quem diz é a textura. Uma luz apagada `A1` a cada 32 px
   continua sendo o máximo.
3. **Nada de ambiente tem forma de projétil.** Ponto isolado de `N7` ou `A2`
   com raio de 3 a 6 px é proibido: é exatamente a silhueta de um tiro. Detalhe
   pequeno é sempre linha, junta ou canto — nunca um disco.
4. **Sinal é COMPRIDO, e não grande.** A regra era "o menor sinal do jogo é o
   campo de porta, 80×32", e ela caiu junto com o campo de força (PORTA 01): a
   barra de trancada tem 32×6. O que ela protegia continua de pé e é o item 3 —
   sinal não pode ter silhueta de projétil. Uma barra que atravessa a abertura
   inteira não tem: ela é longa num eixo e fina no outro, que é o oposto de um
   disco. O piso passa a ser esse, e não uma área: **nenhum sinal cabe num
   quadrado**.
5. **Telegrafo encurta com a fase, nunca some** (GDD). Uma textura nunca pode
   cobrir um telegrafo: o disco de perigo é `z=0`, acima do chão.
6. **Efeito que atrapalha a leitura é efeito cortado**, por mais bonito que
   seja. O shader de glitch tem `alpha_maximo` por isso.

---

## A linguagem dos projéteis

Vinte e uma armas desenhavam **o mesmo losango**. Dez dos 210 pares estavam a
menos de 15 graus de matiz um do outro, e dois tinham RGB idêntico
(`rail_x`/`gravity_gun`, `onda_guardiao`/`sucata_guardiao`). Duas armas com a
mesma cor e a mesma forma são a mesma arma.

O que separa hoje é, em ordem de prioridade:
**LEITURA → SILHUETA → HITBOX → COR → ANIMAÇÃO → PARTÍCULAS.**

### As oito famílias de silhueta

Elas moram em `src/util/formas_projetil.gd` — em `src/util/` e **nunca** em
`tools/`, que é excluída do export. `familia_silhueta` no `.tres` da arma
escolhe; `alongamento_silhueta` estica no eixo do voo.

| Família | Desenho | Quem usa |
|---|---|---|
| `LOSANGO` | o de sempre, ponta à frente | `pistola`, `salva_diretora` |
| `CAPSULA` | núcleo aceso, nariz rombudo | `smg_mantis`, `shotgun`, `pistola_cipher`, `tiro_sentinela`, `tiro_vigia` |
| `AGULHA` | longa e fina, perfurante | `rail_x`, `swarm`, `tiro_neon` |
| `ESFERA` | redonda | `boomer`, `plasma_arc`, `volt_caster`, `tiro_drone`, `tiro_diretora` |
| `ORBE` | núcleo denso com anel | `gravity_gun` |
| `CLUSTER` | pedaços soltos, por `Polygon2D.polygons` | `nanite_rifle`, `sucata_guardiao` |
| `ETEREO` | contorno vazado | `phase_blaster` |
| `ARCO` | crescente, atravessa tudo | `onda_guardiao` |

Duas invariantes que a biblioteca inteira respeita: o contorno **contém
`(0, ±raio)`** e **`max|y| ≤ raio`**. O eixo do voo é livre — é de lado que o
jogador esquiva, e é lá que a silhueta não pode mentir.

### O terceiro regime de paleta: ATOR

O documento descrevia AMBIENTE contra ATOR como uma regra de *cor*. Há um
regime **medido por pixel**, e ele é o **inverso exato** do de ambiente:

| | AMBIENTE (`_regra_de_gamut`) | ATOR (`_regra_de_ator`) |
|---|---|---|
| pixels que competem | **zero** | **≥ 70% do miolo** |
| o que se mede | a imagem inteira | o **miolo**, não o sprite |

São funções irmãs e quatro das cinco asserções invertem — uma bandeira faria a
mesma função afirmar duas coisas opostas.

**Mede o miolo e não o sprite inteiro**, e isso não é detalhe: pixel art tem
contorno escuro, e cobrar brilho do contorno é proibir contorno. Miolo é o pixel
cujos quatro vizinhos são opacos.

### As molduras

A **lateral** sai do raio; o **comprimento** é livre. A colisão é um círculo de
`raio`, e o portão de coerência só amarra o eixo lateral.

A arte ancora no **CENTRO do bbox**, que é a inversão exata do funil de ator —
lá `Direcoes.BASE_NO_QUADRO` põe os pés 36 px abaixo da origem. Um projétil que
herde aquela âncora desenha 36 px acima de onde fere, sem uma linha no console.

### A exceção de giro, escrita ao lado da regra

A seção 28 do `LOW_TOPDOWN_SQUARED.md` proíbe girar arte de **FACE**: ela é
desenhada para ser vista de frente, e girada 90 graus a perspectiva morre. É a
regra da porta.

**Projétil é outra coisa, e gira.** Ele voa acima do chão e é visto de cima —
é arte de **TOPO**, como `porta_topo.png`, que o projeto já gira. O runtime faz
`rotation = velocidade.angle()` sessenta vezes por segundo.

As duas varreduras nunca se cruzam. E `flip_h`/`flip_v` continuam proibidos nos
dois: **espelhar REFLETE onde girar TRANSPÕE.**

### Onde a arte autorada para, e por quê

Seis armas têm arte; catorze desenham o polígono **por decisão medida**. O
critério é o **miolo**, e a separação não tem caso no meio:

```
gravity_gun 206   onda_guardiao 144   tiro_vigia     91
tiro_diretora 88  boomer         75   salva_diretora 67
-------------------------------------------- MIOLO_MINIMO = 64
tiro_drone     54   sucata_guardiao 12
```

Abaixo do corte a arte é um borrão e o polígono — exato, já cobrado por dois
portões — lê melhor. `tiro_drone` sai um disco cortado; `sucata_guardiao`, um
CLUSTER feito de pedaços soltos, vira poeira.

### A receita, para quando a próxima arte for feita

1. **Paleta forçada com TODOS os degraus competindo** (s > 0,35 e v > 0,55). Com
   um degrau escuro o gerador o usa para *sombrear*, e num sprite de 16 px o
   sombreado ocupa quase todo o miolo: a fonte nasce em 15% contra o piso de 70%.
   Não é a redução que derruba — a fonte já nasce assim.
2. Gerar **grande** e reduzir no funil. `gerar_projeteis.py` reduz e depois
   **gruda na paleta da fonte**: o BOX medeia cor, e a média entre o contorno e o
   corpo é uma cor que a fonte não tem.
3. **`--comprimento=N`**, com o número que `FormasProjetil` mede para aquela arma.
   O aspecto **não se obtém por prompt** — cinco reformulações deram bbox entre
   3:1 e 8:1 onde o alvo era 2:1.
4. **Nunca** passe projétil por `preparar_textura.py`. Aquele funil empurra a arte
   para o regime de AMBIENTE: dessatura, chapa o valor e grampeia o matiz —
   produz exatamente o arquivo que o regime de ATOR recusa, e o nome convida ao
   erro.

### O rastro e o impacto

`rastro_comprimento` nasce **zero, e zero desliga**. Cravado em
`maxf(raio * 6, 16)` ele reprovava `rastro * raio < velocidade / cadencia` em três
armas: `onda_guardiao` desenhava 96 px de trilha sobre um vão de 26. Trilha maior
que o vão vira um risco sólido e o jogador perde a **contagem** de projéteis.

`familia_impacto` escolhe entre os nove perfis de `src/fx/impactos.gd`.
`Impactos.vestir()` roda **antes** do `add_child`, ao contrário da convenção da
casa: o `_ready` de `fx_autodestroi.gd` liga a emissão e agenda a liberação com o
`lifetime` daquele instante.

### O feixe é a exceção, e ele também não mente

`FEIXE` não instancia projétil: ele se desenha e o dano sai de uma consulta da
`Arma`. Ela tem a **largura desenhada** — antes era uma linha de espessura zero
sob um traço de 6 px, e um alvo encostado na borda não levava dano nenhum.

O desenho para na fração **segura** do `cast_motion`; a pergunta de *quem* é
feita na **insegura**. Perguntando na segura, `intersect_shape` volta vazia justo
no frame do acerto.

## O regime de ÍCONE

Ícone é a quarta situação de arte do projeto, ao lado de ambiente, ator e sinal
— e ele não é nenhuma das três. Ele desenha **no chão** junto do pickup, **na
bancada** da Loja e **na bandeja** da HUD, e em nenhum desses lugares ele pode
virar tiro nem sumir no piso.

Este é o padrão que uma peça segue quando o pedido não declarou identidade.

### As seis linhas do regime

| | |
|---|---|
| **Corpo** | Aço gasto da mesma fábrica: chanfro, rebite, cantoneira, parafuso. As peças de um andar são hardware de um fabricante só, e é isso que faz o conjunto ler como conjunto |
| **Cor** | O acento é a `cor` do `.tres` (`cor_projetil` numa arma), **dominante o bastante para ler a 16 px**. A arte obedece ao dado, porque o pickup e a HUD já leem aquele campo |
| **Vista** | 3/4 de cima, a mesma do jogo. Vista frontal chapada some ao lado das peças que têm volume |
| **Fundo** | Transparente, sem chão e sem sombra projetada |
| **Âncora** | O **CENTRO**. Arte de ator ancora nos pés; um ícone que herdasse aquela âncora desenha deslocado dentro do slot, sem uma linha no console |
| **Tamanho** | Master de 256, entregue de 64. Arte se gera **grande** e se reduz no funil — gerar direto no tamanho final enche cada pixel de detalhe |

### Os números que o portão cobra

Medidos, não escolhidos. `tools/itens/laboratorio_icones.tscn` mede **todas as
peças de todas as famílias na mesma matriz** — item e arma dividem as três
bancadas da Loja, e é ali que dois ícones viram a mesma mancha.

| Medida | Valor | De onde sai |
|---|---|---|
| Lado medido | **16 px** | O menor tamanho que o jogo desenha (a bandeja da HUD). 16 domina 32 nos dois eixos: célula maior borra silhueta e faz média de cinza sobre mais pixels |
| Silhueta | IoU < **0,70** entre dois quaisquer | Medição: as formas que o projeto aceita como diferentes caem entre 0,24 e 0,63; o par idêntico dá 1,00 |
| Cinza | separação ≥ **0,046** | O degrau mediano da rampa `Paleta.NEUTROS`, calculado em runtime |
| Valor do miolo | entre **0,30 e 0,55** | Piso: o teto de valor do chão, para o ícone não afundar no piso de luma 14–16. Teto: `Paleta.LIMITE_VALOR`, o piso de ator, para o ícone não ler como projétil |
| Competição | ≤ **70%** do miolo | Gêmeo invertido de `PISO_COMPETE`: lá é piso para o projétil ler como tiro, aqui é teto para o ícone não virar um |

Um par **colide** quando falha em silhueta **E** em cinza — a leitura literal de
*"duas armas com a mesma cor e a mesma forma são a mesma arma"*. Falhar num eixo
só é `atenção`: não reprova, mas é onde a próxima peça vai encostar.

### O caminho, ponta a ponta

1. **A issue**, com a identidade — ver
   [CONVENCOES.md](CONVENCOES.md#arte-nova-arma-item-ou-cosmético).
2. **Gerar a 256** com fundo transparente. O prompt descreve o **objeto**;
   palavra de função ou de energia vira efeito desenhado.
3. **Passar pelo funil**: `python tools/itens/preparar_icone.py <id> <png>`
   (`--familia arma` para arma). Ele recorta o fundo, assenta o valor, reduz por
   vizinho mais próximo e gruda na paleta da fonte. Ele **só escurece** — peça
   escura demais se redesenha, não se clareia.
4. **Apontar do `.tres`**: `icone` em `DadosItem` ou `DadosArma`, com o caminho
   casando com o id por construção.
5. **Medir**: `godot --headless --path . tools/itens/laboratorio_icones.tscn`.
   Peça que colide se **redesenha**; não se alarga o teto.
6. **Olhar**: o mesmo comando com janela desenha a folha inteira sobre `N0` e
   `N1`, nos três tamanhos de leitura.

### As duas coisas que não se fazem

**Família nova ganha pasta nova.** O portão de órfão é por pasta: todo PNG de
`assets/itens/` precisa de um implante que o aponte, então um ícone de arma ali
reprovaria — com razão. O que **não** se separa é a medição.

**Master versionado não se reprocessa como fonte crua.** Ele já sai do funil com
alfa; uma segunda passada leria o RGB dos pixels transparentes (preto) e comeria
todo contorno escuro encostado na borda. O funil tem guarda para isso, e é ela
que sustenta `refazer_icones.py --lado 48` sem uma geração nova.

---

## Como adicionar uma textura nova

Este é o roteiro que mantém o documento vivo. Não pule o passo 1.

1. **Decida a paleta antes do pixel.** É ambiente, ator ou sinal? Se for
   ambiente, todas as cores vêm de `Paleta.NEUTROS` e `Paleta.ACENTOS[tipo]`.
   Se precisar de uma cor que não existe, adicione em `paleta.gd` **e** na
   tabela deste documento, e rode a suite: G2 vai dizer se ela é brilhante
   demais.
2. **Escreva o gerador**, não o PNG. Em `tools/texturas/gerar_texturas.gd`,
   crie uma `static func gerar_<nome>(...) -> Image` ao lado das que existem.
   Use o `RandomNumberGenerator` local com a seed fixa da tabela `SEEDS` —
   nunca `randi()` global. Amostre ruído em coordenada modular
   (`x % largura`, `y % altura`) para a textura ser seamless por construção.
   Dimensão múltipla de 16. Alpha só 0 ou 1.
3. **Registre em `CATALOGO`** no mesmo arquivo, com o nome do arquivo de saída.
   É essa lista que o gerador percorre e que o teste de determinismo lê.
4. **Gere e importe**: os dois primeiros comandos da seção de portões.
   Commite o `.png`, o `.png.import` e — se houver — o `.uid`. O LFS já está
   configurado para `*.png`.
5. **Aponte a textura** de onde ela é usada. Textura de sala vai no grupo
   Visual do `tipo_*.tres`. Textura de prop vai no `props_atlas.png` e a região
   entra em `regioes_props` do tipo que pode usá-la. Não invente `@export` novo
   em `sala.gd` para isso.
6. **Rode os quatro portões.** `runner.tscn` tem de passar, `teste_fumaca` tem
   de imprimir PASSOU, e as capturas têm de ser olhadas — a de combate e as do
   chefe antes das outras.
7. **Olhe a captura com a pergunta certa:** "o projétil inimigo continua tão
   fácil de achar quanto em `docs/capturas/07_sala_de_combate.png`?" Se a
   resposta hesitar, a textura não entra ainda.

Tipo de sala novo segue o mesmo caminho, mais uma linha na tabela de acentos:
escolha o matiz pelo que a sala **entrega** (o pickup, o chefe, o perigo), e
rebaixe o `cor_mapa` em três degraus mantendo S alta e V ≤ 0,55.

---

## Onde está cada coisa

| O quê | Onde |
|---|---|
| As cores, em código | `tools/texturas/paleta.gd` |
| O gerador e o catálogo de texturas | `tools/texturas/gerar_texturas.gd` (+ `.tscn` que o roda) |
| Os PNGs gerados | `assets/texturas/` |
| Os portões | `tools/testes/teste_texturas.gd` |
| Qual textura cada tipo de sala usa | grupo Visual em `src/mapa/tipo_*.tres` |
| Montagem das camadas na sala | `src/mapa/sala.gd` (`_montar_visual`, `_montar_decoracao`) |
| Porta (moldura e campo) | `src/mapa/porta.tscn`, `src/mapa/porta.gd` |
| Corredor | `src/mapa/corredor.gd` |
| O vazio entre salas | `default_clear_color` em `project.godot` (= N0) |
| Cor do minimapa | `cor_mapa` em `src/mapa/tipo_*.tres` — não muda com a textura |
| Os ícones de loot | `assets/itens/` (implante) e `assets/armas/` (arma); masters em `tools/art_sources/` |
| O funil de ícone | `tools/itens/preparar_icone.py`, e `refazer_icones.py` para a leva inteira |
| A régua de ícone | `tools/itens/laboratorio_icones.tscn` — mede as duas famílias na mesma matriz |
| O portão de ícone | `tools/testes/teste_icones_de_item.gd` (`IconesDeLoot`) |
