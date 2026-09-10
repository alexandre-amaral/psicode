# A biblioteca de prompts da fabrica -- andar 1

`[FAB 20]` do epico #302. Secoes 43 e 44 do briefing.

Este arquivo existe para a geracao ser **reproduzivel**: quando uma peca voltar
errada, a pergunta tem de ser "o prompt esta escrito assim, o que nele produziu
isso?" e nao "o que eu digitei da outra vez?". Prompt novo entra aqui ANTES de
consumir geracao, e prompt que produziu peca aprovada nao se reescreve por
gosto -- ele e o que faz a variante seguinte combinar com a que ja esta em
disco.

> **A issue de identidade vem antes.** `docs/CONVENCOES.md` exige uma issue pelo
> gabarito `.github/ISSUE_TEMPLATE/arte.md` antes do primeiro pixel. Este
> arquivo diz COMO pedir; ele nao substitui a decisao do QUE pedir.

---

## 1. O prompt base

Ele entra em toda peca de cenario do andar 1, com o bloco da familia colado
depois. E o que faz 60 pecas geradas em semanas diferentes parecerem a mesma
fabrica.

```
pixel art abandoned cyberpunk factory prop, low top-down squared perspective,
dark dirty blue-gray industrial steel, heavy used machinery, worn paint,
rust around bolts and edges, oil stains, old functional industrial technology,
visible top surface and front face, upper-left lighting, restrained warm amber
work lights, subtle cold blue ambient shadows, compact readable silhouette,
game-ready isolated asset, transparent background, no text, no character,
no scenery, no clean futuristic design, no bright green,
no loose cables, no hanging wires, no hoses, no rubber tubing
```

Tres pedacos dele nao sao decoracao e nao saem:

- **`visible top surface and front face`** e a camera do projeto
  (`docs/LOW_TOPDOWN_SQUARED.md`). Sem isso volta arte de lado ou isometrica, e
  arte de FACE nao pode ser girada para caber -- girar face destroi a
  perspectiva, e a secao 28 daquele documento e a decisao inteira.
- **`upper-left lighting`** e o acordo de luz de todo o resto do jogo. Peca com
  a luz vindo de outro canto nao se conserta no funil: espelhar em x REFLETE
  onde girar TRANSPOE, e a sombra vai para o lado errado.
- **`no bright green`** e a correcao medida do briefing. O verde nunca foi do
  andar todo -- eram seis texturas, e as seis eram a sala de item --, mas o
  gerador puxa para verde-industrial sozinho quando se pede "factory".

---

## 2. As tres licoes ja pagas, que todo prompt carrega

Elas nao sao estilo. Cada uma custou geracao jogada fora.

**1. Palavra de ENERGIA vira efeito desenhado.** `"exploding into a charge"` no
chefe produziu literalmente uma estrela de explosao amarela cobrindo o sprite, e
jatos de chama numa das direcoes -- fora da paleta e diferente em cada direcao.
Um prompt de cenario descreve **materia**: chapa, solda, rebite, ferrugem,
mancha. Luz so entra como `unlit`, `dark`, `dead bulb`, `powered down`.

**2. Palavra de FUNCAO vira outro objeto.** `"grupo de gatilho com solenoide"`
devolveu uma pistola inteira. O gerador desenha o que a frase sugere, nao o que
ela pede -- e a negacao explicita foi a unica coisa que resolveu:
`"there is no gun, no barrel, no grip, only the trigger part"`. Toda familia
abaixo tem a linha `NAO:` por isso.

**3. `no_background` do PixelLab NAO devolve alfa.** As 16 pecas de icone
voltaram **100% opacas**, com o fundo chapado em DOIS tons quase iguais (medido:
73,6% de um e 26,4% de outro, a 9 de distancia). Quem recorta e
`tools/itens/preparar_icone.py`, por **preenchimento a partir da borda** com
tolerancia 24 -- nunca por cor, senao um fundo cinza abre buraco dentro de uma
peca de aco da mesma familia. Fundo CERCADO pelo desenho e furo, e sai so com
`--vazar-furos`, peca a peca.

---

## 3. Parametros de geracao

