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
    python tools/sprites/baixar_pixellab.py <id> <clipe> <fonte> [a-b]

A FONTE tem duas formas, e a segunda existe porque a primeira APODRECE:

    manifesto.json          as URLs assinadas, como o MCP as devolve
    pacote.zip#animacao     o download do personagem, e o nome da animacao dentro dele

O intervalo opcional `a-b` (inclusivo, base zero) recorta os quadros. Ele existe
porque um GESTO de ataque e uma coisa so na geracao e DUAS no jogo: um template
de 8 quadros do PixelLab tem o wind-up nos primeiros e o golpe nos ultimos, e
fatiar a MESMA geracao mantem as duas metades coerentes por construcao -- o
punho que sobe no preparo e o mesmo que desce no golpe, sem risco de duas
geracoes discordarem. E como um animador trabalha.

    ... soco.json 0-3   -> o preparo
    ... soco.json 4-7   -> o golpe

O manifesto e `{"<direcao>": ["url", ...], ...}`, que e o formato em que o
`get_character` do MCP devolve os quadros. As URLs sao publicas e assinadas no
proprio link, entao o script nao precisa de credencial nenhuma -- o que tambem
quer dizer que elas EXPIRAM: manifesto velho falha no download, e nao com um
PNG corrompido.

O ZIP e o `download:` que o `get_character` imprime, e ele resolve DOIS
problemas do manifesto. O primeiro e a validade: o pacote e um arquivo, e
arquivo nao expira. O segundo e mais caro e menos obvio -- para montar um
manifesto e preciso LER o `get_character`, e a saida dele cresce com cada
animacao do personagem; num chefe com quatro ataques em oito direcoes ela ja
passa de dez mil palavras, das quais se aproveita uma URL por direcao. O pacote
traz os mesmos quadros sem intermediario.

