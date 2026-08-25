# -*- coding: utf-8 -*-
"""Monta locale/textos.csv, a tabela de traducao do jogo.

Por que a CHAVE e o proprio texto em portugues, e nao um codigo tipo
MENU_NOVO_JOGO: o .tres e o .tscn continuam legiveis. Quem abre
implante_nucleo.tres no Inspetor le "Nucleo de Reserva", nao
"ITEM_NUCLEO_NOME" -- e o jogo em portugues funciona mesmo sem nenhuma
traducao carregada, porque tr() devolve a chave quando nao acha entrada.

O preco: mudar o texto em portugues quebra o ingles em silencio. Por isso
existe tools/testes/teste_traducao.gd, que confere que toda string de dado
tem par nesta tabela.

Uso:  python tools/i18n/gerar_csv.py
"""

import csv
import io
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SAIDA = os.path.join(RAIZ, "locale", "textos.csv")

# Texto de interface. Chave = portugues; unica outra coluna = ingles.
UI = [
    # menu inicial
    ("NOVO JOGO", "NEW GAME"),
    ("CARREGAR", "LOAD GAME"),
    ("OPÇÕES", "OPTIONS"),
    ("SAIR", "QUIT"),
    # opcoes
    ("Tela cheia", "Fullscreen"),
    ("Tremor de câmera", "Screen shake"),
    ("Distorção visual", "Visual distortion"),
    ("Idioma", "Language"),
    ("VOLTAR", "BACK"),
    # pausa
    ("JOGO PAUSADO", "GAME PAUSED"),
    ("CONTINUAR", "RESUME"),
    ("VOLTAR PARA O MENU", "BACK TO MENU"),
    # selecao de personagem
    ("ESCOLHA O OPERADOR", "CHOOSE YOUR OPERATOR"),
    # perfil da arma, no cartao
    ("DANO", "DAMAGE"),
    ("CADÊNCIA", "FIRE RATE"),
    ("PRECISÃO", "ACCURACY"),
    ("ALCANCE", "RANGE"),
    ("Enche a sala de chumbo. Quanto mais tempo no gatilho, mais o tiro abre.",
     "Fills the room with lead. The longer on the trigger, the wider the shot."),
    ("Um tiro, um alvo. Cada disparo pode marcar o inimigo e espalhar o Hack.",
     "One shot, one target. Every round can mark the enemy and spread the Hack."),
    # HUD
    ("ESTÁVEL", "STABLE"),
    ("DEGRADANDO", "DEGRADING"),
    ("CRÍTICO", "CRITICAL"),
    ("SALAS %d / %d", "ROOMS %d / %d"),
    ("HOSTIS %d", "HOSTILES %d"),
    ("RECARREGANDO...", "RELOADING..."),
    ("MIRA PREDITIVA ATIVA", "PREDICTIVE AIM ONLINE"),
    ("DEGRADAÇÃO EM 50%", "DEGRADATION AT 50%"),
    # Duas chaves e nao uma frase de duas linhas: o importador de CSV do Godot
    # trata a quebra de linha como fim de registro, entao chave multilinha
    # partiria a tabela ao meio.
    ("Eles pararam de mirar em você.", "They stopped aiming at you."),
    ("Agora miram onde você vai estar.", "Now they aim where you will be."),
    ("NÍVEL CRÍTICO", "CRITICAL LEVEL"),
    ("Não confie no que você está vendo.", "Do not trust what you are seeing."),
    ("Você já instalou o máximo deste implante.",
     "You have already installed the maximum of this implant."),
    # tela de fim
    ("DIRETORA OFFLINE", "DIRECTOR OFFLINE"),
    ("Você sobreviveu à própria cabeça. Por enquanto.",
     "You survived your own head. For now."),
    ("CONSCIÊNCIA PERDIDA", "CONSCIOUSNESS LOST"),
    ("Restaurando do último backup...", "Restoring from last backup..."),
    ("SALAS LIMPAS", "ROOMS CLEARED"),
    ("HOSTIS NEUTRALIZADOS", "HOSTILES NEUTRALIZED"),
    ("CRÉDITOS", "CREDITS"),
    ("TEMPO", "TIME"),
    ("LUTA DO CHEFE", "BOSS FIGHT"),
    ("DETERIORAÇÃO FINAL", "FINAL DETERIORATION"),
    ("R  outra run          ESC  trocar de personagem",
     "R  another run          ESC  change operator"),
    # personagens -- o NOME nao entra: RAVEN e NOVA sao marcas, nao frases.
    ("Operadora de Combate", "Combat Operator"),
    ("Hacker Experimental", "Experimental Hacker"),
]