| | |
|---|---|
| Ferramenta | `mcp__pixellab__create_map_object` / `create_1_direction_object` |
| Modo | `v3` com descricao propria. **Nunca template com esqueleto**: ele prende a silhueta e deformou o chefe (bbox de 130 px virou 67) |
| Tamanho de saida | 128 ou 256 no master; o jogo consome 32 a 96 |
| Fundo | pedir transparente e **conferir**; ver a licao 3 |
| Master | versionado em `tools/art_sources/fabrica/<familia>/<nome>.png` |

**O master se guarda no tamanho grande.** Textura autorada se gera GRANDE e se
reduz no funil: as mesmas ideias em 64x64 sairam com 55% a 61% de densidade
contra a faixa de 18-34% da parede; em 256 reduzidas pelo BOX do funil, 24% a
31%. E master com alfa nao se reprocessa pelo chaveamento de fundo -- a segunda
passada leria o RGB dos pixels transparentes, que e preto, e comeria o contorno.

---

## 4. O funil, por porte

A arte crua **nao entra no jogo**. Ela passa por `preparar_textura.py`, que e
quem poe a peca na paleta do andar e responde o portao de gamut.

```bash
# volume (HERO, GRANDE, MEDIO, PEQUENO): a peca que vai para o atlas de props
python tools/texturas/preparar_textura.py preparar ORIGEM PRONTO.png --familia prop --tamanho 64x64 --sem-costura --grudar-na-fonte

# decalque (DECALQUE, MICRO): chao pintado
python tools/texturas/preparar_textura.py preparar ORIGEM PRONTO.png --familia decalque --tamanho 64x32 --alvo-v 0.055 --compressao-v 0.30
```

E ela **nunca e escrita direto no atlas**: quem cola e
`tools/texturas/colar_no_atlas.py`, que cresce o arquivo para baixo, ancora o
recorte no fundo da celula e imprime as regioes para os `tipo_*.tres`.

Dois numeros do decalque nao sao gosto. Com o default da familia ele sai com
luma mediana **0,080** contra **0,079** do `chao_andar1_a`: ele nao fica mais
claro que o chao, fica EXATAMENTE em cima dele, e some. O que faz a peca ler e
separar para BAIXO -- `--alvo-v 0.055` poe o p90 dela abaixo do p10 do chao, e
ela vira silhueta escura, que e como uma marcacao gasta se ve. No chao do CHEFE,
que e mais escuro (p10 0,042), o alvo desce junto.

**Prop novo passa pelo funil SOZINHO, e nao junto do atlas inteiro.** O funil
processa a imagem toda: rodar no atlas completo mexeria no valor e na saturacao
de todos os props ja aprovados. Prepare a tira nova, e so entao cole -- e o
atlas CRESCE para baixo, nunca se recompoe, porque as regioes ja declaradas nos
`tipo_*.tres` sao coordenadas cruas.

---

## 4.1 Os tres numeros que o Batch 1 mediu

Eles nao estavam no plano e sairam da primeira leva de arte gerada. Valem para
todas as levas seguintes.

**1. Reduzir INVENTA cor, e prop e arte paletizada.** O tanque veio 128x128 com
60 cores e saiu 64x64 com **467** -- contra as 358 do atlas inteiro que ele ia
acompanhar. E a mesma armadilha que `gerar_projeteis.py` ja paga desde a arte de
projetil. `--grudar-na-fonte` devolve cada pixel a cor mais proxima da FONTE
depois da reducao: as 467 viraram **71**.

**2. A peca chega com a cor do gerador, e o funil nao gira matiz sozinho.** A
familia `prop` esta em `SEM_FAIXA_DE_MATIZ`, entao nada clampa o matiz dela --
medido, o tanque chegou em **186 graus (ciano)** e a caixa em **28 (laranja)**.
Quem resolve e `--tingir 228 --saturacao 0.40 --limiar-neon 0.9`, que poe a peca
no mesmo lugar do atlas existente (H 230 / S 0,42 medidos). O `--limiar-neon`
alto e o ponto: com o default de 0,30 os aneis vermelhos do tubo sobrevivem ao
tingimento e a peca sai sendo a unica quente da leva.

