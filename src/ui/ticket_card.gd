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
## Espaço reservado abaixo do bilhete para a fita "próximo" (px do bilhete).
const NEXT_TAG_SPACE := 18.0
## Menor redução de um bilhete alto demais para a faixa (G1 do QA do cozinhar simples).
const MIN_FIT := 0.6
## Linhas da frase no modo compacto (telas baixas): 1 linha com reticências (M5 do QA M2).
const COMPACT_LINES := 1
const RECIPE_PATH := "res://data/recipes/%s.json"
## Lado dos ícones da receita (px lógicos do bilhete); encolhe para a fileira caber em RECIPE_ROW_W.
const RECIPE_ICON := 26.0
const RECIPE_ROW_W := 162.0
const RECIPE_GAP := 2.0
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
## Limite inferior (coordenadas do pai) da faixa dos bilhetes, fita "próximo" inclusa: o bilhete
## alto demais sobe e, se ainda não couber, encolhe; nunca desce sobre os caixotes e a tábua.
var max_bottom := INF:
	set(v):
		max_bottom = v
		_place()
## Redução aplicada para caber na faixa (1 = tamanho normal).
var fit := 1.0
## Escala das animações (entrada, virada da resposta); a escala real é pop * fit.
var pop := Vector2.ONE:
	set(v):
		pop = v
		scale = pop * fit
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
## Modo compacto: frase em até COMPACT_LINES linhas e nome em 1 linha, com reticências.
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
	# 1 item: etiqueta "sem X" embaixo do bilhete; vários itens: uma por fileira (M2 do QA M2).
	var without: Array = items[0]["without"] if items.size() == 1 else []
	_without.visible = not without.is_empty()
	if _without.visible:
		_without.text = UiText.without_text(without)
	_hungry.text = UiText.HUNGRY_LINE
	_stamp.visible = false
	modulate.a = 0.0
	pop = Vector2(0.85, 0.85)
	float_offset = Vector2(0, -36)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)
	tw.tween_property(self, "pop", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "float_offset", Vector2.ZERO, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_reply(reply: String, band: int) -> void:
	is_reply = true
	var tw := create_tween()
	tw.tween_property(self, "pop:x", 0.0, 0.15).set_ease(Tween.EASE_IN)
	tw.tween_callback(apply_reply.bind(reply, band))
	tw.tween_property(self, "pop:x", 1.0, 0.18).set_ease(Tween.EASE_OUT)
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
		for icon in _row(item).get_children():
			if icon.has_meta("id"):
				out.append(String(icon.get_meta("id")))
	return out


func item_row_count() -> int:
	return _items.get_child_count() if _items.visible else 0


## Marca o item como entregue (✓ e fileira esmaecida).
func mark_delivered(item: int) -> void:
	if item < 0 or item >= _items.get_child_count():
		return
	_items.get_child(item).set_meta("delivered", true)
	var row := _row(item)
	row.get_node("Check").visible = true
	for icon in row.get_children():
		if icon.has_meta("id"):
			icon.modulate.a = 0.4
	_items.get_child(item).get_node("Without").modulate.a = 0.4


func is_delivered(item: int) -> bool:
	return item >= 0 and item < _items.get_child_count() and _items.get_child(item).get_meta("delivered", false)


## Etiqueta "sem X" da fileira do item (bilhete com vários itens), ou null.
func item_without_label(item: int) -> Label:
	if item < 0 or item >= _items.get_child_count():
		return null
	return _items.get_child(item).get_node("Without")


func _row(item: int) -> HBoxContainer:
	return _items.get_child(item).get_node("Row")


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
		var item := VBoxContainer.new()
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_theme_constant_override("separation", 1)
		var row := HBoxContainer.new()
		row.name = "Row"
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", int(RECIPE_GAP))
		var cols := ids.size() + 1  # + visto
		var side := minf(RECIPE_ICON, floorf((RECIPE_ROW_W - (cols - 1) * RECIPE_GAP) / cols))
		for id in ids:
			var icon := TextureRect.new()
			icon.texture = _trimmed_icon(id)
			icon.custom_minimum_size = Vector2.ONE * side
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.tooltip_text = UiText.ingredient_name(id)
			icon.set_meta("id", id)
			row.add_child(icon)
		var check := CheckMark.new()
		check.name = "Check"
		check.custom_minimum_size = Vector2.ONE * side
		check.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
		check.visible = false
		row.add_child(check)
		item.add_child(row)
		var wo := Label.new()
		wo.name = "Without"
		wo.theme_type_variation = &"TicketWithout"
		wo.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		wo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wo.visible = items.size() > 1 and not (it["without"] as Array).is_empty()
		if wo.visible:
			wo.text = UiText.without_text(it["without"])
		item.add_child(wo)
		_items.add_child(item)
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
	_name.autowrap_mode = TextServer.AUTOWRAP_OFF if compact else TextServer.AUTOWRAP_WORD_SMART
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if compact else TextServer.OVERRUN_NO_TRIMMING
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
	# faixa dos bilhetes: sobe o que passar de max_bottom; se ainda não couber, encolhe (pivô no centro).
	var h := size.y + NEXT_TAG_SPACE
	var top := maxf(minf(p.y, max_bottom - h), MARGIN)
	fit = 1.0
	if size.y > 0.0 and top + h > max_bottom:
		fit = clampf((max_bottom - top) / h, MIN_FIT, 1.0)
	p.y = maxf(top - next_lift, 0.0) - size.y * 0.5 * (1.0 - fit)
	position = p
	scale = pop * fit


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


## Retângulo da fita "próximo" (coordenadas locais do bilhete).
func _next_tag_rect() -> Rect2:
	var font := get_theme_font("font", "TicketWithout")
	var fs := get_theme_font_size("font_size", "TicketWithout")
	var text_size := font.get_string_size(NEXT_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	return Rect2(Vector2(size.x * 0.5 - text_size.x * 0.5 - 12.0, size.y - 6.0), Vector2(text_size.x + 24.0, text_size.y + 4.0))


## Fita "próximo" em coordenadas de tela, já com a subida final do destaque (vazio se não é o próximo).
func next_tag_screen_rect() -> Rect2:
	if not is_next or not is_inside_tree():
		return Rect2()
	var xf := get_global_transform()
	var tag := _next_tag_rect()
	var out := Rect2(xf * tag.position, Vector2.ZERO)
	for corner in [Vector2(tag.end.x, tag.position.y), tag.end, Vector2(tag.position.x, tag.end.y)]:
		out = out.expand(xf * corner)
	# a subida do destaque pode estar animando: cobre a posição final também.
	out = out.merge(Rect2(out.position - Vector2(0, (NEXT_LIFT - next_lift) * xf.get_scale().y), out.size))
	return out


## Fita "próximo" pendurada na base do bilhete.
func _draw_next_tag() -> void:
	var font := get_theme_font("font", "TicketWithout")
	var fs := get_theme_font_size("font_size", "TicketWithout")
	var tag := _next_tag_rect()
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
