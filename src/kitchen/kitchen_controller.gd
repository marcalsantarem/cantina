class_name KitchenController
extends Node3D
## Interação na cena da cozinha (T-007): mouse/toque -> amostras normalizadas ->
## GestureRecognizer; raycast nas estações (camada 2); itens 3D seguindo o dedo,
## encaixe nos `Snap`, picar, cozinhar/virar, montar, servir e prato de volta.
## A UI liga só pelos sinais abaixo, `get_slot_screen_position` e `start`.
## Slots dos bilhetes: 0..2 (= `TicketRail/Slot1..Slot3`).

signal ticket_added(slot: int, ticket: TicketData)
signal ticket_served(slot: int, ticket: TicketData, score: int, band: int, reply: String)
signal gesture_feedback(quality: int, label: String, screen_pos: Vector2)
## Dica da próxima ação (decisão 18); `text == ""` esconde. Só emite quando muda.
signal action_hint(text: String, screen_pos: Vector2)

const KITCHEN_SCENE := preload("res://scenes/kitchen/kitchen.tscn")
const MODEL_PATH := "res://assets/models/kaykit/%s.gltf"
const STATION_MASK := 2
const RAY_LENGTH := 200.0
## Altura (m) acima do topo da bancada em que o item segue o dedo.
const COUNTER_Y := 1.0
const CARRY_LIFT := 0.35
const RETURN_S := 0.25
const PLATE_RETURN_S := 1.5
const NEW_PLATE_S := 1.5
const PLATE_SCALE := 1.25
## Meia largura (m) do ingrediente na tábua, para as faixas de cobertura.
const CHOP_HALF_WIDTH := 0.45
const GLOW_S := 0.35
const GLOW_COLOR := Color(1.0, 0.92, 0.55, 0.75)
const SLOT_COUNT := 3
## Altura (m) acima da estação onde a dica aponta.
const HINT_LIFT := 0.4
const HINT_DROP_BOARD := "Solte na tábua"
const HINT_DROP_PAN := "Solte na panela"
const HINT_DROP_PLATE := "Solte no prato"
const HINT_CHOP := "Pique em zigue-zague ↕"
const HINT_TO_PLATE := "Arraste para o prato"
const HINT_FLIP := "Puxe para cima para virar"
const HINT_PATTY_DONE := "No ponto! Tire para o prato"
const HINT_BURNT := "Queimou! Tire da panela"
const HINT_SERVE := "Arraste o prato até a janela"
const HINT_IDLE := "Pegue um ingrediente nos caixotes"
## Cor/alfa da fumaça por Patty.Stage (alfa 0 = sem fumaça).
const SMOKE_COLORS: Array[Color] = [
	Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.3), Color(1, 1, 0.9, 0.45),
	Color(0.6, 0.6, 0.6, 0.65), Color(0.18, 0.16, 0.15, 0.85),
]


## Item na mão.
class Carry:
	var node: Node3D
	var id: String = ""
	var notes: Dictionary = {}
	## Estação de origem ("BunTopRest" para o pão de cima estacionado).
	var origin: String = ""
	## Caixote onde o item pode ser devolvido (some); "" = não pode.
	var crate_key: String = ""
	var chop: ChopTarget
	var patty: Patty
	var is_plate: bool = false


## Desligue nos testes para avançar o tempo só por `advance()`.
var auto_process: bool = true
var started: bool = false
var recipe: Recipe
var tickets: TicketQueue
var scorer: DishScorer
var replies: ReplyPicker
var recognizer: GestureRecognizer
var stack: PlateStack
## Ingrediente na tábua (null = vazia) e carne na panela (null = vazia).
var board: ChopTarget
var patty: Patty
## Faixa x (0–1) do ingrediente na tábua, para a cobertura do picar.
var chop_area_x := Vector2.ZERO
## Bilhete aberto por slot (null = livre).
var slots: Array[TicketData] = [null, null, null]
## Prato devolvido na janela (some ao tocar).
var returned_plate: Node3D
var plate_root: Node3D

