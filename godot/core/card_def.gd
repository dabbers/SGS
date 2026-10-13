class_name CardDef
extends RefCounted
## Static definition of a kind of card ("Strike", "Peach", ...). Game modules
## subclass this and implement the behaviour hooks. One CardDef is shared by
## every printed copy (Card) of it.

var id: StringName
var name: String = ""
var type: StringName = &""      ## game-specific, e.g. basic / trick / equipment
var subtype: StringName = &""   ## game-specific, e.g. weapon / armor / delayed
var text: String = ""
var tags: Array[StringName] = []
var implemented: bool = true


func _init(p_id: StringName = &"", p_name: String = "", p_type: StringName = &"", p_subtype: StringName = &"") -> void:
	id = p_id
	name = p_name
	type = p_type
	subtype = p_subtype


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)


## Can `player` play `card` right now from their hand during their own action phase?
func can_play(_engine: CardEngine, _player: int, _card: Card) -> bool:
	return false


## Targeting rule. Returns {"min": int, "max": int, "candidates": Array[int]}.
## max == 0 means the card has no explicit targets.
func target_spec(_engine: CardEngine, _player: int, _card: Card) -> Dictionary:
	return {"min": 0, "max": 0, "candidates": []}


## Resolve the card after it has been played and targets chosen. May await prompts.
func on_play(_engine: CardEngine, _player: int, _card: Card, _targets: Array) -> void:
	pass


func to_dict() -> Dictionary:
	return {
		"id": String(id), "name": name, "type": String(type), "subtype": String(subtype),
		"text": text, "tags": tags.map(func(t): return String(t)), "implemented": implemented,
	}
