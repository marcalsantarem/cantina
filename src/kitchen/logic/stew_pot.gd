class_name StewPot
extends RefCounted
## Panela do ensopado (m2_turno §4.2): aceita 1 de cada picado; com os 3 dentro cozinha
## sozinha (tick), gruda sem mexer, rende 2 porções e queima com g = 1. Panela queimada
## se raspa com 3 voltas. Tempo por tick(delta); nada é alocado por tick.

enum Stage { EMPTY, FILLING, COOKING, READY, STICKING, SCORCHING, BURNT }

const READY_S := 18.0
## Grude por segundo sem mexer: cozinhando e depois de pronto.
const STICK_PER_S_COOKING := 1.0 / 14.0
const STICK_PER_S_READY := 1.0 / 18.0
## Logo depois de pronto, o grude não sobe por isto (descanso, B3 do QA M2).
const READY_REST_S := 6.0
## Cada volta de mexer tira isto de g.
const STIR_RELIEF := 0.35
const STICKING_G := 0.6
const SCORCHING_G := 0.85
const PORTIONS := 2
const SCRAPE_TURNS := 3

const W_CUT := 0.30
const W_COOK := 0.45
const W_STIR := 0.25
## Nota de mexer sem nenhuma volta no lote.
const NO_STIR_SCORE := 0.4

const STEW := "food_stew"
const POT_EMPTY := "pot_A"
const POT_STEW := "pot_A_stew"

## Erros dominantes (chaves de gancho em replies.json).
const ERR_BURNT := "stew_burnt"
const ERR_RAW := "stew_raw"
const ERR_STIR := "stew_stir"
const ERR_COOK := "cooking"
const ERR_CUT := "cut"

var recipe: Recipe
## Camada (id do picado) -> nota de corte (0–1).
var contents: Dictionary = {}
## Porções restantes (0 = vazia ou montando).
var portions: int = 0
## Segundos cozinhando no lote atual.
var cook_time: float = 0.0
## Grude 0–1 e o maior grude do lote.
var stick: float = 0.0
var max_stick: float = 0.0
## Voltas de raspar já feitas na panela queimada.
var scrape_turns: int = 0
var _stir_sum: float = 0.0
var _stir_n: int = 0


func _init(recipe_data: Recipe = null) -> void:
	recipe = recipe_data if recipe_data != null else Recipe.load_stew()


## Nota do cozimento (0–1) para o tempo e o maior grude do lote.
static func cook_score_for(time_s: float, max_g: float) -> float:
	if max_g >= 1.0:
		return Kitchen.SCORE_NONE
	if time_s < READY_S:
		return Kitchen.quality_score(Kitchen.Quality.CLUMSY)
	if max_g <= STICKING_G:
		return Kitchen.quality_score(Kitchen.Quality.PERFECT)
	if max_g <= SCORCHING_G:
		return Kitchen.quality_score(Kitchen.Quality.GOOD)
	return Kitchen.quality_score(Kitchen.Quality.CLUMSY)


func is_cooking() -> bool:
	return portions > 0


func is_ready() -> bool:
	return portions > 0 and cook_time >= READY_S


func is_burnt() -> bool:
	return portions > 0 and stick >= 1.0


func stage() -> int:
	if portions == 0:
		return Stage.EMPTY if contents.is_empty() else Stage.FILLING
	if stick >= 1.0:
		return Stage.BURNT
	if stick >= SCORCHING_G:
		return Stage.SCORCHING
	if stick >= STICKING_G:
		return Stage.STICKING
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


## Solta um picado. `notes` = ChopTarget.notes(). Com os 3 dentro, começa a cozinhar.
## Retorna false se não cabe (o chamador devolve à tábua).
func add(item_id: String, notes: Dictionary) -> bool:
	if not can_accept(item_id):
		return false
	contents[recipe.layer_of(item_id)] = float(notes.get(Kitchen.NOTE_CUT, 0.0))
	if contents.size() >= recipe.layers.size():
		portions = PORTIONS
		cook_time = 0.0
		stick = 0.0
		max_stick = 0.0
		_stir_sum = 0.0
		_stir_n = 0
	return true


## Avança o cozimento. Retorna true se o estágio mudou.
func tick(delta_s: float) -> bool:
	if portions == 0 or stick >= 1.0 or delta_s <= 0.0:
		return false
	var before := stage()
	var t0 := cook_time
	var t1 := cook_time + delta_s
	var rest_end := READY_S + READY_REST_S
	var cooking_s := maxf(minf(t1, READY_S) - t0, 0.0)
	var ready_s := maxf(t1 - maxf(t0, rest_end), 0.0)
	stick += cooking_s * STICK_PER_S_COOKING + ready_s * STICK_PER_S_READY
	if stick >= 1.0 - 0.000001:
		stick = 1.0
	max_stick = maxf(max_stick, stick)
	cook_time += delta_s
	return stage() != before


## Uma volta completa de mexer (`quality` = Kitchen.Quality, de StirGesture).
## Cozinhando: tira 0,35 do grude e conta a nota. Queimada: conta como raspar; na 3ª
## volta a panela esvazia. Retorna true se a volta teve efeito.
func stir(quality: int) -> bool:
	if portions == 0:
		return false
	if stick >= 1.0:
		scrape_turns += 1
		if scrape_turns >= SCRAPE_TURNS:
			clear()
		return true
	stick = maxf(stick - STIR_RELIEF, 0.0)
	_stir_sum += Kitchen.quality_score(quality)
	_stir_n += 1
	return true


func stir_score() -> float:
	return NO_STIR_SCORE if _stir_n == 0 else _stir_sum / _stir_n


func cut_score() -> float:
	if contents.is_empty():
		return 0.0
	var sum := 0.0
	for v: float in contents.values():
		sum += v
	return sum / recipe.layers.size()


func cook_score() -> float:
	return cook_score_for(cook_time, max_stick)


## Nota de uma porção agora (sem servir): {score, band, dominant, components}.
func evaluate() -> Dictionary:
	var cut := cut_score()
	var cook := cook_score()
	var stir_s := stir_score()
	var s := clampi(roundi(100.0 * (W_CUT * cut + W_COOK * cook + W_STIR * stir_s)), 0, 100)
	var cook_err := ERR_COOK
	if max_stick >= 1.0:
		cook_err = ERR_BURNT
	elif cook_time < READY_S:
		cook_err = ERR_RAW
	var losses := [
		[cook_err, W_COOK * (1.0 - cook)],
		[ERR_STIR, W_STIR * (1.0 - stir_s)],
		[ERR_CUT, W_CUT * (1.0 - cut)],
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
		"components": {"cut": cut, "cook": cook, "stir": stir_s},
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
	stick = 0.0
	max_stick = 0.0
	scrape_turns = 0
	_stir_sum = 0.0
	_stir_n = 0
