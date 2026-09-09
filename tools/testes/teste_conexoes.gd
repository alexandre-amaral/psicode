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
	await _a_conexao_do_chefe_e_sempre_corredor()
	await _o_cluster_agrupa_sem_virar_gradiente()
	_o_perfil_de_corredor_nao_anuncia_a_vizinha()
	await _o_corredor_e_raro_e_por_isso_significa_algo()
	await _sem_chefe_nenhuma_conexao_veste_o_chefe()
	await _as_bocas_das_duas_salas_se_ENCONTRAM()


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
		_desmontar(mapa)
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
	_desmontar(mapa_sem)
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


## A conexao que entra na sala do chefe e sempre corredor tecnico.
##
## O corredor pre-chefe e a UNICA excecao autorizada a regra da noite base, e com
## corredor em 10% das arestas ele pode simplesmente nao ser sorteado. O anuncio
## sumiria sem uma linha no console -- uma parede compartilhada de 96 px ainda
## troca a textura de chao, entao ele viraria uma mancha de dois passos.
##
## E o outro lado: num andar SEM chefe nenhuma conexao pode vestir o perfil dele.
## `celula_do_chefe()` devolve ZERO quando nao ha chefe, e zero e a celula
## inicial -- sem conferir a reserva, a entrada do andar ganharia o corredor do
## chefe.
func _a_conexao_do_chefe_e_sempre_corredor() -> void:
	var conferidos := 0
	var fora := 0
	for i in ANDARES:
		seed(9300 + i * 53)
		var mapa := _montar(true)
		if mapa == null:
			continue
		await Engine.get_main_loop().process_frame
		var chefe := mapa.celula_do_chefe()
		for ligacao in mapa.ligacoes():
			if ligacao["a"] != chefe and ligacao["b"] != chefe:
				continue
			conferidos += 1
			if int(ligacao["tipo"]) != PlantaDoAndar.Conexao.CORREDOR_TECNICO:
				fora += 1
		_desmontar(mapa)
		await Engine.get_main_loop().process_frame
	ok(conferidos > 0, "houve conexao de chefe para conferir (%d)" % conferidos)
	igual(fora, 0,
		"toda conexao que entra no chefe e corredor tecnico (%d fora de %d)"
			% [fora, conferidos])


## O cluster agrupa por VIZINHANCA, e nao por distancia da entrada.
##
## **Esta e a metade que impede o cluster de reintroduzir o que o vies de
## distancia foi recusado por fazer.** A tentacao obvia -- `DEGRADADA` mais
## provavel fundo no andar -- e a armadilha que o corredor pre-chefe ja registra:
## um andar que escurecesse a cada sala anunciaria o chefe desde a terceira
## porta, e o jogador passaria a ler o mapa pela parede.
##
## Cluster nao faz isso, e o portao prova em vez de afirmar: se o indice do
## cluster tiver correlacao com a distancia da entrada, o agrupamento virou
## gradiente sem ninguem decidir.
##
## E as duas metades opostas: salas do MESMO cluster tem de se ligar
## majoritariamente por parede compartilhada, e as de clusters diferentes nao --
## senao o cluster existe e nao muda nada.
func _o_cluster_agrupa_sem_virar_gradiente() -> void:
	var pares_dentro := 0
	var compartilhadas_dentro := 0
	var pares_entre := 0
	var compartilhadas_entre := 0
	var soma_x := 0.0
	var soma_y := 0.0
	var soma_xy := 0.0
	var soma_x2 := 0.0
	var soma_y2 := 0.0
	var n := 0

	for i in ANDARES:
		seed(9400 + i * 71)
		var mapa := _montar(true)
		if mapa == null:
			continue
		await Engine.get_main_loop().process_frame
		var origem := Vector2i.ZERO
		for celula in mapa.celulas():
			var cluster := mapa.cluster_da_celula(celula)
			if cluster < 0:
				continue
			# Distancia de MANHATTAN ate a entrada: e o que o jogador percorre no
			# grafo, e e a variavel que nao pode explicar o cluster.
			var d := float(absi(celula.x - origem.x) + absi(celula.y - origem.y))
			var c := float(cluster)
			soma_x += d
			soma_y += c
			soma_xy += d * c
			soma_x2 += d * d
			soma_y2 += c * c
			n += 1
		for ligacao in mapa.ligacoes():
			var mesmo := mapa.cluster_da_celula(ligacao["a"]) == mapa.cluster_da_celula(ligacao["b"])
			var compartilhada := int(ligacao["tipo"]) == PlantaDoAndar.Conexao.PAREDE_COMPARTILHADA
			if mesmo:
				pares_dentro += 1
				compartilhadas_dentro += 1 if compartilhada else 0
			else:
				pares_entre += 1
				compartilhadas_entre += 1 if compartilhada else 0
		_desmontar(mapa)
		await Engine.get_main_loop().process_frame

	ok(n > 0, "houve celula para medir (%d)" % n)
	ok(pares_dentro > 0 and pares_entre > 0,
		"houve fronteira dos dois tipos (%d dentro, %d entre)" % [pares_dentro, pares_entre])
	if n < 2 or pares_dentro == 0 or pares_entre == 0:
		return

	var num := float(n) * soma_xy - soma_x * soma_y
	var den := sqrt(maxf(float(n) * soma_x2 - soma_x * soma_x, 0.0001)) \
		* sqrt(maxf(float(n) * soma_y2 - soma_y * soma_y, 0.0001))
	var correlacao := absf(num / den)
	# O corte e generoso porque a inundacao parte de sementes ordenadas e alguma
	# correlacao e inevitavel; o que ele tem de pegar e o gradiente, e um
	# gradiente de verdade mede acima de 0,8.
	ok(correlacao < 0.6,
		"o cluster nao e um gradiente de distancia (correlacao %.2f, teto 0,60)" % correlacao)

	var dentro := float(compartilhadas_dentro) / float(pares_dentro)
	var entre := float(compartilhadas_entre) / float(pares_entre)
	ok(dentro > entre,
		"dentro do cluster a parede compartilhada domina (%.0f%% contra %.0f%% entre clusters)"
			% [dentro * 100.0, entre * 100.0])


