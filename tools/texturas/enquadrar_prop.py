"""Recorta a peca no alfa e a emoldura na PROPORCAO da celula de destino.

Ele e o passo que faltava ANTES do funil, e a ausencia dele deforma a peca sem
avisar. `preparar_textura.py --tamanho LARGURAxALTURA` reduz para o retangulo
pedido, e reduzir nao preserva proporcao: uma peca gerada em 96x128 (3:4)
empurrada para uma celula 64x64 sai 33% mais gorda, e o defeito nao aparece em
portao nenhum -- ela continua na paleta, continua na grade, continua ancorada. So
fica errada.

O gerador nao entrega a proporcao da celula, e nao tem como: ele desenha o objeto
na tela que se pede, com o vazio que sobrar. As celulas do atlas volumetrico sao
32x64, 64x64 ou 96x96 -- e a peca chega em 96x128, 160x160, 128x96.

## O que ele faz, e por que nessa ordem

1. **Recorta no alfa.** O vazio em volta nao e parte da peca, e mante-lo faria a
   proporcao medida ser a da TELA em vez da do objeto.
2. **Emoldura na proporcao pedida**, aumentando so o lado que falta. Nunca
   corta: cortar tiraria pixel desenhado, e o objetivo e o contrario.
3. **Ancora no FUNDO.** `Sala._montar_props_volumetricos` desloca o sprite em
   `-altura/2` e trata a base da regiao como o ponto de contato com o chao --
   `teste_props.gd` cobra isso com folga de 1 px. Centrar na vertical faria a
   peca flutuar meio corpo, sem erro nenhum no console.
4. **Centra na horizontal.** A peca nao tem lado preferido, e o sorteio de
   `flip_h` da `Sala` cobraria simetria de margem de qualquer forma.

Ele NAO reduz e NAO toca em cor: quem faz isso e o funil, depois. Sao dois
passos porque sao duas perguntas -- "que forma tem a celula?" e "que cor tem o
andar?" -- e junta-las esconderia qual delas deformou a peca.

## Uso

    python tools/texturas/enquadrar_prop.py ORIGEM DESTINO 64x64
    python tools/texturas/enquadrar_prop.py ORIGEM DESTINO 32x64 --margem 2

`--margem` deixa uma folga em pixels do tamanho FINAL em volta do desenho, para
o contorno nao encostar na borda da celula. Zero por padrao: a peca encosta no
fundo por construcao, e e isso que o portao de ancora cobra.
"""

import argparse
import sys
from pathlib import Path

from PIL import Image


def enquadrar(origem: Path, destino: Path, larg: int, alt: int, margem: int) -> None:
    imagem = Image.open(origem).convert("RGBA")
    caixa = imagem.getchannel("A").getbbox()
    if caixa is None:
        raise SystemExit(f"{origem}: a imagem esta inteira transparente.")
    peca = imagem.crop(caixa)

    # A proporcao ALVO, com a margem ja descontada: a folga e do quadro final, e
    # nao da peca, senao pedir margem mudaria a proporcao do desenho.
    util_l = max(1, larg - margem * 2)
    util_a = max(1, alt - margem * 2)
    alvo = util_l / util_a
    atual = peca.width / peca.height

    if atual > alvo:
        # Larga demais: cresce a ALTURA.
        nova_a = round(peca.width / alvo)
        nova_l = peca.width
    else:
        nova_l = round(peca.height * alvo)
        nova_a = peca.height

    quadro = Image.new("RGBA", (nova_l, nova_a), (0, 0, 0, 0))
    # Centrada em x, ancorada no FUNDO em y.
    quadro.paste(peca, ((nova_l - peca.width) // 2, nova_a - peca.height))

    if margem > 0:
        # A margem entra na mesma proporcao do quadro, para nao desfazer o que
        # acabou de ser feito.
        borda_l = round(nova_l * margem / util_l)
        borda_a = round(nova_a * margem / util_a)
        com_borda = Image.new(
            "RGBA", (nova_l + borda_l * 2, nova_a + borda_a * 2), (0, 0, 0, 0)
        )
        com_borda.paste(quadro, (borda_l, borda_a))
        quadro = com_borda

    destino.parent.mkdir(parents=True, exist_ok=True)
    quadro.save(destino)
    print(
        f"{origem.name}: {imagem.width}x{imagem.height} -> recorte "
        f"{peca.width}x{peca.height} -> quadro {quadro.width}x{quadro.height} "
        f"(proporcao {larg}x{alt})"
    )


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("origem", type=Path)
    p.add_argument("destino", type=Path)
    p.add_argument("celula", help="LARGURAxALTURA da celula de destino, ex 64x64")
    p.add_argument("--margem", type=int, default=0)
    args = p.parse_args(argv)

    try:
        larg, alt = (int(v) for v in args.celula.lower().split("x"))
    except ValueError:
        raise SystemExit("celula: use LARGURAxALTURA, ex 64x64")
    enquadrar(args.origem, args.destino, larg, alt, args.margem)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
