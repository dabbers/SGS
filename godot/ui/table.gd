extends Control
## The table: opponents on top, log + play area + prompt panel in the middle,
## my seat and hand at the bottom, and an effects layer on top. Everything
## renders from the session's filtered snapshot; events drive animations.

@onready var game: Node = get_node("/root/Game")
var session: GameSession
var defs: Dictionary = {}

var seats_row: HBoxContainer
var seat_views: Dictionary = {}       ## seat -> SeatView (opponents)
var my_seat_view: SeatView
var log_box: RichTextLabel
var play_area: Control
var deck_stack: Control
var center_slot: Control
var center_caption: Label
var prompt_title: Label
var prompt_help: Label
var card_info: Label
var option_row: HFlowContainer
var choice_row: HBoxContainer
var hand_row: HBoxContainer
var skills_label: Label
var confirm_btn: Button
var pass_btn: Button
var lobby_panel: PanelContainer
var lobby_list: Label
var start_btn: Button
var overlay: PanelContainer
var overlay_label: Label
var fx: FxLayer

var selected_cards: Array[int] = []
var selected_players: Array[int] = []
var log_lines: Array[String] = []
var _pending_snapshot: Dictionary = {}
var _pending_prompt: Prompt = null
var _pending_wait: Array = []   ## [seat, title] of a "waiting for" notice held back
var _hand_positions: Dictionary = {}   ## card id -> global centre, for animations


func _ready() -> void:
	theme = SgsTheme.get_theme()
	session = game.session
	if session == null:
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")
		return
	for d in SgsRules.new().create_defs().values():
		defs[String(d.id)] = d.to_dict()
	_build()
	session.lobby_changed.connect(_on_lobby)
	session.game_started.connect(func(): lobby_panel.visible = false)
	session.synced.connect(_on_sync_deferred)
	session.event_received.connect(_on_event)
	session.prompt_received.connect(_on_prompt_deferred)
	session.waiting_for.connect(_on_waiting_deferred)
	session.game_over.connect(_on_game_over)
	session.error.connect(func(m): _log("[color=#ff8080]%s[/color]" % m))
	if not session.snapshot.is_empty():
		_on_sync(session.snapshot)
	# Catch up the log on what happened before this view existed (no animations).
	fx.enabled = false
	for ev in session.event_history:
		_on_event(ev)
	fx.enabled = true
	if session.pending != null:
		_on_prompt(session.pending)
	elif not session.snapshot.is_empty():
		var cur := int(session.snapshot.get("current_player", -1))
		if cur >= 0 and cur != session.my_seat:
			_on_waiting(cur, "their turn")
	lobby_panel.visible = session is NetSession and session.snapshot.is_empty()
	if session is NetSession:
		_on_lobby(session.lobby)


# --- layout -----------------------------------------------------------------------