Dentro dele os quadros moram em `<estado>/animations/<animacao>/<direcao>/`, e e
por isso que a fonte carrega o `#animacao`: o nome do CLIPE no jogo
(`armar_rajada`) nao e o nome da ANIMACAO na geracao (`rajada`) -- uma geracao
vira dois clipes, que e a razao de o corte existir.
"""
import io
import json
import os
import sys
import zipfile

from urllib.request import urlopen, Request

## O CDN do PixelLab recusa requisicao sem User-Agent com 403.
##
## Nao e autenticacao -- as URLs ja vem assinadas no proprio link. E filtro de
## bot, e sem cabecalho o download falha com "Forbidden", o que manda procurar o
## erro em credencial e nao em cabecalho.
CABECALHO = {"User-Agent": "psicode-baixar-pixellab/1.0"}

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
    dados = urlopen(Request(url, headers=CABECALHO)).read()
    if not dados.startswith(b"\x89PNG"):
        sys.exit("nao veio PNG de %s" % url)
    with io.open(caminho, "wb") as f:
        f.write(dados)
    return len(dados)


## Os quadros de cada direcao, vindos de um manifesto de URLs.
def _do_manifesto(caminho):
    with io.open(caminho, encoding="utf-8") as f:
        mapa = json.load(f)
    return {d: list(mapa.get(d) or []) for d in DIRECOES}


## Os quadros de cada direcao, vindos do pacote do personagem.
##
## A chave e o BYTE do PNG e nao uma URL, entao quem consome nao precisa saber
## de onde veio -- e o que deixa o resto do script igual nas duas fontes.
def _do_zip(caminho, animacao):
    if not os.path.exists(caminho):
        sys.exit("pacote nao encontrado: %s" % caminho)
    pacote = zipfile.ZipFile(caminho)
    achados = {d: [] for d in DIRECOES}
    sufixo = "/animations/%s/" % animacao
    for nome in sorted(pacote.namelist()):
        if sufixo not in nome or not nome.endswith(".png"):
            continue
        direcao = nome.split("/")[-2]
        if direcao in achados:
            achados[direcao].append(pacote.read(nome))
    if not any(achados.values()):
        dentro = sorted(set(n.split("/animations/")[1].split("/")[0]
                            for n in pacote.namelist() if "/animations/" in n))
        sys.exit("o pacote nao tem a animacao '%s'. Tem: %s" % (animacao, ", ".join(dentro)))
    return achados


def _escrever(dado, caminho):
    """Grava um quadro, venha ele de URL ou de pacote."""
    if isinstance(dado, bytes):
        if not dado.startswith(b"\x89PNG"):
            sys.exit("nao veio PNG do pacote em %s" % caminho)
        with io.open(caminho, "wb") as f:
            f.write(dado)
        return len(dado)
    return baixar(dado, caminho)


## PROJETIL nao tem direcao, e por isso ele tem um modo proprio.
##
## Um ator tem oito vistas que sao DESENHOS diferentes -- voce ve o rosto, depois
## as costas. Um projetil e visto de cima e voa em angulo arbitrario: as "oito
## vistas" dele seriam o mesmo desenho girado, e girar em runtime custa menos que
## assar oito arquivos e ainda quantizar o angulo (a Swarm e TELEGUIADA -- um
## dardo quantizado em 45 graus estalaria no meio da curva).
##
## Entao aqui nao ha `DIRECOES`: uma pasta so, quadros numerados, e o
## `gerar_projeteis.py` faz o resto.
def _objeto(id_arma, fontes):
    base = os.path.join(DESTINO, "projeteis", id_arma)
    if not os.path.isdir(base):
        os.makedirs(base)
    total = 0
    for i, fonte in enumerate(fontes):
        alvo = os.path.join(base, "%02d.png" % i)
        if os.path.isfile(fonte):
            with io.open(fonte, "rb") as f:
                total += _escrever(f.read(), alvo)
        else:
            total += _escrever(fonte, alvo)
    print("projeteis/%s: %d quadro(s), %.1f KB" % (id_arma, len(fontes), total / 1024.0))
    print("agora: python tools/sprites/gerar_projeteis.py %s <raio>" % id_arma)
    return 0


def main():
    if len(sys.argv) >= 4 and sys.argv[1] == "--objeto":
        return _objeto(sys.argv[2], sys.argv[3:])
    if len(sys.argv) not in (4, 5):
        sys.exit(__doc__)
    ator, clipe, fonte = sys.argv[1], sys.argv[2], sys.argv[3]
    corte = None
    if len(sys.argv) == 5:
        try:
            a, b = sys.argv[4].split("-")
            corte = (int(a), int(b) + 1)
        except ValueError:
            sys.exit("intervalo tem de ser a-b, ex.: 0-3")
    if clipe == NOME_RESERVADO:
        sys.exit("'%s' e nome reservado: ele comeria o ciclo de caminhada" % NOME_RESERVADO)

    if ".zip" in fonte:
        pacote, _, animacao = fonte.partition("#")
        if not animacao:
            sys.exit("com pacote a fonte e caminho.zip#animacao")
        mapa = _do_zip(pacote, animacao)
    else:
        mapa = _do_manifesto(fonte)

    faltando = [d for d in DIRECOES if not mapa.get(d)]
    if faltando:
        # Direcao faltando e erro DURO, e nao um aviso: as oito direcoes de um
        # clipe tem de ter a mesma contagem de quadros, porque `hframes` sai de
        # um campo so. Sete direcoes viram sete arquivos que passam em tudo e
        # deixam um lado do bicho congelado.
        sys.exit("faltam direcoes na fonte: %s" % ", ".join(faltando))

    if corte is not None:
        for d in DIRECOES:
            mapa[d] = mapa[d][corte[0]:corte[1]]
        vazias = [d for d in DIRECOES if not mapa[d]]
        if vazias:
            sys.exit("o intervalo %d-%d nao pegou quadro nenhum em: %s"
                     % (corte[0], corte[1] - 1, ", ".join(vazias)))

    contagens = set(len(mapa[d]) for d in DIRECOES)
    if len(contagens) > 1:
        sys.exit("contagem de quadros desigual entre direcoes: %s" % sorted(contagens))

    base = os.path.join(DESTINO, ator, clipe)
    total = 0
    for direcao in DIRECOES:
        pasta = os.path.join(base, direcao)
        if not os.path.isdir(pasta):
            os.makedirs(pasta)
        for i, quadro in enumerate(mapa[direcao]):
            alvo = os.path.join(pasta, "%02d.png" % i)
            total += _escrever(quadro, alvo)
        print("  %-12s %d quadros" % (direcao, len(mapa[direcao])))

    print("%s/%s: %d quadros por direcao, %.1f KB" % (
        ator, clipe, sorted(contagens)[0], total / 1024.0))
    print("agora: python tools/sprites/gerar_sprites.py")


if __name__ == "__main__":
    sys.exit(main() or 0)
