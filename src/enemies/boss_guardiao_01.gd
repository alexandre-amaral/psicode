extends InimigoBase
## AUTOMATO ENFERRUJADO -- o chefe do andar 1. Nome de codigo `boss_guardiao_01`,
## neutro de proposito, para nao amarrar a implementacao ao nome final.
##
## A IDENTIDADE, NUMA FRASE: **quanto mais danificado ele fica, mais rapido
## funciona.**
##
## Ele comeca pesado, enferrujado e quase incapaz de acompanhar o jogador. O dano
## nao o enfraquece -- remove a resistencia mecanica que a corrosao acumulou. Aos
## 2/3 o jogador percebe que ele nao era lento por design: estava travado. Aos
## 1/3, percebe o problema -- a maquina nao esta tentando sobreviver ao dano,
## esta usando a propria destruicao para funcionar acima do limite.
##
## A frase que o jogador deve pensar tres vezes, em fases diferentes:
## "eu ja conheco esse ataque, mas agora ele esta acontecendo mais rapido".
##
## POR QUE ELE E UM INIMIGO NOVO, E NAO UMA REFORMA DA DIRETORA. As duas
## identidades sao OPOSTAS, e uma delas e proibida por portao executavel: a
## trava 7 de `teste_diretora.gd` diz que ela NUNCA persegue, porque "um sistema
## nao corre atras de voce". O Automato faz o inverso -- ele investe, soca e
## pisa. Reformar a Diretora para caber nisso exigiria afrouxar o portao dela, e
## a personagem deixaria de existir sem uma linha no console. Ela continua
## intocada, e sai do andar 1 (BOSS 11).
##
## O MOVESET NAO E SUBSTITUIDO ENTRE FASES (BOSS 03 a 06). Os mesmos quatro
## ataques ficam reconheciveis e mais rapidos, e cada um ganha uma camada por
## fase em vez de virar outro ataque -- e essa continuidade que faz a mecanica de
## velocidade ENSINAR em vez de surpreender. Um moveset trocado a cada terco
## seria tres chefes curtos em sequencia, e o jogador nao teria o que dominar.
##
## | ataque   | fase 1            | fase 2                  | fase 3                    |
## |----------|-------------------|-------------------------|---------------------------|
## | SOCO     | uma onda frontal  | leque de tres           | dois golpes, um telegrafo cada |
## | RAJADA   | um leque de 5     | dois, o segundo nos vaos| tres, cada um nos vaos do anterior |
## | INVESTIDA| uma               | ate duas                | ate tres, e recuperacao grande |
## | PISAO    | anel de 8         | anel girado meio setor  | dois aneis intercalados   |
##
## A UNICA excecao e a FALHA DO REATOR (BOSS 08), exclusiva da fase 3: o ultimo
## terco precisa de assinatura propria, e ela e o unico ataque NOVO da luta. Ela
## nao substitui nada -- o repertorio so cresce, porque ataque que some faria o
## jogador desaprender.

## As tres fases, por FRACAO de vida.
##
## Os limiares sao fracao e nao valor absoluto de proposito: mexer na vida do
## chefe na sessao de tuning nao pode reescrever onde as viradas acontecem.
## A virada aconteceu. E o GANCHO DE SOM da luta: quem quiser o rangido de metal,
## o motor estabilizando ou o alarme interno liga aqui e nao precisa saber nada
## sobre a maquina de estados do chefe.
##
## Fica como sinal e nao como chamada direta porque o projeto ainda nao tem
## camada de audio -- ela e a AND1 08. O gancho existe agora para o dia em que
## ela existir nao ter de mexer no chefe.
signal fase_mudou(fase: int)

const LIMIAR_DESTRAVADO := 0.67
const LIMIAR_SOBRECARGA := 0.34

## O PISO de todo tempo derivado do multiplicador.
##
## E o mesmo numero que o `Telegrafo` crava e que a Diretora chama de
## `TELEGRAFO_MINIMO` -- e tem de ser o mesmo, senao a fronteira entre "dificil"
## e "mente sobre a propria regra" passa a ter duas posicoes no mesmo jogo.
##
## O pior caso NAO e o multiplicador de fase 3 sozinho: a Deterioracao multiplica
## dificuldade POR CIMA dele e chega a 1,7x em cadencia. `tempo_real()` divide
## pelos dois e so entao aplica o piso, entao o numero cobrado e o do pior caso
## de verdade -- 1,30 combinado com a barra cheia.
const TEMPO_MINIMO := Telegrafo.DURACAO_MINIMA

const CENA_AREA := preload("res://src/enemies/area_de_perigo.tscn")

## Teto de opacidade de todo efeito de fase (fumaca, faisca, brilho).
##
## E a mesma regra do `alpha_maximo` do shader de glitch, e ela nao e estetica:
## efeito que atrapalha a leitura do combate e efeito cortado, por mais bonito
## que seja. Fumaca e faisca na fase 3 sao o risco obvio -- eles nao podem cobrir
## telegrafo nem projetil.
const ALPHA_MAXIMO_EFEITO := 0.42

## Onde os efeitos de fase desenham: ATRAS do corpo dele.
##
## `Sala.Z_MUNDO` e zero, e e onde ficam o telegrafo, os projeteis e os atores.
## Um efeito em zero disputaria a mesma faixa e poderia cair na frente de um
## projetil -- e o jogador perderia justamente o que precisa ler. Negativo, ele
## nunca cobre nada que importe.
const Z_EFEITO := -1

## Acima disto o corpo esta ANDANDO, para efeito de desenho. O mesmo numero dos
## outros cinco inimigos com arte -- um chefe com limiar proprio andaria de um
## jeito e os demais de outro, sem nada que apontasse a diferenca.
const VELOCIDADE_ANDANDO := 12.0

## O repertorio. Ele so CRESCE com a fase (a BOSS 08 acrescenta a Falha do
## Reator na 3) -- ataque que some faria o jogador desaprender.
const SOCO := &"SOCO"
const RAJADA := &"RAJADA"
const INVESTIDA := &"INVESTIDA"
const PISAO := &"PISAO"
## O ataque exclusivo da fase 3. Ver `_falha_do_reator()`.
const REATOR := &"REATOR"
const REPERTORIO: Array[StringName] = [SOCO, RAJADA, INVESTIDA, PISAO]

const IDLE := &"IDLE"
## Ele ACORDA antes de lutar. Ver `_despertar()`.
const DESPERTAR := &"DESPERTAR"
const ESCOLHER_ATAQUE := &"ESCOLHER_ATAQUE"
const PREPARAR := &"PREPARAR"
const EXECUTAR := &"EXECUTAR"
const RECUPERAR := &"RECUPERAR"
const TRANSICAO_FASE := &"TRANSICAO_FASE"
const ATORDOADO := &"ATORDOADO"
const MORTE := &"MORTE"

