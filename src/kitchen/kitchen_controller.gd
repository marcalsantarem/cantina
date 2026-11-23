class_name KitchenController
extends Node3D
## Interação na cena da cozinha (T-007; M2 T-019): mouse/toque -> amostras normalizadas ->
## GestureRecognizer/StirGesture; raycast nas estações (camada 2); itens 3D seguindo o
## dedo, encaixe nos `Snap`, picar, 2 frigideiras, panela de ensopado, montar, servir item
## a item e prato/tigela de volta. O `ShiftClock` dirige o turno (chegadas, fases, fim).
## A UI liga só pelos sinais abaixo, `get_slot_screen_position` e `start`.
## Slots dos bilhetes: 0..3 (= `TicketRail/Slot1..Slot4`).

signal ticket_added(slot: int, ticket: TicketData)
## Só quando o bilhete fecha (todos os itens entregues). `score` = nota do bilhete.
signal ticket_served(slot: int, ticket: TicketData, score: int, band: int, reply: String)
signal gesture_feedback(quality: int, label: String, screen_pos: Vector2)
## Dica da próxima ação (decisão 18); `text == ""` esconde. Só emite quando muda.
signal action_hint(text: String, screen_pos: Vector2)
## Um item do bilhete foi entregue (emitido antes de `ticket_served` quando é o último).
signal ticket_item_delivered(slot: int, ticket: TicketData, item_index: int)
## Humor de espera mudou (`ShiftScorer.Mood`).
signal ticket_mood_changed(slot: int, mood: int)
## Fase do turno (`ShiftClock.Phase`); emite OPENING no `start()`.
signal shift_phase_changed(phase: int)
## Resumo do turno (`ShiftScorer.summarize`), `END_SCREEN_DELAY_S` após o fim.
signal shift_ended(summary: Dictionary)
## Pausa por foco/segundo plano ligada ou desligada (a UI mostra "Pausado").
signal pause_changed(paused: bool)

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
const SLOT_COUNT := 4
const PAN_STATIONS: Array[String] = ["Stove_Pan", "Stove_Pan2"]
const POT_STATION := "Stove_Pot"
## Arrastar a mais que isto (u) do centro da panela, sem volta de mexer, leva a tigela.
const POT_LEAVE_U := 0.17
## Picados visíveis na panela montando: escala e deslocamento local (m) por ordem.
const POT_ITEM_SCALE := 0.55
const POT_ITEM_OFFSETS: Array[Vector3] = [Vector3(-0.09, 0, 0.03), Vector3(0.09, 0, 0.03), Vector3(0, 0.02, -0.08)]
## Grude a partir do qual a dica pede para mexer (antes de grudar de vez).
const POT_STIR_HINT_G := 0.3
const POT_BURNT_COLOR := Color(0.08, 0.05, 0.03, 0.6)
## Pulso do aro de alerta: amplitude da escala e frequência (Hz).
const ALERT_PULSE := 0.12
const ALERT_HZ := 1.5
## Tempo (s) da dica "Ninguém pediu isso agora".
const NOBODY_HINT_S := 2.0
## Altura (m) acima da estação onde a dica aponta.
const HINT_LIFT := 0.4
const HINT_DROP_BOARD := "Solte na tábua"
const HINT_DROP_PAN := "Solte na panela"
const HINT_DROP_PLATE := "Solte no prato"
const HINT_DROP_POT := "Solte os legumes na panela"
const HINT_CHOP := "Pique em zigue-zague"
const HINT_TO_PLATE := "Arraste para o prato"
const HINT_FLIP := "Puxe para cima para virar"
const HINT_PATTY_DONE := "No ponto! Tire para o prato"
const HINT_BURNT := "Queimou! Tire da panela"
const HINT_SERVE := "Arraste o prato até a janela"
const HINT_SERVE_BOWL := "Arraste a tigela à janela"
const HINT_STIR := "Mexa em círculos"
const HINT_SCRAPE := "Raspe a panela (3 voltas)"
const HINT_NOBODY := "Ninguém pediu isso agora"
const HINT_IDLE := "Pegue um ingrediente nos caixotes"
## Cor/alfa da fumaça por Patty.Stage (alfa 0 = sem fumaça).
const SMOKE_COLORS: Array[Color] = [
	Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.3), Color(1, 1, 0.9, 0.45),
	Color(0.6, 0.6, 0.6, 0.55), Color(0.22, 0.2, 0.19, 0.65),
]
## Tamanho (px) da textura redonda da fumaça, gerada uma vez.
const SMOKE_TEX_PX := 64


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
	## Tigela de ensopado tirada da panela (a porção só sai na entrega).
	var is_bowl: bool = false


