class_name SgsCardsDelayed
extends RefCounted
## Delayed tricks live in a player's judgement zone until that player's
## judgement phase, where SgsRules calls on_judgement.


static func build(defs: Dictionary) -> void:
	for d in [Lightning.new(), Contentment.new(), Starvation.new()]:
		defs[d.id] = d


class Delayed extends SgsCardDef:
	func _init(p_id: StringName, p_name: String, p_text: String) -> void:
		super(p_id, p_name, TYPE_TRICK, &"delayed")
		text = p_text
		harmful = true

	func already_has(e: CardEngine, pid: int) -> bool:
		for c in e.state.cards_in(Sgs.judge(pid)):
			if c.def_id == id:
				return true
		return false

	func can_play(e: CardEngine, player: int, card: Card) -> bool:
		var spec := target_spec(e, player, card)
		return not spec["candidates"].is_empty()

	func on_play(e: CardEngine, player: int, card: Card, targets: Array) -> void:
		var t: int = int(targets[0]) if not targets.is_empty() else player
		card.attrs["source"] = player
		await e.move_cards([card.id], Sgs.judge(t), {"why": "delayed", "by": player})


class Lightning extends Delayed:
	func _init() -> void:
		super(&"lightning", "Lightning", "Place on yourself. Judgement: spade 2-9 deals 3 thunder damage; otherwise it moves to the next player.")

	func target_spec(e: CardEngine, player: int, _card: Card) -> Dictionary:
		var c: Array[int] = []
		if not already_has(e, player):
			c.append(player)
		return {"min": 1, "max": 1, "candidates": c}

	func on_judgement(e: CardEngine, player: int, card: Card) -> void:
		var r := rules(e)
		var j := await r.judge(e, player, "lightning")
		if j.suit == &"spade" and j.rank >= 2 and j.rank <= 9:
			await r.damage(e, -1, player, 3, Sgs.NATURE_THUNDER, card.id)
			return
		# Pass it along to the next living player who does not already have one.
		var next := e.state.next_alive(player)
		var tries := 0
		while next != -1 and already_has(e, next) and tries < e.state.players.size():
			next = e.state.next_alive(next)
			tries += 1
		if next != -1 and not already_has(e, next):
			await e.move_cards([card.id], Sgs.judge(next), {"why": "lightning_pass"})


class Contentment extends Delayed:
	func _init() -> void:
		super(&"contentment", "Contentment", "Target skips their play phase unless the judgement is a heart.")

	func target_spec(e: CardEngine, player: int, _card: Card) -> Dictionary:
		return single_target(e, player, func(eng, _a, b): return not already_has(eng, b))

	func on_judgement(e: CardEngine, player: int, _card: Card) -> void:
		var j := await rules(e).judge(e, player, "contentment")
		if j.suit != &"heart":
			e.state.player(player).flags["skip_play"] = true


class Starvation extends Delayed:
	func _init() -> void:
		super(&"starvation", "Starvation", "Target at distance 1 skips their draw phase unless the judgement is a club.")

	func target_spec(e: CardEngine, player: int, _card: Card) -> Dictionary:
		return single_target(e, player, func(eng, a, b): return not already_has(eng, b) and rules(eng).distance(eng, a, b) <= 1)

	func on_judgement(e: CardEngine, player: int, _card: Card) -> void:
		var j := await rules(e).judge(e, player, "starvation")
		if j.suit != &"club":
			e.state.player(player).flags["skip_draw"] = true
