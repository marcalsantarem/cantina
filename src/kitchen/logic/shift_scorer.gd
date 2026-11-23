class_name ShiftScorer
extends RefCounted
## Paciência e estrelas do turno (m2_turno §2 e §3). Sem estado: funções puras sobre
## os bilhetes que chegaram no turno.

enum Mood { CONTENT, IMPATIENT, HUNGRY }

## Tolerância de espera (s) para 1 item e para 2+ itens.
const TOLERANCE_1_S := 30.0
const TOLERANCE_2_S := 50.0
## Agilidade cai linear de 1,0 em T até o mínimo em T + isto.
const AGILITY_FALL_S := 60.0
const AGILITY_MIN := 0.3
## Impaciente até T + isto; depois, faminto.
const IMPATIENT_S := 30.0
## Abaixo disto a resposta ganha gancho de demora (§3).
const LATE_AGILITY := 0.7

const W_QUALITY := 0.60
const W_SERVICE := 0.25
const W_AGILITY := 0.15
const TWO_STARS_MIN := 60.0
const THREE_STARS_MIN := 80.0
## Atendimento (A) mínimo para ★★ e ★★★ (B1 do QA M2: 1 prato perfeito não vale ★★).
const TWO_STARS_MIN_A := 50.0
const THREE_STARS_MIN_A := 75.0

const AGILITY_WORDS: Array[String] = ["Ágil", "No ritmo", "Sem pressa"]
const AGILITY_WORD_FAST := 80.0
const AGILITY_WORD_OK := 50.0


static func tolerance_s(item_count: int) -> float:
	return TOLERANCE_1_S if item_count <= 1 else TOLERANCE_2_S


## Agilidade 0,3–1,0 para uma espera de `wait` s.
static func agility(wait: float, item_count: int) -> float:
	var t := tolerance_s(item_count)
	if wait <= t:
		return 1.0
	var k := clampf((wait - t) / AGILITY_FALL_S, 0.0, 1.0)
	return maxf(1.0 - k * (1.0 - AGILITY_MIN), AGILITY_MIN)


static func mood(wait: float, item_count: int) -> int:
	var t := tolerance_s(item_count)
	if wait <= t:
		return Mood.CONTENT
	if wait <= t + IMPATIENT_S:
		return Mood.IMPATIENT
	return Mood.HUNGRY


static func ticket_agility(ticket: TicketData, now_s: float) -> float:
	return agility(ticket.wait_s(now_s), ticket.item_count())


static func ticket_mood(ticket: TicketData, now_s: float) -> int:
	return mood(ticket.wait_s(now_s), ticket.item_count())


## S (0–100) = 0,60·Q + 0,25·A + 0,15·G.
static func shift_score(q: float, a: float, g: float) -> float:
	return W_QUALITY * q + W_SERVICE * a + W_AGILITY * g


## Estrelas para S e A (0–100): ★★ com S ≥ 60 e A ≥ 50; ★★★ com S ≥ 80 e A ≥ 75.
static func stars_for(s: float, a: float = 100.0) -> int:
	if s >= THREE_STARS_MIN - 0.0001 and a >= THREE_STARS_MIN_A - 0.0001:
		return 3
	if s >= TWO_STARS_MIN - 0.0001 and a >= TWO_STARS_MIN_A - 0.0001:
		return 2
	return 1


## Palavra da agilidade (G 0–100).
static func agility_word(g: float) -> String:
	if g >= AGILITY_WORD_FAST:
		return AGILITY_WORDS[0]
	if g >= AGILITY_WORD_OK:
		return AGILITY_WORDS[1]
	return AGILITY_WORDS[2]


## Resultado do turno a partir de todos os bilhetes que chegaram (abertos contam como
## não atendidos). `held_items` = itens de chegadas seguradas pelo trilho cheio que não
## chegaram (`ShiftClock.held_arrivals`): entram no denominador de A (ficar parado não
## encolhe a régua). Retorna {score, stars, quality, service, agility, served, arrived,
## items_delivered, items_total, items_held, avg_score, agility_word, best_reply}.
static func summarize(tickets: Array, held_items: int = 0) -> Dictionary:
	var served := 0
	var q_sum := 0.0
	var g_sum := 0.0
	var items_total := 0
	var items_delivered := 0
	var best: TicketData = null
	var best_g := -1.0
	for t: TicketData in tickets:
		t.ensure_items()
		items_total += t.item_count()
		items_delivered += t.delivered_count()
		if not t.is_complete():
			continue
		served += 1
		var g := agility(t.wait_s(t.completed_s), t.item_count())
		q_sum += t.score()
		g_sum += g
		if t.reply != "" and (best == null or t.score() > best.score() \
				or (t.score() == best.score() and g > best_g)):
			best = t
			best_g = g
	var q := 0.0 if served == 0 else q_sum / served
	var g_pct := 0.0 if served == 0 else 100.0 * g_sum / served
	var a_total := items_total + maxi(held_items, 0)
	var a := 0.0 if a_total == 0 else 100.0 * items_delivered / a_total
	var s := shift_score(q, a, g_pct)
	return {
		"score": s,
		"stars": stars_for(s, a),
		"quality": q,
		"service": a,
		"agility": g_pct,
		"served": served,
		"arrived": tickets.size(),
		"items_delivered": items_delivered,
		"items_total": items_total,
		"items_held": maxi(held_items, 0),
		"avg_score": roundi(q),
		"agility_word": agility_word(g_pct),
		"best_reply": best.reply if best != null else "",
	}
