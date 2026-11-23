extends GutTest
## StewPot (m2_turno §4.2): montar, grude, mexer, pronto aos 18 s, 2 porções, raspar e nota.

const CARROT := "food_ingredient_carrot_chopped"
const POTATO := "food_ingredient_potato_chopped"
const ONION := "food_ingredient_onion_chopped"

var pot: StewPot


func before_each() -> void:
	pot = StewPot.new()


func _fill(cut := 1.0) -> void:
	for id in [CARROT, POTATO, ONION]:
		assert_true(pot.add(id, {Kitchen.NOTE_CUT: cut}), id)


func test_accepts_one_of_each_chopped() -> void:
	assert_eq(pot.stage(), StewPot.Stage.EMPTY)
	assert_false(pot.can_accept("food_ingredient_carrot"), "cru não entra")
	assert_false(pot.can_accept(Kitchen.TOMATO_SLICE))
	assert_true(pot.add(CARROT, {Kitchen.NOTE_CUT: 1.0}))
	assert_false(pot.add(CARROT, {Kitchen.NOTE_CUT: 1.0}), "repetido volta à tábua")
	assert_eq(pot.stage(), StewPot.Stage.FILLING)
	pot.tick(30.0)
	assert_eq(pot.stick, 0.0, "montando não gruda")
	pot.add(POTATO, {})
	pot.add(ONION, {})
	assert_eq(pot.portions, 2)
	assert_eq(pot.stage(), StewPot.Stage.COOKING)
	assert_eq(pot.model_id(), "pot_A_stew")
	assert_false(pot.can_accept(CARROT), "cozinhando não aceita")


func test_burns_at_14s_without_stirring() -> void:
	_fill()
	pot.tick(8.5)
	assert_eq(pot.stage(), StewPot.Stage.STICKING)
	pot.tick(3.5)
	assert_eq(pot.stage(), StewPot.Stage.SCORCHING)
	pot.tick(1.9)
	assert_false(pot.is_burnt())
	assert_true(pot.tick(0.1), "estágio mudou")
	assert_true(pot.is_burnt())
	assert_eq(pot.stage(), StewPot.Stage.BURNT)
	pot.tick(5.0)
	assert_eq(pot.stick, 1.0, "trava em 1")


func test_stir_relieves_and_ready_at_18s() -> void:
	_fill()
	for i in 4:
		pot.tick(4.0)
		pot.stir(Kitchen.Quality.PERFECT)
	assert_eq(pot.stick, 0.0, "mínimo 0")
	assert_false(pot.is_ready())
	pot.tick(2.0)
	assert_true(pot.is_ready())
	assert_eq(pot.stage(), StewPot.Stage.READY)
	var res := pot.serve()
	assert_eq(res["id"], "food_stew")
	assert_eq(res["score"], 100)
	assert_eq(res["dominant"], "")


func test_stick_rate_changes_when_ready() -> void:
	_fill()
	pot.cook_time = 17.0
	pot.tick(2.0)
	assert_almost_eq(pot.stick, 1.0 / 14.0 + 1.0 / 10.0, 0.0001)


func test_stir_reduces_035() -> void:
	_fill()
	pot.tick(7.0)
	pot.stir(Kitchen.Quality.GOOD)
	assert_almost_eq(pot.stick, 0.5 - 0.35, 0.0001)
	assert_almost_eq(pot.max_stick, 0.5, 0.0001)
	assert_almost_eq(pot.stir_score(), 0.7, 0.0001)


func test_cook_score_table() -> void:
	assert_eq(StewPot.cook_score_for(10.0, 0.2), 0.4, "antes de pronto: desajeitado")
	assert_eq(StewPot.cook_score_for(18.0, 0.6), 1.0)
	assert_eq(StewPot.cook_score_for(18.0, 0.61), 0.7)
	assert_eq(StewPot.cook_score_for(18.0, 0.85), 0.7)
	assert_eq(StewPot.cook_score_for(18.0, 0.9), 0.4)
	assert_eq(StewPot.cook_score_for(18.0, 1.0), 0.0)
	assert_eq(StewPot.cook_score_for(5.0, 1.0), 0.0, "queimado antes de pronto")


func test_serve_before_ready_is_raw() -> void:
	_fill()
	pot.tick(5.0)
	var res := pot.serve()
	# corte 1,0; cozimento 0,4; mexer 0,4 (nenhuma volta): 30 + 18 + 10 = 58.
	assert_eq(res["score"], 58)
	assert_eq(res["dominant"], StewPot.ERR_RAW)
	assert_eq(pot.portions, 1)


func test_burnt_serves_with_burnt_hook() -> void:
	_fill(0.7)
	pot.tick(20.0)
	var res := pot.serve()
	# corte 0,7; cozimento 0; mexer 0,4: 21 + 0 + 10 = 31.
	assert_eq(res["score"], 31)
	assert_eq(res["dominant"], StewPot.ERR_BURNT)
	assert_eq(res["band"], DishScorer.Band.POOR)


func test_two_portions_then_empty() -> void:
	_fill()
	pot.tick(1.0)
	assert_false(pot.serve().is_empty())
	assert_eq(pot.model_id(), "pot_A_stew")
	assert_false(pot.serve().is_empty())
	assert_eq(pot.stage(), StewPot.Stage.EMPTY)
	assert_eq(pot.model_id(), "pot_A")
	assert_true(pot.serve().is_empty())
	assert_true(pot.can_accept(CARROT), "pode montar de novo")


func test_scrape_burnt_with_3_turns() -> void:
	_fill()
	pot.tick(15.0)
	assert_true(pot.is_burnt())
	assert_true(pot.stir(Kitchen.Quality.PERFECT))
	pot.stir(Kitchen.Quality.PERFECT)
	assert_eq(pot.stick, 1.0, "mexer não desqueima")
	assert_eq(pot.stage(), StewPot.Stage.BURNT)
	pot.stir(Kitchen.Quality.CLUMSY)
	assert_eq(pot.stage(), StewPot.Stage.EMPTY)
	assert_eq(pot.portions, 0)


func test_stir_on_empty_does_nothing() -> void:
	assert_false(pot.stir(Kitchen.Quality.PERFECT))


func test_stew_recipe_chop_config() -> void:
	var r := Recipe.load_stew()
	assert_eq(r.id, "food_stew")
	assert_eq(r.layers, [CARROT, POTATO, ONION])
	var expected := {"food_ingredient_carrot": 5, "food_ingredient_potato": 5, "food_ingredient_onion": 6}
	for raw: String in expected:
		var c := ChopTarget.from_recipe(r, raw)
		assert_eq(c.cuts_required, expected[raw], raw)
		for i in expected[raw]:
			c.add_cut(200, 1)
		assert_true(c.is_done())
		assert_eq(c.carry_item_id(), raw + "_chopped")
	assert_eq(r.crate_item("carrots"), "food_ingredient_carrot")
	assert_eq(r.crate_item("potatoes"), "food_ingredient_potato")
	assert_eq(r.crate_item("onions"), "food_ingredient_onion")


func test_more_than_9_cuts_forces_clumsy() -> void:
	var c := ChopTarget.from_recipe(Recipe.load_stew(), "food_ingredient_carrot")
	for i in 9:
		c.add_cut(200, 31)
	assert_eq(c.cut_quality(), Kitchen.Quality.PERFECT)
	c.add_cut(200, 31)
	assert_eq(c.cut_quality(), Kitchen.Quality.CLUMSY)
	assert_eq(c.carry_item_id(), "food_ingredient_carrot_chopped", "continua picado")
