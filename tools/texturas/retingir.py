# -*- coding: utf-8 -*-
"""Retinge textura JA PRONTA sem passar pelo funil, e PROVA que nao comeu detalhe.

Esta ferramenta existe por uma razao que e restricao de fato, e nao preferencia:
**nao ha master das 56 texturas de `assets/texturas/`.** `tools/art_sources/`
guarda os masters dos ICONES (itens e armas) e mais nada. O que existe da parede,
do chao, da porta e dos props e a SAIDA do funil -- o PNG final, ja reduzido, ja
costurado, ja grampeado no gamut.

E rodar `preparar_textura.py` de novo em cima dessa saida e proibido, com
medicao: nos tres chaos do andar 1 a densidade caiu de **16,4% / 16,9% / 12,3%**
para **8,1% / 6,1% / 4,0%**, e a razao piso-sobre-parede furou o piso em duas das
tres. A causa nao e mistica -- e a REQUANTIZACAO para a paleta, que acontece uma
segunda vez. `preparar_icone.py` chega a RECUSAR a origem por isso (regra 5).

Entao o retingimento precisa de um caminho que nao requantize nada. E existe:
girar o disco de matiz e uma BIJECAO. Duas cores diferentes continuam diferentes,
nenhuma paleta e reconstruida, e o `V` do HSV de cada pixel sai identico ao que
entrou -- a operacao inteira e feita com ele preso. O funil derruba a densidade
porque COLAPSA cores; aqui nada colapsa.

## A ARMADILHA QUE ESTA FERRAMENTA QUASE CAIU, e por que ha DUAS densidades

A primeira versao media densidade sobre a LUMINANCIA Rec.601 e reprovou os tres
chaos com o codigo certo. O motivo e aritmetica e nao bug: girar matiz **nao
preserva luminancia**. Azul puro e verde puro tem o MESMO `V` e luminancias de
0,114 e 0,587 -- os coeficientes pesam o verde cinco vezes mais que o azul.
Medido no `chao_boss`, girando 236 graus: a densidade de luminancia saltou de
6,8% para 11,5%, e o veredito acusava dano onde nao houve nenhum.

O que a operacao preserva, e portanto o que da para COBRAR, e a estrutura em
VALOR. Daí as duas leituras, com papeis diferentes:

- **densidade estrutural (V)** -- o PORTAO. Ela e cega ao giro de matiz e a
  escala de saturacao por construcao, e sensivel exatamente ao que se teme:
  requantizar colapsa niveis de valor e ela cai, borrar apaga arestas e ela cai.
  Um portao bom e cego a mudanca pretendida e sensivel ao dano temido; este e.
- **densidade do funil (RGB)** -- INFORMATIVA, e importada de
  `preparar_textura.medir_densidade` em vez de recopiada, para as duas nunca
  divergirem. Ela e a regua de onde saem os numeros escritos no `GEMINI.md`, e
  reproduz os tres: medido agora, 16,1% / 16,9% / 12,3%. Ela SE MEXE com giro de
  matiz, porque e uma regua de RGB e nao de estrutura -- entao ela e impressa
  para comparacao historica, e nunca reprova.

Densidade informativa em vez de travada e a mesma escolha que o funil ja faz e
explica: *"uma trava em que nao se confia empurra a arte para o lado errado com
a autoridade de um numero"*. A diferenca e que aqui existe UMA leitura em que se
confia, e e ela que morde.

### E ela MORDE -- medido, porque regua que nao reprova nada e um carimbo

Varrido no `chao_andar1_a`, cuja densidade estrutural crua e 20,6%:

    retingir 218 graus, saturacao 0,55     20,6% ->  20,6%    +0,00 pp   passa
    reprocessar pelo funil, reduzindo      20,6% ->   7,5%   -13,08 pp   REPROVA
    desfoque gaussiano de 1,2 px           20,6% ->   0,5%   -20,10 pp   REPROVA
    quantizar para 16 cores                20,6% ->  19,3%    -1,30 pp   REPROVA

A segunda linha e o ponto: ela e exatamente o dano que o `GEMINI.md` registra --
a mesma peca, pelo mesmo caminho, com a densidade do funil indo de 16,1% para
2,6%. O portao pega o defeito que ele existe para pegar, e deixa passar a
operacao que a ferramenta existe para fazer.

A quarta linha e a mais apertada, e vale saber: quantizacao de paleta e o dano
que o `V` sente MENOS, porque colapsar cores vizinhas de matiz nao mexe no
maximo de canal. Ela ainda estoura o ponto percentual, mas com pouca folga --
por isso a contagem de cores continua sendo impressa ao lado, como segunda
testemunha do mesmo crime.

## Por que a media de matiz e CIRCULAR

Matiz e um angulo, e media aritmetica de angulo esta errada -- nao "imprecisa",
errada. Uma textura com metade dos pixels em 350 graus e metade em 10 responde
**180** na media aritmetica (ciano, que nao existe na imagem) e **0** na
circular (vermelho, que e a resposta). O andar 1 vive perto de 215-235, longe da
descontinuidade, mas a ferramenta nao pode depender de a arte ficar longe dela:
a sala do chefe mora em 330-355, encostada no zero, e foi ela que este arquivo
mediu em 341,8.

A media e PONDERADA PELA SATURACAO porque pixel quase cinza tem matiz que e
ruido de arredondamento de 8 bits -- a mesma razao que faz `preparar_textura.py`
so medir matiz acima de `PISO_MATIZ_LEGIVEL`. Milhares de pixels cinza com matiz
aleatorio, contados com peso igual, afogam a cor que a textura de fato tem.

## Por que o mesmo DELTA para todos, e nao o mesmo matiz para todos

Cravar o matiz alvo em todo pixel achata a imagem numa cor so: a ferrugem
alaranjada ao lado da chapa fria vira a MESMA chapa, e a peca perde a unica coisa
que a fazia parecer metal sujo em vez de plastico pintado. Medir o dominante,
calcular `delta = alvo - dominante` e somar esse delta a todos preserva as
relacoes INTERNAS -- a ferrugem continua relativamente mais quente que a chapa
vizinha -- e move o CONJUNTO para o gunmetal. E o mesmo espirito do `--tingir` do
funil, que deixa o acento aceso passar intacto, so que sem precisar de um limiar
para separar quem passa: aqui ninguem e achatado.

## O que ela NAO faz

Nao toca no VALOR de pixel nenhum. Nao reduz, nao costura, nao quantiza, nao
grampeia gamut, nao mexe no alfa. Escurecer, apagar ponto claro e aparar teto
continua sendo trabalho do funil, na arte que ainda tem origem.

E ela **e uma FERRAMENTA, nao uma migracao.** Quem decide o matiz alvo e o fator
de saturacao de cada textura -- e quais das 56 sequer devem ser tocadas -- e a
Fase B do plano, olhando o resultado. Rodar isto em lote sobre `assets/texturas/`
com um numero so, sem medir peca a peca, e exatamente o mesmo erro de reprocessar
tudo pelo funil: um numero aplicado com autoridade sobre arte que ninguem olhou.

USO
    python tools/texturas/retingir.py ENTRADA [ENTRADA...]
        --matiz-alvo 218 --saturacao 0.55 [--saida PASTA] [--conferir]

    python tools/texturas/retingir.py assets/texturas/chao_item.png
        --matiz-alvo 218 --saturacao 0.45 --conferir

    ENTRADA        um ou mais PNGs. Sem `--saida`, escreve POR CIMA da entrada.
    --matiz-alvo   graus para onde o matiz DOMINANTE deve ir. Omitido, nao gira.
    --saturacao    fator multiplicativo (1.0 nao mexe). E assim que o 0,95 do
                   `chao_item` desce para perto de 0,4.
    --preservar-cinza  abaixo desta saturacao o pixel nao e girado (default 0,05).
    --conferir     NAO escreve: mede antes e depois e da o veredito.
"""

