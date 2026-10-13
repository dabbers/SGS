class_name GameState
extends RefCounted
## Plain data: players, cards and zones. No rules live here.

var players: Array[GamePlayer] = []
var cards: Dictionary = {}        ## int -> Card
var zones: Dictionary = {}        ## StringName -> Zone
var current_player: int = -1
var phase: StringName = &""
var turn_number: int = 0
var vars: Dictionary = {}         ## game-specific shared scratch


func add_player(p_name: String, is_bot: bool = false) -> GamePlayer:
	var p := GamePlayer.new()
	p.id = players.size()
	p.name = p_name
	p.is_bot = is_bot
	players.append(p)
	return p


func player(pid: int) -> GamePlayer:
	return players[pid]


func add_zone(z: Zone) -> Zone:
	zones[z.id] = z
	return z


func zone(zid: StringName) -> Zone:
	return zones[zid]


func has_zone(zid: StringName) -> bool:
	return zones.has(zid)


func card(cid: int) -> Card:
	return cards[cid]


func cards_in(zid: StringName) -> Array[Card]:
	var out: Array[Card] = []
	for cid in zones[zid].cards:
		out.append(cards[cid])
	return out


func alive_players() -> Array[int]:
	var out: Array[int] = []
	for p in players:
		if p.alive:
			out.append(p.id)
	return out


## Alive seats in turn order starting at `start` (inclusive if alive).
func alive_from(start: int) -> Array[int]:
	var out: Array[int] = []
	var n := players.size()
	if n == 0:
		return out
	for i in n:
		var pid := (start + i) % n
		if players[pid].alive:
			out.append(pid)
	return out


func next_alive(pid: int) -> int:
	var n := players.size()
	for i in range(1, n + 1):
		var q := (pid + i) % n
		if players[q].alive:
			return q
	return -1


## Number of seats between a and b going around the table, shortest way,
## counting only living players.
func seat_distance(a: int, b: int) -> int:
	if a == b:
		return 0
	var ring := alive_from(a)
	var idx := ring.find(b)
	if idx < 0:
		return 999
	return mini(idx, ring.size() - idx)


func snapshot(viewer: int = -1) -> Dictionary:
	var out_players := []
	for p in players:
		out_players.append(p.to_dict(viewer))
	var out_zones := {}
	var known := {}
	for zid in zones:
		var z: Zone = zones[zid]
		out_zones[String(zid)] = z.to_dict()
		for cid in z.cards:
			var c: Card = cards[cid]
			if viewer == -1 or z.visible_to(viewer) or c.face_up:
				known[cid] = c.to_dict()
	return {
		"players": out_players, "zones": out_zones, "cards": known,
		"current_player": current_player, "phase": String(phase),
		"turn_number": turn_number, "vars": vars.duplicate(true),
	}


static func from_snapshot(d: Dictionary) -> GameState:
	var s := GameState.new()
	for pd in d.get("players", []):
		s.players.append(GamePlayer.from_dict(pd))
	for zid in d.get("zones", {}):
		var z := Zone.from_dict(d["zones"][zid])
		s.zones[z.id] = z
	for cid in d.get("cards", {}):
		var c := Card.from_dict(d["cards"][cid])
		s.cards[c.id] = c
	s.current_player = int(d.get("current_player", -1))
	s.phase = StringName(d.get("phase", ""))
	s.turn_number = int(d.get("turn_number", 0))
	s.vars = d.get("vars", {}).duplicate(true)
	return s
