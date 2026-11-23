class_name TicketData
extends Resource
## Pedido de um cliente invisível (M1 design §4; M2 m2_turno §5: 1 ou mais itens).
## `items[i]` = {recipe, without, delivered: bool, score: int, dominant: String}.
## `recipe`/`without` espelham o 1º item (compatibilidade com o M1).

enum State { OPEN, SERVED }

@export var id: int = 0
@export var nickname: String = ""
@export var phrase: String = ""
@export var recipe: String = "food_burger"
## Ids de camada que o cliente não quer (do 1º item).
@export var without: Array[String] = []
@export var state: State = State.OPEN
## Itens do pedido (vazio só em bilhete antigo criado à mão: vale `recipe`/`without`).
@export var items: Array[Dictionary] = []
## Tempo do turno (s) em que chegou e em que o último item foi entregue (-1 = ainda não).
@export var arrived_s: float = 0.0
@export var completed_s: float = -1.0
## Frase do bilhete-resposta (preenchida no fim do bilhete).
@export var reply: String = ""


## Acrescenta um item. O 1º também define `recipe`/`without`.
func add_item(recipe_id: String, without_ids: Array = []) -> void:
	var w: Array[String] = []
	w.assign(without_ids)
	if items.is_empty():
		recipe = recipe_id
		without.assign(w)
	items.append({"recipe": recipe_id, "without": w, "delivered": false, "score": 0, "dominant": ""})


## Garante `items` (bilhete feito só com `recipe`/`without`).
func ensure_items() -> void:
	if items.is_empty():
		add_item(recipe, without)


func item_count() -> int:
	return maxi(items.size(), 1)


## Índice do 1º item ainda não entregue com esta receita (-1 se nenhum).
func pending_index(recipe_id: String) -> int:
	for i in items.size():
		if not items[i]["delivered"] and items[i]["recipe"] == recipe_id:
			return i
	return -1


func waits_for(recipe_id: String) -> bool:
	return pending_index(recipe_id) >= 0


## Marca o item i como entregue com a nota (0–100) e o erro dominante.
## Se for o último, fecha o bilhete (SERVED, `completed_s` = now_s). Retorna true se fechou.
func deliver(index: int, score: int, dominant: String, now_s: float) -> bool:
	var it: Dictionary = items[index]
	it["delivered"] = true
	it["score"] = score
	it["dominant"] = dominant
	if is_complete():
		state = State.SERVED
		completed_s = now_s
		return true
	return false


func delivered_count() -> int:
	var n := 0
	for it in items:
		if it["delivered"]:
			n += 1
	return n


func is_complete() -> bool:
	return not items.is_empty() and delivered_count() == items.size()


## Nota do bilhete = média simples das notas dos itens entregues (arredondada).
func score() -> int:
	var n := 0
	var sum := 0
	for it in items:
		if it["delivered"]:
			n += 1
			sum += int(it["score"])
	return 0 if n == 0 else roundi(float(sum) / n)


## Índice do item entregue de pior nota (-1 se nenhum). Empate: o primeiro.
func worst_index() -> int:
	var best := -1
	for i in items.size():
		if items[i]["delivered"] and (best < 0 or int(items[i]["score"]) < int(items[best]["score"])):
			best = i
	return best


## Espera (s): da chegada ao último item entregue, ou até `now_s` se aberto.
func wait_s(now_s: float) -> float:
	var end := completed_s if completed_s >= 0.0 else now_s
	return maxf(end - arrived_s, 0.0)
