extends Node
## Regua de armas: DPS teorico, DPS sustentado e tempo para matar cada inimigo.
##
## Existe porque dez armas com mecanica propria nao se comparam lendo `.tres`.
## O dano de uma esta em `dano`, o de outra em `dano_explosao`, o de outra em
## `dano_por_segundo`, e a Riot-12 ainda sorteia quantos projeteis saem. Ler os
## campos lado a lado responde "qual numero e maior"; o que a sessao de tuning
## precisa saber e "quantos segundos leva para matar um Vigia".
##
## Tres colunas, e as tres importam:
##
## - **DPS de pico** ignora recarga. E o que o jogador sente na rajada.
## - **DPS sustentado** inclui o tempo de recarga diluido no pente inteiro. E o
##   que decide uma sala longa, e e onde armas de pente pequeno se pagam ou nao.
## - **Tempo de morte** converte o DPS na unica pergunta que o jogador faz de
##   verdade, contra a vida REAL lida de cada cena de inimigo.
##
## O que ele NAO mede, e e honesto dizer: alcance util, dificuldade de acertar,
## e o valor de empurrar ou de atravessar parede. A Gravity Gun vai aparecer no
## fim da lista de DPS porque o dano dela nao esta no dano -- isso e desenho, nao
## defeito. Numero de DPS nao substitui jogar; ele so impede que uma arma esteja
## dez vezes fora da faixa sem ninguem notar.
##
## Nao entra no runner e nao roda no CI: e regua de tuning, nao teste. Teste
## falha quando o codigo quebra; isto muda de resposta toda vez que alguem edita
## um `.tres`, e e exatamente para isso que serve.
##
## Use:  godot --headless --path . tools/medir_armas.tscn

## So as armas que o JOGADOR pode ter na mao. Tiro de inimigo entra pelo
## `grupo_*.tres` e se compara com outro criterio.
const ARMAS := [
	"res://src/weapons/pistola.tres",
	"res://src/weapons/pistola_cipher.tres",
	"res://src/weapons/smg_mantis.tres",
	"res://src/weapons/shotgun.tres",
	"res://src/weapons/rail_x.tres",
	"res://src/weapons/phase_blaster.tres",
	"res://src/weapons/gravity_gun.tres",
	"res://src/weapons/boomer.tres",
	"res://src/weapons/plasma_arc.tres",
	"res://src/weapons/swarm.tres",
	"res://src/weapons/volt_caster.tres",
	"res://src/weapons/nanite_rifle.tres",
	"res://src/weapons/laser_cutter.tres",
]

const INIMIGOS := [
	"res://src/enemies/rastejante.tscn",
	"res://src/enemies/vigia.tscn",
	"res://src/enemies/drone_aranha.tscn",
	"res://src/enemies/atirador_neon.tscn",
	"res://src/enemies/sentinela_orbital.tscn",
	"res://src/enemies/cyber_besta.tscn",
	"res://src/enemies/hacker_parasita.tscn",
	"res://src/enemies/diretora.tscn",
]

## Quantas rajadas a media de uma arma com contagem variavel usa. A Riot-12
## sorteia de 8 a 10 por tiro; uma amostra so mentiria por ate 25%.
const AMOSTRAS := 4000


func _ready() -> void:
	var vidas := _vidas_dos_inimigos()

	print("\n=== DPS por arma ===")
	print("pico ignora recarga; sustentado dilui a recarga no pente inteiro.\n")
	print("%-26s %7s %7s %7s  %s" % ["arma", "pico", "sustent", "queda", "de onde vem o dano"])
	print("%s" % "-".repeat(86))

	var linhas: Array = []
	for caminho in ARMAS:
		var dados: DadosArma = load(caminho)
		if dados == null:
			push_warning("nao carregou: %s" % caminho)
			continue
		linhas.append(_medir(dados))

	linhas.sort_custom(func(a, b): return a["sustentado"] > b["sustentado"])
	for l in linhas:
		var queda := 0.0
		if l["pico"] > 0.0:
			queda = (1.0 - l["sustentado"] / l["pico"]) * 100.0
		print("%-26s %7.1f %7.1f %6.0f%%  %s" % [
			l["nome"], l["pico"], l["sustentado"], queda, l["fonte"]])

	print("\n=== segundos para matar (DPS sustentado, sem Deterioracao) ===\n")
	var cabecalho := "%-26s" % "arma"
	for par in vidas:
		cabecalho += "%9s" % par["curto"]
	print(cabecalho)
	print("%s" % "-".repeat(26 + 9 * vidas.size()))
	for l in linhas:
		var linha := "%-26s" % l["nome"]
		for par in vidas:
			if l["sustentado"] <= 0.0:
				linha += "%9s" % "--"
			else:
				linha += "%9.1f" % (float(par["vida"]) / l["sustentado"])

		print(linha)

	print("\nA Deterioracao multiplica a vida dos inimigos em tempo de run, entao")
	print("estes segundos sao o PISO -- o inicio do andar, com a barra em zero.")
	print("A Gravity Gun aparece no fim de proposito: o valor dela esta no")
	print("knockback, que nenhuma destas colunas mede.\n")
	get_tree().quit()


