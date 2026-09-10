"""Apaga o FUNDO CHAPADO de uma celula do atlas, sem tocar no resto da folha.

## Que problema isto resolve

`transparent background` no prompt do PixelLab **nao garante alfa**, e a
armadilha ja esta registrada duas vezes neste repositorio: nos icones as 16
pecas voltaram 100% opacas, e nos props "o armario voltou com alfa e o vaso de
pressao 100% opaco" na mesma leva. Quando isso passa despercebido, a peca entra
no atlas com um RETANGULO CINZA atras dela -- e numa sala escura o jogador ve
uma moldura clara em volta do movel, que le como bug de renderizacao.

Foi o que aconteceu com duas celulas do `props_volume.png`: a cadeira da
estacao de modificacao corporal (25,7% da celula em cinza `(107,107,107)`) e um
resto de fundo na base da bancada de ferramentas. Nenhum portao acusou, porque
o portao de paleta mede VALOR e SATURACAO do arquivo inteiro -- e um cinza de
luma 0,42 cabe folgado no teto da familia `prop`.

## Por que uma ferramenta, e nao um conserto a mao

Arte deste projeto se conserta por FUNIL, e nao por edicao manual: o conserto
tem de ser reproduzivel para a proxima peca que voltar opaca. Mas o funil
inteiro (`preparar_textura.py`) nao serve aqui, por duas razoes ja medidas:

- ele processa a IMAGEM TODA, e rodar no atlas mexeria no valor e na saturacao
  das outras 59 pecas ja aprovadas;
- **reprocessar pelo funil um PNG que ja passou por ele COME detalhe** -- a
  requantizacao acontece de novo, e a densidade dos chaos do andar 1 caiu pela
  metade quando isso foi medido.

Este script nao requantiza, nao mexe em matiz, valor nem saturacao. Ele so
APAGA pixel de fundo. O resto da folha sai byte a byte identico.

## O recorte e por CONEXAO, e nunca por cor

Mesma regra que `preparar_icone.py` e `enquadrar_prop.py` ja seguem: so sai o
fundo que ALCANCA a borda da celula. Apagar "todo pixel parecido com a cor do
fundo" abriria buraco DENTRO da peca -- e aqui isso seria fatal, porque metal
escovado tem highlight quase branco: 36 das 61 celulas do atlas tem pixel de
saturacao zero, e em 34 delas ele e o brilho da chapa, e nao fundo.

O que separa um caso do outro nao e um limiar escolhido a dedo: e a paleta. O
funil do andar 1 GRAMPEIA o matiz, entao a arte aprovada e azulada por
construcao e nunca cinza puro. Fundo de gerador tem saturacao ~zero; sombra
legitima medida nas mesmas celulas fica entre 0,14 e 0,52.

Uso:

    python tools/texturas/chavear_celula.py assets/texturas/props_volume.png \\
        --celula 192,768,64,96 --celula 192,1376,32,64
"""

from __future__ import annotations

import argparse
import sys
from collections import Counter, deque
from pathlib import Path

from PIL import Image

## Distancia L1 de RGB ate a cor do fundo para um pixel ainda contar como fundo.
##
## O mesmo 24 de `preparar_icone.py`, e pelo mesmo motivo medido: o gerador
## devolve o fundo em DOIS tons quase iguais, e uma tolerancia apertada deixa o
## segundo para tras -- a peca sai com a moldura colada em volta.
TOLERANCIA_PADRAO = 24

## Acima disto a cor tem matiz e NAO e fundo de gerador. Ver o bloco do topo.
SATURACAO_MAXIMA_DE_FUNDO = 0.08

## Abaixo disto o "fundo" e escuro demais para ser o cinza do gerador -- e
## sombra de contato, que e desenho e tem de ficar.
VALOR_MINIMO_DE_FUNDO = 60


def _saturacao(cor: tuple[int, int, int]) -> float:
    maior = max(cor)
    if maior == 0:
        return 0.0
    return (maior - min(cor)) / maior


def _distancia(a: tuple[int, int, int], b: tuple[int, int, int]) -> int:
    return abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])


