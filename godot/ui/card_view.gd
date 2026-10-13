class_name CardView
extends Button
## A card: parchment face with a big tinted icon, type band, name and
## suit/rank; Kenney card back when face down. Used in the hand, in prompts
## and by the effects layer for flying cards.

const SUIT_GLYPH := {"spade": "♠", "heart": "♥", "club": "♣", "diamond": "♦"}
const RANKS := ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const SIZE := Vector2(122, 170)
const COMPACT_SIZE := Vector2(92, 128)

var card_id: int = -1
var selected_card: bool = false:
	set(v):
		selected_card = v
		_restyle()
var playable: bool = true:
	set(v):
		playable = v
		_restyle()

var _face_up := false
var compact := false
var _type_color := Color.GRAY
var _band: ColorRect
var _icon: TextureRect
var _name: Label
var _corner: Label
var _back: TextureRect


func _init() -> void:
	custom_minimum_size = SIZE
	toggle_mode = false
	clip_contents = true
	focus_mode = Control.FOCUS_NONE
	text = ""


func setup(cid: int, info: Dictionary, defs: Dictionary, p_compact: bool = false) -> void:
	card_id = cid
	compact = p_compact
	custom_minimum_size = COMPACT_SIZE if compact else SIZE
	for c in get_children():
		c.queue_free()
	_face_up = info.has("def")
	if not _face_up:
		_back = TextureRect.new()
		_back.texture = load("res://ui/assets/kenney/card_back.png")
		_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_back.stretch_mode = TextureRect.STRETCH_SCALE
		_back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
		_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_back)
		tooltip_text = "Face-down card"
		_restyle()
		return
	var d: Dictionary = defs.get(info["def"], {})
	_type_color = SgsIcons.type_color(d.get("type", ""))
	var suit: String = info.get("suit", "none")
	var rank: int = int(info.get("rank", 0))
	var red := suit == "heart" or suit == "diamond"

	_band = ColorRect.new()
	_band.color = _type_color
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_band.offset_left = 4
	_band.offset_right = -4
	_band.offset_top = 4
	_band.offset_bottom = 34 if compact else 46
	add_child(_band)

	_name = Label.new()
	_name.text = d.get("name", str(info["def"]))
	_name.theme_type_variation = "InkLabel"
	_name.add_theme_font_override("font", load("res://ui/fonts/DejaVuSerif-Bold.ttf"))
	var long_name := _name.text.length() > 11
	_name.add_theme_font_size_override("font_size", (10 if long_name else 14) if compact else (12 if long_name else 17))
	_name.add_theme_constant_override("line_spacing", -4)
	_name.add_theme_color_override("font_color", Color.WHITE)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if long_name else TextServer.AUTOWRAP_OFF
	_name.clip_text = true
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_name.offset_left = 6
	_name.offset_right = -6
	_name.offset_top = 4
	_name.offset_bottom = 34 if compact else 46
	add_child(_name)

	_icon = TextureRect.new()
	_icon.texture = SgsIcons.card(str(info["def"]))
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.modulate = _type_color.darkened(0.25)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 16 if compact else 22
	_icon.offset_right = -16 if compact else -22
	_icon.offset_top = 38 if compact else 52
	_icon.offset_bottom = -30 if compact else -36
	add_child(_icon)

	_corner = Label.new()
	_corner.text = "%s%s" % [SUIT_GLYPH.get(suit, ""), RANKS[rank] if rank < RANKS.size() else ""]
	_corner.add_theme_font_size_override("font_size", 17 if compact else 22)
	_corner.add_theme_color_override("font_color", Color(0.8, 0.12, 0.12) if red else Color(0.1, 0.1, 0.1))
	_corner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_corner.offset_top = -28 if compact else -34
	_corner.offset_bottom = -4
	add_child(_corner)
	tooltip_text = d.get("text", "")
	_restyle()


func _restyle() -> void:
	var sb := StyleBoxFlat.new()
	if not _face_up:
		sb.bg_color = Color(0.15, 0.12, 0.1)
		sb.border_color = Color(0.3, 0.25, 0.2)
	elif selected_card:
		sb.bg_color = Color(0.86, 0.95, 1.0)
		sb.border_color = Color(0.2, 0.6, 1.0)
	elif playable:
		sb.bg_color = SgsTheme.PARCHMENT
		sb.border_color = SgsTheme.GOLD
	else:
		sb.bg_color = Color(0.74, 0.70, 0.62)
		sb.border_color = Color(0.4, 0.36, 0.3)
	sb.set_border_width_all(4 if (selected_card or playable) and _face_up else 2)
	sb.set_corner_radius_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(st, sb)
	if _face_up and is_instance_valid(_icon):
		_icon.modulate = _type_color.darkened(0.25) if (playable or selected_card) else Color(0.45, 0.42, 0.38)
	if _face_up and is_instance_valid(_band):
		_band.color = _type_color if (playable or selected_card) else Color(0.5, 0.48, 0.45)
