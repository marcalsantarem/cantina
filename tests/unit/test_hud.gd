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


func test_next_follows_delivery_target() -> void:
	for i in 3:
		fake.ticket_added.emit(i, _ticket())
	await wait_process_frames(2)
	assert_eq(hud.get_next_slot(), 0, "sem o sinal ainda: FIFO")
	fake.delivery_target_changed.emit(2)  # tigela na mão: vai ao bilhete do slot 2
	assert_eq(hud.get_next_slot(), 2)
	assert_true(hud.get_card(2).is_next, "fita no alvo da entrega")
	assert_false(hud.get_card(0).is_next, "não no mais antigo")
	fake.delivery_target_changed.emit(-1)  # ninguém espera essa receita
	assert_eq(hud.get_next_slot(), -1)
	for i in 3:
		assert_false(hud.get_card(i).is_next, "sem fita")
	fake.delivery_target_changed.emit(1)
	assert_true(hud.get_card(1).is_next)
	fake.ticket_served.emit(1, _ticket(), 90, 0, "ok")
	assert_eq(hud.get_next_slot(), -1, "alvo fechado: espera o novo alvo da cozinha")
	fake.delivery_target_changed.emit(0)
	assert_true(hud.get_card(0).is_next)
	hud.unbind()
	assert_eq(hud.get_next_slot(), 0, "sem cozinha: volta ao FIFO")


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


func test_compact_cards_scaled_one_line_on_screen() -> void:
	hud.set_ui_scale(1.6)
	var long := Fake.make_ticket(2, "Professor Otávio Albuquerque", "Capricha no ponto, sem pressa, e pode tirar a alface que hoje eu tô de regime.", [] as Array[String])
	for i in 3:
		fake.ticket_added.emit(i, long if i == 1 else Fake.make_ticket(1, "Lia", "Capricha!"))
	await wait_seconds(0.6)
	var card: Control = hud.get_card(1)
	assert_true(card.compact)
	assert_eq(card.phrase_label().max_lines_visible, 1)
	assert_true(card.phrase_label().get_line_count() <= 1, "frase em 1 linha")
	assert_true(card.phrase_text().ends_with("…"), "reticências")
	var name_label: Label = card.get_node("%Name")
	assert_eq(name_label.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS, "nome em 1 linha")
	assert_true(name_label.get_line_count() <= 1)
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


# --- M2 (BRF-016) -------------------------------------------------------------

func _combo() -> TicketData:
	return Fake.make_multi_ticket(5, "Seu Jorge", "Um de cada, chef!", ["food_burger", "food_stew"] as Array[String])


func test_multi_item_card_shows_one_row_per_item() -> void:
	fake.ticket_added.emit(0, _combo())
	await wait_process_frames(2)
	var card: Control = hud.get_card(0)
	assert_eq(card.item_row_count(), 2)
	assert_eq(card.recipe_ids(0).size(), 6, "hambúrguer completo")
	assert_eq(card.recipe_ids(1), ["food_stew", "food_ingredient_carrot_chopped",
			"food_ingredient_potato_chopped", "food_ingredient_onion_chopped"] as Array[String], "tigela + picados")
	assert_null(card.icon_texture(), "sem ícone do prato no cabeçalho com 2 itens")
	fake.ticket_added.emit(1, Fake.make_multi_ticket(6, "Lia", "Ensopado.", ["food_stew"] as Array[String]))
	await wait_process_frames(2)
	assert_eq(hud.get_card(1).recipe_ids(0).size(), 3, "1 item: só os picados")
	assert_not_null(hud.get_card(1).icon_texture(), "1 item: ícone do prato no cabeçalho")


func test_item_delivered_gets_check() -> void:
	var t := _combo()
	fake.ticket_added.emit(0, t)
	await wait_process_frames(2)
	var card: Control = hud.get_card(0)
	assert_false(card.is_delivered(1))
	fake.ticket_item_delivered.emit(0, t, 1)
	assert_true(card.is_delivered(1), "✓ no ensopado")
	assert_false(card.is_delivered(0))
	fake.ticket_item_delivered.emit(3, t, 0)  # slot sem bilhete: ignora
	assert_false(card.is_delivered(0))


func test_mood_impatient_and_hungry() -> void:
	fake.ticket_added.emit(0, _ticket())
	await wait_process_frames(2)
	var card: Control = hud.get_card(0)
	assert_false(card.is_swaying())
	fake.ticket_mood_changed.emit(0, 1)  # IMPATIENT
	assert_true(card.is_swaying(), "balança")
	assert_false(card.hungry_label().visible)
	fake.ticket_mood_changed.emit(0, 2)  # HUNGRY
	assert_false(card.is_swaying())
	assert_true(card.hungry_label().visible)
	assert_eq(card.hungry_label().text, "Tô com fome, chef!")
	assert_true(card.has_theme_stylebox_override("panel"), "papel amarelado")
	fake.ticket_served.emit(0, _ticket(), 80, 1, "ok")
	await wait_seconds(0.4)
	assert_false(card.hungry_label().visible, "resposta sem humor")
	assert_false(card.has_theme_stylebox_override("panel"))


