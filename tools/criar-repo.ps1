# =============================================================================
#  psicode - cria o repositorio no GitHub e sobe o projeto
#
#  Rode DEPOIS de .\tools\setup-git.ps1, e de dentro de C:\dev\psicode.
#  Cria o repositorio privado ja com o codigo dentro -- nao precisa criar
#  nada pelo site antes.
#
#  Pode rodar quantas vezes quiser: ele detecta o que ja foi feito e continua
#  de onde parou.
# =============================================================================

# NAO usar "Stop" aqui. No PowerShell 5.1 (o que vem no Windows), qualquer
# coisa que o git escreva em stderr vira um NativeCommandError que aborta o
# script -- inclusive mensagens que sao a resposta certa. Checamos o codigo de
# saida na mao, que e o que de fato importa.
$ErrorActionPreference = "Continue"

function Passo($texto) { Write-Host "`n=== $texto ===" -ForegroundColor Cyan }
function Ok($texto)    { Write-Host "  [ok] $texto"    -ForegroundColor Green }
function Erro($texto)  { Write-Host "  [X]  $texto"    -ForegroundColor Red }
function Info($texto)  { Write-Host "  $texto"         -ForegroundColor Gray }

# Roda um comando externo capturando saida e codigo, sem deixar o stderr
# derrubar o script.
function Exec([string]$programa, [string[]]$argumentos) {
    $saida = & $programa @argumentos 2>&1 | Out-String
    return [pscustomobject]@{
        Texto  = $saida.Trim()
        Codigo = $LASTEXITCODE
    }
}

# -----------------------------------------------------------------------------
if (-not (Test-Path ".\project.godot")) {
    Erro "project.godot nao encontrado aqui."
    Erro "Rode este script de dentro da pasta do projeto (C:\dev\psicode)."
    exit 1
}

if ((Get-Location).Path -match "OneDrive|Google Drive|Dropbox") {
    Erro "O projeto esta dentro de uma pasta sincronizada: $((Get-Location).Path)"
    Erro "Mova para C:\dev\psicode antes de continuar. O Godot nem consegue"
    Erro "criar a pasta de cache .godot dentro do OneDrive."
    exit 1
}

foreach ($prog in @("git", "gh")) {
    if (-not (Get-Command $prog -ErrorAction SilentlyContinue)) {
        Erro "'$prog' nao encontrado. Rode antes:  .\tools\setup-git.ps1"
        Erro "Se ja rodou, feche este PowerShell e abra outro."
        exit 1
    }
}

# -----------------------------------------------------------------------------
Passo "1/4  Repositorio local"

if (Test-Path ".git") {
    Ok "ja existe um repositorio aqui"
} else {
    $r = Exec git @("init")
    if ($r.Codigo -ne 0) { Erro "git init falhou: $($r.Texto)"; exit 1 }
    Exec git @("branch", "-M", "main") | Out-Null
    Ok "repositorio criado no branch main"
}

# -----------------------------------------------------------------------------
Passo "2/4  Commit"

Exec git @("add", ".") | Out-Null

$staged = Exec git @("diff", "--cached", "--name-only")
if ([string]::IsNullOrWhiteSpace($staged.Texto)) {
    Ok "nada novo para commitar"
} else {
    $qtd = ($staged.Texto -split "`r?`n").Count
    $c = Exec git @("commit", "-m", "primeira build jogavel do vertical slice")
    if ($c.Codigo -ne 0) { Erro "commit falhou: $($c.Texto)"; exit 1 }
    Ok "$qtd arquivos commitados"
}

# Conferencia: .godot e cache do editor e nunca deve entrar no repositorio.
# 'git ls-files -- .godot' devolve vazio e codigo 0 quando nada casa, sem
# escrever em stderr -- por isso NAO usamos --error-unmatch aqui.
$cache = Exec git @("ls-files", "--", ".godot")
if (-not [string]::IsNullOrWhiteSpace($cache.Texto)) {
    Erro ".godot foi commitado. Isso vira conflito garantido no time."
    Info "Rode:  git rm -r --cached .godot ; git commit -m 'remove cache do godot'"
    exit 1
}
Ok ".godot ficou de fora, como esperado"

# -----------------------------------------------------------------------------
Passo "3/4  Repositorio no GitHub"

$remoto = Exec git @("remote", "get-url", "origin")
if ($remoto.Codigo -eq 0 -and -not [string]::IsNullOrWhiteSpace($remoto.Texto)) {
    Ok "remoto ja configurado: $($remoto.Texto)"
    $p = Exec git @("push", "-u", "origin", "main")
    if ($p.Codigo -ne 0) { Erro "push falhou:"; Info $p.Texto; exit 1 }
    Ok "codigo enviado"
} else {
    $g = Exec gh @("repo", "create", "psicode", "--private", "--source=.", "--remote=origin", "--push")
    if ($g.Codigo -ne 0) {
        Erro "gh repo create falhou:"
        Info $g.Texto
        Info ""
        Info "Se a mensagem disser que o repositorio ja existe, conecte na mao:"
        Info "  git remote add origin https://github.com/SEU-USUARIO/psicode.git"
        Info "  git push -u origin main"
        exit 1
    }
    Ok "repositorio privado criado e codigo enviado"
}

# -----------------------------------------------------------------------------
Passo "4/4  O que fazer agora no site"

$url = (Exec git @("remote", "get-url", "origin")).Texto
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
