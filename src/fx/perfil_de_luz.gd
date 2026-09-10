class_name PerfilDeLuz
extends Resource
## Que TIPO de luminaria e esta. Cor, alcance, e a chance de ela ainda funcionar.
##
## A decisao de design que este recurso carrega: **no andar 1 a luz nao e
## decoracao, e o assunto.** O briefing pede uma fabrica pesada, antiga e
## abandonada "que ainda mantem partes de sua infraestrutura funcionando
## precariamente" -- e o que diz "precariamente" nao e a textura, e a lampada que
## esta apagada ao lado de uma que ainda acende. Por isso o estado de uma
## luminaria e um SORTEIO com chance declarada, e nao uma escolha por cena: uma
## fabrica em que toda luz funciona nao esta abandonada, e uma em que nenhuma
## funciona nao tem infraestrutura nenhuma.
##
## **Por que isto e um Resource e nao `@export` no no.** Sao as mesmas cinco
## luminarias repetidas por dezenas de soquetes ao longo do andar. Com os numeros
## no no, girar "a lampada esta amarela demais" viraria uma varredura de cenas; e
## foi exatamente esse modelo que o `GerenciadorMapa` ja pagou com
## `cena_boss`/`cena_tesouro`. Perfil novo = `.tres` novo.
##
## **O que este recurso NAO decide** e onde a luz nasce, quantas nascem e qual
## perfil cada soquete recebe. Isso e da sala, e a fronteira e a mesma que separa
## `DadosSala` de `PropAnimado`: o recurso diz o QUE, quem monta diz o ONDE.

## O nome do perfil, para o Inspetor e para mensagem de teste.
@export var id: StringName = &""

## A cor da luz. **Ela e multiplicada e SOMADA sobre o chao, e nao pintada nele**
## -- o que a torna um caso especial do portao G2 da `Paleta`.
##
## Secao 94/95 do briefing. As amostras que ele sugere para o ambar (`#F1B760`
## nucleo, `#C8863F` medio) sao amostras de PIXEL, para arte: medidas, elas dao
## S 0,60 / V 0,95 e S 0,69 / V 0,78, e as duas cruzam
## `Paleta.compete_com_ator()` com folga. Uma luz com essa cor poe AMBIENTE na
## faixa reservada ao tiro e ao inimigo, que e o unico erro de cor que este
## projeto trata como bug e nao como gosto.
##
## Entao o que sobrevive da amostra e o MATIZ, e nao o brilho: o brilho passa a
## ser `energia`. A luz e uma cor de valor baixo com energia alta, e nao uma cor
## clara com energia baixa -- as duas acendem o chao parecido, e so a primeira
## deixa o teto de valor do ambiente onde ele estava.
@export var cor: Color = Color(1.0, 1.0, 1.0)

## Quanto a luz acrescenta ao que esta embaixo dela.
##
## Secao 14: "ambiente base ESCURO, luz geral azul-cinza muito fraca, luzes
## locais AMBAR". Ela e o unico botao de brilho, de proposito -- ver `cor`.
##
## O teto pratico e `cor.v * energia <= Paleta.LIMITE_VALOR`: acima disso a poca
## de luz sozinha, sem nada pintado nela, ja entra na faixa de valor do ator.
@export var energia: float = 1.0

## O raio da poca de luz, em pixels.
##
## Secao 94 pede 80 a 160 para o ambar e a secao 95 pede 48 a 96 para o frio. Os
## dois sao pocas LOCAIS: o briefing quer contraste entre escuridao e bolsoes de
## luz (secao 15), e um raio grande demais apaga o contraste iluminando a sala
## inteira -- que e o mesmo defeito de "se tudo se mover, nada parece
## importante", visto pelo lado da luz.
@export var raio: float = 96.0

## A chance de esta luminaria estar ACESA (acesa estavel + acesa instavel).
##
## Secao 17 pede 50% ligadas, 30% apagadas, 20% instaveis -- e "instavel" e um
## caso de LIGADA, entao a chance de acender e 0,70 e nao 0,50.
@export_range(0.0, 1.0) var chance_de_estar_ligada: float = 0.70

## Entre as ACESAS, a chance de esta piscar.
##
## Secao 96: so 10 a 20% das ligadas piscam. **Este numero manda sobre os 20% da
## secao 17**, e a razao e a mesma que limita `max_props_animados` a 2: piscar e
## movimento, movimento no cenario compete com movimento de projetil, e o
## projetil tem de ganhar sempre. Com 0,70 de acender e 0,20 aqui, o andar sai
## com 56% estaveis, 30% apagadas e 14% piscando -- a secao 96 satisfeita no
## limite de cima, e a secao 17 aproximada.
@export_range(0.0, 1.0) var chance_de_instabilidade: float = 0.20

## A frequencia BASE do piscar, em ciclos por segundo.
##
## Secao 96 exige irregular e LENTO, nunca estroboscopico. Ela e so a base: quem
## produz a irregularidade e `LuzDeFabrica.fator_do_flicker()`, somando tres
## frequencias incomensuraveis a partir daqui.
@export var velocidade_do_flicker: float = 0.70

## Quanto a energia varia ao piscar, como fracao dela.
##
## 0,35 faz a luz oscilar entre 65% e 100% do proprio brilho. **Ela nunca alcanca
## zero**, e isso nao depende deste numero: o piso mora em
## `LuzDeFabrica.PISO_DO_FLICKER`, porque apagar por completo e reacender le como
## bug de renderizacao e nao como lampada velha -- limite de design nao e botao
## de tuning, pela mesma razao que `Porta.TEMPO_DE_ABERTURA` e `const`.
@export_range(0.0, 1.0) var profundidade_do_flicker: float = 0.35
