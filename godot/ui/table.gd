extends Control
## The table: opponents on top, log + prompt in the middle, my hand at the
## bottom. Everything is built from the session's filtered snapshot, so the
## same scene works for local, host and remote-client sessions.

@onready var game: Node = get_node("/root/Game")
var session: GameSession
var defs: Dictionary = {}          ## def id -> dict (names/text) for display

var seats_row: HBoxContainer
var seat_panels: Dictionary = {}   ## seat -> Button
var log_box: RichTextLabel
var prompt_title: Label
var prompt_help: Label
var card_info: Label
var option_row: HFlowContainer
var choice_row: HBoxContainer      ## prompt cards not in my hand (other players' cards, harvest pool)
var hand_row: HBoxContainer
var my_info: Label
var my_equip: Label
var confirm_btn: Button
var pass_btn: Button
var lobby_panel: PanelContainer
var lobby_list: Label
var start_btn: Button
var overlay: Label

var selected_cards: Array[int] = []
var selected_players: Array[int] = []
var log_lines: Array[String] = []


func _ready() -> void:
	session = game.session
	if session == null:
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")
		return
	for d in SgsRules.new().create_defs().values():
		defs[String(d.id)] = d.to_dict()
	_build()
	session.lobby_changed.connect(_on_lobby)
	session.game_started.connect(func(): lobby_panel.visible = false)
	session.synced.connect(_on_sync)
	session.event_received.connect(_on_event)
	session.prompt_received.connect(_on_prompt)
	session.waiting_for.connect(_on_waiting)
	session.game_over.connect(_on_game_over)
	session.error.connect(func(m): _log("[color=red]%s[/color]" % m))
	if not session.snapshot.is_empty():
		_on_sync(session.snapshot)
	if session.pending != null:
		_on_prompt(session.pending)
	lobby_panel.visible = session is NetSession and session.snapshot.is_empty()
	if session is NetSession:
		_on_lobby(session.lobby)


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var top_scroll := ScrollContainer.new()
	top_scroll.custom_minimum_size.y = 165
	top_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	top_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(top_scroll)
	seats_row = HBoxContainer.new()
	seats_row.add_theme_constant_override("separation", 8)
	top_scroll.add_child(seats_row)

	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(middle)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.add_theme_font_size_override("normal_font_size", 19)
	log_box.add_theme_font_size_override("bold_font_size", 19)
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_box.size_flags_stretch_ratio = 1.2
	middle.add_child(log_box)
	var prompt_box := VBoxContainer.new()
	prompt_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(prompt_box)
	prompt_title = Label.new()
	prompt_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_title.add_theme_font_size_override("font_size", 27)
	prompt_box.add_child(prompt_title)
	prompt_help = Label.new()
	prompt_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_help.add_theme_color_override("font_color", Color(0.85, 0.85, 0.75))
	prompt_box.add_child(prompt_help)
	card_info = Label.new()
	card_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_info.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	prompt_box.add_child(card_info)
	option_row = HFlowContainer.new()
	prompt_box.add_child(option_row)
	var choice_scroll := ScrollContainer.new()
	choice_scroll.custom_minimum_size.y = 0
	choice_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choice_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	prompt_box.add_child(choice_scroll)
	choice_row = HBoxContainer.new()
	choice_scroll.add_child(choice_row)
	var btn_row := HBoxContainer.new()
	prompt_box.add_child(btn_row)
	confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(220, 64)
	confirm_btn.pressed.connect(_on_confirm)
	btn_row.add_child(confirm_btn)
	pass_btn = Button.new()
	pass_btn.text = "Pass"
	pass_btn.custom_minimum_size = Vector2(160, 64)
	pass_btn.pressed.connect(_on_pass)
	btn_row.add_child(pass_btn)
	var leave_btn := Button.new()
	leave_btn.text = "Leave"
	leave_btn.custom_minimum_size = Vector2(110, 64)
	leave_btn.pressed.connect(_leave)
	btn_row.add_child(leave_btn)

	var bottom := VBoxContainer.new()
	root.add_child(bottom)
	my_info = Label.new()
	my_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom.add_child(my_info)
	my_equip = Label.new()
	bottom.add_child(my_equip)
	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size.y = 176
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bottom.add_child(hand_scroll)
	hand_row = HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 6)
	hand_scroll.add_child(hand_row)

	lobby_panel = PanelContainer.new()
	lobby_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(lobby_panel)
	var lv := VBoxContainer.new()
	lobby_panel.add_child(lv)
	var lt := Label.new()
	lt.text = "Lobby — waiting for players"
	lv.add_child(lt)
	lobby_list = Label.new()
	lv.add_child(lobby_list)
	start_btn = Button.new()
	start_btn.text = "Start game"
	start_btn.pressed.connect(func(): session.start_game({"decks": ["standard", "expansion"]}))
	lv.add_child(start_btn)

	overlay = Label.new()
	overlay.visible = false
	overlay.add_theme_font_size_override("font_size", 36)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(overlay)
	_set_prompt(null)


