---
name: Arte nova (arma, item, cosmético)
about: Peça que alguém vai desenhar ou gerar. A identidade vem ANTES da arte.
title: "[ARTE] "
labels: arte
---

<!--
Este gabarito existe porque prosa não é cobrável. Ver
docs/CONVENCOES.md#arte-nova-arma-item-ou-cosmético

Se quem pediu não informou a identidade, NÃO deixe em branco: preencha pelas
convenções (docs/IDENTIDADE_VISUAL.md) e escreva na última seção que foi assim.
Identidade preenchida por padrão e não anunciada é identidade inventada — só que
sem ninguém para discordar.
-->

## 1. O que a peça É

<!--
O OBJETO, descrito como objeto. Nunca o que ela faz no jogo.

  ruim: "módulo que dá +18% de cadência"
  bom:  "grupo de gatilho solto, com solenoide e mola à vista"

Palavra de função e palavra de energia viram efeito DESENHADO: "exploding into a
charge" produziu uma estrela de explosão amarela cobrindo o chefe, fora da
paleta e diferente em cada direção.
-->

## 2. A cor, e de onde ela sai

<!--
Ela já existe no dado: `cor` no DadosItem, `cor_projetil` no DadosArma. A arte
OBEDECE ao campo — o pickup e a HUD já o leem, e girar matiz na arte faz a ficha
no chão ter uma cor e o aviso na tela ter outra.

Diga o .tres e o valor.
-->

## 3. A silhueta, e contra quem ela corre risco

<!--
Nomeie as peças vizinhas com que ela pode se confundir, e diga o que a separa.

  "É um recipiente vermelho, como o Núcleo de Reserva — o que separa os dois é a
   agulha, e ela tem de sobreviver a 16 px em preto sólido."
-->

## 4. A família e a paleta

<!-- De que conjunto ela faz parte, e qual paleta a governa: ambiente, ator,
sinal ou ícone. Ver docs/IDENTIDADE_VISUAL.md -->

## 5. Onde ela é desenhada, e em que tamanho de tela

<!--
O número sai da `const` do consumidor, nunca de suposição — é ele que decide o
que a régua mede. A bandeja da HUD desenha ícone a 16 px, e a régua mediu a 32
até alguém conferir contra o código.
-->

## 6. Qual portão a cobra

<!--
Se não há nenhum, escreva isso com todas as letras. Arte sem portão é ponto
cego, e ponto cego tem de ser DECLARADO — é o que PASTAS_SEM_REGIME_AINDA e
SEM_ICONE_AINDA existem para fazer.

Família NOVA ganha régua antes do primeiro pixel, e a régua tem de morder dos
dois lados: alimentada com duas peças iguais de propósito, ela reprova.
-->

## A identidade foi informada no pedido?

- [ ] Sim, veio de quem pediu.
- [ ] Não — preenchida pelas convenções (`docs/IDENTIDADE_VISUAL.md`), para
      poder ser corrigida **antes** da arte e não depois.
