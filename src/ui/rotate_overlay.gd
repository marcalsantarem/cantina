extends CanvasLayer
## Cobre a tela com "Gire o celular" enquanto a viewport estiver em retrato.

const UiText := preload("res://src/ui/ui_text.gd")

var _tween: Tween


static func is_portrait(viewport_size: Vector2) -> bool:
	return viewport_size.y > viewport_size.x


func _ready() -> void:
	%Hint.text = UiText.ROTATE_HINT
	get_viewport().size_changed.connect(refresh)
	refresh()


func refresh() -> void:
	visible = is_portrait(get_viewport().get_visible_rect().size)
	if visible and _tween == null:
		var phone: Control = %Phone
		phone.pivot_offset = phone.custom_minimum_size * 0.5
		_tween = create_tween().set_loops()
		_tween.tween_property(phone, "rotation", -PI / 2, 0.7).set_trans(Tween.TRANS_CUBIC).set_delay(0.5)
		_tween.tween_property(phone, "rotation", 0.0, 0.0).set_delay(0.9)
	elif not visible and _tween:
		_tween.kill()
		_tween = null
