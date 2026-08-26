# Roadmap

Cinco fases. Cada uma termina com algo jogável — nunca com "metade de um
sistema". Sem datas: o time é de três pessoas em tempo parcial e estimativa
com data só cria dívida moral.

---

## Fase 0 — Base técnica ✅ concluída

Stack decidida, repositório com LFS e CI, handoff escrito, e a POC completa
rodando: cinco ondas numa arena, dois limiares de Deterioração, chefe em três
fases, vitória e derrota. (As ondas foram substituídas pelo andar de salas na
Fase 3.)

**Saída:** o projeto abre e joga na máquina dos três.

---

## Fase 1 — Game feel e primeiro playtest ✅ concluída

O objetivo aqui **não era adicionar conteúdo**. Era descobrir se a base é
divertida antes de investir em qualquer coisa.

- [x] Instrumentos de tuning: `docs/TUNING.md` com todos os botões, e duas réguas headless (`tools/medir_ritmo.tscn`, `tools/medir_composicao.tscn`) que medem a curva da run em vez de opinar sobre ela
- [x] ~~Ajustar dificuldade da onda 4~~ → **achar e corrigir o pico real**. Não há onda 4; a régua mostrou o problema equivalente: a mira preditiva ligava no primeiro terço da run, antes de o jogador ter formado o hábito de esquiva que ela existe para trair. Ganho passivo `0.35 → 0.25` e ganho por sala `8 → 6` puseram o limiar entre 38% e 50% da run
- [x] Cronômetro da luta do chefe na tela de fim — é o que torna a pergunta 4 respondível com dado em vez de memória
- [x] CI e release na mesma versão do Godot que o editor do time (4.7.2-stable). A build do testador sai do CI; ela precisa vir do mesmo engine que abriu o projeto
- [x] Exportar build de Windows e build web — o `release.yml` gera os dois zips a partir da tag; saiu na `v0.2.0-alpha`
- [x] Subir a build web no itch.io como projeto privado, com senha
- [x] Mandar o link para 5–8 amigos

**Perguntas para os testadores:** estão em [PLAYTEST.md](PLAYTEST.md), com a
mensagem pronta para copiar e o porquê de cada pergunta. As cinco antigas
falavam de "cinco ondas"; foram revistas para o jogo que existe hoje, e uma
delas passou a cobrir orientação no andar.

### Resultado

O playtest rodou na `v0.2.0-alpha` e **voltou positivo, sem problemas
acionáveis** — nenhuma lista de correções saiu dele.

Vale registrar como isso deve ser lido: **cinco a oito pessoas sem nenhuma
reclamação é um sinal fraco, não uma aprovação.** Costuma significar pergunta
que não mordeu, ou testador sendo gentil, mais do que base pronta. A pergunta
que esta fase existia para responder — *"é divertido sem arte e sem som?"* —
foi respondida de forma rasa. Quem for decidir o escopo da Fase 2 decide com
isso na mão, e não com um "sim" firme.

### Adiado desta fase

Os dois continuam pendentes e não bloqueiam nada:

- [ ] **Sessão de tuning dos três juntos** — velocidade do jogador, cooldown do rolamento, vida dos inimigos, densidade das salas. Os instrumentos estão prontos: [TUNING.md](TUNING.md) tem cada botão com o valor de hoje e a consequência já medida, e as duas réguas (`medir_ritmo`, `medir_composicao`) rodam headless. Falta a conversa e aplicar o que ela decidir
- [ ] **Rebalancear a vida do chefe pelo tempo de luta observado** — a régua diz 59 s (jogador praticado) a 2min10 (cauteloso), e a faixa boa é 60–90 s. O tempo é dominado pelo uptime, não pela vida, então o número só se resolve olhando gente jogar. O dado agora existe: a tela de fim mostra `LUTA DO CHEFE mm:ss`

**Saída entregue:** um link jogável (`v0.2.0-alpha` no itch.io) e os
instrumentos para ajustar a base sem chutar. A lista ordenada de problemas não
existiu, porque o retorno não produziu nenhum.

---

## Fase 2 — Identidade audiovisual

Só depois que a base for divertida.

- [ ] Sprites do jogador e dos dois inimigos (mantendo a silhueta atual, que já lê bem)
- [ ] Sprite e animação do chefe
- [ ] Tileset da arena
- [ ] Feedback sonoro: tiro, impacto, dano, morte, telegrafo do chefe
- [ ] Música: uma faixa que degrada junto com a barra (filtro/distorção crescente)
- [ ] Substituir os `Polygon2D` por `Sprite2D` sem tocar na lógica

> Quando a arte entrar, o Git LFS já está configurado — basta commitar
> normalmente. Ver `.gitattributes`.

**Saída:** a mesma build, com cara de jogo.

---

## Fase 3 — Roguelike de verdade

- [x] Sistema de salas: gerar 8–12 salas conectadas, lockdown por sala
  — ficou de fora o pathfinding: o melee continua andando em linha reta, e agora há pilares e paredes em L para ele encalhar, exatamente o problema que a tabela de dívidas técnicas já previa para esta fase
