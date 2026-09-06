# Briefing — as paredes viram uma fábrica abandonada

O andar 1 é uma fábrica abandonada e a parede não diz isso. Ela diz "metal
escuro estriado", que serve a qualquer cenário. Este documento é o pedido de
arte: o que encomendar, com que números, e o que cada peça tem de passar antes
de entrar em disco.

Ele existe porque **arte de parede aqui não é livre**. Ela é consumida por um
renderizador com regras próprias e cobrada por sete portões. Um briefing que
ignore isso produz arte bonita que o funil recusa — e aí a tentação é afrouxar a
régua, que é como uma família de textura já se perdeu.

---

## 1. Onde a arte entra

A parede **não é tileset**. `RenderizadorParedes` monta faixas contínuas de
`Polygon2D`, uma por banda por lado, com `texture_repeat` e a **UV ancorada no
canto do contorno da sala**. É isso que faz a textura atravessar as quinas sem
emenda, e é isso que impõe a restrição mais importante deste briefing.

Cada lado, do contorno para fora:

```
    contorno
    |<-- face 56 px -->|<-- topo 40 px -->|   vazio
```

Igual nos quatro lados. Sobre isso o **código** desenha a linha de contato
(2 px), a costura (32), o lábio (1) e o bisel (2) — nada disso é arte, e nada
disso deve ser desenhado dentro do tile.

### A restrição que decide o desenho

**O tile é usado com wrap nos dois eixos e deslocamento arbitrário.** A face
mostra uma janela de 56 px de um tile de 64, e *qual* janela depende de onde a
sala está no andar.

> Nenhuma linha ou coluna pode ser especial. Não existe "o topo do tile", não
> existe linha de base, não existe rodapé. Se a peça só funciona numa posição,
> ela vai aparecer errada em metade das salas.

### Quem sorteia o quê

- **O topo é sorteado uma vez por SALA.** Ele é a superfície contínua que dá a
  volta e atravessa as quinas. As três variantes têm de ser o **mesmo
  material** — sortear entre materiais diferentes põe uma sala de metal ao lado
  de uma de pedra, que é o defeito de hoje.
- **A face é sorteada uma vez por LADO.** É ela que carrega identidade, e a
  variedade entre lados e entre salas é o que a biblioteca existe para produzir.

---

## 2. O estado de hoje, medido

| textura | orientação | densidade | V mediana | amplitude | matiz |
|---|---|---|---|---|---|
| `parede_topo_a` (placas 2×2) | −0,012 | 57,3% | 0,298 | 1,29 | 228 |
| `parede_topo_b` (**alvenaria**) | −0,116 | 62,2% | 0,298 | 1,40 | 228 |
| `parede_topo_c` (painel vertical) | +0,100 | 71,5% | 0,298 | 1,13 | 228 |
| `parede_face_combate` | +0,731 | 42,5% | 0,200 | 0,59 | 200 |
| `..._tubulacao` | +0,873 | 76,1% | 0,200 | 1,41 | 198 |
| `..._tecnica` | +0,504 | 73,1% | 0,200 | 0,78 | 201 |
| `..._deteriorada` | +0,831 | 50,0% | 0,200 | 1,16 | 201 |
| `..._ventilada` | +0,794 | 41,5% | 0,204 | 1,17 | 198 |

**Três problemas, e dois são regressões.**

1. **Os três topos são três MATERIAIS.** Chapa rebitada, alvenaria de tijolo e
   painel vertical. A alvenaria não pertence a uma fábrica.
2. **Os cinco módulos de face colapsaram num só.** Ao corrigir a dívida da
   uniformidade eles ficaram todos verticais, no mesmo matiz e no mesmo valor —
   `comum`, `tubulacao`, `deteriorada` e `ventilada` viraram a mesma chapa
   corrugada. Só a `tecnica` ainda se distingue.
3. **Falta o substantivo.** Não há tubulação com válvula, bandeja de cabos,
   chapa arrancada, corrosão descendo de junta, mancha de óleo, número
   estampado nem grade entupida. O vocabulário atual não nomeia nada.

---

## 3. O que cada peça tem de passar

Tudo abaixo é cobrado por portão. A régua não se move para a arte caber.