def fundo_da_celula(celula: Image.Image, tolerancia: int) -> set[tuple[int, int]]:
    """Os pixels de fundo chapado da celula, ou vazio se ela nao tiver nenhum.

    Devolve CONJUNTO e nao imagem para quem chama poder medir antes de apagar --
    e o que deixa o portao e o conserto compartilharem a mesma definicao.
    """
    larg, alt = celula.size
    px = celula.load()

    sementes = (
        [(i, 0) for i in range(larg)]
        + [(i, alt - 1) for i in range(larg)]
        + [(0, j) for j in range(alt)]
        + [(larg - 1, j) for j in range(alt)]
    )
    opacas = [(x, y) for x, y in sementes if px[x, y][3] > 200]
    if not opacas:
        return set()

    # A cor do fundo e a mais comum NA BORDA, e nao na celula: a peca costuma
    # ocupar o miolo, entao a moda da celula inteira seria a cor do movel.
    cor = Counter(px[x, y][:3] for x, y in opacas).most_common(1)[0][0]
    if _saturacao(cor) > SATURACAO_MAXIMA_DE_FUNDO:
        return set()
    if max(cor) < VALOR_MINIMO_DE_FUNDO:
        return set()

    vistos: set[tuple[int, int]] = set()
    fila: deque[tuple[int, int]] = deque()

    def aceita(x: int, y: int) -> bool:
        p = px[x, y]
        return p[3] > 200 and _distancia(p[:3], cor) <= tolerancia

    for x, y in opacas:
        if (x, y) not in vistos and aceita(x, y):
            vistos.add((x, y))
            fila.append((x, y))

    while fila:
        x, y = fila.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < larg and 0 <= ny < alt and (nx, ny) not in vistos:
                if aceita(nx, ny):
                    vistos.add((nx, ny))
                    fila.append((nx, ny))
    return vistos


def chavear(folha: Image.Image, celula: tuple[int, int, int, int], tolerancia: int) -> int:
    """Apaga o fundo daquela celula NA FOLHA. Devolve quantos pixels sairam."""
    x, y, larg, alt = celula
    recorte = folha.crop((x, y, x + larg, y + alt))
    fundo = fundo_da_celula(recorte, tolerancia)
    if not fundo:
        return 0
    px = folha.load()
    for i, j in fundo:
        px[x + i, y + j] = (0, 0, 0, 0)
    return len(fundo)


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("folha", type=Path, help="o atlas a corrigir, no lugar")
    p.add_argument(
        "--celula", action="append", default=[], metavar="X,Y,L,A",
        help="a celula a chavear, no formato do Rect2i do .tres. Repetivel.")
    p.add_argument("--tolerancia", type=int, default=TOLERANCIA_PADRAO)
    p.add_argument(
        "--conferir", action="store_true",
        help="so MEDE e lista; nao escreve nada")
    args = p.parse_args(argv)

    if not args.celula:
        print("nenhuma celula pedida -- use --celula X,Y,L,A", file=sys.stderr)
        return 2

    folha = Image.open(args.folha).convert("RGBA")
    total = 0
    for texto in args.celula:
        partes = [int(v) for v in texto.split(",")]
        if len(partes) != 4:
            print("celula invalida: %s" % texto, file=sys.stderr)
            return 2
        celula = (partes[0], partes[1], partes[2], partes[3])
        if args.conferir:
            recorte = folha.crop(
                (celula[0], celula[1], celula[0] + celula[2], celula[1] + celula[3]))
            n = len(fundo_da_celula(recorte, args.tolerancia))
        else:
            n = chavear(folha, celula, args.tolerancia)
        area = celula[2] * celula[3]
        print("  Rect2i(%d, %d, %d, %d)  fundo %d px (%.1f%% da celula)"
              % (celula[0], celula[1], celula[2], celula[3], n, 100.0 * n / area))
        total += n

    if args.conferir:
        print("\nnada foi escrito (--conferir)")
        return 0
    if total == 0:
        print("\nnenhuma celula tinha fundo chapado -- folha intacta")
        return 0
    folha.save(args.folha)
    print("\n%d pixel(s) de fundo apagados em %s" % (total, args.folha))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
