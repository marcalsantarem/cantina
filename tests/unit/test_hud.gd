extends GutTest
## HUD, tela inicial, overlay de retrato e main com controlador falso.

const Fake := preload("res://tests/fakes/fake_kitchen_controller.gd")
const HudScene := preload("res://scenes/ui/hud.tscn")
const Hud := preload("res://src/ui/hud.gd")
const UiText := preload("res://src/ui/ui_text.gd")
const RotateOverlay := preload("res://src/ui/rotate_overlay.gd")

var fake: Node
var hud: CanvasLayer


func before_each() -> void:
	fake = Fake.new()
	add_child_autofree(fake)
	hud = HudScene.instantiate()
	add_child_autofree(hud)
	hud.set_ui_scale(1.0)  # janela headless não reflete a tela real
	hud.bind(fake)


func _ticket(without: Array[String] = []) -> TicketData:
	return Fake.make_ticket(1, "Dona Cida", "Sem tomate, por favor, é sério.", without)


func test_ticket_added_creates_card_near_slot() -> void:
	fake.ticket_added.emit(0, _ticket(["food_ingredient_tomato_slice"]))
	await wait_process_frames(3)
	var card: Control = hud.get_card(0)
	assert_not_null(card)
	assert_eq(card.get_node("%Name").text, "Dona Cida")
	assert_true(card.without_label().visible)
	assert_eq(card.without_label().text, "sem tomate")
	assert_not_null(card.icon_texture(), "ícone do prato")
	assert_eq(card.anchor_point * hud.ui_scale, fake.get_slot_screen_position(0))


func test_without_hidden_when_empty() -> void:
	fake.ticket_added.emit(1, _ticket())
	await wait_process_frames(2)
	assert_false(hud.get_card(1).without_label().visible)


func test_ticket_shows_recipe_without_removed_items() -> void:
	fake.ticket_added.emit(0, _ticket(["food_ingredient_tomato_slice", "food_ingredient_cheese_slice"]))
	await wait_process_frames(2)
	var card: Control = hud.get_card(0)
	assert_eq(card.recipe_ids(), ["food_ingredient_bun_bottom", "food_ingredient_burger_cooked",
			"food_ingredient_lettuce_slice", "food_ingredient_bun_top"] as Array[String], "base -> topo, sem o 'sem'")
	assert_true(card.without_label().visible, "'sem' continua destacado")
	fake.ticket_added.emit(1, _ticket())
	await wait_process_frames(2)
	assert_eq(hud.get_card(1).recipe_ids().size(), 6, "receita completa")
	fake.ticket_served.emit(0, _ticket(), 90, 0, "ok")
	await wait_seconds(0.4)
	assert_eq(card.recipe_ids(), [] as Array[String], "resposta sem receita")


