# =============================================================================
#  psicode - cria o repositorio no GitHub e sobe o projeto
#
#  Rode DEPOIS de .\tools\setup-git.ps1, e de dentro de C:\dev\psicode.
#  Cria o repositorio privado ja com o codigo dentro -- nao precisa criar
#  nada pelo site antes.
# =============================================================================

$ErrorActionPreference = "Stop"

function Passo($texto) { Write-Host "`n=== $texto ===" -ForegroundColor Cyan }
function Ok($texto)    { Write-Host "  [ok] $texto"    -ForegroundColor Green }
function Erro($texto)  { Write-Host "  [X]  $texto"    -ForegroundColor Red }

if (-not (Test-Path ".\project.godot")) {
    Erro "project.godot nao encontrado aqui."
    Erro "Rode este script de dentro da pasta do projeto (C:\dev\psicode)."
    exit 1
}

if ((Get-Location).Path -match "OneDrive|Google Drive|Dropbox") {
    Erro "O projeto esta dentro de uma pasta sincronizada: $((Get-Location).Path)"
    Erro "Mova para C:\dev\psicode antes de continuar. O Godot corrompe o"
    Erro "proprio cache quando o servico de sync trava arquivo no meio."
    exit 1
}

Passo "1/4  Inicializando o repositorio local"
if (Test-Path ".git") {
    Ok "ja existe um repositorio aqui"
} else {
    git init | Out-Null
    git branch -M main
    Ok "repositorio criado no branch main"
}

Passo "2/4  Primeiro commit"
git add .
$temAlgo = git diff --cached --name-only
if ([string]::IsNullOrWhiteSpace($temAlgo)) {
    Ok "nada novo para commitar"
} else {
    $qtd = ($temAlgo -split "`n").Count
    git commit -m "primeira build jogavel do vertical slice" | Out-Null
    Ok "$qtd arquivos commitados"
}

# Conferencia: a pasta .godot e cache e nunca deve entrar no repositorio.
if (git ls-files --error-unmatch ".godot" 2>$null) {
    Erro ".godot foi commitado. Isso vira conflito garantido no time."
    Erro "Rode:  git rm -r --cached .godot  &&  git commit -m 'remove cache do godot'"
    exit 1
}
Ok ".godot ficou de fora, como esperado"

Passo "3/4  Criando o repositorio no GitHub"
$remoto = git remote get-url origin 2>$null
if ($remoto) {
    Ok "remoto ja configurado: $remoto"
    git push -u origin main
} else {
    # Cria privado, aponta o remoto para esta pasta e ja sobe o codigo.
    gh repo create psicode --private --source=. --remote=origin --push
    Ok "repositorio privado criado e codigo enviado"
}

Passo "4/4  O que fazer agora no site"
$url = git remote get-url origin
Write-Host @"

  Repositorio: $url

  1. Proteger o main
     Settings -> Branches -> Add branch protection rule -> padrao: main
       [x] Require a pull request before merging
       [x] Require status checks to pass  ->  marque 'teste-de-fumaca'

     O check so aparece na lista depois que o GitHub tiver visto o workflow
     rodar ao menos uma vez. Se ainda nao apareceu, espere o primeiro CI
     terminar e volte nesta tela.

  2. Convidar os dois
     Settings -> Collaborators -> Add people
     Mande para eles o link do arquivo docs/HANDOFF.md

"@ -ForegroundColor Gray
