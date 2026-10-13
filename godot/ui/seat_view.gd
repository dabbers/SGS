class_name SeatView
extends Button
## One opponent (or me) at the table: portrait disc, name, role badge, hero,
## HP hearts, hand count, equipment and judgement icons. Highlights the
## current player and selectable targets; can shake and flash for effects.

signal seat_pressed(seat: int)

var seat: int = -1
var selectable := false
var selected := false
var current := false
var alive := true

var _portrait: Label
var _name: Label
var _hero: Label
var _hearts: HBoxContainer
var _hand: Label
var _equip: HBoxContainer
var _judge: HBoxContainer
var _role_icon: TextureRect
var _flash: ColorRect
var _base_pos: Vector2


func _init() -> void:
	custom_minimum_size = Vector2(236, 150)
	focus_mode = Control.FOCUS_NONE
	text = ""
	_build()
	pressed.connect(func(): seat_pressed.emit(seat))


func _build() -> void:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(m)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	m.add_child(row)

	var left := VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)
	_portrait = Label.new()
	_portrait.custom_minimum_size = Vector2(64, 64)
	_portrait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait.add_theme_font_override("font", load("res://ui/fonts/DejaVuSerif-Bold.ttf"))
	_portrait.add_theme_font_size_override("font_size", 26)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_portrait)
	_role_icon = TextureRect.new()
	_role_icon.custom_minimum_size = Vector2(64, 30)
	_role_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_role_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_role_icon.modulate = SgsTheme.GOLD
	_role_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_role_icon)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_theme_constant_override("separation", 2)
	row.add_child(right)
	_name = Label.new()
	_name.theme_type_variation = "TitleLabel"
	_name.add_theme_font_size_override("font_size", 21)
	_name.clip_text = true
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_name)
	_hero = Label.new()
	_hero.theme_type_variation = "SmallLabel"
	_hero.clip_text = true
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_hero)
	_hearts = HBoxContainer.new()
	_hearts.add_theme_constant_override("separation", 1)
	_hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_hearts)
	var info_row := HBoxContainer.new()
	info_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_theme_constant_override("separation", 8)
	right.add_child(info_row)
	var back := TextureRect.new()
	back.texture = load("res://ui/assets/kenney/card_back.png")
	back.custom_minimum_size = Vector2(16, 22)
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_child(back)
	_hand = Label.new()
	_hand.theme_type_variation = "SmallLabel"
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_child(_hand)
	_equip = HBoxContainer.new()
	_equip.add_theme_constant_override("separation", 2)
	_equip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_child(_equip)
	_judge = HBoxContainer.new()
	_judge.add_theme_constant_override("separation", 2)
	_judge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_row.add_child(_judge)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)
	_restyle()


## `p` is the player dict from the snapshot; `hero` the hero dict (may be empty);
## `equip` / `judge` are arrays of {"id", "name", "text"} for face-up cards.
func update(p: Dictionary, hero: Dictionary, hand_count: int, equip: Array, judge: Array, is_me: bool = false) -> void:
	seat = int(p["id"])
	alive = bool(p.get("alive", true))
	_name.text = ("You (%s)" % p.get("name", "?")) if is_me else p.get("name", "?")
	var initials := ""
	for part in str(hero.get("name", p.get("name", "?"))).split(" "):
		if part != "":
			initials += part[0]
	_portrait.text = initials.substr(0, 2) if alive else "✝"
	var faction: String = hero.get("faction", "qun")
	var pc: Color = SgsIcons.FACTION_COLORS.get(faction, Color(0.4, 0.4, 0.4))
	var psb := StyleBoxFlat.new()
	psb.bg_color = pc if alive else Color(0.25, 0.25, 0.25)
	psb.set_corner_radius_all(32)
	psb.border_color = SgsTheme.GOLD if current else Color(0.3, 0.25, 0.2)
	psb.set_border_width_all(3)
	_portrait.add_theme_stylebox_override("normal", psb)
	var role: String = p.get("role", "")
	_hero.text = "%s%s%s" % [hero.get("name", ""), (" · " + role.capitalize()) if role != "" else "", "" if alive else " — dead"]
	_role_icon.texture = SgsIcons.role(role)
	_role_icon.tooltip_text = role.capitalize()
	for c in _hearts.get_children():
		c.queue_free()
	var hp := int(p.get("hp", 0))
	var max_hp := int(p.get("max_hp", 0))
	for i in max_hp:
		var h := TextureRect.new()
		h.texture = SgsIcons.tex("hearts")
		h.custom_minimum_size = Vector2(20, 20)
		h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.modulate = Color(0.9, 0.15, 0.2) if i < hp else Color(0.3, 0.2, 0.2)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hearts.add_child(h)
	var hp_label := Label.new()
	hp_label.text = " %d/%d" % [hp, max_hp]
	hp_label.theme_type_variation = "SmallLabel"
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hearts.add_child(hp_label)
	_hand.text = str(hand_count)
	_fill_icons(_equip, equip, SgsTheme.GOLD)
	_fill_icons(_judge, judge, Color(0.6, 0.55, 1.0))
	tooltip_text = "\n".join((equip + judge).map(func(c): return "%s: %s" % [c["name"], c["text"]]))
	_restyle()


func _fill_icons(box: HBoxContainer, cards: Array, tint: Color) -> void:
	for c in box.get_children():
		c.queue_free()
	for c in cards:
		var t := TextureRect.new()
		t.texture = SgsIcons.card(str(c["id"]))
		t.custom_minimum_size = Vector2(24, 24)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.modulate = tint
		t.tooltip_text = "%s: %s" % [c["name"], c["text"]]
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(t)


func set_state(p_current: bool, p_selectable: bool, p_selected: bool, dim: bool) -> void:
	current = p_current
	selectable = p_selectable
	selected = p_selected
	disabled = (dim and not selectable) or not alive
	_restyle()


func _restyle() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.09, 0.07, 0.93)
	sb.border_color = Color(0.35, 0.28, 0.2)
	sb.set_border_width_all(2)
	if selected:
		sb.bg_color = Color(0.12, 0.25, 0.14, 0.95)
		sb.border_color = Color(0.4, 1.0, 0.5)
		sb.set_border_width_all(4)
	elif selectable:
		sb.bg_color = Color(0.22, 0.17, 0.08, 0.95)
		sb.border_color = SgsTheme.GOLD
		sb.set_border_width_all(4)
	elif current:
		sb.border_color = SgsTheme.GOLD
		sb.set_border_width_all(3)
		sb.shadow_color = Color(0.95, 0.8, 0.3, 0.45)
		sb.shadow_size = 10
	if not alive:
		sb.bg_color = Color(0.08, 0.08, 0.08, 0.8)
	sb.set_corner_radius_all(12)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(st, sb)
	modulate = Color(0.55, 0.55, 0.55) if not alive else Color.WHITE


# --- effects -------------------------------------------------------------------

func flash(color: Color, duration: float = 0.35) -> void:
	_flash.color = Color(color.r, color.g, color.b, 0.55)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, duration)


func shake(strength: float = 10.0, duration: float = 0.35) -> void:
	var base := position
	var tw := create_tween()
	var steps := 6
	for i in steps:
		var off := Vector2(randf_range(-strength, strength), randf_range(-strength * 0.4, strength * 0.4)) * (1.0 - float(i) / steps)
		tw.tween_property(self, "position", base + off, duration / steps)
	tw.tween_property(self, "position", base, duration / steps)