import argparse
import os
import sys

try:
    import numpy as np
except ImportError:
    sys.exit("Precisa do numpy:  pip install numpy")
try:
    from PIL import Image
except ImportError:
    sys.exit("Precisa do Pillow:  pip install Pillow")

# A leitura de HSV e a regua de densidade do funil vem IMPORTADAS, e nao
# recopiadas. Duas copias divergem no dia em que alguem melhorar uma delas, e o
# sintoma seria uma ferramenta escrevendo o que a outra recusa -- a mesma licao
# que tirou o mapa de angulo -> quadro de dentro de `DadosPersonagem`, e a mesma
# que faz `preparar_icone.py` importar a paleta de `gerar_projeteis.py` em vez de
# reimplementa-la. O `MATIZ_POR_TIPO` duplicado ja mostra o preco de nao fazer.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from preparar_textura import (  # noqa: E402
    LIMIAR_DETALHE,
    _canais,
    _rgb_para_hsv,
    medir_densidade as densidade_do_funil,
)


## Abaixo desta saturacao o matiz de um pixel de 8 bits e ruido de
## arredondamento, e nao cor. Mesmo espirito do `PISO_MATIZ_LEGIVEL` do funil.
##
## Pixel cinza girado continua cinza -- a conta e uma identidade quando S e zero.
## O motivo de pular nao e matematico, e de honestidade: com S na casa de 0,01 o
## caminho HSV -> RGB -> uint8 pode devolver um canal um passo diferente, e a
## peca sai com uma tinta que ninguem pediu num pixel que era neutro. Pular e
## mais barato e nao inventa nada.
PRESERVAR_CINZA_PADRAO = 0.05

