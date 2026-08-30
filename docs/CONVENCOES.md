# Convenções

Como três pessoas mexem no mesmo projeto sem pisar uma na outra.

> Duas das três não conhecem Godot nem Git. Tudo aqui que alguém precise
> executar está escrito para ser copiado e colado; o passo a passo do zero é o
> [HANDOFF.md](HANDOFF.md).

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

O que **não** muda nunca: `main` sempre jogável. Se está quebrado, não está no
`main`.

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

**PR aberto não é trabalho entregue.** Um PR verde e esquecido é o mesmo que
trabalho não feito, e custa mais do que parece: as nove capturas do `README`
ficaram desatualizadas na página do GitHub por dias porque o PR que as refazia
seguiu aberto. Antes de começar frente nova, feche o que está aberto.

**O que não vai para o repositório**

```
.godot/                     cache do editor. Apagar resolve a maioria dos
                            problemas de import
[autoload] do godot_mcp     o plugin injeta três autoloads no project.godot ao
                            ser ativado, e os remove ao desativar
```

Os arquivos `.uid` (Godot 4.4+) **devem** ser commitados. E **desative o plugin
MCP antes de exportar build** — uma build publicada com autoload apontando para
script fora do pacote já aconteceu aqui.

---

## Quem mexe em quê

A regra que evita 90% dos conflitos: **uma pessoa por cena por vez.**

Cenas (`.tscn`) são texto e dão merge, mas merge de cena é onde mais se perde
referência de nó. Antes de abrir uma cena que alguém pode estar mexendo,
avise no grupo. Scripts (`.gd`) são bem mais tolerantes — dois arquivos
diferentes nunca conflitam.

**E não deixe cena pela metade numa branch.** Enquanto ela estiver aberta,
ninguém mais pode tocar naquele arquivo — e cena inacabada é o tipo de trabalho
que nem você consegue retomar depois de três dias. Termine ou reverta antes de
abrir a próxima.

Sugestão de divisão por área, para duas pessoas não abrirem a mesma cena
(ajuste como quiserem):

| Área | Arquivos |
|---|---|
| Jogador e armas | `src/player/`, `src/weapons/` |
| Inimigos e chefe | `src/enemies/` |
| Andar, salas e UI | `src/mapa/`, `src/ui/` |
| Implantes e loot | `src/items/` |

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
signal sala_limpa(sala: Node2D) # snake_case, no passado (algo aconteceu)
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

### ⚠️ O `project.godot` é do editor, não seu

Ele é reescrito e normalizado toda vez que o Godot salva: seções são reordenadas
e **comentários são apagados**. Não é hipótese — as três linhas que explicavam
por que `locale/fallback` tem de ser `pt_BR` já foram engolidas assim, sem
ninguém tocar no arquivo de propósito.

**Não documente nada dentro do `project.godot`.** Se uma decisão precisa de
explicação — a ordem dos autoloads, o motivo do fallback, o nome de uma layer de
física — ela mora no `GEMINI.md`, que ninguém reescreve automaticamente.

E confira o diff dele antes de commitar. Ele aparece modificado com frequência
por motivos que não são seus.

### Texto de tela: `tr()` vem ANTES da substituição

A chave de tradução **é o próprio texto em português** — o `.tres` guarda
`"Nucleo de Reserva"` e a tabela mapeia para `"Reserve Core"`. Isso mantém o
Inspetor legível, mas cobra uma disciplina ao montar texto com `%`: traduz-se o
molde, nunca o resultado.

```gdscript
_rotulo.text = tr("Municao: %d") % municao    # certo
_rotulo.text = tr("Municao: %d" % municao)    # errado: "Municao: 14" não bate
                                              # com chave nenhuma, e some em silêncio
```

Texto novo que o jogador lê entra na tabela **na mesma mudança que o cria** —
nunca editando `locale/textos.csv` à mão, sempre por `tools/i18n/gerar_csv.py`.
`teste_traducao.gd` reprova quem esquecer.

As armadilhas de i18n já registradas (chave com quebra de linha, `fallback` em
`pt_BR`, botão com marcador `>`, suíte que precisa fixar o idioma) estão no
`GEMINI.md` — uma verdade por assunto.

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
`@export` ou um `Resource`. Armas, tipos de sala, grupos de inimigo e
implantes já funcionam assim.

Quando adicionar um número novo, pergunte: "alguém vai querer mexer nisso numa
sessão de tuning?" Se sim, exporte.

E o número tem de **nascer medível**: botão que ninguém consegue medir é botão
que a sessão de tuning não consegue girar. As réguas de `tools/` existem para
isso.

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
| `tools/teste_fumaca.gd` | "a run inteira funciona?" | você mexeu em cena, spawn ou no fluxo de salas |

**Mexeu num número de balanceamento?** Rode o unitário. Boa parte das suites
existe justamente para pegar erro de tuning: cadência 0 virando divisão por
zero, sala de recompensa com inimigo dentro, custo de inimigo zerado (o sorteio
de composição nunca terminaria), pistola perdendo a munição infinita que o GDD
promete.

