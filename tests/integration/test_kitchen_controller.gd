extends GutTest
## KitchenController na cena real (sem janela): amostras normalizadas -> raycast nas
## estações -> arrastar/soltar -> servir. M1: hambúrguer completo; M2: turno acelerado com
## `advance`, duas frigideiras, ensopado da tábua ao servir, entrega item a item, fim.
## Decisão 22: tábua pica sozinha, carne e panela cozinham sozinhas (sem gestos).

const GAME := preload("res://scenes/game/game.tscn")

var ctrl: KitchenController
var t: int = 0
var added: Array = []
var served: Array = []
var feedback: Array = []
var hints: Array = []
var delivered: Array = []
var moods: Array = []
var phases: Array = []
var ended: Array = []


func before_each() -> void:
	ctrl = GAME.instantiate()
	add_child_autofree(ctrl)
	ctrl.auto_process = false
	t = 10000
	for a in [added, served, feedback, hints, delivered, moods, phases, ended]:
		a.clear()
	ctrl.action_hint.connect(func(text, pos): hints.append([text, pos]))
	ctrl.ticket_added.connect(func(slot, ticket): added.append([slot, ticket]))
	ctrl.ticket_served.connect(func(slot, ticket, score, band, reply): served.append([slot, ticket, score, band, reply]))
	ctrl.gesture_feedback.connect(func(q, label, pos): feedback.append([q, label, pos]))
	ctrl.ticket_item_delivered.connect(func(slot, ticket, idx): delivered.append([slot, ticket, idx]))
	ctrl.ticket_mood_changed.connect(func(slot, mood): moods.append([slot, mood]))
	ctrl.shift_phase_changed.connect(func(phase): phases.append(phase))
	ctrl.shift_ended.connect(func(summary): ended.append(summary))
	await wait_physics_frames(3)


func _n(pos: Vector3) -> Vector2:
	return ctrl.world_to_norm(pos)


## Arrasta em linha reta de a até b (amostras a cada 16 ms).
func _drag(a: Vector2, b: Vector2, steps: int = 12) -> void:
	ctrl.pointer_down(a, t)
	for i in range(1, steps + 1):
		t += 16
		ctrl.pointer_move(a.lerp(b, float(i) / steps), t)
	t += 16
	ctrl.pointer_up(b, t)


func _plate() -> Vector2:
	return _n(ctrl.snap_position("Plate_Assembly"))


func _window() -> Vector2:
	return _n(ctrl.snap_position("OrderWindow") + Vector3(0, 0.6, 0))


func _st(station: String) -> Vector2:
	return _n(ctrl.snap_position(station))


## Espera a tábua picar sozinha.
func _chop() -> void:
	ctrl.advance(ChopTarget.CHOP_S + 0.05)


func _labels() -> Array:
	var out := []
	for f in feedback:
		out.append(f[1])
	return out


## Textos das dicas sem repetições seguidas.
func _hint_texts() -> Array:
	var out := []
	for h in hints:
		if out.is_empty() or out[-1] != h[0]:
			out.append(h[0])
	return out


## Põe o ensopado pronto na panela pela lógica (sem arrastar os picados).
func _cook_stew() -> void:
	for id in ctrl.stew_recipe.layers:
		ctrl.pot.add(id)
	ctrl.advance(StewPot.READY_S + 0.1)


func test_station_raycast() -> void:
	for st in ["Crate_bun", "Crate_carrot", "Crate_potato", "Crate_onion", "CuttingBoard",
			"Stove_Pan", "Stove_Pan2", "Stove_Pot"]:
		assert_eq(ctrl.station_at(_st(st)), st)
	assert_eq(ctrl.station_at(_plate()), "Plate_Assembly")
	assert_eq(ctrl.station_at(_window()), "OrderWindow")


func test_no_ticket_before_start() -> void:
	ctrl.advance(20.0)
	assert_eq(added.size(), 0)
	ctrl.start()
	assert_eq(phases, [ShiftClock.Phase.OPENING])
	ctrl.advance(2.9)
	assert_eq(added.size(), 0, "1º bilhete só aos 3 s")
	ctrl.advance(0.2)
	assert_eq(added.size(), 1)
	assert_eq(added[0][0], 0, "primeiro bilhete no slot 0")
	assert_gt(added[0][1].items.size(), 0, "bilhete com itens")
	for s in KitchenController.SLOT_COUNT:
		assert_typeof(ctrl.get_slot_screen_position(s), TYPE_VECTOR2)
	assert_ne(ctrl.get_slot_screen_position(3), ctrl.get_slot_screen_position(2), "Slot4 existe")


