class_name Patty
extends RefCounted
## Carne na frigideira (decisão 22; m2_turno "Cozinhar simples"): cozinha sozinha, sem
## virar (os dois lados juntos). O tempo só corre na frigideira; tick(delta) injeta o tempo.
## A nota do ponto é gravada ao tirar.

## Estágio (som/fumaça): cru < 8 s, no ponto 8–10, perfeito 10–14, passando 14–20, queimado ≥ 20.
enum Stage { RAW, MEDIUM, GLOW, SMOKE, BURNT }

const COOKED_S := 8.0
const PERFECT_FROM_S := 10.0
const PERFECT_UNTIL_S := 14.0
const BURNT_S := 20.0

var in_pan: bool = false
var time: float = 0.0
## Nota do ponto (-1 = ainda sem nota). Gravada ao tirar da frigideira.
var note: float = -1.0


## Nota (0, 0.4, 0.7, 1.0) para t segundos de frigideira.
static func grade_time(t: float) -> float:
	if t >= BURNT_S:
		return Kitchen.SCORE_NONE
	return Kitchen.quality_score(quality_for_time(t))


## Qualidade para o feedback; cru e queimado viram CLUMSY ("Ops").
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
	if in_pan:
		time += delta_s


func stage() -> int:
	return stage_for_time(time)


## No ponto (bom ou perfeito) agora?
func is_cooked() -> bool:
	return quality_for_time(time) != Kitchen.Quality.CLUMSY


func is_burnt() -> bool:
	return time >= BURNT_S


## Tira da frigideira (pausa o cozimento), grava a nota e retorna a qualidade, ou -1.
func remove() -> int:
	if not in_pan:
		return -1
	note = grade_time(time)
	in_pan = false
	return quality_for_time(time)


## Id do glTF do estado visual.
func model_id() -> String:
	if is_burnt():
		return Kitchen.BURGER_TRASH
	if time >= COOKED_S:
		return Kitchen.BURGER_COOKED
	return Kitchen.BURGER_UNCOOKED


## Nota gravada no formato do item ({"ponto": x}); vazio sem nota.
func notes() -> Dictionary:
	return {Kitchen.NOTE_COOK: note} if note >= 0.0 else {}
