extends CanvasLayer
## HUD da cozinha: bilhetes, bilhete-resposta e palavra de feedback.
## Fala com a cozinha só por sinais (contrato BRF-007): ticket_added, ticket_served,
## gesture_feedback e get_slot_screen_position(slot).
## O prato vai sempre para o bilhete mais antigo aberto (FIFO): ele ganha o destaque "próximo".
## Em telas baixas os bilhetes são ampliados para a frase ter ao menos min_phrase_px na tela.

const TicketCardScene := preload("res://scenes/ui/ticket_card.tscn")
const FeedbackWord := preload("res://src/ui/feedback_word.gd")
const GAP := 6.0
const MARGIN := 8.0

## Tempo que o bilhete-resposta fica visível.
@export var reply_seconds := 4.0
## Altura mínima (px de tela) do texto da frase do bilhete.
@export var min_phrase_px := 13.0
## Ampliação máxima dos bilhetes.
@export var max_ui_scale := 2.0

## Escala aplicada aos bilhetes (1 = tamanho de projeto).
var ui_scale := 1.0
var _controller: Node
var _open := {}  # slot -> bilhete aberto
var _order: Array[int] = []  # slots abertos, do mais antigo ao mais novo
var _forced_scale := 0.0


## Escala dos bilhetes para que font_size * screen_scale * escala >= min_px.
static func ticket_scale_for(screen_scale: float, font_size: float, min_px: float, max_scale := 2.0) -> float:
	if screen_scale <= 0.0 or font_size <= 0.0:
		return 1.0
	return clampf(min_px / (font_size * screen_scale), 1.0, max_scale)

@onready var _tickets: Control = $Tickets
@onready var _feedback: Control = $Feedback


func _ready() -> void:
	get_viewport().size_changed.connect(_refresh_anchors)
	_refresh_anchors()


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


## Slot do bilhete que recebe o próximo prato (o mais antigo aberto), ou -1.
func get_next_slot() -> int:
	for slot in _order:
		if get_card(slot) != null:
			return slot
	return -1


## Força a escala dos bilhetes (testes/capturas); <= 0 volta ao cálculo automático.
func set_ui_scale(value: float) -> void:
	_forced_scale = value
	_refresh_anchors()


func _on_ticket_added(slot: int, ticket: TicketData) -> void:
	var old := get_card(slot)
	if old:
		old.dismiss(0.15)
	_open[slot] = _new_card(slot, ticket)
	_order.erase(slot)
	_order.append(slot)
	_update_next()
	_layout()


func _on_ticket_served(slot: int, ticket: TicketData, _score: int, band: int, reply: String) -> void:
	var card := get_card(slot)
	if card == null:
		card = _new_card(slot, ticket)
	_open.erase(slot)
	_order.erase(slot)
	_update_next()
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
	card.compact = ui_scale > 1.0
	_tickets.add_child(card)
	card.resized.connect(_layout)
	card.tree_exited.connect(_layout)
	card.anchor_point = _slot_pos(slot)
	card.show_ticket(ticket)
	return card


func _update_next() -> void:
	var next := get_next_slot()
	for slot in _open:
		var card := get_card(slot)
		if card:
			card.is_next = slot == next


## Posição do slot nas coordenadas (escaladas) de _tickets.
func _slot_pos(slot: int) -> Vector2:
	if is_instance_valid(_controller) and _controller.has_method("get_slot_screen_position"):
		return _controller.get_slot_screen_position(slot) / ui_scale
	return Vector2.ZERO


## Pixels de tela por unidade lógica (stretch canvas_items).
func _screen_scale() -> float:
	var vis := get_viewport().get_visible_rect().size
	var win := get_window()
	if win == null or vis.y <= 0.0 or win.size.y <= 0:
		return 1.0
	return float(win.size.y) / vis.y


func _refresh_anchors() -> void:
	if _forced_scale > 0.0:
		ui_scale = _forced_scale
	else:
		var fs := float(_tickets.get_theme_font_size("font_size", "TicketPhrase"))
		ui_scale = ticket_scale_for(_screen_scale(), fs, min_phrase_px, max_ui_scale)
	_tickets.scale = Vector2.ONE * ui_scale
	_tickets.size = get_viewport().get_visible_rect().size / ui_scale
	for card in _tickets.get_children():
		card.compact = ui_scale > 1.0
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