func test_drop_outside_returns_to_crate() -> void:
	_drag(_st("Crate_cheese"), Vector2(0.5, 0.97))
	assert_false(ctrl.is_carrying())
	assert_true(ctrl.stack.is_empty())


func test_full_burger_served() -> void:
	ctrl.start()
	var ticket := ctrl.spawn_order(["food_burger"])
	assert_eq(added.size(), 1)
	ticket.items[0]["without"].clear()
	ticket.without.clear()

	# Pão inteiro no prato -> base + topo estacionado.
	_drag(_st("Crate_bun"), _plate())
	assert_eq(ctrl.stack.ids(), [Kitchen.BUN_BOTTOM] as Array[String])
	assert_true(ctrl.stack.bun_top_parked)

	assert_eq(feedback.size(), 0, "montar não dá nota")

	# Carne: frigideira 1, cozinha sozinha 11 s (perfeito), tirar e montar.
	var pan := _st("Stove_Pan")
	_drag(_st("Crate_burger"), pan)
	assert_not_null(ctrl.pans[0].patty)
	ctrl.advance(11.0)
	assert_eq(ctrl.pans[0].patty.model_id(), Kitchen.BURGER_COOKED)
	_drag(pan, _plate())
	assert_null(ctrl.pans[0].patty)
	assert_eq(_labels(), ["Perfeito!"], "nota do ponto ao tirar")

	_drag(_st("Crate_cheese"), _plate())

	# Alface e tomate: soltar na tábua, pica sozinho, arrastar para o prato.
	var board := _st("CuttingBoard")
	for crate in ["Crate_lettuce", "Crate_tomato"]:
		_drag(_st(crate), board)
		assert_not_null(ctrl.board, crate + " na tábua")
		_drag(board, _plate())
		assert_not_null(ctrl.board, crate + " cru não sai da tábua")
		assert_false(ctrl.is_carrying())
		_chop()
		assert_true(ctrl.board.is_done(), crate + " picado")
		_drag(board, _plate())
		assert_null(ctrl.board)
	assert_eq(_labels(), ["Perfeito!"], "picar e montar não dão nota")

	# Pão de cima, do descanso para o prato.
	_drag(_n(ctrl.bun_top_rest_position()), _plate())
	assert_true(ctrl.stack.closed)
	assert_eq(ctrl.stack.ids(), ctrl.recipe.layers)

	# Prato alinhado (decisão 17): itens centrados no Snap, sem giro, cada um no topo do anterior.
	await wait_seconds(KitchenController.RETURN_S + 0.1)
	var layers: Array[Node3D] = []
	for ch in ctrl.plate_root.get_children():
		if ch.name != "plate":
			layers.append(ch)
	assert_eq(layers.size(), ctrl.recipe.layers.size(), "camadas no prato")
	var y := ctrl.snap_position("Plate_Assembly").y - ctrl.plate_root.global_position.y
	for i in layers.size():
		var n := layers[i]
		assert_almost_eq(n.position.x, 0.0, 0.001, "%s x" % n.name)
		assert_almost_eq(n.position.z, 0.0, 0.001, "%s z" % n.name)
		assert_almost_eq(n.position.y, y, 0.001, "%s altura" % n.name)
		assert_eq(n.rotation, Vector3.ZERO, "%s sem giro" % n.name)
		y += ctrl._heights[ctrl.recipe.layers[i]]

	# Servir na janela.
	_drag(_plate(), _window())
	assert_eq(served.size(), 1)
	if served.size() == 1:
		assert_eq(served[0][0], 0)
		assert_eq(served[0][1], ticket)
		assert_eq(served[0][2], 100, "nota")
		assert_eq(served[0][3], 2, "faixa ≥80")
		assert_ne(served[0][4], "")
	assert_eq(delivered.size(), 1)
	assert_null(ctrl.plate_root, "prato saiu")
	assert_null(ctrl.slots[0], "vaga liberada")

	# 1,5 s: prato limpo volta na janela e prato novo na montagem.
	ctrl.advance(1.6)
	assert_not_null(ctrl.returned_plate)
	assert_not_null(ctrl.plate_root)
	assert_true(ctrl.stack.is_empty())
	ctrl.pointer_down(_window(), t)
	ctrl.pointer_up(_window(), t + 50)
	assert_null(ctrl.returned_plate, "some ao tocar")

	var cut_hints := ["Solte na tábua", "Arraste o prato até a janela", "Arraste ao prato", "Solte no prato", "Arraste o prato até a janela"]
	var expected := ["Pegue um ingrediente nos caixotes",
		"Solte no prato", "Arraste o prato até a janela",
		"Solte na frigideira", "Arraste o prato até a janela", "Tire no ponto!",
		"Solte no prato", "Arraste o prato até a janela",
		"Solte no prato", "Arraste o prato até a janela"]
	expected.append_array(cut_hints)
	expected.append_array(cut_hints)
	expected.append_array(["Solte no prato", "Arraste o prato até a janela"])
	assert_eq(_hint_texts().slice(0, expected.size()), expected, "sequência de dicas")