## Uma frigideira do fogão.
class Pan:
	var station: String = ""
	var area: Node3D
	var patty: Patty
	var node: Node3D
	var model_id: String = ""
	var smoke: CPUParticles3D
	var smoke_stage: int = -1
	var alert: Node3D


## Desligue nos testes para avançar o tempo só por `advance()`.
var auto_process: bool = true
var started: bool = false
## true depois dos 180 s: a cozinha não responde mais.
var frozen: bool = false
## App em segundo plano: `_process` não avança o tempo.
var app_paused: bool = false
var recipe: Recipe
var stew_recipe: Recipe
var clock: ShiftClock
var tickets: TicketQueue
var scorer: DishScorer
var replies: ReplyPicker
var recognizer: GestureRecognizer
var stir: StirGesture
var stack: PlateStack
var pot: StewPot
## Ingrediente na tábua (null = vazia).
var board: ChopTarget
var pans: Array[Pan] = []
## Faixa x (0–1) do ingrediente na tábua, para a cobertura do picar.
var chop_area_x := Vector2.ZERO
## Bilhete aberto por slot (null = livre).
var slots: Array[TicketData] = [null, null, null, null]
## Todos os bilhetes que chegaram no turno (para o resumo).
var shift_tickets: Array[TicketData] = []
## Prato/tigela devolvido na janela (some ao tocar).
var returned_plate: Node3D
var plate_root: Node3D
var hint_text: String = ""
var hint_pos := Vector2.ZERO

var _kitchen: Node3D
var _camera: Camera3D
var _stations: Dictionary = {}
var _scenes: Dictionary = {}
var _heights: Dictionary = {}
var _ray := PhysicsRayQueryParameters3D.new()
var _carry: Carry
var _press_station: String = ""
var _board_node: Node3D
var _bun_top_node: Node3D
var _stack_height: float = 0.0
var _served_node: Node3D
var _served_band: int = 0
var _served_recipe: String = ""
var _return_timer: float = -1.0
var _new_plate_timer: float = -1.0
var _nobody_timer: float = -1.0
var _end_timer: float = -1.0
var _crates_center := Vector3.ZERO
var _moods := PackedInt32Array()
var _fx_time: float = 0.0
var _hand_hour: Node3D
var _hand_minute: Node3D
var _wall_minute: int = -1
var _pot_area: Node3D
var _pot_model: Node3D
var _pot_model_id: String = ""
var _pot_scale := Vector3.ONE
var _pot_stage: int = -1
var _pot_items: Array[Node3D] = []
var _pot_center := Vector2.ZERO
var _pot_alert: Node3D
var _pot_steam: Node3D
var _pot_bubbles: Node3D
var _pot_smoke: CPUParticles3D
var _smoke_quad: QuadMesh
var _burnt_mat: StandardMaterial3D


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
	stew_recipe = Recipe.load_stew()
	clock = ShiftClock.new()
	tickets = TicketQueue.new()
	tickets.max_open = TicketQueue.RAIL_SLOTS
	tickets.ticket_arrived.connect(_on_ticket_arrived)
	scorer = DishScorer.new(recipe)
	replies = ReplyPicker.new()
	recognizer = GestureRecognizer.new()
	stir = StirGesture.new()
	stack = PlateStack.new(recipe)
	pot = StewPot.new(stew_recipe)
	_moods.resize(SLOT_COUNT)
	_moods.fill(-1)
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
	for station in PAN_STATIONS:
		var pan := Pan.new()
		pan.station = station
		pan.area = _stations[station]
		pan.smoke = _make_smoke(pan.area)
		pan.alert = pan.area.get_node_or_null("Fx_Alert")
		pans.append(pan)
	_pot_area = _stations[POT_STATION]
	_pot_model = _pot_area.get_node("Model")
	_pot_scale = _pot_model.scale
	_pot_model_id = StewPot.POT_EMPTY
	_pot_alert = _pot_area.get_node_or_null("Fx_Alert")
	_pot_steam = _pot_area.get_node_or_null("Fx_Steam")
	_pot_bubbles = _pot_area.get_node_or_null("Fx_Bubbles")
	_pot_smoke = _make_smoke(_pot_area)
	_burnt_mat = StandardMaterial3D.new()
	_burnt_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_burnt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_burnt_mat.albedo_color = POT_BURNT_COLOR
	_hand_hour = _kitchen.get_node_or_null("Set/WallClock/HandHour")
	_hand_minute = _kitchen.get_node_or_null("Set/WallClock/HandMinute")
	_update_wall_clock()
	_make_plate()
	_update_pot_visuals()
	_update_hint()


