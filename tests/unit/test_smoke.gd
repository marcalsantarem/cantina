extends GutTest
## Smoke: projeto configurado (versão, cena principal, paisagem).


func test_version_is_0_1_0() -> void:
	assert_eq(ProjectSettings.get_setting("application/config/version"), "0.1.0")


func test_main_scene_loads() -> void:
	var path: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_eq(path, "res://scenes/main.tscn")
	var scene := load(path) as PackedScene
	assert_not_null(scene)
	var main := scene.instantiate()
	assert_not_null(main.get_node_or_null("Camera3D"))
	assert_not_null(main.get_node_or_null("Label"))
	main.free()


func test_landscape_orientation() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 0)
