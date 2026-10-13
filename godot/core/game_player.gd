class_name GamePlayer
extends RefCounted
## A seat at the table. `id` is the seat index and is stable for the whole game.

var id: int = 0
var name: String = ""
var is_bot: bool = false
var alive: bool = true
var hp: int = 0
var max_hp: int = 0
var role: StringName = &""          ## game-specific, e.g. king / rebel
var role_revealed: bool = false
var hero_id: StringName = &""
var flags: Dictionary = {}          ## game-specific scratch, cleared by the game module


func to_dict(viewer: int = -1) -> Dictionary:
	var show_role := role_revealed or viewer == id or viewer == -1
	return {
		"id": id, "name": name, "is_bot": is_bot, "alive": alive,
		"hp": hp, "max_hp": max_hp,
		"role": String(role) if show_role else "",
		"role_revealed": role_revealed,
		"hero": String(hero_id), "flags": flags.duplicate(true),
	}


static func from_dict(d: Dictionary) -> GamePlayer:
	var p := GamePlayer.new()
	p.id = int(d.get("id", 0))
	p.name = d.get("name", "")
	p.is_bot = bool(d.get("is_bot", false))
	p.alive = bool(d.get("alive", true))
	p.hp = int(d.get("hp", 0))
	p.max_hp = int(d.get("max_hp", 0))
	p.role = StringName(d.get("role", ""))
	p.role_revealed = bool(d.get("role_revealed", false))
	p.hero_id = StringName(d.get("hero", ""))
	p.flags = d.get("flags", {}).duplicate(true)
	return p
