extends GutTest
## ShiftClock (m2_turno §1): fases, chegadas, espera de vaga + 4 s, mistura, fim aos 180 s.

var clock: ShiftClock


func before_each() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	clock = ShiftClock.new(rng)


func _arrival_times(step: float) -> Array[float]:
	var out: Array[float] = []
	while not clock.ended:
		var ev := clock.tick(step, 0)
		if ev & ShiftClock.Event.ARRIVAL:
			out.append(clock.last_arrival_s)
	return out


## Avança em passos curtos com `open` bilhetes abertos (o chamador atende entre ticks).
func _run(c: ShiftClock, seconds: float, open: int) -> void:
	var left := seconds
	while left > 0.0001 and not c.ended:
		var d := minf(0.05, left)
		c.tick(d, open)
		left -= d


func test_ideal_schedule_has_9_tickets() -> void:
	assert_eq(ShiftClock.ideal_schedule(), [3.0, 25.0, 47.0, 63.0, 79.0, 95.0, 111.0, 127.0, 143.0])


func test_arrivals_without_delay_follow_schedule() -> void:
	var times := _arrival_times(0.1)
	assert_eq(times.size(), 9)
	for i in times.size():
		assert_almost_eq(times[i], ShiftClock.ideal_schedule()[i], 0.001)
	assert_eq(clock.arrivals_total, 9)


func test_large_tick_does_not_skip_arrivals() -> void:
	clock.tick(50.0, 0)
	assert_eq(clock.arrivals_this_tick, 3, "3, 25 e 47 num tick só")
	assert_eq(clock.next_arrival_s, 63.0)


func test_arrivals_in_same_tick_count_as_open() -> void:
	clock.tick(80.0, 0)   # 3, 25, 47, 63 -> 4 abertos; 79 espera vaga
	assert_eq(clock.arrivals_total, 4)
	assert_true(clock.waiting_vacancy)


func test_phases_and_events() -> void:
	assert_eq(clock.phase(), ShiftClock.Phase.OPENING)
	var ev := clock.tick(44.9, 0)
	assert_eq(ev & ShiftClock.Event.PHASE_CHANGED, 0)
	ev = clock.tick(0.2, 0)
	assert_ne(ev & ShiftClock.Event.PHASE_CHANGED, 0)
	assert_eq(clock.phase(), ShiftClock.Phase.RUSH)
	clock.tick(90.0, 0)
	assert_eq(clock.phase(), ShiftClock.Phase.CLOSING)
	clock.tick(30.0, 0)
	assert_eq(clock.phase(), ShiftClock.Phase.LAST_ORDERS)
	ev = clock.tick(100.0, 0)
	assert_ne(ev & ShiftClock.Event.ENDED, 0)
	assert_true(clock.ended)
	assert_eq(clock.time, 180.0, "trava em 180")
	assert_eq(clock.phase(), ShiftClock.Phase.CLOSED)
	assert_eq(clock.tick(1.0, 0), ShiftClock.Event.NONE)


func test_max_open_per_phase() -> void:
	assert_eq(ShiftClock.max_open_at(10.0), 2)
	assert_eq(ShiftClock.max_open_at(45.0), 4)
	assert_eq(ShiftClock.max_open_at(140.0), 3)
	assert_eq(ShiftClock.interval_at(140.0), 25.0)


func test_full_rail_waits_vacancy_plus_4s() -> void:
	clock.tick(3.0, 0)
	assert_eq(clock.arrivals_total, 1)
	clock.tick(27.0, 2)   # aos 25 s o trilho está no máximo (2)
	assert_true(clock.waiting_vacancy)
	assert_eq(clock.arrivals_total, 1)
	clock.tick(0.5, 1)    # vaga aos 30 s -> chega aos 34 s
	assert_false(clock.waiting_vacancy)
	assert_almost_eq(clock.next_arrival_s, 34.0, 0.001)
	clock.tick(3.4, 1)
	assert_eq(clock.arrivals_total, 1)
	clock.tick(0.2, 1)
	assert_eq(clock.arrivals_total, 2)
	assert_almost_eq(clock.next_arrival_s, 56.0, 0.001, "34 + 22 (fase da chegada)")


func test_rush_max_frees_waiting_arrival() -> void:
	clock.tick(3.0, 0)
	clock.tick(27.0, 2)   # espera desde 25 s
	assert_true(clock.waiting_vacancy)
	clock.tick(20.0, 2)   # aos 45 s o máximo vira 4 -> chega aos 49 s
	assert_eq(clock.arrivals_total, 2)
	assert_almost_eq(clock.next_arrival_s, 65.0, 0.001, "49 + 16")


func test_no_arrivals_in_last_orders() -> void:
	_run(clock, 150.0, 0)   # 143 chegou; agenda 168 (>= 165) -> nada
	assert_eq(clock.arrivals_total, 9)
	_run(clock, 30.0, 0)
	assert_eq(clock.arrivals_total, 9)
	assert_eq(clock.next_arrival_s, INF)


func test_delayed_arrival_after_165_is_dropped() -> void:
	_run(clock, 140.0, 0)
	_run(clock, 5.0, 3)     # 143 devida, cheia (3)
	assert_true(clock.waiting_vacancy)
	_run(clock, 18.0, 3)
	_run(clock, 1.0, 2)     # vaga aos 163 -> 167 >= 165: não chega
	_run(clock, 10.0, 2)
	assert_eq(clock.arrivals_total, 8)


func test_wall_clock() -> void:
	assert_eq(ShiftClock.wall_clock_at(0.0), Vector2i(11, 0))
	assert_eq(ShiftClock.wall_clock_at(90.0), Vector2i(12, 30))
	assert_eq(ShiftClock.wall_clock_at(180.0), Vector2i(14, 0))
	assert_eq(ShiftClock.wall_clock_at(999.0), Vector2i(14, 0))
	clock.tick(45.5, 0)
	assert_eq(clock.wall_clock(), Vector2i(11, 45))
	assert_almost_eq(clock.remaining_s(), 134.5, 0.001)


func test_order_for_rolls() -> void:
	var b := ShiftClock.BURGER
	var s := ShiftClock.STEW
	assert_eq(ShiftClock.order_for_rolls(ShiftClock.Phase.OPENING, 0.0, 0.59), [b])
	assert_eq(ShiftClock.order_for_rolls(ShiftClock.Phase.OPENING, 0.0, 0.6), [s])
	assert_eq(ShiftClock.order_for_rolls(ShiftClock.Phase.RUSH, 0.39, 0.74), [b, s])
	assert_eq(ShiftClock.order_for_rolls(ShiftClock.Phase.RUSH, 0.39, 0.75), [b, b])
	assert_eq(ShiftClock.order_for_rolls(ShiftClock.Phase.RUSH, 0.4, 0.1), [b])
	assert_eq(ShiftClock.order_for_rolls(ShiftClock.Phase.CLOSING, 0.0, 0.1), [b])


func test_roll_order_mix_by_phase() -> void:
	for i in 200:
		assert_eq(clock.roll_order().size(), 1, "abertura: só 1 item")
	clock.tick(50.0, 0)
	var combos := 0
	var stews := 0
	var n := 2000
	for i in n:
		var o := clock.roll_order()
		if o.size() == 2:
			combos += 1
		elif o[0] == ShiftClock.STEW:
			stews += 1
	assert_almost_eq(float(combos) / n, 0.4, 0.04)
	assert_almost_eq(float(stews) / (n - combos), 0.4, 0.05)
