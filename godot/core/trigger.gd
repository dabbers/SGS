class_name Trigger
extends RefCounted
## Something that reacts to a timing point: a hero skill, an equipment effect,
## a delayed card, or a rule of the game itself. Triggers may ask prompts, so
## `on_trigger` is awaited by the engine.
##
## `ctx` is a mutable Dictionary describing the thing happening. Triggers
## communicate back by mutating it (e.g. ctx.cancelled = true, ctx.amount += 1).

var timings: Array[StringName] = []
var owner: int = -1            ## player who "controls" the trigger; -1 = the game
var priority: int = 0          ## higher fires first
var source: String = ""        ## display name (skill / card)
var source_card: int = -1      ## card id if the trigger comes from a card
var fires_when_cancelled: bool = false


func _init(p_timings: Array = [], p_owner: int = -1, p_source: String = "", p_priority: int = 0) -> void:
	for t in p_timings:
		timings.append(StringName(t))
	owner = p_owner
	source = p_source
	priority = p_priority


func listens_to(timing: StringName) -> bool:
	return timings.has(timing)


func is_active(_engine: CardEngine, _timing: StringName, _ctx: Dictionary) -> bool:
	return true


func on_trigger(_engine: CardEngine, _timing: StringName, _ctx: Dictionary) -> void:
	pass


## Convenience: a trigger backed by Callables, for small game rules.
static func make(p_timings: Array, p_owner: int, p_source: String, on_fire: Callable, active: Callable = Callable(), p_priority: int = 0) -> Trigger:
	var t := CallableTrigger.new(p_timings, p_owner, p_source, p_priority)
	t.fire_fn = on_fire
	t.active_fn = active
	return t


class CallableTrigger extends Trigger:
	var fire_fn: Callable
	var active_fn: Callable

	func is_active(engine: CardEngine, timing: StringName, ctx: Dictionary) -> bool:
		if active_fn.is_valid():
			return active_fn.call(engine, timing, ctx)
		return true

	func on_trigger(engine: CardEngine, timing: StringName, ctx: Dictionary) -> void:
		await fire_fn.call(engine, timing, ctx)
