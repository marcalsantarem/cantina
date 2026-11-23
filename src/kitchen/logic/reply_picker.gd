class_name ReplyPicker
extends RefCounted
## Frase do bilhete-resposta (design §4): sorteia da faixa e, se houver gancho para o
## erro dominante, acrescenta-o ("<frase da faixa> <gancho>"). Evita repetir a última.
## M2 (m2_turno §3, §5): `pick_ticket` usa a nota do bilhete, o gancho do pior item ou
## o de demora; frases de faixa por receita em `recipe_bands` (cai em `bands`).

const REPLIES_PATH := "res://data/kitchen/replies.json"
const BAND_KEYS: Array[String] = ["great", "ok", "poor"]
const HOOK_LATE := "late"

var rng: RandomNumberGenerator
var bands: Dictionary = {}
var hooks: Dictionary = {}
var recipe_bands: Dictionary = {}
var _last: Dictionary = {}


func _init(random: RandomNumberGenerator = null, data: Dictionary = {}) -> void:
	rng = random if random != null else RandomNumberGenerator.new()
	var d := data if not data.is_empty() else Kitchen.load_json(REPLIES_PATH)
	bands = d.get("bands", {})
	hooks = d.get("hooks", {})
	recipe_bands = d.get("recipe_bands", {})


## `band` = DishScorer.Band; `dominant` = chave de erro ("" = sem gancho).
## `recipe` = id da receita para frases próprias da faixa ("" = genéricas).
func pick(band: int, dominant: String = "", recipe: String = "") -> String:
	var key: String = BAND_KEYS[band]
	var pool: Array = recipe_bands.get(recipe, {}).get(key, []) if recipe != "" else []
	var text := ""
	if pool.is_empty():
		text = _draw("band:" + key, bands.get(key, []))
	else:
		text = _draw("band:" + recipe + ":" + key, pool)
	if dominant != "" and hooks.has(dominant):
		var hook := _draw("hook:" + dominant, hooks[dominant])
		if hook != "":
			text = hook if text == "" else text + " " + hook
	return text


## Gancho do bilhete: o do pior item; com agilidade < 0,7 o de demora substitui
## quando a nota ≥ 80 (ou quando o pior item não tem erro).
static func ticket_hook(ticket: TicketData, agility: float) -> String:
	var dominant := ""
	var w := ticket.worst_index()
	if w >= 0:
		dominant = ticket.items[w].get("dominant", "")
	if agility < ShiftScorer.LATE_AGILITY and (ticket.score() >= DishScorer.GREAT_MIN or dominant == ""):
		return HOOK_LATE
	return dominant


## Frase do bilhete-resposta de um bilhete completo (M2). `agility` = ShiftScorer.ticket_agility.
func pick_ticket(ticket: TicketData, agility: float) -> String:
	var recipe := ""
	for it in ticket.items:
		if recipe == "":
			recipe = it["recipe"]
		elif recipe != it["recipe"]:
			recipe = ""
			break
	return pick(DishScorer.band_of(ticket.score()), ticket_hook(ticket, agility), recipe)


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
