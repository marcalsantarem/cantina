extends GutTest
## TicketQueue: até 3 abertos, 6 s após vaga, sem expirar, variação `without` 70/10/10/10.

var queue: TicketQueue


func before_each() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	queue = TicketQueue.new(rng)


func test_arrivals_every_6s_up_to_3() -> void:
	queue.tick(5.75)
	assert_eq(queue.open_count(), 0)
	queue.tick(0.25)
	assert_eq(queue.open_count(), 1, "chega aos 6 s")
	queue.tick(6.0)
	queue.tick(6.0)
	assert_eq(queue.open_count(), 3)
	queue.tick(60.0)
	assert_eq(queue.open_count(), 3, "máximo 3")
	assert_eq(queue.time_to_next(), INF)


func test_new_ticket_6s_after_vacancy_and_fifo() -> void:
	queue.tick(18.0)
	queue.tick(100.0)   # cheia: o tempo não acumula
	var first := queue.serve_oldest()
	assert_eq(first.id, 1)
	assert_eq(first.state, TicketData.State.SERVED)
	assert_eq(queue.oldest().id, 2)
	queue.tick(5.9)
	assert_eq(queue.open_count(), 2)
	queue.tick(0.1)
	assert_eq(queue.open_count(), 3)
	assert_eq(queue.open[-1].id, 4)


func test_tickets_never_expire() -> void:
	queue.tick(18.0)
	queue.tick(10000.0)
	assert_eq(queue.open_count(), 3)
	for t in queue.open:
		assert_eq(t.state, TicketData.State.OPEN)


func test_without_roll_limits() -> void:
	assert_eq(TicketQueue.without_for_roll(0.0).size(), 0)
	assert_eq(TicketQueue.without_for_roll(0.6999).size(), 0)
	assert_eq(TicketQueue.without_for_roll(0.7)[0], Kitchen.CHEESE_SLICE)
	assert_eq(TicketQueue.without_for_roll(0.7999)[0], Kitchen.CHEESE_SLICE)
	assert_eq(TicketQueue.without_for_roll(0.8)[0], Kitchen.LETTUCE_SLICE)
	assert_eq(TicketQueue.without_for_roll(0.8999)[0], Kitchen.LETTUCE_SLICE)
	assert_eq(TicketQueue.without_for_roll(0.9)[0], Kitchen.TOMATO_SLICE)
	assert_eq(TicketQueue.without_for_roll(0.9999)[0], Kitchen.TOMATO_SLICE)


func test_without_distribution() -> void:
	var counts := {"": 0, Kitchen.CHEESE_SLICE: 0, Kitchen.LETTUCE_SLICE: 0, Kitchen.TOMATO_SLICE: 0}
	var n := 20000
	for i in n:
		var w := queue.roll_without()
		counts["" if w.is_empty() else w[0]] += 1
	assert_almost_eq(counts[""] / float(n), 0.7, 0.015)
	for k in [Kitchen.CHEESE_SLICE, Kitchen.LETTUCE_SLICE, Kitchen.TOMATO_SLICE]:
		assert_almost_eq(counts[k] / float(n), 0.1, 0.01)


func test_ticket_fields_and_phrases() -> void:
	watch_signals(queue)
	for i in 30:
		var t := queue.spawn()
		assert_ne(t.nickname, "")
		assert_ne(t.phrase, "")
		assert_eq(t.recipe, "food_burger")
		if not t.without.is_empty():
			var pool: Array = queue.without_phrases[t.without[0]]
			assert_has(pool, t.phrase, "frase do 'sem' cita o item")
		queue.serve_oldest()
	assert_signal_emit_count(queue, "ticket_arrived", 30)


func test_open_tickets_have_distinct_customers() -> void:
	for i in 50:
		queue.spawn()
		queue.spawn()
		queue.spawn()
		var nicks := {}
		for t in queue.open:
			nicks[t.nickname] = true
		assert_eq(nicks.size(), 3)
		queue.open.clear()


func test_data_has_enough_customers() -> void:
	assert_gte(queue.customers.size(), 8)
	for key in TicketQueue.WITHOUT_OPTIONS:
		assert_true(queue.without_phrases.has(key), key)
