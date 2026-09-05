class_name Impactos
extends RefCounted
## As familias de IMPACTO: "o que aquilo fez ao chegar".
##
## Havia UM impacto no jogo -- `src/fx/impacto.tscn`, tingido por `modulate` --,
## entao a bala, a granada, o plasma e a sucata do chefe batiam igual. O impacto
## e a metade da leitura que confirma o acerto, e uma metade que fala sempre a
## mesma coisa nao confirma nada alem de "encostou".
##
## **Nove familias, UMA cena.** O que separa uma familia de outra num
## `CPUParticles2D` sao `amount`, `lifetime`, `spread`, `initial_velocity_*`,
## `damping_*` e `scale_amount_*` -- todas propriedades escrevi­veis na
## instanciacao. Nove cenas duplicadas seriam nove lugares para o mesmo ajuste
## divergir, que e a licao do `Movimento` e a do `Telegrafo`.
##
## O enum e SEPARADO do de silhueta de proposito. A forma diz *o que esta
## voando*; o impacto diz *o que aquilo fez ao chegar*. A Riot-12 e a Mantis
## podem dividir silhueta e diferir no impacto; o Rail-X e o sniper inimigo
## dividem o impacto de perfuracao com silhuetas diferentes. Colapsar os dois
## eixos num campo so faria os dois portoes brigarem pelo mesmo numero.


## As familias. **Valor novo entra sempre NO FIM** -- e INT no `.tres`, mesma
## armadilha de todo enum deste projeto. E FAISCA tem de continuar sendo ZERO:
## arma que nao declara nada continua batendo exatamente como batia.
enum Familia {
	FAISCA,     ## O impacto de bala. E o `impacto.tscn` de sempre, numero a numero.
	ESTILHACO,  ## Perfurante: poucos cacos, rapidos e num cone estreito.
	RESPINGO,   ## Energia: muitos pingos lentos, que ficam um instante a mais.
	ANEL,       ## Gravidade: tudo para fora na mesma velocidade, sem dispersao.
	FUMACA,     ## Explosivo: lento, grande, e demora a sumir.
	DESCARGA,   ## Eletrico: curtissimo e nervoso.
	PO,         ## Mecanico: o do chefe e da sucata -- pesado e sem brilho.
	BRASA,      ## Nanite: poucas particulas que ficam MUITO tempo.
	ESTOURO,    ## A explosao de area. E o `explosao.tscn` de sempre.
}

## Um registro por familia, e nada alem de propriedades de `CPUParticles2D`.
##
## FAISCA e ESTOURO reproduzem `impacto.tscn` e `explosao.tscn` numero a numero:
## e o que garante que esta peca entra sem mudar um pixel do que ja existia.
const PERFIS: Dictionary = {
	Familia.FAISCA: {
		"amount": 7, "lifetime": 0.28, "aleatoria": 0.4, "abertura": 180.0,
		"v_min": 60.0, "v_max": 190.0, "freio_min": 240.0, "freio_max": 400.0,
		"e_min": 1.5, "e_max": 3.0,
	},
	Familia.ESTILHACO: {
		"amount": 5, "lifetime": 0.20, "aleatoria": 0.3, "abertura": 38.0,
		"v_min": 260.0, "v_max": 520.0, "freio_min": 600.0, "freio_max": 900.0,
		"e_min": 1.0, "e_max": 2.0,
	},
	Familia.RESPINGO: {
		"amount": 12, "lifetime": 0.34, "aleatoria": 0.5, "abertura": 180.0,
		"v_min": 40.0, "v_max": 150.0, "freio_min": 180.0, "freio_max": 320.0,
		"e_min": 1.5, "e_max": 3.2,
	},
	Familia.ANEL: {
		"amount": 16, "lifetime": 0.30, "aleatoria": 0.1, "abertura": 180.0,
		"v_min": 210.0, "v_max": 240.0, "freio_min": 500.0, "freio_max": 560.0,
		"e_min": 1.5, "e_max": 2.5,
	},
	Familia.FUMACA: {
		"amount": 14, "lifetime": 0.55, "aleatoria": 0.6, "abertura": 180.0,
		"v_min": 30.0, "v_max": 110.0, "freio_min": 120.0, "freio_max": 240.0,
		"e_min": 3.0, "e_max": 6.0,
	},
	Familia.DESCARGA: {
		"amount": 9, "lifetime": 0.14, "aleatoria": 0.7, "abertura": 180.0,
		"v_min": 180.0, "v_max": 460.0, "freio_min": 700.0, "freio_max": 1100.0,
		"e_min": 1.0, "e_max": 2.2,
	},
	Familia.PO: {
		"amount": 10, "lifetime": 0.42, "aleatoria": 0.5, "abertura": 120.0,
		"v_min": 50.0, "v_max": 170.0, "freio_min": 260.0, "freio_max": 420.0,
		"e_min": 2.0, "e_max": 4.0,
	},
	Familia.BRASA: {
		"amount": 6, "lifetime": 0.75, "aleatoria": 0.5, "abertura": 180.0,
		"v_min": 20.0, "v_max": 90.0, "freio_min": 90.0, "freio_max": 200.0,
		"e_min": 1.2, "e_max": 2.4,
	},
	Familia.ESTOURO: {
		"amount": 26, "lifetime": 0.6, "aleatoria": 0.5, "abertura": 180.0,
		"v_min": 120.0, "v_max": 420.0, "freio_min": 200.0, "freio_max": 500.0,
		"e_min": 2.0, "e_max": 5.0,
	},
}


## Veste um `CPUParticles2D` recem-instanciado.
##
## **Chame ANTES do `add_child`**, ao contrario da convencao da casa
## ("add_child antes de configurar"). O motivo e concreto:
## `fx_autodestroi.gd._ready()` faz `emitting = true` e depois
## `await create_timer(lifetime + 0.2)` -- o timer captura o `lifetime` DAQUELE
## instante. Vestido depois, a particula e liberada no tempo da familia errada.
##
## E seguro porque `vestir()` nao escreve posicao global, e o precedente ja
## estava no arquivo: `Projetil._impacto()` sempre escreveu `global_position` e
## `modulate` antes do `add_child`.
static func vestir(no: CPUParticles2D, familia: int, cor: Color, escala: float = 1.0) -> void:
	var p: Dictionary = PERFIS.get(familia, PERFIS[Familia.FAISCA])
	no.modulate = cor
	no.amount = p["amount"]
	no.lifetime = p["lifetime"]
	no.lifetime_randomness = p["aleatoria"]
	no.spread = p["abertura"]
	no.initial_velocity_min = p["v_min"] * escala
	no.initial_velocity_max = p["v_max"] * escala
	no.damping_min = p["freio_min"]
	no.damping_max = p["freio_max"]
	no.scale_amount_min = p["e_min"] * escala
	no.scale_amount_max = p["e_max"] * escala


static func existe(familia: int) -> bool:
	return PERFIS.has(familia)


static func nome(familia: int) -> StringName:
	var chaves := Familia.keys()
	if familia < 0 or familia >= chaves.size():
		return &"?"
	return StringName(chaves[familia])