| | exigência | quem cobra |
|---|---|---|
| tamanho | 64×64, ladrilhável, alfa binário, grade múltipla de 16 | `teste_texturas` |
| valor | mediana **0,30** no topo, **0,20** na face | `teste_profundidade` |
| sequência | topo > face > piso (0,122), passo ≥ **0,036** | `teste_profundidade` |
| amplitude | **≥ 0,58** — `(p90 − p10) / mediana` | `teste_texturas` |
| paleta | **nenhum** pixel com `s > 0,35 ∧ v > 0,55`; teto de valor 0,50 | `teste_texturas` |
| matiz | por tipo: andar1 **185–320**, chefe 330–355, arma 25–50, item 150–180 | `teste_texturas` |
| costura | **≤ 1,10** | `teste_texturas` |
| orientação (face) | **≥ 0,20** vertical, e ≥ 0,15 acima do chão | `teste_profundidade` |
| densidade | 18–34% é a faixa da família — **informativa** | `preparar_textura` |

**A paleta é a que mais recusa arte**, e é a que o gerador mais viola: qualquer
pixel saturado e claro reprova, porque essa faixa é exclusiva de ator. Por isso
a geração vai com **paleta forçada**, tirada da própria `parede_face.png`, que já
é o gamut aprovado.

---

## 4. A receita, peça a peça

Gerar **grande** e reduzir no funil. Gerar direto em 64 enche cada pixel de
detalhe — medido: 55–61% de densidade contra 24–31% quando reduzido de 256.

```bash
# 1. a paleta forcada, uma vez
python - <<'PY'
import base64, io
from PIL import Image
im = Image.open("assets/texturas/parede_face.png").convert("RGB")
cores = sorted({im.getpixel((x, y)) for y in range(im.height) for x in range(im.width)})
p = Image.new("RGB", (len(cores), 1))
for i, c in enumerate(cores):
    p.putpixel((i, 0), c)
b = io.BytesIO(); p.resize((len(cores), 32), Image.NEAREST).save(b, "PNG")
print(base64.b64encode(b.getvalue()).decode())
PY

# 2. gerar em 256x256 no PixelLab (parametros na secao 5)

# 3. o funil, uma vez por TIPO de sala
python tools/texturas/preparar_textura.py preparar \
    fonte.png assets/texturas/parede_face_combate_<modulo>.png \
    --familia parede --tipo andar1 --lado 64 --sem-costura \
    --alvo-v 0.200 --tingir 200 --limiar-neon 1.0 --saturacao 0.39
```

### As duas armadilhas do funil, já pagas

- **`--limiar-neon` tem de ir a 1,0.** No default de 0,30 ele trata metade dos
  pixels como "acento aceso" e não os tinge: pedir matiz 232 devolve 198.
  Material de parede não tem neon.
- **`--sem-costura` só para arte que já ladrilha.** Arte gerada não ladrilha; sem
  a bandeira o funil costura e o preço é um borrão na junção. Com nervura
  vertical periódica a costura horizontal medida fica em 0,08 e a bandeira pode
  ser usada — mas **meça antes**, não assuma.

### O tingimento por tipo

Uma geração por módulo, na rampa neutra, e quatro saídas pelo `--tingir`:

| tipo | `--tingir` | `--tipo` |
|---|---|---|
| neutra (`parede_face.png`) | 232 | `andar1` |
| combate | 200 | `andar1` |
| inicial | 200 | `andar1` |
| arma | 37 | `arma` |
| item | 176 | `item` |
| chefe | 337 | `boss` |

---

## 5. O pedido

Parâmetros comuns a todas as chamadas do `create_image_pixflux`:

```
width 256, height 256
view "side"            (a face é vista de frente; o topo, de cima)
shading "medium shading"
outline "lineless"     (é material, não sprite: contorno criaria arestas falsas)
detail "medium detail"
no_background false
text_guidance_scale 11
color_image_base64 <a paleta da secao 4>
```

### Os três TOPOS — um material só, três desgastes

O topo é visto **de cima**. Ele não carrega identidade e não pode competir com a
face: é espessura. As três variantes mudam o **desgaste**, nunca o material.

