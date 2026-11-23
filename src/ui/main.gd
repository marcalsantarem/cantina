extends Node3D
## Cena principal: tela inicial; ao tocar, instancia a cozinha (game.tscn) + HUD.
## "Jogar de novo" (fim do turno) troca jogo e HUD por novos, sem voltar à tela inicial.

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
	if not _start_game():
		return
	$Camera3D.queue_free()
	$Label.queue_free()
	var tw := _start.create_tween()
	tw.tween_property(_start, "modulate:a", 0.0, 0.35)
	tw.tween_callback(_start.queue_free)


## Recomeça o turno: jogo e HUD novos.
func restart() -> void:
	if hud:
		hud.unbind()
	for old: Node in [game, hud]:
		if is_instance_valid(old):
			remove_child(old)
			old.queue_free()
	game = null
	hud = null
	_start_game()


func _start_game() -> bool:
	var packed := game_scene
	if packed == null and ResourceLoader.exists(GAME_SCENE):
		packed = load(GAME_SCENE)
	if packed == null:
		push_error("cena do jogo não encontrada: " + GAME_SCENE)
		return false
	game = packed.instantiate()
	hud = HudScene.instantiate()
	add_child(game)
	add_child(hud)
	hud.bind(game)
	hud.replay_requested.connect(restart, CONNECT_DEFERRED)
	game.start()
	return true
