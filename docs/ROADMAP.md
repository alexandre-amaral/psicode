# Roadmap

> **Este documento foi reescrito.** A versão anterior organizava o trabalho em
> cinco fases sequenciais, e o trabalho não aconteceu assim: a Fase 2 entrou no
> meio da Fase 3, a seleção de personagem entrou fora de qualquer fase, e dois
> itens da Fase 5 foram entregues sem ninguém abrir aquela seção. O que resta
> está organizado por **marco entregável**, na ordem em que será atacado.
>
> O histórico das fases concluídas está no fim, condensado.

---

## Onde o jogo está hoje

Contado do disco, não de memória:

| | |
|---|---|
| Tipos de inimigo | **8** + 1 hazard (área de perigo do Parasita) |
| Implantes | **16**, todos no pool de loot |
| Armas | **10** — 4 do jogador, 6 de inimigo |
| Armas que caem como loot | **1** (a shotgun) |
| Tipos de sala | **5**, em **9** cenas; andar de 8–12 salas |
| Personagens jogáveis | **2** (RAVEN, NOVA), com 8 direções e ciclo de caminhada |
| Idiomas | **2** (pt-BR, en) — 81 strings |
| Suítes de teste | **17**, 1420 verificações + teste de fumaça da run inteira |

**O que o jogo já faz:** um andar de 8–12 salas sorteadas com lockdown por sala,
minimapa com a silhueta real, chefe em três fases, Deterioração que escala tudo
no frame de uso, 16 implantes com efeitos condicionais e comportamentais,
escolha de operador com armas de identidade própria, e um status effect com
duração (o Hack da NOVA). Tudo isso texturizado e em dois idiomas.

**O que o jogo não faz:** som. Nenhum. Zero `AudioStreamPlayer`, zero arquivo de
áudio, nenhum bus configurado.

---

## A mudança de escopo

O alvo passou a ser **lançamento comercial**. Isso precisa estar escrito, porque
contradiz o que os outros documentos dizem hoje — o `GEMINI.md` declara o
objetivo como *"diversão e aprender fazendo"*, e o `GDD.md` descreve um vertical
slice. Roadmap que contradiz o contexto em silêncio vira desculpa para decisão
ruim seis meses depois.

Fica registrado sem rodeio: **o time é de três pessoas em tempo parcial, e duas
não conhecem Godot nem Git.** Isso não impede um lançamento; muda o que ele
custa. Comercial acrescenta três frentes que um vertical slice não tem:

1. **Escopo maior** — um andar não sustenta um jogo à venda. Vários andares,
   mais personagens, mais armas.
2. **Acabamento** — som, gamepad, salvamento, remapeamento. São itens que
   ninguém elogia e todo mundo cobra.
3. **Trabalho que não é o jogo** — página de loja, trailer, demo, wishlists.
   Consome tempo de quem faria o jogo.

Se em algum momento essas três frentes ficarem pesadas demais, o corte honesto
é reduzir o **escopo** (menos andares) e não o **acabamento**: jogo pequeno e
polido vende; jogo grande e cru não.

---

## M1 — O loop fecha *(próximo)*

Hoje morrer volta ao zero absoluto. É a peça que separa "uma run boa" de
"roguelike".

**A semente já existe e está parada:** `GameState.creditos` acumula a cada abate
(`inimigo_base.gd:199`), a tela de fim mostra o total, e **nada consome**. É um
contador sem ralo. A moeda do jogo já é ganha; falta onde gastar.

A ordem interna importa — sem persistência, nada do resto sobrevive:

- [ ] **Autoload `Progresso` + `user://progresso.cfg`.** Arquivo separado do
      `config.cfg`: o doc-comment de `configuracao.gd` proíbe explicitamente que
      progresso entre ali, *"senão a config vira o save e perde a simplicidade de
      poder ser apagada sem consequência"*. Cuidado herdado de
      `GameState.personagem`: campo que sobrevive à run **não pode** entrar no
      bloco que `iniciar_run()` zera
- [ ] **Créditos viram Núcleos de Memória** — a moeda que atravessa a morte
- [ ] **Loot dropado** por inimigo e por sala. Hoje só existe o pickup fixo da
      sala de arma; crédito vai direto para o contador sem passar pelo chão
- [ ] **Loja entre runs**, gastando Núcleos
- [ ] **Desbloqueios**: implante, arma e personagem que começam travados
- [ ] **Mais armas no pool.** São 4 armas de jogador, mas **só a shotgun cai**;
      Mantis e Cipher são exclusivas de personagem. "Arma nova encontrável"
      segue em 1

**Saída:** morrer deixa alguma coisa para trás, e a próxima run começa diferente.

---

## M2 — O jogo tem som

O buraco mais visível do projeto. Não há um único som.

- [ ] Bus de áudio (`Master` / `SFX` / `Música`) e um autoload no molde do
      `Juice` — mesma disciplina de chaves separadas e preferência persistida
- [ ] Feedback sonoro: tiro, impacto, dano, morte, telegrafo do chefe, pickup
- [ ] Música que **degrada junto com a barra** (filtro/distorção crescente) — o
      GDD promete isso e é o que amarra som à mecânica central
- [ ] Sliders de volume nas Opções, junto das chaves de acessibilidade

> Está em M2 por decisão de ordem, mas vale o registro: **é o item que mais muda
> a percepção de "jogo terminado"**. Se em algum momento a ordem for revista,
> este é o candidato natural a subir.

**Saída:** a mesma build, com peso.

