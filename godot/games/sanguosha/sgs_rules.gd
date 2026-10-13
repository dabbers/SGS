class_name SgsRules
extends GameRules
## Sanguosha (三国杀) rules on top of CardEngine: roles, heroes, the turn
## structure, distance, the Strike / damage / dying pipeline and win checks.
##
## Config keys (all optional):
##   players: int or Array[String]      names (default 4 seats)
##   bots: Array[int]                   seats driven by bots
##   decks: Array[String]               deck data files (default ["standard"])
##   heroes: Dictionary {seat: hero_id} fixed heroes, otherwise random
##   include_unimplemented: bool        keep cards whose effect is not written yet
##   test_hands: {seat: [def_id]}       exact opening hand for a seat (tests)
##   first_draw: bool                   false = first player skips the draw phase (tests)
##   max_turns: int                     safety stop (default 400) -> draw

const DEFAULT_MAX_HP := 4
const VIRTUAL_CARD_ID := -1

var virtual_rules: Array = []   ## [{player, as, filter}]
var heroes_by_seat: Dictionary = {}
var _virtual_card := Card.new()


func id() -> StringName:
	return &"sanguosha"


func create_defs() -> Dictionary:
	var defs := {}
	SgsCardsBasic.build(defs)
	SgsCardsTricks.build(defs)
	SgsCardsDelayed.build(defs)
	SgsCardsEquipment.build(defs)
	return defs


# --- setup -----------------------------------------------------------------

func setup(e: CardEngine, cfg: Dictionary) -> void:
	_virtual_card.id = VIRTUAL_CARD_ID
	var names: Array = []
	var pcfg = cfg.get("players", 4)
	if pcfg is int:
		for i in int(pcfg):
			names.append("Player %d" % (i + 1))
	else:
		names = Array(pcfg)
	assert(names.size() >= 2 and names.size() <= 8, "Sanguosha needs 2-8 players")
	var bots: Array = cfg.get("bots", [])
	var st := e.state
	st.add_zone(Zone.new(Sgs.ZONE_DRAW, &"draw", -1, Zone.Visibility.HIDDEN))
	st.add_zone(Zone.new(Sgs.ZONE_DISCARD, &"discard", -1, Zone.Visibility.PUBLIC))
	for i in names.size():
		var p := st.add_player(names[i], bots.has(i))
		st.add_zone(Zone.new(Sgs.hand(p.id), &"hand", p.id, Zone.Visibility.OWNER))
		st.add_zone(Zone.new(Sgs.equip(p.id), &"equipment", p.id, Zone.Visibility.PUBLIC))
		st.add_zone(Zone.new(Sgs.judge(p.id), &"judgement", p.id, Zone.Visibility.PUBLIC))

	# Deck
	var include_unimpl: bool = cfg.get("include_unimplemented", false)
	for deck_name in cfg.get("decks", ["standard"]):
		var path := "res://games/sanguosha/data/deck_%s.json" % deck_name
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(data != null, "deck file missing or invalid: " + path)
		for row in data["cards"]:
			var def_id := StringName(row["def"])
			if not e.defs.has(def_id):
				push_warning("deck references unknown card def: %s" % def_id)
				continue
			if not include_unimpl and not e.defs[def_id].implemented:
				continue
			e.create_card(def_id, StringName(row["suit"]), int(row["rank"]), Sgs.ZONE_DRAW)
	e.rng.shuffle(st.zone(Sgs.ZONE_DRAW).cards)

	# Roles
	var roles := Sgs.role_set(names.size())
	e.rng.shuffle(roles)
	for i in names.size():
		var p := st.player(i)
		p.role = roles[i]
		p.role_revealed = p.role == Sgs.ROLE_KING

	# Heroes
	var pool := SgsHeroes.all()
	e.rng.shuffle(pool)
	var fixed: Dictionary = cfg.get("heroes", {})
	for i in names.size():
		var p := st.player(i)
		var hero: SgsHeroes.SgsHero = null
		if fixed.has(i) or fixed.has(str(i)):
			hero = SgsHeroes.by_id(StringName(fixed.get(i, fixed.get(str(i), ""))))
		if hero == null:
			hero = pool.pop_back() if not pool.is_empty() else null
		if hero != null:
			p.hero_id = hero.id
			p.max_hp = hero.hp
			heroes_by_seat[i] = hero
		else:
			p.max_hp = DEFAULT_MAX_HP
		if p.role == Sgs.ROLE_KING and names.size() > 2:
			p.max_hp += 1
		p.hp = p.max_hp
		st.vars["heroes"] = st.vars.get("heroes", {})
		st.vars["heroes"][i] = hero.to_dict() if hero != null else {}
	st.vars["max_turns"] = int(cfg.get("max_turns", 400))

	# Game-level triggers
	e.register_trigger(Trigger.make([&"cards_moved"], -1, "equipment cleanup", func(eng: CardEngine, _t, ctx):
		for m in ctx["moves"]:
			if String(m["from"]).begins_with("equip:"):
				eng.unregister_triggers_of_card(int(m["card"]))
	))
	for i in names.size():
		if heroes_by_seat.has(i):
			heroes_by_seat[i].apply(e, self, i)

	# Opening hands (tests may fix a seat's hand with cfg.test_hands = {seat: [def_id, ...]})
	var fixed_hands: Dictionary = cfg.get("test_hands", {})
	for i in names.size():
		if fixed_hands.has(i) or fixed_hands.has(str(i)):
			for def_id in fixed_hands.get(i, fixed_hands.get(str(i), [])):
				_take_from_draw(e, i, StringName(def_id))
		else:
			_draw_silent(e, i, 4)
	for i in names.size():
		e.emit_event(&"sgs_seat", {"player": i, "role": String(st.player(i).role) if st.player(i).role_revealed else "", "hero": String(st.player(i).hero_id), "hp": st.player(i).hp})


