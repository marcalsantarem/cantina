extends PanelContainer
## Bilhete de papel no trilho. Vira bilhete-resposta ao servir e some depois.
## Posição: base inferior centrada em anchor_point (+ deslocamentos), presa à tela.
## M2: uma fileira de receita por item (✓ ao entregar) e humor de espera (ShiftScorer.Mood).

const UiText := preload("res://src/ui/ui_text.gd")
const ICON_PATH := "res://assets/icons/%s.png"
const RAIL_OVERLAP := 14.0
const MARGIN := 8.0
const CLIP_COLOR := Color("#9ea8ad")
const NEXT_COLOR := Color("#c76b45")
const NEXT_TEXT := "próximo"
const NEXT_LIFT := 12.0
## Linhas da frase no modo compacto (telas baixas).
const COMPACT_LINES := 2
const RECIPE_PATH := "res://data/recipes/%s.json"
## Lado dos ícones da receita (px lógicos do bilhete).
const RECIPE_ICON := 26.0
## Receitas cujo ícone do prato abre a fileira quando o bilhete tem mais de 1 item (tigela).
const DISH_PREFIX: Array[String] = ["food_stew"]
enum Mood { CONTENT, IMPATIENT, HUNGRY }  # = ShiftScorer.Mood
## Balanço do bilhete impaciente: a cada SWAY_EVERY s, SWAY_S s de balanço.
const SWAY_EVERY := 5.0
const SWAY_S := 0.6
const SWAY_ANGLE := 0.06
const HUNGRY_PAPER := Color("#f6dc9a")
const MOOD_INK := Color("#c76b45")

static var _recipe_cache := {}
static var _trimmed_cache := {}

var slot := -1
var is_reply := false
var dismissing := false
var anchor_point := Vector2.ZERO:
	set(v):
		anchor_point = v
		_place()
## Ajuste do HUD para não sobrepor bilhetes vizinhos.
var layout_shift := Vector2.ZERO:
	set(v):
		layout_shift = v
		_place()
var float_offset := Vector2.ZERO:
	set(v):
		float_offset = v
		_place()
## Bilhete mais antigo aberto: é ele que recebe o próximo prato.
var is_next := false:
	set(v):
		if v == is_next:
			return
		is_next = v
		_animate_lift(NEXT_LIFT if v else 0.0)
		queue_redraw()
var next_lift := 0.0:
	set(v):
		next_lift = v
		_place()
## Modo compacto: frase do pedido em até COMPACT_LINES linhas com reticências.
var compact := false:
	set(v):
		compact = v
		_apply_compact()

## Humor de espera (Mood); o visual só vale enquanto o bilhete está aberto.
var mood := Mood.CONTENT:
	set(v):
		if v == mood:
			return
		mood = v
		_apply_mood()
## Ângulo extra do balanço (animado).
var sway := 0.0:
	set(v):
		sway = v
		rotation = _base_rotation + v

var _full_phrase := ""
var _base_rotation := 0.0
var _sway_tween: Tween
var _item_count := 1

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _phrase: Label = %Phrase
@onready var _without: Label = %Without
@onready var _items: VBoxContainer = %Items
@onready var _hungry: Label = %Hungry
@onready var _stamp: Control = %Stamp


func _ready() -> void:
	resized.connect(_place)
	_base_rotation = randf_range(-0.035, 0.035)
	rotation = _base_rotation