**3. Ela tambem chega CENTRADA na propria tela, e o vazio vai para o chao.** O
`teste_props.gd` cobra que a arte encoste no fundo da celula (sobra maxima de 1
px), porque a `Sala` trata a base da regiao como o ponto de contato. Colada
inteira, o tanque sobrava 3 px e a bancada 6 -- os dois flutuando, sem erro
nenhum. `colar_no_atlas.py` recorta no alfa e ancora o RECORTE.

**4. A peca chega na proporcao da TELA, e nao na da celula.** Isso e diferente
do item 3: aquele e sobre o vazio em volta, este e sobre a FORMA. `--tamanho
LARGURAxALTURA` reduz para o retangulo pedido, e reduzir nao preserva proporcao
-- uma peca gerada em 96x128 (3:4) empurrada para uma celula 64x64 sai 33% mais
gorda, e nenhum portao ve: ela continua na paleta, na grade e ancorada. So fica
errada. Quem resolve e `tools/texturas/enquadrar_prop.py`, que recorta no alfa e
emoldura na proporcao da celula ANTES do funil, ancorando no fundo.

Os comandos exatos do Batch 1, para a proxima leva copiar:

```bash
COMUM="--familia prop --sem-costura --grudar-na-fonte --tingir 228 --saturacao 0.40 --limiar-neon 0.9"

python tools/texturas/enquadrar_prop.py tools/art_sources/fabrica/tanques/tanque_pressao.png ENQ/tanque.png 64x64
python tools/texturas/preparar_textura.py preparar ENQ/tanque.png PRONTO/tanque.png $COMUM --tamanho 64x64

python tools/texturas/colar_no_atlas.py assets/texturas/props_volume.png PRONTO/tanque.png@64x64 PRONTO/barril.png@32x64
```

O decalque leva o mesmo tingimento, com a familia e os alvos dele:

```bash
python tools/texturas/preparar_textura.py preparar ORIGEM DESTINO --familia decalque --sem-costura --grudar-na-fonte --tamanho 64x32 --tingir 225 --saturacao 0.25 --limiar-neon 0.9 --alvo-v 0.055 --compressao-v 0.30
```

Sem o `--tingir` ali a mancha reprovou o matiz por **cinco graus** (achado
180-320 contra a faixa 185-320): o realce azulado que o gerador desenhou nela,
mesmo depois de escurecida, ainda apontava para o ciano.

---

## 4.2 O BLOCO DE ENQUADRAMENTO, que veio do retorno do dono

As tres primeiras levas sairam em `view: low top-down` sem instrucao de
enquadramento, e o retorno foi direto: *"os angulos e a disposicao estao muito
desconexos... as assets so parecem moveis em outra resolucao jogados nos cantos
do mapa... a maioria flutua sobre o chao"*.

**A causa e que cada peca vinha com a propria rotacao de tres quartos.** O
gerador desenha o objeto girado, com uma face lateral visivel e a base em
LOSANGO -- e a sala e desenhada em face mais topo, sem face lateral, sobre uma
grade reta. Base em losango sobre grade reta le como flutuando, por mais que a
arte encoste no fundo da celula (e ela encosta: `teste_props.gd` cobra isso).

O bloco abaixo entra em TODA peca de volume, antes da descricao do objeto:

```
IMPORTANT FRAMING: the object faces the camera squarely, seen from directly in
front, with only a shallow band of its flat top surface visible above it. There
is no three-quarter rotation, no side face, no isometric angle, no diamond-shaped
base. Its base is a straight horizontal line resting flat on the ground.
THE OBJECT: <descricao>
```

`view` continua `low top-down`: **a comparacao foi feita**. O mesmo tanque saiu
com o bloco em `low top-down` e em `side`, e os dois ficaram frontais -- o
primeiro com a base mais reta e a banda de topo mais rasa, que e o que assenta a
peca. O que resolve e o BLOCO, e nao o parametro.

> **CORRIGIDO na 4.4, e a conclusao acima so vale para peca RADIALMENTE
> SIMETRICA.** Um tanque nao tem "frente"; um motor tem. Refeito com um motor
> deitado, `low top-down` devolveu isometrico COM o bloco inteiro no prompt --
> e o painel eletrico plano, na mesma leva, veio de quina com face lateral
> visivel. **Para peca alongada, o parametro manda e o bloco nao alcanca.** Seis
> geracoes foram gastas provando isso.

