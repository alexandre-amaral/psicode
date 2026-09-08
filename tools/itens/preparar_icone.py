# -*- coding: utf-8 -*-
"""Prepara o ICONE de implante: 256 do PixelLab -> 64 do jogo, sem inventar cor.

Por que este funil existe ao lado dos outros dois, em vez de ser uma bandeira
deles:

- `preparar_textura.py` empurra arte para o regime de AMBIENTE -- dessatura,
  chapa o teto de valor e grampeia o matiz. O icone tem de casar com o campo
  `cor` do `implante_*.tres`, que o pickup no chao e a HUD ja leem: girar matiz
  aqui faria a ficha no chao ter uma cor e o aviso da HUD ter outra, e nenhuma
  linha apareceria no console. **Icone nao passa por aquele funil.**
- `gerar_projeteis.py` e o irmao proximo, e daqui se importa o que ele ja
  resolveu (a paleta). O que nao serve la e a MOLDURA: projetil e uma fita de
  quadros medida pelo raio da hitbox, icone e uma peca so num slot quadrado.

A DECISAO DE DESIGN que este arquivo carrega e a ANCORA. Arte de ator ancora
nos PES (`Direcoes.BASE_NO_QUADRO` poe a base 36 px abaixo da origem, e e isso
que faz o Y-sort funcionar); icone ancora no **CENTRO**. Um icone que herdasse a
ancora de ator desenharia deslocado dentro do slot da bandeja, do pickup e da
bancada -- sem erro nenhum, so tres telas com a peca fora do lugar. Aqui o
centro do bbox de alfa cai no centro da moldura, e nada mais.

USO
    python tools/itens/preparar_icone.py <id> [origem]
                                         [--lado 64] [--raio-limpeza 1]

    <id>       id do implante, sem prefixo: `nucleo`, `fragmentador`, ...
               Ele decide os DOIS destinos, e nao ha segunda fonte de nome.
    [origem]   o PNG de 256 com alfa que saiu do PixelLab.
               Default: o MASTER ja versionado (ver abaixo).
    --lado     lado do icone final. Default 64, que e o que o jogo consome.
    --raio-limpeza  ver "A LIMPEZA E CONSERVADORA", abaixo. Default 1.

    Escreve DOIS arquivos:
      tools/art_sources/itens/icone_<id>.png   o master, enquadrado
      assets/itens/icone_<id>.png              o que o `.tres` aponta

O MASTER FICA VERSIONADO, e isso e o ponto do passo 5. O dia em que a moldura
mudar de 64 para 48 nao pode ser o dia em que se regera 16 icones no PixelLab --
foi o que os GIFs de personagem ensinaram ao ficarem fora do repositorio. Por
isso o master e tambem a ENTRADA PADRAO: `preparar_icone.py nucleo --lado 48`
refaz o icone inteiro sem tocar no gerador.

AS REGRAS, e cada uma existe porque quebra em silencio:

1. **Vizinho mais proximo, em escala INTEIRA.** E a unica reducao que nao borra
   pixel art -- a mesma razao pela qual a miniatura do cartao de selecao dobra
   para 128 em vez de ir para 96. A moldura e o menor multiplo de `--lado` que
   contem o desenho, entao 256 -> 64 e 4x exato; o fator sai medido no
   relatorio, e nunca e fracionario.

2. **Reduzir e depois GRUDAR na paleta da fonte.** A licao e do projetil e esta
   registrada: *"reduzir arte paletizada com BOX inventa cor -- a media entre o
   contorno e o corpo e uma cor que a fonte nao tem, e ela derrubou a fracao que
   compete de 52% para 41%"*. O vizinho mais proximo nao MEDEIA nada, entao aqui
   a colagem e rede de seguranca e nao cirurgia: o relatorio imprime quantos
   pixels ela moveu, e o numero saudavel e ZERO. Ela deixa de ser zero no dia em
   que alguem trocar a reducao -- e ai o portao de `cores novas` acusa antes de
   a arte entrar no jogo.

3. **Alfa binario.** O filtro do projeto e Nearest e meio-tom num icone de 64 px
   nao e suavizado por ninguem. O `create_image_pixflux` entrega borda com alfa
   parcial; ela e cravada em 0 ou 255 antes de qualquer medida.

4. **A LIMPEZA E CONSERVADORA, e o fragmentador e a razao.** A silhueta dele e
   DESCONTINUA de proposito -- duas metades separadas --, e um fechamento de
   buraco guloso as soldaria numa peca so, produzindo exatamente o icone que a
   regua de distinguibilidade nao pediu. Duas travas:

   - So se fecha buraco **ENCLAUSURADO**: um vao de fundo que alcanca a borda do
     quadro e FUNDO, nunca buraco. O corredor entre as duas metades alcanca a
     borda por construcao, entao ele nao e alcancavel por este passo -- e
     garantia GEOMETRICA, e nao cuidado de quem escreveu.
   - `--raio-limpeza R` trata so o defeito que cabe num quadrado de R x R. Em 1
     (o default) isso e literalmente "pixel solto" e "buraco de 1 px", que e o
     lixo que o gerador deixa. Suba com medida na mao, nunca por gosto.

   E o relatorio CONTA as componentes opacas antes e depois: se a limpeza
   soldar ou apagar uma peca da silhueta, o numero muda e o portao reprova.

5. **RODAR O FUNIL NUM PNG QUE JA PASSOU POR ELE E PROIBIDO.** Medido nos tres
   chaos do andar 1: a densidade cai de 16,4% / 16,9% / 12,3% para 8,1% / 6,1% /
   4,0%, porque a requantizacao acontece de novo. Aqui a deteccao e barata e o
   script RECUSA: origem dentro de `assets/itens/`, ou origem que ja esta no
   tamanho final, nao entram. Rodar de novo no MASTER e outra coisa e e legitimo
   -- ele e a fonte enquadrada, e o resultado e byte a byte o mesmo.

O QUE ELE NAO FAZ: nao tinge, nao dessatura, nao "melhora". Toda cor do 64 e uma
cor que ja estava no 256.
"""

