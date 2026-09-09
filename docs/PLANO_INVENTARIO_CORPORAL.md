# Plano — Inventario de Aprimoramentos Corporais + dois slots de arma

Epico `[INV nn]`. Este arquivo e o que **comanda** a implementacao; quando o
codigo e este texto discordarem, o codigo ganha e este texto se atualiza.

O objetivo em uma frase: o inventario deixa de ser "uma lista de coisas que eu
peguei" e passa a ser **o corpo do personagem sendo modificado durante a run**,
com o armamento como a unica coisa que ele carrega FISICAMENTE -- duas armas, e
a terceira cobra uma escolha.

---

## 1. O que ja existe (medido, nao suposto)

O jogo **ja tem dois slots**, e isso muda o tamanho do trabalho. O que existe
hoje em `src/player/player.gd`:

```gdscript
## Slot 0 e sempre a pistola infinita; slot 1 e o loot. Q alterna.
var _slots: Array[DadosArma] = [null, null]
var _slot_ativo: int = 0
```

E o que ele NAO faz, que e o epico inteiro:

| Hoje | O que o plano pede |
|---|---|
| Slot 0 e a arma inicial e **nunca** pode ser trocado | Os dois slots sao simetricos |
| Arma nova sobrescreve o slot 1 **sem perguntar** | A terceira arma abre uma escolha |
| A arma trocada **evapora** | Ela cai no chao |
| `Arma.equipar()` **zera o pente** | O pente e estado DO SLOT |
| A troca e **Q** | A troca e **F**; **TAB** abre o inventario |
| Os implantes vivem numa faixa de 16 px no canto | Eles ganham uma tela propria |

### A descoberta que dissolve o maior risco do plano

**Todas as 21 armas do jogo tem `municao_maxima = -1`** -- reserva infinita.
Conferido arquivo a arquivo. Tres consequencias:

1. **`Arma.ficou_sem_municao` nunca dispara.** O sinal existe, esta ligado, e o
   `Player._ao_acabar_municao()` -- que descarta a arma de loot e volta para a
   pistola -- e **codigo morto desde que as armas nasceram**.
