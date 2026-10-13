extends TestCase


func _game(seed_value: int, cfg: Dictionary = {}) -> CardEngine:
	var e := CardEngine.new()
	var c := {"players": 4, "bots": []}
	c.merge(cfg, true)
	e.start(SgsRules.new(), c, seed_value)
	return e


func _r(e: CardEngine) -> SgsRules:
	return e.rules as SgsRules


func test_setup_roles_heroes_and_hands() -> void:
	var e := _game(1, {"players": 5})
	var roles := e.state.players.map(func(p): return p.role)
	roles.sort()
	var expected := Array(Sgs.role_set(5))
	expected.sort()
	assert_eq(roles, expected, "5-player role set")
	for p in e.state.players:
		if p.id != e.state.current_player:
			assert_eq(e.state.zone(Sgs.hand(p.id)).size(), 4, "opening hand")
		assert_true(p.hp == p.max_hp and p.hp >= 3, "hp set from hero")
		assert_true(p.hero_id != &"", "hero assigned")
		if p.role == Sgs.ROLE_KING:
			assert_true(p.role_revealed, "king revealed")
			assert_eq(e.state.current_player, p.id, "king goes first")
		else:
			assert_false(p.role_revealed, "others hidden")
	assert_eq(e.pending.player, e.state.current_player)
	assert_eq(e.pending.kind, Prompt.KIND_PLAY)
	assert_eq(e.state.zone(Sgs.hand(e.state.current_player)).size(), 6, "king drew 2")


## Test helper: move `n` copies of a def from the draw pile straight into a zone.
func _give(e: CardEngine, pid: int, def_id: StringName, n: int = 1, zone: StringName = &"") -> Array[int]:
	var out: Array[int] = []
	var dest := zone if zone != &"" else Sgs.hand(pid)
	for cid in e.state.zone(Sgs.ZONE_DRAW).cards.duplicate():
		if out.size() >= n:
			break
		if e.card(cid).def_id == def_id:
			e.state.zone(Sgs.ZONE_DRAW).cards.erase(cid)
			e.state.zone(dest).cards.append(cid)
			e.card(cid).zone = dest
			out.append(cid)
	return out


func _hand_ids(e: CardEngine, pid: int, def_id: StringName) -> Array:
	return e.state.zone(Sgs.hand(pid)).cards.filter(func(c): return e.card(c).def_id == def_id)


func test_strike_dodge_and_damage() -> void:
	var e := _game(2, {"players": 3, "heroes": {0: "liubei", 1: "liubei", 2: "liubei"}, "first_draw": false,
		"test_hands": {0: ["strike", "strike"], 1: ["dodge"], 2: ["dodge"]}})
	var king := e.state.current_player
	var victim := e.state.next_alive(king)
	var strikes := _hand_ids(e, king, &"strike")
	var dodge := _hand_ids(e, victim, &"dodge")
	assert_eq(strikes.size(), 2, "king holds 2 strikes")
	var hp_before := e.state.player(victim).hp
	# play strike 1: victim dodges
	assert_true(e.respond(king, e.pending.id, {"cards": [strikes[0]]}), "play strike")
	assert_eq(e.pending.kind, Prompt.KIND_CHOOSE_PLAYERS, "asked for target")
	assert_true(e.pending.players.has(victim), "neighbour in range")
	assert_true(e.respond(king, e.pending.id, {"players": [victim]}))
	assert_eq(e.pending.player, victim, "victim asked to dodge")
	assert_true(e.respond(victim, e.pending.id, {"cards": [dodge[0]]}))
	assert_eq(e.state.player(victim).hp, hp_before, "dodged, no damage")
	assert_eq(e.state.card(strikes[0]).zone, Sgs.ZONE_DISCARD)
	# second strike not allowed (limit 1): not in playable list
	assert_eq(e.pending.player, king)
	assert_false(e.pending.cards.has(strikes[1]), "strike limit reached")


