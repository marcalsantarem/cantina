class_name GestureRecognizer
extends RefCounted
## Reconhece arrastar, picar em zigue-zague e virar com puxão a partir de amostras
## (posição 0–1 da viewport, y para baixo; tempo em ms). Distâncias em "u" = altura
## da tela (x corrigido pelo aspecto). Buffer circular fixo; nada é alocado por amostra.
##
## Uso: begin(modo, p, t) -> add_sample(p, t) a cada movimento (retorna bits de Event)
## -> finish(p, t) (retorna Kind). `last_events` guarda os bits da última chamada.

enum Mode { DRAG, CHOP, PAN }
## Bits combináveis retornados por add_sample/finish.
enum Event { NONE = 0, DRAG_STARTED = 1, CUT = 2, FLIP = 4, SHAKE = 8, SESSION_ENDED = 16 }
enum Kind { NONE, TAP, DRAG, CHOP, FLIP, SHAKE }

const BUFFER_SIZE := 128

const DRAG_MIN_U := 0.02
const TAP_MAX_MS := 200

const CHOP_MIN_DY_U := 0.05
const CHOP_MIN_MS := 80
const CHOP_MAX_MS := 600
const CHOP_PAUSE_MS := 1000
const CHOP_BANDS := 5
## Recuo mínimo em y para confirmar inversão de sentido (filtra tremor).
const CHOP_REVERSAL_U := 0.01
const CHOP_CV_PERFECT := 0.25
const CHOP_CV_GOOD := 0.50
const CHOP_BANDS_GOOD := 3

const FLIP_MIN_U := 0.12
const FLIP_MAX_MS := 250
const FLIP_MAX_DX_RATIO := 0.5
const SHAKE_MIN_U := 0.05

const ALIGN_PERFECT_U := 0.02
const ALIGN_GOOD_U := 0.05
const ALIGN_MAX_OFFSET_U := 0.03

## Largura/altura da viewport.
var aspect: float = 16.0 / 9.0
var mode: int = Mode.DRAG
var active: bool = false
var dragging: bool = false
var flipped: bool = false
var last_events: int = Event.NONE

## Picar: cortes válidos neste gesto, duração e faixas do último corte.
var cuts: int = 0
var last_stroke_ms: int = 0
var last_stroke_bands: int = 0
var coverage_mask: int = 0

var _points := PackedVector2Array()
var _times := PackedInt64Array()
var _count: int = 0

var _start_p := Vector2.ZERO
var _start_t: int = 0
var _last_p := Vector2.ZERO
var _last_t: int = 0

var _pan_resolved: bool = false
var _shook: bool = false
var _max_pull: float = 0.0

var _area_min_x: float = 0.0
var _area_max_x: float = 1.0
var _dir: int = 0
var _ext_p := Vector2.ZERO
var _ext_t: int = 0
var _stroke_p := Vector2.ZERO
var _stroke_t: int = 0
var _dur_sum: float = 0.0
var _dur_sq: float = 0.0


func _init(aspect_ratio: float = 16.0 / 9.0) -> void:
	aspect = aspect_ratio
	_points.resize(BUFFER_SIZE)
	_times.resize(BUFFER_SIZE)


## Faixa x (0–1 da viewport) ocupada pelo ingrediente na tábua, para a cobertura.
func set_chop_area(x_min: float, x_max: float) -> void:
	_area_min_x = x_min
	_area_max_x = x_max


func begin(gesture_mode: int, p: Vector2, t_ms: int) -> void:
	mode = gesture_mode
	active = true
	dragging = false
	flipped = false
	last_events = Event.NONE
	_count = 0
	_start_p = p
	_start_t = t_ms
	_pan_resolved = false
	_shook = false
	_max_pull = 0.0
	cuts = 0
	last_stroke_ms = 0
	last_stroke_bands = 0
	coverage_mask = 0
	_dur_sum = 0.0
	_dur_sq = 0.0
	_reset_stroke(p, t_ms)
	_store(p, t_ms)