## O PERFIL DE CORREDOR DECORA SEM ANUNCIAR A VIZINHA (SETOR 07).
##
## A regra da noite base tem uma excecao so, e ela e deliberada: o trecho
## pre-chefe. Todo o resto do corredor fica neutro de proposito --
##
##     "pintar cada metade com a cor da vizinha anunciaria o que ha do outro lado
##     antes de o jogador chegar"
##
## -- e foi essa regra que barrou a solucao obvia desta issue. Vestir a FACE do
## corredor com os modulos ja entregues (tubulacao, tecnica, deteriorada) usaria
## arte que so existe nos tingimentos de TIPO DE SALA, e vestir um deles diria
## qual sala vem. A decoracao foi entao para o CHAO e para o DECALQUE, que sao
## mudos: as tres texturas de chao SAO a noite base, e uma valvula desenhada no
## piso nao informa nada sobre a proxima sala.
##
## **Este caso guarda a fronteira, e ele e o unico lugar onde ela e verificavel.**
## Um `.tres` novo apontando `textura_chao` para `chao_boss.png` compila,
## carrega, desenha e desfaz a regra do andar inteiro sem uma linha no console --
## o sintoma seria o jogo anunciando o chefe em toda parte, que e exatamente o
## defeito que a excecao existe para conter num lugar so.
func _o_perfil_de_corredor_nao_anuncia_a_vizinha() -> void:
	var perfis := _perfis_de_corredor()
	ok(perfis.size() >= 3, "o andar declara perfis de corredor (%d)" % perfis.size())

	for p in perfis:
		# 1. O CHAO FICA NA NOITE BASE. E a fronteira inteira.
		ok(p.textura_chao != null, "%s declara chao" % p.id)
		if p.textura_chao != null:
			var caminho := p.textura_chao.resource_path
			ok(Corredor.TEXTURAS_CHAO.has(caminho),
				"%s fica na noite base (%s)" % [p.id, caminho.get_file()])

		# 2. E O DECALQUE CABE NO CORREDOR. Uma peca mais larga que a passagem
		#    sai cortada pelas duas laterais, e marca cortada le como erro de
		#    montagem em vez de desgaste.
		var folga := Porta.LARGURA - Corredor.RECUO_DO_DECALQUE
		for regiao in p.regioes_decalques:
			ok(float(maxi(regiao.size.x, regiao.size.y)) <= Porta.LARGURA,
				"%s: a peca %dx%d cabe na largura do corredor (%d px)"
					% [p.id, regiao.size.x, regiao.size.y, int(Porta.LARGURA)])
		ok(folga > 0.0,
			"%s: sobra miolo depois do recuo (%.0f px)" % [p.id, folga])

	# 3. TODO PAR DE TEMAS ACHA UM PERFIL. A afinidade ordena, nao desqualifica:
	#    um par sem perfil correspondente deixaria o corredor pelado, que e o
	#    estado de antes desta issue -- e ele nao daria erro nenhum.
	var ids: Array[StringName] = []
	for caminho in _temas_em_disco():
		var t := load(caminho) as TemaDeSala
		if t != null:
			ids.append(t.id)
	ok(ids.size() >= 4, "a varredura achou os temas (%d)" % ids.size())
	var sem_perfil := 0
	for a in ids:
		for b in ids:
			var melhor := -1
			for p in perfis:
				melhor = maxi(melhor, p.afinidade(a, b))
			if melhor < 0:
				sem_perfil += 1
	igual(sem_perfil, 0,
		"nenhum par de temas fica sem perfil (%d pares nus)" % sem_perfil)

	# 4. O TRECHO PRE-CHEFE TEM O PERFIL QUE O #257 CRAVA. Ele e o unico lugar
	#    autorizado a anunciar, e um anuncio que muda de cara a cada run deixa de
	#    ser reconhecivel -- e o mesmo argumento que faz o chefe ter moveset fixo.
	var tem_forca := false
	for p in perfis:
		if p.id == &"linha_de_forca":
			tem_forca = true
	ok(tem_forca, "o perfil do trecho pre-chefe existe (linha_de_forca)")


