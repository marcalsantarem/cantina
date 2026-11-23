extends GutTest
## PlateStack: pão se divide, itens aceitos/recusados, notas e fechamento (sem alinhamento, decisão 22).

var plate: PlateStack


func before_each() -> void:
	plate = PlateStack.new(Recipe.load_burger())


func test_bun_splits_on_empty_plate() -> void:
	assert_true(plate.add(Kitchen.BUN, {}))
	assert_eq(plate.size(), 1)
	assert_eq(plate.ids()[0], Kitchen.BUN_BOTTOM)
	assert_true(plate.bun_top_parked)
	assert_false(plate.add(Kitchen.BUN, {}), "segundo pão recusado")


func test_bun_rejected_on_non_empty_plate() -> void:
	plate.add(Kitchen.CHEESE_SLICE, {})
	assert_false(plate.can_accept(Kitchen.BUN))


func test_accepts_recipe_items_and_aliases_only() -> void:
	assert_false(plate.add(Kitchen.LETTUCE, {}), "alface inteira não monta")
	assert_false(plate.add(Kitchen.TOMATO_SLICES, {}))
	assert_true(plate.add(Kitchen.BURGER_TRASH, {Kitchen.NOTE_COOK: 0.0}))
	assert_true(plate.add(Kitchen.BURGER_UNCOOKED, {}), "fora de ordem/repetido empilha")
	assert_eq(plate.size(), 2)


func test_notes_are_copied_without_assembly() -> void:
	var notes := {Kitchen.NOTE_COOK: 0.7}
	plate.add(Kitchen.BURGER_COOKED, notes)
	var q: Dictionary = plate.items[0]["quality"]
	assert_eq(q, {Kitchen.NOTE_COOK: 0.7}, "sem nota de montagem")
	assert_eq(plate.items[0].keys(), ["id", "quality"])
	q[Kitchen.NOTE_COOK] = 0.0
	assert_eq(notes, {Kitchen.NOTE_COOK: 0.7}, "não altera o dicionário de entrada")


func test_bun_top_closes_and_take_all_resets() -> void:
	plate.add(Kitchen.BUN, {})
	plate.add(Kitchen.BURGER_COOKED, {})
	assert_true(plate.add(Kitchen.BUN_TOP, {}))
	assert_true(plate.closed)
	assert_false(plate.bun_top_parked)
	assert_false(plate.add(Kitchen.CHEESE_SLICE, {}), "fechado não aceita mais")
	assert_eq(plate.top_id(), Kitchen.BUN_TOP)
	var served := plate.take_all()
	assert_eq(served.size(), 3)
	assert_true(plate.is_empty())
	assert_false(plate.closed)
