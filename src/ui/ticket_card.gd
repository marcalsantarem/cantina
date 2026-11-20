extends PanelContainer
## Bilhete de papel no trilho. Vira bilhete-resposta ao servir e some depois.
## Posição: base inferior centrada em anchor_point (+ deslocamentos), presa à tela.

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

var _full_phrase := ""

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _phrase: Label = %Phrase
@onready var _without: Label = %Without
@onready var _recipe: HBoxContainer = %Recipe
@onready var _stamp: Control = %Stamp


func _ready() -> void:
	resized.connect(_place)
	rotation = randf_range(-0.035, 0.035)


func show_ticket(ticket: TicketData) -> void:
	_name.text = ticket.nickname
	_full_phrase = ticket.phrase
	_apply_compact()
	var icon_path := ICON_PATH % ticket.recipe
	_icon.texture = load(icon_path) if ResourceLoader.exists(icon_path) else null
	_icon.visible = _icon.texture != null
	_show_recipe(recipe_layers(ticket))
	_without.visible = not ticket.without.is_empty()
	if _without.visible:
		_without.text = UiText.without_text(ticket.without)
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
	_phrase.max_lines_visible = -1
	theme_type_variation = &"ReplyPanel"
	_icon.visible = false
	_without.visible = false
	_recipe.visible = false
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


## Ids das camadas pedidas, da base para o topo (ordem de montagem), sem as do `without`.
static func recipe_layers(ticket: TicketData) -> Array[String]:
	var recipe: Recipe = _recipe_cache.get(ticket.recipe)
	if recipe == null:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECIPE_PATH % ticket.recipe))
		recipe = Recipe.from_dict(data if data is Dictionary else {})
		_recipe_cache[ticket.recipe] = recipe
	return recipe.requested_layers(ticket.without)


## Ids mostrados na fileira de receita, na ordem (base -> topo, da esquerda para a direita).
func recipe_ids() -> Array[String]:
	var out: Array[String] = []
	if _recipe.visible:
		for icon in _recipe.get_children():
			out.append(String(icon.get_meta("id")))
	return out


func _show_recipe(ids: Array[String]) -> void:
	for old in _recipe.get_children():
		old.free()
	for id in ids:
		var icon := TextureRect.new()
		icon.texture = _trimmed_icon(id)
		icon.custom_minimum_size = Vector2.ONE * RECIPE_ICON
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.tooltip_text = UiText.ingredient_name(id)
		icon.set_meta("id", id)
		_recipe.add_child(icon)
	_recipe.visible = not ids.is_empty()


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