func _process(delta: float) -> void:
	if auto_process and not app_paused:
		advance(delta)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			set_paused(true)
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			set_paused(false)


## Pausa/retoma a cozinha inteira; emite `pause_changed` só quando muda.
func set_paused(paused: bool) -> void:
	if paused == app_paused:
		return
	app_paused = paused
	pause_changed.emit(paused)


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT:
		if app_paused:
			# Desktop: o próximo clique/toque só retoma (não vira gesto).
			if mb.pressed:
				set_paused(false)
			return
		if mb.pressed:
			pointer_down(_to_norm(mb.position), Time.get_ticks_msec())
		else:
			pointer_up(_to_norm(mb.position), Time.get_ticks_msec())
		return
	var mm := event as InputEventMouseMotion
	if mm and not app_paused and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT):
		pointer_move(_to_norm(mm.position), Time.get_ticks_msec())


# --- Contrato com a UI --------------------------------------------------------

## Inicia o turno: o relógio começa a correr (1º bilhete aos 3 s).
func start() -> void:
	if started:
		return
	started = true
	shift_phase_changed.emit(clock.phase())
	_update_hint()


func get_slot_screen_position(slot: int) -> Vector2:
	var rail: Node3D = _stations["TicketRail"]
	var m := rail.get_node_or_null("Slot%d" % (clampi(slot, 0, SLOT_COUNT - 1) + 1)) as Node3D
	return _camera.unproject_position(m.global_position if m else rail.global_position)


## Cria já um bilhete com estes itens (ids de receita). O relógio usa isto a cada
## chegada; os testes também. Retorna null se o trilho está cheio.
func spawn_order(recipes: Array) -> TicketData:
	return tickets.spawn_order(recipes, clock.time)


# --- Tempo -------------------------------------------------------------------

func advance(delta: float) -> void:
	_fx_time += delta
	if frozen:
		_tick_timers(delta)
		if _end_timer >= 0.0:
			_end_timer -= delta
			if _end_timer < 0.0:
				shift_ended.emit(ShiftScorer.summarize(shift_tickets, clock.held_arrivals))
		return
	if started:
		var ev := clock.tick(delta, tickets.open_count())
		for i in clock.arrivals_this_tick:
			spawn_order(clock.roll_order())
		_update_wall_clock()
		if ev & ShiftClock.Event.PHASE_CHANGED:
			shift_phase_changed.emit(clock.phase())
		_update_moods()
		if ev & ShiftClock.Event.ENDED:
			_end_shift()
			return
	for pan in pans:
		if pan.patty != null:
			pan.patty.tick(delta)
			_update_pan_visuals(pan)
	pot.tick(delta)
	_update_pot_visuals()
	_pulse_alerts()
	_tick_timers(delta)
	_update_hint()


func _tick_timers(delta: float) -> void:
	if _return_timer >= 0.0:
		_return_timer -= delta
		if _return_timer < 0.0:
			_show_returned_plate()
	if _new_plate_timer >= 0.0:
		_new_plate_timer -= delta
		if _new_plate_timer < 0.0:
			_make_plate()
	if _nobody_timer >= 0.0:
		_nobody_timer -= delta


