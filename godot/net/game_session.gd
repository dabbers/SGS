class_name GameSession
extends Node
## What the UI talks to. A session hides whether the engine runs in this
## process (LocalSession) or on a remote host (NetSession). The UI only ever
## sees filtered snapshots, events, and prompts for its own seat.

signal lobby_changed(players: Array)      ## [{seat, name, is_bot, ready}]
signal game_started()
signal synced(snapshot: Dictionary)       ## full filtered state, after every suspension
signal event_received(ev: Dictionary)     ## filtered engine event, for log / animation
signal prompt_received(prompt: Prompt)    ## a question for MY seat
signal waiting_for(seat: int, title: String)  ## someone else is being asked
signal game_over(result: Dictionary)
signal error(message: String)

var my_seat: int = -1
var my_name: String = "Player"
var snapshot: Dictionary = {}
var known_cards: Dictionary = {}          ## card id -> card dict, everything we have seen
var pending: Prompt = null
var is_host: bool = false
var lobby: Array = []


func submit(prompt_id: int, response: Dictionary) -> void:
	push_error("submit() not implemented for %s" % get_class())
	assert(false)


func start_game(_config: Dictionary = {}) -> void:
	pass


func leave() -> void:
	queue_free()


# --- helpers for subclasses -------------------------------------------------

func _apply_sync(snap: Dictionary, prompt_dict: Variant, events: Array) -> void:
	snapshot = snap
	for cid in snap.get("cards", {}):
		known_cards[int(cid)] = snap["cards"][cid]
	for ev in events:
		for cid in ev.get("known_cards", {}):
			known_cards[int(cid)] = ev["known_cards"][cid]
		event_received.emit(ev)
	synced.emit(snap)
	if prompt_dict is Dictionary and not prompt_dict.is_empty():
		var p := Prompt.from_dict(prompt_dict)
		if p.player == my_seat:
			pending = p
			prompt_received.emit(p)
		else:
			pending = null
			waiting_for.emit(p.player, p.title)
	else:
		pending = null


func card_info(cid: int) -> Dictionary:
	return known_cards.get(cid, {"id": cid})


func player_info(seat: int) -> Dictionary:
	for p in snapshot.get("players", []):
		if int(p["id"]) == seat:
			return p
	return {}