import argparse
from collections import Counter, deque
import os
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover -- mesma mensagem dos outros dois funis
    sys.exit("Precisa do Pillow:  pip install Pillow")

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# A paleta e o alfa binario sao O MESMO problema do projetil, e uma segunda
# copia de "gruda na paleta da fonte" divergiria no dia em que alguem melhorasse
# uma das duas -- e o sintoma seria em TELA e nunca no console, que e a mesma
# licao que tirou o mapa de angulo -> quadro de dentro de `DadosPersonagem`.
sys.path.insert(0, os.path.join(RAIZ, "tools", "sprites"))
from gerar_projeteis import (  # noqa: E402
    LIMIAR_ALFA,
    _binarizar,
    _bbox_de_alfa,
    _grudar_na_paleta,
    _paleta_de,
)

MESTRE = os.path.join(RAIZ, "tools", "art_sources", "itens")
SAIDA = os.path.join(RAIZ, "assets", "itens")

## O lado que o jogo consome. Botao e nao literal: a moldura do slot pode
## encolher, e quando encolher o master ja esta em disco para ser reduzido de
## novo.
LADO_PADRAO = 64

## Ver a regra 4. Um quadrado de R x R e o maior defeito que a limpeza toca.
RAIO_LIMPEZA_PADRAO = 1

## Vizinhanca de 8 nos DOIS lados -- desenho e fundo. Nao e simetria por
## elegancia: para o FUNDO, 8 e a escolha CONSERVADORA, porque mais fundo
## alcanca a borda do quadro, menos vao e classificado como buraco, e menos
## chance existe de a limpeza soldar uma silhueta partida. Para o DESENHO, 8 e a
## leitura visual: duas manchas que se tocam na diagonal leem como uma peca so.
VIZINHOS = ((-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1))


## A tolerancia do recorte de fundo, em distancia L1 de RGB.
##
## **O PixelLab nao devolve alfa.** `no_background=True` volta com a imagem 100%
## OPACA e o fundo pintado de chapado -- entao `enquadrar()` nao teria no que
## morder, e o icone sairia com a moldura inteira de fundo colada.
##
## O numero sai de VARREDURA e nao de gosto. O gerador pinta o fundo com DOIS
## tons quase iguais (medido: `municao_inteligente` 73,6% de um e 26,4% de outro,
## a 9 de distancia), entao uma tolerancia apertada deixa o segundo tom para tras.
## Nos 16 masters do andar 1: com 8 tres pecas ficam presas, com 16 duas, com 24
## todas saem -- e **24 e 32 dao resultado byte a byte identico**. Escolher no
## meio do plato e o que faz o numero nao envelhecer com a proxima peca; na
## beirada, envelheceria.
TOLERANCIA_PADRAO = 24

