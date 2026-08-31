extends TesteBase
## OS NUMEROS DE INIMIGO EM RESOURCE (INIM 08).
##
## Tres coisas se cobram aqui, e a primeira e a que faz esta suite valer o
## arquivo: a migracao nao pode ter mudado um numero.
##
## Mover valor de `.tscn` para `.tres` e transcricao a mao, e transcricao a mao
## erra. Um `velocidade = 78` que virasse `87` deixaria o Drone Aranha 12% mais
## rapido para sempre, sem uma linha no console e sem ninguem conseguir apontar
## quando comecou. Por isso os numeros de ANTES da migracao estao escritos aqui
## dentro: eles sao a foto do balanceamento no dia em que ele saiu da cena.
##
## A segunda e a ORDEM DE LEITURA. `InimigoBase._ready()` congela
## `vida = vida_maxima` na linha seguinte a `_aplicar_dados()`. Invertidas, todo
## inimigo com `.tres` nasceria com a vida do default do script -- e o Player ja
## pagou por essa licao com `_vida_maxima_base`.
##
## A terceira e o motivo numero um da issue: DUAS VARIANTES do mesmo inimigo sem
## duplicar a cena. Cena e onde o merge doi, e a convencao do projeto e uma
## pessoa por `.tscn` por vez.

const CENAS := {
	"drone_aranha": "res://src/enemies/drone_aranha.tscn",
	"atirador_neon": "res://src/enemies/atirador_neon.tscn",
	"cyber_besta": "res://src/enemies/cyber_besta.tscn",
	"sentinela_orbital": "res://src/enemies/sentinela_orbital.tscn",
	"hacker_parasita": "res://src/enemies/hacker_parasita.tscn",
}

## A FOTO do balanceamento, medida no `.tscn` antes de a migracao acontecer.
## Campo -> valor, por inimigo. Mudar um numero aqui e uma decisao de tuning e
## tem de ser deliberada; mudar sem querer e o que esta suite existe para pegar.
const ANTES := {
	"drone_aranha": {
		"vida_maxima": 5, "velocidade_base": 78.0, "dano_contato": 1, "creditos": 6,
		"raio_contato": 30.0,
		"tempo_carga": 0.45, "tempo_recuperacao": 0.5, "intervalo": 3.4,
		"alcance_anel": 260.0, "projeteis": 8,
		"distancia_de_posicionamento": 300.0, "distancia_de_recuo": 180.0,
		"peso_lateral": 0.85,
	},
	"atirador_neon": {
		"vida_maxima": 5, "velocidade_base": 104.0, "dano_contato": 1, "creditos": 6,
		"raio_contato": 26.0,
		"distancia_ideal": 300.0, "margem": 50.0, "distancia_de_esquiva": 120.0,
		"intervalo": 2.6, "tempo_mira": 1.0, "tempo_cooldown": 0.6,
		"tempo_esquiva": 0.4, "impulso_esquiva": 1.9,
	},
	"cyber_besta": {
		"vida_maxima": 8, "velocidade_base": 88.0, "dano_contato": 2, "creditos": 12,
		"raio_contato": 34.0, "intervalo_dano_contato": 0.9,
		"tempo_observando": 1.6, "tempo_preparo": 0.5, "tempo_encarando": 0.3,
		"velocidade_investida": 720.0, "duracao_investida": 0.42,
		"tempo_recuperacao": 1.1, "tempo_atordoado": 1.0, "alcance": 420.0,
	},
	"sentinela_orbital": {
		"vida_maxima": 6, "velocidade_base": 132.0, "dano_contato": 1, "creditos": 7,
		"raio_contato": 28.0,
		"raio_orbita": 190.0, "margem": 30.0, "correcao_radial": 0.55,
		"intervalo": 1.5, "tempo_clarao": 0.28,
		"tiros_ate_rajada": 3, "projeteis_rajada": 3, "abertura_rajada": 24.0,
		"fator_aviso_rajada": 1.6,
	},
	"hacker_parasita": {
		"vida_maxima": 6, "velocidade_base": 110.0, "dano_contato": 1, "creditos": 10,
		"raio_contato": 26.0,
		"max_areas": 1, "intervalo": 2.4, "tempo_semear": 0.55,
		"espalhamento": 96.0, "raio_area": 60.0, "tempo_residual": 1.5,
		"distancia_minima": 240.0,
	},
}

