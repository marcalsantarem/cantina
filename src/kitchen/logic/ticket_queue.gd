class_name TicketQueue
extends RefCounted
## Fila de bilhetes (design §4): até 3 abertos; um novo chega 6 s depois que houver
## vaga; não expiram. Tempo por tick(delta) e RNG injetados.
## M2 (m2_turno §5): o ShiftClock decide quando chega; `spawn_order` cria o bilhete
## com 1+ itens e `deliver` entrega item a item ao mais antigo que espera a receita.

signal ticket_arrived(ticket: TicketData)

const CUSTOMERS_PATH := "res://data/kitchen/customers.json"
const MAX_OPEN := 3
## Vagas do trilho no M2 (Slot1..Slot4).
const RAIL_SLOTS := 4
const BURGER := "food_burger"
const ARRIVAL_DELAY_S := 6.0
const PLAIN_CHANCE := 0.7
const WITHOUT_STEP := 0.1
## Itens que podem vir no `without` (10% cada).
const WITHOUT_OPTIONS: Array[String] = [
	Kitchen.CHEESE_SLICE, Kitchen.LETTUCE_SLICE, Kitchen.TOMATO_SLICE,
]

var rng: RandomNumberGenerator
## Abertos, do mais antigo para o mais novo.
var open: Array[TicketData] = []
var customers: Array = []
var without_phrases: Dictionary = {}
var recipe_id: String = "food_burger"
## Máximo de abertos (M1 = 3; no M2 use RAIL_SLOTS e deixe o ShiftClock limitar por fase).
var max_open: int = MAX_OPEN
## Frases por receita/combinação ("food_stew", "combo"), para pedidos que não são 1 hambúrguer.
var recipe_phrases: Dictionary = {}
var _timer: float = 0.0
var _next_id: int = 1


func _init(random: RandomNumberGenerator = null, data: Dictionary = {}) -> void:
	rng = random if random != null else RandomNumberGenerator.new()
	var d := data if not data.is_empty() else Kitchen.load_json(CUSTOMERS_PATH)
	customers = d.get("customers", [])
	without_phrases = d.get("without_phrases", {})
	recipe_phrases = d.get("recipe_phrases", {})


func open_count() -> int:
	return open.size()


func has_vacancy() -> bool:
	return open.size() < max_open


## Segundos até o próximo bilhete (INF se a fila está cheia).
func time_to_next() -> float:
	return ARRIVAL_DELAY_S - _timer if has_vacancy() else INF


func tick(delta_s: float) -> void:
	if not has_vacancy():
		_timer = 0.0
		return
	_timer += delta_s
	while has_vacancy() and _timer >= ARRIVAL_DELAY_S:
		_timer -= ARRIVAL_DELAY_S
		spawn()
	if not has_vacancy():
		_timer = 0.0


## Cria um bilhete já (ignora o atraso). Retorna null se não há vaga.
func spawn() -> TicketData:
	if not has_vacancy():
		return null
	var t := TicketData.new()
	t.id = _next_id
	_next_id += 1
	t.add_item(recipe_id, roll_without() if recipe_id == BURGER else [])
	var c := _pick_customer()
	t.nickname = c.get("nickname", "")
	t.phrase = _pick_phrase(c, t.without)
	t.state = TicketData.State.OPEN
	open.append(t)
	ticket_arrived.emit(t)
	return t


## M2: cria já um bilhete com estes itens (ids de receita, ex. ShiftClock.roll_order()).
## Hambúrguer sorteia `without` como no M1. Retorna null se não há vaga.
func spawn_order(recipes: Array, now_s: float = 0.0) -> TicketData:
	if not has_vacancy() or recipes.is_empty():
		return null
	var t := TicketData.new()
	t.id = _next_id
	_next_id += 1
	var first_without: Array[String] = []
	for r: String in recipes:
		var w: Array[String] = roll_without() if r == BURGER else ([] as Array[String])
		if first_without.is_empty() and not w.is_empty():
			first_without = w
		t.add_item(r, w)
	t.arrived_s = now_s
	var c := _pick_customer()
	t.nickname = c.get("nickname", "")
	t.phrase = _pick_order_phrase(c, recipes, first_without)
	t.state = TicketData.State.OPEN
	open.append(t)
	ticket_arrived.emit(t)
	return t


## Bilhete mais antigo que ainda espera esta receita (null se nenhum).
func oldest_waiting(recipe: String) -> TicketData:
	for t in open:
		if t.waits_for(recipe):
			return t
	return null


## Entrega um item (prato/tigela) ao bilhete mais antigo que espera a receita.
## Se o bilhete fica completo, sai de `open` (SERVED). Retorna o bilhete, ou null se
## ninguém espera (o chamador devolve à origem: "Ninguém pediu isso agora").
func deliver(recipe: String, score: int, dominant: String = "", now_s: float = 0.0) -> TicketData:
	var t := oldest_waiting(recipe)
	if t == null:
		return null
	if t.deliver(t.pending_index(recipe), score, dominant, now_s):
		open.erase(t)
	return t


## 70% vazio; 10% cada item de WITHOUT_OPTIONS.
func roll_without() -> Array[String]:
	return without_for_roll(rng.randf())


## Mapeia r em [0, 1): < 0,7 vazio; [0,7; 0,8) queijo; [0,8; 0,9) alface; [0,9; 1) tomate.
static func without_for_roll(r: float) -> Array[String]:
	var out: Array[String] = []
	if r < PLAIN_CHANCE:
		return out
	var idx := WITHOUT_OPTIONS.size() - 1
	for i in WITHOUT_OPTIONS.size() - 1:
		if r < PLAIN_CHANCE + (i + 1) * WITHOUT_STEP:
			idx = i
			break
	out.append(WITHOUT_OPTIONS[idx])
	return out


func oldest() -> TicketData:
	return null if open.is_empty() else open[0]


## Serve o bilhete mais antigo (marca SERVED e libera a vaga). null se não há.
func serve_oldest() -> TicketData:
	if open.is_empty():
		return null
	var t: TicketData = open.pop_front()
	t.state = TicketData.State.SERVED
	return t


func _pick_customer() -> Dictionary:
	if customers.is_empty():
		return {}
	# Evita repetir um cliente que já está com bilhete aberto.
	var start := rng.randi_range(0, customers.size() - 1)
	for k in customers.size():
		var c: Dictionary = customers[(start + k) % customers.size()]
		if not _is_open_nickname(c.get("nickname", "")):
			return c
	return customers[start]


func _is_open_nickname(nick: String) -> bool:
	for t in open:
		if t.nickname == nick:
			return true
	return false


func _pick_order_phrase(customer: Dictionary, recipes: Array, without: Array[String]) -> String:
	var key := ""
	if recipes.size() > 1:
		key = "combo"
	elif recipes[0] != BURGER:
		key = recipes[0]
	var pool: Array = recipe_phrases.get(key, []) if key != "" else []
	if pool.is_empty():
		return _pick_phrase(customer, without)
	return pool[rng.randi_range(0, pool.size() - 1)]


func _pick_phrase(customer: Dictionary, without: Array[String]) -> String:
	var pool: Array = []
	if not without.is_empty():
		pool = without_phrases.get(without[0], [])
	if pool.is_empty():
		pool = customer.get("phrases", [])
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]