## Sombra que sobrou: acromatica, clara, e encostando no vazio.
##
## O gerador desenha sombra projetada mesmo com "no cast shadow" no prompt, e ela
## toca a BASE da peca -- entao ela nao esta conectada a borda e o preenchimento
## nunca a alcanca. Sobra uma mancha cinza sob o icone, que num piso de luma
## 14-16 le como sujeira.
##
## **Isto nao pode ser automatico**, e por isso `--tirar-sombra` nasce desligado:
## os mesmos tres criterios descrevem tambem as juntas esfericas de aco do
## `reflexo` e a agulha do `vampirico`. Apagar sombra por regra global comeria as
## duas, e o icone perderia justo o detalhe que o separa dos vizinhos. Onze das
## dezesseis nao precisam da bandeira.
SOMBRA_CROMA_MAXIMA = 12
SOMBRA_VALOR_MINIMO = 120
SOMBRA_VALOR_MAXIMO = 240


def _distancia(a, b):
    return abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])


def cor_de_fundo(img):
    """A cor que domina a BORDA do quadro.

    Perguntar a borda, e nao a imagem inteira: numa peca chapada a cor mais
    frequente pode ser a do proprio objeto, e o funil apagaria o desenho.
    """
    px = img.load()
    largura, altura = img.size
    borda = []
    for x in range(largura):
        borda.append(px[x, 0][:3])
        borda.append(px[x, altura - 1][:3])
    for y in range(altura):
        borda.append(px[0, y][:3])
        borda.append(px[largura - 1, y][:3])
    return Counter(borda).most_common(1)[0][0]


def chavear_fundo(img, tolerancia, vazar_furos=False):
    """Apaga o fundo por PREENCHIMENTO A PARTIR DA BORDA. Devolve (img, cor, n).

    **Por preenchimento e nunca por cor.** O fundo do `vampirico` e (171,170,170),
    um cinza medio da mesma familia do aco da propria seringa: "apague todo pixel
    igual a cor do fundo" abriria buracos DENTRO da peca, e num icone de 64 px um
    buraco de poucos pixels no meio do corpo e visivel.

    So sai o fundo CONECTADO a borda. Um vao fechado -- o furo do anel do
    `gatilho` -- e desenho e sobrevive; o vao entre as metades do `fragmentador`
    alcanca a borda e sai, que e o certo. As duas coisas caem desta mesma regra,
    sem caso especial para nenhuma.

    ## `vazar_furos`, e por que ele NAO e o default

    Um vao CERCADO pintado da cor do fundo nao e desenho: e um furo que se ve
    atraves. O anel do `gatilho` provou isso -- o miolo dele ficou um disco BRANCO
    opaco, porque o preenchimento nao alcanca o que esta cercado. A bandeira
    apaga tambem esses, comparando por cor em vez de por conexao.

    Ela e perigosa exatamente onde o preenchimento e seguro: o fundo do
    `vampirico` e (171,170,170), um cinza medio da mesma familia do aco da propria
    seringa, e comparar por cor ali abriria buracos no corpo da peca. Por isso ela
    e por peca e desligada por default -- vale para quem tem furo verdadeiro E cujo
    fundo esta longe da paleta do objeto.
    """
    img = img.convert("RGBA")
    largura, altura = img.size
    px = img.load()

    # **Arte que JA tem alfa nao passa por aqui, e a guarda nao e cortesia.**
    # O master versionado sai deste funil com o fundo em alfa zero -- e o
    # `--lado 48` do futuro relê esse master. Numa segunda passada
    # `cor_de_fundo()` leria o RGB dos pixels TRANSPARENTES, que e preto, e o
    # preenchimento comeria todo contorno escuro encostado na borda: a peca
    # perderia a silhueta, com o arquivo intacto e sem erro nenhum no console.
    if any(px[x, y][3] == 0 for x in range(largura) for y in (0, altura - 1))        or any(px[x, y][3] == 0 for y in range(altura) for x in (0, largura - 1)):
        return img, None, 0

    fundo = cor_de_fundo(img)
    fora = bytearray(largura * altura)
    fila = deque()

    def semear(x, y):
        if not fora[y * largura + x] and _distancia(px[x, y][:3], fundo) <= tolerancia:
            fora[y * largura + x] = 1
            fila.append((x, y))

    for x in range(largura):
        semear(x, 0)
        semear(x, altura - 1)
    for y in range(altura):
        semear(0, y)
        semear(largura - 1, y)
    while fila:
        x, y = fila.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < largura and 0 <= ny < altura:
                semear(nx, ny)

    if vazar_furos:
        for y in range(altura):
            for x in range(largura):
                if not fora[y * largura + x]                    and _distancia(px[x, y][:3], fundo) <= tolerancia:
                    fora[y * largura + x] = 1

    for y in range(altura):
        for x in range(largura):
            if fora[y * largura + x]:
                px[x, y] = (0, 0, 0, 0)
    return img, fundo, sum(fora)


