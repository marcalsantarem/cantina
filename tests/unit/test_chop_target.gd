extends GutTest
## ChopTarget: cortes exigidos, passar do ponto, sessões e nota de corte.

const ALL_BANDS := 31   # 5 faixas
var recipe: Recipe


func before_all() -> void:
	recipe = Recipe.load_burger()


func _cut(t: ChopTarget, n: int, ms: float = 200.0, bands: int = ALL_BANDS) -> void:
	for i in n:
		t.add_cut(ms, bands)


func test_lettuce_states() -> void:
	var t := ChopTarget.from_recipe(recipe, Kitchen.LETTUCE)
	_cut(t, 5)
	assert_eq(t.model_id(), Kitchen.LETTUCE)
	assert_eq(t.carry_item_id(), "", "não está pronta")
	assert_true(t.add_cut(200.0, ALL_BANDS), "6º corte muda o estado")
	assert_eq(t.model_id(), Kitchen.LETTUCE_SLICE)
	assert_eq(t.carry_item_id(), Kitchen.LETTUCE_SLICE)
	assert_eq(t.cut_quality(), Kitchen.Quality.PERFECT)
	_cut(t, 4)
	assert_eq(t.cuts, 10)
	assert_eq(t.model_id(), Kitchen.LETTUCE_SLICE, "10 cortes ainda é fatia")
	assert_true(t.add_cut(200.0, ALL_BANDS))
	assert_eq(t.model_id(), Kitchen.LETTUCE_CHOPPED)
	assert_eq(t.carry_item_id(), Kitchen.LETTUCE_CHOPPED)
	assert_eq(t.cut_quality(), Kitchen.Quality.CLUMSY, "> 10 cortes força desajeitado")
	assert_eq(t.notes(), {"corte": 0.4})


func test_tomato_states() -> void:
	var t := ChopTarget.from_recipe(recipe, Kitchen.TOMATO)
	_cut(t, 5)
	assert_eq(t.model_id(), Kitchen.TOMATO)
	_cut(t, 1)
	assert_eq(t.model_id(), Kitchen.TOMATO_SLICES)
	assert_eq(t.carry_item_id(), Kitchen.TOMATO_SLICE)
	_cut(t, 20)
	assert_eq(t.model_id(), Kitchen.TOMATO_SLICES, "tomate não passa do ponto")
	assert_eq(t.cut_quality(), Kitchen.Quality.PERFECT)


func test_sessions_accumulate_progress() -> void:
	var t := ChopTarget.from_recipe(recipe, Kitchen.TOMATO)
	t.begin_session()
	_cut(t, 3, 200.0, 0b00011)
	t.end_session()
	t.begin_session()
	_cut(t, 3, 200.0, 0b11100)
	t.end_session()
	assert_eq(t.sessions, 2)
	assert_eq(t.cuts, 6)
	assert_eq(t.bands(), 5, "cobertura soma as sessões")
	assert_eq(t.cut_quality(), Kitchen.Quality.PERFECT)


func test_quality_from_rhythm_and_coverage() -> void:
	var t := ChopTarget.from_recipe(recipe, Kitchen.TOMATO)
	for i in 3:
		t.add_cut(100.0, 0b00111)
		t.add_cut(300.0, 0b00111)
	assert_almost_eq(t.cv(), 0.5, 0.0001)
	assert_eq(t.cut_quality(), Kitchen.Quality.GOOD)
	assert_almost_eq(t.cut_score(), 0.7, 0.0001)
	var u := ChopTarget.from_recipe(recipe, Kitchen.TOMATO)
	_cut(u, 6, 200.0, 0b00011)
	assert_eq(u.cut_quality(), Kitchen.Quality.CLUMSY, "40% de cobertura")