## Diferenca de VALOR (0..255) entre vizinhos que conta como detalhe estrutural.
##
## O funil mede a soma dos tres canais contra `LIMIAR_DETALHE` (24); aqui a
## medida e de um canal so, entao 8 e a ordem de grandeza equivalente -- e a
## conta e literalmente essa, 24/3, para os dois numeros nao se soltarem um do
## outro se alguem girar o do funil.
##
## O valor ABSOLUTO importa pouco: esta ferramenta nunca compara a densidade de
## uma textura com a de outra, ela compara a MESMA textura antes e depois de si
## mesma, com o mesmo limiar nos dois lados. O que ele fixa e a escala da
## leitura, e nao o veredito.
LIMIAR_DETALHE_VALOR = LIMIAR_DETALHE / 3.0

## As duas travas do veredito.
##
## A densidade estrutural pode se mexer um fio pelo arredondamento de 8 bits: o
## round-trip HSV -> RGB -> uint8 mexe um canal em ate meio nivel, e um par de
## vizinhos parado exatamente sobre o limiar troca de lado. Um ponto percentual e
## a margem em que isso cabe com folga.
##
## Se o numero estourar, a resposta e olhar o que se pediu -- nunca afrouxar a
## tolerancia. Uma trava que se afrouxa para a arte passar e o "suavizar para
## caber num numero" visto do outro lado.
TOLERANCIA_DENSIDADE = 0.01

## O valor medio, esse nao tem desculpa nenhuma: a operacao inteira e feita com V
## preso. 0,005 e folga de arredondamento e mais nada. Estourar aqui significa
## que alguem mexeu no que esta ferramenta promete nao mexer.
TOLERANCIA_VALOR = 0.005

## Alfa acima disto conta como opaco. As medidas de cor so olham pixel opaco: um
## atlas de props e majoritariamente vazio, e medir o vazio responderia sobre o
## recorte em vez de sobre a arte.
LIMIAR_ALFA = 0.5


# ------------------------------------------------------------------ helpers --