func test_four_multi_cards_fit_side_by_side() -> void:
	for i in 4:
		fake.ticket_added.emit(i, _combo())
	await wait_seconds(0.6)
	var vp := hud.get_viewport().get_visible_rect().size
	var rects: Array[Rect2] = []
	for i in 4:
		rects.append(hud.get_card(i).get_global_rect())
	for i in 3:
		assert_true(rects[i].end.x <= rects[i + 1].position.x + 0.5, "sem sobreposição %d" % i)
	assert_true(rects[0].position.x >= 0.0 and rects[3].end.x <= vp.x + 0.5, "dentro da tela")


func test_screen_scale_uses_css_pixels() -> void:
	assert_almost_eq(Hud.screen_scale_for(390.0, 720.0), 390.0 / 720.0, 0.001, "844x390 com DPR 1")
	assert_almost_eq(Hud.screen_scale_for(1170.0, 720.0, 3.0), 390.0 / 720.0, 0.001, "844x390 com DPR 3")
	assert_eq(Hud.screen_scale_for(0.0, 720.0), 1.0)
	# 844x390 (CSS): frase >= 16 px e 4 bilhetes cabem lado a lado.
	var s := Hud.screen_scale_for(1170.0, 720.0, 3.0)
	var k := minf(Hud.ticket_scale_for(s, 15.0, 16.0), Hud.fit_scale_for(844.0 * 720.0 / 390.0))
	assert_true(15.0 * s * k >= 16.0 - 0.05, "frase legível no celular")


func test_combo_without_label_per_item() -> void:
	var t := Fake.make_ticket(5, "Lu do Skate", "Dois, chef!")
	t.add_item("food_burger")
	t.add_item("food_burger", ["food_ingredient_tomato_slice"] as Array[String])
	fake.ticket_added.emit(0, t)
	await wait_process_frames(3)
	var card: Control = hud.get_card(0)
	assert_eq(card.item_row_count(), 2)
	assert_false(card.without_label().visible, "sem etiqueta do bilhete inteiro")
	assert_false(card.item_without_label(0).visible, "1º item completo")
	assert_true(card.item_without_label(1).visible, "etiqueta no 2º item")
	assert_eq(card.item_without_label(1).text, "sem tomate")
	assert_eq(card.recipe_ids(1).size(), 5, "fileira do 2º sem tomate")
	fake.ticket_item_delivered.emit(0, t, 1)
	assert_true(card.is_delivered(1))
	assert_almost_eq(card.item_without_label(1).modulate.a, 0.4, 0.01, "esmaece junto")


func test_single_item_without_stays_on_ticket() -> void:
	var t := Fake.make_ticket(6, "Dona Cida", "Sem tomate!")
	t.add_item("food_burger", ["food_ingredient_tomato_slice"] as Array[String])
	fake.ticket_added.emit(0, t)
	await wait_process_frames(3)
	var card: Control = hud.get_card(0)
	assert_true(card.without_label().visible)
	assert_false(card.item_without_label(0).visible, "sem etiqueta repetida")


func test_pause_overlay() -> void:
	var pause: Control = hud.get_pause_overlay()
	assert_false(pause.visible)
	assert_eq(pause.mouse_filter, Control.MOUSE_FILTER_IGNORE, "o toque passa para a cozinha retomar")
	fake.pause_changed.emit(true)
	assert_true(pause.visible)
	var texts := pause.find_children("*", "Label", true, false).map(func(l): return l.text)
	assert_has(texts, "Pausado — toque para voltar")
	for c in pause.find_children("*", "Control", true, false):
		assert_eq(c.mouse_filter, Control.MOUSE_FILTER_IGNORE, "não pega toque: %s" % c.name)
	var vp := hud.get_viewport().get_visible_rect().size
	assert_true(pause.get_global_rect().encloses(Rect2(Vector2.ZERO, vp)), "cobre a cozinha")
	fake.pause_changed.emit(false)
	assert_false(pause.visible)
	fake.pause_changed.emit(true)
	hud.unbind()
	assert_false(pause.visible, "unbind esconde")


