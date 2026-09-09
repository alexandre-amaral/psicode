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


## A tolerancia do recorte de fundo, em distancia L1 de RGB.
##
## Gemea da `TOLERANCIA_PADRAO` de `tools/itens/preparar_icone.py`, e pelo mesmo
## motivo medido la: o PixelLab devolve o fundo em DOIS tons quase iguais, entao
## uma tolerancia apertada deixa o segundo para tras e a peca sai com a moldura
## colada. 24 e o meio do plato -- 24 e 32 deram resultado byte a byte identico.
TOLERANCIA_PADRAO = 24


def _distancia(a, b):
    return abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])


def chavear_se_opaco(imagem, tolerancia):
    """Torna transparente o fundo que ALCANCA A BORDA, quando nao ha alfa.

    **`transparent background` no prompt nao garante alfa**, e isso e armadilha
    registrada: as 16 pecas de icone voltaram 100% opacas, com o fundo chapado.
    Nas levas de prop o gerador as vezes devolve alfa e as vezes nao -- medido na
    mesma leva, o armario voltou com alfa e o vaso de pressao sem.

    O recorte e por CONEXAO a partir da borda, e nunca por cor: o fundo pode ser
    um cinza da mesma familia do aco da propria peca, e "apague todo pixel igual
    ao fundo" abriria buraco DENTRO dela. So sai o que alcanca a borda.

    Imagem que ja tem alfa passa intacta -- reprocessar leria o RGB dos pixels
    transparentes, que e preto, e comeria o contorno escuro da peca.
    """
    alfa = imagem.getchannel("A")
    if alfa.getextrema()[0] < 255:
        return imagem

    largura, altura = imagem.size
    px = imagem.load()
    fundo = px[0, 0][:3]
    fora = bytearray(largura * altura)
    fila = []
    for x in range(largura):
        for y in (0, altura - 1):
            fila.append((x, y))
    for y in range(altura):
        for x in (0, largura - 1):
            fila.append((x, y))

    while fila:
        x, y = fila.pop()
        if x < 0 or y < 0 or x >= largura or y >= altura:
            continue
        i = y * largura + x
        if fora[i]:
            continue
        if _distancia(px[x, y][:3], fundo) > tolerancia:
            continue
        fora[i] = 1
        fila.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))

    saida = imagem.copy()
    sp = saida.load()
    for y in range(altura):
        for x in range(largura):
            if fora[y * largura + x]:
                sp[x, y] = (0, 0, 0, 0)
    return saida


def enquadrar(
    origem: Path, destino: Path, larg: int, alt: int, margem: int, tolerancia: int
) -> None:
    imagem = Image.open(origem).convert("RGBA")
    imagem = chavear_se_opaco(imagem, tolerancia)
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
    p.add_argument("--tolerancia", type=int, default=TOLERANCIA_PADRAO,
                   help="recorte do fundo opaco; 0 desliga")
    args = p.parse_args(argv)

    try:
        larg, alt = (int(v) for v in args.celula.lower().split("x"))
    except ValueError:
        raise SystemExit("celula: use LARGURAxALTURA, ex 64x64")
    enquadrar(args.origem, args.destino, larg, alt, args.margem, args.tolerancia)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