def _hsv_para_rgb(h, s, v):
    """Vetorizado, ao contrario do gemeo de `preparar_textura.py`.

    Aquele varre pixel a pixel com `nditer`, e para um tile de 64 preparado uma
    vez isso nao doi. Aqui a ferramenta e apontada a lotes de textura, e o
    proprio `--conferir` converte a imagem inteira para medir o depois -- um
    `nditer` sobre 56 arquivos de 256 transforma a medicao em algo que ninguem
    roda, e medicao que ninguem roda e prosa.
    """
    h = np.mod(h, 360.0) / 60.0
    i = np.floor(h).astype(np.int64) % 6
    f = h - np.floor(h)
    p = v * (1.0 - s)
    q = v * (1.0 - s * f)
    t = v * (1.0 - s * (1.0 - f))
    casos = [i == 0, i == 1, i == 2, i == 3, i == 4, i == 5]
    r = np.select(casos, [v, q, p, p, t, v])
    g = np.select(casos, [t, v, v, q, p, p])
    b = np.select(casos, [p, p, t, v, v, q])
    return np.stack([r, g, b], axis=-1)


def _abrir(caminho):
    return Image.open(caminho).convert("RGBA")


# ---------------------------------------------------------------- medicoes ---

def matiz_dominante(h, s, opacos):
    """Media CIRCULAR do matiz, ponderada pela saturacao. Devolve graus ou None.

    Ver o cabecalho: media aritmetica de angulo responde ciano para uma imagem
    que so tem vermelho, e ponderar pela saturacao e o que impede os pixels
    quase cinza -- cujo matiz e arredondamento de 8 bits -- de afogar a cor real.

    Devolve None em vez de um numero quando nao HA dominante: textura acromatica
    (peso zero) ou matizes espalhados por igual pelo disco (resultante nula).
    Responder um angulo ali seria inventa-lo, e o delta calculado sobre um angulo
    inventado tingiria a peca de uma cor que ninguem escolheu.
    """
    if not opacos.any():
        return None
    peso = np.where(opacos, s, 0.0)
    if float(peso.sum()) <= 1e-6:
        return None
    rad = np.deg2rad(h)
    x = float((peso * np.cos(rad)).sum())
    y = float((peso * np.sin(rad)).sum())
    if abs(x) < 1e-9 and abs(y) < 1e-9:
        return None
    return float(np.rad2deg(np.arctan2(y, x)) % 360.0)


def medir_densidade_estrutural(im):
    """Fracao de pixels cujo VALOR difere de um vizinho de 4-conexao.

    ESTA e a leitura que o portao cobra, e a escolha do canal e o ponto inteiro
    da ferramenta -- ver a secao "A ARMADILHA" no cabecalho. `V` e o que o giro
    de matiz preserva por construcao, entao uma queda aqui nao pode ser efeito
    do retingimento: ela e requantizacao, borrao ou bug.

    Os dois deslocamentos cobrem os quatro vizinhos: todo par horizontal aparece
    uma vez em (0,1) e todo par vertical uma vez em (1,0). Rolar em vez de
    grampear na borda porque a textura LADRILHA -- o vizinho do ultimo pixel e o
    primeiro, de fato, quando ela esta na parede.
    """
    rgb, _ = _canais(im)
    _h, _s, v = _rgb_para_hsv(rgb)
    v = v * 255.0
    d = np.zeros(v.shape, bool)
    for dy, dx in ((0, 1), (1, 0)):
        viz = np.roll(np.roll(v, dy, axis=0), dx, axis=1)
        d |= np.abs(v - viz) > LIMIAR_DETALHE_VALOR
    return float(d.mean())