func add_sample(p: Vector2, t_ms: int) -> int:
	var ev: int = Event.NONE
	if not active:
		last_events = ev
		return ev
	match mode:
		Mode.DRAG:
			ev = _step_drag(p)
		Mode.PAN:
			ev = _step_pan(p, t_ms)
		Mode.CHOP:
			ev = _step_chop(p, t_ms)
	_store(p, t_ms)
	last_events = ev
	return ev


func finish(p: Vector2, t_ms: int) -> int:
	if not active:
		return Kind.NONE
	var ev := add_sample(p, t_ms)
	active = false
	var kind: int = Kind.NONE
	match mode:
		Mode.CHOP:
			if _dir != 0:
				ev |= _close_stroke(_ext_p, _ext_t)
			kind = Kind.CHOP
		Mode.PAN:
			if flipped:
				kind = Kind.FLIP
			elif dragging:
				kind = Kind.DRAG
			elif _shook or _max_pull >= SHAKE_MIN_U:
				if not _shook:
					ev |= Event.SHAKE
					_shook = true
				kind = Kind.SHAKE
			else:
				kind = _tap_or_none(t_ms)
		_:
			kind = Kind.DRAG if dragging else _tap_or_none(t_ms)
	last_events = ev
	return kind


# --- Consultas ---------------------------------------------------------------

func sample_count() -> int:
	return mini(_count, BUFFER_SIZE)


## Amostra i (0 = mais antiga ainda no buffer).
func sample_point(i: int) -> Vector2:
	return _points[_ring_index(i)]


func sample_time(i: int) -> int:
	return _times[_ring_index(i)]


func last_point() -> Vector2:
	return _last_p


func start_point() -> Vector2:
	return _start_p


## Deslocamento desde o início, em u.
func displacement_u() -> float:
	return distance_u(_start_p, _last_p, aspect)


func chop_cv() -> float:
	return cv_of(cuts, _dur_sum, _dur_sq)


func chop_bands() -> int:
	return count_bands(coverage_mask)


func chop_coverage() -> float:
	return float(chop_bands()) / CHOP_BANDS


func chop_quality() -> int:
	return grade_chop(chop_cv(), chop_bands())


## Qualidade de alinhamento da soltura (último ponto) em relação ao centro do alvo.
func drop_quality(center: Vector2) -> int:
	return grade_alignment(distance_u(_last_p, center, aspect))


## Deslocamento visual da soltura em u (x corrigido), limitado a 0,03 u.
func drop_offset_u(center: Vector2) -> Vector2:
	var off := Vector2((_last_p.x - center.x) * aspect, _last_p.y - center.y)
	return off.limit_length(ALIGN_MAX_OFFSET_U)


# --- Funções puras -----------------------------------------------------------

static func distance_u(a: Vector2, b: Vector2, aspect_ratio: float) -> float:
	return Vector2((a.x - b.x) * aspect_ratio, a.y - b.y).length()


static func grade_alignment(d_u: float) -> int:
	if d_u <= ALIGN_PERFECT_U:
		return Kitchen.Quality.PERFECT
	if d_u <= ALIGN_GOOD_U:
		return Kitchen.Quality.GOOD
	return Kitchen.Quality.CLUMSY


static func grade_chop(cv: float, bands: int) -> int:
	if cv <= CHOP_CV_PERFECT and bands >= CHOP_BANDS:
		return Kitchen.Quality.PERFECT
	if cv <= CHOP_CV_GOOD and bands >= CHOP_BANDS_GOOD:
		return Kitchen.Quality.GOOD
	return Kitchen.Quality.CLUMSY


## Coeficiente de variação (desvio-padrão populacional / média). 0 se n < 2.
static func cv_of(n: int, sum: float, sum_sq: float) -> float:
	if n < 2 or sum <= 0.0:
		return 0.0
	var mean := sum / n
	var variance := maxf(sum_sq / n - mean * mean, 0.0)
	return sqrt(variance) / mean


static func count_bands(mask: int) -> int:
	var n := 0
	for i in CHOP_BANDS:
		if mask & (1 << i):
			n += 1
	return n


