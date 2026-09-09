"""Cola pecas ja preparadas num atlas que CRESCE PARA BAIXO, e imprime as
regioes para os `tipo_*.tres`.

Uso:

    python tools/texturas/colar_no_atlas.py assets/texturas/props_volume.png \\
        pronto/tanque.png@64x64 pronto/barril.png@32x64 ...

Cada peca vem com a CELULA que ela vai ocupar (`@LARGURAxALTURA`), e nao com a
posicao: a posicao e o que esta ferramenta calcula, empacotando da esquerda para
a direita em linhas novas abaixo do atlas atual.

## Por que ele nunca recompoe

As regioes ja declaradas nos `tipo_*.tres` sao **coordenadas cruas**, e a ancora
depende delas: a `Sala` desenha o sprite deslocado em `-altura/2`, entao a arte
tem de encostar no FUNDO da celula. Recompor centralizando, ou remanejar celulas
para ganhar espaco, faz TODOS os props ja declarados flutuarem -- sem erro no
console, sem nada em disco parecendo errado.

Por isso a primeira coisa que ele faz e um portao: os pixels da area antiga tem
de sair byte a byte identicos aos que entraram. Se um dia alguem mudar o
empacotamento, e ali que a mudanca aparece.

## O que ele NAO faz

Ele nao prepara nada. A peca ja chega passada por `preparar_textura.py`, com a
familia certa -- e ela passa pelo funil **sozinha**, nunca junto do atlas
inteiro: o funil processa a imagem toda, e rodar no atlas montado mexeria no
valor e na saturacao de todas as pecas ja aprovadas.
"""

import argparse
import os
import sys

from PIL import Image

## A grade do atlas. Celula fora dela nao encaixa nas regioes que os
## `tipo_*.tres` ja declaram, e o desalinhamento so aparece em tela.
GRADE = 32


## O DESENHO, sem o vazio que veio com ele.
##
## A peca gerada chega centrada na propria tela, com transparencia em volta --
## e `teste_props.gd` cobra que a arte ENCOSTE no fundo da celula (sobra maxima
## de 1 px), porque a `Sala` trata a base da regiao como o ponto de contato com
## o chao. Colar a imagem inteira poe o vazio no chao e o prop flutua: medido no
## Batch 1, o tanque sobrava 3 px e a bancada 6.
##
## Recortar no alfa e ancorar o RECORTE resolve os dois lados de uma vez -- a
## base encosta, e a largura da peca deixa de depender de quanta tela o gerador
## deu a ela.
def _recortar(im):
    caixa = im.getchannel("A").point(lambda v: 255 if v > 127 else 0).getbbox()
    return im if caixa is None else im.crop(caixa)


def _peca(spec):
    caminho, _sep, celula = spec.partition("@")
    if not celula:
        raise SystemExit("peca sem celula: '%s' (use ARQUIVO@LARGURAxALTURA)" % spec)
    largura, _sep2, altura = celula.partition("x")
    w, h = int(largura), int(altura)
    if w % GRADE or h % GRADE:
        raise SystemExit("celula %dx%d fora da grade de %d" % (w, h, GRADE))
    return caminho, w, h


def _empacotar(pecas, largura_atlas, topo):
    """Posiciona as celulas em linhas novas, da esquerda para a direita.

    A altura da linha e a da celula mais alta dela: uma peca baixa numa linha
    alta desperdica pixel, e desperdicar pixel e mais barato que embaralhar a
    ordem para economizar -- ordem embaralhada e o que faz alguem, meses depois,
    procurar uma peca no atlas e nao achar.
    """
    postos = []
    x = 0
    y = topo
    altura_da_linha = 0
    for caminho, w, h in pecas:
        if x + w > largura_atlas:
            y += altura_da_linha
            x = 0
            altura_da_linha = 0
        postos.append((caminho, x, y, w, h))
        x += w
        altura_da_linha = max(altura_da_linha, h)
    return postos, y + altura_da_linha


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("atlas")
    p.add_argument("pecas", nargs="+", metavar="ARQUIVO@LARGURAxALTURA")
    p.add_argument("--seco", action="store_true",
                   help="calcula e imprime as regioes sem escrever o atlas")
    a = p.parse_args()

    atlas = Image.open(a.atlas).convert("RGBA")
    antes = atlas.tobytes()
    largura, altura_antiga = atlas.size

    pecas = [_peca(spec) for spec in a.pecas]
    for caminho, w, h in pecas:
        if not os.path.exists(caminho):
            raise SystemExit("nao achei %s" % caminho)
        im = _recortar(Image.open(caminho).convert("RGBA"))
        if im.width > w or im.height > h:
            raise SystemExit(
                "%s tem %dx%d de DESENHO e nao cabe na celula %dx%d -- reduza no "
                "funil, com --tamanho, e nao aqui" % (caminho, im.width, im.height, w, h))

    postos, altura_nova = _empacotar(pecas, largura, altura_antiga)

    print("atlas %s: %dx%d -> %dx%d" % (a.atlas, largura, altura_antiga, largura, altura_nova))
    novo = Image.new("RGBA", (largura, altura_nova), (0, 0, 0, 0))
    novo.paste(atlas, (0, 0))

    linhas = []
    for caminho, x, y, w, h in postos:
        im = _recortar(Image.open(caminho).convert("RGBA"))
        # Ancora no FUNDO da celula e centrada em x: e o contrato com a `Sala`,
        # que desenha o sprite em `-altura/2` e trata a base da regiao como o
        # ponto de contato com o chao.
        novo.paste(im, (x + (w - im.width) // 2, y + h - im.height), im)
        linhas.append("Rect2i(%d, %d, %d, %d)" % (x, y, w, h))
        print("  %-46s -> %s" % (os.path.basename(caminho), linhas[-1]))

    # O portao: a area antiga tem de continuar byte a byte a mesma.
    depois = novo.crop((0, 0, largura, altura_antiga)).tobytes()
    if depois != antes:
        raise SystemExit("ABORTADO: o empacotamento mexeu na area ja declarada")
    print("  [ok] a area antiga saiu byte a byte identica (%d px)" % (largura * altura_antiga))

    if a.seco:
        print("\n(seco: nada escrito)")
    else:
        novo.save(a.atlas)
        print("\nescrito: %s" % a.atlas)

    print("\nas regioes novas, para os tipo_*.tres:")
    print("  " + ", ".join(linhas))
    return 0


if __name__ == "__main__":
    sys.exit(main())
