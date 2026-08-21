# Gerar builds

As duas presets já estão configuradas em `export_presets.cfg` e **foram
testadas**: a build de Windows gera um `.exe` único e a build web roda em
navegador sem erro de console.

## Pré-requisito, uma vez por máquina

O Godot precisa dos *export templates* (≈1,2 GB, download único):

**Editor → Gerenciar Modelos de Exportação → Baixar e Instalar**

Sem eles a exportação falha dizendo que não encontrou o template.

## Pelo editor

`Projeto → Exportar…` → escolha a preset → **Exportar Projeto**.

| Preset | Saída |
|---|---|
| Windows Desktop | `builds/windows/psicode.exe` — arquivo único, ~100 MB, com o jogo embutido |
| Web | `builds/web/` — `index.html` + `.wasm` + `.pck`, ~37 MB |

## Pela linha de comando

```powershell
godot --headless --path . --export-release "Windows Desktop"
godot --headless --path . --export-release "Web"
```

## Testar a build web localmente

Não abra o `index.html` com duplo clique — o navegador bloqueia o carregamento
do `.wasm` por `file://`. Suba um servidor:

```powershell
cd builds\web
python -m http.server 8000
```

e acesse `http://localhost:8000`.

## Publicar no itch.io (o caminho para os testadores)

1. Crie o projeto em https://itch.io/game/new
2. **Kind of project: HTML**
3. Zipe o **conteúdo** de `builds/web/` — o `index.html` tem que estar na raiz
   do zip, não dentro de uma pasta
4. Faça upload e marque **"This file will be played in the browser"**
5. Viewport: `1280 x 720`, com *fullscreen button* ligado
6. Visibilidade **Restricted** com senha enquanto for teste fechado

O testador clica num link e joga. Sem download, sem aviso do SmartScreen,
sem "confia em mim, pode abrir".

> A preset web usa `thread_support=false` de propósito. Com threads ligadas o
> Godot exige os cabeçalhos `COOP`/`COEP` no servidor, o que o itch.io só
> oferece com uma opção extra e quebra em vários navegadores. Sem threads o
> jogo roda em qualquer lugar — e este projeto não precisa delas.

## Tamanho

O `.exe` de 100 MB é o normal do Godot: o executável carrega o runtime inteiro.
Compactado em `.zip` cai bastante. Se isso incomodar depois, dá para compilar
um template customizado sem os módulos que não usamos — mas é otimização para
a Fase 5, não para agora.
