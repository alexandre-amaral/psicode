# -*- coding: utf-8 -*-
"""Normaliza a arte de PROJETIL para a moldura que a hitbox manda.

Por que este script existe ao lado de `gerar_sprites.py`, em vez de ser uma
bandeira dele: o cabecalho daquele arquivo sao tres paragrafos argumentando a
ancora nos **PES**, com dado medido. Um `--centro` ali faria o mesmo arquivo
afirmar duas coisas contraditorias, e a proxima pessoa leria o cabecalho e
erraria. Projetil nao tem pes, nao tem oito direcoes e nao anda.

O DOWNLOAD e o mesmo problema dos dois, entao ele continua em
`baixar_pixellab.py` (modo `--objeto`): ele ja resolve as duas fontes -- o
manifesto que EXPIRA e o pacote que nao --, e dois downloaders divergiriam no
dia em que o PixelLab mudasse o layout do ZIP.

USO
    python tools/sprites/gerar_projeteis.py <id> <raio> [--girar=N] [entrada]

    <id>       nome do arquivo de saida, sem extensao (bate com o `.tres`)
    <raio>     `raio_projetil` daquela arma -- e ele que decide a moldura
    --girar=N  gira a FONTE em N graus (multiplo de 90) antes de tudo
    [entrada]  pasta com os quadros; default `animations/projeteis/<id>/`

O `--girar` existe porque a arte quase nunca nasce apontando para +X, e girar a
FONTE em multiplo de 90 e sem perda -- os pixels sao permutados, nao
reamostrados. Nao confunda com girar em RUNTIME, que e o que o projetil faz o
tempo todo e e legitimo porque ele e visto de cima: aqui o giro so orienta o
arquivo antes de medir, uma vez, em disco.

A SAIDA e `assets/projeteis/<id>.png`, uma fita horizontal de N quadros.

AS SEIS REGRAS, e cada uma existe porque quebra em silencio:

1. **Gera grande, reduz aqui.** O PixelLab recusa 16x16 (piso de 16 px por eixo
   E area total >= 1024), e gerar no tamanho final enche cada pixel de detalhe --
   e a mesma licao que `preparar_textura.py` ja documenta para a parede.

2. **A LATERAL sai do raio; o comprimento e livre.** A colisao e um circulo de
   `raio`, e o portao de coerencia so amarra o eixo lateral: e de lado que o
   jogador esquiva. No eixo do voo a arte pode avancar o quanto quiser -- o
   losango de referencia avanca 2,4 raios, e e assim que ele le direcao.

3. **Ancora no CENTRO do bbox de alfa.** E a inversao exata do funil de ator, em
   que `Direcoes.BASE_NO_QUADRO` poe os pes 36 px abaixo da origem. Um projetil
   que herde aquela ancora desenha 36 px acima de onde fere, e nao ha uma linha
   no console -- so um tiro que nao bate onde parece bater. Centro do BBOX e nao
   centro de massa: uma cauda longa puxaria a media para tras.

4. **A arte aponta para +X.** O runtime faz `rotation = velocidade.angle()`, e
   `Vector2.RIGHT` e 0 rad. Arte apontando para outro lado voa de lado, para
   sempre e em silencio. O script CONFERE: a metade dianteira do bbox tem de ter
   mais pixel opaco que a traseira.

5. **Alfa binario.** O regime de paleta cobra `alpha_parcial == 0`, o filtro do
   projeto e Nearest, e meio-tom num sprite de 16 px nao e suavizado por
   ninguem. Halo, se tiver de existir, e o `Rastro` ou a particula de impacto --
   nunca alfa parcial no corpo.

7. **Reduzir e depois GRUDAR na paleta da fonte.** O BOX medeia cor, e a media
   entre o contorno e o corpo e uma cor que a fonte nao tem -- um halo escuro de
   cores inventadas, que o regime de ATOR reprova com razao. Medido na primeira
   arte: a reducao criou `#617A00`, `#4B5E00` e `#526700`, nenhuma na paleta
   forcada, e derrubou a fracao que compete de 52% para 41%.

6. **NUNCA passe projetil por `preparar_textura.py`.** Aquele funil empurra arte
   para o regime de AMBIENTE: dessatura, chapa o teto de valor e grampeia o
   matiz. Rodado aqui ele produz exatamente o arquivo que o regime de ATOR
   recusa -- e o nome do script convida ao erro.
"""

import os
import sys

from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ENTRADA_PADRAO = os.path.join(RAIZ, "animations", "projeteis")
SAIDA = os.path.join(RAIZ, "assets", "projeteis")

# Molduras possiveis, no eixo lateral e no longitudinal. Multiplos de 8 e nao de
# 16: a grade de 16 e do LADRILHO (`assets/texturas/`), e projetil nao ladrilha.
#
# GEMEA de `FormasProjetil.LATERAIS`, e as duas mudam juntas -- mesma obrigacao
# que `MOLDURAS` e `Direcoes.MOLDURAS_DE_ATOR` ja carregam.
LATERAIS = [8, 16, 32]
LONGITUDINAIS = [8, 16, 32, 64]

## Acima disto o pixel conta como desenho. Ver regra 5.
LIMIAR_ALFA = 128


def lateral_de(raio):
    """A menor moldura que cabe o diametro. Gemea de `FormasProjetil.lateral_de`."""
    preciso = int(round(raio * 2.0))
    for lado in LATERAIS:
        if lado >= preciso:
            return lado
    return LATERAIS[-1]


def _bbox_de_alfa(img):
    alfa = img.getchannel("A").point(lambda v: 255 if v >= LIMIAR_ALFA else 0)
    return alfa.getbbox()