def medir(im):
    """A ficha de uma imagem: matiz, saturacao, valor, as duas densidades, cores."""
    rgb, alpha = _canais(im)
    h, s, v = _rgb_para_hsv(rgb)
    opacos = alpha > LIMIAR_ALFA
    if opacos.any():
        s_media = float(s[opacos].mean())
        v_media = float(v[opacos].mean())
        # Contagem de cores DISTINTAS: e ela que prova que nao houve
        # requantizacao. Girar o disco de matiz e uma bijecao -- duas cores
        # diferentes continuam diferentes --, entao ela cai no maximo pelo
        # arredondamento de 8 bits, que junta vizinhas ja quase iguais.
        # Quantizar COLAPSA por construcao, e ai ela despenca. Dois PNGs com a
        # mesma densidade e contagens muito diferentes nao passaram pelo mesmo
        # tipo de operacao.
        cores = len(set(map(tuple, (rgb[opacos] * 255).round().astype(int))))
    else:
        s_media = 0.0
        v_media = 0.0
        cores = 0
    return {
        "matiz": matiz_dominante(h, s, opacos),
        "s_media": s_media,
        "v_media": v_media,
        "densidade": medir_densidade_estrutural(im),
        "densidade_funil": densidade_do_funil(im),
        "cores": cores,
        "opacos": int(opacos.sum()),
    }


# ------------------------------------------------------------ retingimento ---

def retingir(im, matiz_alvo=None, fator_saturacao=1.0, saturacao_menos=0.0,
             preservar_cinza=PRESERVAR_CINZA_PADRAO):
    """Gira o matiz por um DELTA unico e escala a saturacao. Devolve (img, delta).

    O ALFA passa byte a byte, e o VALOR de cada pixel passa intacto por
    construcao: `_rgb_para_hsv` devolve `v`, esta funcao nao encosta nele, e
    `_hsv_para_rgb` o recebe de volta. E disso que sai a promessa da ferramenta
    -- e `--conferir` COBRA a promessa em vez de acreditar nela.

    O delta e calculado sobre o dominante da imagem INTEIRA e aplicado a todo
    pixel colorido: ver o cabecalho, secao "Por que o mesmo DELTA para todos".

    Pixel abaixo de `preservar_cinza` nao e girado. Ele TAMBEM nao escapa do
    fator de saturacao, e a assimetria e proposital: girar cinza nao muda nada
    (so arrisca um passo de arredondamento), e dessaturar cinza tambem nao muda
    nada -- multiplicar um S quase zero por 0,55 continua quase zero --, entao
    excluir o cinza da escala so acrescentaria um caso especial que nunca se ve.
    """
    rgb, alpha = _canais(im)
    h, s, v = _rgb_para_hsv(rgb)

    delta = 0.0
    if matiz_alvo is not None:
        dominante = matiz_dominante(h, s, alpha > LIMIAR_ALFA)
        # Sem dominante, girar por um delta arbitrario nao tinge nada mesmo --
        # so gastaria um round-trip de arredondamento numa peca acromatica.
        if dominante is not None:
            delta = (float(matiz_alvo) - dominante) % 360.0

    colorido = s >= preservar_cinza
    h = np.where(colorido, (h + delta) % 360.0, h)
    if fator_saturacao != 1.0:
        s = np.clip(s * float(fator_saturacao), 0.0, 1.0)
    if saturacao_menos != 0.0:
        # **SUBTRAIR preserva a diferenca ABSOLUTA entre duas texturas; multiplicar
        # a encolhe.** Isso nao e sutileza: `AssinaturaDeSuperficie` mede densidade
        # somando os tres canais RGB contra um limiar fixo, entao ela le a
        # diferenca ABSOLUTA de cor entre vizinhos. Dessaturar por FATOR aproxima
        # dois modulos na regua mesmo quando a estrutura deles nao mudou -- medido:
        # o par `boss tecnica|motor` caiu de 0,2598 para 0,244 contra um piso de
        # 0,25, so por multiplicacao.
        #
        # Com subtracao, `tecnica` (0,371) e `motor` (0,309) descem os dois 0,07 e
        # continuam 0,062 distantes, em vez de 0,051.
        s = np.clip(s - float(saturacao_menos), 0.0, 1.0)

    novo = np.clip(_hsv_para_rgb(h, s, v), 0.0, 1.0)
    saida = np.concatenate([novo, alpha[:, :, None]], axis=2)
    saida = (saida * 255.0).round().astype(np.uint8)
    # O alfa volta do ORIGINAL e nao do round-trip: ele nunca entrou na conta, e
    # devolve-lo pelo caminho do float so criaria a chance de um 254 aparecer
    # onde havia 255. O projeto exige alfa binario, e um alfa parcial nascido
    # aqui reprovaria a textura num portao que nao tem nada a ver com cor.
    saida[:, :, 3] = np.asarray(im, dtype=np.uint8)[:, :, 3]
    return Image.fromarray(saida, "RGBA"), delta