func _take_from_draw(e: CardEngine, pid: int, def_id: StringName) -> void:
	for cid in e.state.zone(Sgs.ZONE_DRAW).cards:
		if e.card(cid).def_id == def_id:
			e.state.zone(Sgs.ZONE_DRAW).cards.erase(cid)
			e.state.zone(Sgs.hand(pid)).cards.append(cid)
			e.card(cid).zone = Sgs.hand(pid)
			return
	push_warning("test_hands: no %s left in draw pile" % def_id)


func _draw_silent(e: CardEngine, pid: int, n: int) -> void:
	# Opening hands: no triggers, just one move event.
	var ids := e.top_cards(Sgs.ZONE_DRAW, n)
	var dest := e.state.zone(Sgs.hand(pid))
	for cid in ids:
		e.state.zone(Sgs.ZONE_DRAW).cards.erase(cid)
		dest.cards.append(cid)
		e.card(cid).zone = dest.id
		e.card(cid).face_up = false
	e.emit_event(&"cards_moved", {"moves": ids.map(func(c): return {"card": c, "from": "draw", "to": String(dest.id)}), "card_ids": ids, "reason": {"why": "deal"}})


# --- main loop -------------------------------------------------------------

func play(e: CardEngine) -> Dictionary:
	var pid := 0
	for p in e.state.players:
		if p.role == Sgs.ROLE_KING:
			pid = p.id
	while not e.is_over:
		await run_turn(e, pid)
		if e.is_over:
			break
		if e.state.turn_number >= int(e.state.vars["max_turns"]):
			return {"winner": "", "winners": [], "reason": "turn limit"}
		pid = e.state.next_alive(pid)
	return e.result


func run_turn(e: CardEngine, pid: int) -> void:
	var st := e.state
	var p := st.player(pid)
	st.current_player = pid
	st.turn_number += 1
	e.emit_event(&"sgs_turn", {"player": pid, "turn": st.turn_number})
	await e.fire(Sgs.T_TURN_START, {"player": pid})
	for phase in Sgs.PHASES:
		if e.is_over or not p.alive:
			break
		if p.flags.get("skip_" + String(phase), false):
			e.emit_event(&"sgs_phase_skipped", {"player": pid, "phase": String(phase)})
			continue
		st.phase = phase
		e.emit_event(&"sgs_phase", {"player": pid, "phase": String(phase)})
		await e.fire(Sgs.T_PHASE_START, {"player": pid, "phase": phase})
		if p.flags.get("skip_" + String(phase), false):
			continue
		match phase:
			Sgs.PHASE_JUDGEMENT:
				await _judgement_phase(e, pid)
			Sgs.PHASE_DRAW:
				if st.turn_number == 1 and not e.config.get("first_draw", true):
					continue
				var ctx := await e.fire(Sgs.T_DRAW_COUNT, {"player": pid, "count": 2})
				await draw_cards(e, pid, int(ctx["count"]))
			Sgs.PHASE_PLAY:
				await _play_phase(e, pid)
			Sgs.PHASE_DISCARD:
				await _discard_phase(e, pid)
			Sgs.PHASE_END:
				pass
		if e.is_over or not p.alive:
			break
		await e.fire(Sgs.T_PHASE_END, {"player": pid, "phase": phase})
	st.phase = &""
	await e.fire(Sgs.T_TURN_END, {"player": pid})
	for k in Sgs.TURN_FLAGS:
		p.flags.erase(k)
	p.flags.erase("rende_given")