E ele explica por que as pecas de PAREDE ja tinham saido bem: elas pediam
`flat frontal elevation view` desde a primeira geracao.

**A ROBUSTEZ nao vem de peca maior.** A faixa entre a parede e a area de combate
mede 96 px, e celula mais larga que isso invade o jogo. Na referencia quase nada
e uma peca so: o volume vem de tres ou quatro encostadas, e quem monta isso e o
cluster do `DecoradorDeSala` -- que a `Sala` passou a chamar no mesmo retorno.

---

## 4.3 A ESCALA, e o bloco que tem de vir POR ULTIMO

Segundo retorno do dono, depois da primeira leva frontal: os assets estavam
"muito pequenos nas salas, um armario menor do que o proprio jogador, maquinas e
esteiras muito pequenas", sem "sensacao de pertencimento ao lugar ou de
proporcionalidade".

**O que limitava o tamanho era uma REGRA, e nao a arte.** `posicoes()` testava a
pegada da peca contra a `area_spawn` como um QUADRADO de lado igual a largura:
um armario de 96 px reservava 96x96 de piso e, com a folga de meio prop contra a
parede, nao cabia na faixa de 96 -- a saida tinha sido encolher a peca ate ela
ficar menor que o jogador (80 px de moldura). Hoje a pegada e
`DecoradorDeSala.pegada_no_chao()`, larga e RASA: o que nao pode invadir o
combate e o chao que a peca ocupa, e a altura desenhada cresce para cima da
tela, atras de todo mundo.

Com a regra corrigida, o prompt ganha a linha de escala:

```
SCALE: this is a huge piece of factory machinery, more than twice the height of
a standing person, filling the frame from top to bottom.
```

**E o bloco de enquadramento passa a vir DEPOIS da descricao do objeto, nao
antes.** Isso nao e arrumacao: com a linha de escala inserida antes dele, o
armario e a esteira voltaram ISOMETRICOS na mesma leva em que o vaso saiu
frontal. Reescritos com o enquadramento por ultimo e em voz imperativa
(`CRITICAL FRAMING, THIS OVERRIDES EVERYTHING ELSE`), os tres sairam frontais.
E a licao 2 da secao 2 outra vez: o gerador segue o que a frase sugere, e o que
vem por ultimo pesa mais.

Tamanhos de celula que a escala nova usa:

| porte | celula | contra o jogador (80 px) |
|---|---|---|
| HERO | 96x160 | 2,0x |
| GRANDE | 64x128 | 1,6x |
| MEDIO | 64x96 ou 96x96 | 1,2x |
| PEQUENO | 32x64 | 0,8x |

A esteira entra em 96x96 e nao em 96x64: o portao do atlas volumetrico cobra
"prop com volume sobe, nao deita", e a regra continua certa -- ela existe para
impedir prop CHAPADO declarado como volume. A celula quadrada acomoda a maquina
larga sem desfazer isso.

**E o fundo opaco voltou.** `transparent background` no prompt nao garante alfa
-- medido na MESMA leva, o armario voltou com alfa e o vaso sem.
`enquadrar_prop.py` ganhou o chaveamento por preenchimento a partir da borda, o
mesmo de `preparar_icone.py` e com a mesma tolerancia medida (24). Imagem que ja
tem alfa passa intacta: reprocessar leria o RGB dos pixels transparentes, que e
preto, e comeria o contorno.

---

## 4.4 A ORIENTACAO, que e a terceira correcao do dono e a mais dura

Terceiro retorno, olhando as salas montadas:

> *"para as geracoes usar a orientacao 180 grau, reta, norte-sul ou leste-oeste
> para que caiba encostado na parede na maioria das vezes -- so assim a gente se
> aproxima mais da inspiracao e do objetivo do visual"*

**Ela e mais forte que o bloco de enquadramento da 4.2, e nao a repeticao dele.**
Aquele bloco resolveu a PERSPECTIVA -- a peca deixou de vir girada de tres
quartos com a base em losango. Este resolve o EIXO: a peca tem de ter **costas
retas** e o comprimento correndo **paralelo a parede**, senao ela nao encosta.

