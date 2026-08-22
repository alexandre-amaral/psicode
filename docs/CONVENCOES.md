# Convenções

Como três pessoas mexem no mesmo projeto sem pisar uma na outra.

---

## Git

**Branches**

```
main                    sempre jogável, sempre verde no CI
feat/<descricao>        funcionalidade nova
fix/<descricao>         correção
tune/<descricao>        só balanceamento (.tres)
docs/<descricao>        só documentação
```

Ninguém commita direto no `main`. Todo merge passa por Pull Request.

**Commits** — em português, imperativo, minúsculo, sem ponto final:

```
adiciona telegrafo no ataque em anel do chefe
corrige rolamento travando ao encostar na parede
ajusta vida do Vigia de 6 para 5
```

Um commit deve ser revertível sozinho. Se você precisa de "e" no meio da
mensagem, provavelmente são dois commits.

**Pull Requests** — um assunto por PR. Se mexeu em cena, diga qual no título,
porque isso avisa os outros que aquela cena está travada.

---

## Quem mexe em quê

A regra que evita 90% dos conflitos: **uma pessoa por cena por vez.**

Cenas (`.tscn`) são texto e dão merge, mas merge de cena é onde mais se perde
referência de nó. Antes de abrir uma cena que alguém pode estar mexendo,
avise no grupo. Scripts (`.gd`) são bem mais tolerantes — dois arquivos
diferentes nunca conflitam.

Sugestão de divisão para a Fase 1 (ajuste como quiserem):

| Área | Arquivos |
|---|---|
| Jogador e armas | `src/player/`, `src/weapons/` |
| Inimigos e chefe | `src/enemies/` |
| Arena, ondas e UI | `src/arena/`, `src/ui/` |

Balanceamento (`.tres`) qualquer um mexe — são arquivos pequenos e o conflito,
quando acontece, é trivial de resolver.

---

## Código

**Idioma.** Código em português: nomes de variável, função, sinal e comentário.
O time é brasileiro e o projeto é pequeno; misturar idiomas custa mais do que
ganha. Palavras que o Godot impõe (`_ready`, `velocity`, `queue_free`) ficam
como são, óbvio.

**Nomes**

```gdscript
class_name InimigoBase         # PascalCase
var velocidade_maxima: float   # snake_case
const LIMIAR_MEDIO := 50.0     # CONSTANTE_MAIUSCULA
signal onda_limpa(indice: int) # snake_case, no passado (algo aconteceu)
func _metodo_privado()         # underscore na frente
```

**Tipagem.** Sempre que der. `var vida: int = 6`, `func dano(x: int) -> bool`.
O Godot avisa mais cedo e o autocomplete funciona melhor.

**Comentários.** Comente o **porquê**, nunca o **quê**. `# soma 1 na vida` não
serve para nada. `# nao reinicia o clarao em andamento: com dano continuo o
inimigo fica branco permanente` serve.

**Documentação de arquivo.** Todo script começa com um bloco `##` explicando
o que ele faz e qual decisão de design ele carrega. É o que faz alguém
entender o arquivo sem precisar perguntar.

---

## Arquitetura — as duas regras que sustentam o projeto

**1. Comunicação por EventBus, não por caminho de nó.**

Nunca escreva `get_node("../../Player")` nem `get_parent().get_parent()`. Quem
faz algo emite um sinal no `EventBus`; quem se importa conecta.

```gdscript
# ruim -- quebra assim que alguem mover um no
get_node("/root/Main/HUD").atualizar_vida(vida)

# bom
EventBus.player_dano_recebido.emit(vida, vida_maxima)
```

Exceção legítima: procurar por **grupo** (`get_first_node_in_group("player")`),
que é o que os inimigos usam para achar o alvo.

**2. Dificuldade sempre vem de `Deterioracao`.**

Nenhum inimigo guarda uma velocidade já multiplicada. Todos leem o autoload no
frame em que precisam:

```gdscript
# ruim -- congela a dificuldade no momento do spawn
velocidade = 120.0 * Deterioracao.multiplicador_velocidade()

# bom -- responde a barra subindo, inclusive para quem ja esta em tela
func velocidade_atual() -> float:
    return velocidade_base * Deterioracao.multiplicador_velocidade()
```

---

## Números vão para `.tres`, não para o código

Se é um número que alguém vai querer ajustar sem programar, ele é um campo
`@export` ou um `Resource`. Armas e ondas já funcionam assim.

Quando adicionar um número novo, pergunte: "alguém vai querer mexer nisso numa
sessão de tuning?" Se sim, exporte.

---

## Antes de abrir o PR

```bash
godot --headless --path . tools/testes/runner.tscn   # segundos
godot --headless --path . tools/teste_fumaca.tscn    # minutos
```

Os dois precisam imprimir `PASSOU`. Rodam no CI também, mas rodar local
economiza a viagem — e o de cima termina em segundos, então rode ele primeiro.

São dois níveis de propósito:

| | Responde | Quando quebra |
|---|---|---|
| `tools/testes/` | "a conta está certa?" | você mexeu em lógica: Deterioração, Balística, um `.tres` |
| `tools/teste_fumaca.gd` | "a run inteira funciona?" | você mexeu em cena, spawn, fluxo de ondas ou salas |

**Mexeu num número de balanceamento?** Rode o unitário. Boa parte das suites
existe justamente para pegar erro de tuning: cadência 0 virando divisão por
zero, onda comum sem nenhum inimigo (a run trava ali), pistola perdendo a
munição infinita que o GDD promete.

**Criou lógica pura nova?** Adicione uma suite: crie o arquivo em
`tools/testes/`, herde de `TesteBase`, implemente `executar()` e liste em
`SUITES` no `runner.gd`. Não há framework — `ok`, `igual`, `perto` e `entre`
dão conta, e cada falha já diz o esperado e o obtido.

Se você mexeu em algo visual:

```bash
godot --path . tools/capturar.tscn --resolution 1280x720
```

e olhe as imagens em `user://capturas`. Vários problemas de leitura visual só
aparecem numa captura parada.
