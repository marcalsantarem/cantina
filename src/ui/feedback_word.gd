extends Label
## Palavra de feedback de gesto: aparece em screen_pos, sobe, brilha e some.

const Sparkle := preload("res://src/ui/sparkle.gd")
## Por qualidade (Kitchen.Quality): CLUMSY, GOOD, PERFECT.
const COLORS: Array[Color] = [Color("#a9785e"), Color("#e8713a"), Color("#2fa57e")]
const RISE := 70.0
const LIFE := 1.1


func pop(word: String, quality: int, screen_pos: Vector2) -> void:
	quality = clampi(quality, 0, 2)
	text = word
	theme_type_variation = &"FeedbackLabel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_color_override("font_color", COLORS[quality])
	reset_size()
	position = screen_pos - size * 0.5
	pivot_offset = size * 0.5
	scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "scale", Vector2.ONE, 0.1)
	tw.parallel().tween_property(self, "position:y", position.y - RISE, LIFE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.4).set_delay(LIFE - 0.4)
	tw.tween_callback(queue_free)
	if quality > 0:
		_sparkle(quality)


func _sparkle(quality: int) -> void:
	var sp := Sparkle.new()
	sp.show_behind_parent = true
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.radius = 70.0 if quality == 2 else 45.0
	sp.rays = 10 if quality == 2 else 6
	sp.size = size
	add_child(sp)
	sp.create_tween().tween_property(sp, "progress", 1.0, 0.6).set_ease(Tween.EASE_OUT)
