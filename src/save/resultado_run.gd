class_name ResultadoRun
extends RefCounted
## O resultado de uma run, em forma que sobrevive ao disco.
##
## E a PONTE entre o temporario e o permanente: `DadosRun` acumula durante a
## partida, vira um `ResultadoRun` no fim, e e ele -- e nao a run inteira -- que
## entra no historico do save.
##
## **Nada aqui pode ser Node nem Resource, e essa e a regra que decide o
## desenho.** Guardar o `DadosPersonagem` inteiro em vez do `id` dele pareceria
## conveniente: o terminal de historico teria o nome, a miniatura e a arma de
## graca. E transformaria o save num grafo de recursos -- o arquivo deixaria de
## abrir no dia em que aquele `.tres` mudasse de caminho, e o jogador perderia o
## historico inteiro por causa de uma refatoracao de pasta. O `id` e uma string;
## strings nao se mudam de lugar.
##
## `teste_persistencia.gd` cobra isso serializando e exigindo que so sobrevivam
## tipos primitivos, `Array` e `Dictionary`.

## Identificador da run. Cresce, e e o `#15` que o terminal mostra.
var id: int = 0
## Quando ela terminou, em segundos de Unix. Numero e nao string formatada: o
## formato de data e decisao de APRESENTACAO e muda com o idioma, entao guardar
## "02/09/2026" no save escreveria o idioma de hoje dentro do progresso.
var data: int = 0
## O `id` do personagem, nunca o recurso.
var personagem: String = ""
var duracao: float = 0.0
var andar_alcancado: int = 1
var kills: int = 0
var dano_causado: int = 0
var dano_recebido: int = 0
var venceu: bool = false
## Por que a run acabou: "morte", "chefe", "saiu". Texto e nao enum, e aqui a
## razao e a oposta da regra que vale para os `.tres`: enum gravado como INT
## quebra em silencio se alguem inserir um valor no meio da lista, e o save e
## exatamente o arquivo que nao pode reinterpretar dado antigo.
var motivo_fim: String = ""
var itens_principais: Array[String] = []
var arma_final: String = ""


## O que vai para o JSON.
func para_dicionario() -> Dictionary:
	return {
		"id": id,
		"data": data,
		"personagem": personagem,
		"duracao": duracao,
		"andar_alcancado": andar_alcancado,
		"kills": kills,
		"dano_causado": dano_causado,
		"dano_recebido": dano_recebido,
		"venceu": venceu,
		"motivo_fim": motivo_fim,
		"itens_principais": itens_principais,
		"arma_final": arma_final,
	}


## O caminho de volta, e TODO campo tem default.
##
## Nunca `dados["kills"]`: um save escrito por uma versao que nao tinha aquele
## campo faria o jogo estourar ao abrir o historico, e o jogador nao tem como
## saber que o problema e uma chave que faltou.
static func de_dicionario(dados: Dictionary) -> ResultadoRun:
	var r := ResultadoRun.new()
	r.id = int(dados.get("id", 0))
	r.data = int(dados.get("data", 0))
	r.personagem = str(dados.get("personagem", ""))
	r.duracao = float(dados.get("duracao", 0.0))
	r.andar_alcancado = int(dados.get("andar_alcancado", 1))
	r.kills = int(dados.get("kills", 0))
	r.dano_causado = int(dados.get("dano_causado", 0))
	r.dano_recebido = int(dados.get("dano_recebido", 0))
	r.venceu = bool(dados.get("venceu", false))
	r.motivo_fim = str(dados.get("motivo_fim", ""))
	var itens: Array[String] = []
	for item in dados.get("itens_principais", []):
		itens.append(str(item))
	r.itens_principais = itens
	r.arma_final = str(dados.get("arma_final", ""))
	return r
