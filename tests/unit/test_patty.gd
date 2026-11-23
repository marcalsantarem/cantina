extends GutTest
## Patty (decisão 22): cozinha sozinha sem virar; faixas de ponto, nota ao tirar e modelo.


func test_grade_bands() -> void:
	assert_eq(Patty.grade_time(0.0), 0.4, "cru")
	assert_eq(Patty.grade_time(7.99), 0.4)
	assert_eq(Patty.grade_time(8.0), 0.7, "no ponto a partir de 8 s")
	assert_eq(Patty.grade_time(10.0), 1.0, "perfeito 10–12,5 s")
	assert_eq(Patty.grade_time(12.49), 1.0)
	assert_eq(Patty.grade_time(12.5), 0.7)
	assert_eq(Patty.grade_time(17.99), 0.7)
	assert_eq(Patty.grade_time(18.0), 0.0, "queimada aos 18 s")
	assert_eq(Patty.quality_for_time(18.0), Kitchen.Quality.CLUMSY)


func test_stages() -> void:
	assert_eq(Patty.stage_for_time(2.0), Patty.Stage.RAW)
	assert_eq(Patty.stage_for_time(9.0), Patty.Stage.MEDIUM)
	assert_eq(Patty.stage_for_time(11.0), Patty.Stage.GLOW)
	assert_eq(Patty.stage_for_time(15.0), Patty.Stage.SMOKE)
	assert_eq(Patty.stage_for_time(19.0), Patty.Stage.BURNT)


func test_only_cooks_in_pan() -> void:
	var p := Patty.new()
	p.tick(5.0)
	assert_eq(p.time, 0.0)
	p.place_in_pan()
	p.tick(5.0)
	assert_eq(p.time, 5.0)
	assert_eq(p.model_id(), Kitchen.BURGER_UNCOOKED)
	assert_false(p.is_cooked())


func test_remove_records_note_and_pauses() -> void:
	var p := Patty.new()
	assert_eq(p.remove(), -1, "fora da frigideira")
	assert_eq(p.notes(), {})
	p.place_in_pan()
	p.tick(11.0)
	assert_true(p.is_cooked())
	assert_eq(p.model_id(), Kitchen.BURGER_COOKED)
	assert_eq(p.remove(), Kitchen.Quality.PERFECT)
	assert_eq(p.notes(), {Kitchen.NOTE_COOK: 1.0})
	p.tick(20.0)
	assert_eq(p.time, 11.0, "tirar pausa")


func test_burns_if_forgotten() -> void:
	var p := Patty.new()
	p.place_in_pan()
	p.tick(25.0)
	assert_true(p.is_burnt())
	assert_false(p.is_cooked())
	assert_eq(p.model_id(), Kitchen.BURGER_TRASH)
	assert_eq(p.remove(), Kitchen.Quality.CLUMSY)
	assert_eq(p.notes(), {Kitchen.NOTE_COOK: 0.0})