def tirar_sombra(img):
    """Corroi a sombra projetada que encosta no vazio. Devolve (img, n).

    Ela corroi em ONDAS ate estabilizar, porque a sombra e um degrade: apagar so
    a primeira camada expoe a seguinte, e o resultado seria uma borda cinza mais
    fina em vez de nenhuma.
    """
    img = img.convert("RGBA")
    largura, altura = img.size
    px = img.load()
    total = 0
    while True:
        alvo = []
        for y in range(altura):
            for x in range(largura):
                r, g, b, alfa = px[x, y]
                if alfa == 0:
                    continue
                if max(r, g, b) - min(r, g, b) > SOMBRA_CROMA_MAXIMA:
                    continue
                if not SOMBRA_VALOR_MINIMO < (r + g + b) // 3 < SOMBRA_VALOR_MAXIMO:
                    continue
                if any(px[x + dx, y + dy][3] == 0
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                       if 0 <= x + dx < largura and 0 <= y + dy < altura):
                    alvo.append((x, y))
        if not alvo:
            return img, total
        for x, y in alvo:
            px[x, y] = (0, 0, 0, 0)
        total += len(alvo)


## O ALVO de valor do miolo, e por que o funil mexe nisto e nao no matiz.
##
## A arte do PixelLab nasce **muito mais clara que a paleta do jogo**: medidas as
## 16 pecas cruas, DOZE reprovaram a faixa de leitura do
## `laboratorio_icones`, e tres passaram do teto de competicao com projetil
## (`dissipador` 80%, `gatilho` 82%, `celula_eco` 70%). Icone que compete com tiro
## e o defeito que o projeto inteiro se organiza para nao ter -- o mesmo que faz a
## ficha de credito ser losango e desenhar abaixo da faixa do mundo.
##
## A correcao e em VALOR e nunca em matiz. Girar matiz faria o icone discordar do
## campo `cor` do `implante_*.tres`, que o pickup no chao e a HUD ja leem, e o
## jogador veria a ficha de uma cor e o aviso de outra. Escalar o V do HSV
## preserva H e S por construcao.
##
## 0.42 e o meio da faixa `PISO_VALOR_MIOLO`..`TETO_VALOR_MIOLO` (0,30 a 0,55) que
## o laboratorio cobra. Escolher o meio, e nao a beirada, e a mesma razao pela
## qual `TOLERANCIA_PADRAO` mora no meio do plato.
ALVO_VALOR_MIOLO = 0.42

## Teto do ganho. Sem ele uma peca quase preta receberia um ganho enorme e
## sairia lavada -- e o funil estaria INVENTANDO iluminacao em vez de corrigir a
## que existe.
GANHO_MAXIMO = 4.0


def _miolo(img):
    """Pixels opacos cujos quatro vizinhos tambem sao opacos.

    Gemeo de `teste_texturas._e_miolo()` e do laboratorio: pixel art tem contorno
    escuro, e medir o contorno junto responderia sobre a borda em vez de sobre a
    superficie -- cobrar brilho do contorno e proibir contorno.
    """
    largura, altura = img.size
    px = img.load()
    saida = []
    for y in range(altura):
        for x in range(largura):
            if px[x, y][3] < LIMIAR_ALFA:
                continue
            if any(px[x + dx, y + dy][3] < LIMIAR_ALFA
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                   if 0 <= x + dx < largura and 0 <= y + dy < altura):
                continue
            saida.append((x, y))
    return saida