func test_hint_positions_and_no_repeat() -> void:
	ctrl.spawn_order(["food_burger"])
	assert_eq(hints.size(), 1)
	var crate := _st("Crate_burger")
	var pan := _st("Stove_Pan")
	ctrl.pointer_down(crate, t)
	for i in range(1, 13):
		t += 16
		ctrl.pointer_move(crate.lerp(pan, i / 12.0), t)
	assert_eq(hints[-1][0], "Solte na frigideira")
	var n := hints.size()
	ctrl.advance(0.1)
	ctrl.advance(0.1)
	assert_eq(hints.size(), n, "não repete a mesma dica")
	var pan_px: Vector2 = ctrl.world_to_norm(ctrl.snap_position("Stove_Pan") + Vector3(0, KitchenController.HINT_LIFT, 0)) * ctrl._viewport_size()
	assert_almost_eq(hints[-1][1], pan_px, Vector2.ONE, "dica na panela")
	t += 16
	ctrl.pointer_up(pan, t)
	assert_eq(hints[-1][0], "Pegue um ingrediente nos caixotes", "carne crua cozinha sozinha")
	ctrl.advance(8.0)
	assert_eq(hints[-1][0], "Tire no ponto!")


func test_two_pans_independent() -> void:
	var p1 := _st("Stove_Pan")
	var p2 := _st("Stove_Pan2")
	_drag(_st("Crate_burger"), p1)
	ctrl.advance(4.0)
	# Com a 1ª ocupada, a dica aponta a 2ª.
	ctrl.pointer_down(_st("Crate_burger"), t)
	for i in range(1, 13):
		t += 16
		ctrl.pointer_move(_st("Crate_burger").lerp(p2, i / 12.0), t)
	var p2_px: Vector2 = ctrl.world_to_norm(ctrl.snap_position("Stove_Pan2") + Vector3(0, KitchenController.HINT_LIFT, 0)) * ctrl._viewport_size()
	assert_almost_eq(hints[-1][1], p2_px, Vector2.ONE, "dica na frigideira livre")
	t += 16
	ctrl.pointer_up(p2, t)
	assert_not_null(ctrl.pans[1].patty)
	ctrl.advance(4.0)
	assert_almost_eq(ctrl.pans[0].patty.time, 8.0, 0.01)
	assert_almost_eq(ctrl.pans[1].patty.time, 4.0, 0.01)
	assert_eq(ctrl.pans[0].patty.model_id(), Kitchen.BURGER_COOKED, "1ª no ponto")
	assert_eq(ctrl.pans[1].patty.model_id(), Kitchen.BURGER_UNCOOKED, "2ª ainda crua")
	assert_false(ctrl.pans[0].alert.visible)
	ctrl.advance(6.5)
	assert_true(ctrl.pans[0].alert.visible, "aro ao passar do perfeito (14 s)")
	assert_false(ctrl.pans[1].alert.visible)
	# Tirar a 1ª não mexe na 2ª.
	_drag(p1, _plate())
	assert_null(ctrl.pans[0].patty)
	assert_false(ctrl.pans[0].alert.visible)
	assert_not_null(ctrl.pans[1].patty)


