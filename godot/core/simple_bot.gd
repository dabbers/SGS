class_name SimpleBot
extends RefCounted
## Answers prompts for bot seats. Asks the game module first; falls back to a
## "pick something valid" policy. Uses its own RNG so bot choices are inputs,
## not part of the game's random stream.

var engine: CardEngine
var rng: CardRng
var seats: Array[int] = []


func _init(p_engine: CardEngine, p_seats: Array, p_seed: int = 1) -> void:
	engine = p_engine
	for s in p_seats:
		seats.append(int(s))
	rng = CardRng.new(p_seed)
	engine.prompt_requested.connect(_on_prompt)
	if engine.pending != null:
		_on_prompt(engine.pending)


func _on_prompt(prompt: Prompt) -> void:
	if not seats.has(prompt.player):
		return
	var resp := answer(prompt)
	var ok := engine.respond(prompt.player, prompt.id, resp)
	if not ok:
		push_error("SimpleBot produced an invalid response for %s: %s" % [prompt.kind, resp])
		engine.respond(prompt.player, prompt.id, fallback(prompt))


func answer(prompt: Prompt) -> Dictionary:
	var r := engine.rules.bot_answer(engine, prompt, rng)
	if not r.is_empty() and prompt.validate(r):
		return r
	return fallback(prompt)


func fallback(prompt: Prompt) -> Dictionary:
	var prefer: String = prompt.data.get("bot", "")
	match prompt.kind:
		Prompt.KIND_PLAY:
			if prompt.cards.is_empty() and prompt.options.is_empty():
				return {"pass": true}
			if not prompt.cards.is_empty():
				return {"cards": [rng.pick(prompt.cards)]}
			return {"option": rng.pick(prompt.option_ids())}
		Prompt.KIND_CHOOSE_CARDS:
			if prompt.min_cards == 0 and prompt.can_pass and (prefer == "decline" or (prefer != "accept" and rng.randi_range(0, 1) == 0)):
				return {"pass": true}
			var pool := prompt.cards.duplicate()
			rng.shuffle(pool)
			var n: int = maxi(prompt.min_cards, mini(prompt.max_cards, 1))
			if pool.size() < prompt.min_cards:
				return {"pass": true}
			return {"cards": pool.slice(0, n)}
		Prompt.KIND_CHOOSE_PLAYERS:
			if prompt.min_players == 0 and prompt.can_pass and prefer == "decline":
				return {"pass": true}
			var pool := prompt.players.duplicate()
			rng.shuffle(pool)
			var n: int = maxi(prompt.min_players, mini(prompt.max_players, 1))
			if pool.size() < prompt.min_players:
				return {"pass": true}
			return {"players": pool.slice(0, n)}
		Prompt.KIND_CHOOSE_OPTION:
			return {"option": rng.pick(prompt.option_ids())}
		Prompt.KIND_CONFIRM:
			if prefer == "decline":
				return {"option": "no"}
			if prefer == "accept":
				return {"option": "yes"}
			return {"option": rng.pick(["yes", "no"])}
	return {"pass": true}