O contato do pool de combate mostra a diferenca sem regua: as quatro pecas do
regime v3 (vaso, armario, esteira, tanque) tem costas planas e assentam contra o
muro; as **nove restantes -- motor, bomba, engradado, barril, painel, compressor
-- vieram todas na diagonal**. Um motor desenhado em angulo nao encosta em parede
nenhuma: ele fica com uma quina para dentro da sala e um vao atras.

E isso vale duas vezes desde a `[FAB 47]`, porque a peca agora TEM COLISAO e a
`Sala` monta BANCADAS. Peca diagonal encostada numa vizinha reta produz um vao
que o solido nao preenche, e o jogador ve dois moveis que nao se tocam.

O bloco entra POR ULTIMO, depois da descricao e depois da linha de escala -- a
ordem da 4.3 continua valendo, e pelo mesmo motivo medido: o que vem por ultimo
pesa mais.

### O que de fato resolve: `view: side`

O bloco de prompt sozinho **nao alcanca** uma peca alongada. Medido na mesma
leva: com `view: low top-down` e o bloco inteiro, o motor voltou isometrico com a
base em losango e o painel plano voltou de quina. Trocado so o parametro para
`side` -- mesma descricao, mesmo bloco --, o motor saiu com eixo reto
leste-oeste, costas planas e a base numa linha horizontal.

Faz sentido com o que ja estava escrito: as pecas de PAREDE (a 5.1) sairam bem
desde a primeira geracao **porque pediam `flat frontal elevation view`**, e a
porta paga a mesma distincao entre face autorada e vista de cima. O que faltava
era estender isso a peca de chao que precisa encostar.

**Receita:** `view: side`, `flat frontal elevation` na linha de estilo do prompt
base, e o bloco abaixo POR ULTIMO.

```
CRITICAL ORIENTATION, THIS OVERRIDES EVERYTHING ELSE: this is a flat straight-on
front elevation, like a technical drawing seen from directly in front. The object
is perfectly axis-aligned, square to the camera, its long axis running straight
left-to-right across the frame. Its back is a single flat vertical plane that
could sit flush against a wall. There is NO three-quarter rotation, NO diagonal or
corner angle, NO isometric projection, NO diamond-shaped base, NO visible side
face. The base is one straight horizontal line resting flat on the ground.
```

Para peca de conjunto (fileira de tambores, cilindros num rack) acrescente a
negativa que impede a profundidade: `NO drum placed behind another`. Sem ela o
gerador enfileira para o fundo e a base volta a ser um losango.

**E o que o eixo NAO pode ser:** nada de peca em "L", nada de conjunto montado em
quina, nada de tubo saindo pela frente na diagonal. Se a peca precisa de um cano,
ele sai reto para os lados ou para cima -- e de preferencia ele nem vem no asset,
porque a conexao e peca separada (`[FAB 22]`, e ver a linha `no loose cables`
abaixo).

---

## 5. Os blocos por familia

Cada bloco entra DEPOIS do prompt base. `NAO:` e a licao 2 aplicada -- ela nao e
opcional.

### 5.1 Tubulacao -- `[FAB 22]`, porte `PAREDE`

```
industrial pipe running along a wall, welded flanges and bolted brackets,
peeling paint over bare steel, rust bleeding from the joints,
horizontal run seen from above with the front face visible
NAO: no floor, no ground shadow, no character, no valve wheel unless asked,
no glowing indicator, no clean chrome
```

Pecas: `pipe_horizontal_01/02`, `pipe_vertical_01/02`, `pipe_corner`,
`pipe_t_junction`, `valve_large`, `valve_small`, `pipe_broken`, `pipe_steam`.
Variantes intacta, enferrujada e remendada.

**Elas ancoram na FACE, e nao no chao.** Sao as primeiras pecas do porte
`PAREDE`, que existe desde o `[FAB 07]` e ate aqui so a luminaria consome. Na
referencia quase nenhum trecho de parede aparece limpo, e sem elas a parede
continua sendo um plano em vez de uma estante. O `pipe_broken` precisa de uma
boca aberta que aponte para fora: e nela que o vapor do `[FAB 16]` se pendura.