# --- lobby ---------------------------------------------------------------------

func _on_lobby(list: Array) -> void:
	var lines := []
	for p in list:
		lines.append("Seat %d: %s%s" % [int(p["seat"]) + 1, p["name"], " (bot)" if p["is_bot"] else ""])
	lobby_list.text = "\n".join(lines)
	start_btn.visible = session.is_host
	start_btn.disabled = list.size() < 2


# --- state -----------------------------------------------------------------------

func _on_sync(snap: Dictionary) -> void:
	_render_seats(snap)
	_render_me(snap)


func _render_seats(snap: Dictionary) -> void:
	for c in seats_row.get_children():
		c.queue_free()
	seat_panels.clear()
	var me := session.my_seat
	var players: Array = snap.get("players", [])
	var n := players.size()
	# Show seats in turn order starting after me so neighbours are adjacent.
	for i in range(1, n):
		var p: Dictionary = players[(me + i) % n]
		var seat := int(p["id"])
		var b := Button.new()
		b.custom_minimum_size = Vector2(250, 155)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = _seat_text(snap, p)
		b.disabled = not p["alive"]
		if seat == int(snap.get("current_player", -1)):
			b.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		b.pressed.connect(_on_seat_pressed.bind(seat))
		seats_row.add_child(b)
		seat_panels[seat] = b
	_refresh_selection_styles()


func _seat_text(snap: Dictionary, p: Dictionary) -> String:
	var hero: Dictionary = _hero_of(snap, int(p["id"]))
	var lines := ["%s%s" % [p["name"], "  [%s]" % p["role"] if p["role"] != "" else ""]]
	lines.append("%s  ♥ %d/%d" % [hero.get("name", ""), int(p["hp"]), int(p["max_hp"])])
	var hand_n: int = snap["zones"].get("hand:%d" % int(p["id"]), {}).get("cards", []).size()
	lines.append("Hand: %d" % hand_n)
	lines.append("Equip: " + _zone_names(snap, "equip:%d" % int(p["id"])))
	var j := _zone_names(snap, "judge:%d" % int(p["id"]))
	if j != "":
		lines.append("Judge: " + j)
	if not p["alive"]:
		lines.append("(dead)")
	return "\n".join(lines)


## Hero data keyed by seat; keys are ints in-process and strings after JSON transport.
func _hero_of(snap: Dictionary, seat: int) -> Dictionary:
	var heroes: Dictionary = snap.get("vars", {}).get("heroes", {})
	return heroes.get(seat, heroes.get(str(seat), {}))


func _zone_names(snap: Dictionary, zid: String) -> String:
	var names := []
	for cid in snap["zones"].get(zid, {}).get("cards", []):
		var info := session.card_info(int(cid))
		names.append(defs.get(info.get("def", ""), {}).get("name", "?"))
	return ", ".join(names)


