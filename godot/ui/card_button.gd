class_name CardButton
extends Button
## A tappable card. Shows name + suit/rank when known, a back otherwise.

const SUIT_GLYPH := {"spade": "♠", "heart": "♥", "club": "♣", "diamond": "♦"}
const RANKS := ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

var card_id: int = -1
var selected_card: bool = false:
	set(v):
		selected_card = v
		_restyle()
var playable: bool = true:
	set(v):
		playable = v
		_restyle()


func setup(cid: int, info: Dictionary, defs: Dictionary) -> void:
	card_id = cid
	toggle_mode = false
	custom_minimum_size = Vector2(132, 166)
	add_theme_font_size_override("font_size", 21)
	size_flags_vertical = Control.SIZE_SHRINK_END
	if info.has("def"):
		var d: Dictionary = defs.get(info["def"], {})
		var suit: String = info.get("suit", "none")
		var glyph: String = SUIT_GLYPH.get(suit, "")
		var rank: String = RANKS[int(info.get("rank", 0))] if int(info.get("rank", 0)) < RANKS.size() else ""
		text = "%s\n%s%s" % [d.get("name", info["def"]), glyph, rank]
		tooltip_text = d.get("text", "")
		if suit == "heart" or suit == "diamond":
			add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
		else:
			add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	else:
		text = "?"
		add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_restyle()


func _restyle() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.98, 0.9) if not selected_card else Color(0.8, 0.95, 1.0)
	if not playable and not selected_card:
		sb.bg_color = Color(0.75, 0.73, 0.68)
	sb.border_color = Color(0.1, 0.5, 0.9) if selected_card else (Color(0.95, 0.75, 0.2) if playable else Color(0.4, 0.35, 0.25))
	sb.set_border_width_all(4 if selected_card or playable else 2)
	sb.set_corner_radius_all(8)
	add_theme_stylebox_override("normal", sb)
	add_theme_stylebox_override("hover", sb)
	add_theme_stylebox_override("pressed", sb)
	add_theme_stylebox_override("focus", sb)
