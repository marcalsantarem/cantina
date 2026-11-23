class_name ShiftClock
extends RefCounted
## Relógio do turno (m2_turno §1): fases, agenda de chegadas, máximo aberto por fase,
## mistura de pedidos e fim aos 180 s. Tempo por tick(delta) (o chamador não chama
## tick em pausa/segundo plano); RNG injetável. Nada é alocado por tick.

enum Phase { OPENING, RUSH, CLOSING, LAST_ORDERS, CLOSED }
## Bits retornados por tick().
enum Event { NONE = 0, ARRIVAL = 1, PHASE_CHANGED = 2, ENDED = 4 }

const DURATION_S := 180.0
const FIRST_ARRIVAL_S := 3.0
## Com o trilho no máximo da fase, a chegada espera a vaga + isto.
const WAIT_AFTER_VACANCY_S := 4.0
## Depois do fim, a tela de fim de turno abre após isto (o controller conta).
const END_SCREEN_DELAY_S := 1.5
## Início de cada fase (s); CLOSED começa em DURATION_S.
const PHASE_START_S: Array[float] = [0.0, 45.0, 135.0, 165.0, 180.0]
## Intervalo entre chegadas por fase (0 = sem chegadas).
const PHASE_INTERVAL_S: Array[float] = [22.0, 16.0, 25.0, 0.0, 0.0]
## Máximo de bilhetes abertos por fase.
const PHASE_MAX_OPEN: Array[int] = [2, 4, 3, 0, 0]
## Chance de pedido com 2 itens por fase.
const PHASE_COMBO_CHANCE: Array[float] = [0.0, 0.4, 0.0, 0.0, 0.0]
## 1 item: hambúrguer 60%, ensopado 40%. 2 itens: hambúrguer + ensopado 75%, 2 hambúrgueres 25%.
const SINGLE_BURGER_CHANCE := 0.6
const COMBO_MIXED_CHANCE := 0.75
const BURGER := "food_burger"
const STEW := "food_stew"
## Relógio de parede: 11h00 no início, 1 min de parede por s de jogo (14h00 aos 180 s).
const WALL_START_MIN := 11 * 60
const WALL_MIN_PER_S := 1.0

var rng: RandomNumberGenerator
## Tempo de jogo (s), 0–180.
var time: float = 0.0
var ended: bool = false
## Chegadas ocorridas no último tick (normalmente 0 ou 1).
var arrivals_this_tick: int = 0
## Total de chegadas no turno e tempo da última.
var arrivals_total: int = 0
var last_arrival_s: float = -1.0
## Próxima chegada agendada (INF = nenhuma; também INF enquanto espera vaga).
var next_arrival_s: float = FIRST_ARRIVAL_S
## true se a chegada devida está esperando vaga no trilho.
var waiting_vacancy: bool = false
var _phase: int = Phase.OPENING


func _init(random: RandomNumberGenerator = null) -> void:
	rng = random if random != null else RandomNumberGenerator.new()


static func phase_at(t: float) -> int:
	for p in range(Phase.CLOSED, Phase.OPENING, -1):
		if t >= PHASE_START_S[p]:
			return p
	return Phase.OPENING


static func max_open_at(t: float) -> int:
	return PHASE_MAX_OPEN[phase_at(t)]


static func interval_at(t: float) -> float:
	return PHASE_INTERVAL_S[phase_at(t)]


## Minutos do relógio de parede desde 0h (11h00 = 660 ... 14h00 = 840).
static func wall_minutes_at(t: float) -> float:
	return WALL_START_MIN + clampf(t, 0.0, DURATION_S) * WALL_MIN_PER_S


## (hora, minuto) inteiros do relógio de parede.
static func wall_clock_at(t: float) -> Vector2i:
	var m := int(floor(wall_minutes_at(t)))
	return Vector2i(floori(m / 60.0), m % 60)


## Agenda sem atraso (para conferência): 3, 25, 47, 63, ..., 143.
static func ideal_schedule() -> Array[float]:
	var out: Array[float] = []
	var t := FIRST_ARRIVAL_S
	while t < PHASE_START_S[Phase.LAST_ORDERS]:
		out.append(t)
		t += interval_at(t)
	return out


## Pedido para dois sorteios em [0, 1): `r_size` decide 1 ou 2 itens (pela fase),
## `r_mix` decide as receitas.
static func order_for_rolls(phase: int, r_size: float, r_mix: float) -> Array[String]:
	var out: Array[String] = []
	if r_size < PHASE_COMBO_CHANCE[phase]:
		out.append(BURGER)
		out.append(STEW if r_mix < COMBO_MIXED_CHANCE else BURGER)
	else:
		out.append(BURGER if r_mix < SINGLE_BURGER_CHANCE else STEW)
	return out


func phase() -> int:
	return _phase


func remaining_s() -> float:
	return maxf(DURATION_S - time, 0.0)


func wall_clock() -> Vector2i:
	return wall_clock_at(time)


## Sorteia o pedido da chegada pela fase atual (ids de receita).
func roll_order() -> Array[String]:
	var r_size := rng.randf()
	var r_mix := rng.randf()
	return order_for_rolls(_phase, r_size, r_mix)


## Avança o relógio. `open_count` = bilhetes abertos no trilho agora. Cada chegada
## conta como +1 aberto até o fim deste tick. Retorna bits de Event; o nº de chegadas
## fica em `arrivals_this_tick` (o chamador cria um bilhete por chegada).
func tick(delta_s: float, open_count: int) -> int:
	arrivals_this_tick = 0
	if ended:
		return Event.NONE
	var ev: int = Event.NONE
	var target := minf(time + maxf(delta_s, 0.0), DURATION_S)
	while true:
		if waiting_vacancy and open_count + arrivals_this_tick < max_open_at(time):
			waiting_vacancy = false
			next_arrival_s = time + WAIT_AFTER_VACANCY_S
		var step := target
		var boundary := _next_boundary(time)
		if boundary < step:
			step = boundary
		if not waiting_vacancy and next_arrival_s < step:
			step = next_arrival_s
		time = step
		var p := phase_at(time)
		if p != _phase:
			_phase = p
			ev |= Event.PHASE_CHANGED
		if not waiting_vacancy and time >= next_arrival_s:
			if time >= PHASE_START_S[Phase.LAST_ORDERS]:
				next_arrival_s = INF
			elif open_count + arrivals_this_tick >= max_open_at(time):
				waiting_vacancy = true
			else:
				arrivals_this_tick += 1
				arrivals_total += 1
				last_arrival_s = time
				ev |= Event.ARRIVAL
				next_arrival_s = time + interval_at(time)
		if time >= target:
			break
	if time >= DURATION_S:
		ended = true
		waiting_vacancy = false
		next_arrival_s = INF
		ev |= Event.ENDED
	return ev


func _next_boundary(t: float) -> float:
	for s in PHASE_START_S:
		if s > t:
			return s
	return INF
