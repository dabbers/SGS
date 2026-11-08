class_name SgsBot
extends RefCounted
## Bot policy for Sanguosha. It only uses information a human at the table
## would have: its own role, the revealed king, roles of dead players, and
## what everyone has done so far (who hurt or helped whom, from the public
## event log). It never peeks at hidden roles or hands.

const ENEMY := &"enemy"
const ALLY := &"ally"
const UNKNOWN := &"unknown"

# The spy only attacks a king with at least this much HP while rebels remain.
const SPY_SAFE_KING_HP := 3

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


## Could a rebel still be alive, as far as `me` can tell from public information?
static func rebels_remain(e: CardEngine, me: int) -> bool:
	if hidden_pool(e, me).has(Sgs.ROLE_REBEL):
		return true
	for q in e.state.alive_players():
		if public_role(e, q) == Sgs.ROLE_REBEL:
			return true
	return false


## Which side `other` is probably on, from public information: Sgs.ROLE_KING
## (the king's side), Sgs.ROLE_REBEL, or &"" when there is no evidence yet.
## Besides revealed roles and behaviour it uses elimination: once every hidden
## rebel has been spotted, the remaining unknowns must be loyal, and vice versa.
static func side_guess(e: CardEngine, me: int, other: int) -> StringName:
	return _side_guesses(e, me).get(other, &"")


static func _side_guesses(e: CardEngine, me: int) -> Dictionary:
	var king := king_seat(e)
	var pool := hidden_pool(e, me)
	var out := {}
	var unknown: Array[int] = []
	var hidden_rebels := 0
	var hidden_loyalists := 0
	for q in e.state.alive_players():
		if q == me:
			continue
		var known := public_role(e, q)
		if q == king or known == Sgs.ROLE_LOYALIST:
			out[q] = Sgs.ROLE_KING
		elif known == Sgs.ROLE_REBEL:
			out[q] = Sgs.ROLE_REBEL
		elif known == Sgs.ROLE_SPY:
			continue
		else:
			var s := suspicion(e, q)
			if s >= 1.0:
				out[q] = Sgs.ROLE_REBEL
				hidden_rebels += 1
			elif s <= -1.0:
				out[q] = Sgs.ROLE_KING
				hidden_loyalists += 1
			else:
				unknown.append(q)
	var rebels_left := int(pool.get(Sgs.ROLE_REBEL, 0)) - hidden_rebels
	var loyal_left := int(pool.get(Sgs.ROLE_LOYALIST, 0)) - hidden_loyalists
	var spies_left := int(pool.get(Sgs.ROLE_SPY, 0))
	if not unknown.is_empty():
		if rebels_left <= 0 and spies_left <= 0:
			for q in unknown:
				out[q] = Sgs.ROLE_KING
		elif loyal_left <= 0 and spies_left <= 0:
			for q in unknown:
				out[q] = Sgs.ROLE_REBEL
	return out


## Rough fighting strength of a side as `me` sees it: every alive member counts
## for being there, for their HP and for the cards they hold. Players whose side
## is still unknown count half for each side.
static func side_strength(e: CardEngine, me: int, side: StringName) -> float:
	var guesses := _side_guesses(e, me)
	var total := 0.0
	for q in e.state.alive_players():
		if q == me:
			continue
		var g: StringName = guesses.get(q, &"")
		var weight := 1.0 if g == side else (0.5 if g == &"" else 0.0)
		if weight == 0.0:
			continue
		var p := e.state.player(q)
		total += weight * (2.0 + maxi(p.hp, 0) + 0.5 * e.state.zone(Sgs.hand(q)).size() + 0.5 * e.state.zone(Sgs.equip(q)).size())
	return total


## Chip at a king whose side is ahead, but only once everyone else has been
## placed (the loyalist is the better early target) and only while the king is
## healthy: the king must outlive the rebels for the spy to win at all, so a
## weakened king is protected instead.
static func _spy_can_chip_king(e: CardEngine, me: int) -> bool:
	if e.state.player(king_seat(e)).hp < SPY_SAFE_KING_HP:
		return false
	var guesses := _side_guesses(e, me)
	for q in e.state.alive_players():
		if q != me and q != king_seat(e) and guesses.get(q, &"") == &"":
			return false
	return true


## The king's side is ahead only on paper: everyone is placed, the king is its
## last member and too weak to be chipped at. Then the spy finishes the rebels
## instead and takes that king on alone, rather than idling.
static func _spy_faces_lone_weak_king(e: CardEngine, me: int) -> bool:
	if e.state.player(king_seat(e)).hp >= SPY_SAFE_KING_HP:
		return false
	var guesses := _side_guesses(e, me)
	for q in e.state.alive_players():
		if q != me and q != king_seat(e) and guesses.get(q, &"") != Sgs.ROLE_REBEL:
			return false
	return true


