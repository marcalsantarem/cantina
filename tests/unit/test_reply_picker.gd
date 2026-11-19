extends GutTest
## ReplyPicker: frase por faixa, gancho do erro dominante, sem repetir a última.

var picker: ReplyPicker


func before_each() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	picker = ReplyPicker.new(rng)


func test_data_has_4_phrases_per_band() -> void:
	for key in ReplyPicker.BAND_KEYS:
		assert_gte((picker.bands[key] as Array).size(), 4, key)
	for key in [DishScorer.ERR_BURNT, DishScorer.ERR_FORBIDDEN, DishScorer.ERR_ORDER]:
		assert_true(picker.has_hook(key), key)


func test_pick_comes_from_band() -> void:
	for band in [DishScorer.Band.GREAT, DishScorer.Band.OK, DishScorer.Band.POOR]:
		var pool: Array = picker.bands[ReplyPicker.BAND_KEYS[band]]
		for i in 20:
			assert_has(pool, picker.pick(band))


func test_hook_is_appended() -> void:
	var text := picker.pick(DishScorer.Band.OK, DishScorer.ERR_BURNT)
	var found := false
	for h: String in picker.hooks[DishScorer.ERR_BURNT]:
		if text.ends_with(" " + h):
			found = true
	assert_true(found, text)


func test_unknown_dominant_has_no_hook() -> void:
	var pool: Array = picker.bands["great"]
	assert_has(pool, picker.pick(DishScorer.Band.GREAT, DishScorer.ERR_ALIGN))


func test_no_immediate_repeat() -> void:
	var last := ""
	for i in 50:
		var text := picker.pick(DishScorer.Band.POOR)
		assert_ne(text, last)
		last = text