@export_group("Identidade")
## O nome que a HUD mostra e o que o teste de fumaca usa para RECONHECER o chefe.
##
## Nao e cosmetico: `teste_fumaca.gd` acha o chefe por
## `inimigo.get("nome_exibicao") != null`, e sem ele o Automato seria conferido
## como um inimigo comum -- ninguem checaria que ele nasceu na sala do chefe.
@export var nome_exibicao: String = "AUTOMATO ENFERRUJADO"
## Quantas fases ele tem. Declarado e nao cravado no teste porque o teste de
## fumaca exige que TODAS as transicoes tenham acontecido, e a Diretora tem
## quatro enquanto ele tem tres -- um numero fixo la reprovaria o chefe certo.
@export var total_de_fases: int = 3

@export_group("Som")
## Um som por fase, na ordem 1, 2, 3. Toca na VIRADA.
##
## O gancho `fase_mudou` existia desde a BOSS 07 esperando a camada de audio; ela
## chegou na AND1 08 e isto e o que ele passou a fazer. Os tres sao a MESMA
## sintese com um parametro diferente (`tools/audio/gerar_sons.gd`), e nao tres
## timbres: a luta inteira e "o mesmo, mais rapido", e tres motores diferentes
## diriam que sao tres maquinas.
@export var som_por_fase: Array[AudioStream] = []

@export_group("Fases")
## O multiplicador de cada fase. E o botao central do chefe inteiro: ele alcanca
## movimentacao, cadencia, telegrafo, recuperacao e rotacao de uma vez.
##
## Se ele valesse so para a movimentacao, o jogador veria um robo andando rapido
## com ataques no mesmo ritmo -- e a ideia inteira nao chega.
@export var mult_enferrujado: float = 0.75
@export var mult_destravado: float = 1.0
@export var mult_sobrecarga: float = 1.30

@export_group("Soco Hidraulico")
## Onde o punho cai, a frente dele.
@export var alcance_soco: float = 92.0
@export var raio_soco: float = 78.0
## Quanto o segundo golpe da fase 3 desloca para o outro lado. E o que faz o par
## ser "esquerdo e direito" e nao "o mesmo golpe duas vezes".
@export var desvio_do_segundo_golpe: float = 46.0
## Abertura do leque de ondas, a partir da fase 2. -25 / 0 / +25.
@export var abertura_onda: float = 50.0

@export_group("Rajada de Sucata")
@export var projeteis_rajada: int = 5
@export var abertura_rajada: float = 60.0
## Espaco entre duas rajadas da mesma salva.
@export var intervalo_rajada: float = 0.28

@export_group("Investida Pesada")
@export var velocidade_investida: float = 620.0
@export var duracao_investida: float = 0.5
## Quanto ele fica aberto depois de bater na parede. E a melhor janela de dano.
@export var tempo_atordoado_parede: float = 1.6

@export_group("Pisao")
@export var projeteis_pisao: int = 8
## Espaco entre as duas ondas da fase 3. Curto: elas tem de ler como UM ataque.
@export var intervalo_pisao: float = 0.25

@export_group("Falha do Reator")
## Quantas areas cercam ele. Os VAOS entre elas sao as aberturas do ataque, e e
## por isso que a contagem importa: mais areas fecham o cerco.
@export var areas_do_reator: int = 6
@export var raio_do_cerco: float = 200.0
@export var raio_da_area_do_reator: float = 76.0
## O estouro central. Ele cobre o miolo do cerco, entao ficar colado nele deixa
## de ser abrigo -- as saidas sao os vaos e o lado de fora.
@export var raio_do_estouro: float = 150.0
@export var projeteis_do_reator: int = 12
## O TELEGRAFO MAIS LONGO DA LUTA, e ele tem de continuar sendo na fase 3.
##
## Regra do projeto, e ela e dura: quanto mais forte o ataque, maior o
## telegrafo. Ataque capaz de tirar grande parte da vida precisa ser facilmente
## reconhecivel. Este e o mais perigoso da luta, entao ele avisa mais que
## qualquer outro -- inclusive com o multiplicador em 1,30 e a barra cheia.
@export var tempo_preparo_reator: float = 2.2
## A recuperacao nao e sobra: ela REPRESENTA a ficcao. Acelerar esta destruindo o
## proprio sistema, e o preco de usar a arma mais forte e ficar aberto. E uma das
## melhores janelas de dano da luta.
@export var tempo_recuperacao_reator: float = 2.4

@export_group("Desgaste visual")
## Onde a carcaca comeca a cair, em fracao de vida. Espelha as fases: o jogador
## tem de conseguir dizer em que fase ele esta SEM olhar a barra.
@export var desgaste_placas: float = 0.67
@export var desgaste_motor: float = 0.34
## Quanto o nucleo pulsa por segundo em cada fase. E o sinal que se le de longe.
@export var pulso_fase_1: float = 1.2
@export var pulso_fase_2: float = 3.0
@export var pulso_fase_3: float = 7.5

@export_group("Selecao de ataque")
@export var peso_soco: float = 3.0
@export var peso_rajada: float = 3.0
@export var peso_investida: float = 2.0
@export var peso_pisao: float = 2.0
@export var peso_reator: float = 3.0
## Quanto sobra do peso do ataque que ACABOU de sair. Zero = nunca repete.
##
## Sem memoria, dois socos seguidos por azar leem como bug e tres leem como
## injustica -- o jogador nao tem como saber que foi sorteio.
@export var peso_da_repeticao: float = 0.0
## A fronteira entre perto e longe, em px.
@export var distancia_de_perto: float = 220.0
## Quanto a distancia mexe no peso. 1,0 desliga o vies.
@export var vies_de_distancia: float = 2.2

@export_group("Ritmo")
## Quanto ele leva escolhendo o proximo ataque. E a respiracao entre golpes.
@export var tempo_escolha: float = 0.5
## O telegrafo. Encurta com a fase, e nunca abaixo de `TEMPO_MINIMO`.
@export var tempo_preparo: float = 0.8
@export var tempo_execucao: float = 0.4
## A janela de punicao depois do golpe.
@export var tempo_recuperacao: float = 1.0
## A virada de fase. Ele trava, a maquina reassenta, e SO ENTAO volta a atacar.
@export var tempo_transicao: float = 1.2
@export var tempo_atordoado: float = 1.2
## Quanto ele leva para acordar na baia, uma vez por luta.
##
## A APRESENTACAO dele e o jogador acreditar que o robo e CENARIO: parado na
## baia, luzes apagadas, cabeca baixa. Ai a porta fecha, a energia chega, o motor
## tenta girar, FALHA, tenta de novo, e ele desperta. Isso entrega "velho, pesado
## e dificil de iniciar" antes do primeiro ataque -- que e exatamente a frase que
## a luta inteira existe para provar.
##
## Longo, e uma vez so: e a unica parte da luta em que o jogador nao esta sendo
## atacado, e ela paga por si mesma dizendo com o que ele vai lidar.
@export var tempo_despertar: float = 2.0

## 1, 2 ou 3. Publico porque a HUD, o tuning e as suites leem daqui.
var fase_chefe: int = 1

