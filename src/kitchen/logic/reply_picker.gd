class_name ReplyPicker
extends RefCounted
## Frase do bilhete-resposta (design §4): sorteia da faixa e, se houver gancho para o
## erro dominante, acrescenta-o ("<frase da faixa> <gancho>"). Evita repetir a última.

const REPLIES_PATH := "res://data/kitchen/replies.json"
const BAND_KEYS: Array[String] = ["great", "ok", "poor"]

var rng: RandomNumberGenerator
var bands: Dictionary = {}
var hooks: Dictionary = {}
var _last: Dictionary = {}


func _init(random: RandomNumberGenerator = null, data: Dictionary = {}) -> void:
	rng = random if random != null else RandomNumberGenerator.new()
	var d := data if not data.is_empty() else Kitchen.load_json(REPLIES_PATH)
	bands = d.get("bands", {})
	hooks = d.get("hooks", {})


## `band` = DishScorer.Band; `dominant` = chave de erro ("" = sem gancho).
func pick(band: int, dominant: String = "") -> String:
	var text := _draw("band:" + BAND_KEYS[band], bands.get(BAND_KEYS[band], []))
	if dominant != "" and hooks.has(dominant):
		var hook := _draw("hook:" + dominant, hooks[dominant])
		if hook != "":
			text = hook if text == "" else text + " " + hook
	return text


func has_hook(dominant: String) -> bool:
	return hooks.has(dominant)


func _draw(key: String, pool: Array) -> String:
	if pool.is_empty():
		return ""
	var i := rng.randi_range(0, pool.size() - 1)
	if pool.size() > 1 and i == _last.get(key, -1):
		i = (i + 1) % pool.size()
	_last[key] = i
	return pool[i]
