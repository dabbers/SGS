class_name SgsCardDef
extends CardDef
## Base class for every Sanguosha card. Gives subclasses the rules object and
## a few helpers. Cards never touch state directly; they call SgsRules.

const TYPE_BASIC := &"basic"
const TYPE_TRICK := &"trick"
const TYPE_EQUIPMENT := &"equipment"

var harmful: bool = false     ## hint for bots / UI: does this hurt its targets?


static func rules(engine: CardEngine) -> SgsRules:
	return engine.rules as SgsRules


func others_targets(engine: CardEngine, player: int, filter: Callable = Callable()) -> Array[int]:
	var out: Array[int] = []
	for pid in engine.state.alive_players():
		if pid == player:
			continue
		if filter.is_valid() and not filter.call(engine, player, pid):
			continue
		out.append(pid)
	return out


func single_target(engine: CardEngine, player: int, filter: Callable = Callable()) -> Dictionary:
	var c := others_targets(engine, player, filter)
	return {"min": 1, "max": 1, "candidates": c}


## Delayed tricks override this; called in the owner's judgement phase.
func on_judgement(_engine: CardEngine, _player: int, _card: Card) -> void:
	pass


## Equipment overrides this to register its triggers (source_card = card.id).
func on_equip(_engine: CardEngine, _player: int, _card: Card) -> void:
	pass
