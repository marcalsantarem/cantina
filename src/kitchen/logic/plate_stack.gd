class_name PlateStack
extends RefCounted
## Pilha do prato de montagem (design §2.4). O pão inteiro solto no prato vazio vira
## bun_bottom na pilha + bun_top estacionado em BunTopRest. O bun_top fecha o prato.
## Cada item: {id, quality: Dictionary, offset: Vector2 (u), tilt_deg: float}.

var recipe: Recipe
var rng: RandomNumberGenerator
var items: Array[Dictionary] = []
## true enquanto o bun_top espera em BunTopRest.
var bun_top_parked: bool = false
var closed: bool = false


func _init(recipe_data: Recipe = null, random: RandomNumberGenerator = null) -> void:
	recipe = recipe_data if recipe_data != null else Recipe.load_burger()
	rng = random if random != null else RandomNumberGenerator.new()


func is_empty() -> bool:
	return items.is_empty()


func size() -> int:
	return items.size()


## Aceita o item? (para devolver à origem quando não).
func can_accept(item_id: String) -> bool:
	if closed:
		return false
	if item_id == Kitchen.BUN:
		return items.is_empty() and not bun_top_parked
	return recipe.layer_of(item_id) != ""


## Solta um item no prato. `notes` = notas já obtidas (corte, lados...);
## `align` = Kitchen.Quality do alinhamento; `offset_u` = GestureRecognizer.drop_offset_u.
## Retorna false se o item não cabe (o chamador devolve à origem).
func add(item_id: String, notes: Dictionary, align: int, offset_u: Vector2 = Vector2.ZERO) -> bool:
	if not can_accept(item_id):
		return false
	var id := item_id
	if item_id == Kitchen.BUN:
		id = Kitchen.BUN_BOTTOM
		bun_top_parked = true
	elif item_id == Kitchen.BUN_TOP:
		bun_top_parked = false
		closed = true
	var q := notes.duplicate()
	q[Kitchen.NOTE_ASSEMBLY] = Kitchen.quality_score(align)
	var max_tilt: float = Kitchen.ASSEMBLY_TILT_DEG[align]
	items.append({
		"id": id,
		"quality": q,
		"offset": offset_u.limit_length(GestureRecognizer.ALIGN_MAX_OFFSET_U),
		"tilt_deg": rng.randf_range(-max_tilt, max_tilt),
	})
	return true


func top_id() -> String:
	return "" if items.is_empty() else items[-1]["id"]


## Ids na ordem de baixo para cima.
func ids() -> Array[String]:
	var out: Array[String] = []
	for it in items:
		out.append(it["id"])
	return out


## Entrega a pilha (cópia) e esvazia o prato.
func take_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = items.duplicate(true)
	clear()
	return out


func clear() -> void:
	items.clear()
	bun_top_parked = false
	closed = false
