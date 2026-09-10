# A referencia da fabrica, lida — e o que ela corrige no briefing

Companheiro de `docs/PLANO_FABRICA_ANDAR1.md`. O briefing diz o que a fabrica
deve ser; este arquivo registra o que a IMAGEM DE REFERENCIA de fato mostra, e
os cinco pontos em que ela **discorda do proprio briefing**.

A imagem esta em `docs/fabrica_01.png`, 1672x941, e os numeros deste arquivo
foram **medidos nela**, pixel a pixel. As observacoes de composicao (o que esta
desenhado onde) continuam sendo leitura a olho, e vao marcadas como tal.

> **Uma correcao registrada.** A primeira versao deste documento estimou a
> saturacao do ambiente da referencia "na casa de 0,10 a 0,20", a olho. Medida,
> ela e **0,380 no quadro inteiro e 0,284 no centro** -- quase o dobro. A
> conclusao que aquela estimativa sustentava sobreviveu (o problema do jogo e
> saturacao, nao matiz), mas por uma margem bem menor do que parecia, e o
> culpado ficou mais preciso: nao e o andar todo, sao os TRES chaos tingidos.

---

## 1. O que a referencia CONFIRMA

Estas nao precisam de discussao -- a imagem e o repositorio ja concordam:

- **Camera Low Top-Down Squared.** Vista de cima levemente inclinada, com a
  parede mostrando TOPO e FACE ao mesmo tempo. E o que `src/mapa/sala.gd` ja
  monta.
- **Cantos chanfrados.** A sala da imagem e um octogono: os quatro cantos sao
  chanfros largos, e nao quinas retas. O `chanfro_de_canto` do
  `PerfilDeParede` esta certo, e a referencia sugere que ele poderia ser ate
  mais generoso.
- **Parede mais CLARA que o chao.** Na imagem o topo da parede e visivelmente
  mais claro que o piso. O jogo ja faz isso (face em valor 0,18-0,23 contra
  chao em 0,12), e a tentacao de escurecer a parede para "sujar" iria contra a
  referencia.
- **Centro amplo e vazio de MAQUINA.** Toda a maquinaria esta encostada na
  parede. Isso e a secao 22-25 do briefing, e a imagem e mais radical que ela.
- **Ambar pequeno e intenso.** As luzes sao pontos, nao lavagens.
- **Ciano raro e funcional.** Ha exatamente UM na sala inteira.

---

## 2. Os CINCO pontos em que a referencia discorda do briefing

### 2.1 O centro NAO esta vazio — ele esta PINTADO

O briefing (§25) define `COMBAT_CLEAR_ZONE` e diz que "nenhum prop grande
cenografico pode nascer ali". A imagem cumpre isso para PROPS -- e o centro dela
tem, bem no meio, **uma marcacao de piso em galao amarelo-envelhecido**, um
losango de listras que ocupa boa parte da area livre.

**Consequencia para o `[FAB 03]`:** a zona livre precisa distinguir duas coisas
que o briefing trata como uma so:

- **VOLUME** (tanque, caixa, painel) -- proibido no centro, sem excecao.
- **DECALQUE** (marcacao, grade, mancha) -- **permitido** no centro, e e ele que
  impede o piso de virar um vazio chapado.

Sem essa distincao o centro fica limpo demais e a sala perde justamente o que a
referencia usa para dizer "isto aqui era uma area de trabalho". E a marcacao
central e barata: ela e um decalque no chao, sem colisao e sem custo de leitura.

### 2.2 Ha MUITO mais luz do que o briefing autoriza

O briefing (§97) diz: sala de combate normalmente **1 a 3 fontes funcionais**.

A imagem tem, na conta a olho, **sete ou oito pontos ambar** distribuidos pelo
perimetro, mais **um ciano**. Duas a tres vezes o teto do briefing.

E a diferenca nao e de gosto, e estrutural: a sensacao de "fabrica que ainda
funciona precariamente" vem de a luz estar **espalhada e fraca**, e nao
concentrada e forte. Tres lampadas fortes fazem tres holofotes; oito lampadas
fracas fazem uma instalacao eletrica.

**Recomendacao:** subir o teto de fontes ambar por sala e BAIXAR a energia de
cada uma. O numero final e do `laboratorio_luz` (`[FAB 05]`), medindo, e nao
desta prosa.

### 2.3 As grades de piso estao por toda parte, inclusive no meio

O briefing (§79) pede 0 a 4 grades por sala. A imagem tem **mais de dez**, e
varias caem dentro da area central livre.

Elas funcionam ali por serem **planas, escuras e de baixo contraste** -- nao
competem com projetil porque nao tem brilho nem silhueta. Sao o exemplo perfeito
da distincao 2.1: decalque no centro esta certo, volume no centro esta errado.

### 2.4 A parede nao e um plano: ela e uma ESTANTE

Na imagem, quase nenhum trecho de parede aparece limpo. Tubos correm por cima
dela, caixas de junção se penduram nela, dutos atravessam o topo, e algumas
maquinas encostam ate a altura do cap.

O jogo hoje veste a face com UM modulo por lado. A referencia sugere que a
densidade nao vem so de props no chao, mas de **coisas presas na parede** -- e
isso e uma categoria de asset que o briefing lista (tubulacao, caixa de junção,
duto) mas nao diz onde mora.

**Consequencia:** vale um porte novo no `[FAB 03]`, algo como `PAREDE`, para
peca que ancora NA face e nao no chao. Sem ele, todo tubo vira prop de piso e a
composicao nunca alcanca a referencia.

