class_name DishScorer
extends RefCounted
## Nota do prato 0–100 (design §4) = round(100 × Σ peso·componente), faixa e erro dominante.

enum Band { GREAT, OK, POOR }

const W_CUT := 0.20
const W_COOK := 0.35
const W_ALIGN := 0.15
const W_ORDER := 0.15
const W_ORDER_MATCH := 0.15
const GREAT_MIN := 80
const OK_MIN := 50
const PENALTY_PER_ITEM := 0.5

## Chaves de erro dominante ("" = nenhum).
const ERR_BURNT := "burnt"
const ERR_FORBIDDEN := "forbidden"
const ERR_MISSING := "missing"
const ERR_ORDER := "order"
const ERR_RAW := "raw"
const ERR_COOK := "cooking"
const ERR_CUT := "cut"
const ERR_ALIGN := "alignment"

## Modelo que volta pela janela, por faixa ("" = o prato como foi).
const RETURN_MODEL: Array[String] = ["plate", "plate_dirty", ""]

var recipe: Recipe


func _init(recipe_data: Recipe = null) -> void:
	recipe = recipe_data if recipe_data != null else Recipe.load_burger()


static func band_of(score: int) -> int:
	if score >= GREAT_MIN:
		return Band.GREAT
	if score >= OK_MIN:
		return Band.OK
	return Band.POOR


## `without` = TicketData.without; `items` = PlateStack.items (de baixo para cima).
## Retorna {score, band, dominant, components: {cut, cook, align, order, order_match}}.
func score(without: Array, items: Array) -> Dictionary:
	var requested := recipe.requested_layers(without)
	# Primeiro item de cada camada pedida presente no prato; sequência de camadas do prato.
	var found := {}
	var plate_layers: Array[String] = []
	var forbidden := 0
	for it: Dictionary in items:
		var layer := recipe.layer_of(it.get("id", ""))
		if layer == "":
			continue
		plate_layers.append(layer)
		if without.has(layer):
			forbidden += 1
		elif not found.has(layer):
			found[layer] = it
	var missing := 0
	for layer in requested:
		if not found.has(layer):
			missing += 1

	var cut := _avg_note(requested, found, recipe.cut_layers, Kitchen.NOTE_CUT)
	var cook := 0.0
	var burnt := false
	var min_side := 1.0
	var patty_present := found.has(recipe.patty)
	if not requested.has(recipe.patty):
		cook = 1.0
	elif patty_present:
		var q: Dictionary = found[recipe.patty].get("quality", {})
		var a: float = q.get(Kitchen.NOTE_SIDE_A, 0.0)
		var b: float = q.get(Kitchen.NOTE_SIDE_B, 0.0)
		cook = (a + b) / 2.0
		min_side = minf(a, b)
		burnt = found[recipe.patty].get("id", "") == Kitchen.BURGER_TRASH \
				or (q.has(Kitchen.NOTE_SIDE_A) and a <= 0.0) or (q.has(Kitchen.NOTE_SIDE_B) and b <= 0.0)
	var align := _avg_note(requested, found, requested, Kitchen.NOTE_ASSEMBLY)
	var order := 1.0
	if not requested.is_empty():
		order = float(_lcs(requested, plate_layers)) / requested.size()
	var order_match := maxf(1.0 - PENALTY_PER_ITEM * (forbidden + missing), 0.0)

	var total := W_CUT * cut + W_COOK * cook + W_ALIGN * align + W_ORDER * order + W_ORDER_MATCH * order_match
	var s := clampi(roundi(100.0 * total), 0, 100)

	var cook_err := ERR_COOK
	if requested.has(recipe.patty):
		if not patty_present:
			cook_err = ERR_MISSING
		elif burnt:
			cook_err = ERR_BURNT
		elif min_side < Kitchen.quality_score(Kitchen.Quality.GOOD) - 0.001:
			cook_err = ERR_RAW
	# Ordem do array = desempate por prioridade.
	var losses := [
		[cook_err, W_COOK * (1.0 - cook)],
		[ERR_FORBIDDEN if forbidden > 0 else ERR_MISSING, W_ORDER_MATCH * (1.0 - order_match)],
		[ERR_ORDER, W_ORDER * (1.0 - order)],
		[ERR_CUT, W_CUT * (1.0 - cut)],
		[ERR_ALIGN, W_ALIGN * (1.0 - align)],
	]
	var dominant := ""
	var best := 0.0005
	for entry: Array in losses:
		if entry[1] > best:
			best = entry[1]
			dominant = entry[0]
	return {
		"score": s,
		"band": band_of(s),
		"dominant": dominant,
		"components": {"cut": cut, "cook": cook, "align": align, "order": order, "order_match": order_match},
	}


static func return_model(band: int) -> String:
	return RETURN_MODEL[band]


## Média da nota `key` sobre as camadas pedidas que estão em `subset`; ausente = 0.
## Sem camadas no subconjunto pedido: 1 (nada a errar).
func _avg_note(requested: Array[String], found: Dictionary, subset: Array[String], key: String) -> float:
	var n := 0
	var sum := 0.0
	for layer in requested:
		if not subset.has(layer):
			continue
		n += 1
		if found.has(layer):
			sum += float(found[layer].get("quality", {}).get(key, 0.0))
	return 1.0 if n == 0 else sum / n


## Maior subsequência comum (posições corretas, aceitando itens fora de ordem/extras).
static func _lcs(a: Array[String], b: Array[String]) -> int:
	var prev := PackedInt32Array()
	var cur := PackedInt32Array()
	prev.resize(b.size() + 1)
	cur.resize(b.size() + 1)
	for i in a.size():
		cur.fill(0)
		for j in b.size():
			if a[i] == b[j]:
				cur[j + 1] = prev[j] + 1
			else:
				cur[j + 1] = maxi(cur[j], prev[j + 1])
		var tmp := prev
		prev = cur
		cur = tmp
	return prev[b.size()]