- [x] Tipos de sala dirigidos por dados: combate, chefe, arma e item
  — cada tipo é um `src/mapa/tipo_*.tres` com a própria regra de colocação, então sala nova (loja, desafio) não passa por GDScript
- [x] Minimapa na HUD com a silhueta real de cada sala, o tipo e o que já foi limpo
  — fecha a dívida declarada acima: agora dá para se orientar no andar
- [x] Implantes passivos: `src/items/implante_*.tres` somados no autoload `Modificadores`
  — lidos no frame de uso, como a Deterioração; implante novo é um `.tres`
- [x] 16 implantes, incluindo condicionais (vida baixa, cargas, tiros de eco) e comportamentais (ricochete, fragmentação, vampirismo, marcador)
  — `DadosItem` virou lista de `EfeitoItem` + um comportamento; item só-numérico não custa GDScript
- [x] Pente e recarga (`R`, ou automática ao esvaziar), reserva infinita por enquanto
- [x] Composição de inimigos decidida na montagem do andar, por orçamento de área × densidade
  — as ondas saíram inteiras; inimigo novo passou a ser um `grupo_*.tres`, sem GDScript
- [x] Mais tipos de inimigo — entraram **cinco**, e nao os dois pedidos: Drone Aranha (rajada radial), Sentinela Orbital (orbita e nega a esquiva lateral), Atirador Neon (tiro telegrafado de linha travada), Cyber-Besta (investida em direcao travada) e Hacker Parasita (areas de perigo no chao)
  — os dois que o item pedia estao contemplados: a Sentinela forca reposicionamento, o Parasita forca priorizar alvo
  — cada um entra no andar por uma porta de Deterioracao (`deterioracao_minima` no `grupo_*.tres`), entao o andar apresenta os tipos aos poucos
  — a maquina de estados compartilhada (`src/enemies/maquina_estados.gd`) e a costura `InimigoBase.direcao_de_locomocao()` sao o espaco deixado para pathfinding e para uma IA mais robusta
- [ ] 3–4 armas novas — o sistema já suporta: cada arma é um `.tres`, e o pool de loot é `src/items/pool_padrao.tres`
- [ ] Créditos e loot dropados
- [ ] Loja clandestina entre runs
- [ ] Meta-progressão com Núcleos de Memória
- [ ] Implantes que substituem o rolamento: dash cortante, jetpack, escudo estacionário

**Saída:** uma run de 20–30 minutos com progressão entre tentativas.

---

## Fase 4 — A IA Diretora heurística

O sistema que dá nome ao jogo e que ainda não existe.

- [ ] Instrumentar o jogador: distância média dos inimigos, frequência de esquiva, arma preferida, tempo parado
- [ ] Classificar o estilo em 3–4 arquétipos (encostado, sniper, esquivador, camper)
- [ ] Tabela de counters: qual composição de sala pressiona cada arquétipo
- [ ] Popular as salas seguintes com base nessa leitura
- [ ] Deixar isso **legível** para o jogador — se ele não perceber que está sendo lido, o sistema não existe do ponto de vista da experiência

> Este é o item de maior risco do projeto. Ele pode virar um sistema que o
> jogador nunca nota, ou pior, que parece só aleatório e injusto. Vale
> prototipar cedo, mesmo que tosco, e testar se as pessoas percebem.

**Saída:** duas pessoas jogando o mesmo jogo e enfrentando salas diferentes.

---

## Fase 5 — Fechamento

- [x] Menu principal e tela de opções (tela cheia, com a escolha salva em `user://config.cfg`)
  — falta o remapeamento de controles
- [ ] Remapeamento de controles
- [ ] Suporte a gamepad
- [ ] Salvamento
- [x] Acessibilidade: chaves para desligar o tremor de câmera e a distorção visual, nas Opções
  — `Juice.habilitado` virou `shake_habilitado` + `hitstop_habilitado`, porque desligar o tremor não deve levar junto o peso do tiro
- [ ] Página no itch.io e/ou Steam
- [ ] Trailer

---

## Dívidas técnicas conhecidas

Coisas que sabemos que estão simplificadas. Nenhuma bloqueia a Fase 2.

| Item | Onde | Por que ficou assim |
|---|---|---|
| Projéteis são instanciados a cada tiro | `src/weapons/arma.gd` | Pooling só importa quando o bullet hell ficar denso de verdade |
| Inimigos usam distância para dano de contato, não Area2D | `src/enemies/inimigo_base.gd` | Menos nós e mais fácil de ler; trocar quando houver hitbox por parte do corpo |
| Sem pathfinding — todo mundo anda em linha reta | `src/enemies/inimigo_base.gd` | **Virou problema, como previsto**: as salas com pilar e as em L prendem quem persegue. A costura já existe — `InimigoBase.direcao_de_locomocao()` é o único lugar que muda quando alguém for resolver |
| Sem pooling de partículas | `src/fx/` | Idem |
| ~~Sem menu principal~~ — resolvido: `src/ui/intro.tscn` leva ao menu | `src/ui/menu_inicial.tscn` | — |