func _build() -> void:
	add_child(SgsTheme.make_background())
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	# Opponents
	var top_scroll := ScrollContainer.new()
	top_scroll.custom_minimum_size.y = 158
	top_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	top_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(top_scroll)
	var top_center := CenterContainer.new()
	top_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_scroll.add_child(top_center)
	seats_row = HBoxContainer.new()
	seats_row.add_theme_constant_override("separation", 10)
	top_center.add_child(seats_row)

	# Middle: log | play area | prompt
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.custom_minimum_size.y = 300
	middle.add_theme_constant_override("separation", 8)
	root.add_child(middle)
	var log_panel := PanelContainer.new()
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_panel.size_flags_stretch_ratio = 0.9
	middle.add_child(log_panel)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_panel.add_child(log_box)

	play_area = Control.new()
	play_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_area.size_flags_stretch_ratio = 1.0
	play_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(play_area)
	deck_stack = _make_deck_stack()
	play_area.add_child(deck_stack)
	center_slot = Panel.new()
	center_slot.custom_minimum_size = CardView.SIZE
	center_slot.size = CardView.SIZE
	center_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot_sb := StyleBoxFlat.new()
	slot_sb.bg_color = Color(0, 0, 0, 0.18)
	slot_sb.border_color = Color(0.93, 0.78, 0.38, 0.35)
	slot_sb.set_border_width_all(2)
	slot_sb.set_corner_radius_all(10)
	center_slot.add_theme_stylebox_override("panel", slot_sb)
	play_area.add_child(center_slot)
	center_caption = Label.new()
	center_caption.theme_type_variation = "HelpLabel"
	center_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_area.add_child(center_caption)
	play_area.resized.connect(_layout_play_area)

	var prompt_panel := PanelContainer.new()
	prompt_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_panel.size_flags_stretch_ratio = 1.15
	middle.add_child(prompt_panel)
	var prompt_scroll := ScrollContainer.new()
	prompt_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	prompt_panel.add_child(prompt_scroll)
	var prompt_box := VBoxContainer.new()
	prompt_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prompt_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prompt_box.add_theme_constant_override("separation", 6)
	prompt_scroll.add_child(prompt_box)
	prompt_title = Label.new()
	prompt_title.theme_type_variation = "TitleLabel"
	prompt_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_box.add_child(prompt_title)
	prompt_help = Label.new()
	prompt_help.theme_type_variation = "HelpLabel"
	prompt_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_box.add_child(prompt_help)
	card_info = Label.new()
	card_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_info.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	card_info.add_theme_font_size_override("font_size", 19)
	card_info.max_lines_visible = 3
	prompt_box.add_child(card_info)
	option_row = HFlowContainer.new()
	prompt_box.add_child(option_row)
	var choice_scroll := ScrollContainer.new()
	choice_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choice_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	choice_scroll.custom_minimum_size.y = 0
	prompt_box.add_child(choice_scroll)
	choice_row = HBoxContainer.new()
	choice_row.add_theme_constant_override("separation", 6)
	choice_scroll.add_child(choice_row)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	prompt_box.add_child(btn_row)
	confirm_btn = Button.new()
	confirm_btn.theme_type_variation = "PrimaryButton"
	confirm_btn.text = "Confirm"
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_btn.custom_minimum_size.y = 58
	confirm_btn.pressed.connect(_on_confirm)
	btn_row.add_child(confirm_btn)
	pass_btn = Button.new()
	pass_btn.text = "Pass"
	pass_btn.custom_minimum_size = Vector2(150, 58)
	pass_btn.pressed.connect(_on_pass)
	btn_row.add_child(pass_btn)
	var leave_btn := Button.new()
	leave_btn.theme_type_variation = "DangerButton"
	leave_btn.text = "Leave"
	leave_btn.custom_minimum_size = Vector2(110, 58)
	leave_btn.pressed.connect(_leave)
	btn_row.add_child(leave_btn)

	# Me
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)
	my_seat_view = SeatView.new()
	my_seat_view.custom_minimum_size = Vector2(270, 176)
	my_seat_view.disabled = true
	my_seat_view.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(my_seat_view)
	var hand_box := VBoxContainer.new()
	hand_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(hand_box)
	skills_label = Label.new()
	skills_label.theme_type_variation = "SmallLabel"
	skills_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skills_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	hand_box.add_child(skills_label)
	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size.y = CardView.SIZE.y + 14
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hand_box.add_child(hand_scroll)
	hand_row = HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 6)
	hand_scroll.add_child(hand_row)

	# Lobby
	lobby_panel = PanelContainer.new()
	lobby_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(lobby_panel)
	var lv := VBoxContainer.new()
	lobby_panel.add_child(lv)
	var lt := Label.new()
	lt.theme_type_variation = "TitleLabel"
	lt.text = "Lobby — waiting for players"
	lv.add_child(lt)
	lobby_list = Label.new()
	lv.add_child(lobby_list)
	start_btn = Button.new()
	start_btn.theme_type_variation = "PrimaryButton"
	start_btn.text = "Start game"
	start_btn.pressed.connect(func(): session.start_game({"decks": ["standard", "expansion"]}))
	lv.add_child(start_btn)

	# Game over overlay
	overlay = PanelContainer.new()
	overlay.visible = false
	overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(overlay)
	overlay_label = Label.new()
	overlay_label.theme_type_variation = "TitleLabel"
	overlay_label.add_theme_font_size_override("font_size", 40)
	overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(overlay_label)

	fx = FxLayer.new()
	fx.defs = defs
	fx.idle.connect(_apply_deferred)
	add_child(fx)
	_set_prompt(null)


# Snapshots and prompts are applied once the animation queue is empty, so the
# table shows the old state while the actions that change it play out.
func _on_sync_deferred(snap: Dictionary) -> void:
	_pending_snapshot = snap
	if not fx.is_busy():
		_apply_deferred()


