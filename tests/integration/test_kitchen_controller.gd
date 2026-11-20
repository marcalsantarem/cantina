extends GutTest
## KitchenController na cena real (sem janela): hambúrguer completo por amostras
## normalizadas -> raycast nas estações -> gestos -> servir -> prato de volta.

const GAME := preload("res://scenes/game/game.tscn")

var ctrl: KitchenController
var t: int = 0
var added: Array = []
var served: Array = []
var feedback: Array = []
var hints: Array = []


func before_each() -> void:
	ctrl = GAME.instantiate()
	add_child_autofree(ctrl)
	ctrl.auto_process = false
	t = 10000
	added.clear()
	served.clear()
	feedback.clear()
	hints.clear()
	ctrl.action_hint.connect(func(text, pos): hints.append([text, pos]))
	ctrl.ticket_added.connect(func(slot, ticket): added.append([slot, ticket]))
	ctrl.ticket_served.connect(func(slot, ticket, score, band, reply): served.append([slot, ticket, score, band, reply]))
	ctrl.gesture_feedback.connect(func(q, label, pos): feedback.append([q, label, pos]))
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


## Zigue-zague: 6 traços de 200 ms, Δy = 0,08, pontas varrendo a largura do ingrediente.
func _chop_six() -> void:
	var c := _n(ctrl.snap_position("CuttingBoard"))
	var top := c.y - 0.04
	var bottom := c.y + 0.04
	# A faixa só é conhecida depois do toque; usa a mesma conta do controlador.
	var half := ctrl.world_to_norm(ctrl.snap_position("CuttingBoard") + Vector3(KitchenController.CHOP_HALF_WIDTH, 0, 0)).x - c.x
	var x0 := c.x - half * 0.9
	var x1 := c.x + half * 0.9
	var prev := Vector2(x0, top)
	ctrl.pointer_down(prev, t)
	for k in range(1, 7):
		var nxt := Vector2(lerpf(x0, x1, k / 6.0), bottom if k % 2 == 1 else top)
		for s in range(1, 5):
			t += 50
			ctrl.pointer_move(prev.lerp(nxt, s / 4.0), t)
		prev = nxt
	t += 10
	ctrl.pointer_up(prev, t)


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


func test_station_raycast() -> void:
	assert_eq(ctrl.station_at(_n(ctrl.snap_position("Crate_bun"))), "Crate_bun")
	assert_eq(ctrl.station_at(_n(ctrl.snap_position("CuttingBoard"))), "CuttingBoard")
	assert_eq(ctrl.station_at(_n(ctrl.snap_position("Stove_Pan"))), "Stove_Pan")
	assert_eq(ctrl.station_at(_plate()), "Plate_Assembly")
	assert_eq(ctrl.station_at(_n(ctrl.snap_position("OrderWindow") + Vector3(0, 0.6, 0))), "OrderWindow")


func test_no_ticket_before_start() -> void:
	ctrl.advance(20.0)
	assert_eq(added.size(), 0)
	ctrl.start()
	assert_eq(added.size(), 1)
	assert_eq(added[0][0], 0, "primeiro bilhete no slot 0")
	assert_typeof(ctrl.get_slot_screen_position(0), TYPE_VECTOR2)


func test_drop_outside_returns_to_crate() -> void:
	_drag(_n(ctrl.snap_position("Crate_cheese")), Vector2(0.5, 0.97))
	assert_false(ctrl.is_carrying())
	assert_true(ctrl.stack.is_empty())


