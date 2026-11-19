extends GutTest
## GestureRecognizer: arrastar/toque, alinhamento, picar (traços, CV, cobertura, pausa), puxão.
## Aspecto 2.0 e valores binários exatos para limites sem ruído de ponto flutuante.

const ASPECT := 2.0
var rec: GestureRecognizer


func before_each() -> void:
	rec = GestureRecognizer.new(ASPECT)


# --- Buffer --------------------------------------------------------------------

func test_buffer_is_fixed_128_ring() -> void:
	rec.begin(GestureRecognizer.Mode.DRAG, Vector2.ZERO, 0)
	for i in range(1, 200):
		rec.add_sample(Vector2(i / 1000.0, 0.0), i)
	assert_eq(rec.sample_count(), 128)
	assert_eq(rec.sample_time(0), 200 - 128)
	assert_eq(rec.sample_time(127), 199)
	assert_eq(rec.last_point(), Vector2(0.199, 0.0))


# --- Arrastar / toque -------------------------------------------------------------

func test_drag_threshold_uses_aspect() -> void:
	rec.begin(GestureRecognizer.Mode.DRAG, Vector2(0.5, 0.5), 0)
	# dx 0.009 na viewport = 0.018 u: ainda não arrasta.
	assert_eq(rec.add_sample(Vector2(0.509, 0.5), 10), GestureRecognizer.Event.NONE)
	# dx 0.0105 = 0.021 u: arrasta.
	assert_eq(rec.add_sample(Vector2(0.5105, 0.5), 20), GestureRecognizer.Event.DRAG_STARTED)
	assert_true(rec.dragging)
	assert_eq(rec.add_sample(Vector2(0.6, 0.5), 30), GestureRecognizer.Event.NONE, "evento só uma vez")
	assert_eq(rec.finish(Vector2(0.6, 0.5), 40), GestureRecognizer.Kind.DRAG)


func test_tap_needs_short_and_still() -> void:
	rec.begin(GestureRecognizer.Mode.DRAG, Vector2(0.5, 0.5), 0)
	assert_eq(rec.finish(Vector2(0.505, 0.5), 199), GestureRecognizer.Kind.TAP)
	rec.begin(GestureRecognizer.Mode.DRAG, Vector2(0.5, 0.5), 0)
	assert_eq(rec.finish(Vector2(0.5, 0.5), 200), GestureRecognizer.Kind.NONE, "200 ms não é toque")


func test_alignment_limits() -> void:
	assert_eq(GestureRecognizer.grade_alignment(0.0), Kitchen.Quality.PERFECT)
	assert_eq(GestureRecognizer.grade_alignment(0.02), Kitchen.Quality.PERFECT)
	assert_eq(GestureRecognizer.grade_alignment(0.0201), Kitchen.Quality.GOOD)
	assert_eq(GestureRecognizer.grade_alignment(0.05), Kitchen.Quality.GOOD)
	assert_eq(GestureRecognizer.grade_alignment(0.0501), Kitchen.Quality.CLUMSY)


func test_drop_quality_and_offset_use_aspect() -> void:
	var center := Vector2(0.5, 0.5)
	rec.begin(GestureRecognizer.Mode.DRAG, Vector2(0.2, 0.2), 0)
	rec.finish(Vector2(0.5 + 0.0075, 0.5), 300)   # 0.015 u
	assert_eq(rec.drop_quality(center), Kitchen.Quality.PERFECT)
	assert_almost_eq(rec.drop_offset_u(center).x, 0.015, 0.0001)
	rec.begin(GestureRecognizer.Mode.DRAG, Vector2(0.2, 0.2), 0)
	rec.finish(Vector2(0.5 + 0.02, 0.5), 300)     # 0.04 u
	assert_eq(rec.drop_quality(center), Kitchen.Quality.GOOD)
	rec.begin(GestureRecognizer.Mode.DRAG, Vector2(0.2, 0.2), 0)
	rec.finish(Vector2(0.5, 0.6), 300)            # 0.1 u
	assert_eq(rec.drop_quality(center), Kitchen.Quality.CLUMSY)
	assert_almost_eq(rec.drop_offset_u(center).length(), 0.03, 0.0001, "deslocamento limitado a 0,03 u")