## Numeros de balanceamento que nao podem ter sobrado na cena.
const FORA_DA_CENA := [
	"vida_maxima", "velocidade_base", "dano_contato", "creditos",
	"raio_contato", "intervalo_dano_contato",
]

## Longe da origem, como as outras suites que instanciam inimigo.
const LONGE := Vector2(51000.0, 51000.0)


func nome() -> String:
	return "DadosInimigo"


func executar() -> void:
	_os_cinco_leem_de_tres()
	_a_migracao_nao_mudou_um_numero()
	_o_recurso_e_aplicado_antes_do_congelamento()
	_nenhum_numero_de_balanceamento_sobrou_na_cena()
	_duas_variantes_sem_duplicar_a_cena()
	_quem_nao_tem_recurso_continua_funcionando()


## Criterio de aceite: os cinco leem de `.tres`.
func _os_cinco_leem_de_tres() -> void:
	for id in CENAS:
		var inimigo := _nascer(id)
		var d: DadosInimigo = inimigo.dados
		ok(d != null, "%s carrega um DadosInimigo" % id)
		if d != null:
			ok(not d.nome.is_empty(), "e o recurso dele se identifica (\"%s\")" % d.nome)
		inimigo.free()


## A FOTO. Nenhum numero mudou de valor ao mudar de arquivo.
##
## Le o campo pelo nome no no ja pronto: e o valor que o jogo de fato vai usar,
## depois de `_aplicar_dados()` e de `_ler_dados()` -- e nao o que o `.tres`
## diz, que provaria so que o `.tres` e igual a si mesmo.
func _a_migracao_nao_mudou_um_numero() -> void:
	for id in CENAS:
		var inimigo := _nascer(id)
		var esperado: Dictionary = ANTES[id]
		for campo in esperado:
			var obtido: Variant = inimigo.get(campo)
			var alvo: Variant = esperado[campo]
			if obtido is float or alvo is float:
				perto(float(obtido), float(alvo),
					"%s.%s continua o que era antes do .tres" % [id, campo], 0.0001)
			else:
				igual(obtido, alvo, "%s.%s continua o que era antes do .tres" % [id, campo])
		inimigo.free()


## A ORDEM. O recurso e aplicado ANTES de `vida = vida_maxima`.
##
## Invertidas as duas linhas, todo inimigo com `.tres` nasceria com a vida do
## DEFAULT do script -- 5 para todo mundo -- e a Cyber-Besta, que tem 8, viraria
## de vidro sem uma linha no console. E o mesmo padrao do Player, cujo
## `_vida_maxima_base` congela no topo do `_ready` pela mesma razao.
func _o_recurso_e_aplicado_antes_do_congelamento() -> void:
	var besta := _nascer("cyber_besta")
	igual(besta.vida, 8, "a Cyber-Besta nasce com a vida do recurso, e nao com o default 5")
	igual(besta.vida, besta.vida_maxima, "e a vida cheia bate com o maximo dela")
	besta.free()

	# O caso que separa "ordem certa" de "sorte": um recurso com vida diferente
	# da cena E do default tem de aparecer na vida inicial.
	var d := DadosInimigo.new()
	d.vida = 33
	d.velocidade = 55.0
	var cobaia := _nascer("drone_aranha", d)
	igual(cobaia.vida, 33, "vida inicial vem do recurso, nao do default nem da cena")
	perto(cobaia.velocidade_base, 55.0, "e a velocidade tambem")
	cobaia.free()


