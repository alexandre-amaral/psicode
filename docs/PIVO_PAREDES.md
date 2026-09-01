# Pivô das paredes — o levantamento por trás do épico

> Filha da issue **[PAREDE 01]**, e ela não escreve uma linha de `src/`.
>
> O `Plano de substituição do sistema de paredes` foi escrito contra o `sala.gd`
> de **antes** da migração Low Top-Down. Ele descreve `ParedeCorpo` inflado
> 24 px, e isso não existe mais desde a LTD 08. Este documento mede o que existe
> hoje, para o épico atacar o que falta em vez do que já foi feito — e toma as
> três decisões que precedem qualquer código.

---

## 1. O que o plano pede e o código já faz

| Plano | Estado medido |
|---|---|
| §1 parede de 24 px, só borda | `ParedeTopo` inflado **64 px** (`ESPESSURA_PAREDE`) mais `ParedeFace` de **32 px** (`ALTURA_FACE`) |
| §5 topo ≈ 32, face ≈ 32, razão 1:1 | **satisfeito.** A face cobre os 32 px internos da faixa de 64 e o topo os 32 externos |
| §6 norte é a parede principal | **implementado.** `LIMIAR_LADO_NORTE = -0.5` |
| §8 parede sul só com topo | **implementado**, pelo mesmo limiar |
| §25 camada de foreground | **existe.** `Z_FRENTE = 10`, consumida por `_montar_props_frente()` |
| §40 colisão só na base | **implementado.** `SegmentShape2D` sobre a linha do contorno |
| §27 clamp preso aos 24 px | deriva de `Sala.ESPESSURA_PAREDE` (64), travado por `teste_camera.gd` |
| §10 não mexer no tamanho lógico | nada mexeu, e nada deve mexer neste épico |

**Metade do plano já está em disco.** O que ele chama de novidade — dar altura à
parede — está feito. O que falta é outra coisa, e a seção 3 mede.

---

## 2. As nove formas de sala, medidas

Contorno lido do `Line2D "Parede"` de cada cena. `face` conta os lados cuja
normal externa passa em `LIMIAR_LADO_NORTE`; `módulos` é o perímetro dividido
pelo tile visual de 32.

| Cena | Lados | Com face | Portas | Perímetro | Módulos de 32 |
|---|---:|---:|---:|---:|---:|
| `sala_1_retangular` | 4 | 1 | 4 | 3008 | 94 |
| `sala_2_l_shape` | 6 | 1 | 2 | 3008 | 94 |
| `sala_3_grande` | 4 | 1 | 4 | 4480 | 140 |
| `sala_4_corredor` | 4 | 1 | 2 | 3456 | 108 |
| `sala_5_pilar` | 4 | 1 | 4 | 3840 | 120 |
| `sala_6_boss` | 4 | 1 | 1 | 3008 | 94 |
| `sala_7_arma` | 4 | 1 | 4 | 3008 | 94 |
| `sala_8_item` | 4 | 1 | 4 | 3008 | 94 |
| `sala_9_inicial` | 4 | 1 | 4 | 3008 | 94 |

Três leituras saem daí:

**Toda sala tem exatamente UM lado com face.** Inclusive a em L, que tem seis
lados — os outros cinco apontam para leste, oeste ou sul. A face é 32 px de um
perímetro de 3008: **1% do contorno tem desenho vertical**, o resto é topo.

**Em área é ainda mais desequilibrado.** Na `sala_1`, a faixa de parede ocupa
1088×672 − 960×544 = **208 896 px²**, e a face ocupa 960×32 menos o vão da porta
= **28 160 px²**. A face é **13,5% da faixa**; os outros 86,5% são topo liso.

**A fita de módulos tem tamanho conhecido.** 94 módulos numa sala comum, 140 na
maior. Isso é o orçamento da #PAREDE04: não é uma textura, são cerca de cem
sprites por sala.

---

## 3. O que de fato falta

1. **Módulo, e não textura contínua.** Cada lado é hoje um `Polygon2D` com
   `texture_repeat` ligado e UV em pixels ancorada no canto do contorno. Não
   existe "o terceiro ladrilho": existe uma textura esticada. Não há onde
   pendurar um ventilador.
2. **Leste e oeste não têm face nenhuma.** Medido acima: nenhum lado E/O passa
   pelo limiar em nenhuma das nove formas.
3. **Não existem cantos.** O topo é `_inflar(contorno, 64)`, que resolve quina
   por geometria — e por isso nenhuma quina tem desenho.
4. **A porta é desenhada por cima.** A face já abre no vão desde a PAR 01, mas o
   topo passa reto (de propósito: há verga) e a moldura é um sprite solto.
5. **A identidade do andar está espalhada** em listas de textura dentro de cada
   `tipo_*.tres`.

---

## 4. Decisão 1 — a parede NÃO sobe acima de `Z_MUNDO`

§26 propõe `WallUpper z 10` e `Foreground z 20`.

**Recusado, e a faixa atual fica.** `Z_MUNDO = 0` é onde vivem telégrafo,
projétil e ator, e o projeto já tem três decisões registradas defendendo essa
faixa: o prop animado mora em `Z_CHAO_DETALHE` justamente para "animação de
cenário não cobre telégrafo" ser uma garantia **geométrica** e não uma intenção;
o efeito de fase do chefe desenha em `Z_EFEITO = -1` com teto de alpha pela mesma
razão; e o filete de neon foi removido quando virou a coisa mais brilhante
encostando na beira do quadro.

