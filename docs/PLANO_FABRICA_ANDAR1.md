# Plano — Fabrica cyberpunk abandonada (Andar 01)

Epico `[FAB nn]`. Traduz o *Briefing Mestre de Desenvolvimento Visual — Andar 01*
para este repositorio. Quando o codigo e este texto discordarem, o codigo ganha e
este texto se atualiza.

Frase-guia, que manda em toda decisao daqui:

> O jogador explora uma fabrica cyberpunk pesada, antiga e abandonada que ainda
> mantem partes de sua infraestrutura funcionando precariamente.

---

## 1. A MEDICAO, antes de qualquer mudanca

O briefing abre dizendo que o andar 1 tem **excesso de verde**. Medido pixel a
pixel nas 56 texturas de `assets/texturas/`, isso e verdade em parte -- e a
parte que ele erra muda a Fase A inteira.

| grupo | matiz | saturacao | valor |
|---|---|---|---|
| `chao_item` | **172** | **0,95** | 0,12 |
| `chao_arma` | 28 | **0,89** | 0,12 |
| `chao_boss` | 342 | **0,77** | 0,12 |
| `chao_andar1_a/b/c` | 235 | 0,41 | 0,12 |
| `parede_face_item*` (5) | **176** | 0,34-0,42 | 0,18-0,23 |
| `parede_face_combate*` (5) | 200 | 0,34-0,42 | 0,18-0,23 |
| `parede_face_arma*` (5) | 37 | 0,34-0,42 | 0,18-0,23 |
| `parede_face_boss*` (7) | 335 | 0,31-0,42 | 0,20-0,23 |
| `parede_topo_a/b/c` | 215 | **0,29** | 0,27 |
| `porta_*` | 230-233 | 0,35-0,44 | 0,09-0,10 |
| `props_*` | 223-235 | 0,40-0,44 | 0,17-0,25 |

**Seis de 56 texturas caem na faixa verde/teal (90-190 graus), e as SEIS sao a
sala de item.** O resto do andar ja e azul: o topo em 215, a porta em 232, o
chao base em 235, os props em 223-235.

### O que a medicao diz de verdade

**O defeito nao e o matiz verde: e o TINGIMENTO POR TIPO DE SALA.** O chao de
cada tipo sai do funil com saturacao de **0,77 a 0,95** -- nao e metal tingido, e
cor chapada com textura por cima. O verde e so a fatia do item nisso; o laranja
da arma (0,89) e o magenta do chefe (0,77) sao o mesmo defeito com outro angulo.

E isso e exatamente o que o proprio briefing pede que morra, nas secoes 110-114:
*"Desativar tint de room type... Uma pessoa deve identificar a funcao visual. Se
depender da cor: FAIL."* As duas reclamacoes -- "muito verde" e "sala definida
por cor" -- sao **a mesma reclamacao**, e a segunda e a causa.

Entao a Fase A nao e "recolorir o verde para cinza". E:

1. **derrubar a saturacao do tingimento** de todos os quatro tipos ao mesmo
   tempo, convergindo para o gunmetal que o topo (215 / 0,29) ja e;
2. **deixar a funcao carregar a diferenca** -- props, luz e composicao;
3. so entao devolver a cor do tipo em dose pequena (o §111 do briefing).

### A restricao que isso encontra

**Nao existe master de textura neste repositorio.** `tools/art_sources/` tem
`itens/` e `armas/` -- os icones --, e mais nada. As 56 texturas de ambiente sao
saida final do funil, sem fonte.

E o `GEMINI.md` registra que **reprocessar pelo funil um PNG que ja passou por
ele COME detalhe**: medido nos tres chaos, a densidade cai de 16,4% / 16,9% /
12,3% para 8,1% / 6,1% / 4,0%, e a razao piso/parede fura o piso em duas das
tres. A causa e a requantizacao para a paleta, que acontece de novo.