func test_stew_from_board_to_serve() -> void:
	var ticket := ctrl.spawn_order(["food_stew"])
	var board := _st("CuttingBoard")
	var pot := _st("Stove_Pot")
	for crate in ["Crate_carrot", "Crate_potato", "Crate_onion"]:
		_drag(_st(crate), board)
		assert_not_null(ctrl.board, crate + " na tábua")
		_chop()
		assert_true(ctrl.board.is_done(), crate + " picado")
		assert_eq(hints[-1][0], "Arraste à panela")
		ctrl.pointer_down(board, t)
		for i in range(1, 13):
			t += 16
			ctrl.pointer_move(board.lerp(pot, i / 12.0), t)
		assert_eq(hints[-1][0], "Solte os legumes na panela")
		t += 16
		ctrl.pointer_up(pot, t)
		assert_null(ctrl.board, crate + " saiu da tábua")
		if ctrl.pot.portions == 0:
			assert_eq(ctrl.pot.stage(), StewPot.Stage.FILLING)
	assert_eq(ctrl.pot_item_count(), 0, "picados somem ao cozinhar")
	assert_eq(ctrl.pot.stage(), StewPot.Stage.COOKING)
	assert_eq(ctrl.pot_model_id(), StewPot.POT_STEW)
	assert_true(ctrl._pot_steam.visible, "vapor cozinhando")

	# Picado repetido volta à tábua.
	_drag(_st("Crate_carrot"), board)
	_chop()
	_drag(board, pot)
	assert_not_null(ctrl.board, "cenoura repetida voltou")
	_drag(board, _st("Crate_carrot"))
	assert_null(ctrl.board, "devolvida ao caixote")

	# Tocar a panela cozinhando não faz nada; cozinha sozinha até ficar pronta.
	ctrl.pointer_down(pot, t)
	ctrl.pointer_up(pot, t + 50)
	assert_eq(ctrl.pot.portions, 2)
	feedback.clear()
	while not ctrl.pot.is_ready():
		ctrl.advance(1.0)
	assert_eq(hints[-1][0], "Arraste a tigela à janela")
	assert_eq(feedback.size(), 0, "cozinhar não dá nota")

	_drag(pot, _window())
	assert_eq(_labels(), ["Perfeito!"], "nota do ponto ao servir a tigela")
	assert_eq(delivered.size(), 1)
	assert_eq(served.size(), 1)
	if served.size() == 1:
		assert_eq(served[0][1], ticket)
		assert_eq(served[0][2], 100, "ensopado no ponto")
	assert_eq(ctrl.pot.portions, 1, "sobrou 1 porção")
	ctrl.advance(1.6)
	assert_not_null(ctrl.returned_plate)
	assert_true(String(ctrl.returned_plate.name).begins_with("bowl") or ctrl.returned_plate.name == "food_stew", "tigela volta")

	# Ninguém mais pediu ensopado: tigela volta, porção fica.
	_drag(pot, _window())
	assert_false(ctrl.is_carrying())
	assert_eq(ctrl.pot.portions, 1)
	assert_eq(hints[-1][0], "Ninguém pediu isso agora")
	assert_eq(feedback.size(), 1, "sem nota quando ninguém recebe")


func test_combo_delivered_item_by_item() -> void:
	var ticket := ctrl.spawn_order(["food_burger", "food_stew"])
	_cook_stew()
	_drag(_st("Stove_Pot"), _window())
	assert_eq(delivered, [[0, ticket, 1]], "ensopado é o item 1")
	assert_eq(served.size(), 0, "bilhete ainda aberto")
	assert_eq(ctrl.slots[0], ticket)
	# Hambúrguer só com pão (nota baixa, mas entrega).
	_drag(_st("Crate_bun"), _plate())
	_drag(_plate(), _window())
	assert_eq(delivered.size(), 2)
	assert_eq(delivered[1][2], 0)
	assert_eq(served.size(), 1, "fecha no último item")
	if served.size() == 1:
		assert_eq(served[0][2], ticket.score())
		assert_ne(served[0][4], "")
	assert_null(ctrl.slots[0])
	# Prato sem pedido volta à montagem.
	ctrl.advance(1.6)
	_drag(_st("Crate_bun"), _plate())
	_drag(_plate(), _window())
	assert_not_null(ctrl.plate_root, "prato voltou")
	assert_false(ctrl.stack.is_empty())
	assert_eq(hints[-1][0], "Ninguém pediu isso agora")