func _update_moods() -> void:
	for i in SLOT_COUNT:
		var tk := slots[i]
		if tk == null:
			continue
		var m := ShiftScorer.ticket_mood(tk, clock.time)
		if m != _moods[i]:
			_moods[i] = m
			ticket_mood_changed.emit(i, m)


func _update_wall_clock() -> void:
	var wc := clock.wall_clock()
	var minutes := wc.x * 60 + wc.y
	if minutes == _wall_minute:
		return
	_wall_minute = minutes
	if _hand_minute != null:
		_hand_minute.rotation.z = -TAU * wc.y / 60.0
	if _hand_hour != null:
		_hand_hour.rotation.z = -TAU * (wc.x % 12 + wc.y / 60.0) / 12.0


## 180 s: congela, some o que está em preparo e agenda o resumo.
func _end_shift() -> void:
	frozen = true
	if _carry != null:
		if is_instance_valid(_carry.node):
			_carry.node.queue_free()
		_carry = null
	stir.active = false
	if _board_node != null:
		_board_node.queue_free()
		_board_node = null
	board = null
	for pan in pans:
		if pan.node != null:
			pan.node.queue_free()
		pan.node = null
		pan.patty = null
		_set_smoke(pan.smoke, Patty.Stage.RAW)
		pan.smoke_stage = -1
		if pan.alert != null:
			pan.alert.visible = false
	pot.clear()
	_clear_pot_items()
	_update_pot_visuals()
	if _bun_top_node != null:
		_bun_top_node.queue_free()
		_bun_top_node = null
	if plate_root != null:
		plate_root.queue_free()
		plate_root = null
	_new_plate_timer = -1.0
	_make_plate()
	_end_timer = ShiftClock.END_SCREEN_DELAY_S
	_update_hint()


# --- Entrada (p = 0–1 da viewport, y para baixo; t em ms) ---------------------

func pointer_down(p: Vector2, t_ms: int) -> void:
	if frozen or recognizer.active or _carry != null:
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
		POT_STATION:
			if pot.portions > 0:
				_pot_center = world_to_norm(snap_position(POT_STATION))
				stir.aspect = recognizer.aspect
				stir.begin(_pot_center, p, t_ms)
		_:
			var pan := _pan_at(_press_station)
			if pan != null and pan.patty != null:
				mode = GestureRecognizer.Mode.PAN
	recognizer.begin(mode, p, t_ms)
	_update_hint()


func pointer_move(p: Vector2, t_ms: int) -> void:
	if not recognizer.active:
		return
	_handle_events(recognizer.add_sample(p, t_ms))
	if stir.active:
		if stir.add_sample(p, t_ms):
			_on_stir_turn()
		# Servir: sair do raio da panela sem nenhuma volta feita, qualquer que seja o
		# ângulo (quem toca o lado oposto à janela passa pelo centro e gira ~180°).
		if _carry == null and stir.turns == 0 and pot.portions > 0 \
				and GestureRecognizer.distance_u(p, _pot_center, recognizer.aspect) > POT_LEAVE_U:
			stir.active = false
			_start_bowl_carry()
	if _carry != null:
		_follow(p)
	_update_hint()


func pointer_up(p: Vector2, t_ms: int) -> void:
	if not recognizer.active:
		return
	recognizer.finish(p, t_ms)
	_handle_events(recognizer.last_events)
	if stir.active and stir.finish(p, t_ms):
		_on_stir_turn()
	stir.active = false
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


## Id do modelo da panela agora (`pot_A`/`pot_A_stew`).
func pot_model_id() -> String:
	return _pot_model_id


## Picados visíveis na panela montando.
func pot_item_count() -> int:
	return _pot_items.size()


# --- Eventos do gesto ----------------------------------------------------------