### 5.2 Tanques -- `[FAB 23]`, portes `HERO` e `GRANDE`

```
large industrial pressure tank, riveted steel shell, banded reinforcement rings,
heavy support legs bolted to the floor, dented and streaked with rust,
faded stencil markings, seen from above with the front face visible
NAO: no liquid glow, no transparent window, no pipes leaving the frame,
no clean paint, no logo
```

Pecas: `pressure_tank_large`, `pressure_tank_medium`, `reservoir`,
`cylinder_pair`, `damaged_tank`, `leaking_tank`. O hero em 80 a 160 px, o grande
em 64 a 96.

O hero e a peca que responde **"esta sala servia para isto"** a distancia. Ele e
o unico porte que pode ganhar a silhueta da sala inteira, e por isso e um so por
sala.

### 5.3 Eletrica -- `[FAB 24]`

```
industrial electrical cabinet, closed steel door with latch and hinges,
conduit entering from the top, cable bundles clipped to the side,
dead unlit indicator lamps, chipped gray paint, rust at the base
NAO: no lightning, no glow, no sparks, no energy, no screen, no character
```

Pecas: `transformer_large`, `power_box`, `fuse_panel`, `cable_distribution`,
`battery_bank`, `junction_box`, `breaker_panel`.

`dead unlit indicator lamps` e a licao 1 escrita no prompt: a peca precisa de
lampada para ler como painel eletrico, e qualquer palavra de energia ali devolve
brilho fora da paleta.

Esta familia tambem paga uma divida: o par de face do chefe `tecnica|motor` esta
em `MODULOS_COLAPSADOS_DO_CHEFE` de `teste_texturas.gd` medindo 0,2598 contra um
piso de 0,25. **A distancia que falta nele nao esta na cor** -- tres tentativas
por saturacao falharam por medicao. Ele precisa de ESTRUTURA diferente: uma peca
de armario fechado e vertical contra uma de motor exposto e horizontal.

### 5.4 Ventilacao -- `[FAB 25]`

```
industrial wall exhaust unit, bladed fan behind a bolted grille,
sheet metal duct with seam lines, grime caked around the intake,
bent slats on one corner
NAO: no motion blur, no wind lines, no glow, no character
```

Pecas: `fan_large`, `wall_vent`, `exhaust_unit`, `duct_section`, `damaged_vent`,
`floor_grate`.

Duas regras que vem de fora do prompt. O `fan_large` e candidato a `PropAnimado`
-- e ai ele entra no orcamento de `max_props_animados`, que continua em **2 por
sala**, porque movimento no cenario compete com movimento de projetil. E o
`floor_grate` e `DECALQUE`, nao volume: na referencia ha mais de dez grades e
varias caem no centro da sala.

### 5.5 Armazenamento -- `[FAB 26]`

```
stacked industrial storage crate, worn plywood and steel corner brackets,
strapping bands, stenciled numbers half rubbed off, scuffed edges,
seen from above with the front face visible
NAO: no text that reads as words, no logo, no clean cardboard, no character
```

Pecas: `crate_small/medium/large`, `crate_open`, `pallet`, `barrel`,
`barrel_group`, `covered_crate`, `parts_container`.

Sao as pecas mais repetidas do andar, entao a secao 46 vale dobrado: **minimo 3
variantes** de caixa e de barril. Sem isso a densidade que o decorador produz
vira repeticao obvia, e repeticao obvia le como bug de geracao.

### 5.6 Manutencao -- `[FAB 27]`

```
industrial workbench with tools left on top, scratched steel top,
open drawer, parts and rags scattered on the surface, oil stained legs
NAO: no character, no hands, no glowing tool, no clean surface, no empty top
```

Pecas: `workbench`, `tool_cart`, `toolbox`, `small_motor`, `compressor`,
`cable_reel`, `parts_tray`, `dismantled_machine`.

`no empty top` esta ali porque a secao 149 e explicita: **bancada vazia quebra a
ficcao**. E o `dismantled_machine` carrega a frase do andar melhor que qualquer
outra peca -- maquina aberta com peca exposta e "isto foi reparado varias vezes
e depois abandonado".