func test_strike_hits_and_kills_triggers_dying_and_win() -> void:
	var e := _game(3, {"players": 2, "heroes": {0: "zhangfei", 1: "zhangfei"}, "first_draw": false,
		"test_hands": {0: ["strike", "strike", "strike"], 1: ["peach"]}})
	var king := e.state.current_player
	var victim := e.state.next_alive(king)
	var strikes := _hand_ids(e, king, &"strike")
	var peach := _hand_ids(e, victim, &"peach")
	e.state.player(victim).hp = 1
	# Zhang Fei: unlimited strikes.
	assert_true(e.respond(king, e.pending.id, {"cards": [strikes[0]]}))
	assert_true(e.respond(king, e.pending.id, {"players": [victim]}))
	# victim has no dodge: goes to 0 hp, dying prompt offers peach
	assert_eq(e.state.player(victim).hp, 0)
	assert_eq(e.pending.player, victim, "dying player asked first (king has no peach)")
	assert_true(e.pending.cards.has(peach[0]))
	assert_true(e.respond(victim, e.pending.id, {"cards": [peach[0]]}))
	assert_eq(e.state.player(victim).hp, 1, "saved")
	assert_true(e.state.player(victim).alive)
	# strike again -> no peach -> dead -> king wins
	assert_true(e.respond(king, e.pending.id, {"cards": [strikes[1]]}))
	assert_true(e.respond(king, e.pending.id, {"players": [victim]}))
	assert_true(e.is_over, "game over")
	assert_eq(e.result.get("winner", ""), "king")
	assert_false(e.state.player(victim).alive)


func test_distance_and_horses() -> void:
	var e := _game(4, {"players": 5})
	var r := _r(e)
	assert_eq(r.distance(e, 0, 1), 1)
	assert_eq(r.distance(e, 0, 2), 2)
	assert_eq(r.distance(e, 0, 3), 2, "wraps around")
	assert_eq(r.distance(e, 0, 4), 1)
	_give(e, 2, &"horse_plus", 1, Sgs.equip(2))
	assert_eq(r.distance(e, 0, 2), 3, "+1 horse")
	_give(e, 0, &"horse_minus", 1, Sgs.equip(0))
	assert_eq(r.distance(e, 0, 2), 2, "-1 horse")
	assert_eq(r.distance(e, 0, 1), 1, "never below 1")
	e.state.player(1).alive = false
	assert_eq(r.distance(e, 0, 2), 1, "dead seats are skipped")


func test_negate_cancels_trick() -> void:
	var e := _game(5, {"players": 3, "heroes": {0: "liubei", 1: "liubei", 2: "liubei"}, "first_draw": false,
		"test_hands": {0: ["windfall"], 1: ["negate"], 2: ["dodge"]}})
	var king := e.state.current_player
	var target := e.state.next_alive(king)
	var windfall := _hand_ids(e, king, &"windfall")
	var negate := _hand_ids(e, target, &"negate")
	var hand_before := e.state.zone(Sgs.hand(king)).size()
	assert_true(e.respond(king, e.pending.id, {"cards": [windfall[0]]}), "play Something for Nothing")
	assert_eq(e.pending.player, target, "holder of Negate is asked")
	assert_true(e.respond(target, e.pending.id, {"cards": [negate[0]]}))
	assert_eq(e.state.zone(Sgs.hand(king)).size(), hand_before - 1, "negated: no draw")
	assert_eq(e.state.card(windfall[0]).zone, Sgs.ZONE_DISCARD)


func test_full_bot_games_finish_and_replay() -> void:
	var finished := 0
	for seed_value in range(100, 112):
		var n := 2 + (seed_value % 7)
		var bots := range(n)
		var e := _game(seed_value, {"players": n, "bots": bots, "decks": ["standard", "expansion"]})
		var bot := SimpleBot.new(e, bots, seed_value)
		assert_true(e.is_over, "seed %d (%d players) finished" % [seed_value, n])
		if not e.is_over:
			continue
		if e.result.get("reason", "") == "turn limit":
			fail("seed %d hit the turn limit" % seed_value)
			continue
		finished += 1
		assert_true(["king", "rebel", "spy"].has(e.result["winner"]), "winner side")
		# Card conservation: every card is in exactly one zone.
		var seen := {}
		for zid in e.state.zones:
			for cid in e.state.zones[zid].cards:
				assert_false(seen.has(cid), "card %d in two zones" % cid)
				seen[cid] = true
				assert_eq(e.card(cid).zone, zid, "card zone field matches")
		assert_eq(seen.size(), e.state.cards.size(), "no cards lost (seed %d)" % seed_value)
		# Replay determinism
		var r := CardEngine.replay(SgsRules.new(), {"players": n, "bots": bots, "decks": ["standard", "expansion"]}, seed_value, e.inputs)
		assert_true(r.is_over, "replay finished (seed %d)" % seed_value)
		assert_eq(JSON.stringify(r.log), JSON.stringify(e.log), "replay log identical (seed %d)" % seed_value)
		assert_true(bot != null)
	assert_true(finished >= 10, "most games finished")
