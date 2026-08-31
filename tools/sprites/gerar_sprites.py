"""Normaliza a arte de personagem e de inimigo para uma moldura unica, ancorada nos pes.

Por que este script existe, e por que ele e Python e nao GDScript como o
gerador de texturas: **o Godot nao importa GIF**. Nao ha importador; um .gif em
res:// e simplesmente ignorado. Entao a conversao tem de acontecer fora do
motor, e o que entra no jogo e o PNG que sai daqui.

O problema que ele resolve nao e o formato, e o ALINHAMENTO. Medido nas 160
imagens de origem: o personagem tem o mesmo tamanho nos dois conjuntos (~62 a
66px de altura), mas as molduras nao -- o idle vem em 64x64 e a caminhada em
88x88 ou 92x92, misturados dentro do mesmo conjunto. Colar os quadros como
chegam faria o personagem pular de lugar, para o lado e para cima, toda vez que
o jogador comecasse ou parasse de andar.

A ancora tem duas metades, e cada uma foi escolhida olhando o dado:

* **horizontal: pelo centro da MOLDURA de origem**, nao pelo centro do desenho.
  A arte ja vem com um deslocamento lateral intencional -- a RAVEN olhando a
  leste fica 3,5px a esquerda do centro, e fica igual nos dois conjuntos.
  Centralizar pelo desenho apagaria essa intencao e faria a personagem
  escorregar de lado ao trocar de animacao.

* **vertical: pelos PES** (base do bbox de alpha), com uma folga fixa no fundo.
  E o que faz idle e caminhada assentarem no mesmo chao. Alinhar pelo centro ou
  pelo topo deixaria a personagem flutuando em metade das direcoes.

E idempotente: a ancora sai do bbox, que nao muda quando se acrescenta vazio em
volta. Rodar duas vezes da o mesmo arquivo.

Uso:  python tools/sprites/gerar_sprites.py
"""

import os
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.exit("Precisa do Pillow:  pip install Pillow")

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ORIGEM_ANIM = os.path.join(RAIZ, "animations")

## As pastas de saida, e se cada uma quer miniatura. A miniatura e o retrato do
## cartao de selecao de operador -- inimigo nao tem cartao, e sem esta distincao
## o script reportaria "faltando: miniatura" em todo inimigo, para sempre.
##
## A pasta de ENTRADA continua sendo `animations/<id>/` para os dois: o GIF e
## achado por sufixo e o `id` e o nome da pasta, entao nao ha por que separar.
DESTINOS = [
    (os.path.join(RAIZ, "assets", "personagens"), True),
    (os.path.join(RAIZ, "assets", "inimigos"), False),
]

## Lado da moldura de saida. 80 e o menor multiplo de 16 que cabe tudo que ja
## entrou: a maior exigencia medida e 66px (RAVEN), e o Drone Aranha pede 60x56.
## Uma moldura so para o projeto inteiro, em vez de uma por personagem, e um
## numero a menos para alguem errar -- e e o alinhamento ENTRE conjuntos que
## impede o bicho de saltar de lugar ao comecar a andar.
LADO = 80

## Conjuntos que NAO cabem na moldura padrao, e a moldura de cada um.
##
## O chefe do andar 1 e duas a tres vezes o tamanho do jogador: em 80 ele sairia
## cortado, e a saida errada seria dar a ele arte autorada fora do gerador --
## foi assim que a Diretora acabou fora da ancora de base, com o tint de Hack
## nao pintando nela e o portao de origem a pulando em silencio.
##
## 160 e 2x 80 de proposito: a proporcao entre chefe e jogador fica a mesma em
## pixels e em moldura, e a escala continua INTEIRA. Espelha
## `Direcoes.MOLDURAS_DE_ATOR`, e as duas listas precisam continuar iguais.
MOLDURAS = {
    "boss_guardiao_01": 160,
}

## Folga entre o pe e o fundo da moldura. Nao e estetica: sem ela um quadro em
## que a personagem pisa um pixel mais baixo seria cortado.
FOLGA_PE = 4

