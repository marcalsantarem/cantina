extends GutTest
## StewPot (decisão 22): montar, cozinha sozinha sem mexer, pronta aos 12 s, queima 18 s
## depois, 2 porções e nota pelo ponto + receita.

const CARROT := "food_ingredient_carrot_chopped"
const POTATO := "food_ingredient_potato_chopped"
const ONION := "food_ingredient_onion_chopped"

var pot: StewPot


func before_each() -> void:
	pot = StewPot.new()


func _fill() -> void:
	for id in [CARROT, POTATO, ONION]:
		assert_true(pot.add(id), id)


func test_weights_sum_to_one() -> void:
	assert_almost_eq(StewPot.W_COOK + StewPot.W_RECIPE, 1.0, 0.0001)


func test_accepts_one_of_each_chopped() -> void:
	assert_eq(pot.stage(), StewPot.Stage.EMPTY)
	assert_false(pot.can_accept("food_ingredient_carrot"), "cru não entra")
	assert_false(pot.can_accept(Kitchen.TOMATO_SLICE))
	assert_true(pot.add(CARROT))
	assert_false(pot.add(CARROT), "repetido volta à tábua")
	assert_eq(pot.stage(), StewPot.Stage.FILLING)
	pot.tick(30.0)
	assert_eq(pot.cook_time, 0.0, "montando não cozinha")
	pot.add(POTATO)
	pot.add(ONION)
	assert_eq(pot.portions, 2)
	assert_eq(pot.stage(), StewPot.Stage.COOKING)
	assert_eq(pot.model_id(), "pot_A_stew")
	assert_false(pot.can_accept(CARROT), "cozinhando não aceita")


func test_stages_by_time() -> void:
	_fill()
	pot.tick(11.9)
	assert_false(pot.is_ready())
	assert_true(pot.tick(0.1), "estágio mudou")
	assert_true(pot.is_ready(), "pronta aos 12 s, sem mexer")
	assert_eq(pot.stage(), StewPot.Stage.READY)
	pot.tick(8.0)
	assert_eq(pot.stage(), StewPot.Stage.OVERDONE)
	pot.tick(5.0)
	assert_eq(pot.stage(), StewPot.Stage.SCORCHING)
	pot.tick(4.9)
	assert_false(pot.is_burnt())
	pot.tick(0.1)
	assert_true(pot.is_burnt(), "queima 18 s depois de pronta")
	assert_eq(pot.stage(), StewPot.Stage.BURNT)
	pot.tick(10.0)
	assert_eq(pot.cook_time, StewPot.BURNT_S, "trava")


func test_quality_table() -> void:
	assert_eq(StewPot.quality_for_time(5.0), Kitchen.Quality.CLUMSY, "crua")
	assert_eq(StewPot.quality_for_time(12.0), Kitchen.Quality.PERFECT)
	assert_eq(StewPot.quality_for_time(19.9), Kitchen.Quality.PERFECT)
	assert_eq(StewPot.quality_for_time(20.0), Kitchen.Quality.GOOD)
	assert_eq(StewPot.quality_for_time(30.0), Kitchen.Quality.CLUMSY, "queimada")
	assert_eq(StewPot.cook_score_for(5.0), 0.4)
	assert_eq(StewPot.cook_score_for(27.0), 0.7)
	assert_eq(StewPot.cook_score_for(30.0), 0.0)


func test_perfect_serve() -> void:
	_fill()
	pot.tick(13.0)
	var res := pot.serve()
	assert_eq(res["id"], "food_stew")
	assert_eq(res["score"], 100)
	assert_eq(res["quality"], Kitchen.Quality.PERFECT)
	assert_eq(res["dominant"], "")


func test_overdone_is_good() -> void:
	_fill()
	pot.tick(25.0)
	var res := pot.serve()
	# ponto 0,7 × 0,8 + receita 0,2 = 76.
	assert_eq(res["score"], 76)
	assert_eq(res["quality"], Kitchen.Quality.GOOD)
	assert_eq(res["dominant"], StewPot.ERR_COOK)


func test_serve_before_ready_is_raw() -> void:
	_fill()
	pot.tick(5.0)
	var res := pot.serve()
	# 0,4 × 0,8 + 0,2 = 52.
	assert_eq(res["score"], 52)
	assert_eq(res["dominant"], StewPot.ERR_RAW)
	assert_eq(res["quality"], Kitchen.Quality.CLUMSY)
	assert_eq(pot.portions, 1)


func test_burnt_serves_with_burnt_hook() -> void:
	_fill()
	pot.tick(40.0)
	var res := pot.serve()
	assert_eq(res["score"], 20)
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


func test_clear_empties_burnt_pot() -> void:
	_fill()
	pot.tick(40.0)
	pot.clear()
	assert_eq(pot.stage(), StewPot.Stage.EMPTY)
	assert_eq(pot.portions, 0)
	assert_eq(pot.cook_time, 0.0)


func test_stew_recipe_chop_config() -> void:
	var r := Recipe.load_stew()
	assert_eq(r.id, "food_stew")
	assert_eq(r.layers, [CARROT, POTATO, ONION])
	for raw: String in ["food_ingredient_carrot", "food_ingredient_potato", "food_ingredient_onion"]:
		var c := ChopTarget.from_recipe(r, raw)
		c.tick(ChopTarget.CHOP_S)
		assert_true(c.is_done(), raw)
		assert_eq(c.carry_item_id(), raw + "_chopped")
	assert_eq(r.crate_item("carrot"), "food_ingredient_carrot")
	assert_eq(r.crate_item("potato"), "food_ingredient_potato")
	assert_eq(r.crate_item("onion"), "food_ingredient_onion")