# --- Picar ---------------------------------------------------------------------

## Zigue-zague entre y 0.25 e 0.5 (|Δy| 0.25 u). Retorna o nº de eventos CUT.
func _zigzag(durations: Array, xs: Array, dy: float = 0.25, start_t: int = 0) -> int:
	var y0 := 0.25
	var t := start_t
	var events := 0
	rec.begin(GestureRecognizer.Mode.CHOP, Vector2(xs[0], y0), t)
	var down := true
	for k in durations.size():
		var y_to := y0 + dy if down else y0
		var y_from := y0 if down else y0 + dy
		var x: float = xs[k + 1]
		t += int(durations[k] / 2.0)
		if rec.add_sample(Vector2(x, (y_from + y_to) / 2.0), t) & GestureRecognizer.Event.CUT:
			events += 1
		t = start_t + _sum(durations, k + 1)
		if rec.add_sample(Vector2(x, y_to), t) & GestureRecognizer.Event.CUT:
			events += 1
		down = not down
	rec.finish(rec.last_point(), t)
	if rec.last_events & GestureRecognizer.Event.CUT:
		events += 1
	return events


func _sum(a: Array, n: int) -> int:
	var s := 0
	for i in n:
		s += int(a[i])
	return s


func _xs(n: int) -> Array:
	# Pontos de virada espalhados por 0.2–0.8 (as 5 faixas de 0.12).
	var out := []
	for i in n + 1:
		out.append(0.21 + 0.58 * i / n)
	return out


func test_chop_counts_one_cut_per_valid_stroke() -> void:
	rec.set_chop_area(0.2, 0.8)
	var events := _zigzag([200, 200, 200, 200, 200, 200], _xs(6))
	assert_eq(rec.cuts, 6)
	assert_eq(events, 6)
	assert_eq(rec.finish(Vector2.ZERO, 0), GestureRecognizer.Kind.NONE, "inativo após finish")


func test_chop_stroke_duration_limits() -> void:
	rec.set_chop_area(0.2, 0.8)
	_zigzag([79, 80, 600, 601], _xs(4))
	assert_eq(rec.cuts, 2, "80 e 600 ms valem; 79 e 601 não")


func test_chop_stroke_min_dy() -> void:
	rec.set_chop_area(0.2, 0.8)
	_zigzag([200, 200], _xs(2), 0.046875)
	assert_eq(rec.cuts, 0, "|Δy| < 0,05 u não corta")
	_zigzag([200, 200], _xs(2), 0.0625)
	assert_eq(rec.cuts, 2)


func test_chop_perfect_even_rhythm_full_coverage() -> void:
	rec.set_chop_area(0.2, 0.8)
	_zigzag([200, 200, 200, 200, 200, 200], _xs(6))
	assert_almost_eq(rec.chop_cv(), 0.0, 0.0001)
	assert_eq(rec.chop_bands(), 5)
	assert_almost_eq(rec.chop_coverage(), 1.0, 0.0001)
	assert_eq(rec.chop_quality(), Kitchen.Quality.PERFECT)


