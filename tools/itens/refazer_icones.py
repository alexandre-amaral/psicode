#!/usr/bin/env python3
"""Passa TODOS os masters de icone pelo funil de novo, com um comando so.

## Por que isto existe, em vez de um laco decorado

O master versionado em `tools/art_sources/itens/` e o que torna
`preparar_icone.py --lado 48` possivel sem uma geracao nova no PixelLab -- e essa
promessa so vale se refazer os dezesseis for uma coisa que se FAZ, e nao uma
invocacao que alguem precisa lembrar. A moldura do slot vai encolher um dia; o
dia em que ela encolher nao pode ser o dia em que se redescobre o comando.

## O que ele NAO carrega: as bandeiras por peca

`--vazar-furos` e `--tirar-sombra` agiram UMA vez, na passagem da arte crua do
PixelLab para o master, e o resultado esta gravado no proprio master: o furo do
anel do `gatilho` ja esta vazado, o laco de cabo do `servo` tambem, e a sombra do
`sobrecarga` ja saiu. Reprocessar o master nao precisa delas, e passa-las de novo
seria pedir ao funil que resolvesse um problema que ele ja resolveu.

Guardar aqui uma tabela de "que bandeira cada peca usou" seria uma segunda fonte
da mesma verdade, e ela envelheceria no primeiro redesenho. Quem responde por
"este master esta certo?" e o `laboratorio_icones`, medindo o que ha em disco.
"""

import glob
import os
import subprocess
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MESTRE = os.path.join(RAIZ, "tools", "art_sources", "itens")
FUNIL = os.path.join(RAIZ, "tools", "itens", "preparar_icone.py")


def main(argv=None):
    extras = list(argv if argv is not None else sys.argv[1:])
    masters = sorted(glob.glob(os.path.join(MESTRE, "icone_*.png")))
    if not masters:
        sys.exit("nenhum master em %s" % MESTRE)

    ruins = []
    for caminho in masters:
        ident = os.path.basename(caminho)[len("icone_"):-len(".png")]
        saida = subprocess.run([sys.executable, FUNIL, ident] + extras,
                               capture_output=True, text=True)
        marca = "ok " if saida.returncode == 0 else "XX "
        print("  %s %s" % (marca, ident))
        if saida.returncode != 0:
            ruins.append(ident)
            print(saida.stdout.rstrip())
            print(saida.stderr.rstrip())

    print("\n%d master(s), %d com problema" % (len(masters), len(ruins)))
    if ruins:
        print("reprovados: %s" % ", ".join(ruins))
    return 1 if ruins else 0


if __name__ == "__main__":
    sys.exit(main())
