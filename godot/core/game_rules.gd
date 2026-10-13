class_name GameRules
extends RefCounted
## A game module: everything that makes a particular card game. The engine
## knows nothing about hit points, roles or turns; it only knows cards, zones,
## prompts, triggers and events. Subclass this per game.


func id() -> StringName:
	return &"base"


## Build the CardDef registry: {def_id: CardDef}.
func create_defs() -> Dictionary:
	return {}


## Create players, zones and the deck on `engine.state`. Called once by CardEngine.start.
func setup(_engine: CardEngine, _config: Dictionary) -> void:
	pass


## The whole game, written sequentially with `await engine.ask(...)` for input.
## Returns the result Dictionary (winners etc.).
func play(_engine: CardEngine) -> Dictionary:
	return {}


## Default bot policy for this game. The engine's SimpleBot calls this first.
func bot_answer(_engine: CardEngine, _prompt: Prompt, _bot_rng: CardRng) -> Dictionary:
	return {}
