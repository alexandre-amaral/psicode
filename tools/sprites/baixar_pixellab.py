# -*- coding: utf-8 -*-
"""Traz os quadros de uma animacao do PixelLab para `animations/<id>/<clipe>/`.

O funil de arte de ator sempre foi GIF -> `gerar_sprites.py` -> fita PNG, porque
foi assim que a arte de caminhada chegou. O PixelLab entrega **PNG numerado por
direcao**, e passar por GIF no meio so perderia qualidade e adicionaria um passo
manual. Este script escreve direto na arvore que o gerador ja sabe ler:

    animations/<id>/<clipe>/<direcao>/00.png, 01.png, ...

Dai `gerar_sprites.py` faz o resto -- moldura, ancora unica de clipe, fita
horizontal --, e ha **um** lugar que decide moldura e ancora, que e o ponto.

USO
    python tools/sprites/baixar_pixellab.py <id> <clipe> <manifesto.json>

O manifesto e `{"<direcao>": ["url", ...], ...}`, que e o formato em que o
`get_character` do MCP devolve os quadros. As URLs sao publicas e assinadas no
proprio link, entao o script nao precisa de credencial nenhuma -- o que tambem
quer dizer que elas EXPIRAM: manifesto velho falha no download, e nao com um
PNG corrompido.
"""
import io
import json
import os
import sys

try:
    from urllib.request import urlopen
except ImportError:  # Python 2
    from urllib2 import urlopen

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DESTINO = os.path.join(RAIZ, "animations")

## As oito, na ordem canonica. Espelha `DIRECOES` de `gerar_sprites.py` e
## `Direcoes` do jogo -- as tres listas precisam continuar iguais.
DIRECOES = [
    "east", "south-east", "south", "south-west",
    "west", "north-west", "north", "north-east",
]

## O nome que o gerador reserva: um clipe assim sairia como `andar_<dir>.png` e
## comeria o ciclo de caminhada em silencio.
NOME_RESERVADO = "andar"


def baixar(url, caminho):
    dados = urlopen(url).read()
    if not dados.startswith(b"\x89PNG"):
        sys.exit("nao veio PNG de %s" % url)
    with io.open(caminho, "wb") as f:
        f.write(dados)
    return len(dados)


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    ator, clipe, manifesto = sys.argv[1], sys.argv[2], sys.argv[3]
    if clipe == NOME_RESERVADO:
        sys.exit("'%s' e nome reservado: ele comeria o ciclo de caminhada" % NOME_RESERVADO)

    with io.open(manifesto, encoding="utf-8") as f:
        mapa = json.load(f)

    faltando = [d for d in DIRECOES if not mapa.get(d)]
    if faltando:
        # Direcao faltando e erro DURO, e nao um aviso: as oito direcoes de um
        # clipe tem de ter a mesma contagem de quadros, porque `hframes` sai de
        # um campo so. Sete direcoes viram sete arquivos que passam em tudo e
        # deixam um lado do bicho congelado.
        sys.exit("faltam direcoes no manifesto: %s" % ", ".join(faltando))

    contagens = set(len(mapa[d]) for d in DIRECOES)
    if len(contagens) > 1:
        sys.exit("contagem de quadros desigual entre direcoes: %s" % sorted(contagens))

    base = os.path.join(DESTINO, ator, clipe)
    total = 0
    for direcao in DIRECOES:
        pasta = os.path.join(base, direcao)
        if not os.path.isdir(pasta):
            os.makedirs(pasta)
        for i, url in enumerate(mapa[direcao]):
            alvo = os.path.join(pasta, "%02d.png" % i)
            total += baixar(url, alvo)
        print("  %-12s %d quadros" % (direcao, len(mapa[direcao])))

    print("%s/%s: %d quadros por direcao, %.1f KB" % (
        ator, clipe, sorted(contagens)[0], total / 1024.0))
    print("agora: python tools/sprites/gerar_sprites.py")


if __name__ == "__main__":
    main()