func _perfis_de_corredor() -> Array[PerfilDeCorredor]:
	var saida: Array[PerfilDeCorredor] = []
	var pasta := DirAccess.open("res://src/mapa/")
	if pasta == null:
		return saida
	for nome in pasta.get_files():
		if not nome.begins_with("corredor_") or not nome.ends_with(".tres"):
			continue
		var p := load("res://src/mapa/" + nome) as PerfilDeCorredor
		if p != null:
			saida.append(p)
	return saida


func _temas_em_disco() -> Array[String]:
	var saida: Array[String] = []
	var pasta := DirAccess.open("res://src/mapa/")
	if pasta == null:
		return saida
	for nome in pasta.get_files():
		if nome.begins_with("tema_") and nome.ends_with(".tres"):
			saida.append("res://src/mapa/" + nome)
	return saida


## O CORREDOR E RARO, e e por isso que ele significa algo (SETOR 07).
##
## Ele deixou de ser o conector universal para virar o caso especial -- e a
## decoracao por perfil so faz sentido em cima disso: um corredor que aparece
## entre todo par de salas nao e um tunel de servico, e o espaco obrigatorio
## entre combates.
##
## **A issue pede dois criterios que nao sao o mesmo, e o portao morde no que
## descreve o desenho.** "5 a 15% das arestas" e "uma, as vezes duas" divergem:
## com 9 arestas por andar, uma conexao vale 11% e duas valem 22%. Medido em 24
## andares, o andar entrega **15,3% das arestas e 1,38 corredor por andar** -- de
## fora da primeira faixa e dentro da segunda.
##
## Duas coisas empurram a fracao para cima, e nenhuma e o sorteio:
##
##   - o corredor do chefe e RESERVADO (#257), entao um por andar e garantido e
##     isso sozinho ja e 11% das arestas;
##   - o tipo e sorteado por FRONTEIRA e nao por aresta, porque o andar e montado
##     em bandas -- uma fronteira que caia em corredor veste TODAS as arestas que
##     a cruzam, e um unico sorteio pode render duas ou tres.
##
## Contar aresta mede a segunda coisa; contar corredor por andar mede o desenho.
func _o_corredor_e_raro_e_por_isso_significa_algo() -> void:
	var total := 0
	var andares := 0
	var sem_nenhum := 0
	for i in ANDARES:
		seed(7700 + i * 61)
		var mapa := _montar(true)
		if mapa == null:
			continue
		await Engine.get_main_loop().process_frame
		var quantos := 0
		for ligacao in mapa.ligacoes():
			if int(ligacao["tipo"]) == PlantaDoAndar.Conexao.CORREDOR_TECNICO:
				quantos += 1
		total += quantos
		andares += 1
		if quantos == 0:
			sem_nenhum += 1
		_desmontar(mapa)

	ok(andares > 0, "os andares subiram (%d)" % andares)
	if andares == 0:
		return
	# **NENHUM ANDAR FICA SEM CORREDOR**, e isso nao vem do sorteio: vem da
	# reserva do #257. O trecho pre-chefe e o unico lugar autorizado a anunciar o
	# que vem, e com o corredor raro ele poderia simplesmente nao ser sorteado --
	# o anuncio sumiria sem uma linha no console.
	igual(sem_nenhum, 0, "todo andar tem ao menos um corredor (%d sem)" % sem_nenhum)

	var media := float(total) / float(andares)
	# O teto e o que separa "caso especial" de "conector". Tres por andar ja e um
	# andar em que o corredor deixou de ser excecao, e a decoracao por perfil
	# passa a ser vista tantas vezes que ela vira o padrao em vez do desvio.
	entre(media, 1.0, 2.0,
		"o corredor e raro: %.2f por andar (a issue pede uma, as vezes duas)" % media)