func test_chop_cv_limits() -> void:
	rec.set_chop_area(0.2, 0.8)
	_zigzag([150, 250, 150, 250, 150, 250], _xs(6))
	assert_almost_eq(rec.chop_cv(), 0.25, 0.0001)
	assert_eq(rec.chop_quality(), Kitchen.Quality.PERFECT, "CV = 0,25 ainda é perfeito")
	_zigzag([140, 260, 140, 260, 140, 260], _xs(6))
	assert_almost_eq(rec.chop_cv(), 0.3, 0.0001)
	assert_eq(rec.chop_quality(), Kitchen.Quality.GOOD)
	_zigzag([100, 300, 100, 300, 100, 300], _xs(6))
	assert_almost_eq(rec.chop_cv(), 0.5, 0.0001)
	assert_eq(rec.chop_quality(), Kitchen.Quality.GOOD, "CV = 0,5 ainda é bom")
	_zigzag([90, 310, 90, 310, 90, 310], _xs(6))
	assert_eq(rec.chop_quality(), Kitchen.Quality.CLUMSY)


func test_chop_coverage_limits() -> void:
	rec.set_chop_area(0.2, 0.8)
	# Viradas só em 0.21–0.55: faixas 0, 1, 2 -> 3/5 = 60% -> bom.
	_zigzag([200, 200, 200], [0.21, 0.33, 0.45, 0.55])
	assert_eq(rec.chop_bands(), 3)
	assert_eq(rec.chop_quality(), Kitchen.Quality.GOOD)
	# Faixas 0 e 1 -> 40% -> desajeitado.
	_zigzag([200, 200, 200], [0.21, 0.25, 0.33, 0.30])
	assert_eq(rec.chop_bands(), 2)
	assert_eq(rec.chop_quality(), Kitchen.Quality.CLUMSY)
	# Fora da área não conta.
	_zigzag([200, 200], [0.1, 0.9, 0.1])
	assert_eq(rec.cuts, 2)
	assert_eq(rec.chop_bands(), 0)


func test_grade_chop_static_limits() -> void:
	assert_eq(GestureRecognizer.grade_chop(0.25, 5), Kitchen.Quality.PERFECT)
	assert_eq(GestureRecognizer.grade_chop(0.25, 4), Kitchen.Quality.GOOD)
	assert_eq(GestureRecognizer.grade_chop(0.2501, 5), Kitchen.Quality.GOOD)
	assert_eq(GestureRecognizer.grade_chop(0.5, 3), Kitchen.Quality.GOOD)
	assert_eq(GestureRecognizer.grade_chop(0.5, 2), Kitchen.Quality.CLUMSY)
	assert_eq(GestureRecognizer.grade_chop(0.5001, 5), Kitchen.Quality.CLUMSY)


func test_chop_pause_over_1s_ends_session() -> void:
	rec.set_chop_area(0.2, 0.8)
	rec.begin(GestureRecognizer.Mode.CHOP, Vector2(0.3, 0.25), 0)
	rec.add_sample(Vector2(0.3, 0.5), 200)
	assert_eq(rec.add_sample(Vector2(0.3, 0.5), 1200) & GestureRecognizer.Event.SESSION_ENDED, 0, "1,0 s exato não encerra")
	var ev := rec.add_sample(Vector2(0.3, 0.5), 2201)
	assert_true(ev & GestureRecognizer.Event.SESSION_ENDED != 0)
	assert_true(ev & GestureRecognizer.Event.CUT != 0, "traço antes da pausa é fechado")
	assert_eq(rec.cuts, 1)
	# Continua picando depois da pausa.
	rec.add_sample(Vector2(0.4, 0.25), 2401)
	rec.finish(Vector2(0.4, 0.25), 2401)
	assert_eq(rec.cuts, 2)


func test_chop_ignores_jitter_reversal() -> void:
	rec.set_chop_area(0.2, 0.8)
	rec.begin(GestureRecognizer.Mode.CHOP, Vector2(0.3, 0.25), 0)
	rec.add_sample(Vector2(0.3, 0.4), 100)
	rec.add_sample(Vector2(0.3, 0.395), 120)   # recuo de 0,005 u: tremor
	rec.add_sample(Vector2(0.3, 0.5), 200)
	rec.finish(Vector2(0.3, 0.5), 200)
	assert_eq(rec.cuts, 1)
	assert_eq(rec.last_stroke_ms, 200)