func _handle_events(ev: int) -> void:
	if ev & GestureRecognizer.Event.CUT and board != null:
		if board.add_cut(recognizer.last_stroke_ms, recognizer.last_stroke_bands):
			_refresh_board_model()
		_bump(_board_node)
	if ev & GestureRecognizer.Event.SESSION_ENDED and board != null:
		board.end_session()
		board.begin_session()
	var pan := _pan_at(_press_station)
	if ev & GestureRecognizer.Event.FLIP and pan != null and pan.patty != null:
		var q := pan.patty.flip()
		_flip_anim(pan)
		_feedback(q, pan.node)
	if ev & GestureRecognizer.Event.SHAKE and pan != null:
		_shake(pan.area.get_node_or_null("Model"))
	# Na panela, o arrasto só vira tigela ao sair dela (pointer_move).
	if ev & GestureRecognizer.Event.DRAG_STARTED and _press_station != POT_STATION:
		_start_carry()


func _on_stir_turn() -> void:
	var was_burnt := pot.is_burnt()
	if not pot.stir(stir.last_quality):
		return
	_update_pot_visuals()
	if was_burnt:
		_bump(_pot_model, _pot_scale)
	else:
		_feedback(stir.last_quality, _pot_model)


func _start_carry() -> void:
	var c := Carry.new()
	c.origin = _press_station
	var pan := _pan_at(_press_station)
	if _press_station.begins_with("Crate_"):
		c.crate_key = _press_station.substr(6)
		c.id = _crate_item(c.crate_key)
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
	elif pan != null:
		if pan.patty == null:
			return
		var q := pan.patty.remove()
		c.patty = pan.patty
		c.id = pan.patty.model_id()
		c.notes = pan.patty.notes()
		c.crate_key = "burger"
		c.node = pan.node
		c.node.reparent(self)
		pan.patty = null
		pan.node = null
		_set_smoke(pan.smoke, Patty.Stage.RAW)
		pan.smoke_stage = -1
		if pan.alert != null:
			pan.alert.visible = false
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


func _start_bowl_carry() -> void:
	var c := Carry.new()
	c.origin = POT_STATION
	c.is_bowl = true
	c.id = StewPot.STEW
	c.node = _spawn(StewPot.STEW, self)
	c.node.global_position = snap_position(POT_STATION)
	_carry = c


func _drop(p: Vector2) -> void:
	var c := _carry
	_carry = null
	var target := station_at(p)
	if c.is_plate or c.is_bowl:
		if target == "OrderWindow":
			if _deliver(c):
				return
			_nobody_timer = NOBODY_HINT_S
		_return(c)
		return
	if c.crate_key != "" and target == "Crate_" + c.crate_key:
		c.node.queue_free()
		return
	match target:
		"CuttingBoard":
			var r := _chop_recipe(c.id)
			if board == null and c.chop == null and r != null:
				board = ChopTarget.from_recipe(r, c.id)
				_place_on_board(c.node)
				return
		"Stove_Pan", "Stove_Pan2":
			var pan := _pan_at(target)
			if pan.patty == null and (c.patty != null or c.id == Kitchen.BURGER_UNCOOKED):
				_place_in_pan(pan, c.patty if c.patty != null else Patty.new(), c.node)
				return
		POT_STATION:
			if pot.add(c.id, c.notes):
				_place_in_pot(c.node)
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
	elif _pan_at(c.origin) != null:
		_place_in_pan(_pan_at(c.origin), c.patty, c.node)
	else:
		# Veio de um caixote (ou é a tigela): volta e some.
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


func _place_in_pan(pan: Pan, p: Patty, node: Node3D) -> void:
	pan.patty = p
	p.place_in_pan()
	pan.node = node
	pan.model_id = p.model_id()
	_reparent_tween(node, pan.area, _local_snap(pan.station))
	pan.smoke_stage = -1
	_update_pan_visuals(pan)


func _update_pan_visuals(pan: Pan) -> void:
	var id := pan.patty.model_id()
	if id != pan.model_id and pan.node != null:
		pan.model_id = id
		var xf := pan.node.transform
		pan.node.queue_free()
		pan.node = _spawn(id, pan.area)
		pan.node.transform = xf
	var stage := Patty.Stage.BURNT if pan.patty.is_burnt() else pan.patty.down_stage()
	if stage != pan.smoke_stage:
		pan.smoke_stage = stage
		_set_smoke(pan.smoke, stage)
		# Aro de alerta a partir de 10 s no lado (m2_turno §4.1).
		if pan.alert != null:
			pan.alert.visible = stage >= Patty.Stage.SMOKE


