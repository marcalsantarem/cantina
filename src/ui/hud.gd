extends CanvasLayer
## HUD da cozinha: bilhetes, bilhete-resposta e palavra de feedback.
## Fala com a cozinha só por sinais (contrato BRF-007): ticket_added, ticket_served,
## gesture_feedback e get_slot_screen_position(slot); opcional action_hint(text, screen_pos) (BRF-011).
## O prato vai sempre para o bilhete mais antigo aberto (FIFO): ele ganha o destaque "próximo".
## Em telas baixas os bilhetes são ampliados para a frase ter ao menos min_phrase_px na tela,
## sem passar do que deixa SLOTS bilhetes lado a lado.
## M2 (BRF-016), sinais opcionais: ticket_item_delivered, ticket_mood_changed,
## shift_phase_changed (placas) e shift_ended (tela de fim; "Jogar de novo" -> replay_requested).
## Ressalvas M2 (BRF-019): pause_changed (aviso "Pausado"); o balão de dica não cobre a fita "próximo";
## a escala usa px de CSS (divide pelo devicePixelRatio), não px físicos.

signal replay_requested

const TicketCardScene := preload("res://scenes/ui/ticket_card.tscn")
const FeedbackWord := preload("res://src/ui/feedback_word.gd")
const HintBubble := preload("res://src/ui/hint_bubble.gd")
const PhaseBanner := preload("res://src/ui/phase_banner.gd")
const EndScreen := preload("res://src/ui/end_screen.gd")
const UiText := preload("res://src/ui/ui_text.gd")
const GAP := 6.0
const MARGIN := 8.0
## Vagas do trilho (Slot1..Slot4) e largura de projeto de um bilhete.
const SLOTS := 4
const CARD_WIDTH := 190.0
## Sinais da cozinha -> método do HUD (opcionais: liga só os que existirem).
const OPTIONAL_SIGNALS := {
	"action_hint": "_on_action_hint",
	"ticket_item_delivered": "_on_ticket_item_delivered",
	"ticket_mood_changed": "_on_ticket_mood_changed",
	"shift_phase_changed": "_on_shift_phase_changed",
	"shift_ended": "_on_shift_ended",
	"pause_changed": "_on_pause_changed",
}

## Tempo que o bilhete-resposta fica visível.
@export var reply_seconds := 4.0
## Altura mínima (px de tela) do texto da frase do bilhete.
@export var min_phrase_px := 16.0
## Escala a partir da qual o bilhete fica compacto (frase em 1 linha): só telas baixas, não o desktop.
const COMPACT_SCALE := 1.2
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


## Px reais (CSS) por unidade lógica: altura da janela em px físicos / altura lógica / devicePixelRatio.
static func screen_scale_for(window_h: float, visible_h: float, dpr := 1.0) -> float:
	if window_h <= 0.0 or visible_h <= 0.0:
		return 1.0
	return window_h / visible_h / (dpr if dpr > 0.0 else 1.0)


## Maior escala que ainda deixa SLOTS bilhetes lado a lado na largura visível.
static func fit_scale_for(visible_width: float) -> float:
	return maxf((visible_width - 2.0 * MARGIN) / (SLOTS * CARD_WIDTH + (SLOTS - 1) * GAP), 0.5)

@onready var _tickets: Control = $Tickets
@onready var _feedback: Control = $Feedback
@onready var _hint: Control = $Hint
@onready var _overlay: Control = $Overlay
var _bubble: PanelContainer
var _banner: PanelContainer
var _end: Control
var _pause: Control


func _ready() -> void:
	_bubble = HintBubble.new()
	_hint.add_child(_bubble)
	_banner = PhaseBanner.new()
	_overlay.add_child(_banner)
	_end = EndScreen.new()
	_overlay.add_child(_end)
	_end.replay_requested.connect(replay_requested.emit)
	_pause = _make_pause_overlay()
	_overlay.add_child(_pause)
	get_viewport().size_changed.connect(_refresh_anchors)
	_refresh_anchors()


func bind(controller: Node) -> void:
	unbind()
	_controller = controller
	controller.connect("ticket_added", _on_ticket_added)
	controller.connect("ticket_served", _on_ticket_served)
	controller.connect("gesture_feedback", _on_gesture_feedback)
	for sig: String in OPTIONAL_SIGNALS:
		if controller.has_signal(sig):
			controller.connect(sig, Callable(self, OPTIONAL_SIGNALS[sig]))


