# Handoff — setup do zero

Este guia é para quem **nunca abriu o Godot e nunca usou Git**. Siga na ordem.
Leva uns 30 minutos, quase tudo esperando download.

Se algo não bater com o que está escrito aqui, pare e chame no grupo em vez de
improvisar — quase todo problema chato deste projeto nasce de alguém tentando
consertar sozinho.

---

## Parte 1 — Instalar as três coisas

### 1.1 Godot 4.6

1. Vá em https://godotengine.org/download/windows
2. Baixe **Godot Engine 4.6** — a versão **Standard**, *não* a ".NET"
3. É um `.zip`. Extraia numa pasta fixa, por exemplo `C:\Godot\`
4. Dentro tem um `.exe`. Clique com o botão direito → *Fixar na barra de tarefas*

Não existe instalador e não existe conta. O `.exe` **é** o Godot.

> ⚠️ Tem que ser a 4.6. Versão diferente pode abrir o projeto e salvar os
> arquivos num formato que quebra para os outros dois.

### 1.2 GitHub Desktop

1. https://desktop.github.com → baixar e instalar
2. Abra e faça login (crie a conta grátis se ainda não tiver)
3. Em *File → Options → Git*, confira que seu **nome** e **e-mail** estão lá

Por que GitHub Desktop e não o Git de linha de comando: ele já vem com Git e
com Git LFS embutidos, resolve o login sozinho e mostra visualmente o que você
está prestes a enviar. Você pode migrar para o terminal depois, quando quiser.

### 1.3 VS Code (opcional, mas recomendado)

1. https://code.visualstudio.com
2. Depois de instalar, abra a aba de extensões e instale **godot-tools**

O Godot tem editor de código embutido e ele funciona bem. O VS Code só é mais
confortável se você já está acostumado com ele.

---

## Parte 2 — Entrar no repositório

1. Peça ao Alexandre um convite de colaborador para o repositório `psicode`
2. O convite chega no e-mail da sua conta GitHub. **Aceite** — sem aceitar, o
   passo seguinte vai falhar dizendo que o repositório não existe

---

## Parte 3 — Baixar o projeto

No GitHub Desktop:

1. `File → Clone repository`
2. Aba **GitHub.com** → selecione `psicode`
3. Em *Local path*, escolha uma pasta **fora do OneDrive, do Google Drive e do
   Dropbox**. Por exemplo: `C:\dev\psicode`
4. `Clone`

> ⚠️ **Nunca coloque o projeto dentro de uma pasta sincronizada.** O Godot
> escreve e apaga milhares de arquivos de cache enquanto você trabalha; o
> serviço de sincronização trava esses arquivos no meio da operação e o projeto
> corrompe. Já aconteceu com muita gente. `C:\dev\` resolve.

---

## Parte 4 — Abrir no Godot

1. Abra o Godot
2. Na tela de projetos, clique **Importar**
3. Navegue até `C:\dev\psicode` e selecione o arquivo **`project.godot`**
4. `Importar e Editar`

Na primeira vez o Godot demora alguns segundos importando tudo. É normal.

---

## Parte 5 — Jogar

Aperte **F5**.

Você deve ver o menu. Clique em **INICIAR** e você cai numa sala escura, com
seu personagem ciano no centro e **nenhum inimigo** — essa é a sala de entrada
do andar, e ela é vazia de propósito. No canto superior direito aparece
`SALAS 1 / 10`, e no canto inferior direito um minimapa com um quadradinho só.

Se viu isso, **seu setup está pronto** — o resto deste documento é sobre
trabalhar em equipe.

Ande até uma porta e atravesse: na sala seguinte as portas se trancam e os
inimigos já estão lá, espalhados. Mate todos e as portas abrem. O andar tem
10 salas; uma delas tem uma arma, outra tem um implante, e a última tem a
Diretora.

Controles: `WASD` anda, mouse mira, botão esquerdo atira, `Espaço` rola,
`Q` troca de arma, **`R` recarrega**, `Esc` sai.

Sobre a recarga: cada arma tem um pente. Quando ele acaba, a arma recarrega
sozinha — você só perde alguns instantes sem atirar. `R` recarrega antes disso,
quando você quiser escolher a hora. A munição de reserva é infinita por
enquanto, então você nunca fica sem balas de verdade.

`R` só reinicia a partida **depois** que ela termina (na tela de fim). Durante o
jogo ele recarrega — assim ninguém perde uma run boa por engano.

Atalho útil: **`F1` sobe a Deterioração em 25%**. Aperte três vezes para ver o
jogo no estado crítico sem precisar limpar meio andar antes.

---

## Parte 6 — O ciclo de trabalho

Este é o único trecho que você vai reler várias vezes. Toda vez que for mexer
em alguma coisa, o ciclo é sempre este:

### Antes de começar a trabalhar

No GitHub Desktop, clique **Fetch origin** e depois **Pull origin**.

Isso traz o que os outros fizeram. Pular esse passo é o que gera conflito.

### Criar um branch

`Current branch → New branch`. Nome no formato `tipo/descricao-curta`:

```
feat/inimigo-atirador-novo
fix/rolamento-travando-na-parede
tune/sala-grande-facil-demais
```

**Nunca trabalhe direto no `main`.**

### Trabalhar

Mexa no Godot normalmente. Salve com `Ctrl+S`.

### Enviar

1. No GitHub Desktop aparece a lista do que mudou
2. Escreva um resumo no campo de baixo à esquerda — em português, no
   imperativo: `adiciona telegrafo no ataque em anel do chefe`
3. **Commit to `seu-branch`**
4. **Push origin**
5. Aparece um botão azul *Create Pull Request*. Clique
6. Descreva o que fez e peça revisão

Alguém revisa, aprova e faz o merge. Aí você volta para o `main`, dá Pull, e
começa o ciclo de novo.

---

## Parte 7 — As cinco regras de ouro

**1. Sempre Pull antes de começar.** Sério. É a regra que mais economiza dor.

**2. Avise no grupo antes de mexer numa cena que outra pessoa está mexendo.**
Cena (`.tscn`) é o arquivo que dá conflito mais chato. A combinação é simples:
uma pessoa por cena por vez. Quem vai mexer, avisa.

**3. Nunca commite a pasta `.godot/`.** Ela já está no `.gitignore`, então isso
só acontece se alguém desativar o `.gitignore`. Não desative.

**4. Um PR por assunto.** "Arrumei o chefe e de quebra mudei a HUD e renomeei
uns arquivos" é impossível de revisar e impossível de reverter.

**5. Deu conflito num `.tscn` e você não tem certeza do que fazer? Pare e
chame.** Resolver conflito de cena no chute quebra referência de nó e o
sintoma aparece três dias depois, longe da causa.

---

## Parte 8 — Quando der errado

**"O Godot abriu mas está tudo vermelho / cheio de erro"**
Feche o Godot. Apague a pasta `.godot` dentro de `C:\dev\psicode`. Abra de
novo. Ela é só cache e é recriada sozinha.

**"Apertei F5 e não acontece nada"**
Confira que está na 4.6 (`Ajuda → Sobre`). Se estiver certo, veja o painel
*Depurador* na parte de baixo — a mensagem em vermelho diz o que quebrou.

**"O GitHub Desktop diz que tem conflito"**
Não clique em nada. Tire print da tela e mande no grupo.

**"Fiz merda e quero voltar tudo"**
GitHub Desktop → aba *Changes* → botão direito no arquivo → *Discard changes*.
Se quiser jogar fora tudo que você fez no branch: `Branch → Discard all
changes`. Enquanto você não deu Push, nada disso afeta os outros.

**"Meu jogo está diferente do dos outros"**
Você provavelmente esqueceu o Pull. Faça Pull.

---

## Parte 9 — Onde mexer em cada coisa

Antes de sair abrindo arquivo aleatório:

| Quero mexer em | Abra |
|---|---|
| Quantos inimigos cabem numa sala | `src/mapa/tipo_combate.tres` → `densidade`, `orcamento_minimo`, `orcamento_maximo` |
| Quais inimigos podem nascer, e o peso de cada um | `src/enemies/grupo_rastejante.tres`, `grupo_vigia.tres` |
| Quanto a barra sobe ao limpar uma sala | `src/mapa/tipo_combate.tres` → `deterioracao_ao_limpar` |
| Dano/cadência/munição das armas | `src/weapons/pistola.tres`, `shotgun.tres` |
| Velocidade e vida dos inimigos | `src/enemies/rastejante.tscn`, `vigia.tscn` (painel Inspetor) |
| Vida do chefe | `src/enemies/diretora.tscn` (painel Inspetor) |
| Como o jogador anda e rola | `src/player/player.gd` |
| Comportamento do chefe | `src/enemies/diretora.gd` |
| Quando a mira preditiva liga | `src/autoload/deterioracao.gd` |
| Visual de glitch | `assets/shaders/glitch.gdshader` |

Boa parte do balanceamento não exige escrever código: clique no arquivo
`.tres`, e os campos aparecem no painel **Inspetor**, à direita.

> Para a sessão de tuning, o `docs/TUNING.md` tem a lista completa com o valor
> de hoje de cada botão e o que acontece quando você mexe nele.

---

## Parte 10 — Antes de abrir o PR

Se você mexeu em código (não só em `.tres`), rode o teste antes de enviar.
Abra o PowerShell na pasta do projeto e:

```powershell
C:\Godot\Godot_v4.6-stable_win64.exe --headless --path . tools/teste_fumaca.tscn
```

Ele joga o jogo inteiro sozinho e imprime `PASSOU` ou `FALHOU`. Se falhar, o
motivo está logo abaixo. O mesmo teste roda automaticamente no seu PR, então
rodar antes só te poupa a viagem de ida e volta.
