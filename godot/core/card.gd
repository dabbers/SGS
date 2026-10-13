class_name Card
extends RefCounted
## One physical card instance in the game. Identity is the integer id; what it
## *is* comes from the CardDef looked up through `def_id`.

const SUITS: Array[StringName] = [&"spade", &"heart", &"club", &"diamond"]
const RED_SUITS: Array[StringName] = [&"heart", &"diamond"]

var id: int = 0
var def_id: StringName
var suit: StringName = &"none"
var rank: int = 0            ## 1 = A ... 13 = K, 0 = none
var zone: StringName = &""   ## id of the Zone currently holding this card
var face_up: bool = false
var attrs: Dictionary = {}   ## game-specific scratch (e.g. "nature")


func color() -> StringName:
	if RED_SUITS.has(suit):
		return &"red"
	if SUITS.has(suit):
		return &"black"
	return &"none"


func is_red() -> bool:
	return color() == &"red"


func is_black() -> bool:
	return color() == &"black"


func rank_label() -> String:
	match rank:
		0: return ""
		1: return "A"
		11: return "J"
		12: return "Q"
		13: return "K"
		_: return str(rank)


func to_dict() -> Dictionary:
	return {
		"id": id, "def": String(def_id), "suit": String(suit), "rank": rank,
		"zone": String(zone), "face_up": face_up, "attrs": attrs.duplicate(),
	}


## Representation for a viewer who is not allowed to see the face.
func to_hidden_dict() -> Dictionary:
	return {"id": id, "zone": String(zone), "face_up": false}


static func from_dict(d: Dictionary) -> Card:
	var c := Card.new()
	c.id = int(d.get("id", 0))
	c.def_id = StringName(d.get("def", ""))
	c.suit = StringName(d.get("suit", "none"))
	c.rank = int(d.get("rank", 0))
	c.zone = StringName(d.get("zone", ""))
	c.face_up = bool(d.get("face_up", false))
	c.attrs = d.get("attrs", {}).duplicate()
	return c
