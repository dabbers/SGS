class_name SgsCardsEquipment
extends RefCounted
## Weapons, armor and horses. Equipment registers Triggers tagged with its
## card id; SgsRules removes them when the card leaves the equipment zone.


static func build(defs: Dictionary) -> void:
	var list := [
		Weapon.new(&"crossbow", "Crossbow", 1, "Range 1. You may play any number of Strikes in your play phase."),
		Weapon.new(&"double_swords", "Double Swords", 2, "Range 2. (Gender effect not implemented.)"),
		Weapon.new(&"ice_sword", "Ice Sword", 2, "Range 2. When your Strike hits, you may discard 2 of the target's cards instead of dealing damage."),
		Weapon.new(&"black_pommel", "Black Pommel", 2, "Range 2. Your Strikes ignore armor."),
		Weapon.new(&"axe", "Axe", 3, "Range 3. When your Strike is dodged, you may discard 2 other cards to make it hit anyway."),
		Weapon.new(&"green_dragon", "Green Dragon Blade", 3, "Range 3. When your Strike is dodged, you may play another Strike at the same target."),
		Weapon.new(&"serpent_spear", "Serpent Spear", 3, "Range 3. (Two-card Strike not implemented.)"),
		Weapon.new(&"sky_scorcher", "Sky Scorcher", 4, "Range 4. (Multi-target Strike not implemented.)"),
		Weapon.new(&"kylin_bow", "Kylin Bow", 5, "Range 5. When your Strike damages a player, you may discard one of their horses."),
		Weapon.new(&"ancient_scimitar", "Ancient Scimitar", 2, "Range 2. Your Strike deals +1 damage to a player with no hand cards."),
		Weapon.new(&"fire_fan", "Fire Fan", 4, "Range 4. (Fire conversion not implemented.)"),
		Armor.new(&"eight_trigrams", "Eight Trigrams", "When you need a Dodge, you may judge: a red card counts as a Dodge."),
		Armor.new(&"black_shield", "Black Shield", "Black Strikes have no effect on you."),
		Armor.new(&"wooden_armor", "Wooden Armor", "Immune to normal Strikes, Barbarians and Arrow Barrage. Fire damage against you is +1."),
		Armor.new(&"silver_helmet", "Silver Helmet", "Damage of more than 1 against you is reduced to 1."),
		Horse.new(&"horse_plus", "Horse +1", 1, "Other players see you at +1 distance."),
		Horse.new(&"horse_minus", "Horse -1", -1, "You see other players at -1 distance."),
	]
	for d in list:
		defs[d.id] = d


class Equipment extends SgsCardDef:
	func _init(p_id: StringName, p_name: String, p_subtype: StringName, p_text: String) -> void:
		super(p_id, p_name, TYPE_EQUIPMENT, p_subtype)
		text = p_text

	func can_play(_e: CardEngine, _player: int, _card: Card) -> bool:
		return true

	func on_play(e: CardEngine, player: int, card: Card, _targets: Array) -> void:
		await rules(e).equip(e, player, card)


class Weapon extends Equipment:
	var range: int = 1

	func _init(p_id: StringName, p_name: String, p_range: int, p_text: String) -> void:
		super(p_id, p_name, &"weapon", p_text)
		range = p_range

	func on_equip(e: CardEngine, player: int, card: Card) -> void:
		var t: Trigger = null
		match id:
			&"black_pommel":
				t = BlackPommel.new(player, card.id)
			&"ice_sword":
				t = IceSword.new(player, card.id)
			&"axe":
				t = Axe.new(player, card.id)
			&"green_dragon":
				t = GreenDragon.new(player, card.id)
			&"kylin_bow":
				t = KylinBow.new(player, card.id)
			&"ancient_scimitar":
				t = AncientScimitar.new(player, card.id)
		if t != null:
			e.register_trigger(t)


class Armor extends Equipment:
	func _init(p_id: StringName, p_name: String, p_text: String) -> void:
		super(p_id, p_name, &"armor", p_text)

	func on_equip(e: CardEngine, player: int, card: Card) -> void:
		var t: Trigger = null
		match id:
			&"eight_trigrams":
				t = EightTrigrams.new(player, card.id)
			&"black_shield":
				t = BlackShield.new(player, card.id)
			&"wooden_armor":
				t = WoodenArmor.new(player, card.id)
			&"silver_helmet":
				t = SilverHelmet.new(player, card.id)
		if t != null:
			e.register_trigger(t)