var _kitchen: Node3D
var _camera: Camera3D
var _stations: Dictionary = {}
var _scenes: Dictionary = {}
var _heights: Dictionary = {}
var _ray := PhysicsRayQueryParameters3D.new()
var _carry: Carry
var _press_station: String = ""
var _board_node: Node3D
var _pan_node: Node3D
var _pan_model_id: String = ""
var _bun_top_node: Node3D
var _stack_height: float = 0.0
var _smoke: CPUParticles3D
var _smoke_stage: int = -1
var _served_node: Node3D
var _served_band: int = 0
var _return_timer: float = -1.0
var _new_plate_timer: float = -1.0
var hint_text: String = ""
var hint_pos := Vector2.ZERO
var _crates_center := Vector3.ZERO


func _ready() -> void:
	_kitchen = get_node_or_null("Kitchen")
	if _kitchen == null:
		_kitchen = KITCHEN_SCENE.instantiate()
		_kitchen.name = "Kitchen"
		add_child(_kitchen)
	_camera = _kitchen.get_node("MainCamera")
	for st: Node in _kitchen.get_node("Stations").get_children():
		if st is Area3D:
			_stations[st.name] = st
	recipe = Recipe.load_burger()
	tickets = TicketQueue.new()
	tickets.recipe_id = recipe.id
	tickets.ticket_arrived.connect(_on_ticket_arrived)
	scorer = DishScorer.new(recipe)
	replies = ReplyPicker.new()
	recognizer = GestureRecognizer.new()
	stack = PlateStack.new(recipe)
	_ray.collision_mask = STATION_MASK
	_ray.collide_with_areas = true
	_ray.collide_with_bodies = false
	var scene_plate := _stations["Plate_Assembly"].get_node_or_null("Plate") as Node3D
	if scene_plate:
		scene_plate.visible = false
	var n := 0
	for key: String in _stations:
		if key.begins_with("Crate_"):
			_crates_center += snap_position(key)
			n += 1
	_crates_center /= maxf(n, 1)
	_make_smoke()
	_make_plate()
	_update_hint()


func _process(delta: float) -> void:
	if auto_process:
		advance(delta)


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			pointer_down(_to_norm(mb.position), Time.get_ticks_msec())
		else:
			pointer_up(_to_norm(mb.position), Time.get_ticks_msec())
		return
	var mm := event as InputEventMouseMotion
	if mm and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT):
		pointer_move(_to_norm(mm.position), Time.get_ticks_msec())


# --- Contrato com a UI --------------------------------------------------------

func start() -> void:
	if started:
		return
	started = true
	tickets.spawn()
	_update_hint()


func get_slot_screen_position(slot: int) -> Vector2:
	var rail: Node3D = _stations["TicketRail"]
	var m := rail.get_node_or_null("Slot%d" % (clampi(slot, 0, SLOT_COUNT - 1) + 1)) as Node3D
	return _camera.unproject_position(m.global_position if m else rail.global_position)


# --- Tempo -------------------------------------------------------------------

func advance(delta: float) -> void:
	if started:
		tickets.tick(delta)
	if patty != null:
		patty.tick(delta)
		_update_pan_visuals()
	if _return_timer >= 0.0:
		_return_timer -= delta
		if _return_timer < 0.0:
			_show_returned_plate()
	if _new_plate_timer >= 0.0:
		_new_plate_timer -= delta
		if _new_plate_timer < 0.0:
			_make_plate()
	_update_hint()


# --- Entrada (p = 0–1 da viewport, y para baixo; t em ms) ---------------------

