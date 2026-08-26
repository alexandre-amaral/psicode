# -*- coding: utf-8 -*-
"""Prepara e confere textura de mapa AUTORADA.

Ate a v0.2 toda textura do mapa nascia de codigo (`gerar_texturas.gd`), e isso
dava duas garantias de graca: todo pixel vinha da paleta porque o gerador so
sabia escrever a paleta, e todo tile ladrilhava porque `_pintar()` fazia
`posmod`. Arte autorada nao tem nenhuma das duas.

Esta ferramenta e o que devolve as duas garantias. Ela NAO e a fonte da textura
-- a fonte e o PNG, do mesmo jeito que a fonte dos sprites de personagem sao os
GIFs e nao `gerar_sprites.py`. Ela e o funil por onde a arte passa antes de
entrar no jogo.

O que ela faz, nesta ordem e por este motivo:

1. **Costura.** Mistura a imagem com uma copia deslocada de meia imagem, com
   peso que zera nas bordas. Na borda o pixel passa a ser o do meio da imagem,
   e o pixel do outro lado da borda tambem -- entao os dois se encontram
   continuos. Custa borrar a periferia em troca de ladrilhar, e para MATERIAL
   (que e o que um tile tem de ser) essa troca e boa.

2. **Reducao.** Para o lado alvo, por area. Depois disso nao ha mais
   reamostragem: o jogo usa filtro Nearest e escala inteira.

3. **Gamut.** Clampa V ao teto da familia, clampa S e puxa o matiz para a faixa.
   Com `recraft_v4_1` recebendo a rampa em `colors`, isto e rede de seguranca e
   nao cirurgia -- se estiver cortando muito, o problema esta no prompt.

4. **Alpha cravado em 0 ou 1.** Ferramenta de arte produz antialias por default,
   e o portao do projeto recusa alpha parcial.

E ela CONFERE, que e metade do ponto: costura, densidade, gamut, teto de valor e
faixa de matiz saem medidos, nao afirmados.

Uso:
    python tools/texturas/preparar_textura.py preparar ORIGEM DESTINO --familia chao
    python tools/texturas/preparar_textura.py conferir assets/texturas/chao_andar1_a.png
    python tools/texturas/preparar_textura.py conferir assets/texturas/ --familia chao
"""
import argparse
import colorsys
import os
import sys

try:
    import numpy as np
except ImportError:
    sys.exit("Precisa do numpy:  pip install numpy")
try:
    from PIL import Image, ImageFilter
except ImportError:
    sys.exit("Precisa do Pillow:  pip install Pillow")


# ---------------------------------------------------------------- familias ---
# Os tetos NAO sao gosto. O chao para em 0,30 porque ator tem piso de V 0,55 no
# portao G2, e como o andar 1 abandonou a separacao por MATIZ (o chao foi para o
# azul, que e a familia de seis projeteis do jogo), o valor virou a unica
# separacao que sobrou -- e ela precisa ser folgada.
#
# A parede pode ir a 0,50 porque e moldura: ela tem de vencer o chao para dizer
# onde a sala termina, e desde que o filete de neon saiu ela e a unica coisa que
# diz isso.
#
# O decalque e MAIS apertado que o prop, e isso e contraintuitivo de proposito:
# ele vive no miolo, onde o combate acontece, enquanto o prop vive na margem
# calma. Um reflexo claro no meio da sala e um campo claro sob os projeteis.
#
# `ganho_v` e exposicao, e ele existe porque TETO NAO ESCURECE. Medido: variar o
# teto do chao de 0,30 a 0,18 nao mexeu na mediana (0,169 nos dois), porque o
# corte so alcanca os pixels mais claros. O que muda o quanto o chao pesa na
# tela e multiplicar o valor, nao apara-lo.
#
# O alvo do chao e V mediano ~0,12: o chao antigo era 0,09 (seguro e vazio) e a
# arte crua chega em 0,17 (rica e disputando com o projetil). O ganho poe a
# textura entre os dois, mais perto do seguro.
# `alvo_v` e a MEDIANA de valor que a textura deve ter, e nao um multiplicador.
#
# Multiplicador fixo so funciona se toda geracao nascer com o mesmo brilho, e nao
# nasce: a rampa ambar do andar 1 saiu bem mais escura que a azul, e o mesmo
# ganho de 0,70 derrubou o chao de arma para V 0,05 com 159 cores -- escuro
# demais para ter textura. Mirando a mediana, o funil compensa sozinho o quao
# clara a arte chegou.
#
# Chao em 0,12 e parede em 0,30: a parede tem de vencer o chao porque e ela que
# diz onde a sala termina, e desde que o filete saiu ela e a unica coisa que diz.
FAMILIAS = {
    "chao":     {"teto_v": 0.30, "alvo_v": 0.12, "teto_s": 0.95, "densidade": (0.08, 0.18)},
    "parede":   {"teto_v": 0.50, "alvo_v": 0.30, "teto_s": 0.95, "densidade": (0.18, 0.34)},
    "decalque": {"teto_v": 0.19, "alvo_v": 0.10, "teto_s": 0.95, "densidade": (0.00, 1.00)},
    "livre":    {"teto_v": 0.55, "alvo_v": 0.00, "teto_s": 0.95, "densidade": (0.00, 1.00)},
}

