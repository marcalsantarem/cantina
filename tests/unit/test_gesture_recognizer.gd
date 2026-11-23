extends GutTest
## GestureRecognizer (decisão 22): só tocar e arrastar, distâncias em u (x pelo aspecto).

var r: GestureRecognizer


func before_each() -> void:
	r = GestureRecognizer.new(2.0)


func test_drag_starts_after_threshold() -> void:
	r.begin(Vector2(0.5, 0.5), 0)
	assert_eq(r.add_sample(Vector2(0.505, 0.5), 16), GestureRecognizer.Event.NONE, "0,01 u: ainda não")
	assert_eq(r.add_sample(Vector2(0.515, 0.5), 32), GestureRecognizer.Event.DRAG_STARTED, "0,03 u com aspecto 2")
	assert_eq(r.add_sample(Vector2(0.6, 0.5), 48), GestureRecognizer.Event.NONE, "emite uma vez")
	assert_eq(r.finish(Vector2(0.6, 0.5), 64), GestureRecognizer.Kind.DRAG)
	assert_false(r.active)
	assert_eq(r.start_point(), Vector2(0.5, 0.5))
	assert_eq(r.last_point(), Vector2(0.6, 0.5))


func test_tap_and_long_press() -> void:
	r.begin(Vector2(0.5, 0.5), 0)
	assert_eq(r.finish(Vector2(0.5, 0.5), 150), GestureRecognizer.Kind.TAP)
	r.begin(Vector2(0.5, 0.5), 0)
	assert_eq(r.finish(Vector2(0.5, 0.5), 400), GestureRecognizer.Kind.NONE, "segurar parado não é toque")


func test_drag_detected_on_release() -> void:
	r.begin(Vector2(0.5, 0.5), 0)
	assert_eq(r.finish(Vector2(0.5, 0.6), 50), GestureRecognizer.Kind.DRAG)
	assert_eq(r.last_events, GestureRecognizer.Event.DRAG_STARTED)


func test_inactive_ignores_samples() -> void:
	assert_eq(r.add_sample(Vector2(0.9, 0.9), 0), GestureRecognizer.Event.NONE)
	assert_eq(r.finish(Vector2(0.9, 0.9), 0), GestureRecognizer.Kind.NONE)


func test_distance_u_uses_aspect() -> void:
	assert_almost_eq(GestureRecognizer.distance_u(Vector2(0, 0), Vector2(0.1, 0), 2.0), 0.2, 0.0001)
	assert_almost_eq(GestureRecognizer.distance_u(Vector2(0, 0), Vector2(0, 0.1), 2.0), 0.1, 0.0001)