### 2.5 O reflexo umido e o que faz a luz existir

O briefing menciona reflexo em uma linha (§101). Na imagem ele e **metade do
efeito**: cada lampada ambar deixa um risco vertical alongado no piso molhado,
e sao esses riscos -- e nao os halos -- que dizem "ha luz aqui".

Isso e barato e nao custa luz de engine: e um decalque alongado, na cor da
lampada, ancorado abaixo dela. Vale tratar como peca de primeira classe do
`[FAB 04]`, e nao como enfeite opcional.

---

## 3. A referencia MEDIDA

### 3.1 Composicao de familias de cor

| familia | quadro inteiro | so o centro |
|---|---|---|
| PRETO (valor <= 0,10) | **50,75%** | 9,91% |
| CINZA_AZULADO (matiz 195-255, sat <= 0,45) | **35,43%** | **85,81%** |
| OUTRO | 7,77% | 1,90% |
| FERRUGEM | 3,30% | 0,26% |
| CINZA_PURO | 1,51% | 1,07% |
| CIANO | **0,50%** | 0,76% |
| AMBAR | **0,41%** | 0,02% |
| MAGENTA | 0,17% | 0,04% |
| VERDE | **0,16%** | 0,23% |

**Metade da referencia e preto.** Esse e o numero mais importante do documento:
50,75% do quadro esta em valor 0,10 ou menos. A "sombra profunda" que o briefing
pede nao e um efeito, e a maior parte da imagem.

E no CENTRO -- a area jogavel -- o cinza azulado chega a **85,81%**. A area em
que o combate acontece e quase monocromatica, e e exatamente por isso que
projetil e inimigo saltam dela.

**O ambar ocupa 0,41% do quadro**, e so 0,251% dele passa de valor 0,55. As
lampadas sao pontos. Qualquer luz que ocupe uma fracao maior que essa ja saiu da
referencia -- e esse e o numero que o `laboratorio_luz` tem de perseguir.

### 3.2 Matiz e saturacao: onde o jogo esta

| | matiz | sat media | valor medio |
|---|---|---|---|
| **referencia (quadro)** | **216,5** | 0,380 | 0,121 |
| **referencia (centro)** | **212,6** | **0,284** | 0,212 |
| `parede_topo_a` | 215,0 | 0,289 | 0,270 |
| `chao_andar1_a` | 234,9 | 0,404 | 0,121 |
| `parede_face_combate` | 200,1 | 0,424 | 0,186 |
| `chao_boss` | 341,8 | **0,770** | 0,119 |
| `chao_arma` | 28,1 | **0,891** | 0,122 |
| `chao_item` | 171,9 | **0,947** | 0,125 |

Tres leituras saem daqui, e duas sao boas noticias:

1. **O topo do jogo ja E a referencia.** 215,0 contra 216,5 de matiz, 0,289
   contra 0,284 de saturacao. Ele nao precisa de nada. E o alvo para onde os
   outros tem de convergir, e nao um problema a resolver.
2. **O valor tambem ja esta certo.** `chao_andar1_a` mede 0,121 de valor medio
   contra 0,121 da referencia -- identico. O andar 1 ja e escuro o bastante; o
   que falta e a FAIXA (a referencia vai de 0,008 no p10 a 0,243 no p90, e e
   esse contraste que a luz local produz).
3. **O defeito e os tres chaos tingidos, e ele tem tamanho.** 0,770 / 0,891 /
   0,947 contra os 0,284 do centro da referencia: **entre 2,7x e 3,3x**. O
   `chao_andar1_a`, em 0,404, esta so 1,4x -- alto, mas na mesma ordem.

**A distancia maior nao e de matiz, e de saturacao, e ela mora em tres
arquivos.** O verde do `chao_item` e uma das tres cabecas do mesmo problema, e
nao o problema.

### 3.3 O que isso vira em portao

Os tetos que o `[FAB 01]` cravou como chute inicial (8% de verde, 12% de ciano)
sao **frouxos demais**: a referencia tem 0,16% de verde e 0,50% de ciano. Os
numeros que ela sustenta sao mais perto de:

| familia | teto sugerido | referencia mede |
|---|---|---|
| VERDE | 1,0% | 0,16% |
| CIANO | 2,0% | 0,50% |
| MAGENTA | 2,0% | 0,17% |
| AMBAR | 2,0% | 0,41% |
| CINZA_AZULADO | piso de 30% | 35,43% |
| PRETO | piso de 35% | 50,75% |

Com uma ressalva honesta: a referencia e um render 3D de UMA sala, e as texturas
do jogo sao ladrilhos avulsos que nunca aparecem sozinhos em tela. Comparar as
duas coisas diretamente exagera a diferenca. O portao definitivo tem de medir uma
CAPTURA DO JOGO, e nao a pasta de texturas -- e isso e trabalho da Fase B.

---

## 4. O que NAO copiar

A referencia e um render 3D realista. Nao vale copiar:

- gradiente continuo e reflexo especular -- a arte aqui e pixel art paletizada;
- a geometria exata da sala;
- a profundidade de campo e o desfoque das bordas;
- o nivel de detalhe por pixel: reduzido para a resolucao do jogo, aquilo vira
  ruido, e o `GEMINI.md` ja registra que suavizar para caber num numero mata a
  arte.

O que se traduz e: **composicao, densidade, distribuicao, faixa de valor e onde
a luz mora.**