func pointer_down(p: Vector2, t_ms: int) -> void:
	if recognizer.active or _carry != null:
		return
	var size := _viewport_size()
	recognizer.aspect = size.x / maxf(size.y, 1.0)
	_press_station = station_at(p)
	var mode: int = GestureRecognizer.Mode.DRAG
	match _press_station:
		"OrderWindow":
			_clear_returned()
		"CuttingBoard":
			if board != null and not board.is_done():
				mode = GestureRecognizer.Mode.CHOP
				_update_chop_area()
				recognizer.set_chop_area(chop_area_x.x, chop_area_x.y)
				board.begin_session()
		"Stove_Pan":
			if patty != null:
				mode = GestureRecognizer.Mode.PAN
	recognizer.begin(mode, p, t_ms)
	_update_hint()


func pointer_move(p: Vector2, t_ms: int) -> void:
	if not recognizer.active:
		return
	_handle_events(recognizer.add_sample(p, t_ms))
	if _carry != null:
		_follow(p)
	_update_hint()


func pointer_up(p: Vector2, t_ms: int) -> void:
	if not recognizer.active:
		return
	recognizer.finish(p, t_ms)
	_handle_events(recognizer.last_events)
	if recognizer.mode == GestureRecognizer.Mode.CHOP and board != null:
		board.end_session()
		if recognizer.cuts > 0:
			_feedback(board.cut_quality(), _board_node)
	if _carry != null:
		_follow(p)
		_drop(p)
	_press_station = ""
	_update_hint()


## Nome da estação (Area3D na camada 2) sob o ponto, ou "".
func station_at(p: Vector2) -> String:
	var px := p * _viewport_size()
	_ray.from = _camera.project_ray_origin(px)
	_ray.to = _ray.from + _camera.project_ray_normal(px) * RAY_LENGTH
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
	if hit.is_empty():
		return ""
	return String((hit["collider"] as Node).name)


## Posição 0–1 na tela de um ponto do mundo.
func world_to_norm(pos: Vector3) -> Vector2:
	return _to_norm(_camera.unproject_position(pos))


func snap_position(station: String) -> Vector3:
	return (_stations[station].get_node("Snap") as Node3D).global_position


func bun_top_rest_position() -> Vector3:
	return (_stations["Plate_Assembly"].get_node("BunTopRest") as Node3D).global_position


func is_carrying() -> bool:
	return _carry != null


# --- Eventos do gesto ----------------------------------------------------------

func _handle_events(ev: int) -> void:
	if ev & GestureRecognizer.Event.CUT and board != null:
		if board.add_cut(recognizer.last_stroke_ms, recognizer.last_stroke_bands):
			_refresh_board_model()
		_bump(_board_node)
	if ev & GestureRecognizer.Event.SESSION_ENDED and board != null:
		board.end_session()
		board.begin_session()
	if ev & GestureRecognizer.Event.FLIP and patty != null:
		var q := patty.flip()
		_flip_anim()
		_feedback(q, _pan_node)
	if ev & GestureRecognizer.Event.SHAKE:
		_shake(_stations["Stove_Pan"].get_node_or_null("Pan"))
	if ev & GestureRecognizer.Event.DRAG_STARTED:
		_start_carry()


func _start_carry() -> void:
	var c := Carry.new()
	c.origin = _press_station
	if _press_station.begins_with("Crate_"):
		c.crate_key = _press_station.substr(6)
		c.id = recipe.crate_item(c.crate_key)
		if c.id == "":
			return
		c.node = _spawn(c.id, self)
		c.node.global_position = snap_position(_press_station)
	elif _press_station == "CuttingBoard":
		if board == null or board.carry_item_id() == "":
			return
		c.id = board.carry_item_id()
		c.notes = board.notes()
		c.chop = board
		c.crate_key = _crate_of(board.raw_id)
		c.node = _spawn(c.id, self)
		c.node.global_position = _board_node.global_position
		_board_node.queue_free()
		_board_node = null
		board = null
	elif _press_station == "Stove_Pan":
		if patty == null:
			return
		var q := patty.remove()
		c.patty = patty
		c.id = patty.model_id()
		c.notes = patty.notes()
		c.crate_key = "burger"
		c.node = _pan_node
		c.node.reparent(self)
		patty = null
		_pan_node = null
		_set_smoke(Patty.Stage.RAW)
		_feedback(q, c.node)
	elif _press_station == "Plate_Assembly":
		if _bun_top_node != null and _closer_to_bun_top(recognizer.start_point()):
			c.id = Kitchen.BUN_TOP
			c.origin = "BunTopRest"
			c.node = _bun_top_node
			_bun_top_node = null
		elif plate_root != null and not stack.is_empty():
			c.is_plate = true
			c.node = plate_root
			plate_root = null
		else:
			return
		c.node.reparent(self)
	else:
		return
	_carry = c


