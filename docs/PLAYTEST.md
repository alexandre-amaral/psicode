# Primeiro playtest

O que a Fase 1 existe para descobrir: **a base é divertida sem arte e sem som?**
Se for, o resto é acabamento. Se não for, nenhuma quantidade de arte salva — e é
melhor saber agora.

Alvo: **5 a 8 pessoas**. Menos que isso e um gosto pessoal vira "tendência";
mais que isso e vocês não dão conta de ler as respostas com atenção.

---

## Antes de mandar

1. A build web está no itch.io como projeto **Restricted com senha**
   (`docs/BUILD.md`, seção "Publicar no itch.io").
2. Alguém do time abriu o link **numa aba anônima** e jogou uma run inteira.
   Isso pega o erro mais comum: o zip com o `index.html` dentro de uma pasta em
   vez de na raiz.
3. Vocês combinaram quem lê as respostas e onde elas ficam.

---

## A mensagem

> Oi! Fiz um jogo com dois amigos e queria que você jogasse antes de eu
> continuar. Roda no navegador, não precisa instalar nada:
>
> **[link]** — senha: `[senha]`
>
> Leva uns 5 minutos por partida. Joga uma ou duas vezes e me responde estas
> cinco perguntas, do jeito que vier:
>
> 1. Em que momento você percebeu que os inimigos passaram a prever seu
>    rolamento? (Ou: você chegou a perceber?)
> 2. Alguma morte pareceu injusta? Qual?
> 3. Você pegou a arma nova? Ela valeu a pena, ou você voltou pra pistola?
> 4. Quanto tempo a luta final pareceu durar? (Depois me diz o que apareceu em
>    "LUTA DO CHEFE" na tela de fim.)
> 5. Em algum momento você não soube para onde ir?
>
> Não precisa ser gentil. Se foi chato, quero saber onde.

**Não pergunte "gostou?".** A resposta é sempre "gostei" e ela não conserta
nada.

---

## Por que estas cinco

| Pergunta | O que ela mede | O que fazer com a resposta |
|---|---|---|
| 1 — mira preditiva | Se o diferencial do jogo é **percebido**. Um sistema que o jogador não nota não existe do ponto de vista da experiência | "Não percebi" → o aviso de fase está fraco, ou o limiar cai cedo demais. `LIMIAR_MEDIO` e `deterioracao_ao_limpar` no `TUNING.md` |
| 2 — morte injusta | Onde o jogo mente sobre a própria regra. Bullet hell só é justo se dá para ler a intenção antes do projétil existir | Se repetir o mesmo ataque, é telegrafo curto demais. Se for "nasceu em cima de mim", é spawn |
| 3 — a arma | Se a sala de arma paga o desvio. A shotgun tem DPS o dobro da pistola, mas alcance 256 | "Fiquei na pistola" → ou o alcance é curto demais, ou a sala de arma está escondida demais |
| 4 — duração do chefe | O item que o roadmap pede **observado**. A régua diz 59 s a 2min10 dependendo da habilidade, e a faixa boa é 60–90 s | O número real está na tela de fim. Se vier acima de 90 s para a maioria, aí sim mexe nos 300 HP |
| 5 — orientação | O minimapa é conteúdo novo e nunca foi testado com ninguém de fora. "Me perdi" é a reclamação mais provável | Enquadramento e cores do minimapa são `@export` do nó `Minimapa` em `src/ui/hud.tscn` |

A pergunta 4 tem duas metades de propósito: **o que pareceu** e **o que foi**.
A diferença entre as duas é o dado que importa — uma luta de 70 s que pareceu
três minutos é um problema de ritmo, não de vida do chefe.

---

## Ao ler as respostas

Junte tudo numa lista **ordenada pelo que mais apareceu**, não pelo que mais
incomodou vocês. Duas pessoas dizendo a mesma coisa vale mais que uma dizendo
com veemência.

Essa lista é a saída da Fase 1. Com ela na mão dá para decidir o que a Fase 2
(arte e som) resolve e o que ela não resolve.

> Se três ou mais pessoas responderem "não percebi" na pergunta 1, o resultado
> honesto é que o sistema-assinatura do jogo ainda não está no jogo — e isso
> vale mais que qualquer outra conclusão desta rodada.