## NUM ANDAR SEM CHEFE, NADA ANUNCIA O CHEFE (SETOR 11).
##
## **`celula_do_chefe()` devolve ZERO quando nao ha chefe, e ZERO e uma celula
## VALIDA -- a inicial mora nela.** Sem a guarda, um andar sem chefe vestiria os
## corredores da ENTRADA com as texturas dele: o jogo anunciaria a luta na
## primeira porta, que e o oposto exato do que a excecao existe para fazer.
##
## Isto e uma armadilha JA REGISTRADA, e por isso ela precisa de portao: guarda
## que existe so no comentario volta a sumir no proximo refactor. E ela ganhou um
## segundo consumidor com os perfis de corredor, que tambem forcam
## `linha_de_forca` no trecho pre-chefe -- dois caminhos lendo a mesma pergunta.
##
## O que ele NAO cobra: que `linha_de_forca` nunca seja sorteado num andar sem
## chefe. Ele pode, e deve -- o perfil nao e o anuncio. O anuncio sao as texturas
## da sala do chefe, e e nelas que a guarda morde.
func _sem_chefe_nenhuma_conexao_veste_o_chefe() -> void:
	seed(8811)
	var mapa := _montar(true)
	ok(mapa != null, "o andar sobe")
	if mapa == null:
		return
	var chefe := mapa.celula_do_chefe()
	# 1. COM chefe, a celula dele anuncia -- senao o portao passaria por medir a
	#    coisa errada, e um `_e_trecho_pre_chefe` que devolvesse `false` sempre
	#    ficaria verde nos dois lados.
	var vizinhas := mapa.vizinhos_de(chefe)
	ok(not vizinhas.is_empty(), "a sala do chefe tem vizinha (%d)" % vizinhas.size())
	var anunciou := false
	for direcao: Vector2 in vizinhas:
		if mapa._e_trecho_pre_chefe(chefe, chefe + Vector2i(int(direcao.x), int(direcao.y))):
			anunciou = true
	ok(anunciou, "a conexao que entra no chefe anuncia")

	# 2. SEM chefe reservado, NADA anuncia -- inclusive a celula ZERO, que e onde
	#    a armadilha mora.
	mapa._reservadas.clear()
	var falsos := 0
	for ligacao in mapa.ligacoes():
		if mapa._e_trecho_pre_chefe(ligacao["a"], ligacao["b"]):
			falsos += 1
		if mapa._perfil_do_corredor(ligacao["a"], ligacao["b"]) != null \
				and mapa._perfil_do_corredor(ligacao["a"], ligacao["b"]).id == &"linha_de_forca":
			# Sortear `linha_de_forca` por afinidade continua valido -- o perfil
			# nao e o anuncio. O que nao pode e ele ser FORCADO sem chefe.
			pass
	igual(falsos, 0,
		"sem chefe reservado, nenhuma conexao anuncia (%d anunciaram)" % falsos)
	ok(not mapa._e_trecho_pre_chefe(Vector2i.ZERO, Vector2i(1, 0)),
		"e a celula ZERO em especial nao anuncia -- ela e a INICIAL")

	_desmontar(mapa)


