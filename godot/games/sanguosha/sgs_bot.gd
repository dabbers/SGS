class_name SgsBot
extends RefCounted
## Bot policy for Sanguosha. It only uses information a human at the table
## would have: its own role, the revealed king, roles of dead players, and
## what everyone has done so far (who hurt or helped whom, from the public
## event log). It never peeks at hidden roles or hands.

const ENEMY := &"enemy"
const ALLY := &"ally"
const UNKNOWN := &"unknown"

# Card value when deciding what to keep / give away (higher = keep).
const KEEP_VALUE := {
	"peach": 6, "dodge": 5, "negate": 4, "strike": 3, "strike_fire": 3, "strike_thunder": 3, "wine": 2,
}


static func rules(e: CardEngine) -> SgsRules:
	return e.rules as SgsRules


static func king_seat(e: CardEngine) -> int:
	for p in e.state.players:
		if p.role == Sgs.ROLE_KING:
			return p.id
	return -1


static func public_role(e: CardEngine, seat: int) -> StringName:
	var p := e.state.player(seat)
	return p.role if p.role_revealed else &""


## Positive = has acted like a rebel, negative = has acted like a loyalist.
## Computed incrementally from the public event log and cached on the state.
static func suspicion(e: CardEngine, seat: int) -> float:
	var cache: Dictionary = e.state.vars.get("bot_suspicion", {"seq": 0, "scores": {}, "grudges": {}})
	var scores: Dictionary = cache["scores"]
	var grudges: Dictionary = cache.get("grudges", {})
	var king := king_seat(e)
	var from: int = int(cache["seq"])
	for i in range(from, e.log.size()):
		var ev: Dictionary = e.log[i]
		match ev.get("type", ""):
			"sgs_damage":
				var src := int(ev.get("source", -1))
				if src < 0:
					continue
				var tgt := int(ev["target"])
				if not grudges.has(tgt):
					grudges[tgt] = {}
				grudges[tgt][src] = int(grudges[tgt].get(src, 0)) + 1
				if tgt == king:
					_bump(scores, src, 2.0)
				elif public_role(e, tgt) == Sgs.ROLE_REBEL:
					_bump(scores, src, -1.5)
				elif public_role(e, tgt) == Sgs.ROLE_LOYALIST:
					_bump(scores, src, 1.0)
			"sgs_card_used":
				var who := int(ev.get("player", -1))
				if ev.get("rescue", false):
					var tgt := int(ev.get("target", -1))
					if tgt == king:
						_bump(scores, who, -2.0)
					elif public_role(e, tgt) == Sgs.ROLE_REBEL:
						_bump(scores, who, 1.5)
					continue
				var def_id := StringName(ev.get("as", ""))
				if not e.defs.has(def_id) or not (e.defs[def_id] as SgsCardDef).harmful:
					continue
				for t in ev.get("targets", []):
					if int(t) == king:
						_bump(scores, who, 1.0)
					elif public_role(e, int(t)) == Sgs.ROLE_REBEL:
						_bump(scores, who, -0.5)
	cache["seq"] = e.log.size()
	cache["scores"] = scores
	cache["grudges"] = grudges
	e.state.vars["bot_suspicion"] = cache
	return float(scores.get(seat, 0.0))


## Has `other` dealt damage to `me`?
static func damaged_me(e: CardEngine, me: int, other: int) -> bool:
	suspicion(e, me)  # refresh cache
	var grudges: Dictionary = e.state.vars.get("bot_suspicion", {}).get("grudges", {})
	return int(grudges.get(me, {}).get(other, 0)) > 0


## Roles that hidden players could still have, deduced from the role list
## minus every revealed role and my own. {role: count}
static func hidden_pool(e: CardEngine, me: int) -> Dictionary:
	var pool := {}
	for role in Sgs.role_set(e.state.players.size()):
		pool[role] = int(pool.get(role, 0)) + 1
	for p in e.state.players:
		if p.role_revealed or p.id == me:
			pool[p.role] = int(pool.get(p.role, 0)) - 1
	for role in pool.keys():
		if pool[role] <= 0:
			pool.erase(role)
	return pool


