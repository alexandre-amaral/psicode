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
no scenery, no clean futuristic design, no bright green
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
# volume (HERO, GRANDE, MEDIO, PEQUENO) -- o atlas de props
python tools/texturas/preparar_textura.py ORIGEM assets/texturas/props_volume.png \
    --familia prop --manter-tamanho

# decalque (DECALQUE, MICRO) -- chao pintado
python tools/texturas/preparar_textura.py ORIGEM DESTINO \
    --familia decalque --alvo-v 0.055 --compressao-v 0.30
```

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