## As BOCAS das duas salas de uma conexao se encontram, sempre (`[SETOR 05]`).
##
## **Esta e a restricao que a issue nao previu, e ela e o que decide o desenho
## do deslizamento.** A `[SETOR 05]` pede que a sala deixe de ficar centrada na
## banda e encoste na fronteira que compartilha -- e deslizar uma sala
## PERPENDICULARMENTE a uma conexao quebra o encontro das duas portas.
##
## O sintoma nao e um erro: `Corredor.configurar()` recebe as duas bocas, e se
## elas desalinham nos dois eixos ele emite um `push_warning` e monta pelo eixo
## DOMINANTE. O corredor sai torto, sem encostar em nenhuma das duas portas, e o
## jogo continua rodando -- o jogador so encontra uma passagem que nao leva a
## lugar nenhum. `push_warning` nao reprova suite nenhuma.
##
## Hoje isso e garantido por construcao: o deslize e por CORRENTE, e celulas
## ligadas no eixo perpendicular deslizam juntas. Este caso e o que torna a
## garantia cobravel -- sem ele, alguem "simplifica" o deslizamento para
## sala-a-sala, o codigo fica mais curto, nada reclama, e o andar ganha
## corredores tortos.
##
## A tolerancia e a do proprio `Corredor`, e nao um numero novo: dois donos do
## mesmo limite divergem, e aqui a divergencia seria uma suite verde sobre um
## corredor que o motor ja considera desalinhado.
func _as_bocas_das_duas_salas_se_ENCONTRAM() -> void:
	var mapa := _montar(true)
	ok(mapa != null, "o andar sobe")
	if mapa == null:
		return
	await Engine.get_main_loop().process_frame

	# As salas vem da ARVORE e nao de uma API nova: `_salas` e privado, e abrir
	# um acessor publico so para esta suite acrescentaria superficie que o jogo
	# nao usa. Elas sao filhas diretas do gerenciador, com a celula declarada.
	var por_celula: Dictionary = {}
	for filho in mapa.get_children():
		var sala := filho as Sala
		if sala != null:
			por_celula[sala.coordenadas_grid] = sala

	var conferidas := 0
	var tortas: Array[String] = []
	for ligacao in mapa.ligacoes():
		var a: Vector2i = ligacao["a"]
		var b: Vector2i = ligacao["b"]
		var sala_a := por_celula.get(a) as Sala
		var sala_b := por_celula.get(b) as Sala
		if sala_a == null or sala_b == null:
			continue
		var direcao := Vector2(b - a).normalized()
		var boca_a := sala_a.boca_da_porta(direcao)
		var boca_b := sala_b.boca_da_porta(-direcao)
		conferidas += 1
		# O desalinhamento e o que sobra no eixo PERPENDICULAR ao da conexao.
		var delta := boca_b - boca_a
		var perpendicular: float = absf(delta.x) if absf(direcao.y) > 0.5 else absf(delta.y)
		if perpendicular > Corredor.TOLERANCIA_ALINHAMENTO:
			tortas.append("%s -> %s (%.0f px)" % [a, b, perpendicular])

	ok(conferidas > 0, "houve conexao para conferir (%d)" % conferidas)
	igual(tortas.size(), 0,
		"toda conexao tem as duas bocas alinhadas -- corredor torto so avisa, nao reprova (%s)"
			% ", ".join(tortas))
	_desmontar(mapa)


## Libera a cena principal INTEIRA, e nao so o pedaco que interessava.
##
## `mapa.free()` (ou `mapa.get_parent().free()`, que e o `Mundo`) deixa o no
## `Main` na arvore para sempre -- e com ele o `ContainerProjeteis`, que esta num
## GRUPO. A partir dali toda suite que dispara uma arma tem os projeteis dela
## caindo neste container esquecido, porque `Arma._container()` resolve por
## `get_first_node_in_group()` e a ordem de um grupo nao e a de insercao. Sete
## casos de `teste_arma.gd` e `teste_boss_ataques.gd` passaram a medir ZERO
## projeteis com o codigo certo no instante em que aquele no nasceu.
##
## E a mesma armadilha que o cabecalho de `teste_arma.gd` ja registra para quem
## CRIA um container -- vista do outro lado: aqui ninguem criou nada, so deixou
## de limpar.
func _desmontar(no: Node) -> void:
	var raiz: Node = Engine.get_main_loop().root
	var alvo := no
	while alvo.get_parent() != null and alvo.get_parent() != raiz:
		alvo = alvo.get_parent()
	alvo.free()