func test_full_burger_served() -> void:
	ctrl.start()
	assert_eq(added.size(), 1)
	var ticket: TicketData = added[0][1]
	ticket.without.clear()

	# Pão inteiro no prato -> base + topo estacionado.
	_drag(_n(ctrl.snap_position("Crate_bun")), _plate())
	assert_eq(ctrl.stack.ids(), [Kitchen.BUN_BOTTOM] as Array[String])
	assert_true(ctrl.stack.bun_top_parked)

	# Carne: panela, 8 s, puxão para cima, 8 s, tirar e montar.
	var pan := _n(ctrl.snap_position("Stove_Pan"))
	_drag(_n(ctrl.snap_position("Crate_burger")), pan)
	assert_not_null(ctrl.patty)
	ctrl.advance(8.0)
	feedback.clear()
	_drag(pan, pan + Vector2(0, -0.16), 6)
	assert_eq(ctrl.patty.side_down, Patty.Side.B, "virou")
	assert_eq(_labels(), ["Perfeito!"])
	ctrl.advance(8.0)
	assert_eq(ctrl.patty.model_id(), Kitchen.BURGER_COOKED)
	_drag(pan, _plate())
	assert_null(ctrl.patty)

	_drag(_n(ctrl.snap_position("Crate_cheese")), _plate())

	# Alface e tomate: tábua, 6 cortes, arrastar para o prato.
	var board := _n(ctrl.snap_position("CuttingBoard"))
	for crate in ["Crate_lettuce", "Crate_tomato"]:
		_drag(_n(ctrl.snap_position(crate)), board)
		assert_not_null(ctrl.board, crate + " na tábua")
		feedback.clear()
		_chop_six()
		assert_eq(ctrl.board.cuts, 6, crate + " cortes")
		assert_eq(_labels(), ["Perfeito!"], crate + " corte")
		_drag(board, _plate())
		assert_null(ctrl.board)

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
	_drag(_plate(), _n(ctrl.snap_position("OrderWindow") + Vector3(0, 0.6, 0)))
	assert_eq(served.size(), 1)
	if served.size() == 1:
		assert_eq(served[0][0], 0)
		assert_eq(served[0][1], ticket)
		assert_eq(served[0][2], 100, "nota")
		assert_eq(served[0][3], 2, "faixa ≥80")
		assert_ne(served[0][4], "")
	assert_null(ctrl.plate_root, "prato saiu")

	# 1,5 s: prato limpo volta na janela e prato novo na montagem.
	ctrl.advance(1.6)
	assert_not_null(ctrl.returned_plate)
	assert_not_null(ctrl.plate_root)
	assert_true(ctrl.stack.is_empty())
	ctrl.pointer_down(_n(ctrl.snap_position("OrderWindow") + Vector3(0, 0.6, 0)), t)
	ctrl.pointer_up(_n(ctrl.snap_position("OrderWindow") + Vector3(0, 0.6, 0)), t + 50)
	assert_null(ctrl.returned_plate, "some ao tocar")

	var cut_hints := ["Solte na tábua", "Pique em zigue-zague ↕", "Arraste para o prato", "Solte no prato", "Arraste o prato até a janela"]
	var expected := ["Pegue um ingrediente nos caixotes",
		"Solte no prato", "Arraste o prato até a janela",
		"Solte na panela", "Puxe para cima para virar", "No ponto! Tire para o prato",
		"Solte no prato", "Arraste o prato até a janela",
		"Solte no prato", "Arraste o prato até a janela"]
	expected.append_array(cut_hints)
	expected.append_array(cut_hints)
	expected.append_array(["Solte no prato", "Arraste o prato até a janela"])
	assert_eq(_hint_texts().slice(0, expected.size()), expected, "sequência de dicas")


func test_hint_positions_and_no_repeat() -> void:
	ctrl.start()
	assert_eq(hints.size(), 1)
	var crate := _n(ctrl.snap_position("Crate_burger"))
	var pan := _n(ctrl.snap_position("Stove_Pan"))
	ctrl.pointer_down(crate, t)
	for i in range(1, 13):
		t += 16
		ctrl.pointer_move(crate.lerp(pan, i / 12.0), t)
	assert_eq(hints[-1][0], "Solte na panela")
	var n := hints.size()
	ctrl.advance(0.1)
	ctrl.advance(0.1)
	assert_eq(hints.size(), n, "não repete a mesma dica")
	var pan_px: Vector2 = ctrl.world_to_norm(ctrl.snap_position("Stove_Pan") + Vector3(0, KitchenController.HINT_LIFT, 0)) * ctrl._viewport_size()
	assert_almost_eq(hints[-1][1], pan_px, Vector2.ONE, "dica na panela")
	t += 16
	ctrl.pointer_up(pan, t)
	assert_eq(hints[-1][0], "Puxe para cima para virar")