class Horse extends Equipment:
	var delta: int = 0

	func _init(p_id: StringName, p_name: String, p_delta: int, p_text: String) -> void:
		super(p_id, p_name, &"horse_plus" if p_delta > 0 else &"horse_minus", p_text)
		delta = p_delta


# --- equipment triggers ----------------------------------------------------

class EquipTrigger extends Trigger:
	func _init(p_timings: Array, p_owner: int, p_card: int, p_source: String) -> void:
		super(p_timings, p_owner, p_source, 10)
		source_card = p_card


class BlackPommel extends EquipTrigger:
	func _init(p_owner: int, p_card: int) -> void:
		super([Sgs.T_STRIKE_USED], p_owner, p_card, "Black Pommel")

	func is_active(_e: CardEngine, _t: StringName, ctx: Dictionary) -> bool:
		return ctx["source"] == owner

	func on_trigger(_e: CardEngine, _t: StringName, ctx: Dictionary) -> void:
		ctx["ignore_armor"] = true


class IceSword extends EquipTrigger:
	func _init(p_owner: int, p_card: int) -> void:
		super([Sgs.T_STRIKE_HIT], p_owner, p_card, "Ice Sword")

	func is_active(e: CardEngine, _t: StringName, ctx: Dictionary) -> bool:
		return ctx["source"] == owner and SgsCardDef.rules(e).has_any_cards(e, ctx["target"], false)

	func on_trigger(e: CardEngine, _t: StringName, ctx: Dictionary) -> void:
		var r := SgsCardDef.rules(e)
		var resp := await e.ask(Prompt.confirm(owner, "Ice Sword: discard 2 of the target's cards instead of dealing damage?"))
		if resp.get("option", "no") != "yes":
			return
		ctx["skip_damage"] = true
		for i in 2:
			var cid := await r.choose_card_of(e, owner, ctx["target"], "Ice Sword: choose a card to discard", false)
			if cid < 0:
				break
			await r.discard_cards(e, [cid], owner)


class Axe extends EquipTrigger:
	func _init(p_owner: int, p_card: int) -> void:
		super([Sgs.T_STRIKE_DODGED], p_owner, p_card, "Axe")

	func is_active(e: CardEngine, _t: StringName, ctx: Dictionary) -> bool:
		return ctx["source"] == owner and _payable(e).size() >= 2

	func _payable(e: CardEngine) -> Array:
		var out := e.state.zone(Sgs.hand(owner)).cards.duplicate()
		for c in e.state.zone(Sgs.equip(owner)).cards:
			if c != source_card:
				out.append(c)
		return out

	func on_trigger(e: CardEngine, _t: StringName, ctx: Dictionary) -> void:
		var p := Prompt.choose_cards(owner, "Axe: discard 2 cards to force the Strike to hit?", _payable(e), 2, 2, true)
		p.data = {"bot": "decline"}
		var resp := await e.ask(p)
		if resp.get("pass", false):
			return
		await SgsCardDef.rules(e).discard_cards(e, resp["cards"], owner)
		ctx["force_hit"] = true


class GreenDragon extends EquipTrigger:
	func _init(p_owner: int, p_card: int) -> void:
		super([Sgs.T_STRIKE_DODGED], p_owner, p_card, "Green Dragon Blade")

	func is_active(_e: CardEngine, _t: StringName, ctx: Dictionary) -> bool:
		return ctx["source"] == owner and not ctx.get("force_hit", false)

	func on_trigger(e: CardEngine, _t: StringName, ctx: Dictionary) -> void:
		var r := SgsCardDef.rules(e)
		var strike := await r.ask_card_as(e, owner, &"strike", "Green Dragon Blade: play another Strike at the same target?", {"bot": "accept"})
		if strike != null:
			ctx["retry"] = strike.id


