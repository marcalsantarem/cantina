extends PanelContainer
## Bilhete de papel no trilho. Vira bilhete-resposta ao servir e some depois.
## Posição: base inferior centrada em anchor_point (+ deslocamentos), presa à tela.

const UiText := preload("res://src/ui/ui_text.gd")
const ICON_PATH := "res://assets/icons/%s.png"
const RAIL_OVERLAP := 14.0
const MARGIN := 8.0
const CLIP_COLOR := Color("#9ea8ad")

var slot := -1
var is_reply := false
var dismissing := false
var anchor_point := Vector2.ZERO:
	set(v):
		anchor_point = v
		_place()
## Ajuste do HUD para não sobrepor bilhetes vizinhos.
var layout_shift := Vector2.ZERO:
	set(v):
		layout_shift = v
		_place()
var float_offset := Vector2.ZERO:
	set(v):
		float_offset = v
		_place()

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _phrase: Label = %Phrase
@onready var _without: Label = %Without
@onready var _stamp: Control = %Stamp


func _ready() -> void:
	resized.connect(_place)
	rotation = randf_range(-0.035, 0.035)


func show_ticket(ticket: TicketData) -> void:
	_name.text = ticket.nickname
	_phrase.text = ticket.phrase
	var icon_path := ICON_PATH % ticket.recipe
	_icon.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null
	_icon.visible = _icon.texture != null
	_without.visible = not ticket.without.is_empty()
	if _without.visible:
		_without.text = UiText.without_text(ticket.without)
	_stamp.visible = false
	modulate.a = 0.0
	scale = Vector2(0.85, 0.85)
	float_offset = Vector2(0, -36)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)
	tw.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "float_offset", Vector2.ZERO, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_reply(reply: String, band: int) -> void:
	is_reply = true
	var tw := create_tween()
	tw.tween_property(self, "scale:x", 0.0, 0.15).set_ease(Tween.EASE_IN)
	tw.tween_callback(apply_reply.bind(reply, band))
	tw.tween_property(self, "scale:x", 1.0, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(_stamp, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(_stamp, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


## Troca o conteúdo para o bilhete-resposta (sem animação).
func apply_reply(reply: String, band: int) -> void:
	is_reply = true
	theme_type_variation = &"ReplyPanel"
	_icon.visible = false
	_without.visible = false
	_phrase.text = reply
	_stamp.band = band
	_stamp.visible = true
	_stamp.pivot_offset = _stamp.custom_minimum_size * 0.5
	_stamp.modulate.a = 0.0
	_stamp.scale = Vector2(1.8, 1.8)


func stamp_band() -> int:
	return _stamp.band if _stamp.visible else -1


func phrase_text() -> String:
	return _phrase.text


func without_label() -> Label:
	return _without


func icon_texture() -> Texture2D:
	return _icon.texture if _icon.visible else null


func dismiss_after(seconds: float) -> void:
	get_tree().create_timer(seconds).timeout.connect(dismiss)


func dismiss(duration := 0.4) -> void:
	if dismissing or not is_inside_tree():
		return
	dismissing = true
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 0.0, duration)
	tw.tween_property(self, "float_offset", Vector2(0, -24), duration)
	tw.chain().tween_callback(queue_free)


func _place() -> void:
	if not is_inside_tree():
		return
	pivot_offset = size * 0.5
	var vp := get_viewport_rect().size
	var p := anchor_point + layout_shift + float_offset - Vector2(size.x * 0.5, size.y - RAIL_OVERLAP)
	p.x = clampf(p.x, MARGIN, maxf(MARGIN, vp.x - size.x - MARGIN))
	p.y = maxf(p.y, MARGIN)
	position = p


func _draw() -> void:
	var clip := Rect2(size.x * 0.5 - 16.0, -7.0, 32.0, 13.0)
	draw_rect(clip, CLIP_COLOR)
	draw_rect(Rect2(clip.position + Vector2(0, clip.size.y - 3), Vector2(clip.size.x, 3)), CLIP_COLOR.darkened(0.25))
