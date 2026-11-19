class_name Patty
extends RefCounted
## Carne na panela (design §3). O tempo de cada lado só corre na panela e com
## aquele lado para baixo; tick(delta) injeta o tempo.

enum Side { A, B }
## Estágio do lado para baixo (som/fumaça): 0–5, 5–7, 7–10, 10–13, ≥13 s.
enum Stage { RAW, MEDIUM, GLOW, SMOKE, BURNT }

const COOKED_S := 5.0
const PERFECT_FROM_S := 7.0
const PERFECT_UNTIL_S := 10.0
const BURNT_S := 13.0

var in_pan: bool = false
var side_down: int = Side.A
var time_a: float = 0.0
var time_b: float = 0.0
## Nota de cada lado (-1 = ainda sem nota). Gravada quando o lado sai de baixo.
var note_a: float = -1.0
var note_b: float = -1.0


## Nota (0, 0.4, 0.7, 1.0) para um lado com t segundos.
static func grade_time(t: float) -> float:
	if t >= BURNT_S:
		return Kitchen.SCORE_NONE
	return Kitchen.quality_score(quality_for_time(t))


## Qualidade para o feedback do gesto; queimado vira CLUMSY ("Ops").
static func quality_for_time(t: float) -> int:
	if t < COOKED_S or t >= BURNT_S:
		return Kitchen.Quality.CLUMSY
	if t >= PERFECT_FROM_S and t < PERFECT_UNTIL_S:
		return Kitchen.Quality.PERFECT
	return Kitchen.Quality.GOOD


static func stage_for_time(t: float) -> int:
	if t >= BURNT_S:
		return Stage.BURNT
	if t >= PERFECT_UNTIL_S:
		return Stage.SMOKE
	if t >= PERFECT_FROM_S:
		return Stage.GLOW
	if t >= COOKED_S:
		return Stage.MEDIUM
	return Stage.RAW


func place_in_pan() -> void:
	in_pan = true


func tick(delta_s: float) -> void:
	if not in_pan:
		return
	if side_down == Side.A:
		time_a += delta_s
	else:
		time_b += delta_s


func side_time(side: int) -> float:
	return time_a if side == Side.A else time_b


func down_stage() -> int:
	return stage_for_time(side_time(side_down))


## Vira na panela. Grava a nota do lado que estava para baixo e retorna a
## qualidade dele (feedback). Retorna -1 se a carne não está na panela.
func flip() -> int:
	if not in_pan:
		return -1
	var q := _record(side_down)
	side_down = Side.B if side_down == Side.A else Side.A
	return q


## Tira da panela (pausa o cozimento). Grava a nota do lado de baixo e a de
## qualquer lado ainda sem nota. Retorna a qualidade do lado de baixo, ou -1.
func remove() -> int:
	if not in_pan:
		return -1
	var q := _record(side_down)
	if note_a < 0.0:
		_record(Side.A)
	if note_b < 0.0:
		_record(Side.B)
	in_pan = false
	return q


func is_burnt() -> bool:
	return time_a >= BURNT_S or time_b >= BURNT_S


## Id do glTF do estado visual.
func model_id() -> String:
	if is_burnt():
		return Kitchen.BURGER_TRASH
	if time_a >= COOKED_S and time_b >= COOKED_S:
		return Kitchen.BURGER_COOKED
	return Kitchen.BURGER_UNCOOKED


## Notas gravadas no formato do item ({"lado_a": x, "lado_b": y}); omite lado sem nota.
func notes() -> Dictionary:
	var d := {}
	if note_a >= 0.0:
		d[Kitchen.NOTE_SIDE_A] = note_a
	if note_b >= 0.0:
		d[Kitchen.NOTE_SIDE_B] = note_b
	return d


func _record(side: int) -> int:
	var t := side_time(side)
	if side == Side.A:
		note_a = grade_time(t)
	else:
		note_b = grade_time(t)
	return quality_for_time(t)
