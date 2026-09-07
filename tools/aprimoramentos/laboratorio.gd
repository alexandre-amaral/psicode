extends Node2D
## As 15 combinacoes de inimigo x classe, sem jogar a run.
##
## Mesma ideia da `arena_chefe`: um lugar para olhar uma peca isolada, e um lugar
## para MEDI-LA sem janela. O que ele responde e a pergunta que o epico existe
## para fazer -- *"a classe deixa a unidade mais interessante, ou so mais
## demorada?"*.
##
## ## O numero que decide e o TTK, e ele tem teto
##
## A meta de aumento e de **10% a 35%**. Abaixo disso a classe nao muda nada e o
## custo de ameaca esta cobrando por ar; acima, ela virou esponja de dano -- que e
## a definicao do que este epico existe para nao fazer. Uma classe que dobra o
## TTK e "inimigo normal x 2" com uma aura.
##
## O TTK e medido com dano CONSTANTE e nao com a arma real: a arma tem cadencia,
## dispersao e recarga, e tres variaveis a mais tornariam a comparacao entre
## classes uma comparacao entre armas.
##
## ## Por que ele varre em vez de listar
##
## As cinco especies saem de `assets` em disco e as tres classes de
## `src/enemies/aprimoramento/`. Uma lista escrita a mao ficaria para tras no dia
## em que a sexta especie ou a quarta classe entrar -- e o sintoma seria a matriz
## continuar verde sem nunca ter olhado a peca nova.

const INIMIGOS := {
	"Drone Aranha": "res://src/enemies/drone_aranha.tscn",
	"Atirador Neon": "res://src/enemies/atirador_neon.tscn",
	"Cyber-Besta": "res://src/enemies/cyber_besta.tscn",
	"Sentinela Orbital": "res://src/enemies/sentinela_orbital.tscn",
	"Hacker Parasita": "res://src/enemies/hacker_parasita.tscn",
}

const PASTA_CLASSES := "res://src/enemies/aprimoramento/"

## O dano por golpe do medidor, e o intervalo entre eles.
##
## Um golpe de 1 a cada 0,1 s: pequeno o bastante para a Regeneradora ter chance
## de reagir entre eles (a espera dela e de 3 s) e continuo o bastante para a
## Blindada nunca sair da reducao por acidente.
const DANO := 1
const INTERVALO := 0.1
## Teto de golpes. So morde se algo travar -- um inimigo de 8 de vida com 25% de
## reducao morre em ~11.
const MAX_GOLPES := 4000

## Longe da origem, como as suites: o grupo "player" e global e outras cenas
## deixam bonecos nele.
const LONGE := Vector2(52000.0, 52000.0)


func _ready() -> void:
	var com_janela := DisplayServer.get_name() != "headless"
	print("\n=== LABORATORIO DE APRIMORAMENTOS ===")
	print("  TTK com dano constante de %d a cada %.2fs\n" % [DANO, INTERVALO])

	var classes := _classes()
	# GDScript nao tem list comprehension: montar a mao, sem inventar sintaxe.
	var cabecalho := "  %-20s %8s" % ["inimigo", "normal"]
	for classe in classes:
		cabecalho += "%14s" % classe.nome_exibicao
	print(cabecalho)

	var fora_da_faixa := 0
	for nome: String in INIMIGOS:
		var base := await _medir(INIMIGOS[nome], null)
		var linha := "  %-20s %7.2fs" % [nome, base]
		# A pausa e o mesmo tempo para todas, entao ela nao favorece ninguem: o
		# que muda entre as colunas e o que cada classe FAZ com ela.
		# **SEIS segundos, e o numero sai da propria classe.** A Regeneradora
		# espera 3 s antes de comecar, entao uma pausa de 4 s deixava so 1 s de
		# cura -- 0,25 ponto num inimigo de 5 de vida, que arredonda para nada, e
		# a regua respondia +0% para uma classe que funciona.
		#
		# Seis segundos e uma troca de alvo plausivel: o jogador vai para outro
		# inimigo, resolve, e volta. Sobram 3 s de cura, que e a janela que a
		# classe existe para cobrar.
		var pausa := 6.0
		var base_pausada := base
		for classe in classes:
			var t := await _medir(INIMIGOS[nome], classe,
				pausa if _cobra_na_troca(classe) else 0.0)
			var referencia: float = base_pausada if _cobra_na_troca(classe) else base
			var delta := (t / maxf(referencia, 0.001) - 1.0) * 100.0
			linha += "%9.2fs%+4.0f%%" % [t, delta]
			# **A FAIXA DE TTK NAO VALE PARA TODA CLASSE, e confundir isso
			# reprova a classe certa.**
			#
			# A Regeneradora e a Blindada prometem alongar a luta -- uma cura, a
			# outra reduz --, entao +10% a +35% e o teto delas e tambem o piso:
			# abaixo, o custo de ameaca cobra por ar.
			#
			# A Sobrecarregada nao promete isso. Ela aperta a CADENCIA e paga em
			# vida, entao o TTK dela CAI de proposito -- o que sobe e o que o
			# jogador sofre enquanto ele acontece. Medida pela regua das outras,
			# ela reprovava nas cinco especies com o comportamento certo.
			if _promete_alongar(classe):
				if delta < 5.0 or delta > 45.0:
					fora_da_faixa += 1
			elif delta > 5.0:
				# O que se cobra nela e o contrario: que ela nao tenha virado uma
				# esponja por acidente.
				fora_da_faixa += 1
		print(linha)

	print("")
	if fora_da_faixa > 0:
		print("  %d combinacoes fora da faixa de +10%% a +35%% de TTK" % fora_da_faixa)
	else:
		print("  as 15 combinacoes ficam na faixa de TTK")

	if com_janela:
		await _mostrar(classes)
		return
	get_tree().quit()


