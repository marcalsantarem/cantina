extends PanelContainer
## Balão de dica de ação (decisão 18): creme, perto de screen_pos, preso à borda da tela.
## show_hint("") esconde com fade. Não recebe toque/mouse.
## Não cobre `avoid` (ex.: a fita "próximo"): desvia para o lado ou, se não der, para baixo do ponto.
## Também deixa livre a coluna acima do alvo (fumaça da frigideira/panela, aro): fica ao lado dela,
## com o rabicho inclinado para o alvo (T-027).

const MARGIN := 8.0
## Distância (px lógicos do balão) entre screen_pos e a ponta do balão.
const GAP := 26.0
const TAIL := 9.0
const FADE := 0.18
## Coluna livre acima de screen_pos (px lógicos de tela): largura e quanto desce abaixo do ponto.
const COLUMN_W := 120.0
const COLUMN_BELOW := 70.0

## Ampliação do balão (mesma do HUD em telas baixas).
var ui_scale := 1.0:
	set(v):
		ui_scale = v
		scale = Vector2.ONE * v
		_place()

## Retângulos de tela que o balão não deve cobrir.
var avoid: Array[Rect2] = []:
	set(v):
		avoid = v
		if visible:
			_place()

var _target := Vector2.ZERO
var _below := false
var _tween: Tween
var _label: Label
var _fading_in := false


func _init() -> void:
	theme_type_variation = &"HintBubble"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	_label = Label.new()
	_label.theme_type_variation = &"HintText"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)


func _ready() -> void:
	resized.connect(_place)


func show_hint(text: String, screen_pos: Vector2) -> void:
	if text.is_empty():
		hide_hint()
		return
	_label.text = text
	_target = screen_pos
	reset_size()
	_place()
	visible = true
	_fade_to(1.0)


func hide_hint() -> void:
	if not visible:
		return
	_fade_to(0.0)


func hint_text() -> String:
	return _label.text


## Visível e não sumindo.
func is_shown() -> bool:
	return visible and _fading_in


func _fade_to(alpha: float) -> void:
	_fading_in = alpha > 0.0
	if _tween:
		_tween.kill()
	if not is_inside_tree():
		modulate.a = alpha
		visible = alpha > 0.0
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", alpha, FADE)
	if alpha <= 0.0:
		_tween.tween_callback(hide)


func _place() -> void:
	if not is_inside_tree():
		return
	var area := get_viewport().get_visible_rect().size
	var s := size * ui_scale
	var lift := (GAP + TAIL) * ui_scale
	_below = _target.y - lift - s.y < MARGIN
	var p := _clamped(Vector2(_target.x - s.x * 0.5, _target.y + lift if _below else _target.y - lift - s.y), s, area)
	var hit := _hit(p, s)
	if hit.has_area():
		# desvia para o lado mais perto; se ainda cobrir, vai para baixo do ponto.
		var left := _clamped(Vector2(hit.position.x - s.x - MARGIN, p.y), s, area)
		var right := _clamped(Vector2(hit.end.x + MARGIN, p.y), s, area)
		var side := left if absf(left.x - p.x) <= absf(right.x - p.x) else right
		var other := right if side == left else left
		if not _hit(side, s).has_area():
			p = side
		elif not _hit(other, s).has_area():
			p = other
		elif not _below:
			var under := _clamped(Vector2(p.x, _target.y + lift), s, area)
			if not _hit(under, s).has_area():
				_below = true
				p = under
	position = p
	queue_redraw()


func _clamped(p: Vector2, s: Vector2, area: Vector2) -> Vector2:
	return Vector2(clampf(p.x, MARGIN, maxf(MARGIN, area.x - s.x - MARGIN)),
			clampf(p.y, MARGIN, maxf(MARGIN, area.y - s.y - MARGIN)))


## Coluna acima do alvo que o balão deixa livre.
func column_rect() -> Rect2:
	return Rect2(_target.x - COLUMN_W * 0.5, 0.0, COLUMN_W, _target.y + COLUMN_BELOW)


## Primeiro retângulo (`avoid` ou a coluna do alvo) coberto pelo balão em p (ou vazio).
func _hit(p: Vector2, s: Vector2) -> Rect2:
	var r := Rect2(p, s)
	var col := column_rect()
	if r.intersects(col):
		return col
	for a in avoid:
		if a.has_area() and r.intersects(a):
			return a
	return Rect2()


## Retângulo do balão na tela.
func screen_rect() -> Rect2:
	return Rect2(position, size * ui_scale)


## Rabicho apontando para screen_pos.
func _draw() -> void:
	var col := get_theme_stylebox("panel", "HintBubble")
	var bg: Color = col.bg_color if col is StyleBoxFlat else Color.WHITE
	var local := (_target - position) / ui_scale
	var base_x := clampf(local.x, 18.0, size.x - 18.0)
	var base_y := 1.0 if _below else size.y - 1.0
	# ponta inclinada para o alvo quando o balão está ao lado da coluna.
	var dir := (local - Vector2(base_x, base_y)).normalized()
	if dir == Vector2.ZERO or (dir.y > 0.0) == _below:
		dir = Vector2(0, -1 if _below else 1)
	var tip := Vector2(base_x, base_y) + dir * TAIL * 1.6
	draw_colored_polygon(PackedVector2Array([Vector2(base_x - TAIL, base_y), Vector2(base_x + TAIL, base_y), tip]), bg)
