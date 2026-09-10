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
| Tipos de inimigo | **8** + 2 peças da arena do chefe (núcleo e torre) + 1 hazard |
| Implantes | **16**, todos no pool de loot |
| Armas | **10** — 4 do jogador, 6 de inimigo |
| Armas que caem como loot | **1** (a shotgun) |
| Tipos de sala | **5**, em **9** cenas; andar de 8–12 salas |
| Personagens jogáveis | **2** (RAVEN, NOVA), com 8 direções e ciclo de caminhada |
| Idiomas | **2** (pt-BR, en) — 81 strings |
| Suítes de teste | **21**, 1837 verificações + teste de fumaça da run inteira |

**O que o jogo já faz:** um andar de 8–12 salas sorteadas com lockdown por sala,
minimapa com a silhueta real, chefe em quatro fases, a última com a arena atacando, Deterioração que escala tudo
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
- [ ] **Firewall Cinético** — paredes holográficas que atravessam a arena das
      extremidades para o centro, deixando só um corredor de passagem; em fases
      avançadas duas surgem de lados opostos e podem mudar de direção no último
      instante. **Requisito não negociável: a abertura tem de existir sempre** —
      é a trava 6 da identidade da Diretora (GDD). Parede sólida que empurra
      pede `AnimatableBody2D`, e uma que prenda o jogador contra o contorno é
      morte inevitável; foi por isso que a fase Absoluta entregou paredes que
      **acendem e ferem** em vez de deslizar
- [ ] **Execução Administrativa** — a sequência de vida baixa: a arena se
      bloqueia, vários sistemas de mira aparecem juntos, e o chefe monta uma
      ordem de ataques a partir do que registrou da luta inteira. Depende de o
      `PerfilJogador` guardar histórico por ataque, e não só a tendência atual
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

**`v0.3.0-alpha`.** Três entregas e três defeitos de produção que apareceram no
caminho delas:

- **Drone Aranha com oito rotações e ciclo de caminhada.** O nó
  `SpriteDirecional` deixa o próximo inimigo com arte custar um `.tscn` e não
  código; o mapa de ângulo→quadro saiu para `src/util/direcoes.gd`, uma fonte
  só para personagem e inimigo.
- **Piso do andar 1 refeito.** Estava com luminância 8–14 e densidade de detalhe
  de 0,8% a 4,3% — abaixo da faixa 8–18% que o próprio funil declara. Agora
  26–29 e 9–11%. A faixa de matiz do andar alargou para 185–320 para caber o
  acento ciano e magenta da arte; é seguro porque quem separa mapa de ator é o
  **teto de valor**, e ele não mudou.
- **A Diretora ganhou repertório que lê o jogador**, quarta fase com a arena
  atacando, e o corpo passou de 47 px (menor que o jogador, com hitbox de 88 px
  invisível) para 192 px. E ganhou `teste_diretora.gd`, um portão executável de
  identidade: dez travas, escritas **antes** da mudança e rodadas verdes contra
  o código antigo.

> **Os três defeitos, todos vivos desde antes desta versão e nenhum com erro no
> console:** a varredura da `AreaDePerigo` nunca varreu ninguém (ficar parado no
> círculo do Parasita era o jeito mais seguro de sobreviver a ele); o telegrafo
> dela desenhava **embaixo** do chão; e o `project.godot` tinha voltado a
> carregar os autoloads do `godot_mcp`, que a preparação da v0.1.0 havia
> removido — uma build publicada assim subiria com autoload apontando para
> script fora do pacote, e o `mcp_runtime_bridge` lê `user://` todo frame. O
> `BUILD.md` passou a ter esse passo no pré-voo, que era onde ele faltava.

**`v0.5.1-alpha`.** O andar 1 deixou de ser **um plano com móveis nos cantos**: a
fábrica ganhou decoração, luz e volume, o inventário passou a caber duas armas, e
os 26 itens de prateleira ganharam **ícone**. É a versão em que a arte chegou aos
três lugares em que o jogo mais mentia sobre si mesmo — a peça, a parede e o
pickup.