func test_hint_bubble_does_not_cover_next_tag() -> void:
	for i in 4:
		fake.ticket_added.emit(i, _ticket())
	await wait_seconds(0.6)
	var card: Control = hud.get_card(0)
	var tag: Rect2 = card.next_tag_screen_rect()
	assert_true(tag.has_area())
	# ponto logo abaixo da fita: o balão "acima" cairia em cima dela.
	var target := Vector2(tag.get_center().x, tag.end.y + 60.0)
	fake.action_hint.emit("Mexa em círculos", target)
	await wait_seconds(0.3)
	var bubble: Control = hud.get_hint()
	assert_true(bubble.is_shown())
	assert_false(bubble.screen_rect().intersects(tag), "não cobre 'próximo'")
	var vp := hud.get_viewport().get_visible_rect().size
	assert_true(Rect2(Vector2.ZERO, vp).encloses(bubble.screen_rect()), "na tela")


func test_fit_scale_for_four_cards() -> void:
	var k := Hud.fit_scale_for(1280.0)
	assert_true(Hud.SLOTS * Hud.CARD_WIDTH * k <= 1280.0, "4 bilhetes cabem")
	assert_true(k > 1.0)


func test_phase_banners() -> void:
	var banner: Control = hud.get_banner()
	fake.shift_phase_changed.emit(0)  # OPENING
	assert_false(banner.visible, "abertura sem placa")
	fake.shift_phase_changed.emit(1)  # RUSH
	assert_true(banner.is_shown())
	assert_eq(banner.banner_text(), "Hora do almoço!")
	assert_eq(banner.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	fake.shift_phase_changed.emit(3)
	assert_eq(banner.banner_text(), "Últimos pedidos")
	fake.shift_phase_changed.emit(4)
	assert_eq(banner.banner_text(), "Fechado!")
	await wait_seconds(2.6)
	assert_false(banner.visible, "placa breve")


func _shift_summary() -> Dictionary:
	return {"score": 70.0, "stars": 2, "quality": 75.0, "service": 70.0, "agility": 60.0, "served": 7,
			"arrived": 9, "items_delivered": 8, "items_total": 12, "avg_score": 75, "agility_word": "No ritmo",
			"best_reply": "Chef, isso foi poesia com queijo."}


func test_shift_end_screen() -> void:
	var end: Control = hud.get_end_screen()
	assert_false(end.visible)
	fake.shift_ended.emit(_shift_summary())
	assert_true(end.visible)
	assert_eq(end.mouse_filter, Control.MOUSE_FILTER_STOP, "bloqueia a cozinha")
	var t: PackedStringArray = end.texts()
	assert_has(t, "Pedidos atendidos 7/9")
	assert_has(t, "Nota média 75")
	assert_has(t, "Agilidade: No ritmo")
	assert_has(t, "“Chef, isso foi poesia com queijo.”")
	assert_eq(end.star_nodes().filter(func(s): return s.earned).size(), 2)
	await wait_seconds(3.0)
	for s in end.star_nodes():
		assert_almost_eq(s.pop, 1.0, 0.01, "estrelas entraram")
	var btn: Button = end.replay_button()
	assert_eq(btn.text, "Jogar de novo")
	var r := btn.get_global_rect()
	var vp := hud.get_viewport().get_visible_rect().size
	assert_true(r.size.y >= 48.0 and r.size.x >= 48.0, "alvo >= 48 px")
	assert_true(Rect2(Vector2.ZERO, vp).encloses(r), "botão na tela")
	watch_signals(hud)
	btn.pressed.emit()
	btn.pressed.emit()
	assert_signal_emit_count(hud, "replay_requested", 1)


func test_main_replay_restarts_without_start_screen() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	var game_root := Fake.new()
	game_root.name = "Game"
	var packed := PackedScene.new()
	packed.pack(game_root)
	game_root.free()
	main.game_scene = packed
	add_child_autofree(main)
	main.get_node("StartScreen").begin()
	await wait_seconds(0.5)
	assert_false(main.has_node("StartScreen"), "tela inicial saiu")
	var old_game: Node = main.game
	var old_hud: Node = main.hud
	main.game.shift_ended.emit(_shift_summary())
	main.hud.get_end_screen().replay_button().pressed.emit()
	await wait_process_frames(3)
	assert_false(is_instance_valid(old_game), "jogo antigo saiu")
	assert_false(is_instance_valid(old_hud), "HUD antigo saiu")
	assert_ne(main.game, old_game)
	assert_true(main.game.started, "novo turno começou")
	assert_false(main.hud.get_end_screen().visible)
	assert_false(main.has_node("StartScreen"), "não volta à tela inicial")
	main.game.ticket_added.emit(0, _ticket())
	assert_eq(main.hud.get_cards().size(), 1, "HUD novo ligado ao jogo novo")
