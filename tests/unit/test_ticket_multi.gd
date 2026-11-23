extends GutTest
## Bilhete multi-item (m2_turno §5): TicketData.items, entrega ao mais antigo que espera
## a receita, nota = média, gancho do pior item ou de demora.

const B := "food_burger"
const S := "food_stew"

var queue: TicketQueue


func before_each() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	queue = TicketQueue.new(rng)
	queue.max_open = TicketQueue.RAIL_SLOTS


func test_spawn_order_creates_items() -> void:
	var t := queue.spawn_order([B, S], 12.0)
	assert_eq(t.items.size(), 2)
	assert_eq(t.item_count(), 2)
	assert_eq(t.recipe, B, "compat: 1º item")
	assert_eq(t.items[1]["recipe"], S)
	assert_eq((t.items[1]["without"] as Array).size(), 0, "ensopado sem 'sem'")
	assert_false(t.items[0]["delivered"])
	assert_eq(t.arrived_s, 12.0)
	assert_eq(t.state, TicketData.State.OPEN)
	assert_ne(t.phrase, "")


func test_legacy_spawn_still_has_one_item() -> void:
	var t := queue.spawn()
	assert_eq(t.items.size(), 1)
	assert_eq(t.items[0]["recipe"], t.recipe)
	assert_eq(t.items[0]["without"], t.without)


func test_max_open_is_configurable() -> void:
	for i in 4:
		assert_not_null(queue.spawn_order([B]))
	assert_null(queue.spawn_order([B]), "4 vagas no trilho")
	var q3 := TicketQueue.new()
	assert_eq(q3.max_open, 3, "M1 continua com 3")


func test_deliver_goes_to_oldest_waiting_that_recipe() -> void:
	var t1 := queue.spawn_order([B], 0.0)
	var t2 := queue.spawn_order([B, S], 5.0)
	assert_eq(queue.deliver(S, 90, "", 20.0), t2, "t1 não espera ensopado")
	assert_false(t2.is_complete())
	assert_eq(queue.deliver(B, 80, "", 25.0), t1)
	assert_true(t1.is_complete())
	assert_eq(t1.state, TicketData.State.SERVED)
	assert_eq(t1.completed_s, 25.0)
	assert_false(queue.open.has(t1), "completo sai do trilho")
	assert_eq(queue.deliver(B, 61, "raw", 30.0), t2)
	assert_true(t2.is_complete())
	assert_eq(t2.score(), 76, "média de 90 e 61 = 75,5")
	assert_eq(t2.wait_s(99.0), 25.0, "espera até o último item")
	assert_eq(queue.open_count(), 0)
	assert_null(queue.deliver(B, 80), "ninguém pediu isso agora")


func test_two_burgers_fill_in_order() -> void:
	var t := queue.spawn_order([B, B], 0.0)
	queue.deliver(B, 50, "burnt", 10.0)
	assert_eq(t.delivered_count(), 1)
	assert_true(t.waits_for(B))
	queue.deliver(B, 90, "", 12.0)
	assert_true(t.is_complete())
	assert_eq(t.worst_index(), 0)


func test_recipe_phrases_for_stew_and_combo() -> void:
	var data := {
		"customers": [{"nickname": "X", "phrases": ["burger"]}],
		"without_phrases": {},
		"recipe_phrases": {"food_stew": ["stew"], "combo": ["combo"]},
	}
	var q := TicketQueue.new(RandomNumberGenerator.new(), data)
	q.max_open = 4
	assert_eq(q.spawn_order([S]).phrase, "stew")
	assert_eq(q.spawn_order([B, S]).phrase, "combo")
	assert_eq(q.spawn_order([B]).phrase, "burger")


func test_data_has_recipe_phrases() -> void:
	assert_gt((queue.recipe_phrases.get("food_stew", []) as Array).size(), 0)
	assert_gt((queue.recipe_phrases.get("combo", []) as Array).size(), 0)


func _done_ticket(scores: Array, dominants: Array) -> TicketData:
	var t := TicketData.new()
	for i in scores.size():
		t.add_item(S if i == 0 else B)
	for i in scores.size():
		t.deliver(i, scores[i], dominants[i], 10.0)
	return t


func test_ticket_hook_worst_item_or_late() -> void:
	var t := _done_ticket([90, 60], ["", "raw"])
	assert_eq(ReplyPicker.ticket_hook(t, 1.0), "raw", "gancho do pior item")
	assert_eq(ReplyPicker.ticket_hook(t, 0.5), "raw", "nota < 80: erro manda")
	var good := _done_ticket([95, 85], ["stew_stir", "cut"])
	assert_eq(ReplyPicker.ticket_hook(good, 0.69), ReplyPicker.HOOK_LATE, "nota >= 80 e demorou")
	assert_eq(ReplyPicker.ticket_hook(good, 0.7), "cut")
	var clean := _done_ticket([70], [""])
	assert_eq(ReplyPicker.ticket_hook(clean, 0.5), ReplyPicker.HOOK_LATE, "sem erro: demora")


func test_pick_ticket_uses_recipe_bands_and_hooks() -> void:
	var data := {
		"bands": {"great": ["g"], "ok": ["o"], "poor": ["p"]},
		"hooks": {"late": ["L"], "stew_raw": ["R"]},
		"recipe_bands": {"food_stew": {"great": ["sg"], "ok": ["so"], "poor": ["sp"]}},
	}
	var picker := ReplyPicker.new(RandomNumberGenerator.new(), data)
	var stew := TicketData.new()
	stew.add_item(S)
	stew.deliver(0, 90, "", 10.0)
	assert_eq(picker.pick_ticket(stew, 1.0), "sg")
	assert_eq(picker.pick_ticket(stew, 0.5), "sg L")
	var combo := _done_ticket([60, 70], ["stew_raw", ""])
	assert_eq(picker.pick_ticket(combo, 1.0), "o R", "combo: frases genéricas")


func test_reply_data_has_m2_hooks() -> void:
	var picker := ReplyPicker.new()
	for key in [StewPot.ERR_BURNT, StewPot.ERR_RAW, StewPot.ERR_STIR, ReplyPicker.HOOK_LATE]:
		assert_true(picker.has_hook(key), key)
	for key in ReplyPicker.BAND_KEYS:
		assert_gt((picker.recipe_bands["food_stew"][key] as Array).size(), 0, key)


func test_return_model_for_bowl() -> void:
	assert_eq(DishScorer.return_model_for(S, DishScorer.Band.OK), "bowl_dirty")
	assert_eq(DishScorer.return_model_for(B, DishScorer.Band.OK), "plate_dirty")
	assert_eq(DishScorer.return_model_for(S, DishScorer.Band.POOR), "")
