class_name GameHost
extends RefCounted
## Authoritative game runner. Owns the CardEngine, drives bots, and after every
## suspension (prompt or game over) produces one filtered sync per human seat:
## their snapshot, the pending prompt, and the events since their last sync.

signal sync_for_viewer(viewer: int, snapshot: Dictionary, prompt_dict: Variant, events: Array)
signal finished(result: Dictionary)

var engine: CardEngine
var rules: GameRules
var bot: SimpleBot
var human_seats: Array[int] = []
var _cursor: Dictionary = {}     ## viewer -> index into engine.log already sent
var _flushing := false
var _dirty := false


func start(config: Dictionary, p_rules: GameRules = null, seed_value: int = 0) -> void:
	rules = p_rules if p_rules != null else SgsRules.new()
	engine = CardEngine.new()
	var n: int = config["players"].size() if config.get("players") is Array else int(config.get("players", 4))
	var bots: Array = config.get("bots", [])
	for i in n:
		if not bots.has(i):
			human_seats.append(i)
		_cursor[i] = 0
	if seed_value == 0:
		seed_value = int(config.get("seed", 0))
	engine.start(rules, config, seed_value)
	if not bots.is_empty():
		bot = SimpleBot.new(engine, bots, seed_value + 1)
	_flush()


func respond(seat: int, prompt_id: int, response: Dictionary) -> bool:
	var ok := engine.respond(seat, prompt_id, response)
	if ok:
		_flush()
	return ok


## Called when a viewer (re)connects: resend everything they are allowed to see.
func resync(viewer: int) -> void:
	_cursor[viewer] = 0
	_send(viewer)


## Sends pending syncs. Re-entrant: a response submitted from inside a sync
## handler (bots, tests, a very fast UI) marks the host dirty and the outer
## call loops, so the stack never grows with the game.
func _flush() -> void:
	_dirty = true
	if _flushing:
		return
	_flushing = true
	while _dirty:
		_dirty = false
		for v in human_seats:
			_send(v)
	_flushing = false
	if engine.is_over:
		finished.emit(engine.result)


func _send(viewer: int) -> void:
	var events := []
	var from: int = _cursor.get(viewer, 0)
	for i in range(from, engine.log.size()):
		events.append(engine.event_for_viewer(engine.log[i], viewer))
	_cursor[viewer] = engine.log.size()
	var prompt_dict = engine.pending.to_dict() if engine.pending != null else {}
	sync_for_viewer.emit(viewer, engine.state.snapshot(viewer), prompt_dict, events)