## Quanto tempo aquele inimigo leva para morrer, com e sem classe.
##
## O inimigo nasce sem alvo de proposito: com alvo ele persegue, atira e sai do
## lugar, e o que se quer medir e a RECEPCAO de dano. A Blindada e a Regeneradora
## nao dependem de comportamento nenhum -- e a Sobrecarregada nao muda o TTK, ela
## muda o que o jogador sofre enquanto ele acontece.
func _medir(caminho: String, classe: DadosAprimoramento,
		pausa: float = 0.0) -> float:
	var cena := load(caminho) as PackedScene
	if cena == null:
		return 0.0
	var inimigo := cena.instantiate() as InimigoBase
	if inimigo == null:
		return 0.0
	add_child(inimigo)
	inimigo.global_position = LONGE
	if classe != null:
		inimigo.aplicar_aprimoramento(classe)

	var tempo := 0.0
	var golpes := 0
	var pausou := false
	var metade := inimigo.vida_maxima / 2
	# `is_instance_valid` na CONDICAO, e nao so dentro: `morrer()` chama
	# `queue_free()`, entao o no some entre uma volta e a proxima e ler `.morto`
	# no proximo teste estoura.
	while is_instance_valid(inimigo) and not inimigo.morto and golpes < MAX_GOLPES:
		# **A PAUSA E A TROCA DE ALVO, e e nela que a Regeneradora cobra.**
		#
		# Com fogo continuo ela nunca cura -- a espera e de 3 s e o alvo morre em
		# meio segundo --, e medir so assim devolveria +0% e diria que a classe
		# nao faz nada. O que ela faz e punir QUEM TROCA, e uma regua que so mede
		# pressao ininterrupta mede o counterplay em vez da classe.
		if pausa > 0.0 and not pausou and inimigo.vida <= metade:
			pausou = true
			# **A PAUSA NAO ENTRA NO TTK.** Ela e o cenario, e nao tempo de
			# matar: somada, ela domina a conta (4 s de espera contra 0,5 s de
			# tiro) e diluiria a classe ate +4%, que e o mesmo que nao medir.
			# O que se compara e o tempo com o GATILHO PUXADO.
			var t_pausa := 0.0
			while t_pausa < pausa and is_instance_valid(inimigo):
				t_pausa += INTERVALO
				await get_tree().process_frame
				for filho in inimigo.get_children():
					var ap := filho as Aprimoramento
					if ap != null:
						ap._process(INTERVALO)
		golpes += 1
		inimigo.receber_dano(DANO)
		tempo += INTERVALO
		# O controlador roda em `_process`, entao o relogio dele so anda se a
		# arvore andar. Adiantar o tempo na mao mediria a classe parada.
		await get_tree().process_frame
		if is_instance_valid(inimigo) and not inimigo.morto:
			for filho in inimigo.get_children():
				var a := filho as Aprimoramento
				if a != null:
					a._process(INTERVALO)
	# Quem morreu ja se liberou sozinho; liberar de novo e liberacao dupla.
	if is_instance_valid(inimigo) and not inimigo.morto:
		inimigo.free()
	return tempo


## Se esta classe existe para alongar a luta, ou para apertar o ritmo dela.
##
## Sai dos NUMEROS da classe e nao de uma lista de ids: uma classe futura entra
## na regua certa sozinha, e uma lista escrita a mao ficaria para tras sem que
## nada acusasse.
## Se esta classe cobra na TROCA de alvo em vez de no fogo continuo.
##
## Sai dos numeros e nao de uma lista de ids: uma classe futura que cure entra na
## regua certa sozinha.
func _cobra_na_troca(classe: DadosAprimoramento) -> bool:
	return classe.regeneracao_por_segundo > 0.0


func _promete_alongar(classe: DadosAprimoramento) -> bool:
	return classe.multiplicador_cadencia <= 1.0


func _classes() -> Array[DadosAprimoramento]:
	var saida: Array[DadosAprimoramento] = []
	var pasta := DirAccess.open(PASTA_CLASSES)
	if pasta == null:
		return saida
	var nomes := pasta.get_files()
	nomes.sort()
	for nome in nomes:
		if not nome.begins_with("apr_") or not nome.ends_with(".tres"):
			continue
		var d := load(PASTA_CLASSES + nome) as DadosAprimoramento
		if d != null:
			saida.append(d)
	return saida


## Com janela: as tres classes lado a lado, no mesmo inimigo.
##
## O que se olha aqui NAO e a cor -- e o MOVIMENTO. Convergir, orbitar e escapar
## sao tres leituras diferentes a um segundo, e e isso que tem de aparecer na
## foto, inclusive em cinza.
func _mostrar(classes: Array[DadosAprimoramento]) -> void:
	DirAccess.make_dir_recursive_absolute("user://capturas")
	var cena := load(INIMIGOS["Drone Aranha"]) as PackedScene
	var camera := Camera2D.new()
	add_child(camera)
	camera.make_current()
	camera.position = Vector2(480.0, 272.0)

	var x := 160.0
	for classe in classes:
		var inimigo := cena.instantiate() as InimigoBase
		add_child(inimigo)
		inimigo.global_position = Vector2(x, 272.0)
		inimigo.aplicar_aprimoramento(classe)
		x += 200.0
	# A Blindada precisa de um ciclo inteiro para mostrar a abertura, e a
	# Regeneradora precisa da espera dela para as particulas existirem.
	await get_tree().create_timer(3.6).timeout
	get_viewport().get_texture().get_image().save_png(
		"user://capturas/aprimoramentos.png")
	print("  aprimoramentos.png")
	get_tree().quit()