func _drop(p: Vector2) -> void:
	var c := _carry
	_carry = null
	var target := station_at(p)
	if c.is_plate:
		if target == "OrderWindow" and tickets.open_count() > 0:
			_serve(c.node)
		else:
			_return(c)
		return
	if c.crate_key != "" and target == "Crate_" + c.crate_key:
		c.node.queue_free()
		return
	match target:
		"CuttingBoard":
			if board == null and c.chop == null and recipe.chop.has(c.id):
				board = ChopTarget.from_recipe(recipe, c.id)
				_place_on_board(c.node)
				return
		"Stove_Pan":
			if patty == null and (c.patty != null or c.id == Kitchen.BURGER_UNCOOKED):
				_place_in_pan(c.patty if c.patty != null else Patty.new(), c.node)
				return
		"Plate_Assembly":
			if plate_root != null and stack.can_accept(c.id):
				_assemble(c)
				return
	_return(c)


## Devolve à origem: o estado volta já; só o visual anda (tween).
func _return(c: Carry) -> void:
	if c.is_plate:
		plate_root = c.node
		_reparent_tween(c.node, _stations["Plate_Assembly"], Vector3.ZERO)
	elif c.origin == "BunTopRest":
		_bun_top_node = c.node
		var area: Node3D = _stations["Plate_Assembly"]
		_reparent_tween(c.node, area, area.to_local(bun_top_rest_position()))
	elif c.origin == "CuttingBoard":
		board = c.chop
		var from := c.node.global_position
		c.node.queue_free()
		_refresh_board_model()
		_board_node.global_position = from
		_tween_local(_board_node, _local_snap("CuttingBoard"))
	elif c.origin == "Stove_Pan":
		_place_in_pan(c.patty, c.node)
	else:
		# Veio de um caixote: volta e some.
		var tw := c.node.create_tween()
		tw.tween_property(c.node, "global_position", snap_position(c.origin), RETURN_S)
		tw.tween_callback(c.node.queue_free)


# --- Estações ------------------------------------------------------------------

func _place_on_board(node: Node3D) -> void:
	_board_node = node
	_reparent_tween(node, _stations["CuttingBoard"], _local_snap("CuttingBoard"))


func _refresh_board_model() -> void:
	var area: Node3D = _stations["CuttingBoard"]
	var xf := Transform3D(Basis.IDENTITY, _local_snap("CuttingBoard"))
	if _board_node != null:
		xf = _board_node.transform
		_board_node.queue_free()
	_board_node = _spawn(board.model_id(), area)
	_board_node.transform = xf


func _update_chop_area() -> void:
	var c := snap_position("CuttingBoard")
	var a := world_to_norm(c - Vector3(CHOP_HALF_WIDTH, 0, 0)).x
	var b := world_to_norm(c + Vector3(CHOP_HALF_WIDTH, 0, 0)).x
	chop_area_x = Vector2(minf(a, b), maxf(a, b))


