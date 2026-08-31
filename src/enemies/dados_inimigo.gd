class_name DadosInimigo
extends Resource
## Os NUMEROS de um inimigo, fora da cena.
##
## Mesmo caminho que `DadosArma`, `DadosSala`, `DadosItem` e `DadosPersonagem`
## ja fizeram -- o inimigo era o unico dominio que tinha ficado para tras, com
## tudo em `@export` dentro do `.tscn`. Aquilo ja era ajustavel sem programar,
## mas tinha tres limites reais:
##
## 1. **Nao dava para ter duas variantes do mesmo inimigo** sem duplicar a cena,
##    e cena e onde o merge doi -- a convencao do projeto e uma pessoa por
##    `.tscn` por vez.
## 2. **Nao dava para difar um balanceamento.** Um `.tres` de numeros muda em
##    poucas linhas legiveis; um `.tscn` muda junto com posicao de no e
##    sub-recurso, e a revisao vira arqueologia.
## 3. **A sessao de tuning a tres** precisa girar botao sem abrir cena.
##
## ONDE FICA A LINHA: aqui moram os numeros de BALANCEAMENTO. A identidade
## visual -- `cor_base`, `largura_sombra`, o sprite, o poligono -- continua na
## cena, junto do corpo a que ela pertence. Um `.tres` de stats que carregasse a
## cor faria "trocar o balanceamento" e "trocar a aparencia" serem a mesma
## operacao, e sao coisas que pessoas diferentes mexem.
##
## COMO SE APLICA: `InimigoBase.dados` e OPCIONAL. Sem ele, o inimigo usa os
## `@export` do proprio script -- e por isso o Rastejante, o Vigia, a Diretora e
## as pecas da arena dela continuam funcionando sem `.tres` nenhum. Com ele, o
## recurso VENCE, e a aplicacao acontece no TOPO do `_ready()`: `InimigoBase`
## congela `vida = vida_maxima` logo abaixo, e o Player ja ensinou o preco de
## aplicar atributo depois do congelamento -- todo recalculo de modificador
## passa a somar em cima do numero errado.
##
## Nem todo inimigo usa todo campo, e isso e de proposito: e o mesmo desenho de
## `DadosArma`, onde o grupo "Explosao" so interessa a granada e o "Teleguiado"
## so a Swarm. Um Resource por inimigo dariam cinco arquivos de classe para
## descrever a mesma coisa.
##
## **Se algum dia entrar um enum aqui, valor novo entra NO FIM.** Enum e gravado
## como INT no `.tres`; inserir no meio reescreve em silencio o significado de
## todo inimigo ja salvo. Vale para `DadosArma.Comportamento` e `DadosItem`, e
## vai valer aqui.

## So para o Inspetor e para a sessao de tuning: e o nome do arquivo que manda.
@export var nome: String = "Inimigo"

@export_group("Atributos")
@export var vida: int = 5
@export var velocidade: float = 120.0
@export var dano_contato: int = 1
@export var creditos: int = 3
## Quanto este inimigo soma na barra ao morrer. Zero por padrao -- quem move a
## barra e limpar a sala, nao a matanca.
@export var deterioracao_ao_morrer: float = 0.0

@export_group("Contato")
## Ate onde o corpo dele machuca. E numero de balanceamento e nao de desenho: e
## o alcance do ataque de encostar.
@export var raio_contato: float = 26.0
@export var intervalo_dano_contato: float = 0.7

@export_group("Ciclo de ataque")
## Quanto tempo entre dois ataques. Sofre `Deterioracao.multiplicador_cadencia`
## em quem o consome -- nunca guarde o produto.
@export var cooldown_ataque: float = 2.0
## Quanto o aviso dura. O piso de `Telegrafo.DURACAO_MINIMA` e aplicado por
## baixo em quem avisa, entao um numero pequeno demais aqui nao apaga o aviso.
@export var tempo_telegrafo: float = 0.5
## Pausa curta ANTES do telegrafo, para separar dois momentos que sem ela
## acontecem no mesmo frame. E o `tempo_encarando` da Cyber-Besta.
@export var tempo_preparo: float = 0.0
## A janela de punicao depois do ataque. E o pagamento pelo dano.
@export var tempo_recuperacao: float = 0.5