func test_action_hint_shows_and_hides() -> void:
	var bubble: Control = hud.get_hint()
	assert_false(bubble.visible)
	assert_eq(bubble.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	fake.action_hint.emit("Pique em zigue-zague", Vector2(1270, 400))
	await wait_seconds(0.3)
	assert_true(bubble.is_shown())
	assert_eq(bubble.hint_text(), "Pique em zigue-zague")
	assert_almost_eq(bubble.modulate.a, 1.0, 0.01, "fade in")
	var vp := hud.get_viewport().get_visible_rect().size
	var r: Rect2 = bubble.get_global_rect()
	assert_true(r.position.x >= 0.0 and r.end.x <= vp.x, "preso à borda")
	assert_true(r.end.y < 400.0, "acima do ponto")
	var fs: int = bubble.get_child(0).get_theme_font_size("font_size")
	assert_true(fs * hud.ui_scale >= 13.0, "texto >= 13 px")
	fake.action_hint.emit("", Vector2.ZERO)
	assert_false(bubble.is_shown())
	await wait_seconds(0.3)
	assert_false(bubble.visible, "fade out")


func test_bind_without_action_hint_signal() -> void:
	var plain := Node.new()
	plain.add_user_signal("ticket_added")
	plain.add_user_signal("ticket_served")
	plain.add_user_signal("gesture_feedback")
	add_child_autofree(plain)
	hud.bind(plain)
	hud.unbind()
	assert_false(hud.get_hint().visible)


func test_three_cards_do_not_overlap_and_stay_on_screen() -> void:
	for i in 3:
		fake.ticket_added.emit(i, _ticket())
	await wait_seconds(0.6)
	var rects: Array[Rect2] = []
	for i in 3:
		var c: Control = hud.get_card(i)
		rects.append(Rect2(c.position, c.size))
	for i in 2:
		assert_true(rects[i].end.x <= rects[i + 1].position.x + 0.5, "sem sobreposição %d" % i)
	var vp := hud.get_viewport().get_visible_rect().size
	assert_true(rects[2].end.x <= vp.x, "dentro da tela")
	assert_true(rects[0].position.y >= 0.0)


func test_served_turns_into_reply_and_disappears() -> void:
	hud.reply_seconds = 0.3
	var t := _ticket(["food_ingredient_cheese_slice"])
	fake.ticket_added.emit(2, t)
	await wait_process_frames(2)
	var card: Control = hud.get_card(2)
	fake.ticket_served.emit(2, t, 91, 0, "Chef, isso foi poesia com queijo.")
	assert_null(hud.get_card(2), "slot liberado")
	await wait_seconds(0.4)
	assert_true(is_instance_valid(card))
	assert_true(card.is_reply)
	assert_eq(card.phrase_text(), "Chef, isso foi poesia com queijo.")
	assert_eq(card.stamp_band(), 0)
	assert_false(card.without_label().visible)
	await wait_seconds(0.6)
	assert_false(is_instance_valid(card), "bilhete-resposta some")


func test_served_without_open_card_still_shows_reply() -> void:
	fake.ticket_served.emit(0, _ticket(), 30, 2, "Vou levar pra casa pra estudar.")
	await wait_seconds(0.5)
	assert_eq(hud.get_cards().size(), 1)
	assert_eq(hud.get_cards()[0].stamp_band(), 2)


func test_oldest_open_ticket_is_next() -> void:
	for i in 3:
		fake.ticket_added.emit(i, _ticket())
	await wait_process_frames(2)
	assert_eq(hud.get_next_slot(), 0)
	assert_true(hud.get_card(0).is_next, "mais antigo destacado")
	assert_false(hud.get_card(1).is_next)
	assert_false(hud.get_card(2).is_next)
	fake.ticket_served.emit(0, _ticket(), 90, 0, "ok")
	assert_eq(hud.get_next_slot(), 1)
	assert_true(hud.get_card(1).is_next)
	fake.ticket_added.emit(0, _ticket())  # novo entra no slot 0, mas é o mais novo
	assert_eq(hud.get_next_slot(), 1, "FIFO, não ordem de slot")
	assert_false(hud.get_card(0).is_next)
	fake.ticket_served.emit(1, _ticket(), 90, 0, "ok")
	fake.ticket_served.emit(2, _ticket(), 90, 0, "ok")
	assert_eq(hud.get_next_slot(), 0)
	assert_true(hud.get_card(0).is_next)
	fake.ticket_served.emit(0, _ticket(), 90, 0, "ok")
	assert_eq(hud.get_next_slot(), -1)


func test_next_card_is_lifted() -> void:
	fake.ticket_added.emit(0, _ticket())
	fake.ticket_added.emit(1, _ticket())
	await wait_seconds(0.6)
	var a: Control = hud.get_card(0)
	var b: Control = hud.get_card(1)
	assert_true(a.position.y < b.position.y - 5.0, "o próximo fica mais alto")


func test_ticket_scale_for_low_screens() -> void:
	var s := 390.0 / 720.0  # 844x390 com stretch canvas_items
	var k := Hud.ticket_scale_for(s, 15.0, 13.0)
	assert_true(15.0 * s * k >= 13.0 - 0.01, "frase >= 13 px")
	assert_eq(Hud.ticket_scale_for(1.0, 15.0, 13.0), 1.0, "1280x720 sem ampliação")
	assert_eq(Hud.ticket_scale_for(0.1, 15.0, 13.0, 2.0), 2.0, "limite")


func test_compact_cards_scaled_two_lines_on_screen() -> void:
	hud.set_ui_scale(1.6)
	var long := Fake.make_ticket(2, "Professor Otávio", "Capricha no ponto, sem pressa, e pode tirar a alface que hoje eu tô de regime.", [] as Array[String])
	for i in 3:
		fake.ticket_added.emit(i, long if i == 1 else _ticket())
	await wait_seconds(0.6)
	var card: Control = hud.get_card(1)
	assert_true(card.compact)
	assert_eq(card.phrase_label().max_lines_visible, 2)
	assert_true(card.phrase_label().get_line_count() <= 2, "frase em até 2 linhas")
	assert_true(card.phrase_text().ends_with("…"), "reticências")
	assert_false(hud.get_card(0).phrase_text().ends_with("…"), "frase curta inteira")
	assert_eq(hud.get_node("Tickets").scale, Vector2.ONE * 1.6)
	var vp := hud.get_viewport().get_visible_rect().size
	for i in 3:
		var r: Rect2 = hud.get_card(i).get_global_rect()
		assert_true(r.position.x >= 0.0 and r.end.x <= vp.x + 0.5, "dentro da tela %d" % i)
	fake.ticket_served.emit(1, long, 90, 0, "Uma resposta comprida que não deve ser cortada no bilhete-resposta.")
	await wait_seconds(0.3)
	assert_eq(card.phrase_label().max_lines_visible, -1, "resposta inteira")


func test_gesture_feedback_word() -> void:
	fake.gesture_feedback.emit(2, "Perfeito!", Vector2(400, 300))
	await wait_process_frames(1)
	var words: Array = hud.get_node("Feedback").get_children()
	assert_eq(words.size(), 1)
	var w: Label = words[0]
	assert_eq(w.text, "Perfeito!")
	assert_eq(w.get_theme_color("font_color"), w.COLORS[2])
	assert_almost_eq(w.position.x + w.size.x * 0.5, 400.0, 1.0)
	await wait_seconds(1.3)
	assert_false(is_instance_valid(w), "palavra some")


func test_unbind_disconnects() -> void:
	hud.unbind()
	fake.ticket_added.emit(0, _ticket())
	assert_eq(hud.get_cards().size(), 0)


func test_without_text() -> void:
	assert_eq(UiText.without_text(["food_ingredient_lettuce"]), "sem alface")
	assert_eq(UiText.without_text(["food_ingredient_tomato_slice", "food_ingredient_cheese_slice"]), "sem tomate e queijo")


func test_portrait_detection() -> void:
	assert_true(RotateOverlay.is_portrait(Vector2(720, 1280)))
	assert_false(RotateOverlay.is_portrait(Vector2(1280, 720)))


func test_start_screen_emits_once() -> void:
	var start: Control = load("res://scenes/ui/start_screen.tscn").instantiate()
	add_child_autofree(start)
	watch_signals(start)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	start._gui_input(ev)
	start._gui_input(ev)
	assert_signal_emit_count(start, "started", 1)
	assert_eq(start.get_node("%Title").text, "Cantina")
	assert_string_contains(start.get_node("%Credits").text, "Kay Lousberg")


func test_main_starts_game_and_binds_hud() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	var game_root := Fake.new()
	game_root.name = "Game"
	var packed := PackedScene.new()
	packed.pack(game_root)
	game_root.free()
	main.game_scene = packed
	add_child_autofree(main)
	main.get_node("StartScreen").begin()
	assert_not_null(main.game)
	assert_true(main.game.started, "game.start() chamado")
	main.game.ticket_added.emit(0, _ticket())
	assert_eq(main.hud.get_cards().size(), 1, "hud ligado ao game")


func test_theme_has_font() -> void:
	var theme: Theme = load("res://assets/ui/cantina_theme.tres")
	assert_not_null(theme.default_font)
	assert_true(theme.has_stylebox("panel", "TicketPanel"))