func show_ticket(ticket: TicketData) -> void:
	_name.text = ticket.nickname
	_full_phrase = ticket.phrase
	_apply_compact()
	var items := ticket_items(ticket)
	_item_count = items.size()
	var icon_path := ICON_PATH % ticket.recipe
	_icon.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null
	_icon.visible = _icon.texture != null and _item_count == 1
	_show_items(items)
	var without: Array[String] = []
	for it in items:
		for id: String in it["without"]:
			if not without.has(id):
				without.append(id)
	_without.visible = not without.is_empty()
	if _without.visible:
		_without.text = UiText.without_text(without)
	_hungry.text = UiText.HUNGRY_LINE
	_stamp.visible = false
	modulate.a = 0.0
	scale = Vector2(0.85, 0.85)
	float_offset = Vector2(0, -36)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)
	tw.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "float_offset", Vector2.ZERO, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_reply(reply: String, band: int) -> void:
	is_reply = true
	var tw := create_tween()
	tw.tween_property(self, "scale:x", 0.0, 0.15).set_ease(Tween.EASE_IN)
	tw.tween_callback(apply_reply.bind(reply, band))
	tw.tween_property(self, "scale:x", 1.0, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(_stamp, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(_stamp, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)


## Troca o conteúdo para o bilhete-resposta (sem animação).
func apply_reply(reply: String, band: int) -> void:
	is_reply = true
	is_next = false
	mood = Mood.CONTENT
	_phrase.max_lines_visible = -1
	theme_type_variation = &"ReplyPanel"
	_icon.visible = false
	_without.visible = false
	_items.visible = false
	_phrase.text = reply
	_stamp.band = band
	_stamp.visible = true
	_stamp.pivot_offset = _stamp.custom_minimum_size * 0.5
	_stamp.modulate.a = 0.0
	_stamp.scale = Vector2(1.8, 1.8)


func stamp_band() -> int:
	return _stamp.band if _stamp.visible else -1


func phrase_text() -> String:
	return _phrase.text


func without_label() -> Label:
	return _without


func icon_texture() -> Texture2D:
	return _icon.texture if _icon.visible else null


func dismiss_after(seconds: float) -> void:
	get_tree().create_timer(seconds).timeout.connect(dismiss)


func dismiss(duration := 0.4) -> void:
	if dismissing or not is_inside_tree():
		return
	dismissing = true
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 0.0, duration)
	tw.tween_property(self, "float_offset", Vector2(0, -24), duration)
	tw.chain().tween_callback(queue_free)


## Itens do bilhete ({recipe, without, delivered}); bilhete antigo sem `items` vira 1 item.
static func ticket_items(ticket: TicketData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it in ticket.items:
		out.append(it)
	if out.is_empty():
		out.append({"recipe": ticket.recipe, "without": ticket.without, "delivered": false})
	return out


## Ids das camadas pedidas, da base para o topo (ordem de montagem), sem as do `without`.
static func recipe_layers(ticket: TicketData) -> Array[String]:
	return layers_for(ticket.recipe, ticket.without)


static func layers_for(recipe_id: String, without: Array) -> Array[String]:
	var recipe: Recipe = _recipe_cache.get(recipe_id)
	if recipe == null:
		var path := RECIPE_PATH % recipe_id
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		recipe = Recipe.from_dict(data if data is Dictionary else {})
		_recipe_cache[recipe_id] = recipe
	return recipe.requested_layers(without)


## Ids mostrados na fileira do item, na ordem (base -> topo, da esquerda para a direita).
func recipe_ids(item := 0) -> Array[String]:
	var out: Array[String] = []
	if _items.visible and item < _items.get_child_count():
		for icon in _items.get_child(item).get_children():
			if icon.has_meta("id"):
				out.append(String(icon.get_meta("id")))
	return out


func item_row_count() -> int:
	return _items.get_child_count() if _items.visible else 0


## Marca o item como entregue (✓ e fileira esmaecida).
func mark_delivered(item: int) -> void:
	if item < 0 or item >= _items.get_child_count():
		return
	var row: Control = _items.get_child(item)
	row.set_meta("delivered", true)
	row.get_node("Check").visible = true
	for icon in row.get_children():
		if icon.has_meta("id"):
			icon.modulate.a = 0.4


func is_delivered(item: int) -> bool:
	return item >= 0 and item < _items.get_child_count() and _items.get_child(item).get_meta("delivered", false)


func hungry_label() -> Label:
	return _hungry


func is_swaying() -> bool:
	return _sway_tween != null and _sway_tween.is_valid()


func _show_items(items: Array[Dictionary]) -> void:
	for old in _items.get_children():
		old.free()
	for it in items:
		var ids: Array[String] = []
		var rid := String(it["recipe"])
		if items.size() > 1 and DISH_PREFIX.has(rid):
			ids.append(rid)
		ids.append_array(layers_for(rid, it["without"]))
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 2)
		for id in ids:
			var icon := TextureRect.new()
			icon.texture = _trimmed_icon(id)
			icon.custom_minimum_size = Vector2.ONE * RECIPE_ICON
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.tooltip_text = UiText.ingredient_name(id)
			icon.set_meta("id", id)
			row.add_child(icon)
		var check := CheckMark.new()
		check.name = "Check"
		check.custom_minimum_size = Vector2.ONE * RECIPE_ICON
		check.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
		check.visible = false
		row.add_child(check)
		_items.add_child(row)
		if it.get("delivered", false):
			mark_delivered(_items.get_child_count() - 1)
	_items.visible = not items.is_empty()


func _apply_mood() -> void:
	if _hungry == null:
		return
	var open := not is_reply
	var hungry := open and mood == Mood.HUNGRY
	_hungry.visible = hungry
	if hungry:
		var sb := get_theme_stylebox("panel", &"TicketPanel").duplicate() as StyleBoxFlat
		if sb:
			sb.bg_color = HUNGRY_PAPER
			add_theme_stylebox_override("panel", sb)
	else:
		remove_theme_stylebox_override("panel")
	if open and mood == Mood.IMPATIENT:
		if not is_swaying():
			_sway_tween = create_tween().set_loops()
			_sway_tween.tween_interval(SWAY_EVERY - SWAY_S)
			for a in [SWAY_ANGLE, -SWAY_ANGLE, SWAY_ANGLE * 0.5, 0.0]:
				_sway_tween.tween_property(self, "sway", a, SWAY_S / 4.0).set_trans(Tween.TRANS_SINE)
	elif is_swaying():
		_sway_tween.kill()
		_sway_tween = null
		sway = 0.0
	queue_redraw()


## Visto de entrega, desenhado (a fonte pode não ter o glifo ✓).
class CheckMark extends Control:
	const COLOR := Color("#2fa57e")

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var o := (size - Vector2(s, s)) * 0.5
		draw_polyline(PackedVector2Array([o + Vector2(0.15, 0.55) * s, o + Vector2(0.4, 0.8) * s,
				o + Vector2(0.88, 0.2) * s]), COLOR, maxf(3.0, s * 0.16), true)


## Ícone sem a margem transparente (as fatias são achatadas e somem num ícone pequeno).
static func _trimmed_icon(id: String) -> Texture2D:
	if _trimmed_cache.has(id):
		return _trimmed_cache[id]
	var path := ICON_PATH % id
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if tex != null:
		var img := tex.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			var used := img.get_used_rect()
			if used.has_area():
				var atlas := AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = Rect2(used)
				tex = atlas
	_trimmed_cache[id] = tex
	return tex


func phrase_label() -> Label:
	return _phrase


func _apply_compact() -> void:
	if _phrase == null or is_reply:
		return
	_phrase.text = _full_phrase
	_phrase.max_lines_visible = COMPACT_LINES if compact else -1
	if compact:
		_fit_phrase.call_deferred()


## Corta a frase por palavras, com reticências, até caber em COMPACT_LINES linhas.
func _fit_phrase() -> void:
	if is_reply or not compact or _phrase.get_line_count() <= COMPACT_LINES:
		return
	var words := _full_phrase.split(" ", false)
	while words.size() > 1:
		words.remove_at(words.size() - 1)
		_phrase.text = " ".join(words).rstrip(",.;:") + "…"
		if _phrase.get_line_count() <= COMPACT_LINES:
			return


func _animate_lift(target: float) -> void:
	if not is_inside_tree():
		next_lift = target
		return
	create_tween().tween_property(self, "next_lift", target, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _place() -> void:
	if not is_inside_tree():
		return
	pivot_offset = size * 0.5
	var area := get_parent_area_size()
	var p := anchor_point + layout_shift + float_offset - Vector2(size.x * 0.5, size.y - RAIL_OVERLAP)
	p.x = clampf(p.x, MARGIN, maxf(MARGIN, area.x - size.x - MARGIN))
	p.y = maxf(maxf(p.y, MARGIN) - next_lift, 0.0)
	position = p


func _draw() -> void:
	var clip := Rect2(size.x * 0.5 - 16.0, -7.0, 32.0, 13.0)
	draw_rect(clip, CLIP_COLOR)
	draw_rect(Rect2(clip.position + Vector2(0, clip.size.y - 3), Vector2(clip.size.x, 3)), CLIP_COLOR.darkened(0.25))
	if is_next:
		_draw_next_tag()
	if mood == Mood.IMPATIENT and not is_reply:
		_draw_impatient_stamp()


## Carimbo "…" no canto superior direito do bilhete impaciente.
func _draw_impatient_stamp() -> void:
	var c := Vector2(size.x - 14.0, 12.0)
	var r := 13.0
	draw_circle(c, r, Color(1, 0.98, 0.93))
	draw_arc(c, r, 0.0, TAU, 32, MOOD_INK, 2.5, true)
	var font := get_theme_font("font", "TicketName")
	var fs := 20
	var t := UiText.IMPATIENT_STAMP
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(c.x - w * 0.5, c.y + 3.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, MOOD_INK)


## Fita "próximo" pendurada na base do bilhete.
func _draw_next_tag() -> void:
	var font := get_theme_font("font", "TicketWithout")
	var fs := get_theme_font_size("font_size", "TicketWithout")
	var text_size := font.get_string_size(NEXT_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var tag := Rect2(Vector2(size.x * 0.5 - text_size.x * 0.5 - 12.0, size.y - 6.0), Vector2(text_size.x + 24.0, text_size.y + 4.0))
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = NEXT_COLOR
	ring.set_border_width_all(3)
	ring.set_corner_radius_all(14)
	draw_style_box(ring, Rect2(Vector2.ZERO, size).grow(2.0))
	var notch := 6.0
	var mid := tag.size.y * 0.5
	draw_colored_polygon(PackedVector2Array([tag.position, Vector2(tag.end.x, tag.position.y),
			Vector2(tag.end.x - notch, tag.position.y + mid), tag.end, Vector2(tag.position.x, tag.end.y),
			Vector2(tag.position.x + notch, tag.position.y + mid)]), NEXT_COLOR)
	var cream := get_theme_color("font_color", "TicketWithout")
	draw_string(font, Vector2(tag.position.x + 12.0, tag.position.y + 2.0 + font.get_ascent(fs)), NEXT_TEXT,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cream)