## The side that is currently ahead (ties go to the king's side: it starts
## ahead and is the spy's final opponent anyway).
static func stronger_side(e: CardEngine, me: int) -> StringName:
	if side_strength(e, me, Sgs.ROLE_KING) >= side_strength(e, me, Sgs.ROLE_REBEL):
		return Sgs.ROLE_KING
	return Sgs.ROLE_REBEL


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
			if not pool.has(Sgs.ROLE_LOYALIST):
				return ENEMY   # every hidden player left is a rebel or the spy, whatever they did for us
			var s := suspicion(e, other)
			if s >= 1.0:
				return ENEMY
			if s <= -1.0:
				return ALLY
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
			# The spy wins only as the last one standing, so it plays the balancer:
			# keep the king alive while rebels could remain, wear down whichever
			# side is ahead (the loyalist rather than the king early on), and prop
			# up the side that is behind. Once the rebels are gone, everyone is prey.
			if not rebels_remain(e, me):
				# Loyalists first. The king is fair game once it is just the two of us,
				# and may be worn down while healthy before that, but never finished
				# while a loyalist lives: that would still hand the rebels the win.
				if other != king:
					return ENEMY
				if e.state.alive_players().size() == 2 or e.state.player(king).hp >= SPY_SAFE_KING_HP:
					return ENEMY
				return ALLY
			var strong := stronger_side(e, me)
			if other == king:
				return ENEMY if strong == Sgs.ROLE_KING and _spy_can_chip_king(e, me) else ALLY
			var guess := side_guess(e, me, other)
			if guess == &"":
				return UNKNOWN
			if guess == strong:
				return ENEMY
			if strong == Sgs.ROLE_KING and _spy_faces_lone_weak_king(e, me):
				return ENEMY
			return ALLY
	return UNKNOWN


static func filter_stance(e: CardEngine, me: int, seats: Array, want: StringName) -> Array:
	return seats.filter(func(q): return stance(e, me, int(q)) == want)


## Enemies first, then (for rebels only) unknowns; royals never attack unknowns.
static func attack_targets(e: CardEngine, me: int, candidates: Array) -> Array:
	var enemies := filter_stance(e, me, candidates, ENEMY)
	if not enemies.is_empty():
		if e.state.player(me).role == Sgs.ROLE_SPY and enemies.size() > 1:
			enemies.erase(king_seat(e))   # the balancer wears down loyalists before the king
		return enemies
	if e.state.player(me).role == Sgs.ROLE_REBEL:
		return filter_stance(e, me, candidates, UNKNOWN)
	return []


## Who `me` would spend a beneficial effect on: allies, failing that players not
## known to be enemies. The spy is stricter: protecting a player (stance ALLY)
## is not the same as building them up, so it only helps itself and the side
## that is behind; a king it merely keeps alive gets nothing extra.
static func help_targets(e: CardEngine, me: int, candidates: Array) -> Array:
	if e.state.player(me).role == Sgs.ROLE_SPY and rebels_remain(e, me):
		var weaker := Sgs.ROLE_REBEL if stronger_side(e, me) == Sgs.ROLE_KING else Sgs.ROLE_KING
		return candidates.filter(func(q): return int(q) == me or side_guess(e, me, int(q)) == weaker)
	var allies := filter_stance(e, me, candidates, ALLY)
	if not allies.is_empty():
		return allies
	return filter_stance(e, me, candidates, UNKNOWN)


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
			var king := king_seat(e)
			if p.role == Sgs.ROLE_REBEL and targets.has(king) and not r.in_attack_range(e, me, king):
				return 58.0   # a Strike cannot reach the king, but a Duel can
			for t in targets:
				if r.equip_of(e, int(t), &"armor") != null:
					return 57.0   # armour stops Strikes, not Duels
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
					var preferred := attack_targets(e, me, pool) if harmful else help_targets(e, me, pool)
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
					# Something good for the chosen player.
					var worthy := help_targets(e, me, pool)
					if not worthy.is_empty():
						pool = worthy
					elif prompt.can_pass and prompt.min_players == 0:
						return {"pass": true}
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
				for q in help_targets(e, me, e.state.alive_players()):
					if e.state.player(q).hp < e.state.player(q).max_hp:
						return {"option": o["id"]}
			"skill:zhiheng":
				var junk := e.state.zone(Sgs.hand(me)).cards.filter(func(c): return keep_value(e, int(c)) <= 2)
				if junk.size() >= 2:
					return {"option": o["id"]}
			"skill:rende":
				if e.state.zone(Sgs.hand(me)).size() >= 4 and not help_targets(e, me, r.others(e, me)).is_empty():
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
			var save := stance(e, me, target) == ALLY
			if e.state.player(me).role == Sgs.ROLE_SPY and target == king_seat(e) and rebels_remain(e, me):
				save = true   # a dead king hands the game to the rebels, whatever the balance
			return {"cards": [prompt.cards[0]]} if save else {"pass": true}
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
	var keep_dodge := -1   # a rebel keeps one Dodge back: it is the one card that stops the next Strike
	var spare := []        # a third Peach or Dodge is hoarding: it crowds out the cards that win fights
	if discarding:
		var p := e.state.player(me)
		var held := {&"peach": 1 if p.hp >= p.max_hp else 0}   # at full HP a second Peach is dead weight too
		for c in pool:
			if not e.state.cards.has(int(c)):
				continue
			var id := e.card(int(c)).def_id
			if id == &"dodge" and keep_dodge < 0 and e.state.player(me).role == Sgs.ROLE_REBEL:
				keep_dodge = int(c)
			if id == &"peach" or id == &"dodge":
				held[id] = int(held.get(id, 0)) + 1
				if held[id] > 2:
					spare.append(int(c))
	var value := func(c: int) -> int:
		if c == keep_dodge:
			return KEEP_VALUE["peach"] + 1
		if spare.has(c):
			return 1
		return keep_value(e, c) if e.state.cards.has(c) else 0
	pool.sort_custom(func(a, b):
		var va: int = value.call(int(a))
		var vb: int = value.call(int(b))
		return va < vb if discarding else va > vb)
	return {"cards": pool.slice(0, maxi(prompt.min_cards, 1))}