Logo: **retingir NAO pode passar pelo funil.** Precisa de um caminho que gire o
matiz e escale a saturacao **sem requantizar** -- rotacao em HSV preserva a
luminancia, e densidade e medida espacial. E `[FAB 02]`, e ele nasce com a
medicao de densidade antes/depois como portao.

---

## 2. O que o briefing NAO pode derrubar

Tres decisoes dele colidem com portoes ja pagos aqui. A divergencia vai
declarada:

### 2.1 A porta NAO volta para tres vistas geradas

O briefing (§65-73) quer a porta substituida, e esta certo sobre o defeito. Mas
o `GEMINI.md` registra uma reversao consciente: as tres vistas de cima ja foram
tentadas em TRES rodadas, passaram por chapadas demais, mais claras que a parede
e sem cercar o vao, e o dono reverteu para a arte autorada girada. A linha e
literal: *"Nao proponha as tres vistas de novo sem arte autorada pronta na mao."*

**Entao a porta nova entra como ARTE AUTORADA substituindo `porta_moldura.png` e
`porta_folha.png`, mantendo a estrutura de nos que `teste_porta.gd` cobra** --
moldura que cerca o vao nos quatro lados, recesso separado da moldura, folha que
recolhe dentro do batente, escala sempre 1, sem `flip_v`. Os oito portoes
daquela suite continuam valendo e sao o criterio de aceite.

### 2.2 A subordinacao do topo continua sem janela

O briefing quer o topo "levemente mais claro que a face" (§75). A #242 mediu que
subordinacao do topo e nao-competicao do chao **puxam para lados opostos e nao ha
ponto que satisfaca os dois**: calmar o topo ate 0,780 derruba o detalhe da
parede a 22,5% e a razao chao/parede vai a 73%, contra o teto de 40%. Isso nao
mudou. Qualquer mexida no topo mede as duas pontas antes.

### 2.3 Densidade nova nao pode reabrir a conta dos props animados

O briefing pede densidade bem mais alta (§26). `max_props_animados` continua em
2, e `teste_props_animados.gd` cobra que o teto MORDE. Densidade e sobre props
PARADOS; o que se mexe continua com orcamento, porque movimento no cenario
compete com movimento de projetil.

---

## 3. As issues

As 92 issues do briefing viram 46 `[FAB nn]`. **A fusao nao e arbitraria**: ela
agrupa o que compartilha arquivo e portao, e SEPARA o que o briefing tinha
juntado por engano. O criterio de corte e o unico que muda o custo de verdade --
**precisa de arte gerada, ou nao?**

Legenda de `arte`: **nao** = so codigo e dado; **SIM** = consome geracao de
PixelLab, e portanto e decisao de orcamento e nao so de trabalho.

### Fase A — o esqueleto (sem arte) — ENTREGUE

| # | o que | briefing | arte |
|---|---|---|---|
| **FAB 01** | `medir_ambiente.gd`: dominancia de paleta, teste em cinza, teste em miniatura | 02, 118, 129, 130 | nao |
| **FAB 02** | `retingir.py`: retinge sem passar pelo funil, densidade medida antes/depois | habilita 03-06 | nao |
| **FAB 03** | `PerfilDeDecoracao` + `AgrupamentoDeDecoracao` + `DecoradorDeSala` | 61-70 | nao |
| **FAB 04** | `PerfilDeLuz` + `LuzDeFabrica` + os dois `.tres` | 71-77, 80 | nao |
| **FAB 05** | `laboratorio_decoracao` e `laboratorio_luz` | 81, 82 | nao |

### Fase A' — as duas lacunas que a REFERENCIA abriu

Nao existem no briefing: sairam de medir `docs/fabrica_01.png` depois que a
Fase A ja estava especificada. Ver `docs/REFERENCIA_FABRICA.md` secoes 2.1 e 2.4.

