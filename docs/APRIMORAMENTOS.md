# Unidades Aprimoradas -- o padrao para classes novas

Uma Unidade Aprimorada e um inimigo normal MAIS uma classe modular. Ela nao e
inimigo novo, nao e skin, nao e variante fixa de especie e nao e miniboss:
qualquer inimigo compativel nasce normal (a grande maioria) ou com UMA classe
pendurada.

**Nenhum script de inimigo conhece o sistema.** O inimigo hospeda um no
`Aprimoramento` sem saber o que ele faz, e a base chama quatro coisas que nao
mencionam classe nenhuma -- `multiplicador_de_dano_recebido()`,
`ao_receber_dano()`, `multiplicador_de_cadencia()` e
`multiplicador_de_telegrafo()`. E isso que faz uma classe nova entrar sem tocar
nos cinco inimigos, e um inimigo novo aceitar as tres sem codigo proprio.

| Onde | O que |
|---|---|
| `src/enemies/aprimoramento/apr_*.tres` | as classes: os numeros e as regras |
| `src/enemies/aprimoramento/dados_aprimoramento.gd` | o recurso e o enum `Classe` |
| `src/enemies/aprimoramento/aprimoramento.gd` | o controlador pendurado no inimigo |
| `src/enemies/aprimoramento/aura_de_aprimoramento.gd` | a leitura em tela |
| lista `aprimoramentos` do `GerenciadorMapa` | quais classes existem no jogo |
| `chance_de_aprimorada` no `src/mapa/tipo_*.tres` | quao rara ela e |
| `peso_de_aprimoramento` no `src/enemies/dados_*.tres` | quem recebe classe com mais frequencia |
| `tools/aprimoramentos/laboratorio.tscn` | as 15 combinacoes e o TTK de cada uma |
| `tools/testes/teste_aprimoramento.gd` | as travas do sistema |

Classe nova e `.tres` novo na lista. Se a resposta a "como faco a classe X" for
"vou editar um `.gd` de inimigo", a resposta esta errada.

---

## As dez perguntas

Antes de aprovar uma classe, ela precisa responder as dez. Uma resposta
"depende" e uma classe que ainda nao esta pronta -- e o custo de descobrir isso
depois e um `.tres` ja em disco, medido, e um andar balanceado em cima dele.

**1. Ela preserva o inimigo base?**
O jogador aprendeu o Drone Aranha; a classe tem de deixa-lo reconhecivel como
Drone Aranha. Uma classe que troca o moveset nao e classe, e inimigo novo com
menos trabalho -- e inimigo novo custa arte, telegrafo e uma rodada de medicao
propria.

**2. Ela funciona universalmente?**
As classes existem para multiplicar o elenco sem multiplicar o codigo: cinco
especies x tres classes sao quinze encontros a partir de tres arquivos. Uma
classe que so faz sentido em um inimigo devolve o `if` por especie que o sistema
inteiro existe para nao ter.

**3. As tags resolvem as excecoes?**
Quando a universalidade tiver uma excecao real, ela se declara em
`tags_exigidas` / `tags_incompativeis` do `.tres` -- nunca num `if` sobre o nome
da especie. Excecao que nao cabe numa tag e sinal de que a classe esta presa a
um comportamento, e a pergunta 2 volta.

**4. Ela cria decisao nova?**
A pergunta que o jogador se faz tem de mudar: "atiro em quem primeiro?"
(Regeneradora), "atiro AGORA ou espero?" (Blindada), "onde eu fico?"
(Sobrecarregada). Se a resposta continua sendo "atiro do mesmo jeito, so demora
mais", a classe e um numero maior com um chapeu.

**5. Ela tem counterplay?**
Tem de existir uma jogada que o jogador executa e que muda o resultado --
focar, esperar a janela, mudar de posicao. Sem isso a classe nao cobra pericia:
ela cobra tempo, e tempo neste jogo e Deterioracao subindo, o que ja e a
punicao de todo o resto.

**6. Ela tem telegrafo?**
Todo ataque avisa, e classe nenhuma revoga essa regra. O aviso pode ENCURTAR --
`multiplicador_telegrafo` faz isso --, mas nunca some: o piso vive em
`Telegrafo.duracao_segura()`, aplicado por `InimigoBase.duracao_do_telegrafo()`,
e o pior caso e a classe MAIS a barra cheia, nunca um dos dois sozinho.
Telegrafo que some e a fronteira entre "dificil" e "mente sobre a propria
regra".