## Quanto a faixa de matiz e apertada NA HORA DE ESCREVER, para sobrar folga
## contra o arredondamento de 8 bits.
##
## O portao confere a faixa cheia. Sem esta margem, uma cor grampeada exatamente
## em 330 sai do conversor HSV->RGB->uint8 medindo 328, e a textura reprova por
## dois graus que nao sao dela -- sao do formato. Nesses valores escuros os
## canais estao na casa de 10 a 40, e um passo de 1/255 gira o matiz varios
## graus.
MARGEM_MATIZ = 3.0

# A faixa de matiz e do TIPO DE SALA, nao da familia -- e o que faz a sala do
# chefe se anunciar de longe sem o andar deixar de ser um lugar so. Sai das
# rampas ACENTOS de tools/texturas/paleta.gd, rebaixadas: `cor_mapa` puro nunca
# e pintado no mundo.
#
# O corredor NAO entra aqui. Ele fica na noite base de proposito: pintar cada
# metade com a cor da sala vizinha anunciaria o que ha do outro lado antes de o
# jogador chegar.
#
# A faixa do ANDAR 1 e larga -- 135 graus contra os 25 a 30 das outras -- e isso
# e deliberado. O que ela separa e TIPO DE SALA, e nao mapa de ator: quem faz a
# segunda separacao e o teto de valor logo acima (chao em 0,30 contra o piso de
# 0,55 do portao G2), justamente porque o andar 1 ja abriu mao do matiz ao ir
# para o azul, que e a familia de seis projeteis do jogo.
#
# Alargar veio da arte: as tres referencias de piso trazem acento ciano (~180) e
# magenta (~320), e a faixa antiga de 200-250 os grampeava nos dois em azul --
# o acento sobrevivia como brilho, mas perdia o vocabulario cyberpunk que fez
# escolherem essas imagens. Como o teto de valor nao mudou, alargar nao aproxima
# o chao de projetil nenhum: um pixel de piso continua no maximo a 0,30 de
# valor, e ator comeca em 0,55.
#
# Os limites nao sao redondos por acaso: 185 fica 5 graus acima do teto do item
# (180) e 320 fica 10 abaixo do piso do chefe (330). As tres faixas continuam
# disjuntas, que e o que faz a sala de recompensa e a do chefe se anunciarem.
MATIZ_POR_TIPO = {
    "andar1": (185, 320),   # a base: combate e inicial
    "boss":   (330, 355),
    "arma":   (25, 50),
    "item":   (150, 180),
}

# A sala do chefe leva teto mais baixo que as outras, e nao e capricho: e a sala
# mais densa de projetil do jogo, e o matiz dela e vizinho do `tiro_diretora`
# (336 graus). Como o andar 1 abriu mao da separacao por matiz, sobrou o valor --
# e no lugar onde ele mais importa vale compra-lo mais folgado.
#
# Arma e item nao precisam: sao salas de recompensa, sem combate.
TETO_POR_TIPO = {
    "boss": {"chao": 0.24},
}

## Teto da razao de costura, CALIBRADO e nao chutado. Medido em tres regimes:
##
##   textura gerada com posmod, que ladrilha    0.14 a 0.42
##   saida de costurar()                        0.22 a 0.95
##   arte crua, que nao ladrilha                ate 1.47
##
## A validacao mais forte e que a metrica aprova as texturas geradas com
## `posmod`, que ladrilham por construcao e portanto sao gabarito conhecido.
LIMITE_COSTURA = 1.10