## Arrasta de a até b sem soltar (o item fica na mão).
func _hold(a: Vector2, b: Vector2, steps: int = 12) -> void:
	ctrl.pointer_down(a, t)
	for i in range(1, steps + 1):
		t += 16
		ctrl.pointer_move(a.lerp(b, float(i) / steps), t)


func _release(b: Vector2) -> void:
	t += 16
	ctrl.pointer_up(b, t)


func test_delivery_target_follows_carried_recipe() -> void:
	var targets: Array = []
	ctrl.delivery_target_changed.connect(func(slot): targets.append(slot))
	var burger := ctrl.spawn_order(["food_burger"])
	var stew := ctrl.spawn_order(["food_stew"])
	var s_burger := ctrl.slots.find(burger)
	var s_stew := ctrl.slots.find(stew)
	assert_ne(s_burger, s_stew)
	assert_eq(ctrl.delivery_target, s_burger, "mão vazia: bilhete mais antigo")
	_cook_stew()
	# Tigela na mão: vai ao bilhete do ensopado, não ao mais antigo.
	_hold(_st("Stove_Pot"), _window())
	assert_true(ctrl.is_carrying())
	assert_eq(ctrl.delivery_target, s_stew, "tigela: quem espera ensopado")
	assert_eq(targets[-1], s_stew)
	_release(_window())
	assert_eq(ctrl.delivery_target, s_burger, "entregou: volta ao mais antigo")
	# Ingrediente na mão conta como mão vazia.
	_hold(_st("Crate_bun"), _plate())
	assert_eq(ctrl.delivery_target, s_burger)
	_release(_plate())
	# Prato montado: o hambúrguer.
	_hold(_plate(), _window())
	assert_eq(ctrl.delivery_target, s_burger)
	_release(_st("Crate_bun"))
	# Tigela sem ninguém esperando ensopado: -1.
	assert_eq(ctrl.pot.portions, 1, "sobrou uma porção")
	_hold(_st("Stove_Pot"), _window())
	assert_eq(ctrl.delivery_target, -1, "ninguém espera ensopado")
	assert_eq(targets[-1], -1)
	_release(Vector2(0.5, 0.97))
	assert_eq(ctrl.delivery_target, s_burger)
	# Só emite quando muda.
	for i in range(1, targets.size()):
		assert_ne(targets[i], targets[i - 1], "sem repetição seguida")


func test_shift_runs_moods_and_ends() -> void:
	ctrl.start()
	_drag(_st("Crate_burger"), _st("Stove_Pan"))
	for i in 179:
		ctrl.advance(1.0)
		if ctrl.pans[0].patty == null:
			_drag(_st("Crate_burger"), _st("Stove_Pan"))
	assert_false(ctrl.frozen)
	assert_gt(added.size(), 1, "chegadas pelo relógio")
	assert_true(moods.has([0, ShiftScorer.Mood.IMPATIENT]), "1º bilhete fica impaciente")
	assert_true(moods.has([0, ShiftScorer.Mood.HUNGRY]), "e depois faminto")
	_drag(_st("Crate_carrot"), _st("CuttingBoard"))
	ctrl.advance(1.5)
	assert_true(ctrl.frozen, "congela aos 180 s")
	assert_eq(phases, [ShiftClock.Phase.OPENING, ShiftClock.Phase.RUSH, ShiftClock.Phase.CLOSING,
		ShiftClock.Phase.LAST_ORDERS, ShiftClock.Phase.CLOSED])
	assert_null(ctrl.pans[0].patty, "carne some")
	assert_null(ctrl.board, "tábua vazia")
	assert_eq(ctrl.hint_text, "")
	var hh: Node3D = ctrl._kitchen.get_node("Set/WallClock/HandHour")
	assert_almost_eq(hh.rotation.z, -TAU * 2.0 / 12.0, 0.001, "14h00")
	assert_eq(ended.size(), 0, "resumo só depois do atraso")
	_drag(_st("Crate_burger"), _st("Stove_Pan"))
	assert_false(ctrl.is_carrying(), "cozinha congelada")
	ctrl.advance(1.0)
	ctrl.advance(1.0)
	assert_eq(ended.size(), 1)
	if ended.size() == 1:
		assert_eq(ended[0]["arrived"], ctrl.shift_tickets.size())
		assert_eq(ended[0]["served"], 0)
		assert_eq(ended[0]["stars"], 1)
	ctrl.advance(5.0)
	assert_eq(ended.size(), 1, "emite uma vez")


