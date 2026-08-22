# MCP do Godot

Liga um assistente de IA direto no editor do Godot aberto: ler a arvore de
cena, criar no, mexer em propriedade, conectar sinal, rodar a cena, tirar
screenshot, ler o log de erro. Sao 173 ferramentas.

Como funciona:

```
cliente de IA  <--stdio-->  servidor Node  <--WebSocket:6505-->  plugin no editor
```

Os tres precisam estar de pe. Se o Godot estiver fechado, o servidor sobe mas
nao responde nada — e o sintoma numero um de "nao funciona".

Implementacao usada: https://github.com/mkdevkit/godot-mcp (MIT).

---

## Instalacao — uma vez so

Tudo isso e no PowerShell do Windows.

### 1. Conferir os pre-requisitos

```powershell
node --version
git --version
```

`node` precisa ser 18 ou maior. Se nao existir, instalar em
https://nodejs.org (LTS) e abrir um PowerShell novo depois.

### 2. Baixar e compilar o servidor

Fora do OneDrive, de proposito: `node_modules` tem milhares de arquivos
pequenos e o OneDrive sincronizando isso trava a maquina.

```powershell
git clone https://github.com/mkdevkit/godot-mcp.git C:\dev\godot-mcp
cd C:\dev\godot-mcp\server
npm install
npm run build
```

O `npm run build` precisa terminar sem erro e criar
`C:\dev\godot-mcp\server\build\index.js`. Confere:

```powershell
Test-Path C:\dev\godot-mcp\server\build\index.js
```

Tem que imprimir `True`.

### 3. Instalar o plugin no psicode

```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\OneDrive\Documents\psicode\addons"
Copy-Item -Recurse -Force C:\dev\godot-mcp\addons\godot_mcp "$env:USERPROFILE\OneDrive\Documents\psicode\addons\"
```

Abrir o projeto no Godot e ligar em:
**Projeto -> Configuracoes do Projeto -> Plugins -> Godot MCP -> Ativar**

O Output do editor tem que imprimir `[Godot MCP] Plugin started`.

### 4. Apontar o cliente

O arquivo `.mcp.json` na raiz do projeto ja esta escrito e e lido
automaticamente pelo Claude Code quando aberto nessa pasta. Ele nao vai para
o Git — o caminho e por maquina.

Para o app do Claude no desktop, colar isso em
`%APPDATA%\Claude\claude_desktop_config.json` e reiniciar o app:

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "node",
      "args": ["C:/dev/godot-mcp/server/build/index.js"],
      "env": { "GODOT_MCP_PORT": "6505" }
    }
  }
}
```

Se o app reclamar que nao acha `node`, trocar `"node"` pelo caminho
completo — descobre com `(Get-Command node).Source`.

---

## Ordem de uso, sempre

1. Abrir o psicode no Godot.
2. Abrir o cliente de IA.
3. Testar com um pedido barato: "pegue a arvore de cena atual".

---

## Duas armadilhas deste projeto

**Ativar o plugin mexe no `project.godot`.** Ele injeta tres autoloads
(`MCPRuntimeBridge`, `MCPInputBridge`, `MCPScreenshotBridge`) e os remove ao
desativar. Ou seja: o `project.godot` fica sujo no `git status` so por ter
ligado o plugin. Nao commitar essas linhas, e **desativar o plugin antes de
exportar build** — senao os tres autoloads vao junto para a build de
playtest.

**O OneDrive sincroniza a pasta `.godot/`.** Ela e cache do editor, ja esta
no `.gitignore`, mas o OneDrive nao le `.gitignore`. Sincronizar cache do
Godot causa arquivo travado e reimport do nada. Vale tirar `.godot` da
sincronizacao em Configuracoes do OneDrive -> Conta -> Escolher pastas.

---

## Nao funcionou

| Sintoma | Causa quase certa |
|---|---|
| Cliente conecta, toda ferramenta da timeout | Godot fechado, ou plugin desativado |
| `[Godot MCP] Plugin started` nao aparece | Pasta copiada errado — tem que ser `addons/godot_mcp/plugin.cfg` |
| Cliente nao lista o servidor | Caminho do `index.js` errado, ou `npm run build` falhou |
| Porta em uso | Trocar 6505 nos dois lados: `GODOT_MCP_PORT` e o painel do plugin |
| Ferramentas de runtime nao respondem | So funcionam com o jogo em Play dentro do editor |
