class_name CardEngine
extends RefCounted
## The rules kernel. Owns the state, runs the game module as a coroutine,
## suspends on prompts, fires triggers and records an event log.
##
## Determinism: all randomness comes from `rng` (seeded) and all player input
## arrives through `respond`. (seed, config, inputs) reproduces a game exactly.

signal event_emitted(ev: Dictionary)
signal prompt_requested(prompt: Prompt)
signal game_finished(result: Dictionary)
signal _answered(response: Dictionary)

const ZONE_PROCESSING := &"processing"   ## cards mid-resolution; public

var rules: GameRules
var state: GameState
var rng: CardRng
var defs: Dictionary = {}          ## StringName -> CardDef
var config: Dictionary = {}
var seed_value: int = 0
var triggers: Array[Trigger] = []
var pending: Prompt = null
var log: Array[Dictionary] = []
var inputs: Array[Dictionary] = []
var result: Dictionary = {}
var is_over: bool = false

var _next_card_id: int = 1
var _next_prompt_id: int = 1
var _dispatching: bool = false
var _early_response: Dictionary = {}
var _has_early_response: bool = false


# --- lifecycle -------------------------------------------------------------

func start(p_rules: GameRules, p_config: Dictionary = {}, p_seed: int = 0) -> void:
	rules = p_rules
	config = p_config.duplicate(true)
	seed_value = p_seed if p_seed != 0 else int(Time.get_unix_time_from_system()) ^ randi()
	rng = CardRng.new(seed_value)
	state = GameState.new()
	state.add_zone(Zone.new(ZONE_PROCESSING, &"processing", -1, Zone.Visibility.PUBLIC))
	defs = rules.create_defs()
	rules.setup(self, config)
	emit_event(&"game_started", {"seed": seed_value, "game": String(rules.id()), "players": state.players.size()})
	_run()


## Re-run a recorded game. Returns the engine positioned after the last input.
static func replay(p_rules: GameRules, p_config: Dictionary, p_seed: int, p_inputs: Array) -> CardEngine:
	var e := CardEngine.new()
	e.start(p_rules, p_config, p_seed)
	for inp in p_inputs:
		if e.is_over:
			break
		e.respond(int(inp["player"]), int(inp["prompt"]), inp["response"])
	return e


func _run() -> void:
	var res: Dictionary = await rules.play(self)
	finish(res)


func finish(res: Dictionary) -> void:
	if is_over:
		return
	is_over = true
	result = res.duplicate(true)
	pending = null
	emit_event(&"game_over", result)
	game_finished.emit(result)


# --- input -----------------------------------------------------------------

## Ask one player a question and suspend until `respond` delivers a valid answer.
func ask(prompt: Prompt) -> Dictionary:
	assert(pending == null, "ask() while another prompt is pending")
	if is_over:
		return {"pass": true}
	prompt.id = _next_prompt_id
	_next_prompt_id += 1
	pending = prompt
	_has_early_response = false
	_dispatching = true
	prompt_requested.emit(prompt)
	_dispatching = false
	if _has_early_response:
		# A listener answered synchronously inside the signal; don't await.
		_has_early_response = false
		return _early_response
	var resp: Dictionary = await _answered
	return resp


## Deliver a player's answer. Returns false (and keeps waiting) if it is not
## for the pending prompt, not from that player, or not a valid selection.
func respond(player: int, prompt_id: int, response: Dictionary) -> bool:
	if pending == null or is_over:
		return false
	if pending.id != prompt_id or pending.player != player:
		return false
	if not pending.validate(response):
		return false
	var p := pending
	pending = null
	var resp := response.duplicate(true)
	inputs.append({"prompt": p.id, "player": player, "response": resp})
	emit_event(&"responded", {"prompt_id": p.id, "player": player, "kind": String(p.kind), "response": resp})
	if _dispatching:
		_early_response = resp
		_has_early_response = true
	else:
		_answered.emit(resp)
	return true


# --- events ----------------------------------------------------------------

func emit_event(type: StringName, data: Dictionary = {}) -> Dictionary:
	var ev := data.duplicate(true)
	ev["type"] = String(type)
	ev["seq"] = log.size()
	log.append(ev)
	event_emitted.emit(ev)
	return ev


