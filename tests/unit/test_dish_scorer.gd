extends GutTest
## DishScorer: 5 pesos, ausentes valem 0, `without`, ordem, faixas e erro dominante.

var scorer: DishScorer


func before_all() -> void:
	scorer = DishScorer.new(Recipe.load_burger())


func _item(id: String, q: Dictionary = {}) -> Dictionary:
	var notes := {"montagem": 1.0}
	notes.merge(q, true)
	return {"id": id, "quality": notes}


## Hambúrguer completo e perfeito, na ordem.
func _perfect() -> Array:
	return [
		_item(Kitchen.BUN_BOTTOM),
		_item(Kitchen.BURGER_COOKED, {"lado_a": 1.0, "lado_b": 1.0}),
		_item(Kitchen.CHEESE_SLICE),
		_item(Kitchen.LETTUCE_SLICE, {"corte": 1.0}),
		_item(Kitchen.TOMATO_SLICE, {"corte": 1.0}),
		_item(Kitchen.BUN_TOP),
	]


func test_weights_sum_to_one() -> void:
	assert_almost_eq(DishScorer.W_CUT + DishScorer.W_COOK + DishScorer.W_ALIGN + DishScorer.W_ORDER + DishScorer.W_ORDER_MATCH, 1.0, 0.0001)


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


func test_raw_patty_scores_79() -> void:
	var items := _perfect()
	items[1] = _item(Kitchen.BURGER_UNCOOKED, {"lado_a": 0.4, "lado_b": 0.4})
	var r := scorer.score([], items)
	assert_almost_eq(r["components"]["cook"], 0.4, 0.0001)
	assert_eq(r["score"], 79)
	assert_eq(r["band"], DishScorer.Band.OK)
	assert_eq(r["dominant"], DishScorer.ERR_RAW)


func test_burnt_side() -> void:
	var items := _perfect()
	items[1] = _item(Kitchen.BURGER_TRASH, {"lado_a": 0.7, "lado_b": 0.0})
	var r := scorer.score([], items)
	assert_eq(r["score"], 77)
	assert_eq(r["dominant"], DishScorer.ERR_BURNT)


func test_forbidden_item() -> void:
	var items := _perfect()
	items[2] = _item(Kitchen.CHEESE_SLICE, {"montagem": 0.7})
	var r := scorer.score([Kitchen.TOMATO_SLICE], items)
	var c: Dictionary = r["components"]
	assert_almost_eq(c["order_match"], 0.5, 0.0001)
	assert_almost_eq(c["order"], 1.0, 0.0001, "item proibido não estraga a ordem")
	assert_almost_eq(c["align"], 0.94, 0.0001)
	assert_almost_eq(c["cut"], 1.0, 0.0001, "só a alface é pedida")
	assert_eq(r["score"], 92)
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
	items[5] = _item(Kitchen.BUN_TOP, {"montagem": 0.7})
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
	assert_almost_eq(c["align"], 5.0 / 6.0, 0.0001)
	assert_almost_eq(c["order_match"], 0.5, 0.0001)
	assert_eq(r["band"], DishScorer.Band.OK)
	assert_eq(r["dominant"], DishScorer.ERR_MISSING)


func test_missing_cut_item_counts_zero() -> void:
	var items := _perfect()
	items.remove_at(3)   # sem alface no prato, mas foi pedida
	var r := scorer.score([], items)
	assert_almost_eq(r["components"]["cut"], 0.5, 0.0001)


func test_two_missing_floor_order_match_at_zero() -> void:
	var items := _perfect()
	items.remove_at(4)
	items.remove_at(3)
	items.append(_item(Kitchen.CHEESE_SLICE))
	var r := scorer.score([Kitchen.CHEESE_SLICE], items)
	assert_eq(r["components"]["order_match"], 0.0, "2 faltando + 1 proibido = 0 (mínimo)")


func test_duplicates_and_aliases() -> void:
	var items := _perfect()
	items[3] = _item(Kitchen.LETTUCE_CHOPPED, {"corte": 0.4})
	items.insert(2, _item(Kitchen.BURGER_COOKED, {"lado_a": 0.0, "lado_b": 0.0}))
	var r := scorer.score([], items)
	assert_almost_eq(r["components"]["cook"], 1.0, 0.0001, "vale a primeira carne")
	assert_almost_eq(r["components"]["cut"], 0.7, 0.0001, "alface picada demais conta como alface")
	assert_almost_eq(r["components"]["order"], 1.0, 0.0001, "extra não tira posição")