## Abaixo deste valor o matiz de um pixel de 8 bits e ruido de arredondamento.
PISO_MATIZ_LEGIVEL = 0.06

## Diferenca de canal que conta como "detalhe". Absoluto e igual ao do apendice
## de docs/TEXTURAS_ANDAR_1.md, para os numeros continuarem comparaveis com os
## que ja estao escritos la.
##
## DENSIDADE E INFORMATIVA, NAO E PORTAO -- e vale registrar por que, porque a
## tentacao de trava-la e forte.
##
## Ela nao e invariante a exposicao: escurecer a textura comprime as diferencas
## de canal, e a mesma estrutura passa a medir menos (baixar o ganho do chao de
## 1,0 para 0,7 levou 8,4% a 4,2% sem tirar um traco do desenho). Tentei prender
## o limiar a amplitude da propria imagem para corrigir isso, e ficou pior: numa
## textura escura a amplitude e pequena, o limiar cai ao piso e a medicao passa a
## contar ruido de arredondamento -- o mesmo chao media 66% de "detalhe".
##
## Uma trava em que nao se confia empurra a arte para o lado errado com a
## autoridade de um numero. Entao o numero sai medido e fica ao lado dos outros,
## para quem estiver desenhando comparar com a referencia e com o que ja existe,
## e a decisao continua sendo de quem olha.
LIMIAR_DETALHE = 24


# ------------------------------------------------------------------ helpers --

def _rgb_para_hsv(a):
    """a: (H,W,3) em 0..1 -> h em graus, s e v em 0..1."""
    mx = a.max(axis=2)
    mn = a.min(axis=2)
    d = mx - mn
    v = mx
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0)
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    h = np.zeros_like(v)
    nz = d > 1e-6
    i = (mx == r) & nz
    h[i] = ((g - b)[i] / d[i]) % 6
    i = (mx == g) & nz
    h[i] = ((b - r)[i] / d[i]) + 2
    i = (mx == b) & nz
    h[i] = ((r - g)[i] / d[i]) + 4
    return h * 60.0, s, v


def _hsv_para_rgb(h, s, v):
    saida = np.zeros(h.shape + (3,), dtype=float)
    it = np.nditer(h, flags=["multi_index"])
    for _ in it:
        idx = it.multi_index
        saida[idx] = colorsys.hsv_to_rgb((h[idx] % 360.0) / 360.0, s[idx], v[idx])
    return saida


def _abrir(caminho):
    im = Image.open(caminho).convert("RGBA")
    return im


def _canais(im):
    a = np.asarray(im).astype(float) / 255.0
    return a[:, :, :3], a[:, :, 3]


# ----------------------------------------------------------------- pre-passo --
# O funil abaixo e rede de SEGURANCA: ele apara o que passou do limite. As duas
# funcoes daqui sao o contrario -- elas ADICIONAM o que a arte nao trouxe, e por
# isso ficam separadas e desligadas por default. Textura que ja nasceu na paleta
# nao deve passar por nenhuma delas.
#
# Elas existem porque as tres referencias de piso do andar 1 sao fotografia de
# metal: quase cinza e com vinheta. Passadas cruas pelo funil, saem CINZA -- o
# `teto_s` apara saturacao, nunca levanta -- e o andar perde a noite azul que e a
# identidade dele.


def desvinhetar(im):
    """Divide a imagem pelo proprio borrao: mata gradiente de iluminacao global.

    Arte gerada costuma vir com o centro aceso e os cantos apagados, o que e
    bonito emoldurado e pessimo em ladrilho: a vinheta vira uma CRUZ escura na
    junta, repetida por toda a sala. Dividir pelo borrao e normalizar pela media
    devolve a mesma imagem com iluminacao chapada, sem tocar no detalhe fino --
    que e o que sobrevive a divisao por um borrao largo.
    """
    a = np.asarray(im.convert("RGBA")).astype(float)
    rgb = a[:, :, :3]
    borrao = np.asarray(
        Image.fromarray(rgb.round().astype(np.uint8)).filter(ImageFilter.GaussianBlur(45)),
        dtype=float,
    )
    a[:, :, :3] = np.clip(rgb * (borrao.mean() / np.maximum(borrao, 1.0)), 0.0, 255.0)
    return Image.fromarray(a.round().astype(np.uint8), "RGBA")


