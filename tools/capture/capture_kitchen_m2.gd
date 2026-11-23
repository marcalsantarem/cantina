# Captura da cozinha do M2 em docs/capturas/cozinha_m2*.png.
# Liga temporariamente os nos Fx_* (so na captura "_fx") para conferir os efeitos.
# Uso (COM janela, nao headless):
#   godot --path . -s res://tools/capture/capture_kitchen_m2.gd
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
	for fx: bool in [false, true]:
		for size: Vector2i in SIZES:
			if fx and size != SIZES[0]:
				continue
			var vp := SubViewport.new()
			vp.size = size
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			vp.own_world_3d = true
			vp.msaa_3d = Viewport.MSAA_4X
			root.add_child(vp)
			var kitchen := packed.instantiate()
			vp.add_child(kitchen)
			if fx:
				for n: Node in kitchen.find_children("Fx_*", "", true, false):
					(n as Node3D).visible = true
			for i in 60 if fx else 8:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			var path := OUT_DIR + "cozinha_m2%s_%dx%d.png" % ["_fx" if fx else "", size.x, size.y]
			img.save_png(ProjectSettings.globalize_path(path))
			print("salvo: ", path)
			vp.queue_free()
			await process_frame
	quit(0)