func _render_me(snap: Dictionary) -> void:
	var p := session.player_info(session.my_seat)
	if p.is_empty():
		return
	var hero: Dictionary = _hero_of(snap, session.my_seat)
	my_info.text = "You: %s  [%s]  %s  ♥ %d/%d   %s" % [p["name"], p["role"], hero.get("name", ""), int(p["hp"]), int(p["max_hp"]),
		"  |  ".join(hero.get("skills", []).map(func(s): return s["label"].split(":")[0]))]
	my_info.tooltip_text = "\n".join(hero.get("skills", []).map(func(s): return s["label"]))
	my_equip.text = "Equipment: " + _zone_names(snap, "equip:%d" % session.my_seat) + "    Judgement: " + _zone_names(snap, "judge:%d" % session.my_seat)
	for c in hand_row.get_children():
		c.queue_free()
	for cid in snap["zones"].get("hand:%d" % session.my_seat, {}).get("cards", []):
		var cb := CardButton.new()
		cb.setup(int(cid), session.card_info(int(cid)), defs)
		cb.pressed.connect(_on_card_pressed.bind(int(cid)))
		hand_row.add_child(cb)
	_refresh_selection_styles()


# --- prompts ---------------------------------------------------------------------

func _on_prompt(p: Prompt) -> void:
	selected_cards.clear()
	selected_players.clear()
	_set_prompt(p)


func _on_waiting(seat: int, title: String) -> void:
	_set_prompt(null)
	var who: String = session.player_info(seat).get("name", "seat %d" % seat)
	prompt_title.text = "Waiting for %s… (%s)" % [who, title]


func _set_prompt(p: Prompt) -> void:
	for c in option_row.get_children():
		c.queue_free()
	for c in choice_row.get_children():
		c.queue_free()
	if p == null:
		prompt_title.text = ""
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
		b.text = o["label"]
		b.custom_minimum_size.y = 48
		b.pressed.connect(func(): session.submit(p.id, {"option": o["id"]}))
		option_row.add_child(b)
	# Cards that are not in my hand (another player's cards, a revealed pool).
	var my_hand: Array = session.snapshot.get("zones", {}).get("hand:%d" % session.my_seat, {}).get("cards", [])
	for cid in p.cards:
		if my_hand.has(cid):
			continue
		var cb := CardButton.new()
		cb.setup(cid, session.card_info(cid), defs)
		cb.pressed.connect(_on_card_pressed.bind(cid))
		choice_row.add_child(cb)
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
		for cb in row.get_children():
			if cb is CardButton:
				cb.selected_card = selected_cards.has(cb.card_id)
				cb.playable = p != null and p.cards.has(cb.card_id)
	for seat in seat_panels:
		var b: Button = seat_panels[seat]
		var selectable := p != null and p.players.has(seat)
		b.disabled = not selectable and p != null and not p.players.is_empty()
		b.modulate = Color(0.7, 1.0, 0.7) if selected_players.has(seat) else (Color(1, 1, 0.85) if selectable else Color.WHITE)
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
			return "Tap a card to read it. Highlighted cards can be played now: tap one, then press Play. Skills appear as buttons. End turn when you are done."
		Prompt.KIND_CHOOSE_PLAYERS:
			var n := "a player" if p.max_players <= 1 else "%d-%d players" % [p.min_players, p.max_players]
			return "Tap %s in the row above (highlighted ones are valid), then confirm." % n
		Prompt.KIND_CHOOSE_CARDS:
			if p.data.has("of_player"):
				return "Cards below belong to %s. Face-down ones are their hand. Tap one, then confirm." % p.data.get("of_player_name", "that player")
			if p.min_cards == p.max_cards and p.min_cards > 1:
				return "Tap %d cards, then confirm." % p.min_cards
			if p.min_cards == 0 and p.can_pass:
				return "Tap a highlighted card and confirm to use it, or Pass."
			return "Tap a card, then confirm."
		Prompt.KIND_CONFIRM, Prompt.KIND_CHOOSE_OPTION:
			return "Choose one of the options."
	return ""