var _maquina: MaquinaEstados
## A maior fase ja anunciada. E a bandeira que faz cada transicao acontecer UMA
## vez: sem ela, o HP oscilando em volta do limiar -- e ele oscila, porque a
## vida cai a cada tiro -- reentraria em TRANSICAO_FASE para sempre, e o chefe
## nunca mais atacaria.
var _fase_anunciada: int = 1

## O ataque em curso, e o que ele ainda tem para fazer.
var _ataque: StringName = SOCO
## Sobe a cada ataque escolhido. Alimenta a alternancia deterministica das
## salvas -- ver `Balistica.alternancia()`.
var _indice_salva: int = 0
## Quantos beats do ataque atual ja sairam: rajadas de uma salva, aneis de um
## pisao, investidas de uma sequencia.
var _beats: int = 0
## Quantos golpes de soco ainda faltam nesta sequencia. Fase 3 pede dois, e cada
## um com telegrafo PROPRIO -- por isso ele volta a PREPARAR em vez de repetir
## dentro de EXECUTAR.
var _golpes_restantes: int = 1
## Travada em PREPARAR e NAO atualizada durante a execucao. E a regra que torna
## a investida justa, e a mesma que a Cyber-Besta ja segue: investida que
## persegue durante a execucao nao da para esquivar, so para sobreviver.
var _direcao_travada: Vector2 = Vector2.RIGHT
## O corpo de oito rotacoes. Ver `_animar()`.
var _sprite: SpriteDirecional
## O ataque anterior. E a MEMORIA da selecao: sem ela, dois socos seguidos por
## azar leem como bug e tres leem como injustica.
var _ultimo_ataque: StringName = &""
## A duracao do telegrafo DESTE ataque, fixada na entrada.
##
## Fixada e nao relida todo frame porque a barra sobe durante o proprio
## telegrafo: relendo, o aviso encolheria enquanto o jogador o le, e o alvo do
## telegrafo e justamente ser previsivel.
var _aviso_atual: float = 0.0
var _arma_onda: Arma
var _arma_sucata: Arma
var _braco: Node2D
## As areas que ele semeou e que ainda vivem. Ver `morrer()`.
var _areas: Array[Node] = []
## O quanto ele ja se desfez, de 0 a 1. Sobe com o dano e NUNCA desce.
##
## Nao desce porque o desgaste e FISICO: placas que cairam nao voltam. Deixa-lo
## seguir a vida para cima faria a carcaca se remontar sozinha se alguem curasse
## o chefe, e o jogador leria isso como o chefe se recuperando -- o oposto da
## ficcao, em que o dano e o que o destrava.
var _desgaste: float = 0.0
var _placa: CanvasItem
var _nucleo: CanvasItem
var _fumaca: CanvasItem
var _t_pulso: float = 0.0


func _ready() -> void:
	super._ready()

	_placa = $Visual/Placa
	_nucleo = $Visual/Nucleo
	_fumaca = $Visual/Fumaca
	_fumaca.z_index = Z_EFEITO
	_fumaca.modulate.a = 0.0
	_braco = $Braco
	_sprite = get_node_or_null("Visual/Corpo") as SpriteDirecional
	_arma_onda = $Braco/ArmaOnda
	_arma_onda.hostil = true
	_arma_sucata = $Braco/ArmaSucata
	_arma_sucata.hostil = true

	_maquina = MaquinaEstados.new(name)
	_maquina.adicionar(IDLE, _idle)
	_maquina.adicionar(DESPERTAR, _despertar, _despertar_entrar)
	_maquina.adicionar(ESCOLHER_ATAQUE, _escolher)
	_maquina.adicionar(PREPARAR, _preparar, _preparar_entrar)
	_maquina.adicionar(EXECUTAR, _executar, _executar_entrar)
	_maquina.adicionar(RECUPERAR, _recuperar)
	_maquina.adicionar(TRANSICAO_FASE, _transicao, _transicao_entrar)
	_maquina.adicionar(ATORDOADO, _atordoado, _atordoado_entrar)
	_maquina.adicionar(MORTE, _morte)
	_maquina.iniciar(IDLE)


## Ver `DadosInimigo`. Os numeros de ritmo dele saem do recurso pelo mesmo
## caminho dos cinco inimigos comuns (INIM 08) -- a sessao de tuning gira o
## chefe sem abrir cena.
func _ler_dados(d: DadosInimigo) -> void:
	tempo_escolha = d.cooldown_ataque
	tempo_preparo = d.tempo_telegrafo
	tempo_recuperacao = d.tempo_recuperacao


## A HUD do chefe so existe se alguem a acender.
##
## `boss_revelado` e o que faz a barra dele aparecer, e `boss_vida_mudou` e o que
## a move. Sao os mesmos sinais que a Diretora emite -- a HUD nao sabe qual chefe
## esta na sala, e nao precisa saber.
func _ao_nascer() -> void:
	super._ao_nascer()
	EventBus.boss_revelado.emit(nome_exibicao, vida_maxima)
	EventBus.boss_vida_mudou.emit(vida, vida_maxima)


## Chama `super` e SO ENTAO avisa a HUD.
##
## A Diretora reimplementa `receber_dano` sem chamar `super`, e o GEMINI.md
## registra o preco: ela e o unico inimigo do jogo imune ao bonus de Hack, em
## silencio. Aqui o caminho comum roda inteiro e este metodo so acrescenta o
## aviso -- o Automato apanha de Hack como qualquer outro.
func receber_dano(quantidade: int, impulso: Vector2 = Vector2.ZERO) -> bool:
	var doeu := super.receber_dano(quantidade, impulso)
	if doeu:
		EventBus.boss_vida_mudou.emit(maxi(vida, 0), vida_maxima)
	return doeu


func _comportamento(delta: float) -> void:
	_checar_fase()
	_atualizar_leitura_visual(delta)
	# A velocidade de projetil le a Deterioracao no frame, como em todo inimigo.
	_arma_onda.multiplicador_velocidade = Deterioracao.multiplicador_velocidade_projetil()
	_arma_sucata.multiplicador_velocidade = Deterioracao.multiplicador_velocidade_projetil()
	_maquina.processar(delta)


## A batida na parede.
##
## Roda em `_pos_movimento` porque so depois do `move_and_slide()` o
## `is_on_wall()` significa alguma coisa -- antes dele o motor ainda nao tentou
## mover ninguem. Parede e detectada por LAYER e nao por grupo: as paredes
## geradas por `sala.gd` e `corredor.gd` nao entram em grupo nenhum, e o teste
## antigo por grupo foi o que deixava projetil atravessar parede.
func _pos_movimento(delta: float) -> void:
	# A batida vem PRIMEIRO, e antes de qualquer retorno por causa de arte:
	# regra de combate nao pode passar a depender de haver sprite. E a mesma
	# ordem que `cyber_besta.gd` mantem no `_conferir_batida()` dela.
	_conferir_batida()
	_animar(delta)


