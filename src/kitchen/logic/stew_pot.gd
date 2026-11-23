class_name StewPot
extends RefCounted
## Panela do ensopado (decisão 22; m2_turno "Cozinhar simples"): aceita 1 de cada picado;
## com os 3 dentro cozinha sozinha (tick), sem mexer; pronta aos 12 s, rende 2 porções e
## queima se esquecida (18 s depois de pronta). Panela queimada ainda serve, ou esvazia
## com um toque. Tempo por tick(delta); nada é alocado por tick.

enum Stage { EMPTY, FILLING, COOKING, READY, OVERDONE, SCORCHING, BURNT }

const READY_S := 12.0
## Ponto perfeito de READY_S até aqui; depois "bom" até queimar.
const PERFECT_UNTIL_S := 20.0
## Fumaça cinza (quase queimando).
const SCORCHING_S := 25.0
const BURNT_S := 30.0
const PORTIONS := 2

const W_COOK := 0.8
const W_RECIPE := 0.2

const STEW := "food_stew"
const POT_EMPTY := "pot_A"
const POT_STEW := "pot_A_stew"

## Erros dominantes (chaves de gancho em replies.json).
const ERR_BURNT := "stew_burnt"
const ERR_RAW := "stew_raw"
const ERR_COOK := "cooking"
const ERR_MISSING := "missing"

var recipe: Recipe
## Camadas (ids dos picados) já na panela.
var contents: Dictionary = {}
## Porções restantes (0 = vazia ou montando).
var portions: int = 0
## Segundos cozinhando no lote atual.
var cook_time: float = 0.0


func _init(recipe_data: Recipe = null) -> void:
	recipe = recipe_data if recipe_data != null else Recipe.load_stew()


## Qualidade do ponto para t segundos de cozimento (queimado vira CLUMSY, "Ops").
static func quality_for_time(t: float) -> int:
	if t < READY_S or t >= BURNT_S:
		return Kitchen.Quality.CLUMSY
	if t < PERFECT_UNTIL_S:
		return Kitchen.Quality.PERFECT
	return Kitchen.Quality.GOOD


## Nota do ponto (0–1): cru 0,4; perfeito 1; bom 0,7; queimado 0.
static func cook_score_for(t: float) -> float:
	if t >= BURNT_S:
		return Kitchen.SCORE_NONE
	return Kitchen.quality_score(quality_for_time(t))


func is_cooking() -> bool:
	return portions > 0


func is_ready() -> bool:
	return portions > 0 and cook_time >= READY_S


func is_burnt() -> bool:
	return portions > 0 and cook_time >= BURNT_S


func stage() -> int:
	if portions == 0:
		return Stage.EMPTY if contents.is_empty() else Stage.FILLING
	if cook_time >= BURNT_S:
		return Stage.BURNT
	if cook_time >= SCORCHING_S:
		return Stage.SCORCHING
	if cook_time >= PERFECT_UNTIL_S:
		return Stage.OVERDONE
	return Stage.READY if cook_time >= READY_S else Stage.COOKING


## Id do glTF da panela (queimado: a cena escurece o `pot_A_stew`).
func model_id() -> String:
	return POT_STEW if portions > 0 else POT_EMPTY


## Aceita o item? Só picados da receita, 1 de cada, com a panela vazia/montando.
func can_accept(item_id: String) -> bool:
	if portions > 0:
		return false
	var layer := recipe.layer_of(item_id)
	return layer != "" and not contents.has(layer)


## Solta um picado. Com os 3 dentro, começa a cozinhar.
## Retorna false se não cabe (o chamador devolve à tábua).
func add(item_id: String) -> bool:
	if not can_accept(item_id):
		return false
	contents[recipe.layer_of(item_id)] = true
	if contents.size() >= recipe.layers.size():
		portions = PORTIONS
		cook_time = 0.0
	return true


## Avança o cozimento (para em BURNT_S). Retorna true se o estágio mudou.
func tick(delta_s: float) -> bool:
	if portions == 0 or cook_time >= BURNT_S or delta_s <= 0.0:
		return false
	var before := stage()
	cook_time = minf(cook_time + delta_s, BURNT_S)
	return stage() != before


func cook_quality() -> int:
	return quality_for_time(cook_time)


func cook_score() -> float:
	return cook_score_for(cook_time)


## Receita certa: fração das camadas na panela (sempre 1 cozinhando, no M2).
func recipe_score() -> float:
	return float(contents.size()) / maxf(recipe.layers.size(), 1)


## Nota de uma porção agora (sem servir): {score, band, dominant, components, quality}.
func evaluate() -> Dictionary:
	var cook := cook_score()
	var rec := recipe_score()
	var s := clampi(roundi(100.0 * (W_COOK * cook + W_RECIPE * rec)), 0, 100)
	var cook_err := ERR_COOK
	if cook_time >= BURNT_S:
		cook_err = ERR_BURNT
	elif cook_time < READY_S:
		cook_err = ERR_RAW
	var losses := [
		[cook_err, W_COOK * (1.0 - cook)],
		[ERR_MISSING, W_RECIPE * (1.0 - rec)],
	]
	var dominant := ""
	var best := 0.0005
	for entry: Array in losses:
		if entry[1] > best:
			best = entry[1]
			dominant = entry[0]
	return {
		"score": s,
		"band": DishScorer.band_of(s),
		"dominant": dominant,
		"quality": cook_quality(),
		"components": {"cook": cook, "recipe": rec},
	}


## Serve uma tigela (`food_stew`). Retorna {} se não há porção; senão evaluate() +
## {"id": "food_stew"}. A 2ª porção esvazia a panela.
func serve() -> Dictionary:
	if portions == 0:
		return {}
	var res := evaluate()
	res["id"] = STEW
	portions -= 1
	if portions == 0:
		clear()
	return res


func clear() -> void:
	contents.clear()
	portions = 0
	cook_time = 0.0