func unbind() -> void:
	if _controller == null or not is_instance_valid(_controller):
		_controller = null
		return
	var pairs := [["ticket_added", _on_ticket_added], ["ticket_served", _on_ticket_served],
			["gesture_feedback", _on_gesture_feedback]]
	for sig: String in OPTIONAL_SIGNALS:
		pairs.append([sig, Callable(self, OPTIONAL_SIGNALS[sig])])
	for pair in pairs:
		if _controller.has_signal(pair[0]) and _controller.is_connected(pair[0], pair[1]):
			_controller.disconnect(pair[0], pair[1])
	_controller = null
	_bubble.hide_hint()
	_pause.visible = false


## Balão de dica de ação.
func get_hint() -> PanelContainer:
	return _bubble


## Placa do turno.
func get_banner() -> PanelContainer:
	return _banner


## Aviso de pausa ("Pausado — toque para voltar").
func get_pause_overlay() -> Control:
	return _pause


## Tela de fim de turno.
func get_end_screen() -> Control:
	return _end


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


func _on_action_hint(text: String, screen_pos: Vector2) -> void:
	_bubble.avoid = _avoid_rects()
	_bubble.show_hint(text, screen_pos)


## Pausa por perda de foco: aviso por cima da cozinha. Não pega o toque (a cozinha retoma).
func _on_pause_changed(paused: bool) -> void:
	_pause.visible = paused


func _make_pause_overlay() -> Control:
	var dim := ColorRect.new()
	dim.name = "Pause"
	dim.color = Color(0.16, 0.1, 0.08, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	var label := Label.new()
	label.text = UiText.PAUSED
	label.theme_type_variation = &"HintLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"HintBubble"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.add_child(panel)
	dim.add_child(center)
	return dim


## O que o balão de dica não deve cobrir: a fita "próximo".
func _avoid_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var card := get_card(get_next_slot())
	if card:
		var r: Rect2 = card.next_tag_screen_rect()
		if r.has_area():
			out.append(r.grow(4.0))
	return out


func _on_ticket_item_delivered(slot: int, _ticket: TicketData, item_index: int) -> void:
	var card := get_card(slot)
	if card:
		card.mark_delivered(item_index)


func _on_ticket_mood_changed(slot: int, mood: int) -> void:
	var card := get_card(slot)
	if card:
		card.mood = mood


func _on_shift_phase_changed(phase: int) -> void:
	if phase >= 0 and phase < UiText.PHASE_BANNERS.size():
		_banner.show_text(UiText.PHASE_BANNERS[phase])


func _on_shift_ended(summary: Dictionary) -> void:
	_bubble.hide_hint()
	_end.ui_scale = ui_scale
	_end.show_summary(summary)


func _new_card(slot: int, ticket: TicketData) -> Control:
	var card := TicketCardScene.instantiate()
	card.slot = slot
	card.compact = ui_scale >= COMPACT_SCALE
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
	_bubble.avoid = _avoid_rects()


## Posição do slot nas coordenadas (escaladas) de _tickets.
func _slot_pos(slot: int) -> Vector2:
	if is_instance_valid(_controller) and _controller.has_method("get_slot_screen_position"):
		return _controller.get_slot_screen_position(slot) / ui_scale
	return Vector2.ZERO


## Pixels de tela por unidade lógica (stretch canvas_items).
func _screen_scale() -> float:
	var win := get_window()
	if win == null:
		return 1.0
	return screen_scale_for(float(win.size.y), get_viewport().get_visible_rect().size.y,
			DisplayServer.screen_get_scale())


func _refresh_anchors() -> void:
	if _forced_scale > 0.0:
		ui_scale = _forced_scale
	else:
		var fs := float(_tickets.get_theme_font_size("font_size", "TicketPhrase"))
		ui_scale = ticket_scale_for(_screen_scale(), fs, min_phrase_px, max_ui_scale)
		ui_scale = minf(ui_scale, maxf(fit_scale_for(get_viewport().get_visible_rect().size.x), 1.0))
	_tickets.scale = Vector2.ONE * ui_scale
	_bubble.ui_scale = ui_scale
	_banner.ui_scale = ui_scale
	_end.ui_scale = ui_scale
	_tickets.size = get_viewport().get_visible_rect().size / ui_scale
	for card in _tickets.get_children():
		card.compact = ui_scale >= COMPACT_SCALE
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
	_bubble.avoid = _avoid_rects()