def _paleta_de(img):
    """As cores opacas distintas da fonte."""
    return sorted({px[:3] for px in img.convert("RGBA").getdata() if px[3] >= LIMIAR_ALFA})


def _grudar_na_paleta(img, paleta):
    """Devolve cada pixel a cor mais proxima da FONTE.

    O BOX preserva massa -- e por isso ele reduz --, mas ele MEDEIA cor: um pixel
    na fronteira entre o contorno e o corpo sai como a media dos dois, que e uma
    cor que a fonte nao tem. Numa arte paletizada isso e destruir a paleta, e o
    sintoma e um halo escuro de cores inventadas em volta do desenho -- que o
    regime de ATOR reprova, com razao.

    Reduzir e depois GRUDAR mantem as duas coisas: a silhueta que o BOX preserva
    e a paleta que o pixel art declara.
    """
    if not paleta:
        return img
    dados = []
    cache = {}
    for px in img.getdata():
        if px[3] < LIMIAR_ALFA:
            dados.append((0, 0, 0, 0))
            continue
        chave = px[:3]
        perto = cache.get(chave)
        if perto is None:
            perto = min(paleta, key=lambda c: sum((c[i] - chave[i]) ** 2 for i in range(3)))
            cache[chave] = perto
        dados.append(perto + (255,))
    fora = Image.new("RGBA", img.size)
    fora.putdata(dados)
    return fora


def _binarizar(img):
    r, g, b, a = img.split()
    a = a.point(lambda v: 255 if v >= LIMIAR_ALFA else 0)
    return Image.merge("RGBA", (r, g, b, a))


def _aponta_para_frente(img):
    """A metade dianteira tem mais desenho que a traseira? (regra 4)"""
    caixa = _bbox_de_alfa(img)
    if caixa is None:
        return True
    x0, y0, x1, y1 = caixa
    meio = (x0 + x1) // 2
    alfa = img.getchannel("A")
    frente = tras = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            if alfa.getpixel((x, y)) < LIMIAR_ALFA:
                continue
            if x >= meio:
                frente += 1
            else:
                tras += 1
    return frente >= tras


def _normalizar(origem, raio, girar=0):
    """Um quadro: recorta no alfa, escala pela LATERAL, centraliza na moldura."""
    img = origem.convert("RGBA")
    if girar % 360:
        if girar % 90:
            raise SystemExit("--girar tem de ser multiplo de 90: giro livre reamostra")
        img = img.rotate(-girar, expand=True)
    caixa = _bbox_de_alfa(img)
    if caixa is None:
        raise SystemExit("quadro vazio: nao ha um pixel opaco na arte")
    recorte = img.crop(caixa)

    lateral = lateral_de(raio)
    alvo_altura = max(1, int(round(raio * 2.0)))
    escala = alvo_altura / float(recorte.height)
    nova_largura = max(1, int(round(recorte.width * escala)))
    # BOX preserva massa (regra 1); grudar na paleta desfaz as cores que a media
    # inventou (regra 7).
    reduzido = _binarizar(recorte.resize((nova_largura, alvo_altura), Image.BOX))
    reduzido = _grudar_na_paleta(reduzido, _paleta_de(recorte))

    largura = next((l for l in LONGITUDINAIS if l >= nova_largura), LONGITUDINAIS[-1])
    quadro = Image.new("RGBA", (largura, lateral), (0, 0, 0, 0))
    # Regra 3: o CENTRO do bbox cai no centro da moldura, porque e la que o
    # `CircleShape2D` esta.
    quadro.paste(reduzido, ((largura - nova_largura) // 2, (lateral - alvo_altura) // 2))
    return quadro


def _relatorio(fita, quadros, raio, id_arma):
    lateral = lateral_de(raio)
    caixa = _bbox_de_alfa(fita)
    meia_altura = (caixa[3] - caixa[1]) / 2.0 if caixa else 0.0
    print("  %-18s %d quadro(s)  moldura %dx%d  meia-altura %.1f (raio %.1f)"
          % (id_arma, quadros, fita.width // max(quadros, 1), lateral, meia_altura, raio))
    # As MESMAS medidas que `teste_linguagem_projetil.gd` cobra. Par gemeo
    # declarado: se divergirem, o funil escreve o que o portao recusa.
    if abs(meia_altura - raio) > 1.0:
        print("    AVISO: a meia-altura foge do raio em mais de 1 px -- o portao vai reprovar")
    if not _aponta_para_frente(fita):
        print("    AVISO: a arte NAO aponta para +X -- em jogo ela voa de lado")


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    id_arma = argv[1]
    raio = float(argv[2])
    resto = [a for a in argv[3:] if not a.startswith("--girar=")]
    girar = next((int(a.split("=")[1]) for a in argv[3:] if a.startswith("--girar=")), 0)
    entrada = resto[0] if resto else os.path.join(ENTRADA_PADRAO, id_arma)

    if not os.path.isdir(entrada):
        print("pasta de entrada nao existe: %s" % entrada)
        return 1
    nomes = sorted(n for n in os.listdir(entrada) if n.lower().endswith(".png"))
    if not nomes:
        print("nenhum PNG em %s" % entrada)
        return 1

    quadros = [_normalizar(Image.open(os.path.join(entrada, n)), raio, girar) for n in nomes]
    largura = max(q.width for q in quadros)
    altura = quadros[0].height
    fita = Image.new("RGBA", (largura * len(quadros), altura), (0, 0, 0, 0))
    for i, q in enumerate(quadros):
        fita.paste(q, (i * largura + (largura - q.width) // 2, 0))

    os.makedirs(SAIDA, exist_ok=True)
    destino = os.path.join(SAIDA, "%s.png" % id_arma)
    fita.save(destino)
    print("escrito: %s" % destino)
    _relatorio(fita, len(quadros), raio, id_arma)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