func _conferir_batida() -> void:
	if _maquina == null or _maquina.estado != EXECUTAR or _ataque != INVESTIDA:
		return
	if is_on_wall():
		_maquina.trocar(ATORDOADO)


## O corpo desenha a direcao e o passo.
##
## ISTO NAO EXISTIA, e o chefe passou da BOSS 10 ate aqui congelado. A cena
## declarava as 8 poses e as 8 fitas desde que ele ganhou arte, e nada nas 1060
## linhas deste script chamava `apontar()` -- nao havia sequer um campo
## `_sprite`. O corpo ficava no quadro que o `_ready()` do `SpriteDirecional`
## escreve, `south.png` quadro 0, a luta inteira: ele deslizava para o norte
## encarando o sul.
##
## Nada acusava. Os arquivos estavam certos, casados e medidos, e a suite
## conferia tudo isso -- ninguem conferia se alguem os USAVA. O portao que fecha
## esse silencio ja existia em `teste_sprite_direcional.gd`, cravado na
## Cyber-Besta; hoje ele varre o elenco inteiro.
func _animar(delta: float) -> void:
	if _sprite == null:
		return
	_sprite.apontar(
		_direcao_encarada(), velocity.length() > VELOCIDADE_ANDANDO, delta, velocity
	)


## Para onde o corpo aponta neste estado.
##
## `_direcao_travada` so significa alguma coisa DEPOIS do primeiro PREPARAR: ela
## nasce em `Vector2.RIGHT` e tem UM escritor (`_preparar_entrar`). Usa-la nos
## estados que acontecem antes disso faria ele encarar o leste sem motivo.
##
## Dormente ele encara o SUL e nao o jogador, e isso e a apresentacao inteira: na
## baia ele tem de ler como CENARIO, e cenario nao vira para te olhar. O sul e
## exatamente o que o `_ready()` do sprite ja desenha, entao a pose dormente e a
## pose de fabrica -- de graca.
##
## A TRANSICAO encara o alvo pelo mesmo motivo que o DESPERTAR: ela pode disparar
## durante o PRIMEIRO `ESCOLHER_ATAQUE`, antes de existir trava nenhuma. Travar a
## direcao tambem la resolveria, mas custaria a propriedade de o campo ter um
## escritor so.
func _direcao_encarada() -> Vector2:
	if _maquina == null:
		return Vector2.DOWN
	match _maquina.estado:
		IDLE:
			return Vector2.DOWN
		DESPERTAR, ESCOLHER_ATAQUE, TRANSICAO_FASE:
			var d := direcao_para_alvo()
			return d if d.length_squared() > 0.01 else Vector2.DOWN
		_:
			# PREPARAR, EXECUTAR, RECUPERAR, ATORDOADO, MORTE. O corpo travado E
			# metade do aviso, e e o que torna a investida justa.
			return _direcao_travada


# --------------------------------------------------------- o multiplicador --

## A fase que a vida ATUAL pede. Pura: nao muda nada, so responde.
func fase_por_vida() -> int:
	var fracao := float(vida) / float(maxi(vida_maxima, 1))
	if fracao > LIMIAR_DESTRAVADO:
		return 1
	if fracao > LIMIAR_SOBRECARGA:
		return 2
	return 3


## O multiplicador da fase, sozinho. E o numero que a ficcao promete.
func multiplicador_de(fase: int) -> float:
	match fase:
		1: return mult_enferrujado
		2: return mult_destravado
		3: return mult_sobrecarga
	return mult_destravado


func multiplicador() -> float:
	return multiplicador_de(fase_chefe)


## Tudo que acelera o chefe, junto: a fase E a Deterioracao.
##
## Existe como funcao propria porque e ELE, e nao o multiplicador de fase, o
## numero contra o qual o piso tem de ser calculado. Cobrar o piso so contra 1,30
## deixaria a barra cheia furar o piso por baixo, sem erro nenhum.
func multiplicador_total() -> float:
	return multiplicador() * Deterioracao.multiplicador_cadencia()


## Converte um tempo de projeto no tempo REAL desta fase, com piso.
##
## Todo tempo do chefe passa por aqui -- telegrafo, execucao, recuperacao,
## escolha, transicao. E o que faz o moveset ficar reconhecivel e mais rapido em
## vez de virar outro moveset: os mesmos gestos, na mesma ordem, comprimidos.
func tempo_real(base: float) -> float:
	return maxf(base / maxf(multiplicador_total(), 0.01), TEMPO_MINIMO)


## A velocidade dele agora. Sobrescreve a base para somar o multiplicador de
## fase ao da Deterioracao, e nada guarda o produto -- perder vida no meio de um
## passo ja acelera aquele passo.
func velocidade_atual() -> float:
	return velocidade_base * Deterioracao.multiplicador_velocidade() * multiplicador()


func em_transicao() -> bool:
	return _maquina.estado == TRANSICAO_FASE


# -------------------------------------------------------- leitura visual ----

## O DESGASTE: 0 na carcaca inteira, 1 no motor exposto.
##
## Ele acompanha a VIDA e nao a fase, e a diferenca importa: dentro de um mesmo
## terco o jogador continua vendo progresso, e e isso que faz bater nele parecer
## que esta funcionando antes de a virada acontecer.
func desgaste() -> float:
	return _desgaste


## Os TRES estados de deterioracao do corpo: 0 inteiro, 1 danificado, 2 motor
## exposto.
##
## Sai da VIDA e nao da fase, e os dois nao sao a mesma coisa por acaso -- eles
## usam os mesmos limiares de proposito, para o corpo contar a mesma historia
## que o ritmo. O que muda e a granularidade: a fase troca uma vez por terco, o
## desgaste acompanha continuamente dentro dele (a fumaca cresce), e e isso que
## faz bater nele parecer que esta funcionando antes de a virada acontecer.
func estado_de_desgaste() -> int:
	var fracao := 1.0 - _desgaste
	if fracao > desgaste_placas:
		return 0
	if fracao > desgaste_motor:
		return 1
	return 2


## Quanto o nucleo pulsa por segundo, nesta fase.
##
## E o sinal que se le de LONGE, e o que responde "em que fase ele esta?" sem a
## barra de vida. Fraco e travado na 1, constante na 2, rapido e instavel na 3.
func pulso_da_fase() -> float:
	match fase_chefe:
		1: return pulso_fase_1
		2: return pulso_fase_2
	return pulso_fase_3