### 5.7 Decalques -- `[FAB 28]`, porte `DECALQUE`

```
flat floor stain seen straight from above, no volume and no silhouette,
dark oil soaked into concrete, irregular edge, faint spread halo,
low contrast against dark floor
NAO: no object, no shadow, no highlight, no reflection, no bright color,
no outline
```

Pecas: `oil_small/large`, `wet_patch`, `rust_patch`, `scrape_marks`,
`drag_marks`, `small_debris`, `metal_scraps`, `broken_cable`,
`faded_warning_line`.

**A ferrugem e o alvo numerico desta familia.** Depois do retingimento ela caiu
de 13,71% para **0,17%** contra os 3,30% da referencia -- ela media 13,71%
porque o laranja da sala de arma contava como ferrugem, e hoje o andar ficou sem
desgaste quente. Quem devolve isso e ARTE, e nao tinta de ambiente: e
principalmente o `rust_patch` e a oxidacao nas juntas. O `faded_warning_line` e
amarelo **envelhecido**, pouco saturado -- amarelo aceso e paleta de SINAL.

### 5.8 Grades e drenos -- `[FAB 29]`, porte `DECALQUE`

```
recessed floor grate seen straight from above, parallel steel bars in a frame,
dark gaps between the bars, flush with the floor, debris caught in the slots
NAO: no raised edge, no volume, no shadow cast on the floor, no glow
```

Pecas: `floor_grate_small/medium`, `drain`, `cable_channel`,
`maintenance_hatch`.

`no raised edge` e o que as mantem legais dentro da zona livre. Elas sao planas,
escuras e de baixo contraste -- e por isso podem morar no centro, onde volume
nao pode. A referencia tem mais de dez delas, contra as 0 a 4 que o briefing
pede; quem manda e a imagem.

### 5.10 Estacao de modificacao corporal -- `[FAB 33]`, sala de ITEM

```
<peca>, seen from above with the front face visible.
This object is completely powered down: there is no light anywhere on it,
no cyan, no teal, no glow, no lit screen, no indicator lamp.
NAO: no character, no floor, no blood, no medical cross symbol,
no hologram, no glass tube
```

Pecas: `estacao_aumento` (hero, 96x96), `cadeira_aumento`, `scanner_quebrado`,
`bandeja_modulos` (64x64), `armario_modulos`, `capsula_implante`,
`braco_mecanico`, `console_diagnostico`, `feixe_cabos` (32x64).

