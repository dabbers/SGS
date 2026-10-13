class_name SgsCardsTricks
extends RefCounted
## Instant tricks. Each one resolves per target through SgsRules.trick_effect,
## which is where Negate gets its chance.


static func build(defs: Dictionary) -> void:
	for d in [Negate.new(), Dismantle.new(), Snatch.new(), Windfall.new(), PeachGarden.new(),
			Harvest.new(), Barbarians.new(), Arrows.new(), Duel.new(), BorrowedSword.new(), Blaze.new(), Chain.new()]:
		defs[d.id] = d


class Trick extends SgsCardDef:
	func _init(p_id: StringName, p_name: String, p_text: String, p_harmful: bool) -> void:
		super(p_id, p_name, TYPE_TRICK, &"instant")
		text = p_text
		harmful = p_harmful

	## Default: a trick with no explicit targets affects its user.
	func can_play(e: CardEngine, player: int, card: Card) -> bool:
		var spec := target_spec(e, player, card)
		return spec["max"] == 0 or not spec["candidates"].is_empty()

	func on_play(e: CardEngine, player: int, card: Card, targets: Array) -> void:
		var list := targets.duplicate()
		if list.is_empty():
			list = [player]
		for t in list:
			if e.is_over:
				return
			if not e.state.player(int(t)).alive:
				continue
			if await rules(e).trick_effect(e, player, int(t), card):
				await effect(e, player, int(t), card)

	func effect(_e: CardEngine, _source: int, _target: int, _card: Card) -> void:
		pass


class AllOthersTrick extends Trick:
	func on_play(e: CardEngine, player: int, card: Card, _targets: Array) -> void:
		var list := others_targets(e, player)
		await super(e, player, card, list)


class Negate extends SgsCardDef:
	func _init() -> void:
		super(&"negate", "Negate", TYPE_TRICK, &"instant")
		tags = [&"negate"]
		text = "Cancel a trick card (or another Negate) as it takes effect on a player."


class Dismantle extends Trick:
	func _init() -> void:
		super(&"dismantle", "Dismantle", "Discard one card from any other player's hand, equipment or judgement area.", true)

	func target_spec(e: CardEngine, player: int, _card: Card) -> Dictionary:
		return single_target(e, player, func(eng, _a, b): return rules(eng).has_any_cards(eng, b))

	func effect(e: CardEngine, source: int, target: int, _card: Card) -> void:
		var cid := await rules(e).choose_card_of(e, source, target, "Dismantle: choose a card to discard")
		if cid >= 0:
			await rules(e).discard_cards(e, [cid], source)


class Snatch extends Trick:
	func _init() -> void:
		super(&"snatch", "Snatch", "Take one card from a player at distance 1 (hand, equipment or judgement area).", true)

	func target_spec(e: CardEngine, player: int, _card: Card) -> Dictionary:
		return single_target(e, player, func(eng, a, b): return rules(eng).has_any_cards(eng, b) and rules(eng).distance(eng, a, b) <= 1)

	func effect(e: CardEngine, source: int, target: int, _card: Card) -> void:
		var cid := await rules(e).choose_card_of(e, source, target, "Snatch: choose a card to take")
		if cid >= 0:
			await e.move_cards([cid], Sgs.hand(source), {"why": "snatch", "by": source, "from_player": target})


class Windfall extends Trick:
	func _init() -> void:
		super(&"windfall", "Something for Nothing", "Draw 2 cards.", false)

	func effect(e: CardEngine, source: int, _target: int, _card: Card) -> void:
		await rules(e).draw_cards(e, source, 2)


class PeachGarden extends Trick:
	func _init() -> void:
		super(&"peach_garden", "Peach Garden", "Every player recovers 1 HP.", false)

	func on_play(e: CardEngine, player: int, card: Card, _targets: Array) -> void:
		await super(e, player, card, e.state.alive_from(player))

	func effect(e: CardEngine, _source: int, target: int, _card: Card) -> void:
		await rules(e).heal(e, target, 1)


class Harvest extends Trick:
	func _init() -> void:
		super(&"harvest", "Bountiful Harvest", "Reveal one card per living player; starting with you, each player takes one.", false)

	func on_play(e: CardEngine, player: int, card: Card, _targets: Array) -> void:
		var order := e.state.alive_from(player)
		var pool := await rules(e).reveal_from_draw(e, order.size())
		for t in order:
			if e.is_over:
				return
			if not e.state.player(t).alive or pool.is_empty():
				continue
			if await rules(e).trick_effect(e, player, t, card):
				var p := Prompt.choose_cards(t, "Bountiful Harvest: take a card", pool, 1, 1)
				var resp := await e.ask(p)
				var cid: int = resp["cards"][0] if resp.has("cards") else pool[0]
				pool.erase(cid)
				await e.move_cards([cid], Sgs.hand(t), {"why": "harvest", "by": t})


class Barbarians extends AllOthersTrick:
	func _init() -> void:
		super(&"barbarians", "Barbarians", "Every other player must play a Strike or take 1 damage from you.", true)

	func effect(e: CardEngine, source: int, target: int, card: Card) -> void:
		var played := await rules(e).ask_card_as(e, target, &"strike", "Barbarians: play a Strike or take 1 damage", {"bot": "accept"})
		if played == null:
			await rules(e).damage(e, source, target, 1, Sgs.NATURE_NONE, card.id)


class Arrows extends AllOthersTrick:
	func _init() -> void:
		super(&"arrows", "Arrow Barrage", "Every other player must play a Dodge or take 1 damage from you.", true)

	func effect(e: CardEngine, source: int, target: int, card: Card) -> void:
		var played := await rules(e).ask_card_as(e, target, &"dodge", "Arrow Barrage: play a Dodge or take 1 damage", {"bot": "accept"})
		if played == null:
			await rules(e).damage(e, source, target, 1, Sgs.NATURE_NONE, card.id)


class Duel extends Trick:
	func _init() -> void:
		super(&"duel", "Duel", "You and the target alternate playing Strikes, target first. Whoever cannot takes 1 damage from the other.", true)

	func target_spec(e: CardEngine, player: int, _card: Card) -> Dictionary:
		return single_target(e, player)

	func effect(e: CardEngine, source: int, target: int, card: Card) -> void:
		var r := rules(e)
		var attacker := target
		var defender := source
		while true:
			if e.is_over:
				return
			var played := await r.ask_card_as(e, attacker, &"strike", "Duel: play a Strike", {"bot": "accept"})
			if played == null:
				await r.damage(e, defender, attacker, 1, Sgs.NATURE_NONE, card.id)
				return
			var tmp := attacker
			attacker = defender
			defender = tmp


class BorrowedSword extends Trick:
	func _init() -> void:
		super(&"borrowed_sword", "Borrowed Sword", "Choose a player with a weapon and a player in their attack range. They Strike that player or give you their weapon.", true)

	func target_spec(e: CardEngine, player: int, _card: Card) -> Dictionary:
		var r := rules(e)
		var spec := single_target(e, player, func(eng, _a, b): return r.equip_of(eng, b, &"weapon") != null and not r.players_in_attack_range(eng, b).is_empty())
		return spec

	func effect(e: CardEngine, source: int, target: int, _card: Card) -> void:
		var r := rules(e)
		var weapon := r.equip_of(e, target, &"weapon")
		if weapon == null:
			return
		var victims := r.players_in_attack_range(e, target)
		if victims.is_empty():
			return
		var vp := Prompt.choose_players(source, "Borrowed Sword: who must be attacked?", victims, 1, 1)
		var victim: int = (await e.ask(vp)).get("players", [victims[0]])[0]
		var strike := await r.ask_card_as(e, target, &"strike", "Borrowed Sword: Strike %s or give away your weapon" % e.state.player(victim).name, {"bot": "accept"})
		if strike != null:
			await r.resolve_strike(e, target, victim, strike, r.strike_nature(e, strike), 1)
		else:
			await e.move_cards([weapon.id], Sgs.hand(source), {"why": "borrowed_sword", "by": source})


class Blaze extends Trick:
	func _init() -> void:
		super(&"blaze", "Blaze", "Target shows a hand card. If you discard a card of the same suit, they take 1 fire damage.", true)

	func target_spec(e: CardEngine, player: int, _card: Card) -> Dictionary:
		return single_target(e, player, func(eng, _a, b): return eng.state.zone(Sgs.hand(b)).size() > 0)

	func effect(e: CardEngine, source: int, target: int, card: Card) -> void:
		var r := rules(e)
		var hand := e.state.zone(Sgs.hand(target)).cards
		if hand.is_empty():
			return
		var shown: int = (await e.ask(Prompt.choose_cards(target, "Blaze: show a hand card", hand, 1, 1))).get("cards", [hand[0]])[0]
		var suit := e.card(shown).suit
		e.emit_event(&"sgs_card_shown", {"player": target, "card": shown, "card_ids": [shown], "to": source})
		var matching := e.state.zone(Sgs.hand(source)).cards.filter(func(c): return e.card(c).suit == suit and c != card.id)
		if matching.is_empty():
			return
		var resp := await e.ask(Prompt.choose_cards(source, "Blaze: discard a %s card to deal 1 fire damage" % suit, matching, 0, 1, true))
		if resp.get("pass", false):
			return
		await r.discard_cards(e, resp["cards"], source)
		await r.damage(e, source, target, 1, Sgs.NATURE_FIRE, card.id)


class Chain extends Trick:
	func _init() -> void:
		super(&"chain", "Iron Chain", "Chain players together so they share elemental damage. (Not implemented yet.)", true)
		implemented = false

	func can_play(_e: CardEngine, _player: int, _card: Card) -> bool:
		return false
