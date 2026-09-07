extends TesteBase
## A COMPOSICAO de conexoes de um andar, e ela falha em silencio dos dois lados.
##
## Uma aresta do grafo deixou de significar `criar_corredor(A, B)` e passa a
## significar `criar_conexao(A, B)`. O que decide qual e a `PlantaDoAndar`, e nada
## no jogo acusa quando ela nao decide nada:
##
##   - **composicao errada nao da erro.** Se o resolvedor devolver corredor para
##     tudo -- porque a planta nao carregou, porque um peso ficou zero, porque a
##     lista de fronteiras nasceu vazia --, o andar volta a ser o de antes e o
##     console fica limpo. E a mesma armadilha que `_sortear_grupo()` ja registra:
##     "se todo grupo tiver porta acima de zero, as salas de combate nascem
##     vazias, e o andar vira uma caminhada sem uma linha no console".
##   - **e o inverso tambem.** Uma parede compartilhada aplicada onde a geometria
##     nao permite deixa duas salas se sobrepondo, e o teste de fumaca nao pega:
##     ele atravessa o andar por script, e nao pela porta.
##
## **A CAMERA e o caso que autoriza o epico inteiro.** Encostar duas salas
## arrisca o clamp de uma mostrar o chao da outra, e isso nao e um erro -- e uma
## sala que vaza para a vizinha antes de o jogador chegar nela.

const ANDARES := 8

## Longe da origem, como as outras suites que sobem nos.
const LONGE := Vector2(41000.0, 41000.0)


func nome() -> String:
	return "Conexoes"


func executar() -> void:
	await _a_planta_manda_e_sem_ela_nada_muda()
	await _todo_vao_cai_na_grade_de_16()
	await _nenhuma_camera_alcanca_o_chao_da_vizinha()
	_a_planta_do_andar1_declara_o_vao_em_que_as_faixas_se_encontram()


## Sobe o andar inteiro e devolve o gerenciador ja montado.
##
## **O Player sai antes do `add_child`.** O grupo "player" e global, e outras
## suites o consultam por `get_first_node_in_group` -- um boneco a mais no grupo
## ja custou um dia de teste vermelho com o codigo certo (ver `teste_hack.gd` e
## `teste_boss_selecao.gd`). Aqui ele nao faz falta: o que se mede e a geometria
## das conexoes, e ela nasce no `_ready` do gerenciador.
func _montar(com_planta: bool) -> GerenciadorMapa:
	var cena: PackedScene = load("res://src/main/main.tscn")
	var main := cena.instantiate()
	var jogador := main.find_child("Player", true, false)
	if jogador != null:
		jogador.get_parent().remove_child(jogador)
		jogador.free()
	var mapa := main.find_child("GerenciadorMapa", true, false) as GerenciadorMapa
	if mapa != null and not com_planta:
		mapa.planta = null
	var mundo := main.find_child("Mundo", true, false) as Node2D
	if mundo != null:
		mundo.position = LONGE
	Engine.get_main_loop().root.add_child(main)
	return mapa


## Com planta, os tres tipos aparecem; sem planta, nada muda.
##
## A segunda metade e a que faz os outros andares continuarem funcionando, e ela
## morde: se `planta == null` deixasse de cair no caminho de sempre, todo andar
## que nao declara planta mudaria de layout sem ninguem pedir.
func _a_planta_manda_e_sem_ela_nada_muda() -> void:
	var conta := {}
	var arestas := 0
	for i in ANDARES:
		seed(9100 + i * 31)
		var mapa := _montar(true)
		if mapa == null:
			ok(false, "o andar monta o gerenciador")
			continue
		await Engine.get_main_loop().process_frame
		for ligacao in mapa.ligacoes():
			var tipo: int = ligacao["tipo"]
			conta[tipo] = int(conta.get(tipo, 0)) + 1
			arestas += 1
		mapa.get_parent().free()
		await Engine.get_main_loop().process_frame

	ok(arestas > 0, "houve aresta para classificar (%d em %d andares)" % [arestas, ANDARES])
	for tipo in [PlantaDoAndar.Conexao.PAREDE_COMPARTILHADA,
			PlantaDoAndar.Conexao.PASSAGEM_CURTA,
			PlantaDoAndar.Conexao.CORREDOR_TECNICO]:
		var quantas: int = conta.get(tipo, 0)
		ok(quantas > 0, "o tipo %s aparece (%d de %d) -- peso acima de zero que nunca sai e peso que nao funciona"
			% [PlantaDoAndar.nome_de(tipo), quantas, arestas])

	# SEM PLANTA: corredor para tudo, como sempre foi.
	seed(9199)
	var mapa_sem := _montar(false)
	if mapa_sem == null:
		return
	await Engine.get_main_loop().process_frame
	var fora_do_padrao := 0
	var vistas := 0
	for ligacao in mapa_sem.ligacoes():
		vistas += 1
		if int(ligacao["tipo"]) != PlantaDoAndar.Conexao.CORREDOR_TECNICO:
			fora_do_padrao += 1
	ok(vistas > 0, "o andar sem planta tambem tem arestas (%d)" % vistas)
	igual(fora_do_padrao, 0,
		"sem planta, toda conexao continua sendo corredor (%d fora)" % fora_do_padrao)
	mapa_sem.get_parent().free()
	await Engine.get_main_loop().process_frame