2. Portanto **nao ha rede de seguranca a perder** ao tornar o slot 0
   substituivel. O medo obvio ("o jogador troca a pistola infinita e fica sem
   nada") nao tem caso: nenhuma arma acaba.
3. O que o pedido chama de "municao por slot" (§26) e, na pratica, o **PENTE**.
   Rail-X 3/5 e Mantis 12/32 tem de sobreviver a dez trocas -- e a reserva nao
   entra na conta porque e infinita nas duas.

**Mas `_ao_acabar_municao()` nao pode simplesmente ficar como esta.** Ele
carrega uma regra ("arma vazia volta para a pistola do slot 0") que deixa de ser
verdade no instante em que os slots viram simetricos. Codigo morto que afirma
uma regra falsa e pior que codigo morto: ele volta a rodar no dia em que alguem
escrever a primeira arma de reserva finita, e vai fazer a coisa errada em
silencio. Ele vira "o slot esvazia", que e a regra certa para os dois.

---

## 2. As tres correcoes que este plano faz no pedido

O pedido original esta em ingles e em pseudo-Godot. Tres pontos dele nao
sobrevivem as regras desta casa, e a divergencia vai declarada em vez de
silenciosa:

### 2.1 Os nomes sao em portugues

`WeaponInstance` -> **`InstanciaDeArma`**, `WeaponInventory` ->
**`InventarioDeArmas`**, `body_category` -> **`categoria_corporal`**,
`inventory_screen.tscn` -> **`tela_inventario.tscn`**. O `docs/CONVENCOES.md`
manda, e um `class_name` em ingles no meio de 55 suites em portugues e a mesma
divida que duas copias do mapa de angulos ja cobraram.

### 2.2 NAO existe `RunInventory`

O pedido (§60) quer um `RunInventory` que contenha os aprimoramentos passivos e
o inventario de armas. **Os aprimoramentos ja tem dono**: o autoload
`Modificadores`, que guarda `_itens`, responde `itens_ativos()`, limpa em
`resetar()` e emite `modificadores_mudaram`. Um `RunInventory` que os guardasse
de novo seria uma segunda fonte para a mesma verdade -- a armadilha que ja
custou entrega inteira neste repositorio duas vezes (o `EstiloDeParede` com uma
copia do perfil, e a Loja nascendo com `tipo = &"arma"` clonado da sala de
arma).

Entao: **o inventario de armas e um componente novo; os aprimoramentos
continuam onde estao.** A tela de inventario pergunta aos dois. Ela e uma VISTA,
e vista nao guarda estado.

### 2.3 F entra sem tirar o Q

`trocar_arma` ja existe no InputMap, ligado ao Q. Uma acao do Godot aceita
varios eventos, entao F entra COMO EVENTO da mesma acao e o Q fica. Nao ha duas
verdades: ha uma acao com dois teclados, que e exatamente para isso que a camada
de acao existe. Quem le o codigo continua vendo
`Input.is_action_just_pressed("trocar_arma")` num lugar so.

---

## 3. Arquitetura

```
Player  (CharacterBody2D)
├── InventarioDeArmas   <- O QUE CARREGAMOS: dois slots, o ativo, o pente de cada
│     ├── slot[0]: InstanciaDeArma { dados, pente }
│     └── slot[1]: InstanciaDeArma | null
└── Visual/Arma  (Arma)  <- O QUE ESTAMOS USANDO: cadencia, recarga, disparo
```

A separacao do pedido (§30) e a certa e ja e meio verdade aqui: `Arma` e o
executor (cadencia, pente, recarga, o portao dos implantes) e nao deveria saber
que existem slots. Quem sabe e o `InventarioDeArmas`.

**O pente atravessa a troca por `Arma.equipar(dados, pente_inicial)`.** O
parametro e opcional e o default e "pente cheio", que e o que `equipar()` faz
hoje -- entao todo chamador atual (o `_ready` do Player, os cinco inimigos, o
chefe) continua funcionando byte a byte. Quem passa o pente e so o inventario.

### O contrato de aquisicao

Uma funcao, para os quatro caminhos (chao, sala de recompensa, Loja, futuro
bau). O pedido pede isso em §48 e esta certo: uma segunda logica de aquisicao
divergiria, e o sintoma seria uma arma comprada se comportando diferente da
mesma arma achada no chao.

```
InventarioDeArmas.pedir_aquisicao(dados) -> Resultado
        │
        ├─ ha vaga?  -> ocupa, vira ATIVA, devolve ACEITA
        └─ nao ha    -> devolve PRECISA_ESCOLHER (e nao mexe em NADA)
```

Quem abre a tela de escolha e **quem pediu** -- o pickup, a bancada --, e nao o
inventario. O inventario nao conhece UI, pela mesma razao que a HUD nao conhece
o Player.

---

## 4. As armadilhas previstas (antes de escrever o codigo)

- **`Arma.equipar()` emite `municao_alterada` na hora.** Ligar o sinal depois de
  equipar perde o primeiro aviso -- ja custou uma HUD com o texto da cena. O
  `_ready` do Player ja faz na ordem certa, e a ordem tem de sobreviver a
  delegacao.
- **A arma substituida cai no chao e o jogador esta EM CIMA dela.** Sem trava,
  o `body_entered` reabre a tela de escolha no frame seguinte -- laco fechado,
  com o jogo pausado. Por isso `PickupArma` nasce com trava de recoleta.
- **A tela de troca pausa a arvore, e pausar mata o `_process` de quem a
  desenha.** Ela precisa de `PROCESS_MODE_ALWAYS`, como o `menu_pausa` e como o
  reticulo.
- **O reticulo e dono do cursor do sistema.** Ele esconde a seta enquanto
  aparece. Tela de escolha que aceita mouse precisa da seta de volta -- e tem de
  devolve-la ao sair.
- **Enum novo em `DadosItem` grava INT no `.tres`.** `CategoriaCorporal` nasce
  agora, entao nao ha `.tres` salvo para reescrever -- mas o valor 0 tem de ser
  o neutro (`SISTEMA`), senao um implante sem categoria declarada nasce dizendo
  "eu sou neural". E valor novo entra sempre NO FIM.
- **`GameState.iniciar_run()` NAO pode zerar o personagem.** A armadilha ja esta
  registrada; o inventario de armas entra no bloco de contadores que a funcao
  limpa, e o personagem continua fora dele.
- **Categoria corporal e campo que ninguem le em jogo.** Ela existe so para
  posicionar na UI. Campo que so a UI le e campo que apodrece: o portao tem de
  cobrar que os 16 implantes tenham categoria E que a tela desenhe cada
  categoria que existe.

---

## 5. A reversao do CORPO

A primeira versao da aba de itens desenhava o que o pedido descreve nos §3, §7 e
§40-41: uma silhueta tecnica com os implantes pendurados por regiao e ligados
por linhas finas. **O dono do projeto olhou a captura e reprovou.** A ideia pode
voltar no futuro; por enquanto o inventario e uma CONSULTA em tres abas --
ITENS, ARMAMENTO e STATUS -- e nao um retrato.

O que ficou dela, de proposito:

- **`DadosItem.categoria_corporal` continua nos 16 `.tres`**, e continua cobrado
  por `teste_inventario.gd`. Nada em jogo o le. E o mesmo desenho que mantem
  `teste_diretora.gd` no runner com a Diretora engavetada: e por nao ser usado
  que ele precisa continuar conferido. Apagar os dezesseis para reescolhe-los no
  dia em que a ideia voltar e o mesmo trabalho feito duas vezes.
- **O titulo deixou de dizer "CORPORAIS"**, porque a palavra prometia uma
  leitura que a tela nao entrega mais.

---

## 6. Estado

**Entregue: as fases A a E (o MVP inteiro), mais a regua visual.** Os portoes
passam: 6001 verificacoes em 58 suites, e o teste de fumaca fecha a run com o
chefe morto.

Fica em aberto, declarado e fora do MVP:

- **[INV 29] os quatro sons.** Os sinais (`arma_trocada`, `arma_substituida`,
  `arma_descartada`) ja saem do EventBus sem ouvinte nenhum -- e essa e a metade
  barata; a outra e passar pelo `tools/audio/gerar_sons.gd`, que refaz os `.wav`
  e mexe no portao de audio.
- **[INV 31] a serializacao.** Ela existe para um save de meio de run que ainda
  nao existe. `InstanciaDeArma` ja guarda o par (molde, pente), que e tudo que
  ela precisaria.
- **A animacao curta de troca na HUD** (§17 do pedido). Hoje a troca e
  instantanea e o rotulo apenas muda.
- **Tres armas ainda sem icone**: `pistola`, `pistola_cipher` e `smg_mantis` --
  as tres INICIAIS, que nunca aparecem como pickup e por isso ficaram de fora da
  onda de arte. Elas aparecem agora, no inventario e na tela de troca, e caem no
  losango de `cor_projetil`. O fallback funciona (esta na captura), mas a divida
  ficou visivel onde antes nao era.

---

## 7. As issues

### Fase A — a espinha das armas (sem UI)

- **[INV 01]** `InstanciaDeArma`: `dados` + `pente`. O estado que sobrevive a troca.
- **[INV 02]** `InventarioDeArmas`: dois slots, slot ativo, `pedir_aquisicao`,
  `substituir`, `alternar`, `tem_vaga`, `ativa`, `reserva`.
- **[INV 03]** `Arma.equipar(dados, pente_inicial)`; -1 = pente cheio.
- **[INV 04]** O Player delega: `_slots`/`_slot_ativo` saem, `equipar_arma_loot`
  vira fachada de `pedir_aquisicao`.
- **[INV 05]** `_ao_acabar_municao()` esvazia o slot em vez de "voltar para a pistola".
- **[INV 06]** Sinais novos no `EventBus`: `arma_trocada`, `arma_substituida`,
  `arma_descartada`.
- **[INV 07]** Suite `teste_inventario_de_armas.gd`.

### Fase B — os dois slots em jogo

- **[INV 08]** Arma inicial no slot 0, slot 1 vazio, ativo = 0.
- **[INV 09]** A primeira arma diferente ocupa o slot 1 e **vira ativa**.
- **[INV 10]** F no InputMap (o Q fica) + cooldown de troca de 0,15 s.
- **[INV 11]** HUD: arma ativa grande, reserva pequena, a dica `[F]`.

### Fase C — a terceira arma

- **[INV 12]** `tela_troca_de_arma.tscn`: a nova arma e os dois slots, com
  4 a 6 atributos e as tags de comportamento.
- **[INV 13]** Entradas `1` / `2` / `ESC` + mouse; a arvore pausa.
- **[INV 14]** A arma substituida cai no chao como `PickupArma`.
- **[INV 15]** Trava de recoleta na arma descartada (0,5 s).
- **[INV 16]** Cancelar nao muda nada e a arma continua no chao.
- **[INV 17]** Suite `teste_troca_de_arma.gd`.

### Fase D — o inventario

- **[INV 18]** `DadosItem.categoria_corporal` (enum; valor novo SEMPRE no fim).
- **[INV 19]** Os 16 implantes recebem categoria.
- **[INV 20]** `tela_inventario.tscn`: a aba ITENS, em grade. **O esquema
  corporal foi reprovado** -- ver a secao 5.
- **[INV 21]** TAB abre/fecha e a arvore pausa; setas e mouse trocam de aba.
- **[INV 22]** A aba ARMAMENTO.
- **[INV 23]** A aba STATUS: stats DERIVADOS dos sistemas reais.
- **[INV 24]** Tooltip do aprimoramento, com o icone do funil de ICO.
- **[INV 25]** Suite `teste_inventario.gd`.

### Fase E — a Loja

- **[INV 26]** A bancada respeita as duas vagas.
- **[INV 27]** O credito so sai DEPOIS da escolha; cancelar nao custa.
- **[INV 28]** A arma trocada na Loja vira `PickupArma` normal ao lado da bancada.

### Fase F — acabamento

- **[INV 29]** Os sons: troca, coldre, instalacao, substituicao.
- **[INV 30]** Acoes abstratas no InputMap para o gamepad futuro.

### Fase G — persistencia (declarada, FORA do MVP)

- **[INV 31]** Serializar `InstanciaDeArma` por id no `DadosRun`.

### Fase H — QA

- **[INV 32]** O teste de fumaca atravessa o fluxo novo.

---

## 8. O MVP

O sistema esta pronto quando, medido:

1. Raven e Nova comecam com a arma assinatura no slot 0 e o slot 1 vazio.
2. A primeira arma diferente ocupa o slot 1 e vira ativa.
3. F alterna, e o pente de cada uma sobrevive a dez trocas.
4. A terceira arma cobra a escolha entre os dois slots.
5. A substituida cai no chao e da para recolher.
6. Cancelar nao perde nada, e a arma continua no chao.
7. A Loja passa pelo mesmo caminho, e cancelar nao custa credito.
8. TAB abre o inventario em tres abas: itens, armamento e status.
9. Os aprimoramentos continuam ACUMULATIVOS -- a aba e vista, nao limite.
10. Tudo zera ao fim da run.