| # | o que | briefing | arte |
|---|---|---|---|
| **FAB 06** | Zona livre passa a proibir VOLUME e permitir DECALQUE: a referencia tem marcacao de galao e grades no centro | corrige 25 | nao |
| **FAB 07** | Porte `PAREDE`: peca que ancora na FACE e nao no chao (tubo, caixa de juncao, duto) | corrige 22-26 | nao |

### Fase B — a paleta aplicada (ainda sem arte nova)

| # | o que | briefing | arte |
|---|---|---|---|
| **FAB 08** | Paleta mestre em `paleta.gd`: o alvo e o topo, que ja mede 215,0 / 0,289 | 01 | nao |
| **FAB 09** | Retingir os TRES chaos tingidos (`chao_item` 0,947, `chao_arma` 0,891, `chao_boss` 0,770) | 06 | nao |
| **FAB 10** | Retingir as 22 faces por tipo de sala | 03 | nao |
| **FAB 11** | Tubos e paineis: eles vivem DENTRO das faces e dos props, nao em arquivo proprio | 04, 05, 76, 77 | nao |
| **FAB 12** | Acento de tipo de sala reduzido a indicador: luz e marca, nunca recolorir a sala | 07, 111-114 | nao |
| **FAB 13** | O portao de dominancia passa a medir uma CAPTURA DO JOGO, e nao a pasta de texturas | 118 | nao |
| **FAB 14** | `CanvasModulate` e ambiente escuro integrados na sala | 16, 80 | nao |
| **FAB 15** | Decalque de reflexo umido: na referencia ele e metade do efeito de luz | 78, 101 | nao |
| **FAB 16** | Emissor de vapor no tubo quebrado | 79, 102, 103 | nao |
| **FAB 17** | Integrar o `DecoradorDeSala` na `Sala` (nao esta no briefing, e sem ele a Fase A nao chega ao jogo) | -- | nao |
| **FAB 18** | Os quatro `PerfilDeDecoracao.tres`: combate, item, arma, loja | 82 | nao |
| **FAB 19** | Luminarias integradas por sala, com as contagens por tipo | 75, 97-100 | nao |

### Fase C — a arte (PixelLab: custa geracao)

| # | o que | briefing | arte |
|---|---|---|---|
| **FAB 20** | Biblioteca de prompts -- entregue em `docs/PROMPTS_FABRICA.md` | 19 | nao |
| **FAB 21** | **Batch 1: 12 assets**, montar sala de teste, validar perspectiva e paleta | 20-23 | **SIM** |
| **FAB 22** | Tubulacao (10 pecas) | 24 | **SIM** |
| **FAB 23** | Tanques (5-6) | 25 | **SIM** |
| **FAB 24** | Eletrica (7) | 26 | **SIM** |
| **FAB 25** | Ventilacao (6) | 27 | **SIM** |
| **FAB 26** | Armazenamento (9) | 28 | **SIM** |
| **FAB 27** | Manutencao (8) | 29 | **SIM** |
| **FAB 28** | Decalques (10) | 30 | **SIM** |
| **FAB 29** | Grades de piso e drenos | secao 79 | **SIM** |
| **FAB 30** | A porta: arte autorada (padrao, remendada, danificada) + moldura, trilhos, luz | 08-14 | **SIM** |
| **FAB 31** | A porta: integrar os quatro estados sem campo colorido gigante | 15-17, 116 | nao |
| **FAB 32** | Porta do chefe | 18 | **SIM** |
| **FAB 33** | Sala de item: 8-10 assets da estacao de modificacao corporal | 31-38 | **SIM** |
| **FAB 34** | Sala de item: perfil de decoracao e luz | 39, 40 | nao |
| **FAB 35** | Sala de armas: 8-10 assets de oficina/arsenal | 41-48 | **SIM** |
| **FAB 36** | Sala de armas: perfil e luz | 49, 50 | nao |
| **FAB 37** | Loja: 10-12 assets do posto improvisado | 51-58 | **SIM** |
| **FAB 38** | Loja: perfil e luz | 59, 60 | nao |