# --------------------------------------------------------------- relatorio ---

def _texto_matiz(ficha):
    return "--" if ficha["matiz"] is None else "%.1f" % ficha["matiz"]


def relatorio(caminho, antes, depois, delta):
    """Imprime antes/depois lado a lado e devolve o veredito."""
    d_dens = depois["densidade"] - antes["densidade"]
    d_funil = depois["densidade_funil"] - antes["densidade_funil"]
    d_valor = depois["v_media"] - antes["v_media"]
    d_sat = depois["s_media"] - antes["s_media"]
    d_cores = depois["cores"] - antes["cores"]

    print("%s  (%d px opacos)" % (os.path.basename(caminho), antes["opacos"]))
    print("         %-24s %9s %9s %12s" % ("", "antes", "depois", "delta"))
    print("         %-24s %9s %9s %12s"
          % ("matiz dominante", _texto_matiz(antes), _texto_matiz(depois),
             "%+.1f graus" % delta))
    print("         %-24s %9.3f %9.3f %12s"
          % ("saturacao media", antes["s_media"], depois["s_media"], "%+.3f" % d_sat))
    print("         %-24s %9.3f %9.3f %12s"
          % ("valor medio", antes["v_media"], depois["v_media"], "%+.4f" % d_valor))
    print("         %-24s %8.1f%% %8.1f%% %12s"
          % ("densidade estrutural", 100 * antes["densidade"],
             100 * depois["densidade"], "%+.2f pp" % (100 * d_dens)))
    print("         %-24s %8.1f%% %8.1f%% %12s"
          % ("densidade do funil", 100 * antes["densidade_funil"],
             100 * depois["densidade_funil"], "%+.2f pp" % (100 * d_funil)))
    print("         %-24s %9d %9d %12s"
          % ("cores distintas", antes["cores"], depois["cores"], "%+d" % d_cores))

    ok_dens = abs(d_dens) <= TOLERANCIA_DENSIDADE
    ok_valor = abs(d_valor) <= TOLERANCIA_VALOR
    print("  %s  densidade estrutural preservada: |%+.2f pp| <= %.2f pp"
          % ("[ok]" if ok_dens else "[XX]", 100 * d_dens,
             100 * TOLERANCIA_DENSIDADE))
    print("  %s  valor medio inalterado: |%+.4f| <= %.3f"
          % ("[ok]" if ok_valor else "[XX]", d_valor, TOLERANCIA_VALOR))
    # As duas linhas abaixo sao INFORMATIVAS, e cada uma por um motivo proprio.
    #
    # A densidade do funil se mexe com giro de matiz porque e uma regua de RGB e
    # nao de estrutura (ver "A ARMADILHA", no cabecalho): trava-la reprovaria a
    # operacao correta. Ela fica impressa porque e a regua de onde saem os
    # numeros escritos no GEMINI.md, e comparavel com eles.
    #
    # A contagem de cores oscila pelo arredondamento de 8 bits, e mais com uma
    # saturacao agressiva, que junta cores ja quase iguais no mesmo trio de
    # bytes. O que ela responde e de que ORDEM foi a mudanca -- unidades contra
    # milhares --, e essa pergunta nao cabe num limiar.
    print("  [--]  densidade do funil %+.2f pp: regua de RGB, comparavel com o "
          "GEMINI (informativo)" % (100 * d_funil))
    print("  [--]  cores distintas %+.1f%%: despencar seria requantizacao "
          "(informativo)" % (100.0 * d_cores / max(antes["cores"], 1)))
    return ok_dens and ok_valor


