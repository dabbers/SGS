class_name Prompt
extends RefCounted
## A question the engine asks one player. Serializable so it can cross the
## network; `validate` is the single place a response is checked, on the server.
##
## Response shape (Dictionary): {"cards": [ids], "players": [ids], "option": id, "pass": bool}

const KIND_CHOOSE_CARDS := &"choose_cards"
const KIND_CHOOSE_PLAYERS := &"choose_players"
const KIND_CHOOSE_OPTION := &"choose_option"
const KIND_PLAY := &"play"          ## action phase: a card, an option (skill), or pass
const KIND_CONFIRM := &"confirm"

var id: int = 0
var player: int = -1
var kind: StringName = KIND_CONFIRM
var title: String = ""
var cards: Array[int] = []          ## selectable card ids
var min_cards: int = 0
var max_cards: int = 0
var players: Array[int] = []        ## selectable player ids
var min_players: int = 0
var max_players: int = 0
var options: Array = []             ## [{"id": String, "label": String}]
var can_pass: bool = false
var data: Dictionary = {}           ## free-form hints for UI / bots


static func choose_cards(p_player: int, p_title: String, p_cards: Array, p_min: int, p_max: int, p_can_pass: bool = false) -> Prompt:
	var p := Prompt.new()
	p.player = p_player
	p.kind = KIND_CHOOSE_CARDS
	p.title = p_title
	for c in p_cards:
		p.cards.append(int(c))
	p.min_cards = p_min
	p.max_cards = p_max
	p.can_pass = p_can_pass
	return p


static func choose_players(p_player: int, p_title: String, p_players: Array, p_min: int, p_max: int, p_can_pass: bool = false) -> Prompt:
	var p := Prompt.new()
	p.player = p_player
	p.kind = KIND_CHOOSE_PLAYERS
	p.title = p_title
	for q in p_players:
		p.players.append(int(q))
	p.min_players = p_min
	p.max_players = p_max
	p.can_pass = p_can_pass
	return p


static func choose_option(p_player: int, p_title: String, p_options: Array, p_can_pass: bool = false) -> Prompt:
	var p := Prompt.new()
	p.player = p_player
	p.kind = KIND_CHOOSE_OPTION
	p.title = p_title
	p.options = p_options.duplicate()
	p.can_pass = p_can_pass
	return p


static func play(p_player: int, p_title: String, p_cards: Array, p_options: Array = []) -> Prompt:
	var p := Prompt.new()
	p.player = p_player
	p.kind = KIND_PLAY
	p.title = p_title
	for c in p_cards:
		p.cards.append(int(c))
	p.min_cards = 0
	p.max_cards = 1
	p.options = p_options.duplicate()
	p.can_pass = true
	return p


static func confirm(p_player: int, p_title: String) -> Prompt:
	var p := Prompt.new()
	p.player = p_player
	p.kind = KIND_CONFIRM
	p.title = p_title
	p.options = [{"id": "yes", "label": "Yes"}, {"id": "no", "label": "No"}]
	p.can_pass = true
	return p


func option_ids() -> Array:
	return options.map(func(o): return o["id"])


func validate(resp: Dictionary) -> bool:
	if resp.get("pass", false):
		return can_pass
	var sel_cards: Array = resp.get("cards", [])
	var sel_players: Array = resp.get("players", [])
	var option = resp.get("option", null)
	match kind:
		KIND_CHOOSE_CARDS:
			return _subset(sel_cards, cards, min_cards, max_cards)
		KIND_CHOOSE_PLAYERS:
			return _subset(sel_players, players, min_players, max_players)
		KIND_CHOOSE_OPTION:
			return option != null and option_ids().has(option)
		KIND_CONFIRM:
			return option != null and option_ids().has(option)
		KIND_PLAY:
			if option != null:
				return option_ids().has(option) and sel_cards.is_empty()
			return _subset(sel_cards, cards, 1, 1)
	return false


static func _subset(sel: Array, allowed: Array, lo: int, hi: int) -> bool:
	if sel.size() < lo or sel.size() > hi:
		return false
	var seen := {}
	for s in sel:
		var v := int(s)
		if seen.has(v) or not allowed.has(v):
			return false
		seen[v] = true
	return true


func to_dict() -> Dictionary:
	return {
		"id": id, "player": player, "kind": String(kind), "title": title,
		"cards": cards.duplicate(), "min_cards": min_cards, "max_cards": max_cards,
		"players": players.duplicate(), "min_players": min_players, "max_players": max_players,
		"options": options.duplicate(true), "can_pass": can_pass, "data": data.duplicate(true),
	}


static func from_dict(d: Dictionary) -> Prompt:
	var p := Prompt.new()
	p.id = int(d.get("id", 0))
	p.player = int(d.get("player", -1))
	p.kind = StringName(d.get("kind", "confirm"))
	p.title = d.get("title", "")
	for c in d.get("cards", []):
		p.cards.append(int(c))
	p.min_cards = int(d.get("min_cards", 0))
	p.max_cards = int(d.get("max_cards", 0))
	for q in d.get("players", []):
		p.players.append(int(q))
	p.min_players = int(d.get("min_players", 0))
	p.max_players = int(d.get("max_players", 0))
	p.options = d.get("options", []).duplicate(true)
	p.can_pass = bool(d.get("can_pass", false))
	p.data = d.get("data", {}).duplicate(true)
	return p