## Lado da moldura da miniatura ANTES de dobrar. O retrato do cartao de selecao
## nao pode usar o sprite de 80: a moldura de 80 existe para o quadro mais largo
## do conjunto e deixa vazio dos dois lados, entao no cartao o personagem sairia
## pequeno demais para a proporcao que o layout pede. Recortado no alpha e
## dobrado, ele chega em 128 -- que e o tamanho certo E continua escala inteira,
## a unica que nao borra pixel art.
LADO_MINIATURA = 64

## A ordem canonica das oito direcoes. E a mesma de DadosPersonagem.ORDEM, e as
## duas precisam continuar iguais -- teste_personagem.gd confere o mapa de
## angulo para quadro, mas nao tem como saber que o ARQUIVO saiu trocado.
DIRECOES = [
    "east", "south-east", "south", "south-west",
    "west", "north-west", "north", "north-east",
]


def quadros_do_gif(caminho):
    """Todos os quadros de um GIF, ja compostos em RGBA."""
    im = Image.open(caminho)
    saida = []
    indice = 0
    while True:
        try:
            im.seek(indice)
        except EOFError:
            break
        saida.append(im.convert("RGBA"))
        indice += 1
    return saida


def _bbox(img):
    return img.getchannel("A").getbbox()


def moldura_de(personagem):
    """A moldura deste conjunto. LADO para todo mundo, menos quem declarar."""
    return MOLDURAS.get(personagem, LADO)


def deslocamento_de(img, lado):
    """O (dx, dy) que poe `img` na moldura com a ancora descrita no topo.

    Separado de `normalizar` porque um CLIPE precisa medir a ancora uma vez e
    aplica-la a todos os quadros. Ver `montar_fita_de_clipe`.
    """
    caixa = _bbox(img)
    if caixa is None:
        return None

    largura, _altura = img.size
    centro_origem = largura / 2.0
    # Horizontal: preserva a distancia do desenho ate o centro da moldura antiga.
    dx = int(round(lado / 2.0 - centro_origem))
    # Vertical: leva o pe (base do bbox) para a linha fixa de baixo.
    dy = (lado - FOLGA_PE) - caixa[3]
    return (dx, dy)


def colar_na_moldura(img, lado, deslocamento):
    fundo = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    if deslocamento is not None:
        fundo.paste(img, deslocamento, img)
    return fundo


def normalizar(img, lado=None):
    """Poe `img` numa moldura `lado` x `lado` com a ancora descrita no topo."""
    lado = LADO if lado is None else lado
    return colar_na_moldura(img, lado, deslocamento_de(img, lado))


def montar_fita(quadros, lado=None):
    """Os N quadros lado a lado, para virarem hframes de um Sprite2D.

    Ancora CADA quadro, e isso e o certo para caminhada: os pes voltam ao chao
    todo passo, entao normalizar quadro a quadro mantem o bicho no lugar.
    """
    lado = LADO if lado is None else lado
    fita = Image.new("RGBA", (lado * len(quadros), lado), (0, 0, 0, 0))
    for i, q in enumerate(quadros):
        fita.paste(normalizar(q, lado), (i * lado, 0))
    return fita


def montar_fita_de_clipe(quadros, lado):
    """A fita de um GESTO: ancora UNICA, medida no primeiro quadro com desenho.

    **Esta e a diferenca inteira entre um clipe e a caminhada, e ela nao aparece
    em erro nenhum.** `montar_fita` ancora cada quadro pela base do proprio bbox
    de alfa. Num ciclo de caminhada isso passa -- os pes voltam ao chao todo
    passo. Num GESTO isso CANCELA a animacao: no agachamento de uma investida,
    subir cada quadro ate a linha dos pes apaga exatamente o agachamento; num
    pisao, a perna erguida vira o corpo inteiro descendo. O clipe se achata
    sozinho, sem erro e sem nada em tela que aponte a causa.

    A ancora e do ATOR, e nao da pose. Medida uma vez, aplicada a todos.
    """
    ancora = None
    for q in quadros:
        ancora = deslocamento_de(q, lado)
        if ancora is not None:
            break
    fita = Image.new("RGBA", (lado * len(quadros), lado), (0, 0, 0, 0))
    for i, q in enumerate(quadros):
        fita.paste(colar_na_moldura(q, lado, ancora), (i * lado, 0))
    return fita


