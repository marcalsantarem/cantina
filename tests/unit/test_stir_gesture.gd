extends GutTest
## StirGesture (m2_turno §4.2): voltas por ângulo acumulado, limites de raio/duração,
## inversão zera a volta, nota por CV do tempo e do raio das últimas 3 voltas.

const ASPECT := 16.0 / 9.0
const C := Vector2(0.6, 0.5)
const STEPS := 24

var g: StirGesture
var t: int = 0
var turn_pos: float = 0.0
var qualities: Array[int] = []


func before_each() -> void:
	g = StirGesture.new(ASPECT)
	t = 1000
	turn_pos = 0.0
	qualities.clear()


func _point(turn: float, r_u: float) -> Vector2:
	var a := turn * TAU
	return C + Vector2(r_u * cos(a) / ASPECT, r_u * sin(a))


func _start(r_u: float) -> void:
	g.begin(C, _point(0.0, r_u), t)


## Gira `turns` voltas (negativo = sentido inverso) com `period_ms` por volta. Retorna voltas válidas.
func _spin(turns: float, period_ms: float, r_u: float) -> int:
	var n := roundi(absf(turns) * STEPS)
	var dturn := signf(turns) / STEPS
	var ok := 0
	var t0 := float(t)
	for k in range(1, n + 1):
		turn_pos += dturn
		t = roundi(t0 + k * period_ms / STEPS)
		if g.add_sample(_point(turn_pos, r_u), t):
			ok += 1
			qualities.append(g.last_quality)
	return ok


func test_steady_turns_are_perfect_after_first() -> void:
	_start(0.08)
	assert_eq(_spin(3.0, 800.0, 0.08), 3)
	assert_eq(g.turns, 3)
	assert_eq(qualities, [Kitchen.Quality.GOOD, Kitchen.Quality.PERFECT, Kitchen.Quality.PERFECT])
	assert_almost_eq(float(g.last_turn_ms), 800.0, 2.0)
	assert_almost_eq(g.last_turn_radius, 0.08, 0.001)


func test_either_direction() -> void:
	_start(0.08)
	assert_eq(_spin(-2.0, 700.0, 0.08), 2)


func test_duration_limits() -> void:
	_start(0.08)
	assert_eq(_spin(2.0, 300.0, 0.08), 0, "rápido demais")
	before_each()
	_start(0.08)
	assert_eq(_spin(2.0, 1700.0, 0.08), 0, "lento demais")
	before_each()
	_start(0.08)
	assert_eq(_spin(1.0, 450.0, 0.08), 1)


func test_radius_limits() -> void:
	_start(0.02)
	assert_eq(_spin(2.0, 800.0, 0.02), 0, "raio < 0,03")
	before_each()
	_start(0.2)
	assert_eq(_spin(2.0, 800.0, 0.2), 0, "raio > 0,15")


func test_reversal_resets_turn_in_progress() -> void:
	_start(0.08)
	assert_eq(_spin(0.75, 600.0, 0.08), 0)
	assert_eq(_spin(-0.95, 760.0, 0.08), 0, "a volta recomeçou na inversão")
	assert_eq(_spin(-0.25, 200.0, 0.08), 1)


func test_uneven_rhythm_is_clumsy() -> void:
	_start(0.08)
	_spin(1.0, 500.0, 0.08)
	_spin(1.0, 1400.0, 0.08)
	_spin(1.0, 500.0, 0.08)
	assert_eq(qualities.size(), 3)
	assert_eq(qualities[2], Kitchen.Quality.CLUMSY)


func test_uneven_radius_lowers_grade() -> void:
	_start(0.05)
	_spin(1.0, 800.0, 0.05)
	_spin(1.0, 800.0, 0.12)
	assert_eq(qualities.size(), 2)
	assert_ne(qualities[1], Kitchen.Quality.PERFECT)


func test_grade_stir_thresholds() -> void:
	assert_eq(StirGesture.grade_stir(0.20, 0.25), Kitchen.Quality.PERFECT)
	assert_eq(StirGesture.grade_stir(0.21, 0.1), Kitchen.Quality.GOOD)
	assert_eq(StirGesture.grade_stir(0.40, 0.40), Kitchen.Quality.GOOD)
	assert_eq(StirGesture.grade_stir(0.41, 0.1), Kitchen.Quality.CLUMSY)
	assert_eq(StirGesture.grade_stir(0.1, 0.41), Kitchen.Quality.CLUMSY)


func test_inactive_ignores_samples() -> void:
	assert_false(g.add_sample(C, 0))
	_start(0.08)
	_spin(0.5, 800.0, 0.08)
	g.finish(_point(turn_pos, 0.08), t)
	assert_false(g.active)
	assert_eq(_spin(2.0, 800.0, 0.08), 0)