## Roda todo frame: a carcaca cai, o nucleo pulsa, a fumaca cresce.
##
## Tudo aqui e procedural. `SCREEN_TEXTURE` quebra no export web e MSAA 2D nao
## existe no renderer Compatibility, entao efeito de chefe que dependesse de
## qualquer um dos dois sairia no PC e sumiria no navegador -- e a build que vai
## para o testador e a web.
func _atualizar_leitura_visual(delta: float) -> void:
	var fracao := float(vida) / float(maxi(vida_maxima, 1))
	_desgaste = maxf(_desgaste, clampf(1.0 - fracao, 0.0, 1.0))

	# O remendo de MOTOR EXPOSTO. Ele aparece no ultimo terco e nao volta.
	#
	# Com o placeholder o sinal era o inverso -- uma placa que sumia --, e isso
	# deixou de funcionar quando a arte chegou: a carcaca desenhada ja tem as
	# placas, e esconder um poligono por cima dela nao tira nada. Sobre arte, o
	# que le e o que se ACRESCENTA.
	if _placa != null:
		_placa.visible = estado_de_desgaste() >= 2
	# O nucleo pulsa mais rapido a cada fase, e nunca apaga: um nucleo que some
	# tiraria justamente o sinal que diz que ele ainda esta funcionando.
	if _nucleo != null:
		if esta_dormente():
			# APAGADO na baia: e o que faz o corpo ler como cenario. Um chefe que
			# pulsa antes de acordar entrega o truque no primeiro quadro.
			_nucleo.modulate.a = 0.0
			_t_pulso = 0.0
		else:
			_t_pulso += delta * pulso_da_fase()
			var onda := 0.5 + 0.5 * sin(_t_pulso * TAU)
			var teto := 1.0
			if esta_despertando():
				# A energia CHEGANDO: o nucleo sobe do zero ao longo do despertar,
				# em vez de acender de uma vez.
				teto = clampf(_maquina.tempo_no_estado / maxf(tempo_despertar, 0.01), 0.0, 1.0)
			_nucleo.modulate.a = lerpf(0.55, 1.0, onda) * teto
			_nucleo.scale = Vector2.ONE * lerpf(1.0, 1.0 + 0.25 * _desgaste, onda)
	# A fumaca so comeca no segundo terco, e cresce dali. No primeiro ela seria
	# ruido: a carcaca inteira ja diz "velho", e fumaca desde o inicio nao
	# distinguiria estado nenhum.
	if _fumaca != null:
		var acesa := estado_de_desgaste() >= 1
		_fumaca.visible = acesa
		_fumaca.modulate.a = minf(_desgaste * ALPHA_MAXIMO_EFEITO, ALPHA_MAXIMO_EFEITO) if acesa else 0.0
		_fumaca.scale = Vector2.ONE * lerpf(0.7, 1.5, _desgaste)


# ------------------------------------------------------------ as viradas ----

## Entra em TRANSICAO_FASE quando a vida cruza um limiar, uma vez por virada.
##
## NAO troca de fase durante a propria transicao nem depois de morto: no
## primeiro caso a virada se reiniciaria a cada frame em que o dano continuasse
## chegando, e o chefe ficaria preso no gesto de virar.
func _checar_fase() -> void:
	if morto or em_transicao():
		return
	var pedida := fase_por_vida()
	if pedida <= _fase_anunciada:
		return
	_fase_anunciada = pedida
	_maquina.trocar(TRANSICAO_FASE)


## A fase so muda AQUI, na entrada da transicao -- e nao no instante em que o HP
## cruza o limiar.
##
## A diferenca importa: se `fase_chefe` subisse no `_checar_fase`, o ataque em
## curso terminaria com o timing da fase NOVA no meio do proprio gesto. O
## jogador leria o telegrafo de uma fase e levaria o golpe de outra, que e a
## definicao de mentir sobre a propria regra.
func _transicao_entrar() -> void:
	fase_chefe = _fase_anunciada
	EventBus.pedido_shake.emit(6.0, 0.35)
	fase_mudou.emit(fase_chefe)
	EventBus.boss_fase_mudou.emit(fase_chefe)
	_soar_a_virada()
	_encenar_a_virada()


## A VIRADA, encenada.
##
## Se o jogador nao VE a maquina destravar, a mecanica inteira da luta -- dano
## que acelera -- nao chega, e ele so sente que o chefe ficou injusto de repente.
## Entao o momento e explicito: ele trava, o corpo estala, o nucleo dispara e a
## fumaca sai.
##
## A leitura narrativa: o dano REMOVE a resistencia mecanica que a corrosao
## acumulou. Ele funciona melhor porque esta sendo quebrado.
## O som da virada. Silencio se ninguem declarou som para esta fase -- a luta nao
## pode depender de audio para acontecer.
func _soar_a_virada() -> void:
	var i := fase_chefe - 1
	if i < 0 or i >= som_por_fase.size():
		return
	Audio.tocar(som_por_fase[i])


func _encenar_a_virada() -> void:
	if _visual == null:
		return
	var t := create_tween()
	# O estalo: comprime e volta. Anisotropico, como o agachamento da Cyber-Besta.
	t.tween_property(_visual, "scale", Vector2(1.18, 0.82), 0.09)
	t.tween_property(_visual, "scale", Vector2(0.92, 1.12), 0.09)
	t.tween_property(_visual, "scale", Vector2.ONE, 0.14)
	if _nucleo != null:
		# O nucleo dispara junto: e o que diz "isto e uma mudanca de estado", e
		# nao "ele levou um tiro forte".
		_t_pulso = 0.0


func _transicao(delta: float) -> void:
	Movimento.frear(self, delta, 2000.0)
	if _maquina.passou(duracao_do_estado()):
		_maquina.trocar(ESCOLHER_ATAQUE)


# ------------------------------------------------------------- os estados ---

## DORMENTE na baia. Ele nao espera: ele esta desligado.
##
## Enquanto esta aqui o nucleo fica APAGADO -- e o que faz o jogador ler o corpo
## como cenario, e nao como um inimigo parado. Um chefe que pulsa antes de
## acordar entrega o truque no primeiro quadro.
func _idle(delta: float) -> void:
	Movimento.frear(self, delta, 1200.0)
	if alvo != null and is_instance_valid(alvo):
		_maquina.trocar(DESPERTAR)


func esta_dormente() -> bool:
	return _maquina != null and _maquina.estado == IDLE


func esta_despertando() -> bool:
	return _maquina != null and _maquina.estado == DESPERTAR


## A partida que nao pega.
##
## O motor tenta, FALHA, e tenta de novo -- e a falha e a peca, nao o ruido. Uma
## maquina que liga de primeira e uma maquina nova; esta e velha, e a luta
## inteira e sobre ela destravar. O som e o mesmo `motor_falhando` da fase 1, e
## nao um sting proprio: a primeira coisa que o jogador ouve dele ja e o timbre
## que vai acompanha-lo o primeiro terco.
func _despertar_entrar() -> void:
	Audio.tocar(som_por_fase[0] if not som_por_fase.is_empty() else null)
	EventBus.pedido_shake.emit(2.0, 0.2)
	if _visual == null:
		return
	var t := create_tween()
	# Tres arranques: dois falham, o terceiro pega. O corpo estremece e volta.
	for i in 3:
		var forca := 0.06 + 0.05 * float(i)
		t.tween_property(_visual, "scale", Vector2(1.0 + forca, 1.0 - forca * 0.6), 0.10)
		t.tween_property(_visual, "scale", Vector2.ONE, 0.16)
		t.tween_interval(0.14)


func _despertar(delta: float) -> void:
	Movimento.frear(self, delta, 1800.0)
	if _maquina.passou(duracao_do_estado()):
		_maquina.trocar(ESCOLHER_ATAQUE)


## Anda para cima do jogador enquanto decide.
##
## PERSEGUIR e a diferenca inteira entre ele e a Diretora, e e onde o
## multiplicador de fase aparece primeiro: e andando que o jogador percebe que
## ele destravou, antes de qualquer ataque existir. Por isso a BOSS 01 e so isto.
func _escolher(delta: float) -> void:
	Movimento.perseguir(self, delta, 1.0, 900.0)
	if alvo == null or not is_instance_valid(alvo):
		_maquina.trocar(IDLE)
		return
	if _maquina.passou(duracao_do_estado()):
		_escolher_ataque()
		_maquina.trocar(PREPARAR)


## O repertorio DESTA fase. Ele so cresce: a Falha do Reator entra na 3 e nada
## sai, porque ataque que some faria o jogador desaprender.
func repertorio_da_fase(fase: int) -> Array[StringName]:
	var lista: Array[StringName] = REPERTORIO.duplicate()
	if fase >= 3:
		lista.append(REATOR)
	return lista


## O peso base de cada ataque, antes da distancia e da memoria.
func peso_base_de(ataque: StringName) -> float:
	match ataque:
		SOCO: return peso_soco
		RAJADA: return peso_rajada
		INVESTIDA: return peso_investida
		PISAO: return peso_pisao
		REATOR: return peso_reator
	return 1.0


## O peso de um ataque AGORA: base, mais o vies de distancia, menos a memoria.
##
## O VIES DE DISTANCIA e o que faz o chefe parecer reativo sem trapacear -- ele
## nao le a intencao do jogador, so onde ele esta. De perto sobem o soco e o
## pisao e desce a rajada; de longe sobem a investida e a rajada e desce o soco.
##
## E ele NAO VALE NA FASE 1, e isso e a licao do `PerfilJogador` aplicada aqui: a
## fase 1 existe para ENSINAR, e um chefe que ja escolhe bem no primeiro terco
## pune um habito que o jogador nao teve chance de formar. Ele parece burro
## porque precisa parecer -- selecao esperta cedo demais vira selecao cruel.
func peso_de(ataque: StringName, distancia: float, ultimo: StringName) -> float:
	var peso := peso_base_de(ataque)
	if ataque == ultimo:
		peso *= peso_da_repeticao
	if fase_chefe <= 1 or peso <= 0.0:
		return peso
	var perto := distancia <= distancia_de_perto
	match ataque:
		SOCO, PISAO:
			peso *= vies_de_distancia if perto else 1.0 / vies_de_distancia
		INVESTIDA:
			peso *= 1.0 / vies_de_distancia if perto else vies_de_distancia
		RAJADA:
			# Ela sobe LONGE e desce perto: e a unica que perde para os dois lados
			# do cerco, e e o que impede "chegue perto" de ser sempre a resposta.
			peso *= 1.0 / vies_de_distancia if perto else vies_de_distancia
	return peso


## Sorteia o proximo ataque por peso, distancia e memoria (BOSS 09).
func _escolher_ataque() -> void:
	var lista := repertorio_da_fase(fase_chefe)
	var distancia := distancia_do_alvo()
	var soma := 0.0
	var pesos: Array[float] = []
	for a in lista:
		var peso := peso_de(a, distancia, _ultimo_ataque)
		pesos.append(peso)
		soma += peso

	_indice_salva += 1
	if soma <= 0.0:
		# So acontece se alguem zerar todos os pesos no Inspetor. Cair no
		# primeiro do repertorio e melhor que um chefe que para de atacar.
		_ataque = lista[0]
	else:
		var sorteio := randf() * soma
		_ataque = lista[lista.size() - 1]
		for i in lista.size():
			sorteio -= pesos[i]
			if sorteio <= 0.0:
				_ataque = lista[i]
				break

	_ultimo_ataque = _ataque
	_golpes_restantes = _golpes_do_soco() if _ataque == SOCO else 1


## O telegrafo. Ele trava o corpo, e o corpo travado E metade do aviso.
##
## A direcao e travada AQUI e nao e mais atualizada -- vale para os quatro
## ataques, e e o que torna a investida justa. A duracao tambem e fixada aqui:
## relida todo frame, ela encolheria enquanto o jogador le o aviso.
## Quanto o estado ATUAL dura, ja em tempo real. FONTE UNICA.
##
## Quem processa o estado compara contra ISTO, e nunca contra a expressao -- a
## duracao existia inline em oito lugares, e uma animacao dirigida pelo progresso
## do estado precisa do mesmo numero. Duas copias divergiriam sem erro nenhum, e
## o sintoma seria o gesto terminando antes ou depois do golpe.
##
## **PREPARAR devolve `_aviso_atual`, e nao `tempo_real(preparo_de(...))`.** A
## diferenca nao e estilo: a duracao do telegrafo e FIXADA na entrada, para a
## barra subindo durante a leitura nao encolher o aviso ja em curso.
## Recalculando aqui, o valor devolvido seria MENOR que aquele contra o qual
## `_preparar` compara -- invisivel com a barra parada, crescendo com ela.
##
## IDLE e MORTE devolvem zero: eles nao terminam por tempo.
func duracao_do_estado() -> float:
	if _maquina == null:
		return 0.0
	match _maquina.estado:
		# CRU, sem `tempo_real`: o despertar acontece uma vez por luta e nunca
		# escalou com a fase nem com a barra. Passa-lo pelo multiplicador aqui
		# mudaria a apresentacao do chefe sem ninguem ter pedido.
		DESPERTAR:
			return tempo_despertar
		ESCOLHER_ATAQUE:
			return tempo_real(tempo_escolha)
		PREPARAR:
			return _aviso_atual
		EXECUTAR:
			return duracao_da_execucao()
		RECUPERAR:
			return tempo_real(recuperacao_de(_ataque))
		TRANSICAO_FASE:
			return tempo_real(tempo_transicao)
		ATORDOADO:
			return tempo_real(tempo_atordoado_parede if _ataque == INVESTIDA else tempo_atordoado)
	return 0.0


## A execucao varia por ataque, e nos de BEAT ela e o beat vezes a contagem --
## nao um numero proprio. E por isso que ela nao cabia inline.
func duracao_da_execucao() -> float:
	match _ataque:
		INVESTIDA:
			return tempo_real(duracao_investida)
		RAJADA, PISAO, REATOR:
			return intervalo_de_beat() * float(_beats_do_ataque())
	return tempo_real(tempo_execucao)


## Espaco entre dois beats deste ataque.
##
## O REATOR usa o intervalo do PISAO, como sempre usou: as duas ondas dele tem
## de ler como UM ataque, e nao como dois.
func intervalo_de_beat() -> float:
	return tempo_real(intervalo_rajada if _ataque == RAJADA else intervalo_pisao)