def assentar_valor(img, alvo):
    """Desce o V do HSV ate a MEDIANA do miolo cair no alvo. Devolve (img, ganho).

    Mediana e nao media, pela mesma razao que o laboratorio usa mediana: uma peca
    com um ponto de luz e outra lavada de claro tem a mesma media, e so uma vira
    tiro.

    Ele so DESCE. Um ganho acima de 1 clarearia arte que ja esta na faixa, e a
    faixa tem piso justamente para o icone nao sumir no piso de luma 14-16 -- mas
    quem responde por "esta escuro demais" e o portao do laboratorio, e nao um
    funil que clareia sozinho para passar num numero.
    """
    img = img.convert("RGBA")
    px = img.load()
    pontos = _miolo(img)
    if not pontos:
        return img, 1.0
    valores = sorted(max(px[x, y][:3]) / 255.0 for x, y in pontos)
    mediana = valores[len(valores) // 2]
    if mediana <= 0.0 or mediana <= alvo:
        return img, 1.0
    ganho = min(alvo / mediana, GANHO_MAXIMO)

    largura, altura = img.size
    for y in range(altura):
        for x in range(largura):
            r, g, b, alfa = px[x, y]
            if alfa == 0:
                continue
            px[x, y] = (int(round(r * ganho)), int(round(g * ganho)),
                        int(round(b * ganho)), alfa)
    return img, ganho


# ----------------------------------------------------------------- moldura ---

def moldura_de(largura, altura, lado):
    """O menor multiplo de `lado` que contem o desenho.

    E daqui que sai a escala INTEIRA da regra 1: com o desenho ocupando 250 px
    de um master de 256 e `lado` 64, a moldura e 256 e o fator e 4. Escolher a
    moldura pelo TAMANHO DO ARQUIVO em vez de pelo desenho amarraria o funil a
    256 para sempre, e a proxima moldura entraria com o numero calculado a mao.
    """
    maior = max(largura, altura, 1)
    passos = (maior + lado - 1) // lado
    return passos * lado


def enquadrar(img, lado):
    """Recorta no alfa e centraliza numa moldura quadrada. Devolve (master, bbox).

    A ANCORA E O CENTRO -- ver o cabecalho. Centro do BBOX e nao centro de massa:
    uma peca com uma haste longa de um lado puxaria a media e desenharia torta no
    slot.
    """
    img = _binarizar(img.convert("RGBA"))
    caixa = _bbox_de_alfa(img)
    if caixa is None:
        raise SystemExit("origem vazia: nao ha um pixel opaco na arte")
    recorte = img.crop(caixa)
    moldura = moldura_de(recorte.width, recorte.height, lado)
    quadro = Image.new("RGBA", (moldura, moldura), (0, 0, 0, 0))
    quadro.paste(recorte, ((moldura - recorte.width) // 2, (moldura - recorte.height) // 2))
    return quadro, caixa


def reduzir(img, lado):
    """Vizinho mais proximo, escala inteira. Nunca interpola, nunca medeia cor."""
    if img.width % lado or img.height % lado:
        raise SystemExit("moldura %dx%d nao e multipla de %d: a escala sairia fracionaria"
                         % (img.width, img.height, lado))
    return img.resize((lado, lado), Image.NEAREST)


# ------------------------------------------------------------------ limpeza ---

def _mascara(img):
    """Lista de bool por pixel: True onde ha desenho."""
    return [px[3] >= LIMIAR_ALFA for px in img.getdata()]


def _componentes(mascara, largura, altura, valor):
    """Componentes conexas (8-vizinhanca) dos pixels que valem `valor`.

    Devolve lista de listas de indices. Varredura iterativa de proposito: um
    flood recursivo em 64x64 ainda cabe, mas o mesmo codigo rodado num master de
    256 estoura a pilha do Python.
    """
    visto = [False] * (largura * altura)
    saida = []
    for inicio in range(largura * altura):
        if visto[inicio] or mascara[inicio] != valor:
            continue
        pilha = [inicio]
        visto[inicio] = True
        grupo = []
        while pilha:
            i = pilha.pop()
            grupo.append(i)
            x, y = i % largura, i // largura
            for dx, dy in VIZINHOS:
                nx, ny = x + dx, y + dy
                if nx < 0 or ny < 0 or nx >= largura or ny >= altura:
                    continue
                j = ny * largura + nx
                if not visto[j] and mascara[j] == valor:
                    visto[j] = True
                    pilha.append(j)
        saida.append(grupo)
    return saida


def _cabe_em(grupo, largura, raio):
    """O defeito cabe num quadrado de `raio` x `raio`?"""
    xs = [i % largura for i in grupo]
    ys = [i // largura for i in grupo]
    return (max(xs) - min(xs) + 1) <= raio and (max(ys) - min(ys) + 1) <= raio


def _toca_a_borda(grupo, largura, altura):
    xs = [i % largura for i in grupo]
    ys = [i // largura for i in grupo]
    return min(xs) == 0 or min(ys) == 0 or max(xs) == largura - 1 or max(ys) == altura - 1


def _cor_da_vizinhanca(dados, largura, altura, grupo):
    """A cor opaca mais frequente em volta do buraco.

    Ela vem de um pixel VIZINHO e nao de uma media: o passo de limpeza nao pode
    ser o unico do funil capaz de inventar cor. Empate desempata pela ordem da
    tupla, para o resultado ser byte a byte estavel entre execucoes.
    """
    contagem = {}
    for i in grupo:
        x, y = i % largura, i // largura
        for dx, dy in VIZINHOS:
            nx, ny = x + dx, y + dy
            if nx < 0 or ny < 0 or nx >= largura or ny >= altura:
                continue
            px = dados[ny * largura + nx]
            if px[3] >= LIMIAR_ALFA:
                contagem[px[:3]] = contagem.get(px[:3], 0) + 1
    if not contagem:
        return None
    return max(sorted(contagem), key=lambda c: contagem[c])


def limpar(img, raio):
    """Apara pixel solto e fecha buraco ENCLAUSURADO. Devolve (img, aparados, fechados).

    O gerador deixa lixo de alfa nas bordas, e num icone de 64 um pixel solto e
    1/4096 da peca -- visivel. Mas ver a regra 4: buraco que alcanca a borda do
    quadro e FUNDO, e fundo nao se fecha. E o que garante que a silhueta partida
    de proposito continue partida.
    """
    if raio <= 0:
        return img, 0, 0
    largura, altura = img.size
    dados = list(img.getdata())
    mascara = [px[3] >= LIMIAR_ALFA for px in dados]

    aparados = 0
    for grupo in _componentes(mascara, largura, altura, True):
        if not _cabe_em(grupo, largura, raio):
            continue
        for i in grupo:
            dados[i] = (0, 0, 0, 0)
            mascara[i] = False
        aparados += 1

    fechados = 0
    for grupo in _componentes(mascara, largura, altura, False):
        if _toca_a_borda(grupo, largura, altura):
            continue  # e fundo, nao buraco
        if not _cabe_em(grupo, largura, raio):
            continue
        cor = _cor_da_vizinhanca(dados, largura, altura, grupo)
        if cor is None:
            continue
        for i in grupo:
            dados[i] = cor + (255,)
            mascara[i] = True
        fechados += 1

    fora = Image.new("RGBA", img.size)
    fora.putdata(dados)
    return fora, aparados, fechados


# --------------------------------------------------------------- relatorio ---

def _pecas(img, raio):
    """Quantas manchas de desenho a peca tem, ignorando o que e lixo por tamanho."""
    largura, altura = img.size
    grupos = _componentes(_mascara(img), largura, altura, True)
    return sum(1 for g in grupos if not _cabe_em(g, largura, raio)), len(grupos)


def _alfa_parcial(img):
    return sum(1 for px in img.getdata() if 0 < px[3] < 255)


def relatorio(id_item, origem, mestre, final, medidas, raio):
    linhas = []
    tudo = [True]

    def checa(ok, texto):
        linhas.append(("  [ok]  " if ok else "  [XX]  ") + texto)
        tudo[0] &= bool(ok)

    def informa(texto):
        linhas.append("  [--]  " + texto)

    paleta_fonte = set(_paleta_de(mestre))
    paleta_final = set(_paleta_de(final))
    novas = sorted(paleta_final - paleta_fonte)

    fator = mestre.width // final.width
    pecas_antes, brutas_antes = medidas["pecas_antes"]
    pecas_depois, brutas_depois = medidas["pecas_depois"]
    opacos = sum(1 for px in final.getdata() if px[3] >= LIMIAR_ALFA)

    if medidas.get("fundo") is not None:
        # O recorte e informativo e nao portao: nao existe fracao "certa" de
        # fundo -- ela e diferente numa peca alta e numa peca larga. Quem
        # reprova recorte que comeu desenho e a contagem de PECAS, logo abaixo.
        informa("fundo %s recortado: %.1f%% do quadro"
                % (str(medidas["fundo"]), 100.0 * medidas["chaveados"]
                   / float(mestre.width * mestre.height)))
    if medidas.get("ganho", 1.0) != 1.0:
        informa("valor do miolo assentado: ganho %.3f" % medidas["ganho"])
    if medidas.get("sombra"):
        informa("sombra projetada corroida: %d px" % medidas["sombra"])

    checa(mestre.width == mestre.height and final.width == final.height,
          "moldura quadrada: master %dx%d, final %dx%d"
          % (mestre.width, mestre.height, final.width, final.height))
    checa(mestre.width % final.width == 0,
          "escala inteira: %d / %d = %dx (vizinho mais proximo)"
          % (mestre.width, final.width, fator))
    checa(not novas, "nenhuma cor nova: %d cores no master, %d no final (inventadas: %d)"
          % (len(paleta_fonte), len(paleta_final), len(novas)))
    checa(medidas["grudados"] == 0,
          "pixels grudados na paleta: %d (zero e o saudavel; ver regra 2)"
          % medidas["grudados"])
    checa(_alfa_parcial(final) == 0, "alfa so 0 ou 255 (parciais: %d)" % _alfa_parcial(final))
    checa(pecas_antes == pecas_depois,
          "a silhueta continua com %d peca(s): a limpeza nao soldou nem apagou nenhuma"
          % pecas_depois)
    informa("limpeza raio %d: %d pixel(s) solto(s) aparado(s), %d buraco(s) fechado(s)"
            % (raio, medidas["aparados"], medidas["fechados"]))
    informa("manchas brutas: %d antes, %d depois (as de %dx%d ou menos contam como lixo)"
            % (brutas_antes, brutas_depois, raio, raio))
    informa("ocupacao do quadro: %.1f%% (%d de %d px)"
            % (100.0 * opacos / (final.width * final.height), opacos, final.width * final.height))

    print("icone_%s  <- %s" % (id_item, origem))
    for l in linhas:
        print(l)
    if novas:
        print("         cores inventadas: %s" % ", ".join("#%02X%02X%02X" % c for c in novas[:8]))
    return tudo[0]


# --------------------------------------------------------------------- cli ---

def _recusar_reprocesso(origem, img, lado):
    """A regra 5, com a deteccao que da para fazer barato."""
    pasta = os.path.abspath(os.path.dirname(os.path.abspath(origem)))
    if pasta == os.path.abspath(SAIDA):
        raise SystemExit("RECUSADO: a origem esta em assets/itens/ -- isso e o icone JA PRONTO.\n"
                         "           Reprocessar come detalhe (medido: densidade de 16,4%% para "
                         "8,1%%).\n"
                         "           Use o master em %s." % MESTRE)
    if img.width <= lado or img.height <= lado:
        raise SystemExit("RECUSADO: a origem tem %dx%d e o final tem %d -- nao ha o que reduzir.\n"
                         "           Isto e o icone pronto, e nao a arte de %d que sai do "
                         "PixelLab." % (img.width, img.height, lado, lado * 4))


def main(argv=None):
    p = argparse.ArgumentParser(
        prog="preparar_icone.py",
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("id", help="id do implante, sem prefixo (ex.: nucleo, fragmentador)")
    p.add_argument("origem", nargs="?", default=None,
                   help="PNG de 256 com alfa; default e o master ja versionado em "
                        "tools/art_sources/itens/")
    p.add_argument("--lado", type=int, default=LADO_PADRAO, metavar="N",
                   help="lado do icone final (default %d). A moldura do master vira o "
                        "menor multiplo dele que contem o desenho, para a reducao ser "
                        "inteira." % LADO_PADRAO)
    p.add_argument("--tolerancia", type=int, default=TOLERANCIA_PADRAO, metavar="T",
                   help="distancia L1 de RGB que o recorte de fundo aceita como fundo "
                        "(default %d). O PixelLab devolve a arte OPACA com o fundo "
                        "chapado em dois tons quase iguais; %d e o meio do plato medido "
                        "nos 16 masters do andar 1. Zero desliga o recorte, para arte que "
                        "ja chega com alfa." % (TOLERANCIA_PADRAO, TOLERANCIA_PADRAO))
    p.add_argument("--alvo-valor", type=float, default=ALVO_VALOR_MIOLO, metavar="V",
                   help="desce o V do HSV ate a mediana do MIOLO cair em V "
                        "(default %.2f, o meio da faixa que o laboratorio cobra). "
                        "So desce, nunca clareia, e nunca toca matiz nem saturacao. "
                        "Zero desliga." % ALVO_VALOR_MIOLO)
    p.add_argument("--vazar-furos", action="store_true",
                   help="apaga tambem o fundo CERCADO pelo desenho -- o miolo de um "
                        "anel, que senao sai como um disco opaco da cor do fundo. "
                        "DESLIGADO por default: ele compara por COR, e num master cujo "
                        "fundo esta perto da paleta do objeto isso abre buraco no corpo "
                        "da peca. Ligue so onde ha furo de verdade.")
    p.add_argument("--tirar-sombra", action="store_true",
                   help="corroi a sombra projetada que sobrou encostada na peca. "
                        "DESLIGADO por default de proposito: os mesmos criterios "
                        "descrevem tambem juntas de aco e agulhas, e a bandeira ligada "
                        "sem conferir come detalhe. Ligue peca a peca, olhando.")
    p.add_argument("--raio-limpeza", type=int, default=RAIO_LIMPEZA_PADRAO, metavar="R",
                   help="trata so o defeito que cabe num quadrado de R x R (default %d: "
                        "pixel solto e buraco de 1 px). Buraco que alcanca a borda e FUNDO "
                        "e nunca e fechado -- e o que impede a limpeza de soldar uma "
                        "silhueta partida de proposito, como a do fragmentador. Suba com "
                        "medida na mao." % RAIO_LIMPEZA_PADRAO)

    a = p.parse_args(argv)
    if a.lado <= 0:
        raise SystemExit("--lado tem de ser positivo")

    origem = a.origem or os.path.join(MESTRE, "icone_%s.png" % a.id)
    if not os.path.isfile(origem):
        raise SystemExit("origem nao existe: %s" % origem)

    bruta = Image.open(origem)
    _recusar_reprocesso(origem, bruta, a.lado)
    if bruta.width != bruta.height:
        print("  aviso: origem %dx%d nao e quadrada -- a moldura cresce para o maior lado"
              % (bruta.width, bruta.height))

    # O recorte vem ANTES do enquadramento, e a ordem e o contrato: `enquadrar()`
    # mede o bbox do ALFA, e sem este passo a arte do PixelLab e opaca de ponta a
    # ponta -- o bbox seria o quadro inteiro e o icone sairia com a moldura de
    # fundo colada, sem uma linha de erro.
    if a.tolerancia > 0:
        bruta, fundo, chaveados = chavear_fundo(bruta, a.tolerancia, a.vazar_furos)
    else:
        fundo, chaveados = None, 0
    sombra = 0
    if a.tirar_sombra:
        bruta, sombra = tirar_sombra(bruta)

    mestre, _caixa = enquadrar(bruta, a.lado)
    # O assentamento vem ANTES da reducao e antes da colagem: o master gravado ja
    # e o corrigido, entao `_paleta_de(mestre)` descreve a arte que o jogo recebe
    # e o portao de "nenhuma cor nova" continua valendo.
    mestre, ganho = assentar_valor(mestre, a.alvo_valor) if a.alvo_valor > 0 else (mestre, 1.0)
    reduzido = reduzir(mestre, a.lado)
    # A colagem e rede e nao cirurgia (regra 2): com vizinho mais proximo ela nao
    # tem o que mover, e o relatorio cobra que ela realmente nao moveu.
    colado = _grudar_na_paleta(reduzido, _paleta_de(mestre))
    grudados = sum(1 for a1, b1 in zip(reduzido.getdata(), colado.getdata()) if a1 != b1)

    pecas_antes = _pecas(colado, a.raio_limpeza)
    final, aparados, fechados = limpar(colado, a.raio_limpeza)
    pecas_depois = _pecas(final, a.raio_limpeza)

    os.makedirs(MESTRE, exist_ok=True)
    os.makedirs(SAIDA, exist_ok=True)
    caminho_mestre = os.path.join(MESTRE, "icone_%s.png" % a.id)
    caminho_final = os.path.join(SAIDA, "icone_%s.png" % a.id)
    mestre.save(caminho_mestre)
    final.save(caminho_final)
    print("escrito: %s  (master %dx%d)" % (caminho_mestre, mestre.width, mestre.height))
    print("escrito: %s  (final %dx%d)" % (caminho_final, final.width, final.height))

    ok = relatorio(a.id, origem, mestre, final, {
        "grudados": grudados,
        "aparados": aparados,
        "fechados": fechados,
        "pecas_antes": pecas_antes,
        "pecas_depois": pecas_depois,
        "fundo": fundo,
        "chaveados": chaveados,
        "sombra": sombra,
        "ganho": ganho,
    }, a.raio_limpeza)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
