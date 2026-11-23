extends GutTest
## ChopTarget (decisão 22): pica sozinho em 1,5 s, batidas da faca, modelo e item levado.

var recipe: Recipe


func before_all() -> void:
	recipe = Recipe.load_burger()


func test_lettuce_chops_by_itself() -> void:
	var t := ChopTarget.from_recipe(recipe, Kitchen.LETTUCE)
	assert_eq(t.model_id(), Kitchen.LETTUCE)
	assert_eq(t.carry_item_id(), "", "crua não sai da tábua")
	t.tick(1.4)
	assert_false(t.is_done())
	assert_eq(t.model_id(), Kitchen.LETTUCE)
	t.tick(0.1)
	assert_true(t.is_done(), "pronta aos 1,5 s")
	assert_eq(t.model_id(), Kitchen.LETTUCE_SLICE)
	assert_eq(t.carry_item_id(), Kitchen.LETTUCE_SLICE)
	assert_almost_eq(t.progress(), 1.0, 0.0001)


func test_tomato_board_shows_slices_and_carries_one() -> void:
	var t := ChopTarget.from_recipe(recipe, Kitchen.TOMATO)
	t.tick(ChopTarget.CHOP_S)
	assert_eq(t.model_id(), Kitchen.TOMATO_SLICES)
	assert_eq(t.carry_item_id(), Kitchen.TOMATO_SLICE)


func test_beats_then_stops() -> void:
	var t := ChopTarget.from_recipe(Recipe.load_stew(), "food_ingredient_carrot")
	var beats := 0
	for i in 30:
		if t.tick(0.1):
			beats += 1
	assert_eq(beats, ChopTarget.BEATS, "uma batida por quarto do tempo, a última = picado")
	assert_eq(t.model_id(), "food_ingredient_carrot_chopped")
	assert_false(t.tick(1.0), "pronto não muda mais")
	assert_false(t.tick(0.0))
