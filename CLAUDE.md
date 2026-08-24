# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# psicode

Fonte unica de contexto deste repositorio: **`GEMINI.md`**. Ele vale para
qualquer assistente que trabalhe aqui — o arquivo esta importado abaixo, entao
nao duplique nada nele neste arquivo. Se algo precisar mudar, mude no
`GEMINI.md`.

@GEMINI.md

## Comandos

Nao ha linter. O portao de qualidade sao **dois** niveis, e vale rodar o rapido
primeiro:

```bash
godot --headless --path . --import                          # gera .godot/ ; rode antes do resto em maquina limpa
godot --headless --path . tools/testes/runner.tscn          # segundos ; "a conta esta certa?"
godot --headless --path . tools/teste_fumaca.tscn           # minutos ; "a run inteira funciona?"
godot --path . tools/capturar.tscn --resolution 960x544    # screenshots em user://capturas
godot --headless --path . --export-release "Windows Desktop"
godot --headless --path . --export-release "Web"
```

`tools/testes/` tem suites unitarias de verdade (Deterioracao, Balistica,
DadosArma, GameState, DadosSala, Modificadores). Para adicionar uma: crie o
arquivo, herde de `TesteBase`, implemente `executar()` e liste em `SUITES` no
`runner.gd`. Os helpers `ok`, `igual`, `perto` e `entre` dao conta.

**No teste de fumaca nao da para rodar "um teste so".** Ele e monolitico: os
asserts unitarios (balistica, limiares da Deterioracao) vivem em
`_testar_balistica()` e rodam no `_ready`, antes de o jogo subir; o resto e um
`_process` que mata os inimigos por script ate a run terminar. Para iterar num
assert isolado, comente a linha que instancia `main.tscn` no `_ready`.

O mesmo teste roda em todo push e PR pelo `.github/workflows/ci.yml`.

## Versao do Godot — conferir antes de confiar

As quatro fontes **concordam** desde a entrega da Fase 1, e concordam de
proposito: a build que vai para o testador sai do CI, entao ele tem de rodar o
mesmo engine que abriu o projeto.

| Onde | Diz |
|---|---|
| `project.godot` (`config/features`) | 4.7 |
| `GEMINI.md` e `README.md` | 4.7.2-stable |
| `.github/workflows/ci.yml` e `release.yml` (`GODOT_VERSAO`) | 4.7.2-stable |

Se for mudar de versao, mude nos quatro. O editor instalado nesta maquina e
**4.7.2-stable**, e nao esta no PATH:

```bash
GODOT="/c/Users/alcyn/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
```

Use a variante `_console.exe` — a outra nao devolve stdout, e o teste de fumaca
se comunica imprimindo.

## Arquitetura que so aparece lendo varios arquivos

**Ciclo de vida da run.** Nenhum autoload se inicia sozinho. `GameState` fica em
`Estado.MENU` ate alguem chamar `iniciar_run()`, e e essa chamada que liga
`Deterioracao.passiva_ativa` e destrava `alternar_pausa()`. O fim vem de
`GameState.terminar_run(venceu)`, que emite `EventBus.run_terminada` — o unico
sinal que a `tela_fim` e o teste de fumaca escutam. Derrota sai de
`player.gd`; a vitoria precisa de alguem chamando `terminar_run(true)`.
Ao mexer em quem hospeda a run, **verifique que essas duas chamadas
sobreviveram** — ja se perderam uma vez ao trocar a arena pelo sistema de salas,
e o sintoma foi silencioso: a Deterioracao passiva simplesmente parou de subir.

**Os inimigos sao escolhidos na montagem do andar, nao quando o jogador entra.**
Nao existe mais sistema de ondas — `GerenciadorOndas`, `DadosOnda`, os
`onda_*.tres` e o marcador de spawn foram removidos. O `GerenciadorMapa` sorteia
a composicao de cada celula em `_sortear_composicoes()`, ao fim de
`_montar_andar()`, e entrega a lista pronta a cada `Sala` por
`definir_composicao()`. A sala coloca tudo de uma vez em `ativar()` e vira
`LIMPA` quando o ultimo dos SEUS inimigos morre.

Tres consequencias que nao aparecem lendo um arquivo so:

- **Composicao vazia = sala sem combate**, decidido em `ativar()` e nao no
  `_ready` — no `_ready` a sala ainda nao recebeu a lista.
- **Os invocados da Diretora nao entram na contagem.** `Sala._vivos` guarda so
  quem a sala colocou, e e isso que faz a sala do chefe fechar pela morte dele e
  por mais nada.
- **A quantidade sai da AREA do contorno** vezes `DadosSala.densidade`, limitada
  por `orcamento_minimo`/`maximo`. Sala maior recebe mais sem tabela por cena; um
  `GrupoInimigo` de `custo` 2 ocupa o lugar de dois de custo 1, o que da "menos
  corpos, mais perigo" pelo mesmo botao.

**A camada de mapa e dirigida por dados, nao por codigo.** `src/mapa/` fecha o
loop: o `GerenciadorMapa` recebe um `Array[DadosSala]` (`tipos_de_sala` no
`main.tscn`) e cada `tipo_*.tres` carrega a propria regra de colocacao —
pendurada ou de preenchimento, exige beco, distancia minima da origem,
prioridade, mais a cor e o icone do minimapa. **Nao adicione um `@export` de
cena novo no gerenciador para criar um tipo de sala**: isso era o modelo antigo
(`cena_boss`/`cena_tesouro` + um `_pendurar_X` copiado por tipo) e foi removido
justamente por nao escalar. Tipo novo = `.tres` novo na lista.

**O minimapa le forma real, nao retangulo.** `src/ui/minimapa.gd` desenha o
contorno de `Sala.contorno_local()` — o mesmo `Line2D` `Parede` de onde nasce a
colisao — com escala unica para o andar todo, porque o layout e em bandas e
normalizar por celula mentiria sobre as distancias. Ele acha o gerenciador por
grupo e so consome a API publica (`contorno_global_de`,
`e_conhecida`, `esta_limpa`, `dados_da_celula`, `ligacoes`, `limites_do_andar`).

**Layers de fisica sao nomeadas** em `project.godot` — 1 `player`, 2 `inimigo`,
3 `parede`, 4 `projetil_player`, 5 `projetil_inimigo`, 6 `pickup`. Cena nova que
inventa layer numerica sem olhar essa tabela quebra colisao de um jeito dificil
de enxergar.

## So para o Claude

- Em sessao no Claude.ai ou no Cowork existe uma **skill `psicode`** com o
  mesmo conteudo mais `references/gdd.md`, `references/decisoes.md` e
  `references/armadilhas.md`. Ela e carregada sozinha quando o assunto e o
  jogo. No Claude Code, vale este arquivo.
- Com o MCP do Godot ativo (`docs/MCP.md`), prefira **ler o estado real** a
  supor: `get_scene_tree`, `get_node_properties`, `get_editor_errors`,
  `validate_script`. Um `.tscn` lido pelo MCP e mais confiavel que um lido como
  texto.
- Ferramenta de MCP dando timeout quase sempre significa **Godot fechado**, nao
  bug. Conferir antes de investigar qualquer outra coisa.
- Editar cena pelo MCP passa pelo undo do editor, mas **grava em disco so no
  save**. Depois de mexer em `.tscn`, chame `save_scene` — senao o `git status`
  nao vai ver a mudanca.
