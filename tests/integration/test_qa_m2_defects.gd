extends GutTest
## QA M2 (BRF-017): regressões de defeitos achados no navegador (corrigidos no BRF-018).

const GAME := preload("res://scenes/game/game.tscn")

var ctrl: KitchenController
var t: int = 0
var delivered: Array = []


func before_each() -> void:
	ctrl = GAME.instantiate()
	add_child_autofree(ctrl)
	ctrl.auto_process = false
	t = 10000
	delivered.clear()
	ctrl.ticket_item_delivered.connect(func(slot, ticket, idx): delivered.append([slot, ticket, idx]))
	await wait_physics_frames(3)


func _n(pos: Vector3) -> Vector2:
	return ctrl.world_to_norm(pos)


func _drag(a: Vector2, b: Vector2, steps: int = 12) -> void:
	ctrl.pointer_down(a, t)
	for i in range(1, steps + 1):
		t += 16
		ctrl.pointer_move(a.lerp(b, float(i) / steps), t)
	t += 16
	ctrl.pointer_up(b, t)


func _cook_stew() -> void:
	for id in ctrl.stew_recipe.layers:
		ctrl.pot.add(id)
	ctrl.advance(StewPot.READY_S + 0.1)


## Q-G1: tocar a panela no lado de baixo/esquerdo e arrastar até a janela (cima/direita)
## passa pelo centro da panela e o ângulo gira ~180°; a tigela tem de sair mesmo assim.
func test_serve_stew_from_near_side_of_pot() -> void:
	var ticket := ctrl.spawn_order(["food_stew"])
	_cook_stew()
	var size := ctrl._viewport_size()
	var aspect := size.x / size.y
	var c := _n(ctrl.snap_position("Stove_Pot"))
	var window := _n(ctrl.snap_position("OrderWindow") + Vector3(0, 0.6, 0))
	# Toques no lado esquerdo da panela (o lado oposto à janela), ainda dentro dela.
	var failed := []
	for off: Vector2 in [Vector2(-0.03, 0.0), Vector2(-0.02, 0.0), Vector2(-0.015, 0.005)]:
		var start := c + Vector2(off.x / aspect, off.y)
		assert_eq(ctrl.station_at(start), "Stove_Pot", "o toque começa dentro da panela %s" % off)
		var before := delivered.size()
		_drag(start, window, 20)
		if delivered.size() == before:
			failed.append(off)
		if ctrl.pot.portions == 0:
			_cook_stew()
		if ctrl.tickets.oldest_waiting("food_stew") == null:
			ctrl.spawn_order(["food_stew"])
	assert_eq(failed, [], "tigela sai de qualquer lado da panela")
	assert_eq(delivered.size(), 3)
	if delivered.size() > 0:
		assert_eq(delivered[0][1], ticket)