## Criterio de aceite: nenhum numero de balanceamento sobrou so no `.tscn`.
##
## Le o FONTE da cena. E a unica forma de cobrar isto: um valor esquecido no
## `.tscn` seria simplesmente SOBRESCRITO pelo recurso em runtime, entao nenhum
## teste de comportamento acusaria nada -- e o proximo a girar aquele botao na
## cena passaria uma tarde sem entender por que nao muda nada.
func _nenhum_numero_de_balanceamento_sobrou_na_cena() -> void:
	for id in CENAS:
		var fonte := FileAccess.get_file_as_string(CENAS[id])
		if fonte.is_empty():
			ok(false, "%s.tscn foi lido" % id)
			continue
		ok(fonte.contains("dados = ExtResource"), "%s.tscn aponta para o recurso" % id)
		for campo: String in FORA_DA_CENA:
			ok(
				not fonte.contains("\n%s = " % campo),
				"%s.tscn nao guarda mais `%s` -- o botao esta no .tres" % [id, campo]
			)


## O MOTIVO NUMERO UM da issue: duas variantes do mesmo inimigo, sem duplicar a
## cena.
##
## Cena e onde o merge doi -- a convencao e uma pessoa por `.tscn` por vez --,
## entao "um Drone de elite" nao pode custar uma copia do `.tscn` inteiro. Com o
## recurso, custa um arquivo de vinte linhas legiveis num diff.
func _duas_variantes_sem_duplicar_a_cena() -> void:
	var elite := DadosInimigo.new()
	elite.nome = "Drone Aranha de Elite"
	elite.vida = 12
	elite.velocidade = 140.0
	elite.projeteis = 16
	elite.cooldown_ataque = 1.8

	var comum := _nascer("drone_aranha")
	var forte := _nascer("drone_aranha", elite)

	ok(forte.vida_maxima > comum.vida_maxima,
		"a variante tem mais vida (%d contra %d), da MESMA cena"
			% [forte.vida_maxima, comum.vida_maxima])
	ok(forte.projeteis > comum.projeteis,
		"e abre um anel maior (%d contra %d)" % [forte.projeteis, comum.projeteis])
	ok(forte.velocidade_base > comum.velocidade_base, "e anda mais rapido")
	igual(forte.scene_file_path, comum.scene_file_path,
		"e as duas saem do mesmo arquivo de cena -- que e o ponto")

	comum.free()
	forte.free()


## Quem NAO tem recurso continua funcionando, com os numeros da cena.
##
## O campo e opcional de proposito: o Rastejante e o Vigia sao a base que o
## playtest da v0.2.0-alpha validou, e a Diretora e as pecas da arena dela sao
## outro assunto. Migra-los junto seria mexer neles sem motivo, e um `dados`
## obrigatorio faria o jogo quebrar em quem ainda nao migrou.
func _quem_nao_tem_recurso_continua_funcionando() -> void:
	var vigia := preload("res://src/enemies/vigia.tscn").instantiate()
	vigia.position = LONGE
	Engine.get_main_loop().root.add_child(vigia)
	ok(vigia.dados == null, "o Vigia continua sem recurso")
	igual(vigia.vida_maxima, 6, "e os numeros da cena dele continuam valendo (vida 6)")
	igual(vigia.vida, 6, "e ele nasce com a vida cheia mesmo assim")
	vigia.free()


func _nascer(id: String, recurso: DadosInimigo = null) -> Node:
	var cena: PackedScene = load(CENAS[id])
	var no := cena.instantiate()
	# ANTES do add_child: o `_ready` e quem le o recurso, e ele roda na entrada
	# da arvore. Depois, o inimigo ja nasceu com os numeros antigos.
	if recurso != null:
		no.dados = recurso
	no.position = LONGE
	Engine.get_main_loop().root.add_child(no)
	return no