def _gif_da_direcao(pasta, direcao):
    """Acha o GIF daquela direcao sem depender do prefixo.

    Os nomes vieram da ferramenta que gerou a arte e nao sao iguais entre as
    duas personagens ("walk_foward" na RAVEN, "walking_foward" na NOVA). Casar
    pelo sufixo evita transformar isso num caso especial por personagem.
    """
    alvo = "_%s.gif" % direcao
    achados = [f for f in sorted(os.listdir(pasta)) if f.endswith(alvo)]
    if not achados:
        return None
    return os.path.join(pasta, achados[0])


## O nome de clipe que NAO pode existir: ele sairia como `andar_<direcao>.png` e
## substituiria o ciclo de caminhada em silencio, com o arquivo saindo do tamanho
## certo e passando em todos os portoes de runtime.
NOME_RESERVADO = "andar"


def _ordem_de_quadro(nome):
    """Ordena 0,1,...,10 e nao 0,1,10,2 -- o PixelLab numera os quadros."""
    raiz = os.path.splitext(nome)[0]
    return (0, int(raiz)) if raiz.isdigit() else (1, raiz)


def quadros_da_pasta(pasta):
    """Os PNG numerados de uma direcao de clipe, em ordem."""
    nomes = sorted(
        (f for f in os.listdir(pasta) if f.lower().endswith(".png")),
        key=_ordem_de_quadro,
    )
    return [Image.open(os.path.join(pasta, n)).convert("RGBA") for n in nomes]


def clipes_de(pasta_anim):
    """Os gestos deste ator: uma SUBPASTA por gesto.

    Subpasta e nao prefixo de arquivo, e a escolha resolve um problema em vez de
    o policiar. `_gif_da_direcao` casa por SUFIXO com prefixo livre -- foi assim
    que `Idle_custom-walking_foward_east.gif` e `andar_east.gif` puderam
    conviver. Com clipes por prefixo, um `abrir_east.gif` ordenaria antes de
    `andar_east.gif` e seria escrito como `andar_east.png`, comendo o ciclo de
    caminhada em silencio. Pastas nao colidem.
    """
    if not os.path.isdir(pasta_anim):
        return []
    nomes = []
    for f in sorted(os.listdir(pasta_anim)):
        if not os.path.isdir(os.path.join(pasta_anim, f)):
            continue
        if f == NOME_RESERVADO:
            sys.exit(
                "clipe chamado '%s' em %s: ele sairia como andar_<direcao>.png e "
                "comeria o ciclo de caminhada" % (NOME_RESERVADO, pasta_anim)
            )
        nomes.append(f)
    return nomes


def quadros_do_clipe(pasta_clipe, direcao):
    """Os quadros daquela direcao: pasta de PNG numerado, ou um GIF."""
    por_pasta = os.path.join(pasta_clipe, direcao)
    if os.path.isdir(por_pasta):
        return quadros_da_pasta(por_pasta)
    gif = _gif_da_direcao(pasta_clipe, direcao)
    if gif is None:
        return []
    return quadros_do_gif(gif)


