# Abre a cena da cozinha e salva PNGs em docs/capturas/.
# Uso (COM janela, nao headless):
#   godot --path . -s res://tools/capture/capture_kitchen.gd
extends SceneTree

const SCENE := "res://scenes/kitchen/kitchen.tscn"
const OUT_DIR := "res://docs/capturas/"
const SIZES := [Vector2i(1280, 720), Vector2i(1688, 780), Vector2i(1024, 768)]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load(SCENE)
	if packed == null:
		push_error("cena nao encontrada: " + SCENE)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for size: Vector2i in SIZES:
		var vp := SubViewport.new()
		vp.size = size
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.own_world_3d = true
		vp.msaa_3d = Viewport.MSAA_4X
		root.add_child(vp)
		vp.add_child(packed.instantiate())
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var path := OUT_DIR + "kitchen_%dx%d.png" % [size.x, size.y]
		img.save_png(ProjectSettings.globalize_path(path))
		print("salvo: ", path)
		vp.queue_free()
		await process_frame
	quit(0)