### Fase D — QA

| # | o que | briefing | arte |
|---|---|---|---|
| **FAB 39** | Teste SEM tint de tipo: identificar a funcao da sala sem cor | 83, 110 | nao |
| **FAB 40** | As quatro salas montadas e fotografadas | 84-87, 128 | nao |
| **FAB 41** | Teste em cinza | 88 | nao |
| **FAB 42** | Teste em miniatura | 89 | nao |
| **FAB 43** | Teste de bullet hell: projetil continua legivel na sala densa | 90, 131 | nao |
| **FAB 44** | 50 seeds | 91 | nao |
| **FAB 45** | Comparar capturas com `docs/fabrica_01.png` | 92 | nao |
| **FAB 46** | Teste de movimento: prop sem colisao nao pode parecer obstaculo | secao 132 | nao |

### O que o briefing PEDE e nao numerou

A lista de 92 issues dele nao cobre tudo que a prosa dele exige. Estes entram
como divida declarada, para nao se perderem:

- **Politica de colisao** (secoes 86-88): decorativo sem colisao, obstaculo com
  colisao explicita, e a ordem de correcao quando a densidade atrapalha --
  primeiro tirar colisao, depois baixar contraste, e so entao remover props.
  Entra no `[FAB 17]`.
- **Portao de performance** (secao 124): sala densa nao pode virar dezenas de
  nos pesados. Entra no `[FAB 17]` como medicao.
- **Atlas** (secao 125): agrupar depois de aprovado, nunca durante a criacao.
  Entra depois do `[FAB 28]`.
- **Som ambiental** (secao 104): soquetes de som nos hero props. Fora de escopo
  agora, e o proprio briefing diz "futuramente".

---

## 4. Estado

**Entregues:** `[FAB 01]` a `[FAB 07]`, `[FAB 09]`, `[FAB 10]`, `[FAB 14]`,
`[FAB 17]`, `[FAB 18]` e `[FAB 19]` -- **13 de 46**.