**Os ícones vieram com a régua ANTES da arte.** As 26 peças — 16 implantes e as
10 armas de prateleira — foram medidas em par (325 pares) antes de existir a
primeira: cruas, **doze das dezesseis** reprovavam a faixa de leitura e três
passavam do teto de competição com projétil. O funil **assenta o valor e só
desce**; as duas peças escuras demais foram **redesenhadas**, não clareadas —
clarear para passar num número é inventar iluminação.

- **Prateleira metade ilustrada não lê como duas categorias: lê como ícone
  quebrado.** Os ícones entraram só nos implantes, e o dono jogou e reportou
  *"alguns ícones não estão funcionando na Loja"*. Medido: **303 de 600** ofertas
  são arma. Cada metade estava certa sozinha, e portão nenhum pegava isso —
  família visual só pode ser entregue **inteira**.
- O losango sólido **saiu de baixo** do ícone: sendo opaco ele emoldurava o
  desenho e roubava a silhueta, que é justamente o que a régua mede. A cor passou
  ao halo, que já existia e nunca tinha recebido a cor da peça.
- `no_background` do PixelLab **não devolve alfa**: as 16 voltaram 100% opacas,
  com o fundo em dois tons quase iguais. O recorte é por **preenchimento a partir
  da borda**, nunca por cor — o fundo do `vampirico` é da mesma família do aço da
  própria seringa.

**O inventário corporal e os dois slots de arma** (INV 01–28): três abas — ITENS
sem teto, ARMAMENTO com exatamente dois, STATUS **derivado** dos outros dois. Não
é arrumação: são três perguntas com regras diferentes, e fundir duas obriga o
jogador a descobrir sozinho qual delas vale para o que ele acabou de pegar.

- **O pente virou estado do SLOT.** `equipar()` enchia o pente toda vez, então
  sair da Mantis com 3/32 e voltar devolvia 32/32 de graça — uma arma que nunca
  precisa recarregar desde que você alterne antes.
- `Arma.ficou_sem_municao` **nunca disparou**: as 21 armas têm reserva infinita, e
  o código que ele executava afirmava uma regra morta (voltar para o slot 0, que
  não existe mais). Código morto que afirma regra falsa é pior que código morto.
- Quatro defeitos de layout que portão nenhum pega saíram da **captura**, e não
  da lógica: `draw_string` alinhado à direita desenhando **fora** do painel, nome
  entrando por cima da coluna de barras, nome cortado no meio da palavra, e
  tabelas esticadas por 904 px.

**A fábrica do andar 1.** A sala montava tudo por posições isoladas — o sistema
de **clusters existia, era testado, era medido, e o jogo nunca o chamava**, com
cinco `agrupamento_*.tres` em disco sem efeito. Ligado, a massa passou a vir de
bancada e não de peça solta: **29% → 69%**.

- **Duas fontes para a mesma densidade, e a que valia era a errada.** Os perfis do
  `[FAB 18]` não eram apontados por ninguém; a `Sala` lia um `44` paralelo, e a
  fatia útil de uma peça de 64 media **doze pixels**. A sala de combate foi de ~16
  para **33,8 peças**.
- **A pegada quadrada era o que impedia o andar de ter objeto grande** — um
  armário de 96 reservava 96×96 de piso, e a saída tinha sido encolher a peça até
  ela ficar **menor que o jogador**. Hoje há envelope: a peça escolhe a célula que
  **cabe**, e o que se protege é a caminhada.
- **A máquina é parede**: colisão na layer 3, e o sólido **cresce para trás** até
  encostar no muro — 92 de 311 peças deixavam uma fresta de 4 a 23 px, larga
  demais para ler como encostada e estreita demais para o corpo passar.
- A **lâmpada saiu do chão** e foi para a parede, com a poça descendo para o piso;
  e o **cano** corre atrás da bancada e reaparece nos vãos, que é o que a
  referência mostra — ligar peça a peça produzia zero canos, porque as peças de um
  conjunto se sobrepõem de propósito.