func _place_in_pan(p: Patty, node: Node3D) -> void:
	patty = p
	patty.place_in_pan()
	_pan_node = node
	_pan_model_id = patty.model_id()
	_reparent_tween(node, _stations["Stove_Pan"], _local_snap("Stove_Pan"))
	_smoke_stage = -1
	_update_pan_visuals()


func _update_pan_visuals() -> void:
	var id := patty.model_id()
	if id != _pan_model_id and _pan_node != null:
		_pan_model_id = id
		var xf := _pan_node.transform
		_pan_node.queue_free()
		_pan_node = _spawn(id, _stations["Stove_Pan"])
		_pan_node.transform = xf
	var stage := Patty.Stage.BURNT if patty.is_burnt() else patty.down_stage()
	if stage != _smoke_stage:
		_set_smoke(stage)


func _assemble(c: Carry) -> void:
	# A precisão da soltura vale só na nota; o visual fica centralizado (decisão 17).
	var center := world_to_norm(snap_position("Plate_Assembly"))
	var q := recognizer.drop_quality(center)
	var off := recognizer.drop_offset_u(center)
	stack.add(c.id, c.notes, q, off)
	var item: Dictionary = stack.items[-1]
	var node := c.node
	if c.id == Kitchen.BUN:
		var from := node.global_position
		node.queue_free()
		node = _spawn(Kitchen.BUN_BOTTOM, self)
		node.global_position = from
		var area: Node3D = _stations["Plate_Assembly"]
		_bun_top_node = _spawn(Kitchen.BUN_TOP, area)
		_bun_top_node.position = area.to_local(bun_top_rest_position())
	node.rotation = Vector3.ZERO
	node.scale = Vector3.ONE
	_reparent_tween(node, plate_root, Vector3(0, _stack_height, 0))
	_stack_height += _height_of(item["id"], node)
	_feedback(q, node)


func _serve(plate: Node3D) -> void:
	var ticket := tickets.serve_oldest()
	var slot := slots.find(ticket)
	if slot >= 0:
		slots[slot] = null
	var res := scorer.score(ticket.without, stack.take_all())
	var band: int = res["band"]
	# Faixa de bilhete da UI: 0 = <50, 1 = 50–79, 2 = ≥80 (DishScorer.Band é o inverso).
	var ui_band := 2 - band
	var reply := replies.pick(band, res["dominant"])
	if _bun_top_node != null:
		_bun_top_node.queue_free()
		_bun_top_node = null
	_stack_height = 0.0
	_clear_returned()
	if _served_node != null:
		_served_node.queue_free()
	_served_node = plate
	_served_band = band
	var tw := plate.create_tween()
	tw.tween_property(plate, "global_position", snap_position("OrderWindow"), RETURN_S)
	tw.tween_callback(plate.hide)
	_return_timer = PLATE_RETURN_S
	_new_plate_timer = NEW_PLATE_S
	ticket_served.emit(slot, ticket, res["score"], ui_band, reply)


func _show_returned_plate() -> void:
	_clear_returned()
	if _served_node == null:
		return
	var model := DishScorer.return_model(_served_band)
	if model == "":
		returned_plate = _served_node
		returned_plate.show()
	else:
		_served_node.queue_free()
		returned_plate = _spawn(model, self)
		returned_plate.scale = Vector3.ONE * PLATE_SCALE
	_served_node = null
	returned_plate.global_position = snap_position("OrderWindow")
	_glow(returned_plate)


func _clear_returned() -> void:
	if returned_plate != null:
		returned_plate.queue_free()
		returned_plate = null


func _make_plate() -> void:
	var area: Node3D = _stations["Plate_Assembly"]
	plate_root = Node3D.new()
	plate_root.name = "AssemblyPlate"
	area.add_child(plate_root)
	var model := _spawn("plate", plate_root)
	model.scale = Vector3.ONE * PLATE_SCALE
	_stack_height = _local_snap("Plate_Assembly").y
	stack.clear()


