class_name Zone
extends RefCounted
## An ordered pile of card ids with an owner and a visibility rule.

enum Visibility { PUBLIC, OWNER, HIDDEN }

var id: StringName
var kind: StringName          ## hand / equipment / judgement / draw / discard / processing / ...
var owner: int = -1           ## player id, -1 for shared zones
var visibility: Visibility = Visibility.PUBLIC
var cards: Array[int] = []


func _init(p_id: StringName = &"", p_kind: StringName = &"", p_owner: int = -1, p_vis: Visibility = Visibility.PUBLIC) -> void:
	id = p_id
	kind = p_kind
	owner = p_owner
	visibility = p_vis


func size() -> int:
	return cards.size()


func is_empty() -> bool:
	return cards.is_empty()


func visible_to(viewer: int) -> bool:
	match visibility:
		Visibility.PUBLIC:
			return true
		Visibility.OWNER:
			return viewer == owner
		_:
			return false


func to_dict() -> Dictionary:
	return {
		"id": String(id), "kind": String(kind), "owner": owner,
		"visibility": visibility, "cards": cards.duplicate(),
	}


static func from_dict(d: Dictionary) -> Zone:
	var z := Zone.new(StringName(d.get("id", "")), StringName(d.get("kind", "")), int(d.get("owner", -1)), int(d.get("visibility", 0)) as Visibility)
	for c in d.get("cards", []):
		z.cards.append(int(c))
	return z