## Quanto o telegrafo DESTE ataque dura, em tempo de projeto.
##
## A Falha do Reator tem o mais longo da luta e continua tendo na fase 3: e o
## ataque mais perigoso, e a regra do projeto e que ataque capaz de tirar grande
## parte da vida precisa ser facilmente reconhecivel.
func preparo_de(ataque: StringName) -> float:
	return tempo_preparo_reator if ataque == REATOR else tempo_preparo


func recuperacao_de(ataque: StringName) -> float:
	return tempo_recuperacao_reator if ataque == REATOR else tempo_recuperacao


func _preparar_entrar() -> void:
	_aviso_atual = tempo_real(preparo_de(_ataque))
	_beats = 0
	var d := direcao_para_alvo()
	if d.length_squared() > 0.01:
		_direcao_travada = d
	match _ataque:
		SOCO:
			_semear_aviso_do_soco()
		REATOR:
			_semear_cerco_do_reator()


func _preparar(delta: float) -> void:
	Movimento.frear(self, delta, 2400.0)
	if _maquina.passou(duracao_do_estado()):
		_maquina.trocar(EXECUTAR)


func _executar_entrar() -> void:
	_beats = 0
	match _ataque:
		SOCO:
			_bater()
		RAJADA, PISAO:
			_disparar_beat()
		REATOR:
			_estourar_o_reator()
		INVESTIDA:
			EventBus.pedido_shake.emit(4.0, 0.18)


## A execucao de cada ataque. Os beats -- rajadas de uma salva, aneis de um
## pisao -- saem daqui, e o tempo entre eles tambem passa por `tempo_real()`:
## na fase 3 a mesma sequencia acontece comprimida, que e a frase inteira do
## chefe.
func _executar(delta: float) -> void:
	match _ataque:
		INVESTIDA:
			Movimento.investir(self, _direcao_travada, velocidade_investida)
			if _maquina.passou(duracao_do_estado()):
				_fim_da_investida()
			return
		RAJADA, PISAO, REATOR:
			Movimento.frear(self, delta, 1800.0)
			var intervalo := intervalo_de_beat()
			if _beats < _beats_do_ataque() and _maquina.passou(intervalo * float(_beats)):
				_disparar_beat()
			if _maquina.passou(duracao_do_estado()):
				_maquina.trocar(RECUPERAR)
			return
		_:
			Movimento.frear(self, delta, 1800.0)

	if not _maquina.passou(duracao_do_estado()):
		return
	# O soco da fase 3 sao DOIS golpes, e cada um volta a PREPARAR: a issue pede
	# telegrafo por golpe, e repetir dentro de EXECUTAR daria o segundo de graca.
	_golpes_restantes -= 1
	if _ataque == SOCO and _golpes_restantes > 0:
		_maquina.trocar(PREPARAR)
		return
	_maquina.trocar(RECUPERAR)


## A janela de punicao. Ela encolhe com a fase junto com todo o resto -- e por
## isso a fase 3 e mais perigosa sem um numero de dano ter mudado.
func _recuperar(delta: float) -> void:
	Movimento.frear(self, delta, 900.0)
	if _maquina.passou(duracao_do_estado()):
		_maquina.trocar(ESCOLHER_ATAQUE)


# -------------------------------------------------------- SOCO HIDRAULICO ---

## O aviso do soco e uma `AreaDePerigo` no chao, com o tempo do telegrafo.
##
## Ela e reusada em vez de um circulo proprio, e a economia nao e de linhas: a
## `AreaDePerigo` ja carrega as tres armadilhas registradas deste ataque
## resolvidas. Ela nao estoura no `_ready` (o estouro sai de `configurar()`, e e
## sincrono); ela varre com `intersect_shape` no espaco direto em vez de
## `get_overlapping_bodies()`, que responderia com o passo de fisica anterior e
## voltaria vazia; e o aviso dela desenha na faixa do mundo pelo `Telegrafo`.
## Escrever um circulo proprio aqui seria reencenar os tres bugs.
##
## Ela nasce no container da SALA e nao como filha dele: filha, ela andaria com o
## chefe -- e aviso no chao que se move e aviso que mente.
func _semear_aviso_do_soco() -> void:
	var container := get_parent()
	if container == null:
		return
	var area: AreaDePerigo = CENA_AREA.instantiate()
	area.tempo_aviso = _aviso_atual
	area.tempo_dano = tempo_real(tempo_execucao)
	area.cor = cor_base
	container.add_child(area)
	area.configurar(_ponto_do_soco(), raio_soco, dano_contato)
	_areas.append(area)


## Onde o punho cai. Na fase 3 o segundo golpe sai deslocado para o outro lado,
## que e o que faz o par ser "esquerdo e direito".
func _ponto_do_soco() -> Vector2:
	var frente := global_position + _direcao_travada * alcance_soco
	if _golpes_restantes >= 2:
		return frente + _direcao_travada.orthogonal() * desvio_do_segundo_golpe
	if _ataque == SOCO and _golpes_do_soco() >= 2:
		return frente - _direcao_travada.orthogonal() * desvio_do_segundo_golpe
	return frente


## A onda de choque. Quem cobra o dano do IMPACTO e a area semeada no telegrafo;
## isto aqui e o que sai dele para a frente.
func _bater() -> void:
	EventBus.pedido_shake.emit(7.0, 0.25)
	var direcoes := Balistica.leque(_direcao_travada, _ondas_do_soco(), abertura_onda)
	_arma_onda.atirar_varias(direcoes)


## Uma onda na fase 1, tres a partir da 2. Ele nao vira outro ataque: vira uma
## versao mais eficiente do mesmo.
func _ondas_do_soco() -> int:
	return 1 if fase_chefe <= 1 else 3


## Dois golpes na fase 3, um antes.
func _golpes_do_soco() -> int:
	return 2 if fase_chefe >= 3 else 1


# ------------------------------------------- RAJADA DE SUCATA e PISAO -------

## Quantos beats esta salva tem: rajadas de sucata, ou aneis de pisao.
func _beats_do_ataque() -> int:
	match _ataque:
		RAJADA:
			return mini(fase_chefe, 3)
		PISAO:
			return 2 if fase_chefe >= 3 else 1
		REATOR:
			# Duas ondas: a segunda cai nos vaos da primeira, como o pisao.
			return 2
	return 1


## Um beat da salva, ja girado pela alternancia deterministica.
##
## `atirar_varias` e obrigatorio e nao preferencia: um `for` com `atirar()`
## sairia com UM projetil, porque `_t_cadencia` e setado no primeiro tiro e
## `pode_atirar()` recusa o resto -- o `_process` que decrementa nao roda no meio
## do laco. Foi este mesmo defeito que fez o anel da Diretora sair com um
## projetil.
func _disparar_beat() -> void:
	var giro := deg_to_rad(_giro_do_beat())
	if _ataque == REATOR:
		_arma_sucata.atirar_varias(Balistica.anel(projeteis_do_reator, giro))
	elif _ataque == PISAO:
		_arma_sucata.atirar_varias(Balistica.anel(projeteis_pisao, giro))
	else:
		_arma_sucata.atirar_varias(
			Balistica.leque(_direcao_travada.rotated(giro), projeteis_rajada, abertura_rajada)
		)
	EventBus.pedido_shake.emit(3.0, 0.12)
	_beats += 1