static func _bump(scores: Dictionary, seat: int, delta: float) -> void:
	scores[seat] = float(scores.get(seat, 0.0)) + delta


## How `me` should treat `other`, from public information only.
static func stance(e: CardEngine, me: int, other: int) -> StringName:
	if me == other:
		return ALLY
	var my_role := e.state.player(me).role
	var known := public_role(e, other)
	var king := king_seat(e)
	var pool := hidden_pool(e, me)
	match my_role:
		Sgs.ROLE_KING, Sgs.ROLE_LOYALIST:
			if other == king or known == Sgs.ROLE_LOYALIST:
				return ALLY
			if known == Sgs.ROLE_REBEL or known == Sgs.ROLE_SPY:
				return ENEMY
			var s := suspicion(e, other)
			if s >= 1.0:
				return ENEMY
			if s <= -1.0:
				return ALLY
			if not pool.has(Sgs.ROLE_LOYALIST):
				return ENEMY   # every hidden player left is a rebel or the spy
			if damaged_me(e, me, other):
				return ENEMY
			return UNKNOWN
		Sgs.ROLE_REBEL:
			if other == king or known == Sgs.ROLE_LOYALIST or known == Sgs.ROLE_SPY:
				return ENEMY
			if known == Sgs.ROLE_REBEL:
				return ALLY
			var s := suspicion(e, other)
			if s >= 1.0:
				return ALLY
			if s <= -1.0:
				return ENEMY
			if not pool.has(Sgs.ROLE_REBEL):
				return ENEMY   # no hidden rebels left: everyone unknown is against us
			if not pool.has(Sgs.ROLE_LOYALIST) and not pool.has(Sgs.ROLE_SPY):
				return ALLY
			if damaged_me(e, me, other):
				return ENEMY
			return UNKNOWN
		Sgs.ROLE_SPY:
			# Keep the king alive while rebels could remain; then turn on everyone.
			var rebels_left := pool.has(Sgs.ROLE_REBEL)
			for q in e.state.alive_players():
				if public_role(e, q) == Sgs.ROLE_REBEL:
					rebels_left = true
			if other == king:
				return ALLY if rebels_left else ENEMY
			if known == Sgs.ROLE_REBEL or suspicion(e, other) >= 1.0:
				return ENEMY
			if not rebels_left:
				return ENEMY   # only loyalists remain; the spy must be last standing
			if damaged_me(e, me, other):
				return ENEMY
			return UNKNOWN
	return UNKNOWN


static func filter_stance(e: CardEngine, me: int, seats: Array, want: StringName) -> Array:
	return seats.filter(func(q): return stance(e, me, int(q)) == want)


## Enemies first, then (for rebels only) unknowns; royals never attack unknowns.
static func attack_targets(e: CardEngine, me: int, candidates: Array) -> Array:
	var enemies := filter_stance(e, me, candidates, ENEMY)
	if not enemies.is_empty():
		return enemies
	if e.state.player(me).role == Sgs.ROLE_REBEL:
		return filter_stance(e, me, candidates, UNKNOWN)
	return []


static func pick_weakest(e: CardEngine, seats: Array, brng: CardRng) -> int:
	var best := -1
	var best_hp := 999
	var pool := seats.duplicate()
	brng.shuffle(pool)
	for q in pool:
		var hp := e.state.player(int(q)).hp
		if hp < best_hp:
			best_hp = hp
			best = int(q)
	return best


static func keep_value(e: CardEngine, cid: int) -> int:
	var d := e.def_of(cid) as SgsCardDef
	if KEEP_VALUE.has(String(d.id)):
		return KEEP_VALUE[String(d.id)]
	if d.type == SgsCardDef.TYPE_EQUIPMENT:
		return 1
	return 2


