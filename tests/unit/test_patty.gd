extends GutTest
## Patty: faixas de tempo por lado, virar/tirar, notas lado_a/lado_b e modelo.


func test_grade_time_limits() -> void:
	assert_eq(Patty.grade_time(0.0), 0.4)
	assert_eq(Patty.grade_time(4.99), 0.4)
	assert_eq(Patty.grade_time(5.0), 0.7)
	assert_eq(Patty.grade_time(6.99), 0.7)
	assert_eq(Patty.grade_time(7.0), 1.0)
	assert_eq(Patty.grade_time(9.99), 1.0)
	assert_eq(Patty.grade_time(10.0), 0.7)
	assert_eq(Patty.grade_time(12.99), 0.7)
	assert_eq(Patty.grade_time(13.0), 0.0)
	assert_eq(Patty.quality_for_time(13.0), Kitchen.Quality.CLUMSY, "queimado = Ops")


func test_stage_limits() -> void:
	assert_eq(Patty.stage_for_time(4.99), Patty.Stage.RAW)
	assert_eq(Patty.stage_for_time(5.0), Patty.Stage.MEDIUM)
	assert_eq(Patty.stage_for_time(7.0), Patty.Stage.GLOW)
	assert_eq(Patty.stage_for_time(10.0), Patty.Stage.SMOKE)
	assert_eq(Patty.stage_for_time(13.0), Patty.Stage.BURNT)


func test_only_cooks_in_pan_and_side_down() -> void:
	var p := Patty.new()
	p.tick(5.0)
	assert_eq(p.time_a, 0.0, "fora da panela não cozinha")
	p.place_in_pan()
	p.tick(3.0)
	assert_eq(p.time_a, 3.0)
	assert_eq(p.time_b, 0.0)
	p.flip()
	p.tick(2.0)
	assert_eq(p.time_a, 3.0)
	assert_eq(p.time_b, 2.0)


func test_flip_and_remove_record_notes() -> void:
	var p := Patty.new()
	p.place_in_pan()
	p.tick(8.0)
	assert_eq(p.flip(), Kitchen.Quality.PERFECT)
	assert_eq(p.notes(), {"lado_a": 1.0})
	p.tick(5.5)
	assert_eq(p.model_id(), Kitchen.BURGER_COOKED)
	assert_eq(p.remove(), Kitchen.Quality.GOOD)
	assert_eq(p.notes(), {"lado_a": 1.0, "lado_b": 0.7})
	assert_false(p.in_pan)
	p.tick(10.0)
	assert_eq(p.time_b, 5.5, "tirar pausa o cozimento")


func test_model_transitions() -> void:
	var p := Patty.new()
	p.place_in_pan()
	p.tick(6.0)
	assert_eq(p.model_id(), Kitchen.BURGER_UNCOOKED, "um lado só ainda é cru")
	p.flip()
	p.tick(4.9)
	assert_eq(p.model_id(), Kitchen.BURGER_UNCOOKED)
	p.tick(0.1)
	assert_eq(p.model_id(), Kitchen.BURGER_COOKED, "os dois lados >= 5 s")
	p.tick(8.0)
	assert_eq(p.model_id(), Kitchen.BURGER_TRASH, "lado >= 13 s queima")
	assert_true(p.is_burnt())


func test_never_flipped_burns_side_a_only() -> void:
	var p := Patty.new()
	p.place_in_pan()
	p.tick(13.0)
	assert_eq(p.time_b, 0.0)
	assert_eq(p.model_id(), Kitchen.BURGER_TRASH)
	assert_eq(p.down_stage(), Patty.Stage.BURNT)
	p.remove()
	assert_eq(p.notes(), {"lado_a": 0.0, "lado_b": 0.4})


func test_multiple_flips_keep_latest_notes() -> void:
	var p := Patty.new()
	p.place_in_pan()
	p.tick(4.0)
	assert_eq(p.flip(), Kitchen.Quality.CLUMSY)
	p.tick(8.0)
	p.flip()
	p.tick(4.0)   # lado A chega a 8 s
	p.remove()
	assert_eq(p.notes(), {"lado_a": 1.0, "lado_b": 1.0})


func test_flip_outside_pan_is_ignored() -> void:
	var p := Patty.new()
	assert_eq(p.flip(), -1)
	assert_eq(p.remove(), -1)
	assert_eq(p.side_down, Patty.Side.A)