# Implantes: nome e descricao de cada um.
IMPLANTES = [
    ("Célula de Eco", "Echo Cell"),
    ("Recarregar carrega o cano. Os 3 tiros seguintes causam +50% de dano.",
     "Reloading charges the barrel. The next 3 shots deal +50% damage."),
    ("Daemon de Combate", "Combat Daemon"),
    ("Matar sem apanhar acumula carga: +5% de dano cada, até 5. Levar dano zera tudo.",
     "Killing without being hit stacks charges: +5% damage each, up to 5. "
     "Taking damage clears them."),
    ("Dissipador Térmico", "Thermal Sink"),
    ("A cabeça esquenta devagar. -20% de Deterioração.",
     "The head heats up slowly. -20% Deterioration."),
    ("Firewall Cognitivo", "Cognitive Firewall"),
    ("Filtra o ruído, e junto o impacto. -25% de Deterioração, -10% de dano.",
     "Filters the noise, and the impact with it. -25% Deterioration, -10% damage."),
    ("Fragmentador Quântico", "Quantum Splitter"),
    ("10% dos tiros se partem em dois ao acertar, com metade do dano.",
     "10% of shots split in two on hit, with half the damage."),
    ("Gatilho Overclock", "Overclock Trigger"),
    ("O dedo não espera. +18% de cadência.", "The finger does not wait. +18% fire rate."),
    ("Munição Inteligente", "Smart Rounds"),
    ("A bala procura de novo. 15% de chance de ricochetear na parede.",
     "The bullet looks again. 15% chance to ricochet off walls."),
    ("Nanobots de Reparação", "Repair Nanobots"),
    ("A cada 30 abates, 1 de vida de volta.", "Every 30 kills, 1 health back."),
    ("Núcleo de Reserva", "Reserve Core"),
    ("Mais um backup de consciência. +2 de vida máxima.",
     "One more backup of consciousness. +2 max health."),
    ("Overclock Neural", "Neural Overclock"),
    ("O cérebro acelera junto com o gatilho. +20% de cadência, +10% de Deterioração.",
     "The brain speeds up with the trigger. +20% fire rate, +10% Deterioration."),
    ("Munição Perfurante", "Piercing Rounds"),
    ("Cada tiro dói mais. +1 de dano.", "Every shot hurts more. +1 damage."),
    ("IA Predatória", "Predator AI"),
    ("Um abate marca o próximo alvo. O tiro seguinte nele causa +75% de dano.",
     "A kill marks the next target. The following shot on it deals +75% damage."),
    ("Reflexo Sintético", "Synthetic Reflex"),
    ("O rolamento volta antes. -15% de recarga da esquiva.",
     "The roll comes back sooner. -15% dodge cooldown."),
    ("Servo-Motor", "Servo Motor"),
    ("Passadas mais longas. +12% de velocidade.", "Longer strides. +12% speed."),
    ("Módulo de Sobrecarga", "Overload Module"),
    ("Encurralado, o sistema queima reservas. Abaixo de 30% de vida: "
     "+40% de dano e +25% de cadência.",
     "Cornered, the system burns reserves. Below 30% health: "
     "+40% damage and +25% fire rate."),
    ("Núcleo Vampírico", "Vampiric Core"),
    ("Cada abate devolve um pouco. 5% de chance de recuperar 1 de vida.",
     "Every kill gives a little back. 5% chance to recover 1 health."),
]

# Armas: so a descricao. O nome ("PST-9 \"Teimosa\"") e marca.
ARMAS = [
    ("Pistola de serviço com célula de energia auto-recarregável. Não acaba. "
     "Também não impressiona.",
     "Service pistol with a self-recharging power cell. Never runs out. "
     "Never impresses either."),
    ("Oito a dez fragmentos por disparo, e nunca a mesma conta. Encosta e resolve.",
     "Eight to ten fragments per shot, and never the same count. Get close and settle it."),
    ("Cadência alta, dano baixo. Segurar o gatilho abre o tiro; soltar fecha de novo.",
     "High fire rate, low damage. Holding the trigger opens the spread; "
     "letting go closes it again."),
    ("Disparo único, eletromagnético. Atravessa um corpo, então um tiro pode "
     "marcar dois.",
     "Single shot, electromagnetic. It goes through one body, so a single shot "
     "can mark two."),
    ("Um trilho eletromagnético. Atravessa três corpos antes de parar, e "
     "recompensa quem alinha a fila.",
     "An electromagnetic rail. Punches through three bodies before stopping, "
     "and rewards whoever lines them up."),
    ("O tiro ignora parede. Dano menor em troca de acertar quem se escondeu "
     "atrás do pilar.",
     "The shot ignores walls. Less damage in exchange for hitting whoever hid "
     "behind the pillar."),
    ("Quase não machuca: arremessa. Serve para tirar inimigo de cima de você e "
     "para juntar quem estava espalhado.",
     "It barely hurts: it throws. Good for getting enemies off you, and for "
     "bunching up whoever was spread out."),
]


def main():
    linhas = UI + IMPLANTES + ARMAS

    vistas = {}
    for chave, _ in linhas:
        if chave in vistas:
            raise SystemExit("chave repetida na tabela: %r" % chave)
        if "\n" in chave:
            raise SystemExit("chave com quebra de linha: %r" % chave)
        vistas[chave] = True

    os.makedirs(os.path.dirname(SAIDA), exist_ok=True)
    with io.open(SAIDA, "w", encoding="utf-8", newline="\n") as f:
        w = csv.writer(f, quoting=csv.QUOTE_ALL, lineterminator="\n")
        w.writerow(["keys", "en"])
        for chave, en in linhas:
            w.writerow([chave, en])
    print("%s: %d chaves" % (os.path.relpath(SAIDA, RAIZ), len(linhas)))


if __name__ == "__main__":
    main()
