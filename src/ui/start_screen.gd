extends Control
## Tela inicial: um toque (ou clique/Enter) começa o jogo.
## O toque também será o gesto que libera o áudio na Web (futuro).

signal started

const UiText := preload("res://src/ui/ui_text.gd")

var _done := false


func _ready() -> void:
	%Title.text = UiText.START_TITLE
	%Hint.text = UiText.START_HINT
	%Credits.text = UiText.START_CREDITS
	var tw := create_tween().set_loops()
	tw.tween_property(%Hint, "modulate:a", 0.35, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(%Hint, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed:
		accept_event()
		begin()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		begin()


func begin() -> void:
	if _done:
		return
	_done = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	started.emit()