func _on_prompt_deferred(p: Prompt) -> void:
	_pending_prompt = p
	_pending_wait = []
	if not fx.is_busy():
		_apply_deferred()
	else:
		prompt_title.text = "Resolving…"
		prompt_help.text = "Watch what the others did; your options appear next."


func _on_waiting_deferred(seat: int, title: String) -> void:
	_pending_prompt = null
	_pending_wait = [seat, title]
	if not fx.is_busy():
		_apply_deferred()


func _apply_deferred() -> void:
	if not _pending_snapshot.is_empty():
		var snap := _pending_snapshot
		_pending_snapshot = {}
		_on_sync(snap)
	if _pending_prompt != null:
		var p := _pending_prompt
		_pending_prompt = null
		_on_prompt(p)
	elif not _pending_wait.is_empty():
		var w := _pending_wait
		_pending_wait = []
		_on_waiting(int(w[0]), str(w[1]))


func _make_deck_stack() -> Control:
	var c := Control.new()
	c.custom_minimum_size = CardView.SIZE * 0.6
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		var back := TextureRect.new()
		back.texture = load("res://ui/assets/kenney/card_back.png")
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_SCALE
		back.size = CardView.SIZE * 0.6
		back.position = Vector2(i * 2, -i * 2)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(back)
	var l := Label.new()
	l.name = "Count"
	l.theme_type_variation = "SmallLabel"
	l.position = Vector2(0, CardView.SIZE.y * 0.6 + 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(l)
	return c


func _layout_play_area() -> void:
	var s := play_area.size
	deck_stack.position = Vector2(12, (s.y - CardView.SIZE.y * 0.6) / 2 - 10)
	center_slot.position = (s - CardView.SIZE) / 2 + Vector2(20, -16)
	center_caption.size = Vector2(s.x - 16, 60)
	center_caption.position = Vector2(8, center_slot.position.y + CardView.SIZE.y + 6)


func _center_pos() -> Vector2:
	return center_slot.global_position + CardView.SIZE / 2


func _deck_pos() -> Vector2:
	return deck_stack.global_position + CardView.SIZE * 0.3


func _seat_pos(seat: int) -> Vector2:
	if seat == session.my_seat:
		return my_seat_view.global_position + my_seat_view.size / 2
	if seat_views.has(seat):
		var v: SeatView = seat_views[seat]
		return v.global_position + v.size / 2
	return _center_pos()


func _card_pos(cid: int, fallback_seat: int) -> Vector2:
	if _hand_positions.has(cid):
		return _hand_positions[cid]
	return _seat_pos(fallback_seat)


# --- lobby ---------------------------------------------------------------------------

func _on_lobby(list: Array) -> void:
	var lines := []
	for p in list:
		lines.append("Seat %d: %s%s" % [int(p["seat"]) + 1, p["name"], " (bot)" if p["is_bot"] else ""])
	lobby_list.text = "\n".join(lines)
	start_btn.visible = session.is_host
	start_btn.disabled = list.size() < 2


# --- state -----------------------------------------------------------------------------

func _hero_of(snap: Dictionary, seat: int) -> Dictionary:
	var heroes: Dictionary = snap.get("vars", {}).get("heroes", {})
	return heroes.get(seat, heroes.get(str(seat), {}))


func _zone_cards(snap: Dictionary, zid: String) -> Array:
	var out := []
	for cid in snap["zones"].get(zid, {}).get("cards", []):
		var info := session.card_info(int(cid))
		var d: Dictionary = defs.get(info.get("def", ""), {})
		out.append({"id": info.get("def", ""), "name": d.get("name", "?"), "text": d.get("text", ""), "card": int(cid)})
	return out


func _on_sync(snap: Dictionary) -> void:
	_render_seats(snap)
	_render_me(snap)
	deck_stack.get_node("Count").text = "Deck %d" % snap["zones"].get("draw", {}).get("cards", []).size()


func _render_seats(snap: Dictionary) -> void:
	var players: Array = snap.get("players", [])
	var n := players.size()
	var me := session.my_seat
	var order := []
	for i in range(1, n):
		order.append(int(players[(me + i) % n]["id"]))
	# Reuse views so animations can target them between syncs.
	for seat in seat_views.keys():
		if not order.has(seat):
			seat_views[seat].queue_free()
			seat_views.erase(seat)
	for seat in order:
		if not seat_views.has(seat):
			var v := SeatView.new()
			v.seat_pressed.connect(_on_seat_pressed)
			seat_views[seat] = v
			seats_row.add_child(v)
		seats_row.move_child(seat_views[seat], order.find(seat))
		var p: Dictionary = players[seat]
		var width := clampf((size.x - 24 - 10 * (n - 2)) / maxf(n - 1, 1), 150, 236)
		seat_views[seat].custom_minimum_size = Vector2(width, 150)
		seat_views[seat].update(p, _hero_of(snap, seat), snap["zones"].get("hand:%d" % seat, {}).get("cards", []).size(),
			_zone_cards(snap, "equip:%d" % seat), _zone_cards(snap, "judge:%d" % seat))
	_refresh_selection_styles()


func _render_me(snap: Dictionary) -> void:
	var p := session.player_info(session.my_seat)
	if p.is_empty():
		return
	var hero := _hero_of(snap, session.my_seat)
	my_seat_view.update(p, hero, snap["zones"].get("hand:%d" % session.my_seat, {}).get("cards", []).size(),
		_zone_cards(snap, "equip:%d" % session.my_seat), _zone_cards(snap, "judge:%d" % session.my_seat), true)
	my_seat_view.set_state(int(snap.get("current_player", -1)) == session.my_seat, false, false, false)
	var skills: Array = hero.get("skills", [])
	skills_label.text = "  |  ".join(skills.map(func(s): return s["label"])) if not skills.is_empty() else ""
	for c in hand_row.get_children():
		c.queue_free()
	for cid in snap["zones"].get("hand:%d" % session.my_seat, {}).get("cards", []):
		var cv := CardView.new()
		cv.setup(int(cid), session.card_info(int(cid)), defs)
		cv.pressed.connect(_on_card_pressed.bind(int(cid)))
		hand_row.add_child(cv)
	_refresh_selection_styles()
	call_deferred("_record_hand_positions")


func _record_hand_positions() -> void:
	_hand_positions.clear()
	for cv in hand_row.get_children():
		if cv is CardView:
			_hand_positions[cv.card_id] = cv.global_position + cv.size / 2


# --- prompts -----------------------------------------------------------------------------

func _on_prompt(p: Prompt) -> void:
	selected_cards.clear()
	selected_players.clear()
	_set_prompt(p)


func _on_waiting(seat: int, title: String) -> void:
	_set_prompt(null)
	var who: String = session.player_info(seat).get("name", "seat %d" % seat)
	prompt_title.text = "Waiting for %s…" % who
	prompt_help.text = title


func _set_prompt(p: Prompt) -> void:
	for c in option_row.get_children():
		c.queue_free()
	for c in choice_row.get_children():
		c.queue_free()
	if p == null:
		prompt_title.text = ""
		prompt_help.text = ""
		card_info.text = ""
		confirm_btn.visible = false
		pass_btn.visible = false
		_refresh_selection_styles()
		return
	prompt_title.text = p.title
	prompt_help.text = _help_for(p)
	card_info.text = ""
	pass_btn.visible = p.can_pass
	pass_btn.text = "End turn" if p.kind == Prompt.KIND_PLAY else "Pass"
	confirm_btn.visible = p.kind != Prompt.KIND_CONFIRM and p.kind != Prompt.KIND_CHOOSE_OPTION
	for o in p.options:
		var b := Button.new()
		b.theme_type_variation = "PrimaryButton" if str(o["id"]) == "yes" or str(o["id"]).begins_with("skill:") else "Button"
		b.text = o["label"]
		b.custom_minimum_size.y = 50
		b.pressed.connect(func(): session.submit(p.id, {"option": o["id"]}))
		option_row.add_child(b)
	var my_hand: Array = session.snapshot.get("zones", {}).get("hand:%d" % session.my_seat, {}).get("cards", [])
	for cid in p.cards:
		if my_hand.has(cid):
			continue
		var cv := CardView.new()
		cv.setup(cid, session.card_info(cid), defs, true)
		cv.pressed.connect(_on_card_pressed.bind(cid))
		choice_row.add_child(cv)
	_refresh_selection_styles()


func _on_card_pressed(cid: int) -> void:
	_show_card_info(cid)
	var p := session.pending
	if p == null or not p.cards.has(cid):
		return
	if selected_cards.has(cid):
		selected_cards.erase(cid)
	else:
		if selected_cards.size() >= maxi(p.max_cards, 1):
			selected_cards.pop_front()
		selected_cards.append(cid)
	_refresh_selection_styles()


func _show_card_info(cid: int) -> void:
	var info := session.card_info(cid)
	if not info.has("def"):
		card_info.text = "A face-down card."
		return
	var d: Dictionary = defs.get(info["def"], {})
	var kind: String = d.get("type", "")
	if d.get("subtype", "") in ["weapon", "armor", "horse_plus", "horse_minus", "delayed"]:
		kind = str(d.get("subtype", "")).replace("_plus", " +1").replace("_minus", " -1").replace("delayed", "delayed trick")
	card_info.text = "%s (%s, %s): %s" % [d.get("name", "?"), kind, _card_name(cid).split(" ")[-1], d.get("text", "")]


func _on_seat_pressed(seat: int) -> void:
	var p := session.pending
	if p == null or not p.players.has(seat):
		return
	if selected_players.has(seat):
		selected_players.erase(seat)
	else:
		if selected_players.size() >= maxi(p.max_players, 1):
			selected_players.pop_front()
		selected_players.append(seat)
	_refresh_selection_styles()


func _current_response() -> Dictionary:
	return {"cards": selected_cards.duplicate(), "players": selected_players.duplicate()}


func _current_response_valid() -> bool:
	return session.pending != null and session.pending.validate(_current_response())


func _on_confirm() -> void:
	var p := session.pending
	if p == null:
		return
	var r := _current_response()
	if not p.validate(r):
		_log("[color=orange]Select %s first.[/color]" % ("a target" if p.kind == Prompt.KIND_CHOOSE_PLAYERS else "card(s)"))
		return
	_set_prompt(null)
	session.submit(p.id, r)


func _on_pass() -> void:
	var p := session.pending
	if p == null:
		return
	_set_prompt(null)
	session.submit(p.id, {"pass": true})


func _refresh_selection_styles() -> void:
	var p := session.pending
	for row in [hand_row, choice_row]:
		for cv in row.get_children():
			if cv is CardView:
				cv.selected_card = selected_cards.has(cv.card_id)
				cv.playable = p != null and p.cards.has(cv.card_id)
	var current := int(session.snapshot.get("current_player", -1))
	var targeting := p != null and not p.players.is_empty()
	for seat in seat_views:
		var v: SeatView = seat_views[seat]
		v.set_state(seat == current, p != null and p.players.has(seat), selected_players.has(seat), targeting)
	confirm_btn.disabled = not _current_response_valid()
	confirm_btn.text = _confirm_label(p)


func _confirm_label(p: Prompt) -> String:
	if p == null:
		return "Confirm"
	if not selected_players.is_empty():
		return "Target " + ", ".join(selected_players.map(func(s): return _name(s)))
	if not selected_cards.is_empty():
		var names := selected_cards.map(func(c): return defs.get(session.card_info(c).get("def", ""), {}).get("name", "card"))
		match p.kind:
			Prompt.KIND_PLAY:
				return "Play " + names[0]
			_:
				if p.data.get("discard", false) or p.title.begins_with("Discard"):
					return "Discard %d" % selected_cards.size() if selected_cards.size() > 1 else "Discard " + names[0]
				return "Use " + names[0] if selected_cards.size() == 1 else "Confirm %d cards" % selected_cards.size()
	match p.kind:
		Prompt.KIND_PLAY:
			return "Tap a card"
		Prompt.KIND_CHOOSE_PLAYERS:
			return "Tap a player"
		_:
			return "Tap a card"


func _help_for(p: Prompt) -> String:
	match p.kind:
		Prompt.KIND_PLAY:
			return "Tap a card to read it. Gold-framed cards can be played now: tap one, then press Play. End turn when you are done."
		Prompt.KIND_CHOOSE_PLAYERS:
			var n := "a player" if p.max_players <= 1 else "%d-%d players" % [p.min_players, p.max_players]
			return "Tap %s at the top (gold frames are valid), then confirm." % n
		Prompt.KIND_CHOOSE_CARDS:
			if p.data.has("of_player"):
				return "These belong to %s. Face-down ones are their hand. Tap one, then confirm." % p.data.get("of_player_name", "that player")
			if p.min_cards == p.max_cards and p.min_cards > 1:
				return "Tap %d cards, then confirm." % p.min_cards
			if p.min_cards == 0 and p.can_pass:
				return "Tap a gold-framed card and confirm to use it, or Pass."
			return "Tap a card, then confirm."
		Prompt.KIND_CONFIRM, Prompt.KIND_CHOOSE_OPTION:
			return "Choose one of the options."
	return ""


# --- events: log + animation ----------------------------------------------------------------

func _name(seat: int) -> String:
	if seat < 0:
		return "the heavens"
	if seat == session.my_seat:
		return "You"
	return session.player_info(seat).get("name", "seat %d" % seat)


func _card_name(cid: int) -> String:
	var info := session.card_info(cid)
	var d: Dictionary = defs.get(info.get("def", ""), {})
	if d.is_empty():
		return "a card"
	return "%s %s%s" % [d["name"], CardView.SUIT_GLYPH.get(info.get("suit", ""), ""), CardView.RANKS[int(info.get("rank", 0))]]


func _info(cid: int) -> Dictionary:
	var i := session.card_info(cid)
	if not i.has("id"):
		i["id"] = cid
	return i


func _on_event(ev: Dictionary) -> void:
	var t: String = ev["type"]
	match t:
		"sgs_roles":
			var parts := []
			for role in ["king", "loyalist", "rebel", "spy"]:
				if ev["counts"].has(role):
					parts.append("%d %s" % [int(ev["counts"][role]), role])
			_log("[b]Roles:[/b] %s. Only the king is revealed. Rebels win if the king dies; the king's side wins when all rebels and the spy are dead; the spy wins by being the last one standing with the king." % ", ".join(parts))
		"sgs_turn":
			_log("[b]— %s's turn —[/b]" % _name(ev["player"]))
			var who := _name(ev["player"])
			fx.enqueue(func(): await fx.banner("%s turn" % ("Your" if who == "You" else who + "'s")))
		"sgs_card_used":
			var as_name: String = defs.get(ev["as"], {}).get("name", ev["as"])
			var tg: Array = ev.get("targets", [])
			var who: int = ev["player"]
			var cid: int = ev["card"]
			var s := "%s play%s %s" % [_name(who), "" if who == session.my_seat else "s", _card_name(cid)]
			if as_name != defs.get(session.card_info(cid).get("def", ""), {}).get("name", ""):
				s += " as %s" % as_name
			if not tg.is_empty():
				s += " → " + ", ".join(tg.map(func(x): return _name(int(x))))
			_log(s)
			var info := _info(cid)
			var caption := s
			var from := _card_pos(cid, who)
			fx.enqueue(func():
				center_caption.text = caption
				await fx.fly_card(info, from, _center_pos(), 0.4, 0.35 if tg.is_empty() else 0.1, 1.0, 0.4)
			)
			for x in tg:
				var target := int(x)
				if target == who:
					continue
				fx.enqueue(func(): await fx.dash(info, _center_pos(), _seat_pos(target)))
		"sgs_damage":
			var amount := int(ev["amount"])
			var target := int(ev["target"])
			_log("[color=#ff7070]%s take%s %d %sdamage from %s (HP %d)[/color]" % [_name(target), "" if target == session.my_seat else "s", amount, "" if ev["nature"] == "none" else ev["nature"] + " ", _name(ev["source"]), ev["hp"]])
			var color := Color(1.0, 0.3, 0.2)
			if ev["nature"] == "fire":
				color = Color(1.0, 0.55, 0.1)
			elif ev["nature"] == "thunder":
				color = Color(0.6, 0.5, 1.0)
			fx.enqueue(func():
				var v := _seat_view(target)
				if v != null:
					v.shake(12.0)
					v.flash(color)
				await fx.float_text(_seat_pos(target), "-%d" % amount, color, 44)
			)
		"sgs_heal":
			var target := int(ev["player"])
			_log("[color=#80e080]%s recover%s %d HP (HP %d)[/color]" % [_name(target), "" if target == session.my_seat else "s", ev["amount"], ev["hp"]])
			fx.enqueue(func():
				var v := _seat_view(target)
				if v != null:
					v.flash(Color(0.3, 1.0, 0.4))
				await fx.float_text(_seat_pos(target), "+%d" % int(ev["amount"]), Color(0.4, 1.0, 0.5), 40)
			)
		"sgs_strike_dodged":
			var target := int(ev["target"])
			_log("%s dodge%s" % [_name(target), "" if target == session.my_seat else "s"])
			fx.enqueue(func(): await fx.float_text(_seat_pos(target), "Dodged!", Color(0.6, 0.9, 1.0), 34))
		"sgs_strike_no_effect", "sgs_trick_no_effect":
			var target := int(ev["target"])
			_log("No effect on %s" % _name(target))
			fx.enqueue(func(): await fx.float_text(_seat_pos(target), "No effect", Color(0.8, 0.8, 0.8), 30))
		"sgs_dying":
			var target := int(ev["player"])
			_log("[color=orange]%s %s dying![/color]" % [_name(target), "are" if target == session.my_seat else "is"])
			fx.enqueue(func():
				var v := _seat_view(target)
				if v != null:
					v.flash(Color(1.0, 0.5, 0.0), 0.8)
				await fx.float_text(_seat_pos(target), "Dying!", Color(1.0, 0.6, 0.2), 40)
			)
		"sgs_death":
			var target := int(ev["player"])
			_log("[b]%s die%s (%s)[/b]" % [_name(target), "" if target == session.my_seat else "s", ev["role"]])
			fx.enqueue(func(): await fx.banner("%s %s dead — %s" % [_name(target), "are" if target == session.my_seat else "is", str(ev["role"]).capitalize()], Color(0.9, 0.3, 0.3)))
		"sgs_negated":
			_log("%s is negated" % _card_name(ev["card"]))
			fx.enqueue(func(): await fx.float_text(_center_pos(), "Negated!", Color(1.0, 0.8, 0.3), 38))
		"sgs_judgement":
			var cid: int = ev["card"]
			_log("%s judge%s: %s" % [_name(ev["player"]), "" if int(ev["player"]) == session.my_seat else "s", _card_name(cid)])
			var info := _info(cid)
			var reason: String = str(ev.get("reason", "")).capitalize()
			fx.enqueue(func():
				center_caption.text = "Judgement (%s): %s" % [reason, _card_name(cid)]
				await fx.fly_card(info, _deck_pos(), _center_pos(), 0.35, 0.6, 1.0, 1.5)
			)
		"sgs_equipped":
			var who: int = int(ev["player"])
			_log("%s equip%s %s" % [_name(who), "" if who == session.my_seat else "s", _card_name(ev["card"])])
		"sgs_skill":
			var who: int = int(ev["player"])
			_log("%s use%s %s" % [_name(who), "" if who == session.my_seat else "s", ev["skill"]])
			fx.enqueue(func(): await fx.float_text(_seat_pos(who), str(ev["skill"]).capitalize(), Color(0.9, 0.8, 1.0), 30))
		"sgs_phase_skipped":
			_log("%s skip%s the %s phase" % [_name(ev["player"]), "" if int(ev["player"]) == session.my_seat else "s", ev["phase"]])
		"sgs_reshuffle":
			_log("The discard pile is shuffled into the deck")
		"cards_moved":
			var why: String = ev.get("reason", {}).get("why", "")
			if why == "draw":
				var who := int(ev["reason"]["by"])
				var count: int = ev["moves"].size()
				_log("%s draw%s %d" % [_name(who), "" if who == session.my_seat else "s", count])
				fx.enqueue(func():
					for i in mini(count, 3):
						fx.fly_card({"id": -1}, _deck_pos(), _seat_pos(who), 0.3, 0.0, 0.5)
						await fx.wait(0.08)
					await fx.wait(0.25)
				)
			elif why == "discard":
				_log("%s discard%s %s" % [_name(ev["reason"]["by"]), "" if int(ev["reason"]["by"]) == session.my_seat else "s", ", ".join(ev["moves"].map(func(m): return _card_name(int(m["card"]))))])


func _seat_view(seat: int) -> SeatView:
	if seat == session.my_seat:
		return my_seat_view
	return seat_views.get(seat, null)


func _log(text: String) -> void:
	log_lines.append(text)
	log_box.append_text(text + "\n")


func _on_game_over(result: Dictionary) -> void:
	game.last_result = result
	var winners: Array = result.get("winners", [])
	var side := str(result.get("winner", "?")).capitalize()
	overlay_label.text = "%s side wins!\n%s" % [side, ", ".join(winners.map(func(w): return _name(int(w))))]
	overlay.visible = true
	_set_prompt(null)
	pass_btn.visible = false
	fx.enqueue(func(): await fx.banner("%s side wins!" % side))


func _leave() -> void:
	game.clear_session()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