func _on_ticket_arrived(ticket: TicketData) -> void:
	var slot := slots.find(null)
	if slot < 0:
		return
	slots[slot] = ticket
	ticket_added.emit(slot, ticket)


# --- Visual --------------------------------------------------------------------

func _spawn(id: String, parent: Node) -> Node3D:
	var ps: PackedScene = _scenes.get(id)
	if ps == null:
		ps = load(MODEL_PATH % id)
		_scenes[id] = ps
	var n := ps.instantiate() as Node3D
	n.name = id
	parent.add_child(n)
	return n


func _follow(p: Vector2) -> void:
	var px := p * _viewport_size()
	var from := _camera.project_ray_origin(px)
	var dir := _camera.project_ray_normal(px)
	if absf(dir.y) < 0.0001:
		return
	var t := (COUNTER_Y + CARRY_LIFT - from.y) / dir.y
	_carry.node.global_position = from + dir * t


func _reparent_tween(node: Node3D, parent: Node3D, local_pos: Vector3) -> void:
	node.reparent(parent)
	_tween_local(node, local_pos)


func _tween_local(node: Node3D, local_pos: Vector3) -> void:
	var tw := node.create_tween()
	tw.tween_property(node, "position", local_pos, RETURN_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _flip_anim() -> void:
	if _pan_node == null:
		return
	var base := _local_snap("Stove_Pan")
	_pan_node.position = base
	var tw := _pan_node.create_tween()
	tw.tween_property(_pan_node, "position:y", base.y + 0.6, 0.15).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_pan_node, "rotation:z", _pan_node.rotation.z + PI, 0.3)
	tw.tween_property(_pan_node, "position:y", base.y, 0.15).set_ease(Tween.EASE_IN)


func _bump(node: Node3D) -> void:
	if node == null:
		return
	node.scale = Vector3(1.08, 0.85, 1.08)
	node.create_tween().tween_property(node, "scale", Vector3.ONE, 0.12)


func _shake(node: Node3D) -> void:
	if node == null:
		return
	var tw := node.create_tween()
	for a: float in [0.08, -0.06, 0.03, 0.0]:
		tw.tween_property(node, "rotation:z", a, 0.05)


## Brilho curto no item + palavra de feedback na UI.
func _feedback(q: int, node: Node3D) -> void:
	if q < 0:
		return
	var pos := snap_position("Plate_Assembly")
	if node != null:
		_glow(node)
		pos = node.global_position
	gesture_feedback.emit(q, Kitchen.quality_label(q), _camera.unproject_position(pos + Vector3(0, 0.4, 0)))


func _glow(node: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = GLOW_COLOR
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	for m: MeshInstance3D in meshes:
		m.material_overlay = mat
	var tw := node.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, GLOW_S)
	tw.tween_callback(_clear_glow.bind(meshes, mat))


func _clear_glow(meshes: Array, mat: Material) -> void:
	for m: Variant in meshes:
		if is_instance_valid(m) and (m as MeshInstance3D).material_overlay == mat:
			(m as MeshInstance3D).material_overlay = null


func _make_smoke() -> void:
	_smoke = CPUParticles3D.new()
	_smoke.name = "Smoke"
	_smoke.amount = 10
	_smoke.lifetime = 1.4
	_smoke.emitting = false
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = 0.2
	_smoke.direction = Vector3.UP
	_smoke.spread = 15.0
	_smoke.gravity = Vector3(0, 0.4, 0)
	_smoke.initial_velocity_min = 0.4
	_smoke.initial_velocity_max = 0.8
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	_smoke.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.35, 0.35)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	_smoke.mesh = quad
	var pan: Node3D = _stations["Stove_Pan"]
	pan.add_child(_smoke)
	_smoke.position = _local_snap("Stove_Pan") + Vector3(0, 0.25, 0)


func _set_smoke(stage: int) -> void:
	_smoke_stage = stage
	var c: Color = SMOKE_COLORS[stage]
	_smoke.color = c
	_smoke.emitting = c.a > 0.0