func test_background_pauses_clock() -> void:
	ctrl.start()
	ctrl.advance(1.0)
	ctrl.auto_process = true
	ctrl.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(ctrl.app_paused)
	ctrl._process(5.0)
	assert_almost_eq(ctrl.clock.time, 1.0, 0.001, "parado em segundo plano")
	ctrl.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	ctrl._process(0.5)
	ctrl.auto_process = false
	assert_almost_eq(ctrl.clock.time, 1.5, 0.001, "volta a correr")


func test_pause_changed_signal_and_click_resumes() -> void:
	var pauses: Array = []
	ctrl.pause_changed.connect(func(p): pauses.append(p))
	ctrl.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	ctrl.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_eq(pauses, [true], "emite só quando muda")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(10, 10)
	ctrl._unhandled_input(click)
	assert_false(ctrl.app_paused, "clique retoma")
	assert_false(ctrl.recognizer.active, "o clique de retomar não vira gesto")
	assert_eq(pauses, [true, false])
	ctrl.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_eq(pauses, [true, false], "já estava retomado")


func test_forgotten_pot_burns_and_tap_empties() -> void:
	ctrl.start()
	for id in ctrl.stew_recipe.layers:
		ctrl.pot.add(id)
	ctrl.advance(StewPot.PERFECT_UNTIL_S + 1.0)
	assert_eq(hints[-1][0], "Arraste a tigela à janela", "passando do ponto: servir")
	assert_true(ctrl._pot_alert.visible, "aro ao passar do ponto")
	ctrl.advance(StewPot.BURNT_S)
	assert_true(ctrl.pot.is_burnt())
	assert_eq(hints[-1][0], "Queimou! Toque para esvaziar")
	var pot := _st("Stove_Pot")
	ctrl.pointer_down(pot, t)
	ctrl.pointer_up(pot, t + 50)
	assert_eq(ctrl.pot.stage(), StewPot.Stage.EMPTY, "um toque esvazia")
	assert_eq(ctrl.pot_model_id(), StewPot.POT_EMPTY)
	assert_false(ctrl._pot_alert.visible)


func test_burnt_patty_hint_and_feedback() -> void:
	var pan := _st("Stove_Pan")
	_drag(_st("Crate_burger"), pan)
	ctrl.advance(Patty.BURNT_S + 0.5)
	assert_eq(hints[-1][0], "Queimou! Tire da frigideira")
	assert_eq(ctrl.pans[0].patty.model_id(), Kitchen.BURGER_TRASH)
	feedback.clear()
	_drag(pan, _st("Crate_burger"))
	assert_eq(_labels(), ["Ops"])
	assert_null(ctrl.pans[0].patty)
	assert_false(ctrl.is_carrying(), "devolvida ao caixote")


func test_smoke_uses_round_soft_texture() -> void:
	var mesh := ctrl._pot_smoke.mesh as QuadMesh
	var mat := mesh.material as StandardMaterial3D
	var tex := mat.albedo_texture as GradientTexture2D
	assert_not_null(tex, "fumaça com textura")
	assert_eq(tex.fill, GradientTexture2D.FILL_RADIAL)
	assert_eq(tex.gradient.get_color(tex.gradient.get_point_count() - 1).a, 0.0, "borda transparente")
	assert_eq(ctrl.pans[0].smoke.mesh, mesh, "malha compartilhada")
	assert_lt(KitchenController.SMOKE_COLORS[Patty.Stage.BURNT].a, 0.75, "fumaça escura translúcida")