---

## M3 — Mais jogo

O que transforma um andar num jogo à venda.

- [ ] **Vários andares.** Hoje `GerenciadorMapa` monta um só. Precisa de contador
      de andar, escalada entre andares, e o que muda a cada um
- [ ] **Sprites dos 7 inimigos restantes.** Só a Diretora tem sprite; os outros
      sete são `Polygon2D`/`Line2D`. Projéteis e pickups também
- [ ] **Animação do chefe** — ele tem sprite, mas estático
- [ ] **Pathfinding.** A dívida que o roadmap antigo previu e **que já mordeu**:
      as salas em L e com pilar estão em produção no `tipo_combate.tres`, e quem
      persegue encalha nelas. A costura existe:
      `InimigoBase.direcao_de_locomocao()`
- [ ] **Mais personagens** — `DadosPersonagem` já torna isso um `.tres` mais arte
- [ ] **Implantes que substituem o rolamento**: dash cortante, jetpack, escudo

**Saída:** uma sessão de 20–30 minutos que não repete.

---

## M4 — A IA Diretora heurística

O sistema que dá nome ao jogo e que **ainda não existe** — hoje "Diretora" é
apenas o nome do chefe final. A composição de sala é sorteada por orçamento de
área × densidade com porta de Deterioração: isso é dificuldade progressiva, não
leitura do jogador.

- [ ] Instrumentar: distância média, frequência de esquiva, arma preferida,
      tempo parado
- [ ] Classificar em 3–4 arquétipos (encostado, sniper, esquivador, camper)
- [ ] Tabela de counters: que composição pressiona cada arquétipo
- [ ] Popular as salas seguintes com essa leitura
- [ ] Tornar isso **legível** — se o jogador não percebe que está sendo lido, o
      sistema não existe do ponto de vista da experiência

> Maior diferencial e maior risco do projeto. Pode virar um sistema que ninguém
> nota, ou pior, que parece só aleatório e injusto. Vale prototipar tosco e cedo,
> e testar se as pessoas percebem — antes de investir.

**Saída:** duas pessoas jogando o mesmo jogo e enfrentando salas diferentes.

---

## M5 — Lançamento

- [ ] **Gamepad.** Hoje **nenhuma** das 11 ações tem evento de joypad. Para um
      twin-stick, isso não é acabamento — é metade do público
- [ ] Remapeamento de controles
- [ ] Salvamento de run em andamento
- [ ] Página de loja, trailer, demo
- [ ] Créditos e licenças de terceiros

O **i18n pt-BR/en já está pronto** e é ativo aqui: alcance de loja dobrado sem
trabalho novo.

---

## Dívidas técnicas

| Item | Onde | Situação |
|---|---|---|
| Sem pathfinding | `src/enemies/inimigo_base.gd` | **Bloqueia M3.** Já em produção: salas em L e com pilar prendem quem persegue |
| Sem áudio nenhum | — | **É o M2 inteiro**, não uma dívida lateral |
| Projéteis instanciados a cada tiro | `src/weapons/arma.gd` | Sem custo hoje. Pooling só importa quando o bullet hell ficar denso |
| Partículas sem pooling | `src/fx/` | Idem |
| Dano de contato por distância, não Area2D | `src/enemies/inimigo_base.gd` | Sem custo. Trocar quando houver hitbox por parte do corpo |
| Sem y-sort | todo o projeto | Novo. O sprite do jogador tem 62 px e cobre a parede ao encostar; ordenação é `z_index` manual |
| `dev/null/` versionada | raiz | Lixo: 4 hooks do Git LFS escritos num caminho literal por engano (commit `5c69867`). Inertes — o Git só executa hooks em `.git/hooks/`. Seguro remover |
| `animations/` fora do versionamento | `.gitignore` | Deliberado: é a **entrada** do gerador de sprites, não a saída. Quem for regerar precisa dos GIFs |

---

## Histórico

**Fase 0 — base técnica.** Stack decidida, repositório com LFS e CI, handoff
escrito, POC rodando. As ondas daquela POC foram substituídas pelo andar de
salas.

**Fase 1 — game feel e primeiro playtest.** Instrumentos de tuning
(`docs/TUNING.md` e duas réguas headless), correção do pico da mira preditiva,
CI e release na mesma versão do editor, build Windows e web, `v0.2.0-alpha` no
itch.io privado, link para 5–8 pessoas.

> **A leitura do playtest, que não pode se perder:** voltou positivo e **sem
> nenhum problema acionável**. Cinco a oito pessoas sem uma reclamação é **sinal
> fraco, não aprovação** — costuma significar pergunta que não mordeu ou
> testador sendo gentil. A pergunta que a fase existia para responder — *"é
> divertido sem arte e sem som?"* — foi respondida de forma rasa. Quem apostar
> alto em cima disso está apostando em cima de pouco.

**Dois itens da Fase 1 seguem abertos e não bloqueiam nada:** a sessão de tuning
dos três juntos (os instrumentos estão prontos, falta a conversa) e o rebalanceio
da vida do chefe pelo tempo de luta observado — a régua diz 59 s a 2min10, a
faixa boa é 60–90 s, e o tempo é dominado pelo uptime, não pela vida.

**Entregue depois disso, fora de qualquer fase:** texturas de sala geradas por
código (`docs/IDENTIDADE_VISUAL.md`), cinco tipos de inimigo novos, seleção de
personagem com dois operadores, sprites direcionais com ciclo de caminhada, e a
internacionalização completa.
