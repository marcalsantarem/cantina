class_name Kitchen
extends RefCounted
## Tipos e constantes comuns da lógica da cozinha (M1). Sem estado.

## Qualidade do ponto (decisões 14 e 22).
enum Quality { CLUMSY, GOOD, PERFECT }

const QUALITY_LABELS: Array[String] = ["Ops", "Bom", "Perfeito!"]
const QUALITY_SCORES: Array[float] = [0.4, 0.7, 1.0]
## Nota de item ausente ou carne queimada.
const SCORE_NONE := 0.0

## Chave da nota do ponto em `quality: Dictionary` do item (carne; decisão 22).
const NOTE_COOK := "ponto"

const BUN := "food_ingredient_bun"
const BUN_BOTTOM := "food_ingredient_bun_bottom"
const BUN_TOP := "food_ingredient_bun_top"
const BURGER_UNCOOKED := "food_ingredient_burger_uncooked"
const BURGER_COOKED := "food_ingredient_burger_cooked"
const BURGER_TRASH := "food_ingredient_burger_trash"
const CHEESE_SLICE := "food_ingredient_cheese_slice"
const LETTUCE := "food_ingredient_lettuce"
const LETTUCE_SLICE := "food_ingredient_lettuce_slice"
const TOMATO := "food_ingredient_tomato"
const TOMATO_SLICES := "food_ingredient_tomato_slices"
const TOMATO_SLICE := "food_ingredient_tomato_slice"


static func quality_label(q: int) -> String:
	return QUALITY_LABELS[q]


static func quality_score(q: int) -> float:
	return QUALITY_SCORES[q]


## Lê um JSON de `res://data/`. Retorna {} se faltar ou for inválido.
static func load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Kitchen.load_json: arquivo vazio ou ausente: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("Kitchen.load_json: JSON inválido: %s" % path)
	return {}