## De quantos graus este beat sai girado.
##
## A conta e a mesma -- meio vao --, mas o VAO nao: o anel do pisao divide 360
## pela contagem, e o leque da rajada divide a ABERTURA por `contagem - 1`. Usar
## o passo do anel no leque gira demais, e a segunda rajada cai EM CIMA da
## primeira em vez de nos vaos dela. Foi o defeito da primeira versao disto, e o
## unico sintoma era o padrao nao aparecer.
func _giro_do_beat() -> float:
	var indice := _indice_salva + _beats
	if _ataque == REATOR:
		return Balistica.alternancia(projeteis_do_reator, indice)
	if _ataque == PISAO:
		return Balistica.alternancia(projeteis_pisao, indice)
	return Balistica.alternancia_de_passo(
		Balistica.passo_do_leque(projeteis_rajada, abertura_rajada), indice
	)


# --------------------------------------------------- FALHA DO REATOR -------

## O cerco: um anel de areas em volta dele, com VAOS entre elas.
##
## Os vaos sao as aberturas do ataque, e sao a diferenca entre "esquive" e "tome
## dano". A trava vale para todo ataque de area de qualquer chefe deste jogo, e a
## Diretora ja a carrega em `aberturas_de()` -- aqui o metodo e o mesmo.
##
## As areas sao `AreaDePerigo` e nao um circulo proprio pelo mesmo motivo do
## soco: ela ja nasce no container da SALA e nao como filha de quem semeou (filha
## dele, ela andaria junto -- e aviso no chao que se move e aviso que mente), ja
## varre com `intersect_shape`, e ja avisa na faixa do mundo.
func _semear_cerco_do_reator() -> void:
	var container := get_parent()
	if container == null:
		return
	for i in maxi(areas_do_reator, 1):
		var direcao := Vector2.RIGHT.rotated(TAU * float(i) / float(maxi(areas_do_reator, 1)))
		_semear_area(container, global_position + direcao * raio_do_cerco, raio_da_area_do_reator)
	# O estouro central cobre o MIOLO do cerco: colar nele deixa de ser abrigo, e
	# as saidas passam a ser os vaos e o lado de fora. Sem ele, o lugar mais
	# seguro da sala seria encostado no chefe, que e o oposto do que o ataque diz.
	_semear_area(container, global_position, raio_do_estouro)


func _semear_area(container: Node, onde: Vector2, raio: float) -> void:
	var area: AreaDePerigo = CENA_AREA.instantiate()
	area.tempo_aviso = _aviso_atual
	area.tempo_dano = tempo_real(tempo_execucao)
	area.cor = cor_base
	container.add_child(area)
	area.configurar(onde, raio, dano_contato)
	_areas.append(area)


## O estouro, e as ondas que saem dele.
func _estourar_o_reator() -> void:
	EventBus.pedido_shake.emit(12.0, 0.5)
	_disparar_beat()


## Quantas aberturas este ataque deixa. Mesma API da Diretora, e pelo mesmo
## motivo: dano inevitavel COM telegrafo e pior que sem, porque ler a intencao e
## nao poder agir sobre ela e a definicao de mentir sobre a propria regra.
##
## Devolve -1 para ataque que nao e de area: disparo nao fecha espaco, e cobrar
## abertura dele seria cobrar o numero errado.
func aberturas_de(ataque: StringName) -> int:
	match ataque:
		REATOR:
			# Um vao entre cada par de areas vizinhas do cerco.
			return maxi(areas_do_reator, 1)
		SOCO:
			# O punho cai num ponto: a sala inteira menos aquele circulo.
			return 1
		PISAO:
			return projeteis_pisao
	return -1


## O vao LINEAR entre duas areas vizinhas do cerco, em px.
##
## E o numero que diz se a abertura cabe o jogador. Medido e nao estimado: com o
## raio do cerco e a contagem no Inspetor, alguem pode fechar o cerco sem
## perceber, e o sintoma seria um ataque que nao da para esquivar.
func vao_do_cerco() -> float:
	var passo := TAU / float(maxi(areas_do_reator, 1))
	var corda := 2.0 * raio_do_cerco * sin(passo * 0.5)
	return corda - raio_da_area_do_reator * 2.0


# ------------------------------------------------------- INVESTIDA PESADA ---

## Fim de uma investida: encadeia outra, ou recupera.
##
## A fase 3 encadeia ate tres e SO ENTAO recupera, e a recuperacao dela e a
## melhor janela de dano da luta -- e o pagamento por um ataque que atravessa a
## sala. Entre uma investida e a seguinte ele volta a PREPARAR, entao a direcao e
## RECALCULADA e telegrafada de novo: sem isso a segunda sairia sem aviso.
func _fim_da_investida() -> void:
	_beats += 1
	if _beats < _investidas_da_fase():
		_maquina.trocar(PREPARAR)
		return
	_maquina.trocar(RECUPERAR)


func _investidas_da_fase() -> int:
	return clampi(fase_chefe, 1, 3)


## Bater na parede e a janela de contra-ataque. Ela e mais longa que o
## atordoamento comum de proposito: errar a investida tem de RENDER ao jogador,
## senao acertar a esquiva nao vale nada e a investida vira pressao pura.
func _atordoado_entrar() -> void:
	velocity = Vector2.ZERO
	EventBus.pedido_shake.emit(6.0, 0.3)


func _atordoado(delta: float) -> void:
	Movimento.frear(self, delta, 3000.0)
	if _maquina.passou(duracao_do_estado()):
		_maquina.trocar(ESCOLHER_ATAQUE)


func _morte(delta: float) -> void:
	Movimento.frear(self, delta, 4000.0)


## A vitoria da run NAO sai daqui, e isso e deliberado.
##
## Quem chama `GameState.terminar_run(true)` e o `GerenciadorMapa`, quando a
## sala do tipo `boss` fica LIMPA -- e a sala fica limpa pela morte de quem ela
## colocou. Trocar o chefe do andar (BOSS 11) nao mexe nesse caminho, e e bom que
## seja assim: a chamada ja se perdeu uma vez neste projeto ao trocar quem
## hospeda a run, e o sintoma foi silencioso.
func morrer() -> void:
	if morto:
		return
	# Aviso no chao tem de morrer com quem o pediu: um circulo que sobrevive ao
	# chefe cobra dano depois de a luta ter acabado, e o jogador nao tem como
	# atribuir aquilo a nada. Mesma licao do Parasita e da Diretora.
	for a in _areas:
		if is_instance_valid(a):
			a.queue_free()
	_areas.clear()
	if _maquina != null:
		_maquina.trocar(MORTE)
	EventBus.pedido_shake.emit(10.0, 0.6)
	EventBus.boss_morreu.emit()
	super.morrer()