**Criou lógica pura nova?** Adicione uma suite: crie o arquivo em
`tools/testes/`, herde de `TesteBase`, implemente `executar()` e liste em
`SUITES` no `runner.gd`. Não há framework — `ok`, `igual`, `perto` e `entre`
dão conta, e cada falha já diz o esperado e o obtido.

### O que cada ferramenta prova — e o que ela NÃO prova

| Ferramenta | Prova | **Não** prova |
|---|---|---|
| `--import` | Classes globais registradas, assets importados | Nada sobre script que nenhuma cena alcança |
| `teste_fumaca` | A run inteira: andar, salas, chefe, vitória | Cor, textura, parede, enquadramento — ele nunca encosta na parede nem olha um pixel |
| `runner.tscn` | A conta, e a paleta pelos portões G1/G2/G3 | Se o resultado **parece** bom |
| `capturar.tscn` | Leitura visual | Só funciona **com janela** — nunca `--headless` |

### ⚠️ A armadilha do falso verde

Exit 0 não significa "o projeto está são". Um script com erro de parse em
`src/` que **nenhuma cena alcança** passa nos dois jobs do CI sem um aviso.

Hoje isso é um buraco real aqui: `runner.gd` valida com `can_instantiate()`,
mas só os scripts listados em `SUITES`. E o `teste_fumaca` sobe o `main.tscn`,
que não alcança `intro.tscn`, `menu_inicial.tscn` nem `selecao_personagem.tscn`.
Uma suíte que varra todo `.gd` de `src/` fecharia isso.

O detector confiável é `can_instantiate()`. Os dois jeitos óbvios **não**
funcionam:

- **`load(...) == null` nunca dá `null`.** Script com erro de parse volta como
  objeto; os erros só aparecem no stderr.
- **`reload()` dá falso positivo.** Retorna `22` (`ERR_UNAVAILABLE`) em qualquer
  script que já tenha instância viva — o que inclui **todo autoload**.

```gdscript
var s: Script = ResourceLoader.load(caminho, "Script", ResourceLoader.CACHE_MODE_IGNORE)
if s == null or not s.can_instantiate():
    # quebrado
```

`CACHE_MODE_IGNORE` serve ao runner headless, onde nada do jogo está
instanciado. **Dentro do editor ele dá falso negativo**, porque cena aberta
conta como instância viva.

### ⚠️ Autoload novo exige reabrir o editor

O Godot lê a seção `[autoload]` do `project.godot` uma vez, no boot. Se o
arquivo for editado por fora com o editor aberto — que é exatamente o que
acontece ao ativar o plugin MCP — o editor continua sem conhecer o
identificador, e **todo script que o mencionar** passa a acusar:

```
Compile Error: Identifier not found: EventBus
```

O erro é convincente e mentiroso: o código está certo e uma instância nova sobe
com exit 0. Antes de investigar, **rode o projeto numa instância limpa**. Se lá
passa, o problema é a sessão do editor — feche e reabra.

E `/root/EventBus` **não existe dentro do editor**, o que é normal: o editor
registra o autoload para o parser, mas o nó só existe com o jogo rodando.
Checar pelo nó leva a concluir que o autoload está quebrado quando ele está
perfeito.

### Mexeu em algo visual

```bash
godot --path . tools/capturar.tscn --resolution 960x544
```

As imagens saem em `user://capturas`. Vários problemas de leitura visual só
aparecem numa captura parada.

**Se a mudança altera o que se vê em jogo, copie as nove para
`docs/capturas/`.** Elas são versionadas de propósito: o `README` as usa na
primeira dobra, e como estão no git o diff mostra exatamente o que mudou na
tela — é o jeito mais barato de perceber que um ajuste estragou a leitura do
combate.

A pergunta que decide, sempre a mesma: **um projétil inimigo continua tão fácil
de achar quanto antes?** Se a resposta hesita, a mudança não entra ainda.

### Réguas

Além dos testes que passam ou falham, existem **réguas** em `tools/`. Elas não
aprovam nada — elas **medem**, e a saída delas é o que sustenta uma sessão de
tuning. Ver [TUNING.md](TUNING.md).

| Régua | Mede | Responde |
|---|---|---|
| `medir_ritmo` | Em que minuto da run cada limiar da Deterioração cai | "a dificuldade sobe no lugar certo?" |
| `medir_composicao` | Composição de inimigos ao longo de muitos andares gerados | "a sala-corredor virou uma parede de corpos?" |
| `medir_armas` | DPS de pico, DPS sustentado e tempo para matar cada inimigo | "quantos segundos leva para matar um Vigia?" |

Nenhuma delas entra no `runner` nem roda no CI, de propósito.

Régua nova entra **junto do sistema que ela mede**, nunca antes: régua que mede
o vazio é cerimônia. Pelo mesmo motivo, nenhum teste é escrito antes de existir
lógica para testar.
