extends Node3D
## Cena principal: tela inicial; ao tocar, instancia a cozinha (game.tscn) + HUD.

const GAME_SCENE := "res://scenes/game/game.tscn"
const HudScene := preload("res://scenes/ui/hud.tscn")

## Sobrescreve a cena do jogo (testes). Vazio = GAME_SCENE.
var game_scene: PackedScene
var game: Node
var hud: CanvasLayer

@onready var _start: Control = $StartScreen


func _ready() -> void:
	_start.started.connect(_on_started)


func _on_started() -> void:
	var packed := game_scene
	if packed == null and ResourceLoader.exists(GAME_SCENE):
		packed = load(GAME_SCENE)
	if packed == null:
		push_error("cena do jogo não encontrada: " + GAME_SCENE)
		return
	game = packed.instantiate()
	hud = HudScene.instantiate()
	add_child(game)
	add_child(hud)
	hud.bind(game)
	$Camera3D.queue_free()
	$Label.queue_free()
	var tw := _start.create_tween()
	tw.tween_property(_start, "modulate:a", 0.0, 0.35)
	tw.tween_callback(_start.queue_free)
	game.start()
