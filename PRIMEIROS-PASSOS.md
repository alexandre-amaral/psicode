# Primeiros passos — Alexandre

Este arquivo é só para você, dono do repositório. Seus amigos usam o
[docs/HANDOFF.md](docs/HANDOFF.md).

---

## 1. Colocar o projeto no lugar certo

O projeto tem que morar em **`C:\dev\psicode`** — fora do OneDrive.

Não é preferência. Ao abrir o projeto, o Godot precisa criar a pasta de cache
`.godot` dentro dele; o OneDrive intercepta a criação do diretório e o Godot
desiste com esta mensagem:

> Can't open project at '...'. Failed to start the editor.

Não adianta insistir nem rodar como administrador. E mesmo que abrisse, o
Godot escreve e apaga milhares de arquivos de cache enquanto roda — a
sincronização trava um deles no meio da operação e o projeto corrompe.

Se você já extraiu dentro do OneDrive, rode `MOVER-PARA-DEV.ps1` (está na
pasta do OneDrive): ele move tudo para `C:\dev\psicode` e limpa o cache meio
escrito da tentativa que falhou.

## 2. Instalar e configurar o Git

Você tem conta no GitHub, mas o Git em si ainda não está na máquina. Este
script instala Git, Git LFS e GitHub CLI, configura sua identidade e autentica
no GitHub — tudo de uma vez.

Abra o **PowerShell** (não precisa ser administrador) e:

```powershell
cd C:\dev\psicode
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\tools\setup-git.ps1
```

Ele vai pedir seu nome e e-mail (use o **mesmo e-mail da conta GitHub**, senão
os commits não aparecem vinculados ao seu perfil) e abrir o navegador para
autenticar.

> Se o script terminar dizendo que `git` ainda não está no PATH, **feche o
> PowerShell, abra outro e rode de novo**. O instalador altera o PATH, mas a
> sessão já aberta não enxerga a mudança.

O que ele configura, e por quê:

| Configuração | Motivo |
|---|---|
| `init.defaultBranch = main` | O padrão antigo do Git é `master`; o GitHub usa `main` |
| `pull.rebase = false` | Rebase automático reescreve histórico sem avisar — péssimo para quem está começando |
| `core.longpaths = true` | O Godot gera caminhos profundos em `.godot/` e estoura o limite de 260 caracteres do Windows |
| `core.autocrlf = false` | Quem manda no fim de linha é o `.gitattributes` do projeto; deixar o Git decidir gera diff de arquivo inteiro sem ninguém ter mudado nada |
| `git lfs install` | Registra os filtros do LFS. Quando a arte entrar na Fase 2, ela vai para o LFS sozinha |

## 3. Criar o repositório e subir

```powershell
.\tools\criar-repo.ps1
```

Ele faz `git init`, o primeiro commit, **confere que a pasta `.godot` não
entrou** e cria o repositório privado no GitHub já com o código dentro — você
não precisa criar nada pelo site antes.

Se preferir na mão:

```powershell
git init
git branch -M main
git add .
git commit -m "primeira build jogavel do vertical slice"
gh repo create psicode --private --source=. --remote=origin --push
```

## 4. Proteger o `main`

`Settings → Branches → Add branch protection rule`, padrão `main`:

- ✅ Require a pull request before merging
- ✅ Require status checks to pass → marque **`teste-de-fumaca`**

O segundo item é o que faz o CI valer alguma coisa: um PR que quebra o jogo
não consegue entrar no `main`. O check só aparece na lista depois do primeiro
push, porque o GitHub precisa ter visto o workflow rodar ao menos uma vez.

## 5. Convidar os dois

`Settings → Collaborators → Add people`. Mande para eles o link do
`docs/HANDOFF.md`.

## 6. Conferir que rodou

1. Abra o Godot 4.6 → Importar → `C:\dev\psicode\project.godot`
2. `F5`
3. Aperte `F1` três vezes e veja a barra de Deterioração cruzar 50% — os Vigias
   passam a atirar à sua frente e o laser deles fica vermelho

## 7. Reconectar a pasta ao Claude

No app do Claude, use **Add folder** e adicione `C:\dev\psicode`. A partir daí
eu escrevo direto no projeto e você só dá commit.

---

## O que já está pronto

- Projeto Godot 4.6 completo, POC jogável de ponta a ponta
- 5 ondas → chefe → vitória/derrota, com o sistema de Deterioração inteiro
- Mira preditiva com telegrafo, chefe em 3 fases, shader de alucinação
- Teste automatizado da run inteira, rodando também no CI a cada PR
- Presets de export para Windows e Web, **testadas** (a build web foi carregada
  num navegador e rodou sem erro)
- Handoff, GDD, roadmap e convenções escritos

## O que fazer em seguida

Ler o [ROADMAP](docs/ROADMAP.md), Fase 1. O objetivo dela não é adicionar
conteúdo — é descobrir se a base é divertida antes de investir em arte.