**A frase "completely powered down" e afirmativa, e ela e o bloco inteiro.** A
primeira geracao do `armario_modulos` levava `no glowing screen, no neon` na
lista de NAO e voltou com uma **tela ciano acesa** -- que e a cor do projetil do
jogador. Reescrita como afirmacao sobre o estado do objeto ("every panel on it
is dark dead grey glass, there is no light anywhere on it"), a mesma peca voltou
apagada. E a licao 2 da secao 2 confirmada de novo: o gerador desenha o que a
frase SUGERE, e uma lista de negacoes sugere aquilo que ela nega.

**E o `no bright green` do prompt base nao basta nesta sala.** O
`scanner_quebrado` voltou TURQUESA -- justamente o defeito que a `[FAB 33]`
existe para nao repetir ("a arquitetura NAO fica verde"). Quem resolveu foi o
funil: com `--tingir 228 --limiar-neon 0.9` as nove pecas mediram **matiz 228 e
ZERO pixels em verde ou teal**. Vale a regra geral: o prompt reduz a chance, o
funil e quem garante.

### 5.11 Oficina e arsenal -- `[FAB 35]`, sala de ARMA

```
<peca>, seen from above with the front face visible.
There is no gun anywhere on this object: no barrel, no rifle, no pistol,
no complete firearm, only loose parts and tools.
This object is completely powered down: there is no light anywhere on it,
no cyan, no teal, no glow.
NAO: no character, no floor, no readable text, no logo
```

Pecas: `bancada_armas` (hero, 64x96), `caixa_municao` (64x64), `suporte_vazio`,
`painel_balistico`, `armario_pecas`, `terminal_calibragem`, `morsa`,
`armario_blindagem` (32x64), mais `capsulas_decalque` no atlas de DECALQUE.

**A negacao de arma e afirmativa, e ela e a issue.** A secao 56 e explicita: arma
pertence ao pickup, e uma arma desenhada no cenario seria lida como coletavel --
o jogador andaria ate ela. E "no gun" numa lista de NAO nao basta, pela mesma
razao medida no armario da sala de item: a lista sugere o que nega. A forma que
funciona e a afirmacao sobre o objeto ("There is no gun anywhere on this
object... only loose parts and tools"), e as oito voltaram limpas na primeira
geracao.

O que carrega a leitura de OFICINA sem arma nenhuma: o painel de ferramentas
vazio atras da bancada, a morsa de mordentes abertos, o suporte com todos os
encaixes vazios e o painel balistico crivado. A sala fala de manutencao, e nao
de vitrine -- que e o segundo aceite.

### 5.12 O posto improvisado -- `[FAB 37]`, a LOJA

```
<peca>, seen from above with the front face visible.
This was never built as a shop, it was assembled from junk by hand.
This object is completely powered down: there is no light anywhere on it,
no cyan, no teal, no glow.
NAO: no character, no floor, no shop sign, no cash register, no readable text
```

Pecas: `balcao_improvisado`, `caixa_sucata`, `pertences`, `lona` (64x64),
`prateleira_improvisada`, `parede_ferramentas`, `banqueta`, `terminal_troca`,
`cesto_sucata` (32x64).

**A frase que carrega a issue e "was never built as a shop".** A fabrica nao foi
construida como loja: o Sucateiro OCUPOU um setor antigo, e sem essa afirmacao o
gerador devolve mobilia de comercio -- balcao acabado, prateleira reta,
registradora. O vocabulario que produz ocupacao e material MISTURADO: chapa
sobre engradado, tabua sobre tijolo, arame segurando o canto, nada esquadrejado.

**Quatro das onze pecas da issue NAO foram geradas, e nao por esquecimento**:
`offer_pad_A/B` e `work_lamp` ja existem em `src/loja/sala_loja.gd` (as tres
bancadas e a luz de trabalho sao geometria da cena, e a `[LOJA 07]` as montou);
gerar arte para elas criaria uma segunda fonte da mesma coisa.

### 5.9 A porta -- `[FAB 30]` e `[FAB 32]`

A porta tem prompt proprio e as restricoes mais duras do arquivo, porque ela e a
unica peca de cenario que ANIMA.

```
heavy industrial blast door seen from the front, two sliding leaves meeting at
the center, thick steel frame with a lintel above and a sill below,
hydraulic rails on both sides, worn paint and rust streaks, dark recess behind
NAO: no glowing panel, no colored force field, no window, no text, no character,
no open doorway showing a room
```

Tres coisas que a arte tem de entregar, e que ja custaram uma reversao inteira:

- **A moldura CERCA o vao nos quatro lados.** Dois blocos com um vao entre eles
  nao sao uma moldura: o olho le "a parede tem um buraco aqui". Quem fecha em
  cima e a verga, embaixo e a soleira.
- **A folha e uma CHAPA, e ela recolhe atras do batente** (`RECUO_DA_FOLHA`, 16
  px num batente de 24). Ela nunca deforma -- escala fora de 1 le como a porta
  sendo esmagada.
- **Nada de campo colorido gigante.** O `porta_campo.png` antigo era a porta
  INTEIRA feita de sinal; hoje a chapa e AMBIENTE e o sinal e so a barra de
  trancada que a atravessa.

---

## 6. Antes de commitar a arte

1. `preparar_textura.py` com a familia certa (secao 4).
2. `godot --headless --path . --import`.
3. `godot --headless --path . tools/testes/runner.tscn` -- `teste_texturas.gd`
   e quem recusa cor que compete com projetil, e ele varre `assets/texturas/`
   inteira: **PNG fora de `AUTORADAS` ou do gerador nao reprova, ele SOME da
   conta**, e foi assim que cinco arquivos passaram sem prova nenhuma.
4. `godot --headless --path . tools/fabrica/laboratorio_decoracao.tscn` para
   ver a composicao, e `tools/capturar.tscn` para ver no enquadramento do jogo.
