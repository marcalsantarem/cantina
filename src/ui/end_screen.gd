extends Control
## Tela de fim de turno (m2_turno §2): estrelas uma a uma, pedidos atendidos, nota média,
## agilidade em palavra, melhor frase do dia e "Jogar de novo". Bloqueia toque/mouse na cozinha.
## Recebe o resumo de `ShiftScorer.summarize` (sinal `shift_ended`).

signal replay_requested

const UiText := preload("res://src/ui/ui_text.gd")
const STAR_COUNT := 3
const STAR_SIZE := 64.0
## Intervalo entre estrelas (s) e atraso da primeira.
const STAR_STEP_S := 0.45
const STAR_DELAY_S := 0.4
const DIM := Color(0.18, 0.11, 0.08, 0.55)
const MARGIN := 16.0

## Ampliação do painel (mesma do HUD em telas baixas); limitada para caber na tela.
var ui_scale := 1.0:
	set(v):
		ui_scale = v
		_fit()

var stars := 0
var _panel: PanelContainer
var _title: Label
var _star_row: HBoxContainer
var _served: Label
var _avg: Label
var _agility: Label
var _best_caption: Label
var _best: Label
var _replay: Button
var _done := false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"ReplyPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fffdf6")
	sb.border_color = Color("#46c08f")
	sb.border_width_bottom = 5
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 48.0
	sb.content_margin_right = 48.0
	sb.content_margin_top = 22.0
	sb.content_margin_bottom = 28.0
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	_title = _label(box, &"OverlayLabel")
	_star_row = HBoxContainer.new()
	_star_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_star_row.add_theme_constant_override("separation", 14)
	_star_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_star_row)
	for i in STAR_COUNT:
		var s := Star.new()
		s.custom_minimum_size = Vector2.ONE * STAR_SIZE
		_star_row.add_child(s)
	_served = _label(box, &"HintText", 24)
	_avg = _label(box, &"HintText", 24)
	_agility = _label(box, &"HintText", 24)
	_best_caption = _label(box, &"TicketPhrase", 17)
	_best = _label(box, &"TicketName", 21)
	_best.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_best.custom_minimum_size.x = 420.0
	_replay = Button.new()
	_replay.text = UiText.END_REPLAY
	_replay.custom_minimum_size = Vector2(260, 64)
	_replay.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_replay.pressed.connect(_on_replay)
	box.add_child(_replay)


func _ready() -> void:
	_panel.resized.connect(_fit)
	get_viewport().size_changed.connect(_fit)


static func _label(parent: Node, variation: StringName, font_size := 0) -> Label:
	var l := Label.new()
	l.theme_type_variation = variation
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font_size > 0:
		l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l


## Mostra o resumo do turno. Chaves de `ShiftScorer.summarize`.
func show_summary(summary: Dictionary) -> void:
	_done = false
	stars = clampi(int(summary.get("stars", 1)), 0, STAR_COUNT)
	_title.text = UiText.END_TITLE
	_served.text = UiText.END_SERVED % [int(summary.get("served", 0)), int(summary.get("arrived", 0))]
	_avg.text = UiText.END_AVG % int(summary.get("avg_score", 0))
	_agility.text = UiText.END_AGILITY % String(summary.get("agility_word", ""))
	var best := String(summary.get("best_reply", ""))
	_best_caption.text = UiText.END_BEST
	_best.text = "“%s”" % best
	_best_caption.visible = not best.is_empty()
	_best.visible = not best.is_empty()
	visible = true
	modulate.a = 0.0
	_fit.call_deferred()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
	for i in STAR_COUNT:
		var s: Star = _star_row.get_child(i)
		s.earned = i < stars
		s.pop = 0.0
		tw.tween_interval(STAR_DELAY_S if i == 0 else STAR_STEP_S)
		tw.tween_property(s, "pop", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Pula a animação das estrelas (capturas/testes).
func finish_animation() -> void:
	modulate.a = 1.0
	for s: Star in _star_row.get_children():
		s.pop = 1.0


func replay_button() -> Button:
	return _replay


func star_nodes() -> Array[Node]:
	return _star_row.get_children()


func texts() -> PackedStringArray:
	return PackedStringArray([_title.text, _served.text, _avg.text, _agility.text, _best.text if _best.visible else ""])


func _on_replay() -> void:
	if _done:
		return
	_done = true
	replay_requested.emit()


func _fit() -> void:
	if _panel == null or not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	_panel.reset_size()
	var ps := _panel.get_combined_minimum_size()
	var k := ui_scale
	if ps.x > 0.0 and ps.y > 0.0:
		k = minf(k, minf((vp.x - 2.0 * MARGIN) / ps.x, (vp.y - 2.0 * MARGIN) / ps.y))
	_panel.scale = Vector2.ONE * k
	_panel.position = (vp - ps * k) * 0.5


## Estrela desenhada: cheia (ganha) ou só contorno. `pop` 0..1 anima a entrada.
class Star extends Control:
	const GOLD := Color("#f2b33d")
	const GOLD_EDGE := Color("#c76b45")
	const EMPTY := Color("#d9c9b0")

	var earned := false:
		set(v):
			earned = v
			queue_redraw()
	var pop := 1.0:
		set(v):
			pop = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5 * pop
		if r <= 0.5:
			return
		var c := size * 0.5
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI * 0.5 + PI * i / 5.0
			var rr := r if i % 2 == 0 else r * 0.45
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		if earned:
			draw_colored_polygon(pts, GOLD)
		pts.append(pts[0])
		draw_polyline(pts, GOLD_EDGE if earned else EMPTY, 3.0, true)
