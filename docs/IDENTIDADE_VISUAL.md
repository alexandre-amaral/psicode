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
| porta trancada | `#FF3366` sobre `#99203F` | campo de força de 80×32, scanlines |
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
- As texturas de chão e parede têm **128×128** (4×4 tiles) e são *seamless* por
  construção: o ruído é amostrado em coordenada modular, então a borda direita
  continua na esquerda sem retoque. 128 não divide 544, e não precisa: o olho lê
  a sub-grade de 32, e essa está alinhada com todas as bordas.
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

**Porta** (`porta.tscn`): dois `Sprite2D`. `Moldura` (96×48) aparece sempre que
há vão — dois batentes, uma soleira, e a passagem para fora pintada de `N0` (o corredor ainda não revelado é escuridão, não parede).
`Campo` (80×32) é o campo de força, só quando TRANCADA, em SINAL. Porta SELADA
esconde os dois: o vão nem é aberto na parede.

**Corredor** (`corredor.gd`): mesmo chão e mesma parede da variante `combate`,
que é a neutra do andar. As laterais dele são só barreira: quem dá a leitura é
a faixa de parede, igual à das salas.

**Props** (`Decoracao`): `Sprite2D` sem colisão lendo regiões de
`assets/texturas/props_atlas.png`. Quais regiões e quantos, o `tipo_*.tres`
decide. Ficam na margem entre a parede e a `area_spawn`, longe das portas: um
prop no meio do chão, sem colisão, pareceria um obstáculo mentiroso. A seed
vem de `coordenadas_grid`, então reentrar na sala mostra a mesma sala.

Os `@export` de `DadosSala` no grupo **Visual** são o único lugar onde uma
textura é apontada: `textura_chao`, `textura_parede`, `atlas_props`,
`regioes_props`, `quantidade_props`.

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
4. **Sinal é grande.** O menor sinal do jogo é o campo de porta, 80×32.
5. **Telegrafo encurta com a fase, nunca some** (GDD). Uma textura nunca pode
   cobrir um telegrafo: o disco de perigo é `z=0`, acima do chão.
6. **Efeito que atrapalha a leitura é efeito cortado**, por mais bonito que
   seja. O shader de glitch tem `alpha_maximo` por isso.

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
