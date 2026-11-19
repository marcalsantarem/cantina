extends CanvasLayer
## HUD da cozinha: bilhetes, bilhete-resposta e palavra de feedback.
## Fala com a cozinha só por sinais (contrato BRF-007): ticket_added, ticket_served,
## gesture_feedback e get_slot_screen_position(slot).

const TicketCardScene := preload("res://scenes/ui/ticket_card.tscn")
const FeedbackWord := preload("res://src/ui/feedback_word.gd")
const GAP := 6.0
const MARGIN := 8.0

## Tempo que o bilhete-resposta fica visível.
@export var reply_seconds := 4.0

var _controller: Node
var _open := {}  # slot -> bilhete aberto

@onready var _tickets: Control = $Tickets
@onready var _feedback: Control = $Feedback


func _ready() -> void:
	get_viewport().size_changed.connect(_refresh_anchors)


func bind(controller: Node) -> void:
	unbind()
	_controller = controller
	controller.ticket_added.connect(_on_ticket_added)
	controller.ticket_served.connect(_on_ticket_served)
	controller.gesture_feedback.connect(_on_gesture_feedback)


func unbind() -> void:
	if _controller == null or not is_instance_valid(_controller):
		_controller = null
		return
	for pair in [["ticket_added", _on_ticket_added], ["ticket_served", _on_ticket_served],
			["gesture_feedback", _on_gesture_feedback]]:
		if _controller.is_connected(pair[0], pair[1]):
			_controller.disconnect(pair[0], pair[1])
	_controller = null


## Bilhete aberto no slot (ou null).
func get_card(slot: int) -> Control:
	var card: Control = _open.get(slot)
	return card if is_instance_valid(card) else null


func get_cards() -> Array[Node]:
	return _tickets.get_children()


func _on_ticket_added(slot: int, ticket: TicketData) -> void:
	var old := get_card(slot)
	if old:
		old.dismiss(0.15)
	_open[slot] = _new_card(slot, ticket)
	_layout()


func _on_ticket_served(slot: int, ticket: TicketData, _score: int, band: int, reply: String) -> void:
	var card := get_card(slot)
	if card == null:
		card = _new_card(slot, ticket)
	_open.erase(slot)
	card.show_reply(reply, band)
	card.dismiss_after(reply_seconds)
	_layout()


func _on_gesture_feedback(quality: int, label: String, screen_pos: Vector2) -> void:
	var word := FeedbackWord.new()
	_feedback.add_child(word)
	word.pop(label, quality, screen_pos)


func _new_card(slot: int, ticket: TicketData) -> Control:
	var card := TicketCardScene.instantiate()
	card.slot = slot
	_tickets.add_child(card)
	card.resized.connect(_layout)
	card.tree_exited.connect(_layout)
	card.anchor_point = _slot_pos(slot)
	card.show_ticket(ticket)
	return card


func _slot_pos(slot: int) -> Vector2:
	if is_instance_valid(_controller) and _controller.has_method("get_slot_screen_position"):
		return _controller.get_slot_screen_position(slot)
	return Vector2.ZERO


func _refresh_anchors() -> void:
	for card in _tickets.get_children():
		card.anchor_point = _slot_pos(card.slot)
	_layout()


## Afasta bilhetes vizinhos para não se sobreporem e mantém o grupo dentro da tela.
func _layout() -> void:
	if not is_inside_tree():
		return
	var cards: Array = _tickets.get_children().filter(func(c): return not c.dismissing and not c.is_queued_for_deletion())
	if cards.is_empty():
		return
	cards.sort_custom(func(a, b): return a.anchor_point.x < b.anchor_point.x)
	var lefts: Array[float] = []
	var right_edge := -INF
	for c in cards:
		var left := maxf(c.anchor_point.x - c.size.x * 0.5, right_edge + GAP)
		lefts.append(left)
		right_edge = left + c.size.x
	var overflow := right_edge - (_tickets.size.x - MARGIN)
	for i in cards.size():
		var c: Control = cards[i]
		var left := lefts[i] - maxf(overflow, 0.0)
		c.layout_shift = Vector2(left - (c.anchor_point.x - c.size.x * 0.5), 0)