# --- events / log ------------------------------------------------------------------

func _name(seat: int) -> String:
	if seat < 0:
		return "the heavens"
	return session.player_info(seat).get("name", "seat %d" % seat)


func _card_name(cid: int) -> String:
	var info := session.card_info(cid)
	var d: Dictionary = defs.get(info.get("def", ""), {})
	if d.is_empty():
		return "a card"
	return "%s %s%s" % [d["name"], CardButton.SUIT_GLYPH.get(info.get("suit", ""), ""), CardButton.RANKS[int(info.get("rank", 0))]]


func _on_event(ev: Dictionary) -> void:
	var t: String = ev["type"]
	match t:
		"sgs_roles":
			var parts := []
			for role in ["king", "loyalist", "rebel", "spy"]:
				if ev["counts"].has(role):
					parts.append("%d %s" % [int(ev["counts"][role]), role])
			_log("[b]Roles in this game:[/b] %s. Only the king is revealed. Rebels win if the king dies; the king's side wins when all rebels and the spy are dead; the spy wins by being the last one standing with the king." % ", ".join(parts))
		"sgs_turn":
			_log("[b]— %s's turn —[/b]" % _name(ev["player"]))
		"sgs_card_used":
			var as_name: String = defs.get(ev["as"], {}).get("name", ev["as"])
			var tg: Array = ev.get("targets", [])
			var s := "%s plays %s" % [_name(ev["player"]), _card_name(ev["card"])]
			if as_name != defs.get(session.card_info(ev["card"]).get("def", ""), {}).get("name", ""):
				s += " as %s" % as_name
			if not tg.is_empty():
				s += " → " + ", ".join(tg.map(func(x): return _name(int(x))))
			_log(s)
		"sgs_damage":
			_log("[color=red]%s takes %d %sdamage from %s (HP %d)[/color]" % [_name(ev["target"]), ev["amount"], "" if ev["nature"] == "none" else ev["nature"] + " ", _name(ev["source"]), ev["hp"]])
		"sgs_heal":
			_log("[color=green]%s recovers %d HP (HP %d)[/color]" % [_name(ev["player"]), ev["amount"], ev["hp"]])
		"sgs_strike_dodged":
			_log("%s dodges" % _name(ev["target"]))
		"sgs_dying":
			_log("[color=orange]%s is dying![/color]" % _name(ev["player"]))
		"sgs_death":
			_log("[b]%s dies (%s)[/b]" % [_name(ev["player"]), ev["role"]])
		"sgs_negated":
			_log("%s is negated" % _card_name(ev["card"]))
		"sgs_judgement":
			_log("%s judges: %s" % [_name(ev["player"]), _card_name(ev["card"])])
		"sgs_equipped":
			_log("%s equips %s" % [_name(ev["player"]), _card_name(ev["card"])])
		"sgs_skill":
			_log("%s uses %s" % [_name(ev["player"]), ev["skill"]])
		"sgs_phase_skipped":
			_log("%s skips the %s phase" % [_name(ev["player"]), ev["phase"]])
		"cards_moved":
			var why: String = ev.get("reason", {}).get("why", "")
			if why == "draw":
				_log("%s draws %d" % [_name(ev["reason"]["by"]), ev["moves"].size()])
			elif why == "discard":
				_log("%s discards %s" % [_name(ev["reason"]["by"]), ", ".join(ev["moves"].map(func(m): return _card_name(int(m["card"]))))])
		"game_over":
			pass


func _log(text: String) -> void:
	log_lines.append(text)
	log_box.append_text(text + "\n")


func _on_game_over(result: Dictionary) -> void:
	game.last_result = result
	var winners: Array = result.get("winners", [])
	overlay.text = "%s side wins!\n%s" % [str(result.get("winner", "?")).capitalize(), ", ".join(winners.map(func(w): return _name(int(w))))]
	overlay.visible = true
	_set_prompt(null)
	pass_btn.visible = false


func _leave() -> void:
	game.clear_session()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
