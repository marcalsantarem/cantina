class_name ChopTarget
extends RefCounted
## Ingrediente na tábua (decisão 22): solto na tábua, pica sozinho em CHOP_S segundos.
## Sem nota de corte. tick(delta) injeta o tempo; nada é alocado por tick.

const CHOP_S := 1.5
## Batidas da faca durante o picar (a cena dá um "toc" em cada).
const BEATS := 4

var raw_id: String = ""
var result_id: String = ""
var carry_id: String = ""
var elapsed: float = 0.0


## `config` = entrada de `Recipe.chop[raw_id]` ({result, carry}).
func _init(ingredient_id: String = "", config: Dictionary = {}) -> void:
	raw_id = ingredient_id
	result_id = config.get("result", "")
	carry_id = config.get("carry", result_id)


static func from_recipe(recipe: Recipe, ingredient_id: String) -> ChopTarget:
	return ChopTarget.new(ingredient_id, recipe.chop.get(ingredient_id, {}))


## Avança o picar. Retorna true numa nova batida da faca (a última = picado).
func tick(delta_s: float) -> bool:
	if is_done() or delta_s <= 0.0:
		return false
	var before := beat()
	elapsed = minf(elapsed + delta_s, CHOP_S)
	return beat() != before


## Batidas já dadas (0..BEATS).
func beat() -> int:
	if is_done():
		return BEATS
	return int(elapsed / CHOP_S * BEATS)


func progress() -> float:
	return elapsed / CHOP_S


func is_done() -> bool:
	return elapsed >= CHOP_S


## Id do glTF do estado visual.
func model_id() -> String:
	return result_id if is_done() else raw_id


## Id do item que o dedo leva ao arrastar da tábua ("" se ainda não está pronto).
func carry_item_id() -> String:
	return carry_id if is_done() else ""
