extends GutTest
## DishScorer (decisão 22): ponto da carne + receita certa (itens e "sem") + ordem;
## ausentes valem 0, faixas e erro dominante.

var scorer: DishScorer


func before_all() -> void:
	scorer = DishScorer.new(Recipe.load_burger())


func _item(id: String, q: Dictionary = {}) -> Dictionary:
	return {"id": id, "quality": q}


func _patty(note: float, id: String = Kitchen.BURGER_COOKED) -> Dictionary:
	return _item(id, {Kitchen.NOTE_COOK: note})


## Hambúrguer completo e perfeito, na ordem.
func _perfect() -> Array:
	return [
		_item(Kitchen.BUN_BOTTOM),
		_patty(1.0),
		_item(Kitchen.CHEESE_SLICE),
		_item(Kitchen.LETTUCE_SLICE),
		_item(Kitchen.TOMATO_SLICE),
		_item(Kitchen.BUN_TOP),
	]


func _expected(cook: float, rec: float, order: float) -> int:
	return roundi(100.0 * (DishScorer.W_COOK * cook + DishScorer.W_RECIPE * rec + DishScorer.W_ORDER * order))


func test_weights_sum_to_one() -> void:
	assert_almost_eq(DishScorer.W_COOK + DishScorer.W_RECIPE + DishScorer.W_ORDER, 1.0, 0.0001)


func test_perfect_dish() -> void:
	var r := scorer.score([], _perfect())
	assert_eq(r["score"], 100)
	assert_eq(r["band"], DishScorer.Band.GREAT)
	assert_eq(r["dominant"], "")


func test_band_limits() -> void:
	assert_eq(DishScorer.band_of(100), DishScorer.Band.GREAT)
	assert_eq(DishScorer.band_of(80), DishScorer.Band.GREAT)
	assert_eq(DishScorer.band_of(79), DishScorer.Band.OK)
	assert_eq(DishScorer.band_of(50), DishScorer.Band.OK)
	assert_eq(DishScorer.band_of(49), DishScorer.Band.POOR)
	assert_eq(DishScorer.band_of(0), DishScorer.Band.POOR)
	assert_eq(DishScorer.return_model(DishScorer.Band.GREAT), "plate")
	assert_eq(DishScorer.return_model(DishScorer.Band.OK), "plate_dirty")
	assert_eq(DishScorer.return_model(DishScorer.Band.POOR), "")


func test_empty_plate_is_zero() -> void:
	var r := scorer.score([], [])
	assert_eq(r["score"], 0)
	assert_eq(r["band"], DishScorer.Band.POOR)
	assert_eq(r["dominant"], DishScorer.ERR_MISSING)


func test_raw_patty_scores_73() -> void:
	var items := _perfect()
	items[1] = _patty(0.4, Kitchen.BURGER_UNCOOKED)
	var r := scorer.score([], items)
	assert_almost_eq(r["components"]["cook"], 0.4, 0.0001)
	assert_eq(r["score"], 73)
	assert_eq(r["band"], DishScorer.Band.OK)
	assert_eq(r["dominant"], DishScorer.ERR_RAW)


func test_good_patty_is_still_great() -> void:
	var items := _perfect()
	items[1] = _patty(0.7)
	var r := scorer.score([], items)
	assert_eq(r["score"], _expected(0.7, 1.0, 1.0))
	assert_eq(r["band"], DishScorer.Band.GREAT)
	assert_eq(r["dominant"], DishScorer.ERR_COOK)


func test_burnt_patty() -> void:
	var items := _perfect()
	items[1] = _patty(0.0, Kitchen.BURGER_TRASH)
	var r := scorer.score([], items)
	assert_eq(r["score"], 55)
	assert_eq(r["dominant"], DishScorer.ERR_BURNT)


func test_forbidden_item() -> void:
	var r := scorer.score([Kitchen.TOMATO_SLICE], _perfect())
	var c: Dictionary = r["components"]
	assert_almost_eq(c["recipe"], 0.5, 0.0001)
	assert_almost_eq(c["order"], 1.0, 0.0001, "item proibido não estraga a ordem")
	assert_eq(r["score"], _expected(1.0, 0.5, 1.0))
	assert_eq(r["dominant"], DishScorer.ERR_FORBIDDEN)


func test_without_respected() -> void:
	var items := _perfect()
	items.remove_at(4)
	var r := scorer.score([Kitchen.TOMATO_SLICE], items)
	assert_eq(r["score"], 100)


func test_out_of_order() -> void:
	var items := _perfect()
	var cheese: Dictionary = items[2]
	items[2] = items[3]
	items[3] = cheese
	var r := scorer.score([], items)
	assert_almost_eq(r["components"]["order"], 5.0 / 6.0, 0.0001)
	assert_eq(r["score"], 97)
	assert_eq(r["dominant"], DishScorer.ERR_ORDER)


func test_missing_patty() -> void:
	var items := _perfect()
	items.remove_at(1)
	var r := scorer.score([], items)
	var c: Dictionary = r["components"]
	assert_eq(c["cook"], 0.0)
	assert_almost_eq(c["recipe"], 0.5, 0.0001)
	assert_eq(r["score"], _expected(0.0, 0.5, 5.0 / 6.0))
	assert_eq(r["band"], DishScorer.Band.POOR)
	assert_eq(r["dominant"], DishScorer.ERR_MISSING)


func test_missing_item_drops_to_ok() -> void:
	var items := _perfect()
	items.remove_at(3)   # sem alface no prato, mas foi pedida
	var r := scorer.score([], items)
	assert_eq(r["score"], _expected(1.0, 0.5, 5.0 / 6.0))
	assert_eq(r["band"], DishScorer.Band.OK)
	assert_eq(r["dominant"], DishScorer.ERR_MISSING)


func test_two_missing_floor_recipe_at_zero() -> void:
	var items := _perfect()
	items.remove_at(4)
	items.remove_at(3)
	items.append(_item(Kitchen.CHEESE_SLICE))
	var r := scorer.score([Kitchen.CHEESE_SLICE], items)
	assert_eq(r["components"]["recipe"], 0.0, "2 faltando + 1 proibido = 0 (mínimo)")


func test_duplicates_count_first() -> void:
	var items := _perfect()
	items.insert(2, _patty(0.0, Kitchen.BURGER_TRASH))
	var r := scorer.score([], items)
	assert_almost_eq(r["components"]["cook"], 1.0, 0.0001, "vale a primeira carne")
	assert_almost_eq(r["components"]["order"], 1.0, 0.0001, "extra não tira posição")