- **A câmera é única, e o acervo foi refeito.** As 38 peças antigas voltaram no
  eixo reto: `low top-down` devolve isométrico em peça alongada por mais bloco que
  o prompt tenha, e quem resolve é `view: side` com *flat frontal elevation*. Cada
  peça tem **duas artes** — frente e ponta —, porque girar arte de face destrói a
  perspectiva, decisão já fechada na porta.

**E o projétil desenhava acima do cenário por ACIDENTE.** Não havia nó no grupo
`container_projeteis`, então `Arma._container()` caía no `Main` e a ordem certa
vinha da árvore — que se perde no dia em que alguém arrasta um nó. Com a sala indo
de 4 para ~15 corpos volumétricos, projétil passando **atrás** de um caixote
deixou de ser hipótese.

> **A lâmpada não é a alavanca da escuridão do andar, e a nota do
> `medir_ambiente` apontava para o botão errado.** Dobrar as lâmpadas (5 → 11) move
> **3,2 pontos** de preto; o ambiente (0,45 → 0,85) move **46,9**. E a régua que
> media isso montava a sala **sem o `AmbienteDaFabrica`** — 17,4% de preto onde o
> jogo dá 95%. As três réguas de razão sobreviveram ao defeito; quem o denunciou
> foi a única que compara com um número absoluto.

**`v0.5.0-alpha`.** A sala virou **caixa**, o inimigo ganhou **classe**, e o
crédito ganhou **para onde ir** — o M1 fecha o loop que estava aberto desde a
v0.2.0, quando `GameState.creditos` passou a acumular e nada consumia.

**A parede reverteu a assimetria, e a reversão tem medição.** O modelo direcional
dava norte 60, lateral 36 e sul 32; no jogo as quinas diziam *"há uma moldura"* e
os lados diziam *"há um acabamento"* — 40% de dispersão contra o teto de 10%.
Hoje são `corpo 48 + cap 12 + sombra 4` nos quatro lados, e a correção não foi
escolher valores iguais: foi **tirar do recurso a capacidade de divergir**.
Enquanto houvesse um campo por lado, alguém os giraria em separado — e foi
exatamente o que aconteceu.

- A régua que reprovava a `sala_5_pilar` **media metade da caixa**: ela varria só
  colunas, e as laterais são bandas verticais. Com o jogador a leste, a
  `sala_1_retangular` media 0,059 com a parede leste ocupando a beira do quadro.
- E media o **zoom**: a janela de suavização é espacial, e na vista sintética o
  cap de 12 px chega a 5,8 na tela.

**Unidades Aprimoradas**: três classes modulares — Regeneradora, Blindada e
Sobrecarregada — que qualquer inimigo aceita sem código de espécie. O que separa
as três é o **movimento da arte** e não a cor: partículas que convergem, placas
que orbitam e abrem, faíscas que saem. O jogo é escuro, e matiz é a primeira
coisa que se perde.

- O custo de ameaça sai do **orçamento da sala**: um Hacker Regenerador ocupa o
  lugar de um Hacker e dois Drones. Menos corpos, mais decisão.
- Medido em 24 andares: **1,08 aprimorada por andar**, 21,7% das salas de
  combate. O tipo declara 25% — a diferença é o cooldown, e chance por sala não é
  a mesma coisa que frequência percebida.
- Dois números saíram da medição contra o plano: a redução da Blindada é **15% e
  não 25%** (vida é `int`, e o efeito só existe em degraus de um acerto: 25% dá
  +40%, acima do teto), e a cura é **10%/s e não 2%** (2% de 5 de vida é um ponto
  a cada dez segundos). As 15 combinações ficam entre +20% e +33% de TTK.

**A economia de run e a Loja.** O crédito deixou de virar saldo em silêncio e
passou a cair no chão como ficha; a Loja vende três ofertas — uma arma, um item e
uma surpresa — lendo a **pool real do loot**, com estoque determinístico pela
semente. A transação entrega **antes** de debitar: `Modificadores.aplicar()`
recusa um implante único que o jogador já tenha, e com o débito primeiro ele
pagaria por algo que não recebe.