# --------------------------------------------------------------------- cli ---

def main(argv=None):
    p = argparse.ArgumentParser(
        prog="retingir.py",
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("entradas", nargs="+", metavar="ENTRADA",
                   help="um ou mais PNGs ja prontos. Sem --saida, sao reescritos "
                        "no lugar.")
    p.add_argument("--matiz-alvo", type=float, default=None, metavar="GRAUS",
                   help="para onde o matiz DOMINANTE da imagem deve ir. O delta "
                        "ate ele e aplicado a TODOS os pixels coloridos, o que "
                        "preserva as relacoes internas de matiz (a ferrugem "
                        "continua mais quente que a chapa ao lado) em vez de "
                        "achatar tudo numa cor so. Omitido, nao gira nada.")
    p.add_argument("--saturacao", type=float, default=1.0, metavar="FATOR",
                   help="multiplica a saturacao de cada pixel (default 1.0, que "
                        "nao mexe). E este botao que leva o 0,95 do chao da sala "
                        "de item para perto de 0,4.")
    p.add_argument("--saturacao-menos", type=float, default=0.0, metavar="DELTA",
                   help="subtrai DELTA da saturacao de cada pixel (0 nao mexe). "
                        "Preserva a diferenca ABSOLUTA entre texturas, que e o "
                        "que a assinatura de superficie mede -- use este em vez "
                        "de --saturacao quando as pecas forem COMPARADAS entre si")
    p.add_argument("--preservar-cinza", type=float, default=PRESERVAR_CINZA_PADRAO,
                   metavar="LIMIAR",
                   help="pixel com saturacao abaixo disto nao e girado (default "
                        "%.2f). Cinza girado continua cinza, mas o arredondamento "
                        "de 8 bits pode deixar tinta onde havia neutro -- pular e "
                        "mais barato e mais honesto." % PRESERVAR_CINZA_PADRAO)
    p.add_argument("--saida", default=None, metavar="PASTA",
                   help="escreve nesta pasta, mantendo o nome do arquivo. Sem "
                        "ela, a entrada e sobrescrita.")
    p.add_argument("--conferir", action="store_true",
                   help="NAO escreve nada: aplica a transformacao em memoria e "
                        "imprime antes/depois de matiz, saturacao, valor, as "
                        "duas densidades e a contagem de cores, com veredito.")

    a = p.parse_args(argv)
    if a.saturacao <= 0.0:
        raise SystemExit("--saturacao tem de ser positiva (1.0 nao mexe)")
    if a.matiz_alvo is None and a.saturacao == 1.0:
        print("aviso: sem --matiz-alvo e com --saturacao 1.0 nao ha o que fazer; "
              "isto vai medir a identidade.\n")

    if a.saida and not a.conferir:
        os.makedirs(a.saida, exist_ok=True)

    tudo = True
    for caminho in a.entradas:
        if not os.path.isfile(caminho):
            raise SystemExit("entrada nao existe: %s" % caminho)
        im = _abrir(caminho)
        antes = medir(im)
        nova, delta = retingir(im, a.matiz_alvo, a.saturacao, a.saturacao_menos,
                               a.preservar_cinza)
        depois = medir(nova)

        if not a.conferir:
            destino = (os.path.join(a.saida, os.path.basename(caminho))
                       if a.saida else caminho)
            nova.save(destino)
            print("escrito: %s" % destino)
        tudo &= relatorio(caminho, antes, depois, delta)
        print("")

    if not a.conferir:
        # Ver o cabecalho: esta e uma FERRAMENTA e nao uma migracao. Quem decide
        # os numeros de cada textura e a Fase B, olhando o resultado -- e rodar
        # em lote sem olhar e o mesmo erro de reprocessar tudo pelo funil.
        print("lembrete: os numeros acima descrevem o que SAIU, e nao aprovam o "
              "que se queria. Olhe a textura.")
    return 0 if tudo else 1


if __name__ == "__main__":
    sys.exit(main())