def tingir(im, graus, limiar_neon, alvo_s):
    """Puxa o METAL para um matiz so, e deixa o ACENTO ACESO passar intacto.

    O limiar e a peca inteira. Levantar saturacao em tudo pintaria tambem o
    ruido quase-cinza -- que tem matiz aleatorio, porque em S perto de zero o
    matiz e so arredondamento -- e o piso viraria confete colorido. Separando
    por saturacao, o metal apagado vira a noite azul do andar e o neon que o
    artista acendeu continua sendo a cor que ele escolheu.

    A mistura do metal e ponderada e nao cravada (0,3 do que veio, 0,7 do alvo):
    cravar a saturacao apagaria a diferenca entre placa e junta, que e o que da
    materia ao piso.
    """
    a = np.asarray(im.convert("RGBA")).astype(float)
    rgb = a[:, :, :3] / 255.0
    h, s, v = _rgb_para_hsv(rgb)

    aceso = s >= limiar_neon
    h = np.where(aceso, h, float(graus))
    s = np.where(aceso, s, np.clip(s * 0.3 + alvo_s * 0.7, 0.0, 0.95))

    a[:, :, :3] = np.clip(_hsv_para_rgb(h, s, v), 0.0, 1.0) * 255.0
    return Image.fromarray(a.round().astype(np.uint8), "RGBA")


def grampear_matiz(im, lo, hi):
    """Grampeia o matiz ANTES do funil, com folga maior que MARGEM_MATIZ.

    O funil ja grampeia, mas ele e a ultima etapa antes do disco: o que sai dele
    ainda passa por HSV->RGB->uint8, e nesses valores escuros um passo de 1/255
    gira o matiz varios graus. Com acento muito saturado os 3 graus de
    MARGEM_MATIZ nao bastam -- medido: a referencia simetrica saiu em 180-322
    contra uma faixa de 185-320. Grampear mais cedo e mais folgado poe a margem
    onde ela cabe.
    """
    a = np.asarray(im.convert("RGBA")).astype(float)
    rgb = a[:, :, :3] / 255.0
    h, s, v = _rgb_para_hsv(rgb)
    a[:, :, :3] = np.clip(_hsv_para_rgb(np.clip(h, lo, hi), s, v), 0.0, 1.0) * 255.0
    return Image.fromarray(a.round().astype(np.uint8), "RGBA")


# ------------------------------------------------------------------ costura --