class KylinBow extends EquipTrigger:
	func _init(p_owner: int, p_card: int) -> void:
		super([Sgs.T_DAMAGE_AFTER], p_owner, p_card, "Kylin Bow")

	func is_active(e: CardEngine, _t: StringName, ctx: Dictionary) -> bool:
		if ctx["source"] != owner or ctx["card"] < 0 or not e.def_of(ctx["card"]).has_tag(&"strike"):
			return false
		return not _horses(e, ctx["target"]).is_empty()

	func _horses(e: CardEngine, pid: int) -> Array:
		return e.state.zone(Sgs.equip(pid)).cards.filter(func(c): return e.def_of(c) is Horse)

	func on_trigger(e: CardEngine, _t: StringName, ctx: Dictionary) -> void:
		var p := Prompt.choose_cards(owner, "Kylin Bow: discard a horse of the target?", _horses(e, ctx["target"]), 0, 1, true)
		p.data = {"bot": "accept"}
		var resp := await e.ask(p)
		if not resp.get("pass", false) and not resp.get("cards", []).is_empty():
			await SgsCardDef.rules(e).discard_cards(e, resp["cards"], owner)


class AncientScimitar extends EquipTrigger:
	func _init(p_owner: int, p_card: int) -> void:
		super([Sgs.T_STRIKE_HIT], p_owner, p_card, "Ancient Scimitar")

	func is_active(e: CardEngine, _t: StringName, ctx: Dictionary) -> bool:
		return ctx["source"] == owner and e.state.zone(Sgs.hand(ctx["target"])).is_empty()

	func on_trigger(_e: CardEngine, _t: StringName, ctx: Dictionary) -> void:
		ctx["amount"] = int(ctx["amount"]) + 1


class EightTrigrams extends EquipTrigger:
	func _init(p_owner: int, p_card: int) -> void:
		super([Sgs.T_PROVIDE_CARD], p_owner, p_card, "Eight Trigrams")

	func is_active(_e: CardEngine, _t: StringName, ctx: Dictionary) -> bool:
		return ctx["player"] == owner and ctx["as"] == &"dodge" and not ctx.get("provided", false) and not ctx.get("ignore_armor", false)

	func on_trigger(e: CardEngine, _t: StringName, ctx: Dictionary) -> void:
		var resp := await e.ask(Prompt.confirm(owner, "Eight Trigrams: judge for a Dodge?"))
		if resp.get("option", "no") != "yes":
			return
		var j := await SgsCardDef.rules(e).judge(e, owner, "eight_trigrams")
		if j.is_red():
			ctx["provided"] = true


class BlackShield extends EquipTrigger:
	func _init(p_owner: int, p_card: int) -> void:
		super([Sgs.T_STRIKE_USED], p_owner, p_card, "Black Shield")

	func is_active(e: CardEngine, _t: StringName, ctx: Dictionary) -> bool:
		return ctx["target"] == owner and not ctx.get("ignore_armor", false) and e.card(ctx["card"]).is_black()

	func on_trigger(_e: CardEngine, _t: StringName, ctx: Dictionary) -> void:
		ctx["cancelled"] = true


class WoodenArmor extends EquipTrigger:
	func _init(p_owner: int, p_card: int) -> void:
		super([Sgs.T_STRIKE_USED, Sgs.T_TRICK_TARGETED, Sgs.T_DAMAGE_BEFORE], p_owner, p_card, "Wooden Armor")

	func is_active(e: CardEngine, t: StringName, ctx: Dictionary) -> bool:
		if ctx["target"] != owner:
			return false
		match t:
			Sgs.T_STRIKE_USED:
				return not ctx.get("ignore_armor", false) and ctx["nature"] == Sgs.NATURE_NONE
			Sgs.T_TRICK_TARGETED:
				return [&"barbarians", &"arrows"].has(e.card(ctx["card"]).def_id)
			Sgs.T_DAMAGE_BEFORE:
				return ctx["nature"] == Sgs.NATURE_FIRE
		return false

	func on_trigger(_e: CardEngine, t: StringName, ctx: Dictionary) -> void:
		if t == Sgs.T_DAMAGE_BEFORE:
			ctx["amount"] = int(ctx["amount"]) + 1
		else:
			ctx["cancelled"] = true


class SilverHelmet extends EquipTrigger:
	func _init(p_owner: int, p_card: int) -> void:
		super([Sgs.T_DAMAGE_BEFORE], p_owner, p_card, "Silver Helmet")
		priority = -10  # after other modifiers

	func is_active(_e: CardEngine, _t: StringName, ctx: Dictionary) -> bool:
		return ctx["target"] == owner and int(ctx["amount"]) > 1

	func on_trigger(_e: CardEngine, _t: StringName, ctx: Dictionary) -> void:
		ctx["amount"] = 1