O próprio §25 diz que o foreground "deve ser raro" — e ele **já existe**:
`Z_FRENTE = 10`, usado por viga, tubulação e cabo suspenso, com a regra escrita
em `DadosSala`. Parede é arquitetura e fica embaixo; o caso raro que cobre o ator
continua sendo prop de frente, e não parede.

Faixa que vale para o épico inteiro:

```
Z_PAREDE_TOPO   -22
Z_CHAO          -20
Z_CHAO_DETALHE  -18
Z_PAREDE_FACE   -14
Z_MUNDO           0     telégrafo, projétil, ator
Z_FRENTE         10     o "raro" de §25
```

---

## 5. Decisão 2 — §28 é impossível hoje, e a margem por lado não o salva

§28 quer a moldura permanentemente visível. §10 proíbe mexer no tamanho lógico
das salas. **Os dois não fecham**, e a conta é curta:

```
contorno   960 × 544
faixa      +64 de cada lado
clamp     1088 × 672
tela       960 × 544
sobra      128 px de deslize por eixo
```

Com o jogador no centro, o quadro é exatamente o contorno: **nenhuma parede
aparece.** Ela entra quando ele anda até a borda.

Três saídas foram consideradas:

- **Zoom.** Enquadrar 1088×672 numa tela de 960×544 pede 0,88×. O projeto exige
  escala de pixel art **inteira** — 64→96 borra mesmo com filtro Nearest. Fora.
- **Margem por lado** (§27, e é a #PAREDE10). Norte 64, sul e laterais 32, já que
  lá só há topo. O clamp cai para 1024×640 e o deslize para 64×96 — **melhora,
  mas não zera**. Continua sem parede no centro.
- **Geometria.** Salas de 928×512 com faixa de 16 fecham 960×544 exato. É a única
  que resolve, e é a que §10 proíbe agora.

**Decisão: aceitar que a parede entra em quadro na borda**, adotar a margem por
lado na #PAREDE10 porque ela é correta por si (a assimetria de §8 vira número), e
**registrar a mudança geométrica como candidata fora deste épico** — ela mexe em
área jogável, spawn e balanceamento, e misturar redesign visual com mudança de
gameplay é exatamente o que §10 manda evitar.

---

## 6. Decisão 3 — módulo de parede é família nova no funil

`preparar_textura.py` mede **costura** em toda família que não seja `prop`, e
módulo de parede **não ladrilha consigo mesmo**: ele encosta no vizinho. Medir
costura nele seria cobrar continuidade entre a borda direita e a esquerda do
mesmo desenho, que nunca se tocam.

A saída óbvia — declarar módulo como `prop` — **está errada**, e por um motivo
concreto: `prop` está em `SEM_FAIXA_DE_MATIZ`, porque existe um atlas de props
para o jogo inteiro e amarrá-lo à faixa de um tipo pintaria a mesma caixa de
vermelho no chefe e de âmbar na sala de arma. Mas a parede **carrega o acento do
tipo de sala** (§33) — ela é justamente a superfície que diz de que sala se
trata. Ela precisa da faixa de matiz.

**Decisão: família `parede_modulo`**, com o teto de valor e o alvo da família
`parede` (0,50 e 0,30), a faixa de matiz do tipo, e **fora** da medição de
costura. A lista de quem não ladrilha vira nomeada nos dois lados —
`NAO_LADRILHAM` em `teste_texturas.gd` e a gêmea em `preparar_textura.py` —, pelo
mesmo motivo que `MATIZ_POR_TIPO` já é gêmeo: mudar num só deixa o funil
escrevendo o que o portão recusa.

---

## 7. A promessa do §20 do `LOW_TOPDOWN_SQUARED.md`

O documento diz:

> A parede sul recebe só o topo (32 px); a face é desenhada apenas ao norte **e
> nas pontas sul de leste/oeste**.

A segunda metade **nunca foi implementada**, e a medição da seção 2 prova:
nenhuma sala tem mais de um lado com face. Ela não foi esquecida por acaso —
`_montar_faces()` decide por lado inteiro, e "ponta sul de um lado leste" não é
um lado, é uma **quina**.

**Decisão: a promessa continua valendo e muda de dono.** Ela deixa de ser um caso
especial de face e passa a ser `corner_SW` / `corner_SE` na #PAREDE06 — que é
exatamente o que §20 do plano descreve ao pedir cantos inferiores fazendo a
transição entre lateral alta e parede sul baixa. Enquanto a #PAREDE06 não
acontecer, o texto do `LOW_TOPDOWN_SQUARED.md` está descrevendo o futuro, e isso
fica anotado lá.

---

## 8. O que este documento NÃO decide

- Quantos módulos por família, e com que peso. É a #PAREDE08, e o número tem de
  nascer medível.
- Se o `EstiloDeParede` substitui `texturas_parede`/`texturas_face` por inteiro
  ou convive. É a #PAREDE05.
- Se o recorte do chão sobre o topo sobrevive à fita de módulos. É a #PAREDE04, e
  ela **não pode** descobrir isso na #PAREDE06: é o truque que faz a sala em L
  funcionar sem calcular anel com furo.
