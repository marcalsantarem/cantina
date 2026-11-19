extends Control
## Carimbo do bilhete-resposta, desenhado: coração (ótimo), sorriso (bom), gota (fraco).

enum Band { GREAT, OK, POOR }
const COLORS: Array[Color] = [Color("#d9534f"), Color("#2fa57e"), Color("#5f93bd")]
const TILT := -0.21

var band: int = Band.GREAT:
	set(v):
		band = clampi(v, 0, 2)
		queue_redraw()


func _draw() -> void:
	var col := COLORS[band]
	var r := minf(size.x, size.y) * 0.5 - 2.0
	draw_set_transform(size * 0.5, TILT)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, col, 3.0, true)
	draw_arc(Vector2.ZERO, r - 5.0, 0.0, TAU, 48, col, 1.5, true)
	var s := r * 0.55
	match band:
		Band.GREAT:
			draw_colored_polygon(_heart(s), col)
		Band.OK:
			draw_circle(Vector2(-s * 0.4, -s * 0.3), s * 0.13, col)
			draw_circle(Vector2(s * 0.4, -s * 0.3), s * 0.13, col)
			draw_arc(Vector2(0, -s * 0.05), s * 0.6, 0.2 * PI, 0.8 * PI, 16, col, 3.0, true)
		_:
			draw_colored_polygon(_drop(s), col)


static func _heart(s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		var t := TAU * i / 32.0
		var x := 16.0 * pow(sin(t), 3)
		var y := 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)
		pts.append(Vector2(x, -y - 2.0) * s / 16.0)
	return pts


static func _drop(s: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(0, -s)])
	var c := Vector2(0, s * 0.3)
	var rr := s * 0.6
	for i in 21:
		var a := deg_to_rad(-30.0 + 240.0 * i / 20.0)
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts
