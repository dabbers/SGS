class_name SgsCardsBasic
extends RefCounted
## Basic cards: Strike (+ fire / thunder), Dodge, Peach, Wine.


static func build(defs: Dictionary) -> void:
	for d in [Strike.new(&"strike", "Strike", Sgs.NATURE_NONE),
			Strike.new(&"strike_fire", "Fire Strike", Sgs.NATURE_FIRE),
			Strike.new(&"strike_thunder", "Thunder Strike", Sgs.NATURE_THUNDER),
			Dodge.new(), Peach.new(), Wine.new()]:
		defs[d.id] = d


class Strike extends SgsCardDef:
	var nature: StringName = Sgs.NATURE_NONE

	func _init(p_id: StringName, p_name: String, p_nature: StringName) -> void:
		super(p_id, p_name, TYPE_BASIC, &"strike")
		nature = p_nature
		tags = [&"strike"]
		harmful = true
		text = "Deal 1 damage to a player within your attack range unless they play a Dodge."

	func can_play(e: CardEngine, player: int, card: Card) -> bool:
		var r := rules(e)
		if r.strikes_used(e, player) >= r.strike_limit(e, player):
			return false
		return not target_spec(e, player, card)["candidates"].is_empty()

	func target_spec(e: CardEngine, player: int, _card: Card) -> Dictionary:
		var r := rules(e)
		return single_target(e, player, func(eng, a, b): return r.in_attack_range(eng, a, b))

	func on_play(e: CardEngine, player: int, card: Card, targets: Array) -> void:
		var r := rules(e)
		var p := e.state.player(player)
		p.flags["strikes_used"] = r.strikes_used(e, player) + 1
		var bonus := 0
		if p.flags.get("wine_active", false):
			bonus = 1
			p.flags["wine_active"] = false
		for t in targets:
			await r.resolve_strike(e, player, int(t), card, nature, 1 + bonus)


class Dodge extends SgsCardDef:
	func _init() -> void:
		super(&"dodge", "Dodge", TYPE_BASIC, &"dodge")
		tags = [&"dodge"]
		text = "Play in response to a Strike to avoid it."


class Peach extends SgsCardDef:
	func _init() -> void:
		super(&"peach", "Peach", TYPE_BASIC, &"peach")
		tags = [&"peach"]
		text = "Recover 1 HP. Can also be played to save a dying player."

	func can_play(e: CardEngine, player: int, _card: Card) -> bool:
		var p := e.state.player(player)
		return p.hp < p.max_hp

	func on_play(e: CardEngine, player: int, _card: Card, _targets: Array) -> void:
		await rules(e).heal(e, player, 1)


class Wine extends SgsCardDef:
	func _init() -> void:
		super(&"wine", "Wine", TYPE_BASIC, &"wine")
		tags = [&"wine"]
		text = "Your next Strike this turn deals +1 damage (once per turn). When dying, recover 1 HP."

	func can_play(e: CardEngine, player: int, _card: Card) -> bool:
		var p := e.state.player(player)
		return int(p.flags.get("wines_used", 0)) < 1 and not p.flags.get("wine_active", false)

	func on_play(e: CardEngine, player: int, _card: Card, _targets: Array) -> void:
		var p := e.state.player(player)
		p.flags["wine_active"] = true
		p.flags["wines_used"] = int(p.flags.get("wines_used", 0)) + 1
		e.emit_event(&"sgs_wine", {"player": player})