## Picado solto na panela (já aceito por `pot.add`). Com o 3º, vira ensopado.
func _place_in_pot(node: Node3D) -> void:
	if pot.is_cooking():
		node.queue_free()
		_clear_pot_items()
	else:
		var off: Vector3 = POT_ITEM_OFFSETS[mini(_pot_items.size(), POT_ITEM_OFFSETS.size() - 1)]
		_pot_items.append(node)
		node.rotation = Vector3.ZERO
		node.scale = Vector3.ONE * POT_ITEM_SCALE
		_reparent_tween(node, _pot_area, _local_snap(POT_STATION) + off)
	_update_pot_visuals()


func _clear_pot_items() -> void:
	for n in _pot_items:
		if is_instance_valid(n):
			n.queue_free()
	_pot_items.clear()


## Modelo e efeitos da panela; só mexe nos nós quando o estágio ou o modelo mudam.
func _update_pot_visuals() -> void:
	var id := pot.model_id()
	var st := pot.stage()
	if id == _pot_model_id and st == _pot_stage:
		return
	if id != _pot_model_id:
		_pot_model_id = id
		var xf := _pot_model.transform
		_pot_model.queue_free()
		_pot_model = _spawn(id, _pot_area)
		_pot_model.transform = xf
	_pot_stage = st
	var cooking := st == StewPot.Stage.COOKING or st == StewPot.Stage.READY or st == StewPot.Stage.STICKING
	if _pot_steam != null:
		_pot_steam.visible = cooking
	if _pot_bubbles != null:
		_pot_bubbles.visible = st >= StewPot.Stage.STICKING
	if _pot_alert != null:
		_pot_alert.visible = st >= StewPot.Stage.STICKING
	if st == StewPot.Stage.BURNT:
		_set_smoke(_pot_smoke, Patty.Stage.BURNT)
	elif st == StewPot.Stage.SCORCHING:
		_set_smoke(_pot_smoke, Patty.Stage.SMOKE)
	else:
		_set_smoke(_pot_smoke, Patty.Stage.RAW)
	var overlay: Material = _burnt_mat if st == StewPot.Stage.BURNT else null
	for m: MeshInstance3D in _pot_model.find_children("*", "MeshInstance3D", true, false):
		m.material_overlay = overlay


func _pulse_alerts() -> void:
	var s := Vector3.ONE * (1.0 + ALERT_PULSE * sin(_fx_time * TAU * ALERT_HZ))
	for pan in pans:
		if pan.alert != null and pan.alert.visible:
			pan.alert.scale = s
	if _pot_alert != null and _pot_alert.visible:
		_pot_alert.scale = s


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


## Entrega o prato/tigela ao bilhete mais antigo que espera a receita (m2_turno §5).
## Retorna false se ninguém espera (o chamador devolve à origem).
func _deliver(c: Carry) -> bool:
	var rid := StewPot.STEW if c.is_bowl else recipe.id
	var tk := tickets.oldest_waiting(rid)
	if tk == null:
		return false
	var idx := tk.pending_index(rid)
	var res: Dictionary
	if c.is_bowl:
		res = pot.serve()
		if res.is_empty():
			return false
	else:
		res = scorer.score(tk.items[idx]["without"], stack.take_all())
	tickets.deliver(rid, res["score"], res["dominant"], clock.time)
	var slot := slots.find(tk)
	var closed := tk.is_complete()
	var band: int = res["band"]
	if closed:
		band = DishScorer.band_of(tk.score())
		tk.reply = replies.pick_ticket(tk, ShiftScorer.ticket_agility(tk, clock.time))
	ticket_item_delivered.emit(slot, tk, idx)
	if closed:
		if slot >= 0:
			slots[slot] = null
			_moods[slot] = -1
		# Faixa de bilhete da UI: 0 = <50, 1 = 50–79, 2 = ≥80 (DishScorer.Band é o inverso).
		ticket_served.emit(slot, tk, tk.score(), 2 - band, tk.reply)
	if c.is_plate:
		if _bun_top_node != null:
			_bun_top_node.queue_free()
			_bun_top_node = null
		_stack_height = 0.0
		_new_plate_timer = NEW_PLATE_S
	else:
		_update_pot_visuals()
	_send_out(c.node, rid, band)
	return true