@export_group("Distancia")
## Onde ele QUER ficar: o raio de orbita, a faixa de tiro, o ponto de
## posicionamento.
@export var distancia_preferida: float = 200.0
## Tolerancia em volta da preferida. Sem ela o inimigo oscila entrando e saindo.
@export var margem_de_distancia: float = 40.0
## Abaixo disto ele reage -- recua, esquiva, foge. Zero desliga.
@export var distancia_minima: float = 0.0
## Ate onde o ataque dele vale a pena. Longe disto ele nem tenta.
@export var alcance: float = 300.0

@export_group("Salva")
## Quantos projeteis saem de uma vez. Consumido por `Arma.atirar_varias()`, e
## nunca por um laco de `atirar()` -- aquele sairia com UM.
@export var projeteis: int = 1
## Abertura TOTAL do leque, em graus. Zero = tiro reto ou anel completo.
@export var abertura_graus: float = 0.0
## Quantos tiros unicos vem antes de uma salva. Zero desliga a alternancia.
@export var tiros_ate_salva: int = 0
## Quanto o aviso da salva dura A MAIS que o do tiro unico. Um ataque mais forte
## avisa mais -- sem isso os dois ficam indistinguiveis ate o projetil existir.
@export var fator_aviso_salva: float = 1.0

@export_group("Orbita")
## Peso da correcao radial contra a tangente, na forma proporcional. Ver
## `Movimento.rumo_orbital()`.
@export var correcao_radial: float = 0.55
## Quanto do movimento sobra para o lado, na forma de FAIXA. 1,0 e orbita pura;
## 0,0 e aproximacao pura.
@export var peso_lateral: float = 0.85

@export_group("Arranque")
## Velocidade da investida, em px/s. Numero PROPRIO: ele nao deriva de
## `velocidade` e nao escala com a Deterioracao, de proposito -- uma investida
## que acelera com a barra deixa de ser esquivavel pelo timing que o jogador
## acabou de aprender.
@export var velocidade_arranque: float = 0.0
## Multiplicador da velocidade normal, para quem arranca sem numero proprio --
## a esquiva do Atirador Neon.
@export var impulso_arranque: float = 1.0
@export var duracao_arranque: float = 0.0
## Quanto ele fica aberto depois de bater numa parede. Zero desliga.
@export var tempo_atordoado: float = 0.0

@export_group("Escalonamento")
## Os valores AVANCADOS: para onde cada botao caminha com a barra cheia.
##
## A Deterioracao ja multiplicava velocidade, cadencia e velocidade de projetil
## -- planilha. O que muda o jogo e o PADRAO mudar de forma, e e o que estes
## campos descrevem. Quem interpola e `Deterioracao.escalonar()`, no frame.
##
## NEGATIVO desliga, e e o default: inimigo que nao declara nada continua
## exatamente como era. Note que zero e um valor VALIDO em varios deles -- uma
## Sentinela com `tiros_ate_salva_avancado = 0` raja toda vez --, e por isso o
## sentinela e -1 e nao 0.
##
## O tempo de telegrafo NAO esta aqui: ele encurta para todo mundo pelo mesmo
## `Deterioracao.multiplicador_telegrafo()`, com o piso do `Telegrafo` por
## baixo. Deixa-lo por inimigo abriria a porta para alguem zera-lo num `.tres`.
@export var projeteis_avancados: int = -1
@export var tiros_ate_salva_avancado: int = -1
@export var max_areas_avancado: int = -1
@export var duracao_arranque_avancada: float = -1.0
@export var tempo_recuperacao_avancado: float = -1.0

@export_group("Territorio")
## Teto de areas vivas ao mesmo tempo. Sem ele, tres semeadores cobrem o chao
## inteiro e nao sobra lugar para o jogador ESTAR.
@export var max_areas: int = 0
@export var raio_area: float = 60.0
## Raio em volta do alvo onde as areas nascem. Zero cairia sempre em cima dele,
## o que seria um ataque sem escolha.
@export var espalhamento: float = 96.0
## Quanto tempo a brasa fica no chao depois do estouro. Zero desliga.
@export var tempo_residual: float = 0.0
