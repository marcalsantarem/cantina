class_name GestureRecognizer
extends RefCounted
## Reconhece tocar e arrastar a partir de amostras (posição 0–1 da viewport, y para baixo;
## tempo em ms). Decisão 22: a única interação é tocar/arrastar/soltar (sem zigue-zague,
## puxão ou círculos). Distâncias em "u" = altura da tela (x corrigido pelo aspecto).
## Nada é alocado por amostra.
##
## Uso: begin(p, t) -> add_sample(p, t) a cada movimento (retorna bits de Event)
## -> finish(p, t) (retorna Kind). `last_events` guarda os bits da última chamada.

## Bits retornados por add_sample/finish.
enum Event { NONE = 0, DRAG_STARTED = 1 }
enum Kind { NONE, TAP, DRAG }

const DRAG_MIN_U := 0.02
const TAP_MAX_MS := 200

## Largura/altura da viewport.
var aspect: float = 16.0 / 9.0
var active: bool = false
var dragging: bool = false
var last_events: int = Event.NONE

var _start_p := Vector2.ZERO
var _start_t: int = 0
var _last_p := Vector2.ZERO


func _init(aspect_ratio: float = 16.0 / 9.0) -> void:
	aspect = aspect_ratio


func begin(p: Vector2, t_ms: int) -> void:
	active = true
	dragging = false
	last_events = Event.NONE
	_start_p = p
	_start_t = t_ms
	_last_p = p


func add_sample(p: Vector2, _t_ms: int) -> int:
	var ev: int = Event.NONE
	if active:
		_last_p = p
		if not dragging and distance_u(_start_p, p, aspect) >= DRAG_MIN_U:
			dragging = true
			ev = Event.DRAG_STARTED
	last_events = ev
	return ev


func finish(p: Vector2, t_ms: int) -> int:
	if not active:
		return Kind.NONE
	add_sample(p, t_ms)
	active = false
	if dragging:
		return Kind.DRAG
	if t_ms - _start_t < TAP_MAX_MS:
		return Kind.TAP
	return Kind.NONE


func start_point() -> Vector2:
	return _start_p


func last_point() -> Vector2:
	return _last_p


static func distance_u(a: Vector2, b: Vector2, aspect_ratio: float) -> float:
	return Vector2((a.x - b.x) * aspect_ratio, a.y - b.y).length()
