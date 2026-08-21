# Roadmap

Cinco fases. Cada uma termina com algo jogável — nunca com "metade de um
sistema". Sem datas: o time é de três pessoas em tempo parcial e estimativa
com data só cria dívida moral.

---

## Fase 0 — Base técnica ✅ concluída

Stack decidida, repositório com LFS e CI, handoff escrito, e a POC completa
rodando: 5 ondas, dois limiares de Deterioração, chefe em três fases, vitória
e derrota.

**Saída:** o projeto abre e joga na máquina dos três.

---

## Fase 1 — Game feel e primeiro playtest

O objetivo aqui **não é adicionar conteúdo**. É descobrir se a base é
divertida antes de investir em qualquer coisa.

- [ ] Sessão de tuning dos três juntos: velocidade do jogador, cooldown do rolamento, vida dos inimigos, ritmo das ondas
- [ ] Ajustar dificuldade da onda 4 (é onde a mira preditiva já está ligada e o campo está cheio — provavelmente é o pico real)
- [ ] Rebalancear vida do chefe pelo tempo de luta observado, não pelo número que está lá hoje
- [ ] Exportar build de Windows e build web
- [ ] Subir a build web no itch.io como projeto privado, com senha
- [ ] Mandar o link para 5–8 amigos

**Perguntas para os testadores** — mande estas cinco junto com o link, não
pergunte "gostou?":

1. Em que momento você entendeu que os inimigos passaram a prever seu rolamento?
2. Alguma morte pareceu injusta? Qual?
3. A shotgun valeu a pena pegar, ou você ficou na pistola?
4. Quanto tempo a luta do chefe pareceu durar? E quanto durou de verdade?
5. Você jogaria de novo agora mesmo?

**Saída:** um link jogável e uma lista de problemas ordenada pelo que mais
apareceu.

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

- [ ] Sistema de salas: gerar 8–12 salas conectadas, lockdown por sala
- [ ] Mais dois tipos de inimigo (algo que force reposicionamento, e algo que force priorizar alvo)
- [ ] 3–4 armas novas — o sistema já suporta: cada arma é um `.tres`
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

- [ ] Menu principal, opções, remapeamento de controles
- [ ] Suporte a gamepad
- [ ] Salvamento
- [ ] Acessibilidade: chave para desligar screen shake e reduzir o glitch (a hook `Juice.habilitado` e o `alpha_maximo` do shader já existem)
- [ ] Página no itch.io e/ou Steam
- [ ] Trailer

---

## Dívidas técnicas conhecidas

Coisas que sabemos que estão simplificadas. Nenhuma bloqueia a Fase 1.

| Item | Onde | Por que ficou assim |
|---|---|---|
| Projéteis são instanciados a cada tiro | `src/weapons/arma.gd` | Pooling só importa quando o bullet hell ficar denso de verdade |
| Inimigos usam distância para dano de contato, não Area2D | `src/enemies/inimigo_base.gd` | Menos nós e mais fácil de ler; trocar quando houver hitbox por parte do corpo |
| Sem pathfinding — o melee anda em linha reta | `src/enemies/rastejante.gd` | A arena é vazia. Vira problema na Fase 3, com salas e obstáculos |
| Sem pooling de partículas | `src/fx/` | Idem |
| Sem menu principal — o jogo começa direto na arena | `src/main/main.tscn` | Proposital no vertical slice: menos cliques até o teste |
