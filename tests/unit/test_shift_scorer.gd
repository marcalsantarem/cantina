extends GutTest
## ShiftScorer (m2_turno §2, §3): agilidade, humor, S, estrelas e resumo do turno.


func _ticket(scores: Array, arrived: float, completed: float, reply := "") -> TicketData:
	var t := TicketData.new()
	for i in scores.size():
		t.add_item("food_burger")
	t.arrived_s = arrived
	for i in scores.size():
		if scores[i] >= 0:
			t.deliver(i, scores[i], "", completed)
	t.reply = reply
	return t


func test_agility_curve() -> void:
	assert_eq(ShiftScorer.agility(30.0, 1), 1.0)
	assert_almost_eq(ShiftScorer.agility(60.0, 1), 0.65, 0.0001)
	assert_almost_eq(ShiftScorer.agility(90.0, 1), 0.3, 0.0001)
	assert_almost_eq(ShiftScorer.agility(300.0, 1), 0.3, 0.0001)
	assert_eq(ShiftScorer.agility(50.0, 2), 1.0, "2 itens: T = 50")
	assert_almost_eq(ShiftScorer.agility(80.0, 2), 0.65, 0.0001)


func test_mood() -> void:
	assert_eq(ShiftScorer.mood(30.0, 1), ShiftScorer.Mood.CONTENT)
	assert_eq(ShiftScorer.mood(60.0, 1), ShiftScorer.Mood.IMPATIENT)
	assert_eq(ShiftScorer.mood(60.5, 1), ShiftScorer.Mood.HUNGRY)
	assert_eq(ShiftScorer.mood(80.0, 2), ShiftScorer.Mood.IMPATIENT)
	assert_eq(ShiftScorer.mood(81.0, 2), ShiftScorer.Mood.HUNGRY)


func test_ticket_mood_uses_now_while_open() -> void:
	var t := _ticket([-1], 10.0, 0.0)
	assert_eq(ShiftScorer.ticket_mood(t, 40.0), ShiftScorer.Mood.CONTENT)
	assert_eq(ShiftScorer.ticket_mood(t, 60.0), ShiftScorer.Mood.IMPATIENT)
	assert_eq(ShiftScorer.ticket_mood(t, 80.0), ShiftScorer.Mood.HUNGRY)


func test_shift_score_references() -> void:
	assert_almost_eq(ShiftScorer.shift_score(80, 90, 80), 82.5, 0.001)
	assert_almost_eq(ShiftScorer.shift_score(65, 70, 60), 65.5, 0.001)
	assert_almost_eq(ShiftScorer.shift_score(60, 40, 40), 52.0, 0.001)
	assert_eq(ShiftScorer.stars_for(82.5), 3)
	assert_eq(ShiftScorer.stars_for(65.5), 2)
	assert_eq(ShiftScorer.stars_for(52.0), 1)
	assert_eq(ShiftScorer.stars_for(60.0), 2)
	assert_eq(ShiftScorer.stars_for(80.0), 3)
	assert_eq(ShiftScorer.stars_for(0.0), 1, "1 estrela sempre")


func test_stars_need_service() -> void:
	assert_eq(ShiftScorer.stars_for(90.0, 49.0), 1, "★★ pede A ≥ 50")
	assert_eq(ShiftScorer.stars_for(90.0, 50.0), 2)
	assert_eq(ShiftScorer.stars_for(90.0, 74.0), 2, "★★★ pede A ≥ 75")
	assert_eq(ShiftScorer.stars_for(80.0, 75.0), 3)
	assert_eq(ShiftScorer.stars_for(59.0, 100.0), 1)


func test_one_perfect_dish_while_idle_is_one_star() -> void:
	# QA M2, T4: 1 ensopado perfeito e rápido, 4 bilhetes abertos e 5 seguradas.
	var tickets := [_ticket([100], 3.0, 20.0, "A")]
	for i in 4:
		tickets.append(_ticket([-1], 25.0 + i, 0.0))
	var r := ShiftScorer.summarize(tickets, 5)
	assert_almost_eq(r["service"], 10.0, 0.001, "1 de 5 + 5 seguradas")
	assert_eq(r["items_held"], 5)
	assert_eq(r["stars"], 1)


func test_agility_word() -> void:
	assert_eq(ShiftScorer.agility_word(80.0), "Ágil")
	assert_eq(ShiftScorer.agility_word(79.9), "No ritmo")
	assert_eq(ShiftScorer.agility_word(50.0), "No ritmo")
	assert_eq(ShiftScorer.agility_word(49.9), "Sem pressa")


func test_summarize() -> void:
	var t1 := _ticket([90], 0.0, 30.0, "A")
	var t2 := _ticket([70, -1], 10.0, 50.0)       # aberto, 1 de 2 entregue
	var t3 := _ticket([60], 20.0, 80.0, "B")      # espera 60 -> 0,65
	var r := ShiftScorer.summarize([t1, t2, t3])
	assert_eq(r["served"], 2)
	assert_eq(r["arrived"], 3)
	assert_eq(r["items_total"], 4)
	assert_eq(r["items_delivered"], 3)
	assert_almost_eq(r["quality"], 75.0, 0.001)
	assert_almost_eq(r["service"], 75.0, 0.001)
	assert_almost_eq(r["agility"], 82.5, 0.001)
	assert_almost_eq(r["score"], 76.125, 0.001)
	assert_eq(r["stars"], 2)
	assert_eq(r["avg_score"], 75)
	assert_eq(r["agility_word"], "Ágil")
	assert_eq(r["best_reply"], "A")


func test_summarize_empty_day() -> void:
	var r := ShiftScorer.summarize([])
	assert_eq(r["score"], 0.0)
	assert_eq(r["stars"], 1)
	assert_eq(r["best_reply"], "")
	assert_eq(r["agility_word"], "Sem pressa")