func _judgement_phase(e: CardEngine, pid: int) -> void:
	var jz := e.state.zone(Sgs.judge(pid))
	var guard := 0
	while not jz.cards.is_empty() and e.state.player(pid).alive and not e.is_over and guard < 20:
		guard += 1
		var cid: int = jz.cards[-1]
		var c := e.card(cid)
		var def := e.def_of(cid) as SgsCardDef
		await e.move_cards([cid], CardEngine.ZONE_PROCESSING, {"why": "judge", "by": pid}, true)
		var src: int = int(c.attrs.get("source", -1))
		if await trick_effect(e, src, pid, c):
			await def.on_judgement(e, pid, c)
		if c.zone == CardEngine.ZONE_PROCESSING:
			await e.move_cards([cid], Sgs.ZONE_DISCARD, {"why": "resolved"})


func _play_phase(e: CardEngine, pid: int) -> void:
	var p := e.state.player(pid)
	var guard := 0
	while p.alive and not e.is_over and guard < 200:
		guard += 1
		var playable: Array[int] = []
		var hand := e.state.zone(Sgs.hand(pid)).cards
		for cid in hand:
			if not playable_as(e, pid, cid).is_empty():
				playable.append(cid)
		var options := []
		if heroes_by_seat.has(pid):
			options = heroes_by_seat[pid].active_skills(e, self, pid)
		var prompt := Prompt.play(pid, "Your play phase", playable, options)
		var resp := await e.ask(prompt)
		if resp.get("pass", false):
			return
		if resp.has("option") and resp["option"] != null:
			await heroes_by_seat[pid].use_skill(e, self, pid, String(resp["option"]))
			continue
		var cid: int = int(resp["cards"][0])
		var ways := playable_as(e, pid, cid)
		if ways.is_empty():
			continue
		var as_def: StringName = ways[0]
		if ways.size() > 1:
			var opts := ways.map(func(w): return {"id": String(w), "label": e.defs[w].name})
			var pick := await e.ask(Prompt.choose_option(pid, "Play %s as..." % e.def_of(cid).name, opts, true))
			if pick.get("pass", false):
				continue
			as_def = StringName(pick["option"])
		var def := e.defs[as_def] as SgsCardDef
		var spec := def.target_spec(e, pid, e.card(cid))
		var targets: Array = []
		if int(spec["max"]) > 0:
			var tp := Prompt.choose_players(pid, "%s: choose target(s)" % def.name, spec["candidates"], int(spec["min"]), int(spec["max"]), true)
			tp.data = {"card": cid, "harmful": def.harmful, "bot": "target"}
			var tr := await e.ask(tp)
			if tr.get("pass", false):
				continue
			targets = tr["players"]
		await use_card(e, pid, cid, targets, as_def)


func _discard_phase(e: CardEngine, pid: int) -> void:
	var hand := e.state.zone(Sgs.hand(pid)).cards
	var excess := hand.size() - max_hand(e, pid)
	if excess <= 0:
		return
	var resp := await e.ask(Prompt.choose_cards(pid, "Discard down to %d cards" % max_hand(e, pid), hand, excess, excess))
	await discard_cards(e, resp.get("cards", hand.slice(0, excess)), pid)


# --- queries ---------------------------------------------------------------

func others(e: CardEngine, pid: int) -> Array[int]:
	var out: Array[int] = []
	for q in e.state.alive_players():
		if q != pid:
			out.append(q)
	return out


func strikes_used(e: CardEngine, pid: int) -> int:
	return int(e.state.player(pid).flags.get("strikes_used", 0))


func strike_limit(e: CardEngine, pid: int) -> int:
	if e.state.player(pid).flags.get("unlimited_strikes", false) or has_equip(e, pid, &"crossbow"):
		return 999
	return 1


func max_hand(e: CardEngine, pid: int) -> int:
	return maxi(0, e.state.player(pid).hp + int(e.state.player(pid).flags.get("hand_bonus", 0)))