**7. Ela nao depende de vida inflada?**
A meta de aumento de TTK e de 10% a 35%. Acima disso o inimigo vira esponja de
dano, e o jogador para de ler a classe e passa a ler o pente. Vale a nota da
Blindada: **vida e `int`**, entao a reducao percentual so existe em degraus de
um acerto (15-17% da +20%, 18-25% da +40%, e nao ha nada entre os dois) -- o
numero sai da medicao, e nao do que soa razoavel.

**8. Ela nao aumenta so o spam?**
Mais projeteis na tela nao e dificuldade nova, e o custo dela cai justamente em
cima do que o jogo pede que se leia. A regra de balanceamento e uma so: **uma
mecanica central mais, no maximo, um ajuste auxiliar pequeno.** Somar `+50%
vida, +20% dano, +20% velocidade e uma habilidade` produz um super-inimigo
generico. E a velocidade fica em 100%: velocidade maior encurta a janela de
leitura, que e a licao que a Cyber-Besta ja pagou.

**9. Ela tem custo de ameaca?**
`custo_ameaca` e o epico inteiro. Sem ele a sala fica com os mesmos corpos MAIS
uma ameaca -- dificuldade por quantidade com um chapeu. Com ele, um Hacker
Regenerador (3 + 2) ocupa o lugar de um Hacker e dois Drones: menos corpos,
mais decisao.

**10. Ela coexiste com as classes futuras?**
Hoje `MAX_APRIMORAMENTOS` e 1 e a pergunta parece hipotetica -- ela nao e. Duas
classes que escrevem no mesmo canal (o mesmo multiplicador, a mesma cor, o mesmo
temporizador) produzem um resultado que depende da ORDEM das chamadas, e isso
nao aparece no console. Quando duas nao puderem conviver, elas se declaram em
`aprimoramentos_incompativeis` -- e o campo e lido por
`InimigoBase.aprimoramento_incompativel()`, nos dois sentidos.

---

## O que o codigo ja cobra

Estas travas existem porque o defeito correspondente falha em SILENCIO:

- **O teto morde.** `aprimoramentos` e `Array` com `MAX_APRIMORAMENTOS = 1`.
  Array sem teto deixa duas classes se empilharem no dia em que alguem chamar a
  funcao duas vezes, com os dois controladores rodando ao mesmo tempo.
- **Os tres campos de compatibilidade sao LIDOS.** `tags_exigidas` e
  `tags_incompativeis` passam por `DadosAprimoramento.cabe_em()`;
  `aprimoramentos_incompativeis` passa por
  `InimigoBase.aprimoramento_incompativel()`. Campo que existe no `.tres` e
  ninguem le e campo que MENTE: quem o preencher nao recebe erro, e a classe
  nasce onde nao devia.
- **As duas recusas sao SEPARAVEIS.** O teto e a incompatibilidade devolvem os
  dois `false`, entao um portao que so chamasse `aplicar_aprimoramento()` duas
  vezes passaria com o campo morto. E por isso que a checagem de briga e uma
  funcao publica propria: para o portao poder perguntar por ela DIRETAMENTE.
- **A aura nao escreve em `_corpo.color` nem em `_visual.modulate`.** Os dois
  canais ja tem dono (Hack/nanite e clarao de dano); um terceiro escritor
  produz uma cor que depende da ordem das chamadas.
- **Campo de classe nasce em ZERO.** Um default util no script e herdado por
  TODAS as classes, e qualquer regua que pergunte "esta classe cura?" olhando o
  campo responde SIM para todas -- foi assim que a linha de base do laboratorio
  saltou de 0,50 s para 4,50 s sem um pixel ter mudado.
- **Valor novo do enum `Classe` entra NO FIM.** Enum e gravado como INT no
  `.tres`; inserir no meio reescreve em silencio o significado de todo
  aprimoramento ja salvo.

## Como adicionar uma classe

1. Responda as dez perguntas. Uma resposta fraca aqui custa menos que um `.tres`
   medido e um andar balanceado em cima dele.
2. Se ela precisar de comportamento novo, o valor entra **no fim** do enum
   `Classe` de `DadosAprimoramento`, e o `match` de `Aprimoramento._process`
   ganha um ramo.
3. Crie `src/enemies/aprimoramento/apr_<id>.tres`, com `id` unico, `peso`,
   `custo_ameaca` e os campos da SUA secao -- deixando as das outras em zero.
4. Liste o `.tres` em `aprimoramentos`, no `GerenciadorMapa`.
5. Meca: `godot --headless --path . tools/aprimoramentos/laboratorio.tscn`. O
   TTK de cada combinacao tem de cair entre +10% e +35%.
6. Rode o runner: `godot --headless --path . tools/testes/runner.tscn`.
