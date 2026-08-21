# psicode

Fonte unica de contexto deste repositorio: **`GEMINI.md`**. Ele vale para
qualquer assistente que trabalhe aqui — o arquivo esta importado abaixo, entao
nao duplique nada nele neste arquivo. Se algo precisar mudar, mude no
`GEMINI.md`.

@GEMINI.md

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