## What a particular viewer may see of an event. Attaches full card data for
## cards that became visible to them, so clients can keep a "known cards" map.
func event_for_viewer(ev: Dictionary, viewer: int) -> Dictionary:
	var out := ev.duplicate(true)
	if out.has("reveal_to") and viewer != -1 and not out["reveal_to"].has(viewer):
		out.erase("cards")
	var revealed := {}
	for cid in out.get("card_ids", []):
		if card_visible_to(state.cards[int(cid)], viewer):
			revealed[int(cid)] = state.cards[int(cid)].to_dict()
	if not revealed.is_empty():
		out["known_cards"] = revealed
	return out


# --- cards & zones ---------------------------------------------------------

func create_card(def_id: StringName, suit: StringName, rank: int, zone_id: StringName) -> Card:
	assert(defs.has(def_id), "unknown card def: %s" % def_id)
	var c := Card.new()
	c.id = _next_card_id
	_next_card_id += 1
	c.def_id = def_id
	c.suit = suit
	c.rank = rank
	c.zone = zone_id
	state.cards[c.id] = c
	state.zone(zone_id).cards.append(c.id)
	return c


func card(cid: int) -> Card:
	return state.cards[cid]


func def_of(cid: int) -> CardDef:
	return defs[state.cards[cid].def_id]


func card_visible_to(c: Card, viewer: int) -> bool:
	if viewer == -1 or c.face_up:
		return true
	return state.zone(c.zone).visible_to(viewer)


## Move cards between zones. Emits one `cards_moved` event and fires the
## `cards_moved` timing so skills can react. `reason` is free-form
## (e.g. {"why": "discard", "by": 2}).
func move_cards(card_ids: Array, to_zone: StringName, reason: Dictionary = {}, face_up: Variant = null) -> void:
	if card_ids.is_empty():
		return
	var dest := state.zone(to_zone)
	var moves := []
	for raw in card_ids:
		var cid := int(raw)
		var c: Card = state.cards[cid]
		var from := c.zone
		state.zone(from).cards.erase(cid)
		dest.cards.append(cid)
		c.zone = to_zone
		if face_up != null:
			c.face_up = bool(face_up)
		else:
			c.face_up = dest.visibility == Zone.Visibility.PUBLIC
		moves.append({"card": cid, "from": String(from), "to": String(to_zone)})
	emit_event(&"cards_moved", {"moves": moves, "card_ids": card_ids.duplicate(), "reason": reason.duplicate(true)})
	await fire(&"cards_moved", {"moves": moves, "reason": reason})


## Peek at the top `count` card ids of a zone (index 0 is the top).
func top_cards(zone_id: StringName, count: int) -> Array[int]:
	var out: Array[int] = []
	var z := state.zone(zone_id)
	for i in mini(count, z.cards.size()):
		out.append(z.cards[i])
	return out


# --- triggers --------------------------------------------------------------

func register_trigger(t: Trigger) -> Trigger:
	triggers.append(t)
	return t


func unregister_trigger(t: Trigger) -> void:
	triggers.erase(t)


func unregister_triggers_of_card(cid: int) -> void:
	triggers = triggers.filter(func(t: Trigger): return t.source_card != cid)


func unregister_triggers_of_player(pid: int) -> void:
	triggers = triggers.filter(func(t: Trigger): return t.owner != pid)


## Fire a timing point. Triggers run by priority (desc), then by seat order
## starting from the current player; game-owned triggers (owner -1) go first
## within a priority band. Returns the (mutated) ctx.
func fire(timing: StringName, ctx: Dictionary = {}) -> Dictionary:
	var ordered := _ordered_triggers(timing)
	for t in ordered:
		if not triggers.has(t):
			continue  # removed by an earlier trigger
		if ctx.get("cancelled", false) and not t.fires_when_cancelled:
			continue
		if is_over:
			break
		if t.is_active(self, timing, ctx):
			await t.on_trigger(self, timing, ctx)
	return ctx


func _ordered_triggers(timing: StringName) -> Array[Trigger]:
	var list: Array[Trigger] = []
	for t in triggers:
		if t.listens_to(timing):
			list.append(t)
	var n := maxi(state.players.size(), 1)
	var cur := maxi(state.current_player, 0)
	list.sort_custom(func(a: Trigger, b: Trigger) -> bool:
		if a.priority != b.priority:
			return a.priority > b.priority
		var sa := -1 if a.owner < 0 else (a.owner - cur + n) % n
		var sb := -1 if b.owner < 0 else (b.owner - cur + n) % n
		return sa < sb
	)
	return list