func has_equip(e: CardEngine, pid: int, def_id: StringName) -> bool:
	for c in e.state.cards_in(Sgs.equip(pid)):
		if c.def_id == def_id:
			return true
	return false


func equip_of(e: CardEngine, pid: int, subtype: StringName) -> Card:
	for c in e.state.cards_in(Sgs.equip(pid)):
		if e.defs[c.def_id].subtype == subtype:
			return c
	return null


func has_any_cards(e: CardEngine, pid: int, include_judge: bool = true) -> bool:
	if not e.state.zone(Sgs.hand(pid)).is_empty() or not e.state.zone(Sgs.equip(pid)).is_empty():
		return true
	return include_judge and not e.state.zone(Sgs.judge(pid)).is_empty()


func distance(e: CardEngine, a: int, b: int) -> int:
	if a == b:
		return 0
	var d := e.state.seat_distance(a, b)
	if equip_of(e, b, &"horse_plus") != null:
		d += 1
	if equip_of(e, a, &"horse_minus") != null:
		d -= 1
	return maxi(1, d)


func attack_range(e: CardEngine, pid: int) -> int:
	var w := equip_of(e, pid, &"weapon")
	var r := 1
	if w != null:
		r = (e.defs[w.def_id] as SgsCardsEquipment.Weapon).range
	return r + int(e.state.player(pid).flags.get("range_bonus", 0))


func in_attack_range(e: CardEngine, a: int, b: int) -> bool:
	return a != b and distance(e, a, b) <= attack_range(e, a)


func players_in_attack_range(e: CardEngine, pid: int) -> Array[int]:
	var out: Array[int] = []
	for q in others(e, pid):
		if in_attack_range(e, pid, q):
			out.append(q)
	return out


func strike_nature(e: CardEngine, card: Card) -> StringName:
	if card == null or card.id < 0:
		return Sgs.NATURE_NONE
	var d = e.defs[card.def_id]
	if d is SgsCardsBasic.Strike:
		return d.nature
	return Sgs.NATURE_NONE


# --- virtual cards (skills that let a card count as another) ---------------

func add_virtual_rule(pid: int, as_def: StringName, filter: Callable) -> void:
	virtual_rules.append({"player": pid, "as": as_def, "filter": filter})


func card_counts_as(e: CardEngine, pid: int, card: Card, as_def: StringName) -> bool:
	var def := e.defs[card.def_id] as CardDef
	if def.id == as_def or def.has_tag(as_def):
		return true
	for vr in virtual_rules:
		if vr["player"] == pid and vr["as"] == as_def and vr["filter"].call(e, card):
			return true
	return false


func cards_usable_as(e: CardEngine, pid: int, as_def: StringName) -> Array[int]:
	var out: Array[int] = []
	for cid in e.state.zone(Sgs.hand(pid)).cards:
		if card_counts_as(e, pid, e.card(cid), as_def):
			out.append(cid)
	return out


