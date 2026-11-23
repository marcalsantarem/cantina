class_name DishScorer
extends RefCounted
## Nota do prato 0–100 (decisão 22) = round(100 × Σ peso·componente), faixa e erro dominante.
## Componentes: ponto da carne, receita certa (itens e "sem") e ordem das camadas.

enum Band { GREAT, OK, POOR }

const W_COOK := 0.45
const W_RECIPE := 0.35
const W_ORDER := 0.20
const GREAT_MIN := 80
const OK_MIN := 50
## Cada item faltando ou proibido tira isto da nota de receita (mín. 0).
const PENALTY_PER_ITEM := 0.5

## Chaves de erro dominante ("" = nenhum).
const ERR_BURNT := "burnt"
const ERR_FORBIDDEN := "forbidden"
const ERR_MISSING := "missing"
const ERR_ORDER := "order"
const ERR_RAW := "raw"
const ERR_COOK := "cooking"

## Modelo que volta pela janela, por faixa ("" = o prato como foi).
const RETURN_MODEL: Array[String] = ["plate", "plate_dirty", ""]
## Idem para tigela (ensopado, m2_turno §5).
const RETURN_MODEL_BOWL: Array[String] = ["bowl", "bowl_dirty", ""]

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
## Retorna {score, band, dominant, components: {cook, recipe, order}}.
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

	var cook := 0.0
	var burnt := false
	var patty_present := found.has(recipe.patty)
	if not requested.has(recipe.patty):
		cook = 1.0
	elif patty_present:
		cook = float(found[recipe.patty].get("quality", {}).get(Kitchen.NOTE_COOK, 0.0))
		burnt = found[recipe.patty].get("id", "") == Kitchen.BURGER_TRASH or cook <= 0.0
	var order := 1.0
	if not requested.is_empty():
		order = float(_lcs(requested, plate_layers)) / requested.size()
	var recipe_ok := maxf(1.0 - PENALTY_PER_ITEM * (forbidden + missing), 0.0)

	var total := W_COOK * cook + W_RECIPE * recipe_ok + W_ORDER * order
	var s := clampi(roundi(100.0 * total), 0, 100)

	var cook_err := ERR_COOK
	if requested.has(recipe.patty):
		if not patty_present:
			cook_err = ERR_MISSING
		elif burnt:
			cook_err = ERR_BURNT
		elif cook < Kitchen.quality_score(Kitchen.Quality.GOOD) - 0.001:
			cook_err = ERR_RAW
	# Ordem do array = desempate por prioridade.
	var losses := [
		[cook_err, W_COOK * (1.0 - cook)],
		[ERR_FORBIDDEN if forbidden > 0 else ERR_MISSING, W_RECIPE * (1.0 - recipe_ok)],
		[ERR_ORDER, W_ORDER * (1.0 - order)],
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
		"components": {"cook": cook, "recipe": recipe_ok, "order": order},
	}


static func return_model(band: int) -> String:
	return RETURN_MODEL[band]


## Modelo que volta para um item da receita (tigela no ensopado, prato no resto).
static func return_model_for(recipe_id: String, band: int) -> String:
	return RETURN_MODEL_BOWL[band] if recipe_id == StewPot.STEW else RETURN_MODEL[band]


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
