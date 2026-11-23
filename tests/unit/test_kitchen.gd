extends GutTest
## Kitchen (qualidade e rótulos) e Recipe (dados do hambúrguer).


func test_quality_labels_and_scores() -> void:
	assert_eq(Kitchen.quality_label(Kitchen.Quality.CLUMSY), "Ops")
	assert_eq(Kitchen.quality_label(Kitchen.Quality.GOOD), "Bom")
	assert_eq(Kitchen.quality_label(Kitchen.Quality.PERFECT), "Perfeito!")
	assert_eq(Kitchen.quality_score(Kitchen.Quality.CLUMSY), 0.4)
	assert_eq(Kitchen.quality_score(Kitchen.Quality.GOOD), 0.7)
	assert_eq(Kitchen.quality_score(Kitchen.Quality.PERFECT), 1.0)


func test_burger_recipe_data() -> void:
	var r := Recipe.load_burger()
	assert_eq(r.id, "food_burger")
	assert_eq(r.layers.size(), 6)
	assert_eq(r.layers[0], Kitchen.BUN_BOTTOM)
	assert_eq(r.layers[5], Kitchen.BUN_TOP)
	assert_eq(r.layer_of(Kitchen.BURGER_TRASH), Kitchen.BURGER_COOKED)
	assert_eq(r.layer_of(Kitchen.LETTUCE), "")
	assert_eq(r.crate_item("burger"), Kitchen.BURGER_UNCOOKED)
	assert_eq(r.crate_item("cheese"), Kitchen.CHEESE_SLICE)
	assert_eq(r.chop[Kitchen.LETTUCE]["result"], Kitchen.LETTUCE_SLICE)
	assert_eq(r.chop[Kitchen.TOMATO]["carry"], Kitchen.TOMATO_SLICE)
	assert_eq(r.requested_layers([Kitchen.TOMATO_SLICE]).size(), 5)