| arquivo | pedido |
|---|---|
| `parede_topo_a` | *industrial steel checker plate floor seen from directly above, raised diamond tread pattern, bolt heads at the panel corners, clean and intact* |
| `parede_topo_b` | *industrial steel checker plate seen from directly above, one panel replaced by a crudely welded patch with visible weld beads, mismatched tread* |
| `parede_topo_c` | *industrial steel checker plate seen from directly above, corroded and pitted, the tread worn smooth in patches, small rust holes eaten through* |

Use `view "high top-down"` nos três.

### As cinco FACES — cada uma com um substantivo

A face é vista **de frente** e tem de ler **vertical** (orientação ≥ 0,20) numa
janela de 56 px. O substantivo tem de sobreviver a essa altura: peça poucas
formas grandes, não muitas pequenas.

| módulo | pedido |
|---|---|
| `comum` | *flat riveted steel wall panels seen straight on, tall vertical seams between the panels, long rust streaks bleeding down from each bolt line, no horizontal beams* |
| `tubulacao` | *thick vertical pipes running floor to ceiling seen straight on, a heavy valve wheel and a bolted flange on the largest pipe, deep shadow gaps between the pipes, no horizontal beams* |
| `tecnica` | *vertical cable trays bolted to a steel wall seen straight on, dense bundles of cables running down inside them, small junction boxes, no horizontal beams* |
| `deteriorada` | *a steel wall with one panel torn away seen straight on, exposing vertical structural ribs and hanging cables behind it, peeling paint in vertical strips, no horizontal beams* |
| `ventilada` | *a tall exhaust louver grille seen straight on, upright blades side by side clogged with grime, dark slots between the blades, a bent blade near one edge, no horizontal beams* |

E os dois exclusivos do chefe:

| módulo | pedido |
|---|---|
| `motor` | *rows of tall upright hydraulic rams seen straight on, chrome rods inside dark cylinder housings, oil stains running down, no horizontal beams* |
| `energia` | *vertical copper bus bars on insulator columns seen straight on, thick cables clamped alongside, scorch marks around the clamps, no horizontal beams* |

**"no horizontal beams" em todas** — é o que produz a orientação vertical, e
cinco reformulações mostraram que sem essa frase o gerador desenha travessas.

### O que NÃO pedir

- Palavra de energia ou luz ("glowing", "charged", "energy"): vira efeito
  desenhado fora da paleta. Já aconteceu com ator.
- Cena: "no door, no floor, no ceiling" quando o prompt puxar para ambiente —
  uma das gerações anteriores devolveu uma porta em vez de uma parede.
- Alvenaria, pedra, tijolo. É uma fábrica.

---

## 6. O portão que falta, e que esta encomenda torna necessário

Hoje nada impede que cinco módulos de face sejam a mesma imagem — foi
exatamente o que aconteceu. **Antes de commitar a arte nova, entra um portão de
distinguibilidade**, no mesmo desenho do que os projéteis já usam:

> Dois módulos de face do mesmo tipo não podem ser indistinguíveis. A comparação
> é sobre a estrutura (densidade e orientação), não sobre a cor — eles são
> tingidos no mesmo matiz de propósito, então comparar cor não separaria nada.

Sem ele, a próxima rodada de arte pode voltar a colapsar a biblioteca sem que
nenhum teste acuse.

## 7. Limpeza que vem junto

`modulo_canto_no/ne/so/se` — quatro PNGs de 64×64 que o `EstiloDeParede` ainda
carrega e passa ao renderizador, e que **nada desenha** desde que a quina virou
meia-esquadria. Saem com esta encomenda.

---

## Verificação

```bash
python tools/texturas/preparar_textura.py conferir assets/texturas/ --familia parede
godot --headless --path . tools/testes/runner.tscn        # tem de imprimir PASSOU
godot --path . tools/formas_paredes.tscn --resolution 960x544
godot --path . tools/comparar_norte.tscn --resolution 960x544
godot --path . tools/medir_moldura.tscn --resolution 960x544
```

Peça que não passe nos portões é **descartada**, não é acomodada. Foi assim que
duas artes de projétil foram jogadas fora nesta mesma semana, e é o que impede a
régua de virar carimbo.