## Todo vao cai na grade de 16.
##
## `teste_grade.gd` ja cobra isso de `vao_corredor`, e a planta trouxe seis
## numeros novos que fazem o mesmo trabalho. Um vao fora da grade nao quebra nada
## em runtime -- so o tileset e que nao encaixa, meses depois.
func _todo_vao_cai_na_grade_de_16() -> void:
	var planta := load("res://src/mapa/planta_andar1.tres") as PlantaDoAndar
	ok(planta != null, "a planta do andar 1 carrega")
	if planta == null:
		return
	for tipo in [PlantaDoAndar.Conexao.PAREDE_COMPARTILHADA,
			PlantaDoAndar.Conexao.PASSAGEM_CURTA,
			PlantaDoAndar.Conexao.CORREDOR_TECNICO]:
		for vertical in [false, true]:
			var v := planta.vao(tipo, vertical)
			perto(fmod(v, 16.0), 0.0,
				"o vao de %s no eixo %s cai na grade (%.0f)"
					% [PlantaDoAndar.nome_de(tipo), "vertical" if vertical else "horizontal", v])


## NENHUMA camera alcanca o chao da sala vizinha.
##
## E a pergunta que autoriza encostar duas salas, e ela nao era garantida por
## nada -- ate este epico as salas ficavam a 439 px umas das outras e sobrava
## folga de sobra. Com a parede compartilhada o clamp de cada sala fica a poucos
## pixels do chao da vizinha, e a conta e apertada:
##
##     A (sul)    32 + 20 de margem exterior = 52   contra um vao de 96
##     B (norte)  60 + 20                    = 80   contra 96
##     lateral    36 + 20                    = 56   contra 80
##
## Se um dia a margem exterior subir ou a parede engrossar, e aqui que aparece --
## e nao numa captura que alguem precisa lembrar de olhar.
func _nenhuma_camera_alcanca_o_chao_da_vizinha() -> void:
	var perfil := PerfilDeParede.new()
	var planta := load("res://src/mapa/planta_andar1.tres") as PlantaDoAndar
	if planta == null:
		return
	var pares := [
		["vertical", perfil.profundidade(RenderizadorParedes.Lado.SUL),
			perfil.profundidade(RenderizadorParedes.Lado.NORTE), true],
		["horizontal", perfil.profundidade(RenderizadorParedes.Lado.LESTE),
			perfil.profundidade(RenderizadorParedes.Lado.OESTE), false],
	]
	for par in pares:
		var rotulo: String = par[0]
		var vao: float = planta.vao(PlantaDoAndar.Conexao.PAREDE_COMPARTILHADA, par[3])
		for lado_fundo: float in [par[1], par[2]]:
			var alcance := lado_fundo + perfil.margem_exterior
			ok(alcance < vao,
				"%s: o clamp alcanca %.0f px contra um vao de %.0f -- nao chega no chao da vizinha"
					% [rotulo, alcance, vao])
		# E as duas faixas juntas TEM de caber no vao, senao elas se sobrepoem.
		ok(par[1] + par[2] <= vao,
			"%s: as duas faixas cabem no vao (%.0f + %.0f contra %.0f)"
				% [rotulo, par[1], par[2], vao])


## O vao declarado e o menor multiplo de 16 em que as faixas se encontram.
##
## Ele nao e um numero escolhido: e a soma das duas profundidades, arredondada
## para cima. Escrito a mao, ele descola da parede no dia em que alguem girar um
## botao do perfil -- e o sintoma seria piso de corredor voltando a aparecer
## entre duas salas que deveriam compartilhar a parede, sem erro nenhum.
func _a_planta_do_andar1_declara_o_vao_em_que_as_faixas_se_encontram() -> void:
	var perfil := PerfilDeParede.new()
	var planta := load("res://src/mapa/planta_andar1.tres") as PlantaDoAndar
	if planta == null:
		return
	var esperado_v := ceilf((perfil.profundidade(RenderizadorParedes.Lado.SUL)
		+ perfil.profundidade(RenderizadorParedes.Lado.NORTE)) / 16.0) * 16.0
	var esperado_h := ceilf(perfil.profundidade(RenderizadorParedes.Lado.LESTE)
		* 2.0 / 16.0) * 16.0
	perto(planta.vao(PlantaDoAndar.Conexao.PAREDE_COMPARTILHADA, true), esperado_v,
		"o vao vertical bate com a parede (%.0f)" % esperado_v)
	perto(planta.vao(PlantaDoAndar.Conexao.PAREDE_COMPARTILHADA, false), esperado_h,
		"o vao horizontal bate com a parede (%.0f)" % esperado_h)
	# E os tres tipos ficam em ordem: compartilhada < curta < corredor. Sem isso
	# a passagem curta poderia sair mais curta que a parede compartilhada, e os
	# dois nomes deixariam de querer dizer alguma coisa.
	for vertical in [false, true]:
		var a := planta.vao(PlantaDoAndar.Conexao.PAREDE_COMPARTILHADA, vertical)
		var b := planta.vao(PlantaDoAndar.Conexao.PASSAGEM_CURTA, vertical)
		var c := planta.vao(PlantaDoAndar.Conexao.CORREDOR_TECNICO, vertical)
		ok(a < b and b < c,
			"os tres vaos ficam em ordem no eixo %s (%.0f < %.0f < %.0f)"
				% ["vertical" if vertical else "horizontal", a, b, c])
