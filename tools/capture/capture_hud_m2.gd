# Captura da HUD do M2 (BRF-016) em docs/capturas/hud_m2_<cena>_<L>x<A>.png:
# bilhetes (2 itens, "sem X" por item, entrega, humor e dica na panela), placa, pausa e fim de turno.
# A escala dos bilhetes segue a regra do HUD (px de CSS, DPR 1): em 844x390 os bilhetes ampliam.
# Cozinha real (kitchen.tscn) ao fundo + controlador falso com as vagas projetadas da cena.
# Uso (COM janela, nao headless):
#   godot --path . -s res://tools/capture/capture_hud_m2.gd
extends SceneTree

const KITCHEN := "res://scenes/kitchen/kitchen.tscn"
const HUD := "res://scenes/ui/hud.tscn"
const Fake := preload("res://tests/fakes/fake_kitchen_controller.gd")
const OUT_DIR := "res://docs/capturas/"
## Tamanho da tela -> tamanho logico (stretch canvas_items + expand com base 1280x720).
const SIZES := [Vector2i(1280, 720), Vector2i(844, 390)]
const SHOTS := ["bilhetes", "placa", "pausa", "fim"]
const Hud := preload("res://src/ui/hud.gd")


func _initialize() -> void:
	_run.call_deferred()


func _logical(size: Vector2i) -> Vector2:
	var k := 720.0 / size.y
	return Vector2(size) * k


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for size: Vector2i in SIZES:
		for shot: String in SHOTS:
			await _capture(size, shot)
	quit(0)


func _capture(size: Vector2i, shot: String) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.size_2d_override = Vector2i(_logical(size))
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	var kitchen: Node3D = load(KITCHEN).instantiate()
	vp.add_child(kitchen)
	var fake := Fake.new()
	vp.add_child(fake)
	await process_frame
	var cam: Camera3D = kitchen.get_node("MainCamera")
	# com size_2d_override, unproject_position já devolve coordenadas lógicas.
	var to_logical := Vector2.ONE
	var slots: Array[Vector2] = []
	for i in 4:
		var m := kitchen.get_node("Stations/TicketRail/Slot%d" % (i + 1)) as Node3D
		slots.append(cam.unproject_position(m.global_position) * to_logical)
	fake.slot_positions = slots
	var hud: CanvasLayer = load(HUD).instantiate()
	vp.add_child(hud)
	var s := Hud.screen_scale_for(size.y, _logical(size).y)
	hud.set_ui_scale(minf(Hud.ticket_scale_for(s, 15.0, hud.min_phrase_px, hud.max_ui_scale),
			maxf(Hud.fit_scale_for(_logical(size).x), 1.0)))
	hud.bind(fake)

	var combo := Fake.make_multi_ticket(1, "Seu Jorge", "Um de cada, chef! Tô com pressa.", ["food_burger", "food_stew"] as Array[String])
	var burger := Fake.make_ticket(2, "Dona Cida", "Sem tomate, por favor, é sério.", ["food_ingredient_tomato_slice"] as Array[String])
	burger.add_item("food_burger", ["food_ingredient_tomato_slice"])
	var stew := Fake.make_multi_ticket(3, "Lia", "Um ensopadinho quente.", ["food_stew"] as Array[String])
	var two := Fake.make_ticket(4, "Lu do Skate", "Dois, um pra mim e um pro meu eu do futuro.")
	two.add_item("food_burger")
	two.add_item("food_burger", ["food_ingredient_tomato_slice"])
	# Dona Cida (vaga 2) chegou primeiro: o "próximo" fica perto da panela e o balão precisa desviar.
	for pair in [[1, burger], [0, combo], [2, stew], [3, two]]:
		fake.ticket_added.emit(pair[0], pair[1])
	await create_timer(0.7).timeout
	fake.ticket_item_delivered.emit(0, combo, 1)
	fake.ticket_mood_changed.emit(0, 2)  # faminto
	fake.ticket_mood_changed.emit(1, 1)  # impaciente
	fake.ticket_item_delivered.emit(3, two, 0)
	var pot := kitchen.get_node("Stations/Stove_Pot") as Node3D
	fake.action_hint.emit("Mexa em círculos", cam.unproject_position(pot.global_position + Vector3(0, 0.4, 0)) * to_logical)
	await create_timer(0.4).timeout
	if shot == "placa":
		fake.shift_phase_changed.emit(1)
		await create_timer(0.6).timeout
	elif shot == "pausa":
		fake.pause_changed.emit(true)
	elif shot == "fim":
		fake.shift_ended.emit({"score": 70.0, "stars": 2, "quality": 75.0, "service": 70.0, "agility": 60.0,
				"served": 7, "arrived": 9, "items_delivered": 8, "items_total": 12, "avg_score": 75,
				"agility_word": "No ritmo", "best_reply": "Chef, isso foi poesia com queijo."})
		await create_timer(0.5).timeout
		hud.get_end_screen().finish_animation()
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var path := OUT_DIR + "hud_m2_%s_%dx%d.png" % [shot, size.x, size.y]
	img.save_png(ProjectSettings.globalize_path(path))
	print("salvo: ", path)
	vp.queue_free()
	await process_frame