- A renda foi calibrada contra simulação de 40 andares, e não por gosto: com o
  valor cru o andar rendia **253 créditos** contra os 35–55 que o plano assume, e
  100% das runs compravam as três ofertas.
- **Os quatro alvos de comprabilidade do plano não coexistem**, e a tabela está
  no `DadosDropCredito`: subir a renda para "exatamente duas compras" cair na
  faixa derruba "ao menos uma" e "nenhuma" ao mesmo tempo.
- O Sucateiro é o primeiro NPC não hostil do jogo, com três gestos.

**E o `project.godot` voltou a carregar os autoloads do `godot_mcp` de novo** —
o mesmo defeito que a preparação da v0.1.0 removeu e a v0.3.0 registrou aqui.
`addons/*` está no `exclude_filter`, então uma build publicada assim sobe com
autoload apontando para script fora do pacote. O passo do pré-voo do `BUILD.md`
existe; o que falta é alguém executá-lo antes de tagear, e desta vez foi pego na
preparação da tag.

**`v0.4.0-alpha`.** A migração **Low Top-Down Squared** fechada — as nove issues
da trilha LTD (#36 a #46) — mais o começo da identidade industrial do andar 1 e
do refinamento de inimigos.

O mundo passou a ter altura de ponta a ponta:

- **Chão na grade de 64**, com zero pontos de silhueta de projétil. As seis
  texturas já passavam nos seis portões; o que faltava — a grade — nenhum
  portão media.
- **Props com volume**: topo e face, origem na base, sombra e Y-sort. São
  **dois atlas** e não um: o chapado continua gerado e trancado pelo
  determinismo, o volumétrico é autorado e trancado por propriedade medida.
  Fundir obrigaria a escolher um regime, e o perdedor seria o determinismo.
- **A face da parede virou a superfície de identidade.** Ela era um `load()` de
  caminho fixo — nenhum módulo produzido chegaria à tela. Agora é lista por
  tipo de sala, sorteada por `(célula, lado)`.
- **Corredor com face**: era a última parte chapada do jogo, e atravessar de uma
  sala para outra trocava de perspectiva no meio do caminho.
- **Camada Foreground**, com a trava do telegrafo feita **estrutural**: o
  Foreground nunca entra na `area_spawn`, então "não cobre telegrafo" deixou de
  ser revisão de olho e virou comparação de retângulos.
- **Porta industrial** autorada, e **progressão visual** por posição no andar.

**A medição contrariou a suposição em cinco das nove issues**, incluindo
suposições escritas nas próprias issues e duas afirmações minhas:

> - A face desenha **uma** por sala, não uma por lado — medido nas nove formas.
>   Isso muda o que a biblioteca de módulos precisa desenhar.
> - `capturar.gd` comparava o contorno com a tela e **passava por um fio**,
>   porque a sala retangular tem exatamente o tamanho da tela. "A sala cabe"
>   nunca significou "os inimigos estão no quadro", e a foto 07 saía com hostis
>   fora da moldura.
> - Duas das quatro suspeitas sobre a Diretora **não eram defeito**: ela não tem
>   pés, e girar um disco radialmente simétrico não muda perspectiva. As duas que
>   eram: ela era o **único inimigo do jogo sem tint de Hack**, e carregava uma
>   sombra 100% coberta pelo próprio sprite.

**A ferrugem não entrou, e o motivo é medido.** Ela cai em ~25–40°, que é a
faixa da sala de arma; o funil a empurra para dentro da faixa do andar 1 e a
corrosão vira manchinha ciano — a cor do projétil do jogador. Uma variante mediu
**68 pontos com silhueta de projétil**. Ela precisa vir de padrão e valor, ou de
uma decisão formal de paleta. É o que mantém duas das dez perguntas do protótipo
em aberto.

De quebra, **2657 verificações em 27 suítes** contra 2291 no início, com quatro
suítes novas — props, Drone Aranha, Atirador Neon, e a sala de teste que confere
a própria lista antes de fotografar.
