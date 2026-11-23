extends RefCounted
## Textos de interface (pt-BR) num lugar só; trocar por tr() quando houver tradução.

const START_TITLE := "Cantina"
const START_HINT := "Toque para começar"
const START_CREDITS := "Assets: Kay Lousberg (KayKit, CC0)  ·  Fonte: Fredoka (SIL OFL)"
const ROTATE_HINT := "Gire o celular"
const WITHOUT := "sem %s"
const HUNGRY_LINE := "Tô com fome, chef!"
const IMPATIENT_STAMP := "…"
const PAUSED := "Pausado — toque para voltar"
## Placas do turno por `ShiftClock.Phase` (vazio = sem placa).
const PHASE_BANNERS: Array[String] = ["", "Hora do almoço!", "", "Últimos pedidos", "Fechado!"]
const END_TITLE := "Fim do turno"
const END_SERVED := "Pedidos atendidos %d/%d"
const END_AVG := "Nota média %d"
const END_AGILITY := "Agilidade: %s"
const END_BEST := "Melhor frase do dia"
const END_REPLAY := "Jogar de novo"

const INGREDIENT_NAMES := {
	"tomato": "tomate", "cheese": "queijo", "lettuce": "alface", "onion": "cebola",
	"ham": "presunto", "carrot": "cenoura", "potato": "batata", "bun": "pão",
	"burger": "carne", "steak": "carne", "ketchup": "ketchup", "mustard": "mostarda",
}


## "food_ingredient_tomato_slice" -> "tomate".
static func ingredient_name(id: String) -> String:
	var key := id.trim_prefix("food_ingredient_").get_slice("_", 0)
	return INGREDIENT_NAMES.get(key, key)


## ["...tomato_slice", "...cheese_slice"] -> "sem tomate e queijo".
static func without_text(ids: Array) -> String:
	var names: PackedStringArray = []
	for id: String in ids:
		names.append(ingredient_name(id))
	var joined := names[-1] if names.size() > 0 else ""
	if names.size() > 1:
		joined = ", ".join(names.slice(0, -1)) + " e " + names[-1]
	return WITHOUT % joined
