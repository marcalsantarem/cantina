class_name TicketQueue
extends RefCounted
## Fila de bilhetes (design §4): até 3 abertos; um novo chega 6 s depois que houver
## vaga; não expiram. Tempo por tick(delta) e RNG injetados.

signal ticket_arrived(ticket: TicketData)

const CUSTOMERS_PATH := "res://data/kitchen/customers.json"
const MAX_OPEN := 3
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
var _timer: float = 0.0
var _next_id: int = 1


func _init(random: RandomNumberGenerator = null, data: Dictionary = {}) -> void:
	rng = random if random != null else RandomNumberGenerator.new()
	var d := data if not data.is_empty() else Kitchen.load_json(CUSTOMERS_PATH)
	customers = d.get("customers", [])
	without_phrases = d.get("without_phrases", {})


func open_count() -> int:
	return open.size()


func has_vacancy() -> bool:
	return open.size() < MAX_OPEN


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
	t.recipe = recipe_id
	t.without.assign(roll_without())
	var c := _pick_customer()
	t.nickname = c.get("nickname", "")
	t.phrase = _pick_phrase(c, t.without)
	t.state = TicketData.State.OPEN
	open.append(t)
	ticket_arrived.emit(t)
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


func _pick_phrase(customer: Dictionary, without: Array[String]) -> String:
	var pool: Array = []
	if not without.is_empty():
		pool = without_phrases.get(without[0], [])
	if pool.is_empty():
		pool = customer.get("phrases", [])
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]