## Prato/tigela sai pela janela e volta após PLATE_RETURN_S conforme a faixa.
func _send_out(node: Node3D, recipe_id: String, band: int) -> void:
	_clear_returned()
	if _served_node != null:
		_served_node.queue_free()
	_served_node = node
	_served_band = band
	_served_recipe = recipe_id
	var tw := node.create_tween()
	tw.tween_property(node, "global_position", snap_position("OrderWindow"), RETURN_S)
	tw.tween_callback(node.hide)
	_return_timer = PLATE_RETURN_S


func _show_returned_plate() -> void:
	_clear_returned()
	if _served_node == null:
		return
	var model := DishScorer.return_model_for(_served_recipe, _served_band)
	if model == "":
		returned_plate = _served_node
		returned_plate.show()
	else:
		_served_node.queue_free()
		returned_plate = _spawn(model, self)
		if _served_recipe != StewPot.STEW:
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
	shift_tickets.append(ticket)
	var slot := slots.find(null)
	if slot < 0:
		return
	slots[slot] = ticket
	_moods[slot] = ShiftScorer.Mood.CONTENT
	ticket_added.emit(slot, ticket)
	_update_hint()


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


func _flip_anim(pan: Pan) -> void:
	if pan.node == null:
		return
	var base := _local_snap(pan.station)
	pan.node.position = base
	var tw := pan.node.create_tween()
	tw.tween_property(pan.node, "position:y", base.y + 0.6, 0.15).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(pan.node, "rotation:z", pan.node.rotation.z + PI, 0.3)
	tw.tween_property(pan.node, "position:y", base.y, 0.15).set_ease(Tween.EASE_IN)


func _bump(node: Node3D, base: Vector3 = Vector3.ONE) -> void:
	if node == null:
		return
	node.scale = base * Vector3(1.08, 0.85, 1.08)
	node.create_tween().tween_property(node, "scale", base, 0.12)


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
	# A panela queimada mantém o escurecido.
	if _pot_stage == StewPot.Stage.BURNT and is_instance_valid(_pot_model):
		for m: MeshInstance3D in _pot_model.find_children("*", "MeshInstance3D", true, false):
			if m.material_overlay == null:
				m.material_overlay = _burnt_mat


func _make_smoke(area: Node3D) -> CPUParticles3D:
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.amount = 10
	smoke.lifetime = 1.4
	smoke.emitting = false
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.2
	smoke.direction = Vector3.UP
	smoke.spread = 15.0
	smoke.gravity = Vector3(0, 0.4, 0)
	smoke.initial_velocity_min = 0.4
	smoke.initial_velocity_max = 0.8
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	smoke.color_ramp = ramp
	smoke.mesh = _smoke_mesh()
	area.add_child(smoke)
	smoke.position = (area.get_node("Snap") as Node3D).position + Vector3(0, 0.25, 0)
	return smoke


## Quad de partícula com textura redonda e suave (gradiente radial), compartilhado.
func _smoke_mesh() -> QuadMesh:
	if _smoke_quad != null:
		return _smoke_quad
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 0.8))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = SMOKE_TEX_PX
	tex.height = SMOKE_TEX_PX
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_smoke_quad = QuadMesh.new()
	_smoke_quad.size = Vector2(0.4, 0.4)
	_smoke_quad.material = mat
	return _smoke_quad


func _set_smoke(smoke: CPUParticles3D, stage: int) -> void:
	var c: Color = SMOKE_COLORS[stage]
	smoke.color = c
	smoke.emitting = c.a > 0.0


# --- Auxiliares ------------------------------------------------------------------

func _viewport_size() -> Vector2:
	var s := get_viewport().get_visible_rect().size
	return s if s.x > 0.0 and s.y > 0.0 else Vector2(1280, 720)