As **33 restantes estao no GitHub**, com o epico em
[#302](https://github.com/alexandre-amaral/psicode/issues/302) e as issues em
#303 a #335. Cada uma carrega a medicao que a justifica, para o contexto nao
depender desta sessao.

### `[FAB 14]` e `[FAB 19]` fechados, e a calibragem foi MEDIDA

O `AmbienteDaFabrica` esta em **0,45** -- o alvo -- e cinco `LuminariaDeParede`
por sala de combate acendem bolsoes ambar sobre a escuridao. A captura mostra a
linguagem da referencia: escuro por toda parte, poca quente com a lampada
visivel dentro dela, jogador ainda legivel.

**A decisao de design que destravou tudo:** a regra de gamut do ator vale para
SUPERFICIE PINTADA, e nao para fonte de luz. Um projetil e pequeno, saturado e
de borda dura; uma poca e grande, macia e MODULA o que ja esta desenhado. O
portao passou a cobrar o RESULTADO composto no chao, e nao o swatch da lampada.

**Tres suposicoes erradas foram desfeitas por medicao, e todas passavam verde:**

1. **A conta do portao superestimava o render em mais de dez vezes.** Ela era
   `chao + cor.v * energia` e ignorava que o `CanvasModulate` multiplica a
   contribuicao da luz junto com o resto. Hoje ha um `FATOR_DE_RENDER := 0.088`
   **medido no motor**, e a varredura que o produziu esta escrita ao lado dele:
   o delta e LINEAR (0,086 / 0,088 / 0,088 / 0,088 / 0,0887 em cinco energias).
2. **`Light2D.energy <= 1.0` era suposicao.** Ela nao e uma fracao, e um
   multiplicador aditivo; o teto de 1,0 prendia a lampada num valor em que o
   andar ficava sem poca. O caso existe para pegar campo esquecido em ZERO, e o
   piso continua fazendo isso.
3. **`QUEDA_MAXIMA_NA_BORDA := 1.0` proibia a luz de existir.** A queda ABSOLUTA
   por pixel escala com a energia: a mesma rampa, mais forte, perde mais niveis
   sem mudar de FORMA. O numero novo (3,0) sai da comparacao com o CONTROLE, que
   e o que a secao 20 quer separar -- o disco chapado mede **66,94** passos por
   pixel contra **1,31** do ambar calibrado.

**A licao maior:** o `PerfilDeLuz` foi escrito por um agente proibido de rodar o
Godot (para nao corromper o cache com imports concorrentes), entao ele nunca viu
a propria luz -- e a regua analitica que ele escreveu concordou com ele. **Portao
que mede a MATEMATICA de um efeito nao prova que o efeito aparece.** E irma da
armadilha do `--import` limpo: as duas passam verde sobre codigo que nao roda.

### `[FAB 09]` e `[FAB 10]`: o tingimento derrubado, medido

| familia | antes | depois | referencia |
|---|---|---|---|
| cinza_azulado | 42,61% | **68,57%** | 35,43% |
| ciano | 11,77% | **0,52%** | 0,50% |
| ferrugem | 13,71% | **0,17%** | 3,30% |
| magenta | 9,69% | 14,20% | 0,17% |
| verde | 0,01% | 0,01% | 0,16% |

O que mudou de fato: **item girou de 172 para 205** e **arma de 37 para 212**;
andar1 e chefe so dessaturaram. Os chaos foram de 0,95 / 0,89 / 0,77 para a
casa de 0,30.

**Duas descobertas que valem mais que os numeros:**

1. **A ferrugem sumiu junto.** Ela media 13,71% porque o laranja da sala de arma
   contava como ferrugem; hoje mede 0,17% contra os 3,30% da referencia. O andar
   ficou sem desgaste quente, e quem devolve isso e ARTE -- e nao tinta de
   ambiente. Entra como criterio do `[FAB 28]`.
2. **Esta arte nao tem folga.** Os tres pares de modulo que o portao compara
   mediam 0,2598 / 0,2595 / 0,2603 contra um piso de 0,25 -- **1,5% de margem**
   -- e a `parede_face_arma_deteriorada` vivia a dois milesimos do piso de
   verticalidade. Nao eram portoes protegendo a arte: era arte raspando nos
   portoes, e qualquer mexida nos pixels ia bater neles.

**Tres tentativas falharam por medicao antes de a quarta funcionar**, e todas
estao registradas: fator 0,80 (0,246), fator 0,88 (0,246 e o matiz do chefe
dando a volta em 0 por arredondamento de 8 bits), subtracao de 0,07 (0,245). O
que resolveu a verticalidade foi VARRER o alvo de rotacao da arma --
205/212/220/228/236/244 dao 0,2057 / 0,2042 / 0,2008 / 0,1996 / 0,1963 / 0,1976
contra o minimo de 0,20 -- e escolher 212, que por acaso e o matiz dominante da
propria referencia.

`retingir.py` ganhou `--saturacao-menos` nesse caminho: **subtrair preserva a
diferenca ABSOLUTA entre texturas e multiplicar a encolhe**, e a assinatura de
superficie mede diferenca absoluta. E o par `chefe: tecnica|motor` ficou
declarado em `MODULOS_COLAPSADOS_DO_CHEFE` -- a distancia que falta nele nao
esta na cor, e quem o tira de la e o `[FAB 24]`.

### O que `[FAB 06]` e `[FAB 07]` provaram, medido

| | colocadas | no miolo |
|---|---|---|
| DECALQUE | 480 em 60 salas | **71** |
| VOLUME | 360 em 60 salas | **0** |

E a peca de PAREDE entra no maximo **20 px** na sala, contra os 48 da faixa
comum -- ela mora na face, e nao no chao encostada nela.

### Tres defeitos que so a integracao achou

1. **Campo novo com default util quebra todo helper de "perfil vazio".**
   `contagem_micro` e `contagem_parede` nasceram com default, e o
   `_perfil_vazio()` da suite zerava so os cinco campos antigos: quatro casos
   passaram a reprovar apontando para o decorador, quando o defeito estava no
   helper.
2. **Array indexado por enum, dimensionado por literal.** O laboratorio tinha
   dois acumuladores de cinco casas; no dia em que `DECALQUE` e `PAREDE`
   entraram no fim do enum ele morreu com *Out of bounds get index '5'* --
   **depois** de imprimir o cabecalho, entao a saida parecia meio certa. Hoje o
   tamanho sai de `Porte.size()`.
3. **A regra do vazio media sujeira PINTADA NO CHAO como parede ocupada.** Com o
   perfil real, a sala em L dava 11,8% de vao maximo contra o piso de 12% e
   reprovava -- por causa de manchas perto da parede, com a parede vazia atras
   delas. Corrigido no lugar certo (o vao mede o que esta NA parede), e nao
   baixando o piso. Depois disso: 14,0% / 14,1% / 16,3%.

### `[FAB 17]`: a divida dos dois sistemas, paga

Havia dois sistemas de colocacao de prop. A `Sala` tinha
`_sortear_ponto_de_prop` + `_cabe_prop`, com `PROP_AFASTAMENTO_MINIMO/MAXIMO`,
`PROP_ESPACO`, `PROP_TENTATIVAS` e `PROP_DISTANCIA_DE_PORTA`; o
`DecoradorDeSala` tinha a mesma regra escrita de outro jeito.

**O que foi trocado foi a REGRA, e nao as contagens.** O decorador ganhou
`posicoes()` -- um lote de N posicoes legais de uma largura so -- e os cinco
montadores da `Sala` passaram a perguntar a ele. `DadosSala` continua dono de
QUANTOS (`quantidade_props`, `quantidade_props_volume`, `quantidade_decalques`,
`quantidade_props_frente`), que e o que as tres suites de prop cobram hoje.

Foi a divisao certa: trocar as contagens junto obrigaria a reescrever
`teste_props.gd` no mesmo passo, e um refactor que reescreve o portao que o
valida nao e validado por nada. **A migracao das contagens para o
`PerfilDeDecoracao` ficou declarada aqui**, e foi paga logo depois do Batch 1 --
ver a secao abaixo.

O decorador precisou de duas restricoes que a sala de teste nao tinha e a sala
real tem:

- **`area_spawn`** (`Rect2`), e ela e MELHOR que o raio da zona livre: e a area
  jogavel AUTORADA na cena. Num contorno em L o raio mede a partir do centro da
  caixa envolvente, que pode cair fora da sala.
- **as bocas de porta**, com raio proprio. O decorador nao tinha nocao de porta
  nenhuma -- ele poria um tanque na frente de uma passagem sem nada reclamar.

E sairam duas constantes: `PROP_AFASTAMENTO_MINIMO` (virou
`DecoradorDeSala.BORDA_MINIMA` mais a folga de meio prop) e `PROP_TENTATIVAS`
(virou `TENTATIVAS`). Constante morta que PARECE botao de tuning e pior que
constante nenhuma: alguem a gira, nada acontece, e a tarde vai embora.

### A migracao das contagens, paga -- e o que ela achou

O `[FAB 21]` entregou as 12 pecas e ficou aberto pelo segundo aceite: a sala
montada com elas **continuava parecendo vazia**. A conclusao natural era "faltam
os batches 22 a 27". Era outra coisa.

**Havia duas fontes para a densidade, e a que valia era a errada.** Os seis
`PerfilDeDecoracao` do `[FAB 18]` estavam em disco sem NINGUEM apontar para
eles; quem a `Sala` lia eram os `quantidade_props*` do `DadosSala` e uma
constante propria, `PROP_AFASTAMENTO_MAXIMO = 44`, contra os 96 que o perfil
declarava para a mesma coisa.

Os 96 nao sao um numero solto: e exatamente a margem que as cenas de sala
autoram entre o contorno e a `area_spawn` (`sala_1_retangular`: contorno
768x640, area 576x448). E `posicoes()` cobra meio prop de folga contra a parede.
Com faixa 44, a fatia util para uma peca de 64 px media **doze pixels** -- uma
linha, nao uma faixa.

O que a migracao trocou:

| | antes | depois |
|---|---|---|
| dono de QUANTOS | `DadosSala.quantidade_props*` | `PerfilDeDecoracao`, via `DadosSala.faixa_de_*()` |
| dono de QUAO FUNDO | `Sala.PROP_AFASTAMENTO_MAXIMO` | `largura_da_faixa_de_perimetro` do perfil |
| contagem | numero cravado por tipo | FAIXA sorteada por celula |

Medido pela regua nova (`tools/fabrica/medir_sala.tscn`, 24 sementes por tipo),
pecas colocadas por sala:

| tipo | antes | depois | do pedido |
|---|---|---|---|
| combate | ~16 | **33,8** | 97% |
| inicial | ~14 | **29,0** | 100% |
| arma | ~13 | **29,2** | 99% |
| item | ~13 | **24,1** | 100% |
| loja | ~13 | **40,5** | 100% |
| boss | ~11 | **12,7** | 102% |

**Tres defeitos so apareceram porque a regua olha a sala REAL.** Ela existe por
isso, e a licao e a mesma do `PerfilDeLuz`: o `laboratorio_decoracao` mede o
DECORADOR -- geometria pura, sem cena -- e concordava com si mesmo enquanto o
jogo mostrava outra coisa.

1. **O prop volumetrico contava sempre UM.** Ele e a unica familia sem raiz
   propria (ele precisa ser filho direto da sala para o Y-sort), entao quem o
   conta so tem o nome -- e `add_child` renomeia o segundo em diante para
   `@PropVolume@<id>`. `teste_props.gd` media o primeiro prop e mais nada, verde,
   desde que nasceu. Hoje eles entram num GRUPO.
2. **O decalque perdia a maioria das colocacoes** (18% do pedido na Loja, 47% na
   sala de arma): ele dividia a lista de ocupados com o que tem CORPO, entao os
   volumetricos entravam primeiro e lotavam a faixa. Mancha de oleo debaixo de
   um caixote e o que uma fabrica usada produz -- a `[FAB 06]` ja dizia isso, e
   o `DecoradorDeSala` ja obedecia em `decorar()`; a `Sala` nao.
3. **E ele so podia nascer na beirada.** Solto no chao todo, sortear a
   profundidade a partir de uma ARESTA parece uniforme e nao e -- o disco de
   exclusao de cada porta come a beirada, e a distribuicao deu **89% no miolo
   contra 11% no perimetro**. `posicoes()` ganhou `"no_chao_todo"`; a
   distribuicao foi para 72% / 28%.

### `[FAB 44]` e `[FAB 46]`: a regua passa a olhar o que o jogo usa

A `[FAB 44]` pedia "apontar o laboratorio para os perfis reais e fechar o
portao", e ela estava certa por um motivo pior que o previsto: **ate aqui a
regua media UM perfil -- o primeiro `.tres` em ordem alfabetica -- e chamava
aquilo de "o perfil do andar 1"**. Ela imprimia numeros bonitos sobre
`decoracao_arma` enquanto os outros cinco nao eram apontados por ninguem.

Hoje ela varre os SEIS que os `tipo_*.tres` apontam (3 formas x 96 sementes
cada, 1728 salas por execucao), reprova PERFIL ORFAO -- recurso em disco que
nenhum tipo aponta, que e exatamente o estado que produziu o defeito -- e roda
no CI, dentro do job unitario, porque custa segundos.

Ela achou duas coisas na primeira varredura de verdade:

1. **A Loja era o perfil mais denso dos seis** (35,9 a 38,6 pecas contra 33 da
   sala de combate) e reprovava o piso de parede calma em duas das tres formas
   (11,6% e 10,6% contra 12%), mais o desvio por lado (0,126 contra 0,12). E ela
   e a sala que ja monta a propria mobilia -- balcao, tres bancadas e a luz de
   trabalho --, que o perfil nao enxerga. Baixada, ela fica em 32,1.
2. **"O perfil nao pede" e "a regua nao mediu" eram a mesma resposta.** A arena
   do chefe declara HERO `0 a 0` de propósito, e a regua reprovava com "nenhuma
   peca medida -- a regua nao olhou para nada". O guarda estava certo enquanto
   ela media um perfil so; com seis, ele passou a reprovar codigo certo.

A `[FAB 46]` (politica de colisao) virou dois portoes irmaos em vez de um
percurso a pe: **decorativo sem colisao** e **decorativo fora da area util**.
As duas metades falham em silencio e nenhuma aparece no console -- colisao
esquecida vira esbarrao fantasma, e prop sem colisao dentro da area util e
cobertura que nao cobre. A politica esta escrita no `GEMINI.md`.

### `[FAB 43]`: o projetil acima do cenario, declarado em vez de sorteado

A secao 90 pede que o projetil continue legivel na sala densa, e a primeira
pergunta nao e de contraste: e de ORDEM DE DESENHO. Ela estava respondida por
acidente. Nao havia no nenhum no grupo `container_projeteis`, entao
`Arma._container()` caia em `current_scene` -- o proprio `Main` -- e projetil
adicionado depois do `Mundo` desenha depois dele.

O resultado era o certo e a razao nao existia em lugar nenhum. Com a sala de
combate indo de 4 para ~15 corpos volumetricos, "projetil atras de um caixote"
deixou de ser hipotese. Hoje o `ContainerProjeteis` esta declarado na cena --
irmao do `Mundo`, depois dele, sem Y-sort -- e as tres propriedades sao
cobradas.

**E o no novo achou um vazamento de sete casos.** `teste_loja` e
`teste_conexoes` instanciavam `main.tscn` e liberavam so o `mapa`, deixando o
`Main` na arvore para sempre. Isso era invisivel enquanto o `Main` nao tinha
nenhum no em grupo; no instante em que passou a ter, `teste_arma.gd` e
`teste_boss_ataques.gd` comecaram a medir ZERO projeteis com o codigo certo.

O que o `[FAB 43]` NAO cobre ainda: o contraste do projetil contra a arte do
prop. A ordem de desenho garante que ele esta na frente; se ele LE na frente e
outra medicao, e ela depende da arte dos batches 22 a 27.

**O que a migracao NAO resolveu:** o quadro continua **37,7 pontos mais escuro**
que a referencia (era 41,3 antes das pecas novas). O proprio `medir_ambiente`
recusa gatear isso e diz por que -- a referencia tem sete a oito lampadas por
sala e o andar tem tres a cinco. Mas o numero medido hoje compara um QUADRO DE
JOGO (com HUD e com o vazio preto em volta da sala, que sao 12 a 16% do quadro
por decisao do `margem_exterior`) contra um render 3D de uma sala fechada, entao
parte da distancia e a moldura da comparacao e nao falta de luz. Subir lampada
sem separar as duas coisas e girar um botao contra um numero que mede outra
coisa.

**O que `[FAB 17]` NAO fez:** o porte `PAREDE` continua sem consumidor. Ele nao
tem arte (`[FAB 22/24/25]`) nem camada de desenho -- peca presa na FACE nao e
nem prop de chao nem foreground. Liga-lo ao atlas errado seria pior que
deixa-lo esperando, e por isso ele esta declarado aqui em vez de improvisado.