# --- Interno -----------------------------------------------------------------

func _store(p: Vector2, t_ms: int) -> void:
	var i := _count % BUFFER_SIZE
	_points[i] = p
	_times[i] = t_ms
	_count += 1
	_last_p = p
	_last_t = t_ms


func _ring_index(i: int) -> int:
	var first := 0 if _count <= BUFFER_SIZE else _count % BUFFER_SIZE
	return (first + i) % BUFFER_SIZE


func _tap_or_none(t_ms: int) -> int:
	if displacement_u() < DRAG_MIN_U and t_ms - _start_t < TAP_MAX_MS:
		return Kind.TAP
	return Kind.NONE


func _step_drag(p: Vector2) -> int:
	if not dragging and distance_u(_start_p, p, aspect) >= DRAG_MIN_U:
		dragging = true
		return Event.DRAG_STARTED
	return Event.NONE


func _step_pan(p: Vector2, t_ms: int) -> int:
	if flipped:
		return Event.NONE
	if not _pan_resolved:
		if t_ms - _start_t <= FLIP_MAX_MS:
			var up := _start_p.y - p.y
			var dx := absf(p.x - _start_p.x) * aspect
			if up > 0.0 and dx <= FLIP_MAX_DX_RATIO * up:
				_max_pull = maxf(_max_pull, up)
				if up >= FLIP_MIN_U:
					flipped = true
					_pan_resolved = true
					return Event.FLIP
				return Event.NONE
			# Não é puxão: cai para arrastar abaixo.
			if distance_u(_start_p, p, aspect) >= DRAG_MIN_U:
				_pan_resolved = true
		else:
			_pan_resolved = true
			if _max_pull >= SHAKE_MIN_U:
				_shook = true
				return Event.SHAKE
	return _step_drag(p)


func _step_chop(p: Vector2, t_ms: int) -> int:
	var ev: int = Event.NONE
	if t_ms - _last_t > CHOP_PAUSE_MS:
		if _dir != 0:
			ev |= _close_stroke(_ext_p, _ext_t)
		_reset_stroke(p, t_ms)
		return ev | Event.SESSION_ENDED
	if _dir == 0:
		var dy := p.y - _stroke_p.y
		if absf(dy) >= CHOP_REVERSAL_U:
			_dir = 1 if dy > 0.0 else -1
			_ext_p = p
			_ext_t = t_ms
		return ev
	if (p.y - _ext_p.y) * _dir > 0.0:
		_ext_p = p
		_ext_t = t_ms
	elif (_ext_p.y - p.y) * _dir >= CHOP_REVERSAL_U:
		ev |= _close_stroke(_ext_p, _ext_t)
		_stroke_p = _ext_p
		_stroke_t = _ext_t
		_dir = -_dir
		_ext_p = p
		_ext_t = t_ms
	return ev


func _reset_stroke(p: Vector2, t_ms: int) -> void:
	_dir = 0
	_stroke_p = p
	_stroke_t = t_ms
	_ext_p = p
	_ext_t = t_ms


## Fecha o traço atual (início -> extremo). Retorna Event.CUT se válido.
func _close_stroke(end_p: Vector2, end_t: int) -> int:
	var dy := absf(end_p.y - _stroke_p.y)
	var dur := end_t - _stroke_t
	if dy < CHOP_MIN_DY_U or dur < CHOP_MIN_MS or dur > CHOP_MAX_MS:
		return Event.NONE
	cuts += 1
	_dur_sum += dur
	_dur_sq += float(dur) * dur
	last_stroke_ms = dur
	last_stroke_bands = _band_bit(_stroke_p.x) | _band_bit(end_p.x)
	coverage_mask |= last_stroke_bands
	return Event.CUT


func _band_bit(x: float) -> int:
	var w := _area_max_x - _area_min_x
	if w <= 0.0 or x < _area_min_x or x > _area_max_x:
		return 0
	var band := mini(int((x - _area_min_x) / w * CHOP_BANDS), CHOP_BANDS - 1)
	return 1 << band
