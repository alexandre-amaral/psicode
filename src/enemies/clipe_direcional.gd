class_name ClipeDirecional
extends Resource
## Um GESTO de oito direcoes: as fitas, quantos quadros, e contra o que o quadro
## e escolhido.
##
## Ele existe porque `SpriteDirecional` so tinha DOIS conjuntos -- parado e
## andando -- e nao havia como um ataque ter animacao. Era isso que o
## `drone_aranha.gd` registrava ao congelar o corpo no ataque: "como nao ha arte
## de ataque, e a pose parada encarando o jogador que faz esse papel".
##
## **A decisao que este recurso carrega: o modo NAO e escolha de quem chama, e do
## GESTO.** Quem desenhou o preparo sabe que o ultimo quadro dele tem de cair no
## golpe; quem desenhou o tremor do atordoamento sabe que ele nao tem fim
## contratado nenhum. Passar o modo em `encenar()` deixaria dois chamadores
## decidindo diferente para a mesma arte, e o sintoma seria em TELA e nunca no
## console -- a mesma razao que tirou o mapa de angulos de dentro de
## `DadosPersonagem` e o pos em `Direcoes`.

## Contra o que o quadro e escolhido.
##
## A pergunta que separa os tres nao e "progresso ou fps". E: **com o que o
## ultimo quadro tem de coincidir?**
enum Modo {
	## O quadro sai do PROGRESSO do gesto (0..1), e o ultimo cai no fim dele.
	##
	## E o modo do TELEGRAFO, e ele existe por uma medicao: o `PREPARAR` do
	## chefe vale 1,0667 s na fase 1 com a barra zerada e 0,3620 s na fase 3 com
	## ela cheia -- uma faixa de **2,95x**. A duracao de um clipe por fps e
	## constante, e nenhuma constante cabe numa faixa de 2,95x: ela erra numa
	## ponta ou nas duas. Na ponta lenta um clipe de 4 quadros a 9 fps acaba em
	## 42% do estado e congela pelo resto; em laco, ele RE-ARMA o punho 2,4 vezes
	## antes de socar, e ai a animacao mente sobre a CONTAGEM e nao so sobre o
	## tempo.
	PROGRESSO,
	## Corre pelo proprio fps, em laco.
	##
	## Para gesto SEM fim contratado -- o atordoamento acaba porque um timer
	## expirou, e nao porque um gesto terminou. Por progresso, o mesmo tremor
	## tocaria em camera lenta quando a janela e longa, e tremor lento le como
	## "ele esta bem", o oposto do que a melhor janela de dano da luta precisa
	## dizer.
	LACO,
	## Uma vez pelo proprio fps, e SEGURA o ultimo quadro.
	##
	## Para o estado longo cujo "quando" ja e respondido por outro telegrafo. O
	## caso vivo e a Falha do Reator: 2,93 s de preparo na fase 1, com o cerco de
	## `AreaDePerigo` fazendo a contagem regressiva no chao. Por progresso, 4
	## quadros ali rodariam a 1,36 fps -- 0,73 s por quadro, um slideshow.
	UMA_VEZ,
}

## O nome pelo qual o dono pede este gesto.
@export var nome: StringName = &""

## As oito, na ordem canonica de `Direcoes`. Cada entrada e uma FITA horizontal,
## lida por `hframes`, do mesmo jeito que `sprites_andando`.
@export var fitas: Array[Texture2D] = []

@export var quadros: int = 4

## So vale em LACO e UMA_VEZ. Em PROGRESSO quem manda e a duracao do estado, e
## e esse o ponto inteiro do modo.
@export var fps: float = 12.0

@export var modo: Modo = Modo.PROGRESSO

## Toca de tras para a frente, SOBRE AS MESMAS FITAS.
##
## E o que faz um gesto de volta reusar a arte do gesto de ida por ZERO byte: as
## duas entradas apontam para os mesmos `res://`, e o Godot dedupica `Texture2D`
## por `resource_path`. Fica no RECURSO e nao num parametro de `encenar()`
## porque "qual gesto a volta toca" e decisao de arte, e no Inspetor ela fica
## visivel para quem abre o `.tscn`. O preco e a duplicata de `quadros`/`fps`
## poder divergir do original -- e por isso o portao exige que todo clipe
## invertido tenha um par direto com as MESMAS fitas.
@export var invertido: bool = false


## Este clipe esta montado o bastante para desenhar?
##
## Irma de `SpriteDirecional.tem_ciclo()`, e pelo mesmo motivo: quem le nao
## precisa saber que "desmontado" quer dizer lista curta.
func desenhavel() -> bool:
	return nome != &"" and quadros >= 1 and fitas.size() >= Direcoes.TOTAL


## Qual quadro este gesto mostra, dados o progresso e o relogio proprio.
##
## Pura, e por isso o portao a interroga sem montar cena nenhuma. `t` e a
## posicao no relogio do clipe em QUADROS, e so importa nos dois modos que
## correm sozinhos.
func quadro_em(progresso: float, t: float) -> int:
	var q := 0
	match modo:
		Modo.PROGRESSO:
			q = int(clampf(progresso, 0.0, 1.0) * float(quadros))
		Modo.LACO:
			q = int(fposmod(t, float(quadros)))
		Modo.UMA_VEZ:
			q = int(t)
	q = clampi(q, 0, quadros - 1)
	return quadros - 1 - q if invertido else q
