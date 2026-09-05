# Os ataques do psicode

A ficha de todo ataque implementado. Ela existe porque nao dava para revisar o
que nao estava listado: a resposta para *"quantos ataques o jogo tem?"* exigia
abrir onze scripts, e foi por isso que **as 21 armas passaram anos desenhando a
mesma forma** sem ninguem notar.

Gerada a partir do disco, e nao de memoria. Quando o codigo e este texto
discordarem, o codigo ganha e este texto se atualiza.

> **Status** — `OK` · `REVISAR` · `REFATORAR` · `SEM ARTE` · `ARTE TEMPORARIA` ·
> `HITBOX INCORRETA` · `TELEGRAFO INSUFICIENTE`

---

## 1. As armas

Todas instanciam `src/projectiles/projetil.tscn` por `Arma._emitir()`. O que
muda entre elas sao os numeros do `.tres` -- **nao ha uma cena de projetil por
arma**, e nao deve haver: `Polygon2D.polygons` ja resolve as familias de pedacos
soltos, e uma cena por familia seria oito lugares para o mesmo ajuste divergir.

| `.tres` | nome | comportamento | silhueta | impacto | raio | rastro | arte |
|---|---|---|---|---|---|---|---|
| `pistola` | PST-9 "Teimosa" | NENHUM | LOSANGO | FAISCA | 4,0 | -- | SEM ARTE |
| `smg_mantis` | SMG "Mantis" | NENHUM | CAPSULA | FAISCA | 3,0 | -- | SEM ARTE |
| `pistola_cipher` | Pistola "Cipher" | NENHUM | CAPSULA | FAISCA | 4,5 | 6x | SEM ARTE |
| `shotgun` | Shotgun "Riot-12" | NENHUM | CAPSULA | FAISCA | 3,5 | -- | SEM ARTE |
| `rail_x` | Rifle "Rail-X" | NENHUM | AGULHA | ESTILHACO | 5,0 | 6x | SEM ARTE |
| `swarm` | Enxame "Swarm" | TELEGUIADO | AGULHA | FAISCA | 3,0 | -- | SEM ARTE |
| `volt_caster` | Volt Caster | CORRENTE | ESFERA | DESCARGA | 5,0 | -- | SEM ARTE |
| `boomer` | Lanca-Granadas "Boomer" | EXPLOSIVO | ESFERA | FUMACA | 7,0 | -- | SEM ARTE |
| `plasma_arc` | Plasma Arc | PLASMA | ESFERA | RESPINGO | 5,5 | -- | SEM ARTE |
| `gravity_gun` | Gravity Gun | GRAVIDADE | ORBE | ANEL | 9,0 | -- | SEM ARTE |
| `nanite_rifle` | Fuzil Nanite | NANITE | CLUSTER | BRASA | 3,0 | -- | SEM ARTE |
| `phase_blaster` | Phase Blaster | FANTASMA | ETEREO | RESPINGO | 4,5 | 6x | SEM ARTE |
| `laser_cutter` | Cortador Laser | FEIXE | -- | -- | 26 dps | -- | **REVISAR** |

### As de inimigo

| `.tres` | nome | dono | silhueta | impacto | raio | rastro | arte |
|---|---|---|---|---|---|---|---|
| `tiro_vigia` | Feixe do Vigia | Vigia | CAPSULA | FAISCA | 6,0 | -- | SEM ARTE |
| `tiro_drone` | Descarga Radial | Drone Aranha | ESFERA | PO | 6,0 | -- | SEM ARTE |
| `tiro_neon` | Lanca Neon | Atirador Neon | AGULHA | ESTILHACO | 5,0 | 6x | SEM ARTE |
| `tiro_sentinela` | Pontuacao Orbital | Sentinela | CAPSULA | FAISCA | 4,0 | -- | SEM ARTE |
| `tiro_diretora` | Sentenca | Diretora *(engavetada)* | ESFERA | FAISCA | 7,0 | -- | SEM ARTE |
| `salva_diretora` | Varredura | Diretora *(engavetada)* | LOSANGO | FAISCA | 6,0 | -- | SEM ARTE |
| `onda_guardiao` | Onda de Choque | Automato | ARCO | PO | 16,0 | -- | **OK** |
| `sucata_guardiao` | Sucata | Automato | CLUSTER | PO | 7,0 | -- | SEM ARTE |

### O que o `laser_cutter` tem de REVISAR

Ele e a unica arma que desenha a si mesma (`src/weapons/feixe.tscn`), e e a unica
com uma divergencia medida entre desenho e dano: **quem fere e um raycast de
espessura zero, e o `Line2D` desenha `largura_feixe = 6.0`.** O desenho e mais
largo que o dano -- a mesma classe de mentira que o portao de silhueta cobra nos
projeteis, num lugar onde ninguem olhou. Detalhe em #195.

E ele grava `raio_projetil` e `velocidade_projetil` que **ninguem le**: `FEIXE`
desvia antes de instanciar projetil.

---

## 2. Os inimigos

