extends PanelContainer
## Placa do turno (decisão 21): grande e breve, no alto da tela. Não recebe toque/mouse.
## show_text(texto) entra com estalo, fica HOLD_S e some.

const HOLD_S := 1.8
const TEXT_COLOR := Color("#fff9ec")
const FILL := Color("#e8713a")
const EDGE := Color("#c76b45")
## Altura do centro da placa (fração da tela).
const CENTER_Y := 0.3

## Ampliação (mesma do HUD em telas baixas).
var ui_scale := 1.0:
	set(v):
		ui_scale = v
		scale = Vector2.ONE * v
		_place()

var _label: Label
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = FILL
	sb.border_color = EDGE
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 40.0
	sb.content_margin_right = 40.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 14.0
	sb.shadow_color = Color(0.29, 0.18, 0.13, 0.35)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 5)
	add_theme_stylebox_override("panel", sb)
	_label = Label.new()
	_label.theme_type_variation = &"OverlayLabel"
	_label.add_theme_font_size_override("font_size", 60)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _ready() -> void:
	resized.connect(_place)
	get_viewport().size_changed.connect(_place)


func show_text(text: String) -> void:
	if text.is_empty():
		return
	_label.text = text
	reset_size()
	visible = true
	_place()
	if _tween:
		_tween.kill()
	modulate.a = 0.0
	scale = Vector2.ONE * ui_scale * 0.6
	_tween = create_tween()
	_tween.set_parallel()
	_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	_tween.tween_property(self, "scale", Vector2.ONE * ui_scale, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(HOLD_S)
	_tween.chain().tween_property(self, "modulate:a", 0.0, 0.35)
	_tween.chain().tween_callback(hide)


func banner_text() -> String:
	return _label.text


func is_shown() -> bool:
	return visible and _tween != null and _tween.is_valid()


func _place() -> void:
	if not is_inside_tree():
		return
	pivot_offset = size * 0.5
	var vp := get_viewport().get_visible_rect().size
	position = Vector2(vp.x * 0.5, vp.y * CENTER_Y) - size * 0.5