## Score a card for the play phase; < 0 means "do not play".
static func play_score(e: CardEngine, me: int, cid: int, as_def: StringName) -> float:
	var r := rules(e)
	var p := e.state.player(me)
	var d := e.defs[as_def] as SgsCardDef
	var others := r.others(e, me)
	match as_def:
		&"peach":
			return 100.0 if p.hp < p.max_hp else -1.0
		&"windfall", &"harvest":
			return 70.0
		&"peach_garden":
			for q in e.state.alive_players():
				if stance(e, me, q) != ENEMY and e.state.player(q).hp < e.state.player(q).max_hp:
					return 60.0
			return -1.0
		&"wine":
			if r.cards_usable_as(e, me, &"strike").size() > 0 and not attack_targets(e, me, r.players_in_attack_range(e, me)).is_empty() and r.strikes_used(e, me) < r.strike_limit(e, me):
				return 56.0
			return -1.0
		&"barbarians", &"arrows":
			var enemies := filter_stance(e, me, others, ENEMY).size()
			var allies := filter_stance(e, me, others, ALLY).size()
			return 45.0 if enemies > allies else -1.0
		&"lightning":
			return 5.0 if e.state.alive_players().size() >= 5 else -1.0
	if d.type == SgsCardDef.TYPE_EQUIPMENT:
		var current := r.equip_of(e, me, d.subtype)
		if current == null:
			return 80.0
		if d.subtype == &"weapon" and (d as SgsCardsEquipment.Weapon).range > (e.defs[current.def_id] as SgsCardsEquipment.Weapon).range:
			return 65.0
		return -1.0
	if d.harmful:
		var spec := d.target_spec(e, me, e.card(cid))
		if int(spec["max"]) == 0:
			return -1.0
		var targets := attack_targets(e, me, spec["candidates"])
		if targets.is_empty():
			return -1.0
		if d.has_tag(&"strike"):
			return 55.0
		if as_def == &"duel":
			return 50.0
		if as_def == &"dismantle" or as_def == &"snatch":
			for t in targets:
				if r.equip_of(e, int(t), &"armor") != null:
					return 58.0   # stripping armor beats a plain strike
		return 48.0
	return 20.0


static func answer(e: CardEngine, prompt: Prompt, brng: CardRng) -> Dictionary:
	var me := prompt.player
	var r := rules(e)
	var hint: String = prompt.data.get("bot", "")
	match prompt.kind:
		Prompt.KIND_PLAY:
			return _answer_play(e, me, prompt, brng)
		Prompt.KIND_CHOOSE_PLAYERS:
			var pool := prompt.players.duplicate()
			match hint:
				"target":
					var harmful: bool = prompt.data.get("harmful", true)
					if pool == [me]:
						return {"players": [me]}   # self-targeting card (Lightning)
					var preferred := attack_targets(e, me, pool) if harmful else filter_stance(e, me, pool, ALLY)
					if preferred.is_empty():
						if prompt.can_pass:
							return {"pass": true}
					else:
						pool = preferred
					if harmful:
						var king := king_seat(e)
						if pool.has(king) and e.state.player(me).role == Sgs.ROLE_REBEL:
							return {"players": [king]}
						return {"players": [pick_weakest(e, pool, brng)]}
				"victim":
					var enemies := attack_targets(e, me, pool)
					if not enemies.is_empty():
						pool = enemies
				_:
					var allies := filter_stance(e, me, pool, ALLY)
					if not allies.is_empty():
						pool = allies
			brng.shuffle(pool)
			return {"players": pool.slice(0, maxi(prompt.min_players, 1))}
		Prompt.KIND_CHOOSE_CARDS:
			return _answer_cards(e, me, prompt, brng, hint)
		Prompt.KIND_CONFIRM:
			return {"option": "no" if hint == "decline" else "yes"}
		Prompt.KIND_CHOOSE_OPTION:
			return {"option": prompt.option_ids()[0]}
	return {}


