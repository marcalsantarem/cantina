extends Node
## Controlador falso com o contrato de sinais de game.tscn (BRF-007), para testes e capturas da UI.

signal ticket_added(slot: int, ticket: TicketData)
signal ticket_served(slot: int, ticket: TicketData, score: int, band: int, reply: String)
signal gesture_feedback(quality: int, label: String, screen_pos: Vector2)
signal action_hint(text: String, screen_pos: Vector2)
signal ticket_item_delivered(slot: int, ticket: TicketData, item_index: int)
signal ticket_mood_changed(slot: int, mood: int)
signal shift_phase_changed(phase: int)
signal shift_ended(summary: Dictionary)
signal pause_changed(paused: bool)
signal delivery_target_changed(slot: int)

## Aproximadamente o trilho de bilhetes na captura 1280x720.
var slot_positions: Array[Vector2] = [Vector2(900, 190), Vector2(1010, 190), Vector2(1120, 190), Vector2(1230, 190)]
var started := false


func get_slot_screen_position(slot: int) -> Vector2:
	return slot_positions[clampi(slot, 0, slot_positions.size() - 1)]


func start() -> void:
	started = true


static func make_ticket(id: int, nickname: String, phrase: String, without: Array[String] = []) -> TicketData:
	var t := TicketData.new()
	t.id = id
	t.nickname = nickname
	t.phrase = phrase
	t.without = without
	return t


## Bilhete com vários itens: `recipes` = ids de receita na ordem (ex.: ["food_burger", "food_stew"]).
static func make_multi_ticket(id: int, nickname: String, phrase: String, recipes: Array[String]) -> TicketData:
	var t := make_ticket(id, nickname, phrase)
	for r in recipes:
		t.add_item(r)
	return t
