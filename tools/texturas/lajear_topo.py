# -*- coding: utf-8 -*-
"""Impoe a GRADE DE LAJES no topo da parede, sobre uma superficie autorada.

A superficie vem de fora -- arte desenhada, que e onde um modelo e melhor que
uma formula. A ESTRUTURA vem daqui, e ela nao pode vir de fora por dois motivos
que sao geometricos e nao de gosto:

1. **A FASE.** Uma celula da fita e um `region_rect` de 32x32 sorteado por hash
   dentro da textura de 64x64, e celulas vizinhas sorteiam quadrantes
   independentes. Se as juntas nao estiverem em fase nos quatro quadrantes, o
   sorteio EMBARALHA a grade de lajes -- o artista desenha o Isaac e a tela
   mostra confete. Com a junta em periodo de 32, os quatro quadrantes sao
   identicos em fase por construcao, e celulas vizinhas encostam junta com
   junta formando uma linha continua.

2. **O PRETO.** A PAR 03 gerou os topos em 256 e reduziu 4x com `Image.BOX`
   para caber na faixa de densidade. Uma reducao BOX e um filtro passa-baixa:
   ela derruba a frequencia espacial -- que o portao media -- e o CONTRASTE --
   que nada media -- ao mesmo tempo. O resultado nao tinha um unico pixel
   abaixo de 0,12, e uma superficie sem recessos nao le como pedra nem como
   metal: le como tinta. Desenhar a junta DEPOIS da reducao e o que garante que
   ela sobreviva a ela.

Reduz 2x e nao 4x pela mesma razao: o fator e o que mata a aresta.

Uso:
    python tools/texturas/lajear_topo.py ORIGEM DESTINO [--periodo 32]

Depois o funil normal:
    python tools/texturas/preparar_textura.py preparar DESTINO DESTINO \\
        --manter-tamanho --sem-costura --familia parede --tipo andar1 \\
        --alvo-v 0.160
"""
from __future__ import annotations

import argparse

import numpy as np
from PIL import Image

# O lado do tile de parede. A celula da fita e metade disto.
LADO = 64

# A junta: quanto ela ocupa, e o labio aceso logo depois dela.
#
# 2 px de junta num periodo de 32 da ~12% da area entre os dois eixos, e e isso
# que poe o p10 do arquivo DENTRO do escuro -- que e a definicao operacional de
# "a superficie tem recesso". Junta de 1 px nao chega la: foi medido, e o
# resultado foi o topo de hoje.
JUNTA = 2
LABIO = 1

# QUANTO a junta escurece, e este e o botao de tuning da peca.
#
# Ele nao e gosto: a referencia mede `p10 / mediana = 0,71` na parede dela, e a
# primeira versao daqui saiu em 0,24 -- junta tres vezes mais funda que a do
# alvo. A estrutura estava certa e a FORCA nao, e a diferenca entre as duas e o
# que separa "uma parede de blocos" de "uma grade preta desenhada por cima".
PROFUNDIDADE_DA_JUNTA = 0.34

# Quanto cada laje se desloca em valor, para elas nao lerem como uma superficie
# so com linhas desenhadas em cima.
VARIACAO_DA_LAJE = 0.10


def _reduzir(im: Image.Image, lado: int) -> Image.Image:
    if im.size == (lado, lado):
        return im
    return im.resize((lado, lado), Image.BOX)


def _ruido(x: int, y: int, semente: int) -> float:
    """Hash inteiro puro, igual ao do gerador em GDScript."""
    h = (x * 374761393 + y * 668265263 + semente * 1274126177) & 0xFFFFFFFF
    h = (h ^ (h >> 13)) * 1274126177 & 0xFFFFFFFF
    return float(h & 0xFFFFFF) / 0x1000000


def lajear(im: Image.Image, periodo: int, semente: int,
           profundidade: float = PROFUNDIDADE_DA_JUNTA) -> Image.Image:
    """Desenha a grade de lajes sobre a superficie."""
    rgb = np.asarray(im.convert("RGB")).astype(np.float64) / 255.0
    altura, largura = rgb.shape[:2]

    # 1. Cada laje ganha um degrau proprio de valor.
    #
    # Sem isso a grade le como linhas pintadas numa chapa continua. Com isso,
    # duas lajes vizinhas tem tons ligeiramente diferentes e a junta passa a
    # separar DUAS COISAS, que e o que o olho procura.
    ys, xs = np.mgrid[0:altura, 0:largura]
    laje_x = xs // periodo
    laje_y = ys // periodo
    desvio = np.zeros((altura, largura))
    for ly in range(altura // periodo + 1):
        for lx in range(largura // periodo + 1):
            d = (_ruido(lx, ly, semente) - 0.5) * 2.0 * VARIACAO_DA_LAJE
            desvio[(laje_y == ly) & (laje_x == lx)] = d
    rgb = np.clip(rgb * (1.0 + desvio[:, :, None]), 0.0, 1.0)

    # 2. A JUNTA, no periodo exato. Ela e quase preta porque e um vao entre duas
    #    pecas, e nao uma linha desenhada na superficie.
    junta = ((xs % periodo) < JUNTA) | ((ys % periodo) < JUNTA)
    rgb[junta] *= profundidade

    # 3. O LABIO: a aresta da laje que pega luz, do lado oposto ao da junta.
    #
    # A luz vem de cima e da ESQUERDA (LOW_TOPDOWN §18), entao quem acende e a
    # borda de cima e a da esquerda de cada laje -- logo DEPOIS da junta.
    labio = (((xs % periodo) >= JUNTA) & ((xs % periodo) < JUNTA + LABIO)) \
        | (((ys % periodo) >= JUNTA) & ((ys % periodo) < JUNTA + LABIO))
    rgb[labio & ~junta] = np.clip(rgb[labio & ~junta] * 1.45 + 0.06, 0.0, 1.0)

    return Image.fromarray((rgb * 255.0).round().astype(np.uint8), "RGB")


def main() -> int:
    pr = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    pr.add_argument("origem")
    pr.add_argument("destino")
    pr.add_argument("--periodo", type=int, default=32,
                    help="o passo da grade de lajes no DESTINO (default 32, "
                         "que e o lado da celula da fita)")
    pr.add_argument("--semente", type=int, default=0)
    pr.add_argument("--junta", type=float, default=PROFUNDIDADE_DA_JUNTA,
                    metavar="FATOR",
                    help="quanto a junta escurece (default %.2f; 0,10 poe a "
                         "amplitude em ~1,9 e a referencia mede 0,56)"
                         % PROFUNDIDADE_DA_JUNTA)
    a = pr.parse_args()

    im = Image.open(a.origem)
    im = _reduzir(im, LADO)
    im = lajear(im, a.periodo, a.semente, a.junta)
    im.save(a.destino)

    # O relatorio e a amplitude relativa, que e o numero que o portao cobra --
    # ver por que ela e invariante a exposicao em `teste_texturas.gd`.
    v = np.asarray(im.convert("RGB")).astype(np.float64).max(axis=2) / 255.0
    p10, p50, p90 = np.percentile(v, [10, 50, 90])
    print("escrito: %s" % a.destino)
    print("  p10=%.3f  mediana=%.3f  p90=%.3f  amplitude=%.2f"
          % (p10, p50, p90, (p90 - p10) / max(p50, 1e-6)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
