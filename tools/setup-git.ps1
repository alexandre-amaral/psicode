# =============================================================================
#  psicode - setup de Git no Windows
#
#  Instala Git, Git LFS e GitHub CLI, configura sua identidade e autentica
#  no GitHub. Roda do zero numa maquina que nunca viu Git.
#
#  Como usar:
#    1. Menu Iniciar -> digite "PowerShell" -> Enter (NAO precisa ser admin)
#    2. cd C:\dev\psicode
#    3. .\tools\setup-git.ps1
#
#  Se o PowerShell reclamar que scripts estao desabilitados, rode antes:
#    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
# =============================================================================

$ErrorActionPreference = "Stop"

function Passo($texto) { Write-Host "`n=== $texto ===" -ForegroundColor Cyan }
function Ok($texto)    { Write-Host "  [ok] $texto"    -ForegroundColor Green }
function Aviso($texto) { Write-Host "  [!]  $texto"    -ForegroundColor Yellow }

# -----------------------------------------------------------------------------
Passo "1/5  Instalando Git, Git LFS e GitHub CLI"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Aviso "winget nao encontrado nesta maquina."
    Aviso "Instale manualmente e rode este script de novo:"
    Aviso "  Git      https://git-scm.com/download/win"
    Aviso "  Git LFS  https://git-lfs.com"
    Aviso "  GitHub CLI  https://cli.github.com"
    exit 1
}

# --silent evita telas de instalador; --accept-* evita prompts de licenca.
# Se ja estiver instalado, o winget devolve codigo de 'no applicable upgrade'
# e seguimos em frente -- por isso o ErrorAction fica silencioso aqui.
foreach ($pkg in @("Git.Git", "GitHub.GitLFS", "GitHub.cli")) {
    Write-Host "  instalando $pkg ..."
    winget install --id $pkg --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
}

# O instalador mexe no PATH, mas a sessao atual do PowerShell ainda nao sabe.
# Recarregar evita o classico "git nao e reconhecido" logo apos instalar.
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")

foreach ($cmd in @("git", "gh")) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Aviso "'$cmd' ainda nao esta no PATH."
        Aviso "FECHE este PowerShell, abra outro e rode o script de novo."
        exit 1
    }
}
Ok (git --version)
Ok (gh --version | Select-Object -First 1)

# -----------------------------------------------------------------------------
Passo "2/5  Sua identidade nos commits"

$nomeAtual  = git config --global user.name
$emailAtual = git config --global user.email

if ([string]::IsNullOrWhiteSpace($nomeAtual)) {
    $nome = Read-Host "  Seu nome (aparece em todo commit)"
    git config --global user.name "$nome"
} else { Ok "nome ja configurado: $nomeAtual" }

if ([string]::IsNullOrWhiteSpace($emailAtual)) {
    Write-Host "  Use o MESMO e-mail da sua conta GitHub, senao os commits nao" -ForegroundColor DarkGray
    Write-Host "  aparecem vinculados ao seu perfil." -ForegroundColor DarkGray
    $email = Read-Host "  Seu e-mail do GitHub"
    git config --global user.email "$email"
} else { Ok "e-mail ja configurado: $emailAtual" }

# -----------------------------------------------------------------------------
Passo "3/5  Configuracoes que evitam dor de cabeca"

# Padrao antigo do Git ainda e 'master'; o GitHub usa 'main'.
git config --global init.defaultBranch main

# Merge no pull. Rebase automatico confunde quem esta comecando e reescreve
# historico sem avisar.
git config --global pull.rebase false

# Caminhos longos: Godot gera caminhos profundos em .godot/ e o limite de
# 260 caracteres do Windows estoura.
git config --global core.longpaths true

# Nao deixa o Git converter fim de linha por conta propria -- quem manda e o
# .gitattributes do projeto. Sem isso, Windows e Linux geram diff de arquivo
# inteiro sem ninguem ter mudado nada.
git config --global core.autocrlf false

Ok "init.defaultBranch = main"
Ok "pull.rebase = false"
Ok "core.longpaths = true"
Ok "core.autocrlf = false"

# -----------------------------------------------------------------------------
Passo "4/5  Git LFS"

# Registra os filtros do LFS na sua maquina. Roda uma vez por usuario.
# O .gitattributes do projeto ja tem as regras para sprite, som e fonte:
# quando a arte entrar na Fase 2, ela vai para o LFS sozinha.
git lfs install
Ok "filtros do LFS registrados"

# -----------------------------------------------------------------------------
Passo "5/5  Autenticacao no GitHub"

$statusGh = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Vai abrir o navegador. Escolha:" -ForegroundColor DarkGray
    Write-Host "    GitHub.com  ->  HTTPS  ->  Yes (autenticar o Git)  ->  Login with a web browser" -ForegroundColor DarkGray
    gh auth login
} else { Ok "ja autenticado" }

gh auth setup-git
Ok "Git passa a usar as credenciais do gh -- sem digitar senha em push"

Write-Host "`nSetup concluido." -ForegroundColor Green
Write-Host "Proximo passo: .\tools\criar-repo.ps1`n"