static func _answer_play(e: CardEngine, me: int, prompt: Prompt, brng: CardRng) -> Dictionary:
	var r := rules(e)
	var p := e.state.player(me)
	# Active skills first when clearly useful.
	for o in prompt.options:
		match o["id"]:
			"skill:qingnang":
				return {"option": o["id"]}
			"skill:zhiheng":
				var junk := e.state.zone(Sgs.hand(me)).cards.filter(func(c): return keep_value(e, int(c)) <= 2)
				if junk.size() >= 2:
					return {"option": o["id"]}
			"skill:rende":
				if e.state.zone(Sgs.hand(me)).size() >= 4 and not filter_stance(e, me, r.others(e, me), ALLY).is_empty():
					return {"option": o["id"]}
	var best := -1
	var best_score := 0.0
	for cid in prompt.cards:
		for as_def in r.playable_as(e, me, cid):
			var s := play_score(e, me, cid, as_def)
			if s <= 0.0:
				continue
			# Prefer playing a real Strike over converting a Dodge into one.
			if as_def == &"strike" and e.card(cid).def_id == &"dodge":
				s -= 10.0
			s += brng.randi_range(0, 2)
			if s > best_score:
				best_score = s
				best = cid
	if best < 0:
		return {"pass": true}
	return {"cards": [best]}


static func _answer_cards(e: CardEngine, me: int, prompt: Prompt, brng: CardRng, hint: String) -> Dictionary:
	var r := rules(e)
	match hint:
		"accept":
			return {"cards": [prompt.cards[0]]}
		"decline":
			return {"pass": true}
		"rescue":
			var target := int(prompt.data["target"])
			return {"cards": [prompt.cards[0]]} if stance(e, me, target) == ALLY else {"pass": true}
		"negate":
			var target := int(prompt.data["target"])
			var harmful: bool = prompt.data["harmful"]
			var negated: bool = prompt.data["negated"]
			var st := stance(e, me, target)
			var want := (harmful and st == ALLY) or (not harmful and st == ENEMY)
			if negated:
				want = (harmful and st == ENEMY) or (not harmful and st == ALLY)
			return {"cards": [prompt.cards[0]]} if want else {"pass": true}
	# Picking from another player's cards: take equipment (public) first.
	if prompt.data.has("of_player"):
		var target := int(prompt.data["of_player"])
		var equip := prompt.cards.filter(func(c): return e.card(int(c)).zone == Sgs.equip(target))
		var judge := prompt.cards.filter(func(c): return e.card(int(c)).zone == Sgs.judge(target))
		if stance(e, me, target) == ALLY and not judge.is_empty():
			return {"cards": [judge[0]]}   # free an ally from a delayed trick
		# Against an enemy: armor first (it is what keeps them alive), then weapon, then horses.
		for subtype in [&"armor", &"weapon", &"horse_minus", &"horse_plus"]:
			for c in equip:
				if e.def_of(int(c)).subtype == subtype:
					return {"cards": [int(c)]}
		return {"cards": [brng.pick(prompt.cards)]}
	# Taking cards for myself (harvest): most valuable first. Discarding: least valuable first.
	var pool := prompt.cards.duplicate()
	if prompt.min_cards == 0 and prompt.can_pass:
		return {"pass": true}
	var discarding: bool = prompt.title.begins_with("Discard") or prompt.data.get("discard", false)
	pool.sort_custom(func(a, b):
		var va := keep_value(e, int(a)) if e.state.cards.has(int(a)) else 0
		var vb := keep_value(e, int(b)) if e.state.cards.has(int(b)) else 0
		return va < vb if discarding else va > vb)
	return {"cards": pool.slice(0, maxi(prompt.min_cards, 1))}