func _to_norm(px: Vector2) -> Vector2:
	return px / _viewport_size()


func _local_snap(station: String) -> Vector3:
	return (_stations[station].get_node("Snap") as Node3D).position


func _pan_at(station: String) -> Pan:
	for pan in pans:
		if pan.station == station:
			return pan
	return null


func _free_pan_station() -> String:
	for pan in pans:
		if pan.patty == null:
			return pan.station
	return ""


func _closer_to_bun_top(p: Vector2) -> bool:
	var a := recognizer.aspect
	var d_top := GestureRecognizer.distance_u(p, world_to_norm(bun_top_rest_position()), a)
	var d_plate := GestureRecognizer.distance_u(p, world_to_norm(snap_position("Plate_Assembly")), a)
	return d_top < d_plate


## Receita que sabe picar este id cru (null = não se pica).
func _chop_recipe(item_id: String) -> Recipe:
	if recipe.chop.has(item_id):
		return recipe
	if stew_recipe.chop.has(item_id):
		return stew_recipe
	return null


func _crate_item(crate_key: String) -> String:
	var id := recipe.crate_item(crate_key)
	return id if id != "" else stew_recipe.crate_item(crate_key)


func _crate_of(item_id: String) -> String:
	for r: Recipe in [recipe, stew_recipe]:
		for key: String in r.crates:
			if r.crates[key] == item_id:
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
	if frozen:
		pass
	elif _nobody_timer >= 0.0:
		station = "OrderWindow"
		text = HINT_NOBODY
	elif _carry != null:
		station = _carry_target(_carry)
		match station:
			"CuttingBoard": text = HINT_DROP_BOARD
			"Stove_Pan", "Stove_Pan2": text = HINT_DROP_PAN
			POT_STATION: text = HINT_DROP_POT
			"Plate_Assembly": text = HINT_DROP_PLATE
			"OrderWindow": text = HINT_SERVE_BOWL if _carry.is_bowl else HINT_SERVE
	else:
		var pst := pot.stage()
		var burnt_pan := ""
		var done_pan := ""
		var flip_pan := ""
		for pan in pans:
			if pan.patty == null:
				continue
			if pan.patty.is_burnt():
				if burnt_pan == "":
					burnt_pan = pan.station
			elif _side_ok(pan.patty, Patty.Side.A) and _side_ok(pan.patty, Patty.Side.B):
				if done_pan == "":
					done_pan = pan.station
			elif flip_pan == "":
				flip_pan = pan.station
		if burnt_pan != "":
			station = burnt_pan
			text = HINT_BURNT
		elif pst == StewPot.Stage.BURNT:
			station = POT_STATION
			text = HINT_SCRAPE
		elif pst >= StewPot.Stage.STICKING:
			station = POT_STATION
			text = HINT_STIR
		elif done_pan != "":
			station = done_pan
			text = HINT_PATTY_DONE
		elif pot.is_cooking() and pot.stick >= POT_STIR_HINT_G:
			station = POT_STATION
			text = HINT_STIR
		elif pst == StewPot.Stage.READY:
			station = POT_STATION
			text = HINT_SERVE_BOWL
		elif flip_pan != "":
			station = flip_pan
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
	if c.is_plate or c.is_bowl:
		return "OrderWindow"
	if c.chop == null and c.patty == null and _chop_recipe(c.id) != null:
		return "CuttingBoard"
	if c.patty == null and c.id == Kitchen.BURGER_UNCOOKED:
		return _free_pan_station()
	if pot.can_accept(c.id):
		return POT_STATION
	if plate_root != null and stack.can_accept(c.id):
		return "Plate_Assembly"
	return ""


func _hint_anchor(station: String) -> Vector3:
	if station == "Crates":
		return _crates_center
	if station == "OrderWindow":
		return snap_position(station) + Vector3(0, 0.6, 0)
	return snap_position(station)


func _side_ok(p: Patty, side: int) -> bool:
	return Patty.quality_for_time(p.side_time(side)) != Kitchen.Quality.CLUMSY
