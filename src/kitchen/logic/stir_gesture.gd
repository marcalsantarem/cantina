class_name StirGesture
extends RefCounted
## Gesto de mexer (m2_turno §4.2): ângulo acumulado em torno do centro da panela na
## tela. Posições 0–1 da viewport (y para baixo), tempo em ms; distâncias em u (altura
## da tela, x corrigido pelo aspecto). Sentido livre; inverter zera a volta em curso.
## Nada é alocado por amostra.
##
## Uso: begin(centro, p, t) -> add_sample(p, t) a cada movimento (true = volta válida
## completa; ver `last_quality`) -> finish(p, t).

const RADIUS_MIN_U := 0.03
const RADIUS_MAX_U := 0.15
const TURN_MIN_MS := 400
const TURN_MAX_MS := 1500
## Voltas usadas no CV do ritmo e do raio.
const HISTORY := 3
const CV_TIME_PERFECT := 0.20
const CV_RADIUS_PERFECT := 0.25
const CV_GOOD := 0.40
## Recuo angular que confirma inversão de sentido (filtra tremor).
const REVERSAL_RAD := 0.35
## Amostras mais perto do centro que isto não somam ângulo (direção indefinida).
const DEAD_ZONE_U := 0.005

var aspect: float = 16.0 / 9.0
var active: bool = false
var center := Vector2.ZERO
## Voltas válidas neste gesto e nota da última.
var turns: int = 0
var last_quality: int = Kitchen.Quality.GOOD
var last_turn_ms: int = 0
var last_turn_radius: float = 0.0
## Ângulo (rad, com sinal) da volta em curso.
var turn_angle: float = 0.0

var _dir: int = 0
var _back: float = 0.0
var _prev_angle: float = 0.0
var _has_prev: bool = false
var _turn_start_t: int = 0
var _r_sum: float = 0.0
var _r_n: int = 0
var _hist_ms := PackedFloat32Array()
var _hist_r := PackedFloat32Array()
var _hist_n: int = 0


func _init(aspect_ratio: float = 16.0 / 9.0) -> void:
	aspect = aspect_ratio
	_hist_ms.resize(HISTORY)
	_hist_r.resize(HISTORY)


## Nota da volta a partir dos CVs do tempo e do raio das últimas voltas.
static func grade_stir(cv_time: float, cv_radius: float) -> int:
	if cv_time <= CV_TIME_PERFECT and cv_radius <= CV_RADIUS_PERFECT:
		return Kitchen.Quality.PERFECT
	if cv_time <= CV_GOOD and cv_radius <= CV_GOOD:
		return Kitchen.Quality.GOOD
	return Kitchen.Quality.CLUMSY


## `pot_center` = centro da panela na tela (0–1 da viewport).
func begin(pot_center: Vector2, p: Vector2, t_ms: int) -> void:
	center = pot_center
	active = true
	turns = 0
	last_quality = Kitchen.Quality.GOOD
	last_turn_ms = 0
	last_turn_radius = 0.0
	_hist_n = 0
	_dir = 0
	_has_prev = false
	_restart_turn(t_ms)
	_sample(p, t_ms)


## Retorna true quando completa uma volta válida (raio e duração dentro dos limites).
func add_sample(p: Vector2, t_ms: int) -> bool:
	if not active:
		return false
	return _sample(p, t_ms)


func finish(p: Vector2, t_ms: int) -> bool:
	if not active:
		return false
	var done := _sample(p, t_ms)
	active = false
	return done


func _sample(p: Vector2, t_ms: int) -> bool:
	var v := Vector2((p.x - center.x) * aspect, p.y - center.y)
	var r := v.length()
	if r < DEAD_ZONE_U:
		return false
	var a := v.angle()
	if not _has_prev:
		_has_prev = true
		_prev_angle = a
		_r_sum += r
		_r_n += 1
		return false
	var d := wrapf(a - _prev_angle, -PI, PI)
	_prev_angle = a
	_r_sum += r
	_r_n += 1
	if d == 0.0:
		return false
	var s := 1 if d > 0.0 else -1
	if _dir == 0:
		_dir = s
	if s != _dir:
		_back += absf(d)
		turn_angle += d
		if _back >= REVERSAL_RAD:
			# Inverteu: a volta em curso zera e recomeça no novo sentido.
			_dir = s
			_restart_turn(t_ms)
			_r_sum = r
			_r_n = 1
		return false
	_back = 0.0
	turn_angle += d
	if absf(turn_angle) < TAU - 0.0001:
		return false
	var dur := t_ms - _turn_start_t
	var radius := _r_sum / maxi(_r_n, 1)
	var rest := turn_angle - TAU * _dir
	_restart_turn(t_ms)
	turn_angle = rest
	_r_sum = r
	_r_n = 1
	if dur < TURN_MIN_MS or dur > TURN_MAX_MS or radius < RADIUS_MIN_U or radius > RADIUS_MAX_U:
		return false
	_push(dur, radius)
	turns += 1
	last_turn_ms = dur
	last_turn_radius = radius
	last_quality = _grade_history()
	return true


func _restart_turn(t_ms: int) -> void:
	turn_angle = 0.0
	_back = 0.0
	_turn_start_t = t_ms
	_r_sum = 0.0
	_r_n = 0


func _push(dur: float, radius: float) -> void:
	var i := _hist_n % HISTORY
	_hist_ms[i] = dur
	_hist_r[i] = radius
	_hist_n += 1


## 1ª volta: Bom (ainda sem ritmo para medir); depois, CV das últimas até 3 voltas.
func _grade_history() -> int:
	var n := mini(_hist_n, HISTORY)
	if n < 2:
		return Kitchen.Quality.GOOD
	var ms := 0.0
	var ms2 := 0.0
	var r := 0.0
	var r2 := 0.0
	for i in n:
		ms += _hist_ms[i]
		ms2 += _hist_ms[i] * _hist_ms[i]
		r += _hist_r[i]
		r2 += _hist_r[i] * _hist_r[i]
	return grade_stir(GestureRecognizer.cv_of(n, ms, ms2), GestureRecognizer.cv_of(n, r, r2))
