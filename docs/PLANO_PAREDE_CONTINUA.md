# Plano — a parede deixa de ser bloco e vira moldura

> Escrito pelo dono do projeto. **Comanda** esta iteração; dissolvido nas issues
> `[MOLDURA nn]`. Quando o código e este texto discordarem, o código ganha e o
> texto se atualiza.

## 1. O problema

A parede de hoje lê como **grandes blocos colocados ao redor da sala**, e não
como **uma superfície contínua que delimita a sala**.

```
hoje                          objetivo
┌────┬────┬────┬────┐         ████████████████████
│████│████│████│████│         ████████████████████
├────┴────┴────┴────┤         ────────────────────
│      CHÃO         │         │      CHÃO        │
```

A primeira parece um mapa construído com caixas. A segunda parece uma sala.

Causas prováveis, combinadas: módulos grandes; topo profundo demais; face alta
demais; repetição clara de tiles; divisão visível entre módulos; cantos
volumosos; parede sul pesada; ausência de linha interna contínua; perspectiva
exagerada em cada segmento.

**O objetivo não é reduzir escala. É mudar a leitura.**

## 2. A ordem, e ela é o coração do plano

```
SILHUETA -> PROPORÇÃO -> CONTINUIDADE -> PROFUNDIDADE
-> CANTOS -> PORTAS -> PALETA -> DETALHES
```

**A ordem a evitar:** textura nova → mais detalhe → mais ferrugem → mais sombra
→ esperar que melhore. Isso só deixa os blocos mais bonitos. **O problema é
estrutural.**

## 3. Congelar o detalhamento primeiro (§3)

Antes de qualquer tubo, ferrugem ou painel: uma versão com **uma cor para topo,
uma para face, uma para sombra**. Nenhuma textura, nenhuma variação.

Se ainda assim parecer uma fileira de blocos, **o problema é a geometria** — e
essa é a primeira verificação.

## 4. Sala de diagnóstico e modo de debug (§4-5)

`wall_visual_test`: sala retangular ~15×9 tiles, com player, uma caixa, um
inimigo, porta norte e porta sul. Nada mais, e nada procedural.

Debug de superfície por cor sólida: chão cinza, topo azul, face vermelha,
colisão verde, foreground amarelo. A pergunta que ele responde: **qual parte
está fazendo a parede parecer um bloco?**

## 5. Continuidade — a mudança técnica mais importante (§9-12, §44-51)

Os segmentos são construídos em células de 32, mas **não podem aparecer** como
`|tile|tile|tile|`. As junções precisam sumir.

**Grade lógica ≠ grade visual.** 32×32 continua valendo para colisão, geração,
portas, mapa e posicionamento. O que para é comunicar visualmente cada célula.

Fluxo do renderizador:

```
ANTES                      DEPOIS
contorno                   contorno
↓                          ↓ classificar direção
para cada tile             ↓ agrupar células contínuas
↓                          ↓ criar WallStrip
instanciar wall tile       ↓ criar superfícies
                           ↓ adicionar detalhes
```

```
WallRenderer
├── detect_segments()   contorno -> north/south/east/west
├── merge_segments()    N N N N N -> NorthStrip(5)
├── build_strip()       geometria contínua
├── build_corner()      fecha mudanças de direção, PEQUENO
├── cut_door()          Strip 4 | Door 2 | Strip 4
└── decorate_strip()    só no fim
```

Uma parede de 10 tiles tem de parecer **uma peça de 320 px**, não dez de 32.

## 6. Proporção e assimetria (§6-8, §17-23)

Testar quatro perfis na mesma sala, comparando screenshots lado a lado:

| perfil | topo | face |
|---|---|---|
| A (atual) | 32 | 32 |
| B | 24 | 24 |
| C | 16 | 24 |
| D | 16 | 16 |

**Assimetria é necessária.** 32/32 nos quatro lados produz moldura pesada
demais, e a perspectiva Low Top-Down não exige simetria:

```
NORTE          topo 16-24, face 20-28
LESTE/OESTE    largura visual 12-20
SUL            8-16
```

**A colisão continua 32.**

### Métrica principal (§8, §40)

Numa screenshot de combate o olho vai primeiro para: player → inimigos →
projéteis → espaço navegável → **parede**. Se a parede vier antes do espaço
jogável, está grande demais. Alvo de diagnóstico: **80-90% espaço de jogo,
10-20% arquitetura**.

### `visual_inset` / `visual_outset` (§23-26)

Dimensão lógica ≠ dimensão desenhada. Com `logical_wall = 32`, `visual_inset =
10` e `visual_outset = 22`, só 10 px entram na arena. Deslocar volume **para
fora** mantém a borda sem perder área aparente.

## 7. Linha de contato e sombra (§14-16, §37-38)

A linha onde a parede encontra o chão precisa ser **contínua e muito clara** —
ela é o que diz "aqui termina a parede e começa a arena".

```
██████████████████████████
──────────────────────────  ← contato, contínuo
            CHÃO
```

`inner_wall_line`: 1-3 px acompanhando todo o contorno interno.

**Sem outline por módulo.** Contorno só no externo, no encontro parede/chão e
nos cantos importantes.

E uma **sombra de contato de 2-4 px** no chão frequentemente cria mais sensação
de altura do que aumentar a parede em 16 px. Sutil, num neutro perto de N0/N1.

## 8. Cantos (§27-29)

Cantos grandes fazem a sala inteira parecer feita de cubos. Começar removendo
os assets de canto; validar `north strip + west strip` formando um encontro
simples; só então um pequeno acabamento.

**O canto conecta superfícies — ele não é um pilar.** Para sala em L, mesma
regra: transição + sombra + topo, nunca um cubo preenchendo a quina.

## 9. Detalhes, e só no fim (§13, §30-35, §56-57)

Decoração é **overlay**, nunca geometria:

```
WallStrip
├── BaseSurface
├── TopSurface
└── Decorations (pipe, panel, damage)
```

Escala menor que os módulos: parede 320 px, painel 32-48, tubo 8-16, parafuso
2-4. **Nada de um painel gigante a cada 32 px.**

Frequência: **80% parede limpa, 20% detalhe**, com grandes regiões vazias.

Contraste: o ambiente é subordinado aos atores. O volume vem de **valor +
sombra + silhueta**, não de cor forte. Separação por valor: piso N1/N2, face
N4/N5, topo N5/N6. **N7 continua raro** — topo todo claro vira moldura
brilhante e compete com o combate.

A identidade não vem do formato de cada bloco; vem do **material aplicado sobre
uma parede contínua**.

## 10. Os testes que aprovam (§41-43, §54-55)

- **Sem props:** chão + paredes + player já tem de parecer uma sala válida.
- **Miniatura:** reduzir a captura a ~25% e olhar. Se ainda der para ver
  `[BLOCO][BLOCO]`, a repetição é excessiva.
- **Silhueta:** parede numa cor sólida, chão em outra. Tem de parecer uma sala,
  não uma grade de construção.

Os doze critérios de aprovação: (1) a primeira leitura é "sala"; (2) módulos
individuais não são percebidos; (3) a norte tem volume; (4) a sul não encobre;
(5) laterais não parecem colunas; (6) cantos não parecem pilares; (7) o chão
parece chegar até a parede; (8) a área de combate parece ampla; (9)
player/projéteis dominam; (10) tirar os detalhes não destrói a leitura; (11)
portas parecem aberturas reais; (12) funciona na sala em L.

**Contra o Isaac, comparar só a sensação estrutural** — parede = moldura, chão =
massa central, cantos discretos, porta = abertura na moldura, detalhes
secundários. Não a textura, a sujeira, a cor nem o desenho dos tijolos.

## 11. Os passes

| pass | entrega | critério |
|---|---|---|
| 1 | floor + wall strips | não parece bloco |
| 2 | top, face, contact shadow | parece parede |
| 3 | cantos | nenhum canto parece pilar |
| 4 | portas | a porta parece parte da parede |
| 5 | paleta psicode | — |
| 6 | detalhes | só depois de tudo aprovado |

## 12. As issues

01 cena `wall_visual_test` · 02 debug de cor por superfície · 03 remover as
divisões visuais entre tiles · 04 `WallStrip` · 05 agrupar células contínuas ·
06 testar 32/32, 24/24, 16/24, 16/16 · 07 `visual_inset`/`visual_outset` ·
08 reduzir a sul · 09 reduzir as laterais · 10 linha contínua parede/chão ·
11 sombra de contato · 12 reconstruir cantos · 13 integrar portas ao strip ·
14 sala retangular · 15 sala em L · 16 corredores · 17 validar câmera ·
18 aplicar paleta · 19 decoração industrial · 20 substituir o sistema antigo.
