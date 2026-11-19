class_name ChopTarget
extends RefCounted
## Ingrediente na tábua (design §1 e §2.2). Acumula cortes entre sessões; a nota de
## corte usa ritmo (CV) e cobertura de todos os cortes válidos já feitos.

var raw_id: String = ""
var cuts_required: int = 0
## Acima deste nº de cortes o ingrediente passa do ponto (0 = sem limite).
var overcut_limit: int = 0
var result_id: String = ""
var overcut_id: String = ""
var carry_id: String = ""
var overcut_carry_id: String = ""

var cuts: int = 0
var sessions: int = 0
var in_session: bool = false
var coverage_mask: int = 0
var _dur_sum: float = 0.0
var _dur_sq: float = 0.0


## `config` = entrada de `Recipe.chop[raw_id]`.
func _init(ingredient_id: String = "", config: Dictionary = {}) -> void:
	raw_id = ingredient_id
	cuts_required = int(config.get("cuts", 0))
	overcut_limit = int(config.get("overcut", 0))
	result_id = config.get("result", "")
	overcut_id = config.get("overcut_result", "")
	carry_id = config.get("carry", "")
	overcut_carry_id = config.get("overcut_carry", "")


static func from_recipe(recipe: Recipe, ingredient_id: String) -> ChopTarget:
	return ChopTarget.new(ingredient_id, recipe.chop.get(ingredient_id, {}))


func begin_session() -> void:
	if not in_session:
		in_session = true
		sessions += 1


func end_session() -> void:
	in_session = false


## Registra um corte válido (duração em ms e bits de faixa do GestureRecognizer).
## Retorna true se o estado visual mudou.
func add_cut(duration_ms: float, band_bits: int) -> bool:
	var before := model_id()
	cuts += 1
	_dur_sum += duration_ms
	_dur_sq += duration_ms * duration_ms
	coverage_mask |= band_bits
	return model_id() != before


func is_done() -> bool:
	return cuts >= cuts_required


func is_overcut() -> bool:
	return overcut_limit > 0 and cuts > overcut_limit


func cv() -> float:
	return GestureRecognizer.cv_of(cuts, _dur_sum, _dur_sq)


func bands() -> int:
	return GestureRecognizer.count_bands(coverage_mask)


func cut_quality() -> int:
	if is_overcut():
		return Kitchen.Quality.CLUMSY
	return GestureRecognizer.grade_chop(cv(), bands())


func cut_score() -> float:
	return Kitchen.quality_score(cut_quality())


## Id do glTF do estado visual.
func model_id() -> String:
	if is_overcut():
		return overcut_id
	if is_done():
		return result_id
	return raw_id


## Id do item que o dedo leva ao arrastar da tábua ("" se ainda não está pronto).
func carry_item_id() -> String:
	if is_overcut():
		return overcut_carry_id
	if is_done():
		return carry_id
	return ""


## Notas do item levado ({"corte": x}).
func notes() -> Dictionary:
	return {Kitchen.NOTE_CUT: cut_score()}
