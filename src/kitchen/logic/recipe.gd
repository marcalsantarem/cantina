class_name Recipe
extends RefCounted
## Receita lida de `data/recipes/<id>.json` (camadas de baixo para cima, apelidos, picar, caixotes).

const BURGER_PATH := "res://data/recipes/food_burger.json"
const RECIPE_PATH := "res://data/recipes/%s.json"

var id: String = ""
var icon: String = ""
## Ids das camadas, de baixo para cima.
var layers: Array[String] = []
## Id de estado alternativo -> id da camada que ele ocupa (ex.: carne queimada -> carne).
var aliases: Dictionary = {}
var patty: String = ""
var optional: Array[String] = []
## Id cru -> {result, carry} (pica sozinho na tábua, decisão 22).
var chop: Dictionary = {}
## Chave curta do caixote -> id do ingrediente.
var crates: Dictionary = {}


static func from_dict(d: Dictionary) -> Recipe:
	var r := Recipe.new()
	r.id = d.get("id", "")
	r.icon = d.get("icon", r.id)
	r.layers.assign(d.get("layers", []))
	r.aliases = d.get("aliases", {})
	r.patty = d.get("patty", "")
	r.optional.assign(d.get("optional", []))
	r.chop = d.get("chop", {})
	r.crates = d.get("crates", {})
	return r


static func load_burger() -> Recipe:
	return from_dict(Kitchen.load_json(BURGER_PATH))


## Carrega `data/recipes/<recipe_id>.json`.
static func load_id(recipe_id: String) -> Recipe:
	return from_dict(Kitchen.load_json(RECIPE_PATH % recipe_id))


static func load_stew() -> Recipe:
	return load_id("food_stew")


## Camada que o id ocupa na receita, ou "" se não é item de receita.
func layer_of(item_id: String) -> String:
	if layers.has(item_id):
		return item_id
	return aliases.get(item_id, "")


## Camadas pedidas, na ordem, sem as do `without`.
func requested_layers(without: Array) -> Array[String]:
	var out: Array[String] = []
	for layer in layers:
		if not without.has(layer):
			out.append(layer)
	return out


func crate_item(crate_key: String) -> String:
	return crates.get(crate_key, "")