def gerar_miniatura(pasta_saida):
    """O retrato do cartao: o `south` recortado no alpha e dobrado."""
    origem = os.path.join(pasta_saida, "south.png")
    if not os.path.exists(origem):
        return False
    img = Image.open(origem).convert("RGBA")
    caixa = _bbox(img)
    if caixa is None:
        return False
    recorte = img.crop(caixa)

    # Centralizado na moldura, e nao colado num canto: o cartao centraliza o
    # TextureRect, e um recorte descentrado faria o personagem pender para um
    # lado sem que nada no layout explicasse por que.
    quadro = Image.new("RGBA", (LADO_MINIATURA, LADO_MINIATURA), (0, 0, 0, 0))
    quadro.paste(
        recorte,
        ((LADO_MINIATURA - recorte.width) // 2, (LADO_MINIATURA - recorte.height) // 2),
        recorte,
    )
    dobrado = quadro.resize((LADO_MINIATURA * 2, LADO_MINIATURA * 2), Image.NEAREST)
    dobrado.save(os.path.join(pasta_saida, "miniatura.png"))
    return True


def processar(destino, personagem, quer_miniatura):
    pasta_anim = os.path.join(ORIGEM_ANIM, personagem)
    pasta_saida = os.path.join(destino, personagem)
    if not os.path.isdir(pasta_saida):
        sys.exit("nao achei %s" % pasta_saida)

    lado = moldura_de(personagem)
    escritos = 0
    faltando = []

    for direcao in DIRECOES:
        # Idle: re-enquadra o PNG que ja esta no lugar. E in-place de proposito
        # -- deixar 64 e 80 convivendo convidaria exatamente o desalinhamento
        # que este script existe para matar.
        alvo_idle = os.path.join(pasta_saida, "%s.png" % direcao)
        if os.path.exists(alvo_idle):
            normalizar(Image.open(alvo_idle).convert("RGBA"), lado).save(alvo_idle)
            escritos += 1
        else:
            faltando.append("idle %s" % direcao)

        if not os.path.isdir(pasta_anim):
            continue
        gif = _gif_da_direcao(pasta_anim, direcao)
        if gif is None:
            faltando.append("andar %s" % direcao)
            continue
        quadros = quadros_do_gif(gif)
        fita = montar_fita(quadros, lado)
        fita.save(os.path.join(pasta_saida, "andar_%s.png" % direcao))
        escritos += 1
        print("  andar_%-11s %d quadros -> %dx%d" % (direcao, len(quadros), fita.width, fita.height))

    for clipe in clipes_de(pasta_anim):
        pasta_clipe = os.path.join(pasta_anim, clipe)
        larguras = set()
        for direcao in DIRECOES:
            quadros = quadros_do_clipe(pasta_clipe, direcao)
            if not quadros:
                faltando.append("%s %s" % (clipe, direcao))
                continue
            fita = montar_fita_de_clipe(quadros, lado)
            fita.save(os.path.join(pasta_saida, "%s_%s.png" % (clipe, direcao)))
            escritos += 1
            larguras.add(len(quadros))
            print("  %s_%-11s %d quadros -> %dx%d" % (clipe, direcao, len(quadros), fita.width, fita.height))
        # As oito direcoes de um clipe tem de ter a MESMA contagem: `quadros` e
        # um campo so no `ClipeDirecional`, e `hframes` sai dele. Uma direcao
        # com um quadro a mais desenharia fatias cortadas so daquele lado.
        if len(larguras) > 1:
            faltando.append("%s: contagem de quadros desigual entre direcoes %s" % (clipe, sorted(larguras)))

    if quer_miniatura:
        if gerar_miniatura(pasta_saida):
            escritos += 1
            print("  miniatura     %dx%d" % (LADO_MINIATURA * 2, LADO_MINIATURA * 2))
        else:
            faltando.append("miniatura")

    return escritos, faltando


def main():
    print("moldura padrao %dx%d, pe a %dpx do fundo" % (LADO, LADO, FOLGA_PE))
    for nome, lado in sorted(MOLDURAS.items()):
        print("  %s usa moldura %dx%d" % (nome, lado, lado))
    print("")
    problemas = []
    for destino, quer_miniatura in DESTINOS:
        if not os.path.isdir(destino):
            continue
        for personagem in sorted(os.listdir(destino)):
            if not os.path.isdir(os.path.join(destino, personagem)):
                continue
            # Sem pasta de origem em animations/, este nao e um conjunto
            # direcional -- e arte de uma peca so, assada a mao (a Diretora e o
            # caso). Cobrar dele as oito rotacoes enche a lista de FALTANDO e
            # faz o gerador sair com codigo != 0 sem nada de errado ter
            # acontecido.
            if not os.path.isdir(os.path.join(ORIGEM_ANIM, personagem)):
                print("%s: sem fitas em animations/, ignorado" % personagem)
                continue
            print("%s: (moldura %d)" % (personagem, moldura_de(personagem)))
            escritos, faltando = processar(destino, personagem, quer_miniatura)
            print("  %d arquivos" % escritos)
            problemas += ["%s: %s" % (personagem, f) for f in faltando]
            print()

    if problemas:
        # Falta de arquivo nao para o script: melhor gerar o que da e dizer o
        # que faltou do que nao gerar nada. Mas sai com codigo != 0, para nao
        # passar despercebido em script que encadeia comandos.
        print("FALTANDO:")
        for p in problemas:
            print("  - %s" % p)
        sys.exit(1)
    print("ok")


if __name__ == "__main__":
    main()
