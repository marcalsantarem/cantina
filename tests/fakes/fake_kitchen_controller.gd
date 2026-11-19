extends Node
## Controlador falso com o contrato de sinais de game.tscn (BRF-007), para testes e capturas da UI.

signal ticket_added(slot: int, ticket: TicketData)
signal ticket_served(slot: int, ticket: TicketData, score: int, band: int, reply: String)
signal gesture_feedback(quality: int, label: String, screen_pos: Vector2)

## Aproximadamente o trilho de bilhetes na captura 1280x720.
var slot_positions: Array[Vector2] = [Vector2(930, 190), Vector2(1050, 190), Vector2(1170, 190)]
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
