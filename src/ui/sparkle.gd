extends Control
## Brilho da palavra de feedback: raios que se abrem e somem.

var color := Color("#ffd36b")
var radius := 60.0
var rays := 8
var progress := 0.0:
	set(v):
		progress = v
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var col := Color(color, 1.0 - progress)
	for i in rays:
		var dir := Vector2.from_angle(TAU * i / rays + 0.3)
		var a := radius * (0.35 + 0.65 * progress)
		draw_line(c + dir * a, c + dir * (a + radius * 0.3 * (1.0 - progress)), col, 4.0, true)
