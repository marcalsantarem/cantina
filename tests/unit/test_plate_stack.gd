extends GutTest
## PlateStack: pão se divide, itens aceitos/recusados, notas de montagem, giro e fechamento.

var plate: PlateStack


func before_each() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	plate = PlateStack.new(Recipe.load_burger(), rng)


func test_bun_splits_on_empty_plate() -> void:
	assert_true(plate.add(Kitchen.BUN, {}, Kitchen.Quality.PERFECT))
	assert_eq(plate.size(), 1)
	assert_eq(plate.ids()[0], Kitchen.BUN_BOTTOM)
	assert_true(plate.bun_top_parked)
	assert_false(plate.add(Kitchen.BUN, {}, Kitchen.Quality.GOOD), "segundo pão recusado")


func test_bun_rejected_on_non_empty_plate() -> void:
	plate.add(Kitchen.CHEESE_SLICE, {}, Kitchen.Quality.GOOD)
	assert_false(plate.can_accept(Kitchen.BUN))


func test_accepts_recipe_items_and_aliases_only() -> void:
	assert_false(plate.add(Kitchen.LETTUCE, {}, Kitchen.Quality.GOOD), "alface inteira não monta")
	assert_false(plate.add(Kitchen.TOMATO_SLICES, {}, Kitchen.Quality.GOOD))
	assert_true(plate.add(Kitchen.BURGER_TRASH, {"lado_a": 0.0, "lado_b": 0.4}, Kitchen.Quality.GOOD))
	assert_true(plate.add(Kitchen.LETTUCE_CHOPPED, {"corte": 0.4}, Kitchen.Quality.GOOD))
	assert_true(plate.add(Kitchen.BURGER_UNCOOKED, {}, Kitchen.Quality.GOOD), "fora de ordem/repetido empilha")
	assert_eq(plate.size(), 3)


func test_notes_keep_steps_and_add_assembly() -> void:
	var notes := {"corte": 0.7}
	plate.add(Kitchen.TOMATO_SLICE, notes, Kitchen.Quality.CLUMSY)
	var q: Dictionary = plate.items[0]["quality"]
	assert_eq(q, {"corte": 0.7, "montagem": 0.4})
	assert_eq(notes, {"corte": 0.7}, "não altera o dicionário de entrada")


func test_tilt_limits_per_quality() -> void:
	var limits := {Kitchen.Quality.PERFECT: 4.0, Kitchen.Quality.GOOD: 12.0, Kitchen.Quality.CLUMSY: 25.0}
	for q: int in limits:
		var max_seen := 0.0
		for i in 200:
			plate.clear()
			plate.add(Kitchen.CHEESE_SLICE, {}, q)
			max_seen = maxf(max_seen, absf(plate.items[0]["tilt_deg"]))
		assert_lte(max_seen, limits[q])
		assert_gt(max_seen, limits[q] * 0.8, "usa a faixa toda")


func test_offset_is_clamped() -> void:
	plate.add(Kitchen.CHEESE_SLICE, {}, Kitchen.Quality.CLUMSY, Vector2(0.1, 0.0))
	assert_almost_eq((plate.items[0]["offset"] as Vector2).length(), 0.03, 0.0001)


func test_bun_top_closes_and_take_all_resets() -> void:
	plate.add(Kitchen.BUN, {}, Kitchen.Quality.PERFECT)
	plate.add(Kitchen.BURGER_COOKED, {}, Kitchen.Quality.PERFECT)
	assert_true(plate.add(Kitchen.BUN_TOP, {}, Kitchen.Quality.GOOD))
	assert_true(plate.closed)
	assert_false(plate.bun_top_parked)
	assert_false(plate.add(Kitchen.CHEESE_SLICE, {}, Kitchen.Quality.GOOD), "fechado não aceita mais")
	assert_eq(plate.top_id(), Kitchen.BUN_TOP)
	var served := plate.take_all()
	assert_eq(served.size(), 3)
	assert_true(plate.is_empty())
	assert_false(plate.closed)
