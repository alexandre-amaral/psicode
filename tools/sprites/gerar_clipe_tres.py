# -*- coding: utf-8 -*-
"""Escreve o `.tres` de um `ClipeDirecional` a partir das fitas em disco.

Um clipe sao OITO `ext_resource` mais o bloco do recurso, e as oito tem de estar
na ordem exata que `Direcoes` usa -- east, south-east, south, south-west, west,
north-west, north, north-east. Escrever isso a mao e um `.tres` de vinte linhas
em que um unico indice trocado poe o chefe encarando o lado errado, sem erro no
console e sem nada em tela que aponte a causa.

O gerador tira a ordem de um lugar so, e ele e o mesmo lugar que o resto do
funil ja usa.

USO
    python tools/sprites/gerar_clipe_tres.py <ator> <clipe> <quadros> <fps> <modo>

    modo: progresso | laco | uma_vez

Exemplo:
    python tools/sprites/gerar_clipe_tres.py boss_guardiao_01 armar_reator 5 6 uma_vez
"""
from __future__ import annotations

import argparse
import os
import sys

# A ORDEM VEM DO GERADOR DE FITAS, e nao de uma copia.
#
# Ela e contrato com `src/util/direcoes.gd`: e a ordem em que o mapa de
# angulo -> quadro indexa as fitas, comecando no leste. Trocar duas entradas poe
# o chefe encarando o lado errado em duas direcoes, sem erro no console e sem
# nada em tela que aponte a causa.
#
# Duplicar a lista aqui seria a mesma armadilha que o projeto ja pagou duas
# vezes -- o telegrafo em sete copias, o mapa de angulos em duas. Duas copias
# divergem, e o sintoma aparece em TELA e nunca no console.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gerar_sprites import DIRECOES  # noqa: E402

MODOS = {"progresso": 0, "laco": 1, "uma_vez": 2}


def main() -> int:
    pr = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    pr.add_argument("ator")
    pr.add_argument("clipe")
    pr.add_argument("quadros", type=int)
    pr.add_argument("fps", type=float)
    pr.add_argument("modo", choices=list(MODOS))
    pr.add_argument("--invertido", action="store_true",
                    help="toca de tras para frente")
    a = pr.parse_args()

    pasta = "assets/inimigos/%s" % a.ator
    faltando = []
    for direcao in DIRECOES:
        caminho = "%s/%s_%s.png" % (pasta, a.clipe, direcao)
        if not os.path.exists(caminho):
            faltando.append(caminho)
    if faltando:
        print("FALTAM as fitas:")
        for caminho in faltando:
            print("  " + caminho)
        return 1

    linhas = ['[gd_resource type="Resource" script_class="ClipeDirecional" '
              'load_steps=%d format=3]' % (len(DIRECOES) + 2), '',
              '[ext_resource type="Script" '
              'path="res://src/enemies/clipe_direcional.gd" id="1_clipe"]']
    ids = []
    for i, direcao in enumerate(DIRECOES):
        ident = "%d_%s" % (i + 2, direcao.replace("-", "_"))
        ids.append(ident)
        linhas.append('[ext_resource type="Texture2D" '
                      'path="res://%s/%s_%s.png" id="%s"]'
                      % (pasta, a.clipe, direcao, ident))
    linhas += ['', '[resource]', 'script = ExtResource("1_clipe")',
               'nome = &"%s"' % a.clipe,
               'fitas = Array[Texture2D]([%s])'
               % ", ".join('ExtResource("%s")' % i for i in ids),
               'quadros = %d' % a.quadros,
               'fps = %.1f' % a.fps,
               'modo = %d' % MODOS[a.modo],
               'invertido = %s' % ("true" if a.invertido else "false"), '']

    destino = "src/enemies/clipe_%s.tres" % a.clipe
    with open(destino, "w", encoding="utf-8", newline="\n") as saida:
        saida.write("\n".join(linhas))
    print("escrito: %s  (%d quadros, %.1f fps, %s)"
          % (destino, a.quadros, a.fps, a.modo))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