# --- Puxão (panela) ----------------------------------------------------------------

func test_flip_limits() -> void:
	rec.begin(GestureRecognizer.Mode.PAN, Vector2(0.5, 0.75), 0)
	assert_eq(rec.add_sample(Vector2(0.5, 0.625), 250), GestureRecognizer.Event.FLIP, "0,125 u em 250 ms")
	assert_eq(rec.finish(Vector2(0.5, 0.6), 260), GestureRecognizer.Kind.FLIP)
	rec.begin(GestureRecognizer.Mode.PAN, Vector2(0.5, 0.75), 0)
	assert_eq(rec.add_sample(Vector2(0.5, 0.625), 251), GestureRecognizer.Event.DRAG_STARTED, "lento demais: vira arrastar")
	rec.begin(GestureRecognizer.Mode.PAN, Vector2(0.5, 0.75), 0)
	assert_eq(rec.add_sample(Vector2(0.5, 0.640625), 100), GestureRecognizer.Event.NONE, "0,109 u não vira")


func test_flip_horizontal_tolerance() -> void:
	# |Δx| = 0,0625 u = 0,5·|Δy| ainda vira.
	rec.begin(GestureRecognizer.Mode.PAN, Vector2(0.5, 0.75), 0)
	assert_eq(rec.add_sample(Vector2(0.53125, 0.625), 100), GestureRecognizer.Event.FLIP)
	# |Δx| = 0,078 u > 0,5·|Δy|: vira arrastar.
	rec.begin(GestureRecognizer.Mode.PAN, Vector2(0.5, 0.75), 0)
	assert_eq(rec.add_sample(Vector2(0.5390625, 0.625), 100), GestureRecognizer.Event.DRAG_STARTED)
	assert_eq(rec.finish(Vector2(0.6, 0.6), 300), GestureRecognizer.Kind.DRAG)


func test_weak_pull_shakes() -> void:
	rec.begin(GestureRecognizer.Mode.PAN, Vector2(0.5, 0.75), 0)
	assert_eq(rec.add_sample(Vector2(0.5, 0.6875), 100), GestureRecognizer.Event.NONE, "puxão adia o arrastar")
	assert_eq(rec.finish(Vector2(0.5, 0.6875), 150), GestureRecognizer.Kind.SHAKE)
	assert_true(rec.last_events & GestureRecognizer.Event.SHAKE != 0)
	# Abaixo de 0,05 u: nada.
	rec.begin(GestureRecognizer.Mode.PAN, Vector2(0.5, 0.75), 0)
	rec.add_sample(Vector2(0.5, 0.703125), 100)
	assert_eq(rec.finish(Vector2(0.5, 0.703125), 150), GestureRecognizer.Kind.NONE)


func test_shake_then_drag_after_window() -> void:
	rec.begin(GestureRecognizer.Mode.PAN, Vector2(0.5, 0.75), 0)
	rec.add_sample(Vector2(0.5, 0.6875), 100)
	assert_eq(rec.add_sample(Vector2(0.5, 0.6875), 300), GestureRecognizer.Event.SHAKE)
	assert_eq(rec.add_sample(Vector2(0.5, 0.6), 400), GestureRecognizer.Event.DRAG_STARTED)
	assert_eq(rec.finish(Vector2(0.5, 0.6), 500), GestureRecognizer.Kind.DRAG)


func test_pan_downward_drags_at_once() -> void:
	rec.begin(GestureRecognizer.Mode.PAN, Vector2(0.5, 0.5), 0)
	assert_eq(rec.add_sample(Vector2(0.5, 0.53), 30), GestureRecognizer.Event.DRAG_STARTED)


func test_pan_tap() -> void:
	rec.begin(GestureRecognizer.Mode.PAN, Vector2(0.5, 0.5), 0)
	assert_eq(rec.finish(Vector2(0.5, 0.5), 50), GestureRecognizer.Kind.TAP)