## Which defs can `cid` be played as right now in the play phase?
func playable_as(e: CardEngine, pid: int, cid: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var card := e.card(cid)
	var def := e.defs[card.def_id] as CardDef
	if def.implemented and def.can_play(e, pid, card):
		out.append(def.id)
	for vr in virtual_rules:
		if vr["player"] != pid or out.has(vr["as"]) or not vr["filter"].call(e, card):
			continue
		var vd := e.defs[vr["as"]] as CardDef
		if vd.can_play(e, pid, card):
			out.append(vr["as"])
	return out


# --- card use --------------------------------------------------------------

func use_card(e: CardEngine, pid: int, cid: int, targets: Array, as_def: StringName = &"") -> void:
	var card := e.card(cid)
	if as_def == &"":
		as_def = card.def_id
	var def := e.defs[as_def] as SgsCardDef
	await e.move_cards([cid], CardEngine.ZONE_PROCESSING, {"why": "use", "by": pid}, true)
	e.emit_event(&"sgs_card_used", {"player": pid, "card": cid, "card_ids": [cid], "as": String(as_def), "targets": targets.duplicate()})
	var ctx := {"player": pid, "card": cid, "as": as_def, "targets": targets.duplicate(), "cancelled": false}
	await e.fire(Sgs.T_CARD_USED, ctx)
	if not ctx["cancelled"]:
		await def.on_play(e, pid, card, ctx["targets"])
	await throw_processing(e)


## A card played in response (Dodge, Strike for Duel, Negate, Peach to save...).
func play_reactive(e: CardEngine, pid: int, cid: int, as_def: StringName) -> void:
	e.emit_event(&"sgs_card_used", {"player": pid, "card": cid, "card_ids": [cid], "as": String(as_def), "targets": [], "reactive": true})
	await e.move_cards([cid], Sgs.ZONE_DISCARD, {"why": "use", "by": pid}, true)


## Ask `pid` for a card usable as `as_def`. Armor may provide one via
## T_PROVIDE_CARD. Returns the Card, a placeholder (id -1) if provided by an
## effect, or null if the player did not / could not play one.
func ask_card_as(e: CardEngine, pid: int, as_def: StringName, title: String, data: Dictionary = {}, extra_ctx: Dictionary = {}) -> Card:
	if not e.state.player(pid).alive:
		return null
	var ctx := {"player": pid, "as": as_def, "provided": false}
	ctx.merge(extra_ctx)
	await e.fire(Sgs.T_PROVIDE_CARD, ctx)
	if ctx["provided"]:
		e.emit_event(&"sgs_card_provided", {"player": pid, "as": String(as_def)})
		return _virtual_card
	var usable := cards_usable_as(e, pid, as_def)
	if usable.is_empty():
		return null
	var p := Prompt.choose_cards(pid, title, usable, 0, 1, true)
	p.data = data.duplicate()
	p.data["as"] = String(as_def)
	var resp := await e.ask(p)
	if resp.get("pass", false) or resp.get("cards", []).is_empty():
		return null
	var cid: int = int(resp["cards"][0])
	var card := e.card(cid)
	await play_reactive(e, pid, cid, as_def)
	return card


func throw_processing(e: CardEngine) -> void:
	var left := e.state.zone(CardEngine.ZONE_PROCESSING).cards.duplicate()
	if not left.is_empty():
		await e.move_cards(left, Sgs.ZONE_DISCARD, {"why": "resolved"})


func draw_cards(e: CardEngine, pid: int, n: int) -> void:
	var ids: Array[int] = []
	for i in n:
		if e.state.zone(Sgs.ZONE_DRAW).is_empty():
			_reshuffle(e)
		if e.state.zone(Sgs.ZONE_DRAW).is_empty():
			break
		var top: int = e.state.zone(Sgs.ZONE_DRAW).cards[ids.size()] if ids.size() < e.state.zone(Sgs.ZONE_DRAW).size() else -1
		if top < 0:
			break
		ids.append(top)
	if ids.is_empty():
		return
	await e.move_cards(ids, Sgs.hand(pid), {"why": "draw", "by": pid})


func _reshuffle(e: CardEngine) -> void:
	var disc := e.state.zone(Sgs.ZONE_DISCARD)
	if disc.is_empty():
		return
	var ids := disc.cards.duplicate()
	e.rng.shuffle(ids)
	var draw := e.state.zone(Sgs.ZONE_DRAW)
	for cid in ids:
		disc.cards.erase(cid)
		draw.cards.append(cid)
		e.card(cid).zone = Sgs.ZONE_DRAW
		e.card(cid).face_up = false
	e.emit_event(&"sgs_reshuffle", {"count": ids.size()})


func discard_cards(e: CardEngine, ids: Array, by: int) -> void:
	await e.move_cards(ids, Sgs.ZONE_DISCARD, {"why": "discard", "by": by}, true)


## Reveal the top n cards of the draw pile into the processing zone.
func reveal_from_draw(e: CardEngine, n: int) -> Array[int]:
	if e.state.zone(Sgs.ZONE_DRAW).size() < n:
		_reshuffle(e)
	var ids := e.top_cards(Sgs.ZONE_DRAW, n)
	await e.move_cards(ids, CardEngine.ZONE_PROCESSING, {"why": "reveal"}, true)
	return ids


## Pick one card from another player's hand (blind), equipment or judgement area.
func choose_card_of(e: CardEngine, chooser: int, target: int, title: String, include_judge: bool = true) -> int:
	var pool: Array = e.state.zone(Sgs.hand(target)).cards + e.state.zone(Sgs.equip(target)).cards
	if include_judge:
		pool += e.state.zone(Sgs.judge(target)).cards
	if pool.is_empty():
		return -1
	var p := Prompt.choose_cards(chooser, title, pool, 1, 1)
	p.data = {"of_player": target, "blind_zone": String(Sgs.hand(target))}
	var resp := await e.ask(p)
	return int(resp.get("cards", [pool[0]])[0])


## Flip a judgement card. Returns the final card after T_JUDGE_AFTER.
func judge(e: CardEngine, pid: int, reason: String) -> Card:
	var ids := await reveal_from_draw(e, 1)
	if ids.is_empty():
		return _virtual_card
	var ctx := {"player": pid, "card": ids[0], "reason": reason}
	e.emit_event(&"sgs_judgement", {"player": pid, "card": ids[0], "card_ids": [ids[0]], "reason": reason})
	await e.fire(Sgs.T_JUDGE_AFTER, ctx)
	var c := e.card(int(ctx["card"]))
	if c.zone == CardEngine.ZONE_PROCESSING:
		await e.move_cards([c.id], Sgs.ZONE_DISCARD, {"why": "judgement"})
	return c


## Per-target trick resolution: armor immunities first, then the Negate chain.
## Returns true if the effect goes through.
func trick_effect(e: CardEngine, source: int, target: int, card: Card) -> bool:
	var ctx := {"source": source, "target": target, "card": card.id, "cancelled": false}
	await e.fire(Sgs.T_TRICK_TARGETED, ctx)
	if ctx["cancelled"]:
		e.emit_event(&"sgs_trick_no_effect", {"card": card.id, "target": target})
		return false
	var negated := false
	var guard := 0
	while guard < 10:
		guard += 1
		var who := await _ask_negate(e, card, target, negated)
		if who < 0:
			break
		negated = not negated
	if negated:
		e.emit_event(&"sgs_negated", {"card": card.id, "target": target})
	return not negated


func _ask_negate(e: CardEngine, trick: Card, target: int, negated: bool) -> int:
	var def := e.defs[trick.def_id] as SgsCardDef
	for pid in e.state.alive_from(e.state.current_player if e.state.current_player >= 0 else 0):
		var usable := cards_usable_as(e, pid, &"negate")
		if usable.is_empty():
			continue
		var title := "Negate the Negate on %s (%s)?" % [def.name, e.state.player(target).name] if negated else "Negate %s targeting %s?" % [def.name, e.state.player(target).name]
		var p := Prompt.choose_cards(pid, title, usable, 0, 1, true)
		p.data = {"bot": "negate", "target": target, "harmful": def.harmful, "negated": negated, "trick": trick.id}
		var resp := await e.ask(p)
		if resp.get("pass", false) or resp.get("cards", []).is_empty():
			continue
		await play_reactive(e, pid, int(resp["cards"][0]), &"negate")
		return pid
	return -1


# --- strike / damage / dying -----------------------------------------------

func resolve_strike(e: CardEngine, source: int, target: int, card: Card, nature: StringName, amount: int) -> void:
	if not e.state.player(target).alive:
		return
	var ctx := {"source": source, "target": target, "card": card.id, "nature": nature,
		"dodges_needed": 1, "ignore_armor": false, "cancelled": false}
	await e.fire(Sgs.T_STRIKE_USED, ctx)
	if ctx["cancelled"]:
		e.emit_event(&"sgs_strike_no_effect", {"source": source, "target": target, "card": card.id})
		return
	var dodged := true
	for i in int(ctx["dodges_needed"]):
		var d := await ask_card_as(e, target, &"dodge", "Dodge %s's Strike?" % e.state.player(source).name, {"bot": "accept"}, {"ignore_armor": ctx["ignore_armor"]})
		if d == null:
			dodged = false
			break
	if dodged:
		var dctx := {"source": source, "target": target, "card": card.id, "retry": -1, "force_hit": false}
		e.emit_event(&"sgs_strike_dodged", {"source": source, "target": target, "card": card.id})
		await e.fire(Sgs.T_STRIKE_DODGED, dctx)
		if int(dctx["retry"]) >= 0:
			var again := e.card(int(dctx["retry"]))
			await resolve_strike(e, source, target, again, strike_nature(e, again), 1)
			return
		if not dctx["force_hit"]:
			return
	var hctx := {"source": source, "target": target, "card": card.id, "nature": nature, "amount": amount, "skip_damage": false}
	await e.fire(Sgs.T_STRIKE_HIT, hctx)
	if not hctx["skip_damage"]:
		await damage(e, source, target, int(hctx["amount"]), nature, card.id)


func damage(e: CardEngine, source: int, target: int, amount: int, nature: StringName = Sgs.NATURE_NONE, card_id: int = -1) -> void:
	var p := e.state.player(target)
	if not p.alive or e.is_over:
		return
	var ctx := {"source": source, "target": target, "amount": amount, "nature": nature, "card": card_id, "cancelled": false}
	await e.fire(Sgs.T_DAMAGE_BEFORE, ctx)
	if ctx["cancelled"] or int(ctx["amount"]) <= 0:
		return
	p.hp -= int(ctx["amount"])
	e.emit_event(&"sgs_damage", {"source": source, "target": target, "amount": int(ctx["amount"]), "nature": String(nature), "card": card_id, "hp": p.hp})
	if p.hp <= 0:
		await dying(e, target, source)
	if not e.is_over:
		await e.fire(Sgs.T_DAMAGE_AFTER, ctx)


func heal(e: CardEngine, pid: int, n: int) -> void:
	var p := e.state.player(pid)
	if not p.alive:
		return
	var before := p.hp
	p.hp = mini(p.max_hp, p.hp + n)
	if p.hp != before:
		e.emit_event(&"sgs_heal", {"player": pid, "amount": p.hp - before, "hp": p.hp})


func lose_hp(e: CardEngine, pid: int, n: int) -> void:
	var p := e.state.player(pid)
	p.hp -= n
	e.emit_event(&"sgs_lose_hp", {"player": pid, "amount": n, "hp": p.hp})
	if p.hp <= 0:
		await dying(e, pid, -1)


func dying(e: CardEngine, pid: int, source: int) -> void:
	var p := e.state.player(pid)
	e.emit_event(&"sgs_dying", {"player": pid, "hp": p.hp})
	await e.fire(Sgs.T_DYING, {"player": pid, "source": source})
	var start := e.state.current_player if e.state.current_player >= 0 else pid
	for q in e.state.alive_from(start):
		while p.hp <= 0 and not e.is_over:
			var usable := cards_usable_as(e, q, &"peach")
			if q == pid:
				usable += cards_usable_as(e, q, &"wine")
			if usable.is_empty():
				break
			var title := "You are dying! Use a Peach or Wine?" if q == pid else "%s is dying. Give a Peach?" % p.name
			var pr := Prompt.choose_cards(q, title, usable, 0, 1, true)
			pr.data = {"bot": "rescue", "target": pid}
			var resp := await e.ask(pr)
			if resp.get("pass", false) or resp.get("cards", []).is_empty():
				break
			var cid: int = int(resp["cards"][0])
			var as_def := &"wine" if e.def_of(cid).has_tag(&"wine") else &"peach"
			await play_reactive(e, q, cid, as_def)
			await heal(e, pid, 1)
		if p.hp > 0:
			return
	await kill(e, pid, source)


func kill(e: CardEngine, pid: int, killer: int) -> void:
	var p := e.state.player(pid)
	if not p.alive:
		return
	p.alive = false
	p.role_revealed = true
	e.emit_event(&"sgs_death", {"player": pid, "killer": killer, "role": String(p.role)})
	e.unregister_triggers_of_player(pid)
	virtual_rules = virtual_rules.filter(func(v): return v["player"] != pid)
	var all_cards: Array = e.state.zone(Sgs.hand(pid)).cards + e.state.zone(Sgs.equip(pid)).cards + e.state.zone(Sgs.judge(pid)).cards
	if not all_cards.is_empty():
		await e.move_cards(all_cards, Sgs.ZONE_DISCARD, {"why": "death", "by": pid}, true)
	var win := check_win(e)
	if not win.is_empty():
		e.finish(win)
		return
	if killer >= 0 and killer != pid and e.state.player(killer).alive:
		var k := e.state.player(killer)
		if p.role == Sgs.ROLE_REBEL:
			await draw_cards(e, killer, 3)
		elif p.role == Sgs.ROLE_LOYALIST and k.role == Sgs.ROLE_KING:
			var kc: Array = e.state.zone(Sgs.hand(killer)).cards + e.state.zone(Sgs.equip(killer)).cards
			if not kc.is_empty():
				await discard_cards(e, kc, killer)
	await e.fire(Sgs.T_DEATH, {"player": pid, "killer": killer})


func check_win(e: CardEngine) -> Dictionary:
	var alive := e.state.alive_players()
	var king_alive := false
	var rebels := 0
	var spies := 0
	for q in alive:
		match e.state.player(q).role:
			Sgs.ROLE_KING: king_alive = true
			Sgs.ROLE_REBEL: rebels += 1
			Sgs.ROLE_SPY: spies += 1
	var winners: Array = []
	var side := ""
	if not king_alive:
		if alive.size() == 1 and spies == 1:
			side = "spy"
		else:
			side = "rebel"
	elif rebels == 0 and spies == 0:
		side = "king"
	if side == "":
		return {}
	for p in e.state.players:
		if side == "king" and (p.role == Sgs.ROLE_KING or p.role == Sgs.ROLE_LOYALIST):
			winners.append(p.id)
		elif side == "rebel" and p.role == Sgs.ROLE_REBEL:
			winners.append(p.id)
		elif side == "spy" and p.role == Sgs.ROLE_SPY:
			winners.append(p.id)
	return {"winner": side, "winners": winners}


func equip(e: CardEngine, pid: int, card: Card) -> void:
	var def := e.defs[card.def_id] as SgsCardDef
	var old := equip_of(e, pid, def.subtype)
	if old != null:
		await discard_cards(e, [old.id], pid)
	await e.move_cards([card.id], Sgs.equip(pid), {"why": "equip", "by": pid}, true)
	e.emit_event(&"sgs_equipped", {"player": pid, "card": card.id, "card_ids": [card.id]})
	def.on_equip(e, pid, card)


# --- bot policy ------------------------------------------------------------

func _is_ally(e: CardEngine, me: int, other: int) -> bool:
	if me == other:
		return true
	return Sgs.same_side(e.state.player(me).role, e.state.player(other).role)


func bot_answer(e: CardEngine, prompt: Prompt, brng: CardRng) -> Dictionary:
	var me := prompt.player
	var hint: String = prompt.data.get("bot", "")
	match prompt.kind:
		Prompt.KIND_PLAY:
			var p := e.state.player(me)
			if not prompt.options.is_empty() and brng.randi_range(0, 2) == 0:
				return {"option": brng.pick(prompt.option_ids())}
			if prompt.cards.is_empty():
				return {"pass": true}
			var best: int = -1
			var best_rank := 99
			for cid in prompt.cards:
				var d := e.def_of(cid) as SgsCardDef
				var rank := 50
				if d.has_tag(&"peach") and p.hp < p.max_hp:
					rank = 0
				elif d.type == SgsCardDef.TYPE_EQUIPMENT:
					rank = 1
				elif d.has_tag(&"strike") or d.id == &"duel":
					rank = 2
				elif d.has_tag(&"wine"):
					rank = 40
				elif d.type == SgsCardDef.TYPE_TRICK:
					rank = 3
				else:
					var ways := playable_as(e, me, cid)
					if ways.has(&"strike"):
						rank = 2
				rank += brng.randi_range(0, 1)
				if rank < best_rank:
					best_rank = rank
					best = cid
			return {"cards": [best]}
		Prompt.KIND_CHOOSE_PLAYERS:
			var pool := prompt.players.duplicate()
			if hint == "target":
				var harmful: bool = prompt.data.get("harmful", true)
				var preferred := pool.filter(func(q): return _is_ally(e, me, q) != harmful)
				if not preferred.is_empty():
					pool = preferred
			brng.shuffle(pool)
			var n: int = maxi(prompt.min_players, 1)
			return {"players": pool.slice(0, mini(n, pool.size()))}
		Prompt.KIND_CHOOSE_CARDS:
			match hint:
				"accept":
					return {"cards": [prompt.cards[0]]}
				"decline":
					return {"pass": true}
				"rescue":
					return {"cards": [prompt.cards[0]]} if _is_ally(e, me, int(prompt.data["target"])) else {"pass": true}
				"negate":
					var target := int(prompt.data["target"])
					var harmful: bool = prompt.data["harmful"]
					var negated: bool = prompt.data["negated"]
					var want := (harmful and _is_ally(e, me, target)) or (not harmful and not _is_ally(e, me, target))
					if negated:
						want = not want
					return {"cards": [prompt.cards[0]]} if want else {"pass": true}
			if prompt.min_cards == 0 and prompt.can_pass:
				return {"pass": true}
			var pool := prompt.cards.duplicate()
			# Keep Peaches when discarding if we can.
			pool.sort_custom(func(a, b): return int(e.def_of(a).has_tag(&"peach")) < int(e.def_of(b).has_tag(&"peach")))
			return {"cards": pool.slice(0, maxi(prompt.min_cards, 1))}
		Prompt.KIND_CONFIRM:
			if hint == "decline":
				return {"option": "no"}
			return {"option": "yes"}
	return {}