def costurar(im):
    """Mistura a imagem com uma copia deslocada de meia imagem.

    O peso e 0 na borda e 1 no centro, entao o pixel da borda passa a ser
    exatamente o pixel do MEIO da copia deslocada -- e o pixel do outro lado da
    borda, que na copia deslocada e o vizinho dele, tambem. Os dois se encontram
    continuos, que e a definicao de ladrilhar.
    """
    a = np.asarray(im).astype(float)
    h, w = a.shape[:2]
    deslocada = np.roll(np.roll(a, w // 2, axis=1), h // 2, axis=0)

    x = np.arange(w)
    y = np.arange(h)
    # Distancia normalizada ate a borda mais proxima, 0 na borda e 1 no centro.
    dx = np.minimum(x, w - 1 - x) / max(w / 2.0 - 1.0, 1.0)
    dy = np.minimum(y, h - 1 - y) / max(h / 2.0 - 1.0, 1.0)
    d = np.minimum(dx[None, :], dy[:, None])
    # Suaviza a transicao: rampa linear deixa uma marca reta visivel.
    t = np.clip(d, 0.0, 1.0)
    t = t * t * (3.0 - 2.0 * t)

    misturada = a * t[:, :, None] + deslocada * (1.0 - t[:, :, None])
    return Image.fromarray(misturada.round().astype(np.uint8), "RGBA")


def medir_costura(im):
    """Quanto a junta do ladrilho destoa das transicoes que a textura ja tem.

    Ladrilha 2x2 em memoria e mede a energia de borda nas duas juntas internas.

    O denominador e o PERCENTIL 95 das transicoes internas, e nao a mediana --
    isso foi um erro que custou uma medicao errada. Num material quase liso a
    mediana e zero, entao qualquer linha de placa de 1 px que caia sobre a junta
    aparece como razao 10x e a textura, que ladrilhava perfeitamente, era
    reprovada. O que se quer saber nao e "ha uma borda na junta" -- muitas vezes
    ha, e de proposito, porque a grade de placas atravessa o ladrilho. O que se
    quer saber e se a junta cria um tipo de borda que a textura nao tem em
    lugar nenhum.
    """
    rgb, _ = _canais(im)
    a = rgb * 255.0
    h, w = a.shape[:2]

    def energia(u, v):
        return float(np.abs(u - v).sum(axis=-1).mean())

    # A junta do ladrilho: a ultima coluna encontra a primeira.
    junta_x = energia(a[:, w - 1], a[:, 0])
    junta_y = energia(a[h - 1, :], a[0, :])

    internas_x = [energia(a[:, i], a[:, i + 1]) for i in range(w - 1)]
    internas_y = [energia(a[i, :], a[i + 1, :]) for i in range(h - 1)]
    # O denominador e o MAXIMO, e nao um percentil. A pergunta que a metrica
    # responde passa a ser exatamente esta: "a junta cria uma borda mais forte
    # do que qualquer borda que a textura ja tem?".
    #
    # Cheguei aqui por eliminacao, e vale registrar as duas tentativas antes.
    # Com mediana, uma grade de placas media 10x e reprovava textura que
    # ladrilha perfeitamente. Com percentil 99 melhorou, mas ainda reprovava
    # parede estruturada passada por `costurar()` -- e ali o falso positivo e
    # demonstravel, porque `costurar()` GARANTE que a ultima coluna e a primeira
    # sao colunas adjacentes do original. Quando a trava reprova o que a
    # construcao prova, a trava e que esta errada.
    #
    # A validacao do maximo e o gabarito: `chao_combate.png`, seamless por
    # construcao (o gerador faz `posmod` em toda escrita), mede 0,33/0,40 -- e
    # `chao_andar1_a`, autorada e costurada, mede os mesmos 0,33/0,40.
    ref_x = float(np.max(internas_x)) if internas_x else 1.0
    ref_y = float(np.max(internas_y)) if internas_y else 1.0

    # Piso no denominador: textura totalmente chapada tem referencia zero, e
    # dividir por zero transformaria "sem borda nenhuma" em falha.
    return (junta_x / max(ref_x, 1.0), junta_y / max(ref_y, 1.0))


# -------------------------------------------------------------------- gamut --

def regra_de(familia, tipo):
    """Junta a familia (o que a superficie e) com o tipo (de que sala ela e)."""
    regra = dict(FAMILIAS[familia])
    regra["matiz"] = MATIZ_POR_TIPO.get(tipo) if familia != "livre" else None
    regra["teto_v"] = TETO_POR_TIPO.get(tipo, {}).get(familia, regra["teto_v"])
    return regra


def forcar_gamut(im, familia, tipo="andar1"):
    regra = regra_de(familia, tipo)
    rgb, alpha = _canais(im)
    h, s, v = _rgb_para_hsv(rgb)

    alvo: float = regra.get("alvo_v", 0.0)
    if alvo > 0.0:
        atual = float(np.median(v[alpha > 0.5])) if (alpha > 0.5).any() else 0.0
        if atual > 1e-4:
            v = v * (alvo / atual)
    v = np.minimum(v, regra["teto_v"])
    s = np.minimum(s, regra["teto_s"])
    if regra["matiz"] is not None:
        lo, hi = regra["matiz"]
        # Puxa para a faixa em vez de cortar: cor fora dela vira a borda mais
        # proxima, o que preserva a intencao do artista sem sair da familia.
        h = np.clip(h, lo + MARGEM_MATIZ, hi - MARGEM_MATIZ)

    novo = _hsv_para_rgb(h, s, v)
    saida = np.concatenate([novo, alpha[:, :, None]], axis=2)
    saida = (np.clip(saida, 0.0, 1.0) * 255.0).round().astype(np.uint8)
    return Image.fromarray(saida, "RGBA")


def cravar_alpha(im):
    a = np.asarray(im).astype(np.uint8).copy()
    a[:, :, 3] = np.where(a[:, :, 3] >= 128, 255, 0)
    return Image.fromarray(a, "RGBA")


# ---------------------------------------------------------------- medicoes ---

def medir_densidade(im):
    rgb, _ = _canais(im)
    a = (rgb * 255.0).astype(int)
    d = np.zeros(a.shape[:2], bool)
    for dy, dx in ((0, 1), (1, 0)):
        viz = np.roll(np.roll(a, dy, axis=0), dx, axis=1)
        d |= np.abs(a - viz).sum(axis=2) > LIMIAR_DETALHE
    return float(d.mean())


def medir_gamut(im):
    rgb, alpha = _canais(im)
    h, s, v = _rgb_para_hsv(rgb)
    op = alpha > 0.5
    if not op.any():
        return {"opacos": 0}
    # G2 do projeto: AMBIENTE nao pode ser saturado E claro ao mesmo tempo.
    compete = (s > 0.35) & (v > 0.55) & op
    legivel = op & (s > 0.05) & (v > PISO_MATIZ_LEGIVEL)
    parcial = ((alpha > 0.004) & (alpha < 0.996)).sum()
    return {
        "opacos": int(op.sum()),
        "compete": int(compete.sum()),
        "alpha_parcial": int(parcial),
        "v_max": float(v[op].max()),
        "v_mediano": float(np.median(v[op])),
        "s_mediano": float(np.median(s[op])),
        # Matiz so e medido onde ele significa alguma coisa. Abaixo de V 0,06 um
        # pixel tem canais na casa de 0..15, e um arredondamento de 1/255 gira o
        # matiz em dezenas de graus -- medir ali e medir o ruido do 8 bits, nao a
        # cor. Custou uma reprovacao falsa no piloto: 8% dos pixels mais escuros
        # diziam 210-260 enquanto os 92% restantes diziam 231-247.
        "matiz_min": float(h[legivel].min()) if legivel.any() else 0.0,
        "matiz_max": float(h[legivel].max()) if legivel.any() else 0.0,
        "cores": len(set(map(tuple, (rgb[op] * 255).round().astype(int)))),
    }


def conferir(caminho, familia, tipo="andar1"):
    im = _abrir(caminho)
    regra = regra_de(familia, tipo)
    g = medir_gamut(im)
    dens = medir_densidade(im)
    cx, cy = medir_costura(im)
    w, hh = im.size

    linhas = []
    def checa(ok, texto):
        linhas.append(("  [ok]  " if ok else "  [XX]  ") + texto)
        return ok

    tudo = True
    tudo &= checa(w % 16 == 0 and hh % 16 == 0, "grade: %dx%d, multiplo de 16" % (w, hh))
    tudo &= checa(g.get("alpha_parcial", 0) == 0, "alpha so 0 ou 1 (parciais: %d)" % g.get("alpha_parcial", 0))
    tudo &= checa(g.get("compete", 1) == 0, "nenhum pixel compete com ator (%d)" % g.get("compete", 0))
    tudo &= checa(g["v_max"] <= regra["teto_v"] + 0.004,
                  "teto de valor: max %.3f <= %.2f" % (g["v_max"], regra["teto_v"]))
    if regra["matiz"] is not None:
        lo, hi = regra["matiz"]
        dentro = g["matiz_min"] >= lo - 1 and g["matiz_max"] <= hi + 1
        tudo &= checa(dentro, "matiz na faixa %d-%d (achado %.0f-%.0f)" % (lo, hi, g["matiz_min"], g["matiz_max"]))
    lo_d, hi_d = regra["densidade"]
    dentro = "dentro" if lo_d <= dens <= hi_d else "FORA"
    linhas.append("  [--]  densidade %.1f%% (%s da faixa %.0f-%.0f%%, informativo)"
                  % (100 * dens, dentro, 100 * lo_d, 100 * hi_d))
    tudo &= checa(cx <= LIMITE_COSTURA and cy <= LIMITE_COSTURA,
                  "costura x=%.2f y=%.2f (teto %.2f)" % (cx, cy, LIMITE_COSTURA))

    print("%s  [%s / %s]" % (os.path.basename(caminho), familia, tipo))
    for l in linhas:
        print(l)
    print("         %d cores, V mediano %.2f, S mediano %.2f" % (g["cores"], g["v_mediano"], g["s_mediano"]))
    return tudo


# --------------------------------------------------------------------- cli ---

def _familia_do_nome(nome):
    base = os.path.basename(nome)
    for f in ("chao", "parede", "decalque"):
        if base.startswith(f):
            return f
    return "livre"


def _tipo_do_nome(nome):
    """`chao_boss.png` -> boss; `chao_andar1_c.png` -> andar1; resto -> andar1.

    O nome do arquivo carrega familia E tipo, e nao ha segunda fonte: um flag de
    linha de comando esquecido produziria uma textura fora da faixa que so
    apareceria no portao, depois de gerada.
    """
    base = os.path.basename(nome)
    for tipo in MATIZ_POR_TIPO:
        if ("_%s." % tipo) in base or ("_%s_" % tipo) in base:
            return tipo
    return "andar1"


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="acao", required=True)

    pr = sub.add_parser("preparar")
    pr.add_argument("origem")
    pr.add_argument("destino")
    pr.add_argument("--familia", choices=list(FAMILIAS), default=None)
    pr.add_argument("--tipo", choices=list(MATIZ_POR_TIPO), default=None)
    pr.add_argument("--lado", type=int, default=256)
    pr.add_argument("--sem-costura", action="store_true",
                    help="pula a costura (para arte que ja nasceu ladrilhavel)")
    # Pre-passo: DESLIGADO por default, para nenhuma textura ja preparada mudar
    # de comportamento se alguem reprocessar. Ver o bloco "pre-passo" acima.
    pr.add_argument("--desvinheta", action="store_true",
                    help="chapa a iluminacao global antes de costurar")
    pr.add_argument("--tingir", type=float, default=None, metavar="GRAUS",
                    help="matiz do metal base; o pixel aceso passa intacto")
    pr.add_argument("--limiar-neon", type=float, default=0.30, metavar="S",
                    help="acima desta saturacao o pixel e acento e nao e tingido")
    pr.add_argument("--saturacao", type=float, default=0.78, metavar="S",
                    help="alvo de saturacao do metal base, com --tingir")
    pr.add_argument("--grampear-matiz", nargs=2, type=float, default=None,
                    metavar=("LO", "HI"),
                    help="grampeia o matiz na origem, com folga maior que a do funil")
    pr.add_argument("--alvo-v", type=float, default=None, metavar="V",
                    help="sobrescreve a mediana de valor alvo da familia")

    cf = sub.add_parser("conferir")
    cf.add_argument("alvo")
    cf.add_argument("--familia", choices=list(FAMILIAS), default=None)
    cf.add_argument("--tipo", choices=list(MATIZ_POR_TIPO), default=None)

    a = p.parse_args()

    if a.acao == "preparar":
        familia = a.familia or _familia_do_nome(a.destino)
        tipo = a.tipo or _tipo_do_nome(a.destino)
        im = _abrir(a.origem)
        print("origem: %dx%d  ->  familia '%s', tipo '%s', lado %d" % (im.size[0], im.size[1], familia, tipo, a.lado))
        # Reduz ANTES de costurar, e a ordem importa: costurar em 1024 e reduzir
        # depois nao sobrevive a reamostragem. Medido no piloto -- a junta em y
        # saiu de 0,28 para 1,27 so por causa do BOX. A costura tem de ser feita
        # nos pixels que vao para o disco.
        if im.size != (a.lado, a.lado):
            im = im.resize((a.lado, a.lado), Image.BOX)
        # O pre-passo vem ANTES da costura: costurar mistura a periferia com a
        # copia deslocada, entao desvinhetar depois dela espalharia a vinheta em
        # vez de apaga-la.
        if a.desvinheta:
            im = desvinhetar(im)
        if a.tingir is not None:
            im = tingir(im, a.tingir, a.limiar_neon, a.saturacao)
        if a.grampear_matiz is not None:
            im = grampear_matiz(im, a.grampear_matiz[0], a.grampear_matiz[1])
        if not a.sem_costura:
            im = costurar(im)
        if a.alvo_v is not None:
            FAMILIAS[familia] = dict(FAMILIAS[familia], alvo_v=a.alvo_v)
        im = forcar_gamut(im, familia, tipo)
        im = cravar_alpha(im)
        os.makedirs(os.path.dirname(os.path.abspath(a.destino)), exist_ok=True)
        im.save(a.destino)
        print("escrito: %s\n" % a.destino)
        return 0 if conferir(a.destino, familia, tipo) else 1

    alvos = []
    if os.path.isdir(a.alvo):
        for nome in sorted(os.listdir(a.alvo)):
            if nome.endswith(".png"):
                alvos.append(os.path.join(a.alvo, nome))
    else:
        alvos = [a.alvo]

    tudo = True
    for caminho in alvos:
        familia = a.familia or _familia_do_nome(caminho)
        tudo &= conferir(caminho, familia, a.tipo or _tipo_do_nome(caminho))
        print("")
    return 0 if tudo else 1


if __name__ == "__main__":
    sys.exit(main())