| inimigo | ataque | telegrafo | dano | projeteis | status |
|---|---|---|---|---|---|
| **Drone Aranha** | ANEL | `Telegrafo` AREA, r 72 | projetil | 8 a 12 (`Balistica.anel`) | OK |
| **Atirador Neon** | TIRO TRAVADO | `Telegrafo` LINHA | projetil | 1 | **REVISAR** |
| **Cyber-Besta** | INVESTIDA | `Telegrafo` LINHA + agachamento | contato | 0 | **REVISAR** |
| **Sentinela Orbital** | TIRO UNICO | `Telegrafo` pulso no clarao | projetil | 1 | **REVISAR** |
| **Sentinela Orbital** | RAJADA | o mesmo pulso, 1,9x maior e 1,6x mais longo | projetil | 3 (leque 24 graus) | **REVISAR** |
| **Hacker Parasita** | SEMEADURA | `Telegrafo` AREA, r 56 | `AreaDePerigo` | 0 | OK |
| **Vigia** | LASER | `Telegrafo` LINHA da BOCA | projetil | 1 | OK |
| **Rastejante** | contato | -- (nao ataca a distancia) | contato | 0 | OK |

**Neon e Sentinela estao em REVISAR pelo mesmo motivo, e ele nao e de arte:** ate
o conserto do #171 os dois disparavam **uma vez por vida**. Toda observacao
anterior sobre como o tiro deles le foi feita sobre um tiro que quase nunca saia.

**A Cyber-Besta esta em REVISAR por falta de IMPACTO**, e nao de aviso: bater na
parede da 1,6 s de atordoamento -- a maior janela de contra-ataque que ela
oferece -- e isso acontece hoje sem nenhum efeito em tela.

---

## 3. O chefe do andar 1

Os cinco passam pelo MESMO trio `PREPARAR` / `EXECUTAR` / `RECUPERAR`. O que
muda por ataque sao as duracoes, o que e semeado na preparacao e o que dispara
na execucao.

| ataque | gesto | telegrafo | dano | status |
|---|---|---|---|---|
| **Soco Hidraulico** | `armar_soco` / `socar` | `AreaDePerigo` r 78 | area + onda (perfuracao 99) | OK |
| **Rajada de Sucata** | `armar_rajada` / `arremessar` | **nenhum** | projetil, leque de 5 x N beats | **TELEGRAFO INSUFICIENTE** |
| **Investida Pesada** | `armar_investida` / `investir` | **nenhum** | contato do corpo | **TELEGRAFO INSUFICIENTE** |
| **Pisao** | `armar_pisao` / `pisar` | **nenhum** | projetil, anel de 8 x N beats | **TELEGRAFO INSUFICIENTE** |
| **Falha do Reator** | `armar_reator` / `sobrecarregar` | 6 areas em cerco + 1 central | area + anel de 12, 2 beats | **SEM ARTE** (o gesto) |

### A lacuna mais seria do inventario

**Tres dos cinco ataques do chefe nao tem telegrafo visual nenhum** -- so corpo
travado e o clipe de sprite. Corpo travado e aviso para quem ja conhece o chefe;
o telegrafo existe para quem nao conhece.

Isso contradiz a regra n1 do `docs/GDD.md:164` com todas as letras:

> *"Todo ataque declara telegrafo > 0 -- bullet hell so e justo se da para ler a
> intencao antes do projetil existir."*

Issues: #203 (Rajada), #204 (Investida), #205 (Pisao).

Os gestos `armar_reator` e `sobrecarregar` estao **declarados como ausentes** em
`SEM_CLIPE_AINDA` (`teste_boss_animacao.gd`), junto de `cambalear` e
`despertar`. Isso e a ANIM 05, e nao o epico dos projeteis.

---

## 4. Os hazards

| peca | dono | telegrafo | dano |
|---|---|---|---|
| `AreaDePerigo` | Parasita, chefe (soco e reator), Diretora | `Telegrafo` AREA, quatro fases | `intersect_shape`, mais brasa residual quando ligada |
| `ExplosaoArea` | granada, plasma, nanite | -- (o aviso foi o projetil) | `intersect_shape` com falloff |
| `ArcoEletrico` | `volt_caster` | -- (o dano ja aconteceu) | nenhum: e so leitura |
| `Feixe` | `laser_cutter` | -- | raycast por frame |

---

## 5. Onde mexer

| ajuste | arquivo |
|---|---|
| silhueta de um projetil | `familia_silhueta` em `src/weapons/*.tres` |
| impacto de um projetil | `familia_impacto` em `src/weapons/*.tres` |
| rastro | `rastro_comprimento` em `src/weapons/*.tres`; zero desliga |
| arte de um projetil | `assets/projeteis/`, via `tools/sprites/gerar_projeteis.py` |
| como QUALQUER projetil desenha | `src/util/formas_projetil.gd` |
| como QUALQUER ataque avisa | `src/enemies/telegrafo.gd` |
| ver tudo lado a lado | `godot --path . tools/laboratorio_projeteis.tscn` |