# --- Auxiliares ------------------------------------------------------------------

func _viewport_size() -> Vector2:
	var s := get_viewport().get_visible_rect().size
	return s if s.x > 0.0 and s.y > 0.0 else Vector2(1280, 720)


func _to_norm(px: Vector2) -> Vector2:
	return px / _viewport_size()


func _local_snap(station: String) -> Vector3:
	return (_stations[station].get_node("Snap") as Node3D).position


func _closer_to_bun_top(p: Vector2) -> bool:
	var a := recognizer.aspect
	var d_top := GestureRecognizer.distance_u(p, world_to_norm(bun_top_rest_position()), a)
	var d_plate := GestureRecognizer.distance_u(p, world_to_norm(snap_position("Plate_Assembly")), a)
	return d_top < d_plate


func _crate_of(item_id: String) -> String:
	for key: String in recipe.crates:
		if recipe.crates[key] == item_id:
			return key
	return ""


## Altura (m) do topo do modelo acima da sua origem (AABB), para empilhar; medida
## uma vez por id. A origem dos modelos é o apoio: queijo e alface caem pelas bordas
## abaixo dela (AABB com y < 0), então conta só o topo para não flutuar.
func _height_of(id: String, node: Node3D) -> float:
	if _heights.has(id):
		return _heights[id]
	var inv := node.global_transform.affine_inverse()
	var box := AABB()
	var first := true
	for m: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (inv * m.global_transform) * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var h := box.end.y if not first and box.end.y > 0.0 else 0.05
	_heights[id] = h
	return h


# --- Dica de ação (decisão 18) ---------------------------------------------------

func _update_hint() -> void:
	var text := ""
	var station := ""
	if _carry != null:
		station = _carry_target(_carry)
		match station:
			"CuttingBoard": text = HINT_DROP_BOARD
			"Stove_Pan": text = HINT_DROP_PAN
			"Plate_Assembly": text = HINT_DROP_PLATE
			"OrderWindow": text = HINT_SERVE
	elif patty != null:
		station = "Stove_Pan"
		if patty.is_burnt():
			text = HINT_BURNT
		elif _side_ok(Patty.Side.A) and _side_ok(Patty.Side.B):
			text = HINT_PATTY_DONE
		else:
			text = HINT_FLIP
	elif board != null:
		station = "CuttingBoard"
		text = HINT_TO_PLATE if board.is_done() else HINT_CHOP
	elif plate_root != null and not stack.is_empty():
		station = "Plate_Assembly"
		text = HINT_SERVE
	elif tickets.open_count() > 0:
		station = "Crates"
		text = HINT_IDLE
	var pos := Vector2.ZERO
	if text != "":
		pos = _camera.unproject_position(_hint_anchor(station) + Vector3(0, HINT_LIFT, 0))
	if text == hint_text and pos.distance_squared_to(hint_pos) < 1.0:
		return
	hint_text = text
	hint_pos = pos
	action_hint.emit(text, pos)


## Estação onde o item na mão deve ser solto ("" = nenhuma).
func _carry_target(c: Carry) -> String:
	if c.is_plate:
		return "OrderWindow"
	if c.chop == null and c.patty == null and recipe.chop.has(c.id):
		return "CuttingBoard"
	if c.patty == null and c.id == Kitchen.BURGER_UNCOOKED:
		return "Stove_Pan"
	if plate_root != null and stack.can_accept(c.id):
		return "Plate_Assembly"
	return ""


func _hint_anchor(station: String) -> Vector3:
	if station == "Crates":
		return _crates_center
	if station == "OrderWindow":
		return snap_position(station) + Vector3(0, 0.6, 0)
	return snap_position(station)


func _side_ok(side: int) -> bool:
	return Patty.quality_for_time(patty.side_time(side)) != Kitchen.Quality.CLUMSY