## Dano por tiro e de onde ele sai. Cada comportamento guarda o dano num campo
## diferente, e somar os campos as cegas inflaria quem tem os dois.
func _dano_por_tiro(dados: DadosArma) -> Dictionary:
	if dados.e_feixe():
		# O feixe nao tem "tiro": ele tem dano por segundo direto. O tiro aqui e
		# a unidade de MUNICAO, que e o que a recarga interrompe.
		return {"dano": dados.dano_por_segundo / maxf(dados.cadencia, 0.01), "fonte": "dano_por_segundo"}

	if dados.explode():
		# Granada e plasma nao machucam por contato: o dano E a explosao. Usar
		# `dano` aqui daria 1 para o Boomer, que e o numero que o projetil
		# deliberadamente nunca aplica.
		#
		# Vale o dano do CENTRO. A borda vale 35% disso, entao o numero real
		# depende de onde o alvo estava -- e um so acerto de granada no meio de
		# tres corpos vale mais que a coluna inteira mostra.
		return {"dano": float(dados.dano_explosao), "fonte": "dano_explosao (centro)"}

	var media := float(dados.dano) * _media_de_projeteis(dados)
	var fonte := "dano x projeteis"

	if dados.encadeia():
		# Os elos somam, com decaimento e piso 1 por elo -- exatamente como o
		# projetil calcula. So conta se houver corpos alinhados, entao este e o
		# TETO da arma e nao o caso comum.
		var elo := float(dados.dano)
		for _i in dados.saltos_corrente:
			elo *= dados.decaimento_corrente
			media += maxf(roundf(elo), 1.0)
		fonte = "dano + %d elos (teto)" % dados.saltos_corrente

	if dados.semeia_nanite():
		# A explosao diluida pelos tiros que ela custa.
		media += float(dados.dano_explosao) / float(dados.stacks_nanite)
		fonte = "dano + explosao/%d" % dados.stacks_nanite

	return {"dano": media, "fonte": fonte}


## Media real de projeteis por tiro, sorteada. `projeteis_extra` faz a Riot-12
## variar, e a media de uma faixa nao e o extremo de nenhuma ponta.
func _media_de_projeteis(dados: DadosArma) -> float:
	if dados.projeteis_extra <= 0:
		return float(maxi(dados.projeteis_por_tiro, 1))
	var soma := 0
	for _i in AMOSTRAS:
		soma += dados.sortear_projeteis()
	return float(soma) / float(AMOSTRAS)


func _medir(dados: DadosArma) -> Dictionary:
	var por_tiro: Dictionary = _dano_por_tiro(dados)
	var dano: float = por_tiro["dano"]
	var pico := dano * dados.cadencia

	# Sustentado: o pente inteiro leva `pente/cadencia` segundos de tiro mais
	# `tempo_recarga` parado. Pente infinito nunca recarrega.
	var pente := float(maxi(dados.pente(), 1))
	var tempo_de_tiro := pente / maxf(dados.cadencia, 0.01)
	var ciclo := tempo_de_tiro + dados.tempo_recarga
	var sustentado := (dano * pente) / maxf(ciclo, 0.01)

	return {
		"nome": dados.nome,
		"pico": pico,
		"sustentado": sustentado,
		"fonte": por_tiro["fonte"],
	}


## Vida real lida de cada cena, e nao uma tabela copiada aqui: tabela envelhece
## em silencio no dia em que alguem ajustar um `@export`.
func _vidas_dos_inimigos() -> Array:
	var saida: Array = []
	for caminho in INIMIGOS:
		var cena: PackedScene = load(caminho)
		if cena == null:
			continue
		var no := cena.instantiate()
		# `vida_maxima` e nao `vida`: o `.tscn` so sobrescreve o primeiro, e o
		# segundo so recebe o valor no `_ready` -- que nunca roda num no que
		# nao entrou na arvore. Lendo `vida` esta regua dava 5 para TODOS os
		# inimigos, do Rastejante a Diretora, e a tabela inteira de tempo de
		# morte saia com colunas identicas.
		var bruto: Variant = no.get("vida_maxima")
		var vida: int = int(bruto) if bruto != null else 0
		var curto: String = caminho.get_file().get_basename()
		saida.append({"curto": curto.substr(0, 8), "vida": vida})
		no.free()
	return saida
